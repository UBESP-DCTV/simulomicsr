# Test per R/stage4-anchor-matching.R
#
# Coprono:
# - parse_anchor_canonical() su L0..L4
# - parse_pair_anchor_key() con/senza suffisso __CT_
# - .match_anchor_strict() e .match_anchor_relaxed()
# - make_anchor_matcher() come factory

# Anchor key reali estratti dal cluster registry Stadio 3
# (analysis/p4-output/20260519T055547Z-stage3-2153addc/clusters.rds, 2026-05-20).
# Conservati qui come fixture per test deterministici.

# L0 group anchor (13 segmenti) — none-baseline CD4+ T cells
L0_GROUP_NONE_CD4 <-
  "none|unknown|wt|nodose|na|exposure|HT55|cell_line_in_vitro|proliferating|whole_cell|large intestine|none|false"

# L0 group anchor (13 segmenti) — vehicle_only baseline T98G
L0_GROUP_VEHICLE_T98G <-
  "vehicle_only|unknown|wt|nodose|3h|exposure|T98G|cell_line_in_vitro|proliferating|whole_cell|brain|none|false"

# L4 group anchor (3 segmenti, solo tier S)
L4_GROUP <- "small_molecule|Parthenolide|stomach"

# L2 group anchor (10 segmenti = drop D + C)
# Ordine: kind_effective|agent_id|variant_label|phase_canonical|cell_id|
#         context_kind|cell_state|subcellular|tissue|disease_status
L2_GROUP <-
  "small_molecule|Carboplatin|wt|exposure|A2780 WT|cell_line_in_vitro|proliferating|whole_cell|ovary|case"

# L4 pair anchor: <treated>__VS__<control> (no __CT_)
L4_PAIR_SIMPLE <-
  "small_molecule|Parthenolide|stomach__VS__vehicle_only|Dimethyl sulfoxide|stomach"

# L0 pair anchor con __CT_ suffisso
L0_PAIR_WITH_CT <- paste0(
  "genetic_knockdown|11203|wt|nodose|na|exposure|HaCaT|cell_line_in_vitro|",
  "proliferating|whole_cell|skin|none|true",
  "__VS__",
  "none|unknown|wt|nodose|na|exposure|HaCaT keratinocytes|cell_line_in_vitro|",
  "proliferating|whole_cell|skin|none|false",
  "__CT_genetic_negative"
)

# ===========================================================================
# parse_anchor_canonical()
# ===========================================================================

test_that("parse_anchor_canonical L0 estrae i 13 segmenti nell'ordine canonical", {
  res <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  expect_type(res, "list")
  expect_length(res, 13L)
  expect_named(res, c(
    "kind_effective", "agent_id", "variant_label",
    "dose_canonical", "duration_canonical", "phase_canonical",
    "cell_id", "context_kind", "cell_state",
    "subcellular", "tissue", "disease_status", "has_engineered"
  ))
  expect_identical(res$kind_effective, "none")
  expect_identical(res$tissue, "large intestine")
  expect_identical(res$has_engineered, "false")
})

test_that("parse_anchor_canonical L4 estrae solo i 3 segmenti tier S", {
  res <- parse_anchor_canonical(L4_GROUP, level = 4L)
  expect_length(res, 3L)
  expect_named(res, c("kind_effective", "agent_id", "tissue"))
  expect_identical(res$agent_id, "Parthenolide")
  expect_identical(res$tissue, "stomach")
})

test_that("parse_anchor_canonical L2 estrae 10 segmenti (drop tier D + C)", {
  res <- parse_anchor_canonical(L2_GROUP, level = 2L)
  expect_length(res, 10L)
  expect_named(res, c(
    "kind_effective", "agent_id", "variant_label",
    "phase_canonical", "cell_id", "context_kind", "cell_state",
    "subcellular", "tissue", "disease_status"
  ))
  expect_false("dose_canonical" %in% names(res))
  expect_false("duration_canonical" %in% names(res))
  expect_false("has_engineered" %in% names(res))
})

test_that("parse_anchor_canonical solleva errore se field count mismatcha il level", {
  # L4 ha 3 campi, ma diamo input con 13
  expect_error(
    parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 4L),
    "13 segmenti.*atteso 3"
  )
  # L0 ha 13 campi, ma diamo input con 3
  expect_error(
    parse_anchor_canonical(L4_GROUP, level = 0L),
    "3 segmenti.*atteso 13"
  )
})

# ===========================================================================
# parse_pair_anchor_key()
# ===========================================================================

test_that("parse_pair_anchor_key splitta treated/control senza __CT_", {
  res <- parse_pair_anchor_key(L4_PAIR_SIMPLE, level = 4L)
  expect_named(res, c("treated", "control", "comparison_type"))
  expect_null(res$comparison_type)
  expect_identical(res$treated$kind_effective, "small_molecule")
  expect_identical(res$treated$agent_id, "Parthenolide")
  expect_identical(res$control$kind_effective, "vehicle_only")
})

test_that("parse_pair_anchor_key estrae comparison_type dal suffisso __CT_", {
  res <- parse_pair_anchor_key(L0_PAIR_WITH_CT, level = 0L)
  expect_identical(res$comparison_type, "genetic_negative")
  expect_identical(res$treated$kind_effective, "genetic_knockdown")
  expect_identical(res$control$kind_effective, "none")
  # I due cell_id differiscono leggermente (HaCaT vs HaCaT keratinocytes)
  expect_identical(res$treated$cell_id, "HaCaT")
  expect_identical(res$control$cell_id, "HaCaT keratinocytes")
})

test_that("parse_pair_anchor_key solleva errore senza __VS__", {
  expect_error(
    parse_pair_anchor_key(L4_GROUP, level = 4L),
    "__VS__"
  )
})

# ===========================================================================
# .match_anchor_strict() e .match_anchor_relaxed()
# ===========================================================================

test_that(".match_anchor_strict ritorna TRUE per anchor identici", {
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  expect_true(.match_anchor_strict(a, a))
})

test_that(".match_anchor_strict ritorna FALSE per anchor con un campo diverso", {
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  b <- a
  b$dose_canonical <- "10uM"
  expect_false(.match_anchor_strict(a, b))
})

test_that(".match_anchor_relaxed tollera differenze su dose_canonical (default)", {
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  b <- a
  b$dose_canonical <- "10uM"
  rs <- c("dose_canonical", "duration_canonical", "has_engineered")
  expect_true(.match_anchor_relaxed(a, b, relaxed_segments = rs))
})

test_that(".match_anchor_relaxed non tollera differenze su tier S (tissue)", {
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  b <- a
  b$tissue <- "blood"
  rs <- c("dose_canonical", "duration_canonical", "has_engineered")
  expect_false(.match_anchor_relaxed(a, b, relaxed_segments = rs))
})

test_that(".match_anchor_relaxed con relaxed_segments custom tollera anche cell_state", {
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  b <- a
  b$cell_state <- "quiescent"
  rs <- c("dose_canonical", "duration_canonical", "has_engineered", "cell_state")
  expect_true(.match_anchor_relaxed(a, b, relaxed_segments = rs))
})

test_that(".match_anchor_relaxed e strict coincidono a L4 (niente tier C/D presente)", {
  a <- parse_anchor_canonical(L4_GROUP, level = 4L)
  b <- a
  # Modifica tier S → entrambi devono ritornare FALSE
  b$tissue <- "skin"
  rs <- c("dose_canonical", "duration_canonical", "has_engineered")
  expect_false(.match_anchor_strict(a, b))
  expect_false(.match_anchor_relaxed(a, b, relaxed_segments = rs))
})

test_that(".match_anchor_strict ritorna FALSE su anchor di diversa lunghezza", {
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  b <- parse_anchor_canonical(L4_GROUP, level = 4L)
  expect_false(.match_anchor_strict(a, b))
})

# ===========================================================================
# make_anchor_matcher()
# ===========================================================================

test_that("make_anchor_matcher policy='strict' produce una chiusura strict", {
  matcher <- make_anchor_matcher(policy = "strict")
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  b <- a
  b$dose_canonical <- "10uM"
  expect_false(matcher(a, b))
  expect_true(matcher(a, a))
})

test_that("make_anchor_matcher policy='relaxed' usa default relaxed_segments", {
  matcher <- make_anchor_matcher(policy = "relaxed")
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  b <- a
  b$dose_canonical <- "10uM"
  b$duration_canonical <- "24h"
  expect_true(matcher(a, b))
})

test_that("make_anchor_matcher policy='relaxed' rispetta relaxed_segments custom", {
  matcher <- make_anchor_matcher(
    policy = "relaxed",
    relaxed_segments = c("dose_canonical", "cell_state")
  )
  a <- parse_anchor_canonical(L0_GROUP_NONE_CD4, level = 0L)
  b <- a
  b$cell_state <- "quiescent"
  expect_true(matcher(a, b))
  # duration_canonical NON e' nel set custom: deve restare strict
  b2 <- a
  b2$duration_canonical <- "24h"
  expect_false(matcher(a, b2))
})

test_that("make_anchor_matcher solleva errore su policy sconosciuta", {
  expect_error(make_anchor_matcher(policy = "foo"))
})
