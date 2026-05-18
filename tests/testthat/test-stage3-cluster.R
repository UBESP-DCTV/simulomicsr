test_that(".partition_by_hard_filters separa per (subcellular, context_kind)", {
  recs <- list(
    list(record_id = "r1",
         hard_filters = list(subcellular = "whole_cell", context_kind = "cell_line")),
    list(record_id = "r2",
         hard_filters = list(subcellular = "whole_cell", context_kind = "cell_line")),
    list(record_id = "r3",
         hard_filters = list(subcellular = "nuclear",    context_kind = "cell_line")),
    list(record_id = "r4",
         hard_filters = list(subcellular = "whole_cell", context_kind = "primary"))
  )
  parts <- simulomicsr:::.partition_by_hard_filters(recs)

  # Tre partition: (whole_cell, cell_line), (nuclear, cell_line), (whole_cell, primary)
  expect_length(parts, 3L)

  sizes <- vapply(parts, length, integer(1L))
  expect_setequal(sizes, c(2L, 1L, 1L))
})

test_that(".assign_records_to_clusters genera cluster_id deterministico via xxhash32", {
  recs <- list(
    list(record_id = "r1", anchor_key = "small_molecule|CHEMBL941|endothelium"),
    list(record_id = "r2", anchor_key = "small_molecule|CHEMBL941|endothelium"),
    list(record_id = "r3", anchor_key = "small_molecule|CHEMBL112|endothelium")
  )
  result <- simulomicsr:::.assign_records_to_clusters(
    records = recs, mode = "pair", level = 0L
  )

  # 2 unique anchor_keys -> 2 clusters
  expect_equal(length(unique(result$cluster_id)), 2L)

  # Records con stesso anchor_key -> stesso cluster_id
  r1_cl <- result$cluster_id[result$record_id == "r1"]
  r2_cl <- result$cluster_id[result$record_id == "r2"]
  r3_cl <- result$cluster_id[result$record_id == "r3"]
  expect_equal(r1_cl, r2_cl)
  expect_true(r3_cl != r1_cl)
})

test_that("cluster_id format: 'pair_L0_<8hex>'", {
  recs <- list(
    list(record_id = "r1", anchor_key = "small_molecule|CHEMBL941|endothelium")
  )
  result <- simulomicsr:::.assign_records_to_clusters(
    records = recs, mode = "pair", level = 0L
  )

  cl_id <- result$cluster_id[1]
  expect_match(cl_id, "^pair_L0_[0-9a-f]{8}$")
})

test_that("cluster_id deterministico cross-call (stesso input -> stesso ID)", {
  recs <- list(
    list(record_id = "r1", anchor_key = "small_molecule|CHEMBL941|endothelium")
  )
  r1 <- simulomicsr:::.assign_records_to_clusters(recs, "pair", 0L)
  r2 <- simulomicsr:::.assign_records_to_clusters(recs, "pair", 0L)

  expect_identical(r1$cluster_id, r2$cluster_id)
})
