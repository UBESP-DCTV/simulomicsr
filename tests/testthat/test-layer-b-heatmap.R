test_that(".build_heatmap writes PNG with vst+ComBat + annotation rows", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(42)
  n_genes <- 200
  n_samples_per_study <- 8
  n_studies <- 2
  n_samples <- n_samples_per_study * n_studies

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 50)
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", seq_len(n_studies)), each = n_samples_per_study),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "vst", ignore.case = TRUE)
})

test_that(".build_heatmap skips ComBat con caption esplicativa su single treatment", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")
  set.seed(1)
  n_genes <- 100
  n_samples <- 12

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 20, cluster_id = "cl_single_treat")
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  # Tutti control: single treatment level
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id  = rep(paste0("GSE", 1:2), each = 6),
    treatment = rep("control", n_samples)
  )

  out_dir <- tempfile("hm_single_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  expect_warning(
    result <- simulomicsr:::.build_heatmap(
      counts = counts, metadata = metadata,
      cluster_pooled_subset = cp,
      out_dir = out_dir, config = cfg
    ),
    "single treatment"
  )
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "ComBat skipped")
})

test_that(".build_heatmap subsamples to max_heatmap_samples", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(1)
  n_genes <- 100
  n_samples <- 150  # > max_heatmap_samples default (100)

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 30, cluster_id = "cl_big")
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:3), each = 50),
    treatment = rep(c("control", "treated"), length.out = n_samples)
  )

  out_dir <- tempfile("hm_big_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_match(result$caption, "subsampled to")
})

test_that(".build_heatmap deduplicates rows sharing gene_symbol before applying top_n (multi-Ensembl artifact)", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(7)
  n_genes <- 20
  n_samples <- 12

  # 8 geni sig (FDR<thr), ma solo 4 gene_symbol distinti (2 righe/simbolo):
  # artefatto multi-Ensembl. Il resto non-sig.
  logFC <- c(rnorm(8, 0, 3), rnorm(n_genes - 8, 0, 0.3))
  pv <- c(runif(8, 1e-10, 0.001), runif(n_genes - 8, 0.05, 1))
  cp <- tibble::tibble(
    cluster_id = "cl_hm_dedup",
    gene_id = paste0("ENSG", sprintf("%011d", seq_len(n_genes))),
    gene_symbol = c(rep(c("A", "B", "C", "D"), each = 2), paste0("SYM_", 9:n_genes)),
    method = "mega",
    logFC_pool = logFC,
    SE_pool = abs(logFC) / 5 + 0.1,
    p_value_pool = pv,
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = p.adjust(pv, method = "BH"),
    direction_applied = "none"
  )
  # cfg$top_n_heatmap default (30) >> 8 sig rows / 4 distinct symbols: senza
  # dedup la caption riporterebbe "top 8"; con dedup "top 4".
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:2), each = 6),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_dedup_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_match(result$caption, "top 4 DE genes")
})

test_that(".build_heatmap ranks by significance (FDR asc), not raw |logFC|", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(11)
  n_samples <- 12
  # Solo 2 geni sig: MARKER_A (FDR bassissimo, logFC modesto) e NOISY_B
  # (ancora sig ma FDR piu alto, logFC enorme). top_n_heatmap=1 forza la
  # scelta: col vecchio criterio (|logFC| desc) vincerebbe NOISY_B.
  cp <- tibble::tibble(
    cluster_id = "cl_hm_rank",
    gene_id = c("ENSG_A", "ENSG_B"),
    gene_symbol = c("MARKER_A", "NOISY_B"),
    method = "mega",
    logFC_pool = c(0.6, 5.0),
    SE_pool = c(0.1, 2.0),
    p_value_pool = c(1e-12, 0.04),
    tau2 = NA_real_, I2 = c(10, 90), Q = NA_real_, Q_pval = NA_real_,
    k_effective = c(20L, 2L),
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = c(1e-10, 0.049),
    direction_applied = "none"
  )
  counts <- matrix(rpois(2 * n_samples, lambda = 100), nrow = 2,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:2), each = 6),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_rank_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  cfg$top_n_heatmap <- 1L

  # Il testo dell'SVG e' codificato come glyph reference (`<use xlink:href=
  # "#glyph-...">`), non stringhe leggibili -> per verificare QUALE gene e'
  # stato scelto intercettiamo l'argomento `row_labels`/rownames passato a
  # `ComplexHeatmap::Heatmap()` (mock, niente rendering reale).
  captured <- new.env()
  local_mocked_bindings(
    Heatmap = function(matrix, ..., row_labels = NULL) {
      captured$row_labels <- row_labels
      captured$gene_ids <- rownames(matrix)
      structure(list(), class = "Heatmap")
    },
    draw = function(x, ...) invisible(NULL),
    .package = "ComplexHeatmap"
  )

  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_match(result$caption, "top 1 DE genes")
  # Col vecchio criterio (|logFC| desc) avrebbe vinto NOISY_B (logFC=5.0)
  # nonostante l'FDR piu alto; col nuovo criterio (FDR asc) vince MARKER_A.
  expect_equal(captured$gene_ids, "ENSG_A")
  expect_equal(captured$row_labels, "MARKER_A")
})
