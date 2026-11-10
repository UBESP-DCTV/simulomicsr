# Tabella dei fattori (ADR-0029): il costruttore deterministico dei confronti.
#
# Una definizione sola: un confronto e' una coppia di gruppi uguali in tutti i
# fattori tranne uno, con uno dei due al livello di base di quel fattore.
# Ogni coppia di gruppi che non diventa un confronto va nel registro, col motivo.

# Ordina e incolla i nomi per la colonna `dettaglio` del registro.
.tf_dettaglio <- function(x) paste(sort(x, method = "radix"), collapse = ", ")

# Tabelle vuote con le colonne giuste (anche per uno studio senza confronti).
.tf_confronti_vuoti <- function() {
  out <- data.frame(id = character(0), fattore = character(0), tipo_fattore = character(0),
                    livello_trattato = character(0), livello_base = character(0),
                    gruppo_trattato = character(0), gruppo_controllo = character(0),
                    stringsAsFactors = FALSE)
  out$trattato <- list(); out$controllo <- list(); out$contesto <- list(); out$avvisi <- list()
  out$esito <- character(0)
  out
}
.tf_registro_vuoto <- function() {
  data.frame(gruppo_a = character(0), gruppo_b = character(0), motivo = character(0),
             dettaglio = character(0), stringsAsFactors = FALSE)
}

# Giudica una coppia di gruppi (righe `a` e `b` di `gruppi`).
# Restituisce `list(motivo, dettaglio)` se la coppia non e' un confronto,
# altrimenti `list(confronto = <riga di una riga>)`.
.tf_giudica_coppia <- function(gruppi, a, b, tabella, n_min) {
  fattori <- tabella$fattori
  liv_a <- vapply(fattori$nome, function(f) gruppi[[f]][a], "")
  liv_b <- vapply(fattori$nome, function(f) gruppi[[f]][b], "")

  # Passo 1: fattori diversi con i due livelli scritti (D) e con uno non scritto (N).
  diversi <- liv_a != liv_b
  non_scritto <- liv_a == TF_NON_SCRITTO | liv_b == TF_NON_SCRITTO
  D <- fattori$nome[diversi & !non_scritto]
  N <- fattori$nome[diversi & non_scritto]

  # Passo 2.
  if (length(D) == 0L) return(list(motivo = "nessuna_differenza", dettaglio = .tf_dettaglio(N)))
  if (length(D) > 1L) return(list(motivo = "piu_di_un_fattore", dettaglio = .tf_dettaglio(D)))

  # Passo 3.
  i_f <- match(D, fattori$nome)
  base <- fattori$base[i_f]
  if (is.na(base)) return(list(motivo = "fattore_senza_base", dettaglio = D))
  a_base <- liv_a[[D]] == base
  b_base <- liv_b[[D]] == base
  if (!a_base && !b_base) return(list(motivo = "nessuno_al_base", dettaglio = D))

  # Passo 4: il gruppo al livello di base e' il controllo.
  ctr <- if (a_base) a else b
  trt <- if (a_base) b else a
  if (gruppi$n[trt] < n_min || gruppi$n[ctr] < n_min) return(list(motivo = "n_min", dettaglio = D))

  # Passo 5: e' un confronto. I fattori non scritti si marcano.
  avvisi <- if (length(N)) paste0("non_scritto:", sort(N, method = "radix")) else character(0)
  altri <- setdiff(fattori$nome, D)
  contesto <- stats::setNames(vapply(altri, function(f) gruppi[[f]][trt], ""), altri)
  riga <- data.frame(id = paste(gruppi$gruppo[trt], gruppi$gruppo[ctr], sep = "_"),
                     fattore = D, tipo_fattore = fattori$tipo[i_f],
                     livello_trattato = gruppi[[D]][trt], livello_base = base,
                     gruppo_trattato = gruppi$gruppo[trt], gruppo_controllo = gruppi$gruppo[ctr],
                     stringsAsFactors = FALSE)
  riga$trattato <- list(gruppi$campioni[[trt]])
  riga$controllo <- list(gruppi$campioni[[ctr]])
  riga$contesto <- list(contesto)
  riga$avvisi <- list(avvisi)
  riga$esito <- if (length(avvisi)) "confronto con avviso" else "confronto"
  list(confronto = riga)
}

#' I confronti di uno studio, dalla tabella dei fattori
#'
#' Applica a ogni coppia di gruppi la definizione: i due gruppi sono uguali in
#' tutti i fattori tranne uno, e uno dei due e' al livello di base di quel
#' fattore. Il gruppo al livello di base e' il controllo. Un livello
#' `TF_NON_SCRITTO` non conta come differenza: il confronto si forma e porta
#' l'avviso `non_scritto:<fattore>`.
#'
#' @param tabella Oggetto di [tf_tabella()].
#' @param n_min Numero minimo di campioni per braccio.
#' @return Lista con `confronti` (una riga per confronto: `id`, `fattore`,
#'   `tipo_fattore`, `livello_trattato`, `livello_base`, `gruppo_trattato`,
#'   `gruppo_controllo`, le colonne-lista `trattato`, `controllo`, `contesto`,
#'   `avvisi`, e `esito`) e `registro` (una riga per ogni coppia di gruppi che
#'   non diventa un confronto: `gruppo_a`, `gruppo_b`, `motivo`, `dettaglio`).
#'   Vale sempre `nrow(confronti) + nrow(registro) == choose(n_gruppi, 2)`.
#' @keywords internal
tf_confronti <- function(tabella, n_min = 2L) {
  if (!inherits(tabella, "simulomicsr_tf_tabella")) {
    .tf_abort("`tabella` deve venire da tf_tabella().", "ingresso_non_valido")
  }
  if (!is.numeric(n_min) || length(n_min) != 1L || is.na(n_min) || n_min < 1) {
    .tf_abort("`n_min` deve essere un numero intero maggiore o uguale a 1.", "ingresso_non_valido")
  }
  gruppi <- tf_gruppi(tabella)
  n_gruppi <- nrow(gruppi)
  confronti <- list(.tf_confronti_vuoti())
  registro <- list(.tf_registro_vuoto())
  if (n_gruppi >= 2L) {
    for (a in seq_len(n_gruppi - 1L)) {
      for (b in seq.int(a + 1L, n_gruppi)) {
        esito <- .tf_giudica_coppia(gruppi, a, b, tabella, n_min)
        if (is.null(esito$confronto)) {
          registro[[length(registro) + 1L]] <- data.frame(
            gruppo_a = gruppi$gruppo[a], gruppo_b = gruppi$gruppo[b],
            motivo = esito$motivo, dettaglio = esito$dettaglio, stringsAsFactors = FALSE)
        } else {
          confronti[[length(confronti) + 1L]] <- esito$confronto
        }
      }
    }
  }
  confronti <- do.call(rbind, confronti)
  registro <- do.call(rbind, registro)
  rownames(confronti) <- NULL
  rownames(registro) <- NULL
  stopifnot(nrow(confronti) + nrow(registro) == choose(n_gruppi, 2))
  list(confronti = confronti, registro = registro)
}
