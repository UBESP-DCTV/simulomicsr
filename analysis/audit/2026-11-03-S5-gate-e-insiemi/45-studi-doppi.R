#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/45-studi-doppi.R
# Anomalia trovata dalla previsione P2: GSE154613 e GSE159522 in amlodipine danno stime identiche.
# Due numeri GEO per gli stessi dati valgono uno studio, non due. Si misura su TUTTE le coppie di
# studi di tutti i gruppi: le 194 e i 282 a due studi. Due segnali indipendenti:
#  - campioni in comune (stesso GSM in piu' studi dello stesso gruppo);
#  - stime quasi identiche (correlazione dei logFC per studio >= 0,999 sui geni comuni).
# Non attese: e' un'anomalia, non una previsione. Lo strumento non vede i doppioni parziali in cui i
# campioni hanno GSM diversi e gli altri bracci diluiscono la correlazione.
# Uso: WORKERS=16 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/45-studi-doppi.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
D <- readRDS(file.path(PES5, "dispatch-A3.rds"))
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
k2 <- D$candidati[k_eff == 2L]
gruppi <- rbind(data.table(cluster_id = d$cluster_id, fonte = "194", dir = "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio"),
                data.table(cluster_id = k2$cluster_id, fonte = "k2", dir = file.path(PES5, "studio-k2")))
ten <- D$tenuti[cluster_id %in% gruppi$cluster_id]
lavoro <- function(i) {
  g <- gruppi$cluster_id[i]
  st <- readRDS(file.path(gruppi$dir[i], paste0(g, ".rds")))
  w <- dcast(st[is.finite(d0)], gene_id ~ study_id, value.var = "d0")
  s <- setdiff(names(w), "gene_id")
  if (length(s) < 2L) return(NULL)
  mat <- as.matrix(w[, ..s])
  tg <- ten[cluster_id == g]
  cam <- lapply(setNames(s, s), function(x) unique(unlist(strsplit(c(tg[study_id == x, gsm_t], tg[study_id == x, gsm_c]), ",", fixed = TRUE))))
  cc <- suppressWarnings(cor(mat, use = "pairwise.complete.obs"))
  co <- t(utils::combn(length(s), 2L))
  rbindlist(lapply(seq_len(nrow(co)), function(r) {
    a <- co[r, 1]; b <- co[r, 2]
    data.table(cluster_id = g, fonte = gruppi$fonte[i], a = s[a], b = s[b], cor_d = cc[a, b],
               comuni = length(intersect(cam[[a]], cam[[b]])), na = length(cam[[a]]), nb = length(cam[[b]]))
  }))
}
ris <- rbindlist(mclapply(seq_len(nrow(gruppi)), lavoro, mc.cores = WORKERS, mc.preschedule = FALSE))
fwrite(ris, file.path(OUT5, "45-coppie-di-studi.csv"))
cat(sprintf("coppie di studi: %d in %d gruppi\n", nrow(ris), uniqueN(ris$cluster_id)))
dup <- ris[comuni > 0L | cor_d >= 0.999]
dup[, tipo := fcase(comuni > 0L & cor_d >= 0.999, "campioni in comune e stime identiche", comuni > 0L, "campioni in comune", default = "stime identiche, campioni diversi")]
print(dup[, .(coppie = .N, gruppi = uniqueN(cluster_id)), by = .(fonte, tipo)][order(fonte, tipo)])
M <- readRDS(file.path(PES5, "quadro-194.rds"))
dup <- merge(dup, M[, .(cluster_id, nome, k, q1, in41, in173, in113)], by = "cluster_id", all.x = TRUE)
cat("\nnelle 194: gruppi toccati", dup[fonte == "194", uniqueN(cluster_id)], "| nelle 173:", dup[in173 == TRUE, uniqueN(cluster_id)], "| nelle 113:", dup[in113 == TRUE, uniqueN(cluster_id)], "| nelle 41:", dup[in41 == TRUE, uniqueN(cluster_id)], "\n")
print(dup[fonte == "194"][order(-in41, -in113, -in173, k), .(nome, k, q1, in41, in173, a, b, cor_d = round(cor_d, 4), comuni, na, nb)], nrows = 200)
cat("\ngruppi a due studi toccati:", dup[fonte == "k2", uniqueN(cluster_id)], "su", gruppi[fonte == "k2", .N], "\n")
k <- merge(dup[fonte == "k2"], k2[, .(cluster_id, canonical_name)], by = "cluster_id")
print(k[order(-cor_d), .(canonical_name = substr(canonical_name, 1, 35), a, b, cor_d = round(cor_d, 4), comuni, na, nb)], nrows = 60)
cat("\nDistribuzione della correlazione fra studi diversi senza campioni in comune (per vedere il confine):\n")
print(ris[comuni == 0L, quantile(cor_d, c(.5, .9, .99, .999, 1), na.rm = TRUE)])
print(ris[comuni == 0L & cor_d >= 0.9][order(-cor_d)][1:min(.N, 15), .(cluster_id, a, b, cor_d = round(cor_d, 4))])
