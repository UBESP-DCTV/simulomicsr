# Schema della lista di controllo dello Stadio 2b (comparison_check.stage2b.v1).

schema_path <- function() system.file("schemas/comparison_check.stage2b.v1.json",
                                      package = "simulomicsr")

test_that("lo schema si compila e accetta la lista di controllo pulita", {
  v <- compile_schema(schema_path())
  expect_true(validate_json(.s2b_check_pulito(), v)$valid)
  expect_true(validate_json(.s2b_check_condizione(), v)$valid)
})

test_that("lo schema rifiuta valori fuori elenco, campi mancanti e campi in piu'", {
  v <- compile_schema(schema_path())
  ck <- .s2b_check_pulito(); ck$axes$sex$relation <- "similar"
  expect_false(validate_json(ck, v)$valid)
  ck <- .s2b_check_pulito(); ck$axes$technique <- NULL
  expect_false(validate_json(ck, v)$valid)
  ck <- .s2b_check_pulito(); ck$verdict <- "pass"
  expect_false(validate_json(ck, v)$valid)
  ck <- .s2b_check_pulito(); ck$agents[[1]]$in_treated <- "most"
  expect_false(validate_json(ck, v)$valid)
  ck <- .s2b_check_pulito(); ck$collection_time$control$hours <- "24"
  expect_false(validate_json(ck, v)$valid)
})

test_that("lo schema usa solo parole chiave che lo structured output di vLLM gestisce", {
  txt <- readLines(schema_path(), warn = FALSE)
  expect_false(any(grepl('"(\\$ref|pattern|format|oneOf|anyOf|allOf|minLength|maxLength)"', txt)))
})

test_that("gli assi dello schema sono quelli della regola, nello stesso ordine", {
  s <- jsonlite::read_json(schema_path())
  expect_identical(names(s$properties$axes$properties), names(simulomicsr:::.S2B_ASSI))
  expect_identical(unlist(s$properties$axes$required), names(simulomicsr:::.S2B_ASSI))
})

test_that("nessun accession GEO in prompt, schema e test (cancello C5 di S12)", {
  file_da_controllare <- c(
    schema_path(),
    system.file("prompts/stage2b-v1.md", package = "simulomicsr"),
    testthat::test_path("helper-stage2b.R"),
    testthat::test_path("test-stage2b-rule.R"),
    testthat::test_path("test-stage2b-input.R")
  )
  for (f in file_da_controllare) {
    expect_false(any(grepl("G(SE|SM|PL)[0-9]", readLines(f, warn = FALSE))), info = f)
  }
})
