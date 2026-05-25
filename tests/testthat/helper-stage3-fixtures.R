# helper-stage3-fixtures.R — fixture condivise per test Stage 3
#
# Caricato automaticamente da testthat prima di ogni file test-stage3-*.R.
# Contiene helper per costruire sample_facts e stage2 records mock.

#' Costruisce un sample_fact fixture minimale per i test Stage 3
#'
#' Anchor v3.1 (ADR-0018): \code{agent_normalized$id_database = "ChEMBL"} per
#' triggerare CHEMBL_NAKED_NOLOOKUP nel resolver (deterministico, no dict
#' lookup). Canonical id risultante: "ChEMBL:CHEMBL941".
#' @keywords internal
make_test_sample_fact <- function() {
  list(
    perturbations = list(list(
      kind = "small_molecule",
      agent_normalized = list(id_database = "ChEMBL", id = "CHEMBL941",
                              preferred_name = "imatinib",
                              type = "small_molecule"),
      dose = list(value_raw = "10nM"),
      duration = list(value_raw = "24h"),
      phase = "exposure"
    )),
    cell_context = list(
      cell_type_or_line_raw = "HUVEC",
      cell_line_cellosaurus_candidate = "CVCL_2959",
      context_kind = "cell_line",
      cell_state = "proliferating",
      subcellular_fraction = NULL,
      tissue = "endothelium",
      engineered_modifications = list()
    ),
    disease_state = list(status = "healthy", mesh_id_candidate = NULL)
  )
}

#' Costruisce input completo mock per build_stage3_clusters
#'
#' Stage2 mock con 1 studio GSE100, 1 comparison c1:
#' - g1 (treated): GSM1 + GSM2 (n=2, REM eligible)
#' - g2 (control): GSM3 + GSM4 (n=2, REM eligible)
#' - GSM5 group separato: per group-mode test
#' - stage1_master: 5 sample (GSM3 ha dose diversa dal default)
#'
#' @keywords internal
make_mock_stage3_input <- function() {
  # GSM3: sample con dose diversa -> anchor diverso dal trattato
  gsm3_fact <- make_test_sample_fact()
  gsm3_fact$perturbations[[1]]$kind <- "none"
  # Vehicle literal: id_database=NULL, type="vehicle" -> LLM_VEHICLE_LITERAL
  # canonical = "STR:vehicle"
  gsm3_fact$perturbations[[1]]$agent_normalized <- list(id = "unknown",
                                                         preferred_name = "vehicle",
                                                         type = "vehicle")
  gsm3_fact$perturbations[[1]]$dose <- list(value_raw = "nodose")

  # GSM5: sample per group-mode separato (stesso trattamento di GSM1)
  gsm5_fact <- make_test_sample_fact()

  list(
    stage1_master = list(
      "GSM1" = make_test_sample_fact(),
      "GSM2" = make_test_sample_fact(),
      "GSM3" = gsm3_fact,
      "GSM4" = gsm3_fact,
      "GSM5" = gsm5_fact
    ),
    stage2_master = list(
      list(
        series_id = "GSE100",
        replicate_groups = list(
          list(group_id = "g1", sample_ids = c("GSM1", "GSM2"),
               n = 2L, primary_role = "treated"),
          list(group_id = "g2", sample_ids = c("GSM3", "GSM4"),
               n = 2L, primary_role = "control"),
          list(group_id = "g3", sample_ids = c("GSM5"),
               n = 1L, primary_role = "treated")
        ),
        comparisons = list(
          list(
            comparison_id = "c1",
            treated_group = "g1",
            control_group = "g2",
            control_type  = "vehicle",
            design_kind   = "treatment_vs_vehicle"
          )
        )
      )
    )
  )
}
