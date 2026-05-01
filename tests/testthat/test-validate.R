test_that("compile_schema legge un file e ritorna un validatore richiamabile", {
  path <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  expect_true(nzchar(path))

  v <- compile_schema(path)
  expect_type(v, "closure")
})

test_that("validate_json passa su input conforme", {
  path <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  v <- compile_schema(path)

  ok <- list(question = "Q?", answer = "A.", confidence = 0.5)
  res <- validate_json(ok, validator = v)
  expect_true(res$valid)
  expect_equal(length(res$errors), 0L)
})

test_that("validate_json fallisce su confidence > 1 con messaggio leggibile", {
  path <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  v <- compile_schema(path)

  bad <- list(question = "Q?", answer = "A.", confidence = 1.5)
  res <- validate_json(bad, validator = v)
  expect_false(res$valid)
  expect_gte(length(res$errors), 1L)
  expect_match(paste(res$errors, collapse = " | "), "confidence", ignore.case = TRUE)
})

test_that("validate_json fallisce se manca un required field", {
  path <- system.file("schemas/llm-call-envelope.v1.json", package = "simulomicsr")
  v <- compile_schema(path)

  bad <- list(question = "Q?", answer = "A.")
  res <- validate_json(bad, validator = v)
  expect_false(res$valid)
  expect_match(paste(res$errors, collapse = " | "), "confidence", ignore.case = TRUE)
})
