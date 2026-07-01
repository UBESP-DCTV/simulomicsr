# Test per R/anchor-parse.R
#
# Coprono:
# - parse_anchor_key() su L0..L4
# - Error su mismatch length(kept) vs length(segs)
# - Roundtrip: .build_anchor_for_level() -> parse_anchor_key() -> segs originali
#
# Strategia: usiamo .extract_anchor_segments() + .build_anchor_for_level()
# come reference per generare anchor key reali, in modo che il roundtrip
# verifichi l'inversione esatta della logica di drop.

# Helper: fixture sample_fact con tutti i 13 segmenti popolati in modo
# distinguibile (per disambiguare l'ordine canonical in roundtrip).
make_full_sample_fact <- function() {
  list(
    perturbations = list(list(
      kind = "small_molecule",
      # Anchor v3.1: id_database="ChEMBL" -> CHEMBL_NAKED_NOLOOKUP canonical
      # "ChEMBL:CHEMBL941" (deterministico, no dict lookup).
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

CANONICAL_NAMES <- c(
  "kind_effective", "agent_id", "variant_label",
  "dose_canonical", "duration_canonical", "phase_canonical",
  "cell_id", "context_kind", "cell_state",
  "subcellular", "tissue", "disease_status", "has_engineered"
)

# ===========================================================================
# Output shape: sempre 13 elementi named, NA per droppati
# ===========================================================================

test_that("parse_anchor_key L0 ritorna 13 segmenti, tutti non-NA", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key  <- simulomicsr:::.build_anchor_for_level(fact, "treated", 0L,
                                                cfg$tier_assignment)

  res <- parse_anchor_key(key, level = 0L)

  expect_type(res, "list")
  expect_length(res, 13L)
  expect_named(res, CANONICAL_NAMES)
  expect_true(all(!vapply(res, is.na, logical(1L))))
  expect_identical(res$kind_effective, "small_molecule")
  expect_identical(res$agent_id, "ChEMBL:CHEMBL941")
  expect_identical(res$tissue, "endothelium")
  expect_identical(res$has_engineered, "false")
})

test_that("parse_anchor_key L1 droppa has_engineered (NA), 12 valori non-NA", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key  <- simulomicsr:::.build_anchor_for_level(fact, "treated", 1L,
                                                cfg$tier_assignment)

  res <- parse_anchor_key(key, level = 1L)

  expect_length(res, 13L)
  expect_named(res, CANONICAL_NAMES)
  expect_true(is.na(res$has_engineered))
  # Tutti gli altri non-NA
  non_dropped <- setdiff(CANONICAL_NAMES, "has_engineered")
  expect_true(all(!vapply(res[non_dropped], is.na, logical(1L))))
})

test_that("parse_anchor_key L2 droppa tier D + C (has_engineered, dose, duration)", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key  <- simulomicsr:::.build_anchor_for_level(fact, "treated", 2L,
                                                cfg$tier_assignment)

  res <- parse_anchor_key(key, level = 2L)

  expect_length(res, 13L)
  dropped_l2 <- c("has_engineered", "dose_canonical", "duration_canonical")
  for (nm in dropped_l2) {
    expect_true(is.na(res[[nm]]), info = sprintf("L2 droppato: %s", nm))
  }
  expect_identical(res$kind_effective, "small_molecule")
  expect_identical(res$agent_id, "ChEMBL:CHEMBL941")
  expect_identical(res$tissue, "endothelium")
})

test_that("parse_anchor_key L3 droppa tier D + C + B", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key  <- simulomicsr:::.build_anchor_for_level(fact, "treated", 3L,
                                                cfg$tier_assignment)

  res <- parse_anchor_key(key, level = 3L)

  expect_length(res, 13L)
  dropped_l3 <- c("has_engineered",
                  "dose_canonical", "duration_canonical",
                  "cell_state", "cell_id")
  for (nm in dropped_l3) {
    expect_true(is.na(res[[nm]]), info = sprintf("L3 droppato: %s", nm))
  }
  # kind_effective + agent_id + tissue ancora presenti
  expect_identical(res$kind_effective, "small_molecule")
  expect_identical(res$tissue, "endothelium")
})

test_that("parse_anchor_key L4 ritorna solo Tier S (kind_effective + agent_id + tissue)", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key  <- simulomicsr:::.build_anchor_for_level(fact, "treated", 4L,
                                                cfg$tier_assignment)

  res <- parse_anchor_key(key, level = 4L)

  expect_length(res, 13L)
  expect_named(res, CANONICAL_NAMES)
  # Solo i 3 tier S sono non-NA
  non_na <- vapply(res, function(x) !is.na(x), logical(1L))
  expect_identical(names(res)[non_na], c("kind_effective", "agent_id", "tissue"))
  expect_identical(res$kind_effective, "small_molecule")
  expect_identical(res$agent_id, "ChEMBL:CHEMBL941")
  expect_identical(res$tissue, "endothelium")
})

# ===========================================================================
# Error handling
# ===========================================================================

test_that("parse_anchor_key solleva errore su segmenti count mismatch col level", {
  # Anchor L0 (13 segmenti) parsato con level=4 (atteso 3)
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key_l0 <- simulomicsr:::.build_anchor_for_level(fact, "treated", 0L,
                                                  cfg$tier_assignment)
  expect_error(
    parse_anchor_key(key_l0, level = 4L),
    "13 segmenti.*atteso 3"
  )

  # Anchor L4 (3 segmenti) parsato con level=0 (atteso 13)
  key_l4 <- simulomicsr:::.build_anchor_for_level(fact, "treated", 4L,
                                                  cfg$tier_assignment)
  expect_error(
    parse_anchor_key(key_l4, level = 0L),
    "3 segmenti.*atteso 13"
  )
})

# ===========================================================================
# Roundtrip: .build_anchor_for_level() -> parse_anchor_key() su sample reale
# ===========================================================================

test_that("roundtrip: parse_anchor_key inverte .build_anchor_for_level a tutti i level", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()

  # Reference: i 13 segmenti raw, prima del drop
  segs_full <- simulomicsr:::.extract_anchor_segments(fact, "treated")

  for (L in 0L:4L) {
    key <- simulomicsr:::.build_anchor_for_level(fact, "treated", L,
                                                  cfg$tier_assignment)
    res <- parse_anchor_key(key, level = L)

    # Determina i kept_names a questo level (replicando la logica)
    if (L == 4L) {
      kept <- CANONICAL_NAMES[CANONICAL_NAMES %in% cfg$tier_assignment$S]
    } else {
      dropped <- simulomicsr:::.dropped_segments_at_level(cfg$tier_assignment, L)
      kept <- CANONICAL_NAMES[!CANONICAL_NAMES %in% dropped]
    }

    # Per ogni kept segment, il valore deve matchare quello di segs_full
    for (nm in kept) {
      expect_identical(
        res[[nm]], as.character(segs_full[[nm]]),
        info = sprintf("L%d roundtrip segment '%s'", L, nm)
      )
    }
    # Per ogni dropped, deve essere NA_character_
    for (nm in setdiff(CANONICAL_NAMES, kept)) {
      expect_true(is.na(res[[nm]]),
                  info = sprintf("L%d dropped segment '%s' deve essere NA", L, nm))
    }
  }
})

# ===========================================================================
# tier_assignment default da stage3_default_config()
# ===========================================================================

test_that("parse_anchor_key usa stage3_default_config() se tier_assignment NULL", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key  <- simulomicsr:::.build_anchor_for_level(fact, "treated", 2L,
                                                cfg$tier_assignment)

  # NULL default deve dare lo stesso risultato di passaggio esplicito
  res_default  <- parse_anchor_key(key, level = 2L)
  res_explicit <- parse_anchor_key(key, level = 2L,
                                   tier_assignment = cfg$tier_assignment)
  expect_identical(res_default, res_explicit)
})

# ===========================================================================
# Pair-mode: anchor_key = treated__VS__control[__CT_type]
# ===========================================================================

test_that("parse_anchor_key mode='pair' splits treated/control + ritorna 13 named", {
  fact_t <- make_full_sample_fact()
  fact_c <- make_full_sample_fact()
  # Modifica il control per distinguere visualmente
  fact_c$perturbations <- list(list(kind = "vehicle_only", phase = "exposure"))
  cfg <- stage3_default_config()

  key_t <- simulomicsr:::.build_anchor_for_level(fact_t, "treated", 2L,
                                                  cfg$tier_assignment)
  key_c <- simulomicsr:::.build_anchor_for_level(fact_c, "control", 2L,
                                                  cfg$tier_assignment)
  pair_key <- sprintf("%s__VS__%s", key_t, key_c)

  res <- parse_anchor_key(pair_key, level = 2L, mode = "pair")

  expect_type(res, "list")
  expect_named(res, c("treated", "control", "comparison_type"),
               ignore.order = TRUE)
  expect_null(res$comparison_type)
  # treated lato: 13 named list con valori del treated original
  expect_length(res$treated, 13L)
  expect_identical(res$treated$kind_effective, "small_molecule")
  expect_identical(res$treated$tissue, "endothelium")
  # control lato: vehicle_only
  expect_identical(res$control$kind_effective, "vehicle_only")
})

test_that("parse_anchor_key mode='pair' estrae comparison_type da __CT_<type>", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key_t <- simulomicsr:::.build_anchor_for_level(fact, "treated", 0L,
                                                  cfg$tier_assignment)
  key_c <- simulomicsr:::.build_anchor_for_level(fact, "control", 0L,
                                                  cfg$tier_assignment)
  pair_key_ct <- sprintf("%s__VS__%s__CT_vehicle", key_t, key_c)

  res <- parse_anchor_key(pair_key_ct, level = 0L, mode = "pair")
  expect_identical(res$comparison_type, "vehicle")
  expect_identical(res$treated$kind_effective, "small_molecule")
})

test_that("parse_anchor_key mode='pair' solleva errore su missing __VS__", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key <- simulomicsr:::.build_anchor_for_level(fact, "treated", 0L,
                                                cfg$tier_assignment)
  # Manca __VS__: non e' pair
  expect_error(
    parse_anchor_key(key, level = 0L, mode = "pair"),
    "deve contenere esattamente un '__VS__'"
  )
})

# ===========================================================================
# extract_anchor_summary: wrapper convenience per summary card Layer B
# ===========================================================================

test_that("extract_anchor_summary group L0 ritorna 3 segmenti popolati", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key  <- simulomicsr:::.build_anchor_for_level(fact, "treated", 0L,
                                                cfg$tier_assignment)

  res <- extract_anchor_summary(key, level = 0L)

  expect_type(res, "list")
  expect_named(res, c("kind_effective", "agent_id", "tissue"))
  expect_identical(res$kind_effective, "small_molecule")
  expect_identical(res$agent_id, "ChEMBL:CHEMBL941")
  expect_identical(res$tissue, "endothelium")
})

test_that("extract_anchor_summary pair L2 estrae dal lato treated", {
  fact_t <- make_full_sample_fact()
  fact_c <- make_full_sample_fact()
  fact_c$perturbations <- list(list(kind = "vehicle_only", phase = "exposure"))
  cfg <- stage3_default_config()

  key_t <- simulomicsr:::.build_anchor_for_level(fact_t, "treated", 2L,
                                                  cfg$tier_assignment)
  key_c <- simulomicsr:::.build_anchor_for_level(fact_c, "control", 2L,
                                                  cfg$tier_assignment)
  pair_key <- sprintf("%s__VS__%s__CT_vehicle", key_t, key_c)

  res <- extract_anchor_summary(pair_key, level = 2L, mode = "pair")

  expect_named(res, c("kind_effective", "agent_id", "tissue"))
  # Lato treated: small_molecule, CHEMBL941, endothelium
  expect_identical(res$kind_effective, "small_molecule")
  expect_identical(res$agent_id, "ChEMBL:CHEMBL941")
  expect_identical(res$tissue, "endothelium")
})

test_that("extract_anchor_summary fallback NA su anchor_key malformato (skip-graceful)", {
  # anchor_key con count mismatch vs level -> parse_anchor_key error, tryCatch
  # ritorna list() -> 3 segmenti NA_character_
  res <- extract_anchor_summary("bad|key", level = 0L)

  expect_named(res, c("kind_effective", "agent_id", "tissue"))
  expect_true(is.na(res$kind_effective))
  expect_true(is.na(res$agent_id))
  expect_true(is.na(res$tissue))
})

test_that("parse_anchor_key mode='group' (default) e 'pair' sono distinte", {
  fact <- make_full_sample_fact()
  cfg  <- stage3_default_config()
  key  <- simulomicsr:::.build_anchor_for_level(fact, "treated", 0L,
                                                cfg$tier_assignment)
  # mode='group' default ritorna 13 names piatti
  res_group <- parse_anchor_key(key, level = 0L)
  expect_length(res_group, 13L)
  expect_false("treated" %in% names(res_group))

  # mode='pair' su SAME key (senza __VS__) fallisce
  expect_error(parse_anchor_key(key, level = 0L, mode = "pair"))
})

# ===========================================================================
# Round-trip NCBITaxon: il nuovo namespace biologici v6 (SARS-CoV-2, etc.)
# deve sopravvivere intatto a parse_anchor_key e parse_anchor_canonical.
# Il `:` nel prefisso NON e' un separatore anchor (solo `|` lo e'), quindi
# il round-trip deve essere pulito BY-CONSTRUCTION senza modifiche al parse.
# ===========================================================================

# Stringhe anchor sintetiche (L0 = 13 segmenti, L4 = 3 segmenti Tier S)
# Costruite a mano replicando l'ordine canonical di .extract_anchor_segments():
# kind_effective | agent_id | variant_label | dose_canonical | duration_canonical |
# phase_canonical | cell_id | context_kind | cell_state | subcellular | tissue |
# disease_status | has_engineered
.ncbitaxon_key_l0 <- paste(
  c("pathogen_or_aggregate_exposure", "NCBITaxon:2697049", "wt",
    "nodose", "48h", "exposure",
    "Vero", "cell_line", "proliferating", "whole_cell",
    "respiratory_tract", "healthy", "false"),
  collapse = "|"
)
.ncbitaxon_key_l4 <- "pathogen_or_aggregate_exposure|NCBITaxon:2697049|respiratory_tract"

test_that("round-trip NCBITaxon:2697049 sopravvive parse_anchor_key a L0", {
  # RED: scritto prima di qualsiasi fix del parse.
  # NCBITaxon:2697049 non contiene '|' ne' '__VS__' -> atteso PASS
  # by-construction senza modifiche.
  res <- parse_anchor_key(.ncbitaxon_key_l0, level = 0L)

  expect_type(res, "list")
  expect_length(res, 13L)
  expect_identical(res$kind_effective, "pathogen_or_aggregate_exposure")
  expect_identical(res$agent_id,       "NCBITaxon:2697049")
  expect_identical(res$tissue,         "respiratory_tract")
  expect_true(all(!vapply(res, is.na, logical(1L))))
})

test_that("round-trip NCBITaxon:2697049 sopravvive parse_anchor_key a L4", {
  res <- parse_anchor_key(.ncbitaxon_key_l4, level = 4L)

  expect_type(res, "list")
  expect_length(res, 13L)
  expect_identical(res$agent_id, "NCBITaxon:2697049")
  # L4: solo tier S non-NA (kind_effective, agent_id, tissue)
  non_na <- names(res)[!vapply(res, is.na, logical(1L))]
  expect_identical(non_na, c("kind_effective", "agent_id", "tissue"))
})

test_that("round-trip NCBITaxon:2697049 sopravvive parse_anchor_canonical a L0", {
  # parse_anchor_canonical e' la variante Stage4 (ritorna solo i segmenti presenti,
  # senza NA padding). Verifica che il prefisso NCBITaxon: passi intatto.
  res <- simulomicsr:::parse_anchor_canonical(.ncbitaxon_key_l0, level = 0L)

  expect_type(res, "list")
  expect_length(res, 13L)
  expect_identical(res$agent_id, "NCBITaxon:2697049")
})

test_that("round-trip NCBITaxon:2697049 sopravvive parse_anchor_canonical a L4", {
  res <- simulomicsr:::parse_anchor_canonical(.ncbitaxon_key_l4, level = 4L)

  expect_length(res, 3L)
  expect_named(res, c("kind_effective", "agent_id", "tissue"))
  expect_identical(res$agent_id, "NCBITaxon:2697049")
})
