test_that("min_viable_level_rem = L0 quando cluster L0 usable_rem_relaxed", {
  assignments <- tibble::tibble(
    record_id  = c("r1", "r1", "r1"),
    mode       = c("pair", "pair", "pair"),
    level      = c(0L, 1L, 2L),
    cluster_id = c("pair_L0_aaaa", "pair_L1_bbbb", "pair_L2_cccc")
  )
  clusters <- tibble::tibble(
    cluster_id = c("pair_L0_aaaa", "pair_L1_bbbb", "pair_L2_cccc"),
    mode       = c("pair", "pair", "pair"),
    level      = c(0L, 1L, 2L),
    usable_rem_relaxed  = c(TRUE, TRUE, TRUE),
    usable_mega_relaxed = c(FALSE, FALSE, FALSE)
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)

  r1 <- result[result$record_id == "r1" & result$mode == "pair", ]
  expect_equal(as.character(r1$min_viable_level_rem), "L0")
  expect_equal(r1$min_viable_cluster_rem, "pair_L0_aaaa")
})

test_that("min_viable_level_rem = L2 quando L0/L1 NON usable, L2 usable", {
  assignments <- tibble::tibble(
    record_id  = c("r1", "r1", "r1"),
    mode       = c("pair", "pair", "pair"),
    level      = c(0L, 1L, 2L),
    cluster_id = c("pair_L0_aaaa", "pair_L1_bbbb", "pair_L2_cccc")
  )
  clusters <- tibble::tibble(
    cluster_id = c("pair_L0_aaaa", "pair_L1_bbbb", "pair_L2_cccc"),
    mode       = c("pair", "pair", "pair"),
    level      = c(0L, 1L, 2L),
    usable_rem_relaxed  = c(FALSE, FALSE, TRUE),
    usable_mega_relaxed = c(FALSE, FALSE, FALSE)
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)
  r1 <- result[result$record_id == "r1" & result$mode == "pair", ]
  expect_equal(as.character(r1$min_viable_level_rem), "L2")
  expect_equal(r1$min_viable_cluster_rem, "pair_L2_cccc")
})

test_that("min_viable_level_rem = NONE quando nessun L usable", {
  assignments <- tibble::tibble(
    record_id  = c("r1"),
    mode       = c("pair"),
    level      = c(0L),
    cluster_id = c("pair_L0_aaaa")
  )
  clusters <- tibble::tibble(
    cluster_id = "pair_L0_aaaa", mode = "pair", level = 0L,
    usable_rem_relaxed = FALSE, usable_mega_relaxed = FALSE
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)
  expect_equal(as.character(result$min_viable_level_rem), "NONE")
  expect_true(is.na(result$min_viable_cluster_rem))
})

test_that("in_n_clusters_rem conta livelli distinti per pair", {
  assignments <- tibble::tibble(
    record_id  = c("r1", "r1", "r1", "r1", "r1"),
    mode       = c("pair", "pair", "pair", "pair", "pair"),
    level      = c(0L, 1L, 2L, 3L, 4L),
    cluster_id = c("pair_L0_a", "pair_L1_b", "pair_L2_c", "pair_L3_d", "pair_L4_e")
  )
  clusters <- tibble::tibble(
    cluster_id = c("pair_L0_a", "pair_L1_b", "pair_L2_c", "pair_L3_d", "pair_L4_e"),
    mode = "pair", level = 0L:4L,
    usable_rem_relaxed = TRUE, usable_mega_relaxed = FALSE
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)
  r1 <- result[result$record_id == "r1" & result$mode == "pair", ]
  expect_equal(r1$in_n_clusters_rem, 5L)
})

test_that("empty assignments restituisce tibble vuoto (no NULL)", {
  assignments_empty <- tibble::tibble(
    record_id = character(), mode = character(),
    level = integer(), cluster_id = character()
  )
  clusters_empty <- tibble::tibble(
    cluster_id = character(), mode = character(), level = integer(),
    usable_rem_relaxed = logical(), usable_mega_relaxed = logical()
  )
  result <- simulomicsr:::.build_record_summary(assignments_empty, clusters_empty)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
  expect_true(all(c("record_id", "mode", "min_viable_level_rem",
                    "min_viable_cluster_rem", "min_viable_level_mega",
                    "min_viable_cluster_mega", "in_n_clusters_rem",
                    "in_n_clusters_mega") %in% names(result)))
})

test_that("group-mode record: _rem cols NA, _mega cols populate", {
  assignments <- tibble::tibble(
    record_id  = c("g1", "g1"),
    mode       = c("group", "group"),
    level      = c(0L, 1L),
    cluster_id = c("group_L0_aaa", "group_L1_bbb")
  )
  clusters <- tibble::tibble(
    cluster_id = c("group_L0_aaa", "group_L1_bbb"),
    mode       = c("group", "group"),
    level      = c(0L, 1L),
    usable_rem_relaxed  = c(FALSE, FALSE),
    usable_mega_relaxed = c(TRUE, TRUE)
  )
  result <- simulomicsr:::.build_record_summary(assignments, clusters)

  expect_equal(nrow(result), 1L)
  expect_true(is.na(result$min_viable_level_rem))
  expect_true(is.na(result$min_viable_cluster_rem))
  expect_equal(as.character(result$min_viable_level_mega), "L0")
  expect_equal(result$min_viable_cluster_mega, "group_L0_aaa")
  expect_equal(result$in_n_clusters_mega, 2L)
  expect_equal(result$in_n_clusters_rem, 0L)
})
