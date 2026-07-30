test_that(".build_top_gene_table writes CSV + LaTeX", {
  cp <- make_fake_cluster_pooled(n_genes = 100, n_sig = 40)
  out_dir <- tempfile("tgt_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_top_gene_table(cp, out_dir = out_dir, config = cfg)

  expect_named(result, c("csv_path", "tex_path", "caption", "n_rows"),
               ignore.order = TRUE)
  expect_true(file.exists(result$csv_path))
  expect_true(file.exists(result$tex_path))

  # CSV content check
  csv_df <- readr::read_csv(result$csv_path, show_col_types = FALSE)
  expect_true(all(c("gene_id", "gene_symbol", "logFC_pool", "SE_pool",
                     "FDR_BH_within_cluster") %in% names(csv_df)))
  expect_lte(nrow(csv_df), cfg$top_n_table)

  # LaTeX content check
  tex <- readLines(result$tex_path)
  expect_true(any(grepl("booktabs|toprule|tabular", tex)))
})

test_that(".build_top_gene_table LaTeX caption uses single backslash log_2 FC (no double-escape)", {
  cp <- make_fake_cluster_pooled(n_genes = 100, n_sig = 40)
  out_dir <- tempfile("tgt_tex_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_top_gene_table(cp, out_dir = out_dir, config = cfg)

  # Legge il .tex come stringa raw (no escape interpretation)
  tex_raw <- paste(readLines(result$tex_path), collapse = "\n")

  # Deve contenere "\log_2 FC" (1 backslash literal nel file)
  expect_true(
    grepl("\\\\log_2 FC", tex_raw),
    info = "Expected '\\log_2 FC' (1 backslash literal) nel .tex"
  )
  # NON deve contenere "\\\\log" (4 backslash literal nel file = bug pre-fix)
  expect_false(
    grepl("\\\\\\\\log", tex_raw),
    info = "Expected NO '\\\\log' (4 backslash literal) nel .tex post-fix"
  )
})

test_that(".build_top_gene_table ranks by significance (FDR asc), not raw |logFC|", {
  # Gene MARKER_A: FDR molto basso ma logFC modesto (marcatore canonico
  # robusto, alto k_effective). Gene NOISY_B: ancora sig ma FDR piu alto e
  # logFC enorme (rumore ad alta varianza, basso k_effective).
  cp <- tibble::tibble(
    cluster_id = "cl_rank",
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
  out_dir <- tempfile("tgt_rank_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  # Il filtro di copertura (2026-07-31) toglierebbe NOISY_B, che ha k=2 su 20:
  # e' esattamente il caso per cui e' stato scritto. Qui lo si disattiva per
  # tenere il test su UNA cosa sola — l'ordinamento — mentre il filtro ha i suoi
  # test in test-layer-b-gene-coverage-filter.R.
  cfg <- layer_b_default_config()
  cfg$top_genes_min_k_frac <- 0
  result <- simulomicsr:::.build_top_gene_table(cp, out_dir = out_dir, config = cfg)

  csv_df <- readr::read_csv(result$csv_path, show_col_types = FALSE)
  expect_equal(csv_df$gene_symbol, c("MARKER_A", "NOISY_B"))
})

test_that(".build_top_gene_table col filtro ATTIVO toglie il gene a bassa copertura", {
  # La controprova del test qui sopra: con la config di default lo stesso
  # NOISY_B (k=2 su 20, logFC 5,0) non deve comparire, e la caption deve dirlo.
  cp <- tibble::tibble(
    cluster_id = "cl_rank",
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
  out_dir <- tempfile("tgt_cov_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_top_gene_table(
    cp, out_dir = out_dir, config = layer_b_default_config())

  csv_df <- readr::read_csv(result$csv_path, show_col_types = FALSE)
  expect_equal(csv_df$gene_symbol, "MARKER_A")
  expect_match(result$caption, "fewer than 10 of 20 studies")
})

test_that(".build_top_gene_table deduplicates rows sharing gene_symbol (multi-Ensembl artifact), keeping the most significant", {
  cp <- tibble::tibble(
    cluster_id = "cl_dedup",
    gene_id = c("ENSG_1", "ENSG_2", "ENSG_3"),
    gene_symbol = c("RDH13", "RDH13", "RDH13"),
    method = "mega",
    logFC_pool = c(1.0, 3.0, 0.5),
    SE_pool = c(0.2, 0.5, 0.1),
    p_value_pool = c(0.001, 1e-8, 0.02),
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = c(0.001, 1e-8, 0.02),
    direction_applied = "none"
  )
  out_dir <- tempfile("tgt_dedup_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_top_gene_table(cp, out_dir = out_dir, config = cfg)

  csv_df <- readr::read_csv(result$csv_path, show_col_types = FALSE)
  expect_equal(nrow(csv_df), 1L)
  expect_equal(csv_df$gene_id[1], "ENSG_2")
  expect_equal(result$n_rows, 1L)
})

test_that(".build_top_gene_table adds gene_label (symbol, fallback gene_id) and drops direction_applied/p_value_pool", {
  cp <- tibble::tibble(
    cluster_id = "cl_label",
    gene_id = c("ENSG_X", "ENSG_Y"),
    gene_symbol = c("SYMX", NA_character_),
    method = "mega",
    logFC_pool = c(1.2, 1.5),
    SE_pool = c(0.2, 0.2),
    p_value_pool = c(0.001, 0.002),
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = c(0.001, 0.002),
    direction_applied = "none"
  )
  out_dir <- tempfile("tgt_label_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_top_gene_table(cp, out_dir = out_dir, config = cfg)

  csv_df <- readr::read_csv(result$csv_path, show_col_types = FALSE)
  expect_true("gene_label" %in% names(csv_df))
  expect_false("direction_applied" %in% names(csv_df))
  expect_false("p_value_pool" %in% names(csv_df))

  row_x <- csv_df[csv_df$gene_id == "ENSG_X", ]
  row_y <- csv_df[csv_df$gene_id == "ENSG_Y", ]
  expect_equal(row_x$gene_label, "SYMX")
  expect_equal(row_y$gene_label, "ENSG_Y")
})

test_that(".build_top_gene_table handles 0 sig genes", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 0)
  out_dir <- tempfile("tgt_zero_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_top_gene_table(cp, out_dir = out_dir, config = cfg)
  expect_equal(result$n_rows, 0L)
  expect_match(result$caption, "No genes significant")
})
