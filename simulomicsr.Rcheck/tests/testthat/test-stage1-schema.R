schema_path <- function() {
  system.file("schemas/sample_facts.stage1.v3.json", package = "simulomicsr")
}

read_fixture <- function(name) {
  path <- testthat::test_path("fixtures", name)
  jsonlite::fromJSON(readr::read_file(path), simplifyVector = FALSE)
}

test_that("schema sample_facts.stage1.v3 esiste come file bundled", {
  expect_true(nzchar(schema_path()))
  expect_true(fs::file_exists(schema_path()))
})

test_that("schema accetta l'esempio v3 della spec (HUVEC + VEGF)", {
  v <- compile_schema(schema_path())
  ex <- read_fixture("stage1-valid-vegf-huvec.json")
  res <- validate_json(ex, validator = v)
  expect_true(res$valid, info = paste(res$errors, collapse = " | "))
})

test_that("schema rifiuta perturbations[].kind fuori vocab", {
  v <- compile_schema(schema_path())
  bad <- read_fixture("stage1-invalid-bad-kind.json")
  res <- validate_json(bad, validator = v)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " | "), "kind", ignore.case = TRUE)
})

test_that("schema rifiuta extraction senza required (confidence + ambiguity_flags)", {
  v <- compile_schema(schema_path())
  bad <- read_fixture("stage1-invalid-missing-required.json")
  res <- validate_json(bad, validator = v)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " | "),
               "confidence|ambiguity_flags", ignore.case = TRUE)
})

test_that("schema rifiuta additionalProperties al top level", {
  v <- compile_schema(schema_path())
  ex <- read_fixture("stage1-valid-vegf-huvec.json")
  ex$rogue_field <- "this should not be accepted"
  res <- validate_json(ex, validator = v)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " | "),
               "additional|rogue_field", ignore.case = TRUE)
})
