#' Heterogeneity panel (tau^2 + I^2 + REM-amenable split) -- REM only
#'
#' Pannello 2x1: (a) histogram tau^2 per-gene; (b) split bar REM-amenable
#' (`tau2 < 0.1`) vs REM-resisted (`tau2 >= 0.1`) con `%` di geni FDR<0.05
#' in ciascuna classe. Skip se metodo non-REM (mega, mega_aug) perche
#' tau^2 per-gene non e' stimabile.
#'
#' @param cluster_pooled_subset tibble subset di `cluster_pooled.parquet`
#'   per il cluster di interesse.
#' @param out_dir character path al dir dove salvare `heterogeneity.png`
#'   (e opzionale `heterogeneity.svg`).
#' @param config list di config (vedi [layer_b_default_config()]).
#'
#' @return list con `png_path`, `svg_path`, `caption`.
#' @keywords internal
.build_heterogeneity_panel <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  method <- unique(cp$method)[1L]

  png_path <- file.path(out_dir, "heterogeneity.png")
  svg_path <- file.path(out_dir, "heterogeneity.svg")

  if (method != "rem") {
    grDevices::png(png_path, width = 8, height = 4, units = "in", res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5, sprintf("Heterogeneity panel N/A\n(method = %s, REM-only)", method))
    grDevices::dev.off()
    return(list(
      png_path = png_path,
      svg_path = NA_character_,
      caption = sprintf(
        "Heterogeneity panel N/A for non-REM methods (method=%s); per-gene tau^2 not estimable in mixed-model framework (mega) or pair-only design (mega_aug).",
        method
      )
    ))
  }

  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr
  cp$tau2_class <- ifelse(
    is.na(cp$tau2), NA_character_,
    ifelse(cp$tau2 < 0.1, "REM-amenable (tau2<0.1)", "REM-resisted (tau2>=0.1)")
  )

  # Panel (a) histogram tau2
  p_hist <- ggplot2::ggplot(
    cp[!is.na(cp$tau2), , drop = FALSE],
    ggplot2::aes(x = .data$tau2)
  ) +
    ggplot2::geom_histogram(bins = 30, fill = "#3366aa", color = "white") +
    ggplot2::geom_vline(xintercept = 0.1, linetype = "dashed", color = "#CC3333") +
    ggplot2::labs(x = expression(tau^2 ~ "(REML)"), y = "Count of genes") +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  # Panel (b) split bar
  split_summary <- cp[!is.na(cp$tau2_class), , drop = FALSE] |>
    dplyr::group_by(.data$tau2_class) |>
    dplyr::summarise(
      n_total = dplyr::n(),
      n_sig = sum(.data$is_sig, na.rm = TRUE),
      pct_sig = .data$n_sig / .data$n_total * 100,
      .groups = "drop"
    )

  p_split <- ggplot2::ggplot(
    split_summary,
    ggplot2::aes(x = .data$tau2_class, y = .data$pct_sig, fill = .data$tau2_class)
  ) +
    ggplot2::geom_col() +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%d / %d\n(%.1f%%)", .data$n_sig, .data$n_total, .data$pct_sig)),
      vjust = -0.3, size = 3
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "REM-amenable (tau2<0.1)" = "#3366aa",
        "REM-resisted (tau2>=0.1)" = "#CC3333"
      ),
      guide = "none"
    ) +
    ggplot2::labs(x = NULL, y = sprintf("%% of genes FDR<%g", fdr_thr)) +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank()) +
    ggplot2::expand_limits(y = max(split_summary$pct_sig, na.rm = TRUE) * 1.15)

  # Combine 2x1 via patchwork se disponibile, fallback single panel
  combined <- if (requireNamespace("patchwork", quietly = TRUE)) {
    patchwork::wrap_plots(p_hist, p_split, ncol = 2L)
  } else {
    p_hist
  }

  ggplot2::ggsave(png_path, combined, width = 8, height = 4, dpi = config$dpi)
  if (isTRUE(config$save_svg)) {
    ggplot2::ggsave(svg_path, combined, width = 8, height = 4, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  amen <- split_summary[split_summary$tau2_class == "REM-amenable (tau2<0.1)", , drop = FALSE]
  amen_pct <- if (nrow(amen) > 0L) amen$pct_sig else NA_real_

  caption <- sprintf(
    "Heterogeneity panel (REM). Left: per-gene tau^2 distribution (REML). Right: %% genes FDR<%g in REM-amenable (tau^2<0.1) vs REM-resisted (tau^2>=0.1) splits. REM-amenable: %.1f%% sig.",
    fdr_thr, amen_pct
  )

  list(
    png_path = png_path,
    svg_path = svg_path,
    caption = caption
  )
}
