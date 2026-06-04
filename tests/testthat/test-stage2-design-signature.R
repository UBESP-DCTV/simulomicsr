# TDD per design_signature() — RED ALERT FASE F4 opzione C (ADR-0020).
#
# La firma e' una chiave canonica deterministica sui Stage 1 facts della SOLA
# condizione sperimentale (D1 + raffinamenti sessione 13): campioni replicati
# della stessa condizione -> stessa firma; condizioni diverse -> firme diverse;
# l'identita' individuale (donor/age/sex/ancestry) e il passaggio sono ignorati.
# Proprieta': NA-aware, ordine-insensibile su set/liste.

# --- builder fixture (struttura nested come jsonlite::fromJSON(simplifyVector=FALSE)) ---

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

# --- contratto base ---

test_that("ritorna una singola stringa non vuota", {
  s <- design_signature(mk_facts())
  expect_type(s, "character")
  expect_length(s, 1L)
  expect_true(nchar(s) > 0L)
})

# --- repliche -> stessa firma ---

test_that("campioni replicati (stessa condizione) producono la stessa firma", {
  a <- mk_facts(geo = "GSM1", donor_id = "P1")
  b <- mk_facts(geo = "GSM2", donor_id = "P2")
  expect_identical(design_signature(a), design_signature(b))
})

# --- identita' individuale ignorata ---

test_that("donor/age/sex/ancestry non cambiano la firma", {
  a <- mk_facts(donor_id = "P1", age = 30, sex = "M")
  b <- mk_facts(donor_id = "P9", age = 80, sex = "F")
  expect_identical(design_signature(a), design_signature(b))
})

test_that("passage_or_state non cambia la firma (escluso)", {
  a <- mk_facts(passage = "P3")
  b <- mk_facts(passage = "P15")
  expect_identical(design_signature(a), design_signature(b))
})

# --- assi di disegno -> firme diverse ---

test_that("dose diversa produce firme diverse", {
  a <- mk_facts(perts = list(mk_pert(dose_num = 100)))
  b <- mk_facts(perts = list(mk_pert(dose_num = 500)))
  expect_false(identical(design_signature(a), design_signature(b)))
})

test_that("durata diversa produce firme diverse", {
  a <- mk_facts(perts = list(mk_pert(dur_hours = 24)))
  b <- mk_facts(perts = list(mk_pert(dur_hours = 48)))
  expect_false(identical(design_signature(a), design_signature(b)))
})

test_that("tissue_segment diverso produce firme diverse (raffinamento sessione 13)", {
  a <- mk_facts(tissue = "brain", tissue_segment = "motor cortex")
  b <- mk_facts(tissue = "brain", tissue_segment = "nucleus accumbens")
  expect_false(identical(design_signature(a), design_signature(b)))
})

test_that("agent_raw diverso con id NULL produce firme diverse (raffinamento sessione 13)", {
  a <- mk_facts(perts = list(mk_pert(agent_raw = "DEX", id = NULL)))
  b <- mk_facts(perts = list(mk_pert(agent_raw = "TEPP-46", id = NULL)))
  expect_false(identical(design_signature(a), design_signature(b)))
})

test_that("agent_raw uguale a meno del case/spazi -> stessa firma (casefold+trim)", {
  a <- mk_facts(perts = list(mk_pert(agent_raw = "DEX", id = NULL)))
  b <- mk_facts(perts = list(mk_pert(agent_raw = " dex ", id = NULL)))
  expect_identical(design_signature(a), design_signature(b))
})

# --- ordine-insensibilita' ---

test_that("ordine delle perturbazioni non conta", {
  p1 <- mk_pert(agent_raw = "drugA")
  p2 <- mk_pert(agent_raw = "drugB")
  a <- mk_facts(perts = list(p1, p2))
  b <- mk_facts(perts = list(p2, p1))
  expect_identical(design_signature(a), design_signature(b))
})

test_that("ordine dei sort_markers non conta", {
  a <- mk_facts(sort_markers = c("CD4", "CD8"))
  b <- mk_facts(sort_markers = c("CD8", "CD4"))
  expect_identical(design_signature(a), design_signature(b))
})

# --- NA-awareness ---

test_that("tissue NULL / NA / stringa vuota / assente sono equivalenti", {
  f_absent <- mk_facts(tissue = NULL)
  f_na <- mk_facts(tissue = NA)
  f_empty <- mk_facts(tissue = "")
  expect_identical(design_signature(f_absent), design_signature(f_na))
  expect_identical(design_signature(f_absent), design_signature(f_empty))
})

test_that("dose con value_raw e nessun numeric usa il raw come fallback", {
  a <- mk_facts(perts = list(mk_pert(dose_num = NULL, dose_unit = NULL,
                                     dose_raw = "high")))
  b <- mk_facts(perts = list(mk_pert(dose_num = NULL, dose_unit = NULL,
                                     dose_raw = "low")))
  expect_false(identical(design_signature(a), design_signature(b)))
})
