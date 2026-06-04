# Firma di design per la deduplica delle condizioni Stadio 2 (ADR-0020, opzione C).
#
# design_signature() comprime un sample_facts (output Stadio 1, schema
# stage1.v3) alla sua SOLA condizione sperimentale: una chiave canonica
# deterministica per cui due campioni replicati della stessa condizione
# producono la stessa firma, mentre condizioni diverse producono firme diverse.
# L'identita' individuale (donor/age/sex/ancestry) e il numero di passaggio
# sono esclusi (vedi ADR-0020 D1 + raffinamenti sessione 13).

# Token che l'LLM emette per "valore mancante" (post-casefold): equivalgono ad
# assente. NON includono valori enum legittimi come "none"/"unclear".
.SIG_NA_TOKENS <- c("na", "n/a", "nan", "null")

#' Normalizza uno scalare a stringa canonica NA-aware
#'
#' NULL, NA, length-0, stringhe vuote e token NA-like (\code{NA}, \code{N/A},
#' \code{null}, \code{NaN}) collassano sul token assente \code{""}. Gli altri
#' valori sono trimmati, con whitespace interno collassato, casefolded e con il
#' segno micro (mu greco U+03BC / micro sign U+00B5) normalizzato a \code{"u"}.
#' Queste normalizzazioni rimuovono rumore di codifica (es. unita' dose
#' \code{µM} vs \code{uM}) senza fondere valori biologicamente distinti.
#' @keywords internal
.norm_scalar <- function(x) {
  if (is.null(x) || length(x) == 0L) return("")
  x <- x[[1]]
  if (is.null(x) || (length(x) == 1L && is.na(x))) return("")
  s <- trimws(as.character(x))
  s <- gsub("[[:space:]]+", " ", s)
  s <- tolower(s)
  s <- gsub("µ|μ", "u", s)
  if (s %in% .SIG_NA_TOKENS) return("")
  s
}

#' Normalizza un set di stringhe (array) -> lista di token, vuota se assente
#' @keywords internal
.norm_set <- function(x) {
  if (is.null(x) || length(x) == 0L) return(list())
  lapply(x, .norm_scalar)
}

#' Token dose: value_numeric+unit se presente, altrimenti fallback value_raw
#' @keywords internal
.norm_dose <- function(dose) {
  num <- .norm_scalar(dose$value_numeric)
  if (nzchar(num)) return(paste(num, .norm_scalar(dose$unit)))
  .norm_scalar(dose$value_raw)
}

#' Token durata: value_hours se presente, altrimenti fallback value_raw
#' @keywords internal
.norm_duration <- function(duration) {
  hrs <- .norm_scalar(duration$value_hours)
  if (nzchar(hrs)) return(hrs)
  .norm_scalar(duration$value_raw)
}

#' Normalizza una modifica ingegnerizzata (esclude la description libera)
#' @keywords internal
.norm_engmod <- function(em) {
  variant <- em$variant
  list(
    kind = .norm_scalar(em$kind),
    label = .norm_scalar(em$label),
    variant_label = .norm_scalar(variant$label),
    variant_is_wildtype = .norm_scalar(variant$is_wildtype)
  )
}

#' Normalizza un partner di co-coltura
#' @keywords internal
.norm_ccp <- function(cp) {
  list(
    cell_type = .norm_scalar(cp$cell_type),
    source_organism = .norm_scalar(cp$source_organism),
    modifications = .norm_set(cp$modifications),
    role = .norm_scalar(cp$role)
  )
}

#' Normalizza una perturbazione alla sua identita' di disegno
#'
#' agent_raw e' casefolded+trimmato (discriminatore primario, robusto entro lo
#' studio); type/db/id restano come separazione extra quando presenti. La
#' canonicalizzazione cross-studio e' compito dell'anchor (Stadio 3), non qui.
#' @keywords internal
.norm_pert <- function(p) {
  an <- p$agent_normalized
  list(
    kind = .norm_scalar(p$kind),
    agent_raw = .norm_scalar(p$agent_raw),
    agent_type = .norm_scalar(an$type),
    agent_db = .norm_scalar(an$id_database),
    agent_id = .norm_scalar(an$id),
    dose = .norm_dose(p$dose),
    duration = .norm_duration(p$duration),
    phase = .norm_scalar(p$phase),
    is_zero_timepoint = .norm_scalar(p$duration$is_zero_timepoint),
    is_negative_control = .norm_scalar(p$is_negative_control)
  )
}

#' Costruisce la struttura normalizzata della firma (solo campi di disegno)
#' @keywords internal
.build_signature_struct <- function(sample_facts) {
  cc <- sample_facts$cell_context
  ds <- sample_facts$disease_state
  pm <- sample_facts$patient_metadata
  list(
    cell_context = list(
      tissue = .norm_scalar(cc$tissue),
      tissue_segment = .norm_scalar(cc$tissue_segment),
      cell_type_or_line_raw = .norm_scalar(cc$cell_type_or_line_raw),
      context_kind = .norm_scalar(cc$context_kind),
      cell_state = .norm_scalar(cc$cell_state),
      developmental_stage = .norm_scalar(cc$developmental_stage),
      subcellular_fraction = .norm_scalar(cc$subcellular_fraction$kind),
      engineered_modifications = lapply(cc$engineered_modifications, .norm_engmod),
      sort_markers = .norm_set(cc$sort_markers),
      co_culture_partners = lapply(cc$co_culture_partners, .norm_ccp)
    ),
    disease_state = list(
      status = .norm_scalar(ds$status),
      term_raw = .norm_scalar(ds$term_raw),
      mesh_id_candidate = .norm_scalar(ds$mesh_id_candidate)
    ),
    perturbations = lapply(sample_facts$perturbations, .norm_pert),
    patient_metadata = list(
      condition = .norm_scalar(pm$condition),
      clinical_response = .norm_scalar(pm$clinical_response),
      stage = .norm_scalar(pm$stage),
      survival_group = .norm_scalar(pm$survival_group),
      visit_or_timepoint = .norm_scalar(pm$visit_or_timepoint)
    )
  )
}

#' Quoting JSON di una stringa (escape minimale, deterministico)
#' @keywords internal
.json_quote <- function(s) {
  s <- gsub("\\\\", "\\\\\\\\", s)
  s <- gsub('"', '\\\\"', s)
  paste0('"', s, '"')
}

#' Serializzazione JSON canonica ordine-insensibile
#'
#' Oggetti: chiavi ordinate. Array: elementi serializzati e POI ordinati (tutti
#' gli array della firma sono insiemi, nessun ordine significativo). Scalari:
#' gia' normalizzati a stringa, quotati.
#' @keywords internal
.canon_json <- function(x) {
  if (is.null(x)) return("null")
  if (is.list(x)) {
    nm <- names(x)
    if (is.null(nm) || all(!nzchar(nm))) {
      parts <- vapply(x, .canon_json, character(1))
      parts <- sort(parts)
      return(paste0("[", paste(parts, collapse = ","), "]"))
    }
    o <- order(nm)
    parts <- vapply(o, function(i) {
      paste0(.json_quote(nm[i]), ":", .canon_json(x[[i]]))
    }, character(1))
    return(paste0("{", paste(parts, collapse = ","), "}"))
  }
  .json_quote(as.character(x[[1]]))
}

#' Firma di design canonica di un sample (Stadio 2 dedup, ADR-0020)
#'
#' Riduce un \code{sample_facts} (schema stage1.v3, lista nested come da
#' \code{jsonlite::fromJSON(simplifyVector = FALSE)}) a una chiave canonica
#' deterministica della sola condizione sperimentale. Campioni replicati della
#' stessa condizione -> stessa firma; condizioni diverse (tessuto, segmento,
#' agente/dose/tempo, malattia, condizione clinica) -> firme diverse. Esclude
#' l'identita' individuale (donor/age/sex/ancestry) e il passaggio. NA-aware
#' (NULL/NA/"" equivalenti) e ordine-insensibile su set e liste.
#'
#' @param sample_facts Lista nested dei fatti Stadio 1 di un campione.
#' @return \code{character(1)}: la firma JSON canonica.
#' @export
design_signature <- function(sample_facts) {
  .canon_json(.build_signature_struct(sample_facts))
}
