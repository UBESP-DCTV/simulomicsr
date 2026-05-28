#' Run dream mixed-effect model per MEGA / MEGA-AUG cluster
#'
#' Modello: \code{~ treatment + (1|study)} su counts assembled cross-study.
#' Pipeline: DGEList -> filterByExpr -> normLibSizes(TMM) ->
#' voomWithDreamWeights -> dream -> eBayes -> per-gene extraction.
#'
#' Fallback: se dream fallisce (rare convergence issues), retry con limma-voom
#' + duplicateCorrelation(block=study) come modello surrogate dello stesso
#' contrasto, preservando la stessa interfaccia di output (logFC, SE, p).
#'
#' @param counts integer matrix (geni x sample) assembled cross-study.
#' @param metadata data.frame con (sample_id, study factor, treatment factor).
#'   Treatment deve avere levels \code{c("control", "treated")}.
#' @param cluster_id string cluster_id per output column.
#' @param workers integer numero di worker BiocParallel (default 1L, serial).
#' @param n_baseline_studies_augmented integer NA per MEGA, n studi baseline
#'   pool per MEGA-AUG.
#' @param method_label string label di metodo per la colonna \code{method}
#'   (default \code{"mega"}; usato \code{"mega_aug"} dal chiamante MEGA-AUG).
#' @return tibble gene-level con cluster_pooled.parquet schema:
#'   \code{cluster_id}, \code{gene}, \code{method}, \code{logFC_pool},
#'   \code{SE_pool}, \code{p_value_pool}, \code{tau2}, \code{I2}, \code{Q},
#'   \code{Q_pval}, \code{k_effective}, \code{n_baseline_studies_augmented},
#'   \code{FDR_BH_within_cluster}, \code{direction_applied}.
#' @keywords internal
.run_dream_mega <- function(counts, metadata, cluster_id, workers = 1L,
                              n_baseline_studies_augmented = NA_integer_,
                              method_label = "mega",
                              covariates = character(0)) {
  stopifnot(
    is.matrix(counts),
    is.data.frame(metadata),
    all(c("sample_id", "study", "treatment") %in% names(metadata)),
    is.factor(metadata$study),
    is.factor(metadata$treatment),
    "control" %in% levels(metadata$treatment),
    "treated" %in% levels(metadata$treatment),
    ncol(counts) == nrow(metadata)
  )

  # Guardia difensiva (defense-in-depth): sample_id duplicati in metadata
  # crashano `rownames(metadata) <-` con il criptico ".rowNamesDF<-: duplicate
  # 'row.names'". Qualunque path di assembly upstream che producesse duplicati
  # (es. lo stesso group baseline pool su entrambi i bracci MEGA-AUG, vedi
  # .assemble_mega_aug_metadata_bidir sez. 3b) deve fallire QUI con un errore
  # esplicito e cluster-named, intercettabile dal tryCatch dell'orchestrator.
  dup_i <- anyDuplicated(metadata$sample_id)
  if (dup_i > 0L) {
    stop(sprintf(
      "metadata$sample_id contiene duplicati (es. '%s') per cluster %s: bug di assembly upstream, il pooling non puo' procedere",
      metadata$sample_id[dup_i], cluster_id
    ))
  }

  # FASE E1 (ADR-0019 D6): defensive make.unique() RIMOSSO. La sorgente del
  # bug paralogi pre-E1 (ADR-0016 Decision 2 / Discovery 2026-05-21) era
  # rownames(counts) = HGNC symbol che ARCHS4 ha duplicati. Post-E1
  # .fetch_counts_from_h5 usa Ensembl come rownames (univoco per
  # costruzione, 67186 ID distinti, 0 NA). La guardia anyDuplicated()
  # sotto e' mantenuta come safety net per fetch_fn alternativi (mock,
  # override) che potrebbero ancora produrre rownames duplicati.
  #
  # FASE E1: estrai mapping Ensembl -> HGNC symbol PRIMA di edgeR (che
  # scarta gli attr della matrice). Retrocompat: counts senza
  # attr("gene_symbol") -> tutti NA.
  gene_symbol_lookup <- attr(counts, "gene_symbol")
  if (is.null(gene_symbol_lookup)) {
    gene_symbol_lookup <- setNames(
      rep(NA_character_, nrow(counts)),
      rownames(counts)
    )
  }
  if (anyDuplicated(rownames(counts)) > 0L) {
    stop(sprintf(
      "rownames(counts) per cluster %s contiene duplicati: post-E1 attesi rownames Ensembl univoci",
      cluster_id
    ), call. = FALSE)
  }

  # Allinea rownames(metadata) a colnames(counts) per silenziare warning
  # variancePartition::filterInputData (sample names check). I tibble non
  # supportano rownames persistenti -> coerce a base data.frame.
  metadata <- as.data.frame(metadata, stringsAsFactors = FALSE)
  rownames(metadata) <- metadata$sample_id

  # Pipeline counts: DGEList -> filterByExpr -> TMM
  dge <- edgeR::DGEList(counts = counts)
  keep <- edgeR::filterByExpr(dge, group = metadata$treatment)
  dge <- dge[keep, , keep.lib.sizes = FALSE]
  dge <- edgeR::normLibSizes(dge, method = "TMM")

  # FASE E3 ADR-0019 D8: covariate batch nel design (instrument_model +
  # aligner_class di default se forniti). .augment_de_design gestisce
  # single-level drop + NA -> 'unknown'. Per dream cross-study le
  # covariate hanno effetto sostanziale (variano cross-GSE).
  aug <- .augment_de_design(metadata, covariates, cluster_id)
  metadata <- aug$metadata_aug

  # Random-effect su study come blocking; fixed effects = treatment + covariate
  formula_mega <- if (aug$formula_terms == "") {
    ~ treatment + (1 | study)
  } else {
    stats::as.formula(paste("~ treatment +", aug$formula_terms, "+ (1 | study)"))
  }

  # BiocParallel backend: serial se workers == 1, altrimenti multicore
  bpparam <- if (workers > 1L) {
    BiocParallel::MulticoreParam(workers)
  } else {
    BiocParallel::SerialParam()
  }

  res <- tryCatch({
    vobj <- variancePartition::voomWithDreamWeights(
      dge, formula = formula_mega, data = metadata, BPPARAM = bpparam
    )
    fitmm <- variancePartition::dream(
      vobj, formula = formula_mega, data = metadata, BPPARAM = bpparam
    )
    fitmm <- variancePartition::eBayes(fitmm)

    logFC <- fitmm$coefficients[, "treatmenttreated"]
    SE    <- sqrt(fitmm$s2.post) * fitmm$stdev.unscaled[, "treatmenttreated"]
    p_val <- fitmm$p.value[, "treatmenttreated"]

    list(logFC = logFC, SE = SE, p_val = p_val, ok = TRUE)
  }, error = function(e) {
    list(error = conditionMessage(e), ok = FALSE)
  })

  if (!isTRUE(res$ok)) {
    # Fallback: limma-voom + duplicateCorrelation(block = study).
    # Modello fixed-effect senza random effect; study e' modellato come
    # correlazione intra-blocco via duplicateCorrelation.
    design <- stats::model.matrix(~ treatment, data = metadata)
    colnames(design) <- c("(Intercept)", "treatmenttreated")
    v <- limma::voom(dge, design)
    corr <- limma::duplicateCorrelation(v, design, block = metadata$study)
    fit <- limma::lmFit(v, design, block = metadata$study,
                         correlation = corr$consensus)
    fit <- limma::eBayes(fit)
    logFC <- fit$coefficients[, "treatmenttreated"]
    SE    <- sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"]
    p_val <- fit$p.value[, "treatmenttreated"]
    res <- list(logFC = logFC, SE = SE, p_val = p_val, ok = TRUE)
  }

  out_gene_ids <- names(res$logFC)
  out <- tibble::tibble(
    cluster_id   = cluster_id,
    gene_id      = out_gene_ids,
    gene_symbol  = unname(gene_symbol_lookup[out_gene_ids]),
    method       = method_label,
    logFC_pool   = unname(res$logFC),
    SE_pool      = unname(res$SE),
    p_value_pool = unname(res$p_val),
    tau2         = NA_real_,
    I2           = NA_real_,
    Q            = NA_real_,
    Q_pval       = NA_real_,
    k_effective  = as.integer(nlevels(metadata$study)),
    n_baseline_studies_augmented = n_baseline_studies_augmented,
    FDR_BH_within_cluster = NA_real_,
    direction_applied = "none"
  )
  out$FDR_BH_within_cluster <- stats::p.adjust(out$p_value_pool, method = "BH")
  # FASE E3: covariate tracking via attr (solo se covariates overridden).
  if (length(covariates) > 0L) {
    attr(out, "covariates_used")    <- aug$covariates_used
    attr(out, "covariates_dropped") <- aug$covariates_dropped
    attr(out, "covariate_drop_log") <- aug$drop_log
  }
  out
}
