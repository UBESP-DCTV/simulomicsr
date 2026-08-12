# Quanto separa la correlazione? Una cifra sola, invece di un'impressione.
SC <- "analysis/audit/2026-08-12-corsie"
P <- readRDS(file.path(SC, "43-coppie.rds"))
a <- P$r[P$dichiarata]; b <- P$r[!P$dichiarata]
cat("coppie dichiarate corsia:", length(a), "| altre:", length(b), "\n")
# AUC = P(una coppia-corsia a caso correla piu' di una coppia biologica a caso)
set.seed(1); ia <- sample(a, 20000, replace = TRUE); ib <- sample(b, 20000, replace = TRUE)
cat("AUC (Mann-Whitney):", round(mean(ia > ib) + 0.5 * mean(ia == ib), 3), "\n")
for (s in c(0.99, 0.995, 0.9963, 0.998)) {
  cat(sprintf("  soglia %.4f: ritrova %2d/%d corsie (%.0f%%) e prende %5d coppie non dichiarate (%.2f%%)\n",
      s, sum(a >= s), length(a), 100*mean(a >= s), sum(b >= s), 100*mean(b >= s)))
}
cat("\nmediana corsie", round(median(a),4), "| mediana altre", round(median(b),4), "\n")
