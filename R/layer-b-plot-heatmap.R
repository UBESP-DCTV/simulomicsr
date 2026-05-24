#' Heatmap top-N geni x sample (vst + ComBat batch-corrected)
#'
#' Top-N geni FDR<thr ranked by |logFC_pool|. Counts normalize via
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
  sig <- sig[order(abs(sig$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top_genes <- utils::head(sig$gene, top_n)

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

  # ComBat batch correction per study_id (cosmetico)
  combat_mat <- tryCatch({
    n_studies <- length(unique(metadata$study_id))
    if (n_studies < 2L) {
      vst_sub
    } else {
      sva::ComBat(
        dat = vst_sub,
        batch = metadata$study_id,
        mod = stats::model.matrix(~ treatment, data = metadata)
      )
    }
  }, error = function(e) vst_sub)

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

  hm <- ComplexHeatmap::Heatmap(
    z_mat,
    name = "z-score",
    top_annotation = ha,
    show_column_names = FALSE,
    show_row_names = TRUE,
    row_names_gp = grid::gpar(fontsize = 8),
    cluster_columns = TRUE,
    cluster_rows = TRUE,
    col = circlize::colorRamp2(c(-2, 0, 2), c("#3050a0", "white", "#c04040"))
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

  caption <- sprintf(
    paste0("Heatmap of top %d DE genes (rows) across samples (columns). ",
           "vst + ComBat batch correction applied for visual cross-study ",
           "coherence; effect-size statistics in pooled output are NOT ",
           "batch-corrected.%s"),
    length(top_genes), subsample_note
  )

  list(png_path = png_path, svg_path = svg_path, caption = caption)
}
