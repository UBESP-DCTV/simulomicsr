test_that("read_sample_fixtures_mini ritorna tibble con 8 sample stratificati", {
  df <- read_sample_fixtures_mini()
  expect_s3_class(df, "tbl_df")
  expect_equal(nrow(df), 8L)
  expect_setequal(
    df$stratum,
    c("easy_treated", "easy_control",
      "disagree_ep_vs_shallow", "short_ambiguous")
  )
  expect_setequal(
    names(df),
    c("geo_accession", "series_id", "string",
      "trtctr_EP", "trtctr", "treat", "gold", "stratum")
  )
  expect_true(all(nzchar(df$geo_accession)))
  expect_true(all(nzchar(df$string)))
})
