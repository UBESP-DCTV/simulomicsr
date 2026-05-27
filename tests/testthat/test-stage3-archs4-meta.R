test_that("load_archs4_metadata legge gpl + series_id + biosample_id da H5 (mock)", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("withr")

  # H5 mock: file temporaneo con dataset sintetici
  tmp_h5 <- withr::local_tempfile(fileext = ".h5")
  rhdf5::h5createFile(tmp_h5)
  rhdf5::h5createGroup(tmp_h5, "meta")
  rhdf5::h5createGroup(tmp_h5, "meta/samples")

  rhdf5::h5write(c("GSM1", "GSM2", "GSM3"), tmp_h5, "meta/samples/geo_accession")
  rhdf5::h5write(c("GSE100", "GSE100", "GSE200"), tmp_h5, "meta/samples/series_id")
  rhdf5::h5write(c("GPL16791", "GPL16791", "GPL11154"), tmp_h5, "meta/samples/platform_id")
  # FASE E0 ADR-0019 D9: relation campo per parse_biosample_id
  rhdf5::h5write(c(
    "Reanalyzed by: GSE123, BioSample: https://www.ncbi.nlm.nih.gov/biosample/SAMN12345678",
    "Reanalyzed by: GSE456, BioSample: https://www.ncbi.nlm.nih.gov/biosample/SAMN12345678",  # stesso SAMN cross-GSE
    ""  # no relation -> NA
  ), tmp_h5, "meta/samples/relation")

  meta <- load_archs4_metadata(h5_path = tmp_h5, use_cache = FALSE)

  expect_s3_class(meta, "tbl_df")
  expect_named(meta, c("sample_id", "series_id", "gpl", "biosample_id"),
               ignore.order = TRUE)
  expect_equal(nrow(meta), 3L)
  expect_equal(meta$sample_id, c("GSM1", "GSM2", "GSM3"))
  expect_equal(meta$series_id, c("GSE100", "GSE100", "GSE200"))
  expect_equal(meta$gpl, c("GPL16791", "GPL16791", "GPL11154"))
  expect_equal(meta$biosample_id,
               c("SAMN12345678", "SAMN12345678", NA_character_))
})

test_that("load_archs4_metadata usa cache alla seconda chiamata", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("withr")

  tmp_h5 <- withr::local_tempfile(fileext = ".h5")
  rhdf5::h5createFile(tmp_h5)
  rhdf5::h5createGroup(tmp_h5, "meta")
  rhdf5::h5createGroup(tmp_h5, "meta/samples")
  rhdf5::h5write(c("GSM1"), tmp_h5, "meta/samples/geo_accession")
  rhdf5::h5write(c("GSE100"), tmp_h5, "meta/samples/series_id")
  rhdf5::h5write(c("GPL16791"), tmp_h5, "meta/samples/platform_id")
  rhdf5::h5write(c("BioSample: https://www.ncbi.nlm.nih.gov/biosample/SAMN1"),
                 tmp_h5, "meta/samples/relation")

  tmp_cache_dir <- withr::local_tempdir()

  m1 <- load_archs4_metadata(h5_path = tmp_h5, cache_dir = tmp_cache_dir,
                              use_cache = TRUE)
  m2 <- load_archs4_metadata(h5_path = tmp_h5, cache_dir = tmp_cache_dir,
                              use_cache = TRUE)
  expect_identical(m1, m2)

  cache_files <- list.files(tmp_cache_dir, pattern = "archs4-metadata")
  expect_true(length(cache_files) >= 1L)
})

test_that("load_archs4_metadata restituisce tibble con colonne corrette per dati reali (smoke)", {
  skip_if_not_installed("rhdf5")
  h5_path <- "analysis/input/human_gene_v2.5.h5"
  skip_if(!file.exists(h5_path), "H5 ARCHS4 non disponibile")

  meta <- load_archs4_metadata(h5_path = h5_path, use_cache = TRUE)

  expect_s3_class(meta, "tbl_df")
  expect_named(meta, c("sample_id", "series_id", "gpl", "biosample_id"),
               ignore.order = TRUE)
  expect_true(nrow(meta) > 800000L)
  # I valori gpl devono iniziare con "GPL" oppure essere stringa vuota
  non_empty_gpl <- meta$gpl[nzchar(meta$gpl)]
  expect_true(all(startsWith(non_empty_gpl, "GPL")))
  # Coverage SAMN attesa ~99.98% (vedi A7-synthesis-biosample-dedupe.md)
  samn_present <- !is.na(meta$biosample_id)
  expect_gt(mean(samn_present), 0.99)
})

test_that("load_archs4_metadata: H5 senza dataset relation -> biosample_id tutto NA", {
  # Edge case: H5 ARCHS4 ipotetico legacy senza il campo relation.
  # Atteso fallback graceful: colonna biosample_id presente ma tutta NA,
  # nessun errore.
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("withr")

  tmp_h5 <- withr::local_tempfile(fileext = ".h5")
  rhdf5::h5createFile(tmp_h5)
  rhdf5::h5createGroup(tmp_h5, "meta")
  rhdf5::h5createGroup(tmp_h5, "meta/samples")
  rhdf5::h5write(c("GSM1", "GSM2"), tmp_h5, "meta/samples/geo_accession")
  rhdf5::h5write(c("GSE1", "GSE1"), tmp_h5, "meta/samples/series_id")
  rhdf5::h5write(c("GPL1", "GPL1"), tmp_h5, "meta/samples/platform_id")
  # nessun meta/samples/relation

  meta <- load_archs4_metadata(h5_path = tmp_h5, use_cache = FALSE)
  expect_true("biosample_id" %in% names(meta))
  expect_true(all(is.na(meta$biosample_id)))
})
