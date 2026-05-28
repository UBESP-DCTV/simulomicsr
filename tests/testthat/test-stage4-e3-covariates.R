# test-stage4-e3-covariates.R — FASE E3 ADR-0019 D8
#
# Test per il design DE con covariate batch (instrument_model +
# aligner_class) nel pool Stadio 4.
#
# Decisione utente RED ALERT FASE E3: il design lineare DE include
# covariate tecniche batch oltre treatment + study(random per dream).
# Single-level covariate -> drop + warning (rank-deficient). NA covariata
# -> livello 'unknown' (preserva sample). Tracciato in qc_report
# pooling_warnings per il revisore del paper.

# ============================================================================
# T1.1 — covariata multi-level: aggiunta al design + ritornata
# ============================================================================

test_that("E3 T1.1 .augment_de_design: covariata multi-level -> aggiunta + factor preservato", {
  metadata <- data.frame(
    sample_id = paste0("GSM", 1:6),
    treatment = factor(rep(c("treated", "control"), 3),
                        levels = c("control", "treated")),
    instrument_model = c("HiSeq2500", "HiSeq2500", "NovaSeq6000",
                          "NovaSeq6000", "HiSeq4000", "HiSeq4000"),
    stringsAsFactors = FALSE
  )
  res <- simulomicsr:::.augment_de_design(
    metadata,
    covariates = "instrument_model",
    cluster_id = "TEST_T1.1"
  )

  expect_named(res, c("formula_terms", "metadata_aug", "covariates_used",
                       "covariates_dropped", "drop_log"))
  expect_equal(res$formula_terms, "instrument_model")
  expect_equal(res$covariates_used, "instrument_model")
  expect_equal(length(res$covariates_dropped), 0L)
  # factor ottenuto con 3 levels univoci
  expect_s3_class(res$metadata_aug$instrument_model, "factor")
  expect_setequal(levels(res$metadata_aug$instrument_model),
                   c("HiSeq2500", "HiSeq4000", "NovaSeq6000"))
})

# ============================================================================
# T1.2 — covariata single-level: drop + warning
# ============================================================================

test_that("E3 T1.2 .augment_de_design: covariata single-level (es. studio singolo) -> drop con warning + log", {
  metadata <- data.frame(
    sample_id = paste0("GSM", 1:4),
    treatment = factor(rep(c("treated", "control"), 2),
                        levels = c("control", "treated")),
    instrument_model = rep("HiSeq2500", 4),  # 1 level only
    stringsAsFactors = FALSE
  )
  expect_warning(
    res <- simulomicsr:::.augment_de_design(
      metadata,
      covariates = "instrument_model",
      cluster_id = "TEST_T1.2"
    ),
    "single-level"
  )
  expect_equal(res$formula_terms, "")
  expect_equal(length(res$covariates_used), 0L)
  expect_equal(res$covariates_dropped, "instrument_model")
  expect_equal(nrow(res$drop_log), 1L)
  expect_equal(res$drop_log$reason, "single_level")
})

# ============================================================================
# T1.3 — covariata missing dal metadata: skip silenzioso con warning
# ============================================================================

test_that("E3 T1.3 .augment_de_design: covariata richiesta ma assente dal metadata -> skip + warning", {
  metadata <- data.frame(
    sample_id = paste0("GSM", 1:4),
    treatment = factor(rep(c("treated", "control"), 2),
                        levels = c("control", "treated")),
    stringsAsFactors = FALSE
    # instrument_model + aligner_class assenti
  )
  expect_warning(
    res <- simulomicsr:::.augment_de_design(
      metadata,
      covariates = c("instrument_model", "aligner_class"),
      cluster_id = "TEST_T1.3"
    ),
    "instrument_model"
  )
  expect_equal(res$formula_terms, "")
  expect_setequal(res$covariates_dropped, c("instrument_model", "aligner_class"))
  expect_setequal(res$drop_log$reason, "missing_from_metadata")
})

# ============================================================================
# T1.4 — covariata con NA partial: NA convertito a livello 'unknown'
# ============================================================================

test_that("E3 T1.4 .augment_de_design: NA partial nella covariata -> livello 'unknown' (preserva sample)", {
  metadata <- data.frame(
    sample_id = paste0("GSM", 1:6),
    treatment = factor(rep(c("treated", "control"), 3),
                        levels = c("control", "treated")),
    aligner_class = c("STAR", "STAR", NA_character_, "Salmon", "Salmon",
                       NA_character_),
    stringsAsFactors = FALSE
  )
  res <- simulomicsr:::.augment_de_design(
    metadata,
    covariates = "aligner_class",
    cluster_id = "TEST_T1.4"
  )
  expect_equal(res$formula_terms, "aligner_class")
  expect_true("unknown" %in% levels(res$metadata_aug$aligner_class))
  expect_equal(sum(res$metadata_aug$aligner_class == "unknown"), 2L)
})

# ============================================================================
# T1.5 — 2 covariate, una single-level + una multi-level: solo multi-level kept
# ============================================================================

test_that("E3 T1.5 .augment_de_design: mix single+multi-level -> tiene solo multi-level", {
  metadata <- data.frame(
    sample_id = paste0("GSM", 1:4),
    treatment = factor(rep(c("treated", "control"), 2),
                        levels = c("control", "treated")),
    instrument_model = rep("HiSeq2500", 4),  # single-level
    aligner_class = c("STAR", "STAR", "Salmon", "Salmon"),  # multi-level
    stringsAsFactors = FALSE
  )
  suppressWarnings(
    res <- simulomicsr:::.augment_de_design(
      metadata,
      covariates = c("instrument_model", "aligner_class"),
      cluster_id = "TEST_T1.5"
    )
  )
  expect_equal(res$formula_terms, "aligner_class")
  expect_equal(res$covariates_used, "aligner_class")
  expect_equal(res$covariates_dropped, "instrument_model")
})

# ============================================================================
# T1.6 — covariates = character(0) o NULL: no-op, design treatment-only
# ============================================================================

test_that("E3 T2.1 .run_limma_voom_de senza covariate (default): behavior invariato", {
  skip_if_not_installed("limma")
  skip_if_not_installed("edgeR")

  set.seed(42)
  counts <- matrix(rnbinom(600, size = 5, mu = 100), nrow = 100, ncol = 6)
  rownames(counts) <- paste0("ENSG", sprintf("%05d", 1:100))
  colnames(counts) <- paste0("GSM", 1:6)
  treatment_vec <- factor(rep(c("treated", "control"), each = 3),
                          levels = c("control", "treated"))

  res <- simulomicsr:::.run_limma_voom_de(
    counts, treatment_vec, "GSE001", "TEST_T2.1"
  )
  expect_true("gene_id" %in% names(res))
  # Niente attr di covariate quando covariates default (character(0))
  expect_null(attr(res, "covariates_used"))
})

test_that("E3 T2.2 .run_limma_voom_de con covariata multi-level: design include covariata", {
  skip_if_not_installed("limma")
  skip_if_not_installed("edgeR")

  set.seed(42)
  counts <- matrix(rnbinom(600, size = 5, mu = 100), nrow = 100, ncol = 6)
  rownames(counts) <- paste0("ENSG", sprintf("%05d", 1:100))
  colnames(counts) <- paste0("GSM", 1:6)
  treatment_vec <- factor(rep(c("treated", "control"), each = 3),
                          levels = c("control", "treated"))
  # Instrument non-confunded col treatment: 2 instrument distribuiti
  # cross-treatment (entrambi i livelli in entrambe le condizioni)
  metadata_extra <- data.frame(
    sample_id = paste0("GSM", 1:6),
    instrument_model = c("HiSeq2500", "HiSeq2500", "NovaSeq6000",
                          "HiSeq2500", "NovaSeq6000", "NovaSeq6000"),
    stringsAsFactors = FALSE
  )

  res <- simulomicsr:::.run_limma_voom_de(
    counts, treatment_vec, "GSE001", "TEST_T2.2",
    metadata_extra = metadata_extra,
    covariates = "instrument_model"
  )
  expect_true("gene_id" %in% names(res))
  # L'output tracking espone le covariate effettivamente usate
  expect_equal(attr(res, "covariates_used"), "instrument_model")
  expect_equal(length(attr(res, "covariates_dropped")), 0L)
})

test_that("E3 T2.3 .run_limma_voom_de con covariata single-level: drop + behavior invariato", {
  skip_if_not_installed("limma")
  skip_if_not_installed("edgeR")

  set.seed(42)
  counts <- matrix(rnbinom(600, size = 5, mu = 100), nrow = 100, ncol = 6)
  rownames(counts) <- paste0("ENSG", sprintf("%05d", 1:100))
  colnames(counts) <- paste0("GSM", 1:6)
  treatment_vec <- factor(rep(c("treated", "control"), each = 3),
                          levels = c("control", "treated"))
  metadata_extra <- data.frame(
    sample_id = paste0("GSM", 1:6),
    instrument_model = rep("HiSeq2500", 6),  # single-level (single study)
    stringsAsFactors = FALSE
  )

  expect_warning(
    res <- simulomicsr:::.run_limma_voom_de(
      counts, treatment_vec, "GSE001", "TEST_T2.3",
      metadata_extra = metadata_extra,
      covariates = "instrument_model"
    ),
    "single-level"
  )
  expect_equal(attr(res, "covariates_dropped"), "instrument_model")
  expect_equal(length(attr(res, "covariates_used")), 0L)
})

test_that("E3 T3.1 .run_dream_mega senza covariate (default): behavior invariato", {
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")

  set.seed(42)
  n_genes <- 50; n_samples <- 24
  counts <- matrix(rnbinom(n_genes * n_samples, size = 5, mu = 200),
                   nrow = n_genes, ncol = n_samples)
  rownames(counts) <- paste0("ENSG", sprintf("%05d", 1:n_genes))
  colnames(counts) <- paste0("GSM", 1:n_samples)
  metadata <- data.frame(
    sample_id = colnames(counts),
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(rep(c("treated","treated","treated",
                              "control","control","control"), 4),
                        levels = c("control", "treated"))
  )

  res <- simulomicsr:::.run_dream_mega(counts, metadata,
                                         cluster_id = "TEST_T3.1",
                                         workers = 1L)
  expect_true("gene_id" %in% names(res))
  expect_null(attr(res, "covariates_used"))
})

test_that("E3 T3.2 .run_dream_mega con covariata cross-study (instrument_model variabile): kept", {
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")

  set.seed(42)
  n_genes <- 80; n_samples <- 24
  counts <- matrix(rnbinom(n_genes * n_samples, size = 5, mu = 200),
                   nrow = n_genes, ncol = n_samples)
  rownames(counts) <- paste0("ENSG", sprintf("%05d", 1:n_genes))
  colnames(counts) <- paste0("GSM", 1:n_samples)
  # 4 studi, 2 instrument (variabile cross-study, non-confunded col treatment)
  metadata <- data.frame(
    sample_id = colnames(counts),
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(rep(c("treated","treated","treated",
                              "control","control","control"), 4),
                        levels = c("control", "treated")),
    instrument_model = rep(c("HiSeq2500", "NovaSeq6000"), each = 12),
    stringsAsFactors = FALSE
  )

  res <- simulomicsr:::.run_dream_mega(
    counts, metadata,
    cluster_id = "TEST_T3.2",
    workers = 1L,
    covariates = "instrument_model"
  )
  expect_true("gene_id" %in% names(res))
  expect_equal(attr(res, "covariates_used"), "instrument_model")
})

test_that("E3 T1.6 .augment_de_design: covariates NULL/empty -> no-op", {
  metadata <- data.frame(
    sample_id = paste0("GSM", 1:4),
    treatment = factor(rep(c("treated", "control"), 2),
                        levels = c("control", "treated")),
    stringsAsFactors = FALSE
  )
  res_null  <- simulomicsr:::.augment_de_design(metadata, NULL, "T1.6")
  res_empty <- simulomicsr:::.augment_de_design(metadata, character(0), "T1.6")
  expect_equal(res_null$formula_terms, "")
  expect_equal(res_empty$formula_terms, "")
  expect_equal(length(res_null$covariates_used), 0L)
})
