#' Mappa primary_role v5 (5 valori) al binary trtctr_predicted
#'
#' v5 vocabolario semplificato (vs v3 con 13 valori): il primary_role del
#' replicate_group e' uno tra 5 valori (treated/control/bystander/excluded/unclear).
#' Il mapping al binary e' 1:1 banale. La specificita' del controllo (vehicle,
#' untreated, genetic_negative, inducer_off, disease_normal, time_zero,
#' secondary_arm) NON e' piu' sul sample ma sul comparison (control_type).
#'
#' Comportamento: bystander/excluded/unclear -> NA (sample escluso da
#' calcolo accuracy, scelta esplicita).
#'
#' Backward compatibility v3 (per riconversione mini-gold v3 -> v5 e per
#' eval su artefatti vecchi): i 13 valori v3 vengono mappati al binary
#' come prima, cosi' i numeri restano confrontabili.
#'
#' @param role character vector di primary_role values (v5) o design_role v3
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
    # v5 (5 valori canonici)
    treated = "treated",
    control = "control",
    bystander = NA_character_,
    excluded = NA_character_,
    unclear = NA_character_,
    # v3 backward-compat (13 valori; usati per eval di artefatti pre-v5)
    perturbed = "treated",
    case = "treated",
    secondary_arm = "treated",
    vehicle_control = "control",
    untreated_control = "control",
    negative_genetic_control = "control",
    negative_inducer_control = "control",
    baseline_t0 = "control",
    comparison = "control",
    positive_control = NA_character_,
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

# Vocabolario design_role che e' "piu' granulare del binary":
# il binary mapping non perde solo informazione (treated/control), ma il
# design_role originale dice qualcosa che il gold non distingue.
.GRANULAR_DESIGN_ROLES <- c(
  "negative_inducer_control",
  "baseline_t0",
  "secondary_arm",
  "bystander"
)

#' Enumera i sample dove simulomicsr ha prodotto un design_role piu'
#' granulare del binary gold xlsx
#'
#' Sample con design_role in negative_inducer_control / baseline_t0 /
#' secondary_arm / bystander forniscono informazione che il binary gold
#' non puo' rappresentare. Questi NON sono errori — sono valore aggiunto.
#'
#' @param df tibble con colonne geo_accession, series_id, design_role,
#'   gold_binary, predicted_binary
#' @return tibble con righe filtrate ai casi granulari, piu' colonna
#'   `granularity_kind` (= design_role)
#' @export
flag_granularity_disagreement <- function(df) {
  stopifnot(all(c("geo_accession", "series_id", "design_role",
                  "gold_binary", "predicted_binary") %in% names(df)))
  out <- df[df$design_role %in% .GRANULAR_DESIGN_ROLES, ]
  out$granularity_kind <- out$design_role
  out
}
