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
      # dream_workers_cap 100 -> 32 (ADR-0016, 2026-05-22). Misura empirica:
      # dream su un cluster cappato (~510 sample) usa ~1 GB di RAM per worker
      # (16w->27GB, 32w->43GB, ~100w->~115GB). La memcurve di ADR-0015 (10-15
      # GB) misurava di fatto il fallback limma, NON dream (vedi ADR-0016
      # sub-finding simboli gene). A 32 worker il picco per-cluster e' ~43 GB:
      # margine ampio anche con overlap di worker orfani tra cluster, sicuro
      # per il fullrun unattended sul laptop 251 GB.
      dream_workers_cap = 32L,
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
    schema_versions = list(
      anchor             = "v3",
      stage3_algorithm   = "v1",
      stage4_algorithm   = "v1"
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
