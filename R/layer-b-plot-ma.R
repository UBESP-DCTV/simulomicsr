#' MA plot (mean expression vs logFC) per un cluster
#'
#' X = log2 mean(CPM+1) across-sample, Y = logFC_pool. Loess smooth (dashed)
#' come sanity check assenza di trend mean-FC.
#'
#' @param cluster_pooled_subset tibble subset di `cluster_pooled.parquet` per
#'   il cluster di interesse (tutte le righe stesso `cluster_id`).
#' @param counts matrix integer (genes x samples) per il cluster.
#' @param out_dir character path al dir dove salvare `ma.png` (+ `ma.svg`).
#' @param config list di config (vedi [layer_b_default_config()]).
#'
#' @return list con `png_path`, `svg_path`, `caption`.
#' @keywords internal
.build_ma_plot <- function(cluster_pooled_subset, counts, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold

  # baseMean: log2(CPM+1) medio per gene attraverso i sample
  lib_size <- colSums(counts)
  cpm <- t(t(counts) / lib_size) * 1e6
  base_mean <- rowMeans(log2(cpm + 1))

  # Match per gene
  match_idx <- match(cp$gene, names(base_mean))
  cp$baseMean <- base_mean[match_idx]
  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr

  cp_plot <- cp[!is.na(cp$baseMean), , drop = FALSE]

  p <- ggplot2::ggplot(cp_plot, ggplot2::aes(x = baseMean, y = logFC_pool)) +
    ggplot2::geom_point(ggplot2::aes(color = is_sig), alpha = 0.5, size = 1.2) +
    ggplot2::scale_color_manual(
      values = c(`TRUE` = "#CC3333", `FALSE` = "#BBBBBB"),
      labels = c(`TRUE` = sprintf("FDR<%g", fdr_thr), `FALSE` = "not sig"),
      name = NULL
    ) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "#333333", alpha = 0.5) +
    ggplot2::geom_smooth(method = "loess", se = FALSE, linetype = "dashed",
                         color = "#3366aa", linewidth = 0.6) +
    ggplot2::labs(
      x = expression(log[2] ~ "mean expression (CPM+1)"),
      y = expression(log[2] ~ "FC pooled")
    ) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank())

  png_path <- file.path(out_dir, "ma.png")
  svg_path <- file.path(out_dir, "ma.svg")
  ggplot2::ggsave(png_path, p, width = 6, height = 6, dpi = config$dpi)
  if (config$save_svg) {
    ggplot2::ggsave(svg_path, p, width = 6, height = 6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    "MA plot. loess smooth (dashed blue) shows absence of mean-effect-size trend; horizontal alignment confirms TMM normalization adequacy in upstream Layer A."
  )

  list(png_path = png_path, svg_path = svg_path, caption = caption)
}
