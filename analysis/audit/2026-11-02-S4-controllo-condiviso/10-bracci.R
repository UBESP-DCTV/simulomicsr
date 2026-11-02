#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/10-bracci.R
# Conta i bracci che condividono campioni e costruisce rho e componenti per ogni coppia
# (gruppo, studio). Solo misura: non cambia nessuna stima.
# Uso: Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/10-bracci.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")

d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
stopifnot(nrow(d) == 194L)
A <- as.data.table(readRDS(file.path(RIL, "dispatch-A3.rds"))$tenuti)
A[, braccio := seq_len(.N), by = .(cluster_id, study_id)]
stopifnot(nrow(A) == 1903L, setequal(A$cluster_id, d$cluster_id))
corsie <- leggi_corsie()
cat(sprintf("campioni nel registro delle corsie: %d in %d librerie\n", length(corsie), length(unique(corsie))))

# controllo sulla formula chiusa: m bracci uguali, stesso controllo
local({
  n <- 3L; m <- 4L; C <- paste0("c", 1:n)
  TT <- lapply(1:m, function(k) paste0("t", k, "_", 1:n)); CC <- rep(list(C), m)
  s <- struttura_coppia(TT, CC)
  stopifnot(all(abs(s$R[upper.tri(s$R)] - 0.5) < 1e-12), all(s$comp == 1L))
  S <- 0.7; U <- matrix(1 / S, 2, m)  # sigma^2 (1/n + 1/n) = S^2
  sigma2 <- S^2 / (2 / n)
  stopifnot(all(abs(var_t1(U, s$R) - sigma2 * (1 / (m * n) + 1 / n)) < 1e-10))
  cat("formula chiusa: scarto < 1e-10\n")
})

TT <- lapply(strsplit(A$gsm_t, ",", fixed = TRUE), librerie, corsie)
CC <- lapply(strsplit(A$gsm_c, ",", fixed = TRUE), librerie, corsie)
stopifnot(all(lengths(TT) == A$n_t), all(lengths(CC) == A$n_c))
stopifnot(!any(mapply(function(a, b) length(intersect(a, b)) > 0L, TT, CC)))
cat("librerie contate = n_t e n_c del dispatch, in 1.903 bracci su 1.903; nessun conflitto dentro un braccio\n")

indici <- split(seq_len(nrow(A)), paste(A$cluster_id, A$study_id, sep = "\r"))
strutture <- lapply(indici, function(ii) struttura_coppia(TT[ii], CC[ii]))
# --- tabella per braccio ---------------------------------------------------
A[, `:=`(rho_max = 0, cc = FALSE, tt = FALSE, opposti = FALSE, componente = 1L)]
for (k in names(indici)) {
  ii <- indici[[k]]; s <- strutture[[k]]; m <- length(ii)
  A$componente[ii] <- s$comp
  if (m == 1L) next
  for (a in seq_len(m)) {
    alt <- setdiff(seq_len(m), a)
    A$rho_max[ii[a]] <- max(abs(s$R[a, alt]))
    A$cc[ii[a]] <- any(vapply(alt, function(b) length(intersect(CC[[ii[a]]], CC[[ii[b]]])) > 0L, TRUE))
    A$tt[ii[a]] <- any(vapply(alt, function(b) length(intersect(TT[[ii[a]]], TT[[ii[b]]])) > 0L, TRUE))
    A$opposti[ii[a]] <- any(vapply(alt, function(b)
      length(intersect(TT[[ii[a]]], CC[[ii[b]]])) > 0L || length(intersect(CC[[ii[a]]], TT[[ii[b]]])) > 0L, TRUE))
  }
}
A[, condivide := cc | tt | opposti]
saveRDS(list(A = A, TT = TT, CC = CC, indici = indici, strutture = strutture, corsie = corsie),
        file.path(PESANTI, "bracci.rds"))
fwrite(A[, .(cluster_id, study_id, braccio, n_t, n_c, condivide, cc, tt, opposti, rho_max, componente)],
       file.path(OUT, "10-bracci.csv"))

multi <- A[, .(m = .N, m_cond = sum(condivide), ncomp = uniqueN(componente),
               rho_med = if (any(condivide)) median(rho_max[condivide]) else NA_real_),
           by = .(cluster_id, study_id)]
fwrite(multi, file.path(OUT, "10-coppie.csv"))

cat("\n=== IL CONTEGGIO ===\n")
cat(sprintf("bracci: %d | coppie (gruppo, studio): %d | coppie con piu' bracci: %d, con %d bracci\n",
            nrow(A), nrow(multi), sum(multi$m > 1), sum(multi$m[multi$m > 1])))
cat(sprintf("P1  bracci che condividono almeno un campione: %d su %d (%.1f%%)\n",
            sum(A$condivide), sum(multi$m[multi$m > 1]), 100 * sum(A$condivide) / sum(multi$m[multi$m > 1])))
cat(sprintf("    stesso controllo (C con C): %d | stesso trattato (T con T): %d | ruolo opposto (T con C): %d\n",
            sum(A$cc), sum(A$tt), sum(A$opposti)))
cat(sprintf("    coppie con condivisione: %d | studi: %d | gruppi: %d su 194\n",
            sum(multi$m_cond > 0), uniqueN(multi[m_cond > 0]$study_id), uniqueN(multi[m_cond > 0]$cluster_id)))
cat(sprintf("    rho massimo per braccio: mediana %.2f, IQR %.2f-%.2f, massimo %.2f\n",
            median(A$rho_max[A$condivide]), quantile(A$rho_max[A$condivide], .25),
            quantile(A$rho_max[A$condivide], .75), max(A$rho_max[A$condivide])))
cat(sprintf("    bracci per coppia con condivisione: mediana %.0f, massimo %d\n",
            median(multi[m_cond > 0]$m), max(multi[m_cond > 0]$m)))
cat(sprintf("    componenti da fondere (2+ bracci): %d, con %d bracci; coppie con ruoli opposti: %d\n",
            A[, .N, by = .(cluster_id, study_id, componente)][N > 1, .N],
            A[, .N, by = .(cluster_id, study_id, componente)][N > 1, sum(N)],
            sum(vapply(strutture, function(s) s$coppie_ruolo_opposto > 0L, TRUE))))

# read.csv come C2-controllo-condiviso.R: fread legge «True» come logico e il confronto cade
v <- as.data.table(utils::read.csv(file.path(RIL, "verdetti-194.csv"), stringsAsFactors = FALSE))
sel113 <- v[n_studi_difettosi == 0 & verdetto_finale == "corretta" & etichetta_non_chiude != "True", cluster_id]
stopifnot(length(sel113) == 113L)
grp <- unique(multi[m_cond > 0]$cluster_id)
d[, dom := multi[m_cond > 0, paste(cluster_id, study_id)][match(paste(cluster_id, studio_dominante),
                                                               multi[m_cond > 0, paste(cluster_id, study_id)])]]
d[, dom_condivide := !is.na(dom)]
q113 <- d[cluster_id %in% sel113]
cat("\n=== NEI 113 ===\n")
cat(sprintf("gruppi dei 113 con almeno una coppia con condivisione: %d | col dominante che condivide: %d\n",
            sum(q113$cluster_id %in% grp), sum(q113$dom_condivide)))
cat(sprintf("gia' dentro i 37: %d | fuori dai 37 col dominante che condivide: %d\n",
            sum(q113$quota_top1 <= .5 & q113$cluster_id %in% grp, na.rm = TRUE),
            sum(q113$quota_top1 > .5 & q113$dom_condivide, na.rm = TRUE)))
vic <- q113[quota_top1 > .5 & quota_top1 <= .6][order(quota_top1)]
cat("sul confine, quota in (0,50; 0,60]:\n")
for (i in seq_len(nrow(vic))) cat(sprintf("  %.3f  %-34s dominante %-11s condivide=%s\n", vic$quota_top1[i],
    substr(vic$contrast_entity_label[i], 1, 34), vic$studio_dominante[i], vic$dom_condivide[i]))
