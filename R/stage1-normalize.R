# Guard deterministici sui fatti Stadio 1 (sample_facts.stage1.v3) applicati
# a valle dell'LLM, prima di costruire l'input Stadio 2.
#
# Motivazione (FASE F2 root-cause, 2026-05-28): l'LLM Stadio 1 puo' emettere
# `duration.is_zero_timepoint = TRUE` su sample privi di qualunque evidenza
# temporale (value_raw e value_hours nulli). E' uno stato semanticamente
# invalido — non esiste un "tempo zero" se non c'e' un tempo. A valle la
# REGOLA 2 di Stadio 2 ("time-zero = control") declassa quei sample a
# control/time_zero, corrompendo il design DE. Il guard riallinea il flag
# all'evidenza in modo deterministico e indipendente dal modello, cosi' il
# comportamento e' stabile rispetto a variazioni del prompt Stadio 1.

# Token testuali che indicano un tempo zero in `duration.value_raw` quando
# `value_hours` non e' disponibile. Costruito per matchare "0", "0h", "t0",
# "t=0", "time(hours): 0", "day 0", "d0", "baseline" e NON "24h", "10h",
# "30 min", "48 hours". Lo zero deve essere "puro" (eventuali decimali tutti
# zero) e non far parte di un numero maggiore (es. "10", "30").
.ZERO_TIMEPOINT_REGEX <- paste0(
  "(\\bbaseline\\b|",
  "(?:^|[^0-9.])0+(?:\\.0+)?(?![0-9.])\\s*",
  "(?:h|hr|hrs|hour|hours|min|mins|minute|minutes|d|day|days|w|week|weeks|s|sec|secs|second|seconds)?\\b)"
)

#' Verifica se una `duration` Stadio 1 porta evidenza di tempo zero
#'
#' `value_hours` numerico e' autoritativo (== 0). In sua assenza si ricade
#' su un match testuale di `value_raw` contro pattern di tempo zero noti.
#' Nessuna evidenza (entrambi nulli/vuoti) -> FALSE.
#'
#' @param duration list con `value_raw`, `value_hours`, `is_zero_timepoint`.
#' @return logical(1).
#' @keywords internal
.has_zero_timepoint_evidence <- function(duration) {
  if (is.null(duration) || !is.list(duration)) return(FALSE)
  vh <- duration$value_hours
  if (!is.null(vh) && length(vh) == 1L && is.numeric(vh) && !is.na(vh)) {
    return(vh == 0)
  }
  vr <- duration$value_raw
  if (is.null(vr) || length(vr) != 1L || is.na(vr)) return(FALSE)
  vr <- trimws(as.character(vr))
  if (!nzchar(vr)) return(FALSE)
  grepl(.ZERO_TIMEPOINT_REGEX, vr, ignore.case = TRUE, perl = TRUE)
}

#' Riallinea `is_zero_timepoint` di una `duration` all'evidenza
#'
#' @param duration list `duration` Stadio 1.
#' @return list(duration = corretta, changed = logical se il flag e' cambiato).
#' @keywords internal
.normalize_duration_zt <- function(duration) {
  if (is.null(duration) || !is.list(duration))
    return(list(duration = duration, changed = FALSE))
  cur  <- isTRUE(duration$is_zero_timepoint)
  evid <- .has_zero_timepoint_evidence(duration)
  duration$is_zero_timepoint <- evid
  list(duration = duration, changed = !identical(cur, evid))
}

#' Applica il guard is_zero_timepoint a tutti i `perturbations` di un sample
#'
#' @param facts list `sample_facts.stage1.v3` di un singolo GSM.
#' @return list(facts = normalizzati, n_corrected = n. flag corretti).
#' @keywords internal
normalize_stage1_facts_zt <- function(facts) {
  n <- 0L
  perts <- facts$perturbations
  if (!is.null(perts) && length(perts) > 0L) {
    for (i in seq_along(perts)) {
      d <- perts[[i]]$duration
      if (!is.null(d)) {
        res <- .normalize_duration_zt(d)
        perts[[i]]$duration <- res$duration
        if (isTRUE(res$changed)) n <- n + 1L
      }
    }
    facts$perturbations <- perts
  }
  list(facts = facts, n_corrected = n)
}
