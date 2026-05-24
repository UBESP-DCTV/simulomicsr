#' Volcano plot publication-grade per un cluster
#'
#' Genera volcano plot (logFC_pool vs -log10(p_value_pool)) con FDR<0.05 color,
#' top-N labels via ggrepel. Salva PNG (DPI configurabile) + SVG.
#'
#' @param cluster_pooled_subset tibble subset di `cluster_pooled.parquet` per il
#'   cluster di interesse (tutte le righe stesso `cluster_id`).
#' @param out_dir character path al dir dove salvare `volcano.png` + `volcano.svg`.
#' @param config list di config (vedi [layer_b_default_config()]).
#'
#' @return list con `png_path`, `svg_path`, `caption`.
#' @keywords internal
.build_volcano <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_volcano_labels

  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr
  cp$neg_log10_p <- -log10(pmax(cp$p_value_pool, .Machine$double.xmin))

  n_total <- nrow(cp)
  n_sig <- sum(cp$is_sig, na.rm = TRUE)

  # Top-N labels: ranked by |logFC| * -log10(FDR) tra i sig
  cp$label_score <- abs(cp$logFC_pool) * (-log10(pmax(cp$FDR_BH_within_cluster, .Machine$double.xmin)))
  sig_idx <- which(cp$is_sig)
  if (length(sig_idx) > 0L) {
    ranked_sig <- sig_idx[order(cp$label_score[sig_idx], decreasing = TRUE)]
    top_idx <- head(ranked_sig, top_n)
    cp$label <- ifelse(seq_len(nrow(cp)) %in% top_idx, cp$gene, NA_character_)
  } else {
    cp$label <- NA_character_
  }

  # Rasterizza il layer di punti nel SVG (axis/labels/legend restano vector).
  # ggrastr e' in Suggests: fallback skip-graceful se non installato (SVG resta
  # full vector e quindi piu' grande, ma plot e' identico). Per N~28k geni la
  # rasterizzazione porta volcano.svg da ~5MB a ~150-300KB.
  use_rasterize <- requireNamespace("ggrastr", quietly = TRUE)
  point_layer <- ggplot2::geom_point(
    ggplot2::aes(color = is_sig), alpha = 0.6, size = 1.5
  )
  if (use_rasterize) {
    point_layer <- ggrastr::rasterise(point_layer, dpi = config$dpi)
  }

  p <- ggplot2::ggplot(cp, ggplot2::aes(x = logFC_pool, y = neg_log10_p)) +
    point_layer +
    ggplot2::scale_color_manual(
      values = c(`TRUE` = "#CC3333", `FALSE` = "#BBBBBB"),
      labels = c(`TRUE` = sprintf("FDR<%g", fdr_thr), `FALSE` = "not sig"),
      name = NULL
    ) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "#333333", alpha = 0.5) +
    ggrepel::geom_text_repel(
      ggplot2::aes(label = label),
      size = 3, max.overlaps = top_n,
      box.padding = 0.3, segment.alpha = 0.5,
      na.rm = TRUE
    ) +
    ggplot2::labs(
      x = expression(log[2] ~ "FC pooled"),
      y = expression(-log[10] ~ "p-value pooled")
    ) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank()
    )

  png_path <- file.path(out_dir, "volcano.png")
  svg_path <- file.path(out_dir, "volcano.svg")

  ggplot2::ggsave(png_path, p, width = 6, height = 6, dpi = config$dpi)
  if (config$save_svg) {
    ggplot2::ggsave(svg_path, p, width = 6, height = 6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    "Volcano plot for cluster %s. %d of %d genes significant at FDR<%g (BH-corrected within cluster).",
    unique(cp$cluster_id), n_sig, n_total, fdr_thr
  )

  list(
    png_path = png_path,
    svg_path = svg_path,
    caption = caption
  )
}
