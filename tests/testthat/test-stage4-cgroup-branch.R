# ADR-0025: il ramo rem_group dello Stadio 4 consuma i cluster derivati dal
# CONTRASTO (mode "cgroup") e non piu' i group, che restavano comparison-blind.
# I rami rem, mega e mega_aug non devono cambiare.

.s4cg_clusters <- function() {
  tibble::tibble(
    cluster_id              = c("cgroup_L5_aaa", "group_L4_bbb", "group_L0_ccc"),
    mode                    = c("cgroup", "group", "group"),
    level                   = c(5L, 4L, 0L),
    k                       = c(5L, 5L, 8L),
    n_total                 = c(20L, 20L, 40L),
    n_studies               = c(5L, 5L, 8L),
    safety_min              = c(0.2, 0.2, 0.9),
    usable_rem_strict       = FALSE,
    usable_rem_relaxed      = FALSE,
    usable_mega_strict      = c(FALSE, FALSE, TRUE),
    usable_mega_relaxed     = FALSE,
    kind_effective_resolved = "small_molecule",
    agent_id_resolved       = c("CHEBI:68534", "CHEBI:68534", "CHEBI:68534"),
    contrast_direction      = c("gain", NA_character_, NA_character_)
  )
}

test_that("il gate rem_group seleziona i cgroup e non piu' i group", {
  sel <- .identify_layer_a_clusters(.s4cg_clusters(), stage4_default_config())
  rg <- sel[sel$method == "rem_group", ]
  expect_equal(nrow(rg), 1L)
  expect_equal(rg$cluster_id, "cgroup_L5_aaa")
})

test_that("il ramo mega non cambia: continua a prendere i group L0/L1", {
  # ADR-0026 lo toglie dal DELIVERABLE, non dal codice: chiesto esplicitamente
  # deve ancora classificare come prima.
  cfg <- stage4_default_config()
  cfg$deliverable_methods <- c("rem", "mega", "mega_aug", "rem_group")
  sel <- .identify_layer_a_clusters(.s4cg_clusters(), cfg)
  mg <- sel[sel$method == "mega", ]
  expect_equal(nrow(mg), 1L)
  expect_equal(mg$cluster_id, "group_L0_ccc")
})

test_that("la dedup per entita' tiene conto del verso", {
  cl <- tibble::tibble(
    cluster_id              = c("a", "b", "c"),
    mode                    = "cgroup",
    level                   = 5L,
    k                       = c(10L, 4L, 6L),
    n_total                 = c(40L, 12L, 20L),
    kind_effective_resolved = "small_molecule",
    agent_id_resolved       = "CHEBI:68534",
    contrast_direction      = c("gain", "gain", "block")
  )
  out <- .dedup_rem_group_by_entity(cl)
  # stessa entita': "gain" tiene il k massimo (a); "block" e' un contrasto
  # diverso (agonista vs antagonista) e sopravvive a se' (c)
  expect_setequal(out$cluster_id, c("a", "c"))
})

test_that("la dedup resta retrocompatibile quando il verso non c'e'", {
  cl <- tibble::tibble(
    cluster_id              = c("a", "b"),
    mode                    = "group",
    level                   = 4L,
    k                       = c(10L, 4L),
    n_total                 = c(40L, 12L),
    kind_effective_resolved = "small_molecule",
    agent_id_resolved       = "CHEBI:68534"
  )
  out <- .dedup_rem_group_by_entity(cl)
  expect_equal(out$cluster_id, "a")
})
