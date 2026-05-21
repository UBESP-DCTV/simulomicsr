# Test per .assemble_mega_aug_metadata_bidir() (R/stage4-mega-aug.R)
#
# Coprono:
# - direction "control": metadata identica al legacy monodirectional
# - direction "treated": augmenta il braccio treated invece del control
# - direction "both": augmenta entrambi
# - dedup: sample del pair non duplicati nel baseline
# - comparison_kind_control/treated/overall popolati correttamente
# - baseline_pool_ids tracciati
# - no candidate: ritorna metadata = pair rows + NA kinds + 0 augmented

# -- Fixture builders -------------------------------------------------------

make_pair_cluster_list <- function(...) {
  list(
    cluster_id            = "pair_L4_test",
    level                 = 4L,
    anchor_key            = paste0(
      "small_molecule|Parthenolide|stomach__VS__",
      "vehicle_only|Dimethyl sulfoxide|stomach"
    ),
    studies_in_cluster    = c("GSE001", "GSE002"),
    treated_samples       = list(c("GSM_A1", "GSM_A2")),
    control_samples       = list(c("GSM_C1", "GSM_C2")),
    treated_sample_studies = list(c("GSE001", "GSE001")),
    control_sample_studies = list(c("GSE002", "GSE002")),
    ...
  )
}

make_group_baseline <- function() {
  tibble::tibble(
    cluster_id        = c("group_L4_ctrl", "group_L4_trt"),
    mode              = "group",
    level             = 4L,
    anchor_key        = c(
      "vehicle_only|Dimethyl sulfoxide|stomach",
      "small_molecule|Parthenolide|stomach"
    ),
    n_studies         = c(5L, 4L),
    n_total           = c(40L, 20L),
    studies_in_cluster = list(
      c("GSE100", "GSE101", "GSE102", "GSE103", "GSE104"),
      c("GSE200", "GSE201", "GSE202", "GSE203")
    ),
    sample_ids = list(
      paste0("GSM_BC_", 1:8),
      paste0("GSM_BT_", 1:6)
    ),
    sample_studies = list(
      c(rep("GSE100", 2), rep("GSE101", 2), rep("GSE102", 1),
        rep("GSE103", 2), rep("GSE104", 1)),
      c(rep("GSE200", 2), rep("GSE201", 1), rep("GSE202", 2),
        rep("GSE203", 1))
    )
  )
}

# ===========================================================================

test_that("bidir direction='control' augmenta il braccio control come legacy", {
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  matcher <- make_anchor_matcher("strict")

  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher,
    direction = "control",
    min_baseline_studies = 2L
  )

  expect_named(res, c(
    "metadata",
    "n_baseline_studies_augmented_control",
    "n_baseline_studies_augmented_treated",
    "comparison_kind_control",
    "comparison_kind_treated",
    "comparison_kind_overall",
    "baseline_pool_ids",
    "bidir_collapsed_to_mono"
  ))

  # 4 pair rows + 8 baseline rows = 12
  expect_equal(nrow(res$metadata), 12L)
  # baseline appare come "control" treatment
  baseline_rows <- res$metadata[res$metadata$sample_id %in% paste0("GSM_BC_", 1:8), ]
  expect_true(all(baseline_rows$treatment == "control"))
  expect_equal(res$n_baseline_studies_augmented_control, 5L)
  expect_equal(res$n_baseline_studies_augmented_treated, 0L)
  expect_identical(res$baseline_pool_ids$control, "group_L4_ctrl")
  expect_null(res$baseline_pool_ids$treated)
})

test_that("bidir direction='treated' augmenta il braccio treated", {
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  matcher <- make_anchor_matcher("strict")

  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher,
    direction = "treated",
    min_baseline_studies = 2L
  )

  # 4 pair + 6 treated baseline = 10
  expect_equal(nrow(res$metadata), 10L)
  # treated baseline rows hanno treatment = "treated"
  baseline_rows <- res$metadata[res$metadata$sample_id %in% paste0("GSM_BT_", 1:6), ]
  expect_true(all(baseline_rows$treatment == "treated"))
  expect_equal(res$n_baseline_studies_augmented_control, 0L)
  expect_equal(res$n_baseline_studies_augmented_treated, 4L)
  expect_identical(res$baseline_pool_ids$treated, "group_L4_trt")
  expect_null(res$baseline_pool_ids$control)
})

test_that("bidir direction='both' augmenta entrambi gli arm", {
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  matcher <- make_anchor_matcher("strict")

  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher,
    direction = "both",
    min_baseline_studies = 2L
  )

  # 4 pair + 8 control aug + 6 treated aug = 18
  expect_equal(nrow(res$metadata), 18L)
  expect_equal(res$n_baseline_studies_augmented_control, 5L)
  expect_equal(res$n_baseline_studies_augmented_treated, 4L)
  expect_identical(res$baseline_pool_ids$control, "group_L4_ctrl")
  expect_identical(res$baseline_pool_ids$treated, "group_L4_trt")
})

test_that("bidir comparison_kind: indirect_partial quando 0 overlap E entrambi multi-study", {
  # pair: GSE001/002, control baseline: GSE100..104 (5 studi), no overlap
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher, direction = "both"
  )
  # control: |pair|=2, |baseline|=5, overlap=0 -> indirect_partial
  expect_identical(res$comparison_kind_control, "indirect_partial")
  # treated: |pair|=2, |baseline|=4, overlap=0 -> indirect_partial
  expect_identical(res$comparison_kind_treated, "indirect_partial")
  # overall: peggior caso (max severity) = indirect_partial
  expect_identical(res$comparison_kind_overall, "indirect_partial")
})

test_that("bidir comparison_kind: direct_overlap se uno studio comune", {
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  # Forziamo overlap: il control baseline include uno studio del pair
  group_baseline$studies_in_cluster[[1L]] <- c("GSE002", "GSE101", "GSE102", "GSE103", "GSE104")
  group_baseline$sample_studies[[1L]] <- c(rep("GSE002", 2), rep("GSE101", 2),
                                              rep("GSE102", 1), rep("GSE103", 2),
                                              rep("GSE104", 1))
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher, direction = "both"
  )
  expect_identical(res$comparison_kind_control, "direct_overlap")
  expect_identical(res$comparison_kind_treated, "indirect_partial")
  # overall: il MEGLIO dei due (LEAST severe) — direct overlap > indirect_partial
  expect_identical(res$comparison_kind_overall, "direct_overlap")
})

test_that("bidir comparison_kind: indirect_disjoint se baseline ha < 3 studi", {
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  # Riduci control baseline a 2 studi
  group_baseline$n_studies[1L] <- 2L
  group_baseline$studies_in_cluster[[1L]] <- c("GSE100", "GSE101")
  group_baseline$sample_studies[[1L]] <- c(rep("GSE100", 4), rep("GSE101", 4))
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher, direction = "both"
  )
  expect_identical(res$comparison_kind_control, "indirect_disjoint")
})

test_that("bidir dedup: sample del pair NON inclusi nel baseline rows", {
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  # Iniettiamo un sample del pair (GSM_C1) nel baseline control:
  # deve essere droppato dal baseline rows.
  group_baseline$sample_ids[[1L]][1L] <- "GSM_C1"
  group_baseline$sample_studies[[1L]][1L] <- "GSE002"
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher, direction = "control"
  )
  # Conto totale: 4 pair + 7 baseline (1 droppato) = 11
  expect_equal(nrow(res$metadata), 11L)
  # GSM_C1 deve apparire UNA volta sola (come pair control)
  expect_equal(sum(res$metadata$sample_id == "GSM_C1"), 1L)
})

test_that("bidir: baseline completamente sovrapposto al pair -> no augmentation effettiva (NA kinds, NULL pool_ids)", {
  # Smoke 5-pick 2026-05-20 ha esposto questo caso: pair piccoli (k=2 entro
  # 2 studi) hanno baseline pool group derivato dallo stesso replicate_group
  # del pair -> 100% overlap sample-level -> dedup elimina TUTTI i baseline
  # sample. Devo riportare kind=NA e baseline_pool_id=NULL, non
  # indirect_disjoint con n_aug=0 (semanticamente sbagliato).
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  # Forziamo overlap totale: il baseline control ha SOLO i sample del pair
  group_baseline$sample_ids[[1L]]     <- c("GSM_C1", "GSM_C2")  # = pair_control_samples
  group_baseline$sample_studies[[1L]] <- c("GSE002", "GSE002")  # = pair_control_studies
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher, direction = "control"
  )
  # Metadata = solo pair rows (nessun baseline aggiunto post-dedup)
  expect_equal(nrow(res$metadata), 4L)
  expect_equal(res$n_baseline_studies_augmented_control, 0L)
  expect_true(is.na(res$comparison_kind_control))
  expect_true(is.na(res$comparison_kind_overall))
  expect_null(res$baseline_pool_ids$control)
})

test_that("bidir direction='both' con pool distinti NON collassa a mono", {
  # Caso normale: control e treated matchano pool DIVERSI -> niente collisione.
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher, direction = "both"
  )
  expect_false(res$bidir_collapsed_to_mono)
})

test_that("bidir: stesso baseline pool su entrambi gli arm -> mono-fallback su control", {
  # Discovery 2026-05-21 fullrun crash (pair_L0_e45151a4, pair_L1_37c75531,
  # pair_L2_a28b250f): quando treated_anchor e control_anchor del pair sono
  # indistinguibili (identici a L2+, o differenti solo nei relaxed_segments a
  # L0/L1), UN SOLO group baseline pool matcha ENTRAMBI i bracci. Aggiungerlo
  # sia a control sia a treated produce sample_id duplicati -> crash
  # "duplicate 'row.names'" in .run_dream_mega. Fix Opzione 1 (utente
  # 2026-05-21): se top_control == top_treated, augmenta SOLO il braccio
  # control (= comportamento legacy monodirezionale validato) e marca il
  # cluster con bidir_collapsed_to_mono = TRUE.
  pair_cluster <- list(
    cluster_id            = "pair_L4_collide",
    level                 = 4L,
    # treated_anchor IDENTICO a control_anchor -> ogni pool matcha entrambi.
    anchor_key            = paste0(
      "small_molecule|Parthenolide|stomach__VS__",
      "small_molecule|Parthenolide|stomach"
    ),
    studies_in_cluster    = c("GSE001", "GSE002"),
    treated_samples       = list(c("GSM_A1", "GSM_A2")),
    control_samples       = list(c("GSM_C1", "GSM_C2")),
    treated_sample_studies = list(c("GSE001", "GSE001")),
    control_sample_studies = list(c("GSE002", "GSE002"))
  )
  group_baseline <- tibble::tibble(
    cluster_id        = "group_L4_shared",
    mode              = "group",
    level             = 4L,
    anchor_key        = "small_molecule|Parthenolide|stomach",
    n_studies         = 5L,
    n_total           = 40L,
    studies_in_cluster = list(c("GSE100", "GSE101", "GSE102", "GSE103", "GSE104")),
    sample_ids         = list(paste0("GSM_BC_", 1:8)),
    sample_studies     = list(c(rep("GSE100", 2), rep("GSE101", 2),
                                 rep("GSE102", 1), rep("GSE103", 2),
                                 rep("GSE104", 1)))
  )
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher,
    direction = "both", min_baseline_studies = 2L
  )

  # (1) nessun sample_id duplicato: il crash NON deve poter avvenire.
  expect_equal(anyDuplicated(res$metadata$sample_id), 0L)
  # (2) flag di collasso attivo.
  expect_true(res$bidir_collapsed_to_mono)
  # (3) baseline aggiunto SOLO al braccio control.
  baseline_rows <- res$metadata[res$metadata$sample_id %in% paste0("GSM_BC_", 1:8), ]
  expect_equal(nrow(baseline_rows), 8L)
  expect_true(all(baseline_rows$treatment == "control"))
  # (4) braccio treated NON augmentato + diagnostics onesti.
  expect_equal(res$n_baseline_studies_augmented_treated, 0L)
  expect_true(is.na(res$comparison_kind_treated))
  expect_null(res$baseline_pool_ids$treated)
  expect_identical(res$baseline_pool_ids$control, "group_L4_shared")
  # (5) 4 pair rows + 8 control-augmented = 12.
  expect_equal(nrow(res$metadata), 12L)
})

test_that("bidir: pool distinti che condividono un sample -> sample droppato da entrambi i bracci", {
  # Discovery 2026-05-21 scan completo: 7 cluster mega_aug hanno control pool e
  # treated pool DIVERSI (cluster_id distinti) che pero' condividono GSM. Accade
  # quando lo stesso GSM e' in replicate_group assegnati a group cluster diversi
  # (duplicazione ARCHS4 super-series: stesso sample in piu' GSE). Aggiungerlo a
  # entrambi i bracci lo duplica -> crash. Fix: il sample condiviso ha ruolo
  # ambiguo -> droppato da ENTRAMBI i blocchi baseline (coerente con
  # .build_mega_metadata_safe role_conflict_dropped, paper-grade).
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  # group_L4_ctrl (riga 1) e group_L4_trt (riga 2) condividono GSM_SHARED.
  group_baseline$sample_ids[[1L]]     <- c(group_baseline$sample_ids[[1L]], "GSM_SHARED")
  group_baseline$sample_studies[[1L]] <- c(group_baseline$sample_studies[[1L]], "GSE104")
  group_baseline$sample_ids[[2L]]     <- c(group_baseline$sample_ids[[2L]], "GSM_SHARED")
  group_baseline$sample_studies[[2L]] <- c(group_baseline$sample_studies[[2L]], "GSE203")
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher, direction = "both"
  )
  # (1) nessun sample_id duplicato.
  expect_equal(anyDuplicated(res$metadata$sample_id), 0L)
  # (2) GSM_SHARED rimosso da entrambi i bracci.
  expect_false("GSM_SHARED" %in% res$metadata$sample_id)
  # (3) gli altri baseline sample sopravvivono su entrambi i lati.
  expect_true(all(paste0("GSM_BC_", 1:8) %in% res$metadata$sample_id))
  expect_true(all(paste0("GSM_BT_", 1:6) %in% res$metadata$sample_id))
  # (4) non e' un collapse-to-mono: i pool sono distinti.
  expect_false(res$bidir_collapsed_to_mono)
  # (5) 4 pair + 8 control + 6 treated = 18.
  expect_equal(nrow(res$metadata), 18L)
})

test_that("bidir senza candidate ritorna solo le pair rows + NA kinds", {
  pair_cluster <- make_pair_cluster_list()
  group_baseline <- make_group_baseline()
  # Cambio anchor del baseline control e treated cosi' nessun match
  group_baseline$anchor_key <- c(
    "vehicle_only|Dimethyl sulfoxide|skin",
    "small_molecule|Parthenolide|skin"
  )
  matcher <- make_anchor_matcher("strict")
  res <- .assemble_mega_aug_metadata_bidir(
    pair_cluster, group_baseline, matcher, direction = "both"
  )
  expect_equal(nrow(res$metadata), 4L)  # solo pair rows
  expect_equal(res$n_baseline_studies_augmented_control, 0L)
  expect_equal(res$n_baseline_studies_augmented_treated, 0L)
  expect_true(is.na(res$comparison_kind_control))
  expect_true(is.na(res$comparison_kind_treated))
  expect_true(is.na(res$comparison_kind_overall))
  expect_null(res$baseline_pool_ids$control)
  expect_null(res$baseline_pool_ids$treated)
})
