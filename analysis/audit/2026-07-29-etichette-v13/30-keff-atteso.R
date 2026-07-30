#!/usr/bin/env Rscript
# 30-keff-atteso.R --- quanti dei 305 gruppi superano il gate del pooling?
#
# Il ramo rem_group scarta i cluster in cui meno di 3 studi DISTINTI portano un
# confronto risolvibile con controllo interno (limite L7, 2026-07-09). Nel log
# del run questi cluster escono con `next` e non stampano nemmeno la riga di
# esito: senza questa misura ce ne accorgeremmo solo a fine run.
#
# Usa la funzione di dispatch VERA (.build_group_rem_dispatch_from_stage3), la
# stessa che il run sta usando: nessuna riproduzione approssimata della regola.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT <- "analysis/audit/2026-07-29-etichette-v13"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

s3  <- load_stage3(V13)
cfg <- stage4_default_config()
la  <- simulomicsr:::.identify_layer_a_clusters(s3$clusters, cfg)
stopifnot(nrow(la) == 305L)

s2 <- simulomicsr:::.load_stage2_master(STAGE2)
# Stesso pre-filtro del run: i sample non presenti nell'asse H5 non contano.
h5_ax <- as.character(rhdf5::h5read("analysis/input/human_gene_v2.5.h5",
                                    "meta/samples/geo_accession"))
h5_set <- new.env(hash = TRUE, parent = emptyenv())
for (s in h5_ax) assign(s, TRUE, envir = h5_set)
for (i in seq_along(s2)) {
  rgs <- s2[[i]]$replicate_groups
  for (j in seq_along(rgs)) {
    sids <- as.character(unlist(rgs[[j]]$sample_ids))
    s2[[i]]$replicate_groups[[j]]$sample_ids <-
      as.list(sids[vapply(sids, exists, logical(1L), envir = h5_set, inherits = FALSE)])
  }
}
rm(h5_ax, h5_set); gc(verbose = FALSE)

disp <- simulomicsr:::.build_group_rem_dispatch_from_stage3(
  eligible_clusters = la, stage3_assignments = s3$assignments,
  stage2_master = s2, n_min = cfg$rem_group$n_min %||% 2L)

k_eff_min <- cfg$rem_group$k_eff_min %||% 3L
res <- data.frame(
  cluster_id      = la$cluster_id,
  contrast_entity = la$contrast_entity,
  canonical_name  = la$canonical_name,
  k_censito       = la$k,
  stringsAsFactors = FALSE)
res$k_eff <- vapply(res$cluster_id, function(cid) {
  d <- disp[[cid]]
  if (is.null(d) || !length(d)) return(0L)
  length(unique(vapply(d, function(z) z$study_id, character(1L))))
}, integer(1L))
res$superato <- res$k_eff >= k_eff_min
res <- res[order(-res$k_censito), ]
utils::write.csv(res, file.path(OUT, "keff-atteso.csv"), row.names = FALSE)

cat("=== QUANTI GRUPPI SARANNO POOLATI ===\n")
cat("gruppi del deliverable :", nrow(res), "\n")
cat("superano k_eff >=", k_eff_min, ":", sum(res$superato),
    sprintf("(%.1f%%)\n", 100 * mean(res$superato)))
cat("scartati dal gate      :", sum(!res$superato), "\n")
cat("studi-slot tenuti      :", sum(res$k_censito[res$superato]), "su", sum(res$k_censito), "\n")
cat("\nk_eff vs k censito (nei superati): k_eff MAI maggiore di k? ",
    all(res$k_eff[res$superato] <= res$k_censito[res$superato]), "\n")
cat("\ndistribuzione k_eff degli scartati:\n")
print(table(res$k_eff[!res$superato]))
cat("\n=== SCARTATI, i 25 con k censito piu' alto ===\n")
print(utils::head(res[!res$superato, c("contrast_entity", "canonical_name", "k_censito", "k_eff")], 25),
      row.names = FALSE)
cat("\ntabella:", file.path(OUT, "keff-atteso.csv"), "\n")
