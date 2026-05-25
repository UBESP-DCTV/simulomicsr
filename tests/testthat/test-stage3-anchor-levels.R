# Helper per costruire un sample_fact fixture
# Nota: helper-stage3-fixtures.R ne definisce uno SHARED che ha lo stesso nome.
# Questo locale lo sovrascrive intenzionalmente (id_database="ChEMBL" per
# triggerare CHEMBL_NAKED_NOLOOKUP -> "ChEMBL:CHEMBL941" deterministico).
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

test_that(".build_anchor_for_level a L0 equivale a make_anchor() (13 segmenti)", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  anchor_l0 <- simulomicsr:::.build_anchor_for_level(
    stage1_facts = fact,
    stage2_role = "treated",
    level = 0L,
    tier_assignment = cfg$tier_assignment
  )

  # Stesso numero di segmenti di make_anchor()
  expect_equal(length(strsplit(anchor_l0, "\\|")[[1]]), 13L)
})

test_that(".build_anchor_for_level L0 e' value-identical a make_anchor()", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  anchor_l0 <- simulomicsr:::.build_anchor_for_level(
    fact, "treated", 0L, cfg$tier_assignment
  )
  anchor_make <- make_anchor(fact, "treated")

  expect_identical(anchor_l0, anchor_make)
})

test_that(".build_anchor_for_level L1 ha 12 segmenti (drop has_engineered)", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  anchor_l1 <- simulomicsr:::.build_anchor_for_level(
    fact, "treated", 1L, cfg$tier_assignment
  )
  expect_equal(length(strsplit(anchor_l1, "\\|")[[1]]), 12L)
})

test_that(".build_anchor_for_level L4 ha 3 segmenti (solo Tier S)", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  anchor_l4 <- simulomicsr:::.build_anchor_for_level(
    fact, "treated", 4L, cfg$tier_assignment
  )
  segs <- strsplit(anchor_l4, "\\|")[[1]]
  expect_equal(length(segs), 3L)
  # Tier S: kind_effective, agent_id, tissue (anchor v3.1 canonical)
  expect_equal(segs[1], "small_molecule")        # kind_effective (LLM preserved, NONE confidence)
  expect_equal(segs[2], "ChEMBL:CHEMBL941")      # agent_id canonical via CHEMBL_NAKED_NOLOOKUP
  expect_equal(segs[3], "endothelium")           # tissue
})

test_that(".build_anchor_for_level e' deterministico (stesso input -> stesso output)", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  a1 <- simulomicsr:::.build_anchor_for_level(fact, "treated", 2L, cfg$tier_assignment)
  a2 <- simulomicsr:::.build_anchor_for_level(fact, "treated", 2L, cfg$tier_assignment)
  expect_identical(a1, a2)
})

test_that(".extract_hard_filters restituisce subcellular + context_kind", {
  fact <- make_test_sample_fact()
  cfg <- stage3_default_config()

  hf <- simulomicsr:::.extract_hard_filters(fact, cfg$tier_assignment)
  expect_named(hf, c("subcellular", "context_kind"))
  expect_equal(hf$context_kind, "cell_line")
  expect_equal(hf$subcellular, "whole_cell")  # default quando NULL
})

test_that(".extract_anchor_segments restituisce 13 segmenti named", {
  fact <- make_test_sample_fact()

  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated")
  expect_named(segs, c(
    "kind_effective", "agent_id", "variant_label", "dose_canonical",
    "duration_canonical", "phase_canonical", "cell_id", "context_kind",
    "cell_state", "subcellular", "tissue", "disease_status", "has_engineered"
  ))
  expect_equal(segs$kind_effective, "small_molecule")
  expect_equal(segs$agent_id, "ChEMBL:CHEMBL941")  # v3.1 canonical
  expect_equal(segs$tissue, "endothelium")
})

test_that(".extract_anchor_segments anchor v3.1: tracking_meta attr presente", {
  fact <- make_test_sample_fact()
  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "treated")
  tm <- attr(segs, "tracking_meta")
  expect_true(is.list(tm))
  expect_equal(tm$resolution_source, "CHEMBL_NAKED_NOLOOKUP")
  expect_equal(tm$agent_id_resolved, "ChEMBL:CHEMBL941")
  expect_equal(tm$kind_effective_llm_original, "small_molecule")
  expect_equal(tm$kind_effective_resolved, "small_molecule")
  expect_false(tm$kind_overridden)
  expect_true(tm$kind_unvalidatable)  # ChEMBL non ha kind inference -> NONE
})

test_that("monotonicity: anchor a L_high e' subset di anchor a L_low (lessicalmente)", {
  # Per ogni sample, segmenti di L_high subset di L_low (in termini di kept_segments)
  cfg <- stage3_default_config()
  ta <- cfg$tier_assignment

  for (L in 0L:3L) {
    kept_L     <- simulomicsr:::.kept_segments_at_level(ta, L)
    kept_Lplus <- simulomicsr:::.kept_segments_at_level(ta, L + 1L)
    expect_true(all(kept_Lplus %in% kept_L),
                info = sprintf("L%d+1 segments must subset L%d segments", L, L))
  }
})

test_that("disease_vs_normal override: stage2_role=case produce kind_effective=disease_vs_normal", {
  fact <- make_test_sample_fact()
  fact$disease_state$status <- "case"
  fact$disease_state$mesh_id_candidate <- "D003920"  # diabetes mellitus

  cfg <- stage3_default_config()
  segs <- simulomicsr:::.extract_anchor_segments(fact, stage2_role = "case")
  expect_equal(segs$kind_effective, "disease_vs_normal")
  # Anchor v3.1: MeSH UI canonicalizzato con prefix "MeSH:"
  expect_equal(segs$agent_id, "MeSH:D003920")
})
