# Test per R/stage4-baseline-pool-pairing.R
#
# Coprono find_baseline_for_pair() per direction control_only / treated_only /
# both, filtering min_baseline_studies, ranking (n_studies desc tiebreak
# n_total desc), e backward compat (zero match).

# -- Fixture builders -------------------------------------------------------

make_pair_row <- function(cluster_id, level, anchor_key) {
  tibble::tibble(
    cluster_id = cluster_id,
    mode       = "pair",
    level      = level,
    anchor_key = anchor_key
  )
}

make_group_row <- function(cluster_id, level, anchor_key, n_studies = 5L,
                             n_total = 30L) {
  tibble::tibble(
    cluster_id = cluster_id,
    mode       = "group",
    level      = level,
    anchor_key = anchor_key,
    n_studies  = n_studies,
    n_total    = n_total
  )
}

# Pair L4 con treated=Parthenolide e control=vehicle_only
PAIR_L4 <- make_pair_row(
  "pair_L4_aa", level = 4L,
  anchor_key = "small_molecule|Parthenolide|stomach__VS__vehicle_only|Dimethyl sulfoxide|stomach"
)

# Group baseline candidati a L4 (solo tier S = kind|agent|tissue)
GROUP_L4_VEHICLE_DMSO <- make_group_row(
  "group_L4_v1", 4L,
  "vehicle_only|Dimethyl sulfoxide|stomach",
  n_studies = 6L, n_total = 50L
)
GROUP_L4_VEHICLE_DMSO_LARGER_STUDIES <- make_group_row(
  "group_L4_v2", 4L,
  "vehicle_only|Dimethyl sulfoxide|stomach",
  n_studies = 10L, n_total = 80L
)
GROUP_L4_PARTHENOLIDE <- make_group_row(
  "group_L4_t1", 4L,
  "small_molecule|Parthenolide|stomach",
  n_studies = 4L, n_total = 25L
)
GROUP_L4_DIFFERENT_TISSUE <- make_group_row(
  "group_L4_x1", 4L,
  "vehicle_only|Dimethyl sulfoxide|skin",
  n_studies = 5L, n_total = 30L
)
GROUP_L4_LOW_STUDIES <- make_group_row(
  "group_L4_low", 4L,
  "vehicle_only|Dimethyl sulfoxide|stomach",
  n_studies = 1L, n_total = 8L
)
GROUP_L3_OTHER_LEVEL <- make_group_row(
  "group_L3_other", 3L,
  # L3 = 8 segmenti
  "vehicle_only|Dimethyl sulfoxide|wt|exposure|cell_line_in_vitro|whole_cell|stomach|none",
  n_studies = 5L, n_total = 30L
)

GROUPS_L4 <- rbind(
  GROUP_L4_VEHICLE_DMSO,
  GROUP_L4_VEHICLE_DMSO_LARGER_STUDIES,
  GROUP_L4_PARTHENOLIDE,
  GROUP_L4_DIFFERENT_TISSUE,
  GROUP_L4_LOW_STUDIES,
  GROUP_L3_OTHER_LEVEL
)

# ===========================================================================
# find_baseline_for_pair()
# ===========================================================================

test_that("find_baseline_for_pair direction='control' trova solo baseline che matcha il control_anchor", {
  matcher <- make_anchor_matcher("strict")
  res <- find_baseline_for_pair(PAIR_L4, GROUPS_L4, matcher,
                                  direction = "control",
                                  min_baseline_studies = 2L)
  expect_type(res, "list")
  # Aspetto 2 match: GROUP_L4_VEHICLE_DMSO + L4_VEHICLE_DMSO_LARGER_STUDIES
  expect_length(res, 2L)
  baseline_ids <- vapply(res, function(x) x$baseline_cluster_id, character(1L))
  expect_setequal(baseline_ids, c("group_L4_v1", "group_L4_v2"))
  # Tutti col arm "control"
  arms <- vapply(res, function(x) x$arm, character(1L))
  expect_true(all(arms == "control"))
})

test_that("find_baseline_for_pair direction='treated' trova solo baseline che matcha il treated_anchor", {
  matcher <- make_anchor_matcher("strict")
  res <- find_baseline_for_pair(PAIR_L4, GROUPS_L4, matcher,
                                  direction = "treated",
                                  min_baseline_studies = 2L)
  # Aspetto 1 match: GROUP_L4_PARTHENOLIDE
  expect_length(res, 1L)
  expect_identical(res[[1L]]$baseline_cluster_id, "group_L4_t1")
  expect_identical(res[[1L]]$arm, "treated")
})

test_that("find_baseline_for_pair direction='both' restituisce sia control che treated match", {
  matcher <- make_anchor_matcher("strict")
  res <- find_baseline_for_pair(PAIR_L4, GROUPS_L4, matcher,
                                  direction = "both",
                                  min_baseline_studies = 2L)
  # Aspetto 3 match: 2 control + 1 treated
  expect_length(res, 3L)
  arms <- vapply(res, function(x) x$arm, character(1L))
  expect_equal(sum(arms == "control"), 2L)
  expect_equal(sum(arms == "treated"), 1L)
})

test_that("find_baseline_for_pair filtra baseline con n_studies < min_baseline_studies", {
  matcher <- make_anchor_matcher("strict")
  # min_baseline_studies = 5: scarta GROUP_L4_VEHICLE_DMSO (6, OK),
  # GROUP_L4_LOW_STUDIES (1, escluso), GROUP_L4_PARTHENOLIDE (4, escluso)
  res <- find_baseline_for_pair(PAIR_L4, GROUPS_L4, matcher,
                                  direction = "both",
                                  min_baseline_studies = 5L)
  ids <- vapply(res, function(x) x$baseline_cluster_id, character(1L))
  expect_false("group_L4_low" %in% ids)
  expect_false("group_L4_t1" %in% ids)  # 4 < 5
  expect_true("group_L4_v1" %in% ids)
  expect_true("group_L4_v2" %in% ids)
})

test_that("find_baseline_for_pair filtra baseline a livello diverso dal pair", {
  matcher <- make_anchor_matcher("strict")
  res <- find_baseline_for_pair(PAIR_L4, GROUPS_L4, matcher,
                                  direction = "both",
                                  min_baseline_studies = 2L)
  ids <- vapply(res, function(x) x$baseline_cluster_id, character(1L))
  # group_L3_other ha level=3, non deve apparire
  expect_false("group_L3_other" %in% ids)
})

test_that("find_baseline_for_pair ordina control prima di treated, poi n_studies desc, poi n_total desc", {
  matcher <- make_anchor_matcher("strict")
  res <- find_baseline_for_pair(PAIR_L4, GROUPS_L4, matcher,
                                  direction = "both",
                                  min_baseline_studies = 2L)
  # Atteso ordering: control wins su treated; tra control, larger studies prima
  expect_identical(res[[1L]]$arm, "control")
  expect_identical(res[[1L]]$baseline_cluster_id, "group_L4_v2")  # n_studies=10
  expect_identical(res[[2L]]$arm, "control")
  expect_identical(res[[2L]]$baseline_cluster_id, "group_L4_v1")  # n_studies=6
  expect_identical(res[[3L]]$arm, "treated")
  expect_identical(res[[3L]]$baseline_cluster_id, "group_L4_t1")
})

test_that("find_baseline_for_pair ritorna list vuota se nessun match", {
  matcher <- make_anchor_matcher("strict")
  # Pair con tissue diversa da tutti i baseline
  pair_noskin <- make_pair_row(
    "pair_L4_noskin", level = 4L,
    anchor_key = "small_molecule|Parthenolide|liver__VS__vehicle_only|Dimethyl sulfoxide|liver"
  )
  res <- find_baseline_for_pair(pair_noskin, GROUPS_L4, matcher,
                                  direction = "both",
                                  min_baseline_studies = 2L)
  expect_length(res, 0L)
})

test_that("find_baseline_for_pair con matcher relaxed accetta baseline diversi su dose/duration", {
  # Crea pair e baseline che differiscono SOLO su dose_canonical (L0, 13 campi)
  pair_l0 <- make_pair_row(
    "pair_L0_a", level = 0L,
    anchor_key = paste0(
      "small_molecule|DrugX|wt|10uM|24h|exposure|HeLa|cell_line_in_vitro|",
      "proliferating|whole_cell|cervix|none|false",
      "__VS__",
      "vehicle_only|DMSO|wt|10uM|24h|exposure|HeLa|cell_line_in_vitro|",
      "proliferating|whole_cell|cervix|none|false"
    )
  )
  # Baseline matcha vehicle_only|DMSO|cervix su tier S, ma differisce su dose
  baseline_l0 <- make_group_row(
    "group_L0_diffdose", 0L,
    paste0(
      "vehicle_only|DMSO|wt|100uM|48h|exposure|HeLa|cell_line_in_vitro|",
      "proliferating|whole_cell|cervix|none|false"
    ),
    n_studies = 5L, n_total = 30L
  )

  matcher_strict <- make_anchor_matcher("strict")
  matcher_relaxed <- make_anchor_matcher("relaxed")

  res_strict <- find_baseline_for_pair(pair_l0, baseline_l0, matcher_strict,
                                         direction = "control",
                                         min_baseline_studies = 2L)
  res_relaxed <- find_baseline_for_pair(pair_l0, baseline_l0, matcher_relaxed,
                                          direction = "control",
                                          min_baseline_studies = 2L)
  expect_length(res_strict, 0L)
  expect_length(res_relaxed, 1L)
  expect_identical(res_relaxed[[1L]]$baseline_cluster_id, "group_L0_diffdose")
})
