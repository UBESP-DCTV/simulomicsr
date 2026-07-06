# analysis/audit/2026-07-06-stage4-v8-antistale-regate.R
# Verifica anti-stale + re-gate del fullrun Stadio 4 v8 (ramo rem_group).
# Run: Rscript analysis/audit/2026-07-06-stage4-v8-antistale-regate.R
suppressPackageStartupMessages({ library(arrow); library(dplyr); library(tibble) })

V8  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v8/20260706T112612Z-stage4-v8-a500d032"
V7  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v7"
cat("== Individuo il run v7 per confronto ==\n")
v7_dir <- list.dirs(V7, recursive = FALSE)
v7_dir <- v7_dir[grepl("stage4-v7", v7_dir)][1]
cat("v7:", v7_dir, "\n")

cp8 <- arrow::open_dataset(file.path(V8, "cluster_pooled.parquet"))
cat("\n== Colonne cluster_pooled v8 ==\n"); print(names(cp8))

# ---- Cluster-level counts per method (v8) --------------------------------
by_method_v8 <- cp8 %>% select(cluster_id, method) %>% collect() %>%
  distinct(cluster_id, method) %>% count(method, name = "n_clusters")
cat("\n== v8: cluster UNICI per method ==\n"); print(by_method_v8)
cat("Totale cluster processati v8:", sum(by_method_v8$n_clusters), "\n")

# ---- v7 confronto --------------------------------------------------------
cp7 <- arrow::open_dataset(file.path(v7_dir, "cluster_pooled.parquet"))
by_method_v7 <- cp7 %>% select(cluster_id, method) %>% collect() %>%
  distinct(cluster_id, method) %>% count(method, name = "n_clusters_v7")
cat("\n== v7: cluster UNICI per method ==\n"); print(by_method_v7)
cat("Totale cluster processati v7:", sum(by_method_v7$n_clusters_v7), "\n")

# ---- Retrocompat: i 3 rami esistenti invariati? --------------------------
cat("\n== Retrocompat rami esistenti (v8 vs v7, atteso identico su rem/mega/mega_aug) ==\n")
cmp <- full_join(by_method_v8, by_method_v7, by = "method")
print(cmp)

# ---- rem_group dettaglio: anchor + n_sig + I2 + tau2 + k -----------------
rg <- cp8 %>% filter(method == "rem_group") %>% collect()
cat("\n== rem_group: cluster processati ==", length(unique(rg$cluster_id)), "\n")
# colonne candidate per etichetta/I2/tau2/k
lab_col <- intersect(c("anchor_label","anchor_key","label","kind_effective","anchor_summary"), names(rg))
cat("colonne label candidate:", paste(lab_col, collapse=", "), "\n")
het_col <- intersect(c("I2","tau2","k_effective","k","n_studies"), names(rg))
cat("colonne eterogeneita candidate:", paste(het_col, collapse=", "), "\n")

sig_col <- if ("FDR_BH_within_cluster" %in% names(rg)) "FDR_BH_within_cluster" else NA
per_cluster <- rg %>% group_by(cluster_id) %>%
  summarise(
    n_genes = n(),
    n_sig = if (!is.na(sig_col)) sum(.data[[sig_col]] < 0.05, na.rm = TRUE) else NA_integer_,
    I2_med = if ("I2" %in% names(rg)) median(I2, na.rm = TRUE) else NA_real_,
    tau2_med = if ("tau2" %in% names(rg)) median(tau2, na.rm = TRUE) else NA_real_,
    k_med = if ("k_effective" %in% names(rg)) median(k_effective, na.rm = TRUE)
            else if ("k" %in% names(rg)) median(k, na.rm = TRUE) else NA_real_,
    .groups = "drop"
  )
# aggancia una label leggibile se presente
if (length(lab_col) > 0) {
  labs <- rg %>% distinct(cluster_id, !!!rlang::syms(lab_col))
  per_cluster <- left_join(per_cluster, labs, by = "cluster_id")
}
per_cluster <- per_cluster %>% arrange(desc(n_sig))
cat("\n== rem_group per-cluster (ordinati per n_sig) ==\n")
print(as.data.frame(per_cluster), row.names = FALSE)

# ---- Bandiera attese ------------------------------------------------------
cat("\n== BANDIERA attese (SARS/enzalutamide/Breast/Prostatic/fulvestrant/tamoxifen/vemurafenib) ==\n")
flag_pat <- "sars|cov|enzalutamide|breast|prostat|fulvestrant|tamoxifen|vemurafenib|D001943|D011471|D011471"
if (length(lab_col) > 0) {
  hay <- apply(per_cluster[, lab_col, drop = FALSE], 1, paste, collapse = " | ")
  hit <- grepl(flag_pat, hay, ignore.case = TRUE)
  print(as.data.frame(per_cluster[hit, c("cluster_id", lab_col, "n_sig")]), row.names = FALSE)
  cat("bandiera trovate:", sum(hit), "\n")
} else cat("(nessuna colonna label per matchare le bandiera nel parquet)\n")

# ---- non_processable: reasons --------------------------------------------
np <- readRDS(file.path(V8, "non_processable.rds"))
cat("\n== non_processable v8:", nrow(np), "righe; colonne:", paste(names(np), collapse=", "), "==\n")
reason_col <- intersect(c("reason","why","status","message"), names(np))[1]
if (!is.na(reason_col)) {
  np$reason_family <- sub(":.*$", "", np[[reason_col]])
  cat("\n-- famiglie di reason --\n")
  print(np %>% count(reason_family, sort = TRUE) %>% as.data.frame(), row.names = FALSE)
  cat("\n-- reason contenenti 'rem_group' --\n")
  print(np %>% filter(grepl("rem_group", .data[[reason_col]])) %>%
          count(reason_family = sub("(k_eff=[0-9]+).*","\\1", .data[[reason_col]]), sort=TRUE) %>%
          head(20) %>% as.data.frame(), row.names = FALSE)
}

cat("\n== FINE VERIFICA ==\n")
