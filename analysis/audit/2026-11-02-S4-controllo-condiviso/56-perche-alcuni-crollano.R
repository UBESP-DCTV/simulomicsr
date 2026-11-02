#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/56-perche-alcuni-crollano.R
# Due dubbi aperti durante il lavoro.
# (1) Perche' alcune meta-analisi perdono quasi tutti i geni significativi con T1, se l'errore
#     standard cresce del 20%. Ipotesi: le loro stime stanno appena sotto la soglia del FDR, e il
#     metodo di Benjamini-Hochberg dipende dal rango. Si guarda quanto cambia SE_pool e quanti
#     geni restano a FDR 0,10 e 0,20.
# (2) Quante righe la regola dei bracci di 2026-11-02-inversioni-194 metteva nel braccio sbagliato.
# Uso: Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/56-perche-alcuni-crollano.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
tab <- fread(file.path(OUT, "50-per-gruppo.csv"))
rap <- fread(file.path(OUT, "50-per-coppia.csv"))
d <- tab[toccato == TRUE & sig0 > 0]
d[, rs := (sig1 - sig0) / sig0]
quali <- d[rs < -0.2]
cat(sprintf("gruppi che perdono oltre il 20%% con T1: %d\n\n", nrow(quali)))
r0 <- as.data.table(read_parquet(file.path(PESANTI, "rem-T0.parquet")))[cluster_id %in% d$cluster_id]
r1 <- as.data.table(read_parquet(file.path(PESANTI, "rem-T1.parquet")))[cluster_id %in% d$cluster_id]
m <- merge(r0, r1, by = c("cluster_id", "gene_id"), suffixes = c("0", "1"))
per <- m[, .(geni = .N, se_rapp = median(SE_pool1 / SE_pool0), se_rapp_sig = median((SE_pool1 / SE_pool0)[FDR0 < .05]),
             z0 = median(abs(logFC_pool0 / SE_pool0)), z1 = median(abs(logFC_pool1 / SE_pool1)),
             s05_0 = sum(FDR0 < .05), s05_1 = sum(FDR1 < .05), s10_1 = sum(FDR1 < .10), s20_1 = sum(FDR1 < .20),
             fdr_min0 = min(FDR0), fdr_mediana_sig0 = median(FDR0[FDR0 < .05]),
             rho_lfc = cor(logFC_pool0, logFC_pool1, method = "spearman"),
             tau0 = median(tau20), tau1 = median(tau21)), by = cluster_id]
per <- merge(per, d[, .(cluster_id, nome, k, in113, q0, q1, dom0, rs)], by = "cluster_id")
dom <- rap[, .(cluster_id, dom0 = study_id, bracci = m, r1)]
per <- merge(per, dom, by = c("cluster_id", "dom0"), all.x = TRUE)
fwrite(per, file.path(OUT, "56-per-gruppo.csv"))
cat("gruppi che perdono oltre il 20%, ordinati:\n")
print(per[rs < -.2][order(rs)][, .(nome = substr(nome, 1, 26), k, in113, bracci_dom = bracci, se_dom = round(r1, 2),
   se_pool = round(se_rapp, 2), se_pool_sig = round(se_rapp_sig, 2), s05_0, s05_1, s10_1, s20_1, fdr_sig0 = signif(fdr_mediana_sig0, 2))], nrows = 40)
cat(sprintf("\nnei %d gruppi che crollano: SE_pool mediana sui geni significativi di T0, rapporto %.3f; FDR mediano dei loro significativi %.3f\n",
            nrow(quali), median(per[rs < -.2]$se_rapp_sig), median(per[rs < -.2]$fdr_mediana_sig0)))
cat(sprintf("negli altri %d: rapporto %.3f; FDR mediano %.3f\n", nrow(per[rs >= -.2]),
            median(per[rs >= -.2]$se_rapp_sig), median(per[rs >= -.2]$fdr_mediana_sig0)))
cat(sprintf("nei gruppi che crollano, geni a FDR<0,10 con T1 sopra il numero a FDR<0,05 con T0: %d su %d\n",
            per[rs < -.2, sum(s10_1 >= s05_0)], nrow(quali)))
cat(sprintf("Spearman fra i logFC poolati T0 e T1 nei gruppi che crollano: mediana %.3f, minimo %.3f\n",
            median(per[rs < -.2]$rho_lfc), min(per[rs < -.2]$rho_lfc)))

# --- (2) la regola dei bracci -------------------------------------------------
x <- as.data.table(read_parquet(file.path(POOL, "per_study_de.parquet"),
       col_select = c("cluster_id", "study_id", "gene_id", "n_treated", "n_control")))
x <- x[cluster_id %in% tab$cluster_id]
vecchia <- function(gene, nt, nc) {
  n <- length(gene); b <- integer(n); corrente <- 1L; i <- 1L
  cambio <- c(FALSE, nt[-1L] != nt[-n] | nc[-1L] != nc[-n])
  while (i <= n) {
    fine <- n; tratto <- i:n
    dup <- duplicated(gene[tratto]) | (cambio[tratto] & tratto != i)
    if (any(dup)) fine <- tratto[which(dup)[1L]] - 1L
    b[i:fine] <- corrente; corrente <- corrente + 1L; i <- fine + 1L
  }
  b
}
asse <- asse_geni(); x[, pos := match(gene_id, asse)]
x[, nuova := segna_bracci(pos, n_treated, n_control), by = .(cluster_id, study_id)]
x[, antica := vecchia(gene_id, n_treated, n_control), by = .(cluster_id, study_id)]
dif <- x[nuova != antica]
cat(sprintf("\nregola dei bracci: righe in un braccio diverso %d su %d | bracci toccati %d | coppie %d | bracci in tutto: %d e %d\n",
            nrow(dif), nrow(x), uniqueN(dif, by = c("cluster_id", "study_id", "nuova")),
            uniqueN(dif, by = c("cluster_id", "study_id")),
            uniqueN(x, by = c("cluster_id", "study_id", "nuova")), uniqueN(x, by = c("cluster_id", "study_id", "antica"))))
