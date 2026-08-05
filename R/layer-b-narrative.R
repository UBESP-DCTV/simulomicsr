#' Bozza di narrativa per un case study Layer B, composta solo dai numeri ricevuti
#'
#' Ogni case study Layer B ha oggi tre sezioni ("Biological context",
#' "Findings", "Discussion", vedi \code{.write_narrative_template()} in
#' \code{R/layer-b-summary-card.R}) che sono stub vuoti -- nessuna figura, per
#' quanto curata, compensa un documento che non dice cosa significa quello
#' che mostra. Questa funzione produce un testo di partenza, non la
#' narrativa finita: **compone frasi solo dai valori che riceve**. Non ha
#' una tabella interna di conoscenza biologica, non afferma nulla sulla
#' letteratura che non sia verificabile nei suoi argomenti, non deduce
#' meccanismi. Le attese di letteratura arrivano da \code{bersagli_attesi},
#' un argomento del chiamante -- non un dizionario dentro il pacchetto. Una
#' narrativa che affermasse cose non verificabili nel deliverable sarebbe
#' peggio di una sezione vuota, perche' sembrerebbe autorevole senza esserlo:
#' per questo il testo e' marcato \code{BOZZA} in modo visibile fin dalla
#' prima riga -- e' testo scientifico che l'utente dovra' leggere e firmare,
#' non un testo pronto per la stampa.
#'
#' La riga consumata e' la STESSA riga del deliverable annotato che consuma
#' \code{.summary_card_v2()} (vedi \code{R/layer-b-summary-card.R}): stessi
#' accessor tolleranti (una colonna assente e' un dato mancante come un
#' altro, mai un errore), stessa regola sul ripiego -- quando un dato manca
#' (etichetta, verdetto, bersagli, confronti imperfetti) la narrativa lo
#' DICE, non lo omette e non ripiega in silenzio.
#'
#' @param riga data.frame/tibble di **una** riga del deliverable annotato
#'   (\code{annotate_stage4_deliverable()}). Colonne usate se presenti:
#'   \code{contrast_entity} (ID grezzo del contrasto, opzionale),
#'   \code{contrast_entity_label}, \code{k_effective}, \code{k_kish},
#'   \code{I2_med}, \code{n_sig}, \code{quota_top1}, \code{studio_dominante},
#'   \code{dominato}, \code{materiale_misto}, \code{coherence_verdict}. Se
#'   \code{riga} ha piu' di una riga, si usa solo la prima.
#' @param bersagli_attesi character vector di simboli genici attesi dalla
#'   letteratura per questa entita'. **Argomento del chiamante**: questa
#'   funzione non ha una tabella interna di bersagli e non deduce quali
#'   geni ci si aspetti -- l'unica affermazione che fa e' "questi sono i
#'   bersagli dichiarati da chi ha chiamato la funzione".
#'   \code{character(0)} (default) se non forniti per questo gruppo --
#'   dichiarato esplicitamente, non taciuto (un'assenza silenziosa
#'   suggerirebbe "zero aspettative di letteratura", che e' un'affermazione
#'   diversa da "nessuna aspettativa e' stata dichiarata qui").
#' @param trovati data.frame/tibble opzionale con almeno le colonne
#'   \code{gene} e \code{logFC} (opzionale \code{FDR}) per i bersagli attesi
#'   effettivamente ritrovati fra i geni misurati (tipicamente l'output di
#'   \code{.bersagli_trovati()}). \code{NULL} (default) o 0 righe se nessuno
#'   e' stato ritrovato -- dichiarato esplicitamente, non con un paragrafo
#'   vuoto.
#' @param imperfetti list opzionale con \code{n}, \code{tot} (interi) e
#'   \code{peso} (frazione 0-1) dalla rilettura dei confronti poolati (vedi
#'   \code{docs/findings/2026-08-05-confronti-imperfetti.md}). \code{NULL}
#'   (default) se non misurato per questo gruppo -- dichiarato "non
#'   misurato", mai omesso in silenzio.
#'
#' @return \code{character(1)}, markdown con l'intestazione \code{> BOZZA --
#'   da rivedere} seguita da tre paragrafi: **Contesto** (che cosa e' stato
#'   confrontato, su quanti studi, e le attese di letteratura dichiarate),
#'   **Cosa si vede** (quali bersagli attesi sono stati ritrovati e coi
#'   quali valori, piu' il totale dei geni significativi e la concordanza
#'   fra studi), **Limiti di questo gruppo** (confronti imperfetti,
#'   dominanza di un singolo studio, materiale misto).
#' @keywords internal
.narrativa_bozza <- function(riga, bersagli_attesi = character(0),
                             trovati = NULL, imperfetti = NULL) {
  riga <- as.data.frame(riga, stringsAsFactors = FALSE)
  if (nrow(riga) == 0L) {
    cli::cli_abort(".narrativa_bozza: {.arg riga} non ha righe.")
  }
  riga <- riga[1L, , drop = FALSE]

  # Accessor tollerante: una colonna assente non e' un errore, e' un dato
  # mancante come un altro -- stesso pattern di .summary_card_v2().
  .v <- function(nm) if (nm %in% names(riga)) riga[[nm]][1L] else NA
  .na_chr <- function(x) is.na(x) || !nzchar(as.character(x))

  entita_id  <- .v("contrast_entity")
  etichetta  <- .v("contrast_entity_label")
  k_eff      <- .v("k_effective")
  k_kish     <- suppressWarnings(as.numeric(.v("k_kish")))
  i2         <- suppressWarnings(as.numeric(.v("I2_med")))
  n_sig      <- .v("n_sig")
  verdetto   <- .v("coherence_verdict")
  quota_top1 <- suppressWarnings(as.numeric(.v("quota_top1")))
  dominante  <- .v("studio_dominante")
  dom_col    <- .v("dominato")
  mat_misto  <- .v("materiale_misto")

  # --- soggetto: stesso ripiego dichiarato di .summary_card_v2() -----------
  soggetto <- if (!.na_chr(etichetta)) {
    as.character(etichetta)
  } else if (!.na_chr(entita_id)) {
    sprintf("%s (etichetta leggibile non disponibile: ripiego sull'identificativo grezzo del contrasto)",
            as.character(entita_id))
  } else {
    "identita' del contrasto non disponibile"
  }

  k_eff_txt  <- if (is.na(k_eff)) "non disponibile" else as.character(as.integer(k_eff))
  k_kish_txt <- if (is.na(k_kish)) "non disponibile" else sprintf("%.1f", k_kish)

  verdetto_txt <- if (.na_chr(verdetto)) {
    "il verdetto di coerenza non e' disponibile per questo gruppo"
  } else if (identical(as.character(verdetto), "coherent")) {
    "il verdetto di coerenza per questo gruppo e' coerente"
  } else {
    sprintf("il VERDETTO DI COERENZA per questo gruppo e' %s -- i confronti raggruppati potrebbero non misurare lo stesso contrasto",
            toupper(as.character(verdetto)))
  }

  n_attesi <- length(bersagli_attesi)
  attesi_txt <- if (n_attesi == 0L) {
    "Per questo gruppo non sono stati forniti bersagli attesi dalla letteratura (nessuna aspettativa dichiarata dal chiamante)."
  } else {
    sprintf("In letteratura sono stati dichiarati %d bersagli attesi per questa entita' (argomento fornito da chi chiama questa funzione, non una tabella interna): %s.",
            n_attesi, paste(as.character(bersagli_attesi), collapse = ", "))
  }

  contesto <- sprintf(
    "**Contesto.** Il gruppo confronta %s, su %s studi (di cui %s efficaci secondo il numero di Kish); %s. %s",
    soggetto, k_eff_txt, k_kish_txt, verdetto_txt, attesi_txt)

  # --- paragrafo 2: cosa si vede --------------------------------------------
  trovati_df <- if (is.null(trovati)) {
    data.frame(gene = character(0), stringsAsFactors = FALSE)
  } else {
    as.data.frame(trovati, stringsAsFactors = FALSE)
  }
  n_trovati <- nrow(trovati_df)

  trovati_txt <- if (n_attesi == 0L) {
    "Non essendo stati dichiarati bersagli attesi, non e' possibile riportare quanti ne siano stati ritrovati."
  } else if (n_trovati == 0L) {
    sprintf("Nessuno dei %d bersagli attesi e' stato ritrovato fra i geni misurati per questo gruppo.",
            n_attesi)
  } else {
    ha_fdr <- "FDR" %in% names(trovati_df)
    dettagli <- vapply(seq_len(n_trovati), function(i) {
      gene_i  <- as.character(trovati_df$gene[i])
      logfc_i <- if ("logFC" %in% names(trovati_df)) {
        suppressWarnings(as.numeric(trovati_df$logFC[i]))
      } else {
        NA_real_
      }
      logfc_txt <- if (is.na(logfc_i)) "logFC non disponibile" else sprintf("logFC=%.2f", logfc_i)
      if (ha_fdr) {
        fdr_i   <- suppressWarnings(as.numeric(trovati_df$FDR[i]))
        fdr_txt <- if (is.na(fdr_i)) "" else sprintf(", FDR=%.2g", fdr_i)
        sprintf("%s (%s%s)", gene_i, logfc_txt, fdr_txt)
      } else {
        sprintf("%s (%s)", gene_i, logfc_txt)
      }
    }, character(1))
    sprintf("Dei %d bersagli attesi, %d sono stati ritrovati fra i geni misurati: %s.",
            n_attesi, n_trovati, paste(dettagli, collapse = "; "))
  }

  n_sig_txt <- if (is.na(n_sig)) "non disponibile" else as.character(as.integer(n_sig))
  i2_txt    <- if (is.na(i2)) "non disponibile" else sprintf("%.1f%%", i2)

  cosa_si_vede <- sprintf(
    "**Cosa si vede.** %s Il gruppo riporta %s geni significativi in totale (FDR<0,05). La concordanza fra studi (I² mediano) e' %s.",
    trovati_txt, n_sig_txt, i2_txt)

  # --- paragrafo 3: limiti di questo gruppo ---------------------------------
  imperfetti_txt <- if (is.null(imperfetti)) {
    "non misurato per questo gruppo"
  } else {
    n_imp    <- imperfetti$n
    tot_imp  <- imperfetti$tot
    peso_imp <- imperfetti$peso
    sprintf(
      "%s confronti imperfetti su %s (%s%% del peso stimato della meta-analisi; vedi docs/findings/2026-08-05-confronti-imperfetti.md)",
      if (is.null(n_imp) || is.na(n_imp)) "?" else as.character(as.integer(n_imp)),
      if (is.null(tot_imp) || is.na(tot_imp)) "?" else as.character(as.integer(tot_imp)),
      if (is.null(peso_imp) || is.na(peso_imp)) "?" else sprintf("%.1f", 100 * peso_imp))
  }

  # `dominato`, quando presente e non-NA, vince sempre sul ricalcolo locale --
  # stesso principio applicato in .summary_card_v2(): una soglia sola, non
  # due che possono divergere in silenzio.
  dominato_flag <- if (!is.na(dom_col)) {
    isTRUE(dom_col)
  } else if (!is.na(quota_top1)) {
    quota_top1 >= 0.5
  } else {
    NA
  }
  dominanza_txt <- if (isTRUE(dominato_flag)) {
    nome_studio <- if (!.na_chr(dominante)) as.character(dominante) else "non identificato"
    peso_txt <- if (!is.na(quota_top1)) sprintf(" (%.1f%% del peso)", 100 * quota_top1) else ""
    sprintf(" Un solo studio (%s) pesa piu' della meta' del gruppo%s.", nome_studio, peso_txt)
  } else {
    ""
  }

  materiale_txt <- if (isTRUE(mat_misto)) {
    " Il materiale e' misto: studi su modello in vitro e su tessuto di paziente insieme."
  } else {
    ""
  }

  limiti <- sprintf("**Limiti di questo gruppo.** %s.%s%s",
                    imperfetti_txt, dominanza_txt, materiale_txt)

  paste(c("> BOZZA — da rivedere", "", contesto, "", cosa_si_vede, "", limiti),
        collapse = "\n")
}
