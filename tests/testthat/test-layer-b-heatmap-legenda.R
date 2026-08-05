# test-layer-b-heatmap-legenda.R --- via la legenda dei 47 codici GSE
#
# Su TGF-beta1 un terzo della heatmap e' occupato da una legenda con 47 codici
# GSE illeggibili, e la fascia "Study" e' una banda di 47 colori indistinguibili
# (spec 2026-08-05 §4.3). La biologia (raggruppamento geni, normalizzazione,
# ComBat, separazione trattato/controllo) resta intatta: qui si tocca solo
# l'annotazione delle colonne (Study opzionale, dietro config) e il titolo
# (stesso pattern gia' in .build_forest()/.build_volcano(), Task 3-4).

test_that("la heatmap non annota gli studi quando heatmap_mostra_studi = FALSE", {
  cfg <- layer_b_default_config()
  expect_false(cfg$heatmap_mostra_studi)
  ann <- simulomicsr:::.heatmap_annotazione_colonne(
    data.frame(study_id = paste0("GSE", 1:47),
               treatment = rep(c("treated", "control"), length.out = 47),
               stringsAsFactors = FALSE),
    mostra_studi = FALSE)
  expect_false("Study" %in% names(ann))
  expect_true("Treatment" %in% names(ann))
})

test_that(".heatmap_annotazione_colonne include Study quando richiesto esplicitamente", {
  ann <- simulomicsr:::.heatmap_annotazione_colonne(
    data.frame(study_id = paste0("GSE", 1:5),
               treatment = rep(c("treated", "control"), length.out = 5),
               stringsAsFactors = FALSE),
    mostra_studi = TRUE)
  expect_true("Study" %in% names(ann))
  expect_true("Treatment" %in% names(ann))
  # Un colore per studio distinto, non uno per campione.
  expect_length(ann$Study$colors, 5L)
})

test_that(".heatmap_annotazione_colonne colora control/treated in modo stabile", {
  ann <- simulomicsr:::.heatmap_annotazione_colonne(
    data.frame(study_id = rep("GSE1", 4),
               treatment = rep(c("control", "treated"), 2),
               stringsAsFactors = FALSE),
    mostra_studi = FALSE)
  expect_identical(ann$Treatment$colors[["control"]], "#BBBBBB")
  expect_identical(ann$Treatment$colors[["treated"]], "#333333")
})

test_that(".build_heatmap non passa l'annotazione Study a ComplexHeatmap con la config di default", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(3)
  n_genes <- 40
  n_samples <- 12

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 15, cluster_id = "cl_ann")
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:3), each = 4),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_ann_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  captured <- new.env()
  local_mocked_bindings(
    HeatmapAnnotation = function(...) {
      captured$ann_names <- names(list(...))
      structure(list(), class = "HeatmapAnnotation")
    },
    Heatmap = function(matrix, ...) structure(list(), class = "Heatmap"),
    draw = function(x, ...) invisible(NULL),
    .package = "ComplexHeatmap"
  )

  cfg <- layer_b_default_config()
  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_false("Study" %in% captured$ann_names)
  expect_true("Treatment" %in% captured$ann_names)
  # NB: niente expect_true(file.exists(...)) qui -- draw() e' mockato a
  # no-op apposta per isolare l'argomento passato a HeatmapAnnotation(), e
  # un device png() senza nulla disegnato non scrive file su questo sistema
  # (verificato: con un draw() reale il file c'e' sempre, vedi gli altri
  # test in test-layer-b-heatmap.R che non mockano ne' Heatmap ne' draw).
  expect_false(is.na(result$png_path))
})

test_that(".build_heatmap passa anche Study quando heatmap_mostra_studi = TRUE", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(4)
  n_genes <- 40
  n_samples <- 12

  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 15, cluster_id = "cl_ann_studi")
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:3), each = 4),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_ann_studi_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  captured <- new.env()
  local_mocked_bindings(
    HeatmapAnnotation = function(...) {
      captured$ann_names <- names(list(...))
      structure(list(), class = "HeatmapAnnotation")
    },
    Heatmap = function(matrix, ...) structure(list(), class = "Heatmap"),
    draw = function(x, ...) invisible(NULL),
    .package = "ComplexHeatmap"
  )

  cfg <- layer_b_default_config()
  cfg$heatmap_mostra_studi <- TRUE
  simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = cfg
  )

  expect_true("Study" %in% captured$ann_names)
  expect_true("Treatment" %in% captured$ann_names)
})

test_that(".build_heatmap usa l'etichetta passata nel titolo, non il cluster_id grezzo", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(9)
  n_genes <- 30
  n_samples <- 12
  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 12, cluster_id = "cgroup_L5_2e16719f")
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:2), each = 6),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_lab_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = layer_b_default_config(),
    etichetta = "TGF-beta1"
  )

  expect_match(result$titolo, "TGF-beta1", fixed = TRUE)
  expect_false(grepl("cgroup_L5_", result$titolo, fixed = TRUE))
  expect_false(grepl("falls back to the raw cluster_id", result$caption, fixed = TRUE))
})

test_that(".build_heatmap senza etichetta ripiega sul cluster_id e lo dichiara in didascalia", {
  skip_if_not_installed("ComplexHeatmap")
  skip_if_not_installed("DESeq2")
  skip_if_not_installed("sva")

  set.seed(10)
  n_genes <- 30
  n_samples <- 12
  cp <- make_fake_cluster_pooled(n_genes = n_genes, n_sig = 12, cluster_id = "cgroup_L5_deadbeef")
  counts <- matrix(rpois(n_genes * n_samples, lambda = 100), nrow = n_genes,
                   dimnames = list(cp$gene_id, paste0("GSM", seq_len(n_samples))))
  metadata <- tibble::tibble(
    sample_id = paste0("GSM", seq_len(n_samples)),
    study_id = rep(paste0("GSE", 1:2), each = 6),
    treatment = rep(c("control", "treated"), times = n_samples / 2L)
  )

  out_dir <- tempfile("hm_nolab_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  result <- simulomicsr:::.build_heatmap(
    counts = counts, metadata = metadata,
    cluster_pooled_subset = cp,
    out_dir = out_dir, config = layer_b_default_config()
    # etichetta non passata: default NULL, il ripiego deve essere dichiarato
  )

  expect_match(result$titolo, "cgroup_L5_deadbeef", fixed = TRUE)
  expect_match(result$caption, "falls back to the raw cluster_id", fixed = TRUE)
})
