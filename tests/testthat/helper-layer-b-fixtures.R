# Helpers per fixture sintetiche usate dai test layer-b-*
# testthat carica automaticamente i file helper-*.R prima di ogni test.

make_fake_cluster_pooled <- function(n_genes = 100, n_sig = 20, cluster_id = "cl_test") {
  set.seed(42)
  logFC <- c(rnorm(n_sig, mean = 0, sd = 3), rnorm(n_genes - n_sig, mean = 0, sd = 0.3))
  p_value <- c(runif(n_sig, 1e-10, 0.01), runif(n_genes - n_sig, 0.05, 1))
  tibble::tibble(
    cluster_id = cluster_id,
    gene_id = paste0("ENSG", sprintf("%011d", seq_len(n_genes))),
    gene_symbol = paste0("SYM_", seq_len(n_genes)),
    method = "mega",
    logFC_pool = logFC,
    SE_pool = abs(logFC) / 5 + 0.1,
    p_value_pool = p_value,
    tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 5L,
    n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = p.adjust(p_value, method = "BH"),
    direction_applied = "none"
  )
}

make_fake_per_study_de <- function(cluster_id = "cl_aug", n_genes = 50, n_studies = 2) {
  set.seed(42)
  studies <- paste0("GSE", seq_len(n_studies))
  expand.grid(study_id = studies, gene_id = paste0("ENSG", sprintf("%011d", seq_len(n_genes))),
              KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      cluster_id = cluster_id,
      gene_symbol = paste0("SYM_",
                            sub("ENSG0*", "", gene_id)),
      logFC = rnorm(dplyr::n(), 0, 1),
      SE = abs(rnorm(dplyr::n(), 0.3, 0.1)),
      p_value = runif(dplyr::n(), 0, 1),
      t_stat = logFC / SE,
      n_treated = 3L, n_control = 3L,
      direction_applied = "none"
    ) |>
    dplyr::select(cluster_id, study_id, gene_id, gene_symbol, logFC, SE, p_value,
                  t_stat, n_treated, n_control, direction_applied)
}

# Fixture end-to-end per build_layer_b_results(): finto stage4 dir + counts cache.
# Usato dai test test-layer-b-build.R, test-layer-b-fixture-mini.R, test-layer-b-replication.R.
#
# `cluster_ids`: coppia (mega, mega_aug) -- default invariato per non rompere
# i chiamanti esistenti. Parametrizzato per il test del collegamento
# scheda/narrativa (test-layer-b-collegamento-scheda.R), che ha bisogno di un
# cluster_id nella forma vera `cgroup_L5_...` per verificare che la scheda
# nuova non lo stampi nel corpo.
# `con_deliverable_annotato`: se TRUE, scrive anche `deliverable-annotato.rds`
# con una riga per il cluster mega (schema minimo di
# `annotate_stage4_deliverable()`) -- il file che fa scattare la scheda/
# narrativa nuove invece del ripiego su quelle vecchie.
make_fake_layer_a_dir <- function(cluster_ids = c("cl_mega_1", "cl_aug_1"),
                                  con_deliverable_annotato = FALSE) {
  stopifnot(length(cluster_ids) == 2L)
  id_mega <- cluster_ids[1L]
  id_aug  <- cluster_ids[2L]

  d <- tempfile("stage4_full_")
  dir.create(d)

  # Cluster pooled: 2 cluster (1 mega + 1 mega_aug), 100 geni ciascuno
  set.seed(42)
  build_cp_chunk <- function(cluster_id, method, n_genes = 100, n_sig = 25) {
    logFC <- c(rnorm(n_sig, 0, 3), rnorm(n_genes - n_sig, 0, 0.3))
    pv <- c(runif(n_sig, 1e-10, 0.001), runif(n_genes - n_sig, 0.05, 1))
    # Pre-calcola scalari fuori da tibble() per evitare data-mask shadowing
    # del nome `method` (tidy-eval lo risolverebbe come colonna appena costruita).
    k_eff_scalar <- if (method == "mega") 5L else 2L
    n_aug_scalar <- if (method == "mega_aug") 8L else NA_integer_
    tibble::tibble(
      cluster_id = cluster_id,
      gene_id = paste0("ENSG", sprintf("%011d", seq_len(n_genes))),
      gene_symbol = paste0("HGNC", seq_len(n_genes)),
      method = method,
      logFC_pool = logFC,
      SE_pool = abs(logFC) / 5 + 0.1,
      p_value_pool = pv,
      tau2 = NA_real_, I2 = NA_real_, Q = NA_real_, Q_pval = NA_real_,
      k_effective = k_eff_scalar,
      n_baseline_studies_augmented = n_aug_scalar,
      FDR_BH_within_cluster = p.adjust(pv, "BH"),
      direction_applied = "none"
    )
  }
  cp <- dplyr::bind_rows(
    build_cp_chunk(id_mega, "mega"),
    build_cp_chunk(id_aug, "mega_aug")
  )
  arrow::write_parquet(cp, file.path(d, "cluster_pooled.parquet"))

  # Per-study DE solo per mega_aug
  ps <- tibble::tibble(
    cluster_id = rep(id_aug, 200L),
    study_id   = rep(c("GSE_PAIR_A", "GSE_PAIR_B"), each = 100L),
    gene_id    = rep(paste0("ENSG", sprintf("%011d", 1:100)), 2L),
    gene_symbol = rep(paste0("HGNC", 1:100), 2L),
    logFC      = rnorm(200, 0, 1),
    SE         = abs(rnorm(200, 0.3, 0.1)),
    p_value    = runif(200, 0, 1),
    t_stat     = rnorm(200, 0, 2),
    n_treated  = 3L, n_control = 3L,
    direction_applied = "none"
  )
  arrow::write_parquet(ps, file.path(d, "per_study_de.parquet"))

  qc <- list(
    qc_drops_sample = tibble::tibble(),
    qc_drops_study = tibble::tibble(),
    qc_drops_cluster = tibble::tibble(),
    pooling_warnings = tibble::tibble(),
    mega_aug_diagnostics = tibble::tibble(
      cluster_id = id_aug, bidir_collapsed_to_mono = FALSE,
      comparison_kind_overall = "direct_overlap"
    )
  )
  saveRDS(qc, file.path(d, "qc_report.rds"))
  saveRDS(tibble::tibble(), file.path(d, "non_processable.rds"))

  meta <- list(
    run_id = "fakea4ce",
    config = list(de_engine = list(mega = "dream"))
  )
  jsonlite::write_json(meta, file.path(d, "run_metadata.json"), auto_unbox = TRUE)

  if (con_deliverable_annotato) {
    n_sig_mega <- sum(cp$cluster_id == id_mega & cp$FDR_BH_within_cluster < 0.05,
                      na.rm = TRUE)
    deliverable <- data.frame(
      cluster_id             = id_mega,
      contrast_entity        = "HGNC:11766",
      contrast_entity_label  = "TGF-beta1 (fixture)",
      k_effective            = 5L,
      k_kish                 = 4.2,
      I2_med                 = 42.0,
      n_sig                  = n_sig_mega,
      quota_top1             = 0.31,
      studio_dominante       = "GSE_PAIR_A",
      materiale_misto        = FALSE,
      coherence_verdict      = "coherent",
      stringsAsFactors       = FALSE
    )
    saveRDS(deliverable, file.path(d, "deliverable-annotato.rds"))
  }

  d
}

#' Genera una `fetch_counts_fn` fake per i test layer-b
#'
#' Pre-calcola counts matrix dummy per ogni studio nel fixture e ritorna
#' una funzione `(gse, sample_ids) -> matrix` compatibile con il contratto
#' di `fetch_counts_fn` (DI). Sostituisce il vecchio manifest-based cache.
make_fake_counts_cache <- function(cluster_ids, samples_per_study = 6L, n_genes = 100L) {
  # Studi di test (identici cross-cluster nel fixture mini)
  studies <- c("GSE_PAIR_A", "GSE_PAIR_B")
  # Pre-build di una matrice per studio (deterministica via set.seed)
  set.seed(123L)
  studies_map <- list()
  for (s in studies) {
    counts <- matrix(
      rpois(n_genes * samples_per_study, lambda = 100),
      nrow = n_genes,
      dimnames = list(
        paste0("ENSG", sprintf("%011d", seq_len(n_genes))),
        paste0(s, "_GSM", seq_len(samples_per_study))
      )
    )
    # FASE E1: attacca gene_symbol (HGNC) come attr named per consistenza
    # con il return contract di .fetch_counts_from_h5.
    attr(counts, "gene_symbol") <- setNames(
      paste0("HGNC", seq_len(n_genes)),
      paste0("ENSG", sprintf("%011d", seq_len(n_genes)))
    )
    studies_map[[s]] <- counts
  }

  fetch_counts_fn <- function(gse, sample_ids) {
    m <- studies_map[[gse]]
    if (is.null(m)) {
      stop(sprintf("No fake counts for gse=%s", gse))
    }
    missing <- setdiff(sample_ids, colnames(m))
    if (length(missing) > 0L) {
      stop(sprintf("Missing samples for gse=%s: %s",
                   gse, paste(missing, collapse = ",")))
    }
    m[, sample_ids, drop = FALSE]
  }

  list(fetch_counts_fn = fetch_counts_fn, studies_map = studies_map)
}
