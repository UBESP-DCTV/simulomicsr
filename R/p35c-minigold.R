#' Sampling stratificato per mini-gold design-aware
#'
#' Estrae N sample distribuiti 50/50 easy/hard, con almeno `min_gse_per_tier`
#' GSE distinti per tier (per evitare di studiare un singolo GSE anomalo).
#' Algoritmo: per ogni tier, seleziona min_gse_per_tier GSE casuali, e
#' campiona uniformemente i sample fino a target_n / 2.
#'
#' Errori tipizzati:
#' - `simulomicsr_minigold_insufficient_gse` se un tier ha meno di
#'   min_gse_per_tier GSE.
#'
#' @param gse_tiers tibble con colonne `series_id`, `confidence_score`, `tier`
#' @param samples_table tibble con `geo_accession`, `series_id`, `string`
#'   (tutti i sample candidati)
#' @param target_n totale sample (50/50 easy/hard)
#' @param min_gse_per_tier minimo numero GSE distinti da coprire per tier
#'
#' @return tibble con colonne geo_accession, series_id, string, tier,
#'   confidence_score
#'
#' @export
sample_minigold_stratified <- function(gse_tiers,
                                       samples_table,
                                       target_n = 100L,
                                       min_gse_per_tier = 15L) {
  stopifnot(target_n %% 2L == 0L)
  per_tier_n <- target_n %/% 2L

  out <- list()
  for (t in c("easy", "hard")) {
    pool <- gse_tiers[gse_tiers$tier == t, ]
    if (nrow(pool) < min_gse_per_tier) {
      rlang::abort(
        sprintf("Tier '%s' ha solo %d GSE (richiesti almeno %d).",
                t, nrow(pool), min_gse_per_tier),
        class = "simulomicsr_minigold_insufficient_gse",
        tier = t, n_gse = nrow(pool)
      )
    }
    # Garantisce copertura minima selezionando prima i GSE "seed",
    # poi campiona uniformemente da tutti i sample del tier.
    seed_gse <- pool$series_id[sample.int(nrow(pool), min_gse_per_tier)]
    all_gse <- pool$series_id
    samples_pool <- samples_table[samples_table$series_id %in% all_gse, ]
    take <- min(nrow(samples_pool), per_tier_n)
    # Garantisce che i seed_gse siano inclusi: prima prende un sample per GSE seed,
    # poi riempie il resto con campionamento uniforme dal pool residuo.
    seed_samples <- samples_pool[samples_pool$series_id %in% seed_gse, ]
    seed_picked_idx <- sample.int(nrow(seed_samples), min(nrow(seed_samples), take))
    seed_picked <- seed_samples[seed_picked_idx, ]
    residual_pool <- samples_pool[!(samples_pool$geo_accession %in% seed_picked$geo_accession), ]
    n_residual <- take - nrow(seed_picked)
    if (n_residual > 0 && nrow(residual_pool) > 0) {
      res_idx <- sample.int(nrow(residual_pool), min(nrow(residual_pool), n_residual))
      picked <- rbind(seed_picked, residual_pool[res_idx, ])
    } else {
      picked <- seed_picked
    }
    picked$tier <- t
    picked <- dplyr::left_join(
      picked,
      gse_tiers[, c("series_id", "confidence_score")],
      by = "series_id"
    )
    out[[t]] <- picked
  }
  dplyr::bind_rows(out)
}

# ---------------------------------------------------------------------------
# Costanti private per il mini-gold CSV
# ---------------------------------------------------------------------------

.MINIGOLD_CSV_COLS <- c(
  "geo_accession", "series_id", "string", "study_title", "study_summary",
  "study_overview",
  "design_role_proposed_models", "design_kind_proposed_models",
  "design_role_gold", "design_kind_gold", "comment_optional", "tier"
)

# Vocabolario design_role v3 (13 valori) - duplica spec stage2.v1 per
# uso runtime senza dipendenza da schema JSON (validazione human-friendly).
.VALID_DESIGN_ROLES <- c(
  "perturbed", "vehicle_control", "untreated_control",
  "negative_genetic_control", "negative_inducer_control",
  "positive_control", "baseline_t0", "case", "comparison",
  "bystander", "secondary_arm", "excluded", "unclear"
)

.VALID_DESIGN_KINDS <- c(
  "case_control_disease", "treatment_vs_vehicle", "treatment_vs_untreated",
  "time_course", "dose_response", "knockdown_panel", "factorial",
  "differentiation_course", "multi_arm_treatment", "unclear"
)

# ---------------------------------------------------------------------------
# Helper interno: cerca il design_role di un sample nello studio
# ---------------------------------------------------------------------------

#' Cerca il design_role di un sample in un study_design
#'
#' Itera sui replicate_groups e ritorna il design_role del gruppo che contiene
#' il sample identificato da geo_accession. Ritorna NULL se non trovato o se
#' il design e' invalido.
#'
#' @noRd
.lookup_role_for_sample <- function(design, geo_accession) {
  if (is.null(design) || .is_invalid_design(design)) return(NULL)
  for (g in design$replicate_groups %||% list()) {
    if (geo_accession %in% unlist(g$sample_ids %||% list())) {
      return(g$design_role)
    }
  }
  NULL
}

#' Costruisce il riepilogo per-studio dei sample con i ruoli proposti
#'
#' Per uno studio (lista nominata per modello), enumera TUTTI i sample
#' presenti almeno in un classificazione valida e per ognuno mostra il
#' design_role assegnato da ogni modello. Output: stringa multi-line, una
#' riga per sample. Serve a dare contesto al revisore umano nel CSV
#' (vede tutto lo studio in una cella, non solo il sample della riga).
#'
#' @noRd
.build_study_overview <- function(multi_outputs_for_study) {
  sample_to_roles <- list()
  for (label in names(multi_outputs_for_study)) {
    d <- multi_outputs_for_study[[label]]
    if (.is_invalid_design(d)) next
    for (g in d$replicate_groups %||% list()) {
      for (sid in unlist(g$sample_ids %||% list())) {
        sid <- as.character(sid)
        if (is.null(sample_to_roles[[sid]])) sample_to_roles[[sid]] <- list()
        sample_to_roles[[sid]][[label]] <- g$design_role
      }
    }
  }
  if (length(sample_to_roles) == 0L) return("(no valid classifications)")

  sample_ids_sorted <- sort(names(sample_to_roles))
  lines <- vapply(sample_ids_sorted, function(sid) {
    roles <- sample_to_roles[[sid]]
    role_strs <- vapply(names(roles), function(label) {
      paste0(label, "=", roles[[label]] %||% "NA")
    }, character(1))
    paste0(sid, ": ", paste(role_strs, collapse = "; "))
  }, character(1))
  paste(lines, collapse = "\n")
}

# ---------------------------------------------------------------------------
# export_minigold_csv
# ---------------------------------------------------------------------------

#' Esporta il template CSV per la review umana del mini-gold
#'
#' Per ogni sample del pool, pre-popola: stringa GEO, study title/summary,
#' role/kind proposti dai modelli (concatenati), tier. Lascia vuote
#' design_role_gold e design_kind_gold (la review umana le compila).
#'
#' @param minigold_pool tibble da `sample_minigold_stratified()`
#' @param study_summaries lista nominata per series_id con title/summary
#' @param multi_classify_outputs lista nominata per series_id, ogni elemento
#'   e' la lista nominata per modello (output di `multi_classify_study()`)
#' @param dest_path path del CSV di destinazione
#'
#' @return invisible(dest_path)
#'
#' @export
export_minigold_csv <- function(minigold_pool,
                                study_summaries,
                                multi_classify_outputs,
                                dest_path) {
  # Pre-computa lo study_overview per ogni studio coinvolto (riusato su tutte
  # le righe dello stesso GSE)
  unique_sids <- unique(minigold_pool$series_id)
  overview_per_gse <- stats::setNames(
    lapply(unique_sids, function(sid) {
      .build_study_overview(multi_classify_outputs[[sid]] %||% list())
    }),
    unique_sids
  )

  rows <- lapply(seq_len(nrow(minigold_pool)), function(i) {
    row <- minigold_pool[i, ]
    sid <- row$series_id
    gsm <- row$geo_accession
    sumr <- study_summaries[[sid]] %||% list(title = "", summary = "")
    multi <- multi_classify_outputs[[sid]] %||% list()

    role_per_model <- vapply(names(multi), function(label) {
      d <- multi[[label]]
      if (.is_invalid_design(d)) return(paste0(label, "=ERROR"))
      role <- .lookup_role_for_sample(d, gsm)
      paste0(label, "=", role %||% "NA")
    }, character(1))

    kind_per_model <- vapply(names(multi), function(label) {
      d <- multi[[label]]
      if (.is_invalid_design(d)) return(paste0(label, "=ERROR"))
      paste0(label, "=", d$design_kind %||% "NA")
    }, character(1))

    tibble::tibble(
      geo_accession = gsm,
      series_id = sid,
      string = row$string %||% "",
      study_title = sumr$title %||% "",
      study_summary = sumr$summary %||% "",
      study_overview = overview_per_gse[[sid]] %||% "",
      design_role_proposed_models = paste(role_per_model, collapse = "; "),
      design_kind_proposed_models = paste(kind_per_model, collapse = "; "),
      design_role_gold = NA_character_,
      design_kind_gold = NA_character_,
      comment_optional = NA_character_,
      tier = row$tier %||% NA_character_
    )
  })
  out <- dplyr::bind_rows(rows) |>
    dplyr::arrange(.data$series_id, .data$geo_accession)
  readr::write_csv(out, dest_path, na = "")
  invisible(dest_path)
}

# ---------------------------------------------------------------------------
# import_minigold_reviewed
# ---------------------------------------------------------------------------

#' Importa il CSV reviewato dall'utente e valida i valori gold
#'
#' Errori tipizzati:
#' - `simulomicsr_minigold_missing_cols` se mancano colonne obbligatorie
#' - `simulomicsr_minigold_invalid_value` se design_role_gold o design_kind_gold
#'   contengono valori fuori dal vocabolario v3.
#'
#' @param csv_path path del CSV reviewato
#' @return tibble con tutte le colonne del template, righe filtrate alle
#'   sole con design_role_gold non NA (la review puo' lasciare in bianco
#'   sample non review-abili).
#'
#' @export
import_minigold_reviewed <- function(csv_path) {
  reviewed <- readr::read_csv(csv_path, show_col_types = FALSE,
                              progress = FALSE)
  missing_cols <- setdiff(.MINIGOLD_CSV_COLS, colnames(reviewed))
  if (length(missing_cols) > 0L) {
    rlang::abort(
      sprintf("CSV reviewato manca delle colonne: %s",
              paste(missing_cols, collapse = ", ")),
      class = "simulomicsr_minigold_missing_cols"
    )
  }

  reviewed <- reviewed[!is.na(reviewed$design_role_gold), ]
  bad_roles <- setdiff(stats::na.omit(unique(reviewed$design_role_gold)), .VALID_DESIGN_ROLES)
  if (length(bad_roles) > 0L) {
    rlang::abort(
      sprintf("design_role_gold ha valori fuori vocabolario: %s",
              paste(bad_roles, collapse = ", ")),
      class = "simulomicsr_minigold_invalid_value",
      bad_values = bad_roles
    )
  }
  bad_kinds <- setdiff(stats::na.omit(unique(reviewed$design_kind_gold)), .VALID_DESIGN_KINDS)
  if (length(bad_kinds) > 0L) {
    rlang::abort(
      sprintf("design_kind_gold ha valori fuori vocabolario: %s",
              paste(bad_kinds, collapse = ", ")),
      class = "simulomicsr_minigold_invalid_value",
      bad_values = bad_kinds
    )
  }
  reviewed
}

# ---------------------------------------------------------------------------
# eval_against_minigold
# ---------------------------------------------------------------------------

#' Calcola accuracy di ogni modello vs mini-gold reviewato
#'
#' Per ogni (model, tier in {overall, easy, hard}), restituisce accuracy
#' del design_role predetto vs design_role_gold.
#'
#' @param reviewed tibble da `import_minigold_reviewed()`
#' @param multi_classify_outputs lista nominata per series_id (come in
#'   `export_minigold_csv()`)
#'
#' @return tibble con colonne model, tier, n, n_correct, accuracy
#'
#' @export
eval_against_minigold <- function(reviewed, multi_classify_outputs) {
  model_labels <- unique(unlist(lapply(multi_classify_outputs, names)))
  if (length(model_labels) == 0L) {
    return(tibble::tibble(
      model = character(),
      tier = character(),
      n = integer(),
      n_correct = integer(),
      accuracy = double()
    ))
  }

  per_sample_rows <- lapply(seq_len(nrow(reviewed)), function(i) {
    row <- reviewed[i, ]
    sid <- row$series_id
    gsm <- row$geo_accession
    multi <- multi_classify_outputs[[sid]] %||% list()
    do.call(rbind, lapply(model_labels, function(label) {
      pred <- .lookup_role_for_sample(multi[[label]], gsm)
      tibble::tibble(
        geo_accession = gsm,
        tier = row$tier,
        model = label,
        gold = row$design_role_gold,
        pred = pred %||% NA_character_,
        correct = identical(pred, row$design_role_gold)
      )
    }))
  })
  per_sample <- dplyr::bind_rows(per_sample_rows)

  by_groups <- dplyr::bind_rows(
    per_sample |>
      dplyr::group_by(.data$model) |>
      dplyr::summarise(
        tier = "overall",
        n = dplyr::n(),
        n_correct = sum(.data$correct),
        accuracy = mean(.data$correct),
        .groups = "drop"
      ),
    per_sample |>
      dplyr::group_by(.data$model, tier = .data$tier) |>
      dplyr::summarise(
        n = dplyr::n(),
        n_correct = sum(.data$correct),
        accuracy = mean(.data$correct),
        .groups = "drop"
      )
  )
  by_groups |>
    dplyr::select("model", "tier", "n", "n_correct", "accuracy") |>
    dplyr::arrange(.data$model, .data$tier)
}
