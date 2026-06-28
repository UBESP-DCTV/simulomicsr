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
#'   \code{gene_id}, \code{gene_symbol}, \code{logFC}, \code{SE},
#'   \code{p_value}, \code{t_stat}, \code{n_treated}, \code{n_control},
#'   \code{direction_applied}. Restituisce una tibble 0-righe (stesso schema)
#'   se il disegno non ha gradi di liberta' residui (skip, con warning).
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
  # T6b Fix C2: join helper che emette warning DEDICATO se sample del
  # pool sono assenti da metadata_extra (join_incomplete), distinto dal
  # warning 'NA biologico' di .augment_de_design.
  joined <- .join_covariates_to_metadata(
    cov_metadata, metadata_extra, covariates, cluster_id
  )
  cov_metadata <- joined$metadata
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

  # Guard gradi di liberta' residui (bug 2026-06-27, Task 15 v4): se i campioni
  # non bastano a stimare la varianza residua (n_sample <= rank(design), tipico
  # studio con 1 treated + 1 control = 2 sample, design ~treatment = 2 coef),
  # limma::eBayes() lancia "No residual degrees of freedom in linear model fits"
  # come errore FATALE che abortiva l'intero run. Skip pulito invece di
  # crashare: tibble 0-righe (lo studio non entra nel pooling del cluster) +
  # warning auditabile. Stessa filosofia dello skip 'mega_rank_deficient' del
  # pooling MEGA.
  design_rank <- qr(design)$rank
  if (nrow(design) - design_rank < 1L) {
    warning(sprintf(
      "per_study DE skip (no residual df): cluster=%s study=%s n_sample=%d rank=%d n_treated=%d n_control=%d",
      cluster_id, study_id, nrow(design), design_rank, n_treated, n_control))
    return(.empty_per_study_de())
  }

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
