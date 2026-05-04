#' Calcola pairwise agreement tra modelli su un singolo studio
#'
#' Per ogni coppia di modelli, confronta:
#' - `design_kind` (match esatto: 1/0)
#' - `design_role` per ogni sample condiviso (rate: frazione di sample con
#'   stesso design_role assegnato dai due modelli)
#' - `comparability_anchor` per comparison (rate: frazione di anchor in comune
#'   sul totale unione)
#'
#' Studi con `.invalid_reason` (LLM error / schema fail) vengono saltati: la
#' coppia che li include non produce nessuna riga.
#'
#' @param study_designs_per_model lista nominata per modello, ogni elemento
#'   e' un study_design valido stage2.v1 oppure un invalid_record.
#'
#' @return tibble con colonne pair, design_kind_match, design_role_match_rate,
#'   anchor_match_rate (una riga per coppia di modelli valida).
#'
#' @export
compute_pairwise_agreement <- function(study_designs_per_model) {
  labels <- names(study_designs_per_model)
  if (length(labels) < 2L) return(.empty_pairwise_agreement())

  pairs <- utils::combn(labels, 2L, simplify = FALSE)
  rows <- lapply(pairs, function(p) {
    a <- study_designs_per_model[[p[1]]]
    b <- study_designs_per_model[[p[2]]]
    if (.is_invalid_design(a) || .is_invalid_design(b)) return(NULL)

    tibble::tibble(
      pair                   = paste(p, collapse = "__"),
      design_kind_match      = as.integer(identical(a$design_kind, b$design_kind)),
      design_role_match_rate = .role_match_rate(a, b),
      anchor_match_rate      = .anchor_match_rate(a, b)
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) return(.empty_pairwise_agreement())
  dplyr::bind_rows(rows)
}

#' @noRd
.is_invalid_design <- function(d) {
  isTRUE(!is.null(d$.invalid_reason))
}

#' @noRd
.empty_pairwise_agreement <- function() {
  tibble::tibble(
    pair                   = character(),
    design_kind_match      = integer(),
    design_role_match_rate = double(),
    anchor_match_rate      = double()
  )
}

#' @noRd
.role_per_sample <- function(design) {
  out <- list()
  for (g in design$replicate_groups %||% list()) {
    role <- g$design_role
    for (sid in g$sample_ids %||% list()) {
      out[[as.character(sid)]] <- role
    }
  }
  out
}

#' @noRd
.role_match_rate <- function(a, b) {
  ra <- .role_per_sample(a)
  rb <- .role_per_sample(b)
  shared <- intersect(names(ra), names(rb))
  if (length(shared) == 0L) return(NA_real_)
  match_count <- sum(vapply(shared, function(s) identical(ra[[s]], rb[[s]]),
                            logical(1)))
  match_count / length(shared)
}

#' @noRd
.anchor_match_rate <- function(a, b) {
  anchors_a <- vapply(a$comparisons %||% list(),
                      function(c) as.character(c$comparability_anchor %||% NA),
                      character(1))
  anchors_b <- vapply(b$comparisons %||% list(),
                      function(c) as.character(c$comparability_anchor %||% NA),
                      character(1))
  if (length(anchors_a) == 0L && length(anchors_b) == 0L) return(1)
  union_n <- length(union(anchors_a, anchors_b))
  inter_n <- length(intersect(anchors_a, anchors_b))
  if (union_n == 0L) return(NA_real_)
  inter_n / union_n
}

#' Aggrega pairwise agreement in un singolo confidence score
#'
#' Per ogni coppia: pair_score = 0.3*design_kind + 0.5*role_rate + 0.2*anchor_rate.
#' Valori NA in role/anchor_rate ricevono peso effettivo 0.
#' Score finale = media dei pair_score sulle coppie disponibili.
#'
#' @param pairwise_agreements tibble da `compute_pairwise_agreement()`
#' @return numeric scalar in \[0, 1\], oppure NA_real_ se 0 coppie valide
#' @export
aggregate_confidence_score <- function(pairwise_agreements) {
  if (nrow(pairwise_agreements) == 0L) return(NA_real_)
  role <- pairwise_agreements$design_role_match_rate
  anch <- pairwise_agreements$anchor_match_rate
  role[is.na(role)] <- 0
  anch[is.na(anch)] <- 0
  pair_scores <- 0.3 * pairwise_agreements$design_kind_match +
                 0.5 * role +
                 0.2 * anch
  mean(pair_scores)
}

#' Assegna tier di difficolta' a un confidence score
#'
#' Soglie preliminari (spec sec.6.1): easy ge 0.85, medium 0.6-0.85, hard lt 0.6.
#'
#' @param score numeric in \[0, 1\]
#' @return character: "easy", "medium" o "hard"
#' @export
assign_difficulty_tier <- function(score) {
  if (is.na(score)) return(NA_character_)
  if (score >= 0.85) return("easy")
  if (score >= 0.6)  return("medium")
  "hard"
}
