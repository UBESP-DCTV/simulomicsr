test_that("cache_init crea jsonl e sqlite vuoti idempotentemente", {
  d <- new_cache_dir()
  c1 <- cache_init(d, namespace = "stage1")

  expect_true(fs::file_exists(c1$jsonl_path))
  expect_true(fs::file_exists(c1$sqlite_path))
  expect_equal(cache_stats(c1)$n_entries, 0L)

  # Idempotente: secondo init sulla stessa dir non rompe e non resetta
  cache_put(c1, key = "a", value = list(x = 1))
  c2 <- cache_init(d, namespace = "stage1")
  expect_equal(cache_stats(c2)$n_entries, 1L)
})

test_that("cache_put + cache_get fanno round-trip su strutture R complesse", {
  c <- cache_init(new_cache_dir(), namespace = "stage1")

  payload <- list(
    geo_accession = "GSM1009635",
    perturbations = list(
      list(kind = "cytokine_stimulation", agent = "VEGFA", dose = "1uM")
    ),
    confidence = 0.81
  )

  cache_put(c, key = "k1", value = payload, metadata = list(model = "gpt-5.4-mini"))

  expect_true(cache_has(c, "k1"))
  got <- cache_get(c, "k1")
  expect_equal(got$value, payload)
  expect_equal(got$metadata$model, "gpt-5.4-mini")
})

test_that("cache_get ritorna NULL su miss e cache_has è coerente", {
  c <- cache_init(new_cache_dir(), namespace = "stage1")
  expect_false(cache_has(c, "nope"))
  expect_null(cache_get(c, "nope"))
})

test_that("la cache sopravvive a una riapertura su nuovo processo (riapertura sqlite)", {
  d <- new_cache_dir()
  c1 <- cache_init(d, namespace = "stage1")
  cache_put(c1, "persist", list(answer = 42))

  c2 <- cache_init(d, namespace = "stage1")
  expect_true(cache_has(c2, "persist"))
  expect_equal(cache_get(c2, "persist")$value$answer, 42)
})

test_that("namespace separa entries dello stesso path", {
  d <- new_cache_dir()
  c_a <- cache_init(d, namespace = "stage1")
  c_b <- cache_init(d, namespace = "stage2")

  cache_put(c_a, "k", list(v = "in_stage1"))
  expect_false(cache_has(c_b, "k"))
  expect_true(cache_has(c_a, "k"))
})

test_that("cache_put append-only: due put su stessa key tengono ENTRAMBI in jsonl ma get ritorna l'ultimo", {
  c <- cache_init(new_cache_dir(), namespace = "stage1")
  cache_put(c, "k", list(v = 1))
  cache_put(c, "k", list(v = 2))

  expect_equal(cache_get(c, "k")$value$v, 2)
  # Append-only: il jsonl ha 2 righe
  jsonl_lines <- readr::read_lines(c$jsonl_path)
  expect_equal(length(jsonl_lines), 2L)
})
