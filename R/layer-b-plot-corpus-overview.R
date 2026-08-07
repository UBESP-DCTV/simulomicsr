#' Tre pannelli: distribuzione di k_effective, I2_med, n_sig sulle meta-analisi
#'
#' Risponde a colpo d'occhio a "quanto e' grande questa cosa" (spec del
#' ridisegno, §3.2 "Il corpus"): tre istogrammi affiancati (via
#' `patchwork::wrap_plots()`) col tema condiviso [.lb_theme()] e i colori di
#' [.LB_COLORI], uno per ciascuna delle tre colonne che il deliverable
#' annotato porta gia' (`annotate_stage4_deliverable()`). La funzione legge
#' SEMPRE dal data.frame che riceve -- nessun numero e' cablato qui dentro:
#' alla prossima esecuzione i pannelli riflettono il deliverable vero, non
#' una fotografia ricopiata a mano.
#'
#' L'asse dei geni significativi e' in scala log10 (dichiarato nel titolo del
#' pannello e nella didascalia, non un taglio silenzioso): la distribuzione e'
#' fortemente asimmetrica (da zero a centinaia di migliaia) e su scala lineare
#' schiaccerebbe quasi tutti i gruppi in una singola barra.
#'
#' @param deliverable_annotato data.frame/tibble, una riga per meta-analisi,
#'   con almeno le colonne `k_effective`, `I2_med`, `n_sig` (schema di
#'   `annotate_stage4_deliverable()`). Le righe con `NA` in una colonna sono
#'   escluse dal solo pannello di quella colonna (comportamento standard di
#'   `ggplot2::geom_histogram()`, che avvisa e non fa crashare).
#' @param out_dir character path dove salvare `corpus_overview.png` (+
#'   `corpus_overview.svg` se `config$save_svg`).
#' @param config list (vedi [layer_b_default_config()]).
#'
#' @return list con `png_path`, `svg_path` (`NA_character_` se
#'   `config$save_svg` e' `FALSE`), `caption`, `n_gruppi`.
#' @keywords internal
.build_corpus_overview <- function(deliverable_annotato, out_dir, config) {
  richieste <- c("k_effective", "I2_med", "n_sig")
  mancanti <- setdiff(richieste, names(deliverable_annotato))
  if (length(mancanti) > 0L) {
    cli::cli_abort(
      ".build_corpus_overview: mancano le colonne {.field {mancanti}} nel deliverable annotato.")
  }

  d <- deliverable_annotato
  n_gruppi <- nrow(d)

  p_k <- ggplot2::ggplot(d, ggplot2::aes(x = k_effective)) +
    ggplot2::geom_histogram(fill = .LB_COLORI$evidenza, bins = 30, na.rm = TRUE) +
    ggplot2::labs(title = "Pooled studies", x = "studies per meta-analysis",
                  y = "meta-analyses") +
    .lb_theme(base_size = 10)

  p_i2 <- ggplot2::ggplot(d, ggplot2::aes(x = I2_med)) +
    ggplot2::geom_histogram(fill = .LB_COLORI$su, bins = 30, na.rm = TRUE) +
    ggplot2::labs(title = "Heterogeneity (median I-squared)", x = "I-squared (%)", y = NULL) +
    .lb_theme(base_size = 10)

  p_sig <- ggplot2::ggplot(d, ggplot2::aes(x = pmax(n_sig, 1))) +
    ggplot2::geom_histogram(fill = .LB_COLORI$giu, bins = 30, na.rm = TRUE) +
    ggplot2::scale_x_log10() +
    ggplot2::labs(title = "Significant genes", x = "genes (log10 scale)", y = NULL) +
    .lb_theme(base_size = 10)

  p <- patchwork::wrap_plots(p_k, p_i2, p_sig, ncol = 3L) +
    patchwork::plot_annotation(
      title = sprintf("%d pooled meta-analyses", n_gruppi))

  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  png_path <- file.path(out_dir, "corpus_overview.png")
  svg_path <- file.path(out_dir, "corpus_overview.svg")

  ggplot2::ggsave(png_path, p, width = 10, height = 3.6, dpi = config$dpi)
  if (isTRUE(config$save_svg)) {
    ggplot2::ggsave(svg_path, p, width = 10, height = 3.6, device = "svg")
  } else {
    svg_path <- NA_character_
  }

  caption <- sprintf(
    paste0("Distribution of the number of pooled studies, median I-squared ",
           "and number of significant genes (FDR < %g) across the %d ",
           "meta-analyses. The gene axis is on a log10 scale because the ",
           "distribution spans four orders of magnitude; on a linear scale ",
           "almost every meta-analysis would fall into a single bar."),
    config$fdr_threshold %||% 0.05, n_gruppi)

  list(png_path = png_path, svg_path = svg_path, caption = caption, n_gruppi = n_gruppi)
}

#' "Il corpus" letto dal bundle: la figura se il deliverable annotato e'
#' raggiungibile, altrimenti il perche' non lo e'
#'
#' Punto di ingresso usato dal template Quarto (`inst/templates/layer-b-report.qmd`).
#' Il deliverable annotato (`deliverable-annotato.rds`) NON e' copiato dentro
#' il bundle Layer B -- vive nella directory dello Stadio 4 -- ma il suo path
#' e' registrato in `run_metadata.json$input_files$deliverable_annotato`
#' (collegato al build dal Task 7bis). Questa funzione lo rilegge AL MOMENTO
#' DEL RENDER: se il file e' li' e ha le colonne giuste, produce la figura a
#' tre pannelli con [.build_corpus_overview()]; altrimenti dichiara il motivo
#' invece di lasciare un buco silenzioso o far fallire il render.
#'
#' Nessun taglio silenzioso: OGNI ramo che porta a `disponibile = FALSE` mette
#' una frase in `motivo` -- chiave assente da `run_metadata` (bundle
#' costruito prima del Task 7bis), file non trovato (spostato, disco esterno
#' non montato, mai stato disponibile al build), file illeggibile, o colonne
#' mancanti.
#'
#' @param lb oggetto `layer_b_result` (output di [load_layer_b()]).
#' @param out_dir character path dove scrivere `corpus_overview.png`/`.svg`
#'   quando la figura viene generata. Default `lb$dir` (la cartella del
#'   bundle: stessa convenzione dei path relativi usata dal template per le
#'   immagini per-cluster).
#'
#' @return list con `disponibile` (`logical(1)`) e, quando `TRUE`, `plot`
#'   (l'output di [.build_corpus_overview()]); quando `FALSE`, `motivo`
#'   (`character(1)`) e `plot = NULL`.
#' @keywords internal
.corpus_overview_from_bundle <- function(lb, out_dir = lb$dir) {
  .assente <- function(motivo) list(disponibile = FALSE, motivo = motivo, plot = NULL)

  info <- lb$run_metadata$input_files$deliverable_annotato
  path <- if (!is.null(info)) info$path else NULL
  if (is.null(path) || length(path) == 0L || is.na(path) || !nzchar(path)) {
    return(.assente(paste(
      "il run_metadata di questo bundle non registra un deliverable",
      "annotato (bundle costruito prima del collegamento scheda/narrativa)."
    )))
  }
  path <- as.character(path)[1L]

  if (!file.exists(path)) {
    motivo <- if (!isTRUE(info$disponibile)) {
      mot <- info$motivo_assenza
      if (is.null(mot) || length(mot) == 0L || is.na(mot) || !nzchar(mot)) {
        sprintf("il deliverable annotato non era disponibile al momento del build (%s).", path)
      } else {
        as.character(mot)[1L]
      }
    } else {
      sprintf(
        paste0("il file %s non e' raggiungibile da questo render (era disponibile ",
               "al momento del build, ma potrebbe essere stato spostato o vivere ",
               "su un disco non montato in questo ambiente)."),
        path)
    }
    return(.assente(motivo))
  }

  d <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(d) || !is.data.frame(d) || nrow(d) == 0L) {
    return(.assente(sprintf(
      "il file %s esiste ma non contiene un data.frame con righe leggibili.", path)))
  }

  richieste <- c("k_effective", "I2_med", "n_sig")
  mancanti <- setdiff(richieste, names(d))
  if (length(mancanti) > 0L) {
    return(.assente(sprintf(
      "il file %s non ha le colonne %s.", path, paste(mancanti, collapse = ", "))))
  }

  config <- lb$run_metadata$config
  if (is.null(config)) config <- layer_b_default_config()
  plot <- .build_corpus_overview(d, out_dir = out_dir, config = config)

  # Le tabelle aggregate viaggiano con la figura: se il deliverable e'
  # raggiungibile per l'una lo e' anche per le altre, e tenerle in due punti
  # diversi vorrebbe dire due letture dello stesso file che potrebbero
  # divergere. Le colonne facoltative mancanti non fanno fallire nulla:
  # .corpus_tabelle() ritorna NA e il documento lo dichiara.
  tabelle <- tryCatch(.corpus_tabelle(d), error = function(e) NULL)

  list(disponibile = TRUE, plot = plot, tabelle = tabelle, motivo = NA_character_)
}

#' Tipo di entita' dedotto dal prefisso dell'identificativo del contrasto
#'
#' Gli identificativi del contrasto portano gia' l'ontologia di provenienza nel
#' prefisso (`CHEBI:`, `HGNC:`, `NCBITaxon:`, `MeSH:`), quindi il tipo non va
#' inventato ne' mantenuto in una tabella a parte che potrebbe divergere: si
#' legge dal dato. `STR:` e tutto il resto sono identificativi non risolti a
#' un'ontologia, e vanno dichiarati come tali invece di essere silenziosamente
#' assegnati a una categoria.
#'
#' @param entita character vector di identificativi (`contrast_entity`).
#' @return character vector della stessa lunghezza, in inglese.
#' @keywords internal
.corpus_tipo_entita <- function(entita) {
  e <- as.character(entita)
  out <- rep("Unresolved identifier", length(e))
  out[grepl("^CHEBI:", e)]       <- "Small molecule"
  out[grepl("^HGNC:", e)]        <- "Protein or gene product"
  out[grepl("^NCBITaxon:", e)]   <- "Pathogen"
  out[grepl("^MeSH:", e)]        <- "Disease or condition"
  out[is.na(e)]                  <- "Unresolved identifier"
  out
}

#' Le tabelle aggregate sul corpus completo, calcolate dal deliverable
#'
#' Sezione conclusiva del documento (richiesta utente 2026-08-06, punto 8):
#' dopo i case study, che cosa c'e' nel resto delle meta-analisi. Ogni cifra e'
#' CALCOLATA dal data.frame ricevuto -- nessun numero e' cablato qui dentro,
#' cosi' un documento rigenerato riflette sempre il deliverable vero e non una
#' fotografia ricopiata a mano (e' l'errore gia' pagato con le note della
#' selezione, che portavano numeri di un run precedente scritti a mano).
#'
#' Le colonne facoltative (`dominato`, `k_kish`, `materiale_misto`,
#' `coherence_verdict`) sono trattate come possono mancare: il conteggio
#' corrispondente esce `NA` e chi scrive il documento lo dichiara, invece di
#' stampare uno zero indistinguibile da "misurato, nessuno".
#'
#' @param deliverable_annotato data.frame, una riga per meta-analisi. Servono
#'   almeno `contrast_entity`, `contrast_entity_label`, `k_effective`,
#'   `I2_med`, `n_sig`.
#' @param top_n numero di righe della tabella delle meta-analisi con piu'
#'   studi poolati. Default 15.
#'
#' @return list con `n_gruppi`, `composizione` (data.frame per tipo di
#'   entita'), `potenza` (data.frame per fascia di k), `piu_potenti`
#'   (data.frame delle `top_n` con piu' studi), `incoerenti` (data.frame delle
#'   marcate incoerenti, 0 righe se nessuna), e i conteggi `n_dominati`,
#'   `n_sotto_due_efficaci`, `n_incoerenti`, `n_materiale_misto`,
#'   `mediana_k`, `mediana_i2`, `totale_geni_sig`.
#' @keywords internal
.corpus_tabelle <- function(deliverable_annotato, top_n = 15L) {
  d <- as.data.frame(deliverable_annotato, stringsAsFactors = FALSE)
  richieste <- c("contrast_entity", "contrast_entity_label", "k_effective",
                 "I2_med", "n_sig")
  mancanti <- setdiff(richieste, names(d))
  if (length(mancanti) > 0L) {
    cli::cli_abort(".corpus_tabelle: mancano le colonne {.field {mancanti}}.")
  }

  .col <- function(nm) if (nm %in% names(d)) d[[nm]] else NULL

  n_gruppi <- nrow(d)
  tipo <- .corpus_tipo_entita(d$contrast_entity)

  # L'etichetta pubblicata riapplica l'override canonico
  # (inst/extdata/entity-label-overrides.csv) invece di fidarsi di quella
  # materializzata nel deliverable: una correzione a quel file arriva nel
  # documento senza dover ri-poolare 214 meta-analisi. E' il caso di
  # `CHEBI:59132`, che nel deliverable v15 porta ancora un'etichetta scritta
  # in italiano ("antigen (classe-ombrello)") e finiva stampata cosi' nella
  # tabella delle incoerenti. Quando l'override non c'e', si tiene
  # l'etichetta del deliverable.
  etichetta <- .corpus_etichetta_pubblicata(d$contrast_entity,
                                            d$contrast_entity_label)

  # --- composizione per tipo di entita' ---------------------------------------
  spl <- split(seq_len(n_gruppi), factor(tipo, levels = unique(tipo)))
  composizione <- data.frame(
    `Entity type`             = names(spl),
    `Meta-analyses`           = vapply(spl, length, integer(1)),
    `Median pooled studies`   = vapply(spl, function(i) stats::median(d$k_effective[i], na.rm = TRUE), numeric(1)),
    `Median significant genes`= vapply(spl, function(i) stats::median(d$n_sig[i], na.rm = TRUE), numeric(1)),
    check.names = FALSE, stringsAsFactors = FALSE, row.names = NULL)
  composizione <- composizione[order(-composizione$`Meta-analyses`), , drop = FALSE]

  # --- potenza per fascia di studi poolati -------------------------------------
  fascia <- cut(d$k_effective, breaks = c(-Inf, 4, 9, 14, Inf),
                labels = c("3-4 studies", "5-9 studies", "10-14 studies",
                           "15 or more studies"))
  k_kish <- .col("k_kish")
  dominato <- .col("dominato")
  spl2 <- split(seq_len(n_gruppi), fascia)
  potenza <- data.frame(
    `Pooled studies`   = names(spl2),
    `Meta-analyses`    = vapply(spl2, length, integer(1)),
    `Median effective studies (Kish)` = if (is.null(k_kish)) {
      rep(NA_real_, length(spl2))
    } else {
      vapply(spl2, function(i) stats::median(k_kish[i], na.rm = TRUE), numeric(1))
    },
    `Dominated by one study` = if (is.null(dominato)) {
      rep(NA_integer_, length(spl2))
    } else {
      vapply(spl2, function(i) sum(.isTRUE_vec(dominato[i])), integer(1))
    },
    `Median I-squared (%)` = vapply(spl2, function(i) stats::median(d$I2_med[i], na.rm = TRUE), numeric(1)),
    check.names = FALSE, stringsAsFactors = FALSE, row.names = NULL)

  # --- le meta-analisi con piu' studi poolati ---------------------------------
  ord <- order(-d$k_effective)
  top <- utils::head(ord, top_n)
  piu_potenti <- data.frame(
    `Contrast`            = etichetta[top],
    `Type`                = tipo[top],
    `Pooled studies`      = as.integer(d$k_effective[top]),
    `Effective studies (Kish)` = if (is.null(k_kish)) NA_real_ else round(k_kish[top], 1),
    `Significant genes`   = as.integer(d$n_sig[top]),
    `Median I-squared (%)`= round(d$I2_med[top], 1),
    check.names = FALSE, stringsAsFactors = FALSE, row.names = NULL)

  # --- le marcate incoerenti ---------------------------------------------------
  # La colonna `coherence_reason` del deliverable e' il VERBALE della lettura
  # umana: italiano, lungo, e in un caso cita per esteso la decisione presa da
  # una persona in una certa data. E' la fonte giusta per chi verifica e la
  # fonte sbagliata per un documento da articolo. La riga pubblicata viene da
  # una traduzione editoriale breve (`inst/extdata/coherence-reason-en.csv`),
  # tenuta separata dal dato perche' e' testo, non misura.
  #
  # Nessun ripiego silenzioso: un gruppo senza traduzione NON stampa il verbale
  # italiano, dichiara che la motivazione non e' disponibile in inglese.
  verdetto <- .col("coherence_verdict")
  incoerenti <- if (is.null(verdetto)) {
    data.frame(Contrast = character(0), `Pooled studies` = integer(0),
               Reason = character(0), check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    idx <- which(!is.na(verdetto) & verdetto != "coherent")
    data.frame(
      Contrast         = etichetta[idx],
      `Pooled studies` = as.integer(d$k_effective[idx]),
      Reason           = .corpus_motivo_en(d$cluster_id[idx]),
      check.names = FALSE, stringsAsFactors = FALSE, row.names = NULL)
  }

  mat_misto <- .col("materiale_misto")

  list(
    n_gruppi             = n_gruppi,
    composizione         = composizione,
    potenza              = potenza,
    piu_potenti          = piu_potenti,
    incoerenti           = incoerenti,
    n_dominati           = if (is.null(dominato)) NA_integer_ else sum(.isTRUE_vec(dominato)),
    n_sotto_due_efficaci = if (is.null(k_kish)) NA_integer_ else sum(k_kish < 2, na.rm = TRUE),
    n_incoerenti         = if (is.null(verdetto)) NA_integer_ else sum(!is.na(verdetto) & verdetto != "coherent"),
    n_materiale_misto    = if (is.null(mat_misto)) NA_integer_ else sum(.isTRUE_vec(mat_misto)),
    mediana_k            = stats::median(d$k_effective, na.rm = TRUE),
    mediana_i2           = stats::median(d$I2_med, na.rm = TRUE),
    totale_geni_sig      = sum(d$n_sig, na.rm = TRUE)
  )
}

#' `isTRUE()` vettorizzato: `NA` non e' `TRUE`
#'
#' `isTRUE()` accetta un solo valore; `x == TRUE` propaga gli `NA`. Serve la
#' terza cosa: un vettore logico dove `NA` conta come "non lo sappiamo",
#' cioe' non `TRUE`.
#' @keywords internal
.isTRUE_vec <- function(x) !is.na(x) & as.logical(x)

#' Motivazione dell'incoerenza, in inglese e breve, per la tabella pubblicata
#'
#' La colonna `coherence_reason` del deliverable annotato e' il verbale della
#' lettura umana che ha marcato il gruppo: in italiano, lunga, e in un caso con
#' dentro la data e l'autore della decisione. Serve a chi verifica, non a chi
#' legge il documento.
#'
#' Questa funzione restituisce invece la frase pubblicabile, presa da
#' `inst/extdata/coherence-reason-en.csv` -- una tabella EDITORIALE (testo
#' scritto e riletto, non una misura), tenuta fuori dal codice per la stessa
#' ragione per cui le narrative stanno in file loro: un testo scientifico si
#' rilegge e si firma, non si nasconde dentro una funzione.
#'
#' Nessun ripiego silenzioso: se un gruppo non ha una traduzione, la tabella
#' non stampa il verbale italiano -- dichiara che la motivazione non e'
#' disponibile in inglese, cosi' chi rilegge il documento vede che manca.
#'
#' @param cluster_id character vector di identificativi di gruppo.
#' @return character vector della stessa lunghezza.
#' @keywords internal
.corpus_motivo_en <- function(cluster_id) {
  path <- system.file("extdata", "coherence-reason-en.csv", package = "simulomicsr")
  non_disp <- "reason not available in English for this group"
  if (!nzchar(path) || !file.exists(path)) {
    return(rep(non_disp, length(cluster_id)))
  }
  tab <- utils::read.csv(path, stringsAsFactors = FALSE)
  i <- match(as.character(cluster_id), tab$cluster_id)
  out <- tab$reason_en[i]
  out[is.na(out) | !nzchar(out)] <- non_disp
  out
}

#' L'etichetta leggibile pubblicata, dall'override canonico se c'e'
#'
#' `contrast_entity_label` nel deliverable e' una fotografia dell'override
#' (`inst/extdata/entity-label-overrides.csv`) al momento in cui il pooling e'
#' stato eseguito. Correggere una etichetta in quel file, dopo, non basterebbe
#' a correggerla nel documento: servirebbe un re-pool di 214 meta-analisi per
#' un problema di testo. Qui l'override viene riapplicato al momento della
#' pubblicazione.
#'
#' Nessun ripiego silenzioso in nessuno dei due sensi: se l'entita' non e'
#' nell'override, si tiene l'etichetta del deliverable; se manca anche quella,
#' si tiene l'identificativo grezzo, che e' informazione e non un buco.
#'
#' @param entita character vector di `contrast_entity`.
#' @param etichetta character vector di `contrast_entity_label`, stessa lunghezza.
#' @return character vector della stessa lunghezza.
#' @keywords internal
.corpus_etichetta_pubblicata <- function(entita, etichetta) {
  out <- as.character(etichetta)
  vuota <- is.na(out) | !nzchar(out)
  out[vuota] <- as.character(entita)[vuota]

  path <- system.file("extdata", "entity-label-overrides.csv", package = "simulomicsr")
  if (!nzchar(path) || !file.exists(path)) return(out)
  ov <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!all(c("contrast_entity", "label") %in% names(ov))) return(out)
  i <- match(as.character(entita), ov$contrast_entity)
  ha <- !is.na(i) & !is.na(ov$label[i]) & nzchar(ov$label[i])
  out[ha] <- ov$label[i][ha]
  out
}
