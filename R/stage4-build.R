#' Entry-point Stadio 4: end-to-end DE per-studio + MEGA cluster pooling
#'
#' Esegue i 5 sub-stage: QC + filter, calcolo run_id deterministico,
#' DE per-studio (limma-voom), pooling cluster-level (REM via metafor o
#' MEGA-AUG via dream), aggregazione QC report. Il render del dashboard
#' viene gestito separatamente da \code{render_stage4_dashboard}.
#'
#' Output e' un oggetto S3 \code{stage4_result} consumato da
#' \code{write_stage4_to_dir} per la persistenza on-disk.
#'
#' @param stage3_clusters tibble \code{clusters.rds} prodotto da Stadio 3.
#' @param h5_metadata tibble sample-level (\code{sample_id}, \code{gsm},
#'   \code{gse}, \code{lib_size}).
#' @param config output di \code{stage4_default_config()}.
#' @param fetch_fn funzione \code{(gse, sample_ids) -> matrix} per recuperare
#'   counts. Default chiama \code{.fetch_counts_cached} con \code{h5_path}.
#' @param h5_path path al file H5 ARCHS4 (richiesto se \code{fetch_fn=NULL}).
#' @param stage3_run_id stringa run_id Stadio 3 per input_hashes.
#' @param stage3_dir path della directory Stadio 3 di ingresso (Task 11:
#'   provenienza registrata in \code{run_metadata$stage3}). Default
#'   \code{NULL} per retrocompatibilita' (campo scritto come NA, non errore).
#' @param stage3_clusters_sha256 sha256 del CONTENUTO di
#'   \code{clusters.rds} dello Stadio 3 (Task 11), calcolato dal chiamante con
#'   \code{digest::digest(file = ..., algo = "sha256")}. E' l'impronta
#'   dell'oggetto prodotto, non una stringa di versione scritta a mano — non
#'   si puo' dimenticare di aggiornarla. Default \code{NULL} per
#'   retrocompatibilita' (campo scritto come NA, non errore).
#' @param h5_path_for_hash path al H5 per il calcolo sha256 (NULL se non si
#'   vuole hashare il H5; in tal caso usa placeholder "unknown").
#' @param stage3_assignments tibble \code{assignments.parquet} Stadio 3
#'   (richiesto quando \code{dry_run_inputs_only = FALSE} per costruire i
#'   dispatch per-cluster).
#' @param stage2_master list di study records (output di
#'   \code{.load_stage2_master} o equivalente). Richiesto quando
#'   \code{dry_run_inputs_only = FALSE}.
#' @param cluster_subset character dei \code{cluster_id} da calcolare, oppure
#'   NULL (tutti). Serve a spezzare un re-pool in piu' processi: il filtro si
#'   applica DOPO l'identificazione Layer A, quindi ogni pezzo lavora sugli
#'   stessi gruppi vincenti e con gli stessi \code{k} del run intero.
#' @param dry_run_inputs_only logical: se TRUE, restituisce solo
#'   eligible_clusters + run_metadata + scaffold vuoti (skip DE/pooling)
#'   per debug rapido o test di integrazione minimi.
#' @param gene_biotype_filter character vector o NULL (FASE E2 ADR-0019
#'   D7). Default \code{"protein_coding"}: il pool DE lavora sui ~23k
#'   geni protein_coding (vs ~67k totali in ARCHS4 v2.5). NULL =
#'   nessun filter (tutti i geni); vector multi-valore = union (es.
#'   \code{c("protein_coding", "lncRNA")} per ~42k geni). Propagato al
#'   fetch_fn default \code{.fetch_counts_cached} + a
#'   \code{.fetch_counts_from_h5}.
#' @return oggetto S3 \code{stage4_result} (list) con campi:
#'   \code{per_study_de}, \code{cluster_pooled}, \code{eligible_clusters},
#'   \code{qc_report}, \code{non_processable}, \code{config},
#'   \code{run_metadata}.
#' @export
build_stage4_results <- function(stage3_clusters, h5_metadata,
                                 config = stage4_default_config(),
                                 fetch_fn = NULL, h5_path = NULL,
                                 stage3_run_id = NULL,
                                 stage3_dir = NULL,
                                 stage3_clusters_sha256 = NULL,
                                 h5_path_for_hash = NULL,
                                 stage3_assignments = NULL,
                                 stage2_master = NULL,
                                 dry_run_inputs_only = FALSE,
                                 cluster_subset = NULL,
                                 gene_biotype_filter = "protein_coding",
                                 de_covariates = c("instrument_model",
                                                    "aligner_class")) {

  # T7a Fix 1: warning runtime quando fetch_fn esterno (override
  # esplicito del chiamante) E filter non-NULL. Emesso PRIMA della
  # short-circuit dry-run, cosi' il chiamante e' avvertito anche se non
  # esegue il pool. Il filter e' applicato SOLO al fetch_fn default
  # (closure cacheata costruita in Step 4 sotto). fetch_fn esterno NON
  # riceve gene_biotype_filter automaticamente -> incoerenza paper-grade
  # se cluster_pooled finale contiene tutti i biotype ma
  # run_metadata.json registra filter 'protein_coding'.
  if (!is.null(fetch_fn) && !is.null(gene_biotype_filter)) {
    warning(
      "fetch_fn esterno fornito + gene_biotype_filter non-NULL: il filter ",
      "NON viene applicato automaticamente al fetch_fn override. Il ",
      "chiamante deve implementare il filter all'interno del proprio ",
      "fetch_fn, oppure passare gene_biotype_filter = NULL per ",
      "disabilitarlo esplicitamente. ",
      "run_metadata$gene_biotype_filter registrera' comunque il valore ",
      "richiesto.",
      call. = FALSE
    )
  }

  # T7b Fix 2: gene_axis_summary calcolato UNA volta dall'H5 axis +
  # filter, propagato in run_metadata. Permette al revisore del paper di
  # verificare l'EFFETTO osservato del filter (n_total, n_post_filter,
  # n_biotype_na droppati) non solo il valore richiesto. Se h5_path e'
  # NULL (fetch_fn esterno), summary NULL: non sappiamo cosa il fetch_fn
  # ritorna.
  gene_axis_summary <- if (!is.null(h5_path)) {
    .compute_gene_axis_summary(
      .h5_gene_axis(h5_path),
      gene_biotype_filter
    )
  } else NULL

  # Step 1: QC sample + studio + cluster
  qc <- .qc_filter_samples_and_studies(stage3_clusters, h5_metadata, config)
  # SPEZZETTAMENTO (2026-08-15). Il sottoinsieme si applica QUI, dopo
  # l'identificazione Layer A e prima dei dispatch: la dedup per entita' e le
  # fusioni hanno gia' visto l'insieme completo, quindi ogni pezzo lavora sugli
  # stessi gruppi vincenti e con gli stessi `k` del run intero.
  if (!is.null(cluster_subset)) {
    n_prima <- nrow(qc$eligible_clusters)
    qc$eligible_clusters <- .apply_cluster_subset(qc$eligible_clusters, cluster_subset)
    message(sprintf("pezzo: %d cluster su %d ammessi",
                    nrow(qc$eligible_clusters), n_prima))
  }

  # Step 2: Calcolo run_id deterministico (hash di input + config + schema)
  stage3_hash <- if (is.null(stage3_run_id)) "unknown" else stage3_run_id
  h5_hash <- if (!is.null(h5_path_for_hash)) {
    substr(digest::digest(h5_path_for_hash, algo = "sha256", file = TRUE),
           1L, 16L)
  } else {
    "unknown"
  }
  hashes <- list(stage3 = stage3_hash, h5 = h5_hash)
  run_id <- .run_id_for_stage4(hashes, config, config$schema_versions)

  # Task 11: la provenienza dello Stadio 3 va nel run_metadata, non solo
  # nell'hash (che poi viene buttato). L'identita' dello Stadio 3 e' lo
  # SHA256 del CONTENUTO di clusters.rds — calcolato dall'oggetto prodotto,
  # non una stringa di versione da ricordare di aggiornare. Vedi
  # .NAME_RECOVERY_LOOKUP_SCHEMA_VERSION per il costo di quel tipo di errore.
  stage3_provenance <- list(
    run_id          = stage3_run_id %||% NA_character_,
    dir             = stage3_dir %||% NA_character_,
    clusters_sha256 = stage3_clusters_sha256 %||% NA_character_
  )

  # Step 3: short-circuit per dry-run / debug rapido
  if (isTRUE(dry_run_inputs_only)) {
    return(structure(list(
      per_study_de      = .empty_per_study_de(),
      cluster_pooled    = .empty_pooled_rem(),
      eligible_clusters = qc$eligible_clusters,
      qc_report         = qc[c("qc_drops_sample", "qc_drops_study",
                                "qc_drops_cluster")],
      non_processable   = qc$qc_drops_cluster,
      config            = config,
      run_metadata      = list(
        run_id = run_id,
        timestamp = Sys.time(),
        stage3 = stage3_provenance,                   # Task 11
        gene_biotype_filter = gene_biotype_filter,    # FASE E2 ADR-0019 D7
        gene_axis_summary = gene_axis_summary,        # T7b Fix 2
        de_covariates_requested = de_covariates       # FASE E3 ADR-0019 D8
      )
    ), class = "stage4_result"))
  }

  # Step 4: default fetch_fn cacheato su disco se non specificato.
  # FASE E2 ADR-0019 D7: la closure cattura gene_biotype_filter e lo
  # propaga a .fetch_counts_cached -> .fetch_counts_from_h5. Cache key
  # disk stratificata per filter via .cache_key_for_fetch. Il warning
  # paper-grade per fetch_fn esterno + filter non-NULL e' emesso piu'
  # in alto in funzione (T7a Fix 1).
  if (is.null(fetch_fn)) {
    if (is.null(h5_path)) {
      stop("h5_path e' richiesto quando fetch_fn e' NULL")
    }
    fetch_fn <- function(g, s) .fetch_counts_cached(
      g, s, h5_path = h5_path,
      gene_biotype_filter = gene_biotype_filter
    )
  }

  # Step 4b: dispatch builders (stage3_assignments + stage2_master richiesti)
  # Senza dispatch, .run_per_study_de_all stoppa con "attr 'study_dispatch'
  # mancante". Esponi un messaggio piu' utile + attacca i dispatch come
  # attributes di eligible_clusters.
  if (is.null(stage3_assignments) || is.null(stage2_master)) {
    stop("stage3_assignments + stage2_master sono richiesti quando ",
         "dry_run_inputs_only = FALSE")
  }
  # Guard invariante un-record-per-studio (opzione C, ADR-0020) PRIMA dei dispatch
  # builder: .index_stage2_master indicizza per series_id (last-wins); su un input
  # chunked inatteso i chunk non-ultimi sarebbero persi/misrisolti (finding
  # 2026-06-01). Fail-loud invece del vecchio riassemblaggio namespacing.
  # Coerente col guard in build_stage3_clusters().
  stage2_master <- .assert_stage2_one_record_per_series(stage2_master)
  # I RECORD DEI CLUSTER ASSORBITI PASSANO AL VINCENTE, prima dei dispatch.
  # Senza questo la fusione cancella una riga del deliverable e non porta i suoi
  # studi da nessuna parte: sul re-pool v16 il TNF dichiarava k=48 e il dispatch
  # ne risolveva 32. Vedi .reassign_absorbed_records().
  .fus_rec <- attr(qc$eligible_clusters, "fusioni")
  if (!is.null(.fus_rec) && nrow(.fus_rec) > 0L) {
    stage3_assignments <- .reassign_absorbed_records(stage3_assignments, .fus_rec)
    message(sprintf("fusioni: record di %d cluster assorbiti spostati sul vincente",
                    nrow(.fus_rec)))
  }
  study_dispatch <- .build_study_dispatch_from_stage3(
    qc$eligible_clusters, stage3_assignments, stage2_master
  )
  # FASE F6 2026-07-05: group nominati L2-L4 -> REM per-studio. Stesso schema
  # {study_id, treated, control} dei pair, quindi si fonde nello study_dispatch
  # (cluster_id disgiunti: rem_group e' group, rem/mega_aug sono pair).
  # LE CORSIE NON SONO REPLICHE (2026-08-12). La corrispondenza campione ->
  # libreria si costruisce una volta sola dai metadati H5 e serve DUE consumatori:
  # il gate `n_min` qui sotto (un braccio con due corsie di una sola libreria non
  # e' replicato) e il collasso delle conte prima del DE (Step 5). Spenta di
  # default. Vedi R/stage4-technical-lanes.R.
  lane_lookup <- NULL
  if (isTRUE(config$rem_group$collapse_technical_lanes)) {
    serve <- c("geo_accession", "title", "series_id",
               "characteristics_ch1", "source_name_ch1")
    if (!is.null(h5_metadata) && all(serve %in% names(h5_metadata))) {
      lane_lookup <- build_lane_library_lookup(h5_metadata)
      message(sprintf(
        "corsie: %d campioni in %d librerie da piu' corsie (%d candidate scartate dalle guardie)",
        length(lane_lookup), length(unique(lane_lookup)),
        nrow(attr(lane_lookup, "scartate"))))
    } else {
      # ⚠️ ERRORE, non warning (2026-08-15). Nel re-pool v16 questo ramo ha
      # emesso un warning che e' finito fra i «50 or more warnings» e non l'ha
      # letto nessuno: il collasso delle corsie non si e' acceso e 32 ore di
      # calcolo sono uscite senza il cambio che dovevano applicare. Un
      # meccanismo che tocca le stime pubblicate o e' acceso o si ferma. Chi non
      # lo vuole lo spegne dalla config, esplicitamente.
      stop("collapse_technical_lanes = TRUE ma h5_metadata non ha: ",
           paste(setdiff(serve, names(h5_metadata)), collapse = ", "),
           ".\n  Servono i cinque campi per riconoscere le corsie della stessa ",
           "libreria (il titolo e' quello che le distingue).",
           "\n  Per procedere senza: config$rem_group$collapse_technical_lanes <- FALSE",
           call. = FALSE)
    }
  }
  group_rem_dispatch <- .build_group_rem_dispatch_from_stage3(
    qc$eligible_clusters, stage3_assignments, stage2_master,
    n_min = config$rem_group$n_min %||% 2L,
    lane_lookup = lane_lookup
  )
  # Invariante: i cluster_id pair (study_dispatch) e group (group_rem_dispatch)
  # sono disgiunti per costruzione (mode diverso). Fail-loud se non lo sono:
  # nomi duplicati in c() farebbero prendere silenziosamente il primo match a
  # dispatch[[cid]] a valle.
  .dup_dispatch <- intersect(names(study_dispatch), names(group_rem_dispatch))
  if (length(.dup_dispatch) > 0L) {
    stop("cluster_id sovrapposti tra study_dispatch e group_rem_dispatch: ",
         paste(.dup_dispatch, collapse = ", "))
  }
  study_dispatch <- c(study_dispatch, group_rem_dispatch)
  group_dispatch <- .build_group_dispatch_from_stage3(
    qc$eligible_clusters, stage3_assignments, stage2_master
  )
  attr(qc$eligible_clusters, "study_dispatch") <- study_dispatch
  attr(qc$eligible_clusters, "group_dispatch") <- group_dispatch

  # Step 4c: arricchisce stage3_clusters con sample_ids list-column (necessario
  # per il match MEGA-AUG baseline pool in .assemble_mega_aug_metadata)
  stage3_clusters_enriched <- .enrich_group_baseline_sample_ids(
    stage3_clusters, stage3_assignments, stage2_master
  )

  # Step 5: DE per-studio (limma-voom) su tutti i cluster eligible.
  # FASE E3 ADR-0019 D8: propaga metadata_extra (h5_metadata subset)
  # + de_covariates ai limma-voom per-studio (per-studio le covariate
  # sono spesso single-level e auto-droppate, ma il path resta consistent).
  per_study_de <- .run_per_study_de_all(
    eligible_clusters = qc$eligible_clusters,
    fetch_fn          = fetch_fn,
    metadata_extra    = h5_metadata,
    de_covariates     = de_covariates,
    workers           = 1L,
    # Stessa soglia del dispatch: un braccio ridotto sotto n_min dopo lo scarto
    # dei campioni ambigui non e' un braccio. Vedi R/stage4-role-conflict.R.
    role_conflict_n_min = as.integer(config$rem_group$n_min %||% 2L),
    lane_lookup = lane_lookup
  )

  # Step 5b: SAMN dedupe lookups (FASE E0b, decisione utente 2026-05-27 su
  # evidence A7b). Se h5_metadata contiene biosample_id + lib_size, i due
  # lookup vengono propagati down a .pool_all_clusters per attivare il drop
  # deterministico cross-GSE same-SAMN (max lib_size winner). Fallback
  # graceful con warning se colonne assenti (-> retrocompat pre-E0b).
  samn_lookups <- .build_samn_dedupe_lookups(h5_metadata)

  # Step 6: pooling cluster-level (REM metafor o MEGA-AUG dream).
  # Workers risolti via .resolve_dream_workers (auto-detect availableCores -
  # offset, cap a dream_workers_cap). Per workers > 1, .run_dream_mega usa
  # BiocParallel::MulticoreParam. NOTE: OPENBLAS_NUM_THREADS=1 raccomandato
  # nell'ambiente prima di lanciare R, per evitare oversubscription dei worker
  # forkati (vedi ADR-0015).
  dream_workers <- .resolve_dream_workers(config)
  cluster_pooled <- .pool_all_clusters(
    per_study_de      = per_study_de,
    eligible_clusters = qc$eligible_clusters,
    fetch_fn          = fetch_fn,
    stage3_clusters   = stage3_clusters_enriched,
    workers           = dream_workers,
    dream_workers_cap = config$compute$dream_workers_cap,
    mega_aug_config   = config$mega_aug,
    rem_group_config  = config$rem_group,
    biosample_lookup  = samn_lookups$biosample_lookup,
    libsize_lookup    = samn_lookups$libsize_lookup,
    metadata_extra    = h5_metadata,    # FASE E3 ADR-0019 D8
    de_covariates     = de_covariates
  )

  # Step 7: QC report aggregato. Merge cluster non_processable da QC + dal
  # pool stage (cluster MEGA rank-deficient skippati per scientific validity).
  qc_report <- .build_qc_report(qc$eligible_clusters, per_study_de,
                                 cluster_pooled)
  pool_non_proc <- attr(cluster_pooled, "non_processable_in_pool")
  if (!is.null(pool_non_proc) && nrow(pool_non_proc) > 0L) {
    qc$qc_drops_cluster <- rbind(qc$qc_drops_cluster, pool_non_proc)
    qc_report$qc_drops_cluster <- qc$qc_drops_cluster
  }

  # I DUE REGISTRI CHE TOCCANO STIME PUBBLICATE finiscono dentro `qc_report`,
  # che e' salvato su disco. Vivevano come ATTRIBUTI di `per_study_de`, e
  # `arrow::write_parquet` gli attributi li perde: il registro dei conflitti di
  # ruolo (2026-08-11) non e' mai arrivato su disco. Una selezione silenziosa non
  # e' auditabile, e questa e' la sede dove il resto degli scarti gia' vive.
  qc_report$role_conflicts <- attr(per_study_de, "role_conflicts") %||%
    .empty_role_conflict_log()
  qc_report$lane_collapses <- attr(per_study_de, "lane_collapses") %||%
    data.frame(libreria = character(), n_campioni = integer(),
               campioni = character(), cluster_id = character(),
               study_id = character(), stringsAsFactors = FALSE)
  # IL MOTIVO DI OGNI CONFRONTO CHE NON ENTRA NEL POOLING (2026-08-13, D7).
  # `n_min` e' la porta piu' selettiva della pipeline -- sul deliverable v15
  # lascia fuori piu' della meta' dei confronti assegnati -- e fino a oggi lo
  # faceva senza lasciare traccia. Il 2026-08-10 quel silenzio e' costato una
  # misura sbagliata: 85 confronti dichiarati difettosi, di cui 47 non erano
  # nemmeno nel poolato.
  qc_report$dispatch_drops <- attr(group_rem_dispatch, "scarti") %||%
    .empty_dispatch_drop_log()
  qc_report$covariate_drops <- attr(per_study_de, "covariate_drop_log") %||%
    data.frame(cluster_id = character(), covariate = character(),
               reason = character(), detail = character(), stringsAsFactors = FALSE)

  structure(list(
    per_study_de      = per_study_de,
    cluster_pooled    = cluster_pooled,
    eligible_clusters = qc$eligible_clusters,
    qc_report         = qc_report,
    non_processable   = qc_report$qc_drops_cluster,
    config            = config,
    run_metadata      = list(
      run_id = run_id,
      timestamp = Sys.time(),
      stage3 = stage3_provenance,                  # Task 11
      gene_biotype_filter = gene_biotype_filter  # FASE E2 ADR-0019 D7
    )
  ), class = "stage4_result")
}
