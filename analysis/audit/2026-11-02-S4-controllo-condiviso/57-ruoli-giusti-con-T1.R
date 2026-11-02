#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/57-ruoli-giusti-con-T1.R
# I tre bracci con i ruoli giusti E l'errore standard corretto (T1), insieme: il taglio cambia?
# Piu' i numeri delle 37 meta-analisi e delle quattro che entrano.
# Uso: Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/57-ruoli-giusti-con-T1.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
suppressPackageStartupMessages(library(dplyr))
B <- readRDS(file.path(PESANTI, "bracci.rds")); A <- B$A; strutture <- B$strutture
ris <- fread(file.path(OUT, "20-rifit-bracci.csv")); sb <- ris[ruoli_giusti_per_posizione == FALSE]
tab <- fread(file.path(OUT, "50-per-gruppo.csv"))
for (k in seq_len(nrow(sb))) {
  cid <- sb$cluster_id[k]; sid <- sb$study_id[k]; br <- sb$braccio[k]
  a <- A[cluster_id == cid & study_id == sid & braccio == br]
  x <- as.data.table(open_dataset(file.path(POOL, "per_study_de.parquet")) |> dplyr::filter(cluster_id == !!cid) |> dplyr::collect())
  asse <- asse_geni(); x[, pos := match(gene_id, asse)]
  x[, braccio := segna_bracci(pos, n_treated, n_control), by = study_id]
  tr <- strsplit(a$gsm_t, ",", fixed = TRUE)[[1]]; co <- strsplit(a$gsm_c, ",", fixed = TRUE)[[1]]
  m <- .fetch_counts_cached(sid, c(tr, co), h5_path = NULL, gene_biotype_filter = "protein_coding")
  st <- attr(m, "gene_symbol"); m <- m[, c(tr, co), drop = FALSE]; attr(m, "gene_symbol") <- st
  fr <- factor(c(rep("treated", length(tr)), rep("control", length(co))), levels = c("control", "treated"))
  f <- as.data.table(.run_limma_voom_de(m, fr, sid, cid, direction_flip = FALSE))
  iv <- x[study_id == sid & braccio == br, which = TRUE]; j <- match(x$gene_id[iv], f$gene_id)
  x$logFC[iv] <- f$logFC[j]; x$SE[iv] <- f$SE[j]
  st1 <- rbindlist(lapply(split(x, by = "study_id"), function(xs) {
    s <- strutture[[paste(cid, xs$study_id[1L], sep = "\r")]]
    br <- sort(unique(xs$braccio)); g <- sort(unique(xs$gene_id))
    D <- matrix(NA_real_, length(g), length(br)); S <- D
    D[cbind(match(xs$gene_id, g), match(xs$braccio, br))] <- xs$logFC
    S[cbind(match(xs$gene_id, g), match(xs$braccio, br))] <- xs$SE
    U <- 1 / S; U[is.na(U)] <- 0; D[is.na(D)] <- 0
    data.table(cluster_id = cid, study_id = xs$study_id[1L], gene_id = g,
               y = rowSums(D * U^2) / rowSums(U^2), se = sqrt(var_t1(U, s$R)))
  }))
  r <- rem_gruppo(st1[, .(gene_id, y, se)], cid)
  t2 <- r[FDR < 0.05, .(cluster_id, gene_id, tau2)]
  e <- as.data.table(compute_pooling_effectiveness(as.data.frame(st1[, .(cluster_id, gene_id, study_id, SE = se)]), as.data.frame(t2)))
  tt <- tab[cluster_id == cid]
  cat(sprintf("%-22s nei 113: %s | quota deliverable %.3f, solo T1 %.3f, T1 con ruoli giusti %.3f | geni %d, %d, %d | sotto 0,5: %s\n",
              substr(tt$nome, 1, 22), tt$in113, tt$q0, tt$q1, e$quota_top1, tt$sig0, tt$sig1, nrow(t2), e$quota_top1 <= .5))
}
t37 <- tab[in37_0 == TRUE][, rs := (sig1 - sig0) / pmax(sig0, 1)]
cat(sprintf("\nnelle 37: geni T0 %d, T1 %d (%.2f%%) | variazione per gruppo: mediana %.3f, minimo %.3f | gruppi oltre -10%%: %d | toccati: %d\n",
            sum(t37$sig0), sum(t37$sig1), 100 * (sum(t37$sig1) / sum(t37$sig0) - 1), median(t37$rs), min(t37$rs), sum(t37$rs < -.1), sum(t37$toccato)))
print(t37[order(rs)][1:5, .(nome = substr(nome, 1, 26), k, sig0, sig1, rs = round(rs, 3), q0 = round(q0, 3), q1 = round(q1, 3))])
n4 <- tab[in37_1 == TRUE & in37_0 == FALSE]
print(n4[, .(nome, cluster_id, k, dom0, sig0, sig1, sig3, kish0 = round(kish0, 2), kish1 = round(kish1, 2))])
