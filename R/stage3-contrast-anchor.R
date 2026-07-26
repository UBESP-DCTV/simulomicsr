# stage3-contrast-anchor.R — anchor derivato dal CONTRASTO (ADR-0025).
#
# L'anchor dello Stadio 3 e' comparison-blind: ancora sulla perturbazione del
# campione TRATTATO, non su cio' che il confronto ISOLA. Sotto lo stesso anchor
# "SARS-CoV-2" convivono cosi' "infezione vs mock", "farmaco vs DMSO in cellule
# infette" (dove SARS e' tenuto costante) e un knock-out genetico: tre contrasti
# diversi in una sola meta-analisi.
#
# Qui si costruisce l'identita' di un CONFRONTO a partire dal DELTA fra i
# factor_levels dei due bracci:
#
#   entita' del delta (canonicalizzata) || verso || tipo di controllo
#
# Le regole del gate (R/stage3-contrast-gate.R) e dell'appaiamento della riga
# (R/stage3-row-pairing.R) vengono RICHIAMATE, non riscritte.

#' Livello dei cluster derivati dal contrasto (non e' un L0..L4)
#'
#' La chiave del contrasto e' gia' l'identita' completa: non esiste una gerarchia
#' di livelli da percorrere. Il valore 5 e' nuovo, non un L4 travestito, e tiene
#' i cluster \code{cgroup} fuori dal ramo mega per costruzione
#' (\code{usable_mega_strict} richiede \code{level in {0,1}}).
#' @keywords internal
.CA_CONTRAST_LEVEL <- 5L

#' Chiavi identitarie: non definiscono un contrasto biologico
#'
#' Donatore, eta', sesso, linea cellulare, tessuto: cambiano fra i due bracci in
#' moltissimi disegni senza che il confronto misuri loro.
#' @keywords internal
.CA_NUISANCE_KEYS <- c(
  "donor", "donor_id", "patient", "subject", "individual", "age", "sex",
  "gender", "ancestry", "ancestry_or_population", "ethnicity", "race", "population",
  "replicate", "batch", "rep", "biological_replicate", "technical_replicate",
  "cell_line", "cell_type", "cell_type_or_line_raw", "cell_context",
  "cell_context.cell_type_or_line_raw", "tissue", "tissue_type", "tissue_segment",
  "tissue_source", "cell_source", "context_kind", "passage", "passage_or_state",
  "cell line", "cell_state", "id", "sample_id", "geo_accession", "name", "title"
)

#' Priorita' della classe dominante del delta
#' @keywords internal
.CA_CLASS_PRIORITY <- c("genetic", "drug", "infection", "disease",
                        "environment", "time", "other")

#' Legge i factor_levels di un braccio in un vettore chiave -> valore
#'
#' Accetta la lista dello Stadio 2 (\code{list(list(key=, value=), ...)}) e la
#' forma stringa \code{"k=v;k=v"} usata dagli script d'audit sui contrasti gia'
#' ricostruiti: la stessa funzione serve il build e la verifica di equivalenza.
#'
#' @param fl lista di \code{{key, value}} oppure character(1) \code{"k=v;k=v"}
#' @return named character vector (valori, nomi = chiavi in minuscolo)
#' @keywords internal
.ca_parse_factor_levels <- function(fl) {
  empty <- stats::setNames(character(0), character(0))
  if (length(fl) == 0L) return(empty)
  if (is.character(fl)) {
    if (is.na(fl[1L]) || !nzchar(fl[1L])) return(empty)
    parts <- strsplit(fl[1L], ";", fixed = TRUE)[[1L]]
    keys <- character(0); vals <- character(0)
    for (p in parts) {
      j <- regexpr("=", p, fixed = TRUE)
      if (j > 0L) {
        keys <- c(keys, substr(p, 1L, j - 1L))
        vals <- c(vals, substr(p, j + 1L, nchar(p)))
      } else {
        keys <- c(keys, p); vals <- c(vals, "")
      }
    }
    return(stats::setNames(vals, tolower(trimws(keys))))
  }
  keys <- vapply(fl, function(z) as.character(z$key   %||% ""), character(1L))
  vals <- vapply(fl, function(z) as.character(z$value %||% ""), character(1L))
  stats::setNames(vals, tolower(trimws(keys)))
}

#' Normalizza un valore per il confronto trattato-vs-controllo
#'
#' Dose, tempo e numeri non fanno parte dell'identita' del contrasto: senza
#' questa normalizzazione "LPS 10 ng/ml" e "LPS 100 ng/ml" sarebbero un delta.
#' @keywords internal
.ca_normalize_value <- function(x) {
  if (length(x) == 0L || is.na(x[1L])) return("")
  s <- tolower(trimws(x[1L]))
  s <- gsub(paste0("\\b\\d+(\\.\\d+)?\\s?(nm|um|µm|mm|mg|ng|ug|µg|%|h|hr|hrs|hpi|dpi|",
                   "day|days|d|week|weeks|min|moi|pfu|ml)\\b"),
            " ", s, perl = TRUE)
  s <- gsub("\\b\\d+(\\.\\d+)?\\b", " ", s)
  s <- gsub("[^a-z ]+", " ", s)
  trimws(gsub("\\s+", " ", s))
}

#' Classe semantica di una chiave dei factor_levels
#'
#' La classe si legge dal NOME della chiave, non dal valore: e' l'unico segnale
#' disponibile in modo uniforme cross-studio.
#' @keywords internal
.ca_classify_key <- function(key) {
  k <- tolower(trimws(key))
  if (k %in% .CA_NUISANCE_KEYS) return("nuisance")
  if (grepl(paste0("genet|genotype|transgene|knock|sirna|shrna|sgrna|crispr|mutat|mutant|",
                   "overexpress|engineer|guide|vector|construct|allele|\\boe\\b|",
                   "perturbation_type|gene"), k)) return("genetic")
  if (grepl(paste0("treat|drug|compound|dose|concentr|perturbation|exposure|agent|stimul|",
                   "ligand|inhibitor|cytokine|small_molecule|molecule|chemical|smallmolecule"),
            k)) return("drug")
  if (grepl("infect|virus|viral|pathogen|bacteri|\\bmoi\\b|inocul|vaccin", k)) return("infection")
  if (grepl(paste0("disease|diagnos|clinical|tumor|tumour|cancer|malign|severity|grade|",
                   "patholog|condition|response|remission|\\bstage\\b|status|phenotype|subtype"),
            k)) return("disease")
  if (grepl(paste0("diet|hypox|oxygen|normox|glucose|fasting|temperature|irradiat|radiat|",
                   "starv|nutrient|media|medium|serum"), k)) return("environment")
  if (grepl("time|timepoint|time_point|duration|hour|\\bday\\b|week|developmental|differentiat",
            k)) return("time")
  "other"
}

#' Delta fra i due bracci: che cosa cambia, di che classe, con quali valori
#'
#' @param treated_fl,control_fl factor_levels dei due bracci (lista o stringa)
#' @return list con \code{keys}, \code{classes}, \code{treated_values},
#'   \code{control_values}, \code{dominant_class} (\code{NA} se il delta e' vuoto
#'   o solo identitario) e \code{classes_signature}
#' @keywords internal
.ca_delta <- function(treated_fl, control_fl) {
  tv_all <- .ca_parse_factor_levels(treated_fl)
  cv_all <- .ca_parse_factor_levels(control_fl)
  keys <- union(names(tv_all), names(cv_all))
  k_out <- character(0); cls_out <- character(0)
  tval  <- character(0); cval    <- character(0)
  for (k in keys) {
    a <- if (k %in% names(tv_all)) tv_all[[k]] else ""
    b <- if (k %in% names(cv_all)) cv_all[[k]] else ""
    if (identical(.ca_normalize_value(a), .ca_normalize_value(b))) next
    cls <- .ca_classify_key(k)
    if (identical(cls, "nuisance")) next
    k_out <- c(k_out, k); cls_out <- c(cls_out, cls)
    tval  <- c(tval, a);  cval    <- c(cval, b)
  }
  dominant <- if (length(cls_out) == 0L) NA_character_
              else .CA_CLASS_PRIORITY[.CA_CLASS_PRIORITY %in% cls_out][1L]
  list(
    keys              = k_out,
    classes           = cls_out,
    treated_values    = tval,
    control_values    = cval,
    dominant_class    = dominant,
    classes_signature = paste(sort(unique(cls_out)), collapse = "+")
  )
}

# ------------------------------------------------ entita' del delta -----------
# Passare al resolver il treated_label INTERO produce entita' spurie ("CD8 T
# cells ..." -> CD8A) e le unita' di misura collidono coi sinonimi ("ug/ml" ->
# "ML" -> Thrombopoietin). Si risolve SOLO cio' che cambia fra i due bracci,
# ripulito da dosi e unita', e il label intero e' ammesso solo dove il nome sta
# spesso soltanto li' (infezione, malattia, genetica).

#' Unita' di misura: mai un'entita'
#' @keywords internal
.CA_UNITS <- c(
  "ml", "ul", "dl", "l", "ug", "mg", "ng", "pg", "kg", "g", "nm", "um", "mm",
  "pm", "cm", "mol", "mmol", "umol", "nmol", "moi", "pfu", "ffu", "tcid", "iu",
  "hr", "hrs", "min", "sec", "h", "d", "day", "days", "week", "weeks", "wk",
  "month", "months", "hour", "hours", "hpi", "dpi", "rpm", "per", "dose",
  "doses", "conc", "final", "approx", "total", "fold", "percent"
)

#' Parole che non sono mai un'entita'
#' @keywords internal
.CA_NONENTITY <- c(
  "none", "control", "controls", "vehicle", "untreated", "treated", "treatment",
  "treatments", "mock", "naive", "baseline", "normal", "healthy", "wildtype",
  "wild", "type", "sample", "samples", "patient", "patients", "case", "cases",
  "donor", "donors", "group", "groups", "condition", "conditions", "cells",
  "cell", "tissue", "line", "lines", "culture", "cultured", "medium", "media",
  "experiment", "replicate", "replicates", "therapy", "therapies", "after",
  "before", "post", "pre", "with", "without", "from", "the", "and", "for",
  "anti", "plus", "versus", "status", "state", "level", "levels", "number",
  "stage", "grade", "score", "high", "low", "early", "late", "acute", "chronic",
  "unknown", "other", "test", "exposure", "exposed", "stimulated", "infected",
  "biopsy", "blood", "serum", "plasma", "primary", "secondary", "human",
  "male", "female"
)

#' Toglie dosi, unita' e tempi senza spezzare i nomi con suffisso numerico
#'
#' I numeri isolati si tolgono SOLO fra spazi: \code{\\b\\d+\\b} distruggeva
#' \code{sars-cov-2} -> \code{sars-cov} (che e' il SARS del 2003, un'altra
#' specie) e ogni nome con suffisso numerico (IL-6, MCF-7).
#' @keywords internal
.ca_strip_units <- function(x) {
  if (length(x) == 0L || all(is.na(x))) return("")
  s <- tolower(trimws(paste(stats::na.omit(x), collapse = " ")))
  s <- gsub(paste0("\\b\\d+([.,]\\d+)?\\s*(ug|mg|ng|pg|kg|g|ul|ml|dl|l|nm|um|mm|pm|mol|",
                   "mmol|umol|nmol|iu|moi|pfu|ffu|%)\\s*(/\\s*(ml|l|kg|g|ul))?\\b"),
            " ", s, perl = TRUE)
  s <- gsub(paste0("\\b\\d+([.,]\\d+)?\\s*(h|hr|hrs|hour|hours|d|day|days|week|weeks|wk|",
                   "min|sec|hpi|dpi)\\b"),
            " ", s, perl = TRUE)
  s <- gsub("\\b(ug|mg|ng|pg|kg|ul|ml|dl|nm|um|mm|iu|moi|pfu|ffu)\\s*/\\s*(ml|l|kg|g|ul|min)\\b",
            " ", s, perl = TRUE)
  s <- gsub("[/\\\\]", " ", s)
  s <- gsub("(^|\\s)\\d+([.,]\\d+)?(?=\\s|$)", " ", s, perl = TRUE)
  trimws(gsub("\\s+", " ", s))
}

#' Un token che e' un'unita' di misura, una parola funzionale o troppo corto
#' @keywords internal
.ca_is_unit_or_nonentity <- function(tok) {
  t <- gsub("[^a-z0-9+-]", "", tolower(trimws(tok)))
  if (!nzchar(t)) return(TRUE)
  if (t %in% .CA_UNITS || t %in% .CA_NONENTITY) return(TRUE)
  if (!grepl("[a-z]", t)) return(TRUE)
  nchar(t) < 3L
}

#' Sanitizza una frase tenendo interi i nomi veri
#'
#' Si tolgono SOLO i token-unita': tagliare anche i token corti spezzerebbe i
#' nomi veri (\code{SARS CoV 2} -> \code{sars cov}, \code{IL 6} -> \code{il}).
#' Il filtro a >=3 caratteri vale per i candidati-token isolati, non per la frase.
#' @keywords internal
.ca_sanitize_phrase <- function(x) {
  s <- .ca_strip_units(x)
  w <- strsplit(s, "[^a-z0-9+-]+")[[1L]]
  w <- w[nzchar(w) & !(w %in% .CA_UNITS)]
  trimws(paste(w, collapse = " "))
}

#' Traduce le lettere greche in lettere latine
#'
#' \code{TGF-\u03b21} dice l'isoforma: il resolver la mancava solo perche' il
#' nome nei dizionari e' scritto \code{TGF-beta1}. Regola generale, non una
#' lista di casi. Si prova DOPO la forma originale, per non cambiare le
#' risoluzioni che gia' funzionano (\code{TNF\u03b1} risolve a HGNC via il ramo
#' citochine; tradotta per prima finirebbe su un alias ChEMBL).
#' @keywords internal
.ca_latinize_greek <- function(x) {
  s <- tolower(x)
  greche <- c("\u03b1" = "alpha", "\u03b2" = "beta", "\u03b3" = "gamma",
              "\u03b4" = "delta", "\u03ba" = "kappa", "\u03bb" = "lambda",
              "\u03c3" = "sigma", "\u03c9" = "omega")
  for (g in names(greche)) s <- gsub(g, greche[[g]], s, fixed = TRUE)
  s
}

#' Guardia sulle sigle: un candidato corto vale solo se coincide col nome risolto
#'
#' Le tabelle di sinonimi contengono sigle di 2-3 lettere che collidono col gergo
#' di laboratorio: \code{ML} (unita' di volume) e' sinonimo ImmPort di
#' Thrombopoietin, \code{HGI} risolve a IL6. Senza questa guardia il resolver
#' battezza le unita' di misura.
#' @keywords internal
.ca_acronym_ok <- function(candidate, name) {
  alnum <- function(z) gsub("[^a-z0-9]", "", tolower(z %||% ""))
  a <- alnum(candidate)
  if (nchar(a) > 4L) return(TRUE)
  nm <- name %||% NA_character_
  !is.na(nm) && nzchar(nm) && identical(a, alnum(nm))
}

#' Candidati da passare al resolver, dal piu' specifico al piu' generico
#'
#' @param values valori TRATTATI delle chiavi che cambiano (la classe dominante)
#' @param treated_label etichetta leggibile del braccio trattato
#' @param contrast_class classe dominante del delta
#' @keywords internal
.ca_candidates <- function(values, treated_label = NA_character_,
                           contrast_class = NA_character_) {
  out <- character(0)
  for (v in values) {
    if (is.na(v) || !nzchar(trimws(v))) next
    s <- .ca_sanitize_phrase(v)
    if (nzchar(s) && !.ca_is_unit_or_nonentity(s)) out <- c(out, s)
    for (p in strsplit(s, "[,;+&]| and | plus | with ")[[1L]]) {
      p <- trimws(p)
      if (nzchar(p) && !.ca_is_unit_or_nonentity(p)) out <- c(out, p)
    }
    for (tk in strsplit(s, "[^a-z0-9-]+")[[1L]]) {
      if (!.ca_is_unit_or_nonentity(tk)) out <- c(out, tk)
    }
  }
  # Il label intero e' ammesso solo dove il nome sta spesso soltanto li'. Per la
  # classe drug e' la fonte documentata di entita' spurie.
  if (!is.na(contrast_class) && contrast_class %in% c("infection", "disease", "genetic") &&
      !is.na(treated_label)) {
    s <- .ca_sanitize_phrase(treated_label)
    if (nzchar(s) && !.ca_is_unit_or_nonentity(s)) out <- c(out, s)
  }
  unique(out[nzchar(out)])
}

#' Sigle accertate LEGGENDO le etichette degli studi che le usano
#'
#' Non e' inferenza e non e' una lista di comodo: ogni voce e' stata verificata
#' guardando tutte le etichette del gruppo che la contiene (censimento
#' 2026-07-27). Si applica SOLO quando i resolver hanno gia' fallito.
#'
#' \itemize{
#'   \item \code{enza}: etichette \code{LNCaP_ENZA}, \code{VCaP_ENZA},
#'     \code{LAPC4_ENZA}, \code{R1AD1_ENZA} — le stesse linee prostatiche del
#'     gruppo enzalutamide. 4 studi, nessuna ambiguita' nel contesto.
#'   \item \code{5-aza-cdr}: sei studi, tutti con la sigla standard della
#'     5-aza-2'-deossicitidina (decitabina).
#'   \item \code{zikv}: sigla universale del virus Zika; il resolver la rifiuta
#'     solo perche' la guardia sulle sigle vuole >4 caratteri.
#' }
#'
#' NON contiene \code{TGFb}: le etichette non dicono MAI l'isoforma
#' (\code{TGFb-treated SAEC}, \code{TGFB 48hrs}, \code{Vehicle A + TGFb}), e
#' mapparla a TGFB1 sarebbe asserire un'identita' per inferenza — l'errore
#' d'origine di questo progetto. Resta separata e il limite si dichiara.
#' @keywords internal
.CA_VERIFIED_ALIASES <- c(
  "enza"           = "CHEBI:68534",     # enzalutamide
  "5-aza-cdr"      = "CHEBI:50131",     # 5-aza-2'-deossicitidina (decitabina)
  "5 aza cdr"      = "CHEBI:50131",
  "aza-cdr"        = "CHEBI:50131",
  "zikv"           = "NCBITaxon:64320"  # Zika virus
)

#' Cerca una sigla accertata fra i candidati
#' @keywords internal
.ca_verified_alias <- function(candidates) {
  for (cand in candidates) {
    k <- tolower(trimws(cand))
    if (k %in% names(.CA_VERIFIED_ALIASES)) {
      return(list(id = unname(.CA_VERIFIED_ALIASES[[k]]), name = k,
                  source = "ALIAS_ACCERTATO", candidate = cand))
    }
  }
  NULL
}

#' Risolve l'entita' del delta con i resolver della classe dominante
#'
#' \code{raw_values} = valori grezzi (servono a ChEBI: gli alias hanno
#' punteggiatura, \code{poly(I:C)} non e' \code{poly i c}); \code{candidates} =
#' sanitizzati (per i rami con sinonimi rumorosi).
#'
#' @return list con \code{id} (\code{NA} se non risolve), \code{name},
#'   \code{source}, \code{candidate} (il candidato che ha prodotto il match)
#' @keywords internal
.ca_resolve_entity <- function(contrast_class, raw_values, candidates, ontology_env) {
  none <- list(id = NA_character_, name = NA_character_,
               source = "UNRESOLVED", candidate = NA_character_)
  if (length(contrast_class) == 0L || is.na(contrast_class)) return(none)
  is_canon <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  hit <- function(r, cand) list(id = r$id, name = r$name,
                                source = r$source %||% "RESOLVER", candidate = cand)
  raw <- trimws(tolower(as.character(raw_values)))
  raw <- raw[!is.na(raw) & nzchar(raw)]
  both <- unique(c(raw, candidates))

  if (identical(contrast_class, "drug")) {
    for (cand in both) {
      r <- .normalize_compound_to_chebi(cand, ontology_env)
      if (is_canon(r$id)) return(hit(r, cand))
    }
    # La forma con le lettere greche tradotte si prova DOPO l'originale. La
    # traduzione va fatta sui valori GREZZI: la sanitizzazione toglie la lettera
    # greca e lascia "tgf- 1", su cui tradurre non serve piu' a niente.
    for (cand in unique(c(candidates, .ca_candidates(.ca_latinize_greek(raw_values))))) {
      r <- .normalize_cytokine_to_hgnc(cand, ontology_env)
      if (is_canon(r$id) && .ca_acronym_ok(cand, r$name)) return(hit(r, cand))
    }
    # La classe viene dal NOME della chiave ("treatment" -> drug): se il valore
    # e' un patogeno ("SARS-CoV-2 Omicron") il ramo drug non lo vedrebbe.
    for (cand in both) {
      r <- .normalize_pathogen_to_taxid(cand, ontology_env)
      if (is_canon(r$id) && .ca_acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (identical(contrast_class, "infection")) {
    for (cand in both) {
      r <- .normalize_pathogen_to_taxid(cand, ontology_env)
      if (is_canon(r$id) && .ca_acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (identical(contrast_class, "disease")) {
    for (cand in both) {
      r <- .normalize_disease_to_mesh(cand, ontology_env)
      if (is_canon(r$id) && .ca_acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (identical(contrast_class, "genetic")) {
    for (cand in unique(c(candidates, .ca_candidates(.ca_latinize_greek(raw_values))))) {
      h <- .hgnc_lookup_symbol(cand, env = ontology_env)
      if (!is.null(h) && !is.null(h$hgnc_int)) {
        return(list(id = paste0("HGNC:", h$hgnc_int), name = h$primary_symbol,
                    source = "HGNC", candidate = cand))
      }
    }
  }
  # Ultimo passo: le sigle accertate leggendo le etichette. Solo dopo che i
  # resolver hanno fallito, mai al loro posto.
  hit <- .ca_verified_alias(unique(c(raw, candidates)))
  if (!is.null(hit)) return(hit)
  none
}

# ------------------------------------------------------------ combinazioni ----
# Decisione utente 2026-07-24: una combinazione e' un'entita' a se' (COMBO:a+b),
# non si spezza ne' si scarta. Gli agenti presenti su ENTRAMBI i bracci sono
# tenuti costanti e non fanno parte del delta: "SARS-CoV-2 + Ruxolitinib vs
# SARS-CoV-2" resta un contrasto su ruxolitinib.

#' ID canonico dell'agente contenuto in una parte, se esiste
#'
#' Un agente e' "vero" solo se risolve a un ID canonico: non basta essere
#' informativo (\code{MOI}, \code{Contact}, \code{053} sono informativi e non
#' sono agenti).
#' @param cache environment opzionale di memoizzazione
#' @keywords internal
.ca_agent_id <- function(part, ontology_env, cache = NULL) {
  p <- trimws(part)
  if (!nzchar(p)) return("")
  if (!is.null(cache) && exists(p, envir = cache, inherits = FALSE)) {
    return(get(p, envir = cache))
  }
  ok <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  res <- ""
  for (cand in unique(c(p, strsplit(p, " ")[[1L]]))) {
    if (nchar(cand) < 3L) next
    r <- .normalize_compound_to_chebi(cand, ontology_env)
    if (ok(r$id)) { res <- r$id; break }
    r <- .normalize_cytokine_to_hgnc(cand, ontology_env)
    if (ok(r$id) && nchar(cand) > 4L) { res <- r$id; break }
    r <- .normalize_pathogen_to_taxid(cand, ontology_env)
    if (ok(r$id) && nchar(cand) > 4L) { res <- r$id; break }
    h <- .hgnc_lookup_symbol(sub("^(sh|si|sg)", "", cand), env = ontology_env)
    if (!is.null(h) && !is.null(h$hgnc_int) && nchar(cand) > 3L) {
      res <- paste0("HGNC:", h$hgnc_int); break
    }
  }
  if (!is.null(cache)) assign(p, res, envir = cache)
  res
}

#' Toglie dosi e tempi PRESERVANDO i separatori
#'
#' Serve al rilevatore di combinazioni, che deve ancora vedere \code{/} e
#' \code{_}. \code{.ca_strip_units()} invece trasforma \code{/} in spazio (li'
#' e' voluto: \code{ug/ml} e' rumore), e usarla qui faceva sparire il separatore
#' prima dello split: \code{Bleomycin/Alpha-Lipoic Acid} diventava la sola
#' bleomicina (regressione misurata dall'equivalenza 2026-07-27).
#' @keywords internal
.ca_drop_doses <- function(x) {
  if (length(x) == 0L || all(is.na(x))) return("")
  s <- tolower(paste(stats::na.omit(x), collapse = " "))
  s <- gsub(paste0("\\b\\d+([.,]\\d+)?\\s*(ug|mg|ng|pg|kg|g|ul|ml|dl|l|nm|um|mm|pm|iu|moi|",
                   "pfu|ffu|%)\\s*(/\\s*(ml|l|kg|g|ul))?"),
            " ", s, perl = TRUE)
  s <- gsub("\\b\\d+([.,]\\d+)?\\s*(h|hr|hrs|hour|hours|d|day|days|week|weeks|min|hpi|dpi)\\b",
            " ", s, perl = TRUE)
  s <- gsub("\\b(ug|mg|ng|kg|ul|ml|nm|um|iu|moi|pfu)\\s*/\\s*(ml|l|kg|g|ul|min)\\b",
            " ", s, perl = TRUE)
  trimws(gsub("\\s+", " ", s))
}

#' Normalizza una parte di combinazione
#'
#' La soglia va sui caratteri alfanumerici della PARTE, non su ogni token:
#' \code{M.tb} e' fatto di token da 1 e 2 caratteri e veniva buttato, per cui la
#' co-infezione \code{M.tb + CMV} non era vista come combinazione.
#' @keywords internal
.ca_normalize_part <- function(p) {
  # Il vocabolario e' quello del GATE (.CG_GENERIC + .CG_CONNECTORS): l'entita'
  # e' la chiave del cluster, e "COMBO:taz sirna+yap" e "COMBO:taz+yap" sono due
  # gruppi diversi. Con un vocabolario diverso 102 membri finivano in una chiave
  # leggermente diversa dal gate misurato (2026-07-27).
  w <- strsplit(gsub("[^a-z0-9 -]", " ", tolower(p)), "[^a-z0-9-]+")[[1L]]
  w <- w[nzchar(w) & !(w %in% .CG_GENERIC) & !(w %in% .CG_CONNECTORS)]
  s <- paste(w, collapse = " ")
  if (nchar(gsub("[^a-z0-9]", "", s)) >= 3L) s else ""
}

#' La parte risolve a un agente? (senza la guardia sulle sigle)
#'
#' Qui la parte viene da un separatore ESPLICITO (\code{A + B}): e' l'autore
#' dell'etichetta a dire che sono due agenti, quindi la guardia sui candidati
#' corti — giusta quando i token si pescano da un'etichetta libera — qui butta
#' via i nomi veri. Senza questa distinzione sparivano la co-infezione
#' \code{M.tb + CMV} e la combinazione \code{IL2 + IL23} (misurato 2026-07-27).
#' @keywords internal
.ca_resolves_to_agent <- function(part, ontology_env) {
  p <- trimws(part)
  if (!nzchar(p) || nchar(p) < 3L) return(FALSE)
  ok <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  ok(.normalize_compound_to_chebi(p, ontology_env)$id) ||
    ok(.normalize_cytokine_to_hgnc(p, ontology_env)$id) ||
    ok(.normalize_pathogen_to_taxid(p, ontology_env)$id) ||
    !is.null(.hgnc_lookup_symbol(sub("^(sh|si|sg)", "", p), env = ontology_env))
}

#' Combinazione dentro il valore di UNA chiave
#'
#' \code{+}, \code{and}, \code{plus} bastano da soli; \code{/} e \code{_} solo se
#' >=2 parti sono agenti veri (cosi' \code{Bleomycin/Alpha-Lipoic Acid} e
#' \code{Vemurafenib_Acalabrutinib} passano, \code{SARS-CoV-2_MOI_1} e
#' \code{Contact_Pulmonary} no).
#' @keywords internal
.ca_combo_parts <- function(treated_values, ontology_env, cache = NULL) {
  best <- character(0)
  is_agent <- function(p) .ca_resolves_to_agent(p, ontology_env)
  for (v in treated_values) {
    s <- .ca_drop_doses(v)
    if (!nzchar(s)) next
    strong <- trimws(strsplit(s, "\\s*[+&]\\s*|\\s+and\\s+|\\s+plus\\s+", perl = TRUE)[[1L]])
    ps <- unique(vapply(strong, .ca_normalize_part, character(1L)))
    ps <- ps[nzchar(ps)]
    if (length(ps) >= 2L && sum(vapply(ps, is_agent, logical(1L))) >= 1L) {
      if (length(ps) > length(best)) best <- ps
      next
    }
    weak <- trimws(strsplit(s, "\\s*[/_]\\s*", perl = TRUE)[[1L]])
    pw <- unique(vapply(weak, .ca_normalize_part, character(1L)))
    pw <- pw[nzchar(pw)]
    if (length(pw) >= 2L && sum(vapply(pw, is_agent, logical(1L))) >= 2L) {
      if (length(pw) > length(best)) best <- pw
    }
  }
  best
}

#' Agenti nominati nel braccio trattato e assenti dal controllo
#'
#' Molte combinazioni stanno nel label e NON nel delta (misurato: "Estradiol and
#' Fulvestrant", "Bleomycin/Alpha-Lipoic Acid", "Palbociclib and Indisulam").
#' Non serve un separatore: "M1 macrophage GMCSF INFG activated" e' una
#' combinazione anche senza "+".
#' @keywords internal
.ca_combo_from_labels <- function(treated_label, control_label, ontology_env, cache = NULL) {
  agents_of <- function(lab) {
    s <- .ca_drop_doses(lab)
    toks <- strsplit(gsub("[^a-z0-9 -]", " ", s), "[^a-z0-9-]+")[[1L]]
    # Vocabolario del GATE: senza, "cancer" conta come agente e nasce la
    # combinazione inventata "COMBO:cancer+siINO80" (19 membri, misurato).
    toks <- toks[nzchar(toks) & nchar(gsub("[^a-z0-9]", "", toks)) >= 3L &
                   !(toks %in% .CG_GENERIC) & !(toks %in% .CG_CONNECTORS)]
    ids <- character(0); nms <- character(0)
    for (tk in unique(toks)) {
      a <- .ca_agent_id(tk, ontology_env, cache)
      if (nzchar(a)) { ids <- c(ids, a); nms <- c(nms, tk) }
    }
    stats::setNames(ids, nms)
  }
  at <- agents_of(treated_label); ac <- agents_of(control_label)
  keep <- at[!(at %in% ac)]
  if (length(unique(keep)) >= 2L) unique(names(keep)) else character(0)
}

# --------------------------------------------------- verdetto per-membro ------

#' ID ontologici che non identificano una perturbazione
#'
#' Classi-ombrello (Neoplasms, "organic cation", "steroid"), veicoli (etanolo,
#' DMSO) e un TNF di specie sbagliata: sono ID validi che non sono entita' del
#' contrasto.
#' @keywords internal
.CA_BLACKLIST_ID <- c(
  "MeSH:D009369", "MeSH:D009361", "MeSH:D002277", "MeSH:D004194", "MeSH:D007239",
  "MeSH:D007249", "MeSH:D009371", "CHEBI:17499", "CHEBI:24431", "CHEBI:23367",
  "CHEBI:33232", "CHEBI:50906", "CHEBI:50845", "CHEBI:28262", "CHEBI:25367",
  "CHEBI:35341", "CHEBI:33699", "CHEBI:84123", "CHEBI:16236", "CHEBI:197439"
)

#' Ripulisce il valore del delta per il ripiego STR:
#' @keywords internal
.ca_clean_token <- function(x) {
  s <- tolower(trimws(paste(stats::na.omit(x), collapse = " ")))
  s <- gsub("[_|]+", " ", s)
  # Le CIFRE restano: senza, "RBM4 knockdown" diventa "rbm knockdown" e
  # "p16INK4A" diventa "p ink a" — RBM4 e RBM3 sarebbero la stessa entita'.
  s <- gsub("[^a-z0-9 ]+", " ", s)
  s <- gsub(paste0("\\b(patient|patients|case|cases|control|controls|healthy|donor|donors|",
                   "sample|samples|primary|culture|cell|cells|from|the|and|of|with|vs|total|",
                   "rna|tissue|line|human|treated|treatment|stimulated|infected|exposed|day|",
                   "days|hour|hours|hr|hrs)\\b"), " ", s)
  trimws(gsub("\\s+", " ", s))
}

#' Token che appartengono al nome dell'entita' (non sono identificatori di linea)
#' @keywords internal
.ca_entity_tokens <- function(...) {
  s <- tolower(paste(stats::na.omit(c(...)), collapse = " "))
  t <- strsplit(gsub("[^a-z0-9 -]+", " ", s), " +")[[1L]]
  unique(t[nzchar(t)])
}

#' Verdetto di contrasto per un singolo membro (un confronto trattato-vs-controllo)
#'
#' Applica, NELL'ORDINE misurato dal gate v11
#' (\code{analysis/audit/2026-07-24-anchor-coherence-sim/109-fase1-v11-gate.R}),
#' le regole del gate (\code{.cg_*}) e dell'appaiamento della riga
#' (\code{.rp_row_defect}), e restituisce l'identita' del contrasto oppure la
#' ragione dello scarto. L'ordine non e' arbitrario: cambiarlo cambia le ragioni
#' di scarto e quindi i conteggi, anche a parita' di esito.
#'
#' @param treated_label,control_label etichette leggibili dei due bracci
#' @param treated_fl,control_fl factor_levels dei due bracci (lista o stringa)
#' @param anchor_name,anchor_id nome canonico e ID gia' risolti nell'anchor del
#'   campione trattato di QUESTO record (ramo on-contrast). \code{NA} = ramo
#'   disattivato. Nel build il nome del CLUSTER non esiste ancora: l'analogo
#'   disponibile e' l'anchor del record (decisione utente 2026-07-27).
#' @param ontology_env environment dei dizionari
#' @param caches list opzionale di environment di memoizzazione
#'   (\code{agent}, \code{token})
#' @return list con \code{entity}, \code{direction}, \code{control_key},
#'   \code{contrast_class}, \code{entity_source}, \code{drop_reason}.
#'   \code{drop_reason == ""} = membro tenuto.
#' @keywords internal
.ca_member_contrast <- function(treated_label, control_label, treated_fl, control_fl,
                                anchor_name = NA_character_, anchor_id = NA_character_,
                                ontology_env = NULL, caches = NULL) {
  if (is.null(ontology_env)) ontology_env <- .load_ontology_dicts()
  out <- function(reason, entity = NA_character_, direction = NA_character_,
                  control_key = NA_character_, cls = NA_character_, src = NA_character_) {
    list(entity = entity, direction = direction, control_key = control_key,
         contrast_class = cls, entity_source = src, drop_reason = reason)
  }
  agent_cache <- caches$agent
  row_cache   <- caches$token

  d <- .ca_delta(treated_fl, control_fl)
  if (is.na(d$dominant_class)) return(out("no_delta"))
  # Un delta di solo TEMPO non e' un contrasto: e' una dimensione identitaria
  # (ADR-0025 §4, decisione utente 2026-07-24). Il gate misurato lo escludeva;
  # senza questo filtro nasceva il gruppo "fetale vs adulto" su tre tessuti.
  if (identical(d$dominant_class, "time")) return(out("classe_non_contrastiva"))
  cls  <- d$dominant_class
  tval <- d$treated_values
  cval <- d$control_values

  # Regole che scartano il MEMBRO, nell'ordine del gate misurato.
  if (.cg_broken_contrast(treated_label, control_label, treated_fl, control_fl))
    return(out("contrasto_rotto"))
  if (.cg_is_noncontrol(control_label))
    return(out("controllo_non_valido"))
  if (.cg_resistance_mismatch(treated_label, control_label))
    return(out("resistenza_asimmetrica"))
  if (.cg_is_multiclass(d$classes_signature))
    return(out("delta_multiclasse"))
  if (identical(tolower(trimws(treated_label)), tolower(trimws(control_label))))
    return(out("label_degenere"))
  if (.cg_is_control_like_treated(paste(tval, collapse = " ")))
    return(out("trattato_e_un_controllo"))

  direction <- .cg_direction(tval)
  if (identical(direction, "ambiguo")) return(out("verso_ambiguo"))

  # Entita' del delta: si risolve dai valori della CLASSE DOMINANTE, non da
  # tutti. Con tutti, in "APC/TP53 mutant, STAR positive" il gene risolto
  # diventava STAR (primo valore, classe other) invece di APC.
  # NB: verso, combinazioni e ripiego STR: usano invece TUTTI i valori, come il
  # gate misurato.
  tval_cls <- d$treated_values[d$classes == cls]
  if (!length(tval_cls)) tval_cls <- tval
  res <- .ca_resolve_entity(cls, tval_cls,
                            .ca_candidates(tval_cls, treated_label, cls), ontology_env)

  # Tipo di controllo composito: lato-controllo del delta + materiale + baseline
  # propria + contesto d'infezione. L'asse clinico/sperimentale vale per OGNI
  # contrasto su un patogeno, non solo quando la chiave si chiama "infection"
  # (misurato: HIV arriva spesso come cls=drug).
  cvv <- cval[nzchar(trimws(cval))]
  if (!length(cvv)) cvv <- "untreated"
  ct_base <- paste(sort(unique(vapply(cvv, .normalize_control_type, character(1L)))),
                   collapse = "+")
  material <- if (identical(.cg_material_arm(treated_label, treated_fl), "liquid")) "_liquid" else ""
  is_pathogen <- identical(cls, "infection") ||
    (!is.na(res$id) && startsWith(res$id, "NCBITaxon:"))
  control_key <- paste0(ct_base, material, .cg_baseline_kind(control_label),
                        .cg_infection_context(if (is_pathogen) "infection" else cls,
                                              control_label, treated_label))

  # Combinazione: entita' a se'.
  combo <- .ca_combo_parts(tval, ontology_env, agent_cache)
  if (length(combo) < 2L) {
    combo <- .ca_combo_from_labels(treated_label, control_label, ontology_env, agent_cache)
  }
  if (cls %in% c("drug", "infection") && length(combo) >= 2L) {
    entity <- paste0("COMBO:", paste(sort(combo), collapse = "+"))
    defect <- .rp_row_defect(treated_label, control_label, cls, entity,
                             .ca_entity_tokens(anchor_name, res$name, combo),
                             ontology_env, row_cache)
    if (nzchar(defect)) return(out(paste0("riga_", defect)))
    return(out("", entity, direction, control_key, cls, "COMBO"))
  }

  # Entita': on-contrast (nome gia' risolto nell'anchor di questo record) ->
  # delta risolto -> ripiego STR:.
  entity <- NA_character_; src <- NA_character_
  if (!is.na(anchor_name) && nzchar(anchor_name) && !is.na(anchor_id) &&
      .cg_matches_all_words(.cg_distinctive_tokens(anchor_name), paste(tval, collapse = " "))) {
    entity <- anchor_id; src <- "anchor"
  } else if (!is.na(res$id) && !startsWith(res$id, "STR:")) {
    entity <- res$id; src <- "onto"
  } else {
    tk <- .ca_clean_token(tval)
    if (nzchar(tk)) { entity <- paste0("STR:", gsub(" ", "_", tk)); src <- "STR" }
  }
  if (is.na(entity)) return(out("no_entity"))

  # Si tolgono ENTRAMBI i prefissi: per un'entita' presa dall'anchor la sonda
  # cercherebbe "name training" invece di "training" e non troverebbe nulla.
  raw <- sub("^(NAME|STR):", "", entity)
  if (startsWith(entity, "STR:") && .cg_is_generic_token(gsub("_", " ", raw)))
    return(out("str_generico"))
  # Ombrella sull'entita' stessa quando non e' un ID ontologico: "lesional",
  # "syndrome", "vector" non sono entita' (il gate lo faceva sul ramo NAME:).
  if ((startsWith(entity, "STR:") || startsWith(entity, "NAME:")) &&
      .cg_is_umbrella_name(tolower(raw))) return(out("nome_ombrello"))
  if (entity %in% .CA_BLACKLIST_ID) return(out("id_blacklist"))
  if (.cg_is_inducer(gsub("_", " ", raw))) return(out("induttore"))
  # Il NOME RISOLTO si giudica per APPARTENENZA al vocabolario, non con
  # l'euristica sui token: quella scarta ogni sigla sotto i 4 caratteri, cioe'
  # entita' vere come TNF, IL6, RSV, CMV, HBV (565 membri persi, misurato
  # dall'equivalenza 2026-07-27). Un ID risolto e' gia' una garanzia di identita';
  # qui si tolgono solo i nomi che sono parole generiche o anatomia.
  rn <- tolower(res$name %||% "")
  if (nzchar(rn) && !grepl(" ", rn) &&
      (rn %in% .CG_GENERIC || rn %in% .CG_ANATOMY))
    return(out("nome_generico"))
  if (nzchar(rn) && .cg_is_umbrella_name(rn)) return(out("nome_ombrello"))

  # L'entita' e' TENUTA COSTANTE fra i due bracci: quel membro non la misura
  # ("Current PTSD, perturbazione" vs "Current PTSD, nessuna perturbazione" non
  # e' il contrasto "PTSD vs sano").
  probe <- if (!is.na(res$candidate) && nzchar(res$candidate)) res$candidate else gsub("_", " ", raw)
  probe <- trimws(gsub("[^a-z0-9 ]+", " ", tolower(probe)))
  if (nzchar(probe) && nchar(gsub("[^a-z0-9]", "", probe)) >= 3L) {
    cl_norm <- gsub("[^a-z0-9]+", " ", tolower(control_label))
    if (grepl(paste0("(^| )", probe, "( |$)"), cl_norm)) return(out("entita_costante"))
  }

  # La riga deve essere anche APPAIATA: il gruppo dice CHE COSA si misura, la
  # riga COME e' stato confrontato.
  defect <- .rp_row_defect(treated_label, control_label, cls, entity,
                           .ca_entity_tokens(anchor_name, res$name, raw),
                           ontology_env, row_cache)
  if (nzchar(defect)) return(out(paste0("riga_", defect)))

  out("", entity, direction, control_key, cls, src)
}
