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
