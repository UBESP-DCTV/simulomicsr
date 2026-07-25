# AUDIT SISTEMATICO DEL RESOLVER — passo 1: catalogo degli alias PERICOLOSI.
#
# Ipotesi da verificare (nata da due casi reali: ImmPort "ML" -> THPO su ogni
# etichetta con "ug/ml"; ImmPort "LAP" -> TGFB1 su "Her/Lap" dove Lap = lapatinib):
# i vocabolari di riferimento contengono sinonimi CORTI o AMBIGUI che collidono
# col gergo di laboratorio, e il resolver li accetta silenziosamente.
#
# Il catalogo NON e' una lista scritta a mano: le classi di pericolo si calcolano
# dai dizionari + dalla frequenza dei token nel corpus reale di etichette.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({library(dplyr); library(arrow)})
OUT <- "analysis/audit/2026-07-25-resolver-alias-audit"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
oe <- .load_ontology_dicts()
t0 <- Sys.time()

## ---------------------------------------------------------------- 1. dizionari
## alias -> (id, nome primario, dizionario). Si enumerano le tabelle di sinonimi
## realmente usate dal resolver di produzione.
cat(format(Sys.time()), "- enumero le tabelle di alias...\n")
rows <- list()
add <- function(alias, id, name, dict) rows[[length(rows) + 1L]] <<-
  data.frame(alias = alias, id = id, name = name, dict = dict, stringsAsFactors = FALSE)

# ChEBI
ca <- oe$chebi$aliases; ka <- ls(ca)
ch_id <- vapply(ka, function(k) as.character(get(k, envir = ca)$chebi_id), "")
ch_nm <- vapply(ch_id, function(i) {
  r <- .chebi_lookup_id(i, env = oe); if (is.null(r)) NA_character_ else r$primary_name }, "")
add(ka, paste0("CHEBI:", ch_id), unname(ch_nm), "chebi")

# ImmPort (citochine)
ia <- oe$immport$by_synonym; ki <- ls(ia)
im <- lapply(ki, function(k) get(k, envir = ia))
im_id <- vapply(im, function(z) as.character(z$hgnc_int %||% z[[1]]), "")
im_nm <- vapply(im, function(z) as.character(z$symbol %||% z[[2]] %||% NA), "")
add(ki, paste0("HGNC:", im_id), im_nm, "immport")

# HGNC (simboli e alias)
hs <- oe$hgnc$by_symbol_lower; kh <- ls(hs)
hh <- lapply(kh, function(k) get(k, envir = hs))
add(kh, vapply(hh, function(z) paste0("HGNC:", z$hgnc_int), ""),
    vapply(hh, function(z) as.character(z$primary_symbol), ""), "hgnc")

# MeSH (entry terms)
ms <- oe$mesh$by_entry_lower; km <- ls(ms)
mu <- vapply(km, function(k) get(k, envir = ms)$ui, "")
m_nm <- vapply(mu, function(u) { r <- .mesh_lookup_ui(u, env = oe); if (is.null(r)) NA_character_ else r$mh }, "")
add(km, paste0("MeSH:", mu), unname(m_nm), "mesh")

# ChEMBL
if (isTRUE(oe$has_chembl)) {
  cl <- oe$chembl$aliases; kc <- ls(cl)
  cc <- lapply(kc, function(k) get(k, envir = cl))
  add(kc, vapply(cc, function(z) paste0("CHEMBL:", z$chembl_id %||% z[[1]]), ""),
      vapply(cc, function(z) as.character(z$pref_name %||% NA), ""), "chembl")
}
# Tassonomia
if (isTRUE(oe$has_taxonomy)) {
  tx <- oe$taxonomy$by_name; kt <- ls(tx)
  tt <- vapply(kt, function(k) as.character(get(k, envir = tx)[[1]]), "")
  add(kt, paste0("NCBITaxon:", tt), NA_character_, "taxonomy")
}
# UniProt
if (isTRUE(oe$has_uniprot)) {
  up <- oe$uniprot$by_name; ku <- ls(up)
  uu <- lapply(ku, function(k) get(k, envir = up))
  add(ku, vapply(uu, function(z) paste0("HGNC:", z$hgnc_int %||% NA), ""),
      vapply(uu, function(z) as.character(z$symbol %||% NA), ""), "uniprot")
}
A <- bind_rows(rows)
A$alias <- tolower(trimws(A$alias))
A <- A[nzchar(A$alias), ]
cat(sprintf("  alias totali: %d (per dizionario: %s)\n", nrow(A),
            paste(sprintf("%s=%d", names(table(A$dict)), as.integer(table(A$dict))), collapse = " ")))

## ------------------------------------------------------- 2. corpus di etichette
## Le vere stringhe che il resolver vede in produzione (Stadio 2 -> Stadio 3).
cat(format(Sys.time()), "- carico il corpus di etichette reali...\n")
pmc <- read_parquet("analysis/audit/2026-07-23-coherence/per-member-contrasts.parquet")
lab <- data.frame(
  study = c(pmc$study_id, pmc$study_id, pmc$study_id, pmc$study_id),
  txt   = c(pmc$treated_label, pmc$control_label, pmc$treated_fl, pmc$control_fl),
  stringsAsFactors = FALSE)
lab <- lab[!is.na(lab$txt) & nzchar(lab$txt), ]
tok_of <- function(s) {
  s <- tolower(s)
  w <- strsplit(gsub("[^a-z0-9]+", " ", s), " +")[[1]]
  unique(w[nzchar(w)])
}
cat(sprintf("  etichette: %d | studi: %d\n", nrow(lab), n_distinct(lab$study)))
tl <- lapply(lab$txt, tok_of)
tok_df <- data.frame(study = rep(lab$study, lengths(tl)), tok = unlist(tl), stringsAsFactors = FALSE)
freq <- tok_df |> group_by(tok) |> summarise(n_studi = n_distinct(study), n_occ = n(), .groups = "drop")
cat(sprintf("  token distinti nel corpus: %d\n", nrow(freq)))
saveRDS(freq, file.path(OUT, "corpus-token-freq.rds"))

## ------------------------------------------------------- 3. classi di PERICOLO
UNITS <- c("ml","ul","dl","l","ug","mg","ng","pg","kg","g","nm","um","mm","pm","cm","mol","mmol",
           "umol","nmol","moi","pfu","ffu","tcid","iu","hr","hrs","min","sec","h","d","rpm","rcf",
           "ph","psi","hz","kb","bp","mb","gb","x","v","w")
A$nchar <- nchar(gsub("[^a-z0-9]", "", A$alias))
A$is_primary <- !is.na(A$name) & (tolower(A$name) == A$alias)
A$single_token <- !grepl("[^a-z0-9-]", A$alias)
A <- left_join(A, freq, by = c("alias" = "tok"))
A$n_studi[is.na(A$n_studi)] <- 0L

# D1 unita' di misura | D2 sigla <=3 char non primaria | D3 gergo ad alta frequenza
# | D4 ambiguo fra dizionari (stesso alias -> entita' diverse)
amb <- A |> group_by(alias) |> summarise(n_ent = n_distinct(id), .groups = "drop")
A <- left_join(A, amb, by = "alias")
A$D1_unita   <- A$alias %in% UNITS
A$D2_sigla   <- A$nchar <= 3 & !A$is_primary
A$D3_gergo   <- A$single_token & A$n_studi >= 50 & !A$is_primary
A$D4_ambiguo <- A$n_ent >= 2
A$pericoloso <- A$D1_unita | A$D2_sigla | A$D3_gergo | A$D4_ambiguo
A$attivo     <- A$n_studi > 0            # l'alias compare davvero nel corpus

cat("\n=== CLASSI DI PERICOLO (su tutti gli alias) ===\n")
print(colSums(A[, c("D1_unita","D2_sigla","D3_gergo","D4_ambiguo","pericoloso")]))
cat("\n=== alias che COMPAIONO nel corpus reale ===\n")
cat(sprintf("attivi: %d di cui pericolosi: %d (%.1f%%)\n",
            sum(A$attivo), sum(A$attivo & A$pericoloso),
            100 * sum(A$attivo & A$pericoloso) / max(1, sum(A$attivo))))
cat("\n=== i 30 alias pericolosi PIU' FREQUENTI nel corpus ===\n")
top <- A[A$attivo & A$pericoloso, ] |> arrange(desc(n_studi)) |>
  select(alias, id, name, dict, n_studi, nchar, D1_unita, D2_sigla, D3_gergo, D4_ambiguo)
print(head(as.data.frame(top), 30), row.names = FALSE)
write.csv(A[A$attivo & A$pericoloso, ], file.path(OUT, "alias-pericolosi-attivi.csv"), row.names = FALSE)
saveRDS(A, file.path(OUT, "alias-catalog.rds"))
cat(sprintf("\nsalvato alias-catalog.rds + alias-pericolosi-attivi.csv (%.1f min)\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))
