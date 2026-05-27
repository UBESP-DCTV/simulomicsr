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

test_that("classify_sample_row accetta una riga tibble e ritorna sample_fact valido", {
  fake <- .fake_raw_v3()
  fake_adapter <- function(...) fake

  row <- tibble::tibble(
    geo_accession = "GSM1009635",
    series_id     = "GSE41166",
    string        = "treatment: VEGF, cell line: HUVEC, time: 0h",
    trtctr_EP     = "control",
    trtctr        = "control",
    treat         = NA_character_,
    gold          = NA_character_,
    stratum       = "easy_agree"
  )

  fact <- classify_sample_row(
    row,
    provider = "mock", model = "gpt-5.5", cache = NULL,
    .mock_adapter = fake_adapter
  )

  expect_type(fact, "list")
  expect_equal(fact$geo_accession, "GSM1009635")
  expect_equal(fact$extraction$schema_version, "stage1.v3")
})

# ---------------------------------------------------------------------------
# P5 audit RED_ALERT D1b — molecule_hint nel prompt Stadio 1
# Spec: ADR-0019 D5 + analysis/audit/D1a-prompt-stage1-current.txt
# Gate utente D1a APPROVATO 2026-05-27: strada cauta (system + user message)
# + naming molecule_hint + valore verbatim + posizione dopo organism_hint.
# ---------------------------------------------------------------------------

test_that("build_prompt_stage1 con molecule_hint non NULL lo inietta nello user message", {
  msgs <- build_prompt_stage1(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
    molecule_hint = "polyA RNA"
  )
  expect_match(msgs[[2]]$content, "molecule_hint: polyA RNA", fixed = TRUE)
})

test_that("build_prompt_stage1 con molecule_hint NULL NON inietta riga molecule_hint", {
  msgs <- build_prompt_stage1(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
    molecule_hint = NULL
  )
  expect_false(grepl("molecule_hint:", msgs[[2]]$content, fixed = TRUE))
})

test_that("build_prompt_stage1 con molecule_hint NA NON inietta riga molecule_hint", {
  msgs <- build_prompt_stage1(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
    molecule_hint = NA_character_
  )
  expect_false(grepl("molecule_hint:", msgs[[2]]$content, fixed = TRUE))
})

test_that("build_prompt_stage1 con molecule_hint '' (empty string) NON inietta riga", {
  msgs <- build_prompt_stage1(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
    molecule_hint = ""
  )
  expect_false(grepl("molecule_hint:", msgs[[2]]$content, fixed = TRUE))
})

test_that("build_prompt_stage1 posiziona molecule_hint dopo organism_hint e prima di sample_string", {
  msgs <- build_prompt_stage1(
    sample_string = "free text body",
    geo_accession = "GSM1", series_id = "GSE1",
    organism_hint = "Homo sapiens",
    molecule_hint = "total RNA"
  )
  user <- msgs[[2]]$content
  pos_org <- regexpr("organism_hint:", user, fixed = TRUE)
  pos_mol <- regexpr("molecule_hint:", user, fixed = TRUE)
  pos_str <- regexpr("sample_string:", user, fixed = TRUE)
  expect_gt(pos_mol, pos_org)
  expect_gt(pos_str, pos_mol)
})

test_that(".stage1_system_prompt cita molecule_hint come metadata di library-prep non-perturbazione", {
  sys_prompt <- simulomicsr:::.stage1_system_prompt()
  # Frase corta approvata D1a: identifica la natura library-prep e l'anti-pattern
  # da evitare (encoding sotto perturbations / technical_treatments).
  expect_match(sys_prompt, "molecule_hint", fixed = TRUE)
  expect_match(sys_prompt, "RNA fraction", fixed = TRUE)
  expect_match(sys_prompt, "not a perturbation", fixed = TRUE)
})

test_that("classify_sample inoltra molecule_hint a build_prompt_stage1", {
  captured <- NULL
  fake <- .fake_raw_v3()
  fake_adapter <- function(model, messages, response_schema, ...) {
    captured <<- messages
    fake
  }

  classify_sample(
    sample_string = "x", geo_accession = "GSM1", series_id = "GSE1",
    provider = "mock", model = "gpt-5.5", cache = NULL,
    molecule_hint = "nuclear RNA",
    .mock_adapter = fake_adapter
  )
  expect_match(captured[[2]]$content, "molecule_hint: nuclear RNA", fixed = TRUE)
})

test_that("classify_sample_row legge row$molecule_ch1 e lo passa come molecule_hint", {
  captured <- NULL
  fake <- .fake_raw_v3()
  fake_adapter <- function(model, messages, response_schema, ...) {
    captured <<- messages
    fake
  }

  row <- tibble::tibble(
    geo_accession = "GSM1",
    series_id     = "GSE1",
    string        = "treatment: VEGF, time: 1h, cell line: HUVEC",
    molecule_ch1  = "polyA RNA"
  )

  classify_sample_row(
    row,
    provider = "mock", model = "gpt-5.5", cache = NULL,
    .mock_adapter = fake_adapter
  )
  expect_match(captured[[2]]$content, "molecule_hint: polyA RNA", fixed = TRUE)
})

test_that("classify_sample_row con row senza molecule_ch1 NON aggiunge riga molecule_hint", {
  captured <- NULL
  fake <- .fake_raw_v3()
  fake_adapter <- function(model, messages, response_schema, ...) {
    captured <<- messages
    fake
  }

  # Row senza colonna molecule_ch1 (es. samples_dev_set legacy P2 alpha).
  row <- tibble::tibble(
    geo_accession = "GSM1",
    series_id     = "GSE1",
    string        = "treatment: VEGF, time: 1h, cell line: HUVEC"
  )

  classify_sample_row(
    row,
    provider = "mock", model = "gpt-5.5", cache = NULL,
    .mock_adapter = fake_adapter
  )
  expect_false(grepl("molecule_hint:", captured[[2]]$content, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# P5 audit RED_ALERT D2 — end-to-end cascade JSONL -> classify_sample_row
# Verifica che il campo molecule_ch1 emesso da archs4_to_stage1_jsonl (C4)
# arrivi davvero al prompt LLM passando per il round-trip JSON.
# ---------------------------------------------------------------------------

test_that("E2E D2: JSONL post-C4 con molecule_ch1 valore -> molecule_hint nel prompt", {
  captured <- NULL
  fake <- .fake_raw_v3()
  fake_adapter <- function(model, messages, response_schema, ...) {
    captured <<- messages
    fake
  }

  # Simula una riga JSONL emessa da archs4_to_stage1_jsonl (R/etl-archs4-h5.R)
  # contenente molecule_ch1 valorizzato (caso comune nel fullrun beta).
  jsonl_line <- jsonlite::toJSON(list(
    geo_accession    = "GSM12345",
    series_id        = "GSE99999",
    string           = "treatment: VEGF, time: 1h, cell line: HUVEC",
    library_strategy = "RNA-Seq",
    organism         = "Homo sapiens",
    molecule_ch1     = "polyA RNA"
  ), auto_unbox = TRUE)

  parsed <- jsonlite::fromJSON(jsonl_line, simplifyVector = TRUE)
  row <- tibble::as_tibble(parsed)

  classify_sample_row(
    row,
    provider = "mock", model = "gpt-5.5", cache = NULL,
    .mock_adapter = fake_adapter
  )
  expect_match(captured[[2]]$content, "molecule_hint: polyA RNA", fixed = TRUE)
})

test_that("E2E D2: JSONL stream_in con molecule_ch1 null produce NA_character_ -> nessuna riga", {
  captured <- NULL
  fake <- .fake_raw_v3()
  fake_adapter <- function(model, messages, response_schema, ...) {
    captured <<- messages
    fake
  }

  # Riproduce il flow reale: jsonlite::stream_in (la convenzione usata dai
  # consumer R-side) lega le righe JSONL in un data.frame con colonna
  # character; i field null diventano NA_character_ (non NULL list-element
  # come in fromJSON simplifyVector). Cosi' la row passata a
  # classify_sample_row ha row$molecule_ch1 = NA_character_, e il guard
  # !is.na in build_prompt_stage1 deve scartarlo.
  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(c(
    '{"geo_accession":"GSM1","series_id":"GSE1","string":"primary fibroblasts","library_strategy":"RNA-Seq","organism":"Homo sapiens","molecule_ch1":"total RNA"}',
    '{"geo_accession":"GSM2","series_id":"GSE1","string":"baseline cells","library_strategy":"RNA-Seq","organism":"Homo sapiens","molecule_ch1":null}'
  ), tmp)
  df <- jsonlite::stream_in(file(tmp), verbose = FALSE)

  # Row 2 ha molecule_ch1 = NA_character_ (proveniente da JSON null in
  # un column-binding data.frame).
  expect_true(is.na(df$molecule_ch1[2]))

  row <- tibble::as_tibble(df[2, , drop = FALSE])
  classify_sample_row(
    row,
    provider = "mock", model = "gpt-5.5", cache = NULL,
    .mock_adapter = fake_adapter
  )
  expect_false(grepl("molecule_hint:", captured[[2]]$content, fixed = TRUE))
})
