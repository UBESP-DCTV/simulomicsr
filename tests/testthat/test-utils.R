test_that("extract_fct_names works", {
  # setup
  funs <- "
  a <- function() {}
  b <- 2
  c<- function() {}
  d <-function() {}
  `%||%` <- function() {}
  "
  withr::local_file("funs.R")
  fs::file_exists("funs.R")
  readr::write_lines(funs, "funs.R")
  readr::read_lines("funs.R")
  # execution
  res <- extract_fct_names("funs.R")

  # expectation
  expect_equal(res, c("a", "c", "d", "%||%"))
})


test_that("extract_treatment works", {
  # setup
  first <- "treatment: siNT,cell line: OCI-LY1"
  last <- "cell type: NTera2/D1,treatment: none"
  spaces <-
    "cell line: MDA-MB-231,treatment: CXCL12 (0ng/mL) + IGF1 (0ng/mL)"

  # eval
  res_first <- extract_treatment(first)
  res_last <- extract_treatment(last)
  res_spaces <- extract_treatment(spaces)

  # test
  expect_equal(res_first, "siNT")
  expect_equal(res_last, "none")
  expect_equal(res_spaces, "CXCL12 (0ng/mL) + IGF1 (0ng/mL)")
})
