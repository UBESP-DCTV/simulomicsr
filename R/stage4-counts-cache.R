#' Cache key per fetch counts ARCHS4
#'
#' xxhash32 di (gse, sorted(sample_ids)) -> 8-hex stabile.
#'
#' @keywords internal
.cache_key_for_fetch <- function(gse, sample_ids) {
  sorted <- sort(sample_ids)
  payload <- paste0(gse, "_", paste(sorted, collapse = "|"))
  hash <- digest::digest(payload, algo = "xxhash32", serialize = FALSE)
  substr(hash, 1L, 8L)
}

#' Default cache dir per Stadio 4 counts
#'
#' @keywords internal
.default_stage4_cache_dir <- function() {
  base <- tools::R_user_dir("simulomicsr", which = "cache")
  file.path(base, "stage4-counts")
}

#' Fetch counts ARCHS4 con cache persistente
#'
#' @param gse string GSE accession
#' @param sample_ids character vector di GSM ids
#' @param h5_path path al H5 ARCHS4 (NULL se fetch_fn override fornito)
#' @param fetch_fn function (gse, sample_ids) -> matrix; default chiama
#'   \code{.fetch_counts_from_h5} (per testabilita').
#' @param cache_dir cache directory; default \code{.default_stage4_cache_dir()}
#' @return integer matrix (genes x samples)
#' @keywords internal
.fetch_counts_cached <- function(gse, sample_ids, h5_path = NULL,
                                  fetch_fn = NULL,
                                  cache_dir = NULL) {
  if (is.null(cache_dir)) cache_dir <- .default_stage4_cache_dir()
  if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)

  key <- .cache_key_for_fetch(gse, sample_ids)
  cache_file <- file.path(cache_dir, paste0(key, ".rds"))

  if (file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  if (is.null(fetch_fn)) {
    if (is.null(h5_path)) stop("h5_path required when fetch_fn is NULL")
    fetch_fn <- function(g, s) .fetch_counts_from_h5(g, s, h5_path)
  }

  counts <- fetch_fn(gse, sample_ids)
  saveRDS(counts, cache_file, compress = "xz")
  counts
}

#' Memo degli assi H5 (sample axis + gene axis)
#'
#' \code{.fetch_counts_from_h5} e' chiamato migliaia di volte in un fullrun
#' (una per studio per cluster). Ri-leggere ad ogni chiamata i ~888k
#' \code{geo_accession} e i ~67k \code{genes/symbol} dominava il wall.
#' Gli assi sono immutabili per un dato file H5: memoizzati nel namespace.
#'
#' @keywords internal
.h5_axis_memo <- new.env(parent = emptyenv())

#' Sample axis (geo_accession) di un H5, memoizzato
#' @keywords internal
.h5_sample_axis <- function(h5_path) {
  k <- paste0("samples::", h5_path)
  if (is.null(.h5_axis_memo[[k]])) {
    .h5_axis_memo[[k]] <- as.character(
      rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
  }
  .h5_axis_memo[[k]]
}

#' Gene axis (HGNC symbol, make.unique) di un H5, memoizzato
#' @keywords internal
.h5_gene_axis <- function(h5_path) {
  k <- paste0("genes::", h5_path)
  if (is.null(.h5_axis_memo[[k]])) {
    .h5_axis_memo[[k]] <- make.unique(as.character(
      rhdf5::h5read(h5_path, "meta/genes/symbol")))
  }
  .h5_axis_memo[[k]]
}

#' Fetch counts da ARCHS4 H5 (low-level, no cache)
#'
#' @param gse string GSE accession
#' @param sample_ids character vector di GSM ids
#' @param h5_path path al H5 ARCHS4
#' @return integer matrix (genes x samples) con rownames HGNC symbol +
#'   colnames GSM accession.
#' @keywords internal
.fetch_counts_from_h5 <- function(gse, sample_ids, h5_path) {
  # Sample index dall'asse H5 memoizzato (vedi .h5_sample_axis)
  all_gsm <- .h5_sample_axis(h5_path)
  idx <- match(sample_ids, all_gsm)
  if (any(is.na(idx))) {
    stop(sprintf("Sample IDs not found in H5: %s",
                 paste(sample_ids[is.na(idx)], collapse = ", ")))
  }

  # ARCHS4 v2.5 expression e' (samples x genes): leggi righe per i sample
  # richiesti, poi traspone a (genes x samples) per downstream limma/edgeR.
  counts <- rhdf5::h5read(h5_path, "data/expression",
                          index = list(idx, NULL))
  counts <- t(counts)
  storage.mode(counts) <- "integer"

  # Rownames = HGNC symbol (gene axis memoizzato, vedi .h5_gene_axis); colnames
  # = GSM. ARCHS4 v2.5 meta/genes/symbol NON e' unico: 4638/67186 simboli sono
  # duplicati (es. KIR3DL2 x43 — piu' gene Ensembl sullo stesso simbolo HGNC).
  # Rownames duplicati fanno fallire dream con "duplicate 'row.names'" ->
  # .run_dream_mega ripiega silenziosamente sul fallback limma. .h5_gene_axis
  # applica make.unique (KIR3DL2, KIR3DL2.1, ...), deterministico: ogni fetch
  # produce gli stessi rownames -> concat cross-study coerente. Discovery
  # 2026-05-21.
  rownames(counts) <- .h5_gene_axis(h5_path)
  colnames(counts) <- sample_ids

  counts
}

#' Prefetch counts per tutti i cluster eligible Stage 4
#'
#' Itera su tutti gli (gse, sample_ids) unique negli eligible cluster e
#' popola la cache. Output manifest path -> cache_key.
#'
#' @param eligible_clusters tibble output di \code{.qc_filter_samples_and_studies}.
#' @param h5_path path al H5 ARCHS4.
#' @param cache_dir cache dir; default \code{.default_stage4_cache_dir()}.
#' @return tibble (gse, n_samples, cache_key, cache_path, status)
#' @export
prefetch_counts_for_clusters <- function(eligible_clusters, h5_path,
                                          cache_dir = NULL) {
  if (is.null(cache_dir)) cache_dir <- .default_stage4_cache_dir()

  # Itera unique (gse, sample_ids) -- implementazione delegata al chiamante
  # per ora: stub che ritorna tibble vuota.
  # Versione full sara' implementata in Task orchestrator quando vediamo
  # come i sample_ids sono propagati da Stage 3.
  tibble::tibble(
    gse = character(),
    n_samples = integer(),
    cache_key = character(),
    cache_path = character(),
    status = character()
  )
}

#' Purge cache counts Stadio 4
#'
#' Opt-in cleanup. Mai chiamato automaticamente.
#'
#' @param cache_dir cache dir; default \code{.default_stage4_cache_dir()}.
#' @param older_than_days se non-NULL, rimuovi solo file piu' vecchi di N giorni.
#' @return invisible(integer) numero di file rimossi.
#' @export
cache_purge_stage4 <- function(cache_dir = NULL, older_than_days = NULL) {
  if (is.null(cache_dir)) cache_dir <- .default_stage4_cache_dir()
  if (!dir.exists(cache_dir)) return(invisible(0L))

  files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(files) == 0L) return(invisible(0L))

  if (!is.null(older_than_days)) {
    cutoff <- Sys.time() - older_than_days * 86400
    files <- files[file.info(files)$mtime < cutoff]
  }

  file.remove(files)
  invisible(length(files))
}
