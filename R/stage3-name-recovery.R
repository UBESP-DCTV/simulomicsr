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

# ---------------------------------------------------------------------------
# Task 7 -- recover_identity (orchestratore pubblico)
# ---------------------------------------------------------------------------

#' Recupera l'identita' biologica di un campione dai metadati GEO grezzi.
#'
#' Orchestratore che compone le funzioni interne Task 1-6 in un flusso
#' prioritario: (1) correzione K2 genetica, (2) normalizzazione malattia,
#' (3) normalizzazione composto/citochina/patogeno, (4) nessun recupero
#' (regime U1). Il campo \code{kind} restituito e' corretto (K2) o invariato
#' rispetto a \code{llm_kind}.
#'
#' @param source character(1) campo \code{source} GEO del campione.
#' @param characteristics character(1) campo \code{characteristics_ch1} GEO.
#' @param title character(1) campo \code{title} GEO del campione.
#' @param llm_kind character(1) \code{kind_effective} emesso dall'LLM Stadio 2.
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#' @return Lista con quattro campi:
#'   \describe{
#'     \item{kind}{character(1) kind corretto (es. \code{"genetic_knockdown"})
#'       oppure invariato rispetto a \code{llm_kind}.}
#'     \item{agent_id}{character(1) ID ontologico canonico (es.
#'       \code{"MeSH:D011471"}, \code{"CHEBI:16236"}, \code{"HGNC:XRN2"},
#'       \code{"STR:<slug>"}) oppure \code{NA} se non recuperabile.}
#'     \item{canonical_name}{character(1) nome leggibile dell'entita' oppure
#'       \code{NA}.}
#'     \item{recovery_source}{character(1) sorgente del recupero:
#'       \code{"K2_GENETIC"}, \code{"MESH_NAME"}, \code{"CHEBI_ALIAS"},
#'       \code{"STR_FALLBACK"}, \code{"NO_RECOVERY"}.}
#'   }
#' @export
recover_identity <- function(source, characteristics, title, llm_kind, ontology_env) {
  .perturbative_kinds <- c(
    "small_molecule",
    "cytokine_stim",
    "pathogen_or_aggregate_exposure"
  )

  # Passo 1: K2 — perturbazione genetica mal-etichettata come perturbativa
  g <- .detect_genetic_perturbation(source, characteristics, title)
  if (isTRUE(g$is_genetic) && !is.na(llm_kind) && llm_kind %in% .perturbative_kinds) {
    agent_id <- if (!is.na(g$target)) paste0("HGNC:", g$target) else NA_character_
    return(list(
      kind            = g$genetic_kind,
      agent_id        = agent_id,
      canonical_name  = g$target,
      recovery_source = "K2_GENETIC"
    ))
  }

  # Passo 2: disease_vs_normal -> MeSH (o STR fallback) o U1
  if (!is.na(llm_kind) && llm_kind == "disease_vs_normal") {
    t <- .extract_disease_term(source, characteristics, title)
    if (!is.na(t)) {
      n <- .normalize_disease_to_mesh(t, ontology_env)
      return(list(
        kind            = "disease_vs_normal",
        agent_id        = n$id,
        canonical_name  = n$name,
        recovery_source = n$source
      ))
    }
    # Regime U1: nessun termine estraibile
    return(list(
      kind            = "disease_vs_normal",
      agent_id        = NA_character_,
      canonical_name  = NA_character_,
      recovery_source = "NO_RECOVERY"
    ))
  }

  # Passo 3: composto/citochina/patogeno -> ChEBI (o STR fallback)
  if (!is.na(llm_kind) && llm_kind %in% .perturbative_kinds) {
    t <- .extract_agent_term(source, characteristics, title)
    if (!is.na(t)) {
      n <- .normalize_compound_to_chebi(t, ontology_env)
      return(list(
        kind            = llm_kind,
        agent_id        = n$id,
        canonical_name  = n$name,
        recovery_source = n$source
      ))
    }
    return(list(
      kind            = llm_kind,
      agent_id        = NA_character_,
      canonical_name  = NA_character_,
      recovery_source = "NO_RECOVERY"
    ))
  }

  # Passo 4: altri kind (time_course, genetic_*, ecc.) -> nessun recupero
  list(
    kind            = llm_kind,
    agent_id        = NA_character_,
    canonical_name  = NA_character_,
    recovery_source = "NO_RECOVERY"
  )
}

# Segnali genetici (K2). Spec: is_genetic SOLO su segnali inequivocabili.
#
# DUE famiglie di pattern testate separatamente per ogni kind:
# - CI (case-INsensitive): termini robustamente inequivocabili che NON dipendono
#   dal case (knockout, knockdown, shRNA, siRNA, crispr, cas9, sgrna, dtag,
#   degron, fkbp12, overexpression). Il depletion e' ristretto a
#   (protein|targeted|degron)[ -]?depletion per NON catturare "serum depletion"
#   o "glucose depletion".
# - CS (case-SENSITIVE): pattern di FORMA (sh/si minuscolo + simbolo gene
#   MAIUSCOLO; KO/AID maiuscoli; oe minuscolo). Con ignore.case questi
#   annullerebbero il loro intento e flipperebbero "simvastatin", "sirolimus",
#   "Resiquimod", "single cell", "signal transduction" a genetic_* (review C1).
# auxin/IAA NON sono piu' trigger autonomi: contano solo accompagnati da
# degron/AID, che gia' triggerano per conto loro.
.GENETIC_SIGNALS_CI <- c(
  knockout       = "knock-?out|crispr|\\bcas9\\b|sgrna|gene deletion",
  knockdown      = paste0("knock-?down|\\bshrna\\b|\\bsirna\\b|dtag|degron|fkbp12|",
                          "(protein|targeted|degron)[ -]?depletion"),
  overexpression = "over-?expression|overexpress|ectopic expression")

.GENETIC_SIGNALS_CS <- c(
  knockout       = "\\bKO\\b|\\bAID\\b",
  knockdown      = "sh[A-Z][A-Z0-9]+|si[A-Z][A-Z0-9]+",
  overexpression = "\\boe\\b")

#' Rileva perturbazione genetica inequivocabile (K2) + gene bersaglio se possibile
#' @keywords internal
.detect_genetic_perturbation <- function(source, characteristics, title) {
  blob <- paste(source %||% "", characteristics %||% "", title %||% "")
  none <- list(is_genetic = FALSE, genetic_kind = NA_character_, target = NA_character_)
  kind <- NA_character_
  for (nm in names(.GENETIC_SIGNALS_CI)) {
    ci_pat <- .GENETIC_SIGNALS_CI[[nm]]
    cs_pat <- .GENETIC_SIGNALS_CS[[nm]]
    ci_hit <- nzchar(ci_pat) && grepl(ci_pat, blob, perl = TRUE, ignore.case = TRUE)
    cs_hit <- nzchar(cs_pat) && grepl(cs_pat, blob, perl = TRUE, ignore.case = FALSE)
    if (ci_hit || cs_hit) {
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
