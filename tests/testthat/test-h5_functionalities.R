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
  h5_samplepath <- ""

  # eval
  res <- h5_gene_names(h5_samplepath)

  # test
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
