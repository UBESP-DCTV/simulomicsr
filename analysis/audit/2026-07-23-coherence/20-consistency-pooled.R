# P5 coherence Task 4: metrica di consistenza cross-studio (ADR-0021 / F6 Fase A)
# generalizzata a TUTTI i cluster poolati dello Stadio 4 v10 (714), non solo ai 15
# della vetrina Layer B. Generalizza analysis/p5-stage4-showcase-consistency-v10.R
# SENZA reinventare la metrica: stessi helper (R/stage4-consistency.R), stesso I/O
# pattern (open_dataset + filter per cluster_id, PI per-gene via metafor).
#
# ramo rem/rem_group (196 cluster): logica IDENTICA allo showcase.
#   - consistency = 1 - median(I2 sui geni sig)                [.rem_consistency_from_i2]
#   - PI 95% per-gene sui geni FDR<0.05, da logFC/SE per-studio [.rem_prediction_interval]
#   - pi_frac_excl0 = frazione di geni sig il cui PI 95% esclude lo 0
#   - k_studies = n. studi distinti nel join per_study_de sui geni sig (come showcase,
#     NON k_effective del pooled: e' la stessa quantita' nella grande maggioranza dei
#     casi ma e' derivata dai dati usati per il PI, non assunta).
#
# ramo mega/mega_aug (518 cluster): cluster_pooled.parquet v10 NON contiene una metrica
#   di consistenza per questi metodi (VPC per mega, sign-concordance per mega_aug sono
#   calcolati SOLO da script F6 dedicati su strutture dati diverse, fuori scope Task 4).
#   Verificato sui dati reali: I2/tau2 sono NA su tutte le 9.041.484 righe mega+mega_aug
#   di cluster_pooled.parquet v10 (0 eccezioni). Si scrive quindi NA esplicito +
#   consistency_note. NESSUNA metrica surrogata forzata (istruzione esplicita brief
#   Task 4: "NON forzare una metrica finta"). Se in futuro la colonna I2 fosse
#   popolata anche per questi metodi, lo script la userebbe (ramo difensivo sotto),
#   ma questo caso non si presenta nei dati v10 attuali.
#
# Parametrizzazione: ONLY_IDS (env var, CSV di cluster_id) per validazione mirata.
# Default "" = tutti i 714 poolati.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE); library(arrow); library(dplyr); library(cli)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}

S4_DIR  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032"
OUT_DIR <- "analysis/audit/2026-07-23-coherence"
OUT_CSV <- file.path(OUT_DIR, "consistency-pooled.csv")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
stopifnot(dir.exists(S4_DIR))

only_ids_raw <- trimws(Sys.getenv("ONLY_IDS", unset = ""))
ONLY_IDS <- if (nzchar(only_ids_raw)) trimws(strsplit(only_ids_raw, ",")[[1L]]) else NULL

REM_METHODS <- c("rem", "rem_group")
CHECKPOINT_EVERY <- 50L  # scrittura CSV parziale ogni N cluster (resilienza sul full run)

cp_ds   <- open_dataset(file.path(S4_DIR, "cluster_pooled.parquet"))
psde_ds <- open_dataset(file.path(S4_DIR, "per_study_de.parquet"))

cli_h1("Consistenza ADR-0021 su cluster poolati Stadio 4 v10")

meta <- cp_ds |> select(cluster_id, method) |> distinct() |> collect()
cli_alert_info(sprintf("cluster poolati totali in cluster_pooled.parquet: %d", nrow(meta)))

if (!is.null(ONLY_IDS)) {
  missing_ids <- setdiff(ONLY_IDS, meta$cluster_id)
  if (length(missing_ids) > 0L) {
    cli_alert_warning(sprintf("ONLY_IDS: %d id non trovati in cluster_pooled.parquet: %s",
      length(missing_ids), paste(missing_ids, collapse = ", ")))
  }
  meta <- meta[meta$cluster_id %in% ONLY_IDS, , drop = FALSE]
}
method_tbl <- table(meta$method)
cli_alert_info(sprintf("cluster da processare: %d (%s)", nrow(meta),
  paste(sprintf("%s=%d", names(method_tbl), as.integer(method_tbl)), collapse = ", ")))

.process_rem_cluster <- function(cid, method, sub) {
  # --- ramo REM: logica IDENTICA a analysis/p5-stage4-showcase-consistency-v10.R ---
  summ_i2 <- .summarize_consistency_over_sig(sub$I2, sub$FDR_BH_within_cluster)
  sig <- sub[!is.na(sub$FDR_BH_within_cluster) & sub$FDR_BH_within_cluster < 0.05, , drop = FALSE]
  pd <- psde_ds |> filter(cluster_id == cid, gene_id %in% sig$gene_id) |>
    select(gene_id, study_id, logFC, SE) |> collect()
  k <- length(unique(pd$study_id))
  if (nrow(pd) > 0L) {
    pis <- lapply(split(seq_len(nrow(pd)), pd$gene_id), function(idx)
      .rem_prediction_interval(pd$logFC[idx], pd$SE[idx]))
    excl0 <- vapply(pis, function(x) isTRUE(x$excl0), logical(1))
    frac_excl0 <- mean(excl0, na.rm = TRUE)
  } else {
    frac_excl0 <- NA_real_
  }
  tibble::tibble(
    cluster_id = cid, method = method, k_studies = k,
    n_sig_used = summ_i2$n_used,
    consistency_score = .rem_consistency_from_i2(summ_i2$median),
    median_I2 = summ_i2$median,
    pi_frac_excl0 = frac_excl0,
    consistency_note = NA_character_)
}

.process_mega_cluster <- function(cid, method, sub) {
  # --- ramo mega/mega_aug: nessuna colonna I2/consistenza calcolata nel pooled per
  # questi metodi (verificato: 100% NA su 9,04M righe). NA esplicito + nota, salvo il
  # caso difensivo (non osservato nei dati v10) in cui I2 sia effettivamente popolato.
  k_eff_vals <- sub$k_effective[!is.na(sub$k_effective)]
  k <- if (length(k_eff_vals) > 0L) as.integer(round(stats::median(k_eff_vals))) else NA_integer_
  n_sig <- sum(!is.na(sub$FDR_BH_within_cluster) & sub$FDR_BH_within_cluster < 0.05)
  if (all(is.na(sub$I2))) {
    cons <- NA_real_; medi2 <- NA_real_
    note <- sprintf(
      "%s: I2/consistenza non presente in cluster_pooled.parquet v10 (VPC per mega e sign-concordance per mega_aug non sono calcolati in questo pooling, sono fuori scope Task 4) -> NA per costruzione.",
      method)
  } else {
    # ramo difensivo, non esercitato sui dati v10 osservati (I2 sempre NA per questi metodi).
    summ_i2 <- .summarize_consistency_over_sig(sub$I2, sub$FDR_BH_within_cluster)
    cons <- .rem_consistency_from_i2(summ_i2$median)
    medi2 <- summ_i2$median
    note <- sprintf(
      "%s: colonna I2 presente e usata (ramo difensivo, non atteso su v10) -> verificare semantica prima di uso paper-grade.",
      method)
  }
  tibble::tibble(
    cluster_id = cid, method = method, k_studies = k,
    n_sig_used = n_sig, consistency_score = cons, median_I2 = medi2,
    pi_frac_excl0 = NA_real_, consistency_note = note)
}

n_total <- nrow(meta)
rows <- vector("list", n_total)
t_start <- Sys.time()
t_last_log <- t_start

for (i in seq_len(n_total)) {
  cid    <- meta$cluster_id[[i]]
  method <- meta$method[[i]]
  t0 <- Sys.time()

  sub <- cp_ds |> filter(cluster_id == cid) |>
    select(gene_id, gene_symbol, logFC_pool, FDR_BH_within_cluster, k_effective, I2, tau2) |>
    collect()

  rows[[i]] <- if (method %in% REM_METHODS) {
    .process_rem_cluster(cid, method, sub)
  } else {
    .process_mega_cluster(cid, method, sub)
  }

  elapsed_hourly <- as.numeric(difftime(Sys.time(), t_last_log, units = "secs"))
  if (i %% 25L == 0L || i == n_total || elapsed_hourly > 3600) {
    el_min <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
    eta_min <- el_min / i * (n_total - i)
    r <- rows[[i]]
    cli_alert_info(sprintf(
      "[%d/%d] %s (%s) k=%s n_sig=%s cons=%s I2med=%s pi_excl0=%s (%.1fs) | %.1f min trascorsi, ETA %.1f min",
      i, n_total, cid, method, r$k_studies, r$n_sig_used,
      formatC(r$consistency_score, digits = 3, format = "f"),
      formatC(r$median_I2, digits = 1, format = "f"),
      formatC(r$pi_frac_excl0, digits = 3, format = "f"),
      as.numeric(difftime(Sys.time(), t0, units = "secs")), el_min, eta_min))
    t_last_log <- Sys.time()
  }

  if (i %% CHECKPOINT_EVERY == 0L || i == n_total) {
    readr::write_csv(dplyr::bind_rows(rows[seq_len(i)]), OUT_CSV)
  }
}

out <- dplyr::bind_rows(rows)
readr::write_csv(out, OUT_CSV)
cli_alert_success(sprintf("scritto %s (%d righe, %d rem/rem_group + %d mega/mega_aug)",
  OUT_CSV, nrow(out), sum(out$method %in% REM_METHODS), sum(!out$method %in% REM_METHODS)))

## ---------------------------------------------------------------------------
## VALIDAZIONE (solo se ONLY_IDS punta ai 15 cluster noti showcase+drop): confronto
## riga-per-riga con analysis/audit/2026-07-23-showcase-consistency-summary.csv.
## ---------------------------------------------------------------------------
REF_CSV <- "analysis/audit/2026-07-23-showcase-consistency-summary.csv"
if (!is.null(ONLY_IDS) && file.exists(REF_CSV)) {
  cli_h2("Validazione vs showcase (2026-07-23-showcase-consistency-summary.csv)")
  ref <- readr::read_csv(REF_CSV, show_col_types = FALSE)
  ref2 <- dplyr::transmute(ref, cluster_id = cluster_id, role = role,
    consistency_score_ref = consistency_score, median_I2_ref = median_I2,
    pi_frac_excl0_ref = pi_frac_excl0, k_studies_ref = k_studies)
  cmp <- dplyr::inner_join(out, ref2, by = "cluster_id")
  cmp$diff_consistency <- cmp$consistency_score - cmp$consistency_score_ref
  cmp$diff_median_I2   <- cmp$median_I2 - cmp$median_I2_ref
  cmp$diff_pi_excl0    <- cmp$pi_frac_excl0 - cmp$pi_frac_excl0_ref
  cmp$diff_k           <- cmp$k_studies - cmp$k_studies_ref

  print(as.data.frame(cmp[, c("cluster_id", "role", "k_studies", "k_studies_ref",
    "n_sig_used", "consistency_score", "consistency_score_ref", "diff_consistency",
    "median_I2", "median_I2_ref", "diff_median_I2",
    "pi_frac_excl0", "pi_frac_excl0_ref", "diff_pi_excl0")]))

  n_matched <- nrow(cmp)
  n_expected <- length(ONLY_IDS)
  tol_tight <- 1e-6
  tol_pi    <- 1e-3
  ok_cons <- all(abs(cmp$diff_consistency) < tol_tight, na.rm = TRUE)
  ok_i2   <- all(abs(cmp$diff_median_I2) < tol_tight, na.rm = TRUE)
  ok_pi   <- all(abs(cmp$diff_pi_excl0) < tol_pi, na.rm = TRUE)
  ok_k    <- all(cmp$diff_k == 0L, na.rm = TRUE)

  cli_alert_info(sprintf("cluster attesi: %d, matchati per cluster_id: %d", n_expected, n_matched))
  cli_alert_info(sprintf("max |diff consistency_score| = %.3e (soglia %.0e)",
    max(abs(cmp$diff_consistency), na.rm = TRUE), tol_tight))
  cli_alert_info(sprintf("max |diff median_I2|         = %.3e (soglia %.0e)",
    max(abs(cmp$diff_median_I2), na.rm = TRUE), tol_tight))
  cli_alert_info(sprintf("max |diff pi_frac_excl0|     = %.3e (soglia %.0e)",
    max(abs(cmp$diff_pi_excl0), na.rm = TRUE), tol_pi))
  cli_alert_info(sprintf("k_studies identico su tutte le righe: %s", ok_k))

  if (n_matched == n_expected && ok_cons && ok_i2 && ok_pi && ok_k) {
    cli_alert_success("VALIDAZIONE PASS: i 15 cluster noti si riproducono entro tolleranza.")
  } else {
    cli_alert_danger("VALIDAZIONE FALLITA: divergenza dalla logica showcase. NON procedere al full run.")
  }
}

cli_alert_success("fine 20-consistency-pooled.R")
