# Stadio 2b (ADR-0028): la regola deterministica che decide se un confronto
# passa, dalla lista di controllo compilata dal modello
# (schema inst/schemas/comparison_check.stage2b.v1.json) e dal confronto dei
# campi tecnici strutturati dell'H5. Il modello riporta i fatti; il verdetto lo
# da' questa regola. Spec: docs/superpowers/specs/2026-11-07-stadio-2b-design.md.
#
# Due passi separati:
#   1. .s2b_segnali()          -> i segnali (codici) che la lista di controllo accende;
#   2. stage2b_esiti_default() -> per ogni segnale, «errore» (il confronto non
#      passa) o «avviso» (passa, il segnale si conta). La decisione del PI su che
#      cosa e' errore cambia solo questa tabella.

# Codici degli assi, nell'ordine dello schema.
.S2B_ASSI <- c(
  material = "MATERIALE",
  cell_line = "LINEA",
  donor = "DONATORE",
  genotype = "GENOTIPO",
  sex = "SESSO",
  age_or_stage = "ETA_STADIO",
  anatomical_site = "SEDE",
  compartment = "COMPARTIMENTO",
  disease_or_condition = "CONDIZIONE",
  culture_conditions = "COLTURA",
  technique = "TECNICA"
)

# Assi dei soggetti: la sovrapposizione parziale fra i bracci e' naturale
# (popolazioni di donatori), quindi parziale = avviso. Sugli altri assi un
# braccio parziale mescola condizioni dell'esperimento: errore.
.S2B_ASSI_SOGGETTO <- c("donor", "sex", "age_or_stage")

# Campi strutturati dell'H5 confrontati senza modello (decisione del PI in S11:
# la differenza tecnica fra i bracci e' sempre un errore).
.S2B_CAMPI_TECNICI_H5 <- c("instrument_model", "platform_id", "library_selection",
                           "library_source", "library_strategy", "molecule_ch1")

.S2B_REL <- c("same", "different", "partial", "not_stated", "not_applicable")
.S2B_PRESENZA <- c("all", "some", "none", "not_stated")
.S2B_KIND <- c("chemical", "biologic", "genetic", "infection", "physical",
               "vehicle_or_mock", "other")
.S2B_MATCH <- c("yes", "no", "unclear", "not_given")

#' Tutti i segnali che la regola dello Stadio 2b puo' accendere
#' @keywords internal
.s2b_tutti_i_segnali <- function() {
  ax <- unname(.S2B_ASSI)
  c("INGRESSO_INCOMPLETO", "LISTA_NON_VALIDA",
    "TEMPO_ZERO", "TEMPO_DIVERSO", "TEMPO_NON_DETTO", "TEMPI_MULTIPLI",
    "SECONDO_AGENTE", "AGENTE_NON_DETTO_CONTROLLO", "AGENTE_SOLO_CONTROLLO",
    "BRACCIO_MISTO", "NESSUNA_DIFFERENZA",
    "ENTITA_DIVERSA", "ENTITA_INCERTA", "INCOERENZA_ENTITA",
    "CONDIZIONE_CON_AGENTE", "PARZIALE_CONDIZIONE", "DONATORI_DIVERSI_CONDIZIONE",
    paste0("DIVERSO_", setdiff(ax, "CONDIZIONE")),
    paste0("PARZIALE_", setdiff(ax, "CONDIZIONE")),
    paste0("NON_DETTO_", ax),
    "TECNICA_H5_DISGIUNTA", "TECNICA_H5_PARZIALE",
    "ALTRA_DIFFERENZA")
}

#' Esito di ciascun segnale dello Stadio 2b: errore o avviso
#'
#' Proposta di S12 (2026-11-07), decisa dal PI il 2026-11-08 senza cambi:
#' donatori diversi nei confronti malati contro sani = avviso (sesso o eta'
#' senza valori in comune restano errore); non detto e casi incerti = avviso
#' (ADR-0028); la voce aperta "altre differenze" = errore. Tempo zero e
#' differenza tecnica, anche in un solo campione, sono sempre errore
#' (decisione del PI in S11).
#'
#' @return vettore nominato: nome = segnale, valore = "errore" o "avviso".
#' @keywords internal
stage2b_esiti_default <- function() {
  tutti <- .s2b_tutti_i_segnali()
  avviso <- c("TEMPO_NON_DETTO", "TEMPI_MULTIPLI", "AGENTE_NON_DETTO_CONTROLLO",
              "ENTITA_INCERTA", "INCOERENZA_ENTITA", "DONATORI_DIVERSI_CONDIZIONE",
              paste0("PARZIALE_", .S2B_ASSI[.S2B_ASSI_SOGGETTO]),
              grep("^NON_DETTO_", tutti, value = TRUE))
  stats::setNames(ifelse(tutti %in% avviso, "avviso", "errore"), tutti)
}

# Primo elemento come stringa; NA se assente (gli scalari JSON possono arrivare
# come liste di un elemento: CLAUDE.md §4).
.s2b_chr <- function(x) {
  x <- unlist(x, use.names = FALSE)
  if (length(x) == 0L) NA_character_ else as.character(x[[1L]])
}

.s2b_ore <- function(x) {
  h <- suppressWarnings(as.numeric(unlist(x, use.names = FALSE)))
  sort(unique(round(h[!is.na(h)], 3)))
}

# Controllo strutturale minimo: le voci che la regola legge esistono e hanno
# valori dello schema. La validazione completa dello schema la fa il chiamante.
.s2b_lista_valida <- function(ck) {
  if (!is.list(ck)) return(FALSE)
  need <- c("agents", "collection_time", "axes", "other_differences",
            "proposed_entity")
  if (!all(need %in% names(ck))) return(FALSE)
  if (!all(names(.S2B_ASSI) %in% names(ck$axes))) return(FALSE)
  rel <- vapply(names(.S2B_ASSI), function(a) .s2b_chr(ck$axes[[a]]$relation),
                character(1))
  if (!all(rel %in% .S2B_REL)) return(FALSE)
  for (ag in ck$agents) {
    if (!.s2b_chr(ag$kind) %in% .S2B_KIND) return(FALSE)
    if (!.s2b_chr(ag$in_treated) %in% .S2B_PRESENZA) return(FALSE)
    if (!.s2b_chr(ag$in_control) %in% .S2B_PRESENZA) return(FALSE)
    if (!.s2b_chr(ag$is_proposed_entity) %in% .S2B_MATCH) return(FALSE)
  }
  ct <- ck$collection_time
  if (!all(c("treated", "control", "relation") %in% names(ct))) return(FALSE)
  if (!.s2b_chr(ct$relation) %in% c("same", "different", "partial", "not_stated"))
    return(FALSE)
  for (b in c("treated", "control"))
    if (!.s2b_chr(ct[[b]]$time_zero) %in% .S2B_PRESENZA) return(FALSE)
  if (!.s2b_chr(ck$proposed_entity$match) %in% .S2B_MATCH) return(FALSE)
  TRUE
}

#' Confronta i campi tecnici strutturati dell'H5 fra i due bracci
#'
#' Per ogni campo: "uguale" (stesso insieme di valori), "parziale" (valori in
#' comune ma insiemi diversi), "disgiunta" (nessun valore in comune), "vuota"
#' (un braccio senza valori). Le stringhe vuote non sono valori.
#'
#' @param treated,control data.frame con una riga per campione e i campi H5.
#' @param campi campi da confrontare (default: quelli tecnici).
#' @return vettore nominato di esiti, uno per campo presente in entrambi.
#' @keywords internal
.s2b_tecnica_h5 <- function(treated, control, campi = .S2B_CAMPI_TECNICI_H5) {
  campi <- intersect(campi, intersect(names(treated), names(control)))
  out <- vapply(campi, function(f) {
    vt <- unique(trimws(as.character(treated[[f]])))
    vc <- unique(trimws(as.character(control[[f]])))
    vt <- vt[!is.na(vt) & nzchar(vt)]
    vc <- vc[!is.na(vc) & nzchar(vc)]
    if (length(vt) == 0L || length(vc) == 0L) return("vuota")
    if (setequal(vt, vc)) return("uguale")
    if (length(intersect(vt, vc)) == 0L) return("disgiunta")
    "parziale"
  }, character(1))
  stats::setNames(out, campi)
}

#' I segnali che una lista di controllo dello Stadio 2b accende
#'
#' @param ck lista di controllo (lista R dal JSON, schema stage2b.v1), o NULL.
#' @param tecnica_h5 esito di [.s2b_tecnica_h5()] per il confronto, o NULL.
#' @param ingresso_completo FALSE se l'ingresso del confronto non e' stato
#'   costruito per intero (oltre il limite di token).
#' @return vettore di codici, senza ripetizioni, nell'ordine di
#'   [.s2b_tutti_i_segnali()].
#' @keywords internal
.s2b_segnali <- function(ck, tecnica_h5 = NULL, ingresso_completo = TRUE) {
  if (!isTRUE(ingresso_completo)) return("INGRESSO_INCOMPLETO")
  if (!.s2b_lista_valida(ck)) return("LISTA_NON_VALIDA")
  s <- character()

  # ---- agenti ----
  ag <- ck$agents
  kind <- vapply(ag, function(a) .s2b_chr(a$kind), character(1))
  it <- vapply(ag, function(a) .s2b_chr(a$in_treated), character(1))
  ic <- vapply(ag, function(a) .s2b_chr(a$in_control), character(1))
  ent <- vapply(ag, function(a) .s2b_chr(a$is_proposed_entity), character(1))
  nv <- kind != "vehicle_or_mock"
  solo_t <- nv & it == "all" & ic == "none"                     # differenza certa
  solo_t_debole <- nv & it == "all" & ic %in% c("none", "not_stated")
  match <- .s2b_chr(ck$proposed_entity$match)

  if (sum(solo_t) >= 2L &&
      (match == "not_given" || any(ent[solo_t] != "yes"))) s <- c(s, "SECONDO_AGENTE")
  if (sum(solo_t_debole) >= 2L &&
      any(it == "all" & ic == "not_stated" & nv & ent != "yes"))
    s <- c(s, "AGENTE_NON_DETTO_CONTROLLO")
  if (any(nv & it == "none" & ic %in% c("all", "some"))) s <- c(s, "AGENTE_SOLO_CONTROLLO")
  if (any(nv & (it == "some" | ic == "some"))) s <- c(s, "BRACCIO_MISTO")

  # ---- che cosa distingue i bracci: un agente o la condizione d'origine ----
  cond <- .s2b_chr(ck$axes$disease_or_condition$relation)
  differenza <- if (any(solo_t_debole)) "agente" else if (cond == "different") "condizione" else NA_character_
  if (is.na(differenza)) s <- c(s, "NESSUNA_DIFFERENZA")

  if (match == "no") s <- c(s, "ENTITA_DIVERSA")
  if (match == "unclear") s <- c(s, "ENTITA_INCERTA")
  if (identical(differenza, "agente") && match == "yes" && !any(ent[solo_t_debole] == "yes"))
    s <- c(s, "INCOERENZA_ENTITA")

  # ---- tempo di raccolta ----
  ct <- ck$collection_time
  tz_t <- .s2b_chr(ct$treated$time_zero); tz_c <- .s2b_chr(ct$control$time_zero)
  h_t <- .s2b_ore(ct$treated$hours); h_c <- .s2b_ore(ct$control$hours)
  rel_t <- .s2b_chr(ct$relation)
  if (tz_c %in% c("all", "some") && tz_t != "all") s <- c(s, "TEMPO_ZERO")
  if ((length(h_t) > 0L && length(h_c) > 0L && !setequal(h_t, h_c)) ||
      rel_t %in% c("different", "partial") ||
      (tz_t %in% c("all", "some") && tz_c == "none")) s <- c(s, "TEMPO_DIVERSO")
  if ((length(h_t) == 0L && tz_t == "not_stated") ||
      (length(h_c) == 0L && tz_c == "not_stated")) s <- c(s, "TEMPO_NON_DETTO")
  if (length(h_t) > 1L && setequal(h_t, h_c)) s <- c(s, "TEMPI_MULTIPLI")

  # ---- assi ----
  for (a in names(.S2B_ASSI)) {
    cod <- .S2B_ASSI[[a]]
    rel <- .s2b_chr(ck$axes[[a]]$relation)
    if (a == "disease_or_condition") {
      if (rel == "different" && identical(differenza, "agente")) s <- c(s, "CONDIZIONE_CON_AGENTE")
      if (rel == "partial") s <- c(s, "PARZIALE_CONDIZIONE")
    } else if (rel == "different") {
      s <- c(s, if (a == "donor" && identical(differenza, "condizione"))
        "DONATORI_DIVERSI_CONDIZIONE" else paste0("DIVERSO_", cod))
    } else if (rel == "partial") {
      s <- c(s, paste0("PARZIALE_", cod))
    }
    if (rel == "not_stated") s <- c(s, paste0("NON_DETTO_", cod))
  }

  # ---- tecnica dai campi strutturati dell'H5 ----
  if (!is.null(tecnica_h5)) {
    if (any(tecnica_h5 == "disgiunta")) s <- c(s, "TECNICA_H5_DISGIUNTA")
    if (any(tecnica_h5 == "parziale")) s <- c(s, "TECNICA_H5_PARZIALE")
  }

  # ---- altre differenze sistematiche ----
  if (length(ck$other_differences) > 0L) s <- c(s, "ALTRA_DIFFERENZA")

  tutti <- .s2b_tutti_i_segnali()
  tutti[tutti %in% s]
}

#' Il verdetto dello Stadio 2b su un confronto
#'
#' @inheritParams .s2b_segnali
#' @param esiti tabella segnale -> "errore"/"avviso" (default:
#'   [stage2b_esiti_default()]).
#' @return lista: `passa` (logico), `motivi` (segnali con esito errore),
#'   `avvisi` (segnali con esito avviso), `differenza` ("agente",
#'   "condizione" o NA), `entita_isolata` (nomi degli agenti presenti solo nel
#'   trattato, o il valore della condizione nel trattato).
#' @keywords internal
stage2b_decide <- function(ck, tecnica_h5 = NULL, ingresso_completo = TRUE,
                           esiti = stage2b_esiti_default()) {
  s <- .s2b_segnali(ck, tecnica_h5 = tecnica_h5, ingresso_completo = ingresso_completo)
  mancanti <- setdiff(s, names(esiti))
  if (length(mancanti) > 0L) {
    rlang::abort(
      paste0("Stadio 2b: segnali senza esito nella tabella: ",
             paste(mancanti, collapse = ", ")),
      class = "simulomicsr_stage2b_esito_mancante"
    )
  }
  differenza <- NA_character_; entita <- character()
  if (!any(s %in% c("INGRESSO_INCOMPLETO", "LISTA_NON_VALIDA"))) {
    ag <- ck$agents
    solo_t <- function(ctrl) vapply(ag, function(a) {
      .s2b_chr(a$kind) != "vehicle_or_mock" && .s2b_chr(a$in_treated) == "all" &&
        .s2b_chr(a$in_control) %in% ctrl
    }, logical(1))
    # prima gli agenti che il controllo certamente non ha; poi quelli non detti
    sel <- solo_t("none")
    if (!any(sel)) sel <- solo_t("not_stated")
    if (any(sel)) {
      differenza <- "agente"
      entita <- vapply(ag[sel], function(a) .s2b_chr(a$name), character(1))
    } else if (.s2b_chr(ck$axes$disease_or_condition$relation) == "different") {
      differenza <- "condizione"
      entita <- .s2b_chr(ck$axes$disease_or_condition$treated)
    }
  }
  list(
    passa = !any(esiti[s] == "errore"),
    motivi = s[esiti[s] == "errore"],
    avvisi = s[esiti[s] == "avviso"],
    differenza = differenza,
    entita_isolata = entita
  )
}
