# Tests per i dispatch builders Stadio 4: traducono `stage3_assignments` +
# `stage2_master` in named-list per-cluster consumate da orchestrator/pool.

test_that(".parse_pair_anchor_key separa treated/control + CT suffix", {
  # L0/L1: anchor_key e' "<tk>__VS__<ck>__CT_<ctype>"
  p0 <- .parse_pair_anchor_key("kidney|disease__VS__kidney|healthy__CT_untreated",
                                level = 0L)
  expect_equal(p0$treated, "kidney|disease")
  expect_equal(p0$control, "kidney|healthy")
  expect_equal(p0$control_type, "untreated")

  # L2+: anchor_key e' "<tk>__VS__<ck>" (no CT suffix)
  p3 <- .parse_pair_anchor_key("cellline|hela__VS__cellline|hela", level = 3L)
  expect_equal(p3$treated, "cellline|hela")
  expect_equal(p3$control, "cellline|hela")
  expect_true(is.na(p3$control_type))

  # Malformed (manca __VS__): NA su tutti i campi
  p_bad <- .parse_pair_anchor_key("not_a_pair_key", level = 0L)
  expect_true(is.na(p_bad$treated))
  expect_true(is.na(p_bad$control))
})

# Mini fixture stage2_master + stage3_assignments per i test dispatch.
.make_dispatch_fixture <- function() {
  # 3 studi, 2 con comparisons (pair), 3 con replicate_groups (group):
  #  - GSE_a: 2 rg (treated/control), 1 cmp
  #  - GSE_b: 2 rg (treated/control), 1 cmp
  #  - GSE_c: 1 rg (treated), 0 cmp -> contribuisce solo a group
  stage2_master <- list(
    list(
      series_id = "GSE_a",
      replicate_groups = list(
        list(group_id = "rg_a_T", sample_ids = c("GSM_a1", "GSM_a2"),
             primary_role = "treated"),
        list(group_id = "rg_a_C", sample_ids = c("GSM_a3", "GSM_a4"),
             primary_role = "control")
      ),
      comparisons = list(
        list(comparison_id = "cmp_a_1", treated_group = "rg_a_T",
             control_group = "rg_a_C", control_type = "untreated")
      )
    ),
    list(
      series_id = "GSE_b",
      replicate_groups = list(
        list(group_id = "rg_b_T", sample_ids = c("GSM_b1", "GSM_b2"),
             primary_role = "treated"),
        list(group_id = "rg_b_C", sample_ids = c("GSM_b3", "GSM_b4"),
             primary_role = "control")
      ),
      comparisons = list(
        list(comparison_id = "cmp_b_1", treated_group = "rg_b_T",
             control_group = "rg_b_C", control_type = "vehicle")
      )
    ),
    list(
      series_id = "GSE_c",
      replicate_groups = list(
        list(group_id = "rg_c_T", sample_ids = c("GSM_c1", "GSM_c2"),
             primary_role = "treated")
      ),
      comparisons = list()
    )
  )

  # Cluster eligible: 1 pair REM (GSE_a + GSE_b cmps), 1 group MEGA (3 rg)
  eligible_clusters <- tibble::tibble(
    cluster_id = c("pair_rem_xxx", "group_mega_yyy"),
    mode       = c("pair", "group"),
    level      = c(0L, 3L),
    anchor_key = c("ANCHOR_T|x__VS__ANCHOR_C|y__CT_untreated",
                   "cellline|hela"),
    method     = c("rem", "mega"),
    direction_check = factor(c("canonical", "na"),
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na")),
    studies_in_cluster = list(c("GSE_a", "GSE_b"),
                               c("GSE_a", "GSE_b", "GSE_c"))
  )

  # Assignments: record_id = "<series>__<cmp_or_rg_id>"
  stage3_assignments <- tibble::tibble(
    record_id  = c("GSE_a__cmp_a_1", "GSE_b__cmp_b_1",
                   "GSE_a__rg_a_T", "GSE_b__rg_b_T", "GSE_c__rg_c_T"),
    mode       = c("pair", "pair", "group", "group", "group"),
    level      = c(0L, 0L, 3L, 3L, 3L),
    cluster_id = c("pair_rem_xxx", "pair_rem_xxx",
                   "group_mega_yyy", "group_mega_yyy", "group_mega_yyy"),
    anchor_key = c("ANCHOR_T|x__VS__ANCHOR_C|y__CT_untreated",
                   "ANCHOR_T|x__VS__ANCHOR_C|y__CT_untreated",
                   "cellline|hela", "cellline|hela", "cellline|hela")
  )

  list(
    eligible_clusters = eligible_clusters,
    stage3_assignments = stage3_assignments,
    stage2_master = stage2_master
  )
}

test_that(".build_study_dispatch_from_stage3 popola treated/control per REM/MEGA-AUG", {
  fix <- .make_dispatch_fixture()
  dispatch <- .build_study_dispatch_from_stage3(
    fix$eligible_clusters, fix$stage3_assignments, fix$stage2_master
  )

  expect_true("pair_rem_xxx" %in% names(dispatch))
  # MEGA pure non e' in study_dispatch (e' in group_dispatch)
  expect_false("group_mega_yyy" %in% names(dispatch))

  pd <- dispatch[["pair_rem_xxx"]]
  expect_length(pd, 2L)
  # Ordina by study_id per il test (stabilita')
  studies <- vapply(pd, `[[`, character(1L), "study_id")
  expect_setequal(studies, c("GSE_a", "GSE_b"))

  a <- pd[[which(studies == "GSE_a")]]
  expect_equal(a$treated, c("GSM_a1", "GSM_a2"))
  expect_equal(a$control, c("GSM_a3", "GSM_a4"))
})

test_that(".build_group_dispatch_from_stage3 popola sample_ids + treatment factor", {
  fix <- .make_dispatch_fixture()
  dispatch <- .build_group_dispatch_from_stage3(
    fix$eligible_clusters, fix$stage3_assignments, fix$stage2_master
  )

  expect_true("group_mega_yyy" %in% names(dispatch))
  expect_false("pair_rem_xxx" %in% names(dispatch))

  gd <- dispatch[["group_mega_yyy"]]
  # 3 rg, ognuno con primary_role = "treated", quindi tutti inclusi
  expect_length(gd, 3L)
  studies <- vapply(gd, `[[`, character(1L), "study_id")
  expect_setequal(studies, c("GSE_a", "GSE_b", "GSE_c"))

  a <- gd[[which(studies == "GSE_a")]]
  expect_equal(a$sample_ids, c("GSM_a1", "GSM_a2"))
  expect_equal(a$treatment, c("treated", "treated"))
})

test_that(".build_group_dispatch_from_stage3 ignora ruoli non treated/control", {
  # Fixture con primary_role = "bystander" -> escluso
  fix <- .make_dispatch_fixture()
  fix$stage2_master[[3]]$replicate_groups[[1]]$primary_role <- "bystander"

  dispatch <- .build_group_dispatch_from_stage3(
    fix$eligible_clusters, fix$stage3_assignments, fix$stage2_master
  )
  gd <- dispatch[["group_mega_yyy"]]
  # GSE_c rimosso (bystander), 2 restano
  expect_length(gd, 2L)
  studies <- vapply(gd, `[[`, character(1L), "study_id")
  expect_setequal(studies, c("GSE_a", "GSE_b"))
})

test_that(".build_study_dispatch_from_stage3 e' tollerante a record_id orfani", {
  fix <- .make_dispatch_fixture()
  # Aggiungi un orfano (series_id non in stage2_master)
  orph <- tibble::tibble(
    record_id  = "GSE_ZZZ__cmp_orfano",
    mode       = "pair",
    level      = 0L,
    cluster_id = "pair_rem_xxx",
    anchor_key = "x__VS__y__CT_untreated"
  )
  fix$stage3_assignments <- rbind(fix$stage3_assignments, orph)

  expect_silent(dispatch <- .build_study_dispatch_from_stage3(
    fix$eligible_clusters, fix$stage3_assignments, fix$stage2_master
  ))
  # Original 2 study dispatch entries, orfano saltato
  expect_length(dispatch[["pair_rem_xxx"]], 2L)
})

test_that(".pool_all_clusters mega_aug usa control_anchor_key parsato + sample_ids enriched", {
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")

  # Fixture realistica: 1 pair MEGA-AUG (k=2 GSE_a + GSE_b) + 1 group baseline
  # con stesso control_anchor_key (BASELINE_C) + sample_ids enriched.
  eligible <- tibble::tibble(
    cluster_id = "pair_aug_k2",
    method = "mega_aug",
    level = 0L,
    mode = factor("pair", levels = c("pair", "group")),
    anchor_key = "TREATED_T|x__VS__BASELINE_C|y__CT_untreated",
    direction_check = factor("canonical",
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na")),
    studies_in_cluster = list(c("GSE_a", "GSE_b"))
  )
  attr(eligible, "study_dispatch") <- list(
    pair_aug_k2 = list(
      list(study_id = "GSE_a", treated = c("GSM_a1", "GSM_a2"),
           control = c("GSM_a3", "GSM_a4")),
      list(study_id = "GSE_b", treated = c("GSM_b1", "GSM_b2"),
           control = c("GSM_b3", "GSM_b4"))
    )
  )

  # Stage 3 clusters: include sia il pair (per coherence) sia un group baseline
  # con anchor_key uguale a quello parsato dal pair (BASELINE_C|y).
  # Nota: .enrich_group_baseline_sample_ids aggiunge sample_ids list-column.
  stage3_clusters <- tibble::tibble(
    cluster_id = c("pair_aug_k2", "group_baseline"),
    mode = factor(c("pair", "group"), levels = c("pair", "group")),
    level = c(0L, 0L),
    anchor_key = c("TREATED_T|x__VS__BASELINE_C|y__CT_untreated",
                   "BASELINE_C|y"),
    studies_in_cluster = list(c("GSE_a", "GSE_b"), c("GSE_baseline_1")),
    sample_ids = list(character(0L),
                       c("GSM_bl1", "GSM_bl2", "GSM_bl3", "GSM_bl4"))
  )

  # Pre-popola un per_study_de vuoto: mega_aug branch usa fetch_fn fresh.
  per_study_de <- .empty_per_study_de()

  # Mock fetch_fn restituisce counts noisi ma stabili.
  mock_fetch <- function(gse, sample_ids) {
    set.seed(nchar(gse) * 100)
    m <- matrix(rnbinom(80 * length(sample_ids), size = 5, mu = 200),
                nrow = 80, ncol = length(sample_ids))
    rownames(m) <- paste0("GENE_", sprintf("%03d", 1:80))
    colnames(m) <- sample_ids
    m
  }

  pooled <- .pool_all_clusters(
    per_study_de = per_study_de,
    eligible_clusters = eligible,
    fetch_fn = mock_fetch,
    stage3_clusters = stage3_clusters,
    workers = 1L,
    dream_workers_cap = 2L
  )

  # Aspettative:
  #   - pooled non vuoto
  #   - method == "mega_aug"
  #   - n_baseline_studies_augmented > 0 (baseline e' stato applicato)
  expect_gt(nrow(pooled), 0L)
  expect_true(all(pooled$method == "mega_aug"))
  expect_true(all(pooled$n_baseline_studies_augmented >= 1L))
})

test_that(".enrich_group_baseline_sample_ids aggiunge sample_ids list-column", {
  # Stage 3 clusters (replicate Stage 3 output schema minimo)
  stage3_clusters <- tibble::tibble(
    cluster_id = c("group_g1", "group_g2", "pair_p1"),
    mode       = c("group", "group", "pair"),
    level      = c(0L, 0L, 0L),
    anchor_key = c("KEY1", "KEY2", "TKEY__VS__CKEY__CT_untreated"),
    studies_in_cluster = list(c("GSE_a"), c("GSE_b", "GSE_c"), c("GSE_a"))
  )
  stage3_assignments <- tibble::tibble(
    record_id  = c("GSE_a__rg_a_T", "GSE_b__rg_b_T", "GSE_c__rg_c_T",
                   "GSE_a__cmp_a_1"),
    mode       = c("group", "group", "group", "pair"),
    level      = c(0L, 0L, 0L, 0L),
    cluster_id = c("group_g1", "group_g2", "group_g2", "pair_p1"),
    anchor_key = c("KEY1", "KEY2", "KEY2", "TKEY__VS__CKEY__CT_untreated")
  )
  fix <- .make_dispatch_fixture()  # riusa stage2_master

  enriched <- .enrich_group_baseline_sample_ids(
    stage3_clusters, stage3_assignments, fix$stage2_master
  )

  # Solo group rows hanno sample_ids; pair row sample_ids = list()
  g1 <- enriched[enriched$cluster_id == "group_g1", ]
  expect_equal(sort(g1$sample_ids[[1L]]), sort(c("GSM_a1", "GSM_a2")))

  g2 <- enriched[enriched$cluster_id == "group_g2", ]
  expect_equal(
    sort(g2$sample_ids[[1L]]),
    sort(c("GSM_b1", "GSM_b2", "GSM_c1", "GSM_c2"))
  )

  # Pair row: sample_ids vuoto (non group)
  p1 <- enriched[enriched$cluster_id == "pair_p1", ]
  expect_true(length(p1$sample_ids[[1L]]) == 0L ||
                is.null(p1$sample_ids[[1L]]))
})
