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
                              method_label = "mega") {
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

  # Guardia difensiva sui gene rownames: dream/variancePartition crashano con
  # "duplicate 'row.names'" se la count matrix ha rownames duplicati. ARCHS4
  # v2.5 ha 4638 simboli HGNC non unici; .fetch_counts_from_h5 li disambigua
  # gia' con make.unique, ma se un fetch_fn alternativo (mock, override) non lo
  # facesse, dream fallirebbe e .run_dream_mega ripiegherebbe SILENZIOSAMENTE
  # sul fallback limma. make.unique qui rende la funzione robusta a qualunque
  # fonte di counts. Idempotente su rownames gia' unici.
  if (anyDuplicated(rownames(counts)) > 0L) {
    rownames(counts) <- make.unique(rownames(counts))
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

  # Random-effect su study come blocking
  formula_mega <- ~ treatment + (1 | study)

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

  out <- tibble::tibble(
    cluster_id   = cluster_id,
    gene         = names(res$logFC),
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
  out
}
