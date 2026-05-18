#' Estrae i 13 segmenti dell'anchor v3 come named list
#'
#' Replica internamente la logica di \code{make_anchor()} ma restituisce un
#' named list con i 13 valori invece della stringa concatenata. Usato come
#' basis per costruire anchor a livelli L0..L4 droppando segmenti.
#'
#' L'ordine dei nomi e' canonical e identico all'output di \code{make_anchor()}:
#' kind_effective, agent_id, variant_label, dose_canonical, duration_canonical,
#' phase_canonical, cell_id, context_kind, cell_state, subcellular, tissue,
#' disease_status, has_engineered.
#'
#' @param stage1_facts list (un sample_fact validato stage1.v3)
#' @param stage2_role character: design_role assegnato dallo Stadio 2 al sample
#'   (es. "treated", "case", "comparison"). Influenza disease_vs_normal override.
#' @return named list di 13 elementi carattere
#' @keywords internal
.extract_anchor_segments <- function(stage1_facts, stage2_role) {
  # Riusa le funzioni helper esistenti da R/anchors.R
  pert <- .select_primary_perturbation(stage1_facts$perturbations, stage2_role)

  # Stessa logica di make_anchor(): verifica perturbazione attiva e design disease
  has_active_perturbation <- length(stage1_facts$perturbations) > 0L &&
    !is.null(pert$kind) &&
    !identical(pert$kind, "none") &&
    !identical(pert$kind, "vehicle_only") &&
    !identical(pert$kind, "unclear")

  is_disease_design <- stage2_role %in% c("case", "comparison") ||
    (isTRUE(stage1_facts$disease_state$status %in%
              c("case", "comparison", "disease_model")) &&
       !has_active_perturbation)

  if (is_disease_design) {
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
    variant_label  <- .resolve_variant_label(stage1_facts$cell_context$engineered_modifications)
  } else {
    kind_effective <- .map_kind_to_anchor(pert$kind %||% "unclear")
    agent_id       <- .resolve_agent_id(pert$agent_normalized)
    variant_label  <- .resolve_variant_label(stage1_facts$cell_context$engineered_modifications)
  }

  dose_canonical     <- .normalize_dose(pert$dose$value_raw %||% NULL)
  duration_canonical <- .normalize_duration(pert$duration$value_raw %||% NULL)
  phase_canonical    <- pert$phase %||% "exposure"

  cell_id      <- .normalize_cell_id(
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

  disease_status <- .resolve_disease_status(stage1_facts$disease_state, stage2_role)
  has_engineered <- tolower(as.character(
    length(stage1_facts$cell_context$engineered_modifications) > 0L
  ))

  # Ordine canonical identico a make_anchor() (13 segmenti)
  list(
    kind_effective     = kind_effective,
    agent_id           = agent_id,
    variant_label      = variant_label,
    dose_canonical     = dose_canonical,
    duration_canonical = duration_canonical,
    phase_canonical    = phase_canonical,
    cell_id            = cell_id,
    context_kind       = context_kind,
    cell_state         = cell_state,
    subcellular        = subcellular,
    tissue             = tissue,
    disease_status     = disease_status,
    has_engineered     = has_engineered
  )
}

#' Costruisce l'anchor a un dato livello L (droppando segmenti per tier)
#'
#' L0 = tutti 13 segmenti (equivalente di \code{make_anchor()}). L1..L4
#' progressivamente droppano tier D, C, B, A (vedi \code{.dropped_segments_at_level()}).
#' A L4 vengono mantenuti esclusivamente i segmenti Tier S (kind_effective,
#' agent_id, tissue): hard_filters e tier A/B/C/D sono tutti esclusi.
#'
#' L'ordine dei segmenti nell'output segue l'ordine canonical dell'anchor v3
#' (identico a \code{make_anchor()}) per garantire determinismo del cluster key.
#'
#' @param stage1_facts list (un sample_fact validato stage1.v3)
#' @param stage2_role character: design_role assegnato dallo Stadio 2
#' @param level integer(1): livello 0..4. L0 = completo, L4 = solo Tier S.
#' @param tier_assignment list: componente \code{tier_assignment} della config
#'   restituita da \code{stage3_default_config()}.
#' @return character(1) chiave concatenata con "|"
#' @keywords internal
.build_anchor_for_level <- function(stage1_facts, stage2_role, level, tier_assignment) {
  stopifnot(level %in% 0L:4L)

  segs <- .extract_anchor_segments(stage1_facts, stage2_role)

  if (level == 4L) {
    # L4: solo Tier S -- hard_filters e tier A/B/C/D esclusi.
    # Usa names(segs) %in% per preservare l'ordine canonical di segs
    # indipendentemente dall'ordine in cui tier_assignment$S e' definito in config.
    kept_names <- names(segs)[names(segs) %in% tier_assignment$S]
  } else {
    # L0-L3: tutti i 13 segmenti (inclusi hard_filters subcellular+context_kind) meno
    # quelli droppati per livello. I hard_filters restano nell'anchor key fino a L3
    # incluso; vengono esclusi solo a L4 dove l'anchor si riduce al solo Tier S.
    dropped <- .dropped_segments_at_level(tier_assignment, level)
    # Mantieni l'ordine canonical (names(segs)) sottraendo i droppati
    kept_names <- names(segs)[!names(segs) %in% dropped]
  }

  values <- vapply(kept_names, function(s) as.character(segs[[s]]), character(1L))
  paste(values, collapse = "|")
}

#' Estrae i 2 hard filters (subcellular + context_kind) come named list
#'
#' Restituisce un sottoinsieme del named list di \code{.extract_anchor_segments()}
#' limitato ai campi \code{hard_filters} definiti nel \code{tier_assignment}.
#' Usato per la partition primaria dei record in \code{.partition_by_hard_filters()}.
#' I hard filters non sono mai droppabili a nessun livello L.
#'
#' @param stage1_facts list (un sample_fact validato stage1.v3)
#' @param tier_assignment list: componente \code{tier_assignment} della config
#'   restituita da \code{stage3_default_config()}.
#' @return named list con elementi \code{subcellular} e \code{context_kind}
#' @keywords internal
.extract_hard_filters <- function(stage1_facts, tier_assignment) {
  # FIX perf: i hard filters (subcellular + context_kind) sono SOLO 2 campi.
  # Implementazione precedente chiamava .extract_anchor_segments() (heavy:
  # estrae tutti i 13 segmenti) per poi sottoselezionare 2: spreco ~10x.
  # Qui accesso diretto ai 2 campi rilevanti (logica identica a quella di
  # .extract_anchor_segments per quei due campi).
  context_kind <- stage1_facts$cell_context$context_kind %||% "unclear"
  subcellular  <- if (!is.null(stage1_facts$cell_context$subcellular_fraction) &&
                       length(stage1_facts$cell_context$subcellular_fraction) > 0L)
                    stage1_facts$cell_context$subcellular_fraction$kind %||% "whole_cell"
                  else
                    "whole_cell"
  list(
    subcellular  = subcellular,
    context_kind = context_kind
  )
}
