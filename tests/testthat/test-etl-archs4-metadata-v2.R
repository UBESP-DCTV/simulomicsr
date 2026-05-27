# ============================================================================
# build_archs4_metadata_v2() — P5 audit RED_ALERT C3 (ADR-0019)
# ============================================================================
# Fixture: tests/testthat/fixtures/archs4-mini.h5 (4 sample, schema v2 14 campi).
# Expected post-filtro Stage 0 v2:
#   - GSM001 keep (Homo, RNA-Seq, transcriptomic, TRIzol/STAR, scprob 0.02)
#   - GSM002 keep (Homo, RNA-Seq, transcriptomic, RNeasy/HISAT2, scprob 0.04)
#   - GSM003 drop not_human (Mus musculus)
#   - GSM004 drop not_bulk_rnaseq (scRNA-Seq) - prima fail su library_strategy

test_that("build_archs4_metadata_v2 - struttura output + n_kept attesi", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  # lib_size mock: tutti > 500k per non droppare nessun sample per D4.
  res <- build_archs4_metadata_v2(fix, lib_size_vec = c(1e7, 1e7, 1e7, 1e7))

  expect_type(res, "list")
  expect_named(res, c("metadata", "n_total", "n_kept", "n_skipped",
                       "skip_reasons", "aligner_distribution"),
               ignore.order = TRUE)
  expect_equal(res$n_total, 4L)
  expect_equal(res$n_kept, 2L)
  expect_equal(res$n_skipped, 2L)
})

test_that("build_archs4_metadata_v2 - data.frame metadata ha le colonne v2", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  res <- build_archs4_metadata_v2(fix, lib_size_vec = c(1e7, 1e7, 1e7, 1e7))

  expect_s3_class(res$metadata, "data.frame")
  expect_named(res$metadata,
               c("geo_accession", "series_id", "library_source", "molecule_ch1",
                 "instrument_model", "data_processing", "aligner_class",
                 "relation", "biosample_id", "lib_size", "singlecellprobability"),
               ignore.order = TRUE)
})

test_that("build_archs4_metadata_v2 - aligner_class parsed da data_processing", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  res <- build_archs4_metadata_v2(fix, lib_size_vec = c(1e7, 1e7, 1e7, 1e7))

  # Fixture: GSM001 data_processing = "STAR_2.7.10a ...", GSM002 = "HISAT2 ..."
  meta <- res$metadata
  expect_s3_class(meta$aligner_class, "factor")
  expect_equal(as.character(meta$aligner_class[meta$geo_accession == "GSM001"]), "STAR")
  expect_equal(as.character(meta$aligner_class[meta$geo_accession == "GSM002"]), "HISAT")
})

test_that("build_archs4_metadata_v2 - biosample_id parsed da relation", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  res <- build_archs4_metadata_v2(fix, lib_size_vec = c(1e7, 1e7, 1e7, 1e7))

  meta <- res$metadata
  # Fixture: GSM001 relation = "BioSample: https://.../SAMN12340001"
  expect_equal(meta$biosample_id[meta$geo_accession == "GSM001"], "SAMN12340001")
  expect_equal(meta$biosample_id[meta$geo_accession == "GSM002"], "SAMN12340002")
})

test_that("build_archs4_metadata_v2 - skip_reasons tabella corretta", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  res <- build_archs4_metadata_v2(fix, lib_size_vec = c(1e7, 1e7, 1e7, 1e7))

  # GSM003 mouse -> not_human; GSM004 scRNA-Seq -> not_bulk_rnaseq.
  reasons <- as.list(res$skip_reasons)
  expect_equal(reasons[["not_human"]], 1L)
  expect_equal(reasons[["not_bulk_rnaseq"]], 1L)
})

test_that("build_archs4_metadata_v2 - D4 scatta se lib_size_vec < 500k", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  # GSM001 con lib_size = 1000 (sotto soglia 500k) deve essere droppato D4.
  res <- build_archs4_metadata_v2(fix, lib_size_vec = c(1000L, 1e7, 1e7, 1e7))

  expect_equal(res$n_kept, 1L)
  expect_equal(res$n_skipped, 3L)
  reasons <- as.list(res$skip_reasons)
  expect_equal(reasons[["lib_size_too_small"]], 1L)
})

test_that("build_archs4_metadata_v2 - lib_size_vec NULL salta check D4", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  # Default lib_size_vec=NULL: D4 saltato -> n_kept = 2 come baseline.
  res <- build_archs4_metadata_v2(fix)
  expect_equal(res$n_kept, 2L)
  # Tutti i lib_size nel metadata sono NA.
  expect_true(all(is.na(res$metadata$lib_size)))
})

test_that("build_archs4_metadata_v2 - lib_size_vec lunghezza sbagliata -> errore", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  expect_error(
    build_archs4_metadata_v2(fix, lib_size_vec = c(1e7, 1e7)),
    "length"
  )
})

test_that("build_archs4_metadata_v2 - salva RDS quando out_rds_path passato", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))
  res <- build_archs4_metadata_v2(fix, lib_size_vec = c(1e7, 1e7, 1e7, 1e7),
                                    out_rds_path = tmp)
  expect_true(file.exists(tmp))
  reloaded <- readRDS(tmp)
  expect_s3_class(reloaded, "data.frame")
  expect_equal(nrow(reloaded), 2L)
  expect_equal(reloaded$geo_accession, c("GSM001", "GSM002"))
})
