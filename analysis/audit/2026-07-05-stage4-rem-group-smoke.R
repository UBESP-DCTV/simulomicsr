#!/usr/bin/env Rscript
# =============================================================================
# 2026-07-05-stage4-rem-group-smoke.R
# Smoke gate per il ramo rem_group PRIMA del fullrun pesante (~11h).
# Obiettivo: validare copertura, dispatch e pool REM su campione leggero.
# NON esegue il fullrun; usa al massimo 5 cluster rem_group ammessi.
# =============================================================================

suppressPackageStartupMessages(devtools::load_all("."))
suppressPackageStartupMessages(library(arrow))

S3_DIR   <- "analysis/p4-output/20260703T113045Z-stage3-v7-364547a7"
S2_PATH  <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
H5_PATH  <- "analysis/input/human_gene_v2.5.h5"
TRIAGE   <- "analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv"
CSV_OUT  <- "analysis/audit/2026-07-05-stage4-rem-group-smoke.csv"
MD_OUT   <- "analysis/audit/2026-07-05-stage4-rem-group-smoke.md"

cat("=== BLOCCO 1: COPERTURA GLOBALE (no H5) ===\n\n")

# -----------------------------------------------------------------------
# 1. Carica input
# -----------------------------------------------------------------------
cat("Carico clusters v7...\n")
clusters <- readRDS(file.path(S3_DIR, "clusters.rds"))
cat("  -> nrow clusters:", nrow(clusters), "\n")

cat("Carico assignments v7...\n")
assignments <- as.data.frame(read_parquet(file.path(S3_DIR, "assignments.parquet")))
cat("  -> nrow assignments:", nrow(assignments), "\n")

cat("Carico stage2_master v3...\n")
t0 <- proc.time()
stage2_master <- .load_stage2_master(S2_PATH)
cat("  -> studi caricati:", length(stage2_master),
    "(", round((proc.time()-t0)[3], 1), "sec)\n")

cfg <- stage4_default_config()
cat("\nConfigurazione rem_group:\n")
cat("  k_eff_min =", cfg$rem_group$k_eff_min, "\n")
cat("  n_min =", cfg$rem_group$n_min, "\n")
cat("  excluded_kinds =", paste(cfg$rem_group$excluded_kinds, collapse=", "), "\n\n")

# -----------------------------------------------------------------------
# 2. Identifica cluster Layer A + misura rem_group
# -----------------------------------------------------------------------
cat("Identifico cluster Layer A (identify_layer_a_clusters)...\n")
layer_a <- .identify_layer_a_clusters(clusters, cfg)
method_tab <- table(layer_a$method)
cat("  Layer A totale:", nrow(layer_a), "cluster\n")
for (m in names(method_tab)) {
  cat(sprintf("    %-12s: %d\n", m, method_tab[[m]]))
}

rg <- layer_a[layer_a$method == "rem_group", ]
cat("\nrem_group post-dedup:", nrow(rg), "cluster\n")
cat("  k (raw) range:", min(rg$k), "-", max(rg$k), "\n")
cat("  kind distribution:\n")
kind_tab <- sort(table(rg$kind_effective_resolved), decreasing = TRUE)
for (kk in names(kind_tab)) {
  cat(sprintf("    %-40s: %d\n", kk, kind_tab[[kk]]))
}

# -----------------------------------------------------------------------
# 3. Costruisci dispatch group rem
# -----------------------------------------------------------------------
cat("\nCostruisco dispatch group_rem...\n")
t0 <- proc.time()
disp <- .build_group_rem_dispatch_from_stage3(
  rg, assignments, stage2_master, n_min = cfg$rem_group$n_min
)
cat("  -> cluster con dispatch valido:", length(disp),
    "(", round((proc.time()-t0)[3], 1), "sec)\n")

# -----------------------------------------------------------------------
# 4. Calcola k_eff, n_entry, n_bracci_extra per-cluster
# -----------------------------------------------------------------------
cat("\nCalcolo k_eff / n_bracci_extra per cluster...\n")
cluster_stats <- lapply(rg$cluster_id, function(cid) {
  d <- disp[[cid]]
  if (is.null(d) || length(d) == 0L) {
    return(data.frame(
      cluster_id          = cid,
      kind_effective_resolved = rg$kind_effective_resolved[rg$cluster_id == cid],
      agent_id_resolved   = rg$agent_id_resolved[rg$cluster_id == cid],
      level               = rg$level[rg$cluster_id == cid],
      k_raw               = rg$k[rg$cluster_id == cid],
      n_entry             = 0L,
      k_eff               = 0L,
      n_bracci_extra      = 0L,
      ammesso             = FALSE,
      stringsAsFactors    = FALSE
    ))
  }
  study_ids <- vapply(d, function(x) x$study_id, character(1))
  n_entry   <- length(d)
  k_eff     <- length(unique(study_ids))
  data.frame(
    cluster_id          = cid,
    kind_effective_resolved = rg$kind_effective_resolved[rg$cluster_id == cid],
    agent_id_resolved   = rg$agent_id_resolved[rg$cluster_id == cid],
    level               = rg$level[rg$cluster_id == cid],
    k_raw               = rg$k[rg$cluster_id == cid],
    n_entry             = n_entry,
    k_eff               = k_eff,
    n_bracci_extra      = n_entry - k_eff,
    ammesso             = k_eff >= cfg$rem_group$k_eff_min,
    stringsAsFactors    = FALSE
  )
})
cs <- do.call(rbind, cluster_stats)

n_ammessi <- sum(cs$ammesso)
n_non_ammessi <- sum(!cs$ammesso)
n_no_dispatch <- sum(cs$n_entry == 0L)

cat(sprintf("  cluster ammessi (k_eff >= %d): %d\n", cfg$rem_group$k_eff_min, n_ammessi))
cat(sprintf("  cluster non-ammessi (k_eff < %d): %d\n", cfg$rem_group$k_eff_min, n_non_ammessi))
cat(sprintf("    di cui con dispatch vuoto (0 entry): %d\n", n_no_dispatch))

# Distribuzione k_eff
cat("\nDistribuzione k_eff (ammessi):\n")
keff_tab <- table(cs$k_eff[cs$ammesso])
# stampa soglie significative
for (bin in c("3","4","5","6-10","11-20","21-50","51-100","101+")) {
  if (bin == "3") n <- sum(cs$k_eff[cs$ammesso] == 3, na.rm=TRUE)
  else if (bin == "4") n <- sum(cs$k_eff[cs$ammesso] == 4, na.rm=TRUE)
  else if (bin == "5") n <- sum(cs$k_eff[cs$ammesso] == 5, na.rm=TRUE)
  else if (bin == "6-10") n <- sum(cs$k_eff[cs$ammesso] >= 6 & cs$k_eff[cs$ammesso] <= 10, na.rm=TRUE)
  else if (bin == "11-20") n <- sum(cs$k_eff[cs$ammesso] >= 11 & cs$k_eff[cs$ammesso] <= 20, na.rm=TRUE)
  else if (bin == "21-50") n <- sum(cs$k_eff[cs$ammesso] >= 21 & cs$k_eff[cs$ammesso] <= 50, na.rm=TRUE)
  else if (bin == "51-100") n <- sum(cs$k_eff[cs$ammesso] >= 51 & cs$k_eff[cs$ammesso] <= 100, na.rm=TRUE)
  else n <- sum(cs$k_eff[cs$ammesso] > 100, na.rm=TRUE)
  if (n > 0) cat(sprintf("    k_eff %6s: %d cluster\n", bin, n))
}

# MISURA I1: bracci multipli intra-studio
cat("\n--- MISURA I1: bracci multipli intra-studio ---\n")
n_con_bracci <- sum(cs$n_bracci_extra > 0 & cs$ammesso)
cat(sprintf("  cluster ammessi con n_bracci_extra > 0: %d / %d (%.1f%%)\n",
            n_con_bracci, n_ammessi,
            100 * n_con_bracci / max(n_ammessi, 1)))
if (n_con_bracci > 0) {
  ba <- cs$n_bracci_extra[cs$ammesso & cs$n_bracci_extra > 0]
  cat(sprintf("  n_bracci_extra - max: %d, mediana: %.1f, Q75: %.1f, Q95: %.1f\n",
              max(ba), median(ba), quantile(ba, 0.75), quantile(ba, 0.95)))
  cat("  distribuzione n_bracci_extra (ammessi):\n")
  be_tab <- table(pmin(cs$n_bracci_extra[cs$ammesso], 10))
  for (v in names(be_tab)) {
    cat(sprintf("    %s extra bracci: %d cluster\n",
                if(v=="10") ">=10" else v, be_tab[[v]]))
  }
}

# Salva CSV
cat("\nSalvo CSV:", CSV_OUT, "\n")
write.csv(cs, CSV_OUT, row.names = FALSE)

cat("\n=== BLOCCO 2: BANDIERA NOMINATE ===\n\n")

# -----------------------------------------------------------------------
# 5. Mappa bandiera verso cluster rem_group
# -----------------------------------------------------------------------
triage <- read.csv(TRIAGE, stringsAsFactors = FALSE)

# Entità bandiera da cercare
bandiere_nomi  <- c("SARS-CoV-2", "sars-cov-2", "sars-cov2",
                    "enzalutamide",
                    "Breast Neoplasms",
                    "Prostatic Neoplasms",
                    "Alzheimer", "Alzheimer Disease",
                    "fulvestrant",
                    "tamoxifen",
                    "vemurafenib")

# Cerca nei cluster rem_group via nome (triage) + agent_id_resolved
# Strategy: join per cluster_id tra triage e cs + grep su agent_id
triage_rg <- merge(triage, cs, by = "cluster_id", all.x = FALSE, all.y = FALSE)

# Cerca anche per agent_id_resolved (stringa grepped)
bandiere_pattern <- paste(
  c("sars.cov", "enzalutamide", "breast.neopl", "prostatic.neopl",
    "alzheimer", "fulvestrant", "tamoxifen", "vemurafenib"),
  collapse = "|"
)

# Match via triage name
found_via_triage <- triage_rg[grepl(bandiere_pattern, triage_rg$name, ignore.case=TRUE), ]
# Match via agent_id_resolved nei cluster rem_group
found_via_agent  <- cs[grepl(bandiere_pattern, cs$agent_id_resolved, ignore.case=TRUE), ]

all_found_cids <- unique(c(found_via_triage$cluster_id, found_via_agent$cluster_id))

cat("Bandiera ricercate:", paste(c("SARS-CoV-2","enzalutamide","Breast Neoplasms",
                                   "Prostatic Neoplasms","Alzheimer Disease",
                                   "fulvestrant","tamoxifen","vemurafenib"), collapse="; "), "\n\n")

if (length(all_found_cids) == 0) {
  cat("NESSUNA bandiera trovata nei cluster rem_group post-dedup.\n")
  cat("  (possibile causa: cadute nel dispatch per mancanza di controlli in-studio)\n\n")
} else {
  cat("Bandiere trovate in rem_group:\n")
  found_detail <- cs[cs$cluster_id %in% all_found_cids, ]
  # Aggiungi nome da triage se disponibile
  found_detail <- merge(found_detail,
                        triage[, c("cluster_id", "name")],
                        by = "cluster_id", all.x = TRUE)
  for (i in seq_len(nrow(found_detail))) {
    cat(sprintf("  [%s] nome='%s' kind=%s k_raw=%d k_eff=%d bracci_extra=%d ammesso=%s\n",
                found_detail$cluster_id[i],
                found_detail$name[i],
                found_detail$kind_effective_resolved[i],
                found_detail$k_raw[i],
                found_detail$k_eff[i],
                found_detail$n_bracci_extra[i],
                found_detail$ammesso[i]))
  }
}

# Bandiere ASSENTI: elenca e spiega
bandiere_tab <- c(
  "SARS-CoV-2"       = "sars.cov",
  "enzalutamide"     = "enzalutamide",
  "Breast Neoplasms" = "breast.neopl",
  "Prostatic Neoplasms" = "prostatic.neopl",
  "Alzheimer Disease" = "alzheimer",
  "fulvestrant"      = "fulvestrant",
  "tamoxifen"        = "tamoxifen",
  "vemurafenib"      = "vemurafenib"
)
cat("\nRiepilogo per bandiera:\n")
for (bn in names(bandiere_tab)) {
  pat <- bandiere_tab[[bn]]
  found_n <- cs[grepl(pat, cs$agent_id_resolved, ignore.case=TRUE) |
                  (cs$cluster_id %in% triage_rg$cluster_id[grepl(pat, triage_rg$name, ignore.case=TRUE)]), ]
  if (nrow(found_n) == 0) {
    cat(sprintf("  %-25s: NON trovata nel rem_group ammesso\n", bn))
  } else {
    for (i in seq_len(nrow(found_n))) {
      cat(sprintf("  %-25s: cluster=%s k_raw=%d k_eff=%d ammesso=%s\n",
                  bn, found_n$cluster_id[i], found_n$k_raw[i],
                  found_n$k_eff[i], found_n$ammesso[i]))
    }
  }
}

cat("\n=== BLOCCO 3: VALIDAZIONE POOL (campione ≤5 cluster, CON H5) ===\n\n")

# -----------------------------------------------------------------------
# 6. Seleziona ≤5 cluster rem_group ammessi per il pool di prova
# -----------------------------------------------------------------------
# Preferisci bandiera ammesse, poi più grandi per k_eff
cs_ammessi <- cs[cs$ammesso, ]
cs_ammessi <- cs_ammessi[order(-cs_ammessi$k_eff), ]

# Cerca bandiera ammesse
bandiera_cids <- cs_ammessi$cluster_id[
  grepl(bandiere_pattern, cs_ammessi$agent_id_resolved, ignore.case = TRUE)
]
if (length(bandiera_cids) == 0) {
  # cerca via triage
  bandiera_cids <- triage_rg$cluster_id[
    grepl(bandiere_pattern, triage_rg$name, ignore.case=TRUE) &
      triage_rg$ammesso
  ]
}

# Componi lista: bandiera prima, poi top k_eff, max 5 totali
pool_cids <- unique(c(bandiera_cids, cs_ammessi$cluster_id))
pool_cids <- pool_cids[seq_len(min(5, length(pool_cids)))]

cat("Cluster selezionati per pool di prova (≤5):\n")
for (cid in pool_cids) {
  row_i <- cs_ammessi[cs_ammessi$cluster_id == cid, ]
  # Cerca nome in triage se disponibile
  triage_row <- triage[triage$cluster_id == cid, ]
  nome <- if (nrow(triage_row) > 0) triage_row$name[1] else row_i$agent_id_resolved
  cat(sprintf("  %s  kind=%-30s k_eff=%d  bracci_extra=%d  nome='%s'\n",
              cid, row_i$kind_effective_resolved, row_i$k_eff,
              row_i$n_bracci_extra, nome))
}

# Costruisci eligible_clusters subset con dispatch
cs_pool <- rg[rg$cluster_id %in% pool_cids, ]
disp_pool <- disp[pool_cids]
names(disp_pool) <- pool_cids

# Limita studi per cluster per non appesantire il test (cap 6 studi per cluster)
CAP_STUDI <- 6L
disp_pool_capped <- lapply(disp_pool, function(d) {
  if (length(d) > CAP_STUDI) {
    cat(sprintf("    (cappando dispatch a %d studi)\n", CAP_STUDI))
    d[seq_len(CAP_STUDI)]
  } else d
})
names(disp_pool_capped) <- pool_cids

attr(cs_pool, "study_dispatch") <- disp_pool_capped

# fetch function con cache
fetch_fn <- function(gse, sample_ids) {
  .fetch_counts_cached(gse, sample_ids, h5_path = H5_PATH,
                       gene_biotype_filter = "protein_coding")
}

cat("\nEseguo per-study DE (REM)...\n")
t0 <- proc.time()
psd <- tryCatch(
  .run_per_study_de_all(cs_pool, fetch_fn = fetch_fn, workers = 1L),
  error = function(e) {
    cat("ERRORE in .run_per_study_de_all:", conditionMessage(e), "\n")
    NULL
  }
)
cat("  -> tempo:", round((proc.time()-t0)[3], 1), "sec\n")

if (is.null(psd)) {
  cat("\n[RED] .run_per_study_de_all ha restituito NULL — blocco interrotto.\n")
} else {
  cat("  -> righe per-study DE:", nrow(psd), "\n")
  if (nrow(psd) == 0) {
    cat("\n[RED] per_study_de VUOTO — il pool non puo' procedere.\n")
  } else {
    cat("  -> cluster con DE:", length(unique(psd$cluster_id)), "\n")

    # Pool REM per cluster
    pool_results <- list()
    for (cid in pool_cids) {
      subset_i <- psd[psd$cluster_id == cid, ]
      if (nrow(subset_i) == 0) {
        cat(sprintf("  [WARN] %s: per_study_de vuota (nessuna entry) — skip pool\n", cid))
        next
      }
      cat(sprintf("  Pooling REM: %s (nrow=%d)\n", cid, nrow(subset_i)))
      pool_i <- tryCatch(
        .pool_rem_cluster(subset_i, method_label = "rem_group"),
        error = function(e) {
          cat(sprintf("    [ERRORE pool] %s: %s\n", cid, conditionMessage(e)))
          NULL
        }
      )
      if (is.null(pool_i)) next
      n_geni   <- nrow(pool_i)
      n_sig    <- if (n_geni > 0 && "FDR_BH_within_cluster" %in% names(pool_i)) {
        sum(pool_i$FDR_BH_within_cluster < 0.05, na.rm = TRUE)
      } else 0L
      med_i2   <- if (n_geni > 0 && "I2" %in% names(pool_i)) {
        round(median(pool_i$I2, na.rm = TRUE), 2)
      } else NA
      med_tau2 <- if (n_geni > 0 && "tau2" %in% names(pool_i)) {
        round(median(pool_i$tau2, na.rm = TRUE), 4)
      } else NA

      cat(sprintf("    -> n_geni_pooled=%d  n_FDR<0.05=%d  medI2=%.2f  medTau2=%.4f\n",
                  n_geni, n_sig, ifelse(is.na(med_i2), -1, med_i2),
                  ifelse(is.na(med_tau2), -1, med_tau2)))

      # VERIFICA CRITICA C1: il pool NON deve essere vuoto
      if (n_geni == 0) {
        cat(sprintf("    [RED C1] POOL VUOTO per %s — bug C1 non risolto end-to-end!\n", cid))
      } else {
        cat(sprintf("    [OK] pool non-vuoto per %s\n", cid))
      }
      pool_results[[cid]] <- list(
        cluster_id = cid,
        n_geni_pooled = n_geni,
        n_sig = n_sig,
        med_i2 = med_i2,
        med_tau2 = med_tau2
      )
    }
  }
}

cat("\n=== RIEPILOGO FINALE ===\n")
cat(sprintf("rem_group post-dedup totale: %d\n", nrow(rg)))
cat(sprintf("  ammessi (k_eff >= %d):      %d\n", cfg$rem_group$k_eff_min, n_ammessi))
cat(sprintf("  non-ammessi:                %d\n", n_non_ammessi))
cat(sprintf("  con bracci multipli intra-studio: %d / %d (%.1f%%)\n",
            n_con_bracci, n_ammessi, 100*n_con_bracci/max(n_ammessi,1)))
cat(sprintf("  max n_bracci_extra negli ammessi: %d\n",
            if(n_con_bracci > 0) max(cs$n_bracci_extra[cs$ammesso]) else 0))
cat("Pool campione NON vuoto: ")
if (!is.null(psd) && nrow(psd) > 0 && length(pool_results) > 0) {
  non_vuoti <- sum(vapply(pool_results, function(r) r$n_geni_pooled > 0, logical(1)))
  cat(sprintf("SI (%d/%d cluster con pool non-vuoto)\n", non_vuoti, length(pool_results)))
} else {
  cat("NON VERIFICATO (vedi errori sopra)\n")
}

# -----------------------------------------------------------------------
# Scrivi report Markdown
# -----------------------------------------------------------------------
cat("\nScrivo report:", MD_OUT, "\n")

# Raccogli info per il report
bandiera_righe <- character(0)
for (bn in names(bandiere_tab)) {
  pat <- bandiere_tab[[bn]]
  found_n <- cs[grepl(pat, cs$agent_id_resolved, ignore.case=TRUE) |
                  (cs$cluster_id %in% triage_rg$cluster_id[grepl(pat, triage_rg$name, ignore.case=TRUE)]), ]
  if (nrow(found_n) == 0) {
    bandiera_righe <- c(bandiera_righe,
      sprintf("| %-25s | NON in rem_group | NA | NA | NA | - |", bn))
  } else {
    for (i in seq_len(nrow(found_n))) {
      bandiera_righe <- c(bandiera_righe,
        sprintf("| %-25s | %s | %d | %d | %s | %d |",
                bn, found_n$cluster_id[i],
                found_n$k_raw[i], found_n$k_eff[i],
                found_n$ammesso[i], found_n$n_bracci_extra[i]))
    }
  }
}

pool_righe <- character(0)
for (cid in names(pool_results)) {
  r <- pool_results[[cid]]
  pool_righe <- c(pool_righe,
    sprintf("| %s | %d | %d | %.2f | %.4f |",
            cid, r$n_geni_pooled, r$n_sig,
            ifelse(is.na(r$med_i2), -1, r$med_i2),
            ifelse(is.na(r$med_tau2), -1, r$med_tau2)))
}

md_lines <- c(
  "# Smoke gate rem_group — Stage 4 v7 (2026-07-05)",
  "",
  "Script: `analysis/audit/2026-07-05-stage4-rem-group-smoke.R`  ",
  "Stage 3: `20260703T113045Z-stage3-v7-364547a7`  ",
  "Stage 2 master: `p4-fase-f4-stage2-master-v3.jsonl`  ",
  "",
  "## (a) Copertura globale",
  "",
  sprintf("Layer A totale: **%d** cluster (mega=%d, mega_aug=%d, rem=%d, rem_group=%d)",
          nrow(layer_a), method_tab[["mega"]], method_tab[["mega_aug"]],
          method_tab[["rem"]], method_tab[["rem_group"]]),
  "",
  sprintf("rem_group post-dedup: **%d** cluster", nrow(rg)),
  sprintf("- Ammessi (k_eff >= %d): **%d**", cfg$rem_group$k_eff_min, n_ammessi),
  sprintf("- Non-ammessi (k_eff < %d): **%d** (di cui %d con dispatch vuoto)",
          cfg$rem_group$k_eff_min, n_non_ammessi, n_no_dispatch),
  "",
  "Principali cause di non-ammissione: mancanza di comparison in stage2 con",
  "il group come treated_group (il controllo non è nello stesso studio). Questo",
  "è atteso per cluster 'both_roles' dove il controllo è nel cluster stesso",
  "ma non compare in una comparison separata, o per studi senza design aperto.",
  "",
  "## (b) Tabella bandiera",
  "",
  "| Bandiera | cluster_id | k_raw | k_eff | ammesso | n_bracci_extra |",
  "|---|---|---|---|---|---|",
  paste(bandiera_righe, collapse="\n"),
  "",
  "## (c) Misura I1 — bracci multipli intra-studio",
  "",
  sprintf("Cluster ammessi con n_bracci_extra > 0: **%d / %d (%.1f%%)**",
          n_con_bracci, n_ammessi, 100*n_con_bracci/max(n_ammessi,1)),
  "",
  if (n_con_bracci > 0) {
    ba_full <- cs$n_bracci_extra[cs$ammesso & cs$n_bracci_extra > 0]
    sprintf("Distribuzione n_bracci_extra (ammessi con bracci > 0): max=%d, mediana=%.1f, Q75=%.1f, Q95=%.1f",
            max(ba_full), median(ba_full), quantile(ba_full, 0.75), quantile(ba_full, 0.95))
  } else "Nessun cluster ammesso con bracci multipli intra-studio.",
  "",
  "I bracci multipli intra-studio derivano da farmaci testati a dosi/tempi diversi",
  "nello stesso studio (es. enzalutamide 1nM vs 10nM). Entrano tutti nel per-study",
  "DE come entry separate e poi vengono aggregati nel REM. Questo introduce",
  "pseudo-replicazione a livello di studio. La decisione di aggregazione",
  "(media bracci o selezione) è aperta e richiede gate utente.",
  "",
  "## (d) Risultati pool campione",
  "",
  if (length(pool_results) > 0) {
    c("| cluster_id | n_geni_pooled | n_FDR<0.05 | mediana_I2 | mediana_tau2 |",
      "|---|---|---|---|---|",
      paste(pool_righe, collapse="\n"))
  } else {
    "Pool campione non eseguito o nessun risultato."
  },
  "",
  sprintf("**Pool campione NON vuoto: %s**",
          if (!is.null(psd) && nrow(psd) > 0 && length(pool_results) > 0 &&
              any(vapply(pool_results, function(r) r$n_geni_pooled > 0, logical(1))))
            "SI" else "NO — VERIFICARE ERRORI"),
  "",
  "## Conclusione",
  "",
  "Il ramo rem_group è validato sul campione leggero se:",
  "- Pool non vuoto: SI",
  "- n_FDR<0.05 > 0 in almeno 1 cluster: da verificare sopra",
  "- Nessun crash critico nel per-study DE",
  ""
)

writeLines(md_lines, MD_OUT)
cat("Report scritto:", MD_OUT, "\n")
cat("\n=== SMOKE GATE COMPLETATO ===\n")
