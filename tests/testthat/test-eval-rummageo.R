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
