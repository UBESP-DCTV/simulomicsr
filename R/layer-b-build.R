#' Build Layer B results (orchestrator)
#'
#' Entry-point pubblico. Esegue i 3 sub-stage Layer B:
#' B.1 Loader+QC (validate selection + fetch_layer_a_subset),
#' B.2 Asset generation (per cluster: 8 plot conditional + summary card +
#' narrative template),
#' B.3 (delegato a `render_layer_b_report()` chiamato dal caller).
#'
#' @param stage4_dir character path al dir Layer A output.
#' @param selection character path-to-CSV o data.frame.
#' @param h5_path character path al H5 ARCHS4 (per default fetch via
#'   \code{.fetch_counts_cached()}). Required quando `fetch_counts_fn` e' NULL.
#' @param per_cluster_samples_provider function(cluster_id) -> tibble
#'   `sample_id, study_id, treatment` per il cluster (assemblata upstream
#'   dal join Stage 3 assignment + Stage 2 design_role).
#' @param pooling_effectiveness data.frame opzionale (una riga per cluster) con
#'   le misure di efficacia del pooling e di materiale; passato tale e quale a
#'   `.build_summary_card()`. NULL -> le schede escono come prima.
#' @param stage3_metadata tibble opzionale con `cluster_id, kind_effective,
#'   agent_id, tissue, safety_min` (per summary card). NULL -> summary card
#'   senza Stage 3 fields.
#' @param config list (vedi [layer_b_default_config()]).
#' @param out_dir character path output dir. Se NULL, genera dir versionata
#'   in `analysis/p4-output/<ts>-layer-b-<run_id>/`.
#' @param fetch_counts_fn opzionale function(study_id, sample_ids) -> integer
#'   matrix (genes x samples). Se NULL, viene creato un wrapper di
#'   \code{.fetch_counts_cached(g, s, h5_path = h5_path)} che riusa la cache
#'   xxhash32 condivisa con Layer A. Override utile per test/fixture.
#'
#' @return Oggetto S3 `layer_b_result` (list con `cluster_bundles`,
#'   `selection_resolved`, `run_metadata`, `dir`).
#' @export
build_layer_b_results <- function(stage4_dir, selection,
                                  h5_path,
                                  per_cluster_samples_provider,
                                  stage3_metadata = NULL,
                                  pooling_effectiveness = NULL,
                                  config = layer_b_default_config(),
                                  out_dir = NULL,
                                  fetch_counts_fn = NULL) {
  cli::cli_h1("Layer B build")
  t0 <- Sys.time()

  # Default fetch_counts_fn: wrappa .fetch_counts_cached (riusa cache xxhash32
  # condivisa con Layer A). Richiede h5_path non-NULL.
  if (is.null(fetch_counts_fn)) {
    if (is.null(h5_path)) {
      cli::cli_abort("h5_path required when fetch_counts_fn is NULL")
    }
    fetch_counts_fn <- function(g, s) .fetch_counts_cached(g, s, h5_path = h5_path)
  }

  # B.1 Loader + QC
  cli::cli_alert_info("B.1 Loader + validation")
  sel_resolved <- layer_b_validate_selection(selection, stage4_dir, config$fdr_threshold)
  cluster_ids <- sel_resolved$cluster_id

  layer_a_subset <- .fetch_layer_a_subset(stage4_dir, cluster_ids)

  # Stage 3 metadata default: tibble vuota (summary card scrive "(no Stage 3 metadata)")
  if (is.null(stage3_metadata)) {
    stage3_metadata <- tibble::tibble(
      cluster_id = character(),
      kind_effective = character(),
      agent_id = character(),
      tissue = character(),
      safety_min = numeric()
    )
  }

  # B.2 Asset gen
  cli::cli_alert_info("B.2 Asset generation ({.field {length(cluster_ids)}} cluster)")

  # Hash selection (campi canonici, ordinati per cluster_id) per run_id deterministico
  sel_for_hash <- sel_resolved[
    order(sel_resolved$cluster_id),
    c("cluster_id", "label_paper", "priority", "notes")
  ]
  sel_sha <- digest::digest(sel_for_hash, algo = "sha256")

  # FASE E5: bumpa stage4_algorithm a 'v2_ensembl_gene_axis' per riflettere
  # il refactor E1-E3 (Ensembl axis + gene_symbol + biotype filter +
  # covariate batch). layer_b_algorithm v1 invariato (template plot
  # immutato; cambia solo la fonte upstream dati).
  schema_versions <- list(
    layer_b_algorithm = "v1",
    stage4_algorithm  = "v2_ensembl_gene_axis"
  )
  run_id <- .run_id_for_layer_b(
    stage4_run_id    = layer_a_subset$stage4_run_id,
    selection_sha256 = sel_sha,
    config           = config,
    schema_versions  = schema_versions
  )

  if (is.null(out_dir)) {
    out_dir <- file.path(
      "analysis/p4-output",
      sprintf(
        "%s-layer-b-%s",
        format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
        run_id
      )
    )
  }
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  cluster_bundles <- list()
  for (cl_id in cluster_ids) {
    cli::cli_alert("Processing {.field {cl_id}}...")
    cl_dir <- file.path(out_dir, cl_id)
    if (!dir.exists(cl_dir)) dir.create(cl_dir, recursive = TRUE)

    cp_sub <- layer_a_subset$cluster_pooled[
      layer_a_subset$cluster_pooled$cluster_id == cl_id, ,
      drop = FALSE
    ]
    ps_sub <- layer_a_subset$per_study_de[
      layer_a_subset$per_study_de$cluster_id == cl_id, ,
      drop = FALSE
    ]
    method <- unique(cp_sub$method)[1L]

    # Calcolata qui (non piu' in basso, vicino a summary_card) perche' serve
    # anche a .build_forest() per il titolo (.lb_titolo()): senza label_paper
    # il titolo ripiegherebbe su cluster_id, un ID grezzo tipo
    # "cgroup_L5_2e16719f" che vanifica lo scopo della funzione.
    selection_row <- sel_resolved[
      sel_resolved$cluster_id == cl_id, ,
      drop = FALSE
    ]

    # Counts assembly (per_cluster_samples + fetch_counts_fn DI)
    per_cluster_samples <- per_cluster_samples_provider(cl_id)
    counts_meta <- .assemble_cluster_counts(
      cluster_id          = cl_id,
      per_cluster_samples = per_cluster_samples,
      fetch_counts_fn     = fetch_counts_fn
    )

    plots <- list()
    plots$volcano <- .build_volcano(
      cp_sub, out_dir = cl_dir, config = config,
      etichetta = selection_row$label_paper[1L]
    )
    plots$forest  <- .build_forest(
      per_study_de_subset   = ps_sub,
      cluster_pooled_subset = cp_sub,
      method                = method,
      out_dir               = cl_dir,
      config                = config,
      etichetta             = selection_row$label_paper[1L]
    )
    plots$ma <- .build_ma_plot(
      cluster_pooled_subset = cp_sub,
      counts                = counts_meta$counts,
      out_dir               = cl_dir,
      config                = config
    )
    plots$top_gene_table <- .build_top_gene_table(
      cluster_pooled_subset = cp_sub,
      out_dir               = cl_dir,
      config                = config
    )
    plots$heatmap <- .build_heatmap(
      counts                = counts_meta$counts,
      metadata              = counts_meta$metadata,
      cluster_pooled_subset = cp_sub,
      out_dir               = cl_dir,
      config                = config
    )
    if (isTRUE(config$go_enrichment)) {
      plots$go_enrichment <- .build_go_enrichment(
        cluster_pooled_subset = cp_sub,
        out_dir               = cl_dir,
        config                = config
      )
    }
    plots$heterogeneity <- .build_heterogeneity_panel(
      cluster_pooled_subset = cp_sub,
      out_dir               = cl_dir,
      config                = config
    )

    summary_card <- .build_summary_card(
      cluster_id          = cl_id,
      layer_a_subset      = layer_a_subset,
      stage3_metadata     = stage3_metadata,
      selection_row       = selection_row,
      config              = config,
      out_dir             = cl_dir,
      per_cluster_samples = counts_meta$metadata,
      pooling_effectiveness = pooling_effectiveness
    )
    narrative_path <- .write_narrative_template(
      cluster_id          = cl_id,
      summary_card_path   = summary_card$md_path,
      selection_row       = selection_row,
      config              = config,
      out_dir             = cl_dir
    )

    cluster_bundles[[cl_id]] <- list(
      cluster_id        = cl_id,
      cluster_dir       = cl_dir,
      plots             = plots,
      summary_card_path = summary_card$md_path,
      narrative_path    = narrative_path
    )
  }

  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  # Bioc versions (6 hard deps Layer B) -- per riproducibilita paper
  bioc_pkgs <- c("clusterProfiler", "ComplexHeatmap", "DESeq2",
                 "org.Hs.eg.db", "sva", "ReactomePA")
  bioc_versions <- stats::setNames(
    vapply(bioc_pkgs, function(p) {
      if (requireNamespace(p, quietly = TRUE)) {
        as.character(utils::packageVersion(p))
      } else {
        NA_character_
      }
    }, character(1L)),
    bioc_pkgs
  )

  # Conta plot generati vs skipped (path NA = skip)
  n_plots_generated <- sum(vapply(cluster_bundles, function(b) {
    sum(vapply(b$plots, function(p) {
      !is.null(p$png_path) && !is.na(p$png_path)
    }, logical(1L)))
  }, integer(1L)))
  n_plots_skipped <- sum(vapply(cluster_bundles, function(b) {
    sum(vapply(b$plots, function(p) {
      is.null(p$png_path) || is.na(p$png_path)
    }, logical(1L)))
  }, integer(1L)))

  run_metadata <- list(
    run_id          = run_id,
    timestamp       = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    schema_versions = schema_versions,
    package_version = as.character(utils::packageVersion("simulomicsr")),
    r_version       = R.version.string,
    bioc_versions   = as.list(bioc_versions),
    input_files     = list(
      stage4_dir       = list(path = stage4_dir, run_id = layer_a_subset$stage4_run_id),
      selection_sha256 = sel_sha
    ),
    config          = config,
    output_counts   = list(
      n_clusters_processed = length(cluster_ids),
      by_method            = as.list(table(sel_resolved$method)),
      n_plots_generated    = n_plots_generated,
      n_plots_skipped      = n_plots_skipped,
      # bundle_size_mb / report_size_mb: computed post-write via du(1) -- non
      # disponibili a questo punto (out_dir popolata sotto da write_layer_b_to_dir)
      bundle_size_mb       = NA_real_,
      report_size_mb       = NA_real_
    ),
    # peak_mem_mb richiederebbe Rprof o pryr::mem_used -- non aggiungiamo
    # dipendenze runtime per un metric meramente informativo
    compute_summary = list(
      wall_seconds = wall,
      peak_mem_mb  = NA_real_
    )
  )

  result <- structure(
    list(
      cluster_bundles    = cluster_bundles,
      selection_resolved = sel_resolved,
      run_metadata       = run_metadata,
      dir                = out_dir
    ),
    class = "layer_b_result"
  )

  write_layer_b_to_dir(result, out_dir)

  cli::cli_alert_success(
    "Layer B build OK in {.field {round(wall, 1)}s}: {.path {out_dir}}"
  )
  result
}
