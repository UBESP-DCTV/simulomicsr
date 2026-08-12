# FASE 2f — LA PROVA NON LESSICALE, mirata: le conte.
#
# Domanda: le coppie che la regola dichiara "stessa libreria, corsie diverse"
# hanno davvero lo stesso profilo, e si distinguono dalle repliche BIOLOGICHE
# dello stesso studio?
#
# Controllo negativo interno allo studio: per ogni studio si calcolano TUTTE le
# correlazioni fra coppie di campioni e si separano in "stessa libreria" (secondo
# la regola) e "libreria diversa". Se la regola dice il vero, le due
# distribuzioni non si sovrappongono.
SC <- "analysis/audit/2026-08-12-corsie"
h5 <- "analysis/input/human_gene_v2.5.h5"
A  <- readRDS(file.path(SC, "90-ampiezza.rds"))
acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))

studi <- c("GSE173902", "GSE178340", "GSE115542", "GSE116899")
out <- list()
for (s in studi) {
  z <- A[A$series == s, ]
  i <- match(z$gsm, acc); stopifnot(!anyNA(i))
  X <- rhdf5::h5read(h5, "data/expression", index = list(i, NULL))
  X <- t(X); colnames(X) <- z$gsm
  keep <- rowSums(X) > 0
  L <- log1p(sweep(X[keep, , drop = FALSE], 2,
                   pmax(colSums(X[keep, , drop = FALSE]), 1), "/") * 1e6)
  C <- stats::cor(L, method = "spearman")
  n <- ncol(L); pr <- which(upper.tri(C), arr.ind = TRUE)
  stessa <- z$lib[pr[, 1]] == z$lib[pr[, 2]]
  d <- data.frame(studio = s, a = z$gsm[pr[, 1]], b = z$gsm[pr[, 2]],
                  ta = z$title[pr[, 1]], tb = z$title[pr[, 2]],
                  r = C[pr], stessa_libreria = stessa, stringsAsFactors = FALSE)
  out[[s]] <- d
  cat(sprintf("\n=== %s | campioni %d | geni usati %d | coppie %d ===\n",
              s, n, sum(keep), nrow(d)))
  cat(sprintf("  stessa libreria (%3d coppie): r  min %.4f  mediana %.4f  max %.4f\n",
      sum(stessa), min(d$r[stessa]), stats::median(d$r[stessa]), max(d$r[stessa])))
  cat(sprintf("  libreria diversa (%3d coppie): r min %.4f  mediana %.4f  max %.4f\n",
      sum(!stessa), min(d$r[!stessa]), stats::median(d$r[!stessa]), max(d$r[!stessa])))
  sep <- min(d$r[stessa]) > max(d$r[!stessa])
  cat("  SEPARAZIONE COMPLETA:", if (sep) "SI" else "NO", "\n")
  if (!sep) {
    ov <- d[!d$stessa_libreria & d$r >= min(d$r[stessa]), ]
    ov <- ov[order(-ov$r), ]
    cat("  coppie di libreria DIVERSA con r >= il minimo delle stesse:", nrow(ov), "\n")
    for (q in seq_len(min(5, nrow(ov))))
      cat(sprintf("     r=%.4f  %s  VS  %s\n", ov$r[q], ov$ta[q], ov$tb[q]))
  }
}
rhdf5::h5closeAll()
D <- do.call(rbind, out)
saveRDS(D, file.path(SC, "41-correlazione-mirata.rds"))
write.csv(D, file.path(SC, "41-correlazione-mirata.csv"), row.names = FALSE)
cat("\nscritto.\n")
