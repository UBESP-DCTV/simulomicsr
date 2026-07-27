# ADR-0026 + decisione utente 2026-07-27: il deliverable dello Stadio 4 e' il
# solo ramo derivato dal CONTRASTO (`rem_group` sui cluster `cgroup`). I rami
# `mega`, `mega_aug` e `rem` escono dal deliverable.
#
# E' una modifica di SELEZIONE, non una cancellazione: le funzioni di quei rami
# restano, restano testate, e restano raggiungibili passando esplicitamente i
# metodi voluti. Questi test fissano entrambe le meta'.

.s4db_clusters <- function() {
  tibble::tibble(
    cluster_id              = c("pair_L2_rem", "group_L0_mega", "pair_L1_aug",
                                "cgroup_L5_ok"),
    mode                    = c("pair", "group", "pair", "cgroup"),
    level                   = c(2L, 0L, 1L, 5L),
    k                       = c(5L, 8L, 2L, 4L),
    n_total                 = c(20L, 40L, 8L, 16L),
    n_studies               = c(5L, 8L, 2L, 4L),
    safety_min              = c(0.9, 0.9, 0.8, 0.2),
    usable_rem_strict       = c(TRUE, FALSE, FALSE, FALSE),
    usable_rem_relaxed      = c(TRUE, FALSE, TRUE, FALSE),
    usable_mega_strict      = c(FALSE, TRUE, FALSE, FALSE),
    usable_mega_relaxed     = FALSE,
    kind_effective_resolved = "small_molecule",
    agent_id_resolved       = "CHEBI:68534",
    contrast_direction      = c(NA_character_, NA_character_, NA_character_, "gain")
  )
}

test_that("la config dichiara il solo ramo dal-contrasto come deliverable", {
  expect_equal(stage4_default_config()$deliverable_methods, "rem_group")
})

test_that("con la config di default la selezione tiene solo rem_group", {
  sel <- .identify_layer_a_clusters(.s4db_clusters(), stage4_default_config())
  expect_equal(unique(sel$method), "rem_group")
  expect_equal(sel$cluster_id, "cgroup_L5_ok")
})

test_that("i rami esclusi restano raggiungibili chiedendoli esplicitamente", {
  cfg <- stage4_default_config()
  cfg$deliverable_methods <- c("rem", "mega", "mega_aug", "rem_group")
  sel <- .identify_layer_a_clusters(.s4db_clusters(), cfg)
  expect_setequal(sel$method, c("rem", "mega", "mega_aug", "rem_group"))
  expect_setequal(sel$cluster_id,
                  c("pair_L2_rem", "group_L0_mega", "pair_L1_aug", "cgroup_L5_ok"))
})

test_that("chiedere un solo ramo escluso lo restituisce comunque", {
  cfg <- stage4_default_config()
  cfg$deliverable_methods <- "mega"
  sel <- .identify_layer_a_clusters(.s4db_clusters(), cfg)
  expect_equal(sel$cluster_id, "group_L0_mega")
})

test_that("se nessun cluster sopravvive alla selezione il risultato e' vuoto, non un errore", {
  cl <- .s4db_clusters()
  cl <- cl[cl$mode != "cgroup", ]          # niente cgroup -> niente deliverable
  sel <- .identify_layer_a_clusters(cl, stage4_default_config())
  expect_equal(nrow(sel), 0L)
})
