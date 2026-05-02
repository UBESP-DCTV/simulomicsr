test_that("fetch_study_summary ritorna shape attesa", {
  skip_if_not_installed("rentrez")
  # Mock rentrez per evitare network in unit test
  mock_summary <- list(
    uids = "200041166",
    `200041166` = list(
      title = "VEGF stimulation time course in HUVEC",
      summary = "Primary HUVEC stimulated with VEGF; t=0,1,6,24h; n=3 per group.",
      gpl = "GPL11154",
      bioproject_id = "PRJNA168145",
      gse = "41166",
      n_samples = "12"
    )
  )
  withr::local_envvar(SIMULOMICSR_GEO_FETCH_TEST_OFFLINE = "1")
  local_mocked_bindings(
    entrez_search = function(db, term, ...) list(ids = "200041166"),
    entrez_summary = function(db, id, ...) mock_summary,
    .package = "rentrez"
  )
  out <- fetch_study_summary("GSE41166")
  expect_named(out, c("series_id", "title", "summary", "overall_design"))
  expect_equal(out$series_id, "GSE41166")
  expect_match(out$title, "VEGF")
  expect_match(out$summary, "HUVEC")
  expect_true(is.na(out$overall_design) || is.character(out$overall_design))
})

test_that("fetch_study_summary cache hit non chiama rentrez", {
  skip_if_not_installed("rentrez")
  cache_dir <- withr::local_tempdir()
  cached <- list(
    series_id = "GSE41166",
    title = "Cached title",
    summary = "Cached summary",
    overall_design = NA_character_
  )
  jsonlite::write_json(
    cached,
    fs::path(cache_dir, "GSE41166.json"),
    auto_unbox = TRUE,
    null = "null"
  )
  # Mock fail-loud: se il codice tenta entrez_search/entrez_summary, fallisce
  local_mocked_bindings(
    entrez_search = function(...) stop("should not be called"),
    entrez_summary = function(...) stop("should not be called"),
    .package = "rentrez"
  )
  out <- fetch_study_summary("GSE41166", cache_dir = cache_dir)
  expect_equal(out$title, "Cached title")
})

test_that("fetch_study_summary cache miss scrive su disco", {
  skip_if_not_installed("rentrez")
  cache_dir <- withr::local_tempdir()
  mock_summary <- list(
    uids = "200041166",
    `200041166` = list(
      title = "Fresh fetch",
      summary = "From rentrez",
      gpl = "GPL11154",
      bioproject_id = "PRJNA168145",
      gse = "41166",
      n_samples = "12"
    )
  )
  local_mocked_bindings(
    entrez_search = function(db, term, ...) list(ids = "200041166"),
    entrez_summary = function(db, id, ...) mock_summary,
    .package = "rentrez"
  )
  out <- fetch_study_summary("GSE41166", cache_dir = cache_dir)
  cached_path <- fs::path(cache_dir, "GSE41166.json")
  expect_true(fs::file_exists(cached_path))
  reread <- jsonlite::read_json(cached_path)
  expect_equal(reread$title, "Fresh fetch")
})

test_that("fetch_study_summary errors on input invalido", {
  expect_error(
    fetch_study_summary("not-a-gse"),
    class = "simulomicsr_invalid_series_id"
  )
})
