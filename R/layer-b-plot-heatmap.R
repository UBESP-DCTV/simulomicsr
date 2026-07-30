#' Heatmap top-N geni x sample (vst + ComBat batch-corrected)
#'
#' Top-N geni FDR<thr ranked by significance (`FDR_BH_within_cluster`
#' ascendente, tie-break `|logFC_pool|` discendente) e deduplicati per
#' `gene_symbol` (vedi [.rank_and_dedup_genes()], stesso criterio della
#' top-gene table cosi tabella ed heatmap mostrano un set di geni coerente
#' e senza duplicati di simbolo). Counts normalize via
#' `DESeq2::varianceStabilizingTransformation()` + `sva::ComBat()` batch
#' correction per `study_id` (cosmetico, esplicitato nella caption).
#' Subsample stratificato per (study, treatment) se
#' n_samples > max_heatmap_samples. Row-wise z-score, annotation rows
#' study (viridis) + treatment (binary), ComplexHeatmap engine.
#'
#' Edge cases:
#' - 0 sig genes -> PNG placeholder + caption N/A.
#' - vst fallisce (small N) -> fallback log2(CPM+1).
#'
#' @param counts integer matrix genes x samples (rownames = HGNC symbol).
#' @param metadata tibble con `sample_id, study_id, treatment` allineata alle
#'   colonne di `counts`.
#' @param cluster_pooled_subset tibble subset di `cluster_pooled.parquet` per
#'   il cluster (tutte le righe stesso `cluster_id`).
#' @param out_dir character path al dir dove salvare `heatmap.png` (+ `.svg`).
#' @param config list di config (vedi [layer_b_default_config()]).
#'
#' @return list con `png_path`, `svg_path`, `caption`.
#' @keywords internal
.build_heatmap <- function(counts, metadata, cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_heatmap
  max_samples <- config$max_heatmap_samples

  sig <- cp[!is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr, , drop = FALSE]
  # Stesso filtro di copertura della top-gene table, e per lo stesso motivo: i
  # geni a k basso sono anche quelli a conteggio quasi tutto zero (Spearman fra
  # k e frazione di zeri: -0,813), ComBat li salta esplicitamente ("genes with
  # uniform expression within a single batch"), e la loro riga nella heatmap
  # resta segnale di STUDIO invece che di trattamento. Misurato il 2026-07-31:
  # filtrando, la frazione mediana di zeri fra i trenta mostrati passa da
  # ~50-68% a ~0-4,5%.
  k_max_cluster <- if (!is.null(cp$k_effective) && any(!is.na(cp$k_effective))) {
    max(cp$k_effective, na.rm = TRUE)
  } else NULL
  filtro_cov <- .filter_genes_by_coverage(sig, config$top_genes_min_k_frac,
                                          k_max = k_max_cluster)
  sig <- filtro_cov$genes
  # Dedup per gene_symbol PRIMA di prendere i top_n: stesso criterio della
  # top-gene table (significativita, non |logFC|), cosi table e heatmap sono
  # coerenti e non mostrano lo stesso gene ripetuto su piu righe (artefatto
  # multi-Ensembl ARCHS4).
  sig <- .rank_and_dedup_genes(sig)
  # FASE E1: top_genes_id = chiave Ensembl (per indicizzare counts matrix
  # post-E1 con rownames = ensembl), top_genes_label = HGNC symbol
  # (per i row label dell'heatmap, leggibile). Mapping 1:1 per indice.
  top_sig <- utils::head(sig, top_n)
  top_genes_id    <- top_sig$gene_id
  top_genes_label <- ifelse(
    is.na(top_sig$gene_symbol) | top_sig$gene_symbol == "",
    top_sig$gene_id, top_sig$gene_symbol
  )
  # Retrocompat: top_genes era usato per filtraggio + count length downstream.
  # Lo manteniamo come gene_id (subset di vst_mat usa Ensembl ID).
  top_genes <- top_genes_id

  if (length(top_genes) == 0L) {
    png_path <- file.path(out_dir, "heatmap.png")
    grDevices::png(png_path, width = 800, height = 400, res = config$dpi)
    graphics::plot.new()
    graphics::text(0.5, 0.5,
                   sprintf("Heatmap N/A: no genes significant at FDR<%g", fdr_thr))
    grDevices::dev.off()
    return(list(
      png_path = png_path,
      svg_path = NA_character_,
      caption = sprintf(
        "Heatmap N/A: no genes significant at FDR<%g for this cluster.",
        fdr_thr
      )
    ))
  }

  # Subsample stratificato per (study, treatment) se necessario
  subsample_note <- ""
  if (ncol(counts) > max_samples) {
    seed <- digest::digest2int(unique(cp$cluster_id)[1L])
    set.seed(seed)
    metadata$strata <- paste(metadata$study_id, metadata$treatment, sep = "::")
    strata_sizes <- table(metadata$strata)
    strata_names <- names(strata_sizes)
    # Allocazione proporzionale, minimo 1 per strata (preserva nomi)
    target_per_strata <- stats::setNames(
      pmax(1L, as.integer(round(as.numeric(strata_sizes) / sum(strata_sizes) * max_samples))),
      strata_names
    )
    # Trim se totale > max_samples
    excess <- sum(target_per_strata) - max_samples
    while (excess > 0L) {
      biggest <- which.max(target_per_strata)
      target_per_strata[biggest] <- target_per_strata[biggest] - 1L
      excess <- excess - 1L
    }
    picked_ids <- unlist(lapply(strata_names, function(s) {
      ids <- metadata$sample_id[metadata$strata == s]
      sample(ids, min(length(ids), target_per_strata[[s]]))
    }), use.names = FALSE)
    counts <- counts[, picked_ids, drop = FALSE]
    metadata <- metadata[metadata$sample_id %in% picked_ids, , drop = FALSE]
    metadata <- metadata[match(picked_ids, metadata$sample_id), , drop = FALSE]
    subsample_note <- sprintf(
      paste0(" Samples subsampled to %d via stratified random selection ",
             "across (study, treatment) cells (seed deterministic from cluster_id)."),
      length(picked_ids)
    )
  }

  # vst (fallback log2(CPM+1)) su tutta la matrice per stabilizzare size factor
  full_counts_for_sf <- round(as.matrix(counts))
  vst_mat <- tryCatch({
    DESeq2::varianceStabilizingTransformation(full_counts_for_sf, blind = TRUE)
  }, error = function(e) {
    lib_size <- pmax(colSums(full_counts_for_sf), 1)
    log2(t(t(full_counts_for_sf) / lib_size) * 1e6 + 1)
  })
  vst_sub <- vst_mat[rownames(vst_mat) %in% top_genes, , drop = FALSE]

  # ComBat batch correction per study_id (cosmetico).
  # Guard: serve almeno 2 studi e 2 livelli di treatment (mod matrix non rank-deficient).
  n_studies <- length(unique(metadata$study_id))
  n_treat_levels <- length(unique(metadata$treatment))
  cluster_id_str <- unique(cp$cluster_id)[1L]
  combat_applied <- FALSE
  combat_skip_reason <- NA_character_

  combat_mat <- if (n_studies < 2L) {
    combat_skip_reason <- "single_study"
    vst_sub
  } else if (n_treat_levels < 2L) {
    cli::cli_warn(
      "ComBat skipped per cluster {.field {cluster_id_str}}: single treatment level"
    )
    combat_skip_reason <- "single_treatment"
    vst_sub
  } else {
    tryCatch({
      out <- sva::ComBat(
        dat = vst_sub,
        batch = metadata$study_id,
        mod = stats::model.matrix(~ treatment, data = metadata)
      )
      combat_applied <- TRUE
      out
    }, error = function(e) {
      cli::cli_warn(
        "ComBat failed per cluster {.field {cluster_id_str}}: {conditionMessage(e)}"
      )
      combat_skip_reason <<- "combat_error"
      vst_sub
    })
  }

  # Row-wise z-score (riduce a 0 righe a varianza nulla)
  z_mat <- t(scale(t(combat_mat)))
  z_mat[is.na(z_mat)] <- 0

  # Annotation rows: study (viridis) + treatment (binary)
  studies_unique <- unique(metadata$study_id)
  study_colors <- stats::setNames(
    viridisLite::viridis(length(studies_unique)),
    studies_unique
  )
  treatment_levels <- unique(metadata$treatment)
  treatment_colors <- stats::setNames(
    rep(c("#BBBBBB", "#333333"), length.out = length(treatment_levels)),
    treatment_levels
  )
  # Override default mapping se i label canonici sono presenti
  if ("control" %in% treatment_levels) treatment_colors[["control"]] <- "#BBBBBB"
  if ("treated" %in% treatment_levels) treatment_colors[["treated"]] <- "#333333"

  ha <- ComplexHeatmap::HeatmapAnnotation(
    Study = metadata$study_id,
    Treatment = metadata$treatment,
    col = list(
      Study = study_colors,
      Treatment = treatment_colors
    ),
    annotation_height = grid::unit(c(4, 4), "mm")
  )

  # use_raster=TRUE: body della heatmap rasterizzato (PNG-embedded nel SVG)
  # mentre axis/labels/annotation restano vettoriali. Riduce SVG da ~5MB a
  # ~200-500KB mantenendo qualita di stampa paper-grade (raster_quality=5 =
  # high-DPI equivalent).
  # FASE E1 ADR-0019 D6: row label = HGNC symbol leggibile (fallback
  # gene_id se symbol NA). z_mat ha rownames = ensembl_gene; rimappiamo
  # via top_genes_id -> top_genes_label.
  row_labels_z <- top_genes_label[match(rownames(z_mat), top_genes_id)]

  hm <- ComplexHeatmap::Heatmap(
    z_mat,
    name = "z-score",
    top_annotation = ha,
    show_column_names = FALSE,
    show_row_names = TRUE,
    row_labels = row_labels_z,
    row_names_gp = grid::gpar(fontsize = 8),
    cluster_columns = TRUE,
    cluster_rows = TRUE,
    col = circlize::colorRamp2(c(-2, 0, 2), c("#3050a0", "white", "#c04040")),
    use_raster = TRUE,
    raster_quality = 5
  )

  png_path <- file.path(out_dir, "heatmap.png")
  svg_path <- file.path(out_dir, "heatmap.svg")

  grDevices::png(png_path, width = 8 * config$dpi, height = 10 * config$dpi,
                 res = config$dpi)
  ComplexHeatmap::draw(hm)
  grDevices::dev.off()

  if (isTRUE(config$save_svg)) {
    grDevices::svg(svg_path, width = 8, height = 10)
    ComplexHeatmap::draw(hm)
    grDevices::dev.off()
  } else {
    svg_path <- NA_character_
  }

  combat_note <- if (!combat_applied && !is.na(combat_skip_reason)) {
    switch(
      combat_skip_reason,
      single_treatment = " ComBat skipped (single treatment level).",
      combat_error     = " ComBat failed, fallback to vst-only (see warnings).",
      single_study     = " ComBat skipped (single study, no batch effect to correct).",
      ""
    )
  } else ""

  caption <- sprintf(
    paste0("Heatmap of top %d DE genes (rows) across samples (columns). ",
           "vst + ComBat batch correction applied for visual cross-study ",
           "coherence; effect-size statistics in pooled output are NOT ",
           "batch-corrected.%s%s%s"),
    length(top_genes), combat_note, subsample_note,
    .coverage_filter_note(filtro_cov)
  )

  list(png_path = png_path, svg_path = svg_path, caption = caption)
}
