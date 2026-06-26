# Recupero deterministico di identita' (malattia/composto/gene) dai metadati GEO
# grezzi + correzione tipi palesemente sbagliati (K2). Spec:
# docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md

# Fallback %||% se non disponibile da rlang
if (!exists("%||%")) {
  `%||%` <- function(a, b) {
    if (is.null(a) || length(a) == 0L) b else a
  }
}

.DISEASE_KEYS <- "^(disease|disease state|diagnosis|condition|histology|tumor type|cancer type|subtype|group|patient group)$"
.CONTROL_VALS <- "healthy|normal|control|non-?malignant|baseline|unaffected|^na$|^none$"
.AGENT_KEYS    <- "^(treatment|agent|compound|drug|chemical|stimulus|stimulation|ligand|exposure|reagent)$"
.AGENT_CONTROL <- paste0(.CONTROL_VALS, "|vehicle|dmso|\\bpbs\\b|untreated|mock|scramble|vector|water")

#' Parsa "key: value, key: value" in vettore nominato (chiavi/valori lowercased)
#' @keywords internal
.parse_characteristics_kv <- function(text) {
  if (length(text) != 1L || is.na(text) || !nzchar(text)) return(character(0))
  pairs <- strsplit(text, ",", fixed = TRUE)[[1L]]
  out <- character(0)
  for (p in pairs) {
    kv <- strsplit(p, ":", fixed = TRUE)[[1L]]
    if (length(kv) >= 2L) {
      k <- tolower(trimws(kv[1L]))
      v <- tolower(trimws(paste(kv[-1L], collapse = ":")))
      if (nzchar(k) && nzchar(v)) out[[k]] <- v
    }
  }
  out
}

#' Estrae il termine-malattia dai metadati (chiavi malattia + fallback source/title)
#' @keywords internal
.extract_disease_term <- function(source, characteristics, title) {
  kv <- .parse_characteristics_kv(characteristics)
  if (length(kv) > 0L) {
    hit <- names(kv)[grepl(.DISEASE_KEYS, names(kv), ignore.case = TRUE)]
    for (k in hit) {
      v <- kv[[k]]
      if (nzchar(v) && !grepl(.CONTROL_VALS, v, ignore.case = TRUE)) return(v)
    }
  }
  # fallback: source/title se contengono un marcatore tumore/malattia esplicito
  blob <- tolower(paste(source %||% "", title %||% ""))
  if (grepl("tumou?r|cancer|carcinoma|neoplas|leukemia|lymphoma", blob) &&
      !grepl(.CONTROL_VALS, blob, ignore.case = TRUE)) {
    return(tolower(trimws(gsub("\\s+", " ", source %||% title))))
  }
  NA_character_
}

#' Estrae il termine-agente (composto) dai metadati
#' @keywords internal
.extract_agent_term <- function(source, characteristics, title) {
  kv <- .parse_characteristics_kv(characteristics)
  if (length(kv) > 0L) {
    hit <- names(kv)[grepl(.AGENT_KEYS, names(kv))]
    for (k in hit) {
      v <- kv[[k]]
      if (nzchar(v) && !grepl(.AGENT_CONTROL, v)) return(v)
    }
  }
  NA_character_
}

# ---------------------------------------------------------------------------
# Task 5 -- .slugify + .normalize_disease_to_mesh
# ---------------------------------------------------------------------------

#' Produce uno slug ASCII minuscolo (spazi e punteggiatura -> underscore)
#' @keywords internal
.slugify <- function(x) {
  s <- tolower(trimws(gsub("[^a-z0-9]+", "_", tolower(x))))
  gsub("^_+|_+$", "", s)
}

#' Normalizza un termine-malattia testuale a MeSH (sinonimi -> stesso UI) oppure
#' al fallback STR:<slug> se non trovato in dizionario, oppure NA se termine assente.
#'
#' Flusso:
#' 1. Guardia su input mancante/vuoto -> id=NA, source="NO_TERM".
#' 2. Lookup nome/sinonimo via \code{.mesh_lookup_term} (indice \code{by_entry_lower}).
#' 3. Se trovato: recupera nome leggibile \code{$mh} via \code{.mesh_lookup_ui} ->
#'    id="MeSH:Dxxxxxx", source="MESH_NAME".
#' 4. Altrimenti: id="STR:<slug>", name=term, source="STR_FALLBACK".
#'
#' @param term character(1) termine-malattia estratto dai metadati GEO.
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#' @return lista con campi \code{id}, \code{name}, \code{source}.
#' @keywords internal
.normalize_disease_to_mesh <- function(term, ontology_env) {
  if (length(term) != 1L || is.na(term) || !nzchar(term)) {
    return(list(id = NA_character_, name = NA_character_, source = "NO_TERM"))
  }
  hit <- .mesh_lookup_term(term, env = ontology_env)
  if (!is.null(hit) && !is.null(hit$ui)) {
    full <- .mesh_lookup_ui(hit$ui, env = ontology_env)
    return(list(
      id     = paste0("MeSH:", hit$ui),
      name   = if (!is.null(full) && !is.null(full$mh)) full$mh else term,
      source = "MESH_NAME"
    ))
  }
  list(id = paste0("STR:", .slugify(term)), name = term, source = "STR_FALLBACK")
}

# ---------------------------------------------------------------------------
# Task 6 -- .normalize_compound_to_chebi
# ---------------------------------------------------------------------------

#' Normalizza un termine-composto testuale a ChEBI (sinonimi -> stesso ID) oppure
#' al fallback STR:<slug> se non trovato in dizionario, oppure NA se termine assente.
#'
#' Flusso:
#' 1. Guardia su input mancante/vuoto -> id=NA, source="NO_TERM".
#' 2. Lookup nome/alias via \code{.chebi_lookup_alias} (indice \code{alias_lower}).
#' 3. Se trovato: recupera nome leggibile \code{$primary_name} via
#'    \code{.chebi_lookup_id} -> id="CHEBI:<chebi_id>", source="CHEBI_ALIAS".
#' 4. Altrimenti: id="STR:<slug>", name=term, source="STR_FALLBACK".
#'
#' @param term character(1) termine-composto estratto dai metadati GEO.
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#' @return lista con campi \code{id}, \code{name}, \code{source}.
#' @keywords internal
.normalize_compound_to_chebi <- function(term, ontology_env) {
  if (length(term) != 1L || is.na(term) || !nzchar(term)) {
    return(list(id = NA_character_, name = NA_character_, source = "NO_TERM"))
  }
  hit <- .chebi_lookup_alias(term, env = ontology_env)
  if (!is.null(hit) && !is.null(hit$chebi_id)) {
    full <- .chebi_lookup_id(hit$chebi_id, env = ontology_env)
    return(list(
      id     = paste0("CHEBI:", hit$chebi_id),
      name   = if (!is.null(full) && !is.null(full$primary_name)) full$primary_name else term,
      source = "CHEBI_ALIAS"
    ))
  }
  list(id = paste0("STR:", .slugify(term)), name = term, source = "STR_FALLBACK")
}

.GENETIC_SIGNALS <- c(
  knockout       = "knock-?out|\\bko\\b|crispr|\\bcas9\\b|sgrna|gene deletion",
  knockdown      = "knock-?down|\\bshrna\\b|\\bsirna\\b|sh[A-Z][A-Z0-9]+|si[A-Z][A-Z0-9]+|dtag|\\baid\\b|auxin|\\biaa\\b|degron|fkbp12|depletion",
  overexpression = "over-?expression|overexpress|\\boe\\b|ectopic expression")

#' Rileva perturbazione genetica inequivocabile (K2) + gene bersaglio se possibile
#' @keywords internal
.detect_genetic_perturbation <- function(source, characteristics, title) {
  blob <- paste(source %||% "", characteristics %||% "", title %||% "")
  none <- list(is_genetic = FALSE, genetic_kind = NA_character_, target = NA_character_)
  kind <- NA_character_
  for (nm in names(.GENETIC_SIGNALS)) {
    if (grepl(.GENETIC_SIGNALS[[nm]], blob, perl = TRUE, ignore.case = TRUE)) {
      kind <- paste0("genetic_", nm); break
    }
  }
  if (is.na(kind)) return(none)
  # estrai gene bersaglio: token in MAIUSCOLO adiacente a un segnale (es. XRN2-dTAG, shTP53)
  m <- regmatches(blob, regexpr("\\b[A-Z][A-Z0-9]{1,6}(?=[- ]?(dTAG|AID|degron|KO|KD))", blob, perl = TRUE))
  m2 <- regmatches(blob, regexpr("(?<=\\b(sh|si))[A-Z][A-Z0-9]{1,6}", blob, perl = TRUE))
  target <- c(m, m2)
  list(is_genetic = TRUE, genetic_kind = kind,
       target = if (length(target)) target[[1L]] else NA_character_)
}
