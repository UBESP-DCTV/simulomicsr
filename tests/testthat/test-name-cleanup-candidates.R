# tests/testthat/test-name-cleanup-candidates.R
test_that(".load_name_cleanup_candidates classifica role ed esclude vehicle", {
  f <- testthat::test_path("fixtures", "name-cleanup-triage-mini.csv")
  d <- .load_name_cleanup_candidates(f)
  expect_equal(nrow(d), 3L)                          # c4 escluso
  expect_setequal(d$cluster_id, c("c1","c2","c3"))
  expect_equal(d$role[d$cluster_id == "c1"], "candidate")
  expect_equal(d$role[d$cluster_id == "c3"], "candidate")
  expect_equal(d$role[d$cluster_id == "c2"], "canary")
})
