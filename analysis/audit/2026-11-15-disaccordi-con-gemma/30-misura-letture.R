# 30-misura-letture.R — la misura delle due letture delle schede (carta: 00-previsioni.md, Parte 2; PD7-PD11, KD3, KD5 iii).
#
#   Rscript analysis/audit/2026-11-15-disaccordi-con-gemma/30-misura-letture.R confronta > .../30-confronta-out.txt 2>&1
#   Rscript analysis/audit/2026-11-15-disaccordi-con-gemma/30-misura-letture.R misura    > .../30-out.txt 2>&1
#
# Fase «confronta»: legge i giudizi delle due letture (30-letture/L1-*.json, L2-*.json), controlla la copertura, calcola
# la causa di ogni scheda in ogni lettura con la chiave e scrive 30-da-decidere.csv: le schede dove le due cause sono
# diverse, con i giudizi delle due letture e SENZA la chiave (non dice quale disegno è del lettore).
# Fase «misura»: legge 31-decisioni.csv (i miei giudizi sulle schede da decidere, scritti senza aprire la chiave) e misura.
#
# Decisioni tecniche, scritte prima di vedere un giudizio:
#   - la causa viene dai due giudizi (lettore, Gemma) così: lettore `sostenuto` e Gemma `sostenuto` = scelte_diverse;
#     lettore `sostenuto` e Gemma `errore` = errore_del_curatore; lettore `sostenuto` e Gemma `non_verificabile` =
#     fuori_vista; lettore `errore` o `non_verificabile` e Gemma `errore` = errore_di_tutti_e_due; lettore `errore` o
#     `non_verificabile` e Gemma `sostenuto` o `non_verificabile` = errore_del_lettore. L'ultimo caso con Gemma
#     `non_verificabile` la carta non lo scrive alla lettera («Gemma no»): si conta a parte, accanto;
#   - la causa finale di una scheda: la causa comune alle due letture; se sono diverse, la causa dai miei giudizi;
#   - quote pesate per classe: peso della voce = voci della classe fra le 545 / voci della classe nel campione;
#   - intervallo: ricampionamento delle voci dentro le classi (ogni voce del campione è uno studio GEO diverso:
#     controllato), B = 10.000, seme 20261115, percentili 2,5 e 97,5;
#   - kappa di Cohen sulla causa, sulle 120 schede del campione, non pesato (le esche a parte);
#   - PD11: quota pesata; la quota non pesata accanto.
QUI <- "analysis/audit/2026-11-15-disaccordi-con-gemma"; FUORI <- "analysis/p4-output/disaccordi-con-gemma"
FASE <- commandArgs(trailingOnly = TRUE)[1]; stopifnot(FASE %in% c("confronta", "misura"))
B <- 10000L; SEME <- 20261115L; GIUD <- c("errore", "non_verificabile", "sostenuto")
CAUSE <- c("errore_del_lettore", "errore_di_tutti_e_due", "scelte_diverse", "errore_del_curatore", "fuori_vista")
campo <- function(z, n) if (is.null(z[[n]])) NA_character_ else as.character(z[[n]])
leggi <- function(let) do.call(rbind, lapply(sort(list.files(file.path(QUI, "30-letture"), sprintf("^%s-[0-9]+\\.json$", let), full.names = TRUE)), function(f) {
  do.call(rbind, lapply(jsonlite::fromJSON(f, simplifyVector = FALSE), function(z) data.frame(scheda = campo(z, "scheda"), fine = isTRUE(z$letta_fino_alla_fine),
    A = tolower(trimws(campo(z, "A"))), A_tipo = campo(z, "A_tipo"), A_prova = campo(z, "A_prova"), B = tolower(trimws(campo(z, "B"))), B_tipo = campo(z, "B_tipo"),
    B_prova = campo(z, "B_prova"), agente = sub("\\.json$", "", basename(f)), stringsAsFactors = FALSE))) }))
causa <- function(l, g) ifelse(l == "sostenuto", unname(c(sostenuto = "scelte_diverse", errore = "errore_del_curatore", non_verificabile = "fuori_vista")[g]),
                               ifelse(g == "errore", "errore_di_tutti_e_due", "errore_del_lettore"))
kappa <- function(x, y) { l <- union(x, y); t <- table(factor(x, l), factor(y, l)); po <- sum(diag(t)) / sum(t); pe <- sum(rowSums(t) * colSums(t)) / sum(t)^2; (po - pe) / (1 - pe) }
ch <- utils::read.csv(file.path(FUORI, "20-chiave.csv"), stringsAsFactors = FALSE)
L1 <- leggi("L1"); L2 <- leggi("L2")
cat("== KD3 (lettura)\n")
for (z in list(L1 = L1, L2 = L2)) cat(sprintf("schede giudicate: %d, distinte %d, tutte le 124: %s; lette fino alla fine: %d; giudizi nell'elenco: %s\n", nrow(z), length(unique(z$scheda)),
  setequal(z$scheda, ch$scheda), sum(z$fine), all(z$A %in% GIUD, z$B %in% GIUD)))
kd3 <- all(vapply(list(L1, L2), function(z) nrow(z) == 124L && setequal(z$scheda, ch$scheda) && all(z$fine) && all(z$A %in% GIUD, z$B %in% GIUD), NA))
cat(sprintf("KD3 (lettura): %s; schede tagliate: 0 (20-out.txt: nessuna riga oltre 1.900 caratteri, nessuna scheda oltre 2.000 righe)\n", if (kd3) "PASSA" else "FALLISCE")); stopifnot(kd3)
L1 <- L1[match(ch$scheda, L1$scheda), ]; L2 <- L2[match(ch$scheda, L2$scheda), ]
lato <- function(z, chi) ifelse((ch$lato_lettore == "A") == (chi == "lettore"), z$A, z$B)
tipo <- function(z, chi) ifelse((ch$lato_lettore == "A") == (chi == "lettore"), z$A_tipo, z$B_tipo)
ch$l1_lettore <- lato(L1, "lettore"); ch$l1_gemma <- lato(L1, "gemma"); ch$l2_lettore <- lato(L2, "lettore"); ch$l2_gemma <- lato(L2, "gemma")
ch$causa1 <- causa(ch$l1_lettore, ch$l1_gemma); ch$causa2 <- causa(ch$l2_lettore, ch$l2_gemma)
if (FASE == "confronta") {
  d <- ch$causa1 != ch$causa2
  out <- data.frame(scheda = ch$scheda, L1_A = L1$A, L1_A_tipo = L1$A_tipo, L1_A_prova = L1$A_prova, L1_B = L1$B, L1_B_tipo = L1$B_tipo, L1_B_prova = L1$B_prova,
                    L2_A = L2$A, L2_A_tipo = L2$A_tipo, L2_A_prova = L2$A_prova, L2_B = L2$B, L2_B_tipo = L2$B_tipo, L2_B_prova = L2$B_prova, stringsAsFactors = FALSE)[d, ]
  utils::write.csv(out, file.path(QUI, "30-da-decidere.csv"), row.names = FALSE)
  cat(sprintf("schede con la stessa causa nelle due letture: %d su 124; da decidere: %d (30-da-decidere.csv, senza la chiave)\n", sum(!d), sum(d)))
  cat(sprintf("giudizi uguali disegno per disegno: A %d su 124, B %d su 124\n", sum(L1$A == L2$A), sum(L1$B == L2$B)))
  quit(save = "no")
}
dec <- utils::read.csv(file.path(QUI, "31-decisioni.csv"), stringsAsFactors = FALSE)
da <- ch$scheda[ch$causa1 != ch$causa2]; stopifnot(setequal(dec$scheda, da), all(dec$A %in% GIUD, dec$B %in% GIUD))
dec <- dec[match(ch$scheda, dec$scheda), ]
ch$f_lettore <- ifelse(ch$causa1 == ch$causa2, ch$l1_lettore, ifelse(ch$lato_lettore == "A", dec$A, dec$B))
ch$f_gemma <- ifelse(ch$causa1 == ch$causa2, ch$l1_gemma, ifelse(ch$lato_lettore == "A", dec$B, dec$A))
ch$causa <- ifelse(ch$causa1 == ch$causa2, ch$causa1, causa(ch$f_lettore, ch$f_gemma)); ch$decisa_da_me <- ch$causa1 != ch$causa2
ch$tipo1_lettore <- tipo(L1, "lettore"); ch$tipo2_lettore <- tipo(L2, "lettore"); ch$tipo1_gemma <- tipo(L1, "gemma"); ch$tipo2_gemma <- tipo(L2, "gemma")
cen <- utils::read.csv(file.path(QUI, "10-censimento-voci.csv"), stringsAsFactors = FALSE, check.names = FALSE)
ch <- merge(ch, cen[c("studio", "classe", "classe_GE-rp0", "classe_haiku-corsa1", "classe_sonnet-corsa1")], by = "studio", all.x = TRUE); ch <- ch[order(ch$scheda), ]
utils::write.csv(ch, file.path(QUI, "30-cause-per-scheda.csv"), row.names = FALSE)
es <- ch[ch$classe_gruppi == "esca", ]; s <- ch[ch$classe_gruppi != "esca", ]; stopifnot(nrow(s) == 120L, !anyDuplicated(s$gse))
cat("\n== KD5 (iii): le esche\n"); print(es[c("scheda", "gse", "l1_lettore", "l1_gemma", "l2_lettore", "l2_gemma", "causa1", "causa2", "causa")], row.names = FALSE)
k53 <- all(es$l1_lettore[es$gse %in% c("GSE46665", "GSE60340")] == "errore", es$l2_lettore[es$gse %in% c("GSE46665", "GSE60340")] == "errore")
cat(sprintf("KD5 (iii) tutte e due le letture danno `errore` al disegno del lettore in GSE46665 e GSE60340: %s\n", if (k53) "PASSA" else "FALLISCE"))
cat(sprintf("accanto: esche GSE51261 e GSE71289 con causa finale scelte_diverse: %d su 2\n", sum(es$causa[es$gse %in% c("GSE51261", "GSE71289")] == "scelte_diverse")))
N <- c(piu_fine = 307L, piu_grossa = 156L, incrociata = 82L); s$w <- N[s$classe_gruppi] / as.integer(table(s$classe_gruppi)[s$classe_gruppi])
altri <- with(s, (!is.na(`classe_GE-rp0`) & `classe_GE-rp0` == "identica") | (!is.na(`classe_haiku-corsa1`) & `classe_haiku-corsa1` == "identica") | (!is.na(`classe_sonnet-corsa1`) & `classe_sonnet-corsa1` == "identica"))
q <- function(x, w) sum(w[x]) / sum(w)
stat <- function(i) { z <- s[i, ]; a <- altri[i]; el <- z$causa == "errore_del_lettore"; sd <- z$causa == "scelte_diverse"
  c(PD7 = q(z$causa %in% c("errore_del_lettore", "errore_di_tutti_e_due"), z$w), PD8 = q(sd, z$w), PD9 = q(z$causa %in% c("errore_del_curatore", "fuori_vista"), z$w),
    PD10 = kappa(z$causa1, z$causa2), PD11 = q(a[el], z$w[el]) - q(a[sd], z$w[sd]), PD11_nonpesata = mean(a[el]) - mean(a[sd]),
    vapply(CAUSE, function(k) q(z$causa == k, z$w), 0), curatore_errore = q(z$f_gemma == "errore", z$w), lettore_errore_stretto = q(z$f_lettore == "errore", z$w),
    PD7_lettura1 = q(z$causa1 %in% c("errore_del_lettore", "errore_di_tutti_e_due"), z$w), PD7_lettura2 = q(z$causa2 %in% c("errore_del_lettore", "errore_di_tutti_e_due"), z$w)) }
set.seed(SEME); idx <- split(seq_len(nrow(s)), s$classe_gruppi); oss <- stat(seq_len(nrow(s)))
bo <- t(vapply(seq_len(B), function(b) stat(unlist(lapply(idx, function(i) i[sample.int(length(i), replace = TRUE)]))), oss))
ic <- apply(bo, 2, stats::quantile, c(0.025, 0.975), na.rm = TRUE)
cat("\n== le due letture\n"); cat(sprintf("schede del campione con la stessa causa: %d su 120; decise da me: %d\n", sum(!s$decisa_da_me), sum(s$decisa_da_me)))
cat("causa nella lettura 1 (righe) e nella lettura 2 (colonne), campione:\n"); print(table(factor(s$causa1, CAUSE), factor(s$causa2, CAUSE)))
cat("\n== cause finali per classe dei gruppi (voci del campione)\n"); print(table(factor(s$causa, CAUSE), s$classe_gruppi))
cat("\n== cause finali per classe del censimento (voci del campione)\n"); print(table(factor(s$causa, CAUSE), s$classe))
cat("\n== quote pesate, con l'intervallo al 95%\n")
for (n in names(oss)) cat(if (grepl("^PD1[01]", n)) sprintf("%s: %+.3f (IC95 %+.3f, %+.3f)\n", n, oss[n], ic[1, n], ic[2, n]) else sprintf("%s: %.1f%% (IC95 %.1f-%.1f%%)\n", n, 100 * oss[n], 100 * ic[1, n], 100 * ic[2, n]))
cat(sprintf("\nvoci con un errore di lettura del lettore sulle 2.052 = 545 x PD7 / 2.052: %.1f%% (IC95 %.1f-%.1f%%), cioe' circa %.0f voci (%.0f-%.0f); accanto, le voci non chiuse: 130 (6,3%%)\n",
  100 * 545 * oss["PD7"] / 2052, 100 * 545 * ic[1, "PD7"] / 2052, 100 * 545 * ic[2, "PD7"] / 2052, 545 * oss["PD7"], 545 * ic[1, "PD7"], 545 * ic[2, "PD7"]))
cat(sprintf("caso che la carta non scrive alla lettera (lettore errore o non verificabile, Gemma non verificabile), contato in errore_del_lettore: %d voci del campione\n",
  sum(s$f_lettore != "sostenuto" & s$f_gemma == "non_verificabile")))
cat(sprintf("giudizio finale del disegno del lettore: %s\n", paste(sprintf("%s %d", names(table(s$f_lettore)), as.integer(table(s$f_lettore))), collapse = ", ")))
cat(sprintf("giudizio finale del disegno di Gemma: %s\n", paste(sprintf("%s %d", names(table(s$f_gemma)), as.integer(table(s$f_gemma))), collapse = ", ")))
cat("\n== tipo dell'errore (a, b, c, d) nelle due letture, campione\n")
for (n in c("tipo1_lettore", "tipo2_lettore", "tipo1_gemma", "tipo2_gemma")) { t <- table(s[[n]][nzchar(s[[n]]) & !is.na(s[[n]])]); cat(sprintf("%s: %s\n", n, paste(sprintf("%s %d", names(t), as.integer(t)), collapse = ", "))) }
cat("\n== almeno un altro lettore identico a Gemma, per causa finale (campione, non pesato)\n"); print(table(factor(s$causa, CAUSE), altri))
cat("\nfine ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n")
