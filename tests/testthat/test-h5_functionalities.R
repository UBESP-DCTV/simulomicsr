test_that("h5_summary works", {
  skip_on_ci()
  skip_on_cran()

  # setup
  h5_samplepath <- ""

  # eval
  res <- h5_summary(h5_samplepath)

  # test
  expect_tibble(res)
})


test_that("h5_gene_names works", {
  skip_on_ci()
  skip_on_cran()

  # setup
  h5_sample_test_path <- targets::tar_read(h5TestPath)
  h5_sample_path <- targets::tar_read(h5DataPath)

  # eval
  res_test <- h5_gene_names(h5_sample_test_path)
  res <- h5_gene_names(h5_sample_path)

  # test
  expect_error(res_test, "HDF5. File accessibility")
  expect_character(res, min.chars = 62548)

})


test_that("h5_expression_data works", {
  skip_on_ci()
  skip_on_cran()

  # setup
  h5_samplepath <- ""

  # eval
  res <- h5_expression_data(h5_samplepath)

  # test
  expect_tibble(res)
})
