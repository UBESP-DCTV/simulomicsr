test_that("h5_summary works", {
  # setup
  h5_samplepath <- ""

  # eval
  res <- h5_summary(h5_samplepath)

  # test
  expect_tibble(res)
})


test_that("h5_gene_names works", {
  # setup
  h5_samplepath <- ""

  # eval
  res <- h5_gene_names(h5_samplepath)

  # test
  expect_character(res, min.chars = 62548)
})


test_that("h5_expression_data works", {
  # setup
  h5_samplepath <- ""

  # eval
  res <- h5_expression_data(h5_samplepath)

  # test
  expect_tibble(res)
})
