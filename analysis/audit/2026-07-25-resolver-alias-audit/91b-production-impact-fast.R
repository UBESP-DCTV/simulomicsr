# AUDIT SISTEMATICO DEL RESOLVER — passo 2 (versione vettorizzata).
#
# Domanda: dei nomi che il recupero-nome ha davvero assegnato in PRODUZIONE
# (cache GSM -> identita'), quanti nascono da un alias PERICOLOSO?
# Testo sorgente = quello vero dell'H5 (gli stessi campi di build_name_recovery_lookup).
#
# NB: tutto per join vettoriali. La versione con env su 4,4 M di alias non
# finiva (22 min di solo indicizzamento, 8,8 GB).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({library(dplyr); library(tidyr)})
OUT <- "analysis/audit/2026-07-25-resolver-alias-audit"
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
t0 <- Sys.time()
A <- readRDS(file.path(OUT, "alias-catalog.rds"))

## ------------------------------------------------- identita' di PRODUZIONE
cat(format(Sys.time()), "- cache di produzione...\n")
cache <- readRDS("/home/user/.cache/R/simulomicsr/name-recovery-lookup/name-recovery-lookup-fae90f35.rds")
gsms <- ls(cache); rec <- lapply(gsms, function(g) get(g, envir = cache))
lk <- data.frame(gsm = gsms,
                 agent_id = vapply(rec, function(z) z$agent_id %||% NA_character_, ""),
                 name = vapply(rec, function(z) z$canonical_name %||% NA_character_, ""),
                 src = vapply(rec, function(z) z$recovery_source %||% NA_character_, ""),
                 stringsAsFactors = FALSE)
onto <- lk[!is.na(lk$agent_id) & grepl("^(CHEBI|MeSH|HGNC|CHEMBL|NCBITaxon):", lk$agent_id), ]
cat(sprintf("  GSM con ID ontologico: %d\n", nrow(onto)))

## ------------------------------------------------- testo sorgente dall'H5
cat(format(Sys.time()), "- H5...\n")
H5 <- "analysis/input/human_gene_v2.5.h5"
gsm_all <- as.character(rhdf5::h5read(H5, "meta/samples/geo_accession"))
idx <- match(onto$gsm, gsm_all)
f_src <- as.character(rhdf5::h5read(H5, "meta/samples/source_name_ch1"))[idx]
f_chr <- as.character(rhdf5::h5read(H5, "meta/samples/characteristics_ch1"))[idx]
f_tit <- as.character(rhdf5::h5read(H5, "meta/samples/title"))[idx]
rhdf5::h5closeAll()
onto$txt <- paste(f_src, f_chr, f_tit)
onto <- onto[!is.na(idx), ]; rm(f_src, f_chr, f_tit); invisible(gc())
cat(sprintf("  testo per %d GSM (%.1f min)\n", nrow(onto), as.numeric(difftime(Sys.time(), t0, units = "mins"))))

## ------------------------------------------------- token -> alias (join)
cat(format(Sys.time()), "- token dei testi...\n")
onto$row <- seq_len(nrow(onto))
tl <- strsplit(gsub("[^a-z0-9]+", " ", tolower(onto$txt)), " +")
tk <- data.frame(row = rep(onto$row, lengths(tl)), tok = unlist(tl), stringsAsFactors = FALSE)
tk <- tk[nzchar(tk$tok), ]
tk <- distinct(tk)
cat(sprintf("  coppie (campione, token): %d | token distinti: %d\n", nrow(tk), n_distinct(tk$tok)))

## l'alias che ha innescato = un token del testo che e' alias PROPRIO dell'ID assegnato
Amin <- A |> select(alias, id, dict, D1_unita, D2_sigla, D3_gergo, D4_ambiguo, pericoloso, n_studi) |>
  filter(alias %in% unique(tk$tok)) |> distinct()
cat(sprintf("  alias del dizionario presenti come token: %d\n", n_distinct(Amin$alias)))
hit <- tk |> inner_join(Amin, by = c("tok" = "alias"), relationship = "many-to-many") |>
  inner_join(onto[, c("row", "agent_id")], by = "row") |>
  filter(id == agent_id)
## se piu' token spiegano lo stesso ID, tiene il PIU' LUNGO (il piu' specifico):
## e' la lettura conservativa — se esiste un alias lungo e legittimo, non si
## accusa il resolver di aver usato la sigla.
fire <- hit |> mutate(len = nchar(tok)) |> group_by(row) |>
  slice_max(len, n = 1, with_ties = FALSE) |> ungroup()
onto <- left_join(onto, fire |> select(row, alias_innesco = tok, dict, D1_unita, D2_sigla,
                                       D3_gergo, D4_ambiguo, pericoloso, n_studi), by = "row")

cat("\n=== IMPATTO SULLA PRODUZIONE (campioni con ID ontologico recuperato) ===\n")
n <- nrow(onto); nid <- sum(!is.na(onto$alias_innesco))
cat(sprintf("campioni analizzati              : %d\n", n))
cat(sprintf("alias di innesco identificato    : %d (%.1f%%)\n", nid, 100 * nid / n))
cat(sprintf("innesco da alias PERICOLOSO      : %d (%.1f%% degli identificati, %.1f%% del totale)\n",
            sum(onto$pericoloso %in% TRUE), 100 * sum(onto$pericoloso %in% TRUE) / max(1, nid),
            100 * sum(onto$pericoloso %in% TRUE) / n))
cat("\n-- per classe di pericolo (campioni) --\n")
cls <- onto |> filter(pericoloso %in% TRUE) |>
  summarise(D1_unita = sum(D1_unita), D2_sigla = sum(D2_sigla), D3_gergo = sum(D3_gergo),
            D4_ambiguo = sum(D4_ambiguo))
print(cls)
cat("\n-- per sorgente di recupero --\n")
print(onto |> group_by(src) |> summarise(n = n(), pericolosi = sum(pericoloso %in% TRUE),
        pct = round(100 * pericolosi / n, 1), .groups = "drop") |> arrange(desc(n)) |> as.data.frame())
cat("\n-- 30 alias di innesco pericolosi piu' impattanti --\n")
tt <- onto |> filter(pericoloso %in% TRUE) |> group_by(alias_innesco, agent_id, name, dict) |>
  summarise(n_gsm = n(), .groups = "drop") |> arrange(desc(n_gsm))
print(head(as.data.frame(tt), 30), row.names = FALSE)
saveRDS(onto, file.path(OUT, "production-firing.rds"))
write.csv(tt, file.path(OUT, "alias-innesco-produzione.csv"), row.names = FALSE)
cat(sprintf("\nfatto (%.1f min)\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
