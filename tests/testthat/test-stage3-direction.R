test_that("direction canonical: vehicle control + perturbed treated -> canonical", {
  treated_segs <- list(kind_effective = "small_molecule", agent_id = "CHEMBL941")
  control_segs <- list(kind_effective = "vehicle_only", agent_id = "DMSO")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "vehicle"
  )
  expect_equal(result, "canonical")
})

test_that("direction swapped: vehicle in treated_group + perturbed in control_group", {
  treated_segs <- list(kind_effective = "vehicle_only", agent_id = "DMSO")
  control_segs <- list(kind_effective = "small_molecule", agent_id = "CHEMBL941")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "vehicle"
  )
  expect_equal(result, "swapped")
})

test_that("direction ambiguous: control_type=secondary_arm", {
  treated_segs <- list(kind_effective = "small_molecule", agent_id = "CHEMBL941")
  control_segs <- list(kind_effective = "small_molecule", agent_id = "CHEMBL112")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "secondary_arm"
  )
  expect_equal(result, "ambiguous")
})

test_that("direction indeterminate: anchor incompleti", {
  treated_segs <- list(kind_effective = "unclear", agent_id = "unknown")
  control_segs <- list(kind_effective = "vehicle_only", agent_id = "DMSO")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "vehicle"
  )
  expect_equal(result, "indeterminate")
})

test_that("direction canonical: disease_normal + disease in treated -> canonical", {
  treated_segs <- list(kind_effective = "disease_vs_normal", agent_id = "D003920")
  control_segs <- list(kind_effective = "disease_vs_normal", agent_id = "D003920")
  # In disease_vs_normal designs, ENTRAMBI hanno kind_effective="disease_vs_normal"
  # by anchor function override. La distinzione e' nel disease_status.

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "disease_normal"
  )
  expect_equal(result, "canonical")
})

test_that("direction canonical: control_type=untreated comportamento simmetrico a vehicle", {
  treated_segs <- list(kind_effective = "cytokine_stim", agent_id = "HGNC:TNF")
  control_segs <- list(kind_effective = "none", agent_id = "unknown")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "untreated"
  )
  expect_equal(result, "canonical")
})

test_that("direction swapped: control_type=untreated ma none in treated_group", {
  treated_segs <- list(kind_effective = "none", agent_id = "unknown")
  control_segs <- list(kind_effective = "cytokine_stim", agent_id = "HGNC:TNF")

  result <- simulomicsr:::.check_direction_canonical(
    treated_anchor_segments = treated_segs,
    control_anchor_segments = control_segs,
    control_type = "untreated"
  )
  expect_equal(result, "swapped")
})
