# analysis/p5-stage4-showcase-consistency-v10.R
# Metrica di consistenza ADR-0021 / F6 (ramo REM) applicata ai cluster rem_group v10
# della vetrina Layer B (9 showcase + 6 drop). RIUSA gli helper esistenti di
# R/stage4-consistency.R e la STESSA logica del ramo rem di
# analysis/p4-fase-f6-consistency.R (righe 157-186). Nessuna metrica nuova.
#
# Per ogni cluster (rem_group = REM per-studio):
#   - gene set = geni FDR-significativi del pooled (FDR_BH_within_cluster < 0.05)
#   - consistency = 1 - median(I2 sui sig)               [.rem_consistency_from_i2]
#   - prediction interval 95% per-gene (metafor REML+HKSJ)   [.rem_prediction_interval]
#     -> excl0 = il PI 95% esclude lo 0 = "replica in direzione in un nuovo studio"
#   - pi_frac_excl0 = frazione di geni sig con PI che esclude 0 (misura di replicabilita')
#
# Output (design F6): cluster_pi_per_gene (per-gene) + summary per-cluster.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE); library(arrow); library(dplyr); library(cli)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}

S4_DIR <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032"
OUT_PI  <- file.path(S4_DIR, "cluster_pi_per_gene_showcase.parquet")
OUT_SUM <- "analysis/audit/2026-07-23-showcase-consistency-summary.csv"
stopifnot(dir.exists(S4_DIR))

showcase <- c(  # 9 KEEP
  "group_L4_c8600f54","group_L4_7b3e137b","group_L4_7059e6f2","group_L4_1f404c0b",
  "group_L4_eda28231","group_L4_b128b80d","group_L4_b6a3eabd","group_L4_274f387d",
  "group_L4_c51b10c1")
drops <- c(      # 6 DROP (per l'indagine root-cause)
  "group_L4_4d2d5aa0","group_L4_c2a27b6c","group_L4_59db95a9","group_L4_b4975123",
  "group_L4_02a1fb3f","group_L4_f4b9f686")
all_ids <- c(showcase, drops)
role <- c(setNames(rep("showcase", length(showcase)), showcase),
          setNames(rep("drop", length(drops)), drops))

cp_ds   <- open_dataset(file.path(S4_DIR, "cluster_pooled.parquet"))
psde_ds <- open_dataset(file.path(S4_DIR, "per_study_de.parquet"))

cli_h1("Showcase consistency (ADR-0021 ramo REM) su rem_group v10")

pi_pg <- list(); rows <- list()
for (cid in all_ids) {
  t0 <- Sys.time()
  sub <- cp_ds |> filter(cluster_id == cid) |>
    select(gene_id, gene_symbol, logFC_pool, FDR_BH_within_cluster, k_effective, I2, tau2) |>
    collect()
  # consistency = 1 - median(I2 sui geni sig); I2 e' percentuale 0-100
  summ_i2 <- .summarize_consistency_over_sig(sub$I2, sub$FDR_BH_within_cluster)
  sig <- sub[!is.na(sub$FDR_BH_within_cluster) & sub$FDR_BH_within_cluster < 0.05, , drop = FALSE]
  # PI per-gene sui soli geni sig, dai logFC/SE per-studio
  pd <- psde_ds |> filter(cluster_id == cid, gene_id %in% sig$gene_id) |>
    select(gene_id, study_id, logFC, SE) |> collect()
  k <- length(unique(pd$study_id))
  if (nrow(pd) > 0L) {
    pis <- lapply(split(seq_len(nrow(pd)), pd$gene_id), function(idx)
      .rem_prediction_interval(pd$logFC[idx], pd$SE[idx]))
    gids <- names(pis)
    m <- match(gids, sig$gene_id)
    pg <- tibble::tibble(
      cluster_id  = cid,
      role        = role[[cid]],
      gene_id     = gids,
      gene_symbol = sig$gene_symbol[m],
      logFC_pool  = sig$logFC_pool[m],
      FDR         = sig$FDR_BH_within_cluster[m],
      k_effective = sig$k_effective[m],
      I2          = sig$I2[m],
      pi_lower    = vapply(pis, `[[`, numeric(1), "pi_lower"),
      pi_upper    = vapply(pis, `[[`, numeric(1), "pi_upper"),
      pi_tau2     = vapply(pis, `[[`, numeric(1), "tau2"),
      excl0       = vapply(pis, function(x) isTRUE(x$excl0), logical(1)))
    pi_pg[[cid]] <- pg
    frac_excl0 <- mean(pg$excl0, na.rm = TRUE)
    tau2_med   <- stats::median(pg$pi_tau2, na.rm = TRUE)
    n_excl0    <- sum(pg$excl0, na.rm = TRUE)
  } else { frac_excl0 <- NA_real_; tau2_med <- NA_real_; n_excl0 <- 0L }

  rows[[cid]] <- tibble::tibble(
    cluster_id = cid, role = role[[cid]], k_studies = k,
    n_sig_used = summ_i2$n_used,
    consistency_score = .rem_consistency_from_i2(summ_i2$median),  # I2 percento -> [0,1]
    median_I2 = summ_i2$median, tau2_median = tau2_med,
    n_pi_excl0 = n_excl0, pi_frac_excl0 = frac_excl0)
  cli_alert_info(sprintf("[%s] %s k=%d n_sig=%d cons=%.3f I2med=%.1f pi_excl0=%.3f (%d geni) (%.0fs)",
    role[[cid]], cid, k, summ_i2$n_used, rows[[cid]]$consistency_score,
    summ_i2$median, frac_excl0, n_excl0,
    as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

arrow::write_parquet(dplyr::bind_rows(pi_pg), OUT_PI)
summ <- dplyr::bind_rows(rows) |> arrange(role, desc(pi_frac_excl0))
readr::write_csv(summ, OUT_SUM)

cli_h2("Summary per-cluster (ordinato per pi_frac_excl0)")
print(as.data.frame(summ))
cli_alert_success(sprintf("scritto %s (%d geni) + %s", OUT_PI,
  nrow(dplyr::bind_rows(pi_pg)), OUT_SUM))
