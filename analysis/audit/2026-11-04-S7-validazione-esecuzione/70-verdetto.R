#!/usr/bin/env Rscript
# Passo B, punti 7, 8, 10 del disegno. Si esegue solo dopo il commit del passo A.
# POOL_DIR sceglie il deliverable: lo stesso codice si riesegue dopo le correzioni (§2 del disegno).
source("analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R")
suppressPackageStartupMessages(library(arrow))
x <- readRDS(file.path(PES7, "firme.rds")); Fo <- x$fondo; Fe <- x$entita; pm <- x$pm; ent <- x$ent; land <- x$land
cat("deliverable:", POOL, "\n")
stopifnot(pm[insieme == "40", .N] == 19L, pm[insieme == "132", .N] == 53L)
ci <- fread(file.path(LIN, "compoundinfo_beta.txt"), sep = "\t", quote = "", colClasses = "character")
ci[moa %in% c('""', ""), moa := NA_character_]
# ---- l'interrogazione: logFC_pool / SE_pool sui landmark
ids <- land$ensembl_id
g <- as.data.table(read_parquet(file.path(POOL, "cluster_pooled.parquet"), col_select = c("cluster_id","gene_id","method","logFC_pool","SE_pool")))
g <- g[cluster_id %in% pm$cluster_id]; g[, id := sub("[.].*", "", gene_id)]; g <- g[id %in% ids]
stopifnot(all(g$method == "rem_group"), !anyDuplicated(g, by = c("cluster_id","id")))
g[, q := logFC_pool / SE_pool]; cat("q non finite:", sum(!is.finite(g$q)), "\n"); g[!is.finite(q), q := NA_real_]
mappa <- setNames(land$gene_id, land$ensembl_id); g[, entrez := mappa[id]]
Qs <- lapply(split(g, by = "cluster_id"), function(d) setNames(d$q, d$entrez))
pm[, geni := vapply(cluster_id, function(cc) sum(!is.na(Qs[[cc]])), 0L)]
cat("landmark per gruppo, minimo e mediana:\n"); print(pm[, .(min = min(geni), mediana = median(geni)), keyby = insieme])
# ---- rango di tutte le coppie (interrogazione, composto)
pert <- split(ent$pert_id, ent$contrast_entity)
s_f <- list(); s_e <- list()
t0 <- Sys.time()
for (i in seq_len(nrow(pm))) { q <- Qs[[pm$cluster_id[i]]]; s_f[[i]] <- sim_q(q, Fo); s_e[[i]] <- sim_q(q, Fe) }
cat("similarita':", format(Sys.time() - t0), "\n")
names(s_f) <- names(s_e) <- pm$contrast_entity
pe <- function(e, c) { via <- union(pert[[e]], pert[[c]]); rango_p(s_e[[e]][c], s_f[[e]][setdiff(colnames(Fo), via)]) }
pm[, P := vapply(contrast_entity, function(e) pe(e, e), 0)]
pm[, successo := P >= 0.90]
# moa
mo <- lapply(pert, function(p) unique(na.omit(ci[pert_id %in% p, moa])))
coppie <- CJ(e = pm$contrast_entity, c = pm$contrast_entity)[e != c]
coppie[, comune := mapply(function(a, b) length(intersect(mo[[a]], mo[[b]])) > 0L || length(intersect(pert[[a]], pert[[b]])) > 0L, e, c)]
cat("coppie sbagliate:", nrow(coppie), "; tolte per moa o pert_id in comune:", sum(coppie$comune), "\n")
cs <- coppie[comune == FALSE]; cs[, P := mapply(pe, e, c)]; cs[, succ := P >= 0.90]
sc <- cs[, .(H_scambio_e = mean(succ), coppie = .N), by = .(contrast_entity = e)]
pm <- merge(pm, sc, by = "contrast_entity")
pm[, d_e := as.numeric(successo) - H_scambio_e]
# ---- verdetto per insieme
verdetto <- function(d, nome, T_) {
  n <- nrow(d); xx <- sum(d$successo); H <- xx / n; hs <- mean(d$H_scambio_e * 1) ; hs2 <- sum(d$H_scambio_e * d$coppie) / sum(d$coppie)
  Teff <- max(T_, hs2); lo <- cp_lim(xx, n, "lo"); hi <- cp_lim(xx, n, "hi")
  set.seed(SEME); b <- replicate(BOOT, { i <- sample(n, replace = TRUE); c(mean(d$d_e[i]), median(d$P[i]), sum(d$H_scambio_e[i] * d$coppie[i]) / sum(d$coppie[i])) })
  ic_d <- quantile(b[1, ], c(.025, .975)); ic_m <- quantile(b[2, ], c(.025, .975)); ic_s <- quantile(b[3, ], c(.025, .975))
  data.table(insieme = nome, n = n, successi = xx, H = H, H_lo = lo, H_hi = hi, H_scambio = hs2, H_scambio_lo = ic_s[1], H_scambio_hi = ic_s[2], T = T_, T_eff = Teff,
             diff = H - hs2, diff_lo = ic_d[1], diff_hi = ic_d[2], mediana_P = median(d$P), mediana_lo = ic_m[1], mediana_hi = ic_m[2], passa = lo > Teff && ic_d[1] > 0)
}
V <- rbind(verdetto(pm[insieme == "40"], "19 (nelle 40)", 0.17), verdetto(pm[insieme == "132"], "53 (nelle 132)", 0.17))
cat("\nVERDETTO\n"); print(as.data.frame(V), digits = 3); fwrite(V, file.path(E7, "70-verdetto.csv"))
cat("\nOGNI P_e\n"); print(as.data.frame(pm[order(insieme, -P), .(nome, insieme, k, metodo_match, geni, P = round(P, 3), successo, H_scambio_e = round(H_scambio_e, 3))]), right = FALSE)
fwrite(pm[order(insieme, -P), .(contrast_entity, cluster_id, nome, insieme, k, metodo_match, pert_id, geni, P, successo, H_scambio_e, coppie)], file.path(E7, "70-P-per-metanalisi.csv"))
fwrite(cs[, .(e, c, P)], file.path(E7, "70-coppie-scambio.csv"))
cat("\nCANCELLO 3: landmark minimo", pm[insieme %in% c("40","132"), min(geni)], "(serve almeno 800); coperti", pm[insieme == "40", .N], "su 19 e", pm[insieme == "132", .N], "su 53\n")
# ---- controlli dello strumento, sullo stesso percorso di codice
# positivo: la firma giusta usata come interrogazione deve stare in cima. Negativo: la q con i geni rimescolati deve dare il caso.
auto <- vapply(pm$contrast_entity, function(e) { q <- Fe[, e]; rango_p(cor(q, Fe[, e], method = "spearman"), sim_q(q, Fo[, setdiff(colnames(Fo), pert[[e]]), drop = FALSE])) }, 0)
cat("\nstrumento, firma contro se stessa: quota nel primo 10% =", mean(auto >= .9), "\n")
set.seed(SEME); per <- vapply(seq_len(nrow(pm)), function(i) { q <- Qs[[pm$cluster_id[i]]]; names(q) <- sample(names(q)); e <- pm$contrast_entity[i]; rango_p(sim_q(q, Fe[, e, drop = FALSE]), sim_q(q, Fo[, setdiff(colnames(Fo), pert[[e]]), drop = FALSE])) }, 0)
cat("strumento, geni rimescolati: H =", round(mean(per >= .9), 3), "su", length(per), "; mediana P =", round(median(per), 3), "\n")
# ---- punto 8: sensibilita'
sens <- function(d, etichetta) { rbindlist(lapply(c("40","132"), function(s) { z <- d[insieme == s]; xx <- sum(z$P >= .9); data.table(sensibilita = etichetta, insieme = s, n = nrow(z), successi = xx, H = xx / nrow(z), lo = cp_lim(xx, nrow(z), "lo"), hi = cp_lim(xx, nrow(z), "hi"), mediana_P = median(z$P)) })) }
S <- list(sens(pm, "primaria"), sens(pm[metodo_match == "struttura_inchikey_completo"], "solo InChIKey completo"))
gr <- fread(file.path(S6, "65-out.txt"), sep = "\n", header = FALSE)
S[[length(S) + 1L]] <- sens(pm[!grepl("estradiol", nome)], "senza lettere greche (65-out.txt)")
# qc_pass: filtro su firme ed entita', regola di misurabilita' riapplicata
M <- readRDS(file.path(PES7, "z-landmark-cp.rds")); da <- readRDS(file.path(PES7, "firme-attive-cp.rds"))
dq <- da[qc_pass == "1"]; fq <- dq[, .(l = uniqueN(cell_iname)), by = pert_id][l >= 3L, pert_id]; cat("\nqc_pass: composti del fondo", length(fq), "; firme", dq[pert_id %in% fq, .N], "\n")
Fq <- firme_per_gruppo(M, dq[pert_id %in% fq, .(sig_id, gruppo = pert_id, cell_iname)])
sq <- merge(ent, dq[, .(sig_id, pert_id, cell_iname)], by = "pert_id", allow.cartesian = TRUE)
lq <- sq[, .(l = uniqueN(cell_iname)), by = contrast_entity][l >= 3L]
Feq <- firme_per_gruppo(M, sq[contrast_entity %in% lq$contrast_entity, .(sig_id, gruppo = contrast_entity, cell_iname)])
pq <- pm[contrast_entity %in% colnames(Feq)]
pq[, P := vapply(seq_len(.N), function(i) { q <- Qs[[cluster_id[i]]]; e <- contrast_entity[i]; rango_p(sim_q(q, Feq[, e, drop = FALSE]), sim_q(q, Fq[, setdiff(colnames(Fq), pert[[e]]), drop = FALSE])) }, 0)]
S[[length(S) + 1L]] <- sens(pq, "qc_pass == 1")
# molecole doppie unite
dop <- ent[, .(ent = list(contrast_entity), n = .N), by = pert_id][n > 1L]; print(dop)
u <- copy(pm); u[, unita := contrast_entity]
for (i in seq_len(nrow(dop))) u[contrast_entity %in% dop$ent[[i]], unita := dop$ent[[i]][1]]
uu <- u[, .(P = mean(P), insieme = if ("40" %in% insieme) "40" else if ("132" %in% insieme) "132" else "fuori", membri = paste(nome, collapse = " + ")), by = unita]
print(uu[grepl("[+]", membri)])
S[[length(S) + 1L]] <- sens(uu, "molecole doppie unite")
S <- rbindlist(S); cat("\nSENSIBILITA'\n"); print(as.data.frame(S), digits = 3); fwrite(S, file.path(E7, "70-sensibilita.csv"))
# ---- punto 10: verdetti della rilettura
i <- unique(rbind(fread(file.path(S5, "80-insieme-40.csv"))[, .(cluster_id, verdetto)], fread(file.path(S5, "80-insieme-172.csv"))[, .(cluster_id, verdetto)]), by = "cluster_id")
vv <- merge(pm, i, by = "cluster_id", all.x = TRUE); vv[, gruppo := fifelse(verdetto == "corretta", "corretta", "difettosa o incerta")]
R <- vv[insieme %in% c("40","132"), .(n = .N, successi = sum(successo), H = mean(successo), mediana_P = median(P)), keyby = .(insieme, gruppo)]
R[, lo := mapply(cp_lim, successi, n, "lo")]; R[, hi := mapply(cp_lim, successi, n, "hi")]
cat("\nVERDETTI DELLA RILETTURA\n"); print(as.data.frame(R), digits = 3); fwrite(R, file.path(E7, "70-verdetti-rilettura.csv"))
saveRDS(list(pm = pm, Qs = Qs, pert = pert), file.path(PES7, "verdetto.rds"))
