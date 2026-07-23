#' Costruisci summary card (.md) per un cluster Layer B
#'
#' Card 1-pagina con metadata cluster: cluster_id, label_paper, anchor, method,
#' k_effective, n_studies, n_total_samples, n_sig_FDR05, top-gene, safety_min,
#' tau2_median (REM only), direction_applied distribution,
#' n_baseline_studies_augmented (MEGA-AUG only). Output embedabile nel report
#' Quarto aggregato.
#'
#' @param cluster_id character (1).
#' @param layer_a_subset list (output di `.fetch_layer_a_subset`).
#' @param stage3_metadata tibble con colonne anchor (kind_effective, agent_id,
#'   tissue, safety_min, ...).
#' @param selection_row tibble (1 row) con `cluster_id, label_paper, priority,
#'   notes`.
#' @param config list.
#' @param out_dir character; se NULL, usa `tempdir()`.
#' @param per_cluster_samples tibble opzionale (sample_id, study_id, treatment)
#'   per il cluster, usata per ricavare \code{n_total_samples} direttamente.
#'   Quando NULL (default backward-compat), cade sul pattern legacy via
#'   \code{layer_a_subset$per_study_de} (popolato solo per mega_aug). Passare
#'   questo argomento permette di mostrare il sample count anche per cluster
#'   mega-strict (n_studies>=5, k>=5) dove \code{per_study_de} e' vuoto.
#'
#' @return list `md_path`.
#' @keywords internal
.build_summary_card <- function(cluster_id, layer_a_subset, stage3_metadata,
                                selection_row, config, out_dir = tempdir(),
                                per_cluster_samples = NULL) {
  cp <- layer_a_subset$cluster_pooled
  cp_c <- cp[cp$cluster_id == cluster_id, , drop = FALSE]
  if (nrow(cp_c) == 0L) {
    cli::cli_abort("No rows in cluster_pooled for cluster {.field {cluster_id}}")
  }

  fdr_thr <- config$fdr_threshold
  method <- unique(cp_c$method)[1L]
  k_eff <- unique(cp_c$k_effective)[1L]
  n_sig <- sum(!is.na(cp_c$FDR_BH_within_cluster) &
                 cp_c$FDR_BH_within_cluster < fdr_thr)
  n_total <- nrow(cp_c)
  pct_sig <- if (n_total > 0L) n_sig / n_total * 100 else NA_real_

  # Top gene (highest |logFC| tra i significativi)
  sig <- cp_c[!is.na(cp_c$FDR_BH_within_cluster) &
                cp_c$FDR_BH_within_cluster < fdr_thr, , drop = FALSE]
  sig <- sig[order(abs(sig$logFC_pool), decreasing = TRUE), , drop = FALSE]
  top_gene_str <- if (nrow(sig) > 0L) {
    # FASE E1 ADR-0019 D6: label = HGNC symbol (leggibile) con fallback
    # all'Ensembl ID se symbol NA.
    top_label <- if (!is.na(sig$gene_symbol[1L]) && nzchar(sig$gene_symbol[1L])) {
      sig$gene_symbol[1L]
    } else sig$gene_id[1L]
    sprintf("%s (logFC=%.2f, FDR=%.2g)",
            top_label, sig$logFC_pool[1L],
            sig$FDR_BH_within_cluster[1L])
  } else {
    "(none significant)"
  }

  # tau2_median per REM
  tau2_median_str <- if (method %in% c("rem", "rem_group") && any(!is.na(cp_c$tau2))) {
    sprintf("%.4f", median(cp_c$tau2, na.rm = TRUE))
  } else {
    "N/A (non-REM)"
  }

  # Direction distribution
  dir_tbl <- table(cp_c$direction_applied, useNA = "ifany")
  dir_str <- paste(sprintf("%s: %d", names(dir_tbl), as.integer(dir_tbl)),
                   collapse = "; ")

  # Stage 3 metadata
  s3_row <- stage3_metadata[stage3_metadata$cluster_id == cluster_id, ,
                            drop = FALSE]
  anchor_str <- if (nrow(s3_row) > 0L) {
    sprintf("%s x %s (tissue=%s)",
            s3_row$kind_effective[1L] %||% "?",
            s3_row$agent_id[1L] %||% "?",
            s3_row$tissue[1L] %||% "?")
  } else {
    "(no Stage 3 metadata)"
  }
  safety_str <- if (nrow(s3_row) > 0L) {
    sprintf("%.2f", s3_row$safety_min[1L])
  } else {
    "N/A"
  }

  # n_baseline_studies_augmented per MEGA-AUG
  n_aug_str <- if (method == "mega_aug") {
    n_aug <- unique(cp_c$n_baseline_studies_augmented)
    n_aug <- n_aug[!is.na(n_aug)]
    if (length(n_aug) > 0L) as.character(n_aug[1L]) else "N/A"
  } else {
    "N/A (non-MEGA-AUG)"
  }

  # n_total_samples: priorita' al per_cluster_samples passato esplicito (path
  # nuovo per mega-strict, dove `per_study_de` e' vuoto); fallback al pattern
  # legacy via per_study_de per backward-compat (caller non passa
  # per_cluster_samples).
  n_total_samples_str <- "N/A"
  if (!is.null(per_cluster_samples) && nrow(per_cluster_samples) > 0L) {
    n_total_samples_str <- as.character(nrow(per_cluster_samples))
  } else {
    ps <- layer_a_subset$per_study_de
    if (!is.null(ps) && nrow(ps) > 0L) {
      ps_c <- ps[ps$cluster_id == cluster_id, , drop = FALSE]
      if (nrow(ps_c) > 0L) {
        uniq <- unique(ps_c[, c("study_id", "n_treated", "n_control")])
        n_total_samples_str <- as.character(
          sum(uniq$n_treated + uniq$n_control)
        )
      }
    }
  }

  md_lines <- c(
    sprintf("# %s -- Cluster %s",
            selection_row$label_paper[1L], cluster_id),
    "",
    sprintf("- **Cluster ID:** `%s`", cluster_id),
    sprintf("- **Anchor:** %s", anchor_str),
    sprintf("- **Method:** `%s`", method),
    sprintf("- **k_effective:** %s", as.character(k_eff)),
    sprintf("- **n_total_samples:** %s", n_total_samples_str),
    sprintf("- **n_sig FDR<%g:** %d / %d (%.1f%%)",
            fdr_thr, n_sig, n_total, pct_sig),
    sprintf("- **Top gene:** %s", top_gene_str),
    sprintf("- **safety_min (Stage 3):** %s", safety_str),
    sprintf("- **tau^2 median:** %s", tau2_median_str),
    sprintf("- **n_baseline_studies_augmented:** %s", n_aug_str),
    sprintf("- **direction_applied distribution:** %s", dir_str),
    "",
    if (nzchar(selection_row$notes[1L])) {
      sprintf("**User notes:** %s", selection_row$notes[1L])
    } else {
      NULL
    }
  )
  md_lines <- md_lines[!vapply(md_lines, is.null, logical(1L))]

  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  md_path <- file.path(out_dir, "summary_card.md")
  writeLines(md_lines, md_path)

  list(md_path = md_path)
}

#' Scrivi narrative.qmd template per un cluster
#'
#' Template Quarto con sezioni TODO ("Biological context", "Findings",
#' "Discussion") che l'utente cura a mano. Embed pointer al summary_card.md
#' + lista figure.
#'
#' @param cluster_id character (1).
#' @param summary_card_path character path al summary_card.md (NULL OK;
#'   entry skip).
#' @param selection_row tibble (1 row).
#' @param config list.
#' @param out_dir character.
#'
#' @return character path al .qmd scritto.
#' @keywords internal
.write_narrative_template <- function(cluster_id, summary_card_path,
                                      selection_row, config,
                                      out_dir = tempdir()) {
  label_paper <- selection_row$label_paper[1L]

  summary_block <- if (!is.null(summary_card_path) &&
                       file.exists(summary_card_path)) {
    paste(readLines(summary_card_path), collapse = "\n")
  } else {
    sprintf("_(summary_card.md not yet generated for cluster %s)_",
            cluster_id)
  }

  qmd_lines <- c(
    "---",
    sprintf('title: "Case study: %s (%s)"', label_paper, cluster_id),
    "---",
    "",
    sprintf("# Case study: %s", label_paper),
    "",
    "## Summary card",
    "",
    summary_block,
    "",
    "## Biological context",
    "",
    "_TODO: write biological narrative (1-2 paragraphs). What is the",
    "biological intervention/disease? Why is this comparison interesting?",
    "What known mechanisms apply?_",
    "",
    "## Findings",
    "",
    "_TODO: interpret top-30 genes table + volcano + GO enrichment.",
    "Which genes confirm known biology? Are there surprises? Cross-reference",
    "with literature._",
    "",
    "## Discussion",
    "",
    "_TODO: discuss heterogeneity (if REM), cross-study consistency (forest),",
    "caveats (mega_aug baseline-pool), implications for the field._",
    "",
    "## Figures",
    "",
    "::: {.figure-list}",
    "- volcano.svg",
    "- forest.svg (REM/MEGA-AUG only)",
    "- ma.svg",
    "- heatmap.svg",
    "- go_enrichment.svg",
    "- heterogeneity.svg (REM only)",
    ":::"
  )

  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  qmd_path <- file.path(out_dir, "narrative.qmd")
  writeLines(qmd_lines, qmd_path)
  qmd_path
}
