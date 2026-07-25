# AUDIT SISTEMATICO DEL RESOLVER — passo 2: impatto sulla PRODUZIONE.
#
# Domanda: dei nomi che il recupero-nome ha davvero assegnato ai campioni
# (cache di produzione GSM -> identita'), quanti nascono da un alias PERICOLOSO?
# Il testo sorgente e' quello vero dell'H5 (gli stessi campi che legge
# build_name_recovery_lookup: source_name_ch1, characteristics_ch1, title).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({library(dplyr)})
OUT <- "analysis/audit/2026-07-25-resolver-alias-audit"
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
oe <- .load_ontology_dicts()
A <- readRDS(file.path(OUT, "alias-catalog.rds"))
t0 <- Sys.time()

## alias -> insieme di ID (per capire QUALE alias ha fatto scattare il match)
cat(format(Sys.time()), "- indicizzo gli alias...\n")
env_alias <- new.env(hash = TRUE, parent = emptyenv())
sp <- split(A$id, A$alias)
for (nm in names(sp)) assign(nm, unique(sp[[nm]]), envir = env_alias)
danger <- A |> group_by(alias) |>
  summarise(D1 = any(D1_unita), D2 = any(D2_sigla), D3 = any(D3_gergo),
            D4 = any(D4_ambiguo), pericoloso = any(pericoloso), n_studi = max(n_studi),
            .groups = "drop")
env_dang <- new.env(hash = TRUE, parent = emptyenv())
for (i in seq_len(nrow(danger))) assign(danger$alias[i], as.list(danger[i, -1]), envir = env_dang)

## identita' recuperate in produzione
cat(format(Sys.time()), "- carico la cache di produzione...\n")
cache <- readRDS("/home/user/.cache/R/simulomicsr/name-recovery-lookup/name-recovery-lookup-fae90f35.rds")
gsms <- ls(cache)
rec <- lapply(gsms, function(g) get(g, envir = cache))
lk <- data.frame(
  gsm = gsms,
  agent_id = vapply(rec, function(z) z$agent_id %||% NA_character_, ""),
  name = vapply(rec, function(z) z$canonical_name %||% NA_character_, ""),
  src = vapply(rec, function(z) z$recovery_source %||% NA_character_, ""),
  stringsAsFactors = FALSE)
onto <- lk[!is.na(lk$agent_id) & grepl("^(CHEBI|MeSH|HGNC|CHEMBL|NCBITaxon):", lk$agent_id), ]
cat(sprintf("  GSM con ID ontologico recuperato: %d\n", nrow(onto)))

## testo sorgente VERO dall'H5
cat(format(Sys.time()), "- leggo i campi H5 (puo' richiedere qualche minuto)...\n")
H5 <- "analysis/input/human_gene_v2.5.h5"
gsm_all <- as.character(rhdf5::h5read(H5, "meta/samples/geo_accession"))
f_src <- as.character(rhdf5::h5read(H5, "meta/samples/source_name_ch1"))
f_chr <- as.character(rhdf5::h5read(H5, "meta/samples/characteristics_ch1"))
f_tit <- as.character(rhdf5::h5read(H5, "meta/samples/title"))
rhdf5::h5closeAll()
idx <- match(onto$gsm, gsm_all)
onto$txt <- paste(f_src[idx], f_chr[idx], f_tit[idx])
onto <- onto[!is.na(idx), ]
rm(f_src, f_chr, f_tit); invisible(gc())
cat(sprintf("  testo sorgente recuperato per %d GSM (%.1f min)\n", nrow(onto),
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

## quale alias ha fatto scattare il match?
cat(format(Sys.time()), "- identifico l'alias che ha innescato ogni risoluzione...\n")
firing <- rep(NA_character_, nrow(onto)); fdang <- rep(NA, nrow(onto)); fcls <- rep("", nrow(onto))
for (i in seq_len(nrow(onto))) {
  id <- onto$agent_id[i]
  cands <- try(.extract_compound_candidates(onto$txt[i]), silent = TRUE)
  if (inherits(cands, "try-error")) next
  cands <- unique(tolower(trimws(c(cands, strsplit(gsub("[^a-z0-9]+", " ", tolower(onto$txt[i])), " +")[[1]]))))
  cands <- cands[nzchar(cands)]
  hit <- NA_character_
  for (cd in cands) {
    if (exists(cd, envir = env_alias, inherits = FALSE) && id %in% get(cd, envir = env_alias)) { hit <- cd; break }
  }
  if (is.na(hit)) next
  firing[i] <- hit
  if (exists(hit, envir = env_dang, inherits = FALSE)) {
    d <- get(hit, envir = env_dang)
    fdang[i] <- isTRUE(d$pericoloso)
    fcls[i] <- paste(c("D1_unita", "D2_sigla", "D3_gergo", "D4_ambiguo")[
      c(isTRUE(d$D1), isTRUE(d$D2), isTRUE(d$D3), isTRUE(d$D4))], collapse = "+")
  }
  if (i %% 5000 == 0) cat(sprintf("  %d/%d\n", i, nrow(onto)))
}
onto$alias_innesco <- firing; onto$pericoloso <- fdang; onto$classi <- fcls

cat("\n=== IMPATTO SULLA PRODUZIONE (campioni con ID ontologico recuperato) ===\n")
cat(sprintf("campioni analizzati            : %d\n", nrow(onto)))
cat(sprintf("alias di innesco identificato  : %d (%.1f%%)\n", sum(!is.na(onto$alias_innesco)),
            100 * mean(!is.na(onto$alias_innesco))))
cat(sprintf("innescati da un alias PERICOLOSO: %d (%.1f%% di quelli identificati)\n",
            sum(isTRUE(TRUE) & onto$pericoloso %in% TRUE),
            100 * sum(onto$pericoloso %in% TRUE) / max(1, sum(!is.na(onto$alias_innesco)))))
cat("\n-- per classe di pericolo --\n"); print(sort(table(onto$classi[onto$pericoloso %in% TRUE]), decreasing = TRUE))
cat("\n-- per sorgente di recupero --\n")
print(onto |> group_by(src) |> summarise(n = n(), pericolosi = sum(pericoloso %in% TRUE),
                                         pct = round(100 * pericolosi / n, 1), .groups = "drop") |> arrange(desc(n)))
cat("\n-- i 25 alias di innesco pericolosi piu' frequenti --\n")
tt <- onto[onto$pericoloso %in% TRUE, ] |> group_by(alias_innesco, agent_id, name) |>
  summarise(n_gsm = n(), .groups = "drop") |> arrange(desc(n_gsm))
print(head(as.data.frame(tt), 25), row.names = FALSE)
saveRDS(onto, file.path(OUT, "production-firing.rds"))
write.csv(tt, file.path(OUT, "alias-innesco-produzione.csv"), row.names = FALSE)
cat(sprintf("\nfatto (%.1f min)\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
