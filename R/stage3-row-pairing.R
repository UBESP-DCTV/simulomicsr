# Appaiamento della RIGA (un confronto trattato-vs-controllo dentro un gruppo).
#
# Il gruppo dice CHE COSA si misura; la riga dice COME e' stato confrontato. Un
# gruppo puo' essere coerente e contenere lo stesso confronti mal appaiati. La
# verifica riga per riga dei 143 gruppi coerenti (2026-07-25) ne ha trovate
# quattro forme, tutte lette sui dati veri:
#
#   tempo_non_appaiato     trattato 24h vs controllo 0h
#   soggetto_diverso       "Erlotinib MSN08" vs "DMSO MSN01" (donatore/linea)
#   genetica_asimmetrica   "+ shMfn2 + TNF" vs "+ DMSO"
#   combinazione_non_vista "TNF-alpha IL-1alpha" vs "Control"
#
# Decisione utente 2026-07-25: queste righe si SCARTANO, accettando che i gruppi
# che scendono sotto i 3 studi si perdano. Le regole sono deterministiche e
# generali (nessuna lista di righe, nessun LLM a runtime).

#' Normalizza i separatori prima di applicare le espressioni regolari
#'
#' \code{_} e \code{|} sono separatori, non lettere: per le espressioni regolari
#' \code{_} e' pero' carattere di parola, quindi \code{\\bsirna\\b} non vede
#' \code{Control_siRNA_1} e \code{10day} dentro \code{osimertinib_10day} non e'
#' un tempo. Stesso inciampo gia' pagato su \code{calcium_low}.
#' @keywords internal
.rp_normalize_separators <- function(x) {
  if (length(x) == 0L || is.na(x[1L])) return("")
  trimws(gsub("\\s+", " ", gsub("[_|]+", " ", paste(x, collapse = " "))))
}

#' Toglie dosi, concentrazioni e tempi da un'etichetta
#'
#' Dosi e tempi non identificano ne' una linea ne' un soggetto: vanno rimossi
#' prima di cercare identificatori, altrimenti \code{LPS 12H} diventa un nome di
#' linea cellulare.
#' @keywords internal
.rp_strip_dose_time <- function(x) {
  s <- tolower(.rp_normalize_separators(x))
  s <- gsub("\\b\\d+([.,]\\d+)?\\s*(ug|mg|ng|pg|kg|g|ul|ml|dl|l|nm|um|mm|pm|iu|moi|pfu|ffu|%)\\s*(/\\s*(ml|l|kg|g|ul))?",
            " ", s, perl = TRUE)
  s <- gsub("\\b\\d+([.,]\\d+)?\\s*(h|hr|hrs|hour|hours|d|day|days|week|weeks|wk|min|mins|minute|minutes|mo|month|months|hpi|dpi)\\b",
            " ", s, perl = TRUE)
  s <- gsub("\\b(ug|mg|ng|kg|ul|ml|nm|um|iu|moi|pfu)\\s*/\\s*(ml|l|kg|g|ul|min)\\b", " ", s, perl = TRUE)
  trimws(gsub("\\s+", " ", s))
}

.RP_TIME_RX <- paste0("\\b([0-9]+(?:[.,][0-9]+)?)\\s*",
                      "(hpi|dpi|hrs|hr|hours|hour|h|days|day|d|weeks|week|wks|wk|",
                      "minutes|minute|mins|min|months|month|mo)\\b")
.RP_TIME_FACTORS <- c(h = 1, hr = 1, hrs = 1, hour = 1, hours = 1, hpi = 1,
                      d = 24, day = 24, days = 24, dpi = 24,
                      wk = 168, wks = 168, week = 168, weeks = 168,
                      min = 1 / 60, mins = 1 / 60, minute = 1 / 60, minutes = 1 / 60,
                      mo = 720, month = 720, months = 720)

#' Tempi dichiarati in un'etichetta, normalizzati in ore
#'
#' \code{7D} e \code{168h} sono lo stesso tempo, \code{1 day} e \code{24h} pure:
#' senza normalizzazione si segnalerebbero come difetti degli appaiamenti
#' corretti.
#' @return numeric ordinato e senza duplicati (lunghezza 0 se nessun tempo)
#' @keywords internal
.rp_time_hours <- function(x) {
  s <- tolower(.rp_normalize_separators(x))
  m <- regmatches(s, gregexpr(.RP_TIME_RX, s, perl = TRUE))[[1L]]
  if (!length(m)) return(numeric(0))
  val <- as.numeric(sub(",", ".", sub("^([0-9]+(?:[.,][0-9]+)?).*$", "\\1", m)))
  unit <- trimws(gsub("^[0-9.,]+\\s*", "", m))
  fac <- .RP_TIME_FACTORS[unit]
  sort(unique(round(val * ifelse(is.na(fac), 1, fac), 3)))
}

#' I due bracci dichiarano tempi diversi e nessuno in comune
#' @keywords internal
.rp_time_mismatch <- function(treated_label, control_label) {
  tt <- .rp_time_hours(treated_label)
  tc <- .rp_time_hours(control_label)
  length(tt) > 0L && length(tc) > 0L && length(intersect(tt, tc)) == 0L
}

.RP_SUBJECT_RX <- paste0("\\b(donor|donors|patient|patients|subject|subjects|volunteer|",
                         "participant|case|sample|samples|specimen)[ .:-]*([a-z]{0,4}[0-9]+[a-z0-9-]*)\\b")
# identificatori di ARCHIVIO: nominano il campione depositato, non la linea
.RP_ARCHIVE_RX <- "^(gsm|gse|gpl|srr|srx|srs|srp|err|erx|prjna|prjeb|samn|same|biosample)[0-9]+$"
# descrizioni anagrafiche: "39-year-old male" non e' un codice di linea
.RP_AGE_RX <- "^[0-9]+-(year|yr|month|week|day)s?-old$"
# sigle biologiche correnti: nomi di molecole, virus o sottotipi cellulari
.RP_NOT_IDENTIFIER <- c(
  "covid-19", "covid19", "sars-cov-2", "sars-cov2", "sarscov2", "mers-cov",
  "h1n1", "h3n2", "h5n1", "hsv-1", "hsv-2", "hhv-6", "hiv-1", "hiv-2", "htlv-1",
  "il-1", "il1", "il-2", "il-4", "il-6", "il6", "il-8", "il-10", "il-12", "il-13",
  "il-15", "il-17", "il-18", "il-21", "il-1a", "il-1b",
  "tgf-b1", "tgf-beta1", "tgfb1", "tnf-a", "ifn-g", "ifn-a", "ifn-b",
  "5-fu", "5fu", "h2o2", "o2", "co2", "n2", "poly-ic", "polyic",
  "th1", "th2", "th17", "cd3", "cd4", "cd8", "cd14", "cd19", "cd34", "cd45",
  "pd-1", "pd-l1", "her2", "p53", "m1", "m2", "g0", "g1", "g2",
  "1a", "1b", "2a", "2b", "3a", "3b", "4a", "4b", "2d", "3d",
  "t1d", "t2d", "type1", "type2", "s1", "s2", "s3",
  "p1", "p2", "p3", "p4", "p5", "d1", "d2", "d3", "d7")

#' Identificatori di soggetto e di linea cellulare presenti in un'etichetta
#'
#' Le due categorie restano separate: un codice condiviso non deve poter
#' cancellare una differenza di donatore (misurato: \code{Donor1 HBV D6} vs
#' \code{Donor2 Mock D6} sfuggiva perche' \code{D6} era in comune).
#'
#' @param extra_stop character: token da non considerare identificatori (i nomi
#'   dell'entita' del contrasto: \code{R1881}, \code{AD169} appartengono al nome
#'   del composto o del ceppo, non alla linea).
#' @return list con \code{subjects} e \code{codes}
#' @keywords internal
.rp_identifiers <- function(x, extra_stop = character(0)) {
  s <- .rp_strip_dose_time(x)
  s <- gsub("[^a-z0-9 .:-]+", " ", s)
  hits <- regmatches(s, gregexpr(.RP_SUBJECT_RX, s, perl = TRUE))[[1L]]
  subjects <- if (length(hits)) unique(sub(.RP_SUBJECT_RX, "\\2", hits, perl = TRUE)) else character(0)
  rest <- gsub(.RP_SUBJECT_RX, " ", s, perl = TRUE)
  # un codice = token con almeno una lettera E almeno una cifra. Il test diretto
  # batte l'espressione regolare: quella pretendeva la cifra nel primo segmento e
  # perdeva "CWR-22Rv1".
  tok <- unique(trimws(gsub("^[.-]+|[.-]+$", "", strsplit(rest, "[^a-z0-9.-]+")[[1L]])))
  codes <- tok[nzchar(tok) & grepl("[a-z]", tok) & grepl("[0-9]", tok) &
                 nchar(gsub("[^a-z0-9]", "", tok)) >= 2L]
  codes <- setdiff(codes, c(.RP_NOT_IDENTIFIER, extra_stop))
  codes <- codes[!grepl(.RP_ARCHIVE_RX, codes) & !grepl(.RP_AGE_RX, codes)]
  list(subjects = subjects, codes = unique(codes))
}

#' Numeri contenuti in un insieme di codici
#'
#' \code{LS4} e \code{LM4} sono lo stesso soggetto in due condizioni (lung-SARS
#' e lung-mock); \code{MSN08} e \code{MSN01} sono due donatori diversi.
#' @keywords internal
.rp_code_numbers <- function(codes) {
  if (!length(codes)) return(character(0))
  sort(unique(unlist(regmatches(codes, gregexpr("[0-9]+", codes)))))
}

#' Caso-controllo clinico travestito da trattamento
#'
#' "HIV-positive Subject 14" vs "Subject 12 (HIV-negative)": qui i soggetti
#' DEVONO essere persone diverse, non e' un difetto di appaiamento.
#' @keywords internal
.rp_clinical_case_control <- function(treated_label, control_label) {
  grepl("positiv", tolower(.rp_normalize_separators(treated_label))) &&
    grepl("negativ", tolower(.rp_normalize_separators(control_label)))
}

#' I due bracci vengono da soggetti o linee cellulari diversi
#'
#' Vale SOLO nei disegni di trattamento: nei caso-controllo di malattia i
#' soggetti sono per forza persone diverse (decisione utente 2026-07-25).
#'
#' @param contrast_class classe dominante del contrasto ("drug", "infection",
#'   "disease", "genetic", "environment").
#' @keywords internal
.rp_subject_mismatch <- function(treated_label, control_label, contrast_class,
                                 extra_stop = character(0)) {
  if (identical(contrast_class, "disease")) return(FALSE)
  if (.rp_clinical_case_control(treated_label, control_label)) return(FALSE)
  it <- .rp_identifiers(treated_label, extra_stop)
  ic <- .rp_identifiers(control_label, extra_stop)
  # (a) donatori/pazienti dichiarati e diversi
  if (length(it$subjects) > 0L && length(ic$subjects) > 0L &&
      length(intersect(it$subjects, ic$subjects)) == 0L) return(TRUE)
  # (b) codici di linea diversi ANCHE nei numeri e non uno dentro l'altro
  if (length(it$codes) > 0L && length(ic$codes) > 0L &&
      length(intersect(it$codes, ic$codes)) == 0L &&
      !identical(.rp_code_numbers(it$codes), .rp_code_numbers(ic$codes))) {
    nested <- any(vapply(it$codes, function(a)
      any(vapply(ic$codes, function(b)
        grepl(b, a, fixed = TRUE) || grepl(a, b, fixed = TRUE), logical(1))), logical(1)))
    if (!nested) return(TRUE)
  }
  FALSE
}

# marcatori genetici ESPLICITI. I pattern sh/si/sg valgono solo case-sensitive
# seguiti da maiuscola ("shMfn2", "siRNA"): in minuscolo catturano parole comuni
# ("sigmoid", "single", "significant") — 21 falsi allarmi misurati.
.RP_GENETIC_CS_RX <- "\\b(sh|si|sg)[A-Z][A-Za-z0-9]{1,}\\b"
.RP_GENETIC_CI_RX <- paste0("knock-?down|knock-?out|\\bko\\b|\\bkd\\b|crispr|cas9|transgen(e|ic)|",
                            "over-?express|\\bshrna\\b|\\bsirna\\b|\\bsgrna\\b|\\bgrna\\b|",
                            "empty vector|vector control|silenc|lentivir|\\bdegron\\b|\\bdtag\\b|\\bmaid\\b")

#' L'etichetta dichiara una modifica genetica
#'
#' \code{wild-type} NON e' un marcatore: dice che una modifica non c'e' (e nei
#' ceppi virali indica il ceppo non mutato).
#' @keywords internal
.rp_has_genetic_marker <- function(x) {
  s <- .rp_normalize_separators(x)
  grepl(.RP_GENETIC_CS_RX, s, perl = TRUE) || grepl(.RP_GENETIC_CI_RX, tolower(s), perl = TRUE)
}

#' La modifica genetica c'e' su un braccio solo
#'
#' Non si applica quando la perturbazione genetica E' l'entita' del gruppo: li'
#' l'asimmetria e' il contrasto, non un difetto.
#' @keywords internal
.rp_genetic_asymmetry <- function(treated_label, control_label, contrast_class, entity) {
  if (identical(contrast_class, "genetic")) return(FALSE)
  if (length(entity) > 0L && !is.na(entity) &&
      grepl("knock|shrna|sirna|sgrna|crispr|silenc", tolower(entity))) return(FALSE)
  .rp_has_genetic_marker(treated_label) != .rp_has_genetic_marker(control_label)
}

# veicoli, contesto e sierotipi non sono agenti: senza questa lista "prostate
# cancer" e "ethanol" facevano numero, e "IAV (H1N1)" contava due virus.
.RP_NOT_AGENT <- c("ethanol", "dmso", "pbs", "saline", "water", "vehicle", "medium", "media",
                   "buffer", "cancer", "tumor", "tumour", "carcinoma", "neoplasm", "disease",
                   "control", "untreated", "treated", "normal", "healthy", "mock", "naive",
                   "adjacent", "tissue", "cells", "cell", "line", "primary", "culture",
                   "patient", "donor", "sample",
                   "h1n1", "h3n2", "h5n1", "h7n9", "ad169", "tb40", "tb40e", "wa1", "wuhan")

#' Agenti (ID canonici) nominati in un'etichetta
#'
#' Una sigla che e' l'inizio di un'altra parola della stessa etichetta non e' un
#' secondo agente: "mitoxantrone (MIT)" nomina una molecola sola.
#'
#' @param ontology_env environment dei dizionari
#' @param cache environment opzionale di memoizzazione per token
#' @keywords internal
.rp_agents <- function(x, ontology_env, cache = NULL) {
  tok <- strsplit(.rp_strip_dose_time(gsub("[^A-Za-z0-9 -]", " ", x %||% "")), " +")[[1L]]
  tok <- unique(tok[nchar(gsub("[^a-z0-9]", "", tok)) >= 3L & !(tok %in% .RP_NOT_AGENT)])
  if (length(tok) > 1L) {
    is_prefix <- vapply(tok, function(t) any(tok != t & startsWith(tok, t)), logical(1))
    tok <- tok[!is_prefix]
  }
  if (!length(tok)) return(character(0))
  is_canonical <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  out <- character(0)
  for (t in tok) {
    if (!is.null(cache) && exists(t, envir = cache, inherits = FALSE)) {
      id <- get(t, envir = cache)
    } else {
      id <- ""
      r <- .normalize_compound_to_chebi(t, ontology_env); if (is_canonical(r$id)) id <- r$id
      if (!nzchar(id)) { r <- .normalize_cytokine_to_hgnc(t, ontology_env); if (is_canonical(r$id)) id <- r$id }
      if (!nzchar(id)) { r <- .normalize_pathogen_to_taxid(t, ontology_env); if (is_canonical(r$id)) id <- r$id }
      if (!is.null(cache)) assign(t, id, envir = cache)
    }
    if (nzchar(id)) out <- c(out, id)
  }
  unique(out)
}

#' Il braccio trattato porta almeno due agenti che il controllo non ha
#'
#' Il contrasto non isola l'entita' del gruppo. Non si applica ai gruppi che SONO
#' una combinazione: li' i due agenti sono l'entita' stessa.
#' @keywords internal
.rp_uncaptured_combination <- function(treated_label, control_label, entity, ontology_env,
                                       cache = NULL) {
  if (length(entity) > 0L && !is.na(entity) && startsWith(entity, "COMBO:")) return(FALSE)
  at <- .rp_agents(treated_label, ontology_env, cache)
  ac <- .rp_agents(control_label, ontology_env, cache)
  length(setdiff(at, ac)) >= 2L
}

#' Verdetto di appaiamento per una riga
#'
#' @param treated_label,control_label etichette dei due bracci
#' @param contrast_class classe dominante del contrasto
#' @param entity entita' del gruppo (ID canonico, \code{COMBO:} o \code{STR:})
#' @param extra_stop token che appartengono al nome dell'entita'
#' @param ontology_env environment dei dizionari; se NULL la regola sulla
#'   combinazione non catturata (l'unica che richiede il resolver) non viene
#'   applicata.
#' @param cache environment opzionale di memoizzazione per token
#' @return "" se la riga e' appaiata, altrimenti il nome della regola violata
#' @keywords internal
.rp_row_defect <- function(treated_label, control_label, contrast_class, entity,
                           extra_stop = character(0), ontology_env = NULL, cache = NULL) {
  if (.rp_time_mismatch(treated_label, control_label)) return("tempo_non_appaiato")
  if (.rp_subject_mismatch(treated_label, control_label, contrast_class, extra_stop))
    return("soggetto_diverso")
  if (.rp_genetic_asymmetry(treated_label, control_label, contrast_class, entity))
    return("genetica_asimmetrica")
  if (!is.null(ontology_env) &&
      .rp_uncaptured_combination(treated_label, control_label, entity, ontology_env, cache))
    return("combinazione_non_vista")
  ""
}
