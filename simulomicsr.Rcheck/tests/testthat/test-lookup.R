test_that("normalize_gene risolve un symbol canonico human a HGNC ID", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("VEGFA", organism = "human", source_path = src)

  expect_equal(res$id, "HGNC:12680")
  expect_equal(res$preferred_name, "VEGFA")
  expect_equal(res$resolved_via, "symbol")
})

test_that("normalize_gene risolve un alias e segnala il path di risoluzione", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("VEGF", organism = "human", source_path = src)

  expect_equal(res$id, "HGNC:12680")
  expect_equal(res$preferred_name, "VEGFA")
  expect_equal(res$resolved_via, "alias_symbol")
})

test_that("normalize_gene risolve un prev_symbol", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("c-Myc", organism = "human", source_path = src)

  expect_equal(res$id, "HGNC:7794")
  expect_equal(res$resolved_via, "prev_symbol")
})

test_that("normalize_gene è case-insensitive ma preserva il preferred_name canonico", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("vegfa", organism = "human", source_path = src)

  expect_equal(res$id, "HGNC:12680")
  expect_equal(res$preferred_name, "VEGFA")
})

test_that("normalize_gene ritorna NULL su gene NON trovato (no allucinazione)", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  res <- normalize_gene("NOTAGENE", organism = "human", source_path = src)

  expect_null(res)
})

test_that("normalize_gene rifiuta organism diversi da 'human' in P1 con errore tipizzato", {
  src <- system.file("extdata/hgnc-fixture-mini.tsv", package = "simulomicsr")
  expect_error(
    normalize_gene("Brca1", organism = "mouse", source_path = src),
    class = "simulomicsr_lookup_unsupported_organism"
  )
})

test_that("hgnc_dump_path ritorna un path nella user cache dir e segnala se assente", {
  withr::local_envvar(R_USER_CACHE_DIR = tempfile())
  p <- hgnc_dump_path()
  expect_match(p, "simulomicsr.+hgnc_complete_set\\.tsv$")
  expect_false(fs::file_exists(p))  # non scarica nulla automaticamente
})
