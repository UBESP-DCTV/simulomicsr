#' I bersagli attesi che sono davvero misurati per un cluster, coi loro valori
#'
#' Incrocia i bersagli attesi dalla letteratura (dichiarati dal CHIAMANTE --
#' vedi `bersagli_attesi_provider` di [build_layer_b_results()]; questa
#' funzione non ha una tabella interna) con i geni effettivamente misurati nel
#' pool (`cluster_pooled`), e riporta SOLO quelli presenti. E' il ponte fra il
#' deliverable annotato (che vive a livello di meta-analisi, non di gene: non
#' ha `logFC`/`FDR` per bersaglio) e `.summary_card_v2()`/`.narrativa_bozza()`
#' (che li vogliono gia' pronti).
#'
#' @param cp data.frame/tibble del subset `cluster_pooled` per UN cluster.
#'   Colonne usate: `gene_symbol`, `logFC_pool`, `FDR_BH_within_cluster`.
#' @param bersagli_attesi character vector di simboli genici attesi. Se
#'   vuoto, ritorna 0 righe senza errore -- e' il caso "nessuna aspettativa
#'   dichiarata dal chiamante", gia' gestito a valle da `.narrativa_bozza()`.
#' @return data.frame con `gene`, `logFC`, `FDR` -- una riga per bersaglio
#'   atteso che e' anche misurato in questo cluster. Deduplicato per
#'   `gene_symbol` (vedi [.rank_and_dedup_genes()]): ARCHS4 mappa piu'
#'   Ensembl gene_id sullo stesso simbolo HGNC (artefatto multi-Ensembl), e
#'   senza questo passo un bersaglio con piu' righe comparirebbe piu' volte
#'   nella scheda/narrativa -- lo stesso difetto gia' corretto per
#'   tabella/heatmap/forest/volcano, qui latente finche' nessun cluster
#'   veniva mai passato a questa funzione (vedi rilievo C1).
#' @keywords internal
.bersagli_trovati <- function(cp, bersagli_attesi) {
  cp <- as.data.frame(cp, stringsAsFactors = FALSE)
  vuoto <- data.frame(gene = character(0), logFC = numeric(0),
                      FDR = numeric(0), stringsAsFactors = FALSE)
  if (length(bersagli_attesi) == 0L || nrow(cp) == 0L) return(vuoto)
  sub <- cp[cp$gene_symbol %in% bersagli_attesi, , drop = FALSE]
  if (nrow(sub) == 0L) return(vuoto)
  sub <- .rank_and_dedup_genes(sub)
  data.frame(
    gene  = sub$gene_symbol,
    logFC = sub$logFC_pool,
    FDR   = sub$FDR_BH_within_cluster,
    stringsAsFactors = FALSE
  )
}

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
#'   `.build_summary_card()` **solo quando si ripiega sulla scheda vecchia**
#'   (deliverable annotato non disponibile per quel cluster: vedi
#'   `deliverable_annotato_path` sotto). Quando la scheda nuova e' in uso,
#'   queste misure vengono dalla riga del deliverable annotato, non da qui.
#'   NULL -> le schede vecchie (ripiego) escono come prima.
#' @param stage3_metadata tibble opzionale con `cluster_id, kind_effective,
#'   agent_id, tissue, safety_min` (per summary card). NULL -> summary card
#'   senza Stage 3 fields.
#' @param bersagli_attesi_provider function(cluster_id) -> character vector
#'   opzionale, i simboli genici attesi dalla letteratura per quel cluster.
#'   **Argomento del chiamante**: il pacchetto non ha una tabella interna di
#'   bersagli (vedi `.narrativa_bozza()`) -- inventarne una qui sarebbe
#'   esattamente il tipo di affermazione non verificabile che quella funzione
#'   e' scritta per evitare. NULL (default) -> nessuna attesa dichiarata per
#'   nessun cluster (la scheda/narrativa lo dicono esplicitamente, non lo
#'   tacciono).
#' @param confronti_imperfetti_provider function(cluster_id) -> list(n, tot,
#'   peso) o NULL, opzionale, dalla rilettura dei confronti poolati (vedi
#'   `docs/findings/2026-08-05-confronti-imperfetti.md`). NULL (default) ->
#'   "non misurato" dichiarato per ogni cluster.
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
                                  bersagli_attesi_provider = NULL,
                                  confronti_imperfetti_provider = NULL,
                                  config = layer_b_default_config(),
                                  out_dir = NULL,
                                  fetch_counts_fn = NULL) {
  # Argomenti del chiamante, mai una tabella interna (vedi doc sopra): quando
  # non forniti, dichiarano esplicitamente "nessun dato" invece di ripiegare
  # in silenzio su una lista vuota indistinguibile da un errore di wiring.
  if (is.null(bersagli_attesi_provider)) {
    bersagli_attesi_provider <- function(cluster_id) character(0)
  }
  if (is.null(confronti_imperfetti_provider)) {
    confronti_imperfetti_provider <- function(cluster_id) NULL
  }
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

  # --- deliverable annotato: fonte della scheda nuova (.summary_card_v2()) e
  # della bozza di narrativa (.narrativa_bozza()) ------------------------------
  # Vive nella STESSA directory dello Stadio 4 passata come stage4_dir -- mai
  # un parametro separato, per garantire che la scheda descriva sempre lo
  # stesso run delle figure (stessa regola gia' applicata a mano negli script
  # di analisi, es. analysis/p5-stage4-layer-b-build-v13.R).
  #
  # Se il file manca (run vecchio, o bundle di test senza quel file) il build
  # NON fallisce: ripiega su .build_summary_card()/.write_narrative_template()
  # senza bozza, come faceva prima di questo collegamento -- ma lo DICHIARA,
  # sia nel run_metadata (per l'audit) sia in una nota scritta dentro ogni
  # narrative.qmd che ripiega (per chi legge il bundle senza aprire il JSON).
  # Un ripiego silenzioso qui vanificherebbe la verifica sull'artefatto: si
  # troverebbe la scheda vecchia senza sapere perche'.
  deliverable_annotato_path <- file.path(stage4_dir, "deliverable-annotato.rds")
  deliverable_annotato <- NULL
  deliverable_annotato_motivo_assenza <- NA_character_
  if (file.exists(deliverable_annotato_path)) {
    d_ann <- readRDS(deliverable_annotato_path)
    if (!("cluster_id" %in% names(d_ann))) {
      deliverable_annotato_motivo_assenza <- sprintf(
        "%s non ha una colonna cluster_id: non e' un deliverable annotato valido.",
        deliverable_annotato_path)
      cli::cli_alert_warning(deliverable_annotato_motivo_assenza)
    } else {
      deliverable_annotato <- d_ann
    }
  } else {
    deliverable_annotato_motivo_assenza <- sprintf(
      "deliverable-annotato.rds assente in %s", deliverable_annotato_path)
    cli::cli_alert_warning(paste0(
      "Deliverable annotato non trovato in ", deliverable_annotato_path,
      ": la scheda ripiega su .build_summary_card() (campi tecnici) e la ",
      "narrativa resta uno stub TODO."
    ))
  }

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

  # MA plot ed eterogeneita' sono ESCLUSI dal bundle di default
  # (config$figure_escluse, Task 8 del ridisegno) -- selezione, non
  # cancellazione: il codice di .build_ma_plot()/.build_heterogeneity_panel()
  # resta, come gia' deciso per il ramo `mega` in ADR-0026. Un config senza
  # quella chiave (bundle costruiti con una list letterale invece di
  # layer_b_default_config()) non esclude nulla.
  figure_escluse <- config$figure_escluse %||% character(0)

  # Accumula quali cluster hanno usato il ripiego (scheda vecchia + narrativa
  # stub) invece della scheda/narrativa nuove: dichiarato in run_metadata.json
  # (vedi sotto), non solo nella nota dentro ogni narrative.qmd.
  cluster_id_ripiego <- character(0)

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
    if (!("ma" %in% figure_escluse)) {
      plots$ma <- .build_ma_plot(
        cluster_pooled_subset = cp_sub,
        counts                = counts_meta$counts,
        out_dir               = cl_dir,
        config                = config
      )
    }
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
      config                = config,
      etichetta             = selection_row$label_paper[1L]
    )
    if (isTRUE(config$go_enrichment)) {
      plots$go_enrichment <- .build_go_enrichment(
        cluster_pooled_subset = cp_sub,
        out_dir               = cl_dir,
        config                = config
      )
    }
    if (!("heterogeneity" %in% figure_escluse)) {
      plots$heterogeneity <- .build_heterogeneity_panel(
        cluster_pooled_subset = cp_sub,
        out_dir               = cl_dir,
        config                = config
      )
    }

    # --- scheda + narrativa: la riga del deliverable annotato vince, se c'e' -
    # `.build_summary_card()`/`.write_narrative_template()` senza bozza sono
    # il RIPIEGO, non un ramo equivalente: si prende solo quando il cluster
    # non ha una riga nel deliverable annotato, e il ripiego viene sempre
    # dichiarato (mai in silenzio -- vedi commento sopra al caricamento).
    riga_deliverable <- NULL
    if (!is.null(deliverable_annotato)) {
      rr <- deliverable_annotato[deliverable_annotato$cluster_id == cl_id, , drop = FALSE]
      if (nrow(rr) > 0L) riga_deliverable <- rr
    }

    if (!is.null(riga_deliverable)) {
      bersagli_attesi <- bersagli_attesi_provider(cl_id)
      trovati_df <- .bersagli_trovati(cp_sub, bersagli_attesi)
      bersagli_trovati_fmt <- if (nrow(trovati_df) > 0L) {
        sprintf("%s %+.2f", trovati_df$gene, trovati_df$logFC)
      } else {
        character(0)
      }
      imperfetti <- confronti_imperfetti_provider(cl_id)

      summary_md <- .summary_card_v2(riga_deliverable, bersagli_trovati_fmt, imperfetti,
                                     bersagli_attesi = bersagli_attesi)
      summary_md_path <- file.path(cl_dir, "summary_card.md")
      writeLines(strsplit(summary_md, "\n", fixed = TRUE)[[1L]], summary_md_path)
      summary_card <- list(md_path = summary_md_path)

      narrativa_md <- .narrativa_bozza(riga_deliverable, bersagli_attesi, trovati_df, imperfetti)
      narrative_path <- .write_narrative_template(
        cluster_id          = cl_id,
        summary_card_path   = summary_card$md_path,
        selection_row       = selection_row,
        config              = config,
        out_dir             = cl_dir,
        narrativa_bozza_md  = narrativa_md
      )
    } else {
      motivo_ripiego <- if (is.null(deliverable_annotato)) {
        deliverable_annotato_motivo_assenza
      } else {
        sprintf(
          "il cluster %s non e' una riga di %s.",
          cl_id, deliverable_annotato_path)
      }
      cluster_id_ripiego <- c(cluster_id_ripiego, cl_id)
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
        out_dir             = cl_dir,
        nota_ripiego        = sprintf(
          "questa scheda usa la versione precedente e la narrativa e' uno stub TODO: %s",
          motivo_ripiego)
      )
    }

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
      selection_sha256 = sel_sha,
      # Dichiara SEMPRE se la scheda/narrativa nuove sono state usate: non
      # solo quando manca il file (deliverable_annotato_motivo_assenza), ma
      # anche quali cluster, pur col file presente, sono finiti sul ripiego
      # perche' non hanno una riga nel deliverable annotato. Un ripiego
      # taciuto qui vanificherebbe la verifica sull'artefatto (Task 10).
      deliverable_annotato = list(
        path                = deliverable_annotato_path,
        disponibile         = !is.null(deliverable_annotato),
        motivo_assenza      = deliverable_annotato_motivo_assenza,
        cluster_id_ripiego  = cluster_id_ripiego
      )
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
