# FASE 2e — LE GUARDIE, dettate dai falsi positivi trovati (script 91).
#
# IL FALSO POSITIVO CHE HA CAMBIATO IL DISEGNO. La regola del solo titolo unisce
# i POZZETTI di una piastra: in GSE145815 `1001703001_L1` ha `well: L1` e
# `1001703001_L10` ha `well: L10` — e i due hanno perfino `moi: 0` contro
# `moi: 0.1`, cioe' un controllo e un trattato. In GSE124742 e GSE116672 le
# "corsie" arrivano a L23/L24 e sono cellule singole di una piastra patch-seq.
# Corpus intero: su 4.360 librerie che collassano, solo il 45,3% ha
# `characteristics_ch1` identici. **La regola nuda sbaglia piu' spesso di quanto
# indovini.** Non puo' andare in produzione cosi'.
#
# Tre guardie, ognuna con una ragione fisica o misurata:
#   G1 CARDINALITA': una libreria non puo' stare su piu' di 8 corsie (il massimo
#      fisico di un flowcell Illumina). 23 o 24 "corsie" sono pozzetti.
#   G2 METADATI: due corsie sono lo STESSO materiale -> `characteristics_ch1` e
#      `source_name_ch1` devono coincidere.
#   G3 NUMERO DI CORSIA: l'indice deve stare fra 1 e 8.
SC <- "analysis/audit/2026-08-12-corsie"
h5 <- "analysis/input/human_gene_v2.5.h5"
A  <- readRDS(file.path(SC, "90-ampiezza.rds"))
acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))
ch  <- as.character(rhdf5::h5read(h5, "meta/samples/characteristics_ch1"))
so  <- as.character(rhdf5::h5read(h5, "meta/samples/source_name_ch1"))
scp <- as.numeric(rhdf5::h5read(h5, "meta/samples/singlecellprobability"))
rhdf5::h5closeAll()
i <- match(A$gsm, acc); A$charact <- ch[i]; A$source <- so[i]; A$scprob <- scp[i]

# indice di corsia estratto dal titolo (per G3)
idx_corsia <- function(x) {
  y <- tolower(trimws(x))
  m <- regexpr("[._-]l0*[0-9]{1,3}([._-]|$)", y)
  out <- rep(NA_integer_, length(y))
  ok <- m > 0
  out[ok] <- as.integer(gsub("[^0-9]", "", regmatches(y, m)))
  out
}
A$corsia <- suppressWarnings(idx_corsia(A$title))

B  <- A[A$in_multi & !A$gia_uguali, ]
sp <- split(seq_len(nrow(B)), B$lib)
G <- data.frame(lib = names(sp), n = vapply(sp, length, integer(1)),
  G1 = vapply(sp, length, integer(1)) <= 8L,
  G2 = vapply(sp, function(j) length(unique(B$charact[j])) == 1L &&
                              length(unique(B$source[j])) == 1L, logical(1)),
  G3 = vapply(sp, function(j) { v <- B$corsia[j]
        all(!is.na(v)) && all(v >= 1L & v <= 8L) }, logical(1)),
  scmax = vapply(sp, function(j) max(B$scprob[j], na.rm = TRUE), numeric(1)),
  stringsAsFactors = FALSE)
G$studio <- sub("\r.*", "", G$lib)

cat("=== EFFETTO DELLE GUARDIE SU TUTTE LE", nrow(G), "LIBRERIE DEL CORPUS ===\n")
cat(sprintf("  nessuna guardia:        %5d librerie | %5d campioni | %3d studi\n",
    nrow(G), sum(G$n), length(unique(G$studio))))
for (g in c("G1", "G2", "G3")) {
  k <- G[[g]]
  cat(sprintf("  supera %s:              %5d librerie | %5d campioni | %3d studi\n",
      g, sum(k), sum(G$n[k]), length(unique(G$studio[k]))))
}
k <- G$G1 & G$G2 & G$G3
cat(sprintf("  supera TUTTE E TRE:     %5d librerie | %5d campioni | %3d studi\n",
    sum(k), sum(G$n[k]), length(unique(G$studio[k]))))
cat(sprintf("  di cui single-cell prob > 0,5: %d librerie\n", sum(k & G$scmax > 0.5)))

cat("\n=== I QUATTRO STUDI DEL DELIVERABLE SUPERANO LE GUARDIE? ===\n")
for (s in c("GSE173902", "GSE178340", "GSE115542", "GSE116899")) {
  z <- G[G$studio == s, ]
  cat(sprintf("  %-11s librerie %2d | G1 %2d | G2 %2d | G3 %2d | tutte %2d | n per libreria %s\n",
      s, nrow(z), sum(z$G1), sum(z$G2), sum(z$G3), sum(z$G1 & z$G2 & z$G3),
      paste(sort(unique(z$n)), collapse = "/")))
  if (any(!(z$G1 & z$G2 & z$G3))) {
    b <- z[!(z$G1 & z$G2 & z$G3), ]
    for (l in utils::head(b$lib, 3)) { j <- sp[[l]]
      cat("     BLOCCATA:", gsub("\r", " | ", l), "\n")
      cat("       titoli:", paste(utils::head(B$title[j], 4), collapse = " ++ "), "\n")
      cat("       charact:", paste(unique(substr(B$charact[j], 1, 60)), collapse = " ++ "), "\n") }
  }
}

cat("\n=== STUDI CHE SOPRAVVIVONO A TUTTE E TRE (i primi 25) ===\n")
kk <- G[k, ]
tt <- sort(table(kk$studio), decreasing = TRUE)
for (s in utils::head(names(tt), 25)) {
  z <- kk[kk$studio == s, ]; j <- sp[[z$lib[1]]]
  cat(sprintf("%-24s %4d librerie | scprob max %.2f | %s\n", s, nrow(z),
      max(z$scmax), paste(utils::head(B$title[j], 2), collapse = " ++ ")))
}
saveRDS(G, file.path(SC, "92-guardie.rds"))
write.csv(G, file.path(SC, "92-guardie.csv"), row.names = FALSE)
cat("\nscritto.\n")
