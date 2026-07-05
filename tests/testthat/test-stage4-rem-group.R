test_that("stage4_default_config espone il blocco rem_group con soglie decise", {
  cfg <- stage4_default_config()
  expect_true(!is.null(cfg$rem_group))
  expect_identical(cfg$rem_group$k_eff_min, 3L)
  expect_identical(cfg$rem_group$n_min, 2L)
  expect_true("vehicle_only" %in% cfg$rem_group$excluded_kinds)
  expect_true("none" %in% cfg$rem_group$excluded_kinds)
  expect_identical(cfg$schema_versions$rem_group_strategy,
                   "v1_per_study_rem_named_groups")
})


test_that("dedup rem_group tiene un cluster per entita al k massimo", {
  rg <- dplyr::bind_rows(
    .mk_cluster_row("group_L4_enza", "group", 4L, 25L, 400L, 25L, 0.33,
                    FALSE, "small_molecule", "CHEBI:enzalutamide"),
    .mk_cluster_row("group_L3_enza", "group", 3L, 9L, 120L, 9L, 0.40,
                    FALSE, "small_molecule", "CHEBI:enzalutamide"),
    .mk_cluster_row("group_L4_tam", "group", 4L, 9L, 90L, 9L, 0.35,
                    FALSE, "small_molecule", "CHEBI:tamoxifen")
  )
  rg$method <- "rem_group"
  out <- .dedup_rem_group_by_entity(rg)
  expect_setequal(out$cluster_id, c("group_L4_enza", "group_L4_tam"))
  expect_identical(
    out$cluster_id[out$agent_id_resolved == "CHEBI:enzalutamide"],
    "group_L4_enza"
  )
})

test_that("porta rem_group ammette group nominato L4, esclude coarse/vehicle/pair", {
  clusters <- dplyr::bind_rows(
    .mk_cluster_row("group_L4_enza", "group", 4L, 25L, 400L, 25L, 0.33,
                    FALSE, "small_molecule", "CHEBI:enzalutamide"),
    .mk_cluster_row("group_L0_coarse", "group", 0L, 8L, 200L, 8L, 0.85,
                    TRUE,  "environmental", "STR:hypoxia"),
    .mk_cluster_row("group_L3_veh", "group", 3L, 5L, 60L, 5L, 0.30,
                    FALSE, "vehicle_only", "CHEBI:dmso"),
    .mk_cluster_row("pair_L2_x", "pair", 2L, 4L, 40L, 4L, 0.60,
                    FALSE, "small_molecule", "CHEBI:foo")
  )
  cfg <- stage4_default_config()
  out <- .identify_layer_a_clusters(clusters, cfg)
  rg <- out[out$method == "rem_group", ]
  expect_identical(rg$cluster_id, "group_L4_enza")
  expect_false("group_L0_coarse" %in% out$cluster_id[out$method == "rem_group"])
  expect_false("group_L3_veh"    %in% out$cluster_id)
  expect_false(any(out$method == "rem_group" & out$mode == "pair"))
})

.mk_study <- function(series_id, rgs, cmps) {
  list(series_id = series_id, replicate_groups = rgs, comparisons = cmps)
}
.rg <- function(group_id, role, sids) {
  list(group_id = group_id, primary_role = role, sample_ids = sids)
}
.cmp <- function(comparison_id, treated_group, control_group) {
  list(comparison_id = comparison_id, treated_group = treated_group,
       control_group = control_group)
}

test_that("group_rem_dispatch linka i control in-study (both_roles + treated_only)", {
  # Studio both_roles: treated tg1 + control cg1 nello stesso studio, entrambi
  # membri del cluster (record __tg1 e __cg1).
  s_both <- .mk_study("GSE1",
    rgs  = list(.rg("tg1","treated",c("s1","s2","s3")),
                .rg("cg1","control",c("s4","s5"))),
    cmps = list(.cmp("c1","tg1","cg1")))
  # Studio treated_only: solo tg2 nel cluster; il control cg2 vive fuori dal
  # cluster ma nella comparison dello stesso studio.
  s_treat <- .mk_study("GSE2",
    rgs  = list(.rg("tg2","treated",c("t1","t2")),
                .rg("cg2","control",c("u1","u2"))),
    cmps = list(.cmp("c2","tg2","cg2")))
  # Studio senza control ricostruibile: comparison assente per tg3.
  s_noctrl <- .mk_study("GSE3",
    rgs  = list(.rg("tg3","treated",c("x1","x2"))),
    cmps = list())
  # Studio con < n_min control (1 solo control) -> scartato.
  s_small <- .mk_study("GSE4",
    rgs  = list(.rg("tg4","treated",c("a1","a2")),
                .rg("cg4","control",c("b1"))),
    cmps = list(.cmp("c4","tg4","cg4")))
  stage2_master <- list(s_both, s_treat, s_noctrl, s_small)

  eligible <- .mk_cluster_row("group_L4_e", "group", 4L, 4L, 40L, 4L, 0.3,
                              FALSE, "small_molecule", "CHEBI:e")
  eligible$method <- "rem_group"
  assignments <- tibble::tibble(
    cluster_id = "group_L4_e",
    record_id  = c("GSE1__tg1", "GSE1__cg1", "GSE2__tg2",
                   "GSE3__tg3", "GSE4__tg4")
  )

  disp <- .build_group_rem_dispatch_from_stage3(eligible, assignments,
                                                stage2_master, n_min = 2L)
  d <- disp[["group_L4_e"]]
  studies <- vapply(d, function(x) x$study_id, character(1))
  expect_setequal(studies, c("GSE1", "GSE2"))   # GSE3 no-ctrl, GSE4 <n_min esclusi
  gse1 <- d[[which(studies == "GSE1")]]
  expect_setequal(gse1$treated, c("s1","s2","s3"))
  expect_setequal(gse1$control, c("s4","s5"))
})

test_that(".pool_rem_cluster marca il method_label (rem_group) senza rompere il default", {
  subset <- tibble::tibble(
    cluster_id = "group_L4_e",
    gene_id    = rep(c("ENSG1", "ENSG2"), each = 3L),
    gene_symbol = rep(c("A", "B"), each = 3L),
    logFC      = c(1.0, 1.2, 0.8, -0.5, -0.6, -0.4),
    SE         = rep(0.2, 6L)
  )
  out_default <- .pool_rem_cluster(subset)
  expect_true(all(out_default$method == "rem"))
  out_group <- .pool_rem_cluster(subset, method_label = "rem_group")
  expect_true(all(out_group$method == "rem_group"))
})

# TDD regressione: fixture senza kind_effective_resolved / agent_id_resolved
# deve tornare 0 righe rem_group senza errore (degradazione graceful).
# RED prima del fix: "Can't subset rows" / "invalid argument type".
# GREEN dopo il fix: nessun errore, 0 righe method=="rem_group".
test_that("identify_layer_a_clusters tollera fixture priva di kind/agent_id_resolved", {
  clusters_minimal <- tibble::tibble(
    cluster_id            = "group_L2_x",
    mode                  = "group",
    level                 = 2L,
    k                     = 4L,
    n_total               = 40L,
    n_studies             = 4L,
    usable_rem_strict     = FALSE,
    usable_rem_relaxed    = FALSE,
    usable_mega_strict    = FALSE,
    safety_min            = 0.30,
    studies_in_cluster    = list(c("GSE1", "GSE2", "GSE3", "GSE4")),
    direction_check       = "ok"
    # NON contiene kind_effective_resolved ne' agent_id_resolved
  )
  cfg <- stage4_default_config()
  expect_no_error(
    out <- .identify_layer_a_clusters(clusters_minimal, cfg)
  )
  # Degradazione graceful: 0 righe rem_group (agent_id_resolved assente = NA = escluso)
  expect_equal(sum(out$method == "rem_group", na.rm = TRUE), 0L)
})

# Finding 2 (Minor): estende il test di regressione al caso in cui manca ANCHE
# usable_mega_strict (oltre a kind_effective_resolved e agent_id_resolved).
# Con .col_or_default gia' presente la funzione non deve ne' crashare ne' produrre
# righe rem_group: senza agent_id_resolved tutti gli agent sono NA e il gate
# !is.na(agent_col) esclude ogni riga.
test_that("identify_layer_a_clusters tollera fixture priva di usable_mega_strict, kind e agent", {
  clusters_noF6 <- tibble::tibble(
    cluster_id            = "group_L3_y",
    mode                  = "group",
    level                 = 3L,
    k                     = 5L,
    n_total               = 50L,
    n_studies             = 5L,
    usable_rem_strict     = FALSE,
    usable_rem_relaxed    = FALSE,
    # MANCANO: usable_mega_strict, kind_effective_resolved, agent_id_resolved
    safety_min            = 0.25,
    studies_in_cluster    = list(c("GSE1","GSE2","GSE3","GSE4","GSE5")),
    direction_check       = "ok"
  )
  cfg <- stage4_default_config()
  expect_no_error(
    out <- .identify_layer_a_clusters(clusters_noF6, cfg)
  )
  expect_equal(sum(out$method == "rem_group", na.rm = TRUE), 0L)
})
