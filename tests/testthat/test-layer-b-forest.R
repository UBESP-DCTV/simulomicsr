test_that(".build_forest produces PNG for mega_aug cluster", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 15, cluster_id = "cl_aug")
  cp$method <- "mega_aug"
  cp$n_baseline_studies_augmented <- 8L
  ps <- make_fake_per_study_de(cluster_id = "cl_aug", n_genes = 50, n_studies = 2)

  out_dir <- tempfile("forest_aug_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps,
    cluster_pooled_subset = cp,
    method = "mega_aug",
    out_dir = out_dir,
    config = cfg
  )
  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "Forest plot")
  expect_match(result$caption, "k=2 pair")
})

test_that(".build_forest REM branch produces PNG with k panels respecting top_n_forest", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("png")
  set.seed(42)
  # Fixture REM: 5 studi, 10 geni sig
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 15, cluster_id = "cl_rem")
  cp$method <- "rem"
  cp$k_effective <- 5L
  cp$tau2 <- abs(rnorm(nrow(cp), 0.02, 0.05))
  cp$n_baseline_studies_augmented <- NA_integer_

  studies <- paste0("GSE", 1:5)
  ps <- expand.grid(study_id = studies, gene_id = cp$gene_id,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      cluster_id = "cl_rem",
      # FASE E1: propaga gene_symbol via lookup gene_id -> gene_symbol
      gene_symbol = cp$gene_symbol[match(gene_id, cp$gene_id)],
      logFC = rnorm(dplyr::n(), 0, 1),
      SE = abs(rnorm(dplyr::n(), 0.3, 0.1)),
      p_value = runif(dplyr::n(), 0, 1),
      t_stat = logFC / SE, n_treated = 3L, n_control = 3L,
      direction_applied = "none"
    )

  out_dir <- tempfile("forest_rem_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  cfg$top_n_forest <- 10L
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "rem", out_dir = out_dir, config = cfg
  )

  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "Forest plots for top \\d+ significantly DE genes")
  expect_match(result$caption, "k=5")
  # Verify PNG dimensions: 8 inch wide x at least 3 inch tall @ 300 DPI
  png_info <- png::readPNG(result$png_path, native = FALSE)
  expect_gte(dim(png_info)[2], 2400L)  # >= 8 inch * 300 dpi
})

test_that(".build_forest skip mega-strict with explanatory caption", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 10, cluster_id = "cl_mega")
  cp$method <- "mega"
  ps <- tibble::tibble()  # mega strict has no per_study_de

  out_dir <- tempfile("forest_mega_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps,
    cluster_pooled_subset = cp,
    method = "mega",
    out_dir = out_dir,
    config = cfg
  )
  expect_true(is.na(result$png_path) || is.null(result$png_path))
  expect_match(result$caption, "Forest plot N/A for mega-strict")
  # minor (revisione finale 2026-08-06): il return anticipato rispetta il
  # proprio @return -- titolo NA_character_, genes_mostrati character(0),
  # non NULL.
  expect_true(is.character(result$titolo) && is.na(result$titolo))
  expect_identical(result$genes_mostrati, character(0))
})

test_that(".build_forest: nessun gene significativo restituisce titolo/genes_mostrati dichiarati (minor)", {
  cp <- make_fake_cluster_pooled(n_genes = 20, n_sig = 0, cluster_id = "cl_nosig")
  cp$method <- "rem"
  cp$k_effective <- 5L
  ps <- make_fake_per_study_de(cluster_id = "cl_nosig", n_genes = 20, n_studies = 5)

  out_dir <- tempfile("forest_nosig_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps,
    cluster_pooled_subset = cp,
    method = "rem",
    out_dir = out_dir,
    config = layer_b_default_config()
  )
  expect_match(result$caption, "no genes significant at FDR")
  expect_true(is.character(result$titolo) && is.na(result$titolo))
  expect_identical(result$genes_mostrati, character(0))
})

test_that(".build_forest: nessuna riga per_study_de restituisce titolo/genes_mostrati dichiarati (minor)", {
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 10, cluster_id = "cl_norows")
  cp$method <- "rem"
  ps <- tibble::tibble()  # 0 righe: stesso schema del ramo mega, ma method != mega

  out_dir <- tempfile("forest_norows_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps,
    cluster_pooled_subset = cp,
    method = "rem",
    out_dir = out_dir,
    config = layer_b_default_config()
  )
  expect_match(result$caption, "no per-study estimates found")
  expect_true(is.character(result$titolo) && is.na(result$titolo))
  expect_identical(result$genes_mostrati, character(0))
})

test_that(".build_forest gestisce gene_symbol duplicati (paraloghi) senza crash", {
  # ARCHS4 v2.5: piu' Ensembl gene_id mappano sullo STESSO gene_symbol HGNC
  # (paraloghi PAR/KIR/HLA + loci multipli, es. KRT23 su 2 ENSG). Il forest usa
  # la label (= gene_symbol) come levels di un factor, che richiede unicita' ->
  # senza make.unique va in "factor level [N] is duplicated". Repro dal cluster
  # v7 Alcoholic hepatitis (KRT23 su ENSG00000263309 + ENSG00000108244).
  cp <- make_fake_cluster_pooled(n_genes = 20, n_sig = 12, cluster_id = "cl_dup")
  cp$method <- "mega_aug"
  cp$n_baseline_studies_augmented <- 8L
  # Due gene_id distinti sullo stesso symbol, |logFC| tra i piu' alti -> top_n_forest.
  cp$logFC_pool[1:2] <- c(9.0, 8.5)
  cp$FDR_BH_within_cluster[1:2] <- c(0.001, 0.001)
  cp$gene_symbol[1:2] <- "KRT23"
  ps <- make_fake_per_study_de(cluster_id = "cl_dup", n_genes = 20, n_studies = 2)

  out_dir <- tempfile("forest_dup_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "mega_aug", out_dir = out_dir, config = cfg
  )
  expect_true(file.exists(result$png_path))
})

test_that(".build_forest seleziona i top-N per FDR (significativita'), non per |logFC|", {
  # Bug reale trovato sull'artefatto TGF-beta1 (2026-08-06): la selezione
  # ordinava per abs(logFC_pool) decrescente, quindi i dieci geni mostrati
  # erano quelli a effetto piu' grande -- che sui dati veri avevano copertura
  # PARZIALE (43-52 studi su 59, sopra la soglia del filtro di copertura ma
  # sotto la copertura PIENA richiesta da .forest_gene_rappresentativo()).
  # Risultato: il pannello inferiore spariva SEMPRE (nessun gene "pieno" fra
  # i dieci) e nessun bersaglio canonico (bassi in |logFC| ma altamente
  # significativi) compariva mai, mentre la tabella (che ordina per FDR)
  # mostrava quei bersagli regolarmente. Riprodotto qui: 10 geni ad effetto
  # enorme ma k_effective parziale (12, sotto il cluster k=20) contro 5 geni
  # a effetto piccolo ma FDR minuscolo e k_effective PIENO (20).
  skip_if_not_installed("metafor")
  k_cluster <- 20L
  n_effetto <- 10L   # i vecchi "vincitori" per |logFC|, copertura parziale
  n_canonici <- 5L   # i bersagli veri: FDR minuscolo, copertura piena

  cp <- tibble::tibble(
    cluster_id  = "cl_selezione",
    gene_id     = c(paste0("ENSG_EFFETTO_", seq_len(n_effetto)),
                    paste0("ENSG_CANONICO_", seq_len(n_canonici))),
    gene_symbol = c(paste0("EFFETTO", seq_len(n_effetto)),
                    paste0("CANONICO", seq_len(n_canonici))),
    method      = "rem_group",
    logFC_pool  = c(rep(8.0, n_effetto), rep(1.5, n_canonici)),
    SE_pool     = 0.2,
    p_value_pool = c(rep(1e-6, n_effetto), rep(1e-40, n_canonici)),
    tau2 = 0.1, Q = 1, Q_pval = 1,
    k_effective = c(rep(12L, n_effetto), rep(k_cluster, n_canonici)),
    n_baseline_studies_augmented = NA_integer_,
    # FDR coerente con la significativita' dichiarata: gli "effetto" hanno
    # p piu' alta (meno significativi) dei "canonici", che sono quasi a
    # macchina epsilon -- esattamente il pattern visto sui dati veri.
    FDR_BH_within_cluster = c(rep(1e-4, n_effetto), rep(1e-38, n_canonici)),
    direction_applied = "none"
  )
  ps <- make_fake_per_study_de(cluster_id = "cl_selezione",
                               n_genes = nrow(cp), n_studies = k_cluster)
  # make_fake_per_study_de numera i geni per posizione (ENSG%011d): ricostruisco
  # gene_id/gene_symbol coerenti col cp sopra, stesso ordine.
  ps$gene_id <- rep(cp$gene_id, each = k_cluster)
  ps$gene_symbol <- rep(cp$gene_symbol, each = k_cluster)

  out_dir <- tempfile("forest_selezione_"); dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  cfg$top_n_forest <- 10L
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "rem_group", out_dir = out_dir, config = cfg
  )

  # (a) i 5 bersagli canonici (FDR minuscolo) entrano nei 10 mostrati, non
  # scartati a favore dei 10 ad alto |logFC|.
  expect_true(all(paste0("ENSG_CANONICO_", seq_len(n_canonici)) %in% result$genes_mostrati))
  # (b) il pannello inferiore c'e' davvero: un gene a copertura piena e'
  # stato trovato, la didascalia non dice piu' "omitted".
  expect_false(grepl("omitted", result$caption))
  expect_match(result$caption, "CANONICO", fixed = TRUE)
})
