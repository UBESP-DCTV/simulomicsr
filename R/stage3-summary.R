#' Costruisce la tabella record_summary con min_viable_level per mode
#'
#' Per ogni (record_id, mode), trova il livello L piu' basso
#' dove il record appartiene a un cluster con `usable_{mode}_relaxed=TRUE`.
#' Se nessun L qualifica, restituisce "NONE" e NA cluster.
#'
#' @param assignments tibble (record_id, mode, level, cluster_id)
#' @param clusters tibble con almeno (cluster_id, mode, level,
#'   usable_rem_relaxed, usable_mega_relaxed)
#' @return tibble (record_id, mode, min_viable_level_rem, min_viable_cluster_rem,
#'   min_viable_level_mega, min_viable_cluster_mega,
#'   in_n_clusters_rem, in_n_clusters_mega)
#' @keywords internal
.build_record_summary <- function(assignments, clusters) {
  # Lookup di usable flags per cluster_id (named vector)
  usable_rem  <- setNames(clusters$usable_rem_relaxed,  clusters$cluster_id)
  usable_mega <- setNames(clusters$usable_mega_relaxed, clusters$cluster_id)

  # Aggiungi le colonne usable a assignments tramite lookup
  joined <- assignments
  joined$usable_rem_relaxed  <- usable_rem[joined$cluster_id]
  joined$usable_mega_relaxed <- usable_mega[joined$cluster_id]

  # Suddividi per (record_id, mode) — chiave composta
  joined$.group_key <- paste(joined$record_id, joined$mode, sep = "::")
  parts <- split(joined, joined$.group_key)

  rows <- lapply(parts, function(sub) {
    rec_id   <- sub$record_id[1]
    mode     <- sub$mode[1]
    is_pair  <- identical(mode, "pair")
    is_group <- identical(mode, "group")

    # Colonne REM (solo mode == "pair")
    if (is_pair) {
      usable_rows <- sub[.isTRUE_vec(sub$usable_rem_relaxed), ]
      if (nrow(usable_rows) == 0L) {
        mvl_rem <- "NONE"
        mvc_rem <- NA_character_
      } else {
        min_L   <- min(usable_rows$level)
        mvl_rem <- sprintf("L%d", min_L)
        mvc_rem <- usable_rows$cluster_id[usable_rows$level == min_L][1L]
      }
      in_n_rem <- length(unique(sub$cluster_id))
    } else {
      mvl_rem  <- NA_character_
      mvc_rem  <- NA_character_
      in_n_rem <- 0L
    }

    # Colonne MEGA (solo mode == "group")
    if (is_group) {
      usable_rows <- sub[.isTRUE_vec(sub$usable_mega_relaxed), ]
      if (nrow(usable_rows) == 0L) {
        mvl_mega <- "NONE"
        mvc_mega <- NA_character_
      } else {
        min_L    <- min(usable_rows$level)
        mvl_mega <- sprintf("L%d", min_L)
        mvc_mega <- usable_rows$cluster_id[usable_rows$level == min_L][1L]
      }
      in_n_mega <- length(unique(sub$cluster_id))
    } else {
      mvl_mega  <- NA_character_
      mvc_mega  <- NA_character_
      in_n_mega <- 0L
    }

    tibble::tibble(
      record_id               = rec_id,
      mode                    = mode,
      min_viable_level_rem    = mvl_rem,
      min_viable_cluster_rem  = mvc_rem,
      min_viable_level_mega   = mvl_mega,
      min_viable_cluster_mega = mvc_mega,
      in_n_clusters_rem       = in_n_rem,
      in_n_clusters_mega      = in_n_mega
    )
  })

  do.call(rbind, rows)
}

#' Versione vettorizzata di isTRUE che gestisce NA in modo sicuro
#'
#' @param x vettore logico (puo' contenere NA)
#' @return vettore logical(length(x)) con TRUE solo dove x e' esattamente TRUE
#' @keywords internal
.isTRUE_vec <- function(x) vapply(x, isTRUE, logical(1L))
