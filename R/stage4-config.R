#' Default configuration per Stadio 4 DE per-studio + MEGA cross-study production
#'
#' Restituisce la configurazione di default che governa Stage 4: QC sample-level
#' (lib_size threshold), DE engine choice (limma-voom REM + dream MEGA),
#' pooling method (REML con DL fallback per REM), parallelism (workers offset),
#' versioning schema per riproducibilita'.
#'
#' @return list con 5 componenti: \code{qc}, \code{de_engine}, \code{pooling},
#'   \code{compute}, \code{schema_versions}.
#' @seealso \code{\link{build_stage4_results}}, ADR-0015.
#' @export
stage4_default_config <- function() {
  list(
    qc = list(
      lib_size_min = 500000L
    ),
    de_engine = list(
      rem      = "limma-voom+eBayes",
      mega     = "dream",
      mega_aug = "dream"
    ),
    pooling = list(
      rem_method   = "REML",
      rem_fallback = "DL",
      fdr          = "BH_within_cluster"
    ),
    compute = list(
      workers_offset   = 10L,
      # dream_workers_cap 100 -> 16 (ADR-0016, 2026-05-22). Misura in
      # ISOLAMENTO: dream su cluster cappato (~510 sample) ~1 GB/worker
      # (16w->27GB, 32w->43GB). Ma nel contesto reale build_stage4_results
      # il processo R tiene in memoria stage2_master + stato accumulato:
      # ogni worker forkato ne fa una copia COW -> nel fullrun dream@32 ha
      # toccato ~127 GB per cluster (validate-cap 2026-05-22). Costo reale
      # ~3.4 GB/worker. A 16 worker il picco per-cluster e' ~75 GB: margine
      # sicuro sotto i 251 GB del laptop per il fullrun unattended.
      dream_workers_cap = 16L,
      dream_workers    = NA_integer_  # NA = auto-detect (availableCores -
                                       # workers_offset, capped a
                                       # dream_workers_cap). Vedi
                                       # .resolve_dream_workers + ADR-0015/0016.
    ),
    mega_aug = list(
      # Default conservativo: legacy = TRUE -> orchestrator usa
      # .assemble_mega_aug_metadata (monodirectional, strict string equality
      # su control_anchor). Bidir flow (.assemble_mega_aug_metadata_bidir)
      # va abilitato esplicitamente con legacy_monodirectional = FALSE.
      # Flip a FALSE come default e' pianificato dopo smoke 5-pick + simulation
      # batch confounding (Test 5.2 spec). Vedi
      # docs/superpowers/specs/2026-05-20-p5-stadio4-mega-aug-bidirezionale-design.md.
      legacy_monodirectional = TRUE,
      direction              = "both",         # "control" | "treated" | "both"
      anchor_policy          = "relaxed",      # "strict" | "relaxed"
      relaxed_segments       = c("dose_canonical", "duration_canonical",
                                   "has_engineered"),
      disjoint_policy        = "permissive",   # "permissive" | "strict"
      min_baseline_studies   = 2L,
      max_baseline_pool_reuse = NA_integer_,    # NA = nessun cap
      # Cap dimensione baseline pool per braccio (Problema B, 2026-05-21). I
      # cluster mega_aug augmentati arrivano a 7000+ sample / 945 studi: la DE
      # (dream o limma) esplode in memoria/tempo. Oltre il punto di saturazione
      # l'augmentation non aggiunge potenza (rendimenti decrescenti: il
      # contrasto e' limitato dal braccio del pair, n_aug >> n_pair non aiuta).
      # Se il braccio augmentato avrebbe > N sample baseline, si sotto-campiona
      # a N (seeded, riproducibile). NA = nessun cap. Valore N = 350 calibrato
      # dalla curva di saturazione (analysis/p5-stage4-debug-problemB-saturation.R,
      # ADR-0016): a cap 350 la correlazione logFC col pool pieno e' 0.997 e il
      # n. geni significativi e' al picco; oltre 350 il risultato non migliora
      # (a cap 600 n_sig cala — sample baseline extra aggiungono rumore).
      max_baseline_per_arm   = 350L,
      franchini_correction   = TRUE             # attiva correzione shared-baseline
                                                 # nel REM pooling (T6/T7).
    ),
    # ADR-0026 + decisione utente 2026-07-27: quali rami di pooling compongono
    # il DELIVERABLE. Dal re-cluster v12 il deliverable e' il solo ramo derivato
    # dal CONTRASTO (`rem_group` sui cluster `cgroup`, ADR-0025). Gli altri tre
    # escono per SELEZIONE, non per cancellazione: il loro codice resta, resta
    # testato, e torna raggiungibile passando i metodi voluti in questo campo.
    # Perche' escono:
    #   mega      -- censito 2026-07-27: il 74% dei campioni poolati viene da
    #                studi che portano UN SOLO braccio; le 99 mega sono in
    #                realta' 55 meta-analisi distinte; I2 e tau2 sono NA su
    #                tutte (ADR-0026).
    #   mega_aug  -- k=2 e 88% dei cluster con campioni prestati da altri studi.
    #   rem       -- 12 cluster = 6 meta-analisi, 5 minestroni; l'unica pulita
    #                (sarcopenia) e' gia' nel ramo nuovo con k piu' alto.
    deliverable_methods = "rem_group",
    rem_group = list(
      # FASE F6 2026-07-05: ammissione group nominati L2-L4 (safety_min basso
      # per design) al REM per-studio. safety_min NON e' un gate qui (il REM
      # modella l'eterogeneita' via I2/tau2, non la filtra). Vedi spec
      # docs/superpowers/specs/2026-07-05-stage4-rem-group-named-metaanalyses-design.md.
      k_eff_min      = 3L,               # min studi contribuenti (dopo linking control in-study)
      n_min          = 2L,               # min campioni per braccio per-studio (limma-voom richiede replica)
      excluded_kinds = c("vehicle_only", "none", ""),  # kind degeneri non-perturbativi
      # DE-FRAMMENTAZIONE (2026-08-08). Vettore con nome `scrittura -> codice
      # canonico`: le scritture che vi compaiono vengono FUSE nel loro codice
      # canonico dentro `.dedup_rem_group_by_entity()`. NULL = comportamento di
      # sempre, verificato byte-identico sui dati veri (351 candidati, insieme
      # dei cluster_id invariato).
      #
      # ⚠️ NON si popola a mano. Una tabella di equivalenze scritta a mano e' la
      # «lista travestita» che questo progetto ha gia' pagato piu' volte: va
      # GENERATA da una regola (ponte fra registri sostenuto da un nome
      # canonico, con le guardie di precisione) e la regola va misurata prima di
      # essere accesa. Misura del 2026-08-08:
      # analysis/audit/2026-08-08-deframmentazione/.
      entity_canonical = NULL,
      # Simmetrica alla precedente, sulle CHIAVI DI CONTROLLO. Due dei tre
      # ingressi sono dimenticanze del vocabolario di `.normalize_control_type()`
      # (`mock` vi sta, `uninfected` no; `normal`/`healthy`/`control` vi stanno,
      # `lean` no), il terzo (`normoxia`) ribalta una scelta deliberata perche' la
      # misura mostra che il confine non separa nulla. Evidenza e verdetti:
      # analysis/audit/2026-08-08-deframmentazione/36-verdetti-4-fusioni-dedup.csv.
      # NULL = comportamento di sempre.
      control_canonical = NULL
    ),
    schema_versions = list(
      anchor             = "v3",
      stage3_algorithm   = "v1",
      # FASE E1 ADR-0019 D6 (decisione utente 2026-05-27): gene axis
      # cambiato da HGNC make.unique a Ensembl ID univoco; output schema
      # cluster_pooled.parquet + per_study_de.parquet: colonna 'gene'
      # rinominata 'gene_id' (Ensembl) + nuova colonna 'gene_symbol' (HGNC).
      # Cache stage4-counts bumpata internamente (v2_ensembl prefix).
      stage4_algorithm   = "v2_ensembl_gene_axis",
      # FASE E2 ADR-0019 D7 (decisione utente 2026-05-28): filter
      # gene_biotype = protein_coding come default; valore effettivamente
      # passato in build_stage4_results e' registrato in
      # run_metadata\$gene_biotype_filter (override possibile a NULL = no
      # filter, o vector multi-valore).
      gene_biotype_filter_strategy = "v1_protein_coding_default",
      # FASE E3 ADR-0019 D8 (decisione utente 2026-05-28): covariate
      # batch nel design DE (instrument_model + aligner_class di
      # default). Single-level + missing + NA gestiti via
      # .augment_de_design. Valori richiesti registrati in
      # run_metadata\$de_covariates_requested.
      de_covariates_strategy = "v1_instrument_aligner_drop_single_level",
      # FASE E0b ADR-0019 D9 (decisione utente 2026-05-27 su evidence A7b).
      # Strategia di SAMN dedupe nel pool Stadio 4: per ogni SAMN cross-GSE
      # con N>=2 GSM, tenuto il GSM con lib_size max; tie-break GSM
      # alfabetico. Quando i lookup biosample_id + lib_size non sono
      # disponibili in h5_metadata, il dedupe e' off (warning emesso da
      # .build_samn_dedupe_lookups). Stringa registrata in run_metadata.json.
      samn_dedupe_strategy = "max_libsize_alphabetic_tiebreak",
      # FASE F6 2026-07-05: ramo rem_group (meta-analisi nominate al REM
      # per-studio). Bump per invalidare output/cache pre-fix.
      rem_group_strategy = "v1_per_study_rem_named_groups"
    )
  )
}

#' Risolve il numero di worker BiocParallel da config (auto-detect se NA)
#'
#' Logica:
#' \itemize{
#'   \item Se \code{config$compute$dream_workers} e' un integer, usa quello
#'         (cap a \code{dream_workers_cap}).
#'   \item Se \code{NA} (default), auto-detect via
#'         \code{parallelly::availableCores() - workers_offset}, cap a
#'         \code{dream_workers_cap}, floor a 1.
#' }
#'
#' @param config output di \code{stage4_default_config()}.
#' @return integer numero di worker per \code{BiocParallel::MulticoreParam}.
#' @keywords internal
.resolve_dream_workers <- function(config) {
  cap <- as.integer(config$compute$dream_workers_cap %||% 100L)
  w   <- config$compute$dream_workers
  if (is.null(w) || (length(w) == 1L && is.na(w))) {
    offset <- as.integer(config$compute$workers_offset %||% 10L)
    cores  <- if (requireNamespace("parallelly", quietly = TRUE)) {
      parallelly::availableCores()
    } else {
      parallel::detectCores(logical = TRUE)
    }
    w <- max(1L, as.integer(cores) - offset)
  }
  w <- as.integer(w)
  min(w, cap)
}
