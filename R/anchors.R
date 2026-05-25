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
  d <- gsub("\u00b5", "u", d)  # micro symbol -> u
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

  # Verifica se si tratta di un design disease_vs_normal (R spec sec.4.3).
  # Override fires solo quando:
  #   (a) stage2_role e' esplicitamente "case"/"comparison" (Stadio 2 ha
  #       assegnato il ruolo disease cohort), OPPURE
  #   (b) c'e' un disease state ma NON una perturbazione attiva
  #       (cell line disease model SENZA drug/KD/cytokine: la malattia stessa
  #       e' il design)
  # Se c'e' una perturbazione attiva su un disease model, vince la perturbazione
  # (segmento 1 = kind_effective della perturbazione, segmento 12 conserva
  # disease_status=disease_model). Coerente con spec sec.4.3 esempio PFF.
  has_active_perturbation <- length(stage1_facts$perturbations) > 0L &&
    !is.null(pert$kind) &&
    !identical(pert$kind, "none") &&
    !identical(pert$kind, "vehicle_only") &&
    !identical(pert$kind, "unclear")

  is_disease_design <- stage2_role %in% c("case", "comparison") ||
    (isTRUE(stage1_facts$disease_state$status %in% c("case", "comparison", "disease_model")) &&
     !has_active_perturbation)

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

#' Audit log degli inducenti per perturbazioni mediated_effect (R8)
#'
#' Per ogni perturbazione con mediated_effect != null, registra l'inducente
#' che make_anchor() perde (es. Dox per sistemi Tet-On). Utile per audit
#' a valle e per QC manuale.
#'
#' @param stage1_facts list (un sample_fact validato stage1.v3)
#' @return list di entries, una per perturbazione mediated. Vuota se nessuna.
#'   Ogni entry ha campi: inducer_kind, inducer_name, mediated_kind, mediated_target.
#' @export
make_inducer_log <- function(stage1_facts) {
  perts <- stage1_facts$perturbations %||% list()
  out <- list()
  for (p in perts) {
    if (is.null(p$mediated_effect) || length(p$mediated_effect) == 0L) next
    # Schema stage1.v3: mediated_effect ha campo `targets` (array), non `target`
    targets <- p$mediated_effect$targets %||% list()
    target_str <- if (length(targets) >= 1L) targets[[1L]] else "unknown"
    out[[length(out) + 1L]] <- list(
      inducer_kind = p$kind %||% "unknown",
      inducer_name = p$agent_normalized$preferred_name %||% (p$agent_raw %||% "unknown"),
      mediated_kind = p$mediated_effect$kind %||% "unknown",
      mediated_target = target_str
    )
  }
  out
}

# --- Anchor v3.1: post-hoc ontology resolver (ADR-0018) ----------------------
#
# resolve_agent_canonical() risolve l'agent LLM-emitted contro le 3 dictionary
# (ChEBI/HGNC/MeSH) restituendo un canonical_id deterministico + source enum.
# Sostituisce concettualmente .resolve_agent_id() per Stage 3 v3.1 (Task 4
# integration); .resolve_agent_id() resta per backward-compat su make_anchor().
#
# Vedi spec docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md
# sezione 4.2 per la decision table completa.

#' @noRd
.is_digit_only <- function(s) {
  if (is.null(s) || length(s) == 0L) return(FALSE)
  if (is.na(s) || !nzchar(s)) return(FALSE)
  grepl("^[0-9]+$", s)
}

#' @noRd
.is_mesh_ui <- function(s) {
  if (is.null(s) || length(s) == 0L) return(FALSE)
  if (is.na(s) || !nzchar(s)) return(FALSE)
  grepl("^D[0-9]{6}$", s)
}

#' @noRd
.strip_db_prefix <- function(value, db_prefix) {
  if (is.null(value) || !nzchar(value)) return(value)
  if (startsWith(toupper(value), toupper(db_prefix))) {
    return(substring(value, nchar(db_prefix) + 1L))
  }
  value
}

#' Risolve un intero ChEBI (anche secondary) contro la dictionary
#'
#' Ritorna \code{list(chebi_id, primary_name, redirected)} su hit,
#' \code{NULL} altrimenti.
#' @noRd
.try_chebi_int <- function(value_str, env) {
  if (!.is_digit_only(value_str)) return(NULL)
  int_val <- suppressWarnings(as.integer(value_str))
  if (is.na(int_val)) return(NULL)
  hit <- .chebi_lookup_id(int_val, env = env)
  if (!is.null(hit)) {
    return(list(chebi_id = hit$chebi_id, primary_name = hit$primary_name,
                redirected = FALSE))
  }
  primary <- .chebi_secondary_redirect(int_val, env = env)
  if (!is.null(primary)) {
    hit2 <- .chebi_lookup_id(primary, env = env)
    if (!is.null(hit2)) {
      return(list(chebi_id = hit2$chebi_id, primary_name = hit2$primary_name,
                  redirected = TRUE))
    }
  }
  NULL
}

#' Risolve un intero HGNC (hgnc_int OR entrez_int) contro la dictionary
#'
#' Tenta prima \code{by_hgnc_int} poi \code{by_entrez_int}. Ritorna
#' \code{list(hgnc_int, symbol, source)} con \code{source} in
#' \code{"HGNC"} o \code{"ENTREZ"}; \code{NULL} su miss.
#' @noRd
.try_hgnc_int <- function(value_str, env) {
  if (!.is_digit_only(value_str)) return(NULL)
  int_val <- suppressWarnings(as.integer(value_str))
  if (is.na(int_val)) return(NULL)
  hit <- .hgnc_lookup_hgnc(int_val, env = env)
  if (!is.null(hit)) {
    return(list(hgnc_int = hit$hgnc_int, symbol = hit$symbol, source = "HGNC"))
  }
  hit2 <- .hgnc_lookup_entrez(int_val, env = env)
  if (!is.null(hit2)) {
    return(list(hgnc_int = hit2$hgnc_int, symbol = hit2$symbol, source = "ENTREZ"))
  }
  NULL
}

#' @noRd
.canonical_noagent <- function() {
  list(canonical_id = "UNK", canonical_name = NA_character_,
       resolution_source = "NO_AGENT")
}

#' Risolve agent_normalized contro ChEBI/HGNC/MeSH per anchor v3.1
#'
#' Decision table completa in spec sezione 4.2. Restituisce \code{canonical_id}
#' deterministico (prefix \code{CHEBI:}, \code{HGNC:}, \code{MeSH:},
#' \code{ChEMBL:}, \code{STR:}, o \code{UNK}) + \code{resolution_source} enum +
#' \code{canonical_name} leggibile.
#'
#' Source enum: \code{CHEBI_DIRECT}, \code{CHEBI_FIELDSWAP},
#' \code{CHEBI_SECONDARY_REDIRECT}, \code{CHEBI_FIELDSWAP_SECONDARY_REDIRECT},
#' \code{WRONG_DB_to_HGNC}, \code{HGNC_DIRECT}, \code{HGNC_FIELDSWAP},
#' \code{HGNC_ENTREZ_MAPPED}, \code{HGNC_ENTREZ_MAPPED_FIELDSWAP},
#' \code{MESH_DIRECT}, \code{MESH_FIELDSWAP}, \code{MESH_NAKED},
#' \code{STRING_ALIAS_CHEBI}, \code{STRING_ALIAS_HGNC}, \code{STRING_ALIAS_MESH},
#' \code{LLM_VEHICLE_LITERAL}, \code{CHEMBL_NAKED_NOLOOKUP},
#' \code{HALLUCINATED_OR_FALLBACK}, \code{STRING_NO_ALIAS_MATCH},
#' \code{NO_AGENT}.
#'
#' @param agent_normalized list (sample_facts.stage1.v3 perturbation
#'   agent_normalized) o NULL. Campi attesi: \code{id_database}, \code{id},
#'   \code{preferred_name}, \code{type}.
#' @param env environment caricato da \code{.load_ontology_dicts()}.
#' @return named list con \code{canonical_id}, \code{canonical_name},
#'   \code{resolution_source}.
#' @keywords internal
resolve_agent_canonical <- function(agent_normalized,
                                    env = .load_ontology_dicts()) {
  if (is.null(agent_normalized)) return(.canonical_noagent())

  type_v  <- agent_normalized$type           %||% ""
  id_db_v <- agent_normalized$id_database    %||% ""
  id_v    <- agent_normalized$id             %||% ""
  pref_v  <- agent_normalized$preferred_name %||% ""

  # NA -> ""
  if (length(type_v)  == 0L || is.na(type_v))  type_v  <- ""
  if (length(id_db_v) == 0L || is.na(id_db_v)) id_db_v <- ""
  if (length(id_v)    == 0L || is.na(id_v))    id_v    <- ""
  if (length(pref_v)  == 0L || is.na(pref_v))  pref_v  <- ""

  if (!nzchar(type_v) && !nzchar(id_db_v) && !nzchar(id_v) && !nzchar(pref_v)) {
    return(.canonical_noagent())
  }
  if (identical(type_v, "none")) return(.canonical_noagent())

  # Vehicle literal: preserva LLM intent (DMSO/PBS as-is)
  if (identical(type_v, "vehicle") && nzchar(pref_v)) {
    return(list(
      canonical_id      = paste0("STR:", tolower(pref_v)),
      canonical_name    = pref_v,
      resolution_source = "LLM_VEHICLE_LITERAL"
    ))
  }

  id_db_norm <- toupper(id_db_v)

  # ChEMBL: accept as opaque (no ChEMBL dictionary loaded)
  if (id_db_norm == "CHEMBL") {
    chembl_val <- if (nzchar(id_v)) id_v else pref_v
    if (nzchar(chembl_val)) {
      return(list(
        canonical_id      = paste0("ChEMBL:", chembl_val),
        canonical_name    = if (nzchar(pref_v)) pref_v else NA_character_,
        resolution_source = "CHEMBL_NAKED_NOLOOKUP"
      ))
    }
  }

  # CHEBI path
  if (id_db_norm == "CHEBI") {
    id_clean   <- .strip_db_prefix(id_v, "CHEBI:")
    pref_clean <- .strip_db_prefix(pref_v, "CHEBI:")

    # 1. id field numerico in ChEBI primary/secondary
    hit <- .try_chebi_int(id_clean, env = env)
    if (!is.null(hit)) {
      src <- if (hit$redirected) "CHEBI_SECONDARY_REDIRECT" else "CHEBI_DIRECT"
      return(list(canonical_id      = paste0("CHEBI:", hit$chebi_id),
                  canonical_name    = hit$primary_name,
                  resolution_source = src))
    }
    # 2. preferred_name numerico (field-swap)
    hit2 <- .try_chebi_int(pref_clean, env = env)
    if (!is.null(hit2)) {
      src <- if (hit2$redirected) "CHEBI_FIELDSWAP_SECONDARY_REDIRECT" else "CHEBI_FIELDSWAP"
      return(list(canonical_id      = paste0("CHEBI:", hit2$chebi_id),
                  canonical_name    = hit2$primary_name,
                  resolution_source = src))
    }
    # 3. id field numerico in HGNC (wrong DB)
    hit3 <- .try_hgnc_int(id_clean, env = env)
    if (!is.null(hit3)) {
      return(list(canonical_id      = paste0("HGNC:", hit3$hgnc_int),
                  canonical_name    = hit3$symbol,
                  resolution_source = "WRONG_DB_to_HGNC"))
    }
    # 4. preferred_name come ChEBI alias
    hit4 <- .chebi_lookup_alias(pref_v, env = env)
    if (!is.null(hit4)) {
      hit_full <- .chebi_lookup_id(hit4$chebi_id, env = env)
      cname <- if (!is.null(hit_full)) hit_full$primary_name else pref_v
      return(list(canonical_id      = paste0("CHEBI:", hit4$chebi_id),
                  canonical_name    = cname,
                  resolution_source = "STRING_ALIAS_CHEBI"))
    }
    # Falltrough --> HALLUCINATED_OR_FALLBACK
  }

  # HGNC path
  if (id_db_norm == "HGNC") {
    id_clean   <- .strip_db_prefix(id_v, "HGNC:")
    pref_clean <- .strip_db_prefix(pref_v, "HGNC:")

    hit <- .try_hgnc_int(id_clean, env = env)
    if (!is.null(hit)) {
      src <- if (hit$source == "ENTREZ") "HGNC_ENTREZ_MAPPED" else "HGNC_DIRECT"
      return(list(canonical_id      = paste0("HGNC:", hit$hgnc_int),
                  canonical_name    = hit$symbol,
                  resolution_source = src))
    }
    hit2 <- .try_hgnc_int(pref_clean, env = env)
    if (!is.null(hit2)) {
      src <- if (hit2$source == "ENTREZ") "HGNC_ENTREZ_MAPPED_FIELDSWAP" else "HGNC_FIELDSWAP"
      return(list(canonical_id      = paste0("HGNC:", hit2$hgnc_int),
                  canonical_name    = hit2$symbol,
                  resolution_source = src))
    }
    hit3 <- .hgnc_lookup_symbol(pref_v, env = env)
    if (!is.null(hit3)) {
      return(list(canonical_id      = paste0("HGNC:", hit3$hgnc_int),
                  canonical_name    = hit3$primary_symbol,
                  resolution_source = "STRING_ALIAS_HGNC"))
    }
  }

  # MeSH path
  if (id_db_norm == "MESH") {
    id_clean   <- .strip_db_prefix(id_v, "MESH:")
    pref_clean <- .strip_db_prefix(pref_v, "MESH:")

    if (.is_mesh_ui(id_clean)) {
      hit <- .mesh_lookup_ui(id_clean, env = env)
      if (!is.null(hit)) {
        return(list(canonical_id      = paste0("MeSH:", hit$ui),
                    canonical_name    = hit$mh,
                    resolution_source = "MESH_DIRECT"))
      }
    }
    if (.is_mesh_ui(pref_clean)) {
      hit2 <- .mesh_lookup_ui(pref_clean, env = env)
      if (!is.null(hit2)) {
        return(list(canonical_id      = paste0("MeSH:", hit2$ui),
                    canonical_name    = hit2$mh,
                    resolution_source = "MESH_FIELDSWAP"))
      }
    }
    hit3 <- .mesh_lookup_term(pref_v, env = env)
    if (!is.null(hit3)) {
      ui_full <- .mesh_lookup_ui(hit3$ui, env = env)
      cname <- if (!is.null(ui_full)) ui_full$mh else pref_v
      return(list(canonical_id      = paste0("MeSH:", hit3$ui),
                  canonical_name    = cname,
                  resolution_source = "STRING_ALIAS_MESH"))
    }
  }

  # Database NULL / non riconosciuto OR primary path fallito: alias discovery
  if (nzchar(pref_v)) {
    # ChEBI alias
    hit <- .chebi_lookup_alias(pref_v, env = env)
    if (!is.null(hit)) {
      hit_full <- .chebi_lookup_id(hit$chebi_id, env = env)
      cname <- if (!is.null(hit_full)) hit_full$primary_name else pref_v
      return(list(canonical_id      = paste0("CHEBI:", hit$chebi_id),
                  canonical_name    = cname,
                  resolution_source = "STRING_ALIAS_CHEBI"))
    }
    # HGNC symbol/alias
    hit2 <- .hgnc_lookup_symbol(pref_v, env = env)
    if (!is.null(hit2)) {
      return(list(canonical_id      = paste0("HGNC:", hit2$hgnc_int),
                  canonical_name    = hit2$primary_symbol,
                  resolution_source = "STRING_ALIAS_HGNC"))
    }
    # MeSH entry term
    hit3 <- .mesh_lookup_term(pref_v, env = env)
    if (!is.null(hit3)) {
      ui_full <- .mesh_lookup_ui(hit3$ui, env = env)
      cname <- if (!is.null(ui_full)) ui_full$mh else pref_v
      return(list(canonical_id      = paste0("MeSH:", hit3$ui),
                  canonical_name    = cname,
                  resolution_source = "STRING_ALIAS_MESH"))
    }
    # MeSH naked UI
    if (.is_mesh_ui(pref_v)) {
      hit4 <- .mesh_lookup_ui(pref_v, env = env)
      if (!is.null(hit4)) {
        return(list(canonical_id      = paste0("MeSH:", hit4$ui),
                    canonical_name    = hit4$mh,
                    resolution_source = "MESH_NAKED"))
      }
    }
  }

  # Hallucinated o non-risolvibile
  # - id_database set ma tutti i lookup failed --> HALLUCINATED_OR_FALLBACK
  # - id_database vuoto + preferred_name non-alias --> STRING_NO_ALIAS_MATCH
  if (nzchar(id_db_v)) {
    fall_str <- if (nzchar(pref_v)) tolower(pref_v)
                else if (nzchar(id_v)) tolower(id_v)
                else "unknown"
    return(list(canonical_id      = paste0("STR:", fall_str),
                canonical_name    = if (nzchar(pref_v)) pref_v else NA_character_,
                resolution_source = "HALLUCINATED_OR_FALLBACK"))
  }
  if (nzchar(pref_v)) {
    return(list(canonical_id      = paste0("STR:", tolower(pref_v)),
                canonical_name    = pref_v,
                resolution_source = "STRING_NO_ALIAS_MATCH"))
  }
  .canonical_noagent()
}
