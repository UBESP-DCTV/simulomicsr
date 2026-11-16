# 42-resa.R — conto accanto, NATO DOPO I NUMERI della prova piccola (non sta nella carta 00-previsioni.md).
# Dal pezzo `casuale` (500 studi nuovi estratti a caso, 482 nell'ingresso) stima quanti studi nuovi di ARCHS4 la regola
# dell'accordo tiene con almeno un confronto, e quanti confronti, sui 21.249 studi nuovi. Unita': lo studio estratto
# (uno studio estratto e senza colonne non costanti conta zero). Intervallo al 95% col ricampionamento dei 500 studi,
# B = 10.000, seme 20261116. Non misura la correttezza dei confronti.
# Uso: Rscript analysis/audit/2026-11-16-archs4-intero/42-resa.R        (SENZA --vanilla)
DIR <- "analysis/audit/2026-11-16-archs4-intero"
el <- utils::read.csv(file.path(DIR, "10-elenco.csv"), stringsAsFactors = FALSE)
d <- utils::read.csv(file.path(DIR, "41-per-studio.csv"), stringsAsFactors = FALSE)
estratti <- el$gse[el$prova == "casuale"]; N <- sum(el$classe == "nuovo")
stopifnot(length(estratti) == 500L, N == 21249L, all(el$classe[el$prova == "casuale"] == "nuovo"))
d <- d[d$prova == "casuale", ]; stopifnot(nrow(d) == 482L, all(d$gse %in% estratti))
i <- match(estratti, d$gse)
tenuto <- !is.na(i) & d$tenuto[i] %in% TRUE
conf <- ifelse(tenuto, d$confronti_M[i], 0L); stopifnot(!anyNA(conf))
con_conf <- as.integer(conf > 0L)
set.seed(20261116); B <- 10000L
boot <- replicate(B, { j <- sample.int(500L, replace = TRUE); c(mean(tenuto[j]), mean(con_conf[j]), mean(conf[j])) })
ic <- apply(boot, 1, stats::quantile, c(0.025, 0.975))
riga <- function(nome, x, k, cifre = 1, per100 = TRUE) {
  m <- mean(x); f <- if (per100) 100 else 1
  cat(sprintf("%s: %s su 500 estratti = %.*f%s (IC95 %.*f-%.*f); sui %s studi nuovi: circa %s (IC95 %s-%s)\n", nome, sum(x), cifre, f * m,
              if (per100) "%" else " per studio", cifre, f * ic[1, k], cifre, f * ic[2, k], format(N, big.mark = ".", decimal.mark = ","),
              format(round(N * m, -1), big.mark = ".", decimal.mark = ","), format(round(N * ic[1, k], -1), big.mark = ".", decimal.mark = ","), format(round(N * ic[2, k], -1), big.mark = ".", decimal.mark = ",")))
}
sink(file.path(DIR, "42-resa-out.txt"), split = TRUE)
cat("42-resa.R  conto accanto nato dopo i numeri ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n", sep = "")
cat("estratti a caso 500; nell'ingresso", nrow(d), "; senza colonne non costanti", 500L - nrow(d), "\n")
riga("studi tenuti dalla regola dell'accordo", as.integer(tenuto), 1)
riga("studi tenuti con almeno un confronto", con_conf, 2)
riga("confronti negli studi tenuti", conf, 3, cifre = 2, per100 = FALSE)
t <- d[d$tenuto %in% TRUE & d$confronti_M == 0, ]
cat("\nstudi tenuti senza confronti:", nrow(t), "\n  per campioni: fino a 3:", sum(t$campioni <= 3), "; 4-12:", sum(t$campioni >= 4 & t$campioni <= 12),
    "; 13-48:", sum(t$campioni >= 13 & t$campioni <= 48), "; oltre 48:", sum(t$campioni > 48), "\n  per gruppi di Mistral: 1 gruppo:", sum(t$gruppi_M == 1),
    "; 2 o piu' gruppi:", sum(t$gruppi_M >= 2), "\n")
cat("FINE 42-resa.R\n"); sink()
