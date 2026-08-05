#' Soglia oltre la quale l'asse del volcano va compresso
#'
#' Un solo gene a -log10 p = 310 schiaccia tutti gli altri in una striscia
#' illeggibile (misurato su TGF-beta1 il 2026-08-05). La compressione e' una
#' manipolazione visiva e va DICHIARATA in didascalia ogni volta che scatta:
#' un taglio silenzioso e' esattamente cio' che questo progetto ha deciso di non
#' fare mai.
#'
#' @param y vettore dei valori sull'asse (-log10 p).
#' @param quota se il 99-esimo percentile copre meno di questa frazione del
#'   massimo, l'asse e' dominato da pochi punti e va compresso.
#' @return la soglia, oppure Inf se non serve comprimere.
#' @keywords internal
.volcano_soglia_asse <- function(y, quota = 0.6) {
  y <- y[is.finite(y)]
  if (length(y) < 10L) return(Inf)
  p99 <- stats::quantile(y, 0.99, names = FALSE)
  if (p99 >= quota * max(y)) return(Inf)
  as.numeric(p99)
}

#' Filtro di copertura sui candidati etichetta del volcano
#'
#' Le etichette pescano SOLO fra i geni ben misurati (stesso criterio gia'
#' usato da tabella/heatmap/forest): sui dati veri pescavano geni misurati in
#' 2 studi su 59 (CD300C, PROK2 su TGF-beta1, misurato il 2026-08-05) invece
#' dei bersagli biologici. A differenza delle altre figure, qui il filtro
#' NON deve togliere righe dal grafico: e' un dettaglio di TESTO (quale nome
#' mostrare), non di dato disegnato -- togliere punti sarebbe una
#' falsificazione visiva.
#'
#' Helper condiviso fra `.volcano_labels()` (la scelta dei nomi) e
#' `.build_volcano()` (la nota in didascalia): stesso calcolo, un solo posto,
#' cosi' i due non possono disallinearsi.
#'
#' @param cp data.frame poolato del cluster.
#' @param config list di configurazione Layer B.
#' @return output di [.filter_genes_by_coverage()], con in piu' `sig_idx`: gli
#'   indici (in `cp`) dei geni significativi sopravvissuti al filtro.
#' @keywords internal
.volcano_label_filtro <- function(cp, config) {
  vuoto <- list(genes = cp[0L, , drop = FALSE], n_dropped = 0L,
                k_max = NA_integer_, k_min_richiesto = NA_integer_,
                fallback = FALSE, sig_idx = integer(0))
  if (nrow(cp) == 0L) return(vuoto)
  sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < config$fdr_threshold
  sig_idx <- which(sig)
  if (length(sig_idx) == 0L) return(vuoto)

  k_cluster <- .cluster_k_effective(cp)
  candidati <- cp[sig_idx, , drop = FALSE]
  candidati$.idx_originale <- sig_idx
  filtro <- .filter_genes_by_coverage(candidati, config$top_genes_min_k_frac,
                                      k_max = k_cluster)
  filtro$sig_idx <- filtro$genes$.idx_originale
  filtro
}

#' Frase di didascalia per il filtro di copertura sulle ETICHETTE del volcano
#'
#' A differenza di `.coverage_filter_note()` (tabella/heatmap/forest, dove il
#' filtro toglie righe dalla figura), qui il filtro non toglie nulla dal
#' grafico: tutti i punti restano disegnati, solo la scelta del NOME cambia.
#' La frase lo dice esplicitamente per evitare che si legga come un taglio di
#' dati.
#'
#' @param filtro output di [.volcano_label_filtro()].
#' @return character(1), eventualmente "".
#' @keywords internal
.volcano_label_coverage_note <- function(filtro) {
  if (isTRUE(filtro$fallback)) {
    return(sprintf(
      paste0(" Label coverage filter (>= %d of %d studies) not applied: no ",
             "significant gene met it in this cluster, so labels are drawn ",
             "from the full significant set."),
      filtro$k_min_richiesto, filtro$k_max))
  }
  if (is.null(filtro$n_dropped) || filtro$n_dropped == 0L) return("")
  sprintf(
    paste0(" Labels are shown only for genes measured in at least %d of %d ",
           "studies (%d significant gene(s) excluded from labeling, not from ",
           "the plot -- all points remain visible): with few studies the ",
           "random-effects model estimates tau^2 as zero, which collapses the ",
           "standard error and inflates significance."),
    filtro$k_min_richiesto, filtro$k_max, filtro$n_dropped)
}

#' Volcano plot publication-grade per un cluster
#'
#' Genera volcano plot (logFC_pool vs -log10(p_value_pool)) con FDR<0.05 color,
#' top-N labels via ggrepel. Salva PNG (DPI configurabile) + SVG.
#'
#' Due correzioni rispetto alla versione precedente (Task 4, 2026-08-05):
#' l'asse verticale si comprime, in modo DICHIARATO, quando un punto domina
#' tutti gli altri (vedi [.volcano_soglia_asse()]); le etichette pescano solo
#' fra i geni ben misurati (vedi [.volcano_label_filtro()]), ma nessun punto
#' viene mai tolto dal grafico per questo.
#'
#' @param cluster_pooled_subset tibble subset di `cluster_pooled.parquet` per il
#'   cluster di interesse (tutte le righe stesso `cluster_id`).
#' @param out_dir character path al dir dove salvare `volcano.png` + `volcano.svg`.
#' @param config list di config (vedi [layer_b_default_config()]).
#' @param etichetta character(1) opzionale, l'etichetta leggibile del gruppo
#'   (tipicamente `selection_row$label_paper`) da usare come `entita` del
#'   titolo (`.lb_titolo()`). Se NULL, NA o vuota il titolo ripiega sul
#'   `cluster_id` grezzo -- MAI in silenzio: la caption lo dichiara.
#'
#' @return list con `png_path`, `svg_path`, `titolo`, `caption`.
#' @keywords internal
.build_volcano <- function(cluster_pooled_subset, out_dir, config, etichetta = NULL) {
  cp <- cluster_pooled_subset
  fdr_thr <- config$fdr_threshold
  top_n <- config$top_n_volcano_labels

  cp$is_sig <- !is.na(cp$FDR_BH_within_cluster) & cp$FDR_BH_within_cluster < fdr_thr
  cp$neg_log10_p <- -log10(pmax(cp$p_value_pool, .Machine$double.xmin))

  n_total <- nrow(cp)
  n_sig <- sum(cp$is_sig, na.rm = TRUE)

  cp$label <- .volcano_labels(cp, config)
  filtro_label <- .volcano_label_filtro(cp, config)

  # Colore per verso, non solo sig/non-sig: stessa semantica di forest
  # (.LB_COLORI$su/$giu), coerente col resto del Layer B.
  cp$verso <- ifelse(!cp$is_sig, "neutro", ifelse(cp$logFC_pool >= 0, "su", "giu"))
  cp$verso <- factor(cp$verso, levels = c("su", "giu", "neutro"))

  # --- compressione DICHIARATA dell'asse verticale ---------------------------
  # Scatta solo quando .volcano_soglia_asse() la trova necessaria. I punti
  # oltre soglia restano disegnati: e' la loro POSIZIONE a essere compressa
  # (radice quadrata oltre la soglia), non un taglio -- nessun punto sparisce.
  soglia <- .volcano_soglia_asse(cp$neg_log10_p)
  comprimi <- is.finite(soglia)
  if (comprimi) {
    # pmax(...,0) sotto radice: ifelse valuta ENTRAMBI i rami per ogni
    # elemento (vettorizzato), quindi senza la guardia sqrt() riceverebbe
    # argomenti negativi per le righe sotto soglia -> warning "NaNs produced"
    # anche se quel risultato non viene mai usato.
    cp$y_plot <- ifelse(cp$neg_log10_p <= soglia, cp$neg_log10_p,
                        soglia + sqrt(pmax(cp$neg_log10_p - soglia, 0)))
    n_oltre <- sum(cp$neg_log10_p > soglia, na.rm = TRUE)
  } else {
    cp$y_plot <- cp$neg_log10_p
  }

  # entita' del titolo: l'etichetta leggibile se c'e', altrimenti il
  # cluster_id grezzo -- MAI in silenzio, la caption dichiara il ripiego.
  etichetta_ok <- !is.null(etichetta) && !is.na(etichetta) && nzchar(etichetta)
  entita_titolo <- if (etichetta_ok) etichetta else cp$cluster_id[1L]
  titolo_nota <- if (etichetta_ok) "" else paste0(
    " Figure title falls back to the raw cluster_id: no readable group ",
    "label (label_paper) was provided to .build_volcano()."
  )
  k_cluster <- .cluster_k_effective(cp)
  titolo <- .lb_titolo(entita = entita_titolo, k = k_cluster)

  # Rasterizza il layer di punti nel SVG (axis/labels/legend restano vector).
  # ggrastr e' in Suggests: fallback skip-graceful se non installato (SVG resta
  # full vector e quindi piu' grande, ma plot e' identico). Per N~28k geni la
  # rasterizzazione porta volcano.svg da ~5MB a ~150-300KB.
  use_rasterize <- requireNamespace("ggrastr", quietly = TRUE)
  point_layer <- ggplot2::geom_point(
    ggplot2::aes(colour = verso), alpha = 0.6, size = 1.5
  )
  if (use_rasterize) {
    point_layer <- ggrastr::rasterise(point_layer, dpi = config$dpi)
  }

  p <- ggplot2::ggplot(cp, ggplot2::aes(x = logFC_pool, y = y_plot)) +
    point_layer +
    ggplot2::scale_colour_manual(
      values = c(su = .LB_COLORI$su, giu = .LB_COLORI$giu, neutro = .LB_COLORI$neutro),
      labels = c(su = sprintf("Up (FDR<%g)", fdr_thr),
                giu = sprintf("Down (FDR<%g)", fdr_thr),
                neutro = "Not significant"),
      name = NULL, drop = FALSE
    ) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed",
                        colour = .LB_COLORI$neutro, alpha = 0.7) +
    ggrepel::geom_text_repel(
      ggplot2::aes(label = label),
      size = 3, max.overlaps = top_n,
      box.padding = 0.3, segment.alpha = 0.5,
      na.rm = TRUE
    ) +
    ggplot2::labs(
      title = titolo,
      x = expression(log[2] ~ "FC pooled"),
      y = expression(-log[10] ~ "p-value pooled")
    ) +
    .lb_theme(base_size = 11)

  if (comprimi) {
    # Linea tratteggiata al punto di compressione: la manipolazione visiva si
    # vede a colpo d'occhio, non solo nella didascalia.
    p <- p +
      ggplot2::geom_hline(yintercept = soglia, linetype = "dotted",
                          colour = .LB_COLORI$neutro, linewidth = 0.4)
    # Tick reali sull'asse: sotto soglia lineari, sopra soglia posizionati con
    # la stessa trasformazione dei punti ma etichettati col valore VERO (mai
    # col valore compresso, che non significa nulla per il lettore).
    brks_orig <- pretty(c(0, soglia), n = 5)
    brks_orig <- brks_orig[brks_orig >= 0 & brks_orig <= soglia]
    y_max <- max(cp$neg_log10_p, na.rm = TRUE)
    brks_orig <- sort(unique(c(brks_orig, round(soglia), round(y_max))))
    brks_plot <- ifelse(brks_orig <= soglia, brks_orig,
                        soglia + sqrt(pmax(brks_orig - soglia, 0)))
    p <- p + ggplot2::scale_y_continuous(breaks = brks_plot, labels = brks_orig)
  }

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
  if (comprimi) {
    caption <- paste0(caption, sprintf(
      paste0(" Vertical axis compressed above -log10(p) = %.1f: %d gene(s) ",
             "exceed the threshold (all points remain plotted; only their ",
             "y-position above the threshold is compressed)."),
      soglia, n_oltre
    ))
  }
  caption <- paste0(caption, .volcano_label_coverage_note(filtro_label), titolo_nota)

  list(
    png_path = png_path,
    svg_path = svg_path,
    titolo = titolo,
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
#' Filtro di copertura (Task 4, 2026-08-05): i candidati all'etichetta passano
#' da [.volcano_label_filtro()] prima del ranking, cosi' un gene misurato in
#' pochi studi (tau^2 stimato a zero, SE collassata, FDR minuscolo) non vince
#' un posto fra i top-N al posto di un bersaglio biologico vero. Il filtro
#' agisce SOLO qui, sulla scelta del nome: nessuna riga di `cp` viene toccata.
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

  filtro <- .volcano_label_filtro(cp, config)
  sig_idx <- filtro$sig_idx
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
