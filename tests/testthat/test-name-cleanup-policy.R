# tests/testthat/test-name-cleanup-policy.R
strong <- function(id) list(resolved_id = id, resolved_name = "x", match_strength = "STRONG")
none_r <- list(resolved_id = NA_character_, resolved_name = NA_character_, match_strength = "NONE")

test_that("STRONG diverso su candidate -> override", {
  p <- .apply_name_cleanup_policy("CHEBI:17126", "high", strong("CHEBI:16412"), "candidate")
  expect_equal(p$action, "override"); expect_equal(p$new_id, "CHEBI:16412")
  expect_equal(p$name_recovery_source, "mistral_fallback")
  expect_false(p$name_llm_unvalidatable)
})
test_that("STRONG diverso su canary -> flag_review (no override)", {
  p <- .apply_name_cleanup_policy("CHEBI:16236", "high", strong("CHEBI:99999"), "canary")
  expect_equal(p$action, "flag_review"); expect_true(is.na(p$new_id))
})
test_that("STRONG uguale -> noop", {
  p <- .apply_name_cleanup_policy("CHEBI:16412", "high", strong("CHEBI:16412"), "candidate")
  expect_equal(p$action, "noop")
})
test_that("NONE o low -> keep + unvalidatable", {
  expect_equal(.apply_name_cleanup_policy("CHEBI:1", "high", none_r, "candidate")$action, "keep")
  expect_true(.apply_name_cleanup_policy("CHEBI:1", "high", none_r, "candidate")$name_llm_unvalidatable)
  expect_equal(.apply_name_cleanup_policy("CHEBI:1", "low", strong("CHEBI:2"), "candidate")$action, "keep")
})
