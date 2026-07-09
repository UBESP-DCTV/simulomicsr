# Kind biologici accettati come override nell'innesto recovery (passo b).
# Estende la correzione K2 (genetic_*) ai mistype biologici citochina/patogeno
# rilevati da recover_identity() (Task 10, biologici v6).
#' @keywords internal
.biological_override_kinds <- c("cytokine_stim", "pathogen_or_aggregate_exposure")

#' Estrae i 13 segmenti dell'anchor v3.1 come named list + tracking_meta attr
#'
#' Replica internamente la logica di \code{make_anchor()} ma restituisce un
#' named list con i 13 valori invece della stringa concatenata. Usato come
#' basis per costruire anchor a livelli L0..L4 droppando segmenti.
#'
#' **Anchor v3.1 (ADR-0018):** i segmenti \code{kind_effective} e \code{agent_id}
#' passano attraverso il resolver \code{resolve_agent_canonical()} +
#' \code{infer_kind_with_override()}; l'output canonicalizzato (es.
#' \code{CHEBI:17126} invece di \code{17126}, \code{vehicle_only} invece del LLM
#' \code{cytokine_stim} per Ethanol) viene usato per costruire l'anchor_key.
#' I valori LLM-original sono preservati in \code{attr(result, "tracking_meta")}
#' per audit paper-grade.
#'
#' **Recupero identita' (Task 9 + Fix-I1, rework Stadio 3):** se \code{recovery}
#' e' non-NULL (record prodotto da \code{build_name_recovery_lookup()} per il GSM
#' rappresentante), la funzione applica DOPO il calcolo ordinario due correzioni:
#' (a) se \code{segs$agent_id == "UNK"} oppure e' un ID debole \code{"STR:<slug>"}
#' E il recovery porta un ID forte (\code{"HGNC:"}, \code{"CHEBI:"},
#' \code{"NCBITaxon:"}, \code{"CHEMBL:"}), sostituisce \code{agent_id} +
#' \code{canonical_name} (Fix-I1: riduce frammentazione \code{STR:lps} vs
#' \code{CHEBI:16412} per la stessa entita'); (b) se \code{recovery$kind} inizia
#' con \code{"genetic_"} e differisce dal \code{kind_effective} calcolato,
#' corregge il segmento (correzione K2).
#' I tre campi di traccia \code{recovery_source}, \code{agent_id_recovered},
#' \code{kind_recovered} vengono aggiunti al \code{tracking_meta} SOLO quando
#' \code{recovery} e' non-NULL, per garantire retrocompatibilita' stretta.
#'
#' L'ordine dei nomi e' canonical e identico all'output di \code{make_anchor()}:
#' kind_effective, agent_id, variant_label, dose_canonical, duration_canonical,
#' phase_canonical, cell_id, context_kind, cell_state, subcellular, tissue,
#' disease_status, has_engineered.
#'
#' @param stage1_facts list (un sample_fact validato stage1.v3)
#' @param stage2_role character: design_role assegnato dallo Stadio 2 al sample
#'   (es. "treated", "case", "comparison"). Influenza disease_vs_normal override.
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#'   Default = lazy-load dalla cache; passare un env esplicito (es. caricato da
#'   fixture) per test deterministici.
#' @param recovery list o NULL: record di recupero identita' per il GSM
#'   rappresentante, con campi \code{agent_id}, \code{canonical_name},
#'   \code{kind}, \code{recovery_source}. Default NULL = comportamento attuale
#'   (nessuna correzione, tracking_meta a 12 campi). Se non-NULL, tracking_meta
#'   viene esteso con 3 campi aggiuntivi: \code{recovery_source},
#'   \code{agent_id_recovered} (logical), \code{kind_recovered} (logical).
#' @return named list di 13 elementi carattere con attribute \code{tracking_meta}
#'   contenente 12 campi quando \code{recovery = NULL} (default), oppure 15 campi
#'   quando \code{recovery} e' non-NULL (12 standard + 3 recovery-trace).
#'   Campi standard: agent_id_llm_original, agent_id_resolved,
#'   resolution_source, canonical_name, kind_effective_llm_original,
#'   kind_effective_resolved, kind_overridden, kind_override_reason,
#'   kind_role_evidence, kind_confidence, kind_unvalidatable, kind_chebi_zero_roles.
#' @keywords internal
.extract_anchor_segments <- function(stage1_facts, stage2_role,
                                     ontology_env = NULL, recovery = NULL) {
  if (is.null(ontology_env)) ontology_env <- .load_ontology_dicts()

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
    kind_effective_llm <- "disease_vs_normal"
    mesh_raw           <- stage1_facts$disease_state$mesh_id_candidate %||% "unknown"
    variant_label      <- "wt"

    # Canonicalizza il MeSH ID se valido D\d{6}; altrimenti STR fallback
    if (.is_mesh_ui(mesh_raw)) {
      hit <- .mesh_lookup_ui(mesh_raw, env = ontology_env)
      agent_id          <- paste0("MeSH:", mesh_raw)
      if (!is.null(hit)) {
        resolution_source <- "MESH_DIRECT"
        canonical_name    <- hit$mh
      } else {
        # Pattern valido ma assente nella release MeSH corrente -> preserva ma
        # marca come hallucinated/missing per audit.
        resolution_source <- "MESH_NAKED_NOLOOKUP"
        canonical_name    <- NA_character_
      }
    } else if (.nzchar_safe(mesh_raw) && !identical(mesh_raw, "unknown")) {
      agent_id          <- paste0("STR:", tolower(mesh_raw))
      resolution_source <- "DISEASE_NO_MESH_UI"
      canonical_name    <- NA_character_
    } else {
      agent_id          <- "UNK"
      resolution_source <- "NO_AGENT"
      canonical_name    <- NA_character_
    }

    # v3.1.1 (S1bis 2026-05-25, audit case Pregnanetriol): applica override
    # se MeSH UI risolto + tree_top != C/F (cioe' onto infers non-disease
    # kind). Rule DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY in infer_kind_with_override.
    # Pre-S1bis: kind sempre preserved = disease_vs_normal (design assertion).
    # Post-S1bis: MeSH tree D (chemicals/sterols) smentisce disease_vs_normal LLM.
    if (.is_mesh_ui(mesh_raw) && identical(resolution_source, "MESH_DIRECT")) {
      ovr <- infer_kind_with_override(agent_id, kind_effective_llm,
                                       env = ontology_env)
      kind_effective        <- ovr$kind_resolved
      kind_overridden       <- ovr$kind_overridden
      kind_override_reason  <- ovr$override_reason
      kind_role_evidence    <- ovr$role_evidence
      kind_confidence       <- ovr$confidence
      kind_unvalidatable    <- ovr$kind_unvalidatable
      kind_chebi_zero_roles <- isTRUE(ovr$kind_chebi_zero_roles)
    } else {
      # No MeSH UI risolto: preserve LLM design assertion (backward-compat).
      kind_effective        <- kind_effective_llm
      kind_overridden       <- FALSE
      kind_override_reason  <- NA_character_
      kind_role_evidence    <- NA_character_
      kind_confidence       <- "STRONG"
      kind_unvalidatable    <- FALSE
      kind_chebi_zero_roles <- FALSE
    }
    agent_id_raw         <- mesh_raw

  } else if (!is.null(pert$mediated_effect) && length(pert$mediated_effect) > 0L) {
    # R8: il Tet-On/AID inducente cede il passo al target biologico
    kind_effective_llm <- .map_kind_to_anchor(pert$mediated_effect$kind %||% pert$kind %||% "unclear")
    target_name        <- if (length(pert$mediated_effect$targets) > 0L)
                            pert$mediated_effect$targets[[1L]]
                          else
                            "unknown"
    agent_id_raw       <- paste0("HGNC:", target_name)
    variant_label      <- .resolve_variant_label(stage1_facts$cell_context$engineered_modifications)

    # Canonicalizza target via HGNC symbol/alias lookup
    synth_agent <- list(
      id_database    = "HGNC",
      id             = "",
      preferred_name = target_name,
      type           = "mediated_target"
    )
    ar <- resolve_agent_canonical(synth_agent, env = ontology_env)
    if (identical(ar$resolution_source, "HALLUCINATED_OR_FALLBACK") ||
        identical(ar$resolution_source, "NO_AGENT")) {
      # Target sconosciuto a HGNC: NON e' un gene canonico -> forma STR:
      # (stessa classe del fix I2; un HGNC:<sigla> fabbricato inquina l'identita').
      agent_id          <- paste0("STR:", target_name)
      resolution_source <- "MEDIATED_STR_NO_LOOKUP"
      canonical_name    <- target_name
    } else {
      agent_id          <- ar$canonical_id
      resolution_source <- ar$resolution_source
      canonical_name    <- ar$canonical_name
    }

    # Override kind via ontology (per gene HGNC la confidence e' NONE, quindi LLM
    # preservato + kind_unvalidatable=TRUE). E' corretto: non si infera kind
    # da gene HGNC alone.
    ovr <- infer_kind_with_override(agent_id, kind_effective_llm,
                                    env = ontology_env)
    kind_effective        <- ovr$kind_resolved
    kind_overridden       <- ovr$kind_overridden
    kind_override_reason  <- ovr$override_reason
    kind_role_evidence    <- ovr$role_evidence
    kind_confidence       <- ovr$confidence
    kind_unvalidatable    <- ovr$kind_unvalidatable
    kind_chebi_zero_roles <- isTRUE(ovr$kind_chebi_zero_roles)

  } else {
    kind_effective_llm <- .map_kind_to_anchor(pert$kind %||% "unclear")
    agent_id_raw       <- .resolve_agent_id(pert$agent_normalized)
    variant_label      <- .resolve_variant_label(stage1_facts$cell_context$engineered_modifications)

    # Resolver downstream: canonicalize via ChEBI/HGNC/MeSH
    ar <- resolve_agent_canonical(pert$agent_normalized, env = ontology_env)
    agent_id          <- ar$canonical_id
    resolution_source <- ar$resolution_source
    canonical_name    <- ar$canonical_name

    # Override kind via ontology evidence
    ovr <- infer_kind_with_override(agent_id, kind_effective_llm,
                                    env = ontology_env)
    kind_effective        <- ovr$kind_resolved
    kind_overridden       <- ovr$kind_overridden
    kind_override_reason  <- ovr$override_reason
    kind_role_evidence    <- ovr$role_evidence
    kind_confidence       <- ovr$confidence
    kind_unvalidatable    <- ovr$kind_unvalidatable
    kind_chebi_zero_roles <- isTRUE(ovr$kind_chebi_zero_roles)
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
  segs <- list(
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

  # Tracking metadata (anchor v3.1, ADR-0018): paper-grade audit columns,
  # propagate downstream a .summarize_clusters() che le converte in 7 cluster
  # columns + 4 di diagnostica (canonical_name, kind_role_evidence,
  # kind_confidence, kind_unvalidatable).
  attr(segs, "tracking_meta") <- list(
    agent_id_llm_original       = agent_id_raw,
    agent_id_resolved           = agent_id,
    resolution_source           = resolution_source,
    canonical_name              = canonical_name,
    kind_effective_llm_original = kind_effective_llm,
    kind_effective_resolved     = kind_effective,
    kind_overridden             = kind_overridden,
    kind_override_reason        = kind_override_reason,
    kind_role_evidence          = kind_role_evidence,
    kind_confidence             = kind_confidence,
    kind_unvalidatable          = kind_unvalidatable,
    # v3.1.1 (S1bis): 12a tracking column propagata downstream
    kind_chebi_zero_roles       = kind_chebi_zero_roles
  )

  # --- Innesto recovery lookup (Task 9, rework Stadio 3) -------------------
  # Applicato DOPO il calcolo ordinario; attivo SOLO quando `recovery` non-NULL.
  # Con recovery = NULL (default) l'output e' byte-identico al comportamento
  # pre-Task9 (retrocompatibilita' stretta: tracking_meta rimane a 12 campi).
  if (!is.null(recovery)) {
    agent_id_recovered <- FALSE
    kind_recovered     <- FALSE

    # (a) Correggi agent_id in due situazioni (Fix-I1):
    # - e' UNK (retrocompat): accetta qualsiasi recovery$agent_id non-NA.
    # - e' un ID debole "STR:<slug>" E il recovery porta un ID forte
    #   (prefisso "HGNC:", "CHEBI:", "NCBITaxon:", "CHEMBL:"): sostituisce per
    #   ridurre la frammentazione "STR:lps" vs "CHEBI:16412" per la stessa entita'.
    # Gli ID forti gia' presenti (MeSH:, CHEBI:, HGNC:, ecc.) NON vengono
    # toccati: l'ontology override ordinario e' gia' piu' affidabile del recovery.
    if (!is.null(recovery$agent_id) && !is.na(recovery$agent_id)) {
      recovery_is_strong <- grepl("^(HGNC|CHEBI|NCBITaxon|CHEMBL):",
                                  recovery$agent_id, perl = TRUE)
      adopt <- identical(segs$agent_id, "UNK") ||
               (startsWith(segs$agent_id, "STR:") && recovery_is_strong)
      if (adopt) {
        segs$agent_id <- recovery$agent_id
        tm <- attr(segs, "tracking_meta")
        tm$agent_id_resolved <- recovery$agent_id
        tm$canonical_name    <- recovery$canonical_name
        attr(segs, "tracking_meta") <- tm
        agent_id_recovered <- TRUE
      }
    }

    # (b) Correggi kind_effective per correzioni genetiche (K2) e biologiche:
    # - K2 genetic_*: recovery$kind inizia con "genetic_" (caso preesistente)
    # - biologici (Task 10, biologici v6): recovery$kind in .biological_override_kinds
    #   (cytokine_stim, pathogen_or_aggregate_exposure) -- mistype K3 rilevato
    #   da recover_identity()
    # Guard !is.na(recovery$kind): startsWith(NA_character_, "genetic_") -> NA,
    # e if(...&& NA) genera "Error: missing value where TRUE/FALSE needed".
    # recover_identity() puo' restituire kind = NA_character_ (llm_kind assente).
    if (!is.null(recovery$kind) && !is.na(recovery$kind) &&
        (startsWith(recovery$kind, "genetic_") ||
           recovery$kind %in% .biological_override_kinds) &&
        !identical(recovery$kind, segs$kind_effective)) {
      segs$kind_effective <- recovery$kind
      tm <- attr(segs, "tracking_meta")
      tm$kind_effective_resolved <- recovery$kind
      attr(segs, "tracking_meta") <- tm
      kind_recovered <- TRUE
    }

    # Aggiungi 3 campi di traccia (solo quando recovery e' non-NULL)
    tm <- attr(segs, "tracking_meta")
    tm$recovery_source     <- recovery$recovery_source
    tm$agent_id_recovered  <- agent_id_recovered
    tm$kind_recovered      <- kind_recovered
    attr(segs, "tracking_meta") <- tm
  }

  segs
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
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#'   Forwardato a \code{.extract_anchor_segments()}.
#' @return character(1) chiave concatenata con "|"
#' @keywords internal
.build_anchor_for_level <- function(stage1_facts, stage2_role, level,
                                    tier_assignment, ontology_env = NULL) {
  stopifnot(level %in% 0L:4L)

  segs <- .extract_anchor_segments(stage1_facts, stage2_role,
                                   ontology_env = ontology_env)

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
