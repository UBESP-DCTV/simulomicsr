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

test_that("build_prompt_stage1 ritorna list di messages OpenAI-shape (system + user)", {
  msgs <- build_prompt_stage1(
    sample_string = "treatment: VEGF, time: 1h, cell line: HUVEC",
    geo_accession = "GSM1009636",
    series_id     = "GSE41166"
  )
  expect_type(msgs, "list")
  expect_length(msgs, 2L)
  expect_equal(msgs[[1]]$role, "system")
  expect_equal(msgs[[2]]$role, "user")
  expect_true(nchar(msgs[[1]]$content) > 1500L,
              info = "system prompt deve superare 1024 char per beneficiare di prompt caching")
})

test_that("build_prompt_stage1 inserisce geo_accession e series_id nello user message", {
  msgs <- build_prompt_stage1(
    sample_string = "siBCL6, OCI-LY1",
    geo_accession = "GSM999000",
    series_id     = "GSE777111"
  )
  user_content <- msgs[[2]]$content
  expect_match(user_content, "GSM999000", fixed = TRUE)
  expect_match(user_content, "GSE777111", fixed = TRUE)
  expect_match(user_content, "siBCL6, OCI-LY1", fixed = TRUE)
})

test_that("build_prompt_stage1 ricorda all'LLM di copiare verbatim geo_accession e series_id", {
  msgs <- build_prompt_stage1(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1"
  )
  sys_content <- msgs[[1]]$content
  expect_match(sys_content, "geo_accession", fixed = TRUE)
  expect_match(sys_content, "series_id", fixed = TRUE)
  expect_match(sys_content, "verbatim|copy|copia", ignore.case = TRUE)
})

test_that("build_prompt_stage1 cita gli enum di kind perturbation nel system prompt", {
  msgs <- build_prompt_stage1(sample_string = "x", geo_accession = "GSM1", series_id = "GSE1")
  sys <- msgs[[1]]$content
  for (k in c("small_molecule", "genetic_knockdown", "cytokine_stimulation",
              "differentiation", "none", "unclear")) {
    expect_match(sys, k, fixed = TRUE)
  }
})

test_that("build_prompt_stage1 con organism_hint non NULL lo passa allo user message", {
  msgs <- build_prompt_stage1(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
    organism_hint = "Homo sapiens"
  )
  expect_match(msgs[[2]]$content, "Homo sapiens", fixed = TRUE)
})
