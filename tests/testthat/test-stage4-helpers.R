test_that(".run_id_for_stage4 e' deterministico per stessi input", {
  hashes <- list(stage3 = "abc123", h5 = "def456")
  cfg <- stage4_default_config()
  schema <- cfg$schema_versions

  id1 <- .run_id_for_stage4(hashes, cfg, schema)
  id2 <- .run_id_for_stage4(hashes, cfg, schema)

  expect_identical(id1, id2)
  expect_true(nchar(id1) == 8L)
  expect_true(grepl("^[0-9a-f]{8}$", id1))
})

test_that(".run_id_for_stage4 cambia con config diverse", {
  hashes <- list(stage3 = "abc123", h5 = "def456")
  cfg1 <- stage4_default_config()
  cfg2 <- cfg1; cfg2$qc$lib_size_min <- 1000000L

  id1 <- .run_id_for_stage4(hashes, cfg1, cfg1$schema_versions)
  id2 <- .run_id_for_stage4(hashes, cfg2, cfg2$schema_versions)

  expect_false(identical(id1, id2))
})

test_that(".compute_input_hashes restituisce list con stage3 e h5", {
  # Fixture: stage3 dir mock + h5 file mock
  tmp_stage3 <- withr::local_tempdir()
  tmp_h5     <- withr::local_tempfile(fileext = ".h5")
  saveRDS(list(run_id = "mock1234"), file.path(tmp_stage3, "run_metadata.rds"))
  writeBin(as.raw(c(0x89, 0x48, 0x44, 0x46)), tmp_h5)  # bytes mock

  hashes <- .compute_input_hashes(tmp_stage3, tmp_h5)

  expect_named(hashes, c("stage3", "h5"))
  expect_true(nchar(hashes$stage3) >= 8L)
  expect_true(nchar(hashes$h5) >= 8L)
})
