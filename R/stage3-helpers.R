#' Filtra i cluster per mode e usability
#'
#' Helper convenienza per i consumer di Stage 3 verso P5.
#' Restituisce un subset di \code{s3$clusters} in base ai criteri
#' di modalita' (pair/group) e soglia di usabilita' (strict/relaxed).
#'
#' @param s3 oggetto \code{stage3_result} restituito da
#'   \code{\link{build_stage3_clusters}}.
#' @param mode Stringa. Uno tra \code{"any"} (default), \code{"pair"},
#'   \code{"group"}. Se \code{"any"}, nessun filtro sul campo \code{mode}.
#' @param usability Stringa. Uno tra \code{"any"} (default), \code{"strict"},
#'   \code{"relaxed"}. Se \code{"any"}, nessun filtro sui flag di usabilita'.
#'   Con \code{"strict"} o \code{"relaxed"}, il flag controllato dipende
#'   da \code{mode}:
#'   \itemize{
#'     \item \code{mode = "pair"}: controlla \code{usable_rem_strict} /
#'       \code{usable_rem_relaxed}.
#'     \item \code{mode = "group"}: controlla \code{usable_mega_strict} /
#'       \code{usable_mega_relaxed}.
#'     \item \code{mode = "any"}: accetta cluster usable in almeno uno dei
#'       due modi (REM oppure MEGA).
#'   }
#' @return Tibble subset di \code{s3$clusters}.
#' @export
filter_clusters <- function(s3,
                             mode      = c("any", "pair", "group"),
                             usability = c("any", "strict", "relaxed")) {
  stopifnot(inherits(s3, "stage3_result"))
  mode      <- match.arg(mode)
  usability <- match.arg(usability)

  result <- s3$clusters

  if (mode != "any") {
    result <- result[result$mode == mode, ]
  }

  if (usability != "any") {
    col_rem  <- sprintf("usable_rem_%s",  usability)
    col_mega <- sprintf("usable_mega_%s", usability)

    if (mode == "pair") {
      result <- result[.isTRUE_vec(result[[col_rem]]), ]
    } else if (mode == "group") {
      result <- result[.isTRUE_vec(result[[col_mega]]), ]
    } else {
      # mode = "any": usable in almeno uno dei due modi
      result <- result[.isTRUE_vec(result[[col_rem]]) |
                         .isTRUE_vec(result[[col_mega]]), ]
    }
  }

  result
}

#' Recupera i record assegnati a un cluster specifico
#'
#' @param s3 oggetto \code{stage3_result}.
#' @param cluster_id Stringa. L'identificatore del cluster.
#' @return Tibble subset di \code{s3$assignments} con le righe
#'   corrispondenti al \code{cluster_id} richiesto.
#' @export
cluster_records <- function(s3, cluster_id) {
  stopifnot(inherits(s3, "stage3_result"))
  s3$assignments[s3$assignments$cluster_id == cluster_id, ]
}
