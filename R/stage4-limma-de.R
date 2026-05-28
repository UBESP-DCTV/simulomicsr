#' Run limma-voom + eBayes per single (cluster, study)
#'
#' Pipeline: DGEList -> filterByExpr -> normLibSizes(TMM) -> voom ->
#' lmFit -> eBayes -> per-gene extraction (logFC, SE, p, t).
#'
#' Direction flip: se \code{direction_flip=TRUE} (cluster con
#' \code{direction_check="swapped"} da Stage 3), il logFC viene negato in
#' output. Il flip e' applicato dopo l'estrazione coefficiente, quindi non
#' altera SE/p/t (la statistica resta valida; cambia solo il segno
#' dell'effect size per allineare la direzione canonica cross-study).
#'
#' @param counts integer matrix o data.frame (geni x sample). Le righe sono
#'   geni (rownames = gene symbol), le colonne sample (colnames = GSM).
#' @param treatment_vec factor di lunghezza \code{ncol(counts)} con levels
#'   \code{c("control", "treated")}.
#' @param study_id string GSE accession.
#' @param cluster_id string cluster_id per output column.
#' @param direction_flip logical: se TRUE, moltiplica logFC per -1 e setta
#'   \code{direction_applied="flipped"}; altrimenti \code{"none"}.
#' @return tibble con colonne \code{cluster_id}, \code{study_id},
#'   \code{gene}, \code{logFC}, \code{SE}, \code{p_value}, \code{t_stat},
#'   \code{n_treated}, \code{n_control}, \code{direction_applied}.
#' @keywords internal
.run_limma_voom_de <- function(counts, treatment_vec, study_id, cluster_id,
                                direction_flip = FALSE,
                                metadata_extra = NULL,
                                covariates = character(0)) {
  stopifnot(
    is.matrix(counts) || is.data.frame(counts),
    is.factor(treatment_vec),
    "control" %in% levels(treatment_vec),
    "treated" %in% levels(treatment_vec),
    ncol(counts) == length(treatment_vec)
  )

  # FASE E3 ADR-0019 D8: costruisco metadata locale per il design DE
  # con eventuali covariate batch. Per-studio (limma-voom) le covariate
  # tipiche (instrument_model, aligner_class) sono spesso single-level
  # entro un singolo GSE -> auto-droppate da .augment_de_design.
  cov_metadata <- data.frame(
    sample_id = colnames(counts) %||% paste0("S", seq_len(ncol(counts))),
    treatment = treatment_vec,
    stringsAsFactors = FALSE
  )
  if (!is.null(metadata_extra) && length(covariates) > 0L) {
    idx <- match(cov_metadata$sample_id, metadata_extra$sample_id)
    for (cov in covariates) {
      if (cov %in% names(metadata_extra)) {
        cov_metadata[[cov]] <- metadata_extra[[cov]][idx]
      }
    }
  }
  aug <- .augment_de_design(cov_metadata, covariates, cluster_id)

  # FASE E1: estrai mapping Ensembl -> HGNC symbol PRIMA di edgeR::DGEList
  # (che scarta gli attr aggiuntivi della matrice). Lookup post-filterByExpr
  # via subscripting per-rownames(fit). Retrocompat: counts senza
  # attr("gene_symbol") -> tutti NA (pre-E1 path).
  gene_symbol_lookup <- attr(counts, "gene_symbol")
  if (is.null(gene_symbol_lookup)) {
    gene_symbol_lookup <- setNames(
      rep(NA_character_, nrow(counts)),
      rownames(counts)
    )
  }

  n_treated <- sum(treatment_vec == "treated")
  n_control <- sum(treatment_vec == "control")

  dge <- edgeR::DGEList(counts = counts, group = treatment_vec)
  keep <- edgeR::filterByExpr(dge, group = treatment_vec)
  dge <- dge[keep, , keep.lib.sizes = FALSE]
  dge <- edgeR::normLibSizes(dge, method = "TMM")

  # FASE E3: design con eventuali covariate batch (instrument + aligner
  # se forniti e multi-level). Aggiungo treatment come prima colonna
  # post-intercept per preservare il pattern di estrazione coef
  # ('treatmenttreated' sempre presente).
  if (aug$formula_terms == "") {
    design <- stats::model.matrix(~ treatment, data = aug$metadata_aug)
  } else {
    design <- stats::model.matrix(
      stats::as.formula(paste("~ treatment +", aug$formula_terms)),
      data = aug$metadata_aug
    )
  }
  # Rinomina intercept + treatmenttreated per coerenza con il codice
  # post-fit; le colonne covariate restano col loro nome model.matrix.
  cn <- colnames(design)
  cn[cn == "(Intercept)"]    <- "(Intercept)"
  cn[cn == "treatmenttreated"] <- "treatmenttreated"
  colnames(design) <- cn

  v   <- limma::voom(dge, design)
  fit <- limma::lmFit(v, design)
  fit <- limma::eBayes(fit)

  logFC  <- fit$coefficients[, "treatmenttreated"]
  SE     <- sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"]
  p_val  <- fit$p.value[, "treatmenttreated"]
  t_stat <- fit$t[, "treatmenttreated"]

  if (direction_flip) {
    logFC <- -logFC
    direction_applied <- "flipped"
  } else {
    direction_applied <- "none"
  }

  fit_genes <- rownames(fit)
  out <- tibble::tibble(
    cluster_id        = cluster_id,
    study_id          = study_id,
    gene_id           = fit_genes,
    gene_symbol       = unname(gene_symbol_lookup[fit_genes]),
    logFC             = unname(logFC),
    SE                = unname(SE),
    p_value           = unname(p_val),
    t_stat            = unname(t_stat),
    n_treated         = n_treated,
    n_control         = n_control,
    direction_applied = direction_applied
  )
  # FASE E3: covariate tracking come attr. NULL quando covariates default
  # character(0) (retrocompat) per preservare il check 'is.null' del test
  # T2.1. Altrimenti char(0) o nome covariate.
  if (length(covariates) > 0L) {
    attr(out, "covariates_used")    <- aug$covariates_used
    attr(out, "covariates_dropped") <- aug$covariates_dropped
    attr(out, "covariate_drop_log") <- aug$drop_log
  }
  out
}
