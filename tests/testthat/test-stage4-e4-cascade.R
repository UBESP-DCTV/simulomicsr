# test-stage4-e4-cascade.R — FASE E4 RED ALERT
#
# Integration test cascade: tutte le features E1+E2+E3 attive insieme su
# un mock H5 sintetico. Verifica che il flow end-to-end produce counts
# + DE output coerenti con le decisioni paper-grade:
#   - Ensembl axis univoco (E1, ADR-0019 D6)
#   - biotype filter protein_coding (E2, ADR-0019 D7)
#   - covariate batch instrument_model + aligner_class (E3, ADR-0019 D8)
#   - SAMN dedupe e' su Stage 3 e non emerge in .fetch_counts_from_h5 (E0b)

# Helper fixture: H5 mini paper-grade
.mk_mock_h5_cascade <- function(n_genes = 100L, n_samples = 24L,
                                  with_biotype = TRUE) {
  skip_if_not_installed("rhdf5")
  p <- tempfile(fileext = ".h5")
  rhdf5::h5createFile(p)
  rhdf5::h5createGroup(p, "meta")
  rhdf5::h5createGroup(p, "meta/genes")
  rhdf5::h5createGroup(p, "meta/samples")
  rhdf5::h5createGroup(p, "data")

  # Geni: 50% protein_coding, 30% lncRNA, 20% miRNA. Ensembl unici.
  ensembl <- paste0("ENSG", sprintf("%011d", seq_len(n_genes)))
  symbol  <- paste0("SYM_", seq_len(n_genes))
  # Pochi duplicati symbol (paralogi simulati, ENSG distinti pero')
  symbol[2] <- symbol[1]
  symbol[4] <- symbol[3]
  biotype <- rep(c("protein_coding", "lncRNA", "miRNA"),
                  length.out = n_genes)
  rhdf5::h5write(ensembl, p, "meta/genes/ensembl_gene")
  rhdf5::h5write(symbol,  p, "meta/genes/symbol")
  if (with_biotype) {
    rhdf5::h5write(biotype, p, "meta/genes/biotype")
  }

  # Sample: 4 studi x 6 sample (3 treated + 3 control per studio)
  geo <- paste0("GSM", sprintf("%06d", seq_len(n_samples)))
  rhdf5::h5write(geo, p, "meta/samples/geo_accession")

  # Expression: rnbinom counts (samples x genes per ARCHS4 v2.5 layout)
  set.seed(42)
  expr <- matrix(rnbinom(n_samples * n_genes, size = 5, mu = 200),
                 nrow = n_samples, ncol = n_genes)
  rhdf5::h5write(expr, p, "data/expression")

  p
}

# ============================================================================
# E4 T1 — Cascade end-to-end .h5_gene_axis -> .fetch_counts_from_h5
# (Ensembl axis + biotype filter + attr gene_symbol/gene_biotype)
# ============================================================================

test_that("E4 T1 cascade: .h5_gene_axis -> .fetch_counts_from_h5 con filter protein_coding", {
  skip_if_not_installed("rhdf5")

  h5 <- .mk_mock_h5_cascade(n_genes = 30L, n_samples = 12L)
  on.exit(unlink(h5))

  # Reset cache memo per evitare hit cross-test
  rm(list = ls(envir = simulomicsr:::.h5_axis_memo),
     envir = simulomicsr:::.h5_axis_memo)

  # Step 1: .h5_gene_axis ritorna 3-comp (Ensembl + symbol + biotype)
  axis <- simulomicsr:::.h5_gene_axis(h5)
  expect_named(axis, c("ensembl_gene", "gene_symbol", "gene_biotype"))
  expect_equal(length(axis$ensembl_gene), 30L)
  expect_equal(anyDuplicated(axis$ensembl_gene), 0L)
  expect_setequal(unique(axis$gene_biotype),
                   c("protein_coding", "lncRNA", "miRNA"))

  # Step 2: .fetch_counts_from_h5 con filter protein_coding
  sample_ids <- c("GSM000001", "GSM000002", "GSM000003",
                   "GSM000004", "GSM000005", "GSM000006")
  counts <- simulomicsr:::.fetch_counts_from_h5(
    "GSE_TEST", sample_ids, h5,
    gene_biotype_filter = "protein_coding"
  )

  # 30 geni totali, 10 protein_coding (rep ciclico 1:30 -> 1,4,7,10,13,16,
  # 19,22,25,28 = 10). Verifico subset.
  expect_true(nrow(counts) <= 30L)
  expect_true(nrow(counts) >= 5L)  # almeno qualche pc
  expect_equal(ncol(counts), 6L)
  expect_true(all(grepl("^ENSG", rownames(counts))))
  # attr gene_symbol + gene_biotype attaccati
  gs <- attr(counts, "gene_symbol")
  bt <- attr(counts, "gene_biotype")
  expect_type(gs, "character")
  expect_type(bt, "character")
  expect_equal(names(gs), rownames(counts))
  expect_true(all(unname(bt) == "protein_coding"))
})

# ============================================================================
# E4 T2 — Cascade .run_dream_mega con counts cascade-filtered + covariata
# ============================================================================

test_that("E4 T2 cascade: .run_dream_mega su counts Ensembl-filtered + covariata batch", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")

  h5 <- .mk_mock_h5_cascade(n_genes = 60L, n_samples = 24L)
  on.exit(unlink(h5))
  rm(list = ls(envir = simulomicsr:::.h5_axis_memo),
     envir = simulomicsr:::.h5_axis_memo)

  sample_ids <- paste0("GSM", sprintf("%06d", 1:24))
  counts <- simulomicsr:::.fetch_counts_from_h5(
    "GSE_TEST", sample_ids, h5,
    gene_biotype_filter = "protein_coding"
  )

  # 4 studi x 6 sample (3 treated + 3 control), 2 instrument cross-study
  metadata <- data.frame(
    sample_id = sample_ids,
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(
      rep(c("treated", "treated", "treated",
            "control", "control", "control"), 4),
      levels = c("control", "treated")
    ),
    # Instrument bilanciato cross-treatment per evitare confound
    instrument_model = c("HiSeq", "NovaSeq", "HiSeq", "NovaSeq", "HiSeq", "NovaSeq",
                          "HiSeq", "NovaSeq", "HiSeq", "NovaSeq", "HiSeq", "NovaSeq",
                          "HiSeq", "NovaSeq", "HiSeq", "NovaSeq", "HiSeq", "NovaSeq",
                          "HiSeq", "NovaSeq", "HiSeq", "NovaSeq", "HiSeq", "NovaSeq"),
    stringsAsFactors = FALSE
  )

  res <- simulomicsr:::.run_dream_mega(
    counts, metadata,
    cluster_id = "TEST_CASCADE",
    workers = 1L,
    covariates = "instrument_model"
  )

  # Output schema E1: gene_id + gene_symbol (no 'gene' legacy)
  expect_true("gene_id" %in% names(res))
  expect_true("gene_symbol" %in% names(res))
  expect_false("gene" %in% names(res))
  # gene_id e' Ensembl (E1)
  expect_true(all(grepl("^ENSG", res$gene_id)))
  # Covariata batch attiva (E3) tracciata in attr
  expect_equal(attr(res, "covariates_used"), "instrument_model")
})

# ============================================================================
# E4 T3 — Edge case: H5 senza biotype + cascade
# ============================================================================

test_that("E4 T3 cascade: H5 senza biotype + filter non-NULL -> errore chiaro (Fix 5)", {
  skip_if_not_installed("rhdf5")

  h5 <- .mk_mock_h5_cascade(n_genes = 20L, n_samples = 12L,
                              with_biotype = FALSE)
  on.exit(unlink(h5))
  rm(list = ls(envir = simulomicsr:::.h5_axis_memo),
     envir = simulomicsr:::.h5_axis_memo)

  expect_error(
    simulomicsr:::.fetch_counts_from_h5(
      "GSE_TEST", paste0("GSM", sprintf("%06d", 1:6)), h5,
      gene_biotype_filter = "protein_coding"
    ),
    "meta/genes/biotype"
  )
})

# ============================================================================
# E4 T4 — Edge case: H5 senza biotype + filter NULL -> retrocompat ok
# ============================================================================

test_that("E4 T4 cascade: H5 senza biotype + filter NULL -> error (no fallback retrocompat)", {
  skip_if_not_installed("rhdf5")

  h5 <- .mk_mock_h5_cascade(n_genes = 20L, n_samples = 12L,
                              with_biotype = FALSE)
  on.exit(unlink(h5))
  rm(list = ls(envir = simulomicsr:::.h5_axis_memo),
     envir = simulomicsr:::.h5_axis_memo)

  # T7a Fix 5: .h5_gene_axis fa hard fail su meta/genes/biotype mancante
  # ANCHE con filter NULL (perche' .h5_gene_axis e' chiamato a monte e
  # non sa che filter sara' usato). Documentato comportamento paper-grade:
  # H5 legacy v1 + filter NULL richiede comunque un patch upstream
  # (es. mock biotype = NA per tutti i geni o axis legacy alternativo).
  expect_error(
    simulomicsr:::.fetch_counts_from_h5(
      "GSE_TEST", paste0("GSM", sprintf("%06d", 1:6)), h5,
      gene_biotype_filter = NULL
    ),
    "meta/genes/biotype"
  )
})

# ============================================================================
# E4 T5 — Cascade con covariata confunded col treatment
# (Fix C1 pre-fit rank check)
# ============================================================================

test_that("E4 T5 cascade: covariata confunded col treatment -> drop + fit treatment-only", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")

  h5 <- .mk_mock_h5_cascade(n_genes = 60L, n_samples = 24L)
  on.exit(unlink(h5))
  rm(list = ls(envir = simulomicsr:::.h5_axis_memo),
     envir = simulomicsr:::.h5_axis_memo)

  sample_ids <- paste0("GSM", sprintf("%06d", 1:24))
  counts <- simulomicsr:::.fetch_counts_from_h5(
    "GSE_TEST", sample_ids, h5,
    gene_biotype_filter = "protein_coding"
  )

  # Instrument PERFETTAMENTE confunded col treatment
  metadata <- data.frame(
    sample_id = sample_ids,
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(
      rep(c("treated", "treated", "treated",
            "control", "control", "control"), 4),
      levels = c("control", "treated")
    ),
    instrument_model = rep(c("HiSeq", "HiSeq", "HiSeq",
                              "NovaSeq", "NovaSeq", "NovaSeq"), 4),
    stringsAsFactors = FALSE
  )

  expect_warning(
    res <- simulomicsr:::.run_dream_mega(
      counts, metadata,
      cluster_id = "TEST_CASCADE_CONFOUND",
      workers = 1L,
      covariates = "instrument_model"
    ),
    "rank.deficient|confounded"
  )
  # Covariata droppata, fit treatment-only completato
  expect_equal(length(attr(res, "covariates_used")), 0L)
  expect_equal(attr(res, "covariates_dropped"), "instrument_model")
  # Output schema invariato
  expect_true("gene_id" %in% names(res))
})
