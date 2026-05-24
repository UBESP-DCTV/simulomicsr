#' Top-gene table (CSV + LaTeX booktabs) per un cluster
#'
#' Top-N geni FDR<thr ranked by |logFC_pool|. Output 2 file: `top_genes.csv`
#' (machine-readable) e `top_genes.tex` (paper-ready, kableExtra booktabs).
#'
#' @param cluster_pooled_subset tibble subset per cluster.
#' @param out_dir character.
#' @param config list.
#'
#' @return list `csv_path, tex_path, caption, n_rows`.
#' @keywords internal
.build_top_gene_table <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_table

  sig <- cp[!is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr, , drop = FALSE]
  sig <- sig[order(abs(sig$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top <- head(sig, top_n)

  csv_path <- file.path(out_dir, "top_genes.csv")
  tex_path <- file.path(out_dir, "top_genes.tex")

  if (nrow(top) == 0L) {
    # CSV vuoto + LaTeX con caption esplicativa
    readr::write_csv(top, csv_path)
    writeLines(
      sprintf("%% No genes significant at FDR<%g for cluster %s.",
              fdr_thr, unique(cp$cluster_id)[1L]),
      tex_path
    )
    return(list(
      csv_path = csv_path,
      tex_path = tex_path,
      caption = sprintf("No genes significant at FDR<%g for this cluster.", fdr_thr),
      n_rows = 0L
    ))
  }

  out_cols <- c("gene", "logFC_pool", "SE_pool", "p_value_pool",
                "FDR_BH_within_cluster", "k_effective", "tau2", "I2",
                "direction_applied")
  out_cols <- intersect(out_cols, names(top))
  top_out <- top[, out_cols, drop = FALSE]

  readr::write_csv(top_out, csv_path)

  # LaTeX via kableExtra (booktabs)
  cluster_id_str <- unique(cp$cluster_id)[1L]
  tex_str <- kableExtra::kbl(
    top_out,
    format = "latex",
    booktabs = TRUE,
    digits = c(NA, 3, 3, -2, -2, 0, 3, 1, NA),
    caption = sprintf("Top %d differentially expressed genes for cluster %s (FDR<%g, ranked by $|\\\\log_2 FC|$).",
                      nrow(top_out), cluster_id_str, fdr_thr),
    label = sprintf("tab:top-genes-%s", gsub("[^a-zA-Z0-9]", "-", cluster_id_str))
  )
  writeLines(as.character(tex_str), tex_path)

  caption <- sprintf(
    "Top %d differentially expressed genes (FDR<%g, ranked by |logFC|). Full table in top_genes.csv.",
    nrow(top_out), fdr_thr
  )

  list(
    csv_path = csv_path,
    tex_path = tex_path,
    caption = caption,
    n_rows = nrow(top_out)
  )
}
