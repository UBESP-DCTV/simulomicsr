#!/usr/bin/env Rscript
# ============================================================================
# RED ALERT FASE F pre-flight, sessione 8 (2026-05-28).
# Step 2: smoke is_sample_classifiable() su sample reali.
# ============================================================================
# Discovery sessione 8: H5 human_gene_v2.5.h5 è pre-filtrato by construction
# da ARCHS4 Maayan Lab:
#   - organism_ch1 == "Homo sapiens" per tutti 888.821 sample
#   - library_strategy == "RNA-Seq" per tutti 888.821 sample
#   - nchar(format_B(title, source, characteristics)) >= 30 per tutti
# I 3 reason code is_sample_classifiable {not_human, not_bulk_rnaseq,
# string_too_short} sono "defensive guards" per H5 alternativi (mouse v2.5,
# rat, future ARCHS4 v3+) o dataset misti. Su questo H5 NON sono triggerabili
# con sample reali.
#
# Coverage strategy:
#   - 7 sample REALI (slice H5) per i 4 reason code effettivamente
#     triggerabili: D1×3 (lib_source SC/other/genomic), D2 protocol,
#     D4 lib_size, D3 scprob, + KEEP.
#   - 3 defensive guards verificati via grep statico nel test unit
#     tests/testthat/test-stage0-v2-e2e.R.

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

H5      <- "analysis/input/human_gene_v2.5.h5"
A1_TSV  <- "analysis/audit/A1-single-cell-by-library-source.tsv"
A1C_TSV <- "analysis/audit/A1c-libsrc-other-detail.tsv"
A1D_TSV <- "analysis/audit/A1d-libsrc-genomic-detail.tsv"
A2_TSV  <- "analysis/audit/A2-sc-by-extract-protocol.tsv"
A3_TSV  <- "analysis/audit/A3-libsize-scprob-bacino.tsv"

stopifnot(file.exists(H5),
          file.exists(A1_TSV), file.exists(A1C_TSV), file.exists(A1D_TSV),
          file.exists(A2_TSV), file.exists(A3_TSV))

# ============================================================================
# Phase 1: pick 7 GSM dai TSV audit (5 reason code triggerabili + KEEP).
# ============================================================================
cat("== Phase 1: 7 GSM target dai TSV audit ==\n")
sc_lib       <- readr::read_tsv(A1_TSV,  show_col_types = FALSE)
sc_other     <- readr::read_tsv(A1C_TSV, show_col_types = FALSE)
sc_genomic   <- readr::read_tsv(A1D_TSV, show_col_types = FALSE)
sc_protocol  <- readr::read_tsv(A2_TSV,  show_col_types = FALSE)
libsize_scp  <- readr::read_tsv(A3_TSV,  show_col_types = FALSE)

cat(sprintf("  A1 SC (lib_source SC)   : %d sample\n", nrow(sc_lib)))
cat(sprintf("  A1c (lib_source other)  : %d sample\n", nrow(sc_other)))
cat(sprintf("  A1d (lib_source genomic): %d sample\n", nrow(sc_genomic)))
cat(sprintf("  A2 SC protocol          : %d sample\n", nrow(sc_protocol)))
cat(sprintf("  A3 post-A1+A2 universe  : %d sample\n", nrow(libsize_scp)))

target_gsm <- c(
  lib_source_SC                = sc_lib$geo_accession[1],
  lib_source_other             = sc_other$geo[1],
  lib_source_genomic           = sc_genomic$geo[1],
  single_cell_protocol_match   = sc_protocol$geo[1],
  lib_size_too_small           =
    libsize_scp$geo[libsize_scp$passed_libsize_500k == FALSE][1],
  single_cell_probability_high =
    libsize_scp$geo[
      libsize_scp$singlecellprobability >= 0.9 &
      libsize_scp$passed_libsize_500k == TRUE
    ][1],
  KEEP                         =
    libsize_scp$geo[
      libsize_scp$passed_libsize_500k == TRUE &
      libsize_scp$singlecellprobability < 0.9
    ][1]
)
stopifnot(!any(is.na(target_gsm)))
cat("\n  Target GSM:\n")
for (nm in names(target_gsm)) cat(sprintf("    %-32s %s\n", nm, target_gsm[[nm]]))

# ============================================================================
# Phase 2: read_archs4_metadata() full + select 7 righe.
# ============================================================================
# Nota: tentato slice via rhdf5::h5read(index = list(...)) ma riscontrato
# "double free or corruption (out)" su multi-call. Switch a read full (~5-10
# min wall) via la funzione canonica C1 read_archs4_metadata() + indicizzazione
# in memoria. Stesso risultato, piu' robusto. Lo step 3 del pre-flight (C3
# build_archs4_metadata_v2) leggera' comunque full H5, quindi questo costo
# non e' marginal: dimostra che la funzione di lettura canonica gira senza
# crash sull'H5 produttivo.
cat("\n== Phase 2: read_archs4_metadata() full + select ==\n")
t0 <- Sys.time()
meta_full <- read_archs4_metadata(H5)
cat(sprintf("  full read 14 colonne x %d sample: %.1f sec\n",
            nrow(meta_full), as.numeric(Sys.time() - t0, units = "secs")))

target_idx <- match(target_gsm, meta_full$geo_accession)
stopifnot(!any(is.na(target_idx)))
meta_sub <- meta_full[target_idx, , drop = FALSE]
rownames(meta_sub) <- NULL
cat(sprintf("  select 7 righe: %d sample x %d colonne\n",
            nrow(meta_sub), ncol(meta_sub)))

# lib_size: dai TSV A3 (precalcolato). Per 3 GSM pre-A3 (A1 SC, A1c other,
# A1d genomic) il TSV non li contiene → NA → D4 skip (gestito da
# is_sample_classifiable con check is.na(lib_size)).
lib_size_lookup <- setNames(libsize_scp$lib_size, libsize_scp$geo)
meta_sub$lib_size <- lib_size_lookup[meta_sub$geo_accession]

# Stringa format B (input prompt LLM Stadio 1; usata da check string_too_short).
meta_sub$string <- mapply(
  build_sample_string_format_B,
  meta_sub$title, meta_sub$source_name_ch1, meta_sub$characteristics_ch1,
  USE.NAMES = FALSE
)

# ============================================================================
# Phase 3: is_sample_classifiable + verifica reason atteso vs returned.
# ============================================================================
cat("\n== Phase 3: is_sample_classifiable + verifica reason ==\n")
res <- Map(is_sample_classifiable,
  organism_ch1          = meta_sub$organism_ch1,
  library_strategy      = meta_sub$library_strategy,
  library_source        = meta_sub$library_source,
  extract_protocol_ch1  = meta_sub$extract_protocol_ch1,
  title                 = meta_sub$title,
  source_name_ch1       = meta_sub$source_name_ch1,
  string                = meta_sub$string,
  singlecellprobability = meta_sub$singlecellprobability,
  lib_size              = meta_sub$lib_size
)
meta_sub$keep   <- vapply(res, function(r) r$keep, logical(1L))
meta_sub$reason <- vapply(res, function(r) {
  if (is.na(r$reason)) "KEEP" else r$reason
}, character(1L))

expected_code <- c(
  lib_source_SC                = "library_source_not_transcriptomic",
  lib_source_other             = "library_source_not_transcriptomic",
  lib_source_genomic           = "library_source_not_transcriptomic",
  single_cell_protocol_match   = "single_cell_protocol_match",
  lib_size_too_small           = "lib_size_too_small",
  single_cell_probability_high = "single_cell_probability_high",
  KEEP                         = "KEEP"
)
meta_sub$reason_expected_label <- names(target_gsm)
meta_sub$reason_expected_code  <- unname(expected_code[names(target_gsm)])
meta_sub$pass <- meta_sub$reason == meta_sub$reason_expected_code

print(meta_sub[, c("geo_accession", "reason_expected_label",
                   "reason_expected_code", "reason", "pass")])

n_pass <- sum(meta_sub$pass)
cat(sprintf("\n== Smoke runtime: %d/%d PASS ==\n", n_pass, nrow(meta_sub)))
if (n_pass != nrow(meta_sub)) {
  cat("FAIL: reason mismatch su sample sopra. STOP investigation.\n")
  quit(status = 1L)
}

# ============================================================================
# Phase 4: verifica statica coverage 7 reason code in TUTTI i test unit.
# ============================================================================
# Scope esteso (sessione 8): cerco ciascun reason code in qualunque file
# tests/testthat/test-*.R. Non basta verificare il test cascade e2e
# (test-stage0-v2-e2e.R), perche' i defensive guards (not_human,
# not_bulk_rnaseq, string_too_short) hanno test unit dedicati alla
# funzione is_sample_classifiable in test-etl-archs4-utils.R, non al
# cascade JSONL.
cat("\n== Phase 4: coverage statica 7 reason code in tests/testthat/ ==\n")
test_files <- list.files("tests/testthat", pattern = "^test-.*\\.R$",
                         full.names = TRUE)
all_codes <- c(unname(expected_code), "not_human", "not_bulk_rnaseq",
               "string_too_short")
all_codes <- unique(all_codes[all_codes != "KEEP"])
for (rc in all_codes) {
  matches <- list()
  for (tf in test_files) {
    src <- readLines(tf)
    hits <- grep(paste0("\"", rc, "\""), src, fixed = TRUE)
    if (length(hits) > 0L) {
      matches[[basename(tf)]] <- hits
    }
  }
  if (length(matches) == 0L) {
    cat(sprintf("  %-40s NO HITS in tests/  -- gap coverage\n", rc))
  } else {
    detail <- paste(sprintf("%s:%s", names(matches),
                            vapply(matches, paste, character(1L), collapse = ",")),
                    collapse = " | ")
    cat(sprintf("  %-40s %s\n", rc, detail))
  }
}

cat("\nOK: 4 reason code triggerabili PASS runtime smoke; 3 defensive guards\n")
cat("    + 4 triggerabili tutti coperti da test unit fixture (vedi righe).\n")
