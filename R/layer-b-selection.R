#' Carica selection Layer B (interno)
#'
#' Polimorfico: accetta path-to-CSV (character) o data.frame already-loaded.
#' Valida schema + duplicati + tipi.
#'
#' @param selection character path-to-CSV o data.frame.
#' @return tibble con `cluster_id, label_paper, priority, notes`.
#' @keywords internal
.load_layer_b_selection <- function(selection) {
  if (is.character(selection)) {
    if (!file.exists(selection)) {
      cli::cli_abort("Selection CSV not found: {.path {selection}}")
    }
    sel <- readr::read_csv(
      selection,
      col_types = readr::cols(
        cluster_id  = readr::col_character(),
        label_paper = readr::col_character(),
        priority    = readr::col_integer(),
        notes       = readr::col_character()
      ),
      comment = "#",
      progress = FALSE
    )
  } else if (is.data.frame(selection)) {
    sel <- tibble::as_tibble(selection)
  } else {
    cli::cli_abort(
      "selection must be a character path or data.frame, got {.cls {class(selection)[1]}}"
    )
  }

  required <- c("cluster_id", "label_paper", "priority", "notes")
  missing_cols <- setdiff(required, names(sel))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "Selection is missing required column(s): {.field {missing_cols}}"
    )
  }

  # Coerce priority a integer se letto come double
  sel$priority <- as.integer(sel$priority)
  # Sostituisce NA notes con stringa vuota
  sel$notes[is.na(sel$notes)] <- ""

  if (anyDuplicated(sel$cluster_id) > 0L) {
    dups <- unique(sel$cluster_id[duplicated(sel$cluster_id)])
    cli::cli_abort(
      "Selection has duplicate cluster_id: {.field {dups}}"
    )
  }

  sel[, required]
}

#' Valida selection Layer B contro Layer A output (pre-check pubblico)
#'
#' Verifica che ogni `cluster_id` esista in `cluster_pooled.parquet` di Layer A
#' (fail-fast su typo o drift Stage 4 re-run). Restituisce tibble arricchita
#' con `exists_in_stage4`, `method`, `k_effective`, `n_sig_FDR05` per ogni
#' cluster --- usabile come smoke check pre-batch da R interactive.
#'
#' @param selection character path-to-CSV o data.frame (passato a [.load_layer_b_selection]).
#' @param stage4_dir character path al dir output di Layer A (contiene `cluster_pooled.parquet`).
#' @param fdr_threshold numeric soglia per `n_sig_FDR05` (default 0.05).
#'
#' @return tibble con `cluster_id, label_paper, priority, notes,
#'   exists_in_stage4, method, k_effective, n_sig_FDR05`.
#' @export
#' @examples
#' \dontrun{
#' val <- layer_b_validate_selection(
#'   "analysis/layer-b-selection.csv",
#'   "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
#' )
#' print(val)
#' }
layer_b_validate_selection <- function(selection, stage4_dir, fdr_threshold = 0.05) {
  sel <- .load_layer_b_selection(selection)

  cp_path <- file.path(stage4_dir, "cluster_pooled.parquet")
  if (!file.exists(cp_path)) {
    cli::cli_abort(
      "cluster_pooled.parquet not found in stage4_dir: {.path {cp_path}}"
    )
  }

  cp <- arrow::open_dataset(cp_path)
  cluster_ids <- sel$cluster_id

  # Estrae subset (small: solo i cluster_ids selezionati)
  cp_subset <- cp |>
    dplyr::filter(cluster_id %in% cluster_ids) |>
    dplyr::collect()

  present <- unique(cp_subset$cluster_id)
  missing <- setdiff(cluster_ids, present)
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Selected cluster_id not found in stage4 output: {.field {missing}}",
      "i" = "Re-browse the Layer A dashboard or check for stage4 re-run drift."
    ))
  }

  # Aggregazione statistiche per cluster
  agg <- cp_subset |>
    dplyr::group_by(cluster_id) |>
    dplyr::summarise(
      method = dplyr::first(method),
      k_effective = as.integer(dplyr::first(k_effective)),
      n_sig_FDR05 = sum(FDR_BH_within_cluster < fdr_threshold, na.rm = TRUE),
      .groups = "drop"
    )

  result <- dplyr::left_join(sel, agg, by = "cluster_id")
  result$exists_in_stage4 <- TRUE

  # Riordina colonne
  result[, c("cluster_id", "label_paper", "priority", "notes",
             "exists_in_stage4", "method", "k_effective", "n_sig_FDR05")]
}
