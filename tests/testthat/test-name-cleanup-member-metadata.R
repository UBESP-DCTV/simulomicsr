# tests/testthat/test-name-cleanup-member-metadata.R
test_that(".build_cluster_member_metadata aggrega e tronca i metadati membri", {
  assignments <- tibble::tibble(
    record_id = c("GSE1__cmp1", "GSE1__cmp1", "GSE2__g1"),
    cluster_id = c("c1", "c1", "c1"))
  rec_env <- new.env(parent = emptyenv())
  assign("GSE1__cmp1", c("GSM1", "GSM2"), envir = rec_env)
  assign("GSE2__g1",  c("GSM3"), envir = rec_env)
  gsm_text <- c(GSM1 = "lps treated 24h", GSM2 = "lps treated 24h", GSM3 = "control pbmc")
  out <- .build_cluster_member_metadata("c1", assignments, rec_env, gsm_text, char_budget = 1000L)
  expect_named(out, "c1")
  expect_match(out[["c1"]], "lps treated")
  expect_match(out[["c1"]], "control pbmc")
  # dedup: "lps treated 24h" appare una sola volta
  expect_equal(lengths(regmatches(out[["c1"]], gregexpr("lps treated 24h", out[["c1"]]))), 1L)
})

test_that(".build_cluster_member_metadata rispetta il char_budget", {
  assignments <- tibble::tibble(record_id = "GSE1__g1", cluster_id = "c1")
  rec_env <- new.env(parent = emptyenv()); assign("GSE1__g1", c("GSM1"), envir = rec_env)
  gsm_text <- c(GSM1 = strrep("x", 5000))
  out <- .build_cluster_member_metadata("c1", assignments, rec_env, gsm_text, char_budget = 100L)
  expect_lte(nchar(out[["c1"]]), 100L)
})
