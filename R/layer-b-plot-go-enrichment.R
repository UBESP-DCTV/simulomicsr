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
#' @param etichetta character(1) opzionale, l'etichetta leggibile del gruppo
#'   (tipicamente `selection_row$label_paper`) da usare come `entita` del
#'   titolo (`.lb_titolo()`). Se NULL, NA o vuota il titolo ripiega sul
#'   `cluster_id` grezzo -- MAI in silenzio: la caption lo dichiara. Stesso
#'   pattern di `.build_forest()`/`.build_volcano()`/`.build_heatmap()`.
#'
#' @return list con `png_path`, `svg_path`, `csv_path`, `titolo`, `caption`.
#' @keywords internal
.build_go_enrichment <- function(cluster_pooled_subset, out_dir, config, etichetta = NULL) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  min_universe <- config$min_genes_for_go_ora

  # entita' del titolo: l'etichetta leggibile se c'e', altrimenti il
  # cluster_id grezzo -- MAI in silenzio, la caption dichiara il ripiego.
  # Calcolato PRIMA di ogni ramo skip-graceful, cosi' `titolo` e' sempre
  # nel valore di ritorno (stesso contratto di forest/volcano/heatmap).
  etichetta_ok <- !is.null(etichetta) && !is.na(etichetta) && nzchar(etichetta)
  entita_titolo <- if (etichetta_ok) etichetta else cp$cluster_id[1L]
  titolo_nota <- if (etichetta_ok) "" else paste0(
    " Figure title falls back to the raw cluster_id: no readable group ",
    "label (label_paper) was provided to .build_go_enrichment()."
  )
  k_cluster <- .cluster_k_effective(cp)
  titolo <- .lb_titolo(entita = entita_titolo, k = k_cluster, extra = "GO BP top 10")

  # FASE E1 ADR-0019 D6: ORA su gene_id (Ensembl, axis univoco). HGNC
  # symbol resta come label per i risultati (readable = TRUE).
  universe <- unique(cp$gene_id[!is.na(cp$p_value_pool)])
  gene_set <- unique(cp$gene_id[!is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr])

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
      titolo = titolo,
      caption = sprintf("GO enrichment N/A: %d genes tested, below threshold %d for over-representation analysis reliability.%s",
                        length(universe), min_universe, titolo_nota)
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
      titolo = titolo,
      caption = sprintf("GO enrichment N/A: no genes significant at FDR<%g.%s", fdr_thr, titolo_nota)
    ))
  }

  enrich_res <- tryCatch({
    clusterProfiler::enrichGO(
      gene          = gene_set,
      universe      = universe,
      OrgDb         = org.Hs.eg.db::org.Hs.eg.db,
      keyType       = "ENSEMBL",
      ont           = "BP",
      pAdjustMethod = "BH",
      qvalueCutoff  = 0.05,
      readable      = TRUE    # FASE E1: rimappa Ensembl -> HGNC nei result
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
      titolo = titolo,
      caption = sprintf("GO Biological Process over-representation: no terms enriched at FDR<0.05 for %d input genes.%s",
                        length(gene_set), titolo_nota)
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

  # Titolo e tema allineati alle altre tre figure (rilievo I4, 2026-08-06):
  # prima il titolo era statico ("GO Biological Process -- top 10 enriched
  # terms", senza gruppo ne' k) e il tema era theme_bw() invece di
  # .lb_theme() -- la spec tiene il GO fra le quattro figure e dice "ogni
  # figura porta nel titolo di quale gruppo si tratta e su quanti studi".
  # legend.position="right" resta (barre orizzontali: "bottom", il default
  # di .lb_theme(), comprimerebbe l'unica colonna disponibile).
  p <- ggplot2::ggplot(top_terms, ggplot2::aes(x = neg_log10_padj, y = Description, fill = neg_log10_padj)) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_viridis_c(name = "-log10(p.adj)", option = "viridis") +
    ggplot2::labs(x = expression(-log[10] ~ "(p.adjust BH)"), y = NULL,
                  title = titolo) +
    .lb_theme(base_size = 10) +
    ggplot2::theme(legend.position = "right")

  ggplot2::ggsave(png_path, p, width = 8, height = 6, dpi = config$dpi)
  if (config$save_svg) {
    ggplot2::ggsave(svg_path, p, width = 8, height = 6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    "GO Biological Process over-representation analysis. %d significant terms at FDR<0.05 (Benjamini-Hochberg). Universe: the %d genes tested in this meta-analysis.%s",
    nrow(enrich_df), length(universe), titolo_nota
  )

  list(png_path = png_path, svg_path = svg_path, csv_path = csv_path, titolo = titolo, caption = caption)
}
