#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/A0-schema-verificabile.R
#
# LO SCHEMA PER IL CONTROLLO A MANO.
#
# Per ognuna delle 194 meta-analisi: quali campioni ci finiscono dentro, da quale
# braccio di quale confronto di quale studio, con accanto DUE COSE:
#   - il DATO GREZZO: la stringa esatta che lo Stadio 1 ha letto, piu' i campi
#     originali dell'H5 (titolo, caratteristiche, sorgente) non toccati da nessuno;
#   - il DATO DERIVATO: che cosa la pipeline ne ha tirato fuori (l'etichetta del
#     braccio prodotta dallo Stadio 2, il ruolo trattato/controllo, l'entita' e il
#     tipo di controllo che formano la chiave del gruppo).
#
# Cosi' ogni riga si puo' controllare da sola: la stringa grezza giustifica
# l'etichetta? L'etichetta giustifica il ruolo? Il ruolo giustifica il gruppo?
#
# I campioni sono quelli VERI del pooling: l'insieme viene dalla replica del
# dispatch di produzione, validata contro il registro degli scarti e contro
# per_study_de (vedi 00-materiale.R, PROVA A e PROVA B).
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/A0-schema-verificabile.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli) })

OUT     <- "analysis/audit/2026-08-20-rilettura-194"
SCHEDE  <- file.path(OUT, "schede")
A3_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
H5      <- "analysis/input/human_gene_v2.5.h5"
S1_IN   <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
stopifnot(file.exists(H5), file.exists(S1_IN))
dir.create(SCHEDE, showWarnings = FALSE, recursive = TRUE)

d <- readRDS(file.path(A3_POOL, "deliverable-annotato.rds"))
A <- readRDS(file.path(OUT, "dispatch-A3.rds"))$tenuti
v <- read.csv(file.path(OUT, "verdetti-194.csv"), stringsAsFactors = FALSE)
# la copertura per studio, prodotta da A1-campioni-persi.R
PERSI <- read.csv(file.path(OUT, "campioni-persi-per-studio.csv"), stringsAsFactors = FALSE,
                  colClasses = c(persi = "character"))
cli_alert_info("meta-analisi: {nrow(d)} | confronti poolati: {nrow(A)}")

# --- una riga per CAMPIONE ----------------------------------------------------
righe <- list()
for (i in seq_len(nrow(A))) {
  x <- A[i, ]
  for (ruolo in c("TRATTATO", "CONTROLLO")) {
    gsms <- strsplit(if (ruolo == "TRATTATO") x$gsm_t else x$gsm_c, ",", fixed = TRUE)[[1L]]
    if (!length(gsms)) next
    righe[[length(righe) + 1L]] <- data.frame(
      cluster_id = x$cluster_id, studio = x$study_id, confronto = x$record_id,
      braccio = ruolo,
      gruppo_stadio2 = if (ruolo == "TRATTATO") x$treated_group else x$control_group,
      etichetta_braccio = if (ruolo == "TRATTATO") x$etichetta_trattato else x$etichetta_controllo,
      gsm = gsms, stringsAsFactors = FALSE)
  }
}
S <- do.call(rbind, righe)
cli_alert_info("righe campione-in-meta-analisi: {nrow(S)} | campioni distinti: {length(unique(S$gsm))}")

# --- il GREZZO: la stringa dello Stadio 1 e i campi originali dell'H5 ---------
cli_alert_info("leggo la stringa che lo Stadio 1 ha letto...")
con <- file(S1_IN, "r"); need <- unique(S$gsm)
str1 <- new.env(hash = TRUE, parent = emptyenv())
repeat {
  ln <- readLines(con, n = 50000L, warn = FALSE)
  if (!length(ln)) break
  # estrazione a mano: piu' veloce di parsare 508k oggetti JSON
  ga <- sub('^.*"geo_accession":"([^"]*)".*$', "\\1", ln)
  st <- sub('^.*"string":"(.*?)","library_strategy".*$', "\\1", ln)
  k <- ga %in% need
  if (any(k)) for (j in which(k)) assign(ga[j], st[j], envir = str1)
}
close(con)
S$stringa_stadio1 <- vapply(S$gsm, function(g)
  if (exists(g, envir = str1, inherits = FALSE)) get(g, envir = str1, inherits = FALSE) else NA_character_,
  character(1), USE.NAMES = FALSE)
cli_alert_info("stringhe ritrovate: {sum(!is.na(S$stringa_stadio1))}/{nrow(S)}")

cli_alert_info("leggo i campi originali dell'H5...")
f <- c("geo_accession","title","source_name_ch1","characteristics_ch1","organism_ch1","molecule_ch1")
h <- lapply(stats::setNames(f, f), function(z)
  as.character(rhdf5::h5read(H5, paste0("meta/samples/", z))))
rhdf5::h5closeAll()
m <- match(S$gsm, h$geo_accession)
S$h5_titolo         <- h$title[m]
S$h5_sorgente       <- h$source_name_ch1[m]
S$h5_caratteristiche<- h$characteristics_ch1[m]
S$h5_organismo      <- h$organism_ch1[m]
S$h5_molecola       <- h$molecule_ch1[m]

# --- il DERIVATO: la chiave della meta-analisi -------------------------------
j <- match(S$cluster_id, d$cluster_id)
S$entita_id     <- d$contrast_entity[j]
S$entita_nome   <- d$contrast_entity_label[j]
S$verso         <- d$contrast_direction[j]
S$tipo_controllo<- d$contrast_control_key[j]
S$k_studi       <- d$k_effective[j]
S$verdetto_rilettura <- v$verdetto_finale[match(S$cluster_id, v$cluster_id)]

nome_ma <- function(i) sprintf("%s [%s] %s / %s",
  ifelse(is.na(d$contrast_entity_label[i]) | !nzchar(d$contrast_entity_label[i]),
         d$contrast_entity[i], d$contrast_entity_label[i]),
  d$contrast_entity[i], d$contrast_direction[i], d$contrast_control_key[i])
S$meta_analisi <- vapply(j, nome_ma, character(1))

col <- c("meta_analisi","cluster_id","entita_id","entita_nome","verso","tipo_controllo",
         "k_studi","verdetto_rilettura","studio","confronto","braccio","gruppo_stadio2",
         "gsm","stringa_stadio1","h5_titolo","h5_sorgente","h5_caratteristiche",
         "h5_organismo","h5_molecola","etichetta_braccio")
S <- S[order(-S$k_studi, S$cluster_id, S$studio, S$confronto, S$braccio, S$gsm), col]
utils::write.csv(S, file.path(OUT, "campioni-per-meta-analisi.csv"), row.names = FALSE)
cli_alert_success("Scritto campioni-per-meta-analisi.csv ({nrow(S)} righe)")

# --- una SCHEDA leggibile per ogni meta-analisi ------------------------------
ord <- order(-d$k_effective, d$contrast_entity)
sicuro <- function(s) gsub("[^A-Za-z0-9._-]", "_", substr(s, 1, 40))
for (n in seq_along(ord)) {
  i <- ord[n]; cid <- d$cluster_id[i]
  s <- S[S$cluster_id == cid, ]
  nm <- d$contrast_entity_label[i]
  if (is.na(nm) || !nzchar(nm)) nm <- d$contrast_entity[i]
  L <- c(
    sprintf("META-ANALISI %03d di 194", n), strrep("=", 78),
    sprintf("nome            : %s", nm),
    sprintf("entita (ID)     : %s", d$contrast_entity[i]),
    sprintf("verso           : %s", d$contrast_direction[i]),
    sprintf("tipo di controllo: %s", d$contrast_control_key[i]),
    sprintf("cluster_id      : %s", cid),
    sprintf("studi poolati   : %d   confronti: %d   campioni: %d",
            d$k_effective[i], length(unique(s$confronto)), nrow(s)),
    sprintf("geni significativi: %d   I2 mediano: %.1f", d$n_sig[i], d$I2_med[i]),
    sprintf("verdetto della rilettura: %s", v$verdetto_finale[match(cid, v$cluster_id)]),
    "",
    "COME SI LEGGE: ogni confronto ha due bracci. Per ogni campione trovi la",
    "STRINGA GREZZA che lo Stadio 1 ha letto (invariata) e, sopra, l'ETICHETTA",
    "che lo Stadio 2 ha prodotto per il braccio. Il controllo da fare e': la",
    "stringa grezza giustifica l'etichetta? I due bracci sono appaiati?",
    strrep("-", 78), "")
  for (cf in unique(s$confronto)) {
    z <- s[s$confronto == cf, ]
    L <- c(L, sprintf("CONFRONTO  %s", cf),
              sprintf("  studio: %s", z$studio[1]))
    for (r in c("TRATTATO", "CONTROLLO")) {
      w <- z[z$braccio == r, ]
      if (!nrow(w)) next
      L <- c(L, sprintf("  %s  (n=%d)  etichetta Stadio 2: %s",
                        r, nrow(w), w$etichetta_braccio[1]),
                sprintf("      gruppo Stadio 2: %s", w$gruppo_stadio2[1]))
      for (q in seq_len(nrow(w))) L <- c(L,
        sprintf("      %s", w$gsm[q]),
        sprintf("        grezzo (Stadio 1): %s", w$stringa_stadio1[q]),
        sprintf("        H5 titolo        : %s", w$h5_titolo[q]),
        sprintf("        H5 caratteristiche: %s", w$h5_caratteristiche[q]),
        sprintf("        H5 sorgente      : %s", w$h5_sorgente[q]))
    }
    L <- c(L, "")
  }
  # NESSUN TAGLIO SILENZIOSO. Chi controlla a mano vede bracci con n=2 dove i GSM
  # dello studio sono di piu', e non ha modo di sapere se e' il gate o una perdita
  # a monte. Qui si dichiara, studio per studio: quanti campioni ha lo studio
  # nell'H5, quanti lo Stadio 2 ne ha collocati in un gruppo qualsiasi, e quanti
  # non stanno in NESSUN gruppo (persi dallo Stadio 2, non dal gate).
  L <- c(L, strrep("-", 78),
         "COPERTURA DEGLI STUDI — che fine hanno fatto gli altri campioni",
         "",
         "  ⚠️ IL CONFRONTO E' CON QUELLO CHE LO STADIO 2 HA RICEVUTO, non con",
         "  quello che lo studio ha in GEO. Prima dello Stadio 2 c'e' lo Stadio 0,",
         "  che esclude con un motivo dichiarato: non umano, non RNA-Seq bulk,",
         "  protocollo single-cell, libreria troppo piccola, stringa troppo corta.",
         "  Quelle esclusioni sono controlli di qualita' che funzionano e NON sono",
         "  perdite: GSE200186, per esempio, ha 1.179 campioni in GEO e ne manda 27",
         "  allo Stadio 2 perche' gli altri 1.152 sono single-cell.",
         "",
         "  Un campione RICEVUTO dallo Stadio 2 puo' non essere qui per tre motivi:",
         "  (a) sta in un ALTRO gruppo dello Stadio 2, che serve un altro confronto;",
         "  (b) e' caduto al gate (n_min<2 sul braccio, o doppione dello stesso",
         "      braccio trattato): il registro completo e' in qc_report$dispatch_drops;",
         "  (c) non sta in NESSUN gruppo: lo Stadio 2 l'ha perso, senza motivo",
         "      dichiarato. Questo si vede qui, ed e' l'unico che sia un difetto.",
         "")
  for (g in sort(unique(s$studio))) {
    k <- match(g, PERSI$studio)
    if (is.na(k)) { L <- c(L, sprintf("  %s: copertura non misurata", g)); next }
    # ⚠️ CAMPIONI DISTINTI, non righe: un braccio di controllo puo' servire piu'
    # confronti dello stesso studio, quindi lo stesso GSM compare piu' volte
    # nella scheda. Contando le righe usciva «usati qui: 20» su uno studio che ha
    # 18 campioni in tutto — un numero che sembra un errore e non lo e'.
    qui <- length(unique(s$gsm[s$studio == g]))
    righe_qui <- sum(s$studio == g)
    L <- c(L, sprintf("  %-12s  ricevuti dallo Stadio 2: %4d | collocati in un gruppo: %4d | PERSI: %4d | usati in questa meta-analisi: %d campioni distinti (%d righe: i controlli servono piu' confronti)",
                      g, PERSI$n_ricevuti[k], PERSI$n_collocati[k], PERSI$n_persi[k], qui, righe_qui))
    if (PERSI$n_persi[k] > 0) {
      pp <- strsplit(PERSI$persi[k], ",", fixed = TRUE)[[1L]]
      L <- c(L, sprintf("      mai collocati: %s%s",
                        paste(utils::head(pp, 12), collapse = ", "),
                        if (length(pp) > 12) sprintf(" ... (+%d)", length(pp) - 12) else ""))
    }
  }
  L <- c(L, "")
  writeLines(L, file.path(SCHEDE, sprintf("%03d-%s-k%02d.txt", n, sicuro(nm), d$k_effective[i])))
}
cli_alert_success("Scritte {length(ord)} schede in {.path {SCHEDE}}")

# --- l'indice ----------------------------------------------------------------
idx <- data.frame(
  n = seq_along(ord),
  scheda = sprintf("%03d-%s-k%02d.txt", seq_along(ord), sicuro(
    ifelse(is.na(d$contrast_entity_label[ord]) | !nzchar(d$contrast_entity_label[ord]),
           d$contrast_entity[ord], d$contrast_entity_label[ord])), d$k_effective[ord]),
  nome = ifelse(is.na(d$contrast_entity_label[ord]) | !nzchar(d$contrast_entity_label[ord]),
                d$contrast_entity[ord], d$contrast_entity_label[ord]),
  entita = d$contrast_entity[ord], verso = d$contrast_direction[ord],
  controllo = d$contrast_control_key[ord], cluster_id = d$cluster_id[ord],
  studi = d$k_effective[ord],
  campioni = as.integer(table(S$cluster_id)[d$cluster_id[ord]]),
  verdetto = v$verdetto_finale[match(d$cluster_id[ord], v$cluster_id)],
  stringsAsFactors = FALSE)
utils::write.csv(idx, file.path(OUT, "INDICE-194.csv"), row.names = FALSE)
cli_alert_success("Scritto INDICE-194.csv")
