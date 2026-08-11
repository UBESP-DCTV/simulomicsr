#!/usr/bin/env Rscript
# 30-regola-e-meta.R --- PASSO 4, passo 3:
#  (a) esiste una REGOLA DETERMINISTICA che predice il nucleo solido?
#      Cercata su meta' dei dati, riportata sull'ALTRA meta'. Mai il contrario.
#  (b) su CHE COSA divergono: i motivi del lettore umano nei 38 casi in cui dice
#      "incoerente" e Mistral dice "coerente", classificati per parola chiave.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
OUT <- "analysis/audit/2026-08-09-passo4"
X <- readRDS(file.path(OUT, "20-dati.rds"))
M <- X$M; P <- X$P; B <- X$B

# ---------------------------------------------------------------- (a) la regola
# Divisione in due meta' per `cluster_id` ORDINATO: deterministica, nessun seme,
# nessuna scelta mia. Le regole si CERCANO su A e si MISURANO su B.
o <- order(M$cluster_id)
M <- M[o, ]; P <- P[o, ]; B <- B[o, ]
A <- seq_len(nrow(M)) %% 2L == 1L
cat("meta' A (ricerca):", sum(A), "  meta' B (misura):", sum(!A), "\n")
cat("nucleo solido: A", sum(M$Y2[A]), " B", sum(M$Y2[!A]),
    sprintf("  (base %.1f%% / %.1f%%)\n", 100*mean(M$Y2[A]), 100*mean(M$Y2[!A])))

# Condizioni candidate: soglie su griglia sui predittori deterministici forti,
# piu' le binarie. Elencate PRIMA di guardare l'esito.
cond <- list()
for (s in c(3,4,5,6,8,10)) cond[[sprintf("k_effective<=%d", s)]] <- P$k_effective <= s
for (s in c(2,3,4,5))      cond[[sprintf("k_kish<=%d", s)]]      <- P$k_kish <= s
for (s in c(0,1,2))        cond[[sprintf("n_studi_model<=%d", s)]] <- P$n_studi_model <= s
for (s in c(0.5,0.6,0.7))  cond[[sprintf("frazione_efficace>=%.1f", s)]] <- P$frazione_efficace >= s
for (s in c(50,60,70))     cond[[sprintf("I2_med<=%d", s)]]      <- P$I2_med <= s
for (nm in names(B)) { cond[[nm]] <- B[[nm]]; cond[[paste0("!", nm)]] <- !B[[nm]] }
cond <- lapply(cond, function(x) { x[is.na(x)] <- FALSE; x })
cat("condizioni candidate:", length(cond), "\n")

valuta <- function(sel, Y, idx) {
  s <- sel & idx; if (sum(s) == 0L) return(c(prec = NA, cop = NA, n = 0))
  c(prec = mean(Y[s]), cop = sum(Y[s]) / sum(Y[idx]), n = sum(s))
}
# tutte le combinazioni fino a 3 condizioni
nmc <- names(cond)
combo <- c(
  lapply(seq_along(nmc), function(i) i),
  unlist(lapply(seq_along(nmc), function(i) lapply(seq_along(nmc)[-seq_len(i)], function(j) c(i,j))), recursive = FALSE),
  unlist(lapply(seq_along(nmc), function(i)
    unlist(lapply(seq_along(nmc)[-seq_len(i)], function(j)
      lapply(seq_along(nmc)[-seq_len(j)], function(k) c(i,j,k))), recursive = FALSE)), recursive = FALSE)
)
cat("combinazioni fino a 3 condizioni:", length(combo), "\n")
res <- do.call(rbind, lapply(combo, function(ix) {
  sel <- Reduce(`&`, cond[ix])
  a <- valuta(sel, M$Y2, A)
  data.frame(regola = paste(nmc[ix], collapse = " & "), n_cond = length(ix),
             prec_A = a["prec"], cop_A = a["cop"], n_A = a["n"], stringsAsFactors = FALSE)
}))
res <- res[!is.na(res$prec_A) & res$n_A >= 10, ]
res <- res[order(-res$prec_A, -res$cop_A), ]
cat("\n=== migliori 10 regole SULLA META' A (dove sono state cercate) ===\n")
print(head(res[, c("regola","n_cond","prec_A","cop_A","n_A")], 10), row.names = FALSE, digits = 3)

# La regola scelta e' la migliore su A per precisione, a parita' preferendo copertura.
best <- res$regola[1]
ix <- match(strsplit(best, " & ", fixed = TRUE)[[1]], nmc)
sel <- Reduce(`&`, cond[ix])
b <- valuta(sel, M$Y2, !A)
cat("\n=== LA REGOLA SCELTA SU A, MISURATA SULLA META' B (mai vista) ===\n")
cat("regola:", best, "\n")
cat(sprintf("  su A: precisione %.3f  copertura %.3f  n %d\n", res$prec_A[1], res$cop_A[1], res$n_A[1]))
cat(sprintf("  su B: precisione %.3f  copertura %.3f  n %d\n", b["prec"], b["cop"], b["n"]))
cat(sprintf("  base di B (nucleo solido): %.3f\n", mean(M$Y2[!A])))
cat(sprintf("  GUADAGNO su B: %+.3f in precisione rispetto al caso\n", b["prec"] - mean(M$Y2[!A])))
cat("\nSOGLIE DELLA PREVISIONE DEPOSITATA: precisione > 0,80 E copertura > 0,50\n")
cat("esito su B:", if (!is.na(b["prec"]) && b["prec"] > 0.80 && b["cop"] > 0.50)
      "REGGE" else "NON REGGE -> previsione P4 FALSIFICATA", "\n")

# quanto e' fragile: le prime 10 di A, tutte misurate su B
cat("\n=== le prime 10 di A, tutte misurate su B (per vedere se e' rumore) ===\n")
top <- head(res, 10)
tb <- do.call(rbind, lapply(seq_len(nrow(top)), function(r) {
  ii <- match(strsplit(top$regola[r], " & ", fixed = TRUE)[[1]], nmc)
  bb <- valuta(Reduce(`&`, cond[ii]), M$Y2, !A)
  data.frame(regola = substr(top$regola[r], 1, 58), prec_A = top$prec_A[r],
             prec_B = bb["prec"], cop_B = bb["cop"], n_B = bb["n"], stringsAsFactors = FALSE)
}))
print(tb, row.names = FALSE, digits = 3)
cat(sprintf("\ncalo mediano di precisione da A a B: %+.3f\n",
            stats::median(tb$prec_B - tb$prec_A, na.rm = TRUE)))

# --------------------------------------------------- (b) su che cosa divergono
um <- utils::read.csv("analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv",
                      stringsAsFactors = FALSE)
M$motivo <- um$motivo[match(M$cluster_id, um$cluster_id)]
gap <- M$umano == "incoerente" & M$mistral_b == "coerente"
cat("\n\n=== CASI IN CUI L'UMANO DICE INCOERENTE E MISTRAL COERENTE:", sum(gap), "===\n")
temi <- list(
  "clinico vs sperimentale" = "clinic|paziente|patient|in vitro|sperimental|modello|iPSC|autopt",
  "materiale/tessuto diverso" = "tessut|material|sede|anatom|organo|PBMC|sangue|blood|polmon|liver|fegato",
  "linea cellulare diversa"   = "linea cellular|cell line|LNCaP|HeLa|donatore|donor",
  "secondo agente/combo"      = "second[oa] agente|combo|combinazion|\\+|insieme a|co-tratt",
  "tempo/passaggio"           = "tempo|time|passagg|visit|ore|giorni|hpi",
  "entita' sbagliata"         = "entita|identita|ID errat|sbagliat|non e' |non è ",
  "controllo non appaiato"    = "controll[oi] (divers|non|misti)|baseline|non appaiat|coorte"
)
cnt <- vapply(temi, function(rx) sum(grepl(rx, M$motivo[gap], ignore.case = TRUE)), integer(1L))
cat("temi ricorrenti nei motivi del lettore umano (un motivo puo' toccarne piu' d'uno):\n")
print(sort(cnt, decreasing = TRUE))
cat("motivi che non toccano nessun tema:",
    sum(!Reduce(`|`, lapply(temi, function(rx) grepl(rx, M$motivo[gap], ignore.case = TRUE)))), "\n")
cat("\nk_effective: nei", sum(gap), "casi di divario mediana",
    stats::median(P$k_effective[gap]), " contro", stats::median(P$k_effective[!gap]), "nel resto\n")

utils::write.csv(M[gap, c("cluster_id","umano","mistral_b","motivo")],
                 file.path(OUT, "30-divario-umano-mistral.csv"), row.names = FALSE)
utils::write.csv(res, file.path(OUT, "30-regole-su-A.csv"), row.names = FALSE)
cat("\nscritto in", OUT, "\n")
