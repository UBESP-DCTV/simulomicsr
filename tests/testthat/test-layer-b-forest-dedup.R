# Il forest deve deduplicare i simboli come fanno gia' tabella, heatmap e volcano.
#
# TROVATO SULL'ARTEFATTO (2026-08-08, non sul sorgente): nel bundle del DHT
# (`cgroup_L5_930c8dcf`, figura 1 del main paper) il forest mostrava `RBP5` e
# `RBP5.1`, cioe' lo STESSO gene biologico due volte, e in cambio perdeva COPS3;
# la tabella dei top geni dello stesso bundle mostrava RBP5 una volta sola.
# Figura e tabella raccontavano due storie diverse sullo stesso cluster.
# Ampiezza misurata sugli SVG dei 9 bundle: 2 su 9 (DHT `RBP5.1`,
# `cgroup_L5_b71a25a2` `ZNF445.1`).
#
# Causa: `.build_forest()` replicava l'ORDINAMENTO di `.rank_and_dedup_genes()`
# ma non la DEDUPLICA, e il `make.unique()` a valle -- che sta li' per garantire
# livelli di factor univoci -- mascherava il difetto invece di segnalarlo.

test_that(".build_forest non mostra due volte lo stesso simbolo (paraloghi ARCHS4)", {
  skip_if_not_installed("metafor")
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 20, cluster_id = "cl_dedup")
  cp$method <- "rem_group"
  cp$k_effective <- 10L
  # ARCHS4 v2.5 mappa piu' Ensembl gene_id sullo stesso simbolo HGNC: qui i due
  # geni piu' significativi condividono il simbolo, quindi senza deduplica
  # occupano DUE dei dieci posti.
  cp$gene_symbol[1:2] <- "PARALOGO"
  cp$FDR_BH_within_cluster[1:2] <- c(1e-30, 1e-29)
  cp$logFC_pool[1:2] <- c(4, -4)
  ps <- make_fake_per_study_de(cluster_id = "cl_dedup", n_genes = 40, n_studies = 10)

  out_dir <- tempfile("forest_dedup_"); dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_forest(ps, cp, "rem_group", out_dir,
                                    layer_b_default_config())

  # 1. dei due paraloghi ne entra UNO SOLO
  expect_equal(sum(res$genes_mostrati %in% cp$gene_id[1:2]), 1L)
  # 2. il posto liberato va a un gene VERO, non resta vuoto: dieci geni mostrati
  expect_equal(length(res$genes_mostrati), 10L)
  # 3. nessun simbolo compare due volte fra quelli mostrati
  simboli <- cp$gene_symbol[match(res$genes_mostrati, cp$gene_id)]
  expect_equal(anyDuplicated(simboli), 0L)
  # 4. entra il piu' significativo dei due, non il secondo
  expect_true(cp$gene_id[1] %in% res$genes_mostrati)
})

test_that(".build_forest tiene distinti i geni SENZA simbolo (non sono doppioni)", {
  skip_if_not_installed("metafor")
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 20, cluster_id = "cl_nosym")
  cp$method <- "rem_group"
  cp$k_effective <- 10L
  # due geni senza annotazione HGNC: sono entita' distinte, la deduplica per
  # simbolo NON deve collassarli (stessa regola di .rank_and_dedup_genes()).
  cp$gene_symbol[1:2] <- NA_character_
  cp$FDR_BH_within_cluster[1:2] <- c(1e-30, 1e-29)
  ps <- make_fake_per_study_de(cluster_id = "cl_nosym", n_genes = 40, n_studies = 10)

  out_dir <- tempfile("forest_nosym_"); dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_forest(ps, cp, "rem_group", out_dir,
                                    layer_b_default_config())

  expect_equal(sum(res$genes_mostrati %in% cp$gene_id[1:2]), 2L)
})
