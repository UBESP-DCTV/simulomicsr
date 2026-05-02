.fact_with <- function(perturbation_kind = "small_molecule",
                      cell_type_or_line_raw = "MCF-7") {
  list(
    cell_context = list(cell_type_or_line_raw = cell_type_or_line_raw),
    perturbations = list(list(kind = perturbation_kind))
  )
}

test_that("stage1_schema_validity_rate ritorna n_valid / (n_valid + n_invalid)", {
  res <- stage1_schema_validity_rate(
    facts_validated = list(.fact_with(), .fact_with(), .fact_with(), .fact_with()),
    facts_invalid   = list(.fact_with())
  )
  expect_equal(res$n_validated, 4L)
  expect_equal(res$n_invalid,    1L)
  expect_equal(res$n_total,      5L)
  expect_equal(res$validity_rate, 0.8)
})

test_that("stage1_schema_validity_rate gestisce zero invalidi", {
  res <- stage1_schema_validity_rate(
    facts_validated = list(.fact_with()),
    facts_invalid   = list()
  )
  expect_equal(res$validity_rate, 1.0)
})

test_that("stage1_schema_validity_rate fallisce su zero totali", {
  expect_error(
    stage1_schema_validity_rate(facts_validated = list(),
                                 facts_invalid   = list()),
    class = "simulomicsr_eval_metrics_empty"
  )
})

test_that("stage1_recall_key_fields conta sample con perturbations.kind != none/unclear/null e cell_type non null", {
  facts <- list(
    .fact_with(perturbation_kind = "small_molecule"),
    .fact_with(perturbation_kind = "none"),
    .fact_with(perturbation_kind = "unclear"),
    .fact_with(perturbation_kind = "cytokine_stimulation",
               cell_type_or_line_raw = NULL)
  )
  res <- stage1_recall_key_fields(facts)
  expect_equal(res$n_samples, 4L)
  expect_equal(res$n_with_perturbation,    2L)  # small_molecule, cytokine_stim
  expect_equal(res$n_with_cell_type,       3L)  # solo l'ultimo ha NULL
  expect_equal(res$recall_perturbation, 0.5)
  expect_equal(res$recall_cell_type,    0.75)
})
