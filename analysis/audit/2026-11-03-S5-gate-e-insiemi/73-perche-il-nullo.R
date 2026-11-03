#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/73-perche-il-nullo.R
# Perche' il controllo negativo ha piu' geni significativi dei gruppi veri? Ipotesi: nei gruppi dominati
# gli altri studi sono piccoli per definizione, quelli estratti a caso hanno una taglia qualunque.
# Misura: errore standard mediano degli studi non dominanti e peso dello studio dominante, vero e nullo.
# Uso: WORKERS=16 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/73-perche-il-nullo.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
piano <- fread(file.path(OUT5, "72-piano-estrazione.csv"))
ver <- fread(file.path(OUT5, "70-senza-dominante.csv"))[dominata_T1 == TRUE & sig > 0]
nu <- fread(file.path(OUT5, "72-nullo.csv"))
DIRS <- "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio"
ris <- rbindlist(mclapply(ver$cluster_id, function(g) {
  p <- piano[cluster_id == g]; dom <- p$dom[1]
  st <- readRDS(file.path(DIRS, paste0(g, ".rds")))
  al <- rbindlist(lapply(seq_len(nrow(p)), function(j) readRDS(file.path(DIRS, paste0(p$g_altro[j], ".rds")))[study_id == p$s_altro[j], .(study_id, se1)]))
  sd_d <- st[study_id == dom, median(se1, na.rm = TRUE)]
  se_v <- st[study_id != dom, .(m = median(se1, na.rm = TRUE)), by = study_id]$m
  se_n <- al[, .(m = median(se1, na.rm = TRUE)), by = study_id]$m
  q <- function(a, b) (1 / a^2) / (1 / a^2 + sum(1 / b^2))
  data.table(cluster_id = g, se_dom = sd_d, se_altri_v = median(se_v), se_altri_n = median(se_n), peso_dom_v = q(sd_d, se_v), peso_dom_n = q(sd_d, se_n))
}, mc.cores = WORKERS, mc.preschedule = FALSE))
fwrite(ris, file.path(OUT5, "73-perche-il-nullo.csv"))
rp <- ris$se_altri_n / ris$se_altri_v
s <- ic_mediana(rp)
cat(sprintf("errore standard mediano degli altri studi: veri %.3f, nulli %.3f; rapporto nullo/vero mediano %.2f [%.2f; %.2f]; gruppi con altri piu' precisi nel nullo: %d su %d\n", median(ris$se_altri_v), median(ris$se_altri_n), s["stima"], s["lo"], s["hi"], sum(rp < 1), nrow(ris)))
cat(sprintf("peso approssimato dello studio dominante (senza tau2): vero %.3f, nullo %.3f\n", median(ris$peso_dom_v), median(ris$peso_dom_n)))
m <- merge(ver[, .(cluster_id, sig_v = sig)], nu[, .(cluster_id, sig_n = sig)], by = "cluster_id")
m <- merge(m, ris, by = "cluster_id")
cat(sprintf("gruppi con piu' geni nel nullo: %d su %d; correlazione di Spearman fra rapporto dei geni e rapporto degli errori standard: %.2f\n", m[sig_n > sig_v, .N], nrow(m), m[, cor(sig_n / pmax(sig_v, 1), se_altri_n / se_altri_v, method = "spearman")]))
sim <- m[se_altri_n / se_altri_v >= 0.8 & se_altri_n / se_altri_v <= 1.25]
cat(sprintf("gruppi con altri studi di precisione simile (rapporto 0,8-1,25): %d; geni veri mediana %g, nulli %g\n", nrow(sim), median(sim$sig_v), median(sim$sig_n)))
