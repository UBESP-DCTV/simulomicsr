# FASE 2.1 — Il segnale NON LESSICALE: le conte.
#
# Il titolo e' un'euristica e il BioSample si e' rivelato inservibile in tutte e
# due le direzioni (script 20/30). Serve una prova che non venga dalle stringhe:
# due corsie della STESSA libreria hanno lo stesso profilo di espressione a meno
# del rumore di campionamento; due repliche BIOLOGICHE no.
#
# Legge 2.000 geni (passo fisso su tutta l'annotazione, nessuna selezione) per i
# 18.371 campioni delle entry ammesse. La matrice serve a due cose:
#   (a) confermare i 9 candidati;
#   (b) CERCARE I FALSI NEGATIVI: coppie con correlazione da replica tecnica il
#       cui titolo NON le dichiara tali.
SC <- "analysis/audit/2026-08-12-corsie"
h5 <- "analysis/input/human_gene_v2.5.h5"
M  <- readRDS(file.path(SC, "20-metadati.rds"))

acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))
ord <- match(M$gsm, acc)
stopifnot(!anyNA(ord))
idx <- sort(unique(ord))
geni <- seq(1L, 67186L, by = 33L)          # passo fisso: nessuna selezione
cat("geni:", length(geni), "| campioni:", length(idx), "\n")

t0 <- Sys.time()
X <- rhdf5::h5read(h5, "data/expression", index = list(idx, geni))
rhdf5::h5closeAll()
rownames(X) <- acc[idx]
cat("letto in", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min | dim",
    paste(dim(X), collapse = " x "), "\n")

# profondita' totale, per il controllo indipendente sulle corsie
libsize <- rowSums(X)
saveRDS(list(X = X, libsize = libsize, geni = geni), file.path(SC, "40-counts.rds"))
cat("scritto.\n")
