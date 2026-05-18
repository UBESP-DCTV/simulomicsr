#' Convention canonica per control_type (baseline-roles)
#'
#' control_type values il cui ruolo "baseline / no-perturbation" e' chiaro:
#' il control_group e' assunto essere il baseline; il treated_group la perturbed.
#'
#' @keywords internal
.canonical_control_types <- c(
  "vehicle", "untreated", "genetic_negative", "inducer_off",
  "time_zero", "disease_normal"
)

#' control_type values che sono intrinsecamente ambigui sul role assignment
#' @keywords internal
.ambiguous_control_types <- c("secondary_arm")

#' kind_effective che indicano "baseline / no-perturbation"
#' @keywords internal
.baseline_kinds <- c("none", "vehicle_only", "unclear")

#' Determina se la direzione del pair (treated -> control) e' canonical
#'
#' Stage 3 NON flippa automaticamente: espone solo il flag. P5 al consumption
#' time, se \code{swapped}, moltiplica yi per -1.
#'
#' Regole:
#' \describe{
#'   \item{canonical}{control_type in .canonical_control_types AND treated_anchor
#'     ha kind_effective NON-baseline AND control_anchor ha kind_effective baseline.
#'     Speciale: control_type=disease_normal accetta \code{disease_vs_normal} in entrambi
#'     (override anchor function), e canonical e' assunta dal LLM.}
#'   \item{swapped}{control_type in .canonical_control_types AND ruoli sono invertiti
#'     (baseline nel treated, perturbed nel control).}
#'   \item{ambiguous}{control_type in .ambiguous_control_types (secondary_arm), oppure
#'     entrambi i kind sono baseline o entrambi non-baseline per un control_type canonico.}
#'   \item{indeterminate}{uno dei anchor ha tier S incomplete (kind=unclear OR
#'     agent_id=unknown) e impossibile valutare.}
#' }
#'
#' @param treated_anchor_segments named list con almeno \code{kind_effective} e
#'   \code{agent_id} (output di \code{.extract_anchor_segments()}).
#' @param control_anchor_segments named list con almeno \code{kind_effective} e
#'   \code{agent_id} (output di \code{.extract_anchor_segments()}).
#' @param control_type character(1): valore control_type dal comparison stage2.v2.
#' @return character(1): uno di "canonical", "swapped", "ambiguous", "indeterminate".
#' @keywords internal
.check_direction_canonical <- function(treated_anchor_segments,
                                       control_anchor_segments,
                                       control_type) {
  t_kind  <- treated_anchor_segments$kind_effective
  t_agent <- treated_anchor_segments$agent_id
  c_kind  <- control_anchor_segments$kind_effective
  c_agent <- control_anchor_segments$agent_id

  # Indeterminate: tier S incomplete -- impossibile valutare.
  # kind="unclear" e' sempre incomplete. agent_id="unknown" e' incomplete solo
  # quando kind non e' gia' un baseline determinato (none, vehicle_only):
  # per kind="none" l'agente assente e' atteso, non un segnale di incomplete.
  tier_s_missing <- function(kind, agent) {
    if (identical(kind, "unclear")) return(TRUE)
    if (identical(agent, "unknown") && !kind %in% c("none", "vehicle_only")) return(TRUE)
    FALSE
  }

  if (tier_s_missing(t_kind, t_agent) || tier_s_missing(c_kind, c_agent)) {
    return("indeterminate")
  }

  # Ambiguous: control_type intrinsecamente non-determinabile
  if (control_type %in% .ambiguous_control_types) {
    return("ambiguous")
  }

  # disease_normal: convention assume LLM ha gia' assegnato correttamente
  # (entrambi i kind sono "disease_vs_normal" per anchor override).
  if (identical(control_type, "disease_normal")) {
    return("canonical")
  }

  # Standard canonical/swapped check per tutti gli altri .canonical_control_types
  if (control_type %in% .canonical_control_types) {
    t_is_baseline <- t_kind %in% .baseline_kinds
    c_is_baseline <- c_kind %in% .baseline_kinds

    if (!t_is_baseline && c_is_baseline) return("canonical")
    if (t_is_baseline && !c_is_baseline) return("swapped")

    # Edge case: entrambi baseline o entrambi non-baseline
    # (es. control_type=untreated ma sia treated_group sia control_group
    # hanno una perturbazione attiva -- comparison di due trattamenti diversi)
    return("ambiguous")
  }

  # control_type non riconosciuto (non dovrebbe accadere se stage2 schema valida)
  "indeterminate"
}
