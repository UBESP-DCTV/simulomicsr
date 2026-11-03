#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/50-insiemi.R
# Cancello 4 e i due insiemi: le 41 (dalla misura sul controllo condiviso) e le 173.
# Il retest serve a dire quanto si muovono gli insiemi con una seconda lettura.
# Uso: Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/50-insiemi.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
Q <- fread(file.path(RIL, "B4-quadro-influenza.csv"))
v <- fread(file.path(RIL, "verdetti-194.csv"))
s4 <- fread("analysis/audit/2026-11-02-S4-controllo-condiviso/50-per-gruppo.csv")
rt <- fread("analysis/audit/2026-08-21-S3-test-retest/verdetti-retest2.csv")
stopifnot(nrow(Q) == 194L, nrow(v) == 194L, nrow(s4) == 194L, nrow(rt) == 194L)
M <- merge(d[, .(cluster_id, nome = contrast_entity_label, k = k_effective, I2_med, tau2_med, sig0 = n_sig, q0 = quota_top1, kish0 = k_kish)],
           Q[, .(cluster_id, n_accusati = n_studi_accusati, verdetto, k_ridotto, sopravvive, peso_contaminato, percentile_sig, percentile_spearman, percentile_delta)], by = "cluster_id")
M <- merge(M, v[, .(cluster_id, chiude = !as.logical(etichetta_non_chiude))], by = "cluster_id")
M <- merge(M, s4[, .(cluster_id, q1, kish1, dom1, sig1, in37_1)], by = "cluster_id")
M <- merge(M, rt[, .(cluster_id, verdetto_rt = verdetto_finale, n_dif_rt = n_studi_difettosi, chiude_rt = !as.logical(etichetta_non_chiude))], by = "cluster_id")
cat("=== CANCELLO 4: il setaccio, dai file\n")
a <- rep(TRUE, nrow(M)); passi <- integer()
a <- a & M$n_accusati == 0L; passi["nessun difetto"] <- sum(a); s128 <- a
a <- a & M$verdetto == "corretta"; passi["verdetto corretta"] <- sum(a)
a <- a & M$chiude; passi["etichetta chiude"] <- sum(a); s113 <- a
s37 <- s113 & !is.na(M$q0) & M$q0 <= 0.5 & M$kish0 >= 2
s41 <- s113 & !is.na(M$q1) & M$q1 <= 0.5
print(c(tutte = nrow(M), passi, T0 = sum(s37), T1 = sum(s41)))
cat(sprintf("le 41 coincidono con in37_1: %s\n", identical(sort(M$cluster_id[s41]), sort(M$cluster_id[M$in37_1]))))
s45 <- M$n_accusati > 0L & !is.na(M$k_ridotto) & M$k_ridotto >= 3L
s173 <- s128 | s45
cat(sprintf("128 + 45 = %d + %d = %d; le 41 stanno nelle 173: %s; le 37 stanno nelle 41: %s\n", sum(s128), sum(s45), sum(s173), all(s173[s41]), all(s41[s37])))
M[, `:=`(in41 = s41, in37 = s37, in173 = s173, in128 = s128, in113 = s113)]

# Avvisi noti, dai finding sulle inversioni e sul controllo condiviso
avvisi <- list(
  list("Carcinoma, Hepatocellular", "GSE144269 ha i bracci invertiti: gruppo non citabile finché non è corretto"),
  list("hepatitis B virus", "GSE93153 ha un braccio sbagliato"),
  list("vtp50469", "GSE186709 ha un braccio sbagliato"),
  list("lipopolysaccharide", "GSE168468 ha un braccio sbagliato"),
  list("Parkinson Disease", "GSE208347 ha un braccio sbagliato e i ruoli sbagliati (peso sotto 1%)"),
  list("R1881 (metribolone)", "GSE222992 ha i ruoli sbagliati nel deliverable"),
  list("endometriosis", "GSE135485 ha i ruoli sbagliati nel deliverable"),
  list("IL22", "il difetto sposta il risultato oltre il caso, su tre statistiche"),
  list("obese", "il difetto sposta il risultato oltre il caso, su tre statistiche"),
  list("sals", "il difetto sposta il risultato oltre il caso, su tre statistiche"))
M[, avviso := ""]
for (z in avvisi) { stopifnot(M[nome == z[[1]], .N] == 1L); M[nome == z[[1]], avviso := z[[2]]] }
M[, perdita_sig := fifelse(sig0 > 0, 1 - sig1 / sig0, NA_real_)]
M[, dominata_T1 := !is.na(q1) & q1 > 0.5]
col <- c("nome", "k", "kish1", "q1", "dom1", "sig0", "sig1", "perdita_sig", "I2_med", "tau2_med", "verdetto", "verdetto_rt", "n_accusati", "n_dif_rt", "k_ridotto", "peso_contaminato", "dominata_T1", "in37", "in41", "in128", "avviso", "cluster_id")
fwrite(M[in41 == TRUE][order(-k, -sig1), ..col], file.path(OUT5, "50-insieme-41.csv"))
fwrite(M[in173 == TRUE][order(-in41, -k, -sig1), ..col], file.path(OUT5, "50-insieme-173.csv"))
scheda <- function(x, nome) {
  cat(sprintf("\n--- %s: %d meta-analisi\n", nome, nrow(x)))
  cat(sprintf("k: mediana %g, minimo %d, massimo %d; a k=3: %d, a k=3-4: %d, a k>=10: %d\n", median(x$k), min(x$k), max(x$k), sum(x$k == 3), sum(x$k <= 4), sum(x$k >= 10)))
  cat(sprintf("geni significativi T1: mediana %g, totale %d, con meno di 100: %d, zero: %d\n", median(x$sig1), sum(x$sig1), sum(x$sig1 < 100), sum(x$sig1 == 0)))
  cat(sprintf("I2 mediano %.1f; k_kish T1 mediano %.2f; quota_top1 T1 mediana %.3f\n", median(x$I2_med), median(x$kish1, na.rm = TRUE), median(x$q1, na.rm = TRUE)))
  cat(sprintf("dominate T1 (q1>0,5): %d; k_kish T1 < 2: %d; con difetti: %d; verdetti: %s\n", sum(x$dominata_T1), sum(x$kish1 < 2, na.rm = TRUE), sum(x$n_accusati > 0), paste(names(table(x$verdetto)), table(x$verdetto), collapse = ", ")))
  cat(sprintf("retest: %s\n", paste(names(table(x$verdetto_rt)), table(x$verdetto_rt), collapse = ", ")))
  cat(sprintf("avvisi: %s\n", paste(x[avviso != "", nome], collapse = "; ")))
  cat(sprintf("perdono oltre il 20%% dei geni con T1: %d (%s)\n", sum(x$perdita_sig > 0.2, na.rm = TRUE), paste(x[perdita_sig > 0.2, sprintf("%s %d->%d", nome, sig0, sig1)], collapse = "; ")))
}
scheda(M[in41 == TRUE], "le 41"); scheda(M[in173 == TRUE], "le 173"); scheda(M[in173 == TRUE & in41 == FALSE], "le 132 delle 173 fuori dalle 41")
cat("\n=== Perché le 132 stanno fuori dalle 41 (primo criterio che non passano)\n")
x <- M[in173 == TRUE & in41 == FALSE]
x[, motivo := fcase(n_accusati > 0L, "contiene difetti", verdetto != "corretta", "verdetto incerta", !chiude, "etichetta non chiude", default = "un solo studio sopra il 50% del peso")]
print(x[, .N, by = motivo][order(-N)])
y <- M[in173 == TRUE & n_accusati > 0L]
cat(sprintf("le 45: peso contaminato mediana %.1f%%, massimo %.1f%%, sopra il 25%%: %d\n", median(y$peso_contaminato), max(y$peso_contaminato), sum(y$peso_contaminato > 25)))
z <- M[in128 == TRUE]
cat(sprintf("le 128 con T1: dominate %d (%.0f%%), k_kish<2 %d (%.0f%%), misura mancante %d\n", sum(z$dominata_T1), 100 * mean(z$dominata_T1), sum(z$kish1 < 2, na.rm = TRUE), 100 * mean(z$kish1 < 2, na.rm = TRUE), sum(is.na(z$q1))))
cat("\n=== Il gate a 2 sui due insiemi\n")
fuori <- M[n_accusati > 0L & (is.na(k_ridotto) | k_ridotto < 3L)]
cat(sprintf("gruppi che escono togliendo i difetti: %d; a k_ridotto=2: %d; con k_ridotto mancante: %d\n", nrow(fuori), sum(fuori$k_ridotto == 2L, na.rm = TRUE), sum(is.na(fuori$k_ridotto))))
cat(sprintf("con il gate a 2 le 173 diventano %d, e restano senza lettura i gruppi nuovi\n", sum(s173) + sum(fuori$k_ridotto == 2L, na.rm = TRUE)))
cat("\n=== Una seconda lettura (retest): come si muovono i due insiemi\n")
M[, `:=`(s128_rt = n_dif_rt == 0L)]
M[, s113_rt := s128_rt & verdetto_rt == "corretta" & chiude_rt]
M[, s41_rt := s113_rt & !is.na(q1) & q1 <= 0.5]
M[, s173_rt := s128_rt | (n_dif_rt > 0L & (k - n_dif_rt) >= 3L)]
cat(sprintf("128 -> %d | 113 -> %d | 41 -> %d (restano %d, escono %d, entrano %d) | 173 -> %d (restano %d, escono %d, entrano %d)\n",
            M[, sum(s128_rt)], M[, sum(s113_rt)], M[, sum(s41_rt)], M[in41 & s41_rt, .N], M[in41 & !s41_rt, .N], M[!in41 & s41_rt, .N],
            M[, sum(s173_rt)], M[in173 & s173_rt, .N], M[in173 & !s173_rt, .N], M[!in173 & s173_rt, .N]))
cat("escono dalle 41:", paste(M[in41 & !s41_rt, sprintf("%s (%s, %d difetti)", nome, verdetto_rt, n_dif_rt)], collapse = "; "), "\n")
cat("entrano nelle 41:", paste(M[!in41 & s41_rt, nome], collapse = "; "), "\n")
cat(sprintf("salti corretta <-> difettosa sulle 194: %d; dentro le 41: %d; dentro le 173: %d\n",
            M[(verdetto == "corretta" & verdetto_rt == "difettosa") | (verdetto == "difettosa" & verdetto_rt == "corretta"), .N],
            M[in41 & verdetto_rt == "difettosa", .N],
            M[in173 & ((verdetto == "corretta" & verdetto_rt == "difettosa") | (verdetto == "difettosa" & verdetto_rt == "corretta")), .N]))
saveRDS(M, file.path(PES5, "quadro-194.rds"))
