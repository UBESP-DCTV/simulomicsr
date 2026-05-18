# stage3-cluster.R — Partizionamento hard-filter e assegnazione cluster
#
# Funzioni interne per:
#   - partizionare record per filtri hard (subcellular x context_kind)
#   - assegnare cluster_id deterministico basato su anchor_key via xxhash32

#' Partiziona records per hard_filters (subcellular, context_kind)
#'
#' Sub-partizioni sono mutually exclusive: records con
#' (subcellular="nuclear", context_kind="cell_line") non mergeano mai con
#' (subcellular="whole_cell", context_kind="cell_line") a nessun livello L.
#'
#' @param records list of records, ognuno con \code{$hard_filters} contenente
#'   \code{subcellular} e \code{context_kind}.
#' @return named list: ogni elemento e' una sub-partizione (list of records),
#'   con nome formato \code{"<subcellular>|<context_kind>"}.
#' @keywords internal
.partition_by_hard_filters <- function(records) {
  if (length(records) == 0L) return(list())
  keys <- vapply(records, function(r) {
    hf <- r$hard_filters
    sprintf("%s|%s", hf$subcellular %||% "NA", hf$context_kind %||% "NA")
  }, character(1L))
  split(records, keys)
}

#' Calcola cluster_id deterministico via xxhash32
#'
#' Formato: \code{<mode>_L<level>_<8hex>} dove 8hex sono i primi 8 caratteri
#' di \code{digest::digest(anchor_key, "xxhash32")}.
#'
#' @param anchor_key stringa chiave dell'anchor canonico.
#' @param mode stringa, es. "pair" o "group".
#' @param level intero 0..4 (livello di aggregazione).
#' @return stringa cluster_id.
#' @keywords internal
.cluster_id_for_anchor <- function(anchor_key, mode, level) {
  hash8 <- substr(digest::digest(anchor_key, algo = "xxhash32"), 1L, 8L)
  sprintf("%s_L%d_%s", mode, level, hash8)
}

#' Assegna records a cluster basato su anchor_key
#'
#' Records con stesso \code{anchor_key} finiscono nello stesso cluster.
#' Output e' una tibble long-format con colonne
#' \code{(record_id, mode, level, cluster_id, anchor_key)}.
#'
#' @param records list of records, ognuno con \code{$record_id} e
#'   \code{$anchor_key}.
#' @param mode stringa "pair" o "group".
#' @param level intero 0..4.
#' @return tibble di assignments.
#' @keywords internal
.assign_records_to_clusters <- function(records, mode, level) {
  if (length(records) == 0L) {
    return(tibble::tibble(
      record_id  = character(),
      mode       = character(),
      level      = integer(),
      cluster_id = character(),
      anchor_key = character()
    ))
  }

  record_ids  <- vapply(records, function(r) r$record_id,  character(1L))
  anchor_keys <- vapply(records, function(r) r$anchor_key, character(1L))

  # Mappa anchor_key univoca -> cluster_id (deterministica via hash)
  unique_keys <- unique(anchor_keys)
  key_to_clid <- setNames(
    vapply(unique_keys, .cluster_id_for_anchor, character(1L),
           mode = mode, level = level),
    unique_keys
  )

  tibble::tibble(
    record_id  = record_ids,
    mode       = mode,
    level      = level,
    cluster_id = unname(key_to_clid[anchor_keys]),
    anchor_key = anchor_keys
  )
}
