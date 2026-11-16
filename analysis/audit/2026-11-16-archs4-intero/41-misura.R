# 41-misura.R — la misura della prova piccola su tutto ARCHS4 (carta: 00-previsioni.md, misure a3-a7 e i conti accanto).
# Nessuna misura contro Gemma o contro Atlas: qui si contano gli esiti, l'accordo fra i due lettori e i tempi.
#
#   MODO=controllo Rscript analysis/audit/2026-11-16-archs4-intero/41-misura.R     (SENZA --vanilla)
#       controllo positivo dello strumento, senza le uscite di oggi: la regola dell'accordo sulle due corse congelate
#       di ieri (`M-rp11` e `GE-rp0`, 2.016 studi aperti di Gemma) rida' il numero noto, 1.337 studi tenuti su 2.008.
#       Scrive 41-ieri-per-studio.csv (serve anche al termine di paragone «tenuti con almeno un confronto»).
#   MODO=prova Rscript analysis/audit/2026-11-16-archs4-intero/41-misura.R
#       le quattro corse di oggi (M-rp11-casuale, M-rp11-coda, GE-rp0-casuale, GE-rp0-coda): cancelli K3, K4 (impronte
#       delle uscite), K5; misure a3-a7; i conti accanto; il giudizio delle previsioni PA3-PA7.
#
# Le funzioni della lettura e dell'accordo sono quelle di ieri, prese dal file di ieri senza copiarle a mano
# (analysis/audit/2026-11-15-lettori-su-gemma/41-misura.R: leggi_corsa, lettura_studio, chiave_gc, quota_studi, riga_q).
# «Tenuto» = i due lettori chiudono lo studio e danno gli stessi gruppi e gli stessi confronti (chiave_gc).
# «Letto» = lo studio ha un'uscita generata (il lavoratore non lo ha saltato perche' oltre il contesto).
# Unita': lo studio. B = 10.000, seme 20261116.
# Decisioni tecniche scritte prima di ogni uscita di oggi:
#   - a3 si conta per lettore: il lavoratore conta i token con il tokenizzatore del suo modello;
#   - a5: uno studio che il secondo lettore salta o non chiude non e' tenuto; il denominatore sono i letti da Mistral;
#   - a7: secondi del lavoratore piu' lento (riga «generazione completata» nel log del job) divisi per gli studi letti
#     del pezzo `casuale`; durata della corsa grande = quel numero per gli studi nuovi nell'ingresso (da
#     21-per-studio-nuovo.csv se c'e'; se lo scarico non e' finito, 21.249 per la quota dei 500 `casuale` nell'ingresso);
#   - i confronti di uno studio tenuto = i confronti della lettura di Mistral (uguali a quelli del secondo lettore);
#   - la grandezza dello studio = i campioni della vista.
# Uscite: 41-ieri-per-studio.csv, 41-per-studio.csv, 41-out-<modo>.txt.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")            # adatta_forma(), sha(), ...; legge SOLO i 47 studi di sviluppo
local({                                                                              # le funzioni di ieri, dal file di ieri
  voglio <- c("leggi_corsa", "lettura_studio", "campioni_di", "NON_CHIUSO", "chiave_gc", "quota_studi", "riga_q")
  ex <- parse("analysis/audit/2026-11-15-lettori-su-gemma/41-misura.R", encoding = "UTF-8", keep.source = FALSE); presi <- character()
  for (e in ex) if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.name(e[[2L]]) && as.character(e[[2L]]) %in% voglio) {
    eval(e, envir = globalenv()); presi <- c(presi, as.character(e[[2L]])) }
  stopifnot(setequal(presi, voglio), !anyDuplicated(presi))
})
DIR <- "analysis/audit/2026-11-16-archs4-intero"; LG <- "analysis/audit/2026-11-15-lettori-su-gemma"
SEME <- 20261116L; B <- 10000L
MODO <- Sys.getenv("MODO"); stopifnot(MODO %in% c("controllo", "prova"))
USCITE_IERI <- "analysis/p4-output/lettori-su-gemma-B0"; USCITE <- "analysis/p4-output/archs4-intero-prova-B0"
F_ING <- c(casuale = "analysis/input/archs4-b0-ingresso-prova-casuale.jsonl", coda = "analysis/input/archs4-b0-ingresso-prova-coda.jsonl")
sink(file.path(DIR, sprintf("41-out-%s.txt", MODO)), split = TRUE)
cat("41-misura.R  MODO=", MODO, " ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n", sep = "")
passa <- function(che, ok, dett = "") {
  cat(sprintf("%s  %s%s\n", if (isTRUE(ok)) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else ""))
  if (!isTRUE(ok)) { sink(); stop("CANCELLO FALLITO: ", che, call. = FALSE) }
}
leggi_viste <- function(f) { v <- lapply(readLines(f, warn = FALSE, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
  names(v) <- vapply(v, `[[`, "", "record_id"); stopifnot(!anyDuplicated(names(v))); v }
# Il validatore di ogni studio resta nella cache `.validatori_forma`: si svuota dopo ogni studio (come ieri).
letture_di <- function(x, V) stats::setNames(lapply(seq_along(x), function(i) { g <- names(x)[i]
  r <- lettura_studio(V[[g]], x[[g]])
  rm(list = ls(.validatori_forma), envir = .validatori_forma); if (i %% 25L == 0L) invisible(gc())
  r }), names(x))
# la tabella per studio di due corse (primo e secondo lettore) sugli stessi studi
tabella <- function(XM, XG, V) {
  stopifnot(identical(names(XM), names(XG)), all(names(XM) %in% names(V)))
  LM <- letture_di(XM, V); LS <- letture_di(XG, V)
  km <- vapply(LM, chiave_gc, ""); kg <- vapply(LS, chiave_gc, "")
  esito <- function(X, k) ifelse(vapply(X, e_saltato, NA), "oltre_contesto", ifelse(k == NON_CHIUSO, "non_chiuso", "chiuso"))
  data.frame(gse = names(XM), campioni = vapply(names(XM), function(g) length(campioni_di(V[[g]])), 1L),
             esito_M = esito(XM, km), esito_GE = esito(XG, kg), chiave_M = unname(km), chiave_GE = unname(kg),
             tenuto = unname(km != NON_CHIUSO & kg != NON_CHIUSO & km == kg),
             gruppi_M = vapply(LM, function(r) if (isTRUE(r$chiuso)) length(unique(unname(r$partizione))) else NA_integer_, 1L),
             confronti_M = vapply(LM, function(r) if (isTRUE(r$chiuso)) nrow(r$confronti) else NA_integer_, 1L),
             stringsAsFactors = FALSE, row.names = NULL)
}
conti_tenuti <- function(d, nome) {
  t <- d[d$tenuto, ]
  cat(sprintf("  %s: tenuti %d; tenuti con almeno un confronto %d (%.1f%% dei tenuti, %.1f%% dei letti da Mistral); confronti negli studi tenuti %d (mediana per studio con confronti %.0f)\n",
              nome, nrow(t), sum(t$confronti_M > 0), 100 * mean(t$confronti_M > 0), 100 * sum(t$confronti_M > 0) / sum(d$esito_M != "oltre_contesto"),
              sum(t$confronti_M), if (any(t$confronti_M > 0)) stats::median(t$confronti_M[t$confronti_M > 0]) else NA))
}
impronte_di <- function(f) { x <- readLines(f); stats::setNames(sub("  .*$", "", x), sub("^[0-9a-f]+  ", "", x)) }

VG <- leggi_viste("analysis/input/gemma-viste-v0.jsonl")
imp_ieri <- impronte_di(file.path(LG, "40-uscite-sha256.txt"))
apri_ieri <- function(corsa) { f <- file.path(USCITE_IERI, paste0(corsa, ".jsonl"))
  passa(sprintf("l'uscita di ieri %s ha l'impronta congelata", corsa), identical(sha(f), unname(imp_ieri[f]))); leggi_corsa(f) }

if (MODO == "controllo") {
  # ---- controllo positivo: la regola dell'accordo sulle corse di ieri rida' 1.337 tenuti su 2.008 ----
  XM <- apri_ieri("M-rp11"); XG <- apri_ieri("GE-rp0"); XG <- XG[names(XM)]
  d <- tabella(XM, XG, VG)
  letti <- d$esito_M != "oltre_contesto"
  passa("CONTROLLO POSITIVO: studi tenuti sulle corse di ieri = 1.337 su 2.008 letti da Mistral",
        sum(d$tenuto) == 1337L && sum(letti) == 2008L && nrow(d) == 2016L, sprintf("%d su %d (studi nell'ingresso %d)", sum(d$tenuto), sum(letti), nrow(d)))
  utils::write.csv(d, file.path(DIR, "41-ieri-per-studio.csv"), row.names = FALSE, na = "")
  cat("Termine di paragone, studi aperti di Gemma di ieri (nessuna misura contro i curatori):\n"); conti_tenuti(d, "ieri")
  cat("FINE 41-misura.R (controllo)\n"); sink(); quit(save = "no", status = 0L)
}

# ---- la prova: ingressi, viste, uscite -----------------------------------------------------------------------
el <- utils::read.csv(file.path(DIR, "10-elenco.csv"), stringsAsFactors = FALSE)
giud <- utils::read.delim("analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv", stringsAsFactors = FALSE)$gse   # sviluppo e giudizio
passa("K4 gli ingressi hanno le impronte di 21-ingresso-sha256-prova.txt",
      identical(sprintf("%s  %s", vapply(F_ING, sha, ""), F_ING), readLines(file.path(DIR, "21-ingresso-sha256-prova.txt"))))
ID <- lapply(F_ING, function(f) sub('^\\{"record_id":"(GSE[0-9]+)".*$', "\\1", readLines(f, warn = FALSE, encoding = "UTF-8")))
V <- c(leggi_viste("analysis/input/archs4-viste-v0-prova.jsonl"), VG[el$gse[el$prova == "controllo"]])
imp_oggi <- impronte_di(file.path(DIR, "40-uscite-sha256.txt"))
apri <- function(corsa, pezzo) { f <- file.path(USCITE, paste0(corsa, ".jsonl"))
  passa(sprintf("K4 l'uscita %s ha l'impronta congelata", corsa), file.exists(f) && identical(sha(f), unname(imp_oggi[f])))
  x <- leggi_corsa(f); cl <- el$classe[match(names(x), el$gse)]
  passa(sprintf("K5 %s: nessuno studio di giudizio, di sviluppo o chiuso di Gemma", corsa), !any(names(x) %in% giud) && all(cl %in% c("nuovo", "gemma_aperta")))
  passa(sprintf("K3 %s: un record per ogni studio mandato", corsa), setequal(names(x), ID[[pezzo]]), sprintf("%d su %d", length(x), length(ID[[pezzo]])))
  x[ID[[pezzo]]] }
D <- list()
for (pz in names(F_ING)) { d <- tabella(apri(paste0("M-rp11-", pz), pz), apri(paste0("GE-rp0-", pz), pz), V); d$pezzo <- pz; D[[pz]] <- d }
D <- do.call(rbind, D); D$prova <- el$prova[match(D$gse, el$gse)]; rownames(D) <- NULL
passa("K3 ogni studio mandato ha un esito per ognuno dei due lettori", !anyNA(D$esito_M) && !anyNA(D$esito_GE) && nrow(D) == sum(lengths(ID)),
      sprintf("%d studi", nrow(D)))

# ---- a6: i 50 studi di controllo contro le corse di ieri -------------------------------------------------------
ctrl <- D$gse[D$prova == "controllo"]; stopifnot(length(ctrl) == 50L)
ieri <- utils::read.csv(file.path(DIR, "41-ieri-per-studio.csv"), stringsAsFactors = FALSE); ieri <- ieri[match(ctrl, ieri$gse), ]
XMi <- apri_ieri("M-rp11")[ctrl]; XMo <- leggi_corsa(file.path(USCITE, "M-rp11-coda.jsonl"))[ctrl]
XGi <- apri_ieri("GE-rp0")[ctrl]; XGo <- leggi_corsa(file.path(USCITE, "GE-rp0-coda.jsonl"))[ctrl]
ug <- function(a, b) vapply(ctrl, function(g) identical(as.character(nullo(a[[g]]$raw)), as.character(nullo(b[[g]]$raw))) && identical(e_saltato(a[[g]]), e_saltato(b[[g]])), NA)
dc <- D[match(ctrl, D$gse), ]
a6 <- c(M_carattere = sum(ug(XMi, XMo)), GE_carattere = sum(ug(XGi, XGo)), M_chiave = sum(dc$chiave_M == ieri$chiave_M), GE_chiave = sum(dc$chiave_GE == ieri$chiave_GE),
        tenuto_uguale = sum(dc$tenuto == ieri$tenuto))
D$uguale_a_ieri_M <- NA; D$uguale_a_ieri_GE <- NA
D$uguale_a_ieri_M[match(ctrl, D$gse)] <- dc$chiave_M == ieri$chiave_M; D$uguale_a_ieri_GE[match(ctrl, D$gse)] <- dc$chiave_GE == ieri$chiave_GE
utils::write.csv(D[, setdiff(names(D), c("chiave_M", "chiave_GE"))], file.path(DIR, "41-per-studio.csv"), row.names = FALSE, na = "")

# ---- a7: i tempi dai log dei job --------------------------------------------------------------------------------
tempi <- function(corsa) { j <- readRDS(file.path(DIR, "jobs", paste0(corsa, ".rds")))
  lg <- unlist(lapply(list.files(file.path("analysis/p4-output", j$run_id), pattern = "^slurm-.*[.]out$", full.names = TRUE), readLines, warn = FALSE))
  m <- regmatches(lg, regexec("\\[worker ([0-9]+)\\] generazione completata in ([0-9.]+)s \\(([0-9]+) record\\)", lg)); m <- m[lengths(m) == 4L]
  data.frame(corsa = corsa, worker = as.integer(vapply(m, `[`, "", 2)), secondi = as.numeric(vapply(m, `[`, "", 3)), record = as.integer(vapply(m, `[`, "", 4))) }
TM <- do.call(rbind, lapply(c("M-rp11-casuale", "GE-rp0-casuale", "M-rp11-coda", "GE-rp0-coda"), tempi))
f_nuovo <- file.path(DIR, "21-per-studio-nuovo.csv")
cas <- D[D$pezzo == "casuale", ]
N_GRANDE <- if (file.exists(f_nuovo)) { x <- utils::read.csv(f_nuovo, stringsAsFactors = FALSE); sum(x$esito == "nell_ingresso") } else round(21249 * nrow(cas) / 500)

# ---- le misure e il giudizio delle previsioni ------------------------------------------------------------------
giudica <- function(basso, alto, lo, hi) if (basso >= lo && alto <= hi) "confermata" else if (alto < lo || basso > hi) "smentita" else "indeterminata"
riga_p <- function(nome, q, lo, hi) cat(sprintf("  %s; intervallo di rilevanza %g-%g%%: %s\n", riga_q(nome, q), lo, hi, giudica(100 * q[["ic_basso"]], 100 * q[["ic_alto"]], lo, hi)))
letto_M <- cas$esito_M != "oltre_contesto"; letto_G <- cas$esito_GE != "oltre_contesto"
cat(sprintf("\nMisure sul pezzo `casuale` (%d studi nell'ingresso su 500 estratti; B = 10.000, seme 20261116, unita' lo studio):\n", nrow(cas)))
riga_p("a3 oltre il contesto, Mistral (PA3)", quota_studi(as.integer(!letto_M), B, SEME), 0, 2)
riga_p("a3 oltre il contesto, Gemma-4-31B (PA3)", quota_studi(as.integer(!letto_G), B, SEME), 0, 2)
riga_p("a4 chiusi da Mistral su letti (PA4)", quota_studi(as.integer(cas$esito_M[letto_M] == "chiuso"), B, SEME), 88, 98)
riga_p("a4 chiusi da Gemma-4-31B su letti (PA4b)", quota_studi(as.integer(cas$esito_GE[letto_G] == "chiuso"), B, SEME), 92, 100)
riga_p("a5 studi tenuti su letti da Mistral (PA5)", quota_studi(as.integer(cas$tenuto[letto_M]), B, SEME), 50, 80)
cat("\nMisure sui 50 studi di `controllo` (contro le corse di ieri):\n")
cat(sprintf("  a6 Mistral, uscita uguale al carattere a ieri: %d su 50 (PA6, atteso 50 su 50: %s)\n", a6[["M_carattere"]], if (a6[["M_carattere"]] == 50L) "confermata" else "smentita"))
cat(sprintf("  a6 Mistral, stessi gruppi e confronti di ieri: %d su 50\n", a6[["M_chiave"]]))
cat(sprintf("  a6 Gemma-4-31B, stessi gruppi e confronti di ieri: %d su 50 (PA6b, intervallo 45-50: %s); uscita uguale al carattere %d su 50\n",
            a6[["GE_chiave"]], if (a6[["GE_chiave"]] >= 45L) "confermata" else "smentita", a6[["GE_carattere"]]))
cat(sprintf("  studi con lo stesso esito della regola dell'accordo (tenuto o non tenuto) di ieri: %d su 50; tenuti oggi %d, ieri %d\n", a6[["tenuto_uguale"]], sum(dc$tenuto), sum(ieri$tenuto)))
if (any(dc$chiave_M != ieri$chiave_M)) cat("  Mistral, studi diversi da ieri:", paste(ctrl[dc$chiave_M != ieri$chiave_M], collapse = ", "), "\n")
if (any(dc$chiave_GE != ieri$chiave_GE)) cat("  Gemma-4-31B, studi diversi da ieri:", paste(ctrl[dc$chiave_GE != ieri$chiave_GE], collapse = ", "), "\n")
cat("\nTempi (righe «generazione completata» dei log):\n"); print(TM, row.names = FALSE)
cat(sprintf("  studi nuovi nell'ingresso della corsa grande: %d (%s)\n", N_GRANDE, if (file.exists(f_nuovo)) "da 21-per-studio-nuovo.csv" else "STIMA: lo scarico non e' finito"))
for (k in c("M-rp11", "GE-rp0")) {
  t <- TM[TM$corsa == paste0(k, "-casuale"), ]; n <- if (k == "M-rp11") sum(letto_M) else sum(letto_G); s <- max(t$secondi) / n; ore <- s * N_GRANDE / 3600
  lim <- if (k == "M-rp11") c(5, 14) else c(11, 30)
  cat(sprintf("  a7 %s: lavoratore piu' lento %.0f s, studi letti %d, %.2f secondi per studio; corsa grande su 4 GPU: %.1f ore (PA7, intervallo %g-%g ore: %s)\n",
              k, max(t$secondi), n, s, ore, lim[1], lim[2], if (ore >= lim[1] && ore <= lim[2]) "dentro" else "fuori"))
}

cat("\nAccanto, senza previsione:\n")
conti_tenuti(cas, "casuale")
ieri_tutti <- utils::read.csv(file.path(DIR, "41-ieri-per-studio.csv"), stringsAsFactors = FALSE); conti_tenuti(ieri_tutti, "studi aperti di Gemma di ieri")
cl <- function(n) cut(n, c(0, 3, 12, 48, Inf), labels = c("fino a 3 campioni", "4-12 campioni", "13-48 campioni", "oltre 48 campioni"))
cas$grandezza <- cl(cas$campioni); ieri_tutti$grandezza <- cl(ieri_tutti$campioni)
cat("  per grandezza dello studio, pezzo `casuale` (fra parentesi gli studi aperti di Gemma di ieri):\n")
for (lv in levels(cas$grandezza)) {
  d <- cas[cas$grandezza == lv & cas$esito_M != "oltre_contesto", ]; e <- ieri_tutti[ieri_tutti$grandezza == lv & ieri_tutti$esito_M != "oltre_contesto", ]
  cat(sprintf("    %-18s letti da Mistral %3d | chiusi da Mistral %3d (%.0f%%) | chiusi da Gemma-4-31B %3d | tenuti %3d (%.0f%%; ieri %d/%d = %.0f%%) | tenuti con confronti %3d\n",
              lv, nrow(d), sum(d$esito_M == "chiuso"), 100 * mean(d$esito_M == "chiuso"), sum(d$esito_GE == "chiuso"), sum(d$tenuto), 100 * mean(d$tenuto),
              sum(e$tenuto), nrow(e), 100 * mean(e$tenuto), sum(d$tenuto & d$confronti_M > 0)))
}
gr <- D[D$prova == "grandi", ]
cat(sprintf("  i %d studi `grandi` nell'ingresso (su 40 estratti): campioni %d-%d\n", nrow(gr), min(gr$campioni), max(gr$campioni)))
cat("    esiti di Mistral:     ", paste(names(table(gr$esito_M)), table(gr$esito_M), collapse = ", "), "\n")
cat("    esiti di Gemma-4-31B: ", paste(names(table(gr$esito_GE)), table(gr$esito_GE), collapse = ", "), "\n")
cat(sprintf("    tenuti %d; tenuti con almeno un confronto %d\n", sum(gr$tenuto), sum(gr$tenuto & gr$confronti_M > 0)))
cat("\nFINE 41-misura.R\n"); sink()
