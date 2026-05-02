test_that("read_samples_input legge il xlsx e ritorna tibble con colonne required", {
  testthat::skip_if_not_installed("readxl")
  path <- testthat::test_path("..", "..", "data-raw", "relevant_sample_classified.xlsx")
  testthat::skip_if(!fs::file_exists(path),
                    "data-raw/relevant_sample_classified.xlsx non disponibile")

  df <- read_samples_input(path, n_max = 50L)
  expect_s3_class(df, "tbl_df")
  expect_lte(nrow(df), 50L)
  expect_gte(nrow(df), 1L)
  for (col in c("geo_accession", "series_id", "string",
                "trtctr_EP", "trtctr", "treat", "gold")) {
    expect_true(col %in% names(df), info = paste("colonna mancante:", col))
  }
  expect_true(is.character(df$geo_accession))
  expect_true(is.character(df$string))
})

test_that("read_samples_input fallisce con errore tipizzato se il file non esiste", {
  expect_error(
    read_samples_input("/path/che/non/esiste.xlsx"),
    class = "simulomicsr_eval_sampling_missing_file"
  )
})
