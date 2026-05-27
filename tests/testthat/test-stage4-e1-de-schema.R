# test-stage4-e1-de-schema.R — FASE E1 ADR-0019 D6 (integrazione T3)
#
# Test del nuovo schema DE output post-E1: colonna chiave 'gene_id'
# (Ensembl, era 'gene' = HGNC make.unique pre-E1), nuova colonna
# 'gene_symbol' (HGNC label, possibili duplicati cross-paralogi + NA).
# Defensive make.unique rimosso da .run_dream_mega (era vestigial).

# Fixture: counts matrix con attr gene_symbol set via .attach_gene_annotation.
.mk_counts_with_axis <- function(n_genes = 50L, n_samples = 6L, seed = 42L) {
  set.seed(seed)
  counts <- matrix(rnbinom(n_genes * n_samples, size = 5, mu = 200),
                   nrow = n_genes, ncol = n_samples)
  colnames(counts) <- paste0("GSM", sprintf("%06d", seq_len(n_samples)))
  axis <- list(
    ensembl_gene = paste0("ENSG", sprintf("%011d", seq_len(n_genes))),
    gene_symbol  = c(
      paste0("SYM_", seq_len(n_genes - 5L)),
      rep("KIR3DL2", 3L),  # paralogi: 3 ensembl distinti, stesso symbol
      NA_character_,        # symbol mancante (gene non annotato HGNC)
      NA_character_
    )
  )
  simulomicsr:::.attach_gene_annotation(counts, axis)
}

# ============================================================================
# T3.1 — .run_limma_voom_de output: gene_id + gene_symbol invece di gene
# ============================================================================

test_that("E1 T3.1 .run_limma_voom_de output schema: gene_id + gene_symbol", {
  skip_if_not_installed("limma")
  skip_if_not_installed("edgeR")

  counts <- .mk_counts_with_axis()
  treatment_vec <- factor(rep(c("treated", "control"), each = 3L),
                          levels = c("control", "treated"))

  res <- simulomicsr:::.run_limma_voom_de(
    counts, treatment_vec, study_id = "GSE001",
    cluster_id = "TEST", direction_flip = FALSE
  )

  expect_s3_class(res, "tbl_df")
  expect_true("gene_id" %in% names(res))
  expect_true("gene_symbol" %in% names(res))
  expect_false("gene" %in% names(res))   # colonna vecchia rimossa
  # gene_id ha prefisso ENSG (Ensembl)
  expect_true(all(grepl("^ENSG", res$gene_id)))
  # gene_symbol e' character (NA preservato dove symbol manca)
  expect_type(res$gene_symbol, "character")
})

test_that("E1 T3.1b .run_limma_voom_de: gene_symbol coerente con axis (paralogi + NA)", {
  skip_if_not_installed("limma")
  skip_if_not_installed("edgeR")

  counts <- .mk_counts_with_axis(n_genes = 50L)
  axis_orig <- attr(counts, "gene_symbol")
  treatment_vec <- factor(rep(c("treated", "control"), each = 3L),
                          levels = c("control", "treated"))

  res <- simulomicsr:::.run_limma_voom_de(
    counts, treatment_vec, study_id = "GSE001",
    cluster_id = "TEST"
  )

  # I gene_id sopravvissuti a filterByExpr devono avere il symbol giusto.
  for (i in seq_len(nrow(res))) {
    expected_sym <- axis_orig[[res$gene_id[i]]]
    actual_sym   <- res$gene_symbol[i]
    if (is.na(expected_sym)) {
      expect_true(is.na(actual_sym))
    } else {
      expect_equal(actual_sym, expected_sym)
    }
  }
})

# ============================================================================
# T3.2 — .run_dream_mega output: gene_id + gene_symbol invece di gene
# ============================================================================

test_that("E1 T3.2 .run_dream_mega output schema: gene_id + gene_symbol", {
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")
  skip_if_not_installed("edgeR")

  counts <- .mk_counts_with_axis(n_genes = 80L, n_samples = 12L)
  metadata <- data.frame(
    sample_id = colnames(counts),
    study     = factor(rep(c("S1", "S2", "S3"), each = 4L)),
    treatment = factor(rep(c("treated", "control"), times = 6L),
                       levels = c("control", "treated")),
    stringsAsFactors = FALSE
  )

  res <- simulomicsr:::.run_dream_mega(
    counts, metadata, cluster_id = "TEST_MEGA", workers = 1L
  )

  expect_s3_class(res, "tbl_df")
  expect_true("gene_id" %in% names(res))
  expect_true("gene_symbol" %in% names(res))
  expect_false("gene" %in% names(res))
  expect_true(all(grepl("^ENSG", res$gene_id)))
})

# ============================================================================
# T3.3 — .empty_per_study_de schema aggiornato
# ============================================================================

test_that("E1 T3.3 .empty_per_study_de schema: gene_id + gene_symbol (no gene)", {
  schema <- simulomicsr:::.empty_per_study_de()
  expect_true("gene_id" %in% names(schema))
  expect_true("gene_symbol" %in% names(schema))
  expect_false("gene" %in% names(schema))
  expect_type(schema$gene_id, "character")
  expect_type(schema$gene_symbol, "character")
})

# ============================================================================
# T3.4 — .empty_pooled_rem schema aggiornato
# ============================================================================

test_that("E1 T3.4 .empty_pooled_rem schema: gene_id + gene_symbol (no gene)", {
  schema <- simulomicsr:::.empty_pooled_rem()
  expect_true("gene_id" %in% names(schema))
  expect_true("gene_symbol" %in% names(schema))
  expect_false("gene" %in% names(schema))
})
