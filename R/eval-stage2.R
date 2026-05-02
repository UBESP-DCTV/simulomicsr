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
