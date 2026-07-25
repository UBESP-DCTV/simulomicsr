# REGOLE DI RIGA — scarto dei confronti mal appaiati dentro un gruppo coerente.
#
# Un gruppo puo' misurare la cosa giusta e contenere lo stesso righe mal appaiate:
# il gruppo dice "che cosa", la riga dice "come e' stato confrontato". Quattro
# forme, tutte viste leggendo i dati veri (verifica riga per riga 2026-07-25):
#
#   T1 tempo non appaiato        trattato 24h vs controllo 0h
#   T2 controllo di linea/donatore diverso   "Erlotinib MSN08" vs "DMSO MSN01"
#   T3 combinazione non vista    "TNF-alpha IL-1alpha" vs "Control"
#   T4 genetica su un solo braccio  "+ shMfn2 + TNF" vs "+ DMSO"
#
# Le regole sono DETERMINISTICHE e generali: nessuna lista di righe, nessun LLM.
# Nessuna funzione qui dentro esegue nulla: si caricano con source().

## ---------------------------------------------------------------- utilita' ---
if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0L || is.na(a[1])) b else a

## "_" e "|" sono SEPARATORI, non lettere. Per le espressioni regolari "_" e'
## carattere di parola: senza questa normalizzazione "\\bsirna\\b" non vede
## "Control_siRNA_1", "10day" dentro "osimertinib_10day" non e' un tempo, e
## "MSR-A549_JQ1" diventa un unico codice diverso da "MSR-A549_DMSO".
## E' lo stesso inciampo gia' pagato su "calcium_low".
rr_sep <- function(x) trimws(gsub("\\s+", " ", gsub("[_|]+", " ", x %||% "")))

## dosi, concentrazioni e tempi non identificano ne' una linea ne' un soggetto:
## vanno tolti PRIMA di cercare identificatori, altrimenti "LPS 12H" diventa un
## nome di linea cellulare (falso allarme misurato).
rr_drop_doses <- function(x) {
  x <- tolower(rr_sep(paste(x, collapse = " ")))
  x <- gsub("\\b\\d+([.,]\\d+)?\\s*(ug|mg|ng|pg|kg|g|ul|ml|dl|l|nm|um|mm|pm|iu|moi|pfu|ffu|%)\\s*(/\\s*(ml|l|kg|g|ul))?", " ", x, perl = TRUE)
  x <- gsub("\\b\\d+([.,]\\d+)?\\s*(h|hr|hrs|hour|hours|d|day|days|week|weeks|wk|min|mins|minute|minutes|mo|month|months|hpi|dpi)\\b", " ", x, perl = TRUE)
  x <- gsub("\\b(ug|mg|ng|kg|ul|ml|nm|um|iu|moi|pfu)\\s*/\\s*(ml|l|kg|g|ul|min)\\b", " ", x, perl = TRUE)
  trimws(gsub("\\s+", " ", x))
}

## ------------------------------------------------------- T1 tempo non appaiato
## I tempi si normalizzano in ORE: "7D" e "168h" sono lo stesso tempo, "1 day" e
## "24h" pure. Senza normalizzazione si segnalerebbero appaiamenti corretti.
RR_TEMPO_RX <- "\\b([0-9]+(?:[.,][0-9]+)?)\\s*(hpi|dpi|hrs|hr|hours|hour|h|days|day|d|weeks|week|wks|wk|minutes|minute|mins|min|months|month|mo)\\b"
rr_tempi_ore <- function(x) {
  s <- tolower(rr_sep(x))
  m <- regmatches(s, gregexpr(RR_TEMPO_RX, s, perl = TRUE))[[1]]
  if (!length(m)) return(numeric(0))
  val <- as.numeric(sub(",", ".", sub("^([0-9]+(?:[.,][0-9]+)?).*$", "\\1", m)))
  un <- trimws(gsub("^[0-9.,]+\\s*", "", m))
  fat <- c(h = 1, hr = 1, hrs = 1, hour = 1, hours = 1, hpi = 1,
           d = 24, day = 24, days = 24, dpi = 24,
           wk = 168, wks = 168, week = 168, weeks = 168,
           min = 1/60, mins = 1/60, minute = 1/60, minutes = 1/60,
           mo = 720, month = 720, months = 720)
  f <- fat[un]
  sort(unique(round(val * ifelse(is.na(f), 1, f), 3)))
}
## Difetto: entrambi i bracci dichiarano un tempo e nessuno dei due coincide.
rr_tempo_non_appaiato <- function(tl, cl) {
  tt <- rr_tempi_ore(tl); tc <- rr_tempi_ore(cl)
  length(tt) > 0 && length(tc) > 0 && length(intersect(tt, tc)) == 0
}

## --------------------------------------- T2 linea / donatore / soggetto diverso
## Identificatori: (a) "Donor 62", "Patient 21", "Subject 4870"; (b) codici che
## mescolano lettere e cifre ("MSN01", "LAPC4", "CWR-22Rv1", "N35").
## Si escludono le sigle biologiche correnti ("IL-1", "SARS-CoV-2", "5-FU"):
## sono nomi di molecole o di sottotipi cellulari, non di linee.
RR_SOGGETTO_RX <- "\\b(donor|donors|patient|patients|subject|subjects|volunteer|participant|case|sample|samples|specimen)[ .:-]*([a-z]{0,4}[0-9]+[a-z0-9-]*)\\b"
## gli identificatori di ARCHIVIO (GSM/GSE/SRR/SAMN...) nominano il campione, non
## la linea: "hALO SARS-CoV-2 (GSM4711203)" vs "hALO Mock (GSM4711201)" e' appaiato.
RR_ARCHIVIO_RX <- "^(gsm|gse|gpl|srr|srx|srs|srp|err|erx|prjna|prjeb|samn|same|biosample)[0-9]+$"
RR_NON_IDENT <- c("covid-19", "covid19", "sars-cov-2", "sars-cov2", "sarscov2", "mers-cov",
  "h1n1", "h3n2", "h5n1", "hsv-1", "hsv-2", "hhv-6", "il-1", "il1", "il-2", "il-4", "il-6", "il6",
  "il-8", "il-10", "il-12", "il-13", "il-17", "il-18", "il-1a", "il-1b", "il-21", "il-15",
  "tgf-b1", "tgf-beta1", "tgfb1", "tnf-a", "ifn-g", "ifn-a", "ifn-b", "5-fu", "5fu", "h2o2",
  "o2", "co2", "n2", "th1", "th2", "th17", "cd4", "cd8", "cd14", "cd34", "cd19", "cd3", "cd45",
  "pd-1", "pd-l1", "her2", "p53", "1a", "1b", "2a", "2b", "3a", "3b", "4a", "4b",
  "t1d", "t2d", "type1", "type2", "g1", "g2", "g0", "s1", "s2", "s3", "m1", "m2",
  "p1", "p2", "p3", "p4", "p5", "d1", "d2", "d3", "d7", "poly-ic", "polyic", "3d", "2d",
  "hiv-1", "hiv-2", "htlv-1", "hbv-1", "hcv-1", "ebv-1")
## descrizioni anagrafiche: "39-year-old male" non e' un codice di linea.
RR_ANAGRAFICA_RX <- "^[0-9]+-(year|yr|month|week|day)s?-old$"
## Restituisce due liste separate: i soggetti dichiarati ("Donor 62") e i codici
## di linea/campione ("MSN01", "CWR-22Rv1"). Le due categorie NON si mescolano:
## un codice condiviso non deve poter cancellare una differenza di donatore
## (misurato: "Donor1 HBV D6" vs "Donor2 Mock D6" sfuggiva perche' "D6" era in
## comune).
rr_identificatori <- function(x, extra_stop = character(0)) {
  s <- rr_drop_doses(x)
  s <- gsub("[^a-z0-9 .:-]+", " ", s)
  sog <- regmatches(s, gregexpr(RR_SOGGETTO_RX, s, perl = TRUE))[[1]]
  ids_sog <- if (length(sog)) unique(sub(RR_SOGGETTO_RX, "\\2", sog, perl = TRUE)) else character(0)
  ## i token gia' consumati come "Donor 62" non vanno riletti come codici
  s2 <- gsub(RR_SOGGETTO_RX, " ", s, perl = TRUE)
  ## un codice = token con almeno una lettera E almeno una cifra. Il test diretto
  ## batte l'espressione regolare: quella richiedeva la cifra nel primo segmento
  ## e perdeva "CWR-22Rv1" (difetto vero non visto).
  tk <- strsplit(s2, "[^a-z0-9.-]+")[[1]]
  tk <- unique(trimws(gsub("^[.-]+|[.-]+$", "", tk)))
  cod <- tk[nzchar(tk) & grepl("[a-z]", tk) & grepl("[0-9]", tk) &
              nchar(gsub("[^a-z0-9]", "", tk)) >= 2]
  cod <- setdiff(cod, c(RR_NON_IDENT, extra_stop))
  cod <- cod[!grepl(RR_ARCHIVIO_RX, cod) & !grepl(RR_ANAGRAFICA_RX, cod)]
  list(soggetti = ids_sog, codici = unique(cod))
}
## numeri contenuti in un insieme di codici: "LS4" e "LM4" sono lo stesso
## soggetto in due condizioni (lung-SARS / lung-mock), "MSN08" e "MSN01" no.
rr_numeri <- function(cod) {
  if (!length(cod)) return(character(0))
  sort(unique(unlist(regmatches(cod, gregexpr("[0-9]+", cod)))))
}
## caso-controllo clinico travestito: "HIV-positive Subject 14" vs "Subject 12
## (HIV-negative)". Qui i soggetti DEVONO essere diversi: non e' un difetto.
rr_caso_controllo_clinico <- function(tl, cl) {
  grepl("positiv", tolower(tl %||% "")) && grepl("negativ", tolower(cl %||% ""))
}
## Difetto: entrambi i bracci nominano un identificatore e non ne condividono
## nessuno. Vale SOLO nei disegni di trattamento: nei caso-controllo di malattia
## i soggetti sono per forza persone diverse (decisione utente 2026-07-25).
rr_soggetto_diverso <- function(tl, cl, cls, extra_stop = character(0)) {
  if (identical(cls, "disease")) return(FALSE)
  if (rr_caso_controllo_clinico(tl, cl)) return(FALSE)
  it <- rr_identificatori(tl, extra_stop); ic <- rr_identificatori(cl, extra_stop)
  ## (a) donatori/pazienti dichiarati e diversi
  if (length(it$soggetti) > 0 && length(ic$soggetti) > 0 &&
      length(intersect(it$soggetti, ic$soggetti)) == 0) return(TRUE)
  ## (b) codici di linea/campione diversi NEI NUMERI. Se i numeri coincidono i due
  ## codici designano lo stesso soggetto in due condizioni ("LS4" / "LM4"); se un
  ## codice contiene l'altro, i due bracci nominano la stessa linea con dettaglio
  ## diverso ("FLAGHA-H3F3A" e "H3F3A").
  if (length(it$codici) > 0 && length(ic$codici) > 0 &&
      length(intersect(it$codici, ic$codici)) == 0 &&
      !identical(rr_numeri(it$codici), rr_numeri(ic$codici)) &&
      !any(outer(it$codici, ic$codici, Vectorize(function(a, b)
        grepl(b, a, fixed = TRUE) || grepl(a, b, fixed = TRUE))))) return(TRUE)
  FALSE
}

## ----------------------------------------------- T3 combinazione non catturata
## Il braccio trattato porta >= 2 agenti che il controllo non ha: il contrasto
## non isola l'entita' del gruppo. Non si applica ai gruppi che SONO una
## combinazione (li' i due agenti sono l'entita' stessa).
## I veicoli e i termini-ombrello non sono agenti: senza questa lista
## "prostate cancer" e "ethanol" facevano numero (falsi allarmi misurati).
RR_NON_AGENTE <- c("ethanol", "dmso", "pbs", "saline", "water", "vehicle", "medium", "media",
  "buffer", "cancer", "tumor", "tumour", "carcinoma", "neoplasm", "disease", "control",
  "untreated", "treated", "normal", "healthy", "mock", "naive", "adjacent", "tissue", "cells",
  "cell", "line", "primary", "culture", "patient", "donor", "sample",
  ## sierotipi e ceppi: nominano lo stesso agente, non un secondo agente
  ## ("IAV (H1N1)" e' un virus solo).
  "h1n1", "h3n2", "h5n1", "h7n9", "ad169", "tb40", "tb40e", "wa1", "usa-wa1", "wuhan")
rr_agenti <- function(x, oe, cache = NULL) {
  tk <- strsplit(rr_drop_doses(gsub("[^A-Za-z0-9 -]", " ", x %||% "")), " +")[[1]]
  tk <- unique(tk[nchar(gsub("[^a-z0-9]", "", tk)) >= 3 & !(tk %in% RR_NON_AGENTE)])
  ## una sigla che e' l'inizio di un'altra parola della stessa etichetta non e' un
  ## secondo agente: "mitoxantrone (MIT)" nomina una molecola sola (e "MIT" da
  ## solo risolve a 3-iodo-L-tirosina, collisione di alias nota).
  if (length(tk) > 1) {
    pref <- vapply(tk, function(t) any(tk != t & startsWith(tk, t)), logical(1))
    tk <- tk[!pref]
  }
  if (!length(tk)) return(character(0))
  ok <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  res <- character(0)
  for (t in tk) {
    if (!is.null(cache) && exists(t, envir = cache, inherits = FALSE)) {
      v <- get(t, envir = cache)
    } else {
      v <- ""
      x1 <- .normalize_compound_to_chebi(t, oe); if (ok(x1$id)) v <- x1$id
      if (!nzchar(v)) { x1 <- .normalize_cytokine_to_hgnc(t, oe); if (ok(x1$id)) v <- x1$id }
      if (!nzchar(v)) { x1 <- .normalize_pathogen_to_taxid(t, oe); if (ok(x1$id)) v <- x1$id }
      if (!is.null(cache)) assign(t, v, envir = cache)
    }
    if (nzchar(v)) res <- c(res, v)
  }
  unique(res)
}
rr_combinazione_non_vista <- function(tl, cl, entity, oe, cache = NULL) {
  if (!is.na(entity) && startsWith(entity, "COMBO:")) return(FALSE)
  at <- rr_agenti(tl, oe, cache); ac <- rr_agenti(cl, oe, cache)
  length(setdiff(at, ac)) >= 2
}

## ------------------------------------------- T4 genetica su un braccio soltanto
## Marcatori ESPLICITI. I pattern sh/si/sg valgono solo case-sensitive seguiti da
## maiuscola ("shMfn2", "siRNA"): in minuscolo catturano parole comuni
## ("sigmoid", "single", "significant") — 21 falsi allarmi misurati.
## "wild-type" NON e' un marcatore: dice che una modifica NON c'e' (e nei ceppi
## virali indica il ceppo non mutato — "wildtype HSV-1" vs "mock" non e' un
## difetto genetico).
RR_GEN_CS_RX <- "\\b(sh|si|sg)[A-Z][A-Za-z0-9]{1,}\\b"
RR_GEN_CI_RX <- paste0("knock-?down|knock-?out|\\bko\\b|\\bkd\\b|crispr|cas9|transgen(e|ic)|",
  "over-?express|\\bshrna\\b|\\bsirna\\b|\\bsgrna\\b|\\bgrna\\b|empty vector|vector control|",
  "silenc|lentivir|\\bdegron\\b|\\bdtag\\b|\\bmaid\\b")
rr_ha_genetica <- function(x) {
  s <- rr_sep(x %||% "")
  grepl(RR_GEN_CS_RX, s, perl = TRUE) || grepl(RR_GEN_CI_RX, tolower(s), perl = TRUE)
}
## Non si applica quando la perturbazione genetica E' l'entita' del gruppo.
rr_genetica_asimmetrica <- function(tl, cl, cls, entity) {
  if (identical(cls, "genetic")) return(FALSE)
  if (!is.na(entity) && grepl("knock|shrna|sirna|sgrna|crispr|silenc", tolower(entity))) return(FALSE)
  rr_ha_genetica(tl) != rr_ha_genetica(cl)
}

## ------------------------------------------------------------------ verdetto --
## Restituisce "" se la riga e' appaiata, altrimenti il nome della regola violata.
rr_difetto_riga <- function(tl, cl, cls, entity, oe, cache = NULL, extra_stop = character(0)) {
  if (rr_tempo_non_appaiato(tl, cl)) return("tempo_non_appaiato")
  if (rr_soggetto_diverso(tl, cl, cls, extra_stop)) return("soggetto_diverso")
  if (rr_genetica_asimmetrica(tl, cl, cls, entity)) return("genetica_asimmetrica")
  if (rr_combinazione_non_vista(tl, cl, entity, oe, cache)) return("combinazione_non_vista")
  ""
}
