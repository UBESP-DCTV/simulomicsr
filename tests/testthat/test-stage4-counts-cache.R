test_that(".cache_key_for_fetch e' deterministico per stessi (gse, sample_ids)", {
  k1 <- .cache_key_for_fetch("GSE001", c("GSM001", "GSM002"))
  k2 <- .cache_key_for_fetch("GSE001", c("GSM002", "GSM001"))  # ordine diverso
  expect_identical(k1, k2)  # sorted internamente
  expect_true(nchar(k1) == 8L)
})

test_that("cache_purge_stage4 ritorna 0 quando cache_dir non esiste", {
  tmp <- file.path(withr::local_tempdir(), "no_cache")
  result <- cache_purge_stage4(cache_dir = tmp)
  expect_equal(result, 0L)
})

test_that(".fetch_counts_cached salva su disco e rispetta cache hit", {
  tmp_cache <- withr::local_tempdir()

  # Mock fetch function che incrementa counter ogni volta
  call_count <- 0L
  mock_fetch <- function(gse, sample_ids) {
    call_count <<- call_count + 1L
    matrix(1:6, nrow = 3, ncol = 2,
           dimnames = list(c("g1", "g2", "g3"), sample_ids))
  }

  # Prima call: cache miss -> fetch
  m1 <- .fetch_counts_cached("GSE001", c("GSM001", "GSM002"),
                              fetch_fn = mock_fetch, cache_dir = tmp_cache)
  expect_equal(call_count, 1L)

  # Seconda call: cache hit -> no fetch
  m2 <- .fetch_counts_cached("GSE001", c("GSM001", "GSM002"),
                              fetch_fn = mock_fetch, cache_dir = tmp_cache)
  expect_equal(call_count, 1L)  # ancora 1, no incremento
  expect_identical(m1, m2)
})
