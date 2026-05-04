#' Classifica uno studio con piu' modelli LLM e ritorna i risultati comparabili
#'
#' Wrapper su `classify_study()` che itera sui `model_specs` e ritorna una lista
#' nominata per `label`. Stage 1 fissato (sample_facts_list passato uguale a tutti).
#' La cache LLM esistente partiziona automaticamente per `(provider, model, messages)`,
#' quindi modelli diversi non si sovrascrivono.
#'
#' Gestione errori per-modello: se un modello solleva, il record diventa
#' `.invalid_reason='llm_call_failed'` (consistente con `classify_study()`).
#' I modelli che riescono restano disponibili nei loro slot.
#'
#' @param series_id GSE accession
#' @param sample_facts_list lista di sample_facts validati (stage1.v3)
#' @param study_summary list con title/summary/overall_design
#' @param model_specs lista di liste, ognuna con campi `provider`, `model`,
#'   `label` (slug univoco, usato come name di output), e opzionalmente
#'   `max_tokens`.
#' @param cache cache object (puo' essere NULL nei test mockati)
#' @param ... args extra passati a llm_call_structured (es. `.mock_response`)
#' @param .mock_adapter_factory (test only) funzione che riceve `label` e
#'   ritorna il `.mock_adapter` da iniettare per quel modello.
#'
#' @return list nominata per `label` (uno slot per modello), valore = output di
#'   `classify_study()` (study_design valido oppure invalid_record).
#'
#' @export
multi_classify_study <- function(series_id,
                                 sample_facts_list,
                                 study_summary,
                                 model_specs,
                                 cache,
                                 ...,
                                 .mock_adapter_factory = NULL) {
  stopifnot(is.list(model_specs), length(model_specs) >= 1L)

  out <- list()
  for (spec in model_specs) {
    stopifnot(all(c("provider", "model", "label") %in% names(spec)))

    extra_args <- list(...)
    if (!is.null(.mock_adapter_factory)) {
      extra_args$.mock_adapter <- .mock_adapter_factory(spec$label)
    }
    if (!is.null(spec$max_tokens)) {
      extra_args$max_tokens <- spec$max_tokens
    }

    out[[spec$label]] <- do.call(
      classify_study,
      c(
        list(
          series_id         = series_id,
          sample_facts_list = sample_facts_list,
          study_summary     = study_summary,
          provider          = spec$provider,
          model             = spec$model,
          cache             = cache
        ),
        extra_args
      )
    )
  }
  out
}
