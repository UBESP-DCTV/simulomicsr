#' Trova i baseline pool candidati per un pair cluster MEGA-AUG
#'
#' Per un dato pair cluster (con \code{anchor_key} composto
#' \code{<treated>__VS__<control>}), scandaglia i group baseline pool
#' al medesimo level e ritorna l'elenco di baseline candidati con anchor
#' compatibile, applicando il \code{matcher} fornito (strict o relaxed)
#' al lato (control e/o treated) richiesto dal \code{direction}.
#'
#' Il ranking dei candidati segue: prima i baseline che augmentano il braccio
#' \code{control} (convenzionale del MEGA-AUG monodirezionale legacy), poi
#' quelli del braccio \code{treated} (novita' bidirezionale). All'interno di
#' uno stesso arm, ordinamento decrescente per \code{n_studies} e tiebreak
#' per \code{n_total}. Il chiamante (orchestrator) tipicamente seleziona il
#' top per ogni arm; il rest e' diagnostica.
#'
#' @param pair_cluster tibble (o list) 1-riga con almeno \code{cluster_id},
#'   \code{level}, \code{anchor_key}.
#' @param group_clusters tibble dei group baseline pool (mode = "group")
#'   con almeno \code{cluster_id}, \code{level}, \code{anchor_key},
#'   \code{n_studies}, \code{n_total}.
#' @param matcher chiusura \code{function(parsed_a, parsed_b) -> logical(1)}
#'   prodotta da \code{make_anchor_matcher()}.
#' @param direction character(1): \code{"control"}, \code{"treated"} o
#'   \code{"both"}.
#' @param min_baseline_studies integer(1): scarta baseline con
#'   \code{n_studies < min_baseline_studies}. Default \code{2L}.
#' @return list di candidate (eventualmente vuota). Ogni elemento ha:
#'   \code{baseline_cluster_id}, \code{arm} ("control" o "treated"),
#'   \code{baseline_n_total}, \code{baseline_n_studies}.
#' @keywords internal
find_baseline_for_pair <- function(pair_cluster, group_clusters, matcher,
                                     direction = c("control", "treated", "both"),
                                     min_baseline_studies = 2L) {
  direction <- match.arg(direction)
  level <- pair_cluster$level[1L]

  parsed_pair <- parse_pair_anchor_key(pair_cluster$anchor_key[1L], level)

  # Pre-filtra group: stesso level + n_studies sufficient
  keep <- group_clusters$level == level &
    group_clusters$n_studies >= min_baseline_studies
  candidates <- group_clusters[keep, , drop = FALSE]
  if (nrow(candidates) == 0L) return(list())

  arms_to_check <- switch(
    direction,
    "control" = "control",
    "treated" = "treated",
    "both"    = c("control", "treated")
  )

  results <- list()
  for (arm in arms_to_check) {
    pair_side <- parsed_pair[[arm]]
    for (i in seq_len(nrow(candidates))) {
      gparsed <- tryCatch(
        parse_anchor_canonical(candidates$anchor_key[i], level = level),
        error = function(e) NULL
      )
      if (is.null(gparsed)) next
      if (!matcher(pair_side, gparsed)) next
      results[[length(results) + 1L]] <- list(
        baseline_cluster_id = candidates$cluster_id[i],
        arm                 = arm,
        baseline_n_total    = as.integer(candidates$n_total[i]),
        baseline_n_studies  = as.integer(candidates$n_studies[i])
      )
    }
  }

  if (length(results) == 0L) return(list())

  # Ordinamento: control prima di treated; n_studies desc; n_total desc.
  arm_key <- vapply(results, function(x) x$arm, character(1L))
  arm_rank <- match(arm_key, c("control", "treated"))  # control=1, treated=2
  ord <- order(
    arm_rank,
    -vapply(results, function(x) x$baseline_n_studies, integer(1L)),
    -vapply(results, function(x) x$baseline_n_total, integer(1L))
  )
  results[ord]
}
