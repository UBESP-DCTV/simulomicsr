#' Il gene da mostrare studio per studio nel pannello inferiore del forest
#'
#' Regola DICHIARATA (va in didascalia): fra i geni misurati in TUTTI gli studi
#' del cluster, quello con l'effetto assoluto maggiore. Se nessun gene ha
#' copertura piena si restituisce NA e il pannello inferiore si omette, invece di
#' ripiegare in silenzio su un gene a bassa copertura -- che e' il difetto che
#' questo ridisegno corregge.
#' @keywords internal
.forest_gene_rappresentativo <- function(top_genes, k_cluster) {
  if (nrow(top_genes) == 0L || is.null(top_genes$k_effective)) return(NA_character_)
  pieni <- top_genes[!is.na(top_genes$k_effective) &
                       top_genes$k_effective >= as.integer(k_cluster), , drop = FALSE]
  if (nrow(pieni) == 0L) return(NA_character_)
  pieni$gene_id[which.max(abs(pieni$logFC_pool))]
}

#' Forest plot top-N geni (REM + MEGA-AUG dispatch)
#'
#' Per `method %in% c("rem", "rem_group")`: figura a due pannelli via `patchwork`.
#' Sopra, la stima poolata +- 95% CI per ciascuno dei geni bersaglio (colpo
#' d'occhio su tutti). Sotto, UN gene -- quello scelto da
#' `.forest_gene_rappresentativo()` -- studio per studio con la stima poolata
#' resa come rombo, a riprova che il pooling e' coerente. Sostituisce il vecchio
#' pannello `metafor::forest()` per-gene in `mfrow`, che mostrava pochi geni con
#' meta' pagina bianca.
#' Per `method == "mega_aug"`: custom ggplot con 2 studi del pair + pooled diamond.
#' Per `method == "mega"`: skip-graceful con caption esplicativa (no per-study DE
#' nel Layer A output).
#'
#' @param per_study_de_subset tibble subset per il cluster (puo' essere 0 rows per mega).
#' @param cluster_pooled_subset tibble subset per il cluster.
#' @param method character "rem", "rem_group", "mega", o "mega_aug".
#' @param out_dir character dir output.
#' @param config list config.
#' @param etichetta character(1) opzionale, l'etichetta leggibile del gruppo
#'   (tipicamente `selection_row$label_paper`) da usare come `entita` del
#'   titolo (`.lb_titolo()`, ramo rem/rem_group). Se NULL, NA o vuota il
#'   titolo ripiega sul `cluster_id` grezzo -- MAI in silenzio: la caption lo
#'   dichiara. Senza questo argomento il titolo sarebbe sempre un ID come
#'   `cgroup_L5_2e16719f`, che vanifica lo scopo di `.lb_titolo()` (dire a
#'   colpo d'occhio di quale gruppo si tratta).
#'
#' @return list con `png_path` (NA se skip), `svg_path` (NA se skip o save_svg=FALSE),
#'   `titolo` (NA se il ramo non genera un titolo, es. mega/mega_aug),
#'   `caption` (skip-explanation se applicable).
#' @keywords internal
.build_forest <- function(per_study_de_subset, cluster_pooled_subset, method,
                          out_dir, config, etichetta = NULL) {
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_forest
  titolo <- NA_character_
  titolo_nota <- ""

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

  # Il filtro di copertura e' lo STESSO usato da tabella e heatmap dal
  # 2026-07-31: il forest era rimasto fuori, e per questo mostrava geni
  # misurati in due studi su 59 (CD300C, PROK2 su TGF-beta1, misurato il
  # 2026-08-05). Il k del cluster va passato esplicitamente: dedurlo dai soli
  # geni significativi abbasserebbe la soglia proprio dove serve di piu'.
  k_cluster <- .cluster_k_effective(cp)
  filtro <- .filter_genes_by_coverage(cp[cp$is_sig, , drop = FALSE],
                                      config$top_genes_min_k_frac,
                                      k_max = k_cluster)
  top_genes <- filtro$genes
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
    caption_base <- sprintf(
      "Forest plot of top %d significantly DE genes (FDR<%g). Pool diamond (red) reflects mixed-model coefficient (k=2 pair + %s baseline studies).",
      nrow(top_genes), fdr_thr, n_aug_str
    )

  } else if (method %in% c("rem", "rem_group")) {
    # rem_group (ADR-0022, meta-analisi nominate group L2-L4) e' REM per-studio con
    # lo stesso schema per_study_de {study_id, logFC, SE} -> stesso code path di rem.
    # Rispetta config$top_n_forest (era hard-coded 4 cap).
    top_n_actual <- min(nrow(top_genes), top_n)
    k_str <- if (!is.na(k_cluster)) as.character(k_cluster) else "?"

    # entita' del titolo: l'etichetta leggibile se c'e', altrimenti il
    # cluster_id grezzo -- MAI in silenzio, la caption dichiara il ripiego
    # (vedi titolo_nota sotto).
    etichetta_ok <- !is.null(etichetta) && !is.na(etichetta) && nzchar(etichetta)
    entita_titolo <- if (etichetta_ok) etichetta else cp$cluster_id[1L]
    if (!etichetta_ok) {
      titolo_nota <- paste0(
        " Figure title falls back to the raw cluster_id: no readable group ",
        "label (label_paper) was provided to .build_forest()."
      )
    }

    # --- pannello superiore: i bersagli, stima poolata ordinata per effetto ---
    top_disp <- top_genes
    # Livelli in ordine crescente di logFC_pool: nel factor discreto di ggplot il
    # primo livello e' in basso, quindi i geni piu' negativi finiscono in basso e
    # i piu' positivi in alto (lettura "a tornado").
    top_disp$label <- factor(top_disp$label,
                             levels = top_disp$label[order(top_disp$logFC_pool)])
    top_disp$verso <- ifelse(top_disp$logFC_pool >= 0, "su", "giu")

    p_top <- ggplot2::ggplot(
      top_disp,
      ggplot2::aes(y = .data$label, x = .data$logFC_pool,
                   xmin = .data$logFC_pool - 1.96 * .data$SE_pool,
                   xmax = .data$logFC_pool + 1.96 * .data$SE_pool,
                   colour = .data$verso)
    ) +
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed", colour = .LB_COLORI$neutro) +
      ggplot2::geom_errorbar(width = 0.2, orientation = "y") +
      ggplot2::geom_point(size = 2.2) +
      ggplot2::scale_colour_manual(
        values = c(su = .LB_COLORI$su, giu = .LB_COLORI$giu), guide = "none"
      ) +
      ggplot2::labs(x = expression(log[2] ~ "FC (pooled)"), y = NULL,
                    subtitle = sprintf("Top %d target genes", nrow(top_disp))) +
      .lb_theme(base_size = 11)

    # --- pannello inferiore: il gene rappresentativo, studio per studio -------
    gene_rap <- .forest_gene_rappresentativo(top_genes, k_cluster)

    if (is.na(gene_rap)) {
      # Mai un ripiego silenzioso su un gene a bassa copertura: si mostra solo
      # il pannello superiore e la didascalia lo dichiara (vedi bottom_desc sotto).
      titolo <- .lb_titolo(entita = entita_titolo, k = k_cluster)
      combined <- p_top + patchwork::plot_annotation(title = titolo)
      h_inch <- max(3, top_n_actual * 0.35 + 1)
    } else {
      ps_g <- ps[ps$gene_id == gene_rap, , drop = FALSE]
      ps_g <- ps_g[order(ps_g$logFC), , drop = FALSE]
      gene_lab_rap <- top_genes$label[top_genes$gene_id == gene_rap][1L]
      pooled_g <- top_genes[top_genes$gene_id == gene_rap, , drop = FALSE]

      # "Pooled" per primo livello -> in basso nel pannello (convenzione forest
      # plot: la sintesi in fondo, sotto le righe per studio).
      livelli <- c("Pooled", ps_g$study_id)
      df_studi <- data.frame(
        riga  = factor(ps_g$study_id, levels = livelli),
        stima = ps_g$logFC,
        ci_lo = ps_g$logFC - 1.96 * ps_g$SE,
        ci_hi = ps_g$logFC + 1.96 * ps_g$SE,
        stringsAsFactors = FALSE
      )
      df_pool <- data.frame(
        riga  = factor("Pooled", levels = livelli),
        stima = pooled_g$logFC_pool[1L],
        ci_lo = pooled_g$logFC_pool[1L] - 1.96 * pooled_g$SE_pool[1L],
        ci_hi = pooled_g$logFC_pool[1L] + 1.96 * pooled_g$SE_pool[1L]
      )

      p_bottom <- ggplot2::ggplot() +
        ggplot2::geom_vline(xintercept = 0, linetype = "dashed", colour = .LB_COLORI$neutro) +
        ggplot2::geom_errorbar(
          data = df_studi,
          ggplot2::aes(y = .data$riga, xmin = .data$ci_lo, xmax = .data$ci_hi),
          # $neutro per le righe per-studio: $evidenza (nel tema) e' la tinta
          # delle stime POOLATE, riservata al solo rombo qui sotto.
          width = 0.2, colour = .LB_COLORI$neutro, orientation = "y"
        ) +
        ggplot2::geom_point(
          data = df_studi,
          ggplot2::aes(y = .data$riga, x = .data$stima),
          size = 2, colour = .LB_COLORI$neutro
        ) +
        ggplot2::geom_errorbar(
          data = df_pool,
          ggplot2::aes(y = .data$riga, xmin = .data$ci_lo, xmax = .data$ci_hi),
          width = 0.25, colour = .LB_COLORI$evidenza, linewidth = 0.9, orientation = "y"
        ) +
        ggplot2::geom_point(
          data = df_pool,
          ggplot2::aes(y = .data$riga, x = .data$stima),
          shape = 18, size = 5, colour = .LB_COLORI$evidenza
        ) +
        ggplot2::labs(x = expression(log[2] ~ "FC"), y = NULL,
                      subtitle = sprintf("%s, per study (k=%d)", gene_lab_rap, nrow(ps_g))) +
        .lb_theme(base_size = 11)

      titolo <- .lb_titolo(entita = entita_titolo, k = k_cluster)
      combined <- patchwork::wrap_plots(p_top, p_bottom, ncol = 1L, heights = c(2, 1)) +
        patchwork::plot_annotation(title = titolo)
      h_inch <- max(4, top_n_actual * 0.32 + (nrow(ps_g) + 1) * 0.3 + 1.2)
    }

    png_path <- file.path(out_dir, "forest.png")
    svg_path <- file.path(out_dir, "forest.svg")
    ggplot2::ggsave(png_path, combined, width = 8, height = h_inch, dpi = config$dpi)
    if (config$save_svg) {
      ggplot2::ggsave(svg_path, combined, width = 8, height = h_inch, device = "svg")
    } else {
      svg_path <- NA_character_
    }

    bottom_desc <- if (is.na(gene_rap)) {
      paste0(
        "omitted -- no gene among the top targets is measured in all studies of ",
        "this cluster; showing a low-coverage gene here would misrepresent ",
        "cross-study consistency"
      )
    } else {
      sprintf("%s per study, REML-pooled summary as diamond (k=%s)", gene_lab_rap, k_str)
    }
    caption_base <- sprintf(
      paste0("Forest plots for top %d significantly DE genes (FDR<%g). Top panel: ",
             "pooled effect +- 95%% CI per gene, ordered by effect and coloured by ",
             "sign. Bottom panel: %s."),
      top_n_actual, fdr_thr, bottom_desc
    )

  } else {
    cli::cli_abort("Unknown method for forest plot: {.field {method}}")
  }

  list(
    png_path = png_path,
    svg_path = svg_path,
    genes_mostrati = top_genes$gene_id,
    titolo = titolo,
    caption = paste0(caption_base, titolo_nota, .coverage_filter_note(filtro))
  )
}
