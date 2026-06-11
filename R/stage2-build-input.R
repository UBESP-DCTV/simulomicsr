# Costruzione dell'input Stadio 2 v3 a condizioni deduplicate (ADR-0020, opzione C).
#
# Raggruppa i campioni di uno studio per design_signature in condizioni di
# disegno distinte, ciascuna con un rappresentante deterministico, il numero di
# repliche e la lista dei campioni membri. Sostituisce il chunking per-campione
# (cs50) che frammentava il disegno (finding 2026-06-01).

#' Raggruppa i campioni di uno studio in condizioni di disegno distinte
#'
#' Ogni campione e' ridotto alla sua \code{\link{design_signature}}; i campioni
#' con la stessa firma sono repliche della stessa condizione. Per ogni condizione
#' si emette: \code{condition_id} stabile (rank della firma ordinata),
#' \code{geo_accession} del rappresentante (GSM minimo alfabetico),
#' \code{sample_facts} del rappresentante, \code{n_replicates} e
#' \code{member_sample_ids} (ordinati). L'ordine delle condizioni e'
#' deterministico (per firma), indipendente dall'ordine dei campioni in input.
#'
#' @param samples Lista di campioni di UNO studio; ciascuno una lista con
#'   \code{geo_accession} e \code{sample_facts} (schema stage1.v3).
#' @return Lista di condizioni (vedi sopra). Lista vuota se nessun campione.
#' @keywords internal
.build_study_conditions <- function(samples) {
  if (length(samples) == 0L) return(list())

  geos <- vapply(samples, function(s) as.character(s$geo_accession)[[1]],
                 character(1))
  sigs <- vapply(samples, function(s) design_signature(s$sample_facts),
                 character(1))

  usig <- sort(unique(sigs))
  width <- max(4L, nchar(length(usig)))

  lapply(seq_along(usig), function(i) {
    sg <- usig[[i]]
    idx <- which(sigs == sg)
    members <- sort(geos[idx])
    rep_geo <- members[[1]]
    rep_sample <- samples[[ idx[which(geos[idx] == rep_geo)[1]] ]]
    facts <- rep_sample$sample_facts
    list(
      condition_id = sprintf("cond_%0*d", width, i),
      geo_accession = rep_geo,
      sample_facts = facts,
      n_replicates = length(idx),
      member_sample_ids = as.list(members),
      signature = sg,
      n_char = nchar(jsonlite::toJSON(facts, auto_unbox = TRUE, null = "null"))
    )
  })
}

#' Stabilisce se una condizione e' un controllo/baseline (broadcast nel chunking)
#'
#' Una condizione e' di controllo se il rappresentante porta evidenza di
#' controllo: una perturbazione \code{is_negative_control}, oppure di kind
#' \code{vehicle_only}/\code{none}, oppure a timepoint zero; oppure assenza di
#' perturbazioni reali con \code{disease_state$status} in \{none, comparison\};
#' oppure \code{disease_state$status == "comparison"} (braccio sano/di confronto).
#' Set generoso: meglio ripetere un controllo in piu' che perdere un confronto.
#' @keywords internal
.is_control_condition <- function(condition) {
  facts <- condition$sample_facts
  perts <- facts$perturbations
  has_real_pert <- FALSE
  for (p in perts) {
    if (isTRUE(p$is_negative_control)) return(TRUE)
    if (isTRUE(p$duration$is_zero_timepoint)) return(TRUE)
    k <- .norm_scalar(p$kind)
    if (k %in% c("vehicle_only", "none")) return(TRUE)
    if (nzchar(k) && !(k %in% c("none", "unclear"))) has_real_pert <- TRUE
  }
  status <- .norm_scalar(facts$disease_state$status)
  if (identical(status, "comparison")) return(TRUE)
  if (!has_real_pert && status %in% c("none", "comparison")) return(TRUE)
  FALSE
}

#' Divide le condizioni di uno studio in chunk entro un budget di caratteri
#'
#' Per gli studi entro budget restituisce un singolo chunk con tutte le
#' condizioni (no-op). Oltre budget, partiziona le condizioni non-controllo in
#' chunk e RIPETE (broadcast) le condizioni di controllo in ogni chunk, cosi' i
#' confronti trattato-vs-controllo si formano entro ogni chunk. Senza controlli,
#' partizione semplice senza ripetizioni. Best-effort sui giganti: se i controlli
#' da soli superano il budget, ricade su partizione semplice (warning).
#'
#' @param conditions Lista di condizioni (vedi \code{\link{.build_study_conditions}});
#'   ciascuna deve avere \code{n_char}.
#' @param budget_chars Tetto di caratteri per chunk (somma \code{n_char}).
#' @param broadcast_max_frac Frazione massima del budget che i controlli possono
#'   occupare per essere broadcastati. Oltre questa soglia, ripetere i controlli
#'   in ogni chunk consumerebbe troppo budget (esplosione di chunk), quindi si
#'   ricade su partizione semplice (no broadcast). Default 0.3.
#' @param max_treated_per_chunk Tetto sul numero di condizioni TRATTATE
#'   (non-controllo) per chunk, in aggiunta al budget caratteri. Il budget limita
#'   l'INPUT del chunk; l'output LLM (numero di confronti) scala col numero di
#'   trattati per chunk, quindi questo tetto bounda direttamente l'output ed e'
#'   broadcast-safe (i controlli non contano contro il tetto, restano in ogni
#'   chunk). Default \code{Inf} (nessun tetto, comportamento storico). Vince il
#'   vincolo piu' stretto fra budget e tetto.
#' @return Lista di chunk; ciascun chunk e' una lista di condizioni.
#' @keywords internal
.chunk_conditions <- function(conditions, budget_chars, broadcast_max_frac = 0.3,
                              max_treated_per_chunk = Inf) {
  sizes <- vapply(conditions, function(c) as.numeric(c$n_char), numeric(1))

  is_ctrl <- vapply(conditions, .is_control_condition, logical(1))
  controls <- conditions[is_ctrl]
  treated  <- conditions[!is_ctrl]
  ctrl_size <- sum(sizes[is_ctrl])

  # broadcast non praticabile: controlli oltre la frazione del budget ->
  # ripeterli esploderebbe il numero di chunk -> partizione semplice (tutte le
  # condizioni diventano "trattate" e il tetto si applica a tutte).
  if (ctrl_size > budget_chars * broadcast_max_frac) {
    controls <- list(); treated <- conditions; ctrl_size <- 0
  }

  # no-op: tutto entro budget E entro il tetto trattati -> un solo chunk.
  if (sum(sizes) <= budget_chars && length(treated) <= max_treated_per_chunk)
    return(list(conditions))

  chunks <- list()
  cur <- list(); cur_size <- 0
  for (i in seq_along(treated)) {
    sz <- as.numeric(treated[[i]]$n_char)
    if (length(cur) > 0 &&
        ((ctrl_size + cur_size + sz) > budget_chars ||
         length(cur) >= max_treated_per_chunk)) {
      chunks[[length(chunks) + 1L]] <- c(controls, cur)
      cur <- list(); cur_size <- 0
    }
    cur[[length(cur) + 1L]] <- treated[[i]]
    cur_size <- cur_size + sz
  }
  if (length(cur) > 0) chunks[[length(chunks) + 1L]] <- c(controls, cur)
  if (length(chunks) == 0L) chunks <- list(controls)  # solo controlli
  chunks
}
