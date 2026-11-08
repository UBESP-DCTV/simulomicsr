# Stadio 2b (ADR-0028): l'ingresso del modello per un confronto, e il prompt.
#
# L'ingresso e' il testo grezzo dei campioni dei due bracci, dai campi GEO che
# l'H5 di ARCHS4 contiene. Non si taglia nulla: un campo con lo stesso valore in
# tutti i campioni dei due bracci si scrive una volta; uguale dentro un braccio,
# una volta per braccio; diverso dentro un braccio, per campione. Due sole
# trasformazioni: la riparazione della codifica UTF-8 doppia dell'H5 e la
# normalizzazione degli spazi (a capo e spazi multipli -> uno spazio), cosi' le
# citazioni del modello si verificano come sottostringhe.
# Spec: docs/superpowers/specs/2026-11-07-stadio-2b-design.md.

# Campi letti dallo Stadio 2b, nell'ordine di scrittura. Dall'H5 (gruppo
# meta/samples): tutti tranne tre. Da GEO, scaricati e congelati con data e
# SHA-256 perche' l'H5 non li contiene (decisione 1 del PI, 2026-11-08):
# description, treatment_protocol_ch1, growth_protocol_ch1.
.S2B_CAMPI_GEO <- c("description", "treatment_protocol_ch1", "growth_protocol_ch1")
.S2B_CAMPI_INGRESSO <- c("title", "source_name_ch1", "characteristics_ch1",
                         "description", "treatment_protocol_ch1", "growth_protocol_ch1",
                         "extract_protocol_ch1", "data_processing",
                         "molecule_ch1", "library_selection", "library_source",
                         "library_strategy", "instrument_model", "platform_id")

# Contesto del modello nella prova (handout S12p) e token riservati alla risposta.
.S2B_MAX_MODEL_LEN <- 32768L
.S2B_RISERVA_RISPOSTA <- 6144L
.S2B_CARATTERI_PER_TOKEN <- 3

.s2b_norm_spazi <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  trimws(gsub("[[:space:]]+", " ", x))
}

#' Ripara la codifica UTF-8 doppia dell'H5 e normalizza gli spazi
#'
#' L'H5 di ARCHS4 v2.5 contiene parte dei testi GEO codificati due volte
#' (byte UTF-8 letti come Latin-1 e ricodificati: la beta greca o il simbolo dei gradi
#' diventano due caratteri latini;
#' verificato su GEO in S12). La riparazione riporta ogni carattere al suo byte
#' Latin-1 e rilegge i byte come UTF-8; si applica solo se il risultato e'
#' UTF-8 valido e diverso, e si ripete (al massimo tre passi: nell'H5 ci sono
#' anche stringhe codificate tre volte). Un testo gia' corretto con caratteri fuori da
#' Latin-1, o con byte che non formano UTF-8 valido (il simbolo micro, una e
#' accentata scritti bene), resta com'e'.
#' @keywords internal
.s2b_norm_testo <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- enc2utf8(x)
  # alcune stringhe sono codificate tre volte: si ripete finche' non cambia piu'
  for (passo in 1:3) {
    y <- suppressWarnings(iconv(x, from = "UTF-8", to = "latin1"))
    # i byte Latin-1 si rileggono come UTF-8 PRIMA del confronto: due stringhe
    # marcate con codifiche diverse si confrontano per carattere, non per byte
    Encoding(y) <- "UTF-8"
    ok <- !is.na(y) & validUTF8(y)
    ok[ok] <- y[ok] != x[ok]
    if (!any(ok)) break
    x[ok] <- y[ok]
  }
  .s2b_norm_spazi(x)
}

.s2b_etichetta_campo <- function(f) sub("_ch1$", "", f)

#' Stima prudente dei token di un testo (caratteri / 3)
#' @keywords internal
.s2b_stima_token <- function(n_caratteri) {
  as.integer(ceiling(n_caratteri / .S2B_CARATTERI_PER_TOKEN))
}

# Un valore unico (normalizzato) se tutte le righe lo condividono, altrimenti NULL.
.s2b_valore_unico <- function(v) {
  u <- unique(v)
  if (length(u) == 1L) u else NULL
}

.s2b_blocco_braccio <- function(df, sigla, nome, campi, comuni) {
  df <- df[order(df$geo_accession), , drop = FALSE]
  n <- nrow(df)
  out <- sprintf("# %s arm: %d sample%s (%s1-%s%d)", nome, n, if (n == 1L) "" else "s",
                 sigla, sigla, n)
  propri <- setdiff(campi, comuni)
  uguali <- character(); variabili <- character()
  for (f in propri) {
    if (!is.null(.s2b_valore_unico(df[[f]]))) uguali <- c(uguali, f) else variabili <- c(variabili, f)
  }
  righe_uguali <- character()
  for (f in uguali) {
    v <- df[[f]][[1L]]
    if (nzchar(v)) righe_uguali <- c(righe_uguali, sprintf("[%s] %s", .s2b_etichetta_campo(f), v))
  }
  if (length(righe_uguali))
    out <- c(out, sprintf("## Fields identical in every %s sample", tolower(nome)), righe_uguali)
  if (length(variabili)) {
    out <- c(out, "## Sample-specific fields")
    for (i in seq_len(n)) {
      for (f in variabili) {
        v <- df[[f]][[i]]
        out <- c(out, sprintf("%s%d [%s] %s", sigla, i, .s2b_etichetta_campo(f),
                              if (nzchar(v)) v else "(empty)"))
      }
    }
  }
  out
}

#' Costruisce il testo d'ingresso dello Stadio 2b per un confronto
#'
#' @param treated,control data.frame, una riga per campione, con
#'   `geo_accession` (solo per l'ordine: non si scrive) e i campi H5.
#' @param etichetta_trattato,etichetta_controllo etichette dei bracci scritte
#'   dallo Stadio 2.
#' @param entita_proposta nome dell'entita' che la pipeline assegna al
#'   confronto (mai un ID); NA se assente.
#' @param campi campi da scrivere. Ognuno deve esistere in `treated` e in
#'   `control` (valori vuoti ammessi): un campo assente ferma la costruzione,
#'   perche' l'ingresso non deve perdere un campo in silenzio.
#' @return lista: `testo`, `n_caratteri`, `campi_comuni` (campi uguali in tutti
#'   i campioni dei due bracci).
#' @keywords internal
.s2b_costruisci_ingresso <- function(treated, control, etichetta_trattato,
                                     etichetta_controllo, entita_proposta = NA_character_,
                                     campi = .S2B_CAMPI_INGRESSO) {
  assenti <- union(setdiff(campi, names(treated)), setdiff(campi, names(control)))
  if (length(assenti) > 0L) {
    rlang::abort(
      paste0("Stadio 2b: campi d'ingresso assenti dai dati dei bracci: ",
             paste(assenti, collapse = ", ")),
      class = "simulomicsr_stage2b_campi_mancanti"
    )
  }
  for (f in campi) {
    treated[[f]] <- .s2b_norm_testo(treated[[f]])
    control[[f]] <- .s2b_norm_testo(control[[f]])
  }
  ent <- .s2b_norm_spazi(entita_proposta)
  testa <- c(
    "# Comparison under review",
    sprintf("Treated arm label (from the pipeline): %s", .s2b_norm_spazi(etichetta_trattato)),
    sprintf("Control arm label (from the pipeline): %s", .s2b_norm_spazi(etichetta_controllo)),
    sprintf("Proposed entity (from the pipeline): %s", if (nzchar(ent)) ent else "not given")
  )
  comuni <- character(); righe_comuni <- character()
  for (f in campi) {
    u <- .s2b_valore_unico(c(treated[[f]], control[[f]]))
    if (!is.null(u)) {
      comuni <- c(comuni, f)
      if (nzchar(u)) righe_comuni <- c(righe_comuni, sprintf("[%s] %s", .s2b_etichetta_campo(f), u))
    }
  }
  corpo <- c(
    if (length(righe_comuni)) c("", "# Fields identical in every sample of both arms", righe_comuni),
    "", .s2b_blocco_braccio(treated, "T", "TREATED", campi, comuni),
    "", .s2b_blocco_braccio(control, "C", "CONTROL", campi, comuni)
  )
  testo <- paste(c(testa, corpo), collapse = "\n")
  list(testo = testo, n_caratteri = nchar(testo), campi_comuni = comuni)
}

#' Verifica che il testo d'ingresso contenga ogni valore non vuoto di ogni campo
#'
#' Controllo d'integrita' (regola di metodo "lo strumento deve vedere il dato
#' intero"): ogni valore, normalizzato negli spazi, deve comparire per intero.
#' @keywords internal
.s2b_ingresso_contiene_tutto <- function(testo, treated, control,
                                         campi = .S2B_CAMPI_INGRESSO) {
  campi <- intersect(campi, intersect(names(treated), names(control)))
  valori <- unique(unlist(lapply(campi, function(f)
    c(.s2b_norm_testo(treated[[f]]), .s2b_norm_testo(control[[f]])))))
  valori <- valori[nzchar(valori)]
  all(vapply(valori, function(v) grepl(v, testo, fixed = TRUE), logical(1)))
}

#' Il messaggio di sistema dello Stadio 2b (inst/prompts/stage2b-v1.md)
#' @keywords internal
.s2b_prompt_sistema <- function(versione = "v1") {
  p <- system.file(sprintf("prompts/stage2b-%s.md", versione), package = "simulomicsr")
  if (!nzchar(p)) {
    rlang::abort(sprintf("Prompt stage2b-%s.md non trovato", versione),
                 class = "simulomicsr_prompt_missing")
  }
  paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

#' Costruisce il prompt dello Stadio 2b per un confronto
#'
#' @param ingresso risultato di [.s2b_costruisci_ingresso()].
#' @param limite_token token d'ingresso ammessi (contesto meno la riserva per la
#'   risposta). Oltre il limite il confronto non si manda al modello e la regola
#'   lo scarta con INGRESSO_INCOMPLETO: non si taglia mai il testo.
#' @return lista: `messages` (sistema + utente), `schema_path`,
#'   `token_stimati`, `completo` (TRUE se entro il limite).
#' @keywords internal
build_prompt_stage2b <- function(ingresso,
                                 limite_token = .S2B_MAX_MODEL_LEN - .S2B_RISERVA_RISPOSTA,
                                 versione = "v1") {
  schema_path <- system.file("schemas/comparison_check.stage2b.v1.json",
                             package = "simulomicsr")
  if (!nzchar(schema_path)) {
    rlang::abort("Schema comparison_check.stage2b.v1.json non trovato",
                 class = "simulomicsr_schema_missing")
  }
  sistema <- .s2b_prompt_sistema(versione)
  tok <- .s2b_stima_token(nchar(sistema) + nchar(ingresso$testo))
  list(
    messages = list(
      list(role = "system", content = sistema),
      list(role = "user", content = ingresso$testo)
    ),
    schema_path = schema_path,
    token_stimati = tok,
    completo = tok <= limite_token
  )
}
