#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/80-tavole.R
# Le tavole dei due insiemi per il file delle opzioni: entita', k, geni significativi e che cosa va
# dichiarato accanto a ciascuna. Dati: quadro-194 (50), doppi (48), controllo appaiato (74).
# Uso: Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/80-tavole.R
suppressPackageStartupMessages(library(data.table))
OUT5 <- "analysis/audit/2026-11-03-S5-gate-e-insiemi"
PES5 <- "/mnt/micron/simulomicsr-dati/2026-11-03-S5-gate-e-insiemi"
M <- readRDS(file.path(PES5, "quadro-194.rds"))
ef <- fread(file.path(OUT5, "48-effetto-sulle-194.csv"))
nu <- fread(file.path(OUT5, "74-nullo-appaiato.csv"))
M <- merge(M, ef[, .(cluster_id, k_senza, sig_senza, q_senza, in41_senza, in173_senza, tolti)], by = "cluster_id", all.x = TRUE)
M <- merge(M, nu[, .(cluster_id, rapporto_nullo = rapporto, sig_nullo = sig_n)], by = "cluster_id", all.x = TRUE)
M[, in40 := in41 == TRUE & (is.na(in41_senza) | in41_senza == TRUE)]
M[, in172 := in173 == TRUE & (is.na(in173_senza) | in173_senza == TRUE)]
cat(sprintf("40: %d | 172: %d | fuori dalle 40 nelle 172: %d\n", M[, sum(in40)], M[, sum(in172)], M[in172 == TRUE & in40 == FALSE, .N]))
dich <- function(x) {
  v <- character()
  if (isTRUE(x$sig1 == 0L)) v <- c(v, "nessun gene significativo")
  if (isTRUE(x$dominata_T1)) v <- c(v, sprintf("un solo studio porta il %.0f%% del peso", 100 * x$q1))
  if (isTRUE(x$kish1 < 2)) v <- c(v, gsub(".", ",", sprintf("vale %.2f studi efficaci", x$kish1), fixed = TRUE))
  if (x$n_accusati > 0L) v <- c(v, sprintf("%d %s, %.0f%% del peso", x$n_accusati, if (x$n_accusati == 1L) "studio difettoso" else "studi difettosi", x$peso_contaminato))
  if (x$verdetto == "incerta") v <- c(v, "verdetto incerta")
  if (x$verdetto == "corretta" && !isTRUE(x$chiude)) v <- c(v, "l'etichetta non chiude il verdetto")
  if (x$verdetto_rt != x$verdetto) v <- c(v, sprintf("alla seconda lettura: %s", x$verdetto_rt))
  if (isTRUE(x$sig0 > 0) && isTRUE(x$perdita_sig > 0.2)) v <- c(v, sprintf("geni da %d a %d con l'errore standard corretto", x$sig0, x$sig1))
  if (!is.na(x$tolti) && nzchar(x$tolti)) v <- c(v, sprintf("studi doppi da togliere: %s (k=%d, geni %d)", gsub(",", ", ", x$tolti), x$k_senza, x$sig_senza))
  if (nzchar(x$avviso)) v <- c(v, x$avviso)
  if (!length(v)) "nessun avviso" else paste(v, collapse = "; ")
}
M[, dichiara := vapply(seq_len(nrow(M)), function(i) dich(M[i]), "")]
col <- c("nome", "k", "sig1", "q1", "kish1", "I2_med", "rapporto_nullo", "verdetto", "verdetto_rt", "n_accusati", "peso_contaminato", "in40", "dominata_T1", "dichiara", "cluster_id")
fwrite(M[in40 == TRUE][order(-k, -sig1), ..col], file.path(OUT5, "80-insieme-40.csv"))
fwrite(M[in172 == TRUE][order(-in40, -k, -sig1), ..col], file.path(OUT5, "80-insieme-172.csv"))
num <- function(v, d) if (is.na(v)) "n.d." else gsub(".", ",", sprintf(paste0("%.", d, "f"), v), fixed = TRUE)
riga <- function(x) sprintf("| %s | %d | %s | %s | %s | %s | %s |", gsub("|", "/", x$nome, fixed = TRUE), x$k, format(x$sig1, big.mark = ".", decimal.mark = ",", trim = TRUE), num(x$q1, 2), num(x$kish1, 2), num(x$I2_med, 0), x$dichiara)
scrivi <- function(x, f) {
  testa <- c("| meta-analisi | k | geni | primo studio | studi efficaci | I² | che cosa dichiarare |", "|---|---:|---:|---:|---:|---:|---|")
  righe <- vapply(seq_len(nrow(x)), function(i) riga(x[i]), "")
  writeLines(c(testa, righe), f)
}
scrivi(M[in40 == TRUE][order(-k, -sig1)], file.path(OUT5, "80-tavola-40.md"))
scrivi(M[in172 == TRUE & in40 == FALSE][order(-k, -sig1)], file.path(OUT5, "80-tavola-132.md"))
k2 <- fread(file.path(OUT5, "30-per-gruppo-k2.csv"))
via <- fread(file.path(OUT5, "48-studi-da-togliere.csv"))
k2[, un_solo_studio_vero := cluster_id %in% via$cluster_id]
inc <- fread(file.path(OUT5, "40-per-gruppo.csv"))[fonte == "k2", .(cluster_id, ampiezza_I2, tau0_sig, kh_nsig, pi_esclude0)]
k2 <- merge(k2, inc, by = "cluster_id", all.x = TRUE)
fwrite(k2[order(-sig1)], file.path(OUT5, "80-gruppi-a-due-studi.csv"))
cat("k censito dei 282:\n"); print(k2[, .N, keyby = .(censito = pmin(k_censito, 6L))])
cat(sprintf("gruppi a due studi: %d; un solo studio vero: %d; veri: %d; senza geni significativi fra i veri: %d; nome mancante: %d\n", nrow(k2), k2[un_solo_studio_vero == TRUE, .N], k2[un_solo_studio_vero == FALSE, .N], k2[un_solo_studio_vero == FALSE & sig1 == 0, .N], k2[is.na(canonical_name) | canonical_name == "", .N]))
cat(sprintf("le 132: dominate %d, con difetti %d, verdetto incerta senza difetti %d, geni zero %d\n", M[in172 & !in40 & dominata_T1 == TRUE, .N], M[in172 & !in40 & n_accusati > 0, .N], M[in172 & !in40 & n_accusati == 0 & verdetto == "incerta", .N], M[in172 & !in40 & sig1 == 0, .N]))
cat(sprintf("le 40: k mediana %g; a k=3 %d; k>=10 %d; geni mediana %g; primo studio mediana %.3f; I2 mediana %.1f; studi efficaci mediana %.2f; seconda lettura corretta %d, incerta %d\n", M[in40 == TRUE, median(k)], M[in40 == TRUE & k == 3, .N], M[in40 == TRUE & k >= 10, .N], M[in40 == TRUE, median(sig1)], M[in40 == TRUE, median(q1)], M[in40 == TRUE, median(I2_med)], M[in40 == TRUE, median(kish1)], M[in40 == TRUE & verdetto_rt == "corretta", .N], M[in40 == TRUE & verdetto_rt == "incerta", .N]))
cat("grandi fuori dalle 40:\n"); print(warnings())
print(as.data.frame(M[in40 == FALSE & k >= 15][order(-k), .(nome, k, in172, n_accusati, q1 = round(q1, 3), sig1)]))
