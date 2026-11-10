# Tabella dei fattori (ADR-0029): l'oggetto validato e i gruppi.
#
# La tabella dei fattori descrive il disegno di uno studio: quali fattori
# cambiano fra i campioni, quale livello ha ogni campione, quale livello e'
# la base. La scrive il lettore dello studio (o un adattatore: Atlas, Stadio 2).
# Il costruttore dei confronti (R/tabella-fattori-confronti.R) la legge.

#' Livello di un fattore che il testo dello studio non scrive
#' @keywords internal
TF_NON_SCRITTO <- "non scritto"

#' Livello di un fattore che per quel campione non si applica
#'
#' Lo stadio della malattia di un donatore sano, la dose di un campione non
#' trattato. Diverso da `TF_NON_SCRITTO`: qui il testo dice (o il disegno
#' implica) che il fattore non vale per il campione. Non e' mai un livello
#' trattato ne' un livello di base (spec 2026-11-09 par. 5.3, aggiornamento S12r2).
#' @keywords internal
TF_NON_APPLICABILE <- "non applicabile"

#' Tipi di fattore ammessi
#' @keywords internal
TF_TIPI <- c("perturbazione", "stato", "contesto", "tempo", "tecnico")

#' Tipi di fattore che possono avere un livello di base
#' @keywords internal
TF_TIPI_CON_BASE <- c("perturbazione", "stato")

#' Tipi di soggetto ammessi
#' @keywords internal
TF_SOGGETTI <- c("donatore", "sesso", "eta", "passaggio", "lotto", "coppia")

#' Nomi che un fattore non puo' avere: sono le colonne fisse di `tf_gruppi()`
#' @keywords internal
TF_NOMI_RISERVATI <- c("gruppo", "n", "campioni")

# Errore con classe `simulomicsr_tf_<classe>`.
.tf_abort <- function(msg, classe) {
  rlang::abort(msg, class = paste0("simulomicsr_tf_", classe))
}

# Mostra al massimo `n` valori in un messaggio d'errore, col conto del resto.
.tf_elenca <- function(x, n = 5L) {
  x <- as.character(x)
  testa <- paste(utils::head(x, n), collapse = ", ")
  if (length(x) > n) sprintf("%s (e altri %d)", testa, length(x) - n) else testa
}

# Porta a `data.frame` di caratteri con una riga per campione, nell'ordine di
# `campioni`. `cosa` e' il nome dell'argomento, per i messaggi.
.tf_per_campione <- function(x, campioni, cosa) {
  if (!is.data.frame(x)) {
    .tf_abort(sprintf("`%s` deve essere un data.frame, non %s.", cosa, class(x)[1]),
              "ingresso_non_valido")
  }
  if (anyDuplicated(names(x))) {
    .tf_abort(sprintf("`%s` ha colonne con lo stesso nome: %s.", cosa,
                      .tf_elenca(unique(names(x)[duplicated(names(x))]))),
              "ingresso_non_valido")
  }
  if (nrow(x) != length(campioni) || !setequal(rownames(x), campioni)) {
    mancanti <- setdiff(campioni, rownames(x))
    estranei <- setdiff(rownames(x), campioni)
    .tf_abort(sprintf(paste0("`%s` deve avere una riga per campione (row.names = campioni). ",
                             "Righe: %d, campioni: %d. Campioni senza riga: %s. Righe senza campione: %s."),
                      cosa, nrow(x), length(campioni),
                      if (length(mancanti)) .tf_elenca(mancanti) else "nessuno",
                      if (length(estranei)) .tf_elenca(estranei) else "nessuna"),
              "ingresso_non_valido")
  }
  x <- x[campioni, , drop = FALSE]
  for (col in names(x)) x[[col]] <- as.character(x[[col]])
  x
}

#' Costruisce e valida la tabella dei fattori di uno studio
#'
#' @param campioni Vettore di caratteri, i campioni dello studio (GSM). Senza doppi.
#' @param livelli `data.frame` di caratteri: una riga per campione
#'   (`row.names` = campioni), una colonna per fattore. Nessun valore mancante:
#'   un livello che il testo non scrive vale `TF_NON_SCRITTO`.
#' @param fattori `data.frame` con `nome`, `tipo` (in `TF_TIPI`) e `base`
#'   (carattere o `NA`). La base e' ammessa solo per i tipi in `TF_TIPI_CON_BASE`.
#'   Un nome in `TF_NOMI_RISERVATI` ferma con la classe `simulomicsr_tf_nome_riservato`.
#' @param soggetti `data.frame` di caratteri come `livelli`, una colonna per
#'   colonna di soggetto. I valori mancanti sono ammessi. `NULL` se non ce ne sono.
#' @param tipo_soggetto Vettore di caratteri con nome: `c(<colonna> = <tipo in TF_SOGGETTI>)`.
#' @return Lista di classe `simulomicsr_tf_tabella` con gli stessi campi.
#' @keywords internal
tf_tabella <- function(campioni, livelli, fattori, soggetti = NULL, tipo_soggetto = NULL) {
  # --- campioni
  if (!is.character(campioni) || length(campioni) == 0L || anyNA(campioni) || any(!nzchar(campioni))) {
    .tf_abort("`campioni` deve essere un vettore di caratteri non vuoto, senza valori mancanti.",
              "ingresso_non_valido")
  }
  if (anyDuplicated(campioni)) {
    .tf_abort(sprintf("Campioni ripetuti in `campioni`: %s.",
                      .tf_elenca(unique(campioni[duplicated(campioni)]))),
              "campioni_doppi")
  }

  # --- fattori
  if (!is.data.frame(fattori) || !all(c("nome", "tipo", "base") %in% names(fattori))) {
    .tf_abort("`fattori` deve essere un data.frame con le colonne `nome`, `tipo`, `base`.",
              "ingresso_non_valido")
  }
  fattori <- data.frame(nome = as.character(fattori$nome), tipo = as.character(fattori$tipo),
                        base = as.character(fattori$base), stringsAsFactors = FALSE)
  if (anyNA(fattori$nome) || any(!nzchar(fattori$nome)) || anyDuplicated(fattori$nome)) {
    .tf_abort(sprintf("I nomi dei fattori devono essere scritti e distinti. Nomi: %s.",
                      .tf_elenca(fattori$nome)),
              "ingresso_non_valido")
  }
  riservati <- intersect(fattori$nome, TF_NOMI_RISERVATI)
  if (length(riservati)) {
    .tf_abort(sprintf(paste0("Nome di fattore riservato: %s. I nomi %s sono le colonne fisse di tf_gruppi(): ",
                             "un fattore con quel nome le sovrascrive. Cambia il nome del fattore a monte."),
                      .tf_elenca(riservati), paste(sprintf("`%s`", TF_NOMI_RISERVATI), collapse = ", ")),
              "nome_riservato")
  }
  ignoti <- !(fattori$tipo %in% TF_TIPI)
  if (any(ignoti)) {
    .tf_abort(sprintf("Tipo di fattore non ammesso: %s. Tipi ammessi: %s.",
                      .tf_elenca(sprintf("%s = \"%s\"", fattori$nome[ignoti], fattori$tipo[ignoti])),
                      paste(TF_TIPI, collapse = ", ")),
              "tipo_ignoto")
  }

  # --- livelli
  livelli <- .tf_per_campione(livelli, campioni, "livelli")
  if (!setequal(names(livelli), fattori$nome)) {
    .tf_abort(sprintf(paste0("Le colonne di `livelli` e i nomi di `fattori` non coincidono. ",
                             "Solo in `livelli`: %s. Solo in `fattori`: %s."),
                      .tf_elenca(setdiff(names(livelli), fattori$nome)),
                      .tf_elenca(setdiff(fattori$nome, names(livelli)))),
              "ingresso_non_valido")
  }
  livelli <- livelli[, fattori$nome, drop = FALSE]
  for (col in names(livelli)) {
    vuoti <- is.na(livelli[[col]]) | !nzchar(livelli[[col]])
    if (any(vuoti)) {
      .tf_abort(sprintf(paste0("Il fattore `%s` non ha un livello per %d campioni: %s. ",
                               "Un livello che il testo non scrive vale \"%s\"."),
                        col, sum(vuoti), .tf_elenca(campioni[vuoti]), TF_NON_SCRITTO),
                "campione_senza_livello")
    }
  }

  # --- base
  for (i in seq_len(nrow(fattori))) {
    b <- fattori$base[i]
    if (is.na(b)) next
    if (!(fattori$tipo[i] %in% TF_TIPI_CON_BASE)) {
      .tf_abort(sprintf(paste0("Il fattore `%s` e' di tipo \"%s\" e non puo' avere una base (\"%s\"). ",
                               "La base e' ammessa solo per: %s."),
                        fattori$nome[i], fattori$tipo[i], b, paste(TF_TIPI_CON_BASE, collapse = ", ")),
                "base_non_ammessa")
    }
    if (identical(b, TF_NON_SCRITTO)) {
      .tf_abort(sprintf("Il fattore `%s` ha per base \"%s\": un livello non scritto non puo' essere la base.",
                        fattori$nome[i], TF_NON_SCRITTO),
                "base_non_ammessa")
    }
    if (identical(b, TF_NON_APPLICABILE)) {
      .tf_abort(sprintf("Il fattore `%s` ha per base \"%s\": un livello non applicabile non puo' essere la base.",
                        fattori$nome[i], TF_NON_APPLICABILE),
                "base_non_ammessa")
    }
    if (!(b %in% livelli[[fattori$nome[i]]])) {
      .tf_abort(sprintf("La base \"%s\" del fattore `%s` non e' fra i suoi livelli: %s.",
                        b, fattori$nome[i], .tf_elenca(unique(livelli[[fattori$nome[i]]]))),
                "base_ignota")
    }
  }

  # --- soggetti
  if (is.null(soggetti)) {
    if (length(tipo_soggetto)) {
      .tf_abort("`tipo_soggetto` e' scritto ma `soggetti` e' NULL.", "ingresso_non_valido")
    }
    tipo_soggetto <- NULL
  } else {
    soggetti <- .tf_per_campione(soggetti, campioni, "soggetti")
    senza_tipo <- setdiff(names(soggetti), names(tipo_soggetto))
    if (length(senza_tipo)) {
      .tf_abort(sprintf("Colonne di soggetto senza tipo in `tipo_soggetto`: %s. Tipi ammessi: %s.",
                        .tf_elenca(senza_tipo), paste(TF_SOGGETTI, collapse = ", ")),
                "soggetto_senza_tipo")
    }
    in_piu <- setdiff(names(tipo_soggetto), names(soggetti))
    if (length(in_piu)) {
      .tf_abort(sprintf("`tipo_soggetto` nomina colonne che `soggetti` non ha: %s.", .tf_elenca(in_piu)),
                "ingresso_non_valido")
    }
    tipo_soggetto <- stats::setNames(as.character(tipo_soggetto[names(soggetti)]), names(soggetti))
    ignoti <- !(tipo_soggetto %in% TF_SOGGETTI)
    if (any(ignoti)) {
      .tf_abort(sprintf("Tipo di soggetto non ammesso: %s. Tipi ammessi: %s.",
                        .tf_elenca(sprintf("%s = \"%s\"", names(tipo_soggetto)[ignoti], tipo_soggetto[ignoti])),
                        paste(TF_SOGGETTI, collapse = ", ")),
                "soggetto_senza_tipo")
    }
    doppi <- intersect(names(soggetti), fattori$nome)
    if (length(doppi)) {
      .tf_abort(sprintf("Una colonna non puo' essere insieme fattore e soggetto: %s.", .tf_elenca(doppi)),
                "ingresso_non_valido")
    }
  }

  structure(list(campioni = campioni, livelli = livelli, fattori = fattori,
                 soggetti = soggetti, tipo_soggetto = tipo_soggetto),
            class = "simulomicsr_tf_tabella")
}

#' I gruppi di una tabella dei fattori
#'
#' Un gruppo e' l'insieme dei campioni con lo stesso livello in ogni fattore.
#' I gruppi vengono dalle righe distinte di `livelli`, confrontate colonna per
#' colonna: nessuna chiave incollata, quindi un separatore dentro un livello
#' non unisce gruppi diversi. `TF_NON_SCRITTO` e' un livello come gli altri.
#'
#' @param tabella Oggetto di [tf_tabella()].
#' @return `data.frame` con `gruppo` (`g1`, `g2`, ... nell'ordine delle righe
#'   distinte di `livelli` ordinate per colonna), una colonna per fattore, `n`
#'   (intero) e `campioni` (colonna-lista, campioni ordinati).
#' @keywords internal
tf_gruppi <- function(tabella) {
  if (!inherits(tabella, "simulomicsr_tf_tabella")) {
    .tf_abort("`tabella` deve venire da tf_tabella().", "ingresso_non_valido")
  }
  liv <- tabella$livelli
  n_campioni <- length(tabella$campioni)
  if (ncol(liv) == 0L) {
    # Nessun fattore: tutti i campioni stanno in un gruppo solo.
    id <- rep(1L, n_campioni)
    distinti <- liv[1L, , drop = FALSE]
  } else {
    # Ordine indipendente dal locale: `method = "radix"` ordina come in C.
    ord <- do.call(order, c(unname(as.list(liv)), list(method = "radix")))
    ordinati <- liv[ord, , drop = FALSE]
    nuovo <- !duplicated(ordinati)
    id <- integer(n_campioni)
    id[ord] <- cumsum(nuovo)
    distinti <- ordinati[nuovo, , drop = FALSE]
  }
  n_gruppi <- nrow(distinti)
  out <- data.frame(gruppo = sprintf("g%d", seq_len(n_gruppi)), stringsAsFactors = FALSE)
  for (col in names(distinti)) out[[col]] <- distinti[[col]]
  membri <- lapply(seq_len(n_gruppi), function(i) sort(tabella$campioni[id == i], method = "radix"))
  out$n <- lengths(membri)
  out$campioni <- membri
  rownames(out) <- NULL
  out
}
