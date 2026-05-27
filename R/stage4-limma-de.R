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
                                direction_flip = FALSE) {
  stopifnot(
    is.matrix(counts) || is.data.frame(counts),
    is.factor(treatment_vec),
    "control" %in% levels(treatment_vec),
    "treated" %in% levels(treatment_vec),
    ncol(counts) == length(treatment_vec)
  )

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

  design <- stats::model.matrix(~ treatment_vec)
  colnames(design) <- c("(Intercept)", "treatmenttreated")

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
  tibble::tibble(
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
}
