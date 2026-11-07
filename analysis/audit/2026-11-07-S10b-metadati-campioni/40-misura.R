#!/usr/bin/env Rscript
# 40-misura.R — S10b: la regola sui fatti dello Stadio 1 contro il riferimento di S10.
#
# Ingressi: 30-esiti-regola.csv (10-regola.py sui 1.903 confronti); dal riferimento di S10:
# 30-riferimento.csv (129 confronti difettosi), difetti.csv (le coppie accusate), 40-esiti.csv
# (esiti V0-V3 e famiglia del difetto).
# Uscite: 40-out.txt, 40-esiti.csv, 40-falsi-allarmi.csv, 40-difetti-non-visti.csv.
# Incertezza: bootstrap degli STUDI, B = 2000, seme 20261107 (00-previsioni.md).
# Scelta della combinazione per la lettura: il criterio depositato in 00-previsioni.md, sotto.
#
# Uso: Rscript analysis/audit/2026-11-07-S10b-metadati-campioni/40-misura.R   (senza --vanilla)
suppressPackageStartupMessages(library(data.table))
OUT <- "analysis/audit/2026-11-07-S10b-metadati-campioni"
S10 <- "analysis/audit/2026-11-07-S10-rilevatore"
x <- fread(file.path(OUT, "30-esiti-regola.csv"), encoding = "UTF-8")
ref <- fread(file.path(S10, "30-riferimento.csv"), encoding = "UTF-8")
dif <- fread("analysis/audit/2026-08-20-rilettura-194/difetti.csv", encoding = "UTF-8")
e10 <- fread(file.path(S10, "40-esiti.csv"), encoding = "UTF-8")
stopifnot(nrow(x) == 1903L, !anyDuplicated(x$record_id), setequal(x$record_id, e10$record_id))

SOTTO <- c("R1", "R1c", "R2a", "R2b", "R3a", "R3b", "R3c", "R4a", "R4b", "R5", "R6", "R7")
NOMI <- c(R1 = "agente_in_piu", R1c = "agente_solo_ctrl", R2a = "tempo_diverso", R2b = "ctrl_tempo_zero",
          R3a = "sesso", R3b = "etnia", R3c = "donatore", R4a = "materiale_tipo", R4b = "linea",
          R5 = "sede", R6 = "passaggio", R7 = "genotipo", R1x = "agente_tolta_entita",
          S10_V3 = "S10 V3", S10_pulita = "S10 V1 + materiale")

# ------------------------------------------------------------- insiemi (come S10) -----
coppie_acc <- unique(paste(dif$cluster_id, dif$study_id))
x[, coppia := paste(cluster_id, study)]
x[, insieme := fifelse(record_id %in% ref$record_id, "difettoso",
                fifelse(coppia %in% coppie_acc, "altro_negativo", "pulito"))]
x[e10, on = "record_id", `:=`(famiglia = i.famiglia, V1 = i.V1, V3 = i.V3, insieme10 = i.insieme,
                              tl = i.tl, cl = i.cl)]
x[, S10_V3 := as.integer(!is.na(V3) & nzchar(V3))]
x[, S10_pulita := as.integer((!is.na(V1) & nzchar(V1)) | (!is.na(V3) & V3 == "materiale_diverso"))]
nD <- sum(x$insieme == "difettoso"); nP <- sum(x$insieme == "pulito"); nA <- sum(x$insieme == "altro_negativo")

# ------------------------------------------------------------- funzioni di misura -----
tp <- function(s) sum(s == 1L & x$insieme == "difettoso")
fp <- function(s) sum(s == 1L & x$insieme == "pulito")
an <- function(s) sum(s == 1L & x$insieme == "altro_negativo")
pct <- function(a, b) sprintf("%d/%d (%.1f%%)", a, b, 100 * a / b)
unione <- function(cols) if (length(cols)) as.integer(rowSums(as.matrix(x[, ..cols])) > 0L) else integer(nrow(x))

set.seed(20261107L)
B <- 2000L
studi <- unique(x$study)
idx_by_study <- split(seq_len(nrow(x)), x$study)
boot_idx <- replicate(B, unlist(idx_by_study[sample(studi, length(studi), replace = TRUE)],
                                use.names = FALSE), simplify = FALSE)
ci_sens_fp <- function(s) {
  r <- vapply(boot_idx, function(i) {
    ins <- x$insieme[i]; si <- s[i]
    c(sum(si == 1L & ins == "difettoso") / sum(ins == "difettoso"),
      sum(si == 1L & ins == "pulito") / sum(ins == "pulito"))
  }, numeric(2))
  list(sens = quantile(r[1, ], c(0.025, 0.975)), fp = nP * quantile(r[2, ], c(0.025, 0.975)))
}
riga <- function(nome, s, ci = TRUE) {
  c0 <- if (ci) ci_sens_fp(s) else NULL
  data.table(regola = nome, segnalati = sum(s), difettosi = pct(tp(s), nD),
             sens_IC95 = if (ci) sprintf("[%.1f; %.1f]", 100 * c0$sens[1], 100 * c0$sens[2]) else "",
             falsi_allarmi = pct(fp(s), nP),
             fa_IC95 = if (ci) sprintf("[%.0f; %.0f]", c0$fp[1], c0$fp[2]) else "",
             altri_negativi = pct(an(s), nA), sui_199 = pct(tp(s) + an(s), nD + nA))
}

sink(file.path(OUT, "40-out.txt"), split = TRUE)
cat("== Cancello C2(c): gli insiemi e V3 della S10 si riproducono ==\n")
cat(sprintf("insiemi: difettosi %d, puliti %d, altri negativi %d; uguali a quelli di S10: %s\n",
            nD, nP, nA, identical(x$insieme, x$insieme10)))
cat(sprintf("S10 V3: difettosi %d, falsi allarmi %d (attesi 10 e 51)\n", tp(x$S10_V3), fp(x$S10_V3)))
cat(sprintf("S10 V1 + materiale: difettosi %d, falsi allarmi %d (attesi 5 e 0)\n\n",
            tp(x$S10_pulita), fp(x$S10_pulita)))

cat("== Cancello C3: copertura ==\n")
cat(sprintf("confronti con un esito per tutte le sotto-regole: %d su 1903\n\n",
            sum(complete.cases(x[, c(SOTTO, "R1x", "M"), with = FALSE]))))

cat("== Cancello C4: controlli ==\n")
ctrl <- rbind(
  x[study == "GSE139963" & tl == "Hypoxia + TGF-β1", .(controllo = "pos R1 Hypoxia + TGF-b1", record_id, esito = R1)],
  x[study == "GSE126409" & grepl("time zero", cl), .(controllo = "pos R2a o R2b, tempo zero GSE126409", record_id, esito = as.integer(R2a | R2b))],
  x[study == "GSE97358" & grepl("grp_0002_vs_grp_0003", record_id), .(controllo = "pos R3b etnia GSE97358", record_id, esito = R3b)],
  x[study == "GSE139963" & tl == "TGF-β1", .(controllo = "neg M GSE139963 TGF-b1", record_id, esito = M)],
  x[study == "GSE114686" & tl == "Lapatinib 1 µM 24h", .(controllo = "neg M GSE114686 Lapatinib 1 uM 24h", record_id, esito = M)])
stopifnot(nrow(ctrl) >= 5L)
print(ctrl)
cat("\n")

cat("== Ogni sotto-regola da sola ==\n")
scala <- rbindlist(lapply(c(SOTTO, "R1x", "S10_V3", "S10_pulita"), function(s)
  cbind(sigla = s, riga(NOMI[[s]], x[[s]]))))
print(scala)

cat("\n== Scala cumulativa, nell'ordine fissato ==\n")
cum <- rbindlist(lapply(seq_along(SOTTO), function(k) {
  s <- unione(SOTTO[1:k]); cbind(fino_a = SOTTO[k], riga(NOMI[[SOTTO[k]]], s, ci = FALSE))
}))
print(cum[, .(fino_a, segnalati, difettosi, falsi_allarmi, altri_negativi)])

cat("\n== Regola completa M e combinazioni con la S10 ==\n")
x[, M_V3 := unione(c("M", "S10_V3"))]
x[, M_S10p := unione(c("M", "S10_pulita"))]
print(rbind(riga("M (12 sotto-regole)", x$M), riga("M + S10 V3", x$M_V3),
            riga("M + S10 V1 e materiale", x$M_S10p)))

cat("\n== Contributo marginale in M (che cosa si perde togliendo la sotto-regola) ==\n")
marg <- rbindlist(lapply(SOTTO, function(s) {
  m <- unione(setdiff(SOTTO, s))
  data.table(sigla = s, regola = NOMI[[s]], difettosi_persi = tp(x$M) - tp(m), falsi_allarmi_persi = fp(x$M) - fp(m))
}))
print(marg)

cat("\n== Tabella a due entrate, M ==\n")
print(table(regola = ifelse(x$M == 1L, "segnala", "tace"), riferimento = x$insieme))

cat("\n== Sensibilita' per famiglia del difetto: S10 V3, M, M + S10 V3 ==\n")
print(x[insieme == "difettoso", .(confronti = .N, V3 = sum(S10_V3), M = sum(M), M_V3 = sum(M_V3)),
        by = famiglia][order(-confronti)])

cat("\n== Visibilita': il campo della famiglia e' scritto su entrambi i bracci (difettosi) ==\n")
VIS <- c("secondo agente solo nel trattato" = "vis_agente", "tempo non appaiato" = "vis_tempo",
         "donatore / soggetto / sesso / etnia diversi" = "vis_soggetto",
         "materiale / tipo cellulare diverso fra i bracci" = "vis_materiale",
         "sede anatomica diversa" = "vis_sede", "passaggio di coltura non appaiato" = "vis_passaggio",
         "genotipo / perturbazione genetica su un braccio solo" = "vis_genotipo")
visib <- rbindlist(lapply(names(VIS), function(f) {
  z <- x[insieme == "difettoso" & famiglia == f]
  v <- z[[VIS[[f]]]] == 1L
  data.table(famiglia = f, difettosi = nrow(z), campo_scritto = sum(v), presi_M = sum(z$M),
             presi_fra_scritti = sum(z$M[v]))
}))
print(visib)

# ------------------------------------------------- scelta per la lettura (depositata) ---
cat("\n== Scelta della combinazione per la lettura (criterio depositato) ==\n")
cand <- c(SOTTO, "S10_V3", "S10_pulita")
via <- cand[vapply(cand, function(s) tp(x[[s]]) == 0L && fp(x[[s]]) >= 1L, logical(1))]
cat("passo 1, tolte perche' prendono 0 difettosi con almeno un falso allarme:",
    if (length(via)) paste(via, collapse = ", ") else "nessuna", "\n")
U <- setdiff(cand, via)
passo <- 2L
while (length(U) && fp(unione(U)) > 85L) {
  u <- unione(U)
  m <- rbindlist(lapply(U, function(s) {
    r <- unione(setdiff(U, s))
    data.table(s = s, tpm = tp(u) - tp(r), fpm = fp(u) - fp(r))
  }))[fpm > 0L]
  m[, prec := tpm / (tpm + fpm)]
  setorder(m, prec, -fpm, s)
  cat(sprintf("passo %d: falsi allarmi dell'unione %d > 85; tolgo %s (marginale: %d difettosi, %d falsi allarmi)\n",
              passo, fp(u), m$s[1], m$tpm[1], m$fpm[1]))
  U <- setdiff(U, m$s[1]); passo <- passo + 1L
}
x[, PROPOSTA := unione(U)]
recuperabile <- length(U) > 0L && tp(x$PROPOSTA) > 0L && fp(x$PROPOSTA) <= 85L
cat("combinazione proposta:", paste(U, collapse = " + "), "\n")
cat("recuperabile (almeno un difettoso, falsi allarmi <= 85):", recuperabile, "\n")
print(riga("PROPOSTA", x$PROPOSTA))

cat("\n== Previsioni ==\n")
cM <- ci_sens_fp(x$M)
cat(sprintf("P1 falsi allarmi di M sui puliti: %d (atteso 150; soglia del PI 85). IC95 del conteggio [%.0f; %.0f]\n",
            fp(x$M), cM$fp[1], cM$fp[2]))
cat(sprintf("P2 sensibilita' di M: %.1f%% IC95 [%.1f; %.1f] (atteso 35%%; intervallo [20%%; 50%%])\n",
            100 * tp(x$M) / nD, 100 * cM$sens[1], 100 * cM$sens[2]))
cat(sprintf("P3 difettosi presi da M e non da S10 V3: %d (atteso 30; rilevante sotto 10)\n",
            sum(x$M == 1L & x$S10_V3 == 0L & x$insieme == "difettoso")))
fam <- x[insieme == "difettoso", .(n = .N, V3 = sum(S10_V3), M = sum(M)), by = famiglia]
cat("P4 per famiglia, presi da M contro S10 V3 (atteso: M prende almeno uno in piu' in ognuna delle quattro):\n")
print(fam[famiglia %in% c("secondo agente solo nel trattato", "tempo non appaiato",
                          "donatore / soggetto / sesso / etnia diversi",
                          "materiale / tipo cellulare diverso fra i bracci")])
cat(sprintf("P5 quota dei falsi allarmi di M segnalati da sede (R5) o donatore (R3c): %.1f%% (atteso > 50%%)\n",
            100 * fp(unione(c("R5", "R3c")) * x$M) / max(fp(x$M), 1L)))
sink()

# ------------------------------------------------------------------- uscite ----------
cols <- c("cluster_id", "study", "record_id", "classe", "entita", "insieme", "famiglia",
          SOTTO, "R1x", "M", "S10_V3", "S10_pulita", "PROPOSTA", paste0("det_", c(SOTTO, "R1x")),
          grep("^vis_", names(x), value = TRUE))
fwrite(x[, ..cols], file.path(OUT, "40-esiti.csv"))
lab <- e10[, .(record_id, trattato = tl, controllo = cl)]
fa <- x[PROPOSTA == 1L & insieme != "difettoso"][lab, on = "record_id", nomatch = NULL]
fa[, regole := apply(.SD, 1L, function(r) paste(names(r)[r == 1L], collapse = "+")), .SDcols = U]
fwrite(fa[order(insieme, cluster_id, study), c("cluster_id", "study", "record_id", "insieme", "regole",
                                               "trattato", "controllo", "entita", "classe",
                                               paste0("det_", intersect(SOTTO, U))), with = FALSE],
       file.path(OUT, "40-falsi-allarmi.csv"))
nv <- x[insieme == "difettoso" & PROPOSTA == 0L][lab, on = "record_id", nomatch = NULL]
fwrite(nv[order(famiglia), c("cluster_id", "study", "record_id", "famiglia", "trattato", "controllo",
                             grep("^vis_", names(nv), value = TRUE)), with = FALSE],
       file.path(OUT, "40-difetti-non-visti.csv"))
cat("Scritti 40-out.txt, 40-esiti.csv, 40-falsi-allarmi.csv, 40-difetti-non-visti.csv\n")
