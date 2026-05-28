#' Cache key per fetch counts ARCHS4
#'
#' xxhash32 di (axis_version, biotype_filter, gse, sorted(sample_ids))
#' -> 8-hex stabile.
#'
#' FASE E1 ADR-0019 D6: prefisso \code{v2_ensembl::} nel payload bumpa
#' la chiave rispetto alla cache pre-E1, che memoizzava matrici con
#' rownames = HGNC symbol \code{make.unique()}. Post-E1 i rownames sono
#' Ensembl ID e gli attr \code{gene_symbol} sono attaccati: cache stale
#' produrrebbe row-axis incoerente -> invalidazione automatica.
#'
#' FASE E2 ADR-0019 D7: aggiunto segmento \code{biotype::<filter>}
#' (ordinato + dedup per neutralizzare permutazioni). Stratifica la
#' cache per il filter biotype attivo, in modo che una run con
#' \code{protein_coding} non collida con una run NULL o
#' \code{c('protein_coding', 'lncRNA')}.
#'
#' @param gse string GSE accession
#' @param sample_ids character vector di GSM ids
#' @param gene_biotype_filter character vector o NULL (default
#'   \code{"protein_coding"} per coerenza con \code{.fetch_counts_from_h5}).
#' @keywords internal
.cache_key_for_fetch <- function(gse, sample_ids,
                                   gene_biotype_filter = "protein_coding") {
  sorted_samples <- sort(sample_ids)
  biotype_seg <- if (is.null(gene_biotype_filter)) {
    "NULL"
  } else {
    # Ordinamento + unique normalizzano permutazioni:
    # c('protein_coding', 'lncRNA') ~ c('lncRNA', 'protein_coding') -> stessa key.
    paste(sort(unique(as.character(gene_biotype_filter))), collapse = "|")
  }
  payload <- paste0(
    "v2_ensembl::biotype::", biotype_seg, "::",
    gse, "_", paste(sorted_samples, collapse = "|")
  )
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
#'   \code{.fetch_counts_from_h5(gse, sample_ids, h5_path,
#'   gene_biotype_filter)} (per testabilita').
#' @param cache_dir cache directory; default \code{.default_stage4_cache_dir()}
#' @param gene_biotype_filter character vector o NULL (FASE E2 ADR-0019 D7,
#'   default \code{"protein_coding"}). Propagato a \code{.fetch_counts_from_h5}
#'   + incluso in \code{.cache_key_for_fetch} per stratificare la cache.
#' @return integer matrix (genes x samples) post-biotype filter +
#'   attr('gene_symbol') + attr('gene_biotype').
#' @keywords internal
.fetch_counts_cached <- function(gse, sample_ids, h5_path = NULL,
                                  fetch_fn = NULL,
                                  cache_dir = NULL,
                                  gene_biotype_filter = "protein_coding") {
  if (is.null(cache_dir)) cache_dir <- .default_stage4_cache_dir()
  if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)

  key <- .cache_key_for_fetch(gse, sample_ids,
                                gene_biotype_filter = gene_biotype_filter)
  cache_file <- file.path(cache_dir, paste0(key, ".rds"))

  if (file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  if (is.null(fetch_fn)) {
    if (is.null(h5_path)) stop("h5_path required when fetch_fn is NULL")
    fetch_fn <- function(g, s) .fetch_counts_from_h5(
      g, s, h5_path, gene_biotype_filter = gene_biotype_filter
    )
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

#' Gene axis (Ensembl ID + HGNC symbol) di un H5, memoizzato
#'
#' FASE E1 (ADR-0019 D6): legge sia \code{meta/genes/ensembl_gene} (axis
#' univoco, 67186 ID distinti in ARCHS4 v2.5) sia \code{meta/genes/symbol}
#' (annotation, 4638 simboli duplicati per paralogi) e li impacchetta via
#' \code{.parse_gene_axis()}. Cache key bumpata a \code{v2_ensembl}:
#' invalida automaticamente la cache pre-E1 che memoizzava
#' \code{make.unique(symbol)}.
#'
#' @return list \code{(ensembl_gene, gene_symbol)} (output di
#'   \code{.parse_gene_axis}).
#' @keywords internal
.h5_gene_axis <- function(h5_path) {
  # FASE E2 ADR-0019 D7: cache key bumpata v3_with_biotype perche' E1
  # axis a 2-componenti non includeva gene_biotype. Le run pre-E2
  # invalidano automaticamente la cache memo.
  k <- paste0("genes::v3_with_biotype::", h5_path)
  if (is.null(.h5_axis_memo[[k]])) {
    ens <- as.character(rhdf5::h5read(h5_path, "meta/genes/ensembl_gene"))
    sym <- as.character(rhdf5::h5read(h5_path, "meta/genes/symbol"))
    # T7a Fix 5: errore esplicito se H5 manca meta/genes/biotype (es.
    # ARCHS4 v1 legacy schema). Senza il check, h5read genera errore
    # criptico tipo "An object with name 'meta/genes/biotype' does not
    # exist" che non suggerisce la causa scientifica (axis schema
    # incompatibile col filter FASE E2).
    bt <- tryCatch(
      as.character(rhdf5::h5read(h5_path, "meta/genes/biotype")),
      error = function(e) {
        stop(sprintf(
          paste0("H5 path '%s' non contiene meta/genes/biotype: filter ",
                 "biotype (FASE E2 ADR-0019 D7) richiede ARCHS4 v2.5+ ",
                 "schema. Per H5 legacy senza biotype, passa ",
                 "gene_biotype_filter = NULL a build_stage4_results. ",
                 "Errore originale rhdf5: %s"),
          h5_path, conditionMessage(e)
        ), call. = FALSE)
      }
    )
    .h5_axis_memo[[k]] <- .parse_gene_axis(ens, sym, bt)
  }
  .h5_axis_memo[[k]]
}

#' Fetch counts da ARCHS4 H5 (low-level, no cache)
#'
#' @param gse string GSE accession
#' @param sample_ids character vector di GSM ids
#' @param h5_path path al H5 ARCHS4
#' @param gene_biotype_filter character vector di biotype Ensembl da
#'   mantenere (FASE E2 ADR-0019 D7, default \code{"protein_coding"}).
#'   NULL = no filter (tutti i ~67k geni). Applicato PRE-cache (cache
#'   key stratifica per filter, vedi \code{.cache_key_for_fetch}).
#' @return integer matrix (genes x samples) con rownames = ensembl_gene +
#'   colnames = GSM accession + attr('gene_symbol') named +
#'   attr('gene_biotype') named.
#' @keywords internal
.fetch_counts_from_h5 <- function(gse, sample_ids, h5_path,
                                    gene_biotype_filter = "protein_coding") {
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

  # Rownames = Ensembl gene ID (axis univoco per costruzione, 67186 ID distinti
  # in ARCHS4 v2.5, 0 NA). HGNC symbol (con 4638 duplicati per paralogi:
  # KIR3DL2 x43, HLA, ...) e' attaccato come attr(counts, "gene_symbol") named
  # vec con names=ensembl_gene per consentire lookup post-filterByExpr.
  # FASE E1 (ADR-0019 D6): rimossa la patch make.unique() che mascherava
  # paralogi sotto rownames sintetici.
  # FASE E2 (ADR-0019 D7): se gene_biotype_filter non NULL, subset di axis +
  # counts ai soli geni col biotype richiesto (default 'protein_coding',
  # 22881/67186 = 34%). Filter applicato PRE-cache disk (vedi
  # .cache_key_for_fetch) -> cache stratifica per filter, e tutto
  # downstream (.run_dream_mega, .run_limma_voom_de) opera sui geni
  # filtrati senza ulteriore lavoro.
  axis <- .h5_gene_axis(h5_path)
  if (!is.null(gene_biotype_filter)) {
    filt <- .apply_biotype_filter(counts, axis, gene_biotype_filter)
    counts <- filt$counts
    axis   <- filt$gene_axis
  }
  colnames(counts) <- sample_ids
  counts <- .attach_gene_annotation(counts, axis)

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
