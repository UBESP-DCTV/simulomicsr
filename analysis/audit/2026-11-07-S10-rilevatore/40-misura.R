#!/usr/bin/env Rscript
# 40-misura.R — S10: la regola nelle quattro varianti contro il riferimento.
#
# Ingressi: 20-ingressi-regola.rds (esiti V0-V3 sui 1.903), 30-riferimento.csv
# (129 confronti difettosi, conto committato prima di questo script).
# Uscite: 40-out.txt, 40-esiti.csv, 40-falsi-allarmi.csv, 40-difetti-non-visti.csv.
# Incertezza: bootstrap degli STUDI, B = 2000, seme 20261107 (00-previsioni.md).
#
# Uso: Rscript analysis/audit/2026-11-07-S10-rilevatore/40-misura.R
suppressPackageStartupMessages(library(data.table))
OUT <- "analysis/audit/2026-11-07-S10-rilevatore"
x <- readRDS(file.path(OUT, "20-ingressi-regola.rds"))$righe
setDT(x)
ref <- fread(file.path(OUT, "30-riferimento.csv"), encoding = "UTF-8")
dif <- fread("analysis/audit/2026-08-20-rilettura-194/difetti.csv", encoding = "UTF-8")
stopifnot(nrow(x) == 1903L, !anyDuplicated(x$record_id))

VAR <- c("V0", "V1", "V2", "V3")
coppie_acc <- unique(paste(dif$cluster_id, dif$study_id))
x[, coppia := paste(cluster_id, study)]
x[, insieme := fifelse(record_id %in% ref$record_id, "difettoso",
                fifelse(coppia %in% coppie_acc, "altro_negativo", "pulito"))]
x[, non_provato := record_id %in% ref[non_provato == TRUE, record_id] &
                   !(record_id %in% ref[non_provato == FALSE, record_id])]
for (v in VAR) set(x, j = paste0("s_", v), value = !is.na(x[[v]]) & nzchar(x[[v]]))

# famiglia del difetto: le stesse espressioni di 30-consolida.py, sulla categoria
FAM <- list(
  c("secondo agente solo nel trattato", "secondo agente|due agenti|agente aggiuntiv|combinaz|co-trattam|insieme"),
  c("materiale / tipo cellulare diverso fra i bracci", "materiale|tipo cellular|linea cellular|iPSC|primar"),
  c("donatore / soggetto / sesso / etnia diversi", "donator|soggett|sesso|etni|paziente divers|individu"),
  c("tempo non appaiato", "tempo|durat|\\bh\\b|ore|timepoint|giorni"),
  c("sede anatomica diversa", "sede|anatom|tessut.*divers|regione"),
  c("passaggio di coltura non appaiato", "passagg|passage"),
  c("genotipo / perturbazione genetica su un braccio solo", "genotip|knockout|\\bKO\\b|knockdown|shRNA|siRNA|mutant|transgen|overexpress"),
  c("entita del gruppo non isolata dal confronto", "entit|non isol|non e.? l.entit|contrasto non|misura altro|diversa entit"),
  c("controllo non e un controllo / tipo di controllo sbagliato", "controllo non|non e.? un controllo|tipo di controllo|veicolo|vehicle|baseline"),
  c("direzione opposta nello stesso gruppo", "direzion|agonist|antagonist|verso opposto|segno opposto"),
  c("dose non appaiata", "dose|concentraz|\\buM\\b|ng/ml"))
famiglia <- function(cat) {
  for (f in FAM) if (grepl(f[2], cat, ignore.case = TRUE, perl = TRUE)) return(f[1])
  "altro"
}
ref1 <- ref[!duplicated(record_id)]
ref1[, famiglia := vapply(categoria, famiglia, "")]
x[ref1, on = "record_id", `:=`(famiglia = i.famiglia, categoria = i.categoria)]

# --------------------------------------------------------------- cancello C3 ---
c3 <- c(righe_riferimento = length(unique(ref$riga)),
        esiti_completi = sum(complete.cases(x[, ..VAR])))

# --------------------------------------------------------------- bootstrap -----
set.seed(20261107L)
studi <- unique(x$study)
B <- 2000L
idx_by_study <- split(seq_len(nrow(x)), x$study)
boot <- replicate(B, {
  s <- sample(studi, length(studi), replace = TRUE)
  i <- unlist(idx_by_study[s], use.names = FALSE)
  xb <- x[i]
  unlist(lapply(VAR, function(v) {
    sv <- xb[[paste0("s_", v)]]
    c(sens = sum(sv & xb$insieme == "difettoso") / sum(xb$insieme == "difettoso"),
      fpr  = sum(sv & xb$insieme == "pulito") / sum(xb$insieme == "pulito"))
  }))
})
rownames(boot) <- as.vector(outer(c("sens", "fpr"), VAR, function(a, b) paste(b, a, sep = "_")))
ci <- function(r) quantile(boot[r, ], c(0.025, 0.975), na.rm = TRUE)

pct <- function(a, b) sprintf("%d/%d (%.1f%%)", a, b, 100 * a / b)
nD <- sum(x$insieme == "difettoso"); nP <- sum(x$insieme == "pulito"); nA <- sum(x$insieme == "altro_negativo")
stopifnot(nD == 129L, nP == 1704L, nA == 70L)

sink(file.path(OUT, "40-out.txt"), split = TRUE)
cat("== Cancello C3 ==\n"); print(c3)
cat(sprintf("insiemi: difettosi %d, puliti %d, altri negativi %d\n\n", nD, nP, nA))

cat("== La scala delle varianti ==\n")
scala <- rbindlist(lapply(VAR, function(v) {
  sv <- x[[paste0("s_", v)]]
  tp <- sum(sv & x$insieme == "difettoso"); fp <- sum(sv & x$insieme == "pulito")
  an <- sum(sv & x$insieme == "altro_negativo")
  tp_np <- sum(sv & x$insieme == "difettoso" & !x$non_provato)
  s199 <- sum(sv & x$insieme != "pulito")
  ciS <- ci(paste0(v, "_sens")); ciF <- ci(paste0(v, "_fpr"))
  data.table(variante = v, segnalati = sum(sv),
             difettosi_presi = pct(tp, nD), sens_IC95 = sprintf("[%.1f; %.1f]", 100 * ciS[1], 100 * ciS[2]),
             difettosi_provati = pct(tp_np, sum(x$insieme == "difettoso" & !x$non_provato)),
             falsi_allarmi_puliti = pct(fp, nP),
             fa_IC95_conteggio = sprintf("[%.0f; %.0f]", nP * ciF[1], nP * ciF[2]),
             altri_negativi = pct(an, nA), sui_199 = pct(s199, nD + nA))
}))
print(scala)

cat("\n== Tabella a due entrate, V3 ==\n")
print(table(regola = ifelse(x$s_V3, "segnala", "tace"), riferimento = x$insieme))

cat("\n== V3: quale regola scatta (la prima), per insieme ==\n")
print(table(regola = ifelse(x$s_V3, x$V3, "(tace)"), insieme = x$insieme))

cat("\n== V3: sensibilita' per famiglia del difetto ==\n")
print(x[insieme == "difettoso", .(confronti = .N, presi = sum(s_V3), quota = round(100 * mean(s_V3), 1)),
        by = famiglia][order(-confronti)])

cat("\n== Gruppi e studi toccati dai falsi allarmi di V3 (sui puliti) ==\n")
cat(sprintf("meta-analisi: %d; studi: %d\n", uniqueN(x[s_V3 & insieme == "pulito", cluster_id]),
            uniqueN(x[s_V3 & insieme == "pulito", study])))

cat("\n== Previsioni ==\n")
fpV3 <- sum(x$s_V3 & x$insieme == "pulito"); ciF <- ci("V3_fpr") * nP
cat(sprintf("P1 falsi allarmi V3 sui puliti: %d (atteso 45; soglia del PI 85). IC95 del conteggio [%.0f; %.0f]\n",
            fpV3, ciF[1], ciF[2]))
ciS <- ci("V3_sens")
cat(sprintf("P2 sensibilita' V3: %.1f%% IC95 [%.1f; %.1f] (atteso 30%%; intervallo [20%%; 50%%])\n",
            100 * mean(x$s_V3[x$insieme == "difettoso"]), 100 * ciS[1], 100 * ciS[2]))
tp <- sapply(VAR, function(v) sum(x[[paste0("s_", v)]] & x$insieme == "difettoso"))
fp <- sapply(VAR, function(v) sum(x[[paste0("s_", v)]] & x$insieme == "pulito"))
cat(sprintf("P3 difettosi aggiunti: V1-V0 %d, V2-V1 %d, V3-V2 %d; falsi allarmi aggiunti: %d, %d, %d\n",
            tp[2] - tp[1], tp[3] - tp[2], tp[4] - tp[3], fp[2] - fp[1], fp[3] - fp[2], fp[4] - fp[3]))
p4 <- x[(study == "GSE139963" & tl == "Hypoxia + TGF-β1") | (study == "GSE240476"), .(study, tl, V3)]
cat("P4 casi che dovevano restare invisibili:\n"); print(p4)
sink()

cols <- c("cluster_id", "study", "record_id", "tl", "cl", "entity_deliverable", "cls_regola",
          "insieme", "famiglia", VAR)
fwrite(x[, ..cols], file.path(OUT, "40-esiti.csv"))
fa <- x[s_V3 & insieme != "difettoso", .(cluster_id, study, record_id, insieme, regola = V3,
                                          trattato = tl, controllo = cl, entita = entity_deliverable,
                                          classe = cls_regola)][order(insieme, cluster_id, study)]
fwrite(fa, file.path(OUT, "40-falsi-allarmi.csv"))
fwrite(x[insieme == "difettoso" & !s_V3, .(cluster_id, study, record_id, famiglia, categoria,
                                          trattato = tl, controllo = cl)][order(famiglia)],
       file.path(OUT, "40-difetti-non-visti.csv"))
cat("Scritti 40-out.txt, 40-esiti.csv, 40-falsi-allarmi.csv, 40-difetti-non-visti.csv\n")
