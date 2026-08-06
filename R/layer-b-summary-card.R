#' Lettura testuale della concordanza fra studi, da I^2 mediano
#'
#' Soglie standard (Cochrane): sotto 25 = eterogeneita' bassa, sotto 50 =
#' moderata, sotto 75 = sostanziale, altrimenti molto alta. Il testo e'
#' scritto in termini di CONCORDANZA (la domanda della scheda), che e'
#' l'inverso dell'eterogeneita': un I^2 alto vuol dire che gli studi
#' concordano poco sulla DIMENSIONE dell'effetto -- possono comunque
#' concordare sul segno, ed e' un'altra misura (vedi il controllo biologico
#' agonista/antagonista in RED_ALERT).
#' @keywords internal
.i2_lettura <- function(i2) {
  if (is.na(i2)) return("concordanza non valutabile (I^2 mancante)")
  if (i2 < 25) return("alta concordanza, eterogeneita' bassa")
  if (i2 < 50) return("concordanza moderata")
  if (i2 < 75) return("bassa concordanza, eterogeneita' sostanziale")
  "concordanza scarsa, eterogeneita' molto alta -- gli studi concordano piu' sul segno che sulla dimensione dell'effetto"
}

#' Scheda riassuntiva v2: cinque domande, non un dump di campi tecnici
#'
#' La scheda precedente (`.build_summary_card()`, invariata da questo task,
#' vedi sotto) elenca campi tecnici -- `safety_min: 0.06`, `direction_applied
#' distribution: none: 19687`, `Anchor: contrast/gain x HGNC:11766` -- che non
#' dicono nulla a un biologo, e sceglie il "Top gene" per solo FDR (per
#' TGF-beta1 e' la cornulina, che con quella via non c'entra). Questa funzione
#' e' la sostituzione: cinque righe che rispondono a cinque domande --- che
#' cosa e' stato confrontato, su quanti studi e quanto pesano davvero, quanto
#' concordano, che cosa si trova, quanto e' sporco --- seguite da un blocco
#' `PROVENIENZA` dove finiscono gli identificativi interni (`cluster_id`,
#' l'ID grezzo del contrasto, `run_id`, sha256): servono a chi verifica, non a
#' chi legge la scheda accanto alla figura.
#'
#' A differenza di `.build_summary_card()`, che legge `cluster_pooled` riga
#' per riga e scrive un file su disco, questa funzione e' PURA: prende la riga
#' gia' calcolata del deliverable annotato (`annotate_stage4_deliverable()`)
#' e ritorna una stringa markdown. Non tocca il disco -- chi la chiama decide
#' dove va (file, chunk Quarto, ...).
#'
#' Nessun taglio silenzioso: quando un dato manca (etichetta, verdetto,
#' run_id, bersagli, confronti imperfetti) la scheda lo DICE, non lo omette e
#' non ripiega senza dirlo su un identificativo tecnico.
#'
#' @param riga data.frame/tibble di **una** riga del deliverable annotato
#'   (`annotate_stage4_deliverable()`). Colonne usate: `cluster_id`,
#'   `contrast_entity` (ID grezzo del contrasto, opzionale),
#'   `contrast_entity_label`, `k_effective`, `k_kish`, `I2_med`, `n_sig`,
#'   `quota_top1`, `studio_dominante`, `materiale_misto`, `coherence_verdict`,
#'   e due colonne opzionali non ancora nel deliverable standard --
#'   `run_id`, `sha256` -- usate se presenti, altrimenti dichiarate `N/A`.
#'   Se `riga` ha piu' di una riga, si usa solo la prima.
#' @param bersagli_trovati character vector di bersagli attesi ritrovati,
#'   gia' formattati per la lettura (es. `"SMAD7 +1.41"` -- notazione col
#'   punto decimale, coerente con `sprintf("%+.2f", ...)` in
#'   `build_layer_b_results()`, non con la virgola italiana). `character(0)`
#'   (default) se nessuno o non calcolato per questo gruppo.
#' @param bersagli_attesi character vector (puo' essere vuoto) dei bersagli
#'   DICHIARATI dal chiamante, **indipendentemente** da quanti sono stati
#'   ritrovati (vedi `bersagli_attesi_provider` di [build_layer_b_results()]).
#'   Serve SOLO a distinguere in riga4 "nessuna aspettativa dichiarata" da
#'   "aspettative dichiarate ma non ritrovate" -- due affermazioni diverse
#'   che, prima di questo parametro, producevano la stessa frase (vedi
#'   [.lb_bersagli_trovati_txt()]). `character(0)` (default) -> "nessuna
#'   aspettativa dichiarata", coerente col comportamento precedente quando
#'   nessun bersaglio era dichiarato.
#' @param confronti_imperfetti list opzionale con `n`, `tot` (interi) e
#'   `peso` (frazione 0-1) dalla rilettura dei confronti poolati (vedi
#'   `docs/findings/2026-08-05-confronti-imperfetti.md`). `NULL` (default) se
#'   non misurato per questo gruppo -- dichiarato "non misurato", mai omesso
#'   in silenzio.
#' @param soglia_dominanza quota di peso oltre la quale lo studio piu'
#'   pesante viene segnalato come dominante. **Usata SOLO come ripiego**,
#'   quando `riga` non porta gia' la colonna `dominato` -- che
#'   `compute_pooling_effectiveness()` calcola a monte con la stessa soglia
#'   di default (0,5) e scrive nel deliverable annotato
#'   (`R/stage4-deliverable-annotation.R`). Quando la colonna c'e', vince
#'   sempre lei: ricalcolare qui con un valore indipendente farebbe
#'   divergere la scheda in silenzio se il default a monte cambiasse.
#'
#' @return `character(1)`, markdown.
#' @keywords internal
.summary_card_v2 <- function(riga, bersagli_trovati = character(0),
                             confronti_imperfetti = NULL,
                             soglia_dominanza = 0.5,
                             bersagli_attesi = character(0)) {
  riga <- as.data.frame(riga, stringsAsFactors = FALSE)
  if (nrow(riga) == 0L) {
    cli::cli_abort(".summary_card_v2: {.arg riga} non ha righe.")
  }
  riga <- riga[1L, , drop = FALSE]

  # Accessor tollerante: una colonna assente non e' un errore, e' un dato
  # mancante come un altro -- dichiarato piu' sotto, non fatto crashare qui.
  .v <- function(nm) if (nm %in% names(riga)) riga[[nm]][1L] else NA

  cluster_id <- as.character(.v("cluster_id"))
  entita_id  <- .v("contrast_entity")
  etichetta  <- .v("contrast_entity_label")
  k_eff      <- .v("k_effective")
  k_kish     <- suppressWarnings(as.numeric(.v("k_kish")))
  i2         <- suppressWarnings(as.numeric(.v("I2_med")))
  n_sig      <- .v("n_sig")
  quota_top1 <- suppressWarnings(as.numeric(.v("quota_top1")))
  dominante  <- .v("studio_dominante")
  dom_col    <- .v("dominato")
  mat_misto  <- .v("materiale_misto")
  verdetto   <- .v("coherence_verdict")
  run_id     <- .v("run_id")
  sha256     <- .v("sha256")

  .na_chr <- function(x) is.na(x) || !nzchar(as.character(x))

  # `dominato`, quando presente e non-NA, viene dalla stessa misura a monte
  # (compute_pooling_effectiveness()) e VINCE sempre sul ricalcolo locale: e'
  # il fix del rilievo Important della review -- una sola soglia, non due che
  # possono divergere in silenzio. Il ricalcolo da quota_top1 resta solo un
  # ripiego per righe che non portano ancora quella colonna. Regola condivisa
  # con .narrativa_bozza() (R/layer-b-narrative.R) via .lb_dominato_flag(): un
  # posto solo, cosi' le due schede non possono disallinearsi in silenzio.
  dominato_flag <- .lb_dominato_flag(dom_col, quota_top1, soglia_dominanza)

  # --- riga 1: cosa e' stato confrontato ------------------------------------
  # soggetto e verdetto_txt: stessa logica di .narrativa_bozza(), condivisa
  # via .lb_soggetto_da_contrasto()/.lb_verdetto_coerenza_txt() -- le
  # formulazioni restano quelle di questa scheda (passate come template).
  soggetto <- .lb_soggetto_da_contrasto(
    etichetta, entita_id,
    non_disponibile = "identita' del contrasto non disponibile (vedi PROVENIENZA)")
  verdetto_txt <- .lb_verdetto_coerenza_txt(
    verdetto,
    tmpl_na = "verdetto di coerenza non disponibile",
    tmpl_coherent = "verdetto di coerenza: coerente",
    tmpl_altro = "VERDETTO DI COERENZA: %s -- i confronti raggruppati potrebbero non misurare lo stesso contrasto")
  riga1 <- sprintf(
    "- **Cosa e' stato confrontato:** %s, trattato contro il proprio controllo (%s).",
    soggetto, verdetto_txt)

  # --- riga 2: su quanti studi, e quanto pesano davvero ---------------------
  k_eff_txt  <- if (is.na(k_eff)) "non disponibile" else as.character(as.integer(k_eff))
  k_kish_txt <- if (is.na(k_kish)) "non disponibile" else sprintf("%.1f", k_kish)
  peso_studio <- if (!is.na(quota_top1)) {
    nome_studio <- if (!.na_chr(dominante)) as.character(dominante) else "non identificato"
    dom_flag <- if (isTRUE(dominato_flag)) " -- **un solo studio pesa piu' della meta'**" else ""
    sprintf(" Lo studio piu' pesante (%s) porta il %.1f%% del peso%s.",
            nome_studio, 100 * quota_top1, dom_flag)
  } else {
    " Il peso del singolo studio piu' pesante non e' disponibile."
  }
  materiale_txt <- .lb_materiale_misto_txt(mat_misto)
  riga2 <- sprintf(
    "- **Su quanti studi, e quanto pesano davvero:** %s studi entrano nel pool, ma quelli che contano davvero (numero efficace di Kish) sono %s.%s%s",
    k_eff_txt, k_kish_txt, peso_studio, materiale_txt)

  # --- riga 3: quanto concordano ---------------------------------------------
  i2_txt <- if (is.na(i2)) "non disponibile" else sprintf("%.1f%%", i2)
  riga3 <- sprintf("- **Quanto concordano:** I² mediano = %s (%s).",
                   i2_txt, .i2_lettura(i2))

  # --- riga 4: cosa si trova --------------------------------------------------
  # .lb_bersagli_trovati_txt() distingue "nessuna aspettativa dichiarata" da
  # "aspettative dichiarate ma non ritrovate" (fix rilievo C2, 2026-08-06):
  # prima la scheda diceva la STESSA frase nei due casi, in contraddizione
  # con .narrativa_bozza() che gia' distingueva i due, a quindici righe di
  # distanza sulla stessa pagina.
  bersagli_txt <- .lb_bersagli_trovati_txt(bersagli_attesi, bersagli_trovati)
  n_sig_txt <- if (is.na(n_sig)) "non disponibile" else as.character(as.integer(n_sig))
  riga4 <- sprintf(
    "- **Cosa si trova:** %s -- su %s geni significativi in totale (FDR<0,05).",
    bersagli_txt, n_sig_txt)

  # --- riga 5: quanto e' sporco -----------------------------------------------
  # Clausola condivisa con .narrativa_bozza() via .lb_confronti_imperfetti_txt()
  # (ritorna solo il contenuto, senza il prefisso di bullet ne' il punto finale).
  riga5 <- sprintf("- **Quanto e' sporco:** %s.",
                   .lb_confronti_imperfetti_txt(confronti_imperfetti))

  # --- provenienza: dove vivono gli identificativi interni --------------------
  .prov <- function(x) if (.na_chr(x)) "N/A" else as.character(x)
  provenienza <- c(
    "",
    "---",
    "",
    "**PROVENIENZA** (per la verifica, non per la lettura)",
    "",
    sprintf("- cluster_id: `%s`", .prov(cluster_id)),
    sprintf("- identita' del contrasto (ID grezzo): `%s`", .prov(entita_id)),
    sprintf("- run_id: `%s`", .prov(run_id)),
    sprintf("- sha256: `%s`", .prov(sha256))
  )

  paste(c(riga1, riga2, riga3, riga4, riga5, provenienza), collapse = "\n")
}

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
#' @param pooling_effectiveness data.frame opzionale, una riga per cluster, con
#'   le colonne di \code{compute_pooling_effectiveness()} e
#'   \code{detect_mixed_material()}: `k_kish`, `quota_top1`,
#'   `frazione_efficace`, `dominato`, `studio_dominante`, `materiale_misto`,
#'   `dominato_da_modello`, `n_studi_model/primary/unknown`.
#'
#'   Serve perche' `k_effective` dice **quanti** studi entrano e non quanto
#'   **contano**: il case study di Parkinson ha k=10 ma 1,8 studi efficaci e il
#'   73% del peso su un modello cellulare, e senza queste righe chi legge la
#'   scheda accanto alla figura non lo vede.
#'
#'   Quando NULL (default) la scheda esce **identica** a prima — nessuna riga
#'   vuota, nessun "NA": un bundle costruito senza annotazione resta leggibile.
#'
#' @return list `md_path`.
#' @keywords internal
.build_summary_card <- function(cluster_id, layer_a_subset, stage3_metadata,
                                selection_row, config, out_dir = tempdir(),
                                per_cluster_samples = NULL,
                                pooling_effectiveness = NULL) {
  cp <- layer_a_subset$cluster_pooled
  cp_c <- cp[cp$cluster_id == cluster_id, , drop = FALSE]
  if (nrow(cp_c) == 0L) {
    cli::cli_abort("No rows in cluster_pooled for cluster {.field {cluster_id}}")
  }

  fdr_thr <- config$fdr_threshold
  method <- unique(cp_c$method)[1L]
  # k del CLUSTER (massimo), non del primo gene del parquet: vedi
  # .cluster_k_effective(). Quattro schede su nove sbagliavano.
  k_eff <- .cluster_k_effective(cp_c)
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

  # --- efficacia del pooling (additiva: NULL -> nessuna riga) ---------------
  eff_lines <- character(0L)
  if (!is.null(pooling_effectiveness) && nrow(pooling_effectiveness) > 0L) {
    er <- pooling_effectiveness[pooling_effectiveness$cluster_id == cluster_id, ,
                                drop = FALSE]
    if (nrow(er) > 0L) {
      .g <- function(nm) if (nm %in% names(er)) er[[nm]][1L] else NA
      k_kish <- .g("k_kish"); q1 <- .g("quota_top1")
      dom <- isTRUE(.g("dominato"))
      eff_lines <- c(
        sprintf("- **Effective studies (Kish):** %s of %s (%s of nominal k)",
                if (is.na(k_kish)) "N/A" else sprintf("%.1f", k_kish),
                as.character(k_eff),
                if (is.na(.g("frazione_efficace"))) "N/A"
                else sprintf("%.0f%%", 100 * .g("frazione_efficace"))),
        sprintf("- **Heaviest study:** %s (%s of the weight)%s",
                .g("studio_dominante") %||% "N/A",
                if (is.na(q1)) "N/A" else sprintf("%.1f%%", 100 * q1),
                if (dom) " -- **this group is dominated by a single study**" else "")
      )
      mm <- .g("materiale_misto")
      if (!is.na(mm) && isTRUE(mm)) {
        eff_lines <- c(eff_lines, sprintf(
          "- **Material:** MIXED -- %s in vitro model / %s patient-derived / %s unclassified%s",
          as.character(.g("n_studi_model")), as.character(.g("n_studi_primary")),
          as.character(.g("n_studi_unknown")),
          if (isTRUE(.g("dominato_da_modello")))
            " -- **the heaviest study is an in vitro model**" else ""))
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
    eff_lines,
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
#' Collegamento (Task 7bis, 2026-08-05): quando il chiamante passa
#' `narrativa_bozza_md` (tipicamente l'output di `.narrativa_bozza()`, in
#' `R/layer-b-narrative.R`), gli stub TODO sono sostituiti da quel testo --
#' gia' marcato `> BOZZA -- da rivedere` dalla funzione stessa, quindi non
#' serve un'altra intestazione TODO sopra. Senza (default `NULL`, e' il caso
#' del ripiego quando il deliverable annotato non e' disponibile) il
#' comportamento resta quello di sempre: stub TODO, invariato per
#' retrocompatibilita' coi bundle costruiti prima di questo collegamento.
#'
#' @param cluster_id character (1).
#' @param summary_card_path character path al summary_card.md (NULL OK;
#'   entry skip).
#' @param selection_row tibble (1 row).
#' @param config list.
#' @param out_dir character.
#' @param narrativa_bozza_md character(1) opzionale, markdown gia' pronto
#'   (tipicamente `.narrativa_bozza()`) da inserire al posto degli stub TODO.
#'   `NULL` (default) -> stub TODO, come prima di questo collegamento.
#' @param nota_ripiego character(1) opzionale: quando non `NULL`, una riga in
#'   evidenza subito sotto il titolo che DICHIARA che questo case study sta
#'   usando la scheda/narrativa precedenti (invece delle nuove) e perche' --
#'   mai un ripiego silenzioso. `NULL` (default) -> nessuna nota.
#'
#' @return character path al .qmd scritto.
#' @keywords internal
.write_narrative_template <- function(cluster_id, summary_card_path,
                                      selection_row, config,
                                      out_dir = tempdir(),
                                      narrativa_bozza_md = NULL,
                                      nota_ripiego = NULL) {
  label_paper <- selection_row$label_paper[1L]

  summary_block <- if (!is.null(summary_card_path) &&
                       file.exists(summary_card_path)) {
    paste(readLines(summary_card_path), collapse = "\n")
  } else {
    sprintf("_(summary_card.md not yet generated for cluster %s)_",
            cluster_id)
  }

  corpo_narrativa <- if (!is.null(narrativa_bozza_md)) {
    c("## Narrative", "", narrativa_bozza_md, "")
  } else {
    c(
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
      ""
    )
  }

  nota_lines <- if (!is.null(nota_ripiego)) {
    c(sprintf("> **Nota:** %s", nota_ripiego), "")
  } else {
    NULL
  }

  # Lista figure ALLINEATA a config$figure_escluse (Task 8): prima di questo
  # fix la lista era cablata a mano e citava sempre ma.svg/heterogeneity.svg,
  # anche quando la config di default (Task 8) le esclude dal bundle --
  # riferimenti a file che non esistono mai sul disco. Un config senza quella
  # chiave (bundle vecchi, list letterale invece di layer_b_default_config())
  # non esclude nulla, come .build_cluster_bundle() in R/layer-b-build.R.
  #
  # go_enrichment segue una chiave DIVERSA (`config$go_enrichment`, booleano:
  # se e' generata affatto, non se e' esclusa dal bundle come ma/heterogeneity)
  # perche' e' l'unica delle sei figure controllata da un flag invece che da
  # `figure_escluse` (vedi R/layer-b-build.R, `if (isTRUE(config$go_enrichment))`).
  # Prima di questo fix (minor, revisione finale 2026-08-06) lo stub elencava
  # sempre go_enrichment.svg anche quando `config$go_enrichment = FALSE`
  # significava che il file non veniva mai scritto.
  figure_disponibili <- c(
    volcano       = "volcano.svg",
    forest        = "forest.svg (REM/MEGA-AUG only)",
    ma            = "ma.svg",
    heatmap       = "heatmap.svg",
    go_enrichment = "go_enrichment.svg",
    heterogeneity = "heterogeneity.svg (REM only)"
  )
  figure_escluse <- config$figure_escluse %||% character(0)
  if (!isTRUE(config$go_enrichment)) {
    figure_escluse <- c(figure_escluse, "go_enrichment")
  }
  figure_incluse <- figure_disponibili[!names(figure_disponibili) %in% figure_escluse]
  figure_lines <- if (length(figure_incluse) > 0L) {
    paste0("- ", unname(figure_incluse))
  } else {
    character(0)
  }

  qmd_lines <- c(
    "---",
    sprintf('title: "Case study: %s (%s)"', label_paper, cluster_id),
    "---",
    "",
    sprintf("# Case study: %s", label_paper),
    "",
    nota_lines,
    "## Summary card",
    "",
    summary_block,
    "",
    corpo_narrativa,
    "## Figures",
    "",
    "::: {.figure-list}",
    figure_lines,
    ":::"
  )

  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  qmd_path <- file.path(out_dir, "narrative.qmd")
  writeLines(qmd_lines, qmd_path)
  qmd_path
}
