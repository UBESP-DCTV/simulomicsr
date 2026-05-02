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

# ---------------------------------------------------------------------------
# Helper condiviso dai test parse_stage1_response e classify_sample
# ---------------------------------------------------------------------------
.fake_raw_v3 <- function() {
  jsonlite::fromJSON(
    readr::read_file(testthat::test_path("fixtures", "stage1-valid-vegf-huvec.json")),
    simplifyVector = FALSE
  )
}

# ---------------------------------------------------------------------------
# parse_stage1_response() — anti-allucinazione + enrichment deterministico
# ---------------------------------------------------------------------------
test_that("parse_stage1_response forza geo_accession e series_id da input (anti-allucinazione)", {
  raw <- .fake_raw_v3()
  raw$geo_accession <- "GSM_HALLUCINATED"  # LLM ha allucinato
  raw$series_id     <- "GSE_HALLUCINATED"

  out <- parse_stage1_response(
    raw,
    sample_string = "treatment: VEGF, cell line: HUVEC",
    geo_accession = "GSM1009635",
    series_id     = "GSE41166",
    model         = "gpt-5.5"
  )
  expect_equal(out$geo_accession, "GSM1009635")
  expect_equal(out$series_id,     "GSE41166")
})

test_that("parse_stage1_response calcola raw_input_hash deterministicamente", {
  raw <- .fake_raw_v3()
  s   <- "treatment: VEGF, cell line: HUVEC"
  out1 <- parse_stage1_response(raw, s, "GSM1", "GSE1", "gpt-5.5")
  out2 <- parse_stage1_response(raw, s, "GSM1", "GSE1", "gpt-5.5")
  expect_equal(out1$extraction$raw_input_hash, out2$extraction$raw_input_hash)
  expect_match(out1$extraction$raw_input_hash, "^sha256:[0-9a-f]{64}$")
})

test_that("parse_stage1_response setta extraction.model col valore richiesto", {
  raw <- .fake_raw_v3()
  out <- parse_stage1_response(raw, "x", "GSM1", "GSE1", model = "gpt-5.5")
  expect_equal(out$extraction$model, "openai:gpt-5.5")
})

test_that("parse_stage1_response setta schema_version a stage1.v3 anche se LLM lo lascia diverso", {
  raw <- .fake_raw_v3()
  raw$extraction$schema_version <- "wrong"
  out <- parse_stage1_response(raw, "x", "GSM1", "GSE1", "gpt-5.5")
  expect_equal(out$extraction$schema_version, "stage1.v3")
})

# ---------------------------------------------------------------------------
# classify_sample() — orchestratore principale Stadio 1
# ---------------------------------------------------------------------------
test_that("classify_sample con provider mock ritorna sample_fact valido contro lo schema", {
  schema <- system.file("schemas/sample_facts.stage1.v3.json", package = "simulomicsr")
  validator <- compile_schema(schema)

  fake <- .fake_raw_v3()
  fake_adapter <- function(model, messages, response_schema, ...) fake

  res <- classify_sample(
    sample_string = "treatment: VEGF, cell line: HUVEC, time: 0h",
    geo_accession = "GSM1009635",
    series_id     = "GSE41166",
    provider      = "mock",
    model         = "gpt-5.5",
    cache         = NULL,
    .mock_adapter = fake_adapter
  )

  expect_true(res$validated)
  expect_equal(res$value$geo_accession, "GSM1009635")
  expect_equal(res$value$extraction$model, "openai:gpt-5.5")
  v <- validate_json(res$value, validator = validator)
  expect_true(v$valid, info = paste(v$errors, collapse = " | "))
})

test_that("classify_sample sfrutta la cache: 2a chiamata = hit, adapter NON richiamato", {
  cache <- cache_init(new_cache_dir(), namespace = "stage1")
  fake  <- .fake_raw_v3()
  call_count <- 0L
  fake_adapter <- function(...) { call_count <<- call_count + 1L; fake }

  args <- list(
    sample_string = "treatment: VEGF, cell line: HUVEC, time: 0h",
    geo_accession = "GSM1009635",
    series_id     = "GSE41166",
    provider      = "mock",
    model         = "gpt-5.5",
    cache         = cache,
    .mock_adapter = fake_adapter
  )

  r1 <- do.call(classify_sample, args)
  expect_false(r1$cache_hit)
  expect_equal(call_count, 1L)

  r2 <- do.call(classify_sample, args)
  expect_true(r2$cache_hit)
  expect_equal(call_count, 1L)
})

test_that("classify_sample propaga simulomicsr_schema_error se LLM ritorna risposta non-conforme", {
  bad <- jsonlite::fromJSON(
    readr::read_file(testthat::test_path("fixtures", "stage1-invalid-bad-kind.json")),
    simplifyVector = FALSE
  )
  fake_adapter <- function(...) bad
  expect_error(
    classify_sample(
      sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
      provider = "mock", model = "gpt-5.5", cache = NULL,
      .mock_adapter = fake_adapter
    ),
    class = "simulomicsr_schema_error"
  )
})
