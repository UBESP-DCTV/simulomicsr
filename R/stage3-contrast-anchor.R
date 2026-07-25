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
    for (cand in candidates) {
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
    for (cand in candidates) {
      h <- .hgnc_lookup_symbol(cand, env = ontology_env)
      if (!is.null(h) && !is.null(h$hgnc_int)) {
        return(list(id = paste0("HGNC:", h$hgnc_int), name = h$primary_symbol,
                    source = "HGNC", candidate = cand))
      }
    }
  }
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

#' Normalizza una parte di combinazione
#'
#' La soglia va sui caratteri alfanumerici della PARTE, non su ogni token:
#' \code{M.tb} e' fatto di token da 1 e 2 caratteri e veniva buttato, per cui la
#' co-infezione \code{M.tb + CMV} non era vista come combinazione.
#' @keywords internal
.ca_normalize_part <- function(p) {
  w <- strsplit(gsub("[^a-z0-9 -]", " ", tolower(p)), "[^a-z0-9-]+")[[1L]]
  w <- w[nzchar(w) & !(w %in% .CA_NONENTITY)]
  s <- paste(w, collapse = " ")
  if (nchar(gsub("[^a-z0-9]", "", s)) >= 3L) s else ""
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
  is_agent <- function(p) nzchar(.ca_agent_id(p, ontology_env, cache))
  for (v in treated_values) {
    s <- .ca_strip_units(v)
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
    s <- .ca_strip_units(lab)
    toks <- strsplit(gsub("[^a-z0-9 -]", " ", s), "[^a-z0-9-]+")[[1L]]
    toks <- toks[nzchar(toks) & nchar(gsub("[^a-z0-9]", "", toks)) >= 3L &
                   !(toks %in% .CA_NONENTITY)]
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
