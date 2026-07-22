# analysis/audit/2026-07-20-stage4-v10-regate.R
# RE-GATE v10 vs v9 (RED ALERT F6 v10 closeout — LLM-fallback materializzato).
# Misura il guadagno della de-frammentazione col fallback finale (overlay v9 k>=2 +
# overlay fallback STR/UNK): quante meta-analisi rem_group NOMINATE, k_eff (studi) e
# OMOGENEITA' (I2). Il controllo anti-minestrone: le fusioni uniscono lo STESSO nome
# (breast+breast), quindi l'I2 deve restare nel range v9, non esplodere.
suppressPackageStartupMessages({ library(arrow); library(dplyr); library(cli) })

# V10 dir: da env V10_DIR, altrimenti l'ultima sotto simulomicsr-stage4-v10/.
V9 <- Sys.getenv("V10_DIR", "")
if (!nzchar(V9)) {
  cand <- sort(Sys.glob("/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/*-stage4-v10-*"), decreasing = TRUE)
  if (!length(cand)) stop("Nessuna dir re-pool v10 trovata: passare V10_DIR")
  V9 <- cand[[1]]
}
cli_alert_info("V10 re-pool dir: {V9}")
S3  <- "analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"   # v10
V8CSV <- "analysis/audit/2026-07-19-stage4-v9-remgroup-processed.csv"  # confronto vs v9 (161 rem_group)
OUT <- "analysis/audit/2026-07-20-stage4-v10-remgroup-processed.csv"

devtools::load_all(".", quiet = TRUE)
cl <- load_stage3(S3)$clusters

cp9 <- arrow::open_dataset(file.path(V9, "cluster_pooled.parquet"))

# ---- Per-method: quante meta-analisi (cluster distinti) + righe ------------
by_method <- cp9 %>% group_by(method) %>%
  summarise(n_rows = n(), .groups = "drop") %>% collect()
cl_by_method <- cp9 %>% select(cluster_id, method) %>% distinct() %>%
  group_by(method) %>% summarise(n_clusters = n(), .groups = "drop") %>% collect()
cli_h2("Meta-analisi poolate per method (v10)")
print(as.data.frame(left_join(cl_by_method, by_method, by = "method")))

# ---- rem_group: per-cluster n_sig, I2, tau2, k ----------------------------
rg <- cp9 %>% filter(method == "rem_group") %>%
  select(cluster_id, gene_id, I2, tau2, k_effective, FDR_BH_within_cluster) %>% collect()
proc_ids <- unique(rg$cluster_id)
cli_h2(sprintf("rem_group PROCESSATI v10: %d cluster (v9: 161)", length(proc_ids)))

per_cluster <- rg %>% group_by(cluster_id) %>%
  summarise(n_sig = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
            I2_med = round(median(I2, na.rm = TRUE), 1),
            tau2_med = round(median(tau2, na.rm = TRUE), 4),
            k_eff = round(median(k_effective, na.rm = TRUE)), .groups = "drop")

name_cols <- intersect(c("anchor_key","kind_effective_resolved","agent_id_resolved",
                         "canonical_name","recovery_source"), names(cl))
meta <- cl %>% filter(cluster_id %in% proc_ids) %>%
  select(cluster_id, all_of(name_cols)) %>% distinct()
joined <- per_cluster %>% left_join(meta, by = "cluster_id") %>% arrange(desc(n_sig))
write.csv(joined, OUT, row.names = FALSE)

# ---- Distribuzione I2 / k: v9 vs v8 (omogeneita' delle fusioni) ------------
cli_h2("Omogeneita' (I2_med) e potenza (k_eff) dei rem_group: v10 vs v9")
v8 <- tryCatch(read.csv(V8CSV, stringsAsFactors = FALSE), error = function(e) NULL)
qs <- function(x) round(quantile(x, c(0,.25,.5,.75,1), na.rm = TRUE), 1)
cat("v10 I2_med  quantili [0/25/50/75/100]:", paste(qs(joined$I2_med), collapse=" "), "\n")
if (!is.null(v8)) cat("v9  I2_med  quantili [0/25/50/75/100]:", paste(qs(v8$I2_med), collapse=" "), "\n")
cat("v10 k_eff   quantili [0/25/50/75/100]:", paste(qs(joined$k_eff), collapse=" "), "\n")
if (!is.null(v8) && "k_med" %in% names(v8)) cat("v9  k_med   quantili [0/25/50/75/100]:", paste(qs(v8$k_med), collapse=" "), "\n")
cat("v10 n_sig   totale:", sum(joined$n_sig), " | mediana per cluster:", round(median(joined$n_sig)), "\n")

# ---- Entita' note (le grandi fusioni): coerenza (I2) + potenza (k) ---------
cli_h2("Entita' note poolate v10: potenza (k) e omogeneita' (I2) delle fusioni")
notes <- c("MeSH:D001943"="breast", "MeSH:D011471"="prostate", "MeSH:D006528"="hepatocell",
           "MeSH:D015179"="colorectal", "NCBITaxon:2697049"="SARS-CoV-2",
           "NCBITaxon:1773"="M.tuberc", "CHEBI:16412"="LPS", "CHEBI:68534"="enzalutamide",
           "CHEBI:41774"="tamoxifen", "CHEBI:31638"="fulvestrant")
for (id in names(notes)) {
  s <- joined[!is.na(joined$agent_id_resolved) & joined$agent_id_resolved == id, , drop = FALSE]
  if (!nrow(s)) { cat(sprintf("  %-18s %-12s | (non tra i rem_group poolati)\n", id, notes[id])); next }
  cat(sprintf("  %-18s %-12s | n_cluster=%2d | k_eff=%3d-%3d | I2_med=%3.0f-%3.0f | n_sig(max)=%d\n",
      id, notes[id], nrow(s), min(s$k_eff), max(s$k_eff),
      min(s$I2_med), max(s$I2_med), max(s$n_sig)))
}

# ---- Bandiera attese (come v8) --------------------------------------------
flag_pat <- "D001943|D011471|2697049|68534|41774|31638|63637|D011471"
hay <- paste(joined$agent_id_resolved, joined$anchor_key)
cli_h2("BANDIERA presenti tra i rem_group v10")
fb <- joined[grepl(flag_pat, hay), c("cluster_id","agent_id_resolved","canonical_name","n_sig","I2_med","k_eff")]
print(as.data.frame(fb), row.names = FALSE)

cat("\nCSV:", OUT, "\n== FINE ==\n")
