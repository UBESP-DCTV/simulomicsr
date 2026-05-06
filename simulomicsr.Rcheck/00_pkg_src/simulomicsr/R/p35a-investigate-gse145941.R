#' Re-classify uno studio con prompt verbose-reasoning
#'
#' Chiama classify_study() con un'istruzione aggiuntiva (extra_instruction)
#' che chiede esplicitamente al modello di esplicitare la chain-of-thought
#' per (a) assegnazione GSM -> replicate_group, (b) identificazione control/
#' treatment arm, (c) inferenza design_kind. Il reasoning risultante e' inserito
#' nel campo .reasoning del design object.
#'
#' Usato per investigation GSE145941 (P3.5-A sec. 5).
#'
#' @param series_id GSE accession
#' @param sample_facts_list list di sample_facts validati per il GSE
#' @param study_summary list ritornato da fetch_study_summary()
#' @param cache cache_init() per Stadio 2 (se NULL nessuna cache)
#' @param provider passato a classify_study() (default "openai")
#' @param model passato a classify_study() (default "gpt-5.5")
#' @return design object con campo aggiuntivo .reasoning
#' @export
reclassify_verbose <- function(series_id, sample_facts_list, study_summary,
                                cache = NULL,
                                provider = "openai", model = "gpt-5.5") {
  extra <- paste(
    "ISTRUZIONE INVESTIGATION: oltre all output JSON canonico,",
    "popola il campo opzionale .reasoning con una chain-of-thought",
    "esplicita che spieghi (1) come hai assegnato GSM ai replicate_groups,",
    "(2) come hai identificato il control vs treatment arm,",
    "(3) come hai inferito il design_kind. Massimo 300 parole.",
    sep = " "
  )
  classify_study(
    series_id = series_id,
    sample_facts_list = sample_facts_list,
    study_summary = study_summary,
    provider = provider,
    model = model,
    cache = cache,
    extra_instruction = extra
  )
}

#' Tabella side-by-side gold xlsx vs simulomicsr P3 vs reclassify verbose
#'
#' @param verbose_design design object da reclassify_verbose()
#' @param gold_xlsx tibble con colonne geo_accession, series_id, string,
#'   gold_binary (treated/control/NA)
#' @param original_design design object dal run P3 originale
#' @return tibble con colonne geo_accession, gold_binary,
#'   simulomicsr_p3_role, simulomicsr_reclassify_role,
#'   p3_predicted_binary, reclassify_predicted_binary, agreement
#' @export
compare_with_gold <- function(verbose_design, gold_xlsx, original_design) {
  flatten_design <- function(d) {
    rows <- list()
    for (g in d$replicate_groups %||% list()) {
      role <- g$design_role
      for (sid in (g$sample_ids %||% list())) {
        rows[[length(rows) + 1L]] <- tibble::tibble(
          geo_accession = as.character(sid),
          design_role = role
        )
      }
    }
    if (length(rows) == 0L) {
      return(tibble::tibble(geo_accession = character(0),
                            design_role = character(0)))
    }
    dplyr::bind_rows(rows)
  }
  p3 <- flatten_design(original_design) |>
    dplyr::rename(simulomicsr_p3_role = "design_role")
  rev <- flatten_design(verbose_design) |>
    dplyr::rename(simulomicsr_reclassify_role = "design_role")
  out <- gold_xlsx |>
    dplyr::select("geo_accession", "gold_binary") |>
    dplyr::left_join(p3, by = "geo_accession") |>
    dplyr::left_join(rev, by = "geo_accession") |>
    dplyr::mutate(
      p3_predicted_binary = design_role_to_binary(.data$simulomicsr_p3_role),
      reclassify_predicted_binary = design_role_to_binary(.data$simulomicsr_reclassify_role),
      agreement = !is.na(.data$gold_binary) &
                  !is.na(.data$reclassify_predicted_binary) &
                  .data$gold_binary == .data$reclassify_predicted_binary
    )
  tibble::as_tibble(out)
}
