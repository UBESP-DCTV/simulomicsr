# analysis/p4-fase-f6-concordance.R --- RED ALERT FASE F6 (pre-shortlist).
#
# Metrica di RIPRODUCIBILITA' cross-studio per cluster Stadio 4, da usare come
# gate scientifico della selezione Layer B AL POSTO della %DE (che la validazione
# 2026-06-13 ha mostrato NON diagnostica: i cluster ad alta %DE sono per lo piu'
# CONCORDI = biologia reale forte, non artefatti). Vedi
# analysis/audit/F5-concordance-metric.md.
#
# Due assi complementari (validati ortogonali, cor~0.03 sui rem):
#   B) concordance: accordo sul PATTERN/direzione dei geni fra studi del cluster.
#      = mediana delle correlazioni di Spearman a coppie dei logFC per-studio,
#        sui top-N geni per significativita' cross-studio (min p_value), pairwise
#        complete. Alta = effetto riproducibile; bassa = pooling incoerente.
#      COPERTURA (verificata, NON uniforme): rem k=3-8 (trusted); mega_aug k=2
#      (i 2 studi della coppia, check fragile ma reale); mega k=0 (pooled, NON
#      calcolabile). Gli artefatti high-%DE sono 71/75 mega_aug -> B copre dove
#      serve; i mega (conservativi, basso rischio) restano senza B per scelta.
#   A) med_I2 (solo rem): accordo sulla MAGNITUDINE dell'effect size fra studi
#      (eterogeneita' meta-analitica). Complementare a B, non sostituto.
#
# Gestione k: la concordanza a k=2 e' una sola coppia -> fragile. Riportiamo k e
# un flag conc_confidence (k>=3 = trusted, k==2 = low_conf). La soglia di
# selezione si fissa con l'utente in fase di shortlist (NON hard-coded qui).
#
# Output: analysis/p4-output/<stage4-dir>/cluster_reproducibility.rds
#   (cluster_id, method, k_studies, concordance, conc_confidence, med_I2, pct_sig,
#    n_sig, max_absLFC)

suppressPackageStartupMessages({ library(arrow); library(dplyr); library(tidyr) })

STAGE4_DIR <- Sys.getenv("STAGE4_DIR",
  unset = "analysis/p4-output/20260613T051637Z-stage4-4f7ea215")
TOP_N <- as.integer(Sys.getenv("TOP_N", unset = "2000"))
stopifnot(dir.exists(STAGE4_DIR))

cat("Carico per_study_de...\n")
ps <- arrow::read_parquet(file.path(STAGE4_DIR, "per_study_de.parquet"),
       col_select = c("cluster_id","study_id","gene_id","logFC","p_value"))

# Concordanza per cluster: matrice gene x studio dei logFC sui top-N geni per
# min p_value cross-studio; mediana delle correlazioni di Spearman a coppie.
conc_of <- function(df) {
  studies <- unique(df$study_id)
  k <- length(studies)
  if (k < 2L) return(c(conc = NA_real_, k = k))
  topg <- df %>% group_by(gene_id) %>%
    summarise(mp = min(p_value, na.rm = TRUE), .groups = "drop") %>%
    arrange(mp) %>% head(TOP_N) %>% pull(gene_id)
  w <- df %>% filter(gene_id %in% topg) %>%
    select(gene_id, study_id, logFC) %>%
    pivot_wider(names_from = study_id, values_from = logFC, values_fn = mean)
  M <- as.matrix(w[, -1, drop = FALSE])
  if (ncol(M) < 2L) return(c(conc = NA_real_, k = ncol(M)))
  cm <- suppressWarnings(cor(M, method = "spearman", use = "pairwise.complete.obs"))
  c(conc = median(cm[upper.tri(cm)], na.rm = TRUE), k = ncol(M))
}

cat("Calcolo concordanza per cluster (top", TOP_N, "geni)...\n")
res <- lapply(split(ps, ps$cluster_id), conc_of)
conc_df <- tibble(
  cluster_id  = names(res),
  concordance = vapply(res, function(x) unname(x["conc"]), numeric(1)),
  k_studies   = vapply(res, function(x) as.integer(unname(x["k"])), integer(1))
)
rm(ps); invisible(gc(verbose = FALSE))

cat("Join con cluster_pooled (pct_sig, I2, effect size)...\n")
cp <- arrow::read_parquet(file.path(STAGE4_DIR, "cluster_pooled.parquet"),
       col_select = c("cluster_id","method","logFC_pool","I2","FDR_BH_within_cluster"))
cls <- cp %>% group_by(cluster_id, method) %>%
  summarise(n_sig      = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
            pct_sig    = 100 * mean(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
            max_absLFC = max(abs(logFC_pool), na.rm = TRUE),
            med_I2     = median(I2, na.rm = TRUE), .groups = "drop")

repro <- cls %>% left_join(conc_df, by = "cluster_id") %>%
  mutate(conc_confidence = dplyr::case_when(
           is.na(concordance) ~ "no_pairs",
           k_studies >= 3L    ~ "trusted",
           TRUE               ~ "low_conf_k2"))

out <- file.path(STAGE4_DIR, "cluster_reproducibility.rds")
saveRDS(repro, out)
cat("\nScritto:", out, "(", nrow(repro), "cluster )\n")
cat("\n=== concordanza per confidence ===\n")
print(as.data.frame(repro %>% group_by(conc_confidence) %>%
  summarise(n = n(), conc_med = round(median(concordance, na.rm = TRUE), 2), .groups = "drop")))
