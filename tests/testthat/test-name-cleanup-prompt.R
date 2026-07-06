# tests/testthat/test-name-cleanup-prompt.R
test_that("lo schema name_cleanup.v1 compila", {
  path <- system.file("schemas", "name_cleanup.v1.json", package = "simulomicsr")
  expect_true(nzchar(path))
  expect_silent(compile_schema(path))
})

test_that(".build_name_cleanup_messages incapsula label+kind+metadati e NON il top_theme", {
  msgs <- .build_name_cleanup_messages("carnitine", "small_molecule", "lps treated 24h pbmc")
  expect_equal(msgs[[1]]$role, "system")
  expect_equal(msgs[[2]]$role, "user")
  expect_match(msgs[[2]]$content, "carnitine")
  expect_match(msgs[[2]]$content, "lps treated")
  expect_match(msgs[[2]]$content, "small_molecule")
})
