#' Helper interni: dedupe GSM cross-GSE per BioSample SAMN
#'
#' Implementa la decisione utente 2026-05-27 (FASE E0b ADR-0019 D9) su
#' evidence A7b: collasso same-SAMN cross-GSE nel pool Stadio 4 via drop
#' deterministico, criterio max \code{lib_size} (tie-break GSM alfabetico).
#'
#' Razionale (sintesi A7b — i 425 GSM cross-GSE NON sono replicate tecnici):
#'   - Pearson(log1p) counts cross-GSE 0.41-0.75 anche con metadata identico
#'     -> mediare counts (opzione b) statisticamente indifendibile.
#'   - Upper bound 128 group cluster colpiti (32.4% dei 176 SAMN duplicati)
#'     -> opzione (c) sotto-noise non difendibile.
#'   - Criterio \code{lib_size} max preserva il GSM piu' profondo per le DE.
#'
#' Vedi: \code{analysis/audit/A7b-samn-duplicate-analysis.md}.
#'
#' @keywords internal
NULL

#' Lookup char per GSM (env o named char vec).
#'
#' Ritorna NA_character_ se GSM non presente nel lookup o se valore originale
#' e' NA/NULL.
#'
#' @keywords internal
.lookup_chr <- function(keys, lookup) {
  if (is.environment(lookup)) {
    vapply(keys, function(k) {
      if (exists(k, envir = lookup, inherits = FALSE)) {
        v <- get(k, envir = lookup, inherits = FALSE)
        if (is.null(v) || length(v) == 0L) NA_character_ else as.character(v)[1L]
      } else NA_character_
    }, character(1L), USE.NAMES = FALSE)
  } else if (!is.null(lookup) && !is.null(names(lookup))) {
    out <- rep(NA_character_, length(keys))
    hit <- keys %in% names(lookup)
    out[hit] <- as.character(unname(lookup[keys[hit]]))
    out
  } else {
    rep(NA_character_, length(keys))
  }
}

#' Lookup numeric per GSM (env o named numeric vec).
#'
#' Ritorna NA_real_ se GSM non presente nel lookup o se valore originale e' NA.
#'
#' @keywords internal
.lookup_num <- function(keys, lookup) {
  if (is.environment(lookup)) {
    vapply(keys, function(k) {
      if (exists(k, envir = lookup, inherits = FALSE)) {
        v <- get(k, envir = lookup, inherits = FALSE)
        if (is.null(v) || length(v) == 0L) NA_real_ else as.numeric(v)[1L]
      } else NA_real_
    }, numeric(1L), USE.NAMES = FALSE)
  } else if (!is.null(lookup) && !is.null(names(lookup))) {
    out <- rep(NA_real_, length(keys))
    hit <- keys %in% names(lookup)
    out[hit] <- as.numeric(unname(lookup[keys[hit]]))
    out
  } else {
    rep(NA_real_, length(keys))
  }
}

#' Costruisce i due lookup (biosample, lib_size) dal tibble h5_metadata
#'
#' Entry point E0b lato \code{build_stage4_results}: trasforma il tibble
#' sample-level passato come \code{h5_metadata} in due named vector
#' compatibili con \code{.dedupe_gsm_by_samn}. Fallback graceful: se
#' \code{h5_metadata} manca \code{biosample_id} o \code{lib_size}, emette
#' un \code{warning} e ritorna entrambi NULL (-> dedupe SAMN disabilitato
#' downstream, comportamento retrocompat pre-E0b).
#'
#' @param h5_metadata tibble/data.frame con almeno colonne \code{sample_id},
#'   \code{biosample_id}, \code{lib_size}. NULL accettato (-> NULL/NULL).
#' @return list \code{(biosample_lookup, libsize_lookup)}. NULL/NULL se
#'   colonne necessarie assenti.
#' @keywords internal
.build_samn_dedupe_lookups <- function(h5_metadata) {
  if (is.null(h5_metadata) || !is.data.frame(h5_metadata)) {
    return(list(biosample_lookup = NULL, libsize_lookup = NULL))
  }
  need <- c("sample_id", "biosample_id", "lib_size")
  miss <- setdiff(need, names(h5_metadata))
  if (length(miss) > 0L) {
    warning(sprintf(
      "h5_metadata manca colonne %s -> SAMN dedupe (FASE E0b) disabilitato",
      paste(miss, collapse = ", ")
    ), call. = FALSE)
    return(list(biosample_lookup = NULL, libsize_lookup = NULL))
  }
  biosample_lookup <- setNames(
    as.character(h5_metadata$biosample_id),
    as.character(h5_metadata$sample_id)
  )
  libsize_lookup <- setNames(
    as.numeric(h5_metadata$lib_size),
    as.character(h5_metadata$sample_id)
  )
  list(biosample_lookup = biosample_lookup,
       libsize_lookup   = libsize_lookup)
}

#' Schema tibble vuoto per il log dei GSM droppati dal dedupe SAMN
#'
#' @keywords internal
.empty_samn_dedupe_dropped <- function() {
  tibble::tibble(
    gsm_dropped     = character(0),
    samn            = character(0),
    gsm_kept        = character(0),
    libsize_dropped = numeric(0),
    libsize_kept    = numeric(0),
    reason          = character(0)
  )
}

#' Dedupe GSM cross-GSE per BioSample SAMN nel pool Stadio 4
#'
#' Per ogni SAMN che compare con N>=2 GSM in \code{sample_ids}, tiene il GSM
#' con \code{lib_size} massimo; tie-break su GSM accessioned alfabetico.
#' GSM con SAMN = NA (identita' biologica ignota) o assente dal lookup sono
#' preservati senza collasso (NA != NA). GSM con SAMN in \code{exclude_samn}
#' (es. SAMN gia' presente nel pair del cluster) sono droppati completamente.
#'
#' @param sample_ids character vector di GSM accessioned.
#' @param biosample_lookup environment o named character vector
#'   \code{GSM -> SAMN}. NA accettato (preservato).
#' @param libsize_lookup environment o named numeric vector
#'   \code{GSM -> lib_size}. NA accettato (deprioritizzato vs non-NA).
#' @param exclude_samn character vector di SAMN da escludere completamente
#'   (default NULL = no exclude).
#' @return list con:
#'   \describe{
#'     \item{\code{kept}}{character vector di GSM tenuti, ordine preservato
#'       dal \code{sample_ids} input (deduplicato sull'identita' GSM).}
#'     \item{\code{dropped}}{tibble con colonne \code{gsm_dropped, samn,
#'       gsm_kept, libsize_dropped, libsize_kept, reason}. \code{reason}
#'       in \{lower_libsize, tie_alphabetic_loser, excluded_samn\}.}
#'   }
#' @keywords internal
.dedupe_gsm_by_samn <- function(sample_ids,
                                 biosample_lookup,
                                 libsize_lookup,
                                 exclude_samn = NULL) {
  empty_dropped <- .empty_samn_dedupe_dropped()

  if (length(sample_ids) == 0L) {
    return(list(kept = character(0), dropped = empty_dropped))
  }

  sample_ids <- as.character(sample_ids)

  samn_vec <- .lookup_chr(sample_ids, biosample_lookup)
  lib_vec  <- .lookup_num(sample_ids, libsize_lookup)

  excl_set <- if (is.null(exclude_samn)) character(0) else as.character(exclude_samn)

  # Step 1: GSM con SAMN in exclude_samn -> droppati con reason="excluded_samn"
  is_excluded <- !is.na(samn_vec) & samn_vec %in% excl_set
  dropped_excl <- if (any(is_excluded)) {
    tibble::tibble(
      gsm_dropped     = sample_ids[is_excluded],
      samn            = samn_vec[is_excluded],
      gsm_kept        = NA_character_,
      libsize_dropped = lib_vec[is_excluded],
      libsize_kept    = NA_real_,
      reason          = "excluded_samn"
    )
  } else empty_dropped

  remain_idx <- which(!is_excluded)
  if (length(remain_idx) == 0L) {
    return(list(kept = character(0), dropped = dropped_excl))
  }

  # Step 2: GSM con SAMN = NA preservati (no collapse)
  na_mask <- is.na(samn_vec[remain_idx])
  na_idx  <- remain_idx[na_mask]
  nonna_idx <- remain_idx[!na_mask]
  kept_na <- sample_ids[na_idx]

  # Step 3: dedupe per SAMN non-NA non-excluded
  drop_rows <- list()
  kept_collapse <- character(0)

  if (length(nonna_idx) > 0L) {
    samn_nonna <- samn_vec[nonna_idx]
    gsm_nonna  <- sample_ids[nonna_idx]
    lib_nonna  <- lib_vec[nonna_idx]

    by_samn <- split(seq_along(nonna_idx), samn_nonna)

    for (samn_g in names(by_samn)) {
      grp <- by_samn[[samn_g]]
      g_gsm <- gsm_nonna[grp]
      g_lib <- lib_nonna[grp]

      if (length(grp) == 1L) {
        kept_collapse <- c(kept_collapse, g_gsm)
        next
      }

      # NA libsize deprioritizzato vs non-NA: -Inf nel ranking max().
      g_lib_for_max <- ifelse(is.na(g_lib), -Inf, g_lib)
      max_lib <- max(g_lib_for_max)
      candidates <- which(g_lib_for_max == max_lib)

      if (length(candidates) == 1L) {
        winner_i   <- candidates
        reason_dr  <- "lower_libsize"
      } else {
        # tie su libsize: alphabetic winner deterministico. `which.min` su
        # character non funziona -> uso order() che lavora lessicalmente.
        winner_i   <- candidates[order(g_gsm[candidates])[1L]]
        reason_dr  <- "tie_alphabetic_loser"
      }

      winner       <- g_gsm[winner_i]
      winner_lib   <- g_lib[winner_i]
      kept_collapse <- c(kept_collapse, winner)

      losers <- setdiff(seq_along(grp), winner_i)
      for (lj in losers) {
        drop_rows[[length(drop_rows) + 1L]] <- tibble::tibble(
          gsm_dropped     = g_gsm[lj],
          samn            = samn_g,
          gsm_kept        = winner,
          libsize_dropped = g_lib[lj],
          libsize_kept    = winner_lib,
          reason          = reason_dr
        )
      }
    }
  }

  dropped_dup <- if (length(drop_rows) > 0L) {
    dplyr::bind_rows(drop_rows)
  } else empty_dropped

  dropped_all <- dplyr::bind_rows(dropped_excl, dropped_dup)

  # Ordine kept preservato dall'input (no duplicati GSM)
  kept_set <- c(kept_na, kept_collapse)
  kept_all <- sample_ids[!duplicated(sample_ids) & sample_ids %in% kept_set]

  list(kept = kept_all, dropped = dropped_all)
}
