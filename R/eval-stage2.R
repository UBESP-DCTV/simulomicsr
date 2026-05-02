#' Mappa design_role v3 (13 valori) al binary trtctr_predicted
#'
#' Implementa la tabella di mapping spec sec.6.2 estesa ai 13 valori
#' del vocabolario design_role. NA = sample escluso dal calcolo accuracy
#' (non un errore, e' una scelta esplicita).
#'
#' Estensione vs spec sec.6.2 originale:
#' - bystander -> NA (paracrine, non-direttamente perturbed)
#' - negative_inducer_control -> control (no-Dox arm di sistema inducibile)
#' - secondary_arm -> treated (trattamento alternativo)
#'
#' @param role character vector di design_role values
#' @return character vector con valori "treated", "control" o NA_character_
#' @export
design_role_to_binary <- function(role) {
  if (length(role) == 0L) return(character(0))
  unname(vapply(role, .design_role_to_binary_one, character(1)))
}

#' @noRd
.design_role_to_binary_one <- function(r) {
  if (is.na(r)) return(NA_character_)
  switch(
    r,
    perturbed = "treated",
    case = "treated",
    secondary_arm = "treated",
    vehicle_control = "control",
    untreated_control = "control",
    negative_genetic_control = "control",
    negative_inducer_control = "control",
    baseline_t0 = "control",
    comparison = "control",
    bystander = NA_character_,
    positive_control = NA_character_,
    excluded = NA_character_,
    unclear = NA_character_,
    rlang::abort(
      sprintf("design_role non riconosciuto: '%s'", r),
      class = "simulomicsr_invalid_design_role"
    )
  )
}

#' Calcola binary accuracy per un vettore di predicted vs gold
#'
#' Coppie con NA in gold OR predicted vengono escluse dal calcolo.
#' Sensitivity/specificity calcolate considerando "treated" come la classe
#' positiva, "control" come la classe negativa.
#'
#' @param gold character vector (treated/control/NA)
#' @param predicted character vector (treated/control/NA), stessa lunghezza
#' @return list con campi n, accuracy, sensitivity, specificity, f1,
#'   confusion_matrix
#' @export
eval_binary_accuracy <- function(gold, predicted) {
  stopifnot(length(gold) == length(predicted))
  keep <- !is.na(gold) & !is.na(predicted)
  g <- gold[keep]
  p <- predicted[keep]
  n <- length(g)
  if (n == 0L) {
    return(list(
      n = 0L, accuracy = NA_real_, sensitivity = NA_real_,
      specificity = NA_real_, f1 = NA_real_,
      confusion_matrix = .empty_confusion_matrix()
    ))
  }
  g_f <- factor(g, levels = c("control", "treated"))
  p_f <- factor(p, levels = c("control", "treated"))
  cm <- table(predicted = p_f, gold = g_f)

  tp <- cm["treated", "treated"]
  tn <- cm["control", "control"]
  fp <- cm["treated", "control"]
  fn <- cm["control", "treated"]
  accuracy <- (tp + tn) / n
  sensitivity <- if (tp + fn > 0) tp / (tp + fn) else NA_real_
  specificity <- if (tn + fp > 0) tn / (tn + fp) else NA_real_
  precision <- if (tp + fp > 0) tp / (tp + fp) else NA_real_
  f1 <- if (!is.na(precision) && !is.na(sensitivity) &&
            (precision + sensitivity) > 0) {
    2 * precision * sensitivity / (precision + sensitivity)
  } else NA_real_

  list(
    n = n, accuracy = accuracy,
    sensitivity = sensitivity, specificity = specificity, f1 = f1,
    confusion_matrix = cm
  )
}

#' @noRd
.empty_confusion_matrix <- function() {
  m <- matrix(0L, nrow = 2, ncol = 2,
              dimnames = list(predicted = c("control", "treated"),
                              gold = c("control", "treated")))
  as.table(m)
}

#' Breakdown binary accuracy per design_kind
#'
#' @param df tibble con colonne gold_binary, predicted_binary, design_kind
#' @return tibble con una riga per design_kind: design_kind, n, accuracy,
#'   sensitivity, specificity, f1
#' @export
eval_per_design_kind <- function(df) {
  stopifnot(all(c("gold_binary", "predicted_binary", "design_kind") %in% names(df)))
  kinds <- unique(df$design_kind)
  rows <- lapply(kinds, function(k) {
    sub <- df[df$design_kind == k, ]
    metrics <- eval_binary_accuracy(sub$gold_binary, sub$predicted_binary)
    tibble::tibble(
      design_kind = k,
      n = metrics$n,
      accuracy = metrics$accuracy,
      sensitivity = metrics$sensitivity,
      specificity = metrics$specificity,
      f1 = metrics$f1
    )
  })
  dplyr::bind_rows(rows)
}
