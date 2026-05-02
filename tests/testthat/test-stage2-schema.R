test_that("schema stage2.v1 accetta esempio valido VEGF HUVEC", {
  skip_if_not_installed("jsonvalidate")
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  expect_true(nzchar(schema_path))
  fixture <- jsonlite::read_json(
    testthat::test_path("fixtures/stage2-valid-vegf-huvec.json")
  )
  validator <- compile_schema(schema_path)
  result <- validate_json(fixture, validator = validator)
  expect_true(result$valid, info = paste(result$errors, collapse = "\n"))
})

test_that("schema stage2.v1 rifiuta design_kind fuori vocab", {
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  fixture <- jsonlite::read_json(
    testthat::test_path("fixtures/stage2-invalid-bad-design-kind.json")
  )
  validator <- compile_schema(schema_path)
  result <- validate_json(fixture, validator = validator)
  expect_false(result$valid)
  expect_match(paste(result$errors, collapse = " "), "design_kind|enum",
               ignore.case = TRUE)
})

test_that("schema stage2.v1 rifiuta missing required (replicate_groups)", {
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  fixture <- jsonlite::read_json(
    testthat::test_path("fixtures/stage2-invalid-missing-required.json")
  )
  validator <- compile_schema(schema_path)
  result <- validate_json(fixture, validator = validator)
  expect_false(result$valid)
  expect_match(paste(result$errors, collapse = " "), "replicate_groups|required",
               ignore.case = TRUE)
})

test_that("schema stage2.v1 rifiuta additionalProperties (campo extra in factors[])", {
  schema_path <- system.file("schemas/study_design.stage2.v1.json",
                             package = "simulomicsr")
  fixture <- jsonlite::read_json(
    testthat::test_path("fixtures/stage2-valid-vegf-huvec.json")
  )
  fixture$factors[[1]]$extra_field <- "not allowed"
  validator <- compile_schema(schema_path)
  result <- validate_json(fixture, validator = validator)
  expect_false(result$valid)
})
