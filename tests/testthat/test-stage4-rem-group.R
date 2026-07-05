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

.mk_cluster_row <- function(cluster_id, mode, level, k, n_total, n_studies,
                            safety_min, usable_mega_strict, kind, agent) {
  tibble::tibble(
    cluster_id = cluster_id, mode = mode, level = level, k = k,
    n_total = n_total, n_studies = n_studies, safety_min = safety_min,
    usable_rem_strict = FALSE, usable_rem_relaxed = FALSE,
    usable_mega_strict = usable_mega_strict, usable_mega_relaxed = FALSE,
    kind_effective_resolved = kind, agent_id_resolved = agent,
    studies_in_cluster = list(paste0("GSE", seq_len(n_studies))),
    direction_check = "ok"
  )
}

test_that("porta rem_group ammette group nominato L4, esclude coarse/vehicle/pair", {
  clusters <- dplyr::bind_rows(
    .mk_cluster_row("group_L4_enza", "group", 4L, 25L, 400L, 25L, 0.33,
                    FALSE, "small_molecule", "CHEBI:enzalutamide"),
    .mk_cluster_row("group_L0_coarse", "group", 0L, 8L, 200L, 8L, 0.85,
                    TRUE,  "environmental", "STR:hypoxia"),
    .mk_cluster_row("group_L3_veh", "group", 3L, 5L, 60L, 5L, 0.30,
                    FALSE, "vehicle_only", "CHEBI:dmso"),
    .mk_cluster_row("pair_L2_x", "pair", 2L, 4L, 40L, 4L, 0.60,
                    FALSE, "small_molecule", "CHEBI:foo")
  )
  cfg <- stage4_default_config()
  out <- .identify_layer_a_clusters(clusters, cfg)
  rg <- out[out$method == "rem_group", ]
  expect_identical(rg$cluster_id, "group_L4_enza")
  expect_false("group_L0_coarse" %in% out$cluster_id[out$method == "rem_group"])
  expect_false("group_L3_veh"    %in% out$cluster_id)
  expect_false(any(out$method == "rem_group" & out$mode == "pair"))
})
