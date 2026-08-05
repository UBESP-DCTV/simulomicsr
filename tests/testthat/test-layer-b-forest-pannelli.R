test_that(".forest_gene_rappresentativo prende l'effetto piu' grande fra i k pieni", {
  tg <- data.frame(
    gene_id = c("G1", "G2", "G3"),
    logFC_pool = c(1.0, -4.0, 3.0),
    k_effective = c(10L, 4L, 10L),   # G2 ha l'effetto piu' grande ma k basso
    stringsAsFactors = FALSE
  )
  expect_equal(simulomicsr:::.forest_gene_rappresentativo(tg, k_cluster = 10L), "G3")
})

test_that(".forest_gene_rappresentativo restituisce NA se nessun gene ha k pieno", {
  tg <- data.frame(gene_id = "G1", logFC_pool = 2, k_effective = 3L,
                   stringsAsFactors = FALSE)
  expect_true(is.na(simulomicsr:::.forest_gene_rappresentativo(tg, k_cluster = 10L)))
})

test_that(".build_forest REM a due pannelli: pooled sopra, un gene studio-per-studio sotto", {
  skip_if_not_installed("png")
  set.seed(42)
  cp <- make_fake_cluster_pooled(n_genes = 50, n_sig = 15, cluster_id = "cl_rem_pan")
  cp$method <- "rem"
  cp$k_effective <- 5L  # copertura piena su tutti i geni: il gene rappresentativo esiste
  cp$n_baseline_studies_augmented <- NA_integer_

  studies <- paste0("GSE", 1:5)
  ps <- expand.grid(study_id = studies, gene_id = cp$gene_id,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      cluster_id = "cl_rem_pan",
      gene_symbol = cp$gene_symbol[match(gene_id, cp$gene_id)],
      logFC = rnorm(dplyr::n(), 0, 1),
      SE = abs(rnorm(dplyr::n(), 0.3, 0.1)),
      p_value = runif(dplyr::n(), 0, 1),
      t_stat = logFC / SE, n_treated = 3L, n_control = 3L,
      direction_applied = "none"
    )

  out_dir <- tempfile("forest_pan_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  cfg$top_n_forest <- 8L
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "rem", out_dir = out_dir, config = cfg
  )

  expect_true(file.exists(result$png_path))
  # didascalia dichiara i due pannelli e non ripiega in silenzio
  expect_match(result$caption, "Top panel")
  expect_match(result$caption, "Bottom panel")
  expect_false(grepl("omitted", result$caption))
  png_info <- png::readPNG(result$png_path, native = FALSE)
  expect_gte(dim(png_info)[2], 2400L)  # 8 pollici * 300 dpi
})

test_that(".build_forest REM: pannello inferiore omesso se nessun gene ha copertura piena, dichiarato", {
  skip_if_not_installed("png")
  set.seed(1)
  cp <- make_fake_cluster_pooled(n_genes = 30, n_sig = 12, cluster_id = "cl_rem_nogene")
  cp$method <- "rem_group"
  # Tutti i geni significativi coprono solo 4 studi su un cluster che ne ha 10:
  # nessuno raggiunge la copertura piena richiesta da .forest_gene_rappresentativo().
  cp$k_effective <- 4L

  # Forza k_cluster (il massimo di k_effective sulle righe, vedi
  # .cluster_k_effective()) a 10 aggiungendo una riga fittizia NON significativa
  # (FDR=1, non entra in top_genes): cosi' k_cluster=10 mentre nessun gene
  # significativo raggiunge k=10.
  riga_alta <- cp[1L, , drop = FALSE]
  riga_alta$gene_id <- "ENSG99999999999"
  riga_alta$k_effective <- 10L
  riga_alta$FDR_BH_within_cluster <- 1  # non significativa: non entra in top_genes
  cp <- dplyr::bind_rows(cp, riga_alta)

  ps <- make_fake_per_study_de(cluster_id = "cl_rem_nogene", n_genes = 30, n_studies = 4)

  out_dir <- tempfile("forest_nogene_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "rem_group", out_dir = out_dir, config = cfg
  )

  expect_true(file.exists(result$png_path))
  expect_match(result$caption, "Top panel")
  expect_match(result$caption, "omitted")
})

test_that(".build_forest usa l'etichetta passata nel titolo, non il cluster_id grezzo", {
  # Revisione: il titolo chiamava .lb_titolo() con cp$cluster_id[1L], che sui
  # dati reali e' un ID tipo "cgroup_L5_2e16719f" -- vanifica lo scopo della
  # funzione (dire a colpo d'occhio di quale gruppo si tratta).
  set.seed(7)
  cp <- make_fake_cluster_pooled(n_genes = 20, n_sig = 10, cluster_id = "cgroup_L5_2e16719f")
  cp$method <- "rem_group"
  cp$k_effective <- 4L  # copertura piena: il ramo con pannello inferiore
  ps <- make_fake_per_study_de(cluster_id = "cgroup_L5_2e16719f", n_genes = 20, n_studies = 4)

  out_dir <- tempfile("forest_lab_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "rem_group", out_dir = out_dir, config = layer_b_default_config(),
    etichetta = "TGF-beta1"
  )

  expect_match(result$titolo, "TGF-beta1", fixed = TRUE)
  expect_false(grepl("cgroup_L5_", result$titolo, fixed = TRUE))
  expect_false(grepl("falls back to the raw cluster_id", result$caption, fixed = TRUE))
})

test_that(".build_forest senza etichetta ripiega sul cluster_id e lo dichiara in didascalia", {
  set.seed(8)
  cp <- make_fake_cluster_pooled(n_genes = 20, n_sig = 10, cluster_id = "cgroup_L5_deadbeef")
  cp$method <- "rem_group"
  cp$k_effective <- 4L
  ps <- make_fake_per_study_de(cluster_id = "cgroup_L5_deadbeef", n_genes = 20, n_studies = 4)

  out_dir <- tempfile("forest_nolab_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "rem_group", out_dir = out_dir, config = layer_b_default_config()
    # etichetta non passata: default NULL, il ripiego deve essere dichiarato
  )

  expect_match(result$titolo, "cgroup_L5_deadbeef", fixed = TRUE)
  expect_match(result$caption, "falls back to the raw cluster_id", fixed = TRUE)
})

test_that(".build_forest collassa i bracci multipli intra-studio prima del pannello per-studio", {
  # Trovato sui dati veri v15 (IFN-gamma, cgroup_L5_87c40ebb): per_study_de.parquet
  # su disco resta PRE-collasso (l'orchestrator collassa i bracci solo in memoria
  # prima di .pool_rem_cluster, R/stage4-orchestrator.R), quindi uno studio con
  # piu' bracci trattati per lo stesso gene produce piu' righe con lo STESSO
  # study_id. Senza collasso .build_forest crashava:
  # "Error in `levels<-`(...) : factor level [19] is duplicated".
  set.seed(9)
  cp <- make_fake_cluster_pooled(n_genes = 10, n_sig = 5, cluster_id = "cl_multiarm")
  cp$method <- "rem_group"
  cp$k_effective <- 3L  # 3 STUDI distinti, non 4 righe

  ps <- make_fake_per_study_de(cluster_id = "cl_multiarm", n_genes = 10, n_studies = 3)
  # GSE1 contribuisce un SECONDO braccio per il gene rappresentativo (quello con
  # l'effetto assoluto massimo fra i geni a copertura piena): stesso study_id,
  # riga in piu'.
  gene_rap_atteso <- cp$gene_id[which.max(abs(cp$logFC_pool))]
  riga_extra <- ps[ps$study_id == "GSE1" & ps$gene_id == gene_rap_atteso, , drop = FALSE]
  riga_extra$logFC <- riga_extra$logFC + 0.5
  ps <- dplyr::bind_rows(ps, riga_extra)
  expect_gt(sum(ps$study_id == "GSE1" & ps$gene_id == gene_rap_atteso), 1L)  # precondizione

  out_dir <- tempfile("forest_multiarm_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_forest(
    per_study_de_subset = ps, cluster_pooled_subset = cp,
    method = "rem_group", out_dir = out_dir, config = layer_b_default_config()
  )

  expect_true(file.exists(result$png_path))
  expect_false(grepl("omitted", result$caption))  # copertura piena raggiunta post-collasso
  expect_match(result$caption, "k=3", fixed = TRUE)  # 3 STUDI, non 4 bracci
})
