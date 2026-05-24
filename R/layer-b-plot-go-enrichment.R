#' GO BP + Reactome enrichment per un cluster (ORA via clusterProfiler)
#'
#' Over-representation analysis: gene set = geni FDR<thr nel cluster,
#' universe = tutti i geni testati nel cluster. Skip-graceful se universo
#' sotto soglia `min_genes_for_go_ora`.
#'
#' @param cluster_pooled_subset tibble subset di `cluster_pooled.parquet` per
#'   il cluster (tutte le righe stesso `cluster_id`).
#' @param out_dir character path al dir dove salvare gli output.
#' @param config list di config (vedi [layer_b_default_config()]).
#'
#' @return list con `png_path`, `svg_path`, `csv_path`, `caption`.
#' @keywords internal
.build_go_enrichment <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  min_universe <- config$min_genes_for_go_ora

  universe <- unique(cp$gene[!is.na(cp$p_value_pool)])
  gene_set <- unique(cp$gene[!is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr])

  png_path <- file.path(out_dir, "go_enrichment.png")
  svg_path <- file.path(out_dir, "go_enrichment.svg")
  csv_path <- file.path(out_dir, "go_enrichment_table.csv")

  # Skip-graceful: universo sotto soglia ORA reliability
  if (length(universe) < min_universe) {
    grDevices::png(png_path, width = 8, height = 4, units = "in", res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5,
      sprintf("GO N/A: %d genes tested\n(below threshold %d for ORA reliability)",
              length(universe), min_universe))
    grDevices::dev.off()
    writeLines("", csv_path)
    return(list(
      png_path = png_path, svg_path = NA_character_, csv_path = csv_path,
      caption = sprintf("GO enrichment N/A: %d genes tested, below threshold %d for over-representation analysis reliability.",
                        length(universe), min_universe)
    ))
  }

  # Skip-graceful: nessun gene significativo
  if (length(gene_set) == 0L) {
    grDevices::png(png_path, width = 8, height = 4, units = "in", res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5, sprintf("GO N/A: no genes significant at FDR<%g", fdr_thr))
    grDevices::dev.off()
    writeLines("", csv_path)
    return(list(
      png_path = png_path, svg_path = NA_character_, csv_path = csv_path,
      caption = sprintf("GO enrichment N/A: no genes significant at FDR<%g.", fdr_thr)
    ))
  }

  enrich_res <- tryCatch({
    clusterProfiler::enrichGO(
      gene          = gene_set,
      universe      = universe,
      OrgDb         = org.Hs.eg.db::org.Hs.eg.db,
      keyType       = "SYMBOL",
      ont           = "BP",
      pAdjustMethod = "BH",
      qvalueCutoff  = 0.05,
      readable      = FALSE
    )
  }, error = function(e) NULL)

  # Skip-graceful: nessun termine arricchito
  if (is.null(enrich_res) || nrow(as.data.frame(enrich_res)) == 0L) {
    grDevices::png(png_path, width = 8, height = 4, units = "in", res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5, "GO BP: no significant enrichment at FDR<0.05")
    grDevices::dev.off()
    writeLines("", csv_path)
    return(list(
      png_path = png_path, svg_path = NA_character_, csv_path = csv_path,
      caption = sprintf("GO Biological Process over-representation: no terms enriched at FDR<0.05 for %d input genes.",
                        length(gene_set))
    ))
  }

  enrich_df <- as.data.frame(enrich_res)
  readr::write_csv(enrich_df, csv_path)

  # Top-10 termini per p.adjust
  top_terms <- enrich_df[order(enrich_df$p.adjust), , drop = FALSE]
  top_terms <- head(top_terms, 10L)
  top_terms$neg_log10_padj <- -log10(top_terms$p.adjust)
  top_terms$Description <- factor(top_terms$Description,
                                  levels = rev(top_terms$Description))

  p <- ggplot2::ggplot(top_terms, ggplot2::aes(x = neg_log10_padj, y = Description, fill = neg_log10_padj)) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_viridis_c(name = "-log10(p.adj)", option = "viridis") +
    ggplot2::labs(x = expression(-log[10] ~ "(p.adjust BH)"), y = NULL,
                  title = "GO Biological Process -- top 10 enriched terms") +
    ggplot2::theme_bw(base_size = 10) +
    ggplot2::theme(legend.position = "right",
                   panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(png_path, p, width = 8, height = 6, dpi = config$dpi)
  if (config$save_svg) {
    ggplot2::ggsave(svg_path, p, width = 8, height = 6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    "GO Biological Process over-representation analysis. %d significant terms at FDR<0.05 (BH-corrected). Universe: %d genes tested in cluster.",
    nrow(enrich_df), length(universe)
  )

  list(png_path = png_path, svg_path = svg_path, csv_path = csv_path, caption = caption)
}
