#' Verifica se un anchor segments ha Tier S completo
#'
#' Tier S = kind_effective, agent_id, tissue. Se uno qualunque e' "unclear",
#' "unknown" o "na", il record non puo' essere clusterizzato a nessun L.
#'
#' Nota: agent_id="unknown" e' accettabile quando kind_effective e' un baseline
#' (none, vehicle_only): per definizione i baseline records non hanno agente.
#' Coerente con .check_direction_canonical::tier_s_missing (stage3-direction.R).
#'
#' @keywords internal
.has_complete_tier_s <- function(anchor_segments) {
  kind_val   <- anchor_segments$kind_effective
  agent_val  <- anchor_segments$agent_id
  tissue_val <- anchor_segments$tissue

  # kind_effective deve essere risolto (non unclear / null / NA).
  # Nota: "none" e "vehicle_only" sono kind validi (rappresentano baselines
  # legitimi per group mode + control_group di pair mode).
  kind_ok <- !is.null(kind_val) && !is.na(kind_val) &&
    !identical(kind_val, "unclear")

  # agent_id: "unknown" e' accettabile SOLO quando kind e' un baseline
  # (none, vehicle_only): per definizione baseline records non hanno agent.
  # Coerente con .check_direction_canonical::tier_s_missing (stage3-direction.R).
  baseline_kinds <- c("none", "vehicle_only")
  agent_ok <- !is.null(agent_val) && !is.na(agent_val) &&
    !identical(agent_val, "unclear") &&
    (!identical(agent_val, "unknown") || isTRUE(kind_val %in% baseline_kinds))

  # tissue: deve essere risolto. "na" e "unknown" sono sentinel di mancato resolve.
  tissue_ok <- !is.null(tissue_val) && !is.na(tissue_val) &&
    !identical(tissue_val, "na") &&
    !identical(tissue_val, "unknown") &&
    !identical(tissue_val, "unclear")

  kind_ok && agent_ok && tissue_ok
}

#' Filtra records eligible per Stage 3 clustering
#'
#' Per ogni record applica:
#' 1. Tier S incomplete check (treated AND control anchors per mode=pair;
#'    treated per mode=group).
#' 2. REM eligibility (mode=pair only): n_per_group >= 2 per entrambi i gruppi.
#'
#' Direction check NON e' qui (richiede tutti gli anchor segments + control_type;
#' fatto in fase di cluster assembly per Stage 3).
#'
#' @param records list di record (output di stage2 normalized + sample_facts joined)
#' @return list(eligible = list_of_records, non_clusterable = list_of_dropped)
#' @keywords internal
.filter_eligible_records <- function(records) {
  eligible <- list()
  non_clusterable <- list()

  for (rec in records) {
    mode <- rec$mode

    # 1. Tier S complete check
    t_complete <- .has_complete_tier_s(rec$treated_anchor_segments)
    c_complete <- if (identical(mode, "pair"))
                    .has_complete_tier_s(rec$control_anchor_segments)
                  else TRUE

    if (!t_complete || !c_complete) {
      details_parts <- character()
      if (!t_complete) details_parts <- c(details_parts, "treated_anchor_segments")
      if (!c_complete) details_parts <- c(details_parts, "control_anchor_segments")
      non_clusterable[[length(non_clusterable) + 1L]] <- list(
        record_id = rec$record_id,
        mode      = mode,
        reason    = "tier_s_incomplete",
        details   = paste0("incomplete: ", paste(details_parts, collapse = ","))
      )
      next
    }

    # 2. REM eligibility (mode=pair only)
    if (identical(mode, "pair")) {
      if (isTRUE(rec$n_treated_group < 2L)) {
        non_clusterable[[length(non_clusterable) + 1L]] <- list(
          record_id = rec$record_id,
          mode      = mode,
          reason    = "rem_eligibility_n1",
          details   = sprintf("n_treated_group=%d (< 2)", rec$n_treated_group)
        )
        next
      }
      if (isTRUE(rec$n_control_group < 2L)) {
        non_clusterable[[length(non_clusterable) + 1L]] <- list(
          record_id = rec$record_id,
          mode      = mode,
          reason    = "rem_eligibility_n1",
          details   = sprintf("n_control_group=%d (< 2)", rec$n_control_group)
        )
        next
      }
    }

    eligible[[length(eligible) + 1L]] <- rec
  }

  list(eligible = eligible, non_clusterable = non_clusterable)
}
