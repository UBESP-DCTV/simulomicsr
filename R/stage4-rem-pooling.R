#' Pool REM cluster con metafor::rma REML + DL fallback
#'
#' Per ogni gene presente in >= 2 studi del per_study subset: stima random-effects
#' meta-analysis via \code{metafor::rma} con method = "REML" (default). Su
#' convergence failure (rara, ma documentata in metafor vignettes per dataset
#' degenerati), fallback a \code{method = "DL"} (DerSimonian-Laird closed-form,
#' robusto perche' non iterativo). Multiple testing correction BH within cluster
#' applicata su \code{p_value_pool}.
#'
#' Schema output allineato a \code{cluster_pooled.parquet} (plan sec. 3.4):
#' \code{cluster_id, gene, method, logFC_pool, SE_pool, p_value_pool, tau2, I2,
#' Q, Q_pval, k_effective, n_baseline_studies_augmented, FDR_BH_within_cluster,
#' direction_applied}.
#'
#' @param per_study_de_subset tibble per-study DE filtrato per singolo cluster
#'   (output di Stage 4.C). Deve contenere almeno le colonne \code{cluster_id},
#'   \code{gene}, \code{logFC}, \code{SE}, opzionalmente
#'   \code{direction_applied}.
#' @param method REM method passato a \code{metafor::rma} (default \code{"REML"}).
#' @param fallback fallback method su convergence failure (default \code{"DL"}).
#' @return tibble gene-level con cluster_pooled.parquet schema. Geni con < 2
#'   studi o per cui sia REML che DL falliscono sono esclusi. Se nessun gene
#'   sopravvive, ritorna tibble vuota con schema completo
#'   (\code{.empty_pooled_rem}).
#' @keywords internal
.pool_rem_cluster <- function(per_study_de_subset, method = "REML",
                              fallback = "DL") {
  stopifnot(
    inherits(per_study_de_subset, "data.frame"),
    "logFC" %in% names(per_study_de_subset),
    "SE" %in% names(per_study_de_subset)
  )

  if (nrow(per_study_de_subset) == 0L) {
    return(.empty_pooled_rem())
  }

  cluster_id <- unique(per_study_de_subset$cluster_id)[1]
  direction_applied <- if ("direction_applied" %in% names(per_study_de_subset)) {
    unique(per_study_de_subset$direction_applied)[1]
  } else {
    NA_character_
  }
  if (is.null(direction_applied) || is.na(direction_applied)) {
    direction_applied <- "none"
  }

  # FASE E1 ADR-0019 D6: pooling per gene_id (Ensembl, univoco). gene_symbol
  # propagato dall'input per_study_de (coerente cross-studio per stesso
  # gene_id post-E1).
  by_gene <- split(per_study_de_subset, per_study_de_subset$gene_id)

  out_rows <- vector("list", length(by_gene))
  for (i in seq_along(by_gene)) {
    g <- names(by_gene)[i]
    sub <- by_gene[[i]]
    if (nrow(sub) < 2L) next  # skip geni con < 2 studi
    gene_symbol_for_g <- if ("gene_symbol" %in% names(sub)) {
      sym_unique <- unique(sub$gene_symbol)
      sym_unique <- sym_unique[!is.na(sym_unique)]
      if (length(sym_unique) > 0L) sym_unique[1L] else NA_character_
    } else NA_character_

    res <- tryCatch(
      metafor::rma(yi = sub$logFC, sei = sub$SE, method = method),
      error = function(e) NULL,
      warning = function(w) NULL
    )

    if (is.null(res)) {
      res <- tryCatch(
        metafor::rma(yi = sub$logFC, sei = sub$SE, method = fallback),
        error = function(e) NULL
      )
    }

    if (is.null(res)) next

    out_rows[[i]] <- tibble::tibble(
      cluster_id   = cluster_id,
      gene_id      = g,
      gene_symbol  = gene_symbol_for_g,
      method       = "rem",
      logFC_pool   = as.numeric(res$b),
      SE_pool      = as.numeric(res$se),
      p_value_pool = as.numeric(res$pval),
      tau2         = as.numeric(res$tau2),
      I2           = as.numeric(res$I2),
      Q            = as.numeric(res$QE),
      Q_pval       = as.numeric(res$QEp),
      k_effective  = as.integer(res$k),
      n_baseline_studies_augmented = NA_integer_,
      FDR_BH_within_cluster = NA_real_,
      direction_applied = direction_applied
    )
  }

  out_rows <- out_rows[!vapply(out_rows, is.null, logical(1))]
  if (length(out_rows) == 0L) return(.empty_pooled_rem())

  out <- do.call(rbind, out_rows)
  if (is.null(out) || nrow(out) == 0L) return(.empty_pooled_rem())

  # FDR Benjamini-Hochberg within cluster (correzione locale al cluster).
  out$FDR_BH_within_cluster <- stats::p.adjust(out$p_value_pool, method = "BH")
  out
}

#' Tibble vuota schema cluster_pooled per output empty / edge case
#'
#' Restituisce una tibble zero-row con tutte le colonne dello schema
#' \code{cluster_pooled.parquet} ai tipi attesi. Usata da
#' \code{.pool_rem_cluster} quando input vuoto o nessun gene poolabile.
#'
#' @return tibble 0 x 14 con schema completo.
#' @keywords internal
.empty_pooled_rem <- function() {
  # FASE E1 ADR-0019 D6: 'gene' -> 'gene_id' (Ensembl) + 'gene_symbol' (HGNC).
  tibble::tibble(
    cluster_id   = character(),
    gene_id      = character(),
    gene_symbol  = character(),
    method       = character(),
    logFC_pool   = double(),
    SE_pool      = double(),
    p_value_pool = double(),
    tau2         = double(),
    I2           = double(),
    Q            = double(),
    Q_pval       = double(),
    k_effective  = integer(),
    n_baseline_studies_augmented = integer(),
    FDR_BH_within_cluster = double(),
    direction_applied = character()
  )
}
