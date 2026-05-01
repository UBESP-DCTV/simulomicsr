test_that("sha256_text produce hash deterministico esadecimale di 64 caratteri", {
  h1 <- sha256_text("hello world")
  expect_type(h1, "character")
  expect_length(h1, 1L)
  expect_match(h1, "^[0-9a-f]{64}$")

  # Determinismo
  expect_identical(sha256_text("hello world"), h1)

  # Sensibilità a un singolo carattere
  expect_false(identical(sha256_text("hello world"), sha256_text("hello world!")))
})

test_that("cache_key_for compone una chiave canonica con prefisso schema_version", {
  k <- cache_key_for(schema_version = "stage1.v3", payload = "VEGF stim 0h HUVEC")
  expect_match(k, "^stage1\\.v3:[0-9a-f]{64}$")

  # Stesso schema + stesso payload → stessa chiave
  expect_identical(
    cache_key_for("stage1.v3", "VEGF stim 0h HUVEC"),
    cache_key_for("stage1.v3", "VEGF stim 0h HUVEC")
  )

  # Bump schema → chiave diversa
  expect_false(identical(
    cache_key_for("stage1.v3", "x"),
    cache_key_for("stage1.v4", "x")
  ))
})
