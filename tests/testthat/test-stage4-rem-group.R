test_that("stage4_default_config espone il blocco rem_group con soglie decise", {
  cfg <- stage4_default_config()
  expect_true(!is.null(cfg$rem_group))
  expect_identical(cfg$rem_group$k_eff_min, 3L)
  expect_identical(cfg$rem_group$n_min, 2L)
  expect_true("vehicle_only" %in% cfg$rem_group$excluded_kinds)
  expect_true("none" %in% cfg$rem_group$excluded_kinds)
  expect_identical(cfg$schema_versions$rem_group_strategy,
                   "v1_per_study_rem_named_groups")
})
