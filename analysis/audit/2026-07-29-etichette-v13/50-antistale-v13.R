#!/usr/bin/env Rscript
# 50-antistale-v13.R --- verifica ANTI-STALE del re-pool v13.
# Non si fida del log: legge i file prodotti.
#
# 1. Methods contiene SOLO rem_group (ADR-0026: mega/mega_aug/rem fuori)
# 2. i cluster_id iniziano tutti con cgroup_L5_ (ADR-0025)
# 3. ~191 cluster poolati, e sono ESATTAMENTE quelli previsti (insiemi)
# 4. k_effective mai maggiore di k (il collasso dei bracci puo' solo ridurlo)
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(arrow); library(dplyr) })

OUT <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
cp <- arrow::open_dataset(file.path(OUT, "cluster_pooled.parquet"))
cat("colonne di cluster_pooled:", paste(names(cp), collapse = ", "), "\n\n")

tot <- cp %>% summarise(n = n()) %>% collect()
cat("righe totali:", tot$n, "\n")

cat("\n--- 1. METHODS ---\n")
me <- cp %>% count(method) %>% collect()
print(as.data.frame(me), row.names = FALSE)
cat("SOLO rem_group:", identical(sort(me$method), "rem_group"), "\n")

cat("\n--- 2. PREFISSO DEI CLUSTER_ID ---\n")
cids <- cp %>% distinct(cluster_id) %>% collect()
cat("cluster distinti poolati:", nrow(cids), "\n")
cat("tutti cgroup_L5_:", all(startsWith(cids$cluster_id, "cgroup_L5_")), "\n")
if (!all(startsWith(cids$cluster_id, "cgroup_L5_")))
  print(head(cids$cluster_id[!startsWith(cids$cluster_id, "cgroup_L5_")], 10))

cat("\n--- 3. SONO ESATTAMENTE I 191 PREVISTI? ---\n")
prev <- read.csv("analysis/audit/2026-07-29-etichette-v13/keff-atteso.csv",
                 stringsAsFactors = FALSE)
att <- sort(prev$cluster_id[prev$superato]); got <- sort(cids$cluster_id)
cat("previsti:", length(att), " poolati:", length(got), "\n")
cat("insiemi identici:", setequal(att, got), "\n")
if (!setequal(att, got)) {
  cat("poolati ma non previsti:", paste(setdiff(got, att), collapse = ", "), "\n")
  cat("previsti ma non poolati:", paste(setdiff(att, got), collapse = ", "), "\n")
}

cat("\n--- 4. k_effective MAI MAGGIORE DI k ---\n")
kcol <- intersect(c("k_effective", "k_eff", "k"), names(cp))
cat("colonne di k presenti:", paste(kcol, collapse = ", "), "\n")
ke <- cp %>% select(cluster_id, all_of(kcol)) %>% distinct() %>% collect()
ke <- merge(ke, prev[, c("cluster_id", "k_censito", "k_eff")], by = "cluster_id")
if ("k_effective" %in% names(ke)) {
  cat("k_effective > k censito:", sum(ke$k_effective > ke$k_censito), "casi\n")
  cat("k_effective > k_eff previsto:", sum(ke$k_effective > ke$k_eff), "casi\n")
  cat("k_effective == k_eff previsto:", sum(ke$k_effective == ke$k_eff), "su", nrow(ke), "\n")
  cat("somma k_effective:", sum(ke$k_effective), " (prevista:", sum(ke$k_eff), ")\n")
  print(summary(ke$k_effective))
  bad <- ke[ke$k_effective > ke$k_censito, ]
  if (nrow(bad)) print(head(bad, 10), row.names = FALSE)
}

cat("\n--- non_processable ---\n")
np <- readRDS(file.path(OUT, "non_processable.rds"))
cat("righe:", nrow(np), "\n")
print(table(sub(":.*$", "", np$reason)))

cat("\n--- eterogeneita' (esiste davvero?) ---\n")
if ("I2" %in% names(cp)) {
  i2 <- cp %>% filter(!is.na(I2)) %>% summarise(n = n()) %>% collect()
  cat("righe con I2 non NA:", i2$n, "su", tot$n, "\n")
}
if ("tau2" %in% names(cp)) {
  t2 <- cp %>% filter(!is.na(tau2)) %>% summarise(n = n()) %>% collect()
  cat("righe con tau2 non NA:", t2$n, "\n")
}
