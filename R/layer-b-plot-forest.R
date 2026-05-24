#' Forest plot top-N geni (REM + MEGA-AUG dispatch)
#'
#' Per `method == "rem"`: usa `metafor::forest()` su per-study yi/vi.
#' Per `method == "mega_aug"`: custom ggplot con 2 studi del pair + pooled diamond.
#' Per `method == "mega"`: skip-graceful con caption esplicativa (no per-study DE
#' nel Layer A output).
#'
#' @param per_study_de_subset tibble subset per il cluster (puo' essere 0 rows per mega).
#' @param cluster_pooled_subset tibble subset per il cluster.
#' @param method character "rem", "mega", o "mega_aug".
#' @param out_dir character dir output.
#' @param config list config.
#'
#' @return list con `png_path` (NA se skip), `svg_path` (NA se skip o save_svg=FALSE),
#'   `caption` (skip-explanation se applicable).
#' @keywords internal
.build_forest <- function(per_study_de_subset, cluster_pooled_subset, method,
                          out_dir, config) {
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_forest

  if (method == "mega") {
    return(list(
      png_path = NA_character_,
      svg_path = NA_character_,
      caption = "Forest plot N/A for mega-strict method (per-study DE absorbed in mixed model; per-study coefficients not extracted in Layer A)."
    ))
  }

  if (nrow(per_study_de_subset) == 0L) {
    return(list(
      png_path = NA_character_,
      svg_path = NA_character_,
      caption = sprintf("Forest plot N/A for cluster (method=%s): no per-study DE rows found.", method)
    ))
  }

  cp <- cluster_pooled_subset
  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr

  top_genes <- cp[cp$is_sig, , drop = FALSE]
  top_genes <- top_genes[order(abs(top_genes$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top_genes <- head(top_genes, top_n)

  if (nrow(top_genes) == 0L) {
    return(list(
      png_path = NA_character_,
      svg_path = NA_character_,
      caption = sprintf("Forest plot N/A: no genes significant at FDR<%g for cluster.", fdr_thr)
    ))
  }

  ps <- per_study_de_subset[per_study_de_subset$gene %in% top_genes$gene, , drop = FALSE]

  if (method == "mega_aug") {
    df_plot <- ps |>
      dplyr::mutate(
        ci_lo = logFC - 1.96 * SE,
        ci_hi = logFC + 1.96 * SE,
        gene = factor(gene, levels = rev(top_genes$gene))
      )
    pooled_df <- top_genes |>
      dplyr::transmute(
        gene = factor(gene, levels = rev(top_genes$gene)),
        study_id = "Pool",
        logFC = logFC_pool,
        ci_lo = logFC_pool - 1.96 * SE_pool,
        ci_hi = logFC_pool + 1.96 * SE_pool
      )

    p <- ggplot2::ggplot() +
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "#666666") +
      ggplot2::geom_errorbar(
        data = df_plot,
        ggplot2::aes(y = gene, xmin = ci_lo, xmax = ci_hi, color = study_id),
        width = 0.2,
        orientation = "y"
      ) +
      ggplot2::geom_point(
        data = df_plot,
        ggplot2::aes(y = gene, x = logFC, color = study_id),
        size = 2
      ) +
      ggplot2::geom_errorbar(
        data = pooled_df,
        ggplot2::aes(y = gene, xmin = ci_lo, xmax = ci_hi),
        color = "#CC3333", width = 0.3, linewidth = 0.8,
        orientation = "y"
      ) +
      ggplot2::geom_point(
        data = pooled_df,
        ggplot2::aes(y = gene, x = logFC),
        color = "#CC3333", shape = 18, size = 4
      ) +
      ggplot2::scale_color_viridis_d(name = "Study") +
      ggplot2::labs(x = expression(log[2]~"FC"), y = NULL) +
      ggplot2::theme_bw(base_size = 11) +
      ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

    h <- max(3, nrow(top_genes) * 0.5)
    png_path <- file.path(out_dir, "forest.png")
    svg_path <- file.path(out_dir, "forest.svg")
    ggplot2::ggsave(png_path, p, width = 8, height = h, dpi = config$dpi)
    if (config$save_svg) {
      ggplot2::ggsave(svg_path, p, width = 8, height = h, device = "svg")
    } else {
      svg_path <- NA_character_
    }

    n_aug <- unique(cp$n_baseline_studies_augmented)
    n_aug_str <- if (length(n_aug) == 1 && !is.na(n_aug)) sprintf("%d", n_aug) else "n/a"
    caption <- sprintf(
      "Forest plot of top %d significantly DE genes (FDR<%g). Pool diamond (red) reflects mixed-model coefficient (k=2 pair + %s baseline studies).",
      nrow(top_genes), fdr_thr, n_aug_str
    )

  } else if (method == "rem") {
    # REM path via metafor::forest per ogni gene. Build matrix of yi, vi per gene.
    png_path <- file.path(out_dir, "forest.png")
    svg_path <- file.path(out_dir, "forest.svg")

    grDevices::png(png_path, width = 8 * config$dpi, height = max(3, nrow(top_genes) * 0.5) * config$dpi,
                   res = config$dpi)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::par(mfrow = c(min(nrow(top_genes), 4L), 1L), mar = c(3, 1, 2, 1))
    for (g in top_genes$gene[seq_len(min(nrow(top_genes), 4L))]) {
      ps_g <- ps[ps$gene == g, , drop = FALSE]
      if (nrow(ps_g) < 2L) next
      tryCatch({
        res <- metafor::rma(yi = ps_g$logFC, sei = ps_g$SE, method = "REML")
        metafor::forest(res, slab = ps_g$study_id, header = g)
      }, error = function(e) NULL)
    }
    grDevices::dev.off()
    on.exit()

    svg_path <- NA_character_  # metafor::forest base graphics non SVG-trivial
    caption <- sprintf(
      "Forest plots for top %d significantly DE genes (FDR<%g). Each panel: per-study logFC +- 95%% CI and REML-pooled summary (k=%d).",
      min(nrow(top_genes), 4L), fdr_thr, unique(top_genes$k_effective)[1L]
    )

  } else {
    cli::cli_abort("Unknown method for forest plot: {.field {method}}")
  }

  list(
    png_path = png_path,
    svg_path = svg_path,
    caption = caption
  )
}
