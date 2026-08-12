# FASE 2h — LA RICERCA DEI FALSI NEGATIVI SU TUTTO IL POOLATO.
#
# Due pre-filtri sono stati PROVATI E SCARTATI, e vanno dichiarati:
#   * la PROFONDITA' non filtra: le corsie di GSE173902 hanno 19,9 M di reads
#     l'una e quelle di GSE116899 10,9 M — sopra la mediana del corpus. L'idea
#     che "una corsia e' un libro sottile" e' falsa quando la libreria e' profonda.
#   * il BioSample non filtra (script 20): quattro corsie, quattro BioSample.
#
# Resta il confronto dei profili. Non e' un criterio (i controlli negativi
# mostrano repliche BIOLOGICHE a r = 0,9955), ma e' un GENERATORE DI CANDIDATI:
# se due campioni dello stesso braccio hanno profili quasi identici e il titolo
# non lo dichiara, quella coppia va letta a mano.
#
# Gira su tutti i 1.115 studi del poolato, un braccio alla volta.
SC <- "analysis/audit/2026-08-12-corsie"
h5 <- "analysis/input/human_gene_v2.5.h5"
M  <- readRDS(file.path(SC, "21-metadati-libsize.rds"))
A  <- readRDS(file.path(SC, "90-ampiezza.rds"))
R  <- readRDS(file.path(SC, "30-entry-annotate.rds")); R <- R[R$esito == "ammessa", ]
lib_of <- setNames(A$lib, A$gsm)

# bracci distinti (lo stesso insieme di campioni ricorre in piu' cluster)
bracci <- unique(c(R$gsm_treated, R$gsm_control))
cat("bracci distinti:", length(bracci), "\n")
per_studio <- split(bracci, vapply(bracci, function(s) {
  g <- strsplit(s, ",")[[1]][1]; M$series[match(g, M$gsm)] }, character(1)))
cat("studi:", length(per_studio), "\n")

acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))
out <- list(); t0 <- Sys.time(); done <- 0L
for (s in names(per_studio)) {
  gs <- unique(unlist(strsplit(per_studio[[s]], ",")))
  done <- done + 1L
  if (length(gs) < 2L) next
  i <- match(gs, acc)
  X <- try(rhdf5::h5read(h5, "data/expression", index = list(i, NULL)), silent = TRUE)
  if (inherits(X, "try-error")) { cat("ERRORE lettura", s, "\n"); next }
  X <- t(X); colnames(X) <- gs
  d <- colSums(X); cpm <- sweep(X, 2, pmax(d, 1), "/") * 1e6
  keep <- rowMeans(cpm >= 1) >= 0.5
  if (sum(keep) < 500L) next
  L <- log2(cpm[keep, , drop = FALSE] + 1)
  C <- stats::cor(L, method = "pearson")
  for (b in per_studio[[s]]) {
    g <- strsplit(b, ",")[[1]]
    if (length(g) < 2L) next
    p <- utils::combn(g, 2)
    r <- C[cbind(match(p[1, ], gs), match(p[2, ], gs))]
    out[[length(out) + 1L]] <- data.frame(
      studio = s, braccio = substr(b, 1, 40), a = p[1, ], b = p[2, ], r = r,
      dichiarata = lib_of[p[1, ]] == lib_of[p[2, ]],
      dep_a = d[match(p[1, ], gs)], dep_b = d[match(p[2, ], gs)],
      stringsAsFactors = FALSE)
  }
  if (done %% 100L == 0L)
    cat(sprintf("[%s] %d/%d studi | %.1f min\n", format(Sys.time(), "%H:%M:%S"),
        done, length(per_studio), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
rhdf5::h5closeAll()
P <- do.call(rbind, out)
P <- P[!duplicated(paste(P$a, P$b)), ]
cat("\ncoppie intra-braccio distinte:", nrow(P), "\n")
cat("dichiarate stessa libreria dalla regola:", sum(P$dichiarata), "\n")
cat("\n=== DISTRIBUZIONE DI r, coppie NON dichiarate ===\n")
print(round(stats::quantile(P$r[!P$dichiarata], c(.5, .9, .99, .999, 1)), 4))
cat("\n=== DISTRIBUZIONE DI r, coppie DICHIARATE ===\n")
if (any(P$dichiarata)) print(round(stats::quantile(P$r[P$dichiarata], c(0, .01, .1, .5, 1)), 4))
soglia <- if (any(P$dichiarata)) min(P$r[P$dichiarata]) else 0.99
cat("\nsoglia = il minimo osservato fra le coppie dichiarate:", round(soglia, 4), "\n")
cand <- P[!P$dichiarata & P$r >= soglia, ]
cat("CANDIDATI (coppie non dichiarate sopra la soglia):", nrow(cand),
    "| studi:", length(unique(cand$studio)), "\n")
saveRDS(P, file.path(SC, "43-coppie.rds"))
write.csv(cand[order(-cand$r), ], file.path(SC, "43-candidati.csv"), row.names = FALSE)
cat("scritto.\n")
