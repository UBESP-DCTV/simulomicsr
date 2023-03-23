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

test_that("trt2casecontrol works", {
  # setup
  ctr <- "none"
  ctr_upper <- "None"
  none <- "foo"
  none_upper <- "Foo"
  all <- c(ctr, none)
  zero <- "0 mg/ml"
  ten <- "10 mg/ml"

  # eval
  res_ctr <- trt2casecontrol(ctr)
  res_ctr_upper <- trt2casecontrol(ctr_upper)
  res_none <- trt2casecontrol(none)
  res_none_upper <- trt2casecontrol(none_upper)
  res_all <- trt2casecontrol(all)
  res_zero <- trt2casecontrol(zero)
  res_ten <- trt2casecontrol(ten)

  # test
  expect_equal(res_ctr, "control")
  expect_equal(res_ctr_upper, "control")
  expect_equal(res_none, "foo")
  expect_equal(res_none_upper, "Foo")
  expect_equal(res_all, c("control", "foo"))
  expect_equal(res_zero, "control")
  expect_equal(res_ten, "treated")
})
