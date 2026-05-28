#!/usr/bin/env Rscript
# ============================================================================
# RED ALERT FASE F pre-flight, sessione 8 (2026-05-28).
# Step 3: verifica build_archs4_metadata_v2() su tutto H5 (run + schema).
# ============================================================================
# Obiettivo (NON build di produzione):
#   - build_archs4_metadata_v2 gira su 888.821 sample senza crash.
#   - schema output coerente con quello che F5 (Stadio 4) si aspetta come
#     h5_metadata: geo_accession, series_id, library_source, molecule_ch1,
#     instrument_model, data_processing, aligner_class (factor), relation,
#     biosample_id (SAMN), lib_size, singlecellprobability.
#   - n_kept == 509.033 (= F1 "included post-D1-D4", PRE-H2: questa funzione
#     NON applica H2 né resolver — vedi nota downstream RED_ALERT §F1).
#   - aligner_class distribution + biosample_id parsing sani.
#
# Output a path di VERIFICA (tempfile), NON il RDS di produzione: la
# decisione H2-consistency del metadata RDS è scope F5.

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

H5     <- "analysis/input/human_gene_v2.5.h5"
A3_TSV <- "analysis/audit/A3-libsize-scprob-bacino.tsv"
OUT    <- tempfile("preflight-step3-metadata-v2-", fileext = ".rds")
stopifnot(file.exists(H5), file.exists(A3_TSV))

# lib_size_vec allineato all'ordine H5 (come F1).
cat("== lib_size_vec da A3 TSV ==\n")
geo_order <- as.character(rhdf5::h5read(H5, "meta/samples/geo_accession"))
rhdf5::H5close()
lib_size_vec <- .build_libsize_vec(geo_order, A3_TSV)
cat(sprintf("  %d sample, %d non-NA\n", length(lib_size_vec), sum(!is.na(lib_size_vec))))

cat("\n== build_archs4_metadata_v2 (full H5) ==\n")
t0 <- Sys.time()
res <- build_archs4_metadata_v2(h5_path = H5, lib_size_vec = lib_size_vec,
                                out_rds_path = OUT)
cat(sprintf("  wall: %.1f min\n", as.numeric(Sys.time() - t0, units = "mins")))

cat("\n== conteggi ==\n")
cat(sprintf("  n_total:   %d\n", res$n_total))
cat(sprintf("  n_kept:    %d  (atteso 509.033 = F1 post-D1-D4 pre-H2)\n", res$n_kept))
cat(sprintf("  n_skipped: %d\n", res$n_skipped))
cat("  skip_reasons:\n"); print(res$skip_reasons)

cat("\n== schema RDS (colonne attese da F5) ==\n")
expected_cols <- c("geo_accession", "series_id", "library_source",
                   "molecule_ch1", "instrument_model", "data_processing",
                   "aligner_class", "relation", "biosample_id", "lib_size",
                   "singlecellprobability")
got_cols <- colnames(res$metadata)
cat("  colonne:", paste(got_cols, collapse = ", "), "\n")
missing_cols <- setdiff(expected_cols, got_cols)
cat(sprintf("  colonne mancanti vs F5: %d %s\n", length(missing_cols),
            if (length(missing_cols)) paste0("[", paste(missing_cols, collapse=","), "]") else ""))

cat("\n== tipi colonne chiave ==\n")
cat(sprintf("  aligner_class is factor: %s (livelli: %s)\n",
            is.factor(res$metadata$aligner_class),
            paste(levels(res$metadata$aligner_class), collapse = ", ")))
cat(sprintf("  lib_size is numeric: %s\n", is.numeric(res$metadata$lib_size)))
cat(sprintf("  biosample_id: %d non-NA / %d (%.1f%% coverage SAMN)\n",
            sum(!is.na(res$metadata$biosample_id)), nrow(res$metadata),
            100 * mean(!is.na(res$metadata$biosample_id))))

cat("\n== aligner_class distribution ==\n")
print(res$aligner_distribution)

cat("\n== sanity gate ==\n")
ok <- res$n_kept == 509033L &&
      length(missing_cols) == 0L &&
      is.factor(res$metadata$aligner_class) &&
      is.numeric(res$metadata$lib_size) &&
      sum(!is.na(res$metadata$biosample_id)) > 0L
cat(sprintf("  GATE: %s\n", if (ok) "PASS" else "FAIL"))
if (!ok) {
  cat("  FAIL: vedi conteggi/schema sopra. STOP investigation.\n")
  quit(status = 1L)
}
cat("OK: build_archs4_metadata_v2 gira full H5, schema F5-compatibile.\n")
cat(sprintf("  (RDS verifica scritto in %s, NON produzione)\n", OUT))
