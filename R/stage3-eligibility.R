#' Verifica se un anchor segments ha Tier S completo
#'
#' Tier S = kind_effective, agent_id, tissue. Se uno qualunque e' "unclear",
#' "unknown" o "na", il record non puo' essere clusterizzato a nessun L.
#'
#' @keywords internal
.has_complete_tier_s <- function(anchor_segments) {
  k <- anchor_segments$kind_effective
  a <- anchor_segments$agent_id
  t <- anchor_segments$tissue

  !(is.null(k) || identical(k, "unclear") || identical(k, "unknown") || is.na(k)) &&
    !(is.null(a) || identical(a, "unknown") || identical(a, "unclear") || is.na(a)) &&
    !(is.null(t) || identical(t, "na") || identical(t, "unknown") ||
        identical(t, "unclear") || is.na(t))
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
