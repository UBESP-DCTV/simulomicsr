#' Costruisce metadata safe per dispatch MEGA con conflict detection
#'
#' Replica orchestrator MEGA branch ma con difese:
#' \itemize{
#'   \item Dedup di sample che appaiono in piu' rg dello stesso cluster.
#'     Pattern visto al fullrun 2026-05-20: rg multipli condividono GSM,
#'     \code{unlist} produce duplicati che crashano \code{rownames(metadata)}.
#'   \item Rilevazione conflitti di ruolo: stesso GSM con
#'     \code{treatment="treated"} in un rg e \code{"control"} in un altro
#'     → sample droppato dal cluster + registrato come conflict.
#'   \item Rilevazione duplicazioni cross-study: stesso GSM presente in
#'     replicate_groups di GSE diversi (caso ARCHS4 super-series) → tenuto
#'     una sola volta + registrato come conflict.
#' }
#'
#' Nessun sample viene perso senza traccia: ogni dedup/drop e' nel
#' \code{conflicts} tibble di ritorno, propagato a
#' \code{qc_report$pooling_warnings}.
#'
#' @param grp list di dispatch entries con campi \code{study_id},
#'   \code{sample_ids}, \code{treatment}.
#' @param cluster_id chr ID del cluster per logging.
#' @return list:
#'   \itemize{
#'     \item \code{metadata}: data.frame con \code{sample_id} unici, factor
#'       \code{study}, factor \code{treatment} (levels: control, treated).
#'     \item \code{conflicts}: tibble \code{(cluster_id, sample_id, studies,
#'       roles, conflict_type)} con i sample rimossi o segnalati.
#'   }
#' @keywords internal
.build_mega_metadata_safe <- function(grp, cluster_id) {
  empty_meta <- data.frame(
    sample_id = character(0L),
    study     = factor(character(0L)),
    treatment = factor(character(0L), levels = c("control", "treated")),
    stringsAsFactors = FALSE
  )
  empty_conf <- tibble::tibble(
    cluster_id    = character(0L),
    sample_id     = character(0L),
    studies       = character(0L),
    roles         = character(0L),
    conflict_type = character(0L)
  )

  if (length(grp) == 0L) {
    return(list(metadata = empty_meta, conflicts = empty_conf))
  }

  all_sids    <- unlist(lapply(grp, `[[`, "sample_ids"))
  all_studies <- unlist(lapply(grp, function(d) {
    rep(d$study_id, length(d$sample_ids))
  }))
  all_treats  <- unlist(lapply(grp, `[[`, "treatment"))

  if (length(all_sids) == 0L) {
    return(list(metadata = empty_meta, conflicts = empty_conf))
  }

  by_sid <- split(seq_along(all_sids), all_sids)
  conflicts_rows <- list()
  drop_idx <- integer(0L)
  for (sid in names(by_sid)) {
    idx <- by_sid[[sid]]
    if (length(idx) == 1L) next  # nessun dup
    roles   <- unique(all_treats[idx])
    studies <- unique(all_studies[idx])
    if (length(roles) > 1L) {
      # Role conflict: sample droppato (paper-grade: non assumere ruolo arbitrario)
      conflicts_rows[[length(conflicts_rows) + 1L]] <- tibble::tibble(
        cluster_id    = cluster_id,
        sample_id     = sid,
        studies       = paste(studies, collapse = ";"),
        roles         = paste(roles, collapse = ";"),
        conflict_type = "role_conflict_dropped"
      )
      drop_idx <- c(drop_idx, idx)
    } else if (length(studies) > 1L) {
      # Cross-study same-role: tenuto una sola volta + flagged
      conflicts_rows[[length(conflicts_rows) + 1L]] <- tibble::tibble(
        cluster_id    = cluster_id,
        sample_id     = sid,
        studies       = paste(studies, collapse = ";"),
        roles         = roles[1L],
        conflict_type = "cross_study_duplicate_kept_first"
      )
      drop_idx <- c(drop_idx, idx[-1L])
    } else {
      # Same study + same role: pura ridondanza (Stage 2 stored sample twice)
      # Tenuto una sola volta, NO conflict (non scientificamente rilevante)
      drop_idx <- c(drop_idx, idx[-1L])
    }
  }

  keep <- setdiff(seq_along(all_sids), drop_idx)
  metadata <- data.frame(
    sample_id = all_sids[keep],
    study     = factor(all_studies[keep]),
    treatment = factor(all_treats[keep], levels = c("control", "treated")),
    stringsAsFactors = FALSE
  )

  conflicts <- if (length(conflicts_rows) > 0L) {
    do.call(rbind, conflicts_rows)
  } else empty_conf

  list(metadata = metadata, conflicts = conflicts)
}

#' Verifica se un cluster MEGA e' rank-deficient per il contrasto treatment
#'
#' Un cluster e' rank-deficient (= contrasto \code{~treatment} non
#' identificabile) se ha < 2 livelli di treatment oppure < n_min samples
#' per ogni livello. Senza entrambi i livelli, \code{lme4::lmer} produce
#' \code{coefficients = NA} per \code{treatmenttreated}.
#'
#' Cluster rank-deficient devono essere SKIPPATI con motivo esplicito in
#' \code{non_processable}, non processati con NA wasting compute.
#'
#' @param metadata data.frame con \code{treatment} factor.
#' @param n_min minimo samples per livello (default 2L).
#' @return list \code{(rank_deficient, reason)} con \code{reason = NA} se
#'   non rank-deficient.
#' @keywords internal
.check_mega_rank <- function(metadata, n_min = 2L) {
  if (nrow(metadata) < (2L * n_min)) {
    return(list(rank_deficient = TRUE,
                reason = sprintf("n_samples_total=%d < 2*n_min=%d",
                                  nrow(metadata), 2L * n_min)))
  }
  tab <- table(metadata$treatment)
  treated_n <- as.integer(tab[["treated"]] %||% 0L)
  control_n <- as.integer(tab[["control"]] %||% 0L)
  if (treated_n < n_min || control_n < n_min) {
    return(list(rank_deficient = TRUE,
                reason = sprintf("treatment_levels_treated=%d_control=%d_n_min=%d",
                                  treated_n, control_n, n_min)))
  }
  list(rank_deficient = FALSE, reason = NA_character_)
}
