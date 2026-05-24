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
      agent_normalized = list(id = "CHEMBL941", preferred_name = "imatinib"),
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
  expect_identical(res$agent_id, "CHEMBL941")
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
  expect_identical(res$agent_id, "CHEMBL941")
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
  expect_identical(res$agent_id, "CHEMBL941")
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
