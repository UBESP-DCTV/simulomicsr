test_that("design_role_to_binary mappa correttamente i 13 valori", {
  # treated
  expect_equal(design_role_to_binary("perturbed"), "treated")
  expect_equal(design_role_to_binary("case"), "treated")
  expect_equal(design_role_to_binary("secondary_arm"), "treated")
  # control
  expect_equal(design_role_to_binary("vehicle_control"), "control")
  expect_equal(design_role_to_binary("untreated_control"), "control")
  expect_equal(design_role_to_binary("negative_genetic_control"), "control")
  expect_equal(design_role_to_binary("negative_inducer_control"), "control")
  expect_equal(design_role_to_binary("baseline_t0"), "control")
  expect_equal(design_role_to_binary("comparison"), "control")
  # NA (escluso da metrica)
  expect_true(is.na(design_role_to_binary("bystander")))
  expect_true(is.na(design_role_to_binary("positive_control")))
  expect_true(is.na(design_role_to_binary("excluded")))
  expect_true(is.na(design_role_to_binary("unclear")))
})

test_that("design_role_to_binary errors on unknown role", {
  expect_error(
    design_role_to_binary("not_a_real_role"),
    class = "simulomicsr_invalid_design_role"
  )
})

test_that("design_role_to_binary vectorized: applica element-wise", {
  roles <- c("perturbed", "vehicle_control", "bystander", "case")
  expected <- c("treated", "control", NA_character_, "treated")
  expect_equal(design_role_to_binary(roles), expected)
})
