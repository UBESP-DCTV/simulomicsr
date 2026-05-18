# Helper: construct un record di input per Stage 3
make_test_record <- function(record_id = "GSE100__cmp01",
                              mode = "pair",
                              kind_treated = "small_molecule",
                              agent_treated = "CHEMBL941",
                              tissue_treated = "endothelium",
                              kind_control = "vehicle_only",
                              agent_control = "DMSO",
                              tissue_control = "endothelium",
                              n_treated = 3, n_control = 3,
                              control_type = "vehicle") {
  list(
    record_id = record_id,
    mode = mode,
    series_id = sub("__.*$", "", record_id),
    treated_anchor_segments = list(
      kind_effective = kind_treated, agent_id = agent_treated,
      tissue = tissue_treated, variant_label = "wt",
      disease_status = "healthy", phase_canonical = "exposure",
      cell_state = "proliferating", cell_id = "HUVEC",
      dose_canonical = "10nM", duration_canonical = "24h",
      has_engineered = "false", subcellular = "whole_cell",
      context_kind = "cell_line"
    ),
    control_anchor_segments = list(
      kind_effective = kind_control, agent_id = agent_control,
      tissue = tissue_control, variant_label = "wt",
      disease_status = "healthy", phase_canonical = "exposure",
      cell_state = "proliferating", cell_id = "HUVEC",
      dose_canonical = "nodose", duration_canonical = "24h",
      has_engineered = "false", subcellular = "whole_cell",
      context_kind = "cell_line"
    ),
    n_treated_group = n_treated,
    n_control_group = n_control,
    control_type = control_type
  )
}

test_that("eligible record (pair) passes filter cleanly", {
  rec <- make_test_record()
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_length(result$eligible, 1L)
  expect_length(result$non_clusterable, 0L)
})

test_that("tier_s_incomplete: kind=unclear -> non_clusterable", {
  rec <- make_test_record(kind_treated = "unclear")
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_length(result$eligible, 0L)
  expect_length(result$non_clusterable, 1L)
  expect_equal(result$non_clusterable[[1]]$reason, "tier_s_incomplete")
})

test_that("tier_s_incomplete: agent=unknown -> non_clusterable", {
  rec <- make_test_record(agent_treated = "unknown")
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "tier_s_incomplete")
})

test_that("tier_s_incomplete: tissue=na -> non_clusterable", {
  rec <- make_test_record(tissue_treated = "na")
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "tier_s_incomplete")
})

test_that("rem_eligibility_n1: n_treated=1 -> non_clusterable per pair", {
  rec <- make_test_record(n_treated = 1)
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "rem_eligibility_n1")
  expect_match(result$non_clusterable[[1]]$details, "n_treated_group=1")
})

test_that("rem_eligibility_n1: n_control=1 -> non_clusterable per pair", {
  rec <- make_test_record(n_control = 1)
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "rem_eligibility_n1")
  expect_match(result$non_clusterable[[1]]$details, "n_control_group=1")
})

test_that("group mode: n_treated=1 e' eligible (no rem_eligibility filter)", {
  rec <- make_test_record(mode = "group", n_treated = 1)
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_length(result$eligible, 1L)
})

test_that("multiple records: separati corretti tra eligible e non_clusterable", {
  recs <- list(
    make_test_record(record_id = "GSE1__cmp01"),                          # eligible
    make_test_record(record_id = "GSE2__cmp01", kind_treated = "unclear"), # tier_s
    make_test_record(record_id = "GSE3__cmp01", n_treated = 1),            # n1
    make_test_record(record_id = "GSE4__cmp01")                           # eligible
  )
  result <- simulomicsr:::.filter_eligible_records(recs)
  expect_length(result$eligible, 2L)
  expect_length(result$non_clusterable, 2L)
})

test_that("vehicle_only + agent=unknown e' eligible (control records legitimi)", {
  rec <- make_test_record(
    kind_control = "vehicle_only",
    agent_control = "unknown"
  )
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_length(result$eligible, 1L)
  expect_length(result$non_clusterable, 0L)
})

test_that("none + agent=unknown e' eligible (baseline records legitimi)", {
  # Group mode con kind=none deve passare (baseline pool per mega-analisi)
  rec <- make_test_record(
    mode = "group",
    kind_treated = "none",
    agent_treated = "unknown"
  )
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_length(result$eligible, 1L)
})

test_that("small_molecule + agent=unknown rimane non_clusterable (perturbazione non risolta)", {
  rec <- make_test_record(
    kind_treated = "small_molecule",
    agent_treated = "unknown"
  )
  result <- simulomicsr:::.filter_eligible_records(list(rec))
  expect_equal(result$non_clusterable[[1]]$reason, "tier_s_incomplete")
})
