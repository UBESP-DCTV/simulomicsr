library(targets)
library(tarchetypes)

# Carica tutte le funzioni della libreria simulomicsr
list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE) |>
  lapply(source) |>
  invisible()

tar_option_set(
  packages = c("tibble", "dplyr", "readxl"),
  format   = "rds",
  error    = "continue",
  workspace_on_error = TRUE
)

list(
  tar_target(
    samples_input_path,
    here::here("data-raw", "relevant_sample_classified.xlsx"),
    format = "file"
  ),

  tar_target(
    samples_input,
    read_samples_input(samples_input_path)
  ),

  tar_target(
    samples_dev_set,
    build_dev_set(samples_input, n = 100L, seed = 1812L)
  ),

  # Cache LLM persistente per Stadio 1 (stessa cache tra run; idempotente).
  # Nota: `targets` traccia questo path come file; la dir e' creata se mancante.
  tar_target(
    stage1_cache_dir,
    fs::dir_create(here::here("analysis", "cache")),
    format = "file"
  ),

  # Dynamic branching: una invocazione per riga di samples_dev_set.
  # `targets` con `pattern = map(samples_dev_set)` su una tibble passa
  # **una riga alla volta** alla funzione. `classify_sample_row()` riceve
  # quindi un tibble di 1 riga per branch e ritorna il sample_fact.
  tar_target(
    sample_facts_raw,
    classify_sample_row(
      samples_dev_set,
      provider = "openai",
      model    = "gpt-5.5",
      cache    = cache_init(stage1_cache_dir, namespace = "stage1")
    ),
    pattern   = map(samples_dev_set),
    iteration = "list"
  ),

  # Validazione schema; partition pass/fail.
  # `sample_facts_validator` conserva il PATH dello schema (stringa), non il
  # validatore compilato: i validatori jsonvalidate/V8 non sono serializzabili
  # in RDS (il contesto V8 viene distrutto alla deserializzazione). Il PATH e'
  # un target stabile che garantisce un'unica sorgente di verita' per lo schema.
  tar_target(
    sample_facts_validator,
    system.file("schemas/sample_facts.stage1.v3.json", package = "simulomicsr"),
    format = "file"
  ),

  tar_target(
    sample_facts_validated,
    {
      # Un record finisce in `validated` se e solo se:
      #   (a) NON e' un record di failure (no `.invalid_reason`)
      #   (b) supera la validazione schema dopo aver rimosso eventuali
      #       campi extra di debug.
      # Importante: i record di .stage1_invalid_record sono schema-conformanti
      # (modulo i campi extra), quindi (a) e' il check primario; (b) e' una
      # safety net in caso un sample_fact "ok" abbia campi inattesi.
      validator <- compile_schema(sample_facts_validator)
      keep <- vapply(sample_facts_raw, function(f) {
        if (!is.null(f$.invalid_reason)) return(FALSE)
        f$.invalid_reason <- NULL
        f$.invalid_detail <- NULL
        validate_json(f, validator = validator)$valid
      }, logical(1))
      sample_facts_raw[keep]
    }
  ),

  tar_target(
    sample_facts_invalid,
    {
      validator <- compile_schema(sample_facts_validator)
      drop <- vapply(sample_facts_raw, function(f) {
        if (!is.null(f$.invalid_reason)) return(TRUE)
        f$.invalid_reason <- NULL
        f$.invalid_detail <- NULL
        !validate_json(f, validator = validator)$valid
      }, logical(1))
      sample_facts_raw[drop]
    }
  ),

  # Cache filesystem dei summary GEO (uno per GSE)
  tar_target(
    geo_summary_cache_dir,
    fs::dir_create(here::here("analysis", "cache", "geo-summary")),
    format = "file"
  ),

  # Estrai gli unique series_id dei sample_facts validati
  # Filtra a SINGLE-GSE pattern (alcuni records hanno series_id come
  # "GSEX,GSEY" SuperSeries — non supportati da fetch_study_summary).
  tar_target(
    study_series_ids,
    {
      ids <- vapply(sample_facts_validated, function(f) f$series_id %||% NA_character_,
                    character(1))
      ids <- unique(ids[!is.na(ids)])
      single_gse <- ids[grepl("^GSE[0-9]+$", ids)]
      n_dropped <- length(ids) - length(single_gse)
      if (n_dropped > 0L) {
        message("study_series_ids: dropped ", n_dropped, " multi-GSE entries (SuperSeries)")
      }
      single_gse
    }
  ),

  # Dynamic branching: una invocazione per series_id
  tar_target(
    study_summaries,
    fetch_study_summary(study_series_ids, cache_dir = geo_summary_cache_dir),
    pattern = map(study_series_ids),
    iteration = "list"
  ),

  # ---------------------------------------------------------------------------
  # Stadio 2 — usa le 15 fixture curate (vedi commit 2976006), non il
  # pipeline study_series_ids dal P2 dev set (che ha 1 sample/GSE).
  # Le 15 GSE coprono diversi design_kind + edge case mirati.
  tar_target(
    curated_stage2_gse,
    c("GSE145028", "GSE145941", "GSE191240", "GSE155528", "GSE200037",
      "GSE104149", "GSE106966", "GSE114781", "GSE57494",  "GSE143441",
      "GSE128771", "GSE101708", "GSE102908", "GSE106716", "GSE100261")
  ),

  tar_target(
    stage2_cache_dir,
    fs::dir_create(here::here("analysis", "cache")),
    format = "file"
  ),

  # Dynamic branching: una invocazione classify_study per GSE curato.
  # Carica sample_facts e study_summary dalla fixture mini.
  tar_target(
    study_designs_raw,
    {
      gse <- curated_stage2_gse
      fixture_dir <- system.file("extdata/stage2-fixtures-mini",
                                 package = "simulomicsr")
      facts_path <- file.path(fixture_dir, paste0(gse, "-sample-facts.json"))
      summary_path <- file.path(fixture_dir, paste0(gse, "-study-summary.json"))
      facts_list <- jsonlite::read_json(facts_path, simplifyVector = FALSE)
      summary_obj <- jsonlite::read_json(summary_path, simplifyVector = FALSE)
      classify_study(
        series_id = gse,
        sample_facts_list = facts_list,
        study_summary = summary_obj,
        provider = "openai", model = "gpt-5.5",
        cache = cache_init(stage2_cache_dir, namespace = "stage2")
      )
    },
    pattern = map(curated_stage2_gse),
    iteration = "list"
  ),

  tar_target(
    study_designs_validator,
    system.file("schemas/study_design.stage2.v1.json", package = "simulomicsr"),
    format = "file"
  ),

  tar_target(
    study_designs_validated,
    {
      validator <- compile_schema(study_designs_validator)
      keep <- vapply(study_designs_raw, function(d) {
        if (!is.null(d$.invalid_reason)) return(FALSE)
        d$.invalid_reason <- NULL
        d$.invalid_detail <- NULL
        validate_json(d, validator = validator)$valid
      }, logical(1))
      study_designs_raw[keep]
    }
  ),

  tar_target(
    study_designs_invalid,
    {
      validator <- compile_schema(study_designs_validator)
      drop <- vapply(study_designs_raw, function(d) {
        if (!is.null(d$.invalid_reason)) return(TRUE)
        d$.invalid_reason <- NULL
        d$.invalid_detail <- NULL
        !validate_json(d, validator = validator)$valid
      }, logical(1))
      study_designs_raw[drop]
    }
  ),

  # Tabella piatta (una riga per comparison) arricchita con comparability_anchor v3.
  # Per ogni comparison, il sample_fact rappresentativo e' il primo sample_id del
  # treated_group (o del gruppo con design_role primario). I sample_facts vengono
  # caricati dalle fixture mini di Stadio 2, non dal dev set P2.
  tar_target(
    comparisons_table,
    {
      rows <- list()
      fixture_dir <- system.file("extdata/stage2-fixtures-mini",
                                 package = "simulomicsr")
      # Cache lazy delle fixture sample_facts per GSE
      facts_cache <- list()
      load_facts <- function(gse) {
        if (!is.null(facts_cache[[gse]])) return(facts_cache[[gse]])
        path <- file.path(fixture_dir, paste0(gse, "-sample-facts.json"))
        facts <- jsonlite::read_json(path, simplifyVector = FALSE)
        # Indicizza per geo_accession
        idx <- list()
        for (f in facts) {
          if (!is.null(f$geo_accession)) idx[[f$geo_accession]] <- f
        }
        facts_cache[[gse]] <<- idx
        idx
      }

      for (design in study_designs_validated) {
        sid <- design$series_id
        facts_idx <- load_facts(sid)
        groups_idx <- list()
        for (g in design$replicate_groups) {
          groups_idx[[g$group_id]] <- g
        }
        for (cmp in design$comparisons) {
          treated_grp <- groups_idx[[cmp$treated_group]]
          if (is.null(treated_grp) || length(treated_grp$sample_ids) == 0L) next
          repr_id <- treated_grp$sample_ids[[1L]]
          repr_facts <- facts_idx[[repr_id]]
          if (is.null(repr_facts)) next
          anchor <- tryCatch(
            make_anchor(repr_facts, stage2_role = treated_grp$design_role),
            error = function(e) NA_character_
          )
          control_grp <- groups_idx[[cmp$control_group]]
          n_ctrl <- if (is.null(control_grp)) 0L else length(control_grp$sample_ids)
          rows[[length(rows) + 1L]] <- tibble::tibble(
            series_id             = sid,
            comparison_id         = cmp$comparison_id,
            treated_group         = cmp$treated_group,
            control_group         = cmp$control_group,
            varying_factor        = cmp$varying_factor %||% NA_character_,
            study_internal_score  = cmp$study_internal_score %||% NA_real_,
            comparability_anchor  = anchor,
            anchor_version        = "v3",
            design_kind           = design$design_kind,
            n_samples_treated     = length(treated_grp$sample_ids),
            n_samples_control     = n_ctrl
          )
        }
      }
      if (length(rows) == 0L) {
        return(tibble::tibble(
          series_id            = character(0),
          comparison_id        = character(0),
          treated_group        = character(0),
          control_group        = character(0),
          varying_factor       = character(0),
          study_internal_score = numeric(0),
          comparability_anchor = character(0),
          anchor_version       = character(0),
          design_kind          = character(0),
          n_samples_treated    = integer(0),
          n_samples_control    = integer(0)
        ))
      }
      dplyr::bind_rows(rows)
    }
  ),

  # ============================================================
  # P3.5-A scaled benchmark (100 GSE freschi paper-ready)
  # ============================================================

  tar_target(
    p35a_gse_csv,
    system.file("extdata", "p35a-gse-selected.csv", package = "simulomicsr"),
    format = "file"
  ),

  tar_target(
    curated_p35a_gse,
    {
      df <- utils::read.csv(p35a_gse_csv, stringsAsFactors = FALSE)
      sort(unique(df$gse_id))
    }
  ),

  tar_target(
    samples_input_p35a,
    {
      full <- read_samples_input(samples_input_path)
      full[full$series_id %in% curated_p35a_gse, ]
    }
  ),

  # Dynamic branching: una invocazione per riga (classify_sample_row riceve
  # tibble di 1 riga). Riusa cache namespace "stage1" per max share.
  tar_target(
    sample_facts_p35a_raw,
    classify_sample_row(
      samples_input_p35a,
      provider = "openai",
      model    = "gpt-5.5",
      cache    = cache_init(stage1_cache_dir, namespace = "stage1")
    ),
    pattern   = map(samples_input_p35a),
    iteration = "list"
  ),

  tar_target(
    sample_facts_p35a_validated,
    {
      validator <- compile_schema(sample_facts_validator)
      keep <- vapply(sample_facts_p35a_raw, function(f) {
        if (!is.null(f$.invalid_reason)) return(FALSE)
        f$.invalid_reason <- NULL
        f$.invalid_detail <- NULL
        validate_json(f, validator = validator)$valid
      }, logical(1))
      sample_facts_p35a_raw[keep]
    }
  ),

  tar_target(
    sample_facts_p35a_invalid,
    {
      validator <- compile_schema(sample_facts_validator)
      drop <- vapply(sample_facts_p35a_raw, function(f) {
        if (!is.null(f$.invalid_reason)) return(TRUE)
        f$.invalid_reason <- NULL
        f$.invalid_detail <- NULL
        !validate_json(f, validator = validator)$valid
      }, logical(1))
      sample_facts_p35a_raw[drop]
    }
  ),

  # Stadio 2 P3.5-A: dynamic-branch su curated_p35a_gse, fetch summary +
  # classify_study insieme (fetch_study_summary cache su disco).
  tar_target(
    study_designs_p35a_raw,
    {
      gse <- curated_p35a_gse
      summary_obj <- fetch_study_summary(
        gse, cache_dir = geo_summary_cache_dir
      )
      facts_list <- Filter(
        function(f) (f$series_id %||% NA_character_) == gse,
        sample_facts_p35a_validated
      )
      if (length(facts_list) == 0L) {
        return(list(
          .invalid_reason = "no_validated_sample_facts",
          series_id = gse
        ))
      }
      classify_study(
        series_id = gse,
        sample_facts_list = facts_list,
        study_summary = summary_obj,
        provider = "openai", model = "gpt-5.5",
        cache = cache_init(stage2_cache_dir, namespace = "stage2")
      )
    },
    pattern = map(curated_p35a_gse),
    iteration = "list"
  ),

  tar_target(
    study_designs_p35a_validated,
    {
      validator <- compile_schema(study_designs_validator)
      keep <- vapply(study_designs_p35a_raw, function(d) {
        if (!is.null(d$.invalid_reason)) return(FALSE)
        d$.invalid_reason <- NULL
        d$.invalid_detail <- NULL
        validate_json(d, validator = validator)$valid
      }, logical(1))
      study_designs_p35a_raw[keep]
    }
  ),

  tar_target(
    study_designs_p35a_invalid,
    {
      validator <- compile_schema(study_designs_validator)
      drop <- vapply(study_designs_p35a_raw, function(d) {
        if (!is.null(d$.invalid_reason)) return(TRUE)
        d$.invalid_reason <- NULL
        d$.invalid_detail <- NULL
        !validate_json(d, validator = validator)$valid
      }, logical(1))
      study_designs_p35a_raw[drop]
    }
  ),

  # Eval P3.5-A: gold join + metrics + RummaGEO

  tar_target(
    gold_table_subset_p35a,
    {
      curated <- curated_p35a_gse
      full_xlsx <- read_samples_input(samples_input_path)
      full_xlsx |>
        dplyr::filter(.data$series_id %in% curated) |>
        dplyr::transmute(
          geo_accession = .data$geo_accession,
          series_id = .data$series_id,
          string = .data$string,
          gold_raw = .data$trtctr_EP,
          gold_binary = dplyr::case_when(
            tolower(.data$trtctr_EP) %in% c("treated") ~ "treated",
            tolower(.data$trtctr_EP) %in% c("control") ~ "control",
            TRUE ~ NA_character_
          )
        )
    }
  ),

  tar_target(
    eval_stage2_p35a_gold_join,
    {
      rows <- list()
      for (design in study_designs_p35a_validated) {
        sid <- design$series_id
        for (g in design$replicate_groups) {
          for (gsm in g$sample_ids) {
            rows[[length(rows) + 1L]] <- tibble::tibble(
              series_id = sid,
              geo_accession = gsm,
              design_role = g$design_role,
              design_kind = design$design_kind,
              predicted_binary = design_role_to_binary(g$design_role)
            )
          }
        }
      }
      pred_df <- dplyr::bind_rows(rows)
      out <- dplyr::left_join(
        pred_df,
        gold_table_subset_p35a[, c("geo_accession", "series_id",
                                    "string", "gold_raw", "gold_binary")],
        by = c("geo_accession", "series_id")
      )
      out
    }
  ),

  tar_target(
    eval_stage2_p35a_metrics,
    {
      list(
        overall = eval_binary_accuracy(
          eval_stage2_p35a_gold_join$gold_binary,
          eval_stage2_p35a_gold_join$predicted_binary
        ),
        per_kind = eval_per_design_kind(eval_stage2_p35a_gold_join),
        granularity = flag_granularity_disagreement(eval_stage2_p35a_gold_join)
      )
    }
  ),

  tar_target(
    rummageo_p35a_signatures,
    {
      out_per_gse <- lapply(curated_p35a_gse, function(gse) {
        sub <- gold_table_subset_p35a[
          gold_table_subset_p35a$series_id == gse, ]
        if (nrow(sub) == 0L) return(NULL)
        labels <- tryCatch({
          data <- fetch_rummageo_signatures(gse, cache_dir = rummageo_cache_dir)
          parsed <- parse_rummageo_labels(data)
          if (nrow(parsed) == 0L) {
            parsed <- rummageo_baseline_internal(sub)
            attr(parsed, "source") <- "internal_fallback_empty_signatures"
          } else {
            attr(parsed, "source") <- "rummageo_official"
          }
          parsed
        }, simulomicsr_rummageo_unavailable = function(e) {
          parsed <- rummageo_baseline_internal(sub)
          attr(parsed, "source") <- "internal_fallback_unavailable"
          parsed
        }, error = function(e) {
          parsed <- rummageo_baseline_internal(sub)
          attr(parsed, "source") <- "internal_fallback_error"
          parsed
        })
        labels$series_id <- gse
        labels$source <- attr(labels, "source") %||% "unknown"
        labels
      })
      dplyr::bind_rows(Filter(Negate(is.null), out_per_gse))
    }
  ),

  tar_target(
    rummageo_p35a_metrics,
    {
      joined <- dplyr::left_join(
        eval_stage2_p35a_gold_join,
        rummageo_p35a_signatures[, c("geo_accession", "series_id",
                                      "rummageo_label", "source")],
        by = c("geo_accession", "series_id")
      )
      list(
        rummageo_vs_gold = eval_binary_accuracy(
          joined$gold_binary, joined$rummageo_label
        ),
        simulomicsr_vs_gold = eval_binary_accuracy(
          joined$gold_binary, joined$predicted_binary
        ),
        rummageo_vs_simulomicsr = eval_binary_accuracy(
          joined$predicted_binary, joined$rummageo_label
        ),
        joined_table = joined,
        source_summary = table(joined$source, useNA = "ifany")
      )
    }
  ),

  # comparisons_table P3.5-A (intra-100 anchor coverage)
  tar_target(
    comparisons_table_p35a,
    {
      rows <- list()
      facts_idx_per_gse <- list()
      for (f in sample_facts_p35a_validated) {
        sid <- f$series_id %||% NA_character_
        if (is.na(sid)) next
        if (is.null(facts_idx_per_gse[[sid]])) facts_idx_per_gse[[sid]] <- list()
        facts_idx_per_gse[[sid]][[f$geo_accession]] <- f
      }
      for (design in study_designs_p35a_validated) {
        sid <- design$series_id
        facts_idx <- facts_idx_per_gse[[sid]] %||% list()
        groups_idx <- list()
        for (g in design$replicate_groups) {
          groups_idx[[g$group_id]] <- g
        }
        for (cmp in design$comparisons) {
          treated_grp <- groups_idx[[cmp$treated_group]]
          if (is.null(treated_grp) || length(treated_grp$sample_ids) == 0L) next
          repr_id <- treated_grp$sample_ids[[1L]]
          repr_facts <- facts_idx[[repr_id]]
          if (is.null(repr_facts)) next
          anchor <- tryCatch(
            make_anchor(repr_facts, stage2_role = treated_grp$design_role),
            error = function(e) NA_character_
          )
          control_grp <- groups_idx[[cmp$control_group]]
          n_ctrl <- if (is.null(control_grp)) 0L else length(control_grp$sample_ids)
          rows[[length(rows) + 1L]] <- tibble::tibble(
            series_id            = sid,
            comparison_id        = cmp$comparison_id,
            treated_group        = cmp$treated_group,
            control_group        = cmp$control_group,
            varying_factor       = cmp$varying_factor %||% NA_character_,
            study_internal_score = cmp$study_internal_score %||% NA_real_,
            comparability_anchor = anchor,
            anchor_version       = "v3",
            design_kind          = design$design_kind,
            n_samples_treated    = length(treated_grp$sample_ids),
            n_samples_control    = n_ctrl
          )
        }
      }
      if (length(rows) == 0L) {
        return(tibble::tibble(
          series_id = character(0), comparison_id = character(0),
          treated_group = character(0), control_group = character(0),
          varying_factor = character(0), study_internal_score = numeric(0),
          comparability_anchor = character(0), anchor_version = character(0),
          design_kind = character(0), n_samples_treated = integer(0),
          n_samples_control = integer(0)
        ))
      }
      dplyr::bind_rows(rows)
    }
  ),

  # GSE145941 reclassify_verbose (P3.5-A Sezione 5 investigation)
  tar_target(
    gse145941_reclassify,
    {
      facts_list <- Filter(
        function(f) (f$series_id %||% NA_character_) == "GSE145941",
        sample_facts_validated
      )
      summary_obj <- fetch_study_summary("GSE145941",
                                          cache_dir = geo_summary_cache_dir)
      reclassify_verbose(
        series_id = "GSE145941",
        sample_facts_list = facts_list,
        study_summary = summary_obj,
        cache = cache_init(stage2_cache_dir, namespace = "stage2_verbose")
      )
    }
  ),

  # Quarto report Task 10
  tarchetypes::tar_render(
    eval_p35a_report,
    here::here("analysis", "eval", "p35a-benchmark.Rmd"),
    output_dir = here::here("analysis", "eval"),
    params = list(
      stage2_metrics       = eval_stage2_p35a_metrics,
      rummageo_metrics     = rummageo_p35a_metrics,
      comparisons_table    = comparisons_table_p35a,
      curated_gse          = curated_p35a_gse,
      gse145941_reclassify = gse145941_reclassify,
      gold_table_subset    = gold_table_subset_p35a
    )
  ),

  # ============================================================
  # P3.5-B eval benchmark sui 15 GSE curated
  # ============================================================

  tar_target(
    gold_table_subset,
    {
      curated <- curated_stage2_gse
      full_xlsx <- read_samples_input(
        here::here("data-raw", "relevant_sample_classified.xlsx")
      )
      full_xlsx %>%
        dplyr::filter(series_id %in% curated) %>%
        dplyr::transmute(
          geo_accession = geo_accession,
          series_id = series_id,
          string = string,
          gold_raw = trtctr_EP,
          gold_binary = dplyr::case_when(
            tolower(trtctr_EP) %in% c("treated") ~ "treated",
            tolower(trtctr_EP) %in% c("control") ~ "control",
            TRUE ~ NA_character_  # outlier non binari (es. specific drug names)
          )
        )
    }
  ),

  tar_target(
    eval_stage2_gold_join,
    {
      rows <- list()
      for (design in study_designs_validated) {
        sid <- design$series_id
        for (g in design$replicate_groups) {
          for (gsm in g$sample_ids) {
            rows[[length(rows) + 1L]] <- tibble::tibble(
              series_id = sid,
              geo_accession = gsm,
              design_role = g$design_role,
              design_kind = design$design_kind,
              predicted_binary = design_role_to_binary(g$design_role)
            )
          }
        }
      }
      pred_df <- dplyr::bind_rows(rows)
      out <- dplyr::left_join(
        pred_df,
        gold_table_subset[, c("geo_accession", "series_id",
                              "string", "gold_raw", "gold_binary")],
        by = c("geo_accession", "series_id")
      )
      out
    }
  ),

  tar_target(
    eval_stage2_metrics,
    {
      list(
        overall = eval_binary_accuracy(
          eval_stage2_gold_join$gold_binary,
          eval_stage2_gold_join$predicted_binary
        ),
        per_kind = eval_per_design_kind(eval_stage2_gold_join),
        granularity = flag_granularity_disagreement(eval_stage2_gold_join)
      )
    }
  ),

  tar_target(
    rummageo_cache_dir,
    fs::dir_create(here::here("analysis", "cache", "rummageo")),
    format = "file"
  ),

  tar_target(
    rummageo_signatures,
    {
      out_per_gse <- lapply(curated_stage2_gse, function(gse) {
        sub <- gold_table_subset[gold_table_subset$series_id == gse, ]
        if (nrow(sub) == 0L) return(NULL)
        labels <- tryCatch({
          data <- fetch_rummageo_signatures(gse, cache_dir = rummageo_cache_dir)
          parsed <- parse_rummageo_labels(data)
          if (nrow(parsed) == 0L) {
            # GSE in API ma signatures vuote -> fallback
            parsed <- rummageo_baseline_internal(sub)
            attr(parsed, "source") <- "internal_fallback_empty_signatures"
          } else {
            attr(parsed, "source") <- "rummageo_official"
          }
          parsed
        }, simulomicsr_rummageo_unavailable = function(e) {
          # GSE non indicizzato in RummaGEO -> fallback interno
          parsed <- rummageo_baseline_internal(sub)
          attr(parsed, "source") <- "internal_fallback_unavailable"
          parsed
        }, error = function(e) {
          # Errore inatteso -> fallback interno
          parsed <- rummageo_baseline_internal(sub)
          attr(parsed, "source") <- "internal_fallback_error"
          parsed
        })
        labels$series_id <- gse
        labels$source <- attr(labels, "source") %||% "unknown"
        labels
      })
      out <- dplyr::bind_rows(Filter(Negate(is.null), out_per_gse))
      out
    }
  ),

  tar_target(
    rummageo_metrics,
    {
      joined <- dplyr::left_join(
        eval_stage2_gold_join,
        rummageo_signatures[, c("geo_accession", "series_id",
                                "rummageo_label", "source")],
        by = c("geo_accession", "series_id")
      )
      list(
        rummageo_vs_gold = eval_binary_accuracy(
          joined$gold_binary, joined$rummageo_label
        ),
        simulomicsr_vs_gold = eval_binary_accuracy(
          joined$gold_binary, joined$predicted_binary
        ),
        rummageo_vs_simulomicsr = eval_binary_accuracy(
          joined$predicted_binary, joined$rummageo_label
        ),
        joined_table = joined,
        source_summary = table(joined$source, useNA = "ifany")
      )
    }
  ),

  # Quarto report finale P3.5-B (Task 8)
  tarchetypes::tar_render(
    eval_p35_report,
    here::here("analysis", "eval", "p35-benchmark.Rmd"),
    output_dir = here::here("analysis", "eval"),
    params = list(
      stage2_metrics   = eval_stage2_metrics,
      rummageo_metrics = rummageo_metrics,
      comparisons_table = comparisons_table,
      curated_gse      = curated_stage2_gse
    )
  ),

  # ---------------------------------------------------------------------------
  tar_target(
    eval_stage1_metrics,
    {
      validity <- stage1_schema_validity_rate(
        sample_facts_validated, sample_facts_invalid
      )
      recall <- stage1_recall_key_fields(sample_facts_validated)
      tibble::tibble(
        n_total              = validity$n_total,
        n_validated          = validity$n_validated,
        n_invalid            = validity$n_invalid,
        validity_rate        = validity$validity_rate,
        n_with_perturbation  = recall$n_with_perturbation,
        n_with_cell_type     = recall$n_with_cell_type,
        recall_perturbation  = recall$recall_perturbation,
        recall_cell_type     = recall$recall_cell_type
      )
    }
  ),

  tarchetypes::tar_render(
    eval_stage1_report,
    here::here("analysis", "eval", "stage1-eval.Rmd"),
    output_dir = here::here("analysis", "eval"),
    params = list(
      metrics   = eval_stage1_metrics,
      validated = sample_facts_validated,
      invalid   = sample_facts_invalid
    )
  ),

  # ===========================================================================
  # P3.5-C: Confidence-aware classification (multi-model + mini-gold)
  # Spec: docs/superpowers/specs/2026-05-04-p3.5c-confidence-aware-design.md
  # ===========================================================================

  tar_target(
    curated_p35c_gse,
    {
      validated <- study_designs_p35a_validated
      kinds <- vapply(validated, function(d) d$design_kind %||% "unclear",
                      character(1))
      sids  <- vapply(validated, function(d) d$series_id, character(1))
      tab <- tibble::tibble(series_id = sids, design_kind = kinds)

      easy_kinds <- c("treatment_vs_vehicle", "dose_response")
      hard_kinds <- c("case_control_disease", "time_course",
                      "treatment_vs_untreated")
      mid_kinds  <- c("factorial", "multi_arm_treatment")

      set.seed(1812)
      take <- function(sub_kinds, n_target) {
        pool <- tab[tab$design_kind %in% sub_kinds, ]
        if (nrow(pool) <= n_target) return(pool$series_id)
        pool$series_id[sample.int(nrow(pool), n_target)]
      }
      selected <- unique(c(
        take(easy_kinds, 15L),
        take(hard_kinds, 15L),
        take(mid_kinds, 10L)
      ))
      remaining <- setdiff(tab$series_id, selected)
      pad_n <- max(0L, 50L - length(selected))
      if (pad_n > 0L && length(remaining) > 0L) {
        pad <- remaining[sample.int(length(remaining), min(pad_n, length(remaining)))]
        selected <- c(selected, pad)
      }
      selected[seq_len(min(50L, length(selected)))]
    }
  ),

  tar_target(
    model_specs_p35c,
    list(
      list(provider = "openai",    model = "gpt-5.5",            label = "gpt_5_5"),
      list(provider = "openai",    model = "gpt-5.4-mini",       label = "gpt_5_4_mini"),
      list(provider = "openai",    model = "gpt-5.4-nano",       label = "gpt_5_4_nano"),
      list(provider = "anthropic", model = "claude-haiku-4-5",   label = "claude_haiku_4_5"),
      list(provider = "anthropic", model = "claude-sonnet-4-6",  label = "claude_sonnet_4_6")
    )
  ),

  # Dynamic branching: fetch study summary per ogni GSE selezionato
  tar_target(
    study_summaries_p35c,
    fetch_study_summary(curated_p35c_gse, cache_dir = geo_summary_cache_dir),
    pattern = map(curated_p35c_gse),
    iteration = "list"
  ),

  tar_target(
    multi_classify_outputs_p35c,
    {
      sids <- curated_p35c_gse
      summaries <- study_summaries_p35c
      names(summaries) <- sids
      sample_facts_by_gse <- split(
        sample_facts_p35a_validated,
        vapply(sample_facts_p35a_validated,
               function(s) s$series_id %||% NA_character_, character(1))
      )

      out <- list()
      for (sid in sids) {
        sf <- sample_facts_by_gse[[sid]] %||% list()
        if (length(sf) == 0L) next
        summary_obj <- summaries[[sid]] %||%
          list(title = "", summary = "", overall_design = "")
        out[[sid]] <- multi_classify_study(
          series_id         = sid,
          sample_facts_list = sf,
          study_summary     = summary_obj,
          model_specs       = model_specs_p35c,
          cache             = cache_init(stage2_cache_dir, namespace = "stage2")
        )
      }
      out
    },
    cue = targets::tar_cue(mode = "thorough")
  )
  ,

  tar_target(
    confidence_scores_p35c,
    {
      out_rows <- list()
      for (sid in names(multi_classify_outputs_p35c)) {
        designs <- multi_classify_outputs_p35c[[sid]]
        pa <- compute_pairwise_agreement(designs)
        score <- aggregate_confidence_score(pa)
        tier  <- assign_difficulty_tier(score)
        out_rows[[sid]] <- tibble::tibble(
          series_id = sid,
          n_pairs = nrow(pa),
          confidence_score = score,
          tier = tier
        )
      }
      dplyr::bind_rows(out_rows)
    }
  ),

  tar_target(
    samples_table_p35c,
    {
      curated <- curated_p35c_gse
      full_xlsx <- read_samples_input(samples_input_path)
      full_xlsx |>
        dplyr::filter(.data$series_id %in% curated) |>
        dplyr::transmute(
          geo_accession = .data$geo_accession,
          series_id = .data$series_id,
          string = .data$string
        )
    }
  ),

  tar_target(
    minigold_pool_p35c,
    {
      set.seed(1812)
      sample_minigold_stratified(
        gse_tiers = confidence_scores_p35c,
        samples_table = samples_table_p35c,
        target_n = 100L,
        # min_gse_per_tier abbassato da 15 a 8: la distribuzione empirica
        # post-run e' easy=9, medium=22, hard=19. 15 era troppo alto per tier easy.
        min_gse_per_tier = 8L
      )
    }
  ),

  tar_target(
    minigold_template_csv_p35c,
    {
      dest <- here::here("analysis", "eval", "p35c-minigold-template.csv")
      summaries <- study_summaries_p35c
      names(summaries) <- curated_p35c_gse
      export_minigold_csv(
        minigold_pool          = minigold_pool_p35c,
        study_summaries        = summaries,
        multi_classify_outputs = multi_classify_outputs_p35c,
        dest_path              = dest
      )
      dest
    },
    format = "file"
  ),

  # Task 12: import del mini-gold reviewato + metriche per modello

  tar_target(
    minigold_reviewed_csv_path_p35c,
    here::here("inst", "extdata", "p35c-minigold-reviewed.csv"),
    format = "file"
  ),

  tar_target(
    minigold_reviewed_p35c,
    import_minigold_reviewed(minigold_reviewed_csv_path_p35c)
  ),

  tar_target(
    eval_p35c_metrics,
    {
      acc <- eval_against_minigold(
        reviewed = minigold_reviewed_p35c,
        multi_classify_outputs = multi_classify_outputs_p35c
      )

      cm_per_model <- lapply(unique(acc$model), function(label) {
        per_sample <- list()
        for (i in seq_len(nrow(minigold_reviewed_p35c))) {
          row <- minigold_reviewed_p35c[i, ]
          d <- multi_classify_outputs_p35c[[row$series_id]][[label]]
          if (is.null(d) || isTRUE(!is.null(d$.invalid_reason))) next
          per_sample[[length(per_sample) + 1L]] <- tibble::tibble(
            kind_gold = row$design_kind_gold,
            kind_pred = d$design_kind %||% NA_character_,
            tier = row$tier,
            correct_kind = identical(d$design_kind, row$design_kind_gold)
          )
        }
        df <- dplyr::bind_rows(per_sample)
        df$model <- label
        df
      })

      list(
        accuracy_table = acc,
        confusion = dplyr::bind_rows(cm_per_model),
        n_reviewed = nrow(minigold_reviewed_p35c)
      )
    }
  )
)
