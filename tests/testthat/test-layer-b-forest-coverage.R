test_that(".build_forest scarta i geni misurati in pochi studi", {
  skip_if_not_installed("metafor")
  cp <- make_fake_cluster_pooled(n_genes = 40, n_sig = 20, cluster_id = "cl_cov")
  cp$method <- "rem_group"
  cp$k_effective <- 10L
  # due geni con effetto enorme ma misurati in 2 studi soli: sono la trappola
  cp$k_effective[1:2] <- 2L
  cp$logFC_pool[1:2] <- c(9, -9)
  cp$FDR_BH_within_cluster[1:2] <- 1e-30
  ps <- make_fake_per_study_de(cluster_id = "cl_cov", n_genes = 40, n_studies = 10)

  out_dir <- tempfile("forest_cov_"); dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_forest(ps, cp, "rem_group", out_dir,
                                     layer_b_default_config())
  expect_false(any(res$genes_mostrati %in% cp$gene_id[1:2]))
  # la nota del filtro e' dichiarata: .coverage_filter_note() non usa la
  # parola "meta" (verificato, R/layer-b-utils.R), il testo reale e'
  # "excluded from ranking" -- e' quello che si controlla qui.
  expect_match(res$caption, "excluded from ranking")
})
