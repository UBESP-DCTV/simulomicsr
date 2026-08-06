test_that(".build_go_enrichment skip-graceful on small universe", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 5)  # < 200 threshold
  out_dir <- tempfile("go_small_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_go_enrichment(cp, out_dir = out_dir, config = cfg)

  expect_named(result, c("png_path", "svg_path", "csv_path", "titolo", "caption"),
               ignore.order = TRUE)
  expect_match(result$caption, "below threshold")
})

# --- rilievo I4 (revisione finale, 2026-08-06): il titolo era statico ("GO
# Biological Process -- top 10 enriched terms", senza gruppo ne' k) e il
# tema era theme_bw() invece di .lb_theme(); la spec tiene il GO fra le
# quattro figure e dice "ogni figura porta nel titolo di quale gruppo si
# tratta e su quanti studi", come forest/volcano/heatmap gia' fanno.

test_that(".build_go_enrichment usa .lb_titolo()/etichetta come le altre tre figure", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 5)  # skip-graceful: universo piccolo
  cp$k_effective <- 12L
  out_dir <- tempfile("go_titolo_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_go_enrichment(
    cp, out_dir = out_dir, config = layer_b_default_config(),
    etichetta = "TGF-beta1"
  )
  expect_match(result$titolo, "TGF-beta1", fixed = TRUE)
  expect_match(result$titolo, "12 studi", fixed = TRUE)
  expect_false(grepl(unique(cp$cluster_id), result$titolo, fixed = TRUE))
})

test_that(".build_go_enrichment senza etichetta ripiega sul cluster_id e lo dichiara in didascalia", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 5, cluster_id = "cgroup_L5_deadbeef")
  out_dir <- tempfile("go_noetichetta_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_go_enrichment(cp, out_dir = out_dir, config = layer_b_default_config())
  expect_match(result$titolo, "cgroup_L5_deadbeef", fixed = TRUE)
  expect_match(result$caption, "falls back to the raw cluster_id", fixed = TRUE)
})

test_that(".build_go_enrichment runs on real-sized universe", {
  skip_if_not_installed("clusterProfiler")
  skip_if_not_installed("org.Hs.eg.db")

  # Real HGNC symbols (subset cromatina/cell cycle che probabilmente enriched)
  real_genes <- c("TP53", "MYC", "CCND1", "CDK2", "RB1", "E2F1", "CDKN1A",
                  "MDM2", "ATM", "ATR", "BRCA1", "BRCA2", "RAD51", "CHEK1",
                  "CHEK2", "PCNA", "MCM2", "MCM3", "MCM4", "MCM5", "MCM6",
                  "MCM7", "ORC1", "CDC6", "CDT1", "GMNN", "FOXM1", "PLK1",
                  "AURKA", "AURKB", "BUB1", "BUB3", "MAD2L1", "CDC20",
                  "CCNB1", "CCNB2", "CDK1", "CDC25A", "CDC25B", "CDC25C")
  filler <- paste0("FILLER_GENE_", 1:300)
  all_genes <- c(real_genes, filler)
  n_total <- length(all_genes)

  set.seed(42)
  # FASE E1 ADR-0019 D6: gene_id (Ensembl) come chiave ORA; gene_symbol
  # (HGNC) come annotation. Per il test usiamo finti ENSG: la ORA sara'
  # skip-graceful ("0 genes mappabili") perche' i mock ENSG non sono in
  # org.Hs.eg.db. Test verifica solo che la funzione gira senza crash e
  # produce il file CSV atteso (path execution); l'enrichment vero richiede
  # Ensembl reali (smoke su dati paper-grade in fixture mini).
  cp <- tibble::tibble(
    cluster_id = "cl_go",
    gene_id = paste0("ENSG", sprintf("%011d", seq_len(n_total))),
    gene_symbol = all_genes,
    method = "mega",
    logFC_pool = c(rnorm(length(real_genes), 3, 1), rnorm(length(filler), 0, 0.3)),
    SE_pool = 0.1,
    p_value_pool = c(runif(length(real_genes), 1e-10, 0.001), runif(length(filler), 0.05, 1)),
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = NA_real_,
    direction_applied = "none"
  )
  cp$FDR_BH_within_cluster <- p.adjust(cp$p_value_pool, method = "BH")

  out_dir <- tempfile("go_real_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_go_enrichment(cp, out_dir = out_dir, config = cfg)
  expect_true(file.exists(result$csv_path))
  # Accept either success path or skip-graceful (no real Ensembl mapping
  # con finti ENSG; verifica execution path, non risultato biologico).
  expect_true(grepl("GO Biological Process|N/A|no significant", result$caption))
})
