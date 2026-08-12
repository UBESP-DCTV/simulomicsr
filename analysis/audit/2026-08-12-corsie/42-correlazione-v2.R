# FASE 2g — LO STRUMENTO DELLA MISURA PRECEDENTE ERA SBAGLIATO, e si e' visto da
# un numero che contraddiceva l'attesa (trappola n.6: il primo sospettato e' lo
# strumento).
#
# La v1 correlava su TUTTI i geni con somma > 0 (40.000 e piu'), cioe' quasi
# tutti nella coda quasi-nulla. Due corsie hanno un QUARTO della profondita' di
# una libreria intera: nella coda il conteggio e' 0/1/2 e la correlazione misura
# rumore di campionamento, non identita' del materiale. Risultato: 0,88-0,94
# ovunque, senza separazione.
#
# v2: si correla sui geni ESPRESSI (CPM >= 1 in almeno meta' dei campioni dello
# studio), con Pearson su log-CPM e Spearman. E si riporta anche la profondita',
# che e' il controllo indipendente: le corsie sono libri sottili.
SC <- "analysis/audit/2026-08-12-corsie"
h5 <- "analysis/input/human_gene_v2.5.h5"
A  <- readRDS(file.path(SC, "90-ampiezza.rds"))
acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))

# quattro studi del deliverable + tre controlli negativi: studi SENZA corsie,
# scelti fra i piu' grandi del poolato, per vedere quanto arrivano in alto le
# repliche biologiche vere.
M <- readRDS(file.path(SC, "20-metadati.rds"))
senza <- setdiff(names(sort(table(M$series), decreasing = TRUE)),
                 unique(A$series[A$in_multi]))
studi <- c("GSE173902", "GSE178340", "GSE115542", "GSE116899", utils::head(senza, 3))

out <- list()
for (s in studi) {
  z <- A[A$series == s, ]
  if (nrow(z) < 4L || nrow(z) > 120L) next
  i <- match(z$gsm, acc)
  X <- rhdf5::h5read(h5, "data/expression", index = list(i, NULL))
  X <- t(X); colnames(X) <- z$gsm
  lib <- colSums(X)
  cpm <- sweep(X, 2, pmax(lib, 1), "/") * 1e6
  keep <- rowMeans(cpm >= 1) >= 0.5
  L <- log2(cpm[keep, , drop = FALSE] + 1)
  Cp <- stats::cor(L, method = "pearson")
  Cs <- stats::cor(L, method = "spearman")
  pr <- which(upper.tri(Cp), arr.ind = TRUE)
  stessa <- z$lib[pr[, 1]] == z$lib[pr[, 2]]
  d <- data.frame(studio = s, ta = z$title[pr[, 1]], tb = z$title[pr[, 2]],
                  r_pearson = Cp[pr], r_spearman = Cs[pr],
                  stessa_libreria = stessa, stringsAsFactors = FALSE)
  out[[s]] <- d
  cat(sprintf("\n=== %s | campioni %d | geni espressi %d | profondita' mediana %s ===\n",
              s, ncol(L), sum(keep), format(round(stats::median(lib)), big.mark = ".")))
  if (any(stessa)) {
    cat(sprintf("  stessa libreria (%3d coppie): Pearson  min %.4f  mediana %.4f\n",
        sum(stessa), min(d$r_pearson[stessa]), stats::median(d$r_pearson[stessa])))
    cat(sprintf("  libreria diversa (%3d coppie): Pearson max %.4f  mediana %.4f\n",
        sum(!stessa), max(d$r_pearson[!stessa]), stats::median(d$r_pearson[!stessa])))
    cat("  SEPARAZIONE COMPLETA (Pearson):",
        if (min(d$r_pearson[stessa]) > max(d$r_pearson[!stessa])) "SI" else "NO", "\n")
    cat(sprintf("  divario: minimo delle stesse %.4f contro massimo delle diverse %.4f\n",
        min(d$r_pearson[stessa]), max(d$r_pearson[!stessa])))
  } else {
    cat(sprintf("  CONTROLLO NEGATIVO (nessuna corsia): Pearson max fra due campioni %.4f, mediana %.4f\n",
        max(d$r_pearson), stats::median(d$r_pearson)))
  }
}
rhdf5::h5closeAll()
D <- do.call(rbind, out)
saveRDS(D, file.path(SC, "42-correlazione-v2.rds"))
write.csv(D, file.path(SC, "42-correlazione-v2.csv"), row.names = FALSE)
cat("\nscritto.\n")
