test_that("h5_summary works", {
  skip_on_ci()
  skip_on_cran()
  skip_on_covr()
  skip_if(!any(
    c("h5DataPath", "h5_summary") %in%
      targets::tar_outdated(targets_only = FALSE)
  ), "Anything relevant for this test changed since last run.")

  # setup
  h5_samplepath <- targets::tar_read(h5DataPath)

  # eval
  res <- h5_summary(h5_samplepath)

  # test
  res |>
    expect_tibble(
      ncols = 6,
      types = c(rep("character", 4), rep("integerish", 2))
    )
})

test_that("h5_gene_names works", {
  skip_on_ci()
  skip_on_cran()
  skip_on_covr()
  skip_if(!any(
    c("h5DataPath", "h5_gene_names") %in%
      targets::tar_outdated(targets_only = FALSE)
  ), "Anything relevant for this test changed since last run.")

  # setup
  h5_sample_path <- targets::tar_read(h5DataPath)

  # eval
  res <- h5_gene_names(h5_sample_path)

  # test
  expect_character(res, min.len = 62548)
  expect_subset("A1BG", res)

})


test_that("h5_expression_data works", {
  skip_on_ci()
  skip_on_cran()
  skip_on_covr()
  skip_if(!any(
    c("h5DataPath", "h5_expression_data") %in%
      targets::tar_outdated(targets_only = FALSE)
  ), "Anything relevant for this test changed since last run.")

  # setup
  h5_samplepath <- targets::tar_read(h5DataPath)

  # eval
  res_default_50 <- h5_expression_data(h5_samplepath)
  res_100 <- h5_expression_data(h5_samplepath, 100)

  # test
  h5_expression_data(h5_samplepath, 1e9) |>
    expect_error("provide a lower")
  expect_tibble(res_default_50, nrows = 50, ncols = 62548)
  expect_tibble(res_100, nrows = 100, ncols = 62548)
})
