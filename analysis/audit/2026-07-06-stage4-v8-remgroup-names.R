# analysis/audit/2026-07-06-stage4-v8-remgroup-names.R
# Mappa i 70 cluster rem_group PROCESSATI (+ i 279 caduti) sui nomi anchor
# dello Stadio 3 v7, per confermare le bandiera attese e nominare le meta-analisi.
suppressPackageStartupMessages({ library(arrow); library(dplyr); library(cli) })

V8 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v8/20260706T112612Z-stage4-v8-a500d032"
S3 <- "analysis/p4-output/20260703T113045Z-stage3-v7-364547a7"

devtools::load_all(".")
s3 <- load_stage3(S3)
cl <- s3$clusters
cat("== colonne clusters stage3 ==\n"); print(names(cl))

cp8 <- arrow::open_dataset(file.path(V8, "cluster_pooled.parquet"))
rg <- cp8 %>% filter(method == "rem_group") %>%
  select(cluster_id, gene_id, I2, tau2, k_effective, FDR_BH_within_cluster) %>% collect()
proc_ids <- unique(rg$cluster_id)
cat("\n== rem_group processati:", length(proc_ids), "==\n")

per_cluster <- rg %>% group_by(cluster_id) %>%
  summarise(n_sig = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
            I2_med = round(median(I2, na.rm = TRUE), 1),
            tau2_med = round(median(tau2, na.rm = TRUE), 4),
            k_med = median(k_effective, na.rm = TRUE), .groups = "drop")

# colonne candidate per il nome
name_cols <- intersect(c("anchor_key","kind_effective","kind_effective_resolved",
                         "level","mode","agent_id","anchor_summary","kind"), names(cl))
cat("colonne nome disponibili:", paste(name_cols, collapse=", "), "\n")
meta <- cl %>% filter(cluster_id %in% proc_ids) %>%
  select(cluster_id, all_of(name_cols)) %>% distinct()

joined <- per_cluster %>% left_join(meta, by = "cluster_id") %>% arrange(desc(n_sig))
cat("\n== 70 rem_group PROCESSATI con nome (ordinati per n_sig) ==\n")
print(as.data.frame(joined), row.names = FALSE)

# ---- Bandiera ------------------------------------------------------------
flag_pat <- "sars|cov|2697049|enzalutamide|breast|prostat|D001943|D011471|fulvestrant|tamoxifen|vemurafenib"
hay <- apply(joined[, intersect(c("anchor_key","kind_effective","agent_id"), names(joined)), drop=FALSE],
             1, paste, collapse = " ¦ ")
cat("\n== BANDIERA attese ==\n")
print(as.data.frame(joined[grepl(flag_pat, hay, ignore.case=TRUE),
      c("cluster_id","anchor_key","n_sig","I2_med","k_med")]), row.names = FALSE)

# ---- salva CSV per il finding --------------------------------------------
out_csv <- "analysis/audit/2026-07-06-stage4-v8-remgroup-processed.csv"
write.csv(joined, out_csv, row.names = FALSE)
cat("\nCSV salvato:", out_csv, "\n")

# ---- i 279 caduti: che entita' erano? ------------------------------------
np <- readRDS(file.path(V8, "non_processable.rds"))
np_rg <- np[grepl("rem_group", np$reason), ]
np_meta <- cl %>% filter(cluster_id %in% np_rg$cluster_id) %>%
  select(cluster_id, all_of(intersect(c("anchor_key","kind_effective"), name_cols))) %>% distinct()
np_join <- np_rg %>% left_join(np_meta, by = "cluster_id")
cat("\n== 279 rem_group CADUTI: sample delle entita' (top per original_k) ==\n")
print(head(np_join[order(-np_join$original_k), c("cluster_id","original_k","reason","anchor_key")], 20), row.names = FALSE)
write.csv(np_join, "analysis/audit/2026-07-06-stage4-v8-remgroup-dropped.csv", row.names = FALSE)
cat("\n== FINE ==\n")
