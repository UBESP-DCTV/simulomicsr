# Tabella dei fattori (ADR-0029): il costruttore deterministico dei confronti.
#
# Una definizione sola: un confronto e' una coppia di gruppi uguali in tutti i
# fattori tranne uno, con uno dei due al livello di base di quel fattore.
# I soggetti (donatore, sesso, eta', passaggio, lotto, coppia) non formano gruppi:
# si confrontano come insiemi fra i due bracci. Ogni coppia di gruppi che non
# diventa un confronto va nel registro, col motivo.

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

# I valori scritti di una colonna di soggetto: senza NA, vuoti e "non scritto".
.tf_valori_scritti <- function(x) {
  x <- trimws(as.character(x))
  unique(x[!is.na(x) & nzchar(x) & x != TF_NON_SCRITTO])
}

# Eta' numerica: ogni valore contiene un solo numero e il resto del testo
# (l'unita') e' lo stesso in tutti i valori. Restituisce i numeri, o NULL.
# Senza il controllo sull'unita', "6 months" e "7 years" sarebbero vicini.
.tf_eta_numerica <- function(x) {
  modello <- "[0-9]+(\\.[0-9]+)?"
  trovati <- regmatches(x, gregexpr(modello, x))
  if (!all(lengths(trovati) == 1L)) return(NULL)
  unita <- tolower(gsub("[[:space:]]+", " ", trimws(sub(modello, "", x))))
  if (length(unique(unita)) != 1L) return(NULL)
  as.numeric(unlist(trovati))
}

#' Confronta i soggetti dei due bracci di un confronto, come insiemi
#'
#' Regola (decisione 2 del PI del 2026-11-08). Si confrontano gli insiemi dei
#' valori distinti e scritti dei due bracci.
#'
#' - Fattore di tipo perturbazione, ogni tipo di soggetto: insiemi in parte
#'   comuni danno un avviso, insiemi senza valori comuni tolgono il confronto.
#' - Fattore di tipo stato, soggetto donatore, passaggio, lotto o coppia: i
#'   soggetti sono diversi per forza, quindi sempre e solo un avviso.
#' - Fattore di tipo stato, soggetto sesso o eta': come per la perturbazione.
#'
#' L'eta' numerica (un solo numero per valore, stessa unita') si confronta per
#' intervalli `[min, max]`: intervalli che si sovrappongono valgono "uguali".
#' Se un solo braccio non ha valori scritti, il confronto resta e porta un avviso.
#'
#' @param valori_trattato,valori_controllo Valori della colonna nei due bracci.
#' @param tipo_soggetto Tipo della colonna, in `TF_SOGGETTI`.
#' @param tipo_fattore Tipo del fattore che cambia nel confronto.
#' @return `"uguali"`, `"avviso_in_parte"`, `"avviso_diversi"`,
#'   `"avviso_non_scritto"` o `"nessun_confronto"`.
#' @keywords internal
.tf_soggetti <- function(valori_trattato, valori_controllo, tipo_soggetto, tipo_fattore) {
  if (!(tipo_soggetto %in% TF_SOGGETTI)) {
    .tf_abort(sprintf("Tipo di soggetto non ammesso: \"%s\".", tipo_soggetto), "soggetto_senza_tipo")
  }
  if (!(tipo_fattore %in% TF_TIPI_CON_BASE)) {
    .tf_abort(sprintf("Un confronto cambia un fattore di tipo %s, non \"%s\".",
                      paste(TF_TIPI_CON_BASE, collapse = " o "), tipo_fattore),
              "ingresso_non_valido")
  }
  t <- .tf_valori_scritti(valori_trattato)
  k <- .tf_valori_scritti(valori_controllo)
  if (length(t) == 0L && length(k) == 0L) return("uguali")
  if (length(t) == 0L || length(k) == 0L) return("avviso_non_scritto")

  relazione <- NULL
  if (tipo_soggetto == "eta") {
    numeri <- .tf_eta_numerica(c(t, k))
    if (!is.null(numeri)) {
      nt <- numeri[seq_along(t)]
      nk <- numeri[length(t) + seq_along(k)]
      relazione <- if (max(nt) < min(nk) || max(nk) < min(nt)) "disgiunti" else "uguali"
    }
  }
  if (is.null(relazione)) {
    relazione <- if (setequal(t, k)) "uguali" else if (length(intersect(t, k))) "in_parte" else "disgiunti"
  }
  if (relazione == "uguali") return("uguali")
  come_donatore <- tipo_soggetto %in% c("donatore", "passaggio", "lotto", "coppia")
  if (tipo_fattore == "stato" && come_donatore) return("avviso_diversi")
  if (relazione == "in_parte") "avviso_in_parte" else "nessun_confronto"
}

#' Quali fattori sono annidati in quali
#'
#' Un fattore B e' annidato in A quando ogni livello di A ha tutti i suoi
#' campioni a `TF_NON_APPLICABILE` in B oppure nessuno, e A ha almeno un livello
#' di ognuno dei due tipi (spec 2026-11-09 par. 5.3, aggiornamento S12r2). La
#' proprieta' si calcola dalla matrice campione per fattore: nessuno la dichiara.
#'
#' @param livelli `data.frame` campione per fattore (il campo `livelli` di una
#'   [tf_tabella()]).
#' @return Matrice logica con i nomi dei fattori su righe e colonne:
#'   `m[B, A]` e' vero quando B e' annidato in A.
#' @keywords internal
#' @noRd
.tf_annidati <- function(livelli) {
  nomi <- names(livelli)
  m <- matrix(FALSE, nrow = length(nomi), ncol = length(nomi), dimnames = list(nomi, nomi))
  for (B in nomi) {
    fuori <- livelli[[B]] == TF_NON_APPLICABILE
    if (!any(fuori) || all(fuori)) next
    for (A in setdiff(nomi, B)) {
      quota <- tapply(fuori, livelli[[A]], mean)
      m[B, A] <- all(quota %in% c(0, 1)) && any(quota == 0) && any(quota == 1)
    }
  }
  m
}

#' Divide i fattori diversi fra due lati in D, N e X, e applica la regola del fattore annidato
#'
#' La stessa definizione serve al costruttore (due gruppi: un livello per
#' fattore) e alla lettura dei confronti di Atlas (due bracci: l'insieme dei
#' livelli per fattore).
#'
#' @param lato_a,lato_b Liste con nome, una voce per fattore: i livelli distinti
#'   del lato, ordinati.
#' @param annidati Uscita di [.tf_annidati()].
#' @param annidato Se `FALSE` la regola del fattore annidato non si applica: un
#'   fattore di X e' sempre una differenza ordinaria.
#' @param non_scritto_conta Se `TRUE` un fattore di N conta come differenza.
#' @return Lista con `D` (i fattori che contano come differenza), `N` (uno dei
#'   due lati non scrive il fattore; vuoto se `non_scritto_conta`), `X` (tutti i
#'   fattori con un lato a `TF_NON_APPLICABILE` e l'altro scritto), `annidati`
#'   (i fattori di X che la regola toglie dal conto) e `solo_x` (vero quando la
#'   differenza e' un solo fattore, e quel fattore e' di X).
#' @keywords internal
#' @noRd
.tf_dividi_differenze <- function(lato_a, lato_b, annidati, annidato = TRUE, non_scritto_conta = FALSE) {
  nomi <- names(lato_a)
  e <- function(lato, f, valore) identical(lato[[f]], valore)
  diverso <- !vapply(nomi, function(f) identical(lato_a[[f]], lato_b[[f]]), TRUE)
  non_scritto <- vapply(nomi, function(f) e(lato_a, f, TF_NON_SCRITTO) || e(lato_b, f, TF_NON_SCRITTO), TRUE)
  fuori <- vapply(nomi, function(f) e(lato_a, f, TF_NON_APPLICABILE) || e(lato_b, f, TF_NON_APPLICABILE), TRUE)
  N <- nomi[diverso & non_scritto]
  X <- nomi[diverso & !non_scritto & fuori]
  D0 <- nomi[diverso & !non_scritto & !fuori]
  if (non_scritto_conta) {
    D0 <- c(D0, N); N <- character(0)
  }
  tolti <- character(0)
  if (annidato && length(D0) == 1L && length(X) > 0L && all(annidati[X, D0])) tolti <- X
  D <- c(D0, setdiff(X, tolti))
  # Senza la regola dell'annidato (lettura intera) un livello non applicabile e' un livello ordinario.
  list(D = D, N = N, X = X, annidati = tolti, solo_x = annidato && length(D) == 1L && D %in% X)
}

# Giudica una coppia di gruppi (righe `a` e `b` di `gruppi`).
# Restituisce `list(motivo, dettaglio)` se la coppia non e' un confronto,
# altrimenti `list(confronto = <riga di una riga>)`.
.tf_giudica_coppia <- function(gruppi, a, b, tabella, n_min, annidati) {
  fattori <- tabella$fattori
  liv_a <- vapply(fattori$nome, function(f) gruppi[[f]][a], "")
  liv_b <- vapply(fattori$nome, function(f) gruppi[[f]][b], "")

  # Passo 1: fattori diversi con i due livelli scritti e applicabili (D), con uno non scritto (N),
  # con uno non applicabile (X). Un fattore di X annidato nel solo fattore di D non conta.
  parti <- .tf_dividi_differenze(as.list(liv_a), as.list(liv_b), annidati)
  D <- parti$D
  N <- parti$N

  # Passo 2.
  if (length(D) == 0L) return(list(motivo = "nessuna_differenza", dettaglio = .tf_dettaglio(N)))
  if (length(D) > 1L) return(list(motivo = "piu_di_un_fattore", dettaglio = .tf_dettaglio(D)))
  # Un livello non applicabile non e' mai il trattato ne' la base.
  if (parti$solo_x) return(list(motivo = "non_applicabile", dettaglio = D))

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

  # Passo 4b: i soggetti si confrontano come insiemi, colonna per colonna.
  avvisi_soggetti <- character(0)
  if (!is.null(tabella$soggetti) && ncol(tabella$soggetti) > 0L) {
    colonne <- sort(names(tabella$soggetti), method = "radix")
    valori <- function(col, lato) tabella$soggetti[gruppi$campioni[[lato]], col]
    esiti <- vapply(colonne, function(col) {
      .tf_soggetti(valori(col, trt), valori(col, ctr), tabella$tipo_soggetto[[col]], fattori$tipo[i_f])
    }, "")
    if (any(esiti == "nessun_confronto")) {
      return(list(motivo = "soggetti_disgiunti",
                  dettaglio = .tf_dettaglio(colonne[esiti == "nessun_confronto"])))
    }
    prefisso <- c(avviso_in_parte = "soggetti_in_parte:", avviso_diversi = "soggetti_diversi:",
                  avviso_non_scritto = "soggetti_non_scritti:")
    con_avviso <- esiti %in% names(prefisso)
    avvisi_soggetti <- paste0(prefisso[esiti[con_avviso]], colonne[con_avviso])
    # Un buco dentro un braccio: alcuni campioni con il valore scritto e altri senza. Il giudizio qui sopra
    # usa i valori scritti; il buco si marca (minore M7 della revisione di S12r).
    buco <- vapply(colonne, function(col) {
      any(vapply(c(trt, ctr), function(lato) {
        v <- valori(col, lato)
        scritto <- !is.na(v) & nzchar(v) & v != TF_NON_SCRITTO
        any(scritto) && !all(scritto)
      }, TRUE))
    }, TRUE)
    if (any(buco)) avvisi_soggetti <- c(avvisi_soggetti, paste0("soggetti_buco:", colonne[buco]))
  }

  # Passo 5: e' un confronto. I fattori non scritti e i fattori annidati si marcano.
  avvisi <- if (length(N)) paste0("non_scritto:", sort(N, method = "radix")) else character(0)
  if (length(parti$annidati)) avvisi <- c(avvisi, paste0("annidato:", sort(parti$annidati, method = "radix")))
  avvisi <- c(avvisi, avvisi_soggetti)
  altri <- setdiff(fattori$nome, D)
  contesto <- stats::setNames(vapply(altri, function(f) gruppi[[f]][trt], ""), altri)
  # Di un fattore annidato il contesto porta il livello scritto, da qualunque braccio venga.
  for (f in parti$annidati) {
    if (contesto[[f]] == TF_NON_APPLICABILE) contesto[[f]] <- gruppi[[f]][ctr]
  }
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
#' l'avviso `non_scritto:<fattore>`. Un livello `TF_NON_APPLICABILE` in un
#' fattore annidato nel fattore che cambia non conta come differenza: il
#' confronto porta l'avviso `annidato:<fattore>`. Fuori da quel caso e' una
#' differenza ordinaria, e una coppia che differisce solo cosi' va nel registro
#' col motivo `non_applicabile`. Dopo la definizione, [.tf_soggetti()]
#' confronta le colonne di soggetto: il motivo `soggetti_disgiunti` toglie il
#' confronto, gli avvisi `soggetti_in_parte:<colonna>`,
#' `soggetti_diversi:<colonna>` e `soggetti_non_scritti:<colonna>` lo marcano.
#' L'avviso `soggetti_buco:<colonna>` dice che in un braccio la colonna e'
#' scritta per alcuni campioni e non per altri.
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
  annidati <- .tf_annidati(tabella$livelli)
  confronti <- list(.tf_confronti_vuoti())
  registro <- list(.tf_registro_vuoto())
  if (n_gruppi >= 2L) {
    for (a in seq_len(n_gruppi - 1L)) {
      for (b in seq.int(a + 1L, n_gruppi)) {
        esito <- .tf_giudica_coppia(gruppi, a, b, tabella, n_min, annidati)
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
