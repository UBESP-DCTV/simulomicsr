N <- read.csv("analysis/audit/2026-08-20-rilettura-194/B3-nulli.csv", stringsAsFactors=FALSE)
ok <- N[N$esito=="ok", ]
cat("gruppi con nullo:", nrow(ok), "\n\n")
cat("=== la CODA: quanti superano il 90o percentile, contro l'atteso per caso ===\n")
for (v in c("percentile_spearman","percentile_sig","percentile_delta")) {
  p <- ok[[v]]; p <- p[!is.na(p)]
  oss <- sum(p > 0.9); att <- 0.10*length(p)
  bt <- binom.test(oss, length(p), 0.10, alternative="greater")
  cat(sprintf("  %-20s osservati %2d su %d | attesi %.1f | binomiale p = %.4f\n",
              v, oss, length(p), att, bt$p.value))
}
cat("\n=== e il numero di studi accusati conta? ===\n")
print(cor.test(ok$n_accusati, ok$percentile_sig, method="spearman")[c("estimate","p.value")])
cat("\n=== quanti gruppi hanno TUTTI E TRE i percentili sopra 0,90? ===\n")
tre <- ok$percentile_spearman>0.9 & ok$percentile_sig>0.9 & ok$percentile_delta>0.9
cat("  ", sum(tre, na.rm=TRUE), ":", paste(ok$entita[which(tre)], collapse=", "), "\n")
