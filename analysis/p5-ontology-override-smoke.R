#!/usr/bin/env Rscript
# p5-ontology-override-smoke.R --- Smoke isolato per anchor v3.1 (ADR-0018).
#
# Esegue resolve_agent_canonical() + infer_kind_with_override() +
# .extract_anchor_segments() su 8 case paradigmatici (6 v3.1 + 2 v3.1.1 audit fix)
# che riproducono i pattern critici dell'audit 2026-05-24 + S1bis 2026-05-25:
#
#   1. Carnitine field-swap LLM=pathogen --> CHEBI:17126 + override LLM_CONTRADICTION
#   2. Ethanol LLM=cytokine_stim    --> CHEBI:16236 + STRONG vehicle_only override
#   3. DMSO LLM=vehicle_only         --> STR:dmso (LLM_VEHICLE_LITERAL, no override)
#   4. Resiquimod LLM=pathogen       --> CHEBI:36706 + LLM preserved + kind_chebi_zero_roles
#   5. poly(I:C) LLM=pathogen        --> CHEBI:84491 + STRONG match (adjuvant)
#   6. Disease MeSH:D011471 + case   --> MeSH:D011471 disease_vs_normal (tree C STRONG)
#   7. v3.1.1 Pregnanetriol MeSH:D011279 + case  --> OVERRIDE small_molecule
#                                                    (DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY)
#   8. v3.1.1 dihydroxyphthalic CHEBI:17199 + LLM=pathogen --> preserved + flag
#                                                    kind_chebi_zero_roles=TRUE
#
# Output: console + log analysis/p5-ontology-override-smoke.log.
# Wall: ~3 sec (carica fixture mini-dict, no full ChEBI/HGNC/MeSH dict).
#
# Gate utente S1bis -> S2bis: review qui che le 2 nuove rule chiudono il 4/4 audit.

suppressMessages({
  devtools::load_all(".")
})

cat("=== P5 ontology override smoke (anchor v3.1, ADR-0018) ===\n")
cat("Loading mini-fixture dictionaries from inst/extdata/ontology-fixtures-mini/\n")
env <- .load_ontology_dicts(refresh = TRUE,
                            fixture_dir = "inst/extdata/ontology-fixtures-mini")
cat(sprintf("  ChEBI compounds in fixture: %d\n",
            length(ls(env$chebi$by_id))))
cat(sprintf("  HGNC genes in fixture:      %d\n",
            length(ls(env$hgnc$by_hgnc_int))))
cat(sprintf("  MeSH descriptors in fixture: %d\n",
            length(ls(env$mesh$by_ui))))
cat("\n")

# Helper per costruire un sample_fact con perturbation custom (vedi
# tests/testthat/test-stage3-anchor-v31.R per il pattern completo).
make_fact <- function(agent, kind = "small_molecule", role = "treated") {
  list(
    perturbations = list(list(
      kind             = kind,
      agent_normalized = agent,
      dose             = list(value_raw = "100ng/ml"),
      duration         = list(value_raw = "6h"),
      phase            = "exposure"
    )),
    cell_context = list(
      cell_type_or_line_raw           = "HEK293",
      cell_line_cellosaurus_candidate = "CVCL_0045",
      context_kind                    = "cell_line",
      cell_state                      = "proliferating",
      subcellular_fraction            = NULL,
      tissue                          = "kidney",
      engineered_modifications        = list()
    ),
    disease_state = list(status = "healthy", mesh_id_candidate = NULL)
  )
}

# Builder per il case disease (no perturbation, mesh_id_candidate set)
make_disease_fact <- function(mesh_ui) {
  list(
    perturbations = list(),
    cell_context = list(
      cell_type_or_line_raw           = "tumor biopsy",
      cell_line_cellosaurus_candidate = NULL,
      context_kind                    = "primary",
      cell_state                      = "proliferating",
      subcellular_fraction            = NULL,
      tissue                          = "prostate",
      engineered_modifications        = list()
    ),
    disease_state = list(status = "case", mesh_id_candidate = mesh_ui)
  )
}

print_case <- function(name, segs) {
  tm <- attr(segs, "tracking_meta")
  cat(sprintf(">>> Case %s <<<\n", name))
  cat(sprintf("  agent_id_llm_original  : %s\n", tm$agent_id_llm_original))
  cat(sprintf("  agent_id_resolved      : %s\n", segs$agent_id))
  cat(sprintf("  resolution_source      : %s\n", tm$resolution_source))
  cat(sprintf("  canonical_name         : %s\n",
              tm$canonical_name %||% "<NA>"))
  cat(sprintf("  kind_effective_llm     : %s\n", tm$kind_effective_llm_original))
  cat(sprintf("  kind_effective_resolved: %s\n", segs$kind_effective))
  cat(sprintf("  kind_overridden        : %s\n",
              as.character(tm$kind_overridden)))
  cat(sprintf("  kind_override_reason   : %s\n",
              tm$kind_override_reason %||% "<NA>"))
  cat(sprintf("  kind_confidence        : %s\n", tm$kind_confidence))
  cat(sprintf("  kind_role_evidence     : %s\n",
              tm$kind_role_evidence %||% "<NA>"))
  cat(sprintf("  kind_unvalidatable     : %s\n",
              as.character(tm$kind_unvalidatable)))
  cat("\n")
}

# --- Case 1: Carnitine field-swap LLM=pathogen ------------------------------
agent1 <- list(id_database = "CHEBI", id = NULL,
               preferred_name = "17126",  # field-swap: number in pref
               type = "small_molecule")
fact1 <- make_fact(agent1, kind = "pathogen_or_aggregate_exposure")
segs1 <- .extract_anchor_segments(fact1, "treated", ontology_env = env)
print_case("1: Carnitine field-swap LLM=pathogen", segs1)

# --- Case 2: Ethanol LLM=cytokine_stim --------------------------------------
agent2 <- list(id_database = "CHEBI", id = "16236",
               preferred_name = "ethanol",
               type = "cytokine")
fact2 <- make_fact(agent2, kind = "cytokine_stimulation")
segs2 <- .extract_anchor_segments(fact2, "treated", ontology_env = env)
print_case("2: Ethanol LLM=cytokine_stim", segs2)

# --- Case 3: DMSO type=vehicle LLM_VEHICLE_LITERAL -------------------------
agent3 <- list(id_database = "CHEBI", id = "28262",
               preferred_name = "DMSO",
               type = "vehicle")
fact3 <- make_fact(agent3, kind = "vehicle_only")
segs3 <- .extract_anchor_segments(fact3, "treated", ontology_env = env)
print_case("3: DMSO LLM=vehicle (LLM_VEHICLE_LITERAL preserva intent)", segs3)

# --- Case 4: Resiquimod 0 roles LLM=pathogen --------------------------------
agent4 <- list(id_database = "CHEBI", id = "36706",
               preferred_name = "resiquimod",
               type = "small_molecule")
fact4 <- make_fact(agent4, kind = "pathogen_or_aggregate_exposure")
segs4 <- .extract_anchor_segments(fact4, "treated", ontology_env = env)
print_case("4: Resiquimod 0 roles LLM=pathogen (kind_unvalidatable)", segs4)

# --- Case 5: poly(I:C) LLM=pathogen STRONG match ---------------------------
agent5 <- list(id_database = "CHEBI", id = "84491",
               preferred_name = "Polyinosinic-polycytidylic acid",
               type = "small_molecule")
fact5 <- make_fact(agent5, kind = "pathogen_or_aggregate_exposure")
segs5 <- .extract_anchor_segments(fact5, "treated", ontology_env = env)
print_case("5: poly(I:C) LLM=pathogen STRONG match (adjuvant)", segs5)

# --- Case 6: Disease MeSH:D011471 (Prostatic Neoplasms, tree C) -----------
fact6 <- make_disease_fact("D011471")
segs6 <- .extract_anchor_segments(fact6, "case", ontology_env = env)
print_case("6: Disease MeSH:D011471 (tree C) + role=case (STRONG match)", segs6)

# --- v3.1.1 Case 7: Pregnanetriol MeSH:D011279 (tree D sterol) -----------
# Audit case 4/4: MeSH D04 sterol con role=case (LLM=disease_vs_normal).
# Atteso: DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY override a small_molecule.
fact7 <- make_disease_fact("D011279")
segs7 <- .extract_anchor_segments(fact7, "case", ontology_env = env)
print_case("7 [v3.1.1]: Pregnanetriol MeSH:D011279 (tree D sterol) + role=case", segs7)

# --- v3.1.1 Case 8: dihydroxyphthalic CHEBI:17199 LLM=pathogen ------------
# Audit case 2/4: ChEBI compound esiste ma 0 roles. NON distinguibile da
# Resiquimod (Case 4) via ChEBI alone. Atteso: LLM preserved + flag
# kind_chebi_zero_roles=TRUE per Layer B shortlist filter.
agent8 <- list(id_database = "CHEBI", id = "17199",
               preferred_name = "4,5-dihydroxyphthalic acid",
               type = "small_molecule")
fact8 <- make_fact(agent8, kind = "pathogen_or_aggregate_exposure")
segs8 <- .extract_anchor_segments(fact8, "treated", ontology_env = env)
print_case("8 [v3.1.1]: dihydroxyphthalic CHEBI:17199 (0 roles) + LLM=pathogen", segs8)

# --- Summary --------------------------------------------------------------
cat("=== Summary ===\n")
all_cases <- list(
  list(name = "1 Carnitine field-swap",         segs = segs1,
       expect_override = TRUE,  expect_resolution = "CHEBI_FIELDSWAP",
       expect_chebi_zero_roles = FALSE),
  list(name = "2 Ethanol cytokine wrong",       segs = segs2,
       expect_override = TRUE,  expect_resolution = "CHEBI_DIRECT",
       expect_chebi_zero_roles = FALSE),
  list(name = "3 DMSO vehicle",                 segs = segs3,
       expect_override = FALSE, expect_resolution = "LLM_VEHICLE_LITERAL",
       expect_chebi_zero_roles = FALSE),
  list(name = "4 Resiquimod 0 roles",           segs = segs4,
       expect_override = FALSE, expect_resolution = "CHEBI_DIRECT",
       expect_chebi_zero_roles = TRUE),
  list(name = "5 poly(I:C) STRONG match",       segs = segs5,
       expect_override = FALSE, expect_resolution = "CHEBI_DIRECT",
       expect_chebi_zero_roles = FALSE),
  list(name = "6 Disease MeSH tree C",          segs = segs6,
       expect_override = FALSE, expect_resolution = "MESH_DIRECT",
       expect_chebi_zero_roles = FALSE),
  list(name = "7 [v3.1.1] Pregnanetriol tree D",segs = segs7,
       expect_override = TRUE,  expect_resolution = "MESH_DIRECT",
       expect_chebi_zero_roles = FALSE),
  list(name = "8 [v3.1.1] dihydroxyphthalic",   segs = segs8,
       expect_override = FALSE, expect_resolution = "CHEBI_DIRECT",
       expect_chebi_zero_roles = TRUE)
)

n_pass <- 0L
for (case in all_cases) {
  tm <- attr(case$segs, "tracking_meta")
  ok_resolution <- identical(tm$resolution_source, case$expect_resolution)
  ok_override   <- identical(isTRUE(tm$kind_overridden), case$expect_override)
  ok_zero_roles <- identical(isTRUE(tm$kind_chebi_zero_roles),
                              isTRUE(case$expect_chebi_zero_roles))
  status <- if (ok_resolution && ok_override && ok_zero_roles) "OK" else "FAIL"
  if (ok_resolution && ok_override && ok_zero_roles) n_pass <- n_pass + 1L
  cat(sprintf("  [%s] Case %-32s : src=%-22s ovr=%-5s zero_roles=%-5s\n",
              status, case$name,
              tm$resolution_source,
              as.character(isTRUE(tm$kind_overridden)),
              as.character(isTRUE(tm$kind_chebi_zero_roles))))
}
cat(sprintf("\n%d/%d cases PASS\n", n_pass, length(all_cases)))

if (n_pass != length(all_cases)) {
  quit(status = 1L)
}
invisible(NULL)
