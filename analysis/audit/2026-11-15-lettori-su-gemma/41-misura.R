# 41-misura.R — la misura dei lettori sulla parte APERTA degli studi di Gemma (carta: 00-previsioni.md).
#
#   Rscript analysis/audit/2026-11-15-lettori-su-gemma/41-misura.R > .../41-out.txt 2>&1      (SENZA --vanilla)
#   SOLO_CONTROLLO=1   solo il controllo positivo sui 21 studi di sviluppo (non servono le uscite sugli studi di Gemma)
#   CORSA=M-rp11       la corsa del primo lettore (default M-rp11)
#   REPLICA=M-rp11r    la replica (default M-rp11r; se il file non esiste, m6 non si fa e lo script lo dice)
#   SECONDO=<corsa>    la corsa del secondo lettore ammesso dalla sua regola (senza: m7 e m8 non si fanno)
#
# Che cosa fa, nell'ordine:
#   K1  riproduzione: Mistral B0 sui 47 studi di sviluppo rida' 45 chiusi, 36/47, 68/95 contro Atlas;
#       controllo positivo dello strumento: la funzione che misura le voci di Gemma (misura_voci, la stessa usata
#       sotto) sui 21 studi di sviluppo con la corsa congelata B0 rida' riga per riga 31-pilota-per-studio.csv
#       (14/21, 26/52, 19/41). Gemma contro Gemma su tutte le voci sta in 31-out-controllo-positivo.txt.
#   K2  l'ingresso ha l'impronta di 22-ingresso-sha256.txt; le uscite hanno le impronte di 40-uscite-sha256.txt.
#   K5  nelle uscite nessuno studio della parte chiusa, di giudizio o di sviluppo.
#   K3  un esito per ognuno dei 2.024 studi aperti: senza_vista, nessuna_colonna_variabile, oltre_contesto,
#       non_chiuso, misurato. La somma e' 2.024.
#   m1-m8 e le classi accanto, come nella carta. Unita' del ricampionamento: lo studio GEO; B = 10.000; seme 20261115.
#
# Decisioni tecniche (scritte prima di ogni uscita di un modello sugli studi di Gemma):
#   - «mandato al modello» = lo studio ha un'uscita generata (carta, m1): escono gli studi senza colonne non
#     costanti e gli studi che il lavoratore salta perche' oltre il contesto;
#   - una voce di Gemma senza nessun campione nella vista non si puo' misurare: si conta a parte e non entra in m3-m5;
#   - la chiave dell'accordo fra due letture (m6, m7) = gruppi + confronti come insiemi di campioni, come nella
#     misura del secondo lettore (24-misura.R); m7 chiede che tutte e due le letture siano chiuse; in m6 due letture
#     non chiuse hanno la stessa chiave e si contano a parte;
#   - la grandezza dello studio = i campioni della vista; il numero di fattori di Gemma = la colonna `fattori` di
#     30-esiti.csv (i fattori che l'adattatore tiene).
# Uscite: 41-per-voce-<corsa>.csv, 41-esiti-studi-<corsa>.csv, 41-riassunto-<corsa>.csv.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")            # legge SOLO i 47 studi di sviluppo
source("analysis/audit/2026-11-15-lettori-su-gemma/30-misura-contro-gemma.R")      # LG, G, misura_contro_gemma, ...
SEME <- 20261115L; B <- 10000L
USCITE_G <- "analysis/p4-output/lettori-su-gemma-B0"
F_VISTE <- "analysis/input/gemma-viste-v0.jsonl"; F_INGRESSO <- "analysis/input/gemma-b0-ingresso-aperta.jsonl"
CORSA <- Sys.getenv("CORSA", "M-rp11"); REPLICA <- Sys.getenv("REPLICA", "M-rp11r"); SECONDO <- Sys.getenv("SECONDO")
passa <- function(che, ok, dett = "") {
  cat(sprintf("%s  %s%s\n", if (isTRUE(ok)) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else ""))
  if (!isTRUE(ok)) stop("CANCELLO FALLITO: ", che, call. = FALSE)
}
scrivi_csv <- function(d, f) utils::write.csv(d, file.path(LG, f), row.names = FALSE, na = "")
cat("41-misura.R ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "\n")

# ---- funzioni comuni al controllo positivo e alla misura ------------------------------------------------------
el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
es <- utils::read.csv(file.path(G, "30-esiti.csv"), stringsAsFactors = FALSE)
voci <- es[es$esito == "tabella", ]; voci$gse <- el$gse[match(voci$shortName, el$shortName)]
voci <- voci[order(voci$gse, voci$shortName, method = "radix"), ]
stopifnot(!anyNA(voci$gse), !any(voci$parte %in% c("giudizio_A", "giudizio_B")))        # nessuno studio di giudizio
tab_gemma <- function(nome, gse) { x <- gemma_leggi(nome); gemma_tabella(x$campioni, x$analisi, gse) }
leggi_corsa <- function(f) { x <- leggi_jsonl(f); names(x) <- vapply(x, `[[`, "", "record_id"); stopifnot(!anyDuplicated(names(x))); x }
lettura_studio <- function(v, x) adatta_forma(v, as.character(nullo(x$raw)), e_saltato(x), as.character(nullo(x$fine)), "B0")
campioni_di <- function(v) as.character(unlist(v$campioni))
NON_CHIUSO <- "non chiuso non chiuso"
chiave_gc <- function(r) {
  if (!isTRUE(r$chiuso)) return(NON_CHIUSO)                 # come chiavi_lettura() di aiuti-misura-r5.R
  g <- imp(paste(sort(vapply(split(names(r$partizione), unname(r$partizione)), camp_ins, "")), collapse = ";"))
  k <- r$confronti
  kk <- if (!nrow(k)) "nessun confronto" else
    imp(paste(sort(sprintf("%s>%s", vapply(k$trattato, camp_ins, ""), vapply(k$controllo, camp_ins, ""))), collapse = ";"))
  paste(g, kk)
}
COL <- c("studio", "chiuso", "classe_gruppi", "n_universo", "n_gemma", "gemma_fuori_vista", "vista_fuori_gemma", "n_gruppi_gemma", "n_gruppi_lettore",
         "n_b_den", "n_b_uguale", "n_b_verso_opposto", "n_nostri", "n_non_elencati", "n_giudicabili", "n_errori")
# Le voci `vv` (shortName, gse) contro le letture `lett` (lista per numero GEO), con le viste `vs` (lista per numero
# GEO). Ritorna le righe delle voci misurate e l'elenco delle voci senza campioni nella vista.
misura_voci <- function(vv, vs, lett) {
  righe <- list(); senza <- character(0)
  for (i in seq_len(nrow(vv))) {
    g <- vv$gse[i]; r <- tab_gemma(vv$shortName[i], g); stopifnot(isTRUE(r$chiuso))
    cv <- campioni_di(vs[[g]])
    if (!length(intersect(r$gsm, cv))) { senza <- c(senza, vv$shortName[i]); next }
    righe[[length(righe) + 1L]] <- misura_contro_gemma(vv$shortName[i], g, r, lett[[g]], cv)$riga
  }
  per <- do.call(rbind, righe); rownames(per) <- NULL
  list(per = per, senza = senza)
}
quota_studi <- function(x, B, seme) {                       # una quota fra studi, con IC 95% (ricampionamento degli studi)
  set.seed(seme); n <- length(x)
  v <- vapply(seq_len(B), function(b) mean(x[sample.int(n, n, replace = TRUE)]), 0)
  c(num = sum(x), den = n, quota = mean(x), ic_basso = unname(stats::quantile(v, 0.025)), ic_alto = unname(stats::quantile(v, 0.975)))
}
riga_q <- function(nome, q) sprintf("%s: %d/%d = %.1f%% (IC95 %.1f-%.1f%%)", nome, as.integer(q[["num"]]), as.integer(q[["den"]]),
                                    100 * q[["quota"]], 100 * q[["ic_basso"]], 100 * q[["ic_alto"]])

# ---- K1: riproduzione e controllo positivo dello strumento sui 21 studi di sviluppo ---------------------------
cx <- leggi_uscite(file.path(USCITE_R5, "B0.jsonl"))
m <- misura_forma(cx, "B0"); t3 <- tre_numeri(m$tab)
passa("K1 riproduzione: Mistral B0 sui 47 studi di sviluppo contro Atlas",
      t3[["chiusi"]] == 45L && t3[["identici"]] == 36L && t3[["ritrovati"]] == 68L && t3[["den"]] == 95L,
      sprintf("%d chiusi, %d/47, %d/%d", t3[["chiusi"]], t3[["identici"]], t3[["ritrovati"]], t3[["den"]]))
s21 <- voci[voci$parte == "sviluppo", ]
stopifnot(nrow(s21) == 21L, all(s21$gse %in% sv$gse), !anyDuplicated(s21$gse))
lett_sv <- stats::setNames(lapply(sv$gse, function(g) lettura_studio(viste[[g]], cx[[g]])), sv$gse)
stopifnot(identical(vapply(lett_sv, chiave_gc, ""), stats::setNames(paste(chiavi_lettura(m)$gruppi, chiavi_lettura(m)$confronti), sv$gse)))
cp <- misura_voci(s21, viste, lett_sv)
pil <- utils::read.csv(file.path(LG, "31-pilota-per-studio.csv"), stringsAsFactors = FALSE); pil <- pil[pil$chi == "mistral_B0", ]
car <- function(d) as.data.frame(lapply(d[COL], as.character), stringsAsFactors = FALSE)
rg <- riassumi_gemma(cp$per, B, SEME)
passa("K1 controllo positivo: misura_voci() sui 21 studi di sviluppo rida' 31-pilota-per-studio.csv riga per riga",
      length(cp$senza) == 0L && identical(car(cp$per), car(pil)),
      sprintf("%s; %s; %s", riga_gemma(rg, "a_gruppi_identici"), riga_gemma(rg, "b_confronti_ritrovati"), riga_gemma(rg, "c_errori_non_elencati")))
if (Sys.getenv("SOLO_CONTROLLO") == "1") { cat("SOLO_CONTROLLO=1: fine dopo il controllo positivo\n"); quit(save = "no", status = 0L) }

# ---- l'oggetto: divisione, viste, schemi, ingresso, uscite ----------------------------------------------------
e21 <- new.env(); sys.source(file.path(LG, "21-divisione.R"), envir = e21)        # parte_gemma()
div <- utils::read.csv(file.path(LG, "21-divisione.csv"), stringsAsFactors = FALSE)
stopifnot(identical(div$parte, unname(e21$parte_gemma(div$gse))))
aperti <- div$gse[div$parte == "aperta"]; chiusi_g <- div$gse[div$parte == "chiusa"]
atlas_div <- utils::read.delim("analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv", stringsAsFactors = FALSE)
VG <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
names(VG) <- vapply(VG, `[[`, "", "record_id")
s22 <- utils::read.csv(file.path(LG, "22-per-studio.csv"), stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(names(VG)), setequal(names(VG), s22$gse), all(names(VG) %in% div$gse))
sha_in <- sprintf("%s  %s", sha(F_INGRESSO), F_INGRESSO)
passa("K2 l'ingresso ha l'impronta di 22-ingresso-sha256.txt", identical(sha_in, readLines(file.path(LG, "22-ingresso-sha256.txt"))))
in_ingresso <- s22$gse[s22$parte == "aperta" & s22$esito == "al_modello"]
impronte <- readLines(file.path(LG, "40-uscite-sha256.txt"))
impronte <- data.frame(sha = sub("  .*$", "", impronte), file = sub("^[0-9a-f]+  ", "", impronte), stringsAsFactors = FALSE)
apri_corsa <- function(corsa) {
  f <- file.path(USCITE_G, paste0(corsa, ".jsonl"))
  passa(sprintf("K2 l'uscita %s ha l'impronta congelata", corsa), file.exists(f) && identical(sha(f), impronte$sha[match(f, impronte$file)]))
  x <- leggi_corsa(f); id <- names(x)
  passa(sprintf("K5 %s: nessuno studio chiuso, di giudizio o di sviluppo", corsa),
        !any(id %in% chiusi_g) && !any(id %in% atlas_div$gse) && all(id %in% aperti),
        sprintf("%d record, tutti della parte aperta", length(id)))
  passa(sprintf("K3 %s: un record per ogni studio dell'ingresso", corsa), setequal(id, in_ingresso), sprintf("%d su %d", length(id), length(in_ingresso)))
  x[in_ingresso]
}
letture_di <- function(x) stats::setNames(lapply(names(x), function(g) lettura_studio(VG[[g]], x[[g]])), names(x))

# ---- la corsa del primo lettore: esiti per studio (K3) e misura per voce -------------------------------------
X <- apri_corsa(CORSA); L <- letture_di(X)
salt <- vapply(X, e_saltato, NA); chiuso <- vapply(L, function(r) isTRUE(r$chiuso), NA)
esiti <- data.frame(gse = aperti, stringsAsFactors = FALSE)
esiti$esito <- ifelse(!esiti$gse %in% names(VG), "senza_vista",
                 ifelse(!esiti$gse %in% in_ingresso, "nessuna_colonna_variabile",
                   ifelse(salt[match(esiti$gse, names(X))] %in% TRUE, "oltre_contesto",
                     ifelse(chiuso[match(esiti$gse, names(L))] %in% TRUE, "misurato", "non_chiuso"))))
esiti$motivi <- vapply(esiti$gse, function(g) if (g %in% names(L) && !isTRUE(L[[g]]$chiuso)) paste(nomi_motivi(L[[g]]), collapse = " | ") else "", "")
esiti$campioni_vista <- vapply(esiti$gse, function(g) if (g %in% names(VG)) length(campioni_di(VG[[g]])) else NA_integer_, 1L)
scrivi_csv(esiti, sprintf("41-esiti-studi-%s.csv", CORSA))
passa("K3 ogni studio aperto ha un esito", nrow(esiti) == length(aperti) && !anyNA(esiti$esito), sprintf("somma %d", nrow(esiti)))
cat("\nEsiti dei", nrow(esiti), "studi aperti:\n"); print(table(esiti$esito))
cat("motivi degli studi non chiusi (uno studio puo' averne piu' di uno):\n")
print(sort(table(unlist(strsplit(esiti$motivi[esiti$esito == "non_chiuso"], " | ", fixed = TRUE))), decreasing = TRUE))

mandati <- names(X)[!salt]                                   # studi con un'uscita generata
vv <- voci[voci$gse %in% mandati, ]
mv <- misura_voci(vv, VG, L); per <- mv$per
per$campioni_vista <- esiti$campioni_vista[match(per$gse, esiti$gse)]
per$fattori_gemma <- vv$fattori[match(per$studio, vv$shortName)]
scrivi_csv(per, sprintf("41-per-voce-%s.csv", CORSA))
cat(sprintf("\nvoci degli studi mandati al modello: %d (in %d studi); misurate %d; senza campioni di Gemma nella vista %d\n",
            nrow(vv), length(mandati), nrow(per), length(mv$senza)))
if (length(mv$senza)) cat("  voci senza campioni nella vista:", paste(mv$senza, collapse = ", "), "\n")
cat(sprintf("campioni di Gemma fuori dalla vista: %d in %d voci; campioni della vista fuori da Gemma: %d in %d voci\n",
            sum(per$gemma_fuori_vista), sum(per$gemma_fuori_vista > 0), sum(per$vista_fuori_gemma), sum(per$vista_fuori_gemma > 0)))

# ---- m1-m5 e P9 ----------------------------------------------------------------------------------------------
con_vista <- esiti$esito != "senza_vista"
cat("\nMisure (parte aperta, corsa ", CORSA, "; B = 10.000, seme 20261115, unita' lo studio GEO):\n", sep = "")
cat(sprintf("  m1 studi aperti con una vista: %d/%d = %.1f%%; mandati al modello su quelli con una vista: %d/%d = %.1f%%; mandati al modello su aperti: %d/%d = %.1f%%\n",
            sum(con_vista), nrow(esiti), 100 * mean(con_vista), length(mandati), sum(con_vista), 100 * length(mandati) / sum(con_vista),
            length(mandati), nrow(esiti), 100 * length(mandati) / nrow(esiti)))
q2 <- quota_studi(as.integer(chiuso[mandati]), B, SEME); cat("  ", riga_q("m2 studi chiusi su mandati al modello", q2), "\n", sep = "")
ria <- riassumi_gemma(per, B, SEME)
for (n in names(QUOTE_GEMMA)) cat(sprintf("  %s\n", riga_gemma(ria, n)))
estr <- estrazioni_per_studio(per$gse, B, SEME)
d9 <- vapply(estr, function(i) mean(per$classe_gruppi[i] %in% "piu_fine") - mean(per$classe_gruppi[i] %in% "piu_grossa"), 0)
p9 <- c(mean(per$classe_gruppi %in% "piu_fine") - mean(per$classe_gruppi %in% "piu_grossa"), stats::quantile(d9, c(0.025, 0.975), names = FALSE))
cat(sprintf("  P9 «piu' fine» meno «piu' grossa»: %+.1f punti (IC95 %+.1f, %+.1f)\n", 100 * p9[1], 100 * p9[2], 100 * p9[3]))
cat("  classi dei gruppi (voci):\n"); print(table(per$classe_gruppi))
ria$corsa <- CORSA; ria$insieme <- "tutte le voci misurate"
RIASSUNTO <- list(ria)

# ---- accanto, senza previsione: per grandezza dello studio e per numero di fattori di Gemma -------------------
per$classe_grandezza <- cut(per$campioni_vista, c(0, 12, 48, Inf), labels = c("fino a 12 campioni", "13-48 campioni", "oltre 48 campioni"))
per$classe_fattori <- ifelse(per$fattori_gemma >= 3L, "3 o piu' fattori di Gemma", sprintf("%d fattori di Gemma", per$fattori_gemma))
cat("\nAccanto, senza previsione (gruppi identici | confronti ritrovati):\n")
for (cl in c("classe_grandezza", "classe_fattori")) for (lv in sort(unique(as.character(per[[cl]])))) {
  d <- per[as.character(per[[cl]]) == lv, ]; r <- riassumi_gemma(d, B, SEME)
  cat(sprintf("  %-28s voci %4d | %s | %s\n", lv, nrow(d), riga_gemma(r, "a_gruppi_identici"), riga_gemma(r, "b_confronti_ritrovati")))
  r$corsa <- CORSA; r$insieme <- lv; RIASSUNTO[[length(RIASSUNTO) + 1L]] <- r
}
scrivi_csv(do.call(rbind, RIASSUNTO), sprintf("41-riassunto-%s.csv", CORSA))

# ---- m6: la replica ------------------------------------------------------------------------------------------
kc <- vapply(L, chiave_gc, "")
if (file.exists(file.path(USCITE_G, paste0(REPLICA, ".jsonl")))) {
  XR <- apri_corsa(REPLICA); LR <- letture_di(XR); kr <- vapply(LR, chiave_gc, "")
  ug <- vapply(names(X), function(g) identical(as.character(nullo(X[[g]]$raw)), as.character(nullo(XR[[g]]$raw))) && identical(e_saltato(X[[g]]), e_saltato(XR[[g]])), NA)
  cat(sprintf("\nm6 replica %s contro %s (studi dell'ingresso: %d)\n", REPLICA, CORSA, length(ug)))
  cat("  ", riga_q("uscita uguale al carattere", quota_studi(as.integer(ug), B, SEME)), "\n", sep = "")
  cat("  ", riga_q("stessi gruppi e stessi confronti", quota_studi(as.integer(kc == kr), B, SEME)), "\n", sep = "")
  cat(sprintf("  (studi non chiusi in tutte e due: %d; contano come «stessi»)\n", sum(kc == NON_CHIUSO & kr == NON_CHIUSO)))
  if (any(!ug)) cat("  studi con l'uscita diversa:", paste(utils::head(names(ug)[!ug], 40L), collapse = ", "), "\n")
} else cat(sprintf("\nm6: la replica %s non esiste ancora: non misurata\n", REPLICA))

# ---- m7, m8: l'accordo con il secondo lettore ----------------------------------------------------------------
if (nzchar(SECONDO)) {
  XS <- apri_corsa(SECONDO); LS <- letture_di(XS); ks <- vapply(LS, chiave_gc, "")
  tenuto <- stats::setNames(kc != NON_CHIUSO & ks != NON_CHIUSO & kc == ks, names(X))[mandati]
  cat(sprintf("\nAccordo fra %s e %s\n", CORSA, SECONDO))
  cat("  ", riga_q("m7 studi tenuti su mandati al modello", quota_studi(as.integer(tenuto), B, SEME)), "\n", sep = "")
  per$tenuto <- tenuto[per$gse]; id_ <- per$classe_gruppi %in% "identica"
  f8 <- function(i) mean(id_[i][per$tenuto[i]]) - mean(id_[i][!per$tenuto[i]])
  d8 <- vapply(estr, f8, 0)
  cat(sprintf("  m8 gruppi identici a Gemma: fra i tenuti %d/%d = %.1f%%, fra i non tenuti %d/%d = %.1f%%; differenza %+.1f punti (IC95 %+.1f, %+.1f)\n",
              sum(id_ & per$tenuto), sum(per$tenuto), 100 * mean(id_[per$tenuto]), sum(id_ & !per$tenuto), sum(!per$tenuto), 100 * mean(id_[!per$tenuto]),
              100 * f8(seq_len(nrow(per))), 100 * stats::quantile(d8, 0.025, na.rm = TRUE), 100 * stats::quantile(d8, 0.975, na.rm = TRUE)))
  rt <- riassumi_gemma(per[per$tenuto, ], B, SEME)
  cat("  fra i tenuti: ", riga_gemma(rt, "b_confronti_ritrovati"), "; ", riga_gemma(rt, "c_errori_non_elencati"), "\n", sep = "")
  scrivi_csv(per, sprintf("41-per-voce-%s.csv", CORSA))       # con la colonna `tenuto`
} else cat("\nm7, m8: nessun secondo lettore dato (SECONDO): non misurate\n")
cat("\nFINE 41-misura.R\n")
