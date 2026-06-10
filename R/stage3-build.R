# stage3-build.R — orchestrator principale Stadio 3 raggruppamento cross-studio

#' Orchestrator principale di Stadio 3
#'
#' Carica stage1_master + stage2_master, costruisce records dual-mode (pair + group),
#' applica eligibility filter, partiziona per hard_filters, costruisce anchor per
#' L0..L4, raggruppa per anchor_key, calcola safety + usability + metadata, output
#' come \code{stage3_result} S3.
#'
#' @param stage1_master path string o named list (per test) di sample_facts indexed
#'   per GSM.
#' @param stage2_master path string o list di stage2 study records.
#' @param config output di \code{stage3_default_config()}. Custom configs supportati per
#'   override threshold + tier assignment.
#' @param archs4_metadata tibble opzionale (output di \code{load_archs4_metadata()}).
#'   Se NULL, la colonna gpl_platforms e' vuota.
#' @param stage2_input path (o character vector di path) ai file JSONL di input
#'   Stadio 2. Se fornito, attiva il completeness guard chunk-aware
#'   (\code{\link{audit_stage2_coverage}}): ogni sample di input non assegnato a
#'   un replicate_group dallo Stadio 2 viene raccolto in un gruppo sintetico
#'   primary_role='unclear' (inerte al pooling treated/control ma auditabile). Le
#'   statistiche finiscono in \code{run_metadata$output_counts$stage2_completeness}.
#'   Richiede che \code{stage2_master} sia un path JSONL (serve il record_id del
#'   chunk). Passare l'union di input + rescue (resplit cs25, cascade) per copertura
#'   piena. Default NULL = nessun guard (comportamento legacy).
#' @return \code{stage3_result} S3 object (list con 5 componenti: \code{assignments},
#'   \code{clusters}, \code{record_summary}, \code{non_clusterable},
#'   \code{run_metadata}).
#' @export
build_stage3_clusters <- function(stage1_master,
                                   stage2_master,
                                   config = stage3_default_config(),
                                   archs4_metadata = NULL,
                                   stage2_input = NULL) {
  ta         <- config$tier_assignment
  thresholds <- config$thresholds
  cli::cli_inform("[stage3] START build_stage3_clusters at {format(Sys.time())}")

  # 1. Caricamento input se path
  if (is.character(stage1_master)) {
    cli::cli_inform("[stage3] Phase 1a: load stage1_master from {stage1_master}")
    stage1_master <- .load_stage1_master(stage1_master)
  }
  # 1b. Caricamento stage2 -> riassemblaggio chunk (un record per series) ->
  # (opzionale) completeness guard per-studio.
  if (is.character(stage2_master)) {
    cli::cli_inform("[stage3] Phase 1b: load stage2_master from {stage2_master}")
    stage2_master <- .load_stage2_master(stage2_master)
  }
  # Guard invariante (opzione C, ADR-0020): lo Stadio 2 v3 produce UN record per
  # studio. Se compaiono series_id duplicati (input chunked inatteso) fallisce
  # rumorosamente invece di riassemblare in silenzio nel modo sbagliato (la
  # vecchia .reassemble_stage2_chunks perdeva i confronti cross-chunk, finding
  # 2026-06-01). Stesso guard in build_stage4_results().
  stage2_master <- .assert_stage2_one_record_per_series(stage2_master)

  # Completeness guard (FASE F4 Step 2): ogni sample di input non coperto dai
  # replicate_groups Stadio 2 (violazione REGOLA 4, ~3.5% nel benchmark F2)
  # viene raccolto in un gruppo sintetico primary_role='unclear' (esplicito e
  # auditabile). Per-studio.
  stage2_completeness <- NULL
  if (!is.null(stage2_input)) {
    input_by_series <- .build_stage2_input_lookup(stage2_input)
    guard <- .apply_stage2_completeness_by_series(stage2_master, input_by_series)
    stage2_master <- guard$records
    stage2_completeness <- c(guard$report, list(n_input_files = length(stage2_input)))
    cli::cli_inform("[stage3] completeness guard: {guard$report$n_uncovered_total} sample non coperti -> 'unclear' su {guard$report$n_records_affected} studi")
  }
  cli::cli_inform("[stage3] Phase 1 done: {length(stage1_master)} stage1 + {length(stage2_master)} stage2 records loaded")

  # 1.5 Converti stage1_master list -> environment per lookup O(1) via hash.
  # FIX perf critico: R list[[name]] su list grandi (>100k) e' O(N) scan, non
  # O(1) hash. Su 879k samples = 4.6ms/lookup. Environment = vero hash O(1),
  # ~0.05ms/lookup (80x speedup).
  if (is.list(stage1_master) && !is.environment(stage1_master)) {
    cli::cli_inform("[stage3] Phase 1.5: convert stage1_master list -> environment for O(1) lookup")
    s1_env <- new.env(hash = TRUE, size = length(stage1_master))
    list2env(stage1_master, envir = s1_env)
    stage1_master <- s1_env
    rm(s1_env)
    cli::cli_inform("[stage3] Phase 1.5 done")
  }

  # 2.0 Pre-compute anchor cache per i sample_id referenziati in stage2_master.
  # FIX perf: senza cache .extract_anchor_segments() viene chiamata ~1M volte
  # (heavy function). Con cache, una sola estrazione per (sample_id, role).
  cli::cli_inform("[stage3] Phase 2.0: pre-compute anchor cache")
  cache <- .precompute_anchor_cache(stage2_master, stage1_master, ta)
  cli::cli_inform("[stage3] Phase 2.0 done: cached {length(cache$anchors)} (sample_id, role) anchors + {length(cache$hard_filters)} hard_filters")

  # 2. Costruzione records dual-mode
  cli::cli_inform("[stage3] Phase 2: build pair+group records")
  records_pair  <- .build_pair_records(stage2_master, stage1_master, ta, cache)
  records_group <- .build_group_records(stage2_master, stage1_master, ta, cache)
  cli::cli_inform("[stage3] Phase 2 done: {length(records_pair)} pair + {length(records_group)} group records")

  # 3. Eligibility filter
  cli::cli_inform("[stage3] Phase 3: eligibility filter")
  pair_filt  <- .filter_eligible_records(records_pair)
  group_filt <- .filter_eligible_records(records_group)
  cli::cli_inform("[stage3] Phase 3 done: pair eligible={length(pair_filt$eligible)} non_clust={length(pair_filt$non_clusterable)}; group eligible={length(group_filt$eligible)} non_clust={length(group_filt$non_clusterable)}")

  # 4. Direction check (pair only) + scarta ambiguous/indeterminate
  if (length(pair_filt$eligible) > 0L) {
    pair_filt$eligible <- .annotate_direction(pair_filt$eligible)
    bad_dir <- vapply(pair_filt$eligible, function(r) {
      isTRUE(r$direction_check %in% c("ambiguous", "indeterminate"))
    }, logical(1L))
    if (any(bad_dir)) {
      for (r in pair_filt$eligible[bad_dir]) {
        pair_filt$non_clusterable[[length(pair_filt$non_clusterable) + 1L]] <- list(
          record_id = r$record_id,
          mode      = "pair",
          reason    = sprintf("direction_%s", r$direction_check),
          details   = sprintf("control_type=%s", r$control_type %||% "unknown")
        )
      }
      pair_filt$eligible <- pair_filt$eligible[!bad_dir]
    }
  }

  # 5. Hard filter partition + clustering per L0..L4 per mode
  cli::cli_inform("[stage3] Phase 5: anchor key build + cluster assignment (5 levels x 2 modes)")
  assignments_all <- list()
  for (mode in c("pair", "group")) {
    eligible <- if (identical(mode, "pair")) pair_filt$eligible else group_filt$eligible
    if (length(eligible) == 0L) next
    parts <- .partition_by_hard_filters(eligible)
    cli::cli_inform("[stage3]   mode={mode}: {length(eligible)} eligible records in {length(parts)} hard-filter partitions")
    for (L in 0L:4L) {
      L_start <- Sys.time()
      for (part in parts) {
        if (length(part) == 0L) next
        # Aggiungi anchor_key per ogni record della partizione al livello L
        part_with_keys <- lapply(part, function(r) {
          if (identical(mode, "pair")) {
            tk <- .build_anchor_key_from_segments(r$treated_anchor_segments, ta, L)
            ck <- .build_anchor_key_from_segments(r$control_anchor_segments, ta, L)
            # L0 e L1: includi control_type nell'anchor key (discriminante biologico)
            r$anchor_key <- if (L %in% c(0L, 1L)) {
              sprintf("%s__VS__%s__CT_%s", tk, ck, r$control_type %||% "unknown")
            } else {
              sprintf("%s__VS__%s", tk, ck)
            }
          } else {
            # group: usa treated_anchor_segments (alias di anchor_segments per group)
            r$anchor_key <- .build_anchor_key_from_segments(
              r$treated_anchor_segments, ta, L
            )
          }
          r
        })
        asg <- .assign_records_to_clusters(part_with_keys, mode, L)
        assignments_all[[length(assignments_all) + 1L]] <- asg
      }
      cli::cli_inform("[stage3]   mode={mode} L{L} done in {round(as.numeric(difftime(Sys.time(), L_start, units = 'secs')), 1)}s")
    }
  }

  # Unione assignments (base R: do.call(rbind, ...) su tibble)
  cli::cli_inform("[stage3] Phase 5 done: combining {length(assignments_all)} assignment chunks")
  assignments <- if (length(assignments_all) > 0L) {
    do.call(rbind, assignments_all)
  } else {
    tibble::tibble(
      record_id  = character(),
      mode       = character(),
      level      = integer(),
      cluster_id = character(),
      anchor_key = character()
    )
  }
  # Assicura tibble
  if (!inherits(assignments, "tbl_df")) {
    assignments <- tibble::as_tibble(assignments)
  }

  # 6. Per ogni cluster_id, calcola summary (k, n_total, safety, metadata, usability)
  cli::cli_inform("[stage3] Phase 6: summarize_clusters ({nrow(assignments)} assignments -> ~clusters)")
  clusters <- .summarize_clusters(
    assignments     = assignments,
    eligible_pair   = pair_filt$eligible,
    eligible_group  = group_filt$eligible,
    config          = config,
    archs4_metadata = archs4_metadata,
    stage1_master   = stage1_master  # E0: per .build_donor_lookup
  )
  cli::cli_inform("[stage3] Phase 6 done: {nrow(clusters)} clusters summarized")

  # 7. Record summary
  cli::cli_inform("[stage3] Phase 7: build_record_summary")
  record_summary <- .build_record_summary(assignments, clusters)
  cli::cli_inform("[stage3] Phase 7 done: {nrow(record_summary)} record_summary rows")

  # 8. Non clusterable (consolidata: pair + group)
  nc_items <- c(pair_filt$non_clusterable, group_filt$non_clusterable)
  nc <- if (length(nc_items) > 0L) {
    # Converti ogni list item in tibble row e unisci
    rows <- lapply(nc_items, function(item) {
      tibble::tibble(
        record_id = item$record_id  %||% NA_character_,
        mode      = item$mode       %||% NA_character_,
        reason    = item$reason     %||% NA_character_,
        details   = item$details    %||% NA_character_
      )
    })
    do.call(rbind, rows)
  } else {
    tibble::tibble(
      record_id = character(),
      mode      = character(),
      reason    = character(),
      details   = character()
    )
  }
  if (!inherits(nc, "tbl_df")) nc <- tibble::as_tibble(nc)

  # 9. Run metadata + run_id deterministico
  run_metadata <- .build_run_metadata(
    stage1_master_summary = list(n_records = length(stage1_master)),
    stage2_master_summary = list(n_records = length(stage2_master)),
    config = config,
    output_counts = list(
      n_records_input_stage2       = length(stage2_master),
      n_records_clusterable_pair   = length(pair_filt$eligible),
      n_records_clusterable_group  = length(group_filt$eligible),
      n_non_clusterable_records    = nrow(nc),
      n_assignments_total          = nrow(assignments),
      n_clusters_per_level = list(
        pair  = .count_clusters_per_level(clusters, "pair"),
        group = .count_clusters_per_level(clusters, "group")
      ),
      stage2_completeness = stage2_completeness
    )
  )

  structure(
    list(
      assignments     = assignments,
      clusters        = clusters,
      record_summary  = record_summary,
      non_clusterable = nc,
      run_metadata    = run_metadata
    ),
    class = "stage3_result"
  )
}

# --- Helper interni -----------------------------------------------------------

#' Costruisce anchor_key da segments pre-estratti a un dato livello L
#'
#' Equivalente a \code{.build_anchor_for_level()} ma opera su segments gia' estratti
#' invece che su stage1_facts (evita ri-estrazione costosa in loop di clustering).
#'
#' Mantiene l'ordine canonical dei segmenti (identico a names(segments) dall'output
#' di \code{.extract_anchor_segments()}) applicando la stessa logica di drop per tier.
#'
#' @keywords internal
.build_anchor_key_from_segments <- function(segments, tier_assignment, level) {
  stopifnot(level %in% 0L:4L)
  if (level == 4L) {
    # L4: solo Tier S -- usa l'ordine canonical da names(segments) (NON sort
    # alphabetical) per garantire identita' con .build_anchor_for_level()
    kept_names <- names(segments)[names(segments) %in% tier_assignment$S]
  } else {
    # L0-L3: tutti i segmenti meno quelli droppati per livello
    dropped <- .dropped_segments_at_level(tier_assignment, level)
    kept_names <- names(segments)[!names(segments) %in% dropped]
  }
  values <- vapply(kept_names, function(s) as.character(segments[[s]]), character(1L))
  paste(values, collapse = "|")
}

#' Conta cluster distinti per livello L (vettore named da L0 a L4)
#' @keywords internal
.count_clusters_per_level <- function(clusters, mode) {
  if (nrow(clusters) == 0L) {
    return(setNames(rep(0L, 5L), sprintf("L%d", 0L:4L)))
  }
  cl_mode <- clusters[clusters$mode == mode, ]
  if (nrow(cl_mode) == 0L) {
    return(setNames(rep(0L, 5L), sprintf("L%d", 0L:4L)))
  }
  tbl <- table(factor(cl_mode$level, levels = 0L:4L))
  setNames(as.integer(tbl), sprintf("L%d", 0L:4L))
}

#' Pre-computa cache di anchor segments + hard_filters per sample_id referenziati
#'
#' Visita stage2_master, raccoglie tutti i (sample_id, role) tuple necessari
#' (sample = first di ogni replicate_group; role = "treated"/"control" per
#' comparisons, role per primary_role per group records), e pre-computa ogni
#' anchor segments UNA volta sola.
#'
#' Senza cache, build_pair_records + build_group_records chiamano
#' \code{.extract_anchor_segments()} ~1M volte (la stessa funzione, sugli
#' stessi sample). La cache riduce a ~unique(sample_id) chiamate.
#'
#' @return list con \code{anchors} (named list: key "sample_id|role" -> segments)
#'   e \code{hard_filters} (named list: key sample_id -> {subcellular, context_kind})
#' @keywords internal
.precompute_anchor_cache <- function(stage2_master, stage1_master, tier_assignment) {
  # FIX perf v2: usa lapply/unlist (no list growth O(N^2)). Collect tutte le
  # tuple via lapply per-study, poi flatten + dedup vettorialmente.

  # Per ogni study, costruisce vettore character "sample_id|role" per tutti i
  # tuple necessari (group records + pair records treated + pair records control).
  per_study_keys <- lapply(stage2_master, function(study) {
    rg_lookup <- setNames(
      study$replicate_groups,
      vapply(study$replicate_groups, function(g) g$group_id, character(1L))
    )

    # Group keys (uno per replicate_group con sample_ids non vuoto)
    group_keys <- vapply(study$replicate_groups, function(rg) {
      if (length(rg$sample_ids) == 0L) return(NA_character_)
      sid_sample <- rg$sample_ids[[1L]]
      role <- switch(
        rg$primary_role %||% "unclear",
        treated   = "treated",
        control   = "control",
        bystander = "treated",
        excluded  = "treated",
        unclear   = "treated",
        "treated"
      )
      sprintf("%s|%s", sid_sample, role)
    }, character(1L))
    group_keys <- group_keys[!is.na(group_keys)]

    # Pair keys (due per comparison: treated + control)
    pair_keys <- unlist(lapply(study$comparisons, function(cmp) {
      tg <- rg_lookup[[cmp$treated_group]]
      cg <- rg_lookup[[cmp$control_group]]
      if (is.null(tg) || is.null(cg)) return(character())
      c(
        sprintf("%s|treated", tg$sample_ids[[1L]]),
        sprintf("%s|control", cg$sample_ids[[1L]])
      )
    }), use.names = FALSE)
    if (is.null(pair_keys)) pair_keys <- character()

    c(group_keys, pair_keys)
  })

  all_keys <- unlist(per_study_keys, use.names = FALSE)
  if (is.null(all_keys)) all_keys <- character()
  unique_keys <- unique(all_keys)
  if (length(unique_keys) == 0L) {
    return(list(anchors = new.env(hash = TRUE, parent = emptyenv()),
                hard_filters = new.env(hash = TRUE, parent = emptyenv())))
  }

  # Anchors come ENVIRONMENT per O(1) lookup downstream (~315k entries).
  # Stesso motivo del fix stage1_master env: list[[name]] su 300k+ entries = O(N).
  anchors <- new.env(hash = TRUE, size = length(unique_keys), parent = emptyenv())
  for (key in unique_keys) {
    parts <- strsplit(key, "|", fixed = TRUE)[[1L]]
    sid   <- parts[1L]
    role  <- parts[2L]
    facts <- stage1_master[[sid]]
    if (is.null(facts)) next
    assign(key, .extract_anchor_segments(facts, stage2_role = role), envir = anchors)
  }

  # Hard filters per ogni unique sample_id (no dipendenza da role) come ENV.
  unique_sample_ids <- unique(vapply(strsplit(unique_keys, "|", fixed = TRUE),
                                       function(p) p[1L], character(1L)))
  hard_filters <- new.env(hash = TRUE, size = length(unique_sample_ids),
                          parent = emptyenv())
  for (sid in unique_sample_ids) {
    facts <- stage1_master[[sid]]
    if (is.null(facts)) next
    assign(sid, .extract_hard_filters(facts, tier_assignment), envir = hard_filters)
  }

  list(anchors = anchors, hard_filters = hard_filters)
}

#' Costruisce records pair-mode da stage2 comparisons
#'
#' Per ogni comparison nello stage2_master, cerca i replicate_groups corrispondenti
#' e costruisce un record con treated/control anchor segments + hard_filters.
#' Usa il primo sample di ogni group come rappresentativo per l'estrazione dell'anchor
#' (future v2: validazione omogeneita' intra-group).
#'
#' @param cache opzionale: output di \code{.precompute_anchor_cache()}. Se fornito,
#'   evita chiamate ripetute a \code{.extract_anchor_segments()} per sample
#'   gia' visti. Big perf win.
#' @keywords internal
.build_pair_records <- function(stage2_master, stage1_master, tier_assignment, cache = NULL) {
  records <- list()
  for (study in stage2_master) {
    sid <- study$series_id
    rg_lookup <- setNames(
      study$replicate_groups,
      vapply(study$replicate_groups, function(g) g$group_id, character(1L))
    )
    for (cmp in study$comparisons) {
      tg <- rg_lookup[[cmp$treated_group]]
      cg <- rg_lookup[[cmp$control_group]]
      if (is.null(tg) || is.null(cg)) next  # comparison malformata: skip

      tg_sample <- tg$sample_ids[[1L]]
      cg_sample <- cg$sample_ids[[1L]]

      tg_facts <- stage1_master[[tg_sample]]
      cg_facts <- stage1_master[[cg_sample]]
      if (is.null(tg_facts) || is.null(cg_facts)) next  # GSM non in stage1: skip

      # Usa cache se disponibile, altrimenti fallback a estrazione live
      t_segs <- if (!is.null(cache)) cache$anchors[[sprintf("%s|treated", tg_sample)]]
                else .extract_anchor_segments(tg_facts, stage2_role = "treated")
      c_segs <- if (!is.null(cache)) cache$anchors[[sprintf("%s|control", cg_sample)]]
                else .extract_anchor_segments(cg_facts, stage2_role = "control")

      # Hard filters: estratti dal treated group (canonical per la partizione)
      hf <- if (!is.null(cache)) cache$hard_filters[[tg_sample]]
            else .extract_hard_filters(tg_facts, tier_assignment)

      records[[length(records) + 1L]] <- list(
        record_id               = sprintf("%s__%s", sid, cmp$comparison_id),
        mode                    = "pair",
        series_id               = sid,
        comparison_id           = cmp$comparison_id,
        treated_anchor_segments = t_segs,
        control_anchor_segments = c_segs,
        n_treated_group         = length(tg$sample_ids),
        n_control_group         = length(cg$sample_ids),
        # FASE E0 ADR-0019 D9: GSM list esposta a livello record per
        # consentire sample-level dedupe BioSample SAMN + fix
        # n_distinct_donors sample-level in .enrich_cluster_metadata().
        treated_sample_ids      = as.character(tg$sample_ids),
        control_sample_ids      = as.character(cg$sample_ids),
        control_type            = cmp$control_type,
        hard_filters            = hf,
        stage1_facts            = tg_facts  # per donor extraction in metadata
      )
    }
  }
  records
}

#' Costruisce records group-mode da stage2 replicate_groups
#'
#' Un record per ogni replicate_group. usa il primo sample come rappresentativo.
#' I record group-mode espongono \code{treated_anchor_segments} (come pair-mode)
#' per compatibilita' con \code{.filter_eligible_records()}.
#'
#' @param cache opzionale: output di \code{.precompute_anchor_cache()}.
#' @keywords internal
.build_group_records <- function(stage2_master, stage1_master, tier_assignment, cache = NULL) {
  records <- list()
  for (study in stage2_master) {
    sid <- study$series_id
    for (rg in study$replicate_groups) {
      if (length(rg$sample_ids) == 0L) next
      first_sample <- rg$sample_ids[[1L]]
      facts <- stage1_master[[first_sample]]
      if (is.null(facts)) next

      # Per group-mode: usa primary_role come stage2_role surrogate per extract
      role_for_anchor <- switch(
        rg$primary_role %||% "unclear",
        treated    = "treated",
        control    = "control",
        bystander  = "treated",
        excluded   = "treated",
        unclear    = "treated",
        "treated"
      )
      segs <- if (!is.null(cache))
                cache$anchors[[sprintf("%s|%s", first_sample, role_for_anchor)]]
              else
                .extract_anchor_segments(facts, stage2_role = role_for_anchor)
      hf <- if (!is.null(cache)) cache$hard_filters[[first_sample]]
            else .extract_hard_filters(facts, tier_assignment)

      records[[length(records) + 1L]] <- list(
        record_id               = sprintf("%s__%s", sid, rg$group_id),
        mode                    = "group",
        series_id               = sid,
        group_id                = rg$group_id,
        treated_anchor_segments = segs,  # nome uniforme per filter_eligible_records
        n_treated_group         = length(rg$sample_ids),
        n_control_group         = length(rg$sample_ids),  # placeholder group
        # FASE E0 ADR-0019 D9: GSM list esposta a livello record. Per group-mode
        # non esiste un control side semantico -> character(0), no NA fittizio.
        treated_sample_ids      = as.character(rg$sample_ids),
        control_sample_ids      = character(0),
        hard_filters            = hf,
        stage1_facts            = facts
      )
    }
  }
  records
}

#' Annota records pair con direction_check
#' @keywords internal
.annotate_direction <- function(records_pair) {
  lapply(records_pair, function(r) {
    r$direction_check <- .check_direction_canonical(
      r$treated_anchor_segments,
      r$control_anchor_segments,
      r$control_type
    )
    r
  })
}

#' Riassume cluster (k, n_total, safety, metadata, usability) da assignments
#'
#' Per ogni cluster_id univoco in assignments, calcola: k (studi distinti), n_total,
#' safety, metadata enrichment, usability flags.
#'
#' @keywords internal
.summarize_clusters <- function(assignments, eligible_pair, eligible_group,
                                 config, archs4_metadata,
                                 stage1_master = NULL) {
  # Schema vuoto canonico per cluster tibble. Anchor v3.1 (ADR-0018) aggiunge
  # 11 colonne tracking + v3.1.1 (S1bis 2026-05-25) aggiunge 12a colonna
  # kind_chebi_zero_roles per Layer B shortlist filter (CHEBI compound esiste
  # ma 0 has_role: legit Resiquimod/poly(I:C) vs ambiguo dihydroxyphthalic).
  # FASE E0 (ADR-0019 D9) aggiunge n_distinct_biosamples per dedupe SAMN.
  empty_clusters <- tibble::tibble(
    cluster_id                  = character(),
    mode                        = character(),
    level                       = integer(),
    anchor_key                  = character(),
    k                           = integer(),
    n_total                     = integer(),
    n_treated                   = integer(),
    n_control                   = integer(),
    safety_min                  = numeric(),
    safety_geom_mean            = numeric(),
    safety_per_segment          = list(),
    usable_rem_strict           = logical(),
    usable_rem_relaxed          = logical(),
    usable_mega_strict          = logical(),
    usable_mega_relaxed         = logical(),
    direction_check             = character(),
    gpl_platforms               = list(),
    n_gpl_distinct              = integer(),
    n_distinct_donors           = integer(),
    n_distinct_biosamples       = integer(),
    studies_in_cluster          = list(),
    n_studies                   = integer(),
    # Anchor v3.1 tracking columns
    agent_id_llm_original       = character(),
    agent_id_resolved           = character(),
    resolution_source           = character(),
    canonical_name              = character(),
    kind_effective_llm_original = character(),
    kind_effective_resolved     = character(),
    kind_overridden             = logical(),
    kind_override_reason        = character(),
    kind_role_evidence          = character(),
    kind_confidence             = character(),
    kind_unvalidatable          = logical(),
    # Anchor v3.1.1 tracking column (S1bis ADR-0018 addendum)
    kind_chebi_zero_roles       = logical()
  )

  if (nrow(assignments) == 0L) return(empty_clusters)

  ta <- config$tier_assignment

  # Lookup veloce record_id -> record. Usa environment per O(1) hash lookup
  # (record_id list potrebbe avere ~40k+ entries; list[[name]] su 40k = ~0.2ms,
  # su 400k+ = ~2ms; env e' costante <0.05ms).
  pair_lookup  <- new.env(hash = TRUE,
                          size = max(1L, length(eligible_pair)),
                          parent = emptyenv())
  for (r in eligible_pair) assign(r$record_id, r, envir = pair_lookup)
  group_lookup <- new.env(hash = TRUE,
                          size = max(1L, length(eligible_group)),
                          parent = emptyenv())
  for (r in eligible_group) assign(r$record_id, r, envir = group_lookup)

  # Pre-build GPL lookup UNA volta (split su series_id) per evitare O(N) scan
  # di archs4_metadata in ogni iterazione del loop su cluster.
  gpl_lookup <- .build_gpl_lookup(archs4_metadata)

  # FASE E0 ADR-0019 D9: pre-build BioSample SAMN lookup geo_accession -> SAMN
  # + donor_id lookup geo_accession -> donor_id, entrambi una sola volta.
  # Usati da .enrich_cluster_metadata() per (a) calcolo n_distinct_biosamples
  # sample-level (NEW), (b) fix sotto-stima n_distinct_donors sample-level
  # (pre-E0 contava primo sample del record).
  biosample_lookup <- .build_biosample_lookup(archs4_metadata)
  donor_lookup     <- .build_donor_lookup(stage1_master)

  # Pre-split assignments per cluster_id UNA volta (split su row index): evita
  # O(N) scan di assignments per ogni cluster nel loop (era O(N^2) globale).
  # Con ~390k cluster x ~390k row scan = ~150 miliardi di confronti.
  cluster_row_idx <- split(seq_len(nrow(assignments)), assignments$cluster_id)
  unique_clids <- names(cluster_row_idx)

  cli::cli_inform(
    "Summarizing {.val {length(unique_clids)}} clusters at {format(Sys.time())}"
  )
  progress_every <- max(1L, length(unique_clids) %/% 20L)  # ~5% steps

  rows <- vector("list", length(unique_clids))

  for (i in seq_along(unique_clids)) {
    cl_id   <- unique_clids[i]
    cl_rows <- assignments[cluster_row_idx[[cl_id]], , drop = FALSE]
    mode       <- cl_rows$mode[1L]
    level      <- cl_rows$level[1L]
    anchor_key <- cl_rows$anchor_key[1L]

    member_records <- if (identical(mode, "pair")) {
      mget(cl_rows$record_id, envir = pair_lookup, ifnotfound = list(NULL))
    } else {
      mget(cl_rows$record_id, envir = group_lookup, ifnotfound = list(NULL))
    }
    # Rimuove NULL (record non trovati nel lookup -- non dovrebbe accadere)
    member_records <- member_records[!vapply(member_records, is.null, logical(1L))]

    # k = studi distinti
    studies <- unique(vapply(member_records, function(r) r$series_id, character(1L)))
    k       <- length(studies)

    # Conteggi sample
    n_treated <- sum(vapply(member_records, function(r) {
      as.integer(r$n_treated_group)
    }, integer(1L)))

    if (identical(mode, "pair")) {
      n_control <- sum(vapply(member_records, function(r) {
        as.integer(r$n_control_group)
      }, integer(1L)))
      n_total <- n_treated + n_control
    } else {
      n_control <- NA_integer_
      n_total   <- n_treated
    }

    # Safety: segmenti droppati a questo livello
    dropped_segs <- .dropped_segments_at_level(ta, level)
    safety_inputs <- lapply(member_records, function(r) r$treated_anchor_segments)
    safety        <- .compute_pooling_safety(safety_inputs, dropped_segs)

    # Metadata enrichment (GPL + donors + studies + biosamples E0)
    meta <- .enrich_cluster_metadata(
      member_records,
      archs4_metadata  = NULL,  # ignorato a favore di gpl_lookup pre-built
      gpl_lookup       = gpl_lookup,
      biosample_lookup = biosample_lookup,
      donor_lookup     = donor_lookup
    )

    # Direction check (pair only: primo record, tutti gli eligibili sono omogenei)
    direction_check <- if (identical(mode, "pair") && length(member_records) > 0L)
                         member_records[[1L]]$direction_check %||% NA_character_
                       else
                         NA_character_

    # Usability flags
    cluster_row_for_usability <- list(
      mode       = mode,
      level      = level,
      k          = k,
      n_total    = n_total,
      n_studies  = meta$n_studies,
      safety_min = safety$safety_min
    )
    usability <- .tag_cluster_usability(cluster_row_for_usability, config$thresholds)

    # Anchor v3.1 tracking (ADR-0018): estrai dal primo member record.
    # I record nello stesso cluster condividono lo stesso agent_id_resolved e
    # kind_effective_resolved per costruzione dell'anchor_key; l'agent_id_llm_original
    # puo' variare leggermente tra LLM emits che canonicalizzano al medesimo
    # canonical_id -- preserviamo il primo per audit deterministico.
    first_tracking <- if (length(member_records) > 0L) {
      attr(member_records[[1L]]$treated_anchor_segments, "tracking_meta")
    } else NULL
    tm_chr <- function(name, default = NA_character_) {
      if (is.null(first_tracking)) return(default)
      v <- first_tracking[[name]]
      if (is.null(v) || length(v) == 0L) return(default)
      if (is.na(v)) return(default)
      as.character(v)
    }
    tm_lgl <- function(name) {
      if (is.null(first_tracking)) return(NA)
      v <- first_tracking[[name]]
      if (is.null(v) || length(v) == 0L) return(NA)
      if (is.na(v)) return(NA)
      isTRUE(as.logical(v))
    }

    rows[[i]] <- tibble::tibble(
      cluster_id                  = cl_id,
      mode                        = mode,
      level                       = level,
      anchor_key                  = anchor_key,
      k                           = k,
      n_total                     = n_total,
      n_treated                   = n_treated,
      n_control                   = n_control,
      safety_min                  = safety$safety_min,
      safety_geom_mean            = safety$safety_geom_mean,
      safety_per_segment          = list(safety$safety_per_segment),
      usable_rem_strict           = usability$usable_rem_strict,
      usable_rem_relaxed          = usability$usable_rem_relaxed,
      usable_mega_strict          = usability$usable_mega_strict,
      usable_mega_relaxed         = usability$usable_mega_relaxed,
      direction_check             = direction_check,
      gpl_platforms               = list(meta$gpl_platforms),
      n_gpl_distinct              = meta$n_gpl_distinct,
      n_distinct_donors           = meta$n_distinct_donors,
      # FASE E0 ADR-0019 D9: BioSample SAMN unique sample-level dedupe
      n_distinct_biosamples       = meta$n_distinct_biosamples,
      studies_in_cluster          = list(meta$studies_in_cluster),
      n_studies                   = meta$n_studies,
      # Anchor v3.1 tracking columns (paper-grade audit, ADR-0018)
      agent_id_llm_original       = tm_chr("agent_id_llm_original"),
      agent_id_resolved           = tm_chr("agent_id_resolved"),
      resolution_source           = tm_chr("resolution_source"),
      canonical_name              = tm_chr("canonical_name"),
      kind_effective_llm_original = tm_chr("kind_effective_llm_original"),
      kind_effective_resolved     = tm_chr("kind_effective_resolved"),
      kind_overridden             = tm_lgl("kind_overridden"),
      kind_override_reason        = tm_chr("kind_override_reason"),
      kind_role_evidence          = tm_chr("kind_role_evidence"),
      kind_confidence             = tm_chr("kind_confidence"),
      kind_unvalidatable          = tm_lgl("kind_unvalidatable"),
      kind_chebi_zero_roles       = tm_lgl("kind_chebi_zero_roles")
    )

    if (i %% progress_every == 0L || i == length(unique_clids)) {
      cli::cli_inform(
        "  ...cluster {i}/{length(unique_clids)} ({round(100*i/length(unique_clids))}%) at {format(Sys.time())}"
      )
    }
  }

  cli::cli_inform("Combining {.val {length(rows)}} cluster rows at {format(Sys.time())}")
  result <- do.call(rbind, rows)
  if (is.null(result)) return(empty_clusters)
  if (!inherits(result, "tbl_df")) result <- tibble::as_tibble(result)
  result
}

#' Costruisce run_metadata con run_id deterministico (xxhash32)
#'
#' Il run_id e' derivato da un JSON canonico dei parametri di input + config.
#' Stesso input + stessa config -> stesso run_id (idempotenza).
#'
#' @keywords internal
.build_run_metadata <- function(stage1_master_summary, stage2_master_summary,
                                 config, output_counts) {
  # Anchor v3.1 (ADR-0018): registra ontology_releases meta nel run_metadata
  # per riproducibilita' paper-grade. Lookup safe (NULL se ontology env non
  # ancora caricato -- improbabile dopo build_stage3_clusters ma defensive).
  ontology_releases <- tryCatch(
    .ontology_release_meta(),
    error = function(e) NULL
  )

  # Forma canonica deterministica: JSON dei parametri chiave
  canon <- jsonlite::toJSON(
    list(
      s1     = stage1_master_summary,
      s2     = stage2_master_summary,
      schema = config$schema_versions,
      thresholds = config$thresholds,
      tier   = config$tier_assignment
    ),
    auto_unbox = TRUE
  )
  run_id <- substr(digest::digest(as.character(canon), algo = "xxhash32"), 1L, 8L)

  list(
    run_id            = run_id,
    timestamp         = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    schema_versions   = config$schema_versions,
    package_version   = as.character(utils::packageVersion("simulomicsr")),
    r_version         = R.version.string,
    input_files       = list(
      stage1_master = stage1_master_summary,
      stage2_master = stage2_master_summary
    ),
    config            = config,
    output_counts     = output_counts,
    ontology_releases = ontology_releases
  )
}

#' Carica stage1 master JSONL in named list indicizzata per GSM
#'
#' Ogni linea del JSONL deve avere campo \code{geo_accession} o \code{sample_id}
#' come chiave dell'elemento risultante.
#'
#' @keywords internal
.load_stage1_master <- function(path) {
  if (!file.exists(path)) stop("stage1_master path non esiste: ", path)
  lines  <- readLines(path, warn = FALSE)
  rows   <- lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)
  # Ogni riga JSONL e' list(record_id=..., parsed_json=list(geo_accession=..., ...), ...)
  # Estraiamo il parsed_json (sample_facts.stage1.v3) indicizzato per GSM
  parsed <- lapply(rows, function(r) {
    if (!is.null(r$parsed_json)) r$parsed_json else r
  })
  keys <- vapply(parsed, function(p) {
    p$geo_accession %||% p$sample_id %||% p$key %||% NA_character_
  }, character(1L))
  setNames(parsed, keys)
}

#' Carica stage2 master da RDS o JSONL
#'
#' Restituisce una lista di study records (parsed_json). NB: per gli studi
#' chunked ci sono piu' record con la stessa series_id; usare
#' \code{\link{.reassemble_stage2_chunks}} a valle per ripristinare l'invariante
#' un-record-per-studio (finding 2026-06-01).
#' @keywords internal
.load_stage2_master <- function(path) {
  if (!file.exists(path)) stop("stage2_master path non esiste: ", path)
  if (grepl("\\.rds$", path, ignore.case = TRUE)) {
    obj <- readRDS(path)
    # Gestione collect-wrapper (output di dgx_collect_stage2):
    # list(predictions = tibble(record_id, parsed_json, ...), errors = ..., summary = ...)
    # Estraiamo i parsed_json dei record validi (valid_schema = TRUE o non NA)
    if (is.list(obj) && !is.null(obj$predictions) && is.data.frame(obj$predictions)) {
      preds <- obj$predictions
      valid_mask <- if (!is.null(preds$valid_schema)) {
        !is.na(preds$valid_schema) & preds$valid_schema
      } else {
        rep(TRUE, nrow(preds))
      }
      return(preds$parsed_json[valid_mask])
    }
    # Formato nativo: lista di study records (passato direttamente)
    obj
  } else {
    # JSONL: ogni riga e' list(record_id=..., parsed_json=list(series_id=..., ...), ...)
    lines <- readLines(path, warn = FALSE)
    rows <- lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)
    lapply(rows, function(r) {
      if (!is.null(r$parsed_json)) r$parsed_json else r
    })
  }
}
