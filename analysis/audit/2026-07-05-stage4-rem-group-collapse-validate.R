#!/usr/bin/env Rscript
# =============================================================================
# 2026-07-05-stage4-rem-group-collapse-validate.R
# Validazione POST-COLLAPSE rem_group su dati REALI prima del fullrun (~11h).
#
# Obiettivo: confermare che .collapse_arms_by_study() riduce k_effective
# a livello di studio (non di braccio) → pseudo-replicazione eliminata.
#
# Verifica chiave: k_effective mediano nel pool POST-collapse <= n_studi_distinti
# del cluster. Se k_effective > n_studi → collapse non ha funzionato → RED ALERT.
#
# Usa 4 cluster bandiera con bracci multipli intra-studio (da smoke precedente):
#   - SARS-CoV-2  (n_entry=25, n_studi=12, bracci_extra=13)
#   - enzalutamide (n_entry=18, n_studi=12, bracci_extra=6)
#   - Prostatic Neoplasms (n_entry=8, n_studi=4, bracci_extra=4)
#   - fulvestrant  (n_entry=8, n_studi=5, bracci_extra=3)
# =============================================================================

suppressPackageStartupMessages(devtools::load_all("."))
suppressPackageStartupMessages(library(arrow))

S3_DIR  <- "analysis/p4-output/20260703T113045Z-stage3-v7-364547a7"
S2_PATH <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
H5_PATH <- "analysis/input/human_gene_v2.5.h5"
MD_OUT  <- "analysis/audit/2026-07-05-stage4-rem-group-collapse-validate.md"

# Cluster bandiera identificati dallo smoke precedente (bracci_extra > 0, ammessi)
BANDIERE <- list(
  list(cid = "group_L4_b6a3eabd", nome = "SARS-CoV-2",
       n_entry_atteso = 25L, n_studi_atteso = 12L, bracci_extra_atteso = 13L),
  list(cid = "group_L4_b128b80d", nome = "enzalutamide",
       n_entry_atteso = 18L, n_studi_atteso = 12L, bracci_extra_atteso = 6L),
  list(cid = "group_L4_fdd42642", nome = "Prostatic Neoplasms",
       n_entry_atteso = 8L,  n_studi_atteso = 4L,  bracci_extra_atteso = 4L),
  list(cid = "group_L4_b4975123", nome = "fulvestrant",
       n_entry_atteso = 8L,  n_studi_atteso = 5L,  bracci_extra_atteso = 3L)
)
TARGET_CIDS <- vapply(BANDIERE, `[[`, "cid", FUN.VALUE = character(1))

# Cap dispatch per cluster: prioritizza studi con bracci multipli ma limita il totale
# per mantenere il test leggero. Prostatic e fulvestrant (8 entry) usano tutto.
CAP_PER_CLUSTER <- 10L

cat("=== BLOCCO 1: CARICO INPUT ===\n\n")

clusters    <- readRDS(file.path(S3_DIR, "clusters.rds"))
cat("  -> clusters:", nrow(clusters), "righe\n")

assignments <- as.data.frame(read_parquet(file.path(S3_DIR, "assignments.parquet")))
cat("  -> assignments:", nrow(assignments), "righe\n")

cat("  -> stage2_master (lento ~30-60s)...\n")
t_s2 <- proc.time()
stage2_master <- .load_stage2_master(S2_PATH)
cat("  ->", length(stage2_master), "studi in",
    round((proc.time() - t_s2)[3], 1), "sec\n\n")

cfg <- stage4_default_config()

# -------------------------------------------------------------------------
# Identifica Layer A e rem_group
# -------------------------------------------------------------------------
cat("Identifico cluster Layer A...\n")
layer_a <- .identify_layer_a_clusters(clusters, cfg)
rg <- layer_a[layer_a$method == "rem_group", ]
cat("  -> rem_group totale:", nrow(rg), "\n\n")

# -------------------------------------------------------------------------
# Dispatch per i cluster bandiera
# -------------------------------------------------------------------------
cat("Costruisco dispatch rem_group (solo bandiere)...\n")
rg_band_full <- rg[rg$cluster_id %in% TARGET_CIDS, ]
t_disp <- proc.time()
disp_full <- .build_group_rem_dispatch_from_stage3(
  rg_band_full, assignments, stage2_master,
  n_min = cfg$rem_group$n_min
)
cat("  ->", length(disp_full), "cluster con dispatch in",
    round((proc.time() - t_disp)[3], 1), "sec\n\n")

cat("=== BLOCCO 2: VERIFICA DISPATCH BANDIERE ===\n\n")

# Verifica e sub-campiona il dispatch priorizzzando studi con bracci multipli
disp_capped <- list()
dispatch_stats <- list()

for (b in BANDIERE) {
  cid <- b$cid
  d <- disp_full[[cid]]
  if (is.null(d) || length(d) == 0L) {
    cat(sprintf("[WARN] %s (%s): dispatch NULL o vuoto\n", b$nome, cid))
    next
  }
  study_ids_all <- vapply(d, function(x) x$study_id, character(1))
  n_entry   <- length(d)
  n_studi   <- length(unique(study_ids_all))
  bracci_extra <- n_entry - n_studi

  # Identifica studi con bracci multipli
  freq_studio <- table(study_ids_all)
  multi_studi  <- names(freq_studio[freq_studio > 1L])
  single_studi <- names(freq_studio[freq_studio == 1L])

  # Sub-campiona: TUTTI i bracci dei multi-arm study (priorità alta) + alcune single-arm
  idx_multi  <- which(study_ids_all %in% multi_studi)
  idx_single <- which(study_ids_all %in% single_studi)

  # Bilancia: prendi tutti i multi-arm, completa con single-arm fino al cap
  n_multi_da_tenere  <- min(length(idx_multi), ceiling(CAP_PER_CLUSTER * 0.7))
  n_single_da_tenere <- min(length(idx_single), CAP_PER_CLUSTER - n_multi_da_tenere)
  idx_kept <- sort(c(head(idx_multi, n_multi_da_tenere),
                     head(idx_single, n_single_da_tenere)))

  d_capped <- d[idx_kept]
  study_ids_kept <- study_ids_all[idx_kept]
  n_entry_capped  <- length(d_capped)
  n_studi_capped  <- length(unique(study_ids_kept))
  multi_arm_in_cap <- sum(table(study_ids_kept) > 1L)

  cat(sprintf("  %s (%s):\n", b$nome, cid))
  cat(sprintf("    dispatch TOTALE: n_entry=%d, n_studi=%d, bracci_extra=%d\n",
              n_entry, n_studi, bracci_extra))
  cat(sprintf("    cap applicato:   n_entry=%d, n_studi=%d, studi_multi-arm=%d\n",
              n_entry_capped, n_studi_capped, multi_arm_in_cap))

  disp_capped[[cid]] <- d_capped
  dispatch_stats[[cid]] <- list(
    nome            = b$nome,
    cid             = cid,
    n_entry_totale  = n_entry,
    n_studi_totale  = n_studi,
    bracci_extra    = bracci_extra,
    n_entry_capped  = n_entry_capped,
    n_studi_capped  = n_studi_capped,
    multi_arm_studi = multi_arm_in_cap
  )
}
cat("\n")

# -------------------------------------------------------------------------
# Prepara eligible_clusters con dispatch capped
# -------------------------------------------------------------------------
cids_con_dispatch <- names(disp_capped)
rg_val <- rg_band_full[rg_band_full$cluster_id %in% cids_con_dispatch, ]
attr(rg_val, "study_dispatch") <- disp_capped

# -------------------------------------------------------------------------
# Per-study DE (limma-voom per ogni dispatch entry)
# -------------------------------------------------------------------------
cat("=== BLOCCO 3: PER-STUDY DE (protein_coding) ===\n\n")

fetch_fn <- function(gse, sample_ids) {
  .fetch_counts_cached(gse, sample_ids, h5_path = H5_PATH,
                       gene_biotype_filter = "protein_coding")
}

cat("Avvio .run_per_study_de_all (workers=1)...\n")
t_de <- proc.time()
psd <- tryCatch(
  .run_per_study_de_all(rg_val, fetch_fn = fetch_fn, workers = 1L),
  error = function(e) {
    cat("[ERRORE] .run_per_study_de_all:", conditionMessage(e), "\n")
    NULL
  }
)
t_de_elapsed <- round((proc.time() - t_de)[3] / 60, 1)
cat("  -> elapsed:", t_de_elapsed, "min\n")

if (is.null(psd) || nrow(psd) == 0L) {
  stop("[RED ALERT] per_study_de vuota — impossibile procedere con la validazione.")
}
cat("  -> righe per_study_de:", nrow(psd), "\n")
cat("  -> cluster con DE:", length(unique(psd$cluster_id)), "\n\n")

# -------------------------------------------------------------------------
# Misura k PRIMA e DOPO collapse + pool REM post-collapse
# -------------------------------------------------------------------------
cat("=== BLOCCO 4: CONFRONTO PRE vs POST COLLAPSE ===\n\n")

risultati <- list()

for (b in BANDIERE) {
  cid <- b$cid
  if (!cid %in% cids_con_dispatch) {
    cat(sprintf("[SKIP] %s: nessun dispatch\n", b$nome))
    next
  }
  dstat <- dispatch_stats[[cid]]
  subset_pre <- psd[psd$cluster_id == cid, ]

  if (nrow(subset_pre) == 0L) {
    cat(sprintf("[WARN] %s: per_study_de vuota per questo cluster\n", b$nome))
    next
  }

  # --- PRE-COLLAPSE ---
  # Quante righe per gene? Deve riflettere i bracci (non gli studi)
  n_righe_pre   <- nrow(subset_pre)
  n_studi_pre   <- length(unique(subset_pre$study_id))
  # k_per_gene: per ogni gene_id, quante entry ha (= bracci che hanno DE valido)
  k_per_gene_pre <- as.vector(table(subset_pre$gene_id[!is.na(subset_pre$logFC)]))
  k_med_pre      <- round(median(k_per_gene_pre, na.rm = TRUE), 1)

  cat(sprintf("  %s (%s):\n", b$nome, cid))
  cat(sprintf("    PRE-collapse:  righe=%d, studi=%d, k_per_gene_mediano=%.1f\n",
              n_righe_pre, n_studi_pre, k_med_pre))

  # --- COLLAPSE ---
  subset_post <- .collapse_arms_by_study(subset_pre)
  n_righe_post  <- nrow(subset_post)
  n_studi_post  <- length(unique(subset_post$study_id))
  k_per_gene_post <- as.vector(table(subset_post$gene_id[!is.na(subset_post$logFC)]))
  k_med_post      <- round(median(k_per_gene_post, na.rm = TRUE), 1)

  # VERIFICA: k_med_post deve essere <= n_studi_capped
  n_studi_atteso <- dstat$n_studi_capped
  collapse_ok <- k_med_post <= n_studi_atteso

  cat(sprintf("    POST-collapse: righe=%d, studi=%d, k_per_gene_mediano=%.1f\n",
              n_righe_post, n_studi_post, k_med_post))
  cat(sprintf("    n_studi_nel_dispatch_capped: %d\n", n_studi_atteso))
  cat(sprintf("    [%s] k_med_post (%.1f) <= n_studi_capped (%d): %s\n",
              if (collapse_ok) "OK" else "RED!", k_med_post, n_studi_atteso,
              if (collapse_ok) "SI" else "NO — BUG collapse non ha funzionato!"))

  # --- POOL REM POST-COLLAPSE ---
  t_pool <- proc.time()
  pool <- tryCatch(
    .pool_rem_cluster(subset_post, method_label = "rem_group"),
    error = function(e) {
      cat(sprintf("    [ERRORE pool] %s\n", conditionMessage(e)))
      NULL
    }
  )
  t_pool_elapsed <- round((proc.time() - t_pool)[3], 1)

  if (is.null(pool) || nrow(pool) == 0L) {
    cat(sprintf("    [RED] Pool REM vuoto per %s\n", b$nome))
    n_geni  <- 0L
    n_sig   <- 0L
    I2_med  <- NA_real_
    k_pool  <- NA_real_  # k_effective dal pool metafor
  } else {
    n_geni  <- nrow(pool)
    n_sig   <- sum(pool$FDR_BH_within_cluster < 0.05, na.rm = TRUE)
    I2_med  <- round(median(pool$I2, na.rm = TRUE), 1)
    k_pool  <- round(median(pool$k_effective, na.rm = TRUE), 1)

    # Verifica CRITICA: k_effective (da metafor) deve essere <= n_studi_capped
    kpool_ok <- is.finite(k_pool) && k_pool <= n_studi_atteso
    cat(sprintf("    Pool REM: n_geni=%d, n_FDR<0.05=%d, I2_med=%.1f%%, k_pool_med=%.1f (in %.1fs)\n",
                n_geni, n_sig, I2_med, k_pool, t_pool_elapsed))
    cat(sprintf("    [%s] k_pool_med (%.1f) <= n_studi_capped (%d): %s\n",
                if (kpool_ok) "OK" else "RED!", k_pool, n_studi_atteso,
                if (kpool_ok) "SI" else "NO — PSEUDO-REPLICAZIONE RESIDUA!"))
  }
  cat("\n")

  risultati[[cid]] <- list(
    nome           = b$nome,
    cid            = cid,
    n_entry_totale = dstat$n_entry_totale,
    n_studi_totale = dstat$n_studi_totale,
    bracci_extra   = dstat$bracci_extra,
    # Nel subset capped
    n_entry_capped = dstat$n_entry_capped,
    n_studi_capped = n_studi_atteso,
    # Misure pre-collapse
    n_righe_pre    = n_righe_pre,
    k_med_pre      = k_med_pre,
    # Misure post-collapse
    n_righe_post   = n_righe_post,
    k_med_post     = k_med_post,
    collapse_ok    = collapse_ok,
    # Pool REM post-collapse
    n_geni_pool    = n_geni,
    n_sig          = n_sig,
    I2_med         = I2_med,
    k_pool_med     = k_pool
  )
}

# -------------------------------------------------------------------------
# Riepilogo finale
# -------------------------------------------------------------------------
cat("=== RIEPILOGO FINALE ===\n\n")
n_ok  <- sum(vapply(risultati, `[[`, "collapse_ok", FUN.VALUE = logical(1)),
             na.rm = TRUE)
n_tot <- length(risultati)
cat(sprintf("Cluster validati: %d / %d\n", n_tot, length(BANDIERE)))
cat(sprintf("Collapse OK (k_post <= n_studi): %d / %d\n", n_ok, n_tot))
cat(sprintf("STATUS: %s\n\n",
            if (n_ok == n_tot && n_tot > 0)
              "PASS — collapse confermato sui dati veri"
            else
              "FAIL — verificare i cluster con [RED!]"))

# -------------------------------------------------------------------------
# Scrivi report Markdown
# -------------------------------------------------------------------------
cat("Scrivo report:", MD_OUT, "\n")

# Tabella principale
tab_rows <- vapply(risultati, function(r) {
  sprintf("| %s | %d | %d | %d | %d | %.1f | %.1f | %.1f%% | %d | %s |",
          r$nome,
          r$n_entry_capped,         # bracci nel subset usato
          r$n_studi_capped,         # studi distinti nel subset
          r$n_righe_pre,            # righe pre-collapse
          r$n_righe_post,           # righe post-collapse
          r$k_med_pre,              # k per gene pre
          r$k_med_post,             # k per gene post
          ifelse(is.na(r$I2_med), NA_real_, r$I2_med),
          r$n_sig,
          if (isTRUE(r$collapse_ok)) "OK" else "RED!")
}, character(1))

md <- c(
  "# Validazione collapse rem_group su dati veri (2026-07-05)",
  "",
  paste0("Script: `analysis/audit/2026-07-05-stage4-rem-group-collapse-validate.R`  "),
  paste0("Stage 3 v7: `20260703T113045Z-stage3-v7-364547a7`  "),
  paste0("Stage 2 master: `p4-fase-f4-stage2-master-v3.jsonl`  "),
  paste0("Data: ", Sys.time()),
  "",
  "## Obiettivo",
  "",
  "Verificare che `.collapse_arms_by_study()` riduca correttamente",
  "la pseudo-replicazione nei cluster `rem_group`: dopo il collapse,",
  "il `k_effective` per gene deve essere ≤ al numero di studi distinti",
  "(non al numero di bracci).",
  "",
  "## Cluster bandiera (da smoke precedente)",
  "",
  paste0("Dispatch sub-campionato a max ", CAP_PER_CLUSTER,
         " entry per cluster, priorizzzando studi con bracci multipli."),
  "",
  "| Cluster | Nome | n_entry_totale | n_studi_totale | bracci_extra |",
  "|---|---|---|---|---|",
  do.call(paste0, lapply(BANDIERE, function(b) {
    ds <- dispatch_stats[[b$cid]]
    if (is.null(ds)) return("")
    sprintf("| %s | %s | %d | %d | %d |\n",
            b$cid, b$nome,
            ds$n_entry_totale, ds$n_studi_totale, ds$bracci_extra)
  })),
  "",
  "## Risultati validazione post-collapse",
  "",
  "Colonne: n_entry = bracci nel subset capped; n_studi = studi distinti nel subset;",
  "k_pre = k_per_gene mediano PRIMA del collapse (= bracci);",
  "k_post = k_per_gene mediano DOPO il collapse (deve essere ≤ n_studi);",
  "I2 = eterogeneità mediana nel pool REM post-collapse; n_sig = geni FDR<0.05.",
  "",
  "| Nome | n_entry | n_studi | n_righe_pre | n_righe_post | k_pre | k_post | I2_med | n_sig | Collapse |",
  "|---|---|---|---|---|---|---|---|---|---|",
  paste(tab_rows, collapse = "\n"),
  "",
  sprintf("**STATUS: %s (%d/%d cluster con collapse OK)**",
          if (n_ok == n_tot && n_tot > 0) "PASS" else "FAIL",
          n_ok, n_tot),
  "",
  "## Interpretazione",
  "",
  "- **k_post ≤ n_studi**: il collapse ha unito i bracci multipli dello stesso studio",
  "  in un'unica stima per gene via inverse-variance FE. Ogni studio pesa una volta sola",
  "  nel REM successivo → pseudo-replicazione eliminata.",
  "",
  "- **I2_med post-collapse**: l'eterogeneità post-collapse riflette la variabilità",
  "  biologica cross-studio (non la variabilità artificiale da bracci multipli).",
  "  Atteso < I2 pre-collapse (smoke precedente: 58–92% con pseudo-replicazione).",
  "",
  "## Confronto con smoke precedente (pre-collapse)",
  "",
  "Lo smoke precedente (`2026-07-05-stage4-rem-group-smoke.R`) ha misurato il pool",
  "senza `.collapse_arms_by_study()`. Risultati pre-collapse (5 cluster capped a 6):",
  "",
  "| Cluster | n_geni | n_sig | I2_med (SENZA collapse) |",
  "|---|---|---|---|",
  "| tamoxifen group_L4_3c38c897 | 16490 | 667 | 92.4% |",
  "| Breast Neopl. group_L4_5d10ee81 | 17053 | 279 | 89.3% |",
  "| enzalutamide group_L4_b128b80d | 15810 | 3747 | 84.0% |",
  "| fulvestrant group_L4_b4975123 | 15876 | 1683 | 74.7% |",
  "| SARS-CoV-2 group_L4_b6a3eabd | 15045 | 240 | 58.4% |",
  "",
  "I valori I2 post-collapse dei cluster sovrapposti confermano se il collapse",
  "ha ridotto la pseudo-eterogeneità.",
  ""
)

writeLines(md, MD_OUT)
cat("Report scritto:", MD_OUT, "\n")
cat("\n=== VALIDAZIONE COMPLETATA ===\n")
