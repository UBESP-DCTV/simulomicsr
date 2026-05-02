test_that("fetch_rummageo_signatures: cache hit non chiama API", {
  cache_dir <- withr::local_tempdir()
  fixture_path <- testthat::test_path("fixtures/rummageo-mock-GSE145941.json")
  fs::file_copy(fixture_path, fs::path(cache_dir, "GSE145941.json"))

  # Mock httr2 fail-loud — non deve essere chiamato se cache e' calda
  testthat::local_mocked_bindings(
    request = function(...) stop("should not be called when cache hit"),
    .package = "httr2"
  )
  out <- fetch_rummageo_signatures("GSE145941", cache_dir = cache_dir)
  expect_equal(out$gse, "GSE145941")
  expect_true(length(out$sampleGroups$samples) >= 1L)
})

test_that("parse_rummageo_labels: estrae control/treated per GSM", {
  data <- jsonlite::read_json(
    testthat::test_path("fixtures/rummageo-mock-GSE145941.json"),
    simplifyVector = FALSE
  )
  labels <- parse_rummageo_labels(data)
  expect_true(tibble::is_tibble(labels))
  expect_setequal(colnames(labels), c("geo_accession", "rummageo_label"))
  # gruppo 1 = treated (indice "1"), gruppo 2 = control (indice "2")
  expect_setequal(labels$rummageo_label, c("treated", "control"))
  # tutti e 8 i GSM sono presenti
  expect_equal(nrow(labels), 8L)
})

test_that("fetch_rummageo_signatures errors on input invalido", {
  expect_error(
    fetch_rummageo_signatures("not-a-gse"),
    class = "simulomicsr_invalid_series_id"
  )
})

test_that("rummageo_baseline_internal: 2-cluster split su metadati semplici", {
  samples <- tibble::tibble(
    geo_accession = paste0("GSM", 1:6),
    series_id = rep("GSE1", 6),
    string = c(
      "treatment: DMSO",
      "treatment: DMSO",
      "treatment: DMSO",
      "treatment: drug X 10nM",
      "treatment: drug X 10nM",
      "treatment: drug X 10nM"
    )
  )
  out <- rummageo_baseline_internal(samples)
  expect_true(tibble::is_tibble(out))
  expect_setequal(colnames(out), c("geo_accession", "rummageo_label"))
  dmso_labels <- out$rummageo_label[out$geo_accession %in% paste0("GSM", 1:3)]
  expect_true(all(dmso_labels == "control"))
  drug_labels <- out$rummageo_label[out$geo_accession %in% paste0("GSM", 4:6)]
  expect_true(all(drug_labels == "treated"))
})

test_that("rummageo_baseline_internal: keyword 'control' in metadata", {
  samples <- tibble::tibble(
    geo_accession = paste0("GSM", 1:4),
    series_id = rep("GSE1", 4),
    string = c(
      "treatment: control siRNA",
      "treatment: control siRNA",
      "treatment: shGAPDH",
      "treatment: shKRAS"
    )
  )
  out <- rummageo_baseline_internal(samples)
  expect_equal(out$rummageo_label[1:2], rep("control", 2))
  expect_true(all(out$rummageo_label[3:4] == "treated"))
})
