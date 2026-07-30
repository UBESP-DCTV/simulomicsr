#' Top-gene table (CSV + LaTeX booktabs) per un cluster
#'
#' Top-N geni FDR<thr ranked by significance (`FDR_BH_within_cluster`
#' ascendente, tie-break `|logFC_pool|` discendente), deduplicati per
#' `gene_symbol` (vedi [.rank_and_dedup_genes()]: il ranking per |logFC|
#' pescava geni ad alta varianza/bassa robustezza e l'artefatto
#' multi-Ensembl di ARCHS4 gonfiava la tabella con lo stesso gene ripetuto
#' su piu righe). Output 2 file: `top_genes.csv` (machine-readable) e
#' `top_genes.tex` (paper-ready, kableExtra booktabs).
#'
#' @param cluster_pooled_subset tibble subset per cluster.
#' @param out_dir character.
#' @param config list.
#'
#' @return list `csv_path, tex_path, caption, n_rows`.
#' @keywords internal
.build_top_gene_table <- function(cluster_pooled_subset, out_dir, config) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_table

  sig <- cp[!is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr, , drop = FALSE]
  # Filtro di copertura PRIMA del ranking: senza, la tabella e' guidata da geni
  # misurati in due studi su trentatre, dove il random-effects stima tau^2 = 0 e
  # l'errore standard collassa (misurato sui bundle v13 il 2026-07-31). `k_max`
  # viene dal cluster INTERO, non dai soli significativi: dedurlo dal
  # sottoinsieme abbasserebbe la soglia proprio dove serve.
  k_max_cluster <- if (!is.null(cp$k_effective) && any(!is.na(cp$k_effective))) {
    max(cp$k_effective, na.rm = TRUE)
  } else NULL
  filtro <- .filter_genes_by_coverage(sig, config$top_genes_min_k_frac,
                                      k_max = k_max_cluster)
  sig <- filtro$genes
  # Dedup per gene_symbol PRIMA di prendere i top_n, cosi si mostrano top_n
  # simboli distinti (non top_n righe di cui alcune ridondanti).
  sig <- .rank_and_dedup_genes(sig)
  top <- head(sig, top_n)

  csv_path <- file.path(out_dir, "top_genes.csv")
  tex_path <- file.path(out_dir, "top_genes.tex")

  if (nrow(top) == 0L) {
    # CSV vuoto + LaTeX con caption esplicativa
    readr::write_csv(top, csv_path)
    writeLines(
      sprintf("%% No genes significant at FDR<%g for cluster %s.",
              fdr_thr, unique(cp$cluster_id)[1L]),
      tex_path
    )
    return(list(
      csv_path = csv_path,
      tex_path = tex_path,
      caption = sprintf("No genes significant at FDR<%g for this cluster.", fdr_thr),
      n_rows = 0L
    ))
  }

  # gene_label: nome display pulito per la tabella (simbolo HGNC se
  # disponibile, altrimenti l'Ensembl gene_id).
  top$gene_label <- ifelse(
    !is.na(top$gene_symbol) & top$gene_symbol != "",
    top$gene_symbol, top$gene_id
  )

  # FASE E1 ADR-0019 D6 + showcase Layer B (ranking per significativita):
  # gene_label prima colonna (display), poi gene_symbol/gene_id (tracciabilita),
  # poi effect size + significativita + robustezza. direction_applied (sempre
  # "none") e p_value_pool (ridondante con FDR) rimossi: inutili per il paper.
  out_cols <- c("gene_label", "gene_symbol", "gene_id", "logFC_pool",
                "FDR_BH_within_cluster", "k_effective", "SE_pool", "tau2", "I2")
  out_cols <- intersect(out_cols, names(top))
  top_out <- top[, out_cols, drop = FALSE]

  readr::write_csv(top_out, csv_path)

  # LaTeX via kableExtra (booktabs). digits allineati per nome colonna (NA per
  # le colonne carattere) cosi' l'ordine resta corretto anche se qualche
  # colonna e' assente (intersect sopra).
  digit_map <- c(
    gene_label = NA_real_, gene_symbol = NA_real_, gene_id = NA_real_,
    logFC_pool = 3, FDR_BH_within_cluster = -2, k_effective = 0,
    SE_pool = 3, tau2 = 3, I2 = 1
  )
  digits_vec <- unname(digit_map[out_cols])

  cluster_id_str <- unique(cp$cluster_id)[1L]
  tex_str <- kableExtra::kbl(
    top_out,
    format = "latex",
    booktabs = TRUE,
    digits = digits_vec,
    caption = sprintf(paste0(
      "Top %d differentially expressed genes for cluster %s (FDR<%g, ",
      "ranked by significance; $\\log_2 FC$ reported for reference).%s"
    ), nrow(top_out), cluster_id_str, fdr_thr, .coverage_filter_note(filtro)),
    label = sprintf("tab:top-genes-%s", gsub("[^a-zA-Z0-9]", "-", cluster_id_str))
  )
  writeLines(as.character(tex_str), tex_path)

  caption <- sprintf(
    "Top %d differentially expressed genes (FDR<%g, ranked by significance). Full table in top_genes.csv.%s",
    nrow(top_out), fdr_thr, .coverage_filter_note(filtro)
  )

  list(
    csv_path = csv_path,
    tex_path = tex_path,
    caption = caption,
    n_rows = nrow(top_out)
  )
}
