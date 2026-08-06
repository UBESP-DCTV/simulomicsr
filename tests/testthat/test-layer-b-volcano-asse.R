# test-layer-b-volcano-asse.R --- TDD: l'asse verticale del volcano si
# comprime SOLO quando un punto domina davvero, e lo dichiara sempre in
# didascalia. Le etichette pescano solo fra i geni ben misurati, ma TUTTI i
# geni restano disegnati.
#
# PERCHE' ESISTE. Su TGF-beta1 un solo gene a -log10(p) ~= 310 schiaccia il
# 99% degli altri geni in una striscia illeggibile sul fondo del grafico, e le
# etichette pescavano geni misurati in due studi su 59 invece dei bersagli
# biologici (misurato il 2026-08-05).

test_that(".volcano_soglia_asse scatta solo quando un punto domina davvero", {
  y_normale <- c(1, 2, 3, 4, 5)
  expect_true(is.infinite(simulomicsr:::.volcano_soglia_asse(y_normale)))

  y_dominato <- c(rep(5, 99), 310)
  s <- simulomicsr:::.volcano_soglia_asse(y_dominato)
  expect_true(is.finite(s))
  expect_lt(s, 310)
  expect_gt(s, 5)
})

test_that(".volcano_soglia_asse non scatta con pochi punti (evidenza insufficiente)", {
  y <- c(1, 2, 300)
  expect_true(is.infinite(simulomicsr:::.volcano_soglia_asse(y)))
})

test_that(".build_volcano comprime l'asse e lo dichiara quando un gene domina", {
  cp <- make_fake_cluster_pooled(n_genes = 60, n_sig = 20, cluster_id = "cl_dom")
  cp$k_effective <- 20L
  # un solo gene a p ~= 1e-310, come il caso reale TGF-beta1 misurato il 2026-08-05
  cp$p_value_pool[1] <- 1e-310
  cp$FDR_BH_within_cluster[1] <- 1e-308

  out_dir <- tempfile("volcano_dom_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = layer_b_default_config())

  expect_match(res$caption, "compressed", ignore.case = TRUE)
  expect_match(res$caption, "-log10\\(p\\) = ")
  expect_true(file.exists(res$png_path))
})

test_that(".build_volcano non comprime l'asse senza un punto dominante", {
  cp <- make_fake_cluster_pooled(n_genes = 60, n_sig = 20, cluster_id = "cl_nodom")
  cp$k_effective <- 20L

  out_dir <- tempfile("volcano_nodom_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = layer_b_default_config())

  expect_false(grepl("compressed", res$caption, ignore.case = TRUE))
})

test_that(".build_volcano usa l'etichetta passata nel titolo, non il cluster_id grezzo", {
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 15, cluster_id = "cgroup_L5_2e16719f")
  cp$k_effective <- 20L

  out_dir <- tempfile("volcano_lab_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_volcano(
    cp, out_dir = out_dir, config = layer_b_default_config(),
    etichetta = "TGF-beta1"
  )

  expect_match(res$titolo, "TGF-beta1", fixed = TRUE)
  expect_false(grepl("cgroup_L5_", res$titolo, fixed = TRUE))
  expect_false(grepl("falls back to the raw cluster_id", res$caption, fixed = TRUE))
})

test_that(".build_volcano usa l'etichetta leggibile anche nella prima frase della didascalia, non il cluster_id (rilievo I7)", {
  # Prima del fix la didascalia apriva SEMPRE con "Volcano plot for cluster
  # cgroup_L5_...", anche quando forest/heatmap della STESSA figura usavano
  # gia' l'etichetta leggibile nel titolo -- due figure adiacenti dello
  # stesso case study raccontavano l'identita' del gruppo in due modi diversi.
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 15, cluster_id = "cgroup_L5_2e16719f")
  cp$k_effective <- 20L

  out_dir <- tempfile("volcano_caption_lab_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_volcano(
    cp, out_dir = out_dir, config = layer_b_default_config(),
    etichetta = "TGF-beta1"
  )

  expect_match(res$caption, "TGF-beta1", fixed = TRUE)
  expect_false(grepl("cgroup_L5_", res$caption, fixed = TRUE))
})

test_that(".build_volcano senza etichetta ripiega sul cluster_id e lo dichiara in didascalia", {
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 15, cluster_id = "cgroup_L5_deadbeef")
  cp$k_effective <- 20L

  out_dir <- tempfile("volcano_nolab_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = layer_b_default_config())

  expect_match(res$titolo, "cgroup_L5_deadbeef", fixed = TRUE)
  expect_match(res$caption, "falls back to the raw cluster_id", fixed = TRUE)
})

test_that(".volcano_labels non etichetta i geni misurati in pochi studi", {
  # stessa trappola gia' corretta nel forest (Task 2): due geni con effetto
  # enorme ma misurati in 2 studi su 10 non devono vincere l'etichetta.
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 20, cluster_id = "cl_cov_v")
  cp$k_effective <- 10L
  cp$k_effective[1:2] <- 2L
  cp$logFC_pool[1:2] <- c(9, -9)
  cp$FDR_BH_within_cluster[1:2] <- 1e-30

  lab <- simulomicsr:::.volcano_labels(cp, layer_b_default_config())
  etichette <- lab[!is.na(lab)]

  expect_false(any(cp$gene_symbol[1:2] %in% etichette))
})

test_that("il filtro di copertura del volcano tocca solo le etichette, mai i punti", {
  # garanzia esplicita del task: nessuna riga va tolta da cp prima del plot,
  # solo la scelta del NOME etichetta cambia. build riesce e la nota in
  # didascalia parla di "labeling", non di righe scartate dal grafico.
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 20, cluster_id = "cl_cov_pts")
  cp$k_effective <- 10L
  cp$k_effective[1:2] <- 2L
  cp$logFC_pool[1:2] <- c(9, -9)
  cp$FDR_BH_within_cluster[1:2] <- 1e-30

  out_dir <- tempfile("volcano_pts_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_volcano(cp, out_dir = out_dir, config = layer_b_default_config())

  expect_true(file.exists(res$png_path))
  expect_match(res$caption, "excluded from labeling")
  expect_match(res$caption, "not from the plot", fixed = TRUE)
})

test_that(".build_volcano usa config$volcano_quota_asse, non un default cablato", {
  # PERCHE' ESISTE (Task 8 review): .build_volcano() chiamava
  # .volcano_soglia_asse(cp$neg_log10_p) SENZA passare config$volcano_quota_asse
  # -- cambiare quella chiave in config non aveva alcun effetto (parametro
  # morto). Distribuzione costruita apposta al confine: p99/max = 0.604, cosi'
  # con la quota di default (0.6) NON comprime, ma con una quota piu' alta
  # (0.7, passata via config) SI -- stessi dati, cambia solo la config.
  y <- c(rep(5, 96), rep(6, 3), 10)
  p99_su_max <- stats::quantile(y, 0.99, names = FALSE) / max(y)
  stopifnot(p99_su_max > 0.6, p99_su_max < 0.7)  # verifica il confine scelto

  cp <- make_fake_cluster_pooled(n_genes = length(y), n_sig = 20, cluster_id = "cl_quota")
  cp$k_effective <- 20L
  cp$p_value_pool <- 10 ^ (-y)

  out_dir_default <- tempfile("volcano_quota_default_")
  dir.create(out_dir_default)
  on.exit(unlink(out_dir_default, recursive = TRUE))
  res_default <- simulomicsr:::.build_volcano(
    cp, out_dir = out_dir_default, config = layer_b_default_config())
  expect_false(grepl("compressed", res_default$caption, ignore.case = TRUE))

  cfg_stretta <- layer_b_default_config()
  cfg_stretta$volcano_quota_asse <- 0.7
  out_dir_stretta <- tempfile("volcano_quota_stretta_")
  dir.create(out_dir_stretta)
  on.exit(unlink(out_dir_stretta, recursive = TRUE), add = TRUE)
  res_stretta <- simulomicsr:::.build_volcano(
    cp, out_dir = out_dir_stretta, config = cfg_stretta)
  expect_match(res_stretta$caption, "compressed", ignore.case = TRUE)
})
