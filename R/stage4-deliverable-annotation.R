# R/stage4-deliverable-annotation.R --- il deliverable annotato, da UNA funzione
# di pacchetto.
#
# PERCHE' ESISTE. Fino al 2026-07-31 il deliverable nasceva da una sequenza di
# script di audit: le etichette in un file, la coerenza in un altro, l'efficacia
# del pooling e il materiale in un terzo, cuciti a mano. Nessuna delle misure era
# richiamata da un file della pipeline, quindi **un re-pool avrebbe prodotto di
# nuovo un deliverable senza `k_kish`** — cioe' senza la cosa che serviva.
#
# Questa funzione COMPONE i pezzi che gia' esistono e non ne riscrive nessuno:
# `.identify_layer_a_clusters` per l'identita' del contrasto (a monte),
# `.display_entity_labels` per l'etichetta, `.annotate_coherence` per i verdetti,
# `compute_pooling_effectiveness` e `detect_mixed_material` per i due assi nuovi.
# Una seconda implementazione di una qualunque di queste sarebbe un modo per
# farle divergere in silenzio.

#' Annota il deliverable dello Stadio 4
#'
#' Da una riga per gene-cluster a **una riga per meta-analisi**, con le metriche
#' del pool, l'etichetta risolta dall'ID, il verdetto di coerenza e i due assi
#' misurati il 2026-07-31: quanto il pooling e' efficace e su che materiale.
#'
#' Perche' i due assi nuovi: `k_effective` dice **quanti** studi entrano e non
#' quanto **contano**. Sui 191 gruppi di v13, 105 (55%) hanno uno studio sopra il
#' 50% del peso e 66 (35%) valgono meno di due studi efficaci — e **tutti sono
#' marcati coerenti**, perche' coerenza e dominanza sono assi indipendenti.
#'
#' @param cluster_pooled data.frame/tibble delle righe poolate (`cluster_id`,
#'   `gene_id`, `k_effective`, `FDR_BH_within_cluster`, `I2`, `tau2`).
#' @param per_study_de data.frame per-braccio (`cluster_id`, `gene_id`,
#'   `study_id`, `SE`). Il collasso dei bracci per studio lo fa
#'   [compute_pooling_effectiveness()].
#' @param cluster_meta data.frame con `cluster_id`, `contrast_entity`,
#'   `contrast_direction`, `contrast_control_key` e (opzionale)
#'   `canonical_name`. **Deve coprire tutti i cluster poolati**: un gruppo senza
#'   identita' del contrasto uscirebbe con entita' `NA` e nessuno se ne
#'   accorgerebbe leggendo il CSV, quindi la funzione si ferma.
#' @param member_labels data.frame opzionale con `cluster_id`, `study_id`,
#'   `label` (una riga per braccio). Serve solo all'asse del materiale: se NULL,
#'   quelle colonne escono `NA` **dichiarate**, non indovinate. Puo' contenere
#'   anche studi non poolati: la funzione li **scarta da sola** tenendo le
#'   coppie (cluster, studio) presenti in `per_study_de`.
#' @param coherence_verdicts data.frame opzionale con `ckey` e `motivo`, passato
#'   a `.annotate_coherence()`. Un verdetto che non trova il suo gruppo **ferma**
#'   la funzione: lasciarlo cadere marcherebbe un gruppo incoerente come
#'   coerente, cioe' il fallimento silenzioso a favore della conclusione comoda.
#' @param coherence_source character(1) provenienza dei verdetti (la marcatura e'
#'   una lettura umana: la sua provenienza viaggia nel dato).
#' @param fdr_threshold soglia per `n_sig` e per i geni su cui si misura
#'   l'efficacia (default 0,05).
#' @param entity_env ambiente dei dizionari ontologici; NULL = caricato al volo.
#'
#' @return data.frame, una riga per meta-analisi, ordinato per `k_effective`
#'   decrescente e poi per `cluster_id` (ordine **deterministico**: due
#'   esecuzioni sullo stesso input devono dare lo stesso file).
#' @export
annotate_stage4_deliverable <- function(cluster_pooled,
                                        per_study_de,
                                        cluster_meta,
                                        member_labels = NULL,
                                        coherence_verdicts = NULL,
                                        coherence_source = NA_character_,
                                        fdr_threshold = 0.05,
                                        entity_env = NULL) {
  cp <- as.data.frame(cluster_pooled, stringsAsFactors = FALSE)
  if (nrow(cp) == 0L) cli::cli_abort("annotate_stage4_deliverable: nessuna riga poolata.")

  # --- 1. metriche per cluster ---------------------------------------------
  met <- cp |>
    dplyr::group_by(.data$cluster_id) |>
    dplyr::summarise(
      # MASSIMO, non un valore a caso: `k_effective` e' per-gene, ed e' il
      # difetto che il 2026-07-31 ha messo un k sbagliato su quattro schede di
      # case study su nove.
      k_effective = as.integer(max(.data$k_effective, na.rm = TRUE)),
      n_geni      = dplyr::n(),
      n_sig       = sum(.data$FDR_BH_within_cluster < fdr_threshold, na.rm = TRUE),
      I2_med      = stats::median(.data$I2, na.rm = TRUE),
      tau2_med    = stats::median(.data$tau2, na.rm = TRUE),
      .groups = "drop") |>
    as.data.frame(stringsAsFactors = FALSE)

  # --- 2. identita' del contrasto ------------------------------------------
  meta <- as.data.frame(cluster_meta, stringsAsFactors = FALSE)
  mancanti <- setdiff(met$cluster_id, meta$cluster_id)
  if (length(mancanti) > 0L) {
    cli::cli_abort(c(
      "Cluster poolati senza identita' del contrasto: {length(mancanti)}.",
      "x" = "Uscirebbero con entita' NA e il CSV sembrerebbe a posto.",
      "i" = "Primi: {utils::head(mancanti, 5)}"))
  }
  d <- merge(met, meta, by = "cluster_id", all.x = TRUE)

  # --- 3. etichetta risolta dall'ID ----------------------------------------
  if ("contrast_entity" %in% names(d)) {
    env <- entity_env %||% .load_ontology_dicts()
    lab <- .display_entity_labels(d$contrast_entity, env = env)
    d$contrast_entity_label        <- lab$contrast_entity_label
    d$contrast_entity_label_source <- lab$contrast_entity_label_source
    d$contrast_entity_label_note   <- lab$contrast_entity_label_note
  }

  # --- 4. coerenza ----------------------------------------------------------
  if (!is.null(coherence_verdicts)) {
    d <- .annotate_coherence(d, coherence_verdicts, source = coherence_source)
  } else {
    d$coherence_verdict <- "coherent"
    d$coherence_reason  <- NA_character_
    d$coherence_source  <- coherence_source
  }

  # --- 5. efficacia del pooling --------------------------------------------
  tau2 <- cp[!is.na(cp$FDR_BH_within_cluster) &
               cp$FDR_BH_within_cluster < fdr_threshold,
             c("cluster_id", "gene_id", "tau2"), drop = FALSE]
  eff <- compute_pooling_effectiveness(
    as.data.frame(per_study_de, stringsAsFactors = FALSE), tau2)
  j <- match(d$cluster_id, eff$cluster_id)
  d$k_kish            <- eff$k_kish[j]
  d$quota_top1        <- eff$quota_top1[j]
  d$frazione_efficace <- eff$frazione_efficace[j]
  d$dominato          <- eff$dominato[j]
  d$studio_dominante  <- eff$studio_dominante[j]

  # `member_labels` contiene TUTTI gli studi assegnati; piu' sotto viene ridotto
  # ai soli poolati per l'asse del materiale. La versione intera serve qui, per
  # dire quanti studi il gate ha lasciato fuori.
  member_labels_full <- if (!is.null(member_labels) && nrow(member_labels) > 0L) {
    as.data.frame(member_labels, stringsAsFactors = FALSE)
  } else NULL

  # --- 6. quanto il gate del pooling ha cambiato la composizione -------------
  # Il gate dei controlli interni scarta studi: sui dati v13 il 76% dei gruppi
  # entra nel pool con MENO studi di quelli assegnati, 524 persi in totale.
  # Senza queste colonne il verdetto di coerenza — dato leggendo i membri
  # CENSITI — sembrerebbe riferirsi all'insieme poolato, che e' un altro.
  poolati <- split(per_study_de$study_id, per_study_de$cluster_id)
  censiti <- if (!is.null(member_labels_full) && nrow(member_labels_full) > 0L) {
    split(member_labels_full$study_id, member_labels_full$cluster_id)
  } else NULL
  d$n_studi_poolati <- vapply(d$cluster_id, function(c)
    length(unique(poolati[[c]])), integer(1L))
  if (!is.null(censiti)) {
    d$n_studi_censiti <- vapply(d$cluster_id, function(c)
      length(unique(censiti[[c]])), integer(1L))
    d$stessi_membri <- vapply(d$cluster_id, function(c)
      setequal(unique(censiti[[c]]), unique(poolati[[c]])), logical(1L))
    d$studi_caduti <- vapply(d$cluster_id, function(c)
      paste(sort(setdiff(unique(censiti[[c]]), unique(poolati[[c]]))), collapse = " "),
      character(1L))
  } else {
    d$n_studi_censiti <- NA_integer_
    d$stessi_membri   <- NA
    d$studi_caduti    <- NA_character_
  }

  # --- 7. materiale ---------------------------------------------------------
  # Si tengono SOLO gli studi che sono davvero nel pool. La funzione lo sa da
  # sola — `per_study_de` contiene esattamente le coppie (cluster, studio)
  # poolate — e non si fida di chi chiama: passare tutti gli studi assegnati
  # invece dei poolati cambia i conteggi (sui dati v13: 1.758 contro 1.234
  # studi-slot), ed e' un errore che si vede solo confrontando due tabelle.
  if (!is.null(member_labels) && nrow(member_labels) > 0L) {
    coppie_pool <- unique(paste(per_study_de$cluster_id, per_study_de$study_id,
                                sep = "\r"))
    member_labels <- member_labels[
      paste(member_labels$cluster_id, member_labels$study_id, sep = "\r") %in%
        coppie_pool, , drop = FALSE]
  }
  if (!is.null(member_labels) && nrow(member_labels) > 0L) {
    mat <- detect_mixed_material(member_labels)
    jm <- match(d$cluster_id, mat$cluster_id)
    d$materiale_misto <- mat$materiale_misto[jm]
    d$n_studi_model   <- mat$n_studi_model[jm]
    d$n_studi_primary <- mat$n_studi_primary[jm]
    d$n_studi_unknown <- mat$n_studi_unknown[jm]

    cls <- .classify_material(member_labels$label)
    rango <- c(unknown = 0L, primary = 1L, model = 2L)
    per_studio <- vapply(
      split(rango[cls], paste(member_labels$cluster_id, member_labels$study_id,
                              sep = "\r")),
      max, integer(1L))
    nomi <- c("unknown", "primary", "model")
    k <- per_studio[paste(d$cluster_id, d$studio_dominante, sep = "\r")]
    d$classe_studio_dominante <- ifelse(is.na(k), "unknown", nomi[k + 1L])
    # La congiunzione con `dominato` non e' un dettaglio: senza, la colonna si
    # accende anche dove lo "studio dominante" pesa il 2,5%, cioe' non domina.
    d$dominato_da_modello <- !is.na(d$dominato) & d$dominato &
      d$classe_studio_dominante == "model" &
      !is.na(d$n_studi_primary) & d$n_studi_primary > 0L
  } else {
    d$materiale_misto <- NA
    d$n_studi_model <- NA_integer_
    d$n_studi_primary <- NA_integer_
    d$n_studi_unknown <- NA_integer_
    d$classe_studio_dominante <- NA_character_
    d$dominato_da_modello <- NA
  }

  d <- d[order(-d$k_effective, d$cluster_id), , drop = FALSE]
  rownames(d) <- NULL
  d
}
