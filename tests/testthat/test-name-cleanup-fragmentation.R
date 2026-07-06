test_that(".measure_fragmentation individua i frammenti e somma k", {
  st <- tibble::tibble(
    cluster_id = c("c1","c2","c3"),
    old_id = c("CHEBI:17126","CHEBI:99","CHEBI:50"),
    new_id = c("CHEBI:16412","CHEBI:16412", NA_character_))  # c1,c2 -> stessa entità
  k_by <- c(c1 = 4L, c2 = 3L, c3 = 5L)
  fr <- .measure_fragmentation(st, k_by)
  expect_equal(nrow(fr), 1L)
  expect_equal(fr$resolved_entity_id, "CHEBI:16412")
  expect_equal(fr$n_clusters, 2L)
  expect_equal(fr$k_merged_est, 7L)
})
