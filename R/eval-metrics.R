#' Metriche di base dello Stadio 1 sul dev set
#'
#' Tutte le funzioni accettano una lista di `sample_fact` (oggetti R parsed
#' dal JSON) e ritornano una lista flat di numeri/conteggi adatta a essere
#' impacchettata in tibble per il report.

#' Rate di sample_facts che superano la validazione schema
#'
#' @param facts_validated lista di sample_fact validati
#' @param facts_invalid lista di sample_fact invalidati (post catch in
#'   `classify_sample_row`)
#' @return list(n_validated, n_invalid, n_total, validity_rate)
#' @keywords internal
stage1_schema_validity_rate <- function(facts_validated, facts_invalid) {
  n_v <- length(facts_validated)
  n_i <- length(facts_invalid)
  n_t <- n_v + n_i
  if (n_t == 0L) {
    rlang::abort(
      "Eval metrics su zero sample: dev set vuoto.",
      class = "simulomicsr_eval_metrics_empty"
    )
  }
  list(
    n_validated   = as.integer(n_v),
    n_invalid     = as.integer(n_i),
    n_total       = as.integer(n_t),
    validity_rate = n_v / n_t
  )
}

#' Recall di campi chiave nei sample_fact validati
#'
#' - "with_perturbation" = `perturbations[1].kind` non in \{none, unclear, NA\}
#' - "with_cell_type"    = `cell_context.cell_type_or_line_raw` non NULL
#'
#' @param facts_validated lista di sample_fact validati
#' @return list(n_samples, n_with_perturbation, n_with_cell_type,
#'   recall_perturbation, recall_cell_type)
#' @keywords internal
stage1_recall_key_fields <- function(facts_validated) {
  n <- length(facts_validated)
  if (n == 0L) {
    return(list(
      n_samples = 0L, n_with_perturbation = 0L, n_with_cell_type = 0L,
      recall_perturbation = NA_real_, recall_cell_type = NA_real_
    ))
  }

  has_perturbation <- vapply(facts_validated, function(f) {
    p <- f$perturbations
    if (length(p) == 0L) return(FALSE)
    k <- p[[1]]$kind
    !is.null(k) && !(k %in% c("none", "unclear"))
  }, logical(1))

  has_cell_type <- vapply(facts_validated, function(f) {
    ct <- f$cell_context$cell_type_or_line_raw
    !is.null(ct) && nzchar(ct)
  }, logical(1))

  list(
    n_samples            = as.integer(n),
    n_with_perturbation  = as.integer(sum(has_perturbation)),
    n_with_cell_type     = as.integer(sum(has_cell_type)),
    recall_perturbation  = mean(has_perturbation),
    recall_cell_type     = mean(has_cell_type)
  )
}
