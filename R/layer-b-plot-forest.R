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

  # FASE E1 ADR-0019 D6: gene_id (Ensembl) come chiave operativa per
  # join/subset; gene_symbol (HGNC) come label leggibile sull'asse y
  # del plot. label = symbol non NA, fallback al gene_id raw se symbol NA.
  top_genes$label <- ifelse(
    is.na(top_genes$gene_symbol) | top_genes$gene_symbol == "",
    top_genes$gene_id, top_genes$gene_symbol
  )
  # Guard paralogo: i gene_symbol HGNC NON sono unici (piu' Ensembl gene_id sullo
  # stesso symbol in ARCHS4 v2.5, es. KRT23 su 2 ENSG nel cluster Alcoholic
  # hepatitis v7). La label e' usata come levels di un factor (mega_aug) e come
  # header per-gene (rem); il factor richiede levels unici. make.unique
  # deterministico (coerente con ADR-0016 D6 sul gene axis): KRT23, KRT23.1.
  top_genes$label <- make.unique(top_genes$label)
  ps <- per_study_de_subset[per_study_de_subset$gene_id %in% top_genes$gene_id, , drop = FALSE]
  # Propaga la label sul ps via lookup per gene_id (mapping 1:1 garantito post-E1)
  ps$label <- top_genes$label[match(ps$gene_id, top_genes$gene_id)]

  if (method == "mega_aug") {
    df_plot <- ps |>
      dplyr::mutate(
        ci_lo = logFC - 1.96 * SE,
        ci_hi = logFC + 1.96 * SE,
        gene = factor(label, levels = rev(top_genes$label))
      )
    pooled_df <- top_genes |>
      dplyr::transmute(
        gene = factor(label, levels = rev(top_genes$label)),
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
    # Rispetta config$top_n_forest (era hard-coded 4 cap).
    top_n_actual <- min(nrow(top_genes), top_n)

    png_path <- file.path(out_dir, "forest.png")
    svg_path <- file.path(out_dir, "forest.svg")

    h_inch <- max(3, top_n_actual * 0.6)
    grDevices::png(png_path, width = 8 * config$dpi, height = h_inch * config$dpi,
                   res = config$dpi)
    # Device-safe: chiude solo se ancora aperto (gestisce crash mid-loop senza leak).
    on.exit(if (grDevices::dev.cur() != 1L) grDevices::dev.off(), add = TRUE)
    graphics::par(mfrow = c(min(top_n_actual, 4L), 1L), mar = c(3, 1, 2, 1))
    for (i in seq_len(top_n_actual)) {
      g_id   <- top_genes$gene_id[i]
      g_lab  <- top_genes$label[i]
      ps_g <- ps[ps$gene_id == g_id, , drop = FALSE]
      if (nrow(ps_g) < 2L) next
      tryCatch({
        res <- metafor::rma(yi = ps_g$logFC, sei = ps_g$SE, method = "REML")
        # FASE E1: header del singolo forest = symbol leggibile (fallback id).
        metafor::forest(res, slab = ps_g$study_id, header = g_lab)
      }, error = function(e) NULL)
    }
    grDevices::dev.off()  # chiusura esplicita post-loop; on.exit copre crash

    svg_path <- NA_character_  # metafor::forest base graphics non SVG-trivial

    # Defensive: k_effective puo' essere NA/empty -> evita NA in caption.
    k_values <- unique(top_genes$k_effective)
    k_str <- if (length(k_values) > 0L && !is.na(k_values[1L])) as.character(k_values[1L]) else "?"
    caption <- sprintf(
      "Forest plots for top %d significantly DE genes (FDR<%g). Each panel: per-study logFC +- 95%% CI and REML-pooled summary (k=%s).",
      top_n_actual, fdr_thr, k_str
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
