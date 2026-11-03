#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/48-doppi-effetto.R
# Quanto contano gli studi doppi. Due campioni sono lo stesso dato se la distanza L1 relativa e' sotto
# 0,001 (47-out.txt: 190 coppie sotto, nessuna fra 0,001 e 0,03). Due studi di un gruppo sono doppi se
# condividono cosi' almeno meta' dei campioni dello studio piu' piccolo. Di ogni componente resta lo
# studio con piu' campioni nel gruppo (a parita', il numero GSE piu' basso). I doppioni parziali
# restano dentro e si elencano. Stime con T1, stessa catena di 30-rem-k2.R.
# Uso: WORKERS=16 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/48-doppi-effetto.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
D <- readRDS(file.path(PES5, "dispatch-A3.rds"))
M <- readRDS(file.path(PES5, "quadro-194.rds"))
ten <- D$tenuti[cluster_id %in% c(M$cluster_id, D$candidati[k_eff == 2L, cluster_id])]
lung <- ten[, .(gsm = unique(unlist(strsplit(c(gsm_t, gsm_c), ",", fixed = TRUE)))), by = .(cluster_id, study_id)]
n_st <- lung[, .(n = uniqueN(gsm)), by = .(cluster_id, study_id)]
v <- fread(file.path(PES5, "coppie-campioni-vicine.csv"))[l1 < 0.001]
v[, `:=`(s1 = pmin(sa, sb), s2 = pmax(sa, sb))]
cop <- v[, .(uguali = min(uniqueN(ga), uniqueN(gb)), l1_max = max(l1)), by = .(cluster_id, s1, s2)]
cop <- merge(merge(cop, n_st, by.x = c("cluster_id", "s1"), by.y = c("cluster_id", "study_id")), n_st, by.x = c("cluster_id", "s2"), by.y = c("cluster_id", "study_id"), suffixes = c("1", "2"))
cop[, frazione := uguali / pmin(n1, n2)]
cop[, doppio := frazione >= 0.5]
togli <- function(x, ns) {
  st <- sort(unique(c(x$s1, x$s2))); comp <- setNames(seq_along(st), st)
  for (r in seq_len(nrow(x))) { a <- comp[x$s1[r]]; b <- comp[x$s2[r]]; comp[comp == max(a, b)] <- min(a, b) }
  unlist(lapply(split(names(comp), comp), function(s) {
    n <- ns[match(s, ns$study_id), n]; s[order(-n, s)][-1L]
  }), use.names = FALSE)
}
gruppi_d <- unique(cop[doppio == TRUE, cluster_id])
via <- rbindlist(lapply(gruppi_d, function(g) data.table(cluster_id = g, tolto = togli(cop[cluster_id == g & doppio == TRUE], n_st[cluster_id == g]))))
nomi <- rbind(M[, .(cluster_id, nome)], D$candidati[k_eff == 2L, .(cluster_id, nome = canonical_name)])
cop <- merge(cop, nomi, by = "cluster_id")
fwrite(cop, file.path(OUT5, "48-coppie-di-studi-doppie.csv"))
cat(sprintf("coppie di studi con campioni uguali: %d in %d gruppi; doppie (almeno meta'): %d in %d gruppi; parziali: %d in %d gruppi\n",
            nrow(cop), uniqueN(cop$cluster_id), cop[doppio == TRUE, .N], uniqueN(gruppi_d), cop[doppio == FALSE, .N], cop[doppio == FALSE, uniqueN(cluster_id)]))
print(cop[order(-doppio, -frazione), .(nome = substr(nome, 1, 30), s1, s2, uguali, n1, n2, frazione = round(frazione, 2), doppio, l1_max = signif(l1_max, 2))], nrows = 100)
cat(sprintf("gruppi: fra le 194 con doppi %d; fra i 282 %d\n", sum(gruppi_d %in% M$cluster_id), sum(!gruppi_d %in% M$cluster_id)))
# Effetto sulle 194
g194 <- intersect(gruppi_d, M$cluster_id)
DIRS <- "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio"
eff <- mclapply(g194, function(g) {
  st <- readRDS(file.path(DIRS, paste0(g, ".rds")))[!(study_id %in% via[cluster_id == g, tolto])]
  if (uniqueN(st$study_id) < 2L) return(data.table(cluster_id = g, k_senza = uniqueN(st$study_id), sig_senza = NA_integer_, q_senza = NA_real_, kish_senza = NA_real_, dom_senza = NA_character_, I2_senza = NA_real_))
  r <- rem_gruppo(st[, .(gene_id, y = d0, se = se1)], g)
  t2 <- r[!is.na(FDR) & FDR < 0.05, .(cluster_id, gene_id, tau2)]
  pa <- st[is.finite(se1) & se1 > 0, .(cluster_id, gene_id, study_id, SE = se1)]
  e <- if (nrow(t2)) as.data.table(compute_pooling_effectiveness(as.data.frame(pa), as.data.frame(t2))) else NULL
  data.table(cluster_id = g, k_senza = uniqueN(st$study_id), sig_senza = nrow(t2), q_senza = if (is.null(e)) NA_real_ else e$quota_top1, kish_senza = if (is.null(e)) NA_real_ else e$k_kish, dom_senza = if (is.null(e)) NA_character_ else e$studio_dominante, I2_senza = median(r$I2, na.rm = TRUE))
}, mc.cores = WORKERS, mc.preschedule = FALSE)
err <- vapply(eff, inherits, TRUE, "try-error")
if (any(err)) { print(g194[err]); print(eff[err]) }
eff <- rbindlist(eff[!err])
eff <- merge(M[, .(cluster_id, nome, k, q1, kish1, sig1, dom1, I2_med, in41, in173, in128, in113)], eff, by = "cluster_id")
eff[, tolti := vapply(cluster_id, function(g) paste(via[cluster_id == g, tolto], collapse = ","), "")]
eff[, in41_senza := in113 & k_senza >= 3L & !is.na(q_senza) & q_senza <= 0.5]
eff[, in173_senza := in173 & k_senza >= 3L]
fwrite(eff, file.path(OUT5, "48-effetto-sulle-194.csv"))
options(width = 250)
print(as.data.frame(eff[, .(nome = substr(nome, 1, 26), k, k_senza, q1 = round(q1, 3), q_senza = round(q_senza, 3), kish1 = round(kish1, 2), kish_senza = round(kish_senza, 2), sig1, sig_senza, in41, in41_senza, in173, in173_senza, tolti)]))
cat(sprintf("le 41 senza i doppi: %d | le 173 senza i doppi: %d\n", M[, sum(in41)] - eff[in41 == TRUE & in41_senza == FALSE, .N], M[, sum(in173)] - eff[in173 == TRUE & in173_senza == FALSE, .N]))
# Effetto sui 282
k2 <- fread(file.path(OUT5, "30-per-gruppo-k2.csv"))
kd <- via[cluster_id %in% k2$cluster_id, .(tolti = .N), by = cluster_id]
cat(sprintf("gruppi a due studi con doppi: %d, quindi con un solo studio vero; i 282 diventano %d\n", nrow(kd), nrow(k2) - nrow(kd)))
print(merge(kd, k2[, .(cluster_id, nome = substr(canonical_name, 1, 30), sig1, q1)], by = "cluster_id"))
fwrite(via, file.path(OUT5, "48-studi-da-togliere.csv"))
