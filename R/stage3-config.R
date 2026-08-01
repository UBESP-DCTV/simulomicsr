#' Default configuration per Stadio 3 raggruppamento cross-studio
#'
#' Restituisce la configurazione di default che governa Stage 3: tier assignment
#' dei 13 segmenti dell'anchor v3 (vedi \code{make_anchor()}), thresholds per
#' quality flags (REM k_min/recommended/gold + MEGA n_studies/n_total + safety
#' strict/relaxed), versioning schema per riproducibilita'.
#'
#' Tier system (drop order D -> A; S sempre presente; hard_filters mai droppabili):
#'
#' \describe{
#'   \item{S (inviolabile)}{kind_effective, agent_id, tissue}
#'   \item{A (system identity)}{variant_label, disease_status, phase_canonical}
#'   \item{B (modulators)}{cell_state, cell_id}
#'   \item{C (continuous)}{dose_canonical, duration_canonical}
#'   \item{D (low-info)}{has_engineered}
#'   \item{hard_filters (partition)}{subcellular, context_kind}
#' }
#'
#' @return list con 3 componenti: \code{tier_assignment}, \code{thresholds},
#'   \code{schema_versions}.
#' @seealso \code{\link{build_stage3_clusters}}, ADR-0014.
#' @export
stage3_default_config <- function() {
  list(
    tier_assignment = list(
      S = c("kind_effective", "agent_id", "tissue"),
      A = c("variant_label", "disease_status", "phase_canonical"),
      B = c("cell_state", "cell_id"),
      C = c("dose_canonical", "duration_canonical"),
      D = c("has_engineered"),
      hard_filters = c("subcellular", "context_kind")
    ),
    thresholds = list(
      rem = list(
        k_min         = 2L,
        k_recommended = 3L,
        k_gold        = 10L
      ),
      mega = list(
        n_studies_min         = 2L,
        n_studies_recommended = 5L,
        n_studies_gold        = 10L,
        n_total_recommended   = 30L
      ),
      safety = list(
        strict  = 0.7,
        relaxed = 0.5
      )
    ),
    schema_versions = list(
      anchor             = "v3.1.1",
      stage3_algorithm   = "v1",
      sample_facts       = "stage1.v3",
      study_design       = "stage2.v2",
      resolver           = "v1.1.0",
      # De-frammentazione dell'entita' del contrasto (R/stage3-defrag-alias.R,
      # 2026-08-01). AGGIUNTA perche' senza di essa `run_metadata.json` NON
      # distingue un run con la regola da uno senza: il diff fra i metadati di
      # v13 e v14 mostrava solo il timestamp e tre conteggi, benche' v14 avesse
      # introdotto la regola. Un run non riproducibile dai suoi metadati non e'
      # un run documentato.
      contrast_defrag    = "v2",
      # FASE E0 ADR-0019 D9: strategia di dedupe cross-studio costante per
      # design (relation BioSample SAMN unique). Loggata una sola volta in
      # run_metadata invece che come colonna ridondante per-cluster.
      dedupe_strategy    = "biosample_samn_unique"
    )
  )
}

#' Restituisce i segmenti droppati a un livello L
#'
#' Helper interno: dato il tier_assignment e il livello L (0..4), restituisce
#' i segmenti che vengono RIMOSSI dall'anchor a quel livello. L0 = empty (nessun
#' drop). L4 = drop(D + C + B + A). I tier S e hard_filters NON sono mai
#' nell'output.
#'
#' @keywords internal
.dropped_segments_at_level <- function(tier_assignment, level) {
  stopifnot(level %in% 0L:4L)
  drop_tiers <- switch(
    as.character(level),
    "0" = character(),
    "1" = "D",
    "2" = c("D", "C"),
    "3" = c("D", "C", "B"),
    "4" = c("D", "C", "B", "A")
  )
  unlist(tier_assignment[drop_tiers], use.names = FALSE)
}

#' Restituisce i segmenti mantenuti nell'anchor a un livello L (S + tier-residui)
#'
#' Non include hard_filters (quelli sono partition esterna, non parte dell'anchor
#' key). @keywords internal
#'
#' @keywords internal
.kept_segments_at_level <- function(tier_assignment, level) {
  dropped <- .dropped_segments_at_level(tier_assignment, level)
  all_droppable <- unlist(tier_assignment[c("S", "A", "B", "C", "D")],
                          use.names = FALSE)
  setdiff(all_droppable, dropped)
}
