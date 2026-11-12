# PROVA DA BUTTARE
# 14-potenza.R — S12r5, prima delle corse: che cosa puo' dire la regola di esito (00-previsioni.md par. 4) con 8
# studi con un errore di B0 e 39 senza. NON legge nessuna uscita del modello: per ogni coppia (x studi con errore
# segnalati su 8, y studi senza errore segnalati su 39) calcola la differenza delle quote e il suo IC 95% per
# ricampionamento degli studi con gli stessi B e seme della regola. L'intervallo dipende poco da QUALI studi sono
# segnalati (gli indici ricampionati sono fissi): per ogni coppia si provano 50 scelte a caso degli studi.
#   Rscript .../14-potenza.R > .../14-out.txt 2>&1          (SENZA --vanilla)
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
con <- sv$gse %in% STUDI_CON_ERRORE
set.seed(SEME); I <- t(vapply(seq_len(B), function(k) sample.int(47L, replace = TRUE), integer(47)))     # gli stessi indici di differenza_quote()
CON <- matrix(con[I], nrow = B); nc <- rowSums(CON); ns <- 47L - nc
ic_inf <- function(segn) { S <- matrix(segn[I], nrow = B); unname(stats::quantile(rowSums(S & CON) / nc - rowSums(S & !CON) / ns, 0.025, na.rm = TRUE)) }
stopifnot(isTRUE(all.equal(ic_inf(seq_len(47L) %% 3L == 0L), differenza_quote(seq_len(47L) %% 3L == 0L)$ic[1])))   # e' la stessa regola
set.seed(SEME + 1L)
P <- do.call(rbind, lapply(0:8, function(x) do.call(rbind, lapply(0:39, function(y) {
  v <- vapply(seq_len(50L), function(r) { s <- logical(47L); s[sample(which(con), x)] <- TRUE; s[sample(which(!con), y)] <- TRUE; ic_inf(s) }, 0)
  data.frame(con_errore_segnalati = x, senza_errore_segnalati = y, differenza = x / 8 - y / 39, ic_inf_min = min(v), ic_inf_max = max(v), a_sempre = all(v > 0), a_mai = all(v <= 0)) }))))
scrivi_r5(P, "14-potenza.csv")
R <- do.call(rbind, lapply(0:8, function(x) { p <- P[P$con_errore_segnalati == x, ]
  data.frame(studi_con_errore_segnalati = x, a_vale_sempre_fino_a = if (any(p$a_sempre)) max(p$senza_errore_segnalati[p$a_sempre]) else NA,
             a_non_vale_mai_da = if (any(p$a_mai)) min(p$senza_errore_segnalati[p$a_mai]) else NA) }))
cat("Condizione (a) della regola di esito: l'IC 95% della differenza sta tutto sopra zero.\nPer x studi con errore segnalati su 8: (a) vale in ogni scelta provata se gli studi senza errore segnalati (su 39) sono al massimo `a_vale_sempre_fino_a`;\nnon vale in nessuna scelta se sono almeno `a_non_vale_mai_da`. NA: mai.\n")
print(R, row.names = FALSE)
