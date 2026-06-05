# TDD per l'espansione collect -> master Stadio 2 v3 (RED ALERT F4 opzione C).
#
# Dopo il run, il modello emette uno study_design dove i replicate_group.sample_ids
# contengono i RAPPRESENTANTI delle condizioni. L'espansione sostituisce ogni
# rappresentante con i suoi member_sample_ids reali (dalla mappa costruita
# dall'input v3), lasciando invariato tutto il resto (group_id, comparisons, ...).

# input record v3 (1 record/studio) come da build input v3
mk_input_record <- function(series = "GSE1", conds = list(
  list(geo = "GSM1", members = c("GSM1", "GSM2", "GSM3")),
  list(geo = "GSM4", members = c("GSM4", "GSM5")))) {
  samples <- lapply(seq_along(conds), function(i) {
    cc <- conds[[i]]
    list(geo_accession = cc$geo, sample_facts = list(),
         n_replicates = length(cc$members),
         member_sample_ids = as.list(cc$members),
         condition_id = sprintf("cond_%04d", i))
  })
  list(record_id = series, series_id = series, samples = samples)
}

mk_design <- function(series = "GSE1", groups, comparisons = list()) {
  list(series_id = series, design_kind = "treatment_vs_vehicle",
       replicate_groups = groups, comparisons = comparisons,
       extraction = list(schema_version = "stage2.v2"))
}

test_that(".build_member_lookup mappa rappresentante -> member_sample_ids", {
  lk <- .build_member_lookup(list(mk_input_record()))
  expect_setequal(names(lk), c("GSM1", "GSM4"))
  expect_identical(as.character(lk[["GSM1"]]), c("GSM1", "GSM2", "GSM3"))
  expect_identical(as.character(lk[["GSM4"]]), c("GSM4", "GSM5"))
})

test_that(".expand_study_design sostituisce i rappresentanti con i membri reali", {
  lk <- .build_member_lookup(list(mk_input_record()))
  d <- mk_design(groups = list(
    list(group_id = "g1", sample_ids = list("GSM1"), primary_role = "treated"),
    list(group_id = "g2", sample_ids = list("GSM4"), primary_role = "control")))
  out <- .expand_study_design(d, lk)
  expect_setequal(as.character(out$replicate_groups[[1]]$sample_ids),
                  c("GSM1", "GSM2", "GSM3"))
  expect_setequal(as.character(out$replicate_groups[[2]]$sample_ids),
                  c("GSM4", "GSM5"))
})

test_that("rappresentante non in mappa resta invariato (robustezza)", {
  lk <- .build_member_lookup(list(mk_input_record()))
  d <- mk_design(groups = list(
    list(group_id = "g1", sample_ids = list("GSM_unknown"), primary_role = "treated")))
  out <- .expand_study_design(d, lk)
  expect_identical(as.character(out$replicate_groups[[1]]$sample_ids), "GSM_unknown")
})

test_that("gruppo con piu' rappresentanti -> union dei membri", {
  lk <- .build_member_lookup(list(mk_input_record()))
  d <- mk_design(groups = list(
    list(group_id = "g1", sample_ids = list("GSM1", "GSM4"), primary_role = "treated")))
  out <- .expand_study_design(d, lk)
  expect_setequal(as.character(out$replicate_groups[[1]]$sample_ids),
                  c("GSM1", "GSM2", "GSM3", "GSM4", "GSM5"))
})

test_that("comparisons e altri campi restano invariati", {
  lk <- .build_member_lookup(list(mk_input_record()))
  cmp <- list(list(comparison_id = "GSE1__t_vs_c", treated_group = "g1",
                   control_group = "g2", control_type = "vehicle"))
  d <- mk_design(groups = list(
    list(group_id = "g1", sample_ids = list("GSM1"), primary_role = "treated"),
    list(group_id = "g2", sample_ids = list("GSM4"), primary_role = "control")),
    comparisons = cmp)
  out <- .expand_study_design(d, lk)
  expect_identical(out$comparisons, cmp)
  expect_identical(out$design_kind, "treatment_vs_vehicle")
  expect_identical(out$replicate_groups[[1]]$group_id, "g1")
})
