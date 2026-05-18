#' Calcola i 4 boolean use-flags per un cluster
#'
#' Sostituiscono i tier labels GOLD/SILVER/BRONZE/DESCRIPTIVE con flag funzionali
#' espliciti: l'intent del consumer (REM o MEGA) e' codificato direttamente.
#'
#' Logica:
#' - \code{usable_rem_strict}:   mode=pair AND level in \{0,1\} AND k>=k_recommended_rem
#'                          AND safety_min>=safety_strict
#' - \code{usable_rem_relaxed}:  mode=pair AND k>=k_min_rem AND safety_min>=safety_relaxed
#' - \code{usable_mega_strict}:  mode=group AND level in \{0,1\} AND n_studies>=n_studies_recommended_mega
#'                          AND n_total>=n_total_recommended_mega AND safety_min>=safety_strict
#' - \code{usable_mega_relaxed}: mode=group AND n_studies>=n_studies_min_mega
#'                          AND n_total>=10 AND safety_min>=safety_relaxed
#'
#' @param cluster_row lista con campi: \code{mode}, \code{level}, \code{k},
#'   \code{n_total}, \code{n_studies}, \code{safety_min}.
#' @param thresholds lista \code{thresholds} estratta da \code{stage3_default_config()},
#'   con sotto-liste \code{rem}, \code{mega}, \code{safety}.
#'
#' @return lista con 4 elementi logical: \code{usable_rem_strict},
#'   \code{usable_rem_relaxed}, \code{usable_mega_strict}, \code{usable_mega_relaxed}.
#'
#' @keywords internal
.tag_cluster_usability <- function(cluster_row, thresholds) {
  mode <- cluster_row$mode

  rem_t  <- thresholds$rem
  mega_t <- thresholds$mega
  saf_t  <- thresholds$safety

  is_pair  <- identical(mode, "pair")
  is_group <- identical(mode, "group")

  list(
    usable_rem_strict = is_pair &&
      cluster_row$level %in% c(0L, 1L) &&
      cluster_row$k >= rem_t$k_recommended &&
      cluster_row$safety_min >= saf_t$strict,

    usable_rem_relaxed = is_pair &&
      cluster_row$k >= rem_t$k_min &&
      cluster_row$safety_min >= saf_t$relaxed,

    usable_mega_strict = is_group &&
      cluster_row$level %in% c(0L, 1L) &&
      cluster_row$n_studies >= mega_t$n_studies_recommended &&
      cluster_row$n_total >= mega_t$n_total_recommended &&
      cluster_row$safety_min >= saf_t$strict,

    usable_mega_relaxed = is_group &&
      cluster_row$n_studies >= mega_t$n_studies_min &&
      cluster_row$n_total >= 10L &&
      cluster_row$safety_min >= saf_t$relaxed
  )
}
