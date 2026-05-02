#' Normalizza un valore di dose nella forma canonica dell'anchor
#'
#' Rimuove spazi, normalizza simboli micro, mappa null/NA/"" -> "nodose".
#' Preserva il valore "standard" come placeholder per dosaggi non specificati
#' ma noti dal protocollo.
#'
#' @param dose stringa o NULL/NA
#' @return stringa canonica (es. "10nM", "100ng/ml", "nodose", "standard")
#' @keywords internal
.normalize_dose <- function(dose) {
  if (is.null(dose) || length(dose) == 0L) return("nodose")
  if (is.na(dose) || !nzchar(dose)) return("nodose")
  d <- gsub("\\s+", "", dose)
  d <- gsub("µ", "u", d)  # micro symbol -> u
  d
}

#' Normalizza una durata nella forma canonica dell'anchor (ore/giorni)
#'
#' Converte minuti -> ore (1.5h per 90 min), days -> ore (48h per 2 days)
#' tranne per durate >= 6 giorni dove preserva "Nd" (es. 6d, 14d).
#' Mappa null/NA/"" -> "na".
#'
#' @param duration stringa o NULL/NA
#' @return stringa canonica
#' @keywords internal
.normalize_duration <- function(duration) {
  if (is.null(duration) || length(duration) == 0L) return("na")
  if (is.na(duration) || !nzchar(duration)) return("na")
  s <- tolower(gsub("\\s+", "", duration))

  # Pattern: <num><unit>
  m <- regmatches(s, regexec("^([0-9.]+)([a-z]+)$", s))[[1L]]
  if (length(m) != 3L) return(s)
  num <- as.numeric(m[2L])
  unit <- m[3L]

  if (unit %in% c("min", "minute", "minutes", "m")) {
    return(paste0(format(num / 60, drop0trailing = TRUE), "h"))
  }
  if (unit %in% c("h", "hr", "hour", "hours")) {
    return(paste0(format(num, drop0trailing = TRUE), "h"))
  }
  if (unit %in% c("d", "day", "days")) {
    if (num >= 6) {
      return(paste0(format(num, drop0trailing = TRUE), "d"))
    }
    return(paste0(format(num * 24, drop0trailing = TRUE), "h"))
  }
  s  # fallback
}

#' Normalizza un cell identifier per l'anchor
#'
#' Preferenza: Cellosaurus ID. Fallback: label_raw. Default: "unclear".
#'
#' @param cellosaurus_id stringa o NULL/NA
#' @param label_raw stringa o NULL/NA
#' @return stringa canonica
#' @keywords internal
.normalize_cell_id <- function(cellosaurus_id, label_raw) {
  if (.nzchar_safe(cellosaurus_id)) return(cellosaurus_id)
  if (.nzchar_safe(label_raw)) return(label_raw)
  "unclear"
}

#' @noRd
.nzchar_safe <- function(x) {
  !is.null(x) && length(x) > 0L && !is.na(x) && nzchar(x)
}

#' Costruisci comparability_anchor v3 (13 segmenti) per un sample fact
#'
#' L'anchor e' una chiave canonica deterministica per cross-studio matching
#' (vedi spec sec.4.3). Selezionata la perturbazione di interesse dal sample,
#' applica le regole R8 (mediated_effect), R9 (variant), R24 (phase), R25
#' (subcellular default whole_cell), R31 (cell_state default proliferating).
#'
#' @param stage1_facts list (un sample_fact validato stage1.v3)
#' @param stage2_role string: design_role assegnato dallo Stadio 2 al sample
#'   (es. "perturbed", "case", "comparison"). Influenza il segmento 12 e,
#'   per role case/comparison, kind_effective diventa "disease_vs_normal".
#' @return string a 13 segmenti separati da "|"
#' @export
make_anchor <- function(stage1_facts, stage2_role) {
  pert <- .select_primary_perturbation(stage1_facts$perturbations, stage2_role)

  # Verifica se si tratta di un design disease_vs_normal (R spec sec.4.3)
  is_disease_design <- stage2_role %in% c("case", "comparison") ||
    isTRUE(stage1_facts$disease_state$status %in% c("case", "comparison", "disease_model"))

  if (is_disease_design) {
    # Per disease_vs_normal: kind_effective fisso + agente = MeSH ID malattia
    kind_effective <- "disease_vs_normal"
    agent_id       <- stage1_facts$disease_state$mesh_id_candidate %||% "unknown"
    variant_label  <- "wt"
  } else if (!is.null(pert$mediated_effect) && length(pert$mediated_effect) > 0L) {
    # R8: il Tet-On/AID inducente cede il passo al target biologico
    kind_effective <- .map_kind_to_anchor(pert$mediated_effect$kind %||% pert$kind %||% "unclear")
    target_name    <- if (length(pert$mediated_effect$targets) > 0L)
                        pert$mediated_effect$targets[[1L]]
                      else
                        "unknown"
    agent_id       <- paste0("HGNC:", target_name)
    # R9: per l'agente mediato, variant da engineered_modifications se non-wt
    variant_label  <- .resolve_variant_label(stage1_facts$cell_context$engineered_modifications)
  } else {
    kind_effective <- .map_kind_to_anchor(pert$kind %||% "unclear")
    agent_id       <- .resolve_agent_id(pert$agent_normalized)
    # R9: variant da engineered_modifications se non-wt
    variant_label  <- .resolve_variant_label(stage1_facts$cell_context$engineered_modifications)
  }

  # Dose e durata: i campi perturbation sono oggetti {value_raw, ...}
  dose_raw         <- pert$dose$value_raw %||% NULL
  dose_canonical   <- .normalize_dose(dose_raw)

  duration_raw     <- pert$duration$value_raw %||% NULL
  duration_canonical <- .normalize_duration(duration_raw)

  phase_canonical  <- pert$phase %||% "exposure"

  # Contesto cellulare
  cell_id    <- .normalize_cell_id(
    stage1_facts$cell_context$cell_line_cellosaurus_candidate,
    stage1_facts$cell_context$cell_type_or_line_raw
  )
  context_kind <- stage1_facts$cell_context$context_kind %||% "unclear"
  # R31: default proliferating se cell_state assente
  cell_state   <- stage1_facts$cell_context$cell_state %||% "proliferating"
  # R25: subcellular_fraction e' un oggetto {kind, raw} oppure null
  subcellular  <- if (!is.null(stage1_facts$cell_context$subcellular_fraction) &&
                       length(stage1_facts$cell_context$subcellular_fraction) > 0L)
                    stage1_facts$cell_context$subcellular_fraction$kind %||% "whole_cell"
                  else
                    "whole_cell"
  tissue       <- stage1_facts$cell_context$tissue %||% "na"

  disease_status  <- .resolve_disease_status(stage1_facts$disease_state, stage2_role)
  has_engineered  <- length(stage1_facts$cell_context$engineered_modifications) > 0L

  paste(
    kind_effective,
    agent_id,
    variant_label,
    dose_canonical,
    duration_canonical,
    phase_canonical,
    cell_id,
    context_kind,
    cell_state,
    subcellular,
    tissue,
    disease_status,
    tolower(as.character(has_engineered)),
    sep = "|"
  )
}

#' @noRd
.select_primary_perturbation <- function(perturbations, stage2_role) {
  if (length(perturbations) == 0L) {
    # Perturbazione nulla (es. disease_vs_normal senza intervento)
    return(list(
      kind = "none",
      agent_normalized = NULL,
      dose = list(value_raw = NULL),
      duration = list(value_raw = NULL),
      phase = NULL,
      mediated_effect = NULL
    ))
  }
  perturbations[[1L]]
}

#' @noRd
.map_kind_to_anchor <- function(stage1_kind) {
  switch(
    stage1_kind,
    cytokine_stimulation             = "cytokine_stim",
    small_molecule                   = "small_molecule",
    genetic_knockdown                = "genetic_knockdown",
    genetic_knockout                 = "genetic_knockout",
    genetic_overexpression           = "genetic_overexpression",
    crispra_activation               = "crispra_activation",
    crispri_repression               = "crispri_repression",
    pathogen_or_aggregate_exposure   = "pathogen_or_aggregate_exposure",
    environmental_or_behavioral      = "environmental",
    differentiation                  = "differentiation",
    mechanical_or_physical           = "mechanical",
    vehicle_only                     = "vehicle_only",
    none                             = "none",
    stage1_kind  # passthrough per kind non mappati
  )
}

#' @noRd
.resolve_agent_id <- function(agent_normalized) {
  if (is.null(agent_normalized)) return("unknown")
  id_cand <- agent_normalized$id %||% NA_character_
  if (.nzchar_safe(id_cand)) return(id_cand)
  id_db   <- agent_normalized$id_database %||% NA_character_
  pref    <- agent_normalized$preferred_name %||% "unknown"
  if (.nzchar_safe(id_db) && .nzchar_safe(pref)) {
    return(paste0(id_db, ":", pref))
  }
  if (.nzchar_safe(pref)) return(pref)
  "unknown"
}

#' @noRd
# R9: se esiste un engineered_modification con variant non-wildtype,
# usa il suo variant.label; altrimenti "wt".
.resolve_variant_label <- function(engineered_modifications) {
  for (mod in engineered_modifications) {
    v <- mod$variant
    if (!is.null(v) && isFALSE(v$is_wildtype) && .nzchar_safe(v$label)) {
      return(v$label)
    }
  }
  "wt"
}

#' @noRd
.resolve_disease_status <- function(disease_state, stage2_role) {
  if (stage2_role %in% c("case", "comparison")) return(stage2_role)
  status <- disease_state$status %||% "none"
  if (status == "disease_model")  return("disease_model")
  if (status == "case")           return("case")
  if (status == "comparison")     return("comparison")
  "none"
}
