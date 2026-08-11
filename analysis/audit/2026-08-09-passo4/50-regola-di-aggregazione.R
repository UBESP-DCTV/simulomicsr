#!/usr/bin/env Rscript
# 50-regola-di-aggregazione.R --- PASSO 4, il cuore.
#
# IPOTESI, formulata dopo aver LETTO i 38 motivi del divario (non prima: e'
# un'ipotesi generata dai dati, e come tale va testata su una previsione che
# non e' quella da cui nasce).
#
# I due giudici NON sono in disaccordo sui FATTI: i 38 motivi del lettore umano
# citano difetti puntuali e verificabili (un secondo agente in un braccio, un
# tessuto diverso fra i bracci, cellule contro tessuto, finestre temporali
# disallineate, sottolinee resistenti). Mistral non li nega: li considera non
# decisivi.
#
# Sono in disaccordo sulla REGOLA DI AGGREGAZIONE:
#   - umano  : "almeno UN confronto difettoso su k -> il gruppo e' incoerente"
#   - Mistral: "la maggioranza dei confronti misura il contrasto -> coerente"
#
# PREVISIONE FALSIFICABILE che ne discende, ed e' il test:
# se la regola umana e' "almeno uno su k", allora la probabilita' che il gruppo
# sia dichiarato incoerente deve CRESCERE con k secondo 1-(1-p)^k, con p il
# tasso di difetto PER CONFRONTO. Se invece la regola e' su una FRAZIONE, la
# probabilita' deve essere INDIPENDENTE da k.
#
# p non e' un parametro libero inventato qui: e' gia' stato misurato il
# 2026-08-05 sui 13 gruppi grandi, 85 confronti imperfetti su 843 = 10,1%.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
OUT <- "analysis/audit/2026-08-09-passo4"
X <- readRDS(file.path(OUT, "20-dati.rds")); M <- X$M; P <- X$P
k <- P$k_effective
u_inc <- M$umano == "incoerente"
m_inc <- M$mistral_b == "incoerente"
u_coe <- M$umano == "coerente"
m_coe <- M$mistral_b == "coerente"

cat("=== 1. p misurato INDIPENDENTEMENTE il 2026-08-05 ===\n")
P_MIS <- 85/843
cat(sprintf("confronti imperfetti nei 13 gruppi grandi: 85/843 = %.4f\n", P_MIS))

cat("\n=== 2. p stimato dai verdetti umani, per massima verosimiglianza ===\n")
nll <- function(p) { q <- 1 - (1-p)^k; -sum(log(ifelse(u_inc, q, 1-q) + 1e-12)) }
fit <- stats::optimize(nll, c(0.001, 0.6))
p_hat <- fit$minimum
cat(sprintf("p stimato dai 213 verdetti umani: %.4f\n", p_hat))
cat(sprintf("scarto dal p misurato il 5 agosto: %+.4f\n", p_hat - P_MIS))

cat("\n=== 3. il modello 'almeno uno su k' predice i verdetti UMANI? ===\n")
b <- cut(k, breaks = c(2,3,4,6,10,100), labels = c("3","4","5-6","7-10","11+"), right = TRUE)
tab <- do.call(rbind, lapply(split(seq_along(k), b), function(ii) data.frame(
  k = as.character(b[ii[1]]), n = length(ii), k_medio = round(mean(k[ii]), 1),
  oss_umano  = round(mean(u_inc[ii]), 3),
  att_p_5ago = round(mean(1 - (1-P_MIS)^k[ii]), 3),
  att_p_stim = round(mean(1 - (1-p_hat)^k[ii]), 3),
  oss_mistral = round(mean(m_inc[ii]), 3))))
print(tab, row.names = FALSE)
cat(sprintf("\nerrore assoluto medio, modello con p del 5 agosto : %.3f\n",
            mean(abs(tab$oss_umano - tab$att_p_5ago))))
cat(sprintf("errore assoluto medio, modello con p stimato      : %.3f\n",
            mean(abs(tab$oss_umano - tab$att_p_stim))))
cat(sprintf("errore assoluto medio, modello COSTANTE (media)   : %.3f\n",
            mean(abs(tab$oss_umano - mean(u_inc)))))

cat("\n=== 4. e Mistral? La sua severita' dipende da k? ===\n")
cat("correlazione di Spearman fra k e 'incoerente':\n")
cat(sprintf("  umano  : rho = %+.3f\n", stats::cor(k, as.numeric(u_inc), method = "spearman")))
cat(sprintf("  Mistral: rho = %+.3f\n", stats::cor(k, as.numeric(m_inc), method = "spearman")))
cat("correlazione fra k e 'coerente':\n")
cat(sprintf("  umano  : rho = %+.3f\n", stats::cor(k, as.numeric(u_coe), method = "spearman")))
cat(sprintf("  Mistral: rho = %+.3f\n", stats::cor(k, as.numeric(m_coe), method = "spearman")))

cat("\n=== 5. il test decisivo: il modello 'almeno uno su k' su Mistral ===\n")
nllM <- function(p) { q <- 1 - (1-p)^k; -sum(log(ifelse(m_inc, q, 1-q) + 1e-12)) }
pM <- stats::optimize(nllM, c(0.0001, 0.6))$minimum
cat(sprintf("p implicito in Mistral: %.4f  (umano %.4f, rapporto %.1fx)\n",
            pM, p_hat, p_hat/pM))
cat(sprintf("errore del modello su Mistral: %.3f  contro modello costante: %.3f\n",
            mean(abs(tab$oss_mistral - vapply(split(seq_along(k), b),
                 function(ii) mean(1-(1-pM)^k[ii]), numeric(1)))),
            mean(abs(tab$oss_mistral - mean(m_inc)))))

cat("\n=== 6. controprova sul dato vero: i gruppi con difetti CONTATI ===\n")
# I 13 gruppi grandi del 5 agosto hanno il conteggio esatto dei confronti
# imperfetti. Se la regola umana e' "almeno uno", TUTTI e 13 devono essere
# incoerenti; se e' una frazione, no.
j <- file.path("analysis/audit/2026-08-05-rilettura-214/13-grandi-conteggio.json")
if (file.exists(j)) {
  g <- jsonlite::fromJSON(j, simplifyVector = FALSE)
  cid <- vapply(g, function(x) x$cluster_id %||% NA_character_, character(1L))
  `%||%` <- function(a,b) if (is.null(a)) b else a
  ok <- cid %in% M$cluster_id
  cat("gruppi grandi ritrovati nella base:", sum(ok), "su", length(cid), "\n")
  if (any(ok)) {
    idx <- match(cid[ok], M$cluster_id)
    cat("  umano incoerente:", sum(M$umano[idx] == "incoerente"), "/", sum(ok), "\n")
    cat("  Mistral incoerente:", sum(M$mistral_b[idx] == "incoerente"), "/", sum(ok), "\n")
  }
} else cat("file dei 13 grandi non trovato:", j, "\n")

cat("\n=== 7. quanto costa la scelta della regola ===\n")
for (soglia in c(3,4,5,6,8,10,15)) {
  s <- k >= soglia
  cat(sprintf("  gruppi con k>=%2d: %3d | umano li dichiara incoerenti %5.1f%% | Mistral %5.1f%%\n",
              soglia, sum(s), 100*mean(u_inc[s]), 100*mean(m_inc[s])))
}
