#!/usr/bin/env Rscript
# 50-membri-case-study.R --- i membri POOLATI dei 12 case study, a testo intero.
#
# Serve per rispondere a una domanda che le figure sollevano ma non chiudono:
# i confronti che entrano in una meta-analisi sono fatti sullo STESSO materiale?
# (il gruppo Parkinson e' dominato all'80% da uno studio che non e' cervello di
# paziente ma neuroni derivati da iPSC).
#
# NESSUN TRONCAMENTO, e il controllo che mancava le tre volte in cui uno
# strumento e' stato cieco: quante stringhe toccano il limite di stampa?
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/50-membri-case-study.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
POOL   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT    <- "analysis/audit/2026-07-31-layer-b-v13"

sel <- read.csv("analysis/layer-b-selection-v13.csv", stringsAsFactors = FALSE)
d   <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")
dd  <- d[match(sel$cluster_id, d$cluster_id), ]
dd$label_paper <- sel$label_paper

asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% dd$cluster_id, ]
asg$study <- sub("__.*$", "", asg$record_id)

sp <- arrow::open_dataset(file.path(POOL, "per_study_de.parquet")) |>
  dplyr::filter(cluster_id %in% dd$cluster_id) |>
  dplyr::distinct(cluster_id, study_id) |> dplyr::collect()
studi_pool <- split(sp$study_id, sp$cluster_id)

s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", study$series_id, cmp$comparison_id)
    if (!rid %in% need) next
    t <- rgl[[cmp$treated_group]]; c <- rgl[[cmp$control_group]]
    if (is.null(t) || is.null(c)) next
    assign(rid, list(tl = lab_of(t, cmp$treated_group), cl = lab_of(c, cmp$control_group)),
           envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

# --- controllo di cecita' dello strumento -----------------------------------
tutte <- unlist(lapply(ls(lab), function(k) { e <- get(k, envir = lab); c(e$tl, e$cl) }))
cat("etichette raccolte:", length(tutte), "\n")
cat("lunghezza: min", min(nchar(tutte)), "mediana", median(nchar(tutte)),
    "max", max(nchar(tutte)), "\n")
for (lim in c(40, 58, 80, 120, 200)) {
  cat(sprintf("  stringhe con >= %d caratteri: %d (%.1f%%)\n",
              lim, sum(nchar(tutte) >= lim), 100 * mean(nchar(tutte) >= lim)))
}
cat("NESSUN troncamento applicato qui: si stampa la stringa intera.\n\n")

dd <- dd[order(-dd$k_effective), ]
zz <- file(file.path(OUT, "membri-case-study.txt"), open = "wt")
sink(zz)
cat("MEMBRI POOLATI DEI 12 CASE STUDY — TESTO INTERO, NESSUN TRONCAMENTO\n")
cat("Domanda: i confronti che entrano nella meta-analisi sono sullo stesso materiale?\n")
for (i in seq_len(nrow(dd))) {
  cid <- dd$cluster_id[i]
  dentro <- unique(studi_pool[[cid]])
  righe <- asg[asg$cluster_id == cid, ]
  cat("\n\n=============================================================\n")
  cat(sprintf("[%02d/%02d] %s\n", i, nrow(dd), dd$label_paper[i]))
  cat(sprintf("  %s || %s || %s | k=%d | n_sig=%d | I2=%.1f | %s\n",
              dd$contrast_entity[i], dd$contrast_direction[i],
              dd$contrast_control_key[i], dd$k_effective[i], dd$n_sig[i],
              dd$I2_med[i], dd$coherence_verdict[i]))
  vis <- character(0)
  for (j in seq_len(nrow(righe))) {
    e <- get0(righe$record_id[j], envir = lab, inherits = FALSE)
    if (is.null(e)) next
    if (!(righe$study[j] %in% dentro)) next
    key <- paste(righe$study[j], e$tl, e$cl)
    if (key %in% vis) next
    vis <- c(vis, key)
    cat(sprintf("   %-10s %s\n          => %s\n", righe$study[j], e$tl, e$cl))
  }
}
sink(); close(zz)
cat("scritto", file.path(OUT, "membri-case-study.txt"), "\n")
