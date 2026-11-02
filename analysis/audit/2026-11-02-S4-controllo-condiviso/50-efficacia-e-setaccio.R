#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/50-efficacia-e-setaccio.R
# Cancello 2 (riproduzione del deliverable) e previsioni P2-P9.
# Peso e quota_top1 vengono da compute_pooling_effectiveness(), la funzione di produzione.
# Uso: WORKERS=32 Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/50-efficacia-e-setaccio.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
library(parallel)
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
B <- readRDS(file.path(PESANTI, "bracci.rds")); A <- B$A
DIR <- file.path(PESANTI, "studio")
gruppi <- sort(d$cluster_id)
coppie <- fread(file.path(OUT, "10-coppie.csv"))
toccati <- unique(coppie[m_cond > 0, cluster_id])
rem <- lapply(c(T0 = "T0", T1 = "T1", T2 = "T2", T3 = "T3"), function(tn)
  as.data.table(read_parquet(file.path(PESANTI, paste0("rem-", tn, ".parquet")))))

# --- Cancello 2: riproduzione ------------------------------------------------
vero <- as.data.table(read_parquet(file.path(POOL, "cluster_pooled.parquet"),
  col_select = c("cluster_id", "gene_id", "logFC_pool", "SE_pool", "tau2", "FDR_BH_within_cluster", "k_effective")))
vero <- vero[cluster_id %in% gruppi]
m <- merge(vero, rem$T0, by = c("cluster_id", "gene_id"), all = TRUE, suffixes = c(".v", ".m"))
cat("=== CANCELLO 2 ===\n")
cat(sprintf("righe del deliverable sulle 194: %d | mie: %d | senza abbinamento: %d\n",
            nrow(vero), nrow(rem$T0), sum(is.na(m$logFC_pool.v) | is.na(m$logFC_pool.m))))
cat(sprintf("gruppi: %d | scarto massimo logFC %.3g, SE %.3g, tau2 %.3g, FDR %.3g, k %d\n",
            uniqueN(rem$T0$cluster_id),
            max(abs(m$logFC_pool.v - m$logFC_pool.m)), max(abs(m$SE_pool.v - m$SE_pool.m)),
            max(abs(m$tau2.v - m$tau2.m)), max(abs(m$FDR_BH_within_cluster - m$FDR)),
            max(abs(m$k_effective.v - m$k_effective.m))))
cat(sprintf("righe con scarto > 1e-6 su logFC, SE, tau2 o FDR: %d, in %d gruppi\n",
            m[abs(logFC_pool.v - logFC_pool.m) > 1e-6 | abs(SE_pool.v - SE_pool.m) > 1e-6 |
                abs(tau2.v - tau2.m) > 1e-6 | abs(FDR_BH_within_cluster - FDR) > 1e-6, .N],
            m[abs(logFC_pool.v - logFC_pool.m) > 1e-6 | abs(SE_pool.v - SE_pool.m) > 1e-6 |
                abs(tau2.v - tau2.m) > 1e-6 | abs(FDR_BH_within_cluster - FDR) > 1e-6, uniqueN(cluster_id)]))
rm(m, vero); gc()

# --- Efficacia per trattamento ---------------------------------------------
efficacia <- function(colonna_se, tn_rem, solo_toccati = FALSE) {
  gs <- if (solo_toccati) toccati else gruppi
  r <- mclapply(gs, function(g) {
    st <- readRDS(file.path(DIR, paste0(g, ".rds")))
    pa <- st[is.finite(get(colonna_se)) & get(colonna_se) > 0,
             .(cluster_id, gene_id, study_id, SE = get(colonna_se))]
    t2 <- rem[[tn_rem]][cluster_id == g & !is.na(FDR) & FDR < 0.05, .(cluster_id, gene_id, tau2)]
    if (nrow(t2) == 0L) return(NULL)
    as.data.table(compute_pooling_effectiveness(as.data.frame(pa), as.data.frame(t2)))
  }, mc.cores = WORKERS, mc.preschedule = FALSE)
  err <- vapply(r, inherits, TRUE, "try-error"); if (any(err)) stop(r[[which(err)[1]]])
  rbindlist(r)
}
e0 <- efficacia("se0", "T0")
j <- match(d$cluster_id, e0$cluster_id)
dq <- abs(d$quota_top1 - e0$quota_top1[j]); dk <- abs(d$k_kish - e0$k_kish[j])
cat(sprintf("quota_top1: scarto massimo %.3g | k_kish: %.3g | gruppi senza misura: deliverable %d, miei %d\n",
            max(dq, na.rm = TRUE), max(dk, na.rm = TRUE), sum(is.na(d$quota_top1)), sum(is.na(e0$quota_top1[j]))))
e1 <- efficacia("se1", "T1", TRUE); e2 <- efficacia("se2", "T2", TRUE); e3 <- efficacia("se3", "T3", TRUE)
ep <- efficacia("se1", "T0", TRUE)  # T1-pesi: SE corretti, tau2 e geni del deliverable

tab <- data.table(cluster_id = d$cluster_id, nome = d$contrast_entity_label, k = d$k_effective,
                  q0 = e0$quota_top1[j], kish0 = e0$k_kish[j], dom0 = e0$studio_dominante[j], sig0 = d$n_sig)
aggiungi <- function(tab, e, suf) {
  ii <- match(tab$cluster_id, e$cluster_id)
  tab[[paste0("q", suf)]] <- ifelse(tab$cluster_id %in% toccati, e$quota_top1[ii], tab$q0)
  tab[[paste0("kish", suf)]] <- ifelse(tab$cluster_id %in% toccati, e$k_kish[ii], tab$kish0)
  tab[[paste0("dom", suf)]] <- ifelse(tab$cluster_id %in% toccati, e$studio_dominante[ii], tab$dom0)
  tab
}
tab <- aggiungi(tab, e1, "1"); tab <- aggiungi(tab, e2, "2"); tab <- aggiungi(tab, e3, "3"); tab <- aggiungi(tab, ep, "p")
nsig <- function(tn) rem[[tn]][, .(s = sum(FDR < 0.05, na.rm = TRUE), I2 = median(I2, na.rm = TRUE), tau2 = median(tau2, na.rm = TRUE)), by = cluster_id]
for (tn in c("T1", "T2", "T3")) {
  ns <- nsig(tn); ii <- match(tab$cluster_id, ns$cluster_id)
  tab[[paste0("sig", sub("T", "", tn))]] <- ifelse(tab$cluster_id %in% toccati, ns$s[ii], tab$sig0)
}
v <- as.data.table(utils::read.csv(file.path(RIL, "verdetti-194.csv"), stringsAsFactors = FALSE))
sel113 <- v[n_studi_difettosi == 0 & verdetto_finale == "corretta" & etichetta_non_chiude != "True", cluster_id]
stopifnot(length(sel113) == 113L)
tab[, in113 := cluster_id %in% sel113]
tab[, toccato := cluster_id %in% toccati]
tab[, dom0_condivide := paste(cluster_id, dom0) %in% coppie[m_cond > 0, paste(cluster_id, study_id)]]
for (s in c("0", "1", "2", "3", "p")) tab[[paste0("in37_", s)]] <- tab$in113 & !is.na(tab[[paste0("q", s)]]) & tab[[paste0("q", s)]] <= 0.5
fwrite(tab, file.path(OUT, "50-per-gruppo.csv"))

conta <- function(s, kish = FALSE) {
  x <- tab[[paste0("in37_", s)]]
  if (kish) x <- x & !is.na(tab[[paste0("kish", s)]]) & tab[[paste0("kish", s)]] >= 2
  sum(x)
}
cat("\n=== IL TAGLIO, 113 -> M ===\n")
cat(sprintf("T0 %d (con kish>=2: %d) | T1 %d (%d) | T1-pesi %d | T2 %d (%d) | T3 %d (%d)\n",
            conta("0"), conta("0", TRUE), conta("1"), conta("1", TRUE), conta("p"), conta("2"), conta("2", TRUE), conta("3"), conta("3", TRUE)))
stampa <- function(s, cosa) {
  a <- if (cosa == "entrano") tab[!in37_0 & get(paste0("in37_", s))] else tab[in37_0 & !get(paste0("in37_", s))]
  cat(sprintf("%s con %s: %d\n", cosa, s, nrow(a)))
  for (i in seq_len(nrow(a))) cat(sprintf("  %-34s k=%2d  quota %.3f -> %.3f  kish %.2f -> %.2f  geni %d -> %d\n",
    substr(a$nome[i], 1, 34), a$k[i], a$q0[i], a[[paste0("q", s)]][i], a$kish0[i], a[[paste0("kish", s)]][i], a$sig0[i],
    if (s == "p") a$sig0[i] else a[[paste0("sig", s)]][i]))
}
for (s in c("1", "3", "2")) { stampa(s, "entrano"); stampa(s, "escono") }
cat(sprintf("\nsu tutte le 194: dominate (quota > 0,5) T0 %d | T1 %d | T3 %d | senza misura T0 %d, T1 %d, T3 %d\n",
            sum(tab$q0 > .5, na.rm = TRUE), sum(tab$q1 > .5, na.rm = TRUE), sum(tab$q3 > .5, na.rm = TRUE),
            sum(is.na(tab$q0)), sum(is.na(tab$q1)), sum(is.na(tab$q3))))
cat(sprintf("gruppi non toccati con quota cambiata: %d\n", tab[toccato == FALSE & abs(q1 - q0) > 0, .N]))

# --- Previsioni --------------------------------------------------------------
set.seed(SEME); BB <- 2000L
ic_med <- function(x) { x <- x[is.finite(x)]; b <- replicate(BB, median(sample(x, replace = TRUE))); c(stima = median(x), quantile(b, c(.025, .975)), n = length(x)) }
stampa_p <- function(nome, q, lo, hi, attesa) {
  verdetto <- if (q[2] >= lo && q[3] <= hi) "confermata" else if (q[3] < lo || q[2] > hi) "smentita" else "indeterminata"
  cat(sprintf("%-4s stima %.3f [IC95 %.3f; %.3f] n=%d | attesa %s, intervallo [%s; %s] -> %s\n", nome, q[1], q[2], q[3], q[4], attesa, lo, hi, verdetto))
}
cat("\n=== PREVISIONI ===\n")
rap <- rbindlist(mclapply(coppie[m_cond > 0, unique(cluster_id)], function(g) {
  st <- readRDS(file.path(DIR, paste0(g, ".rds")))
  cc <- coppie[cluster_id == g & m_cond > 0, study_id]
  st[study_id %in% cc, .(r1 = median(se1 / se0, na.rm = TRUE), r1max = max(se1 / se0, na.rm = TRUE),
                         r3 = median(se3 / se1, na.rm = TRUE), r2 = median(se2 / se1, na.rm = TRUE),
                         dmed = median(abs(d3 - d0), na.rm = TRUE)), by = .(cluster_id, study_id)]
}, mc.cores = WORKERS))
rap <- merge(rap, coppie, by = c("cluster_id", "study_id"))
fwrite(rap, file.path(OUT, "50-per-coppia.csv"))
stampa_p("P2", ic_med(rap$r1), 1.10, 1.35, "1,20")
cat(sprintf("     rapporto SE T1/T0: massimo %.2f, coppie sopra 1,5: %d su %d | per numero di bracci:\n", max(rap$r1max), sum(rap$r1 > 1.5), nrow(rap)))
print(rap[, .(coppie = .N, rapporto = round(median(r1), 2)), keyby = .(bracci = cut(m, c(1, 2, 3, 5, 10, 30)))])
tq <- tab[in113 == TRUE & dom0_condivide == TRUE]
stampa_p("P3", ic_med(tq$q1 - tq$q0), -0.08, -0.01, "-0,04")
cat(sprintf("P4   M(T1) = %d | attesa 44, intervallo [39; 49] -> %s\n", conta("1"), if (conta("1") >= 39 && conta("1") <= 49) "confermata" else "smentita"))
ts <- tab[toccato == TRUE & sig0 > 0]
stampa_p("P5", ic_med((ts$sig1 - ts$sig0) / ts$sig0), -0.15, -0.03, "-0,08")
cat(sprintf("     geni significativi, somma sulle 194: T0 %d | T1 %d | T2 %d | T3 %d\n", sum(tab$sig0), sum(tab$sig1), sum(tab$sig2), sum(tab$sig3)))
usciti <- tab[in37_0 & !in37_1, .N]
cat(sprintf("P6   uscite dai 37 con T1 = %d | attesa 1, intervallo [0; 3] -> %s\n", usciti, if (usciti <= 3) "confermata" else "smentita"))
d7 <- conta("3") - conta("1"); d9 <- abs(conta("2") - conta("1"))
cat(sprintf("P7   M(T3) - M(T1) = %+d | attesa +1, intervallo [-3; +5] -> %s\n", d7, if (d7 >= -3 && d7 <= 5) "confermata" else "smentita"))
stampa_p("P8", ic_med(rap$r3), 1.00, 1.30, "1,10")
cat(sprintf("P9   |M(T2) - M(T1)| = %d | attesa 1, intervallo [0; 3] -> %s\n", d9, if (d9 <= 3) "confermata" else "smentita"))
cat(sprintf("     mediana SE T2/T1: %.3f\n", median(rap$r2, na.rm = TRUE)))
dq1 <- tab[in113 == TRUE, q1 - q0]; dp <- tab[in113 == TRUE, qp - q0]
cat(sprintf("\ni due canali, sui 113: mediana di quota T1-pesi meno T0 %.3f | T1 meno T0 %.3f\n", median(dp, na.rm = TRUE), median(dq1, na.rm = TRUE)))
