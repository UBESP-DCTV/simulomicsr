# Test per .classify_comparison_kind() (in R/stage4-anchor-matching.R)
#
# Regole (spec sez. 6):
# - >= 1 studio comune tra pair e baseline -> "direct_overlap"
# - 0 overlap MA |pair| >= 2 e |baseline| >= 3 -> "indirect_partial"
# - altrimenti (0 overlap + uno dei due con 1 solo studio o baseline < 3)
#   -> "indirect_disjoint"

test_that("classify direct_overlap quando >= 1 studio comune", {
  expect_identical(
    .classify_comparison_kind(c("GSE1", "GSE2"), c("GSE2", "GSE3", "GSE4")),
    "direct_overlap"
  )
  # 1 studio in entrambi sets
  expect_identical(
    .classify_comparison_kind(c("GSE1"), c("GSE1", "GSE2", "GSE3")),
    "direct_overlap"
  )
})

test_that("classify indirect_partial: 0 overlap, pair >= 2 studi, baseline >= 3 studi", {
  expect_identical(
    .classify_comparison_kind(c("GSE1", "GSE2"), c("GSE3", "GSE4", "GSE5")),
    "indirect_partial"
  )
  # pair grosso, baseline minimo 3
  expect_identical(
    .classify_comparison_kind(c("GSE1", "GSE2", "GSE9"), c("GSE3", "GSE4", "GSE5")),
    "indirect_partial"
  )
})

test_that("classify indirect_disjoint: 0 overlap + pair singolo studio", {
  expect_identical(
    .classify_comparison_kind(c("GSE1"), c("GSE2", "GSE3", "GSE4")),
    "indirect_disjoint"
  )
})

test_that("classify indirect_disjoint: 0 overlap + baseline < 3 studi", {
  expect_identical(
    .classify_comparison_kind(c("GSE1", "GSE2"), c("GSE3", "GSE4")),
    "indirect_disjoint"
  )
  expect_identical(
    .classify_comparison_kind(c("GSE1", "GSE2"), c("GSE3")),
    "indirect_disjoint"
  )
})

test_that("classify gestisce input vuoti come direct_overlap impossibile -> disjoint", {
  # Edge case: pair vuoto -> nessun overlap possibile, |pair|=0 fallisce >= 2
  expect_identical(
    .classify_comparison_kind(character(0), c("GSE1", "GSE2", "GSE3")),
    "indirect_disjoint"
  )
  expect_identical(
    .classify_comparison_kind(c("GSE1", "GSE2"), character(0)),
    "indirect_disjoint"
  )
})

test_that("classify dedupa studi ripetuti", {
  # pair_studies con duplicati interni (es. due sample dello stesso studio):
  # unicizza prima del check di overlap.
  expect_identical(
    .classify_comparison_kind(c("GSE1", "GSE1", "GSE1"), c("GSE2", "GSE3", "GSE4")),
    "indirect_disjoint"
  )
})
