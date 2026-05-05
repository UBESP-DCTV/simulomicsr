.fake_design <- function(design_kind, role_per_sample, anchors = character()) {
  list(
    design_kind = design_kind,
    replicate_groups = lapply(seq_along(role_per_sample), function(i) {
      list(
        group_id = paste0("g", i),
        design_role = role_per_sample[[i]],
        sample_ids = list(paste0("GSM", i)),
        factor_levels = list(),
        n_replicates = 1L
      )
    }),
    comparisons = lapply(anchors, function(a) {
      list(
        comparison_id = paste0("c_", a),
        comparability_anchor = a
      )
    })
  )
}

test_that("compute_pairwise_agreement: identici -> agreement 1 su tutti i campi", {
  d1 <- .fake_design("treatment_vs_vehicle", c("perturbed", "vehicle_control"),
                    anchors = c("anchorA"))
  pa <- compute_pairwise_agreement(list(model_a = d1, model_b = d1))

  expect_equal(nrow(pa), 1L)
  expect_equal(pa$pair[1], "model_a__model_b")
  expect_equal(pa$design_kind_match[1], 1)
  expect_equal(pa$design_role_match_rate[1], 1)
  expect_equal(pa$anchor_match_rate[1], 1)
})

test_that("compute_pairwise_agreement: design_kind diversi -> 0 su quel campo", {
  d1 <- .fake_design("treatment_vs_vehicle", c("perturbed"))
  d2 <- .fake_design("case_control_disease", c("perturbed"))
  pa <- compute_pairwise_agreement(list(a = d1, b = d2))
  expect_equal(pa$design_kind_match[1], 0)
  expect_equal(pa$design_role_match_rate[1], 1)
})

test_that("compute_pairwise_agreement: design_role differente in 1 sample su 2 -> 0.5", {
  d1 <- .fake_design("treatment_vs_vehicle", c("perturbed", "vehicle_control"))
  d2 <- .fake_design("treatment_vs_vehicle", c("perturbed", "untreated_control"))
  pa <- compute_pairwise_agreement(list(a = d1, b = d2))
  expect_equal(pa$design_role_match_rate[1], 0.5)
})

test_that("aggregate_confidence_score: media pesata 0.3/0.5/0.2", {
  pa <- tibble::tibble(
    pair = "a__b",
    design_kind_match = 1,
    design_role_match_rate = 0.5,
    anchor_match_rate = 0.0
  )
  expect_equal(aggregate_confidence_score(pa),
               0.3 * 1 + 0.5 * 0.5 + 0.2 * 0.0)
})

test_that("aggregate_confidence_score: media tra le coppie quando ce ne sono 3", {
  pa <- tibble::tibble(
    pair = c("a__b", "a__c", "b__c"),
    design_kind_match = c(1, 1, 1),
    design_role_match_rate = c(1, 0.5, 0.5),
    anchor_match_rate = c(1, 1, 1)
  )
  pair_scores <- 0.3 * pa$design_kind_match +
                 0.5 * pa$design_role_match_rate +
                 0.2 * pa$anchor_match_rate
  expect_equal(aggregate_confidence_score(pa), mean(pair_scores))
})

test_that("assign_difficulty_tier: rispetta soglie 0.60 / 0.45 (calibrate v5)", {
  expect_equal(assign_difficulty_tier(0.95), "easy")
  expect_equal(assign_difficulty_tier(0.60), "easy")
  expect_equal(assign_difficulty_tier(0.59), "medium")
  expect_equal(assign_difficulty_tier(0.45), "medium")
  expect_equal(assign_difficulty_tier(0.44), "hard")
  expect_equal(assign_difficulty_tier(0.0), "hard")
})

test_that("compute_pairwise_agreement gestisce study_designs invalidi (skip)", {
  d_ok <- .fake_design("treatment_vs_vehicle", c("perturbed"))
  d_bad <- list(.invalid_reason = "schema_validation_failed")
  pa <- compute_pairwise_agreement(list(a = d_ok, b = d_bad))
  expect_equal(nrow(pa), 0L)
})
