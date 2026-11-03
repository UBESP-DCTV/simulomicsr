#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/46-doppi-nelle-conte.R
# Stesso campione con due GSM: conte identiche, gene per gene, sull'intero asse dei geni.
# Vede anche i doppioni parziali, che la correlazione delle stime non vede. Non vede due corse di
# sequenziamento diverse della stessa libreria. Controllo positivo: le tre coppie con correlazione 1.
# Legge dall'H5 per studio, non scrive nella cache.
# Uso: WORKERS=16 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/46-doppi-nelle-conte.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
D <- readRDS(file.path(PES5, "dispatch-A3.rds"))
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
gr <- c(d$cluster_id, D$candidati[k_eff == 2L, cluster_id])
ten <- D$tenuti[cluster_id %in% gr]
lung <- ten[, .(gsm = unique(unlist(strsplit(c(gsm_t, gsm_c), ",", fixed = TRUE)))), by = .(cluster_id, study_id)]
per_studio <- lung[, .(gsm = unique(gsm)), by = study_id]
studi <- unique(per_studio$study_id)
cat(sprintf("gruppi %d, studi %d, campioni %d\n", length(gr), length(studi), uniqueN(per_studio$gsm)))
invisible(.fetch_counts_from_h5(studi[1], per_studio[study_id == studi[1], gsm], H5, gene_biotype_filter = "protein_coding")); rhdf5::h5closeAll()
t0 <- Sys.time()
ris <- mclapply(studi, function(s) {
  g <- per_studio[study_id == s, gsm]
  m <- .fetch_counts_from_h5(s, g, H5, gene_biotype_filter = "protein_coding")
  data.table(study_id = s, gsm = colnames(m), somma = colSums(m), impronta = apply(m, 2L, digest::digest, algo = "xxhash64"))
}, mc.cores = WORKERS, mc.preschedule = FALSE)
err <- vapply(ris, inherits, TRUE, "try-error"); cat("errori di lettura:", sum(err), "\n"); if (any(err)) print(ris[[which(err)[1]]])
imp <- rbindlist(ris[!err])
cat(sprintf("%d campioni letti in %.1f min\n", nrow(imp), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
fwrite(imp, file.path(PES5, "impronte-campioni.csv"))
imp <- imp[somma > 0]
# uno stesso GSM in due studi e' un caso diverso da due GSM con la stessa impronta
stessi <- imp[, .(n_gsm = uniqueN(gsm), n_studi = uniqueN(study_id)), by = impronta][n_studi > 1L]
cat(sprintf("impronte condivise fra studi diversi: %d (con GSM diversi: %d)\n", nrow(stessi), stessi[n_gsm > 1L, .N]))
cop <- imp[impronta %in% stessi$impronta][, {
  u <- unique(.SD[, .(study_id, gsm)])
  if (uniqueN(u$study_id) < 2L) NULL else as.data.table(t(utils::combn(sort(unique(u$study_id)), 2L)))
}, by = impronta]
setnames(cop, c("V1", "V2"), c("a", "b"))
coppie <- cop[, .(camp_uguali = .N), by = .(a, b)]
# dentro quali gruppi stanno insieme, e quanta parte dei campioni usati nel gruppo e' doppia
n_usati <- lung[, .(n = uniqueN(gsm)), by = .(cluster_id, study_id)]
g_in <- merge(n_usati, n_usati, by = "cluster_id", allow.cartesian = TRUE, suffixes = c(".a", ".b"))[study_id.a < study_id.b]
imp_g <- merge(lung, imp[, .(study_id, gsm, impronta)], by = c("study_id", "gsm"))
r <- merge(g_in, coppie, by.x = c("study_id.a", "study_id.b"), by.y = c("a", "b"))
r[, uguali_nel_gruppo := mapply(function(g, a, b) {
  length(intersect(imp_g[cluster_id == g & study_id == a, impronta], imp_g[cluster_id == g & study_id == b, impronta]))
}, cluster_id, study_id.a, study_id.b)]
r <- r[uguali_nel_gruppo > 0L]
M <- readRDS(file.path(PES5, "quadro-194.rds"))
r <- merge(r, M[, .(cluster_id, nome, k, q1, dom1, in41, in173, in113)], by = "cluster_id", all.x = TRUE)
r[, fonte := fifelse(is.na(nome), "k2", "194")]
r[, frazione := uguali_nel_gruppo / pmin(n.a, n.b)]
kk <- D$candidati[, .(cluster_id, canonical_name)]
r <- merge(r, kk, by = "cluster_id", all.x = TRUE)
fwrite(r, file.path(OUT5, "46-doppi-per-gruppo.csv"))
cat(sprintf("\ncoppie (gruppo, due studi) con campioni identici: %d in %d gruppi | nelle 194: %d gruppi | nelle 173: %d | nelle 113: %d | nelle 41: %d | a due studi: %d\n",
            nrow(r), uniqueN(r$cluster_id), r[fonte == "194", uniqueN(cluster_id)], r[in173 == TRUE, uniqueN(cluster_id)], r[in113 == TRUE, uniqueN(cluster_id)], r[in41 == TRUE, uniqueN(cluster_id)], r[fonte == "k2", uniqueN(cluster_id)]))
print(r[order(fonte, -in41, -in113, -in173, -frazione), .(fonte, nome = substr(fifelse(is.na(nome), canonical_name, nome), 1, 32), k, q1 = round(q1, 3), dom1, in41, a = study_id.a, b = study_id.b, uguali = uguali_nel_gruppo, n.a, n.b, frazione = round(frazione, 2))], nrows = 200)
cat("\nCONTROLLO POSITIVO: le tre coppie con correlazione 1\n")
for (p in list(c("GSE154613", "GSE159522"), c("GSE108743", "GSE89725"), c("GSE156038", "GSE222279"))) cat(p, ":", r[study_id.a == sort(p)[1] & study_id.b == sort(p)[2], paste(uguali_nel_gruppo, "su", pmin(n.a, n.b))], "\n")
