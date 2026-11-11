# PROVA DA BUTTARE
# 24-misura.R — S12r3: la misura delle due corse del lettore v2 (schema delle uscite a elenco chiuso,
# Mistral-Small 3.2) sui 47 studi di sviluppo, nelle quattro misure di 00-previsioni.md.
#
#   - K4: le uscite hanno le impronte di 23-uscite-sha256.txt, e quel file e' tracciato da git; adattatore,
#     generatore e prompt sono quelli del commit fatto prima del primo invio (COMMIT_PRIMA);
#   - K3: ognuna delle due corse copre 47 studi su 47;
#   - le due corse sono identiche al carattere? (E5, regola di esito punto 1);
#   - adattatore v2 (22-adattatore-v2.R) e costruttore del pacchetto;
#   - le tre misure contro Atlas nelle quattro forme; lettore meno oggi e schema nuovo meno schema v1, appaiati
#     (termini di paragone: 15-per-studio-oggi.csv e 15-per-studio-v1.csv, calcolati prima del deposito);
#   - la tabella 3 x 3 degli stati (S12r2 corsa 1 contro S12r3 corsa 1), le regressioni, i 13 studi;
#   - l'esito di ogni previsione E1-E15 che non chiede la lettura (E12 la chiede) e i punti 1, 2, 3 e 5 della
#     regola di esito (il punto 4 viene dalla lettura dei disaccordi).
# La misura si fa sulla prima corsa (00-previsioni.md); se le due corse non sono identiche si misura anche la seconda.
#
# Uso (SENZA --vanilla):
#   [S12R3_OGGETTI=<file .rds fuori dal repo>] Rscript analysis/audit/2026-11-11-S12r3-elenco-chiuso/24-misura.R \
#     > analysis/audit/2026-11-11-S12r3-elenco-chiuso/24-out.txt 2>&1
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-11-S12r3-elenco-chiuso/aiuti-misura-r3.R")
source(file.path(R3, "22-adattatore-v2.R"))                  # passa da solo il controllo positivo (K2 ii)
USCITE <- "analysis/p4-output/S12r3-lettore-v2"
COMMIT_PRIMA <- "6a00e1e"                                     # prompt v2, adattatore v2, script di lancio: prima del primo invio
TREDICI <- c("GSE147507", "GSE46665", "GSE56787", "GSE57116", "GSE57945", "GSE59781", "GSE60340", "GSE63816",
             "GSE66207", "GSE69597", "GSE71595", "GSE83415", "GSE83687")
nullo <- function(x) if (is.null(x)) NA else x
pc <- function(x) sprintf("%.1f%%", 100 * x)
e_saltato <- function(x) { s <- x$saltato; !is.null(s) && !is.na(s) && nzchar(as.character(s)) }
sha <- function(f) unname(digest::digest(file = f, algo = "sha256"))

# ---- K4: le uscite congelate e i file committati prima delle corse -------------------------------------------
f_imp <- file.path(R3, "23-uscite-sha256.txt")
imp <- readLines(f_imp)
imp <- data.frame(sha = sub("  .*$", "", imp), file = sub("^[0-9a-f]+  ", "", imp), stringsAsFactors = FALSE)
stopifnot(all(vapply(imp$file, sha, "") == imp$sha))
tracciato <- system2("git", c("ls-files", "--error-unmatch", f_imp), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(tracciato, "status")),
          length(system2("git", c("status", "--porcelain", "--", f_imp), stdout = TRUE)) == 0L)
cat("K4: uscite congelate,", nrow(imp), "file con le impronte di 23-uscite-sha256.txt; il file e' committato\n")
for (f in file.path(R3, c("21-prompt-v2.md", "10-schema-per-studio.R", "22-adattatore-v2.R", "23-lancia.R"))) {
  tmp <- tempfile(); stopifnot(system2("git", c("show", paste0(COMMIT_PRIMA, ":", f)), stdout = tmp, stderr = FALSE) == 0L)
  if (sha(f) != sha(tmp)) stop("CANCELLO K4: ", f, " e' cambiato dopo il commit ", COMMIT_PRIMA, call. = FALSE)
  unlink(tmp)
}
cat("K4: prompt v2, generatore, adattatore v2 e script di lancio sono quelli del commit", COMMIT_PRIMA, "(prima del primo invio)\n")

sv <- studi_di_sviluppo(); rif <- atlas_di_sviluppo(sv); viste <- leggi_viste(sv)
campi <- stats::setNames(lapply(sv$gse, function(g) campi_tempo_studio(rif[[g]], viste[[g]])), sv$gse)
termine <- function(f) {
  d <- utils::read.csv(file.path(R3, f), stringsAsFactors = FALSE)
  stats::setNames(lapply(NOMI_R3, function(m) { o <- d[d$misura_r3 == m, ]; o <- o[match(sv$gse, o$studio), ]; stopifnot(!anyNA(o$studio)); o }), NOMI_R3)
}
oggi <- termine("15-per-studio-oggi.csv"); v1 <- termine("15-per-studio-v1.csv")
stopifnot(sum(v1$principale$chiuso) == 34L, sum(v1$principale$classe_gruppi == "identica") == 31L,
          setequal(sv$gse[!v1$principale$chiuso], TREDICI))

leggi_corsa <- function(n) {
  f <- file.path(USCITE, sprintf("M-corsa%d.jsonl", n))
  stopifnot(file.exists(f), f %in% imp$file)
  x <- leggi_jsonl(f); names(x) <- vapply(x, `[[`, "", "record_id")
  if (!setequal(names(x), sv$gse) || anyDuplicated(names(x)))
    stop(sprintf("CANCELLO K3: la corsa %d copre %d studi su 47", n, length(intersect(names(x), sv$gse))), call. = FALSE)
  x[sv$gse]
}
piatto <- function(x) vapply(x, function(e) {
  if (!length(e)) return("")
  if (!is.null(names(e))) unisci(sprintf("%s=%s", names(e), unlist(e)), "; ") else unisci(unlist(e), "; ")
}, "")
stato <- function(chiuso, classe) ifelse(!chiuso, "non chiuso", ifelse(classe %in% "identica", "identica", "diversa"))

# Una corsa: adattatore, costruttore, misure nelle quattro forme, tabelle su disco col prefisso dato.
misura_corsa <- function(cx, pref) {
  nf <- function(coda) sprintf("24-%s-%s", pref, coda)
  lett <- stats::setNames(lapply(sv$gse, function(g) adatta_v2(viste[[g]], as.character(nullo(cx[[g]]$raw)), e_saltato(cx[[g]]),
                                                                as.character(nullo(cx[[g]]$fine)))), sv$gse)
  chiuso <- vapply(lett, `[[`, TRUE, "chiuso")
  nomi_motivi <- lapply(lett, function(r) unique(sub(":.*$", "", sub("^(tf_tabella):.*$", "\\1", r$motivi))))
  cat("studi chiusi dal lettore:", sum(chiuso), "su 47; non chiusi:", sum(!chiuso), "\n")
  cat("studi non chiusi per motivo (uno studio puo' avere piu' motivi):\n")
  print(table(factor(unlist(nomi_motivi), levels = union(c(MOTIVI_V2, "tf_tabella"), unique(unlist(nomi_motivi))))))
  for (g in names(lett)[!chiuso]) cat(sprintf("  %s: %s\n", g, substr(unisci(lett[[g]]$motivi, " || "), 1L, 700L)))
  cat("note dell'adattatore (studi per nota):\n")
  print(table(unlist(lapply(lett, function(r) unique(sub(":.*$", "", r$note))))))
  conti <- do.call(rbind, lapply(lett, function(r) as.data.frame(as.list(r$conti))))
  conti <- cbind(studio = sv$gse, chiuso = chiuso, motivi = vapply(lett, function(r) unisci(r$motivi, " || "), ""),
                 nomi_motivi = vapply(nomi_motivi, unisci, ""),
                 note = vapply(lett, function(r) unisci(r$note, " || "), ""), conti, stringsAsFactors = FALSE)
  conti$fine <- vapply(sv$gse, function(g) as.character(nullo(cx[[g]]$fine)), "")
  conti$n_prompt <- vapply(sv$gse, function(g) as.numeric(nullo(cx[[g]]$n_prompt)), 0)
  conti$n_out <- vapply(sv$gse, function(g) as.numeric(nullo(cx[[g]]$n_out)), 0)
  conti$n_fattori <- vapply(lett, function(r) if (is.null(r$fattori)) NA_integer_ else nrow(r$fattori), 0L)
  conti$n_gruppi <- vapply(lett, function(r) if (r$chiuso) as.integer(r$n_gruppi) else NA_integer_, 0L)
  conti$n_confronti <- vapply(lett, function(r) if (r$chiuso) nrow(r$confronti) else NA_integer_, 0L)
  scrivi_r3(conti, nf("studi.csv"))
  cat(sprintf("voci di assignment (studi con l'uscita valida): %d\n", sum(conti$voci)))
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
  scrivi_r3(fatt, nf("fattori.csv"))
  registro <- do.call(rbind, lapply(names(lett)[chiuso], function(g) {
    r <- lett[[g]]$registro; if (!nrow(r)) return(NULL)
    data.frame(studio = g, gruppo_a = r$gruppo_a, gruppo_b = r$gruppo_b, motivo = r$motivo, dettaglio = r$dettaglio, stringsAsFactors = FALSE)
  }))
  scrivi_r3(registro, nf("registro-coppie.csv"))
  conf <- do.call(rbind, lapply(names(lett)[chiuso], function(g) {
    k <- lett[[g]]$confronti; if (!nrow(k)) return(NULL)
    data.frame(studio = g, id = k$id, fattore = k$fattore, tipo_fattore = k$tipo_fattore,
               livello_trattato = k$livello_trattato, livello_base = k$livello_base,
               n_trattato = lengths(k$trattato), n_controllo = lengths(k$controllo), esito = k$esito,
               avvisi = piatto(k$avvisi), contesto = piatto(k$contesto), stringsAsFactors = FALSE)
  }))
  scrivi_r3(conf, nf("confronti.csv"))
  cat("confronti del lettore (n_min = 2):", if (is.null(conf)) 0L else nrow(conf), "in",
      if (is.null(conf)) 0L else length(unique(conf$studio)), "studi\n")

  mm <- lapply(sv$gse, function(g) {
    x <- rif[[g]]; r <- lett[[g]]
    t <- if (r$chiuso) misura_r3(g, r$partizione, confronti_comuni(g, r$confronti), x, campi[[g]]) else
      misura_r3(g, character(0), CONFRONTI_VUOTI(g), x, campi[[g]])
    for (m in NOMI_R3) {
      if (!r$chiuso) t[[m]]$riga$classe_gruppi <- "non_chiuso"
      t[[m]]$riga$chiuso <- r$chiuso
      t[[m]]$riga$n_gruppi_lettore <- if (r$chiuso) length(unique(r$partizione[names(r$partizione) %in% x$universo])) else 0L
      t[[m]]$riga$n_gruppi_atlas <- length(unique(x$atlas$partizione[names(x$atlas$partizione) %in% x$universo]))
    }
    t
  })
  names(mm) <- sv$gse
  per_studio <- stats::setNames(lapply(NOMI_R3, function(m) do.call(rbind, lapply(mm, function(x) x[[m]]$riga))), NOMI_R3)
  stopifnot(all(vapply(per_studio, nrow, 0L) == 47L))       # K3: ogni misura copre 47 studi
  misure <- lapply(per_studio, tf_riassumi_misure, B = B, seme = SEME)
  at <- do.call(rbind, lapply(NOMI_R3, function(m) do.call(rbind, lapply(mm, function(x) {
    k <- x[[m]]$atlas
    data.frame(misura_r3 = m, studio = k$studio, id = k$id, nome = k$nome, n_trattato = lengths(k$trattato),
               n_controllo = lengths(k$controllo), classe = k$classe, fattori_diversi = k$fattori_diversi,
               fattori_non_scritti = k$fattori_non_scritti, fattori_annidati = k$fattori_annidati,
               tempo_zero = k$tempo_zero, tempo_zero_verso = k$tempo_zero_verso, solo_contesto = k$solo_contesto,
               in_b = k$in_b, ritrovato = k$ritrovato, stringsAsFactors = FALSE)
  }))))
  ne <- do.call(rbind, lapply(NOMI_R3, function(m) do.call(rbind, lapply(mm, function(x) {
    k <- x[[m]]$non_elencati; if (!nrow(k)) return(NULL)
    data.frame(misura_r3 = m, studio = k$studio, id = k$id, n_trattato = lengths(k$trattato),
               n_controllo = lengths(k$controllo), giudizio = k$giudizio, stringsAsFactors = FALSE)
  }))))
  scrivi_r3(impila(per_studio), nf("per-studio.csv"))
  scrivi_r3(impila(misure), nf("misure.csv"))
  scrivi_r3(at, nf("confronti-atlas.csv"))
  if (is.null(ne)) ne <- data.frame(misura_r3 = character(0), studio = character(0), id = character(0),
                                    n_trattato = integer(0), n_controllo = integer(0), giudizio = character(0))
  scrivi_r3(ne, nf("non-elencati.csv"))
  meno_oggi <- list(); meno_v1 <- list()
  for (m in NOMI_R3) {
    cat(sprintf("\n-- %s, misura %s --\n", pref, m))
    print(table(per_studio[[m]]$classe_gruppi, useNA = "ifany"))
    print(misure[[m]][1:3, ], row.names = FALSE, digits = 4)
    cat("lettore (schema nuovo) meno oggi, appaiato:\n")
    meno_oggi[[m]] <- appaiato(per_studio[[m]], oggi[[m]], c("nuovo", "oggi")); print(meno_oggi[[m]], row.names = FALSE, digits = 4)
    cat("schema nuovo meno schema v1, appaiato:\n")
    meno_v1[[m]] <- appaiato(per_studio[[m]], v1[[m]], c("nuovo", "v1")); print(meno_v1[[m]], row.names = FALSE, digits = 4)
  }
  scrivi_r3(impila(meno_oggi), nf("meno-oggi.csv"))
  scrivi_r3(impila(meno_v1), nf("meno-v1.csv"))
  list(lett = lett, chiuso = chiuso, conti = conti, per_studio = per_studio, misure = misure, meno_oggi = meno_oggi,
       meno_v1 = meno_v1, mm = mm, corsa = cx)
}

# ---- Le due corse: K3 e l'identita' al carattere ---------------------------------------------------------------
c1 <- leggi_corsa(1L); c2 <- leggi_corsa(2L)
cat("K3: le due corse coprono 47 studi su 47\n")
r1 <- vapply(c1, function(x) as.character(nullo(x$raw)), ""); r2 <- vapply(c2, function(x) as.character(nullo(x$raw)), "")
s1 <- vapply(c1, e_saltato, NA); s2 <- vapply(c2, e_saltato, NA)
ug <- (s1 == s2) & ((is.na(r1) & is.na(r2)) | (!is.na(r1) & !is.na(r2) & r1 == r2))
identiche <- sum(ug)
cat(sprintf("uscite identiche al carattere fra le due corse: %d su 47\n", identiche))
if (any(!ug)) cat("diverse:", unisci(sv$gse[!ug], ", "), "\n")

cat("\n================ M (Mistral-Small 3.2, schema a elenco chiuso), prima corsa ================\n")
ris <- list(M = misura_corsa(c1, "M"))
if (identiche < 47L) {
  cat("\n---------------- seconda corsa (le due corse non sono identiche) ----------------\n")
  ris[["M-corsa2"]] <- misura_corsa(c2, "M-corsa2")
}

# ---- La tabella 3 x 3 degli stati, le regressioni, i 13 studi ---------------------------------------------------
p <- ris$M$per_studio$principale; k <- ris$M$conti
st <- data.frame(studio = sv$gse, stato_v1 = stato(v1$principale$chiuso, v1$principale$classe_gruppi),
                 stato_nuovo = stato(p$chiuso, p$classe_gruppi), classe_v1 = v1$principale$classe_gruppi, classe_nuovo = p$classe_gruppi,
                 motivi_nuovo = k$nomi_motivi, n_gruppi_lettore = p$n_gruppi_lettore, n_gruppi_atlas = p$n_gruppi_atlas,
                 n_confronti_lettore = k$n_confronti, b_den = p$n_b_den, b_ritrovati_v1 = v1$principale$n_b_uguale, b_ritrovati_nuovo = p$n_b_uguale,
                 giudicabili = p$n_giudicabili, errori = p$n_errori, fattori_per_campione = k$fattori_per_campione,
                 basi_senza_campioni = k$basi_senza_campioni, dei_tredici = sv$gse %in% TREDICI, stringsAsFactors = FALSE)
st$regressione <- st$stato_v1 == "identica" & st$stato_nuovo != "identica"
scrivi_r3(st, "24-transizioni.csv")
LIV <- c("non chiuso", "identica", "diversa")
cat("\n================ Stati dei 47 studi: schema v1 (S12r2, corsa 1) in riga, schema nuovo (corsa 1) in colonna ================\n")
print(table(v1 = factor(st$stato_v1, LIV), nuovo = factor(st$stato_nuovo, LIV)))
cat("\nregressioni (identica con lo schema v1, ora diversa o non chiuso):", sum(st$regressione), "\n")
print(st[st$regressione, c("studio", "stato_nuovo", "classe_nuovo", "motivi_nuovo", "b_den", "b_ritrovati_v1", "b_ritrovati_nuovo")], row.names = FALSE)
cat("\ni 13 studi che non chiudevano con lo schema v1:\n")
print(st[st$dei_tredici, c("studio", "stato_nuovo", "classe_nuovo", "motivi_nuovo", "n_gruppi_lettore", "n_gruppi_atlas", "n_confronti_lettore",
                           "b_den", "b_ritrovati_nuovo", "giudicabili", "errori")], row.names = FALSE)
cat("\ngli altri studi con stato cambiato o non identico:\n")
print(st[!st$dei_tredici & (st$stato_v1 != st$stato_nuovo | st$stato_nuovo != "identica"),
         c("studio", "stato_v1", "stato_nuovo", "classe_nuovo", "motivi_nuovo", "b_den", "b_ritrovati_v1", "b_ritrovati_nuovo")], row.names = FALSE)
cat("\nstudi dove i confronti ritrovati cambiano fra schema v1 e schema nuovo (misura principale):\n")
d <- st[st$b_ritrovati_v1 != st$b_ritrovati_nuovo, c("studio", "stato_v1", "stato_nuovo", "b_den", "b_ritrovati_v1", "b_ritrovati_nuovo")]
print(d, row.names = FALSE)

# ---- Le previsioni -------------------------------------------------------------------------------------------
cat("\n================ Previsioni (00-previsioni.md), prima corsa, misura principale ================\n")
riga <- function(x, nome) x[x$misura == nome, ]
stima <- function(codice, che, r, atteso, basso, alto) {
  if (is.na(r$stima)) { cat(sprintf("%s  %s: senza valore (denominatore 0); atteso %s  ->  non giudicabile\n", codice, che, atteso)); return(invisible()) }
  es <- if (r$ic_basso >= basso && r$ic_alto <= alto) "confermata" else if (r$ic_alto < basso || r$ic_basso > alto) "smentita" else "indeterminata"
  cat(sprintf("%s  %s: %s (IC95 %s, %s); atteso %s, rilevanza %s-%s  ->  %s\n", codice, che, pc(r$stima), pc(r$ic_basso), pc(r$ic_alto), atteso, pc(basso), pc(alto), es))
}
sopra0 <- function(codice, che, r, atteso) {
  es <- if (r$ic_basso > 0) "confermata" else if (r$ic_alto < 0) "smentita" else "indeterminata"
  cat(sprintf("%s  %s: %+.1f punti (IC95 %+.1f, %+.1f); atteso %s, rilevanza: intervallo sopra 0  ->  %s\n", codice, che, 100 * r$differenza, 100 * r$ic_basso, 100 * r$ic_alto, atteso, es))
}
mis <- function(nome) { m <- riga(ris$M$misure$principale, nome); data.frame(stima = m$quota, ic_basso = m$ic_basso, ic_alto = m$ic_alto) }
ha <- function(m) vapply(strsplit(k$nomi_motivi, " | ", fixed = TRUE), function(x) m %in% x, NA)
conto("E1", "studi non chiusi", sum(!k$chiuso), 2, 0, 7)
# E2: con lo schema a elenco chiuso un valore senza voce, una colonna o un valore non letterale possono nascere
# solo come uscita NON troncata che non rispetta lo schema dello studio (non_valida con finish_reason = stop)
conto("E2", "studi non chiusi per un'uscita finita (stop) che non rispetta lo schema dello studio", sum(ha("non_valida") & !(k$fine %in% "length")), 0, 0, 0)
conto("E3", "uscite troncate (finish_reason = length)", sum(k$fine %in% "length"), 0, 0, 1)
conto("E4", "studi fermi per ruolo_incoerente", sum(ha("ruolo_incoerente")), 1, 0, 2)
conto("E5", "uscite identiche fra le due corse", identiche, 47, 47, 47)
stima("E6", "(a) partizione identica", mis("a_gruppi_identici"), "77%", 0.50, 1.00)
sopra0("E7", "schema nuovo meno schema v1, (a)", riga(ris$M$meno_v1$principale, "a_gruppi_identici"), "+10,6 punti")
sopra0("E8", "lettore meno oggi, (b)", riga(ris$M$meno_oggi$principale, "b_confronti_ritrovati"), "+52 punti")
sopra0("E9", "schema nuovo meno schema v1, (b)", riga(ris$M$meno_v1$principale, "b_confronti_ritrovati"), "+13 punti")
stima("E10", "(c) errori fra i non elencati", mis("c_errori_non_elencati"), "5%", 0, 0.10)
conto("E11", "dei 13 studi non chiusi con lo schema v1, quanti chiudono", sum(st$dei_tredici & st$stato_nuovo != "non chiuso"), 13, 10, 13)
cat(sprintf("E12 chiede la lettura: dei 13, chiudono con partizione non identica %d (%s); la lettura dice quanti hanno gruppi sbagliati per una causa del lettore\n",
            sum(st$dei_tredici & st$stato_nuovo == "diversa"), unisci(st$studio[st$dei_tredici & st$stato_nuovo == "diversa"], ", ")))
conto("E13", "regressioni", sum(st$regressione), 1, 0, 2)
conto("E14", "studi con un fattore con un livello per campione", sum(k$fattori_per_campione > 0), 2, 0, 2)
conto("E15", "studi con una base scritta senza campioni", sum(k$basi_senza_campioni > 0), 2, 0, 2)
cat("studi di E14:", unisci(k$studio[k$fattori_per_campione > 0], ", "), "\nstudi di E15:", unisci(k$studio[k$basi_senza_campioni > 0], ", "), "\n")

cat("\n================ Le quattro misure, prima corsa ================\n")
for (m in NOMI_R3) cat(sprintf("%-13s (a) %s  (b) %s  (c) %s   | oggi (b) %d/%d | v1 (b) %d/%d\n", m, fraz(ris$M$misure[[m]], "a_gruppi_identici"),
                               fraz(ris$M$misure[[m]], "b_confronti_ritrovati"), fraz(ris$M$misure[[m]], "c_errori_non_elencati"),
                               sum(oggi[[m]]$n_b_uguale), sum(oggi[[m]]$n_b_den), sum(v1[[m]]$n_b_uguale), sum(v1[[m]]$n_b_den)))

# ---- Regola di esito, punti 1, 2, 3 e 5 (il punto 4 viene dalla lettura dei disaccordi) ----------------------
cat("\n================ Regola di esito, punti 1, 2, 3 e 5, misura principale ================\n")
m <- ris$M$meno_oggi$principale
p1 <- identiche == 47L
p2 <- riga(m, "b_confronti_ritrovati")$ic_basso > 0
da <- riga(m, "a_gruppi_identici")$differenza; dc <- riga(m, "c_errori_non_elencati")$differenza
p3 <- isTRUE(da > 0 && dc < 0)
p5 <- sum(!k$chiuso) <= 7L
si <- function(x) if (isTRUE(x)) "si'" else "no"
cat(sprintf("(1) corse identiche %s; (2) (b) meno oggi con IC95 sopra 0 %s; (3) meglio di oggi in (a) [%+.1f punti] e in (c) [%s] %s; (5) non chiusi %d, al massimo 7 %s\n",
            si(p1), si(p2), 100 * da, if (is.na(dc)) "senza valore: 0 confronti giudicabili" else sprintf("%+.1f punti", 100 * dc), si(p3), sum(!k$chiuso), si(p5)))
if (nzchar(Sys.getenv("S12R3_OGGETTI")))
  saveRDS(list(ris = ris, identiche = identiche, st = st, viste = viste, rif = rif, oggi = oggi, v1 = v1, sv = sv, campi = campi), Sys.getenv("S12R3_OGGETTI"))
cat("\nFINITO\n")
