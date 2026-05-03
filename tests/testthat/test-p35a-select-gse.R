test_that("load_rummageo_index parsa cassetta mock con SuperSeries", {
  fixture_path <- testthat::test_path("fixtures", "rummageo-index-mock.json")
  result <- .parse_rummageo_index_response(
    jsonlite::read_json(fixture_path, simplifyVector = FALSE)
  )
  expect_s3_class(result, "tbl_df")
  expect_setequal(result$gse,
                  c("GSE100001", "GSE100002", "GSE100003", "GSE100004"))
  expect_equal(nrow(result), 4L)
  expect_equal(result$n_signatures[result$gse == "GSE100002"], 3L)
})

test_that("load_rummageo_index usa cache se presente", {
  tmp_dir <- withr::local_tempdir()
  fixture_path <- testthat::test_path("fixtures", "rummageo-index-mock.json")
  fixture_data <- jsonlite::read_json(fixture_path, simplifyVector = FALSE)
  parsed <- .parse_rummageo_index_response(fixture_data)
  jsonlite::write_json(parsed, file.path(tmp_dir, "rummageo-index.json"),
                       auto_unbox = TRUE)
  result <- load_rummageo_index(cache_dir = tmp_dir, api_base = "http://localhost:0")
  expect_equal(nrow(result), 4L)
})
