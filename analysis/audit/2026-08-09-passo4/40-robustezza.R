#!/usr/bin/env Rscript
# 40-robustezza.R --- il risultato negativo di 30- regge, o dipende da COME ho
# diviso i dati? Una sola divisione non basta: la base del nucleo solido nelle
# due meta' era 21,5% e 30,2%, e quello squilibrio da solo puo' spiegare il calo.
#
# Qui: 200 divisioni casuali (seme fisso), ogni volta si CERCA la regola migliore
# su A e la si MISURA su B. Si riporta la distribuzione del guadagno su B.
# Il caso e' la base di B: guadagno = precisione_B - base_B.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
OUT <- "analysis/audit/2026-08-09-passo4"
X <- readRDS(file.path(OUT, "20-dati.rds"))
M <- X$M; P <- X$P; B <- X$B

cond <- list()
for (s in c(3,4,5,6,8,10)) cond[[sprintf("k_effective<=%d", s)]] <- P$k_effective <= s
for (s in c(2,3,4,5))      cond[[sprintf("k_kish<=%d", s)]]      <- P$k_kish <= s
for (s in c(0,1,2))        cond[[sprintf("n_studi_model<=%d", s)]] <- P$n_studi_model <= s
for (s in c(0.5,0.6,0.7))  cond[[sprintf("frazione_efficace>=%.1f", s)]] <- P$frazione_efficace >= s
for (s in c(50,60,70))     cond[[sprintf("I2_med<=%d", s)]]      <- P$I2_med <= s
for (nm in names(B)) { cond[[nm]] <- B[[nm]]; cond[[paste0("!", nm)]] <- !B[[nm]] }
cond <- lapply(cond, function(x) { x[is.na(x)] <- FALSE; x })
nmc <- names(cond); K <- length(cond)

# matrice delle selezioni per tutte le combinazioni fino a 3 condizioni
idx <- c(lapply(seq_len(K), function(i) i),
  unlist(lapply(seq_len(K), function(i) lapply(seq_len(K)[-seq_len(i)], function(j) c(i,j))), recursive = FALSE),
  unlist(lapply(seq_len(K), function(i)
    unlist(lapply(seq_len(K)[-seq_len(i)], function(j)
      lapply(seq_len(K)[-seq_len(j)], function(k) c(i,j,k))), recursive = FALSE)), recursive = FALSE))
SEL <- vapply(idx, function(ii) Reduce(`&`, cond[ii]), logical(nrow(M)))
cat("combinazioni:", ncol(SEL), " righe:", nrow(SEL), "\n")

Y <- M$Y2
set.seed(20260809)
R <- 200L
out <- matrix(NA_real_, R, 4,
              dimnames = list(NULL, c("prec_A","prec_B","base_B","guadagno_B")))
for (r in seq_len(R)) {
  a <- sample(c(TRUE, FALSE), nrow(M), replace = TRUE)
  nA <- colSums(SEL[a, , drop = FALSE]); nB <- colSums(SEL[!a, , drop = FALSE])

  pA <- colSums(SEL[a, , drop = FALSE] & Y[a]) / pmax(1L, nA)
  ok <- nA >= 10L
  if (!any(ok)) next
  pA[!ok] <- -1
  w <- which.max(pA)
  pB <- if (nB[w] > 0L) sum(SEL[!a, w] & Y[!a]) / nB[w] else NA_real_
  out[r, ] <- c(pA[w], pB, mean(Y[!a]), pB - mean(Y[!a]))
}
out <- out[stats::complete.cases(out), , drop = FALSE]
cat("divisioni valide:", nrow(out), "\n\n")
cat("=== la regola migliore su A, misurata su B, su", nrow(out), "divisioni casuali ===\n")
q <- function(x) sprintf("mediana %.3f  [1o quartile %.3f, 3o %.3f]  min %.3f max %.3f",
                         stats::median(x), stats::quantile(x, .25), stats::quantile(x, .75),
                         min(x), max(x))
cat("precisione su A :", q(out[,"prec_A"]), "\n")
cat("precisione su B :", q(out[,"prec_B"]), "\n")
cat("base di B       :", q(out[,"base_B"]), "\n")
cat("GUADAGNO su B   :", q(out[,"guadagno_B"]), "\n")
cat(sprintf("\ndivisioni in cui il guadagno su B e' POSITIVO: %d/%d (%.1f%%)\n",
            sum(out[,"guadagno_B"] > 0), nrow(out), 100*mean(out[,"guadagno_B"] > 0)))
cat(sprintf("divisioni in cui la precisione su B supera 0,80: %d/%d\n",
            sum(out[,"prec_B"] > 0.80), nrow(out)))
cat(sprintf("calo mediano di precisione da A a B: %+.3f\n",
            stats::median(out[,"prec_B"] - out[,"prec_A"])))
saveRDS(out, file.path(OUT, "40-robustezza.rds"))

# --- confronto: e se il bersaglio fosse il verdetto di UN SOLO giudice? -------
# Se nemmeno un giudice singolo e' predicibile, il problema non e' il disaccordo:
# e' che il verdetto non sta nei segnali misurabili.
for (nome in c("umano", "mistral_b")) {
  Yg <- M[[nome]] == "coerente"
  set.seed(20260809)
  g <- replicate(100L, {
    a <- sample(c(TRUE, FALSE), nrow(M), replace = TRUE)
    nA <- colSums(SEL[a, , drop = FALSE]); nB <- colSums(SEL[!a, , drop = FALSE])
    pA <- colSums(SEL[a, , drop = FALSE] & Yg[a]) / pmax(1L, nA); pA[nA < 10L] <- -1
    w <- which.max(pA)
    if (nB[w] == 0L) return(NA_real_)
    sum(SEL[!a, w] & Yg[!a]) / nB[w] - mean(Yg[!a])
  })
  g <- g[is.finite(g)]
  cat(sprintf("\nbersaglio '%s = coerente' (base %.3f): guadagno mediano su B %+.3f, positivo in %d/%d\n",
              nome, mean(Yg), stats::median(g), sum(g > 0), length(g)))
}
