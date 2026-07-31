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

  cp$label <- .volcano_labels(cp, config)

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


#' Etichette del volcano: top-N per |logFC| x -log10(FDR), un simbolo una volta
#'
#' Nella regione MHC lo stesso simbolo ha piu' ID Ensembl su aplotipi
#' alternativi (`UBD` ne ha sei nel gruppo SARS-CoV-2, tre con valori identici):
#' senza deduplica la stessa etichetta occupava piu' posti fra i top-N. Tabella
#' e heatmap deduplicavano gia' via `.rank_and_dedup_genes()`; qui si chiude il
#' terzo pannello, cosi' la stessa figura non racconta due cose diverse.
#'
#' I geni **senza** simbolo restano etichettati col proprio `gene_id` e non
#' vengono fusi fra loro: sono geni diversi, e collassarli sarebbe peggio del
#' problema che si sta risolvendo.
#'
#' @param cp data.frame poolato del cluster, con `is_sig` gia' calcolata.
#' @param config list di configurazione Layer B.
#' @return character della stessa lunghezza di `nrow(cp)`: l'etichetta dove va
#'   mostrata, `NA` altrove.
#' @keywords internal
.volcano_labels <- function(cp, config) {
  top_n <- config$top_n_volcano_labels
  out <- rep(NA_character_, nrow(cp))
  if (nrow(cp) == 0L) return(out)
  # La significativita' si ricalcola qui invece di dipendere da una colonna
  # messa dal chiamante: cosi' la funzione e' verificabile da sola, ed e' il
  # motivo per cui questo difetto era rimasto invisibile nel volcano mentre
  # tabella e heatmap erano gia' state corrette.
  sig <- !is.na(cp$FDR_BH_within_cluster) &
    cp$FDR_BH_within_cluster < config$fdr_threshold
  sig_idx <- which(sig)
  if (length(sig_idx) == 0L) return(out)

  score <- abs(cp$logFC_pool) *
    (-log10(pmax(cp$FDR_BH_within_cluster, .Machine$double.xmin)))
  # FASE E1 ADR-0019 D6: label = simbolo HGNC leggibile, fallback all'Ensembl.
  readable <- ifelse(is.na(cp$gene_symbol) | cp$gene_symbol == "",
                     cp$gene_id, cp$gene_symbol)

  ranked <- sig_idx[order(score[sig_idx], decreasing = TRUE)]
  # dedup per etichetta MOSTRATA, non per simbolo: due geni senza simbolo hanno
  # `gene_id` diversi e devono restare distinti.
  primo <- ranked[!duplicated(readable[ranked])]
  scelti <- utils::head(primo, top_n)

  out[scelti] <- readable[scelti]
  out
}
