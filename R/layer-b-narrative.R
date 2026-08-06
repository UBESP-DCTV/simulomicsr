#' Un valore mancante (`NA` o stringa vuota), per i campi testuali del deliverable
#'
#' Helper condiviso: `.summary_card_v2()` (`R/layer-b-summary-card.R`) e
#' `.narrativa_bozza()` (questo file) leggono la STESSA riga del deliverable
#' annotato e devono trattare i valori mancanti con lo stesso criterio.
#' @keywords internal
.lb_na_chr <- function(x) is.na(x) || !nzchar(as.character(x))

#' Soggetto del confronto, con ripiego dichiarato etichetta -> id grezzo -> assente
#'
#' Regola usata da `.summary_card_v2()`: se manca l'etichetta leggibile
#' (`contrast_entity_label`) si ripiega sull'ID grezzo del contrasto
#' (`contrast_entity`), MA DICHIARANDOLO -- mai un ripiego silenzioso. Se
#' manca anche quello, il testo finale e' dichiarato dal chiamante
#' (`non_disponibile`).
#'
#' Il testo prodotto e' in INGLESE: il documento del Layer B e' materiale da
#' articolo, e una scheda mezza italiana e mezza inglese non e' pubblicabile.
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
      "%s (no human-readable label available: falling back to the raw contrast identifier)",
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

#' Clausola sui confronti imperfetti: il conteggio, o la dichiarazione che manca
#'
#' Ritorna solo la CLAUSOLA (senza prefisso di bullet, senza punto finale),
#' in inglese.
#'
#' @section Il numero che NON va pubblicato (correzione 2026-08-06):
#' La versione precedente stampava sempre il peso, anche quando il conteggio
#' confronto-per-confronto non era stato fatto, producendo frasi come
#' *"? confronti imperfetti su ? (100,0% del peso stimato)"*. Quel peso veniva
#' da `peso_citati`, la quota degli studi CITATI nelle motivazioni della
#' rilettura -- una stima che il progetto stesso ha dichiarato cieca
#' (`docs/findings/2026-08-05-confronti-imperfetti.md`, §5.4: mediana 87%,
#' perche' raccoglie anche gli studi citati come *puliti*, e in un gruppo da
#' quattro studi citarne due copre quasi tutto). Pubblicarlo accanto a due
#' punti di domanda dava a un numero inaffidabile l'aspetto di una misura.
#'
#' Regola nuova: **il peso si pubblica solo insieme al conteggio**. Senza
#' conteggio la clausola dichiara che la misura non e' stata fatta per quel
#' gruppo, e il peso non compare affatto.
#'
#' @param confronti_imperfetti list opzionale con `n`, `tot`, `peso`, o `NULL`.
#'   `n`/`tot` sono il conteggio dei confronti difettosi e dei confronti
#'   totali; `peso` e' la quota di peso (0-1) degli studi che li contengono.
#' @return character(1), in inglese.
#' @keywords internal
.lb_confronti_imperfetti_txt <- function(confronti_imperfetti) {
  non_misurato <- paste0(
    "not measured for this group (the comparison-by-comparison count was ",
    "performed only for the groups with at least 15 pooled studies)")

  if (is.null(confronti_imperfetti)) return(non_misurato)

  n_imp    <- confronti_imperfetti$n
  tot_imp  <- confronti_imperfetti$tot
  peso_imp <- confronti_imperfetti$peso

  # Senza conteggio non si pubblica nulla: ne' i punti di domanda ne' il peso.
  if (is.null(n_imp) || is.na(n_imp) || is.null(tot_imp) || is.na(tot_imp)) {
    return(non_misurato)
  }

  peso_txt <- if (is.null(peso_imp) || is.na(peso_imp)) {
    "weight not available"
  } else {
    sprintf("carrying %.1f%% of the pooled weight", 100 * peso_imp)
  }

  sprintf(
    "%d of %d pooled comparisons carry a design defect, %s (upper bound: the whole weight of a study is attributed to the defect)",
    as.integer(n_imp), as.integer(tot_imp), peso_txt)
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
    return("no expected targets were declared for this entity")
  }
  sprintf(
    "none of the %d expected targets was recovered among the measured genes",
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
    " The material is mixed: in vitro models and patient-derived tissue are pooled together."
  } else {
    ""
  }
}


#' La narrativa firmata di un case study, presa da un file scritto a mano
#'
#' Sostituisce `.narrativa_bozza()`, che componeva un testo da un template a
#' partire dalle colonne del deliverable. Quella scelta ha prodotto nove
#' narrative formalmente corrette e scientificamente vuote: nessuna ricerca
#' bibliografica, nessun contesto biologico, e la stessa forma di frase
#' ripetuta nove volte. In un articolo non regge, ed e' stata ritirata
#' (revisione utente 2026-08-06).
#'
#' La narrativa e' ora **testo scientifico firmato**: la scrive una persona (o
#' un lavoro di ricerca verificato e contestato, vedi
#' `analysis/layer-b-narratives/`) e questa funzione si limita a prenderla dal
#' provider e a dichiarare quando non c'e'.
#'
#' Nessun taglio silenzioso: un gruppo senza narrativa NON produce una sezione
#' vuota o una frase generica che sembri scritta apposta -- dichiara che il
#' testo non e' disponibile, cosi' chi legge il documento lo vede e chi
#' verifica il bundle sa dove guardare.
#'
#' @param cluster_id character(1), l'identificativo del gruppo.
#' @param provider function(cluster_id) -> character(1) markdown, oppure
#'   `NULL`. Un provider che ritorna `NULL`, `NA` o stringa vuota per un
#'   gruppo equivale a "narrativa non ancora scritta per questo gruppo".
#'   `provider = NULL` (nessun provider) e' lo stesso caso: dichiarato, non
#'   taciuto.
#'
#' @return list con `disponibile` (`logical(1)`), `md` (`character(1)`, il
#'   markdown da inserire nel documento -- la narrativa vera, oppure la
#'   dichiarazione di assenza) e `motivo` (`character(1)`, `NA` quando la
#'   narrativa c'e').
#' @keywords internal
.narrativa_da_provider <- function(cluster_id, provider = NULL) {
  .assente <- function(motivo) {
    list(
      disponibile = FALSE,
      md = paste0(
        "::: {.callout-note}\n",
        "The narrative for this group is not available in this build.\n",
        ":::"),
      motivo = motivo)
  }

  if (is.null(provider)) {
    return(.assente(sprintf(
      "nessun provider di narrative passato al build (gruppo %s)", cluster_id)))
  }

  md <- tryCatch(provider(cluster_id), error = function(e) {
    structure(NA_character_, errore = conditionMessage(e))
  })

  if (is.null(md) || length(md) == 0L) {
    return(.assente(sprintf("nessuna narrativa fornita per il gruppo %s", cluster_id)))
  }
  md <- as.character(md)[1L]
  if (is.na(md) || !nzchar(trimws(md))) {
    return(.assente(sprintf("narrativa vuota per il gruppo %s", cluster_id)))
  }

  list(disponibile = TRUE, md = md, motivo = NA_character_)
}
