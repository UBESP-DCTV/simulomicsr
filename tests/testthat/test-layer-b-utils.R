test_that(".run_id_for_layer_b is deterministic", {
  id_a <- simulomicsr:::.run_id_for_layer_b(
    stage4_run_id = "deadbeef",
    selection_sha256 = "abc123",
    config = layer_b_default_config(),
    schema_versions = list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  )
  id_b <- simulomicsr:::.run_id_for_layer_b(
    stage4_run_id = "deadbeef",
    selection_sha256 = "abc123",
    config = layer_b_default_config(),
    schema_versions = list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  )
  expect_equal(id_a, id_b)
  expect_match(id_a, "^[a-f0-9]{8}$")
})

test_that(".run_id_for_layer_b changes if config changes", {
  id_a <- simulomicsr:::.run_id_for_layer_b(
    stage4_run_id = "deadbeef", selection_sha256 = "abc",
    config = layer_b_default_config(),
    schema_versions = list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  )
  cfg2 <- layer_b_default_config(); cfg2$top_n_table <- 50L
  id_b <- simulomicsr:::.run_id_for_layer_b(
    stage4_run_id = "deadbeef", selection_sha256 = "abc",
    config = cfg2,
    schema_versions = list(layer_b_algorithm = "v1", stage4_algorithm = "v1")
  )
  expect_false(id_a == id_b)
})

test_that(".rank_and_dedup_genes orders by FDR ascending, tie-break |logFC| descending", {
  sig <- tibble::tibble(
    gene_id = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol = c("MARKER_A", "NOISY_B", "TIE_C1"),
    logFC_pool = c(0.6, 5.0, 2.0),
    FDR_BH_within_cluster = c(1e-10, 0.049, 0.02)
  )
  out <- simulomicsr:::.rank_and_dedup_genes(sig)
  # FDR crescente vince sempre su |logFC|, anche se NOISY_B ha logFC enorme.
  expect_equal(out$gene_id, c("ENSG_A", "ENSG_C", "ENSG_B"))
})

test_that(".rank_and_dedup_genes tie-breaks on |logFC_pool| descending when FDR is equal", {
  sig <- tibble::tibble(
    gene_id = c("ENSG_1", "ENSG_2"),
    gene_symbol = c("S1", "S2"),
    logFC_pool = c(1.0, 3.0),
    FDR_BH_within_cluster = c(0.01, 0.01)
  )
  out <- simulomicsr:::.rank_and_dedup_genes(sig)
  expect_equal(out$gene_id, c("ENSG_2", "ENSG_1"))
})

test_that(".rank_and_dedup_genes collapses rows sharing gene_symbol, keeping the most significant", {
  sig <- tibble::tibble(
    gene_id = c("ENSG_1", "ENSG_2", "ENSG_3"),
    gene_symbol = c("RDH13", "RDH13", "RDH13"),
    logFC_pool = c(1.0, 3.0, 0.5),
    FDR_BH_within_cluster = c(0.001, 1e-8, 0.02)
  )
  out <- simulomicsr:::.rank_and_dedup_genes(sig)
  expect_equal(nrow(out), 1L)
  expect_equal(out$gene_id, "ENSG_2")
})

test_that(".rank_and_dedup_genes does NOT collapse rows with NA or empty gene_symbol", {
  sig <- tibble::tibble(
    gene_id = c("ENSG_1", "ENSG_2", "ENSG_3"),
    gene_symbol = c(NA_character_, "", NA_character_),
    logFC_pool = c(1.0, 0.9, 0.8),
    FDR_BH_within_cluster = c(0.001, 0.002, 0.003)
  )
  out <- simulomicsr:::.rank_and_dedup_genes(sig)
  expect_equal(nrow(out), 3L)
})

test_that(".rank_and_dedup_genes handles 0-row input", {
  sig <- tibble::tibble(
    gene_id = character(0), gene_symbol = character(0),
    logFC_pool = numeric(0), FDR_BH_within_cluster = numeric(0)
  )
  out <- simulomicsr:::.rank_and_dedup_genes(sig)
  expect_equal(nrow(out), 0L)
})
