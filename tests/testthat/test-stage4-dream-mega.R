# Test per .run_dream_mega: dream MEGA `~ treatment + (1|study)` su
# 4 studi x 6 sample (3 treated + 3 control) x 50 geni.
test_that(".run_dream_mega produce tibble gene-level con logFC_pool + SE_pool", {
  skip_if_not_installed("variancePartition")

  # Fixture: 50 geni x 24 sample (4 studi x 6 sample, 3 treated + 3 control)
  set.seed(42)
  n_genes <- 50
  n_samples <- 24
  counts <- matrix(
    rnbinom(n_genes * n_samples, size = 5, mu = 200),
    nrow = n_genes, ncol = n_samples
  )
  rownames(counts) <- paste0("GENE_", sprintf("%03d", seq_len(n_genes)))
  colnames(counts) <- paste0("GSM", sprintf("%06d", seq_len(n_samples)))

  metadata <- data.frame(
    sample_id = colnames(counts),
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(
      rep(c("treated", "treated", "treated",
            "control", "control", "control"), 4),
      levels = c("control", "treated")
    )
  )

  res <- .run_dream_mega(counts, metadata, cluster_id = "TEST_MEGA",
                          workers = 1L)

  expect_s3_class(res, "tbl_df")
  expect_named(res, c("cluster_id", "gene", "method", "logFC_pool", "SE_pool",
                       "p_value_pool", "tau2", "I2", "Q", "Q_pval",
                       "k_effective", "n_baseline_studies_augmented",
                       "FDR_BH_within_cluster", "direction_applied"),
                ignore.order = TRUE)
  expect_equal(unique(res$method), "mega")
  expect_equal(unique(res$k_effective), 4L)
  expect_true(all(is.na(res$tau2)))
  expect_true(all(is.finite(res$logFC_pool)))
})

test_that(".run_dream_mega workers=4 produce risultati identici a workers=1", {
  # Conferma determinismo del parallel MulticoreParam (ADR-0015 default).
  # lme4 LMM fit non usa RNG; voom non usa RNG dopo TMM. Risultati attesi
  # bit-identici tra serial/parallel.
  skip_if_not_installed("variancePartition")
  skip_if_not_installed("BiocParallel")

  set.seed(42)
  n_genes <- 50; n_samples <- 24
  counts <- matrix(rnbinom(n_genes * n_samples, size = 5, mu = 200),
                   nrow = n_genes, ncol = n_samples)
  rownames(counts) <- paste0("GENE_", sprintf("%03d", seq_len(n_genes)))
  colnames(counts) <- paste0("GSM", sprintf("%06d", seq_len(n_samples)))
  metadata <- data.frame(
    sample_id = colnames(counts),
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(rep(c("treated","treated","treated",
                              "control","control","control"), 4),
                        levels = c("control", "treated"))
  )

  res1 <- .run_dream_mega(counts, metadata, cluster_id = "DET_TEST",
                           workers = 1L)
  res4 <- .run_dream_mega(counts, metadata, cluster_id = "DET_TEST",
                           workers = 4L)

  # Ordine geni e schema identici
  expect_equal(res1$gene, res4$gene)
  # logFC + SE + p-value identici a ~tolerance machine epsilon
  expect_equal(res1$logFC_pool, res4$logFC_pool, tolerance = 1e-10)
  expect_equal(res1$SE_pool, res4$SE_pool, tolerance = 1e-10)
  expect_equal(res1$p_value_pool, res4$p_value_pool, tolerance = 1e-10)
  expect_equal(res1$FDR_BH_within_cluster, res4$FDR_BH_within_cluster,
                tolerance = 1e-10)
})

test_that(".run_dream_mega gestisce rownames gene duplicati senza crash", {
  # Discovery 2026-05-21: ARCHS4 v2.5 ha 4638/67186 simboli HGNC duplicati.
  # Rownames duplicati fanno fallire dream con "duplicate 'row.names'", e il
  # fallback silenzioso a limma maschererebbe il problema. .run_dream_mega
  # deve disambiguare i rownames (make.unique) e completare normalmente.
  skip_if_not_installed("variancePartition")

  set.seed(42)
  n_genes <- 50; n_samples <- 24
  counts <- matrix(rnbinom(n_genes * n_samples, size = 5, mu = 200),
                   nrow = n_genes, ncol = n_samples)
  # Inietta simboli duplicati: i primi 6 geni condividono 3 simboli (x2),
  # come accade per i simboli HGNC non unici di ARCHS4.
  gsym <- paste0("GENE_", sprintf("%03d", seq_len(n_genes)))
  gsym[2] <- gsym[1]; gsym[4] <- gsym[3]; gsym[6] <- gsym[5]
  rownames(counts) <- gsym
  colnames(counts) <- paste0("GSM", sprintf("%06d", seq_len(n_samples)))
  metadata <- data.frame(
    sample_id = colnames(counts),
    study = factor(rep(paste0("GSE00", 1:4), each = 6)),
    treatment = factor(rep(c("treated", "treated", "treated",
                              "control", "control", "control"), 4),
                        levels = c("control", "treated"))
  )

  expect_no_error(
    res <- .run_dream_mega(counts, metadata, cluster_id = "TEST_DUPGENE",
                            workers = 1L)
  )
  expect_s3_class(res, "tbl_df")
  # i gene nell'output sono unici (make.unique applicato)
  expect_equal(anyDuplicated(res$gene), 0L)
  expect_true(all(is.finite(res$logFC_pool)))
})
