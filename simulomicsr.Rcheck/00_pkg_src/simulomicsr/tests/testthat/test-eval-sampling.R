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

test_that("build_dev_set produce 100 sample stratificati 60/30/10 con seed deterministico", {
  set.seed(NULL)
  df <- tibble::tibble(
    geo_accession = sprintf("GSM%05d", 1:5000),
    series_id     = sprintf("GSE%04d", rep(1:500, each = 10)),
    string        = c(
      rep("treatment: drugA, time: 24h", 3000),
      rep("treatment: drugB, time: 24h", 1500),
      rep("ctrl",                          500)  # short/ambigui (nchar <= 60)
    ),
    trtctr_EP = c(rep("treated", 3000), rep("control", 1500), rep("treated", 500)),
    trtctr    = c(rep("treated", 2500), rep("control", 1000),
                  rep("treated", 1000), rep("control",  500)),
    treat = NA_character_, gold = NA_character_
  )

  out1 <- build_dev_set(df, n = 100, seed = 1812)
  out2 <- build_dev_set(df, n = 100, seed = 1812)

  expect_equal(nrow(out1), 100L)
  expect_equal(out1$geo_accession, out2$geo_accession)  # deterministico
  expect_setequal(out1$stratum,
                  c("easy_agree", "disagree_ep_vs_shallow", "short_ambiguous"))

  counts <- table(out1$stratum)
  expect_equal(unname(counts["easy_agree"]),              60L)
  expect_equal(unname(counts["disagree_ep_vs_shallow"]),  30L)
  expect_equal(unname(counts["short_ambiguous"]),         10L)
})

test_that("build_dev_set seed diversi producono dev set diversi", {
  df <- tibble::tibble(
    geo_accession = sprintf("GSM%05d", 1:2000),
    series_id     = sprintf("GSE%04d", rep(1:200, each = 10)),
    string        = rep("treatment: x, time: 6h", 2000),
    trtctr_EP = rep(c("treated", "control"), each = 1000),
    trtctr    = rep(c("treated", "control"), times = 1000),
    treat = NA_character_, gold = NA_character_
  )
  a <- build_dev_set(df, n = 50, seed = 1)
  b <- build_dev_set(df, n = 50, seed = 2)
  expect_false(identical(a$geo_accession, b$geo_accession))
})
