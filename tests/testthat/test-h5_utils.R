test_that("dim_string_to_int works", {
  # setup
  input <- tibble::tribble(
    ~var, ~dim,
    1, "620825 x 62548",
    2, "62548",
    3, "620825",
    4, NA_character_
  )

  expected <- tibble::tribble(
    ~var, ~n_datasets, ~n_genes,
     1, 620825L, 62548L,
     2, NA_integer_,  62548L,
     3, 620825L, NA_integer_,
     4, NA_integer_, NA_integer_
  )

  # eval
  res <- input |> separate_h5_summary_dims()

  # test
  expect_equal(res, expected)
})
