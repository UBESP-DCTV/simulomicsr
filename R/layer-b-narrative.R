#' Un valore mancante (`NA` o stringa vuota), per i campi testuali del deliverable
#'
#' Helper condiviso: `.summary_card_v2()` (`R/layer-b-summary-card.R`) e
#' `.narrativa_bozza()` (questo file) leggono la STESSA riga del deliverable
#' annotato e devono trattare i valori mancanti con lo stesso criterio.
#' @keywords internal
.lb_na_chr <- function(x) is.na(x) || !nzchar(as.character(x))

#' Soggetto del confronto, con ripiego dichiarato etichetta -> id grezzo -> assente
#'
#' Regola condivisa fra `.summary_card_v2()` e `.narrativa_bozza()`: se manca
#' l'etichetta leggibile (`contrast_entity_label`) si ripiega sull'ID grezzo
#' del contrasto (`contrast_entity`), MA DICHIARANDOLO -- mai un ripiego
#' silenzioso. Se manca anche quello, il testo finale e' dichiarato dal
#' chiamante (`non_disponibile`), perche' le due funzioni lo formulano in
#' modo leggermente diverso (la scheda rimanda al blocco PROVENIENZA, la
#' narrativa no).
#'
#' @param etichetta valore di `contrast_entity_label` (puo' essere `NA`).
#' @param entita_id valore di `contrast_entity`, l'ID grezzo (puo' essere `NA`).
#' @param non_disponibile character(1), testo da usare quando mancano
#'   entrambi -- specifico del chiamante.
#' @return character(1).
#' @keywords internal
.lb_soggetto_da_contrasto <- function(etichetta, entita_id, non_disponibile) {
  if (!.lb_na_chr(etichetta)) {
    return(as.character(etichetta))
  }
  if (!.lb_na_chr(entita_id)) {
    return(sprintf(
      "%s (etichetta leggibile non disponibile: ripiego sull'identificativo grezzo del contrasto)",
      as.character(entita_id)))
  }
  non_disponibile
}

#' Testo del verdetto di coerenza, con la stessa logica a tre rami ovunque
#'
#' Regola condivisa: `NA` -> dichiarato non disponibile; `"coherent"` ->
#' affermazione neutra; qualunque altro valore -> segnalato IN MAIUSCOLO con
#' l'avvertenza che i confronti raggruppati potrebbero non misurare lo
#' stesso contrasto. Le FORMULAZIONI restano specifiche del chiamante
#' (passate come template) perche' la scheda e la narrativa incastrano la
#' frase in contesti grammaticali diversi -- e' la REGOLA di dispaccio
#' (quanti rami, quale condizione attiva quale) a dover restare unica.
#'
#' @param verdetto valore di `coherence_verdict` (puo' essere `NA`).
#' @param tmpl_na character(1), testo per verdetto mancante.
#' @param tmpl_coherent character(1), testo per verdetto `"coherent"`.
#' @param tmpl_altro character(1) con un singolo `%s` (il verdetto in
#'   maiuscolo), per qualunque altro valore.
#' @return character(1).
#' @keywords internal
.lb_verdetto_coerenza_txt <- function(verdetto, tmpl_na, tmpl_coherent, tmpl_altro) {
  if (.lb_na_chr(verdetto)) return(tmpl_na)
  if (identical(as.character(verdetto), "coherent")) return(tmpl_coherent)
  sprintf(tmpl_altro, toupper(as.character(verdetto)))
}

#' La colonna `dominato` (gia' calcolata a monte) vince sempre sul ricalcolo locale
#'
#' `compute_pooling_effectiveness(soglia_dominanza)` scrive gia' `dominato`
#' nel deliverable annotato (`R/stage4-deliverable-annotation.R`). Se ogni
#' chiamante ricalcolasse da solo `quota_top1 >= soglia`, un cambio del
#' default a monte potrebbe far divergere in silenzio scheda e narrativa --
#' esattamente il rischio che questa funzione condivisa chiude: una sola
#' implementazione della regola, non due copie che possono disallinearsi.
#'
#' @param dom_col valore della colonna `dominato` (puo' essere `NA`).
#' @param quota_top1 numeric(1), quota di peso dello studio piu' pesante
#'   (puo' essere `NA`).
#' @param soglia_dominanza numeric(1), soglia usata SOLO come ripiego quando
#'   `dom_col` e' `NA`.
#' @return `TRUE`/`FALSE`/`NA`. `NA` quando ne' `dom_col` ne' `quota_top1`
#'   permettono di decidere -- il chiamante deve dichiararlo, non tacerlo.
#' @keywords internal
.lb_dominato_flag <- function(dom_col, quota_top1, soglia_dominanza = 0.5) {
  if (!is.na(dom_col)) {
    isTRUE(dom_col)
  } else if (!is.na(quota_top1)) {
    quota_top1 >= soglia_dominanza
  } else {
    NA
  }
}

#' Clausola sui confronti imperfetti, condivisa fra scheda e narrativa
#'
#' Ritorna solo la CLAUSOLA (senza prefisso di bullet, senza punto finale):
#' i due chiamanti la incastrano in punti diversi della frase (la scheda in
#' un bullet con prefisso `"- **Quanto e' sporco:**"`, la narrativa in un
#' paragrafo prosastico), ma il contenuto -- e il criterio per dichiarare
#' "non misurato" invece di ometterlo -- e' identico.
#'
#' @param confronti_imperfetti list opzionale con `n`, `tot`, `peso`, o `NULL`.
#' @return character(1).
#' @keywords internal
.lb_confronti_imperfetti_txt <- function(confronti_imperfetti) {
  if (is.null(confronti_imperfetti)) {
    return("non misurato per questo gruppo")
  }
  n_imp    <- confronti_imperfetti$n
  tot_imp  <- confronti_imperfetti$tot
  peso_imp <- confronti_imperfetti$peso
  sprintf(
    "%s confronti imperfetti su %s (%s%% del peso stimato della meta-analisi; vedi docs/findings/2026-08-05-confronti-imperfetti.md)",
    if (is.null(n_imp) || is.na(n_imp)) "?" else as.character(as.integer(n_imp)),
    if (is.null(tot_imp) || is.na(tot_imp)) "?" else as.character(as.integer(tot_imp)),
    if (is.null(peso_imp) || is.na(peso_imp)) "?" else sprintf("%.1f", 100 * peso_imp))
}

#' Testo dei bersagli ritrovati, distinguendo "non dichiarati" da "dichiarati ma non trovati"
#'
#' Fix del rilievo C2 della revisione finale (2026-08-06): `.summary_card_v2()`
#' scriveva la STESSA frase ("nessun bersaglio noto ritrovato per questo
#' gruppo") sia quando NESSUNA aspettativa era stata dichiarata dal chiamante,
#' sia quando le aspettative c'erano ma non sono state ritrovate fra i geni
#' misurati -- due affermazioni diverse, a quindici righe di distanza dalla
#' stessa distinzione che `.narrativa_bozza()` gia' faceva (vedi
#' \code{attesi_txt}/\code{trovati_txt} sopra), cosi' la scheda e la
#' narrativa si contraddicevano sulla stessa pagina.
#'
#' @param bersagli_attesi character vector (puo' essere vuoto) dei bersagli
#'   DICHIARATI dal chiamante (vedi \code{bersagli_attesi_provider} di
#'   [build_layer_b_results()]).
#' @param bersagli_trovati_fmt character vector gia' formattato (es. `"SMAD7
#'   +1.41"`) dei bersagli ritrovati fra i geni misurati.
#' @return character(1).
#' @keywords internal
.lb_bersagli_trovati_txt <- function(bersagli_attesi, bersagli_trovati_fmt) {
  # Controllare PRIMA i trovati, non gli attesi: un bersaglio trovato implica
  # per forza che un'aspettativa esisteva, anche quando il chiamante non ha
  # infilato `bersagli_attesi` fino a qui (retrocompatibile con chi passa solo
  # `bersagli_trovati`, come faceva la scheda prima di questo fix).
  if (length(bersagli_trovati_fmt) > 0L) {
    return(paste(bersagli_trovati_fmt, collapse = "; "))
  }
  if (length(bersagli_attesi) == 0L) {
    return("nessun bersaglio dichiarato per questo gruppo (nessuna aspettativa di letteratura fornita)")
  }
  sprintf(
    "nessuno dei %d bersagli attesi e' stato ritrovato fra i geni misurati",
    length(bersagli_attesi))
}

#' Frase sul materiale misto, identica ovunque compaia
#'
#' @param materiale_misto valore della colonna `materiale_misto` (`TRUE`,
#'   `FALSE`, `NA` o mancante).
#' @return character(1): la frase con uno spazio iniziale se `TRUE`,
#'   altrimenti `""` (cosi' il chiamante puo' concatenarla senza controlli).
#' @keywords internal
.lb_materiale_misto_txt <- function(materiale_misto) {
  if (isTRUE(materiale_misto)) {
    " Il materiale e' misto: studi su modello in vitro e su tessuto di paziente insieme."
  } else {
    ""
  }
}

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
#' (etichetta, verdetto, bersagli, confronti imperfetti, peso di un singolo
#' studio) la narrativa lo DICE, non lo omette e non ripiega in silenzio. Le
#' regole condivise con la scheda (ripiego del soggetto, testo del verdetto,
#' precedenza di \code{dominato} sul ricalcolo, clausola sui confronti
#' imperfetti, frase sul materiale misto) vivono in un posto solo -- gli
#' helper \code{.lb_*} sopra in questo file -- cosi' le due non possono
#' divergere in silenzio quando una viene cambiata e l'altra no.
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
#'   vuoto. Se non vuoto deve avere la colonna \code{gene}: e' un contratto
#'   di dati, non un dettaglio opzionale, quindi la sua assenza e' un errore
#'   esplicito e non un crash a valle su \code{vapply}.
#' @param imperfetti list opzionale con \code{n}, \code{tot} (interi) e
#'   \code{peso} (frazione 0-1) dalla rilettura dei confronti poolati (vedi
#'   \code{docs/findings/2026-08-05-confronti-imperfetti.md}). \code{NULL}
#'   (default) se non misurato per questo gruppo -- dichiarato "non
#'   misurato", mai omesso in silenzio.
#' @param soglia_dominanza quota di peso oltre la quale lo studio piu'
#'   pesante viene segnalato come dominante. **Usata SOLO come ripiego**,
#'   quando \code{riga} non porta gia' la colonna \code{dominato} -- stesso
#'   significato e stesso default (0,5) del parametro omonimo di
#'   \code{.summary_card_v2()}.
#'
#' @return \code{character(1)}, markdown con l'intestazione \code{> BOZZA --
#'   da rivedere} seguita da tre paragrafi: **Contesto** (che cosa e' stato
#'   confrontato, su quanti studi, e le attese di letteratura dichiarate),
#'   **Cosa si vede** (quali bersagli attesi sono stati ritrovati e coi
#'   quali valori, piu' il totale dei geni significativi e la concordanza
#'   fra studi), **Limiti di questo gruppo** (confronti imperfetti,
#'   dominanza di un singolo studio -- dichiarata "non disponibile" quando
#'   non e' calcolabile, mai taciuta -- materiale misto).
#' @keywords internal
.narrativa_bozza <- function(riga, bersagli_attesi = character(0),
                             trovati = NULL, imperfetti = NULL,
                             soglia_dominanza = 0.5) {
  riga <- as.data.frame(riga, stringsAsFactors = FALSE)
  if (nrow(riga) == 0L) {
    cli::cli_abort(".narrativa_bozza: {.arg riga} non ha righe.")
  }
  riga <- riga[1L, , drop = FALSE]

  # Accessor tollerante: una colonna assente non e' un errore, e' un dato
  # mancante come un altro -- stesso pattern di .summary_card_v2().
  .v <- function(nm) if (nm %in% names(riga)) riga[[nm]][1L] else NA

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

  # --- soggetto e verdetto: helper condivisi con .summary_card_v2() --------
  soggetto <- .lb_soggetto_da_contrasto(
    etichetta, entita_id,
    non_disponibile = "identita' del contrasto non disponibile")

  k_eff_txt  <- if (is.na(k_eff)) "non disponibile" else as.character(as.integer(k_eff))
  k_kish_txt <- if (is.na(k_kish)) "non disponibile" else sprintf("%.1f", k_kish)

  verdetto_txt <- .lb_verdetto_coerenza_txt(
    verdetto,
    tmpl_na = "il verdetto di coerenza non e' disponibile per questo gruppo",
    tmpl_coherent = "il verdetto di coerenza per questo gruppo e' coerente",
    tmpl_altro = "il VERDETTO DI COERENZA per questo gruppo e' %s -- i confronti raggruppati potrebbero non misurare lo stesso contrasto")

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
  if (n_trovati > 0L && !("gene" %in% names(trovati_df))) {
    # Contratto di dati, non dettaglio opzionale: senza questa guardia
    # `trovati_df$gene` sotto sarebbe NULL e vapply() romperebbe con un
    # errore che non dice nulla sulla causa vera.
    cli::cli_abort(
      ".narrativa_bozza: {.arg trovati} deve avere una colonna {.field gene} quando non e' vuoto.")
  }

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
  imperfetti_txt <- .lb_confronti_imperfetti_txt(imperfetti)

  # `dominato`, quando presente e non-NA, vince sempre sul ricalcolo locale --
  # helper condiviso con .summary_card_v2(), .lb_dominato_flag().
  dominato_flag <- .lb_dominato_flag(dom_col, quota_top1, soglia_dominanza)

  dominanza_txt <- if (isTRUE(dominato_flag)) {
    nome_studio <- if (!.lb_na_chr(dominante)) as.character(dominante) else "non identificato"
    peso_txt <- if (!is.na(quota_top1)) sprintf(" (%.1f%% del peso)", 100 * quota_top1) else ""
    sprintf(" Un solo studio (%s) pesa piu' della meta' del gruppo%s.", nome_studio, peso_txt)
  } else if (is.na(dominato_flag)) {
    # FIX (review): prima questo ramo era assorbito da `else ""`, che
    # confondeva "non calcolabile" con "verificato, nessuno studio domina" --
    # la stessa distinzione che .summary_card_v2() gia' fa (riga2, ramo
    # `is.na(quota_top1)`). Ne' la colonna `dominato` ne' `quota_top1`
    # permettono qui una risposta: va dichiarato, non taciuto.
    " Il peso del singolo studio piu' pesante non e' disponibile."
  } else {
    ""
  }

  materiale_txt <- .lb_materiale_misto_txt(mat_misto)

  limiti <- sprintf("**Limiti di questo gruppo.** %s.%s%s",
                    imperfetti_txt, dominanza_txt, materiale_txt)

  paste(c("> BOZZA — da rivedere", "", contesto, "", cosa_si_vede, "", limiti),
        collapse = "\n")
}
