#!/usr/bin/env Rscript
# 20-sospetti.R --- i casi in cui l'ID e il nome mostrato si contraddicono in
# modo che conta: il nome vecchio e' biologicamente PLAUSIBILE ma diverso da
# cio' che l'ID dice. Per ciascuno stampa i membri veri (studio, trattato =>
# controllo): sono loro a dire chi ha ragione.
#
# Metodo identico al bundle del censimento (10-bundle-v13.R): stesse etichette,
# stessa deduplicazione, cosi' i verdetti sono confrontabili.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT <- "analysis/audit/2026-07-29-etichette-v13"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

SOSPETTI <- c(
  "NCBITaxon:10359",  # dizionario: CMV      | mostrato: influenza virus
  "HGNC:5973",        # IL13                 | IL5RA
  "HGNC:6005",        # IL21                 | IL5
  "HGNC:30743",       # TSLP                 | IL25
  "HGNC:1653",        # CD28                 | Corynebacterium acnes
  "HGNC:11927",       # TNFSF12 (TWEAK)      | epoxyoctadecenoate
  "CHEBI:59132",      # "antigen"            | DCVC (nome usato nel censimento)
  "CHEBI:73572",      # Leu-Thr-Ala          | lipoteichoic acid
  "CHEBI:4167",       # D-glucopyranose      | colon cancer / vuoto
  "CHEBI:233643",     # UNC0642              | L-methionine + UNC0642 (combo?)
  "CHEBI:81571",      # Leptin               | N-hydroxydihomomethionine
  "STR:covid_19",     # covid_19             | Mycobacterium tuberculosis
  "MeSH:D000074285",  # Smokers              | (S)-nicotine
  # Secondo giro (dal controllo sistematico 40-): l'ID e' stato riconosciuto nei
  # membri SOLO da una sigla, e la sigla ha piu' di un significato in letteratura.
  "CHEBI:46024",      # trichostatin A       | "TSA" e' anche tumor-specific antigen
  "CHEBI:138438",     # nome sistematico     | "SAG" e' anche Smoothened Agonist
  "CHEBI:32588",      # potassium chloride   | matcha "[kcl]", forma sospetta
  "CHEBI:49852",      # DRB                  | "DRB" e' anche un locus HLA
  # Terzo giro: i patogeni non matchano MAI per costruzione (il dizionario
  # conserva il nome scientifico normalizzato, i metadati usano le sigle).
  # ID e nome vecchio qui concordano, ma concordare non e' essere verificati.
  "NCBITaxon:11320", "NCBITaxon:11676", "NCBITaxon:10298", "NCBITaxon:10407"
)

cl  <- readRDS(file.path(V13, "clusters.rds"))
sel <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
sel <- sel[sel$contrast_entity %in% SOSPETTI, ]
cat("gruppi da guardare:", nrow(sel), "\n")

asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% sel$cluster_id, ]

s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) {
  if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
}
for (study in s2) {
  sid <- study$series_id
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", sid, cmp$comparison_id)
    if (!rid %in% need) next
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(rid, list(study = sid, tl = lab_of(tg, cmp$treated_group),
                     cl = lab_of(cg, cmp$control_group)), envir = lab)
  }
}

env <- simulomicsr:::.load_ontology_dicts()
zz <- file(file.path(OUT, "sospetti-membri.txt"), open = "wt")
sink(zz)
cat("CASI SOSPETTI — l'ID dice una cosa, il nome mostrato un'altra.\n")
cat("Sono i MEMBRI a dire chi ha ragione.\n")
sel <- sel[order(-sel$k), ]
for (i in seq_len(nrow(sel))) {
  lb <- simulomicsr:::.resolve_contrast_entity_label(sel$contrast_entity[i], env = env)
  rid <- asg$record_id[asg$cluster_id == sel$cluster_id[i]]
  ee <- lapply(rid, function(r) get0(r, envir = lab, inherits = FALSE))
  ee <- ee[!vapply(ee, is.null, logical(1))]
  cat("\n\n=============================================================\n")
  cat(sprintf("%s || %s || %s   (k=%d)\n", sel$contrast_entity[i],
              sel$contrast_direction[i], sel$contrast_control_key[i], sel$k[i]))
  cat(sprintf("  ID dice        : %s\n", lb$label))
  cat(sprintf("  mostrato oggi  : %s\n", sel$canonical_name[i] %||% "(vuoto)"))
  if (!length(ee)) { cat("  (nessun membro risolto)\n"); next }
  key <- vapply(ee, function(e) paste(e$study, e$tl, e$cl, sep = ""), character(1))
  tb <- table(key)
  for (u in names(tb)) {
    p <- strsplit(u, "", fixed = TRUE)[[1]]
    m <- if (tb[[u]] > 1L) sprintf(" x%d", tb[[u]]) else ""
    cat(sprintf("   %-11s %-60s => %s%s\n", p[1], substr(p[2], 1, 60),
                substr(p[3], 1, 40), m))
  }
}
sink(); close(zz)
cat("scritto", file.path(OUT, "sospetti-membri.txt"), "\n")
