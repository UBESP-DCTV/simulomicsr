# Builder fixture condivisi per i test della firma di disegno Stadio 2
# (design_signature + build_study_conditions). Struttura nested come
# jsonlite::fromJSON(simplifyVector = FALSE).

mk_pert <- function(kind = "small_molecule", agent_raw = "DEX",
                    type = "small_molecule", db = NULL, id = NULL,
                    dose_num = 100, dose_unit = "nM", dose_raw = NULL,
                    dur_hours = 24, dur_raw = NULL, phase = "exposure",
                    zero = FALSE, negctrl = FALSE) {
  list(
    kind = kind,
    agent_raw = agent_raw,
    agent_normalized = list(type = type, id_database = db, id = id,
                            preferred_name = NULL, collection = NULL),
    dose = list(value_raw = dose_raw, value_numeric = dose_num, unit = dose_unit),
    duration = list(value_raw = dur_raw, value_hours = dur_hours,
                    is_zero_timepoint = zero),
    phase = phase, temporal_order = 1L,
    is_negative_control = negctrl, mediated_effect = NULL
  )
}

mk_facts <- function(geo = "GSM1", series = "GSE1",
                     tissue = "liver", tissue_segment = NULL,
                     donor_id = NULL, age = NULL, sex = NULL,
                     passage = NULL, sort_markers = c("CD4", "CD8"),
                     perts = list(mk_pert())) {
  list(
    geo_accession = geo, series_id = series,
    organism = "Homo sapiens", host_organism = NULL,
    cell_context = list(
      cell_type_or_line_raw = "hepatocyte",
      cell_line_cellosaurus_candidate = NULL,
      tissue = tissue, tissue_segment = tissue_segment,
      passage_or_state = passage, context_kind = "primary_tissue",
      developmental_stage = NULL, cell_state = NULL,
      subcellular_fraction = NULL,
      engineered_modifications = list(),
      co_culture_partners = list(),
      sort_markers = as.list(sort_markers),
      cell_composition_estimates = list()
    ),
    disease_state = list(term_raw = NULL, mesh_id_candidate = NULL, status = "none"),
    perturbations = perts,
    technical_treatments = list(),
    patient_metadata = list(donor_id = donor_id, age = age, sex = sex,
      ancestry_or_population = NULL, ancestry_admixture = NULL,
      clinical_response = NULL, survival_group = NULL, stage = NULL,
      condition = NULL, visit_or_timepoint = NULL),
    extraction = list(schema_version = "stage1.v3", model = "test",
      confidence = 1, ambiguity_flags = list(),
      raw_input_hash = paste0("sha256:", strrep("0", 64)))
  )
}

# Entry di campione come consumato da .build_study_conditions: il geo_accession
# del campione + i suoi sample_facts.
mk_sample <- function(geo, facts = NULL, ...) {
  if (is.null(facts)) facts <- mk_facts(geo = geo, ...)
  list(geo_accession = geo, sample_facts = facts)
}
