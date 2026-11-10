# PROVA DA BUTTARE
# 24-misura.R — S12r2: la misura delle corse del lettore v1 sui 47 studi di sviluppo, nelle tre letture.
#
# Per ogni modello con la prima corsa congelata (M, M0, G1, G2):
#   - K4: le uscite hanno le impronte di 23-uscite-sha256.txt, e quel file e' tracciato da git;
#   - K3: la corsa copre 47 studi su 47 (uno studio senza riga ferma lo script);
#   - le due corse sono identiche al carattere? (L8, L11);
#   - adattatore v1 (22-adattatore-v1.R, committato prima delle corse) e costruttore del pacchetto;
#   - le tre misure contro Atlas nelle tre letture; lettore meno oggi, appaiato; G meno M e M0 meno M, appaiati;
#   - l'esito di ogni previsione L1-L15 di 00-previsioni.md.
# La misura di un modello si fa sulla prima corsa (00-previsioni.md); se le due corse non sono identiche si
# misura anche la seconda (prefisso <modello>-corsa2).
#
# Uso (SENZA --vanilla):
#   [S12R2_OGGETTI=<file .rds fuori dal repo>] Rscript analysis/audit/2026-11-10-S12r2-prova-ripetuta/24-misura.R \
#     > analysis/audit/2026-11-10-S12r2-prova-ripetuta/24-out.txt 2>&1
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-10-S12r2-prova-ripetuta/aiuti-misura-r2.R")
source(file.path(R2, "22-adattatore-v1.R"))
USCITE <- "analysis/p4-output/S12r2-lettore-v1"
ATTESE <- list(M = 2L, M0 = 1L, G1 = 2L, G2 = 2L)
nullo <- function(x) if (is.null(x)) NA else x
pc <- function(x) sprintf("%.1f%%", 100 * x)
# `saltato` e' assente (null) per uno studio mandato al modello, e porta il motivo per uno studio saltato dal runner.
e_saltato <- function(x) { s <- x$saltato; !is.null(s) && !is.na(s) && nzchar(as.character(s)) }
# Sensibilita' sulla forma delle voci, dichiarata dopo i numeri (27-tollera.R): S12R2_SENSIBILITA = forma | forma_na.
# Le tabelle escono col prefisso 27-<modo>-, e lo script si ferma prima delle previsioni: non ne cambia l'esito.
SENS <- Sys.getenv("S12R2_SENSIBILITA")
stopifnot(SENS %in% c("", "forma", "forma_na"))
NUM <- if (nzchar(SENS)) paste0("27-", sub("_", "-", SENS)) else "24"
nf <- function(pref, coda) sprintf("%s-%s-%s", NUM, pref, coda)
if (nzchar(SENS)) {
  source(file.path(R2, "27-tollera.R"))
  cat("SENSIBILITA' DICHIARATA DOPO I NUMERI, modo", SENS, ": non e' la misura principale\n")
}
grezzo <- function(x, v) { r <- as.character(nullo(x$raw)); if (nzchar(SENS)) tollera(r, v, SENS) else r }
salva_oggetti <- function() if (nzchar(Sys.getenv("S12R2_OGGETTI")))
  saveRDS(list(ris = ris, identiche = identiche, fra = fra, viste = viste, rif = rif, oggi = oggi, sv = sv), Sys.getenv("S12R2_OGGETTI"))

# ---- K4: le uscite congelate ---------------------------------------------------------------------------------
f_imp <- file.path(R2, "23-uscite-sha256.txt")
imp <- readLines(f_imp)
imp <- data.frame(sha = sub("  .*$", "", imp), file = sub("^[0-9a-f]+  ", "", imp), stringsAsFactors = FALSE)
stopifnot(all(vapply(imp$file, function(f) unname(digest::digest(file = f, algo = "sha256")), "") == imp$sha))
tracciato <- system2("git", c("ls-files", "--error-unmatch", f_imp), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(tracciato, "status")),
          length(system2("git", c("status", "--porcelain", "--", f_imp), stdout = TRUE)) == 0L)
cat("K4: uscite congelate,", nrow(imp), "file con le impronte di 23-uscite-sha256.txt; il file e' committato\n")

sv <- studi_di_sviluppo(); rif <- atlas_di_sviluppo(sv); viste <- leggi_viste(sv)
campi <- stats::setNames(lapply(sv$gse, function(g) campi_tempo_studio(rif[[g]], viste[[g]])), sv$gse)
oggi <- utils::read.csv(file.path(R2, "10-per-studio-oggi.csv"), stringsAsFactors = FALSE)
oggi_l <- function(l) { o <- oggi[oggi$lettura == l, ]; o <- o[match(sv$gse, o$studio), ]; stopifnot(!anyNA(o$studio)); o }

leggi_corsa <- function(cod, n) {
  f <- file.path(USCITE, sprintf("%s-corsa%d.jsonl", cod, n))
  if (!file.exists(f)) return(NULL)
  stopifnot(f %in% imp$file)
  x <- leggi_jsonl(f); names(x) <- vapply(x, `[[`, "", "record_id")
  # K3: copertura 47 su 47
  if (!setequal(names(x), sv$gse) || anyDuplicated(names(x)))
    stop(sprintf("CANCELLO K3: %s corsa %d copre %d studi su 47", cod, n, length(intersect(names(x), sv$gse))), call. = FALSE)
  x[sv$gse]
}
piatto <- function(x) vapply(x, function(e) {
  if (!length(e)) return("")
  if (!is.null(names(e))) unisci(sprintf("%s=%s", names(e), unlist(e)), "; ") else unisci(unlist(e), "; ")
}, "")

# Una corsa: adattatore, costruttore, misure nelle tre letture, tabelle su disco col prefisso dato.
misura_corsa <- function(cx, pref) {
  lett <- lapply(sv$gse, function(g) adatta_v1(viste[[g]], grezzo(cx[[g]], viste[[g]]), e_saltato(cx[[g]]),
                                               as.character(nullo(cx[[g]]$fine))))
  names(lett) <- sv$gse
  chiuso <- vapply(lett, `[[`, TRUE, "chiuso")
  nomi_motivi <- lapply(lett, function(r) unique(sub(":.*$", "", r$motivi)))
  cat("studi chiusi dal lettore:", sum(chiuso), "su 47; non chiusi:", sum(!chiuso), "\n")
  cat("studi non chiusi per esito (uno studio puo' avere piu' esiti):\n")
  print(table(factor(unlist(nomi_motivi), levels = union(c(MOTIVI_DEPOSITATI, MOTIVI_S12R), unique(unlist(nomi_motivi))))))
  depositato <- vapply(nomi_motivi, function(m) any(m %in% MOTIVI_DEPOSITATI), TRUE)
  cat("non chiusi per uno dei cinque esiti depositati:", sum(depositato), "; solo per un altro esito:", sum(!chiuso & !depositato), "\n")
  for (g in names(lett)[!chiuso]) cat(sprintf("  %s: %s\n", g, substr(unisci(lett[[g]]$motivi, " || "), 1L, 500L)))
  cat("note dell'adattatore (studi per nota):\n")
  print(table(unlist(lapply(lett, function(r) unique(sub(":.*$", "", r$note))))))
  conti <- do.call(rbind, lapply(lett, function(r) as.data.frame(as.list(r$conti))))
  conti <- cbind(studio = sv$gse, chiuso = chiuso, motivi = vapply(lett, function(r) unisci(r$motivi, " || "), ""),
                 note = vapply(lett, function(r) unisci(r$note, " || "), ""), conti, stringsAsFactors = FALSE)
  conti$fine <- vapply(sv$gse, function(g) as.character(nullo(cx[[g]]$fine)), "")
  conti$n_prompt <- vapply(sv$gse, function(g) as.numeric(nullo(cx[[g]]$n_prompt)), 0)
  conti$n_out <- vapply(sv$gse, function(g) as.numeric(nullo(cx[[g]]$n_out)), 0)
  scrivi_r2(conti, nf(pref, "studi.csv"))
  cat(sprintf("voci di assignment: %d; di forma sbagliata: %d in %d studi\n", sum(conti$voci), sum(conti$voci_malformate), sum(conti$voci_malformate > 0)))
  cat(sprintf("studi con un fattore con un livello per campione: %d; studi con una base scritta senza campioni: %d\n",
              sum(conti$fattori_per_campione > 0), sum(conti$basi_senza_campioni > 0)))
  cat(sprintf("studi con il livello 'not applicable' assegnato: %d; con 'not stated': %d\n",
              sum(conti$livelli_non_applicabile > 0), sum(conti$livelli_non_scritto > 0)))
  cat(sprintf("uscite troncate (finish_reason = length): %d; token dell'uscita: mediana %.0f, massimo %.0f\n",
              sum(conti$fine %in% "length"), stats::median(conti$n_out, na.rm = TRUE), max(conti$n_out, na.rm = TRUE)))

  con_f <- Filter(function(g) !is.null(lett[[g]]$fattori) && nrow(lett[[g]]$fattori) > 0L, sv$gse)
  fatt <- do.call(rbind, lapply(con_f, function(g) {
    f <- lett[[g]]$fattori
    cbind(studio = g, chiuso = lett[[g]]$chiuso, f, livelli_nei_campioni = vapply(f$nome, function(n) {
      if (lett[[g]]$chiuso) unisci(sort(unique(lett[[g]]$tabella$livelli[[n]]))) else ""
    }, ""), stringsAsFactors = FALSE)
  }))
  scrivi_r2(fatt, nf(pref, "fattori.csv"))
  registro <- do.call(rbind, lapply(names(lett)[chiuso], function(g) {
    r <- lett[[g]]$registro; if (!nrow(r)) return(NULL)
    data.frame(studio = g, gruppo_a = r$gruppo_a, gruppo_b = r$gruppo_b, motivo = r$motivo, dettaglio = r$dettaglio, stringsAsFactors = FALSE)
  }))
  scrivi_r2(registro, nf(pref, "registro-coppie.csv"))
  conf <- do.call(rbind, lapply(names(lett)[chiuso], function(g) {
    k <- lett[[g]]$confronti; if (!nrow(k)) return(NULL)
    data.frame(studio = g, id = k$id, fattore = k$fattore, tipo_fattore = k$tipo_fattore,
               livello_trattato = k$livello_trattato, livello_base = k$livello_base,
               n_trattato = lengths(k$trattato), n_controllo = lengths(k$controllo), esito = k$esito,
               avvisi = piatto(k$avvisi), contesto = piatto(k$contesto), stringsAsFactors = FALSE)
  }))
  scrivi_r2(conf, nf(pref, "confronti.csv"))
  cat("confronti del lettore (n_min = 2):", if (is.null(conf)) 0L else nrow(conf), "in",
      if (is.null(conf)) 0L else length(unique(conf$studio)), "studi\n")

  mm <- lapply(sv$gse, function(g) {
    x <- rif[[g]]; r <- lett[[g]]
    tre <- if (r$chiuso) misura_tre(g, r$partizione, confronti_comuni(g, r$confronti), x, campi[[g]]) else
      misura_tre(g, character(0), CONFRONTI_VUOTI(g), x, campi[[g]])
    for (l in LETTURE) {
      if (!r$chiuso) tre[[l]]$riga$classe_gruppi <- "non_chiuso"
      tre[[l]]$riga$chiuso <- r$chiuso
      tre[[l]]$riga$n_gruppi_lettore <- if (r$chiuso) length(unique(r$partizione[names(r$partizione) %in% x$universo])) else 0L
      tre[[l]]$riga$n_gruppi_atlas <- length(unique(x$atlas$partizione[names(x$atlas$partizione) %in% x$universo]))
    }
    tre
  })
  names(mm) <- sv$gse
  per_studio <- stats::setNames(lapply(LETTURE, function(l) do.call(rbind, lapply(mm, function(m) m[[l]]$riga))), LETTURE)
  stopifnot(all(vapply(per_studio, nrow, 0L) == 47L))
  misure <- lapply(per_studio, tf_riassumi_misure, B = B, seme = SEME)
  at <- do.call(rbind, lapply(LETTURE, function(l) do.call(rbind, lapply(mm, function(m) {
    k <- m[[l]]$atlas
    data.frame(lettura = l, studio = k$studio, id = k$id, nome = k$nome, n_trattato = lengths(k$trattato),
               n_controllo = lengths(k$controllo), classe = k$classe, fattori_diversi = k$fattori_diversi,
               fattori_non_scritti = k$fattori_non_scritti, fattori_annidati = k$fattori_annidati,
               tempo_zero = k$tempo_zero, tempo_zero_verso = k$tempo_zero_verso, in_b = k$in_b,
               ritrovato = k$ritrovato, stringsAsFactors = FALSE)
  }))))
  ne <- do.call(rbind, lapply(LETTURE, function(l) do.call(rbind, lapply(mm, function(m) {
    k <- m[[l]]$non_elencati; if (!nrow(k)) return(NULL)
    data.frame(lettura = l, studio = k$studio, id = k$id, n_trattato = lengths(k$trattato),
               n_controllo = lengths(k$controllo), giudizio = k$giudizio, stringsAsFactors = FALSE)
  }))))
  scrivi_r2(do.call(rbind, per_studio), nf(pref, "per-studio.csv"))
  scrivi_r2(do.call(rbind, lapply(LETTURE, function(l) cbind(lettura = l, misure[[l]]))), nf(pref, "misure.csv"))
  scrivi_r2(at, nf(pref, "confronti-atlas.csv"))
  scrivi_r2(ne, nf(pref, "non-elencati.csv"))
  meno <- list()
  for (l in LETTURE) {
    cat(sprintf("\n-- %s, lettura %s --\n", pref, l))
    print(table(per_studio[[l]]$classe_gruppi, useNA = "ifany"))
    print(misure[[l]][1:3, ], row.names = FALSE, digits = 4)
    cat("lettore meno oggi, appaiato:\n")
    meno[[l]] <- appaiato(per_studio[[l]], oggi_l(l)); print(meno[[l]], row.names = FALSE, digits = 4)
  }
  scrivi_r2(do.call(rbind, lapply(LETTURE, function(l) cbind(lettura = l, meno[[l]]))), nf(pref, "meno-oggi.csv"))
  list(lett = lett, chiuso = chiuso, conti = conti, per_studio = per_studio, misure = misure, meno = meno, mm = mm, corsa = cx)
}

ris <- list(); identiche <- list()
for (cod in names(ATTESE)) {
  c1 <- leggi_corsa(cod, 1L)
  if (is.null(c1)) { cat(sprintf("\n================ %s: prima corsa assente, non misurato ================\n", cod)); next }
  cat(sprintf("\n================ %s ================\nK3: la prima corsa copre 47 studi su 47\n", cod))
  if (ATTESE[[cod]] == 2L) {
    c2 <- leggi_corsa(cod, 2L)
    if (is.null(c2)) { cat("seconda corsa assente\n"); identiche[[cod]] <- NA_integer_ } else {
      r1 <- vapply(c1, function(x) as.character(nullo(x$raw)), ""); r2 <- vapply(c2, function(x) as.character(nullo(x$raw)), "")
      s1 <- vapply(c1, function(x) as.character(nullo(x$saltato)), ""); s2 <- vapply(c2, function(x) as.character(nullo(x$saltato)), "")
      ug <- (is.na(s1) == is.na(s2)) & ((is.na(r1) & is.na(r2)) | (!is.na(r1) & !is.na(r2) & r1 == r2))
      identiche[[cod]] <- sum(ug)
      cat(sprintf("uscite identiche al carattere fra le due corse: %d su 47\n", sum(ug)))
      if (any(!ug)) cat("diverse:", unisci(sv$gse[!ug], ", "), "\n")
    }
  }
  ris[[cod]] <- misura_corsa(c1, cod)
  if (ATTESE[[cod]] == 2L && !is.na(identiche[[cod]]) && identiche[[cod]] < 47L) {
    cat(sprintf("\n---------------- %s, seconda corsa (le due corse non sono identiche) ----------------\n", cod))
    ris[[paste0(cod, "-corsa2")]] <- misura_corsa(c2, paste0(cod, "-corsa2"))
  }
}

# ---- Fra modelli: M0 meno M, G meno M (appaiati, lettura per lettura) -----------------------------------------
fra <- list()
for (cod in intersect(c("M0", "G1", "G2"), names(ris))) if (!is.null(ris$M)) {
  cat(sprintf("\n================ %s meno M, appaiato ================\n", cod))
  fra[[cod]] <- lapply(stats::setNames(LETTURE, LETTURE), function(l) appaiato(ris[[cod]]$per_studio[[l]], ris$M$per_studio[[l]], c(cod, "M")))
  for (l in LETTURE) { cat("lettura", l, "\n"); print(fra[[cod]][[l]], row.names = FALSE, digits = 4) }
  d <- do.call(rbind, lapply(LETTURE, function(l) { x <- fra[[cod]][[l]]; names(x)[2:3] <- c("a", "b"); cbind(lettura = l, a_e = cod, b_e = "M", x) }))
  scrivi_r2(d, nf(cod, "meno-M.csv"))
}

if (nzchar(SENS)) { salva_oggetti(); cat("\nFINITO (sensibilita')\n"); quit(save = "no") }

# ---- Le previsioni -------------------------------------------------------------------------------------------
cat("\n================ Previsioni (00-previsioni.md), lettura principale ================\n")
riga <- function(x, nome) x[x$misura == nome, ]
stima <- function(codice, che, r, atteso, basso, alto) {
  # r: una riga con stima e intervallo al 95% (frazioni); intervallo di rilevanza in frazioni
  es <- if (r$ic_basso >= basso && r$ic_alto <= alto) "confermata" else if (r$ic_alto < basso || r$ic_basso > alto) "smentita" else "indeterminata"
  cat(sprintf("%s  %s: %s (IC95 %s, %s); atteso %s, rilevanza %s-%s  ->  %s\n", codice, che, pc(r$stima), pc(r$ic_basso), pc(r$ic_alto), atteso, pc(basso), pc(alto), es))
}
sopra0 <- function(codice, che, r, atteso) {
  es <- if (r$ic_basso > 0) "confermata" else if (r$ic_alto < 0) "smentita" else "indeterminata"
  cat(sprintf("%s  %s: %+.1f punti (IC95 %+.1f, %+.1f); atteso %s, rilevanza: intervallo sopra 0  ->  %s\n", codice, che, 100 * r$differenza, 100 * r$ic_basso, 100 * r$ic_alto, atteso, es))
}
mis <- function(cod, nome) { m <- riga(ris[[cod]]$misure$principale, nome); data.frame(stima = m$quota, ic_basso = m$ic_basso, ic_alto = m$ic_alto) }
if (!is.null(ris$M)) {
  k <- ris$M$conti
  conto("L1", "M: studi non chiusi", sum(!k$chiuso), 5, 0, 7)
  conto("L2", "M: voci di forma sbagliata", sum(k$voci_malformate), 0, 0, 0)
  conto("L3", "M: studi con un fattore con un livello per campione", sum(k$fattori_per_campione > 0), 1, 0, 2)
  conto("L4", "M: studi con una base scritta senza campioni", sum(k$basi_senza_campioni > 0), 1, 0, 2)
  stima("L5", "M: (a) partizione identica", mis("M", "a_gruppi_identici"), "55%", 0.50, 0.80)
  sopra0("L6", "M meno oggi, (b)", riga(ris$M$meno$principale, "b_confronti_ritrovati"), "+15 punti")
  stima("L7", "M: (c) errori fra i non elencati", mis("M", "c_errori_non_elencati"), "5%", 0, 0.10)
  if (!is.null(identiche$M)) conto("L8", "M: uscite identiche fra le due corse", identiche$M, 47, 47, 47)
}
if (!is.null(ris$M0) && !is.null(fra$M0)) {
  r <- riga(fra$M0$principale, "b_confronti_ritrovati")
  es <- if (r$ic_basso >= -0.05 && r$ic_alto <= 0.05) "confermata" else if (r$ic_alto < -0.05 || r$ic_basso > 0.05) "smentita" else "indeterminata"
  cat(sprintf("L9  M0 meno M, (b): %+.1f punti (IC95 %+.1f, %+.1f); atteso 0, rilevanza -5, +5 punti  ->  %s\n", 100 * r$differenza, 100 * r$ic_basso, 100 * r$ic_alto, es))
  conto("L10", "M0: uscite troncate", sum(ris$M0$conti$fine %in% "length"), 0, 0, 1)
}
for (cod in intersect(c("G1", "G2"), names(ris))) {
  if (!is.null(identiche[[cod]])) conto("L11", paste0(cod, ": uscite identiche fra le due corse"), identiche[[cod]], 47, 47, 47)
  conto("L12", paste0(cod, ": studi non chiusi"), sum(!ris[[cod]]$conti$chiuso), 3, 0, 7)
  stima("L13", paste0(cod, ": (a) partizione identica"), mis(cod, "a_gruppi_identici"), "60%", 0.50, 0.80)
  sopra0("L14", paste0(cod, " meno oggi, (b)"), riga(ris[[cod]]$meno$principale, "b_confronti_ritrovati"), "+25 punti")
  if (!is.null(fra[[cod]])) sopra0("L15", paste0(cod, " meno M, (b)"), riga(fra[[cod]]$principale, "b_confronti_ritrovati"), "+10 punti")
}

# ---- Regola di esito, punti 1-3 (il punto 4 viene dalla lettura dei disaccordi) ------------------------------
cat("\n================ Regola di esito, punti 1-3, lettura principale ================\n")
for (cod in intersect(c("M", "G1", "G2"), names(ris))) {
  m <- ris[[cod]]$meno$principale
  p1 <- isTRUE(identiche[[cod]] == 47L)
  p2 <- riga(m, "b_confronti_ritrovati")$ic_basso > 0
  p3 <- riga(m, "a_gruppi_identici")$differenza > 0 && riga(m, "c_errori_non_elencati")$differenza < 0
  cat(sprintf("%s: (1) corse identiche %s; (2) (b) meno oggi con IC95 sopra 0 %s; (3) meglio di oggi in (a) [%+.1f punti] e in (c) [%+.1f punti] %s\n",
              cod, if (p1) "si'" else "no", if (p2) "si'" else "no", 100 * riga(m, "a_gruppi_identici")$differenza,
              100 * riga(m, "c_errori_non_elencati")$differenza, if (isTRUE(p3)) "si'" else "no"))
}
# Gli oggetti per il materiale della lettura dei disaccordi (25-materiale.R): solo se richiesti, fuori dal repo.
salva_oggetti()
cat("\nFINITO\n")
