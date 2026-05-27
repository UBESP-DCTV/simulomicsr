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
