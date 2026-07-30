# R/stage3-entity-label.R --- etichetta leggibile risolta DALL'ID dell'entita'
#
# Perche' esiste: il nome mostrato dei gruppi (`canonical_name`) e' ereditato
# dall'anchor del vecchio cluster e su decine di gruppi e' sbagliato, mentre
# l'ID (`contrast_entity`) e' giusto — CHEBI:63637 mostrato come "sodium
# aurothiomalate" e' vemurafenib, CHEBI:5931 "chloride" e' insulina,
# MeSH:D008180 "cancer" e' il lupus (censimento 2026-07-28).
#
# Queste funzioni NON toccano `canonical_name`: producono una colonna NUOVA,
# cosi' la provenienza dell'etichetta vecchia resta tracciabile. Sono a valle
# del pooling — `canonical_name` non compare in nessun file `R/stage4-*` — e
# quindi non cambiano nessun risultato di Stadio 4.

#' Risolve l'etichetta leggibile di un'entita' di contrasto dal suo ID
#'
#' @param entity_id character(1) nella forma \code{<PREFISSO>:<resto>}
#'   (\code{CHEBI:}, \code{HGNC:}, \code{MeSH:}, \code{CHEMBL:},
#'   \code{NCBITaxon:}, \code{STR:}, \code{COMBO:}). Il prefisso e' riconosciuto
#'   senza distinzione fra maiuscole e minuscole.
#' @param env environment dei dizionari (default \code{.load_ontology_dicts()}).
#' @return named list con \code{label} (character(1), \code{NA} se non
#'   risolvibile) e \code{label_source} (da dove viene l'etichetta:
#'   \code{chebi}, \code{hgnc}, \code{mesh}, \code{chembl},
#'   \code{ncbitaxon_normalized}, \code{str_literal}, \code{combo_parts},
#'   \code{unresolved}, \code{unknown_prefix}).
#' @keywords internal
.resolve_contrast_entity_label <- function(entity_id, env = .load_ontology_dicts()) {
  out <- function(label, source) {
    list(label = if (is.null(label) || !nzchar(label %||% "")) NA_character_ else label,
         label_source = source)
  }
  na_out <- function(source) list(label = NA_character_, label_source = source)

  x <- .normalize_key_chr(entity_id)   # NA su NA / "" / lunghezza != 1
  if (is.na(x)) return(na_out("unknown_prefix"))
  pos <- regexpr(":", x, fixed = TRUE)
  if (pos < 1L) return(na_out("unknown_prefix"))
  pref <- tolower(substr(x, 1L, pos - 1L))
  rest <- substr(x, pos + 1L, nchar(x))
  if (!nzchar(rest)) return(na_out("unknown_prefix"))

  # I primary_name ChEBI portano markup HTML per stereodescrittori e pedici
  # ("bleomycin A<small><sub>2</sub></small>"): via i tag, resta il testo.
  strip_markup <- function(s) trimws(gsub("<[^>]+>", "", s))

  # Un lookup che manca NON diventa un'etichetta inventata: diventa
  # "unresolved", visibile in tabella.
  hit_or_unresolved <- function(hit, field, source) {
    if (is.null(hit)) return(na_out("unresolved"))
    v <- hit[[field]]
    if (is.null(v) || length(v) != 1L || is.na(v) || !nzchar(as.character(v)))
      return(na_out("unresolved"))
    out(strip_markup(as.character(v)), source)
  }

  switch(pref,
    "chebi"  = hit_or_unresolved(.chebi_lookup_id(rest, env = env),  "primary_name", "chebi"),
    "hgnc"   = hit_or_unresolved(.hgnc_lookup_hgnc(rest, env = env), "symbol",       "hgnc"),
    "mesh"   = hit_or_unresolved(.mesh_lookup_ui(rest, env = env),   "mh",           "mesh"),
    "chembl" = hit_or_unresolved(.chembl_lookup_id(rest, env = env), "pref_name",    "chembl"),
    "ncbitaxon" = {
      # Il dizionario in cache conserva solo il nome NORMALIZZATO (senza spazi):
      # e' un'etichetta corretta ma non tipografica, e la fonte lo dichiara.
      tax <- env$taxonomy
      node <- if (!is.null(tax) && exists(rest, envir = tax$by_taxid, inherits = FALSE))
                get(rest, envir = tax$by_taxid, inherits = FALSE) else NULL
      hit_or_unresolved(node, "scientific_name", "ncbitaxon_normalized")
    },
    "str" = out(rest, "str_literal"),
    "combo" = {
      parts <- trimws(strsplit(rest, "+", fixed = TRUE)[[1L]])
      parts <- parts[nzchar(parts)]
      if (length(parts) == 0L) na_out("unresolved")
      else out(paste(parts, collapse = " + "), "combo_parts")
    },
    na_out("unknown_prefix")
  )
}

#' Risolve le etichette di un vettore di ID di entita'
#'
#' @param entity_ids character vector di ID (vedi
#'   \code{.resolve_contrast_entity_label}).
#' @param env environment dei dizionari.
#' @return tibble con \code{contrast_entity}, \code{contrast_entity_label},
#'   \code{contrast_entity_label_source}, nello stesso ordine dell'input.
#' @keywords internal
.resolve_contrast_entity_labels <- function(entity_ids, env = .load_ontology_dicts()) {
  entity_ids <- as.character(entity_ids)
  if (length(entity_ids) == 0L) {
    return(tibble::tibble(contrast_entity = character(0),
                          contrast_entity_label = character(0),
                          contrast_entity_label_source = character(0)))
  }
  res <- lapply(entity_ids, .resolve_contrast_entity_label, env = env)
  tibble::tibble(
    contrast_entity              = entity_ids,
    contrast_entity_label        = vapply(res, function(r) r$label,        character(1L)),
    contrast_entity_label_source = vapply(res, function(r) r$label_source, character(1L))
  )
}

#' Carica la tabella delle etichette curate a mano
#'
#' Il file di dati vive in \code{inst/extdata/entity-label-overrides.csv}: e'
#' una decisione umana (quale nome usare nel paper), non una regola, e per
#' questo sta nei dati e non nel codice.
#'
#' @return data.frame con \code{contrast_entity}, \code{label}, \code{nota}.
#' @keywords internal
.load_entity_label_overrides <- function() {
  p <- system.file("extdata", "entity-label-overrides.csv", package = "simulomicsr")
  if (!nzchar(p) || !file.exists(p)) {
    p <- file.path("inst", "extdata", "entity-label-overrides.csv")
  }
  if (!file.exists(p)) {
    return(data.frame(contrast_entity = character(0), label = character(0),
                      nota = character(0), stringsAsFactors = FALSE))
  }
  utils::read.csv(p, stringsAsFactors = FALSE)
}

#' Etichetta LEGGIBILE di un'entita' di contrasto
#'
#' Come \code{.resolve_contrast_entity_label}, ma applica prima le etichette
#' curate a mano: il dizionario della tassonomia conserva il nome scientifico
#' senza spazi e ChEBI usa i nomi sistematici, entrambi corretti ma non
#' pubblicabili.
#'
#' @param entity_id character(1).
#' @param env environment dei dizionari.
#' @param overrides data.frame delle etichette curate (default: il file di dati).
#' @return named list con \code{label}, \code{label_source} (\code{"override"}
#'   quando la scelta e' umana) e \code{label_note}.
#' @keywords internal
.display_entity_label <- function(entity_id, env = .load_ontology_dicts(),
                                  overrides = .load_entity_label_overrides()) {
  key <- .normalize_key_chr(entity_id)
  if (!is.na(key) && nrow(overrides) > 0L) {
    hit <- which(overrides$contrast_entity == key)
    if (length(hit) > 0L) {
      nota <- overrides$nota[hit[1L]]
      return(list(label = overrides$label[hit[1L]], label_source = "override",
                  label_note = if (is.null(nota) || !nzchar(nota %||% "")) NA_character_ else nota))
    }
  }
  base <- .resolve_contrast_entity_label(entity_id, env = env)
  # Nelle entita' STR l'etichetta e' la stringa grezza del delta: gli underscore
  # sono separatori, non parte del nome.
  if (identical(base$label_source, "str_literal") && !is.na(base$label)) {
    base$label <- gsub("_", " ", base$label, fixed = TRUE)
  }
  list(label = base$label, label_source = base$label_source, label_note = NA_character_)
}

#' Etichette leggibili di un vettore di ID
#'
#' @param entity_ids character vector.
#' @param env environment dei dizionari.
#' @param overrides data.frame delle etichette curate.
#' @return tibble con \code{contrast_entity}, \code{contrast_entity_label},
#'   \code{contrast_entity_label_source}, \code{contrast_entity_label_note}.
#' @keywords internal
.display_entity_labels <- function(entity_ids, env = .load_ontology_dicts(),
                                   overrides = .load_entity_label_overrides()) {
  entity_ids <- as.character(entity_ids)
  if (length(entity_ids) == 0L) {
    return(tibble::tibble(contrast_entity = character(0),
                          contrast_entity_label = character(0),
                          contrast_entity_label_source = character(0),
                          contrast_entity_label_note = character(0)))
  }
  res <- lapply(entity_ids, .display_entity_label, env = env, overrides = overrides)
  tibble::tibble(
    contrast_entity              = entity_ids,
    contrast_entity_label        = vapply(res, function(r) r$label,        character(1L)),
    contrast_entity_label_source = vapply(res, function(r) r$label_source, character(1L)),
    contrast_entity_label_note   = vapply(res, function(r) r$label_note,   character(1L))
  )
}
