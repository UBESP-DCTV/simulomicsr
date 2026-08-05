#!/usr/bin/env Rscript
# analysis/audit/2026-08-05-rilettura-214/00-materiale.R
#
# Prepara il materiale per la rilettura di TUTTI e 214 i gruppi del deliverable
# v15, sulla loro composizione POOLATA VERA (non quella censita).
#
# Perche': `coherent` nel deliverable e' un DEFAULT (assenza di verdetto), e la
# copertura misurata il 2026-08-05 e' «212 su 214 poolano solo studi gia' letti»
# — un ARGOMENTO (chiusura per sottoinsiemi), non una lettura. Questa e' la
# lettura.
#
# ⚠️ ETICHETTE INTERE, MAI TRONCATE. Il progetto ha gia' pagato tre volte lo
# stesso errore (alias corti, lettere greche cancellate, testo tagliato a 58/64
# caratteri: un verdetto dato su mezza frase). Lo script stampa la lunghezza
# massima e quante etichette toccano soglie sospette: se una soglia e' toccata
# da molte etichette, sono troncate a monte e il materiale non e' affidabile.
#
# Uso: POOL_DIR=<dir re-pool> Rscript analysis/audit/2026-08-05-rilettura-214/00-materiale.R

suppressPackageStartupMessages({ library(arrow); library(cli); devtools::load_all(".", quiet = TRUE) })

POOL <- Sys.getenv("POOL_DIR", "")
S3   <- Sys.getenv("STAGE3_DIR", "")
OUT  <- "analysis/audit/2026-08-05-rilettura-214"
BLOCCO <- as.integer(Sys.getenv("PER_BLOCCO", "10"))
if (!dir.exists(POOL) || !dir.exists(S3)) cli_abort("POOL_DIR e STAGE3_DIR obbligatorie.")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

D   <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
psd <- unique(as.data.frame(read_parquet(file.path(POOL, "per_study_de.parquet"),
                                         col_select = c("cluster_id", "study_id"))))
s3  <- load_stage3(S3)
s2  <- simulomicsr:::.load_stage2_master("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
s2i <- new.env(hash = TRUE, parent = emptyenv())
for (st in s2) if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2i)

`%||%` <- function(a, b) if (is.null(a) || !length(a) || !nzchar(a)) b else a

# etichette per (cluster, record): trattato e controllo, INTERE
etichette_di <- function(cid) {
  asg <- s3$assignments[s3$assignments$cluster_id == cid, ]
  out <- list()
  for (rid in unique(asg$record_id)) {
    p <- simulomicsr:::.split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2i, inherits = FALSE)) next
    st <- get(p$series_id, envir = s2i, inherits = FALSE)
    cmp <- simulomicsr:::.lookup_cmp(st, p$suffix); if (is.null(cmp)) next
    rgl <- stats::setNames(st$replicate_groups,
                           vapply(st$replicate_groups, function(g) g$group_id, character(1)))
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    out[[length(out) + 1L]] <- list(
      studio = p$series_id,
      trattato  = tg$label_human %||% cmp$treated_group,
      controllo = cg$label_human %||% cmp$control_group,
      n_t = length(unlist(tg$sample_ids)), n_c = length(unlist(cg$sample_ids)))
  }
  out
}

D <- D[order(-D$k_effective), ]
tutte_lab <- character(0)
blocchi <- split(seq_len(nrow(D)), ceiling(seq_len(nrow(D)) / BLOCCO))
cli_alert_info("{nrow(D)} gruppi -> {length(blocchi)} blocchi da {BLOCCO}")

for (b in seq_along(blocchi)) {
  idx <- blocchi[[b]]
  righe <- c(
    sprintf("# BLOCCO %02d — %d meta-analisi da rileggere", b, length(idx)),
    "",
    "Ogni gruppo qui sotto e' una META-ANALISI del deliverable: gli studi elencati",
    "sono quelli EFFETTIVAMENTE POOLATI (non quelli censiti). Le etichette sono",
    "INTERE, mai troncate.", "")
  for (i in idx) {
    r  <- D[i, ]
    st_poolati <- psd$study_id[psd$cluster_id == r$cluster_id]
    ee <- etichette_di(r$cluster_id)
    ee <- ee[vapply(ee, function(x) x$studio %in% st_poolati, logical(1))]
    righe <- c(righe,
      sprintf("## GRUPPO %s", r$cluster_id),
      sprintf("- entita dichiarata : %s  (%s)", r$contrast_entity, r$contrast_entity_label),
      sprintf("- verso / controllo : %s / %s", r$contrast_direction, r$contrast_control_key),
      sprintf("- studi poolati     : %d   studi efficaci (Kish): %.1f   piu pesante: %.0f%%",
              r$k_effective, r$k_kish, 100 * r$quota_top1),
      sprintf("- geni significativi: %d   I2 mediano: %.1f", r$n_sig, r$I2_med),
      sprintf("- verdetto attuale  : %s%s", r$coherence_verdict,
              if (!is.na(r$coherence_reason)) paste0(" — ", r$coherence_reason) else ""),
      "- CONFRONTI (etichette intere):")
    for (e in ee) {
      righe <- c(righe,
        sprintf("    [%s] n=%d vs %d", e$studio, e$n_t, e$n_c),
        sprintf("        TRATTATO : %s", e$trattato),
        sprintf("        CONTROLLO: %s", e$controllo))
      tutte_lab <- c(tutte_lab, e$trattato, e$controllo)
    }
    righe <- c(righe, "")
  }
  writeLines(righe, file.path(OUT, sprintf("blocco-%02d.txt", b)))
}

# --- il controllo che lo strumento veda il dato per intero ---------------------
n <- nchar(tutte_lab)
cli_h2("Le etichette sono intere?")
cli_alert_info("etichette totali: {length(n)} | lunghezza max: {max(n)} | mediana: {median(n)}")
for (s in c(40, 58, 64, 80, 100)) {
  cnt <- sum(n == s)
  cli_alert_info("che misurano esattamente {s} caratteri: {cnt}{if (cnt > 5) '  <-- SOSPETTO: possibile troncamento' else ''}")
}
cli_alert_success("Scritti {length(blocchi)} blocchi in {.path {OUT}}")
