#!/usr/bin/env Rscript
# E5 smoke plot generator — FASE E5 RED ALERT
#
# Gira Layer B end-to-end su fixture sintetica aggiornata al nuovo schema
# E1-E3 (gene_id + gene_symbol + biotype filter + covariate batch).
# Output PNG/SVG/HTML in analysis/audit/E5-smoke-plots/ per giudizio
# visuale dell'utente.
#
# Scope: NON e' un test paper-grade dei plot Layer B su dati veri
# (quello sara' nel rebuild F5+F6). E' uno smoke che verifica:
#   - i plot girano senza errori col nuovo schema
#   - label leggibili (gene_symbol HGNC) appaiono nei plot
#   - run_metadata.json registra schema_versions stage4_algorithm v2

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

out_dir <- "analysis/audit/E5-smoke-plots"
if (dir.exists(out_dir)) unlink(out_dir, recursive = TRUE)
dir.create(out_dir, recursive = TRUE)

cat("E5 smoke Layer B — output dir:", out_dir, "\n")

# Carica fixture helper (sono in tests/testthat/helper-layer-b-fixtures.R)
source("tests/testthat/helper-layer-b-fixtures.R")

stage4_dir <- make_fake_layer_a_dir()
cat("Mock Stage 4 dir:", stage4_dir, "\n")

cache <- make_fake_counts_cache(c("cl_mega_1", "cl_aug_1"))

per_cluster_samples_provider <- function(cluster_id) {
  studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
  tibble::tibble(
    sample_id = c(paste0("GSE_PAIR_A_GSM", 1:6),
                   paste0("GSE_PAIR_B_GSM", 1:6)),
    study_id  = rep(studies, each = 6L),
    treatment = rep(c("control", "control", "control",
                       "treated", "treated", "treated"), 2L)
  )
}

selection <- tibble::tibble(
  cluster_id = c("cl_mega_1", "cl_aug_1"),
  label_paper = c("MEGA test (E5 smoke)", "MEGA-AUG test (E5 smoke)"),
  priority = c(1L, 2L),
  notes = c("Mega pure post-E1-E3 schema",
             "Mega-aug post-E1-E3 schema")
)

cfg <- layer_b_default_config()
cfg$go_enrichment <- FALSE   # skip GO (richiede Ensembl ID veri in org.Hs.eg.db)

cat("Esecuzione build_layer_b_results...\n")
result <- build_layer_b_results(
  stage4_dir = stage4_dir,
  selection = selection,
  h5_path = NULL,
  fetch_counts_fn = cache$fetch_counts_fn,
  per_cluster_samples_provider = per_cluster_samples_provider,
  config = cfg,
  out_dir = out_dir
)

cat("\n=== OUTPUT ===\n")
cat("Bundle dir:", result$dir, "\n")
cat("Cluster processed:", length(result$cluster_bundles), "\n")

# Lista PNG/SVG/CSV generati per cluster
for (cid in c("cl_mega_1", "cl_aug_1")) {
  cat("\n---", cid, "---\n")
  bundle_files <- list.files(file.path(result$dir, cid), full.names = FALSE)
  for (f in bundle_files) cat("  ", f, "\n")
}

# Verifica top_genes.csv schema (gene_id + gene_symbol)
cat("\n=== Verifica schema top_genes.csv ===\n")
for (cid in c("cl_mega_1", "cl_aug_1")) {
  csv_p <- file.path(result$dir, cid, "top_genes.csv")
  if (file.exists(csv_p)) {
    df <- readr::read_csv(csv_p, show_col_types = FALSE)
    cat(sprintf("  %s: %d righe, cols: %s\n",
                cid, nrow(df), paste(names(df), collapse = ", ")))
  }
}

# Run_metadata.json schema_versions
cat("\n=== Verifica schema_versions in run_metadata.json ===\n")
meta_json <- jsonlite::read_json(file.path(result$dir, "run_metadata.json"))
cat("  layer_b_algorithm:", meta_json$schema_versions$layer_b_algorithm, "\n")
cat("  stage4_algorithm: ", meta_json$schema_versions$stage4_algorithm, "\n")

cat("\nDONE. Output in:", normalizePath(result$dir), "\n")
cat("Per giudizio visuale apri:\n")
cat("  - ", file.path(result$dir, "cl_mega_1", "volcano.png"), "\n")
cat("  - ", file.path(result$dir, "cl_aug_1", "forest.png"), "\n")
cat("  - ", file.path(result$dir, "cl_mega_1", "heatmap.png"), "\n")
cat("  - ", file.path(result$dir, "cl_mega_1", "summary_card.png"), "\n")
