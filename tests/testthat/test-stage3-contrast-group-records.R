# Il record di gruppo nasce dal CONTRASTO (ADR-0025).
#
# Un record per ogni comparison dello Stadio 2, con chiave
# entita'-delta || verso || tipo di controllo. I record pair e group NON devono
# cambiare: l'innesto e' additivo.

.ca_test_study <- function() {
  list(
    series_id = "GSE147876",
    design_kind = "treatment_vs_vehicle",
    replicate_groups = list(
      list(group_id = "rg1", primary_role = "treated",
           label_human = "LNCaP Enzalutamide Treated",
           sample_ids = list("GSM1", "GSM2"),
           factor_levels = list(list(key = "cell_line", value = "LNCaP"),
                                list(key = "treatment", value = "Enzalutamide"))),
      list(group_id = "rg2", primary_role = "control",
           label_human = "LNCaP Vehicle Control",
           sample_ids = list("GSM3", "GSM4"),
           factor_levels = list(list(key = "cell_line", value = "LNCaP"),
                                list(key = "treatment", value = "Vehicle")))),
    comparisons = list(list(comparison_id = "cmp1", treated_group = "rg1",
                            control_group = "rg2", control_type = "vehicle"))
  )
}

.ca_test_stage1 <- function() {
  list(GSM1 = make_test_sample_fact(), GSM2 = make_test_sample_fact(),
       GSM3 = make_test_sample_fact(), GSM4 = make_test_sample_fact())
}

test_that(".build_contrast_group_records produce un record per comparison", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  recs <- .build_contrast_group_records(
    list(.ca_test_study()), .ca_test_stage1(),
    stage3_default_config()$tier_assignment, ontology_env = oe)
  expect_length(recs, 1L)
  r <- recs[[1L]]
  expect_equal(r$mode, "cgroup")
  expect_equal(r$record_id, "GSE147876__cmp1")
  expect_equal(r$contrast_entity, "CHEBI:68534")
  expect_equal(r$contrast_key, "CHEBI:68534||gain||vehicle_untreated")
  expect_equal(r$treated_sample_ids, c("GSM1", "GSM2"))
  expect_equal(r$control_sample_ids, c("GSM3", "GSM4"))
  expect_equal(r$n_treated_group, 2L)
  expect_equal(r$n_control_group, 2L)
})

test_that(".build_contrast_group_records non emette record per i confronti scartati", {
  oe <- .load_ontology_dicts()
  st <- .ca_test_study()
  # i due bracci diventano identici: delta vuoto, nessun contrasto
  st$replicate_groups[[2L]]$factor_levels <- st$replicate_groups[[1L]]$factor_levels
  st$replicate_groups[[2L]]$label_human   <- st$replicate_groups[[1L]]$label_human
  recs <- .build_contrast_group_records(
    list(st), .ca_test_stage1(),
    stage3_default_config()$tier_assignment, ontology_env = oe)
  expect_length(recs, 0L)
  # lo scarto e' tracciato, non silenzioso
  dropped <- attr(recs, "dropped")
  expect_length(dropped, 1L)
  expect_equal(dropped[[1L]]$record_id, "GSE147876__cmp1")
  expect_equal(dropped[[1L]]$details, "no_delta")
})

test_that("i record group e pair NON cambiano (retrocompatibilita')", {
  ta <- stage3_default_config()$tier_assignment
  g <- .build_group_records(list(.ca_test_study()), .ca_test_stage1(), ta)
  p <- .build_pair_records(list(.ca_test_study()), .ca_test_stage1(), ta)
  expect_length(g, 2L)   # un record per replicate_group, come prima
  expect_length(p, 1L)   # un record per comparison, come prima
  expect_equal(g[[1L]]$mode, "group")
  expect_equal(p[[1L]]$mode, "pair")
})

test_that("i cluster cgroup non sono ne' rem ne' mega usable", {
  u <- .tag_cluster_usability(
    list(mode = "cgroup", level = .CA_CONTRAST_LEVEL, k = 10L, n_total = 50L,
         n_studies = 10L, safety_min = 0.9),
    stage3_default_config()$thresholds)
  expect_false(u$usable_rem_strict)
  expect_false(u$usable_rem_relaxed)
  expect_false(u$usable_mega_strict)
  expect_false(u$usable_mega_relaxed)
})

test_that("build_stage3_clusters produce cluster cgroup accanto a pair e group", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  res <- build_stage3_clusters(.ca_test_stage1(), list(.ca_test_study()))
  modes <- unique(res$clusters$mode)
  expect_true("cgroup" %in% modes)
  expect_true("group" %in% modes)                   # il ramo group resta intatto
  # Il record pair di questa fixture viene scartato dal direction check
  # PRE-ESISTENTE (i due bracci hanno gli stessi stage1_facts, quindi il verso
  # non e' determinabile): comportamento invariato, verificato qui perche' e'
  # esattamente cio' che l'innesto non deve cambiare.
  expect_true(any(res$non_clusterable$mode == "pair" &
                    res$non_clusterable$reason == "direction_ambiguous"))
  cg <- res$clusters[res$clusters$mode == "cgroup", ]
  expect_equal(nrow(cg), 1L)
  expect_equal(cg$level, .CA_CONTRAST_LEVEL)
  expect_equal(cg$anchor_key, "CHEBI:68534||gain||vehicle_untreated")
  expect_equal(cg$contrast_entity, "CHEBI:68534")
  expect_equal(cg$contrast_direction, "gain")
  expect_equal(cg$n_treated, 2L)
  expect_equal(cg$n_control, 2L)      # il cgroup ha un lato-controllo vero
  expect_false(cg$usable_mega_strict) # level 5: fuori dal ramo mega per costruzione
  expect_true(startsWith(cg$cluster_id, "cgroup_L5_"))
  expect_equal(res$run_metadata$output_counts$n_records_clusterable_cgroup, 1L)
})
