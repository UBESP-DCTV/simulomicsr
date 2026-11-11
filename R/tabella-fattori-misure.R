# Le misure contro Expression Atlas (ADR-0029, spec 2026-11-09 par. 5).
#
# Tutte le funzioni lavorano su UNO studio. La forma comune:
#   - una partizione e' un vettore di caratteri con nome: GSM -> gruppo;
#   - i confronti sono un data.frame con le colonne-lista `trattato` e `controllo` (GSM);
#   - `atlas` e' l'uscita di `atlas_tabella()`;
#   - `universo` sono i GSM presenti sia nei gruppi di Atlas sia nella nostra vista dello studio.
# Nessuna funzione toglie un caso in silenzio: ogni confronto riceve una classe.

#' Controlla una partizione in forma comune
#' @keywords internal
#' @noRd
.tf_controlla_partizione <- function(x, cosa) {
  if (length(x) == 0L) return(stats::setNames(character(0), character(0)))
  nomi <- names(x)
  if (is.null(nomi) || anyNA(nomi) || any(!nzchar(nomi)) || anyDuplicated(nomi) || anyNA(x)) {
    .tf_abort(sprintf("`%s` deve essere un vettore con nome (GSM -> gruppo), senza nomi ripetuti e senza NA.", cosa),
              "ingresso_non_valido")
  }
  stats::setNames(as.character(x), nomi)
}

#' Controlla i confronti in forma comune
#' @keywords internal
#' @noRd
.tf_controlla_confronti <- function(x, cosa) {
  if (!is.data.frame(x) || !all(c("trattato", "controllo") %in% names(x)) ||
      !is.list(x$trattato) || !is.list(x$controllo)) {
    .tf_abort(sprintf("`%s` deve essere un data.frame con le colonne-lista `trattato` e `controllo`.", cosa),
              "ingresso_non_valido")
  }
  invisible(x)
}

#' Taglia un braccio all'universo e lo ordina
#' @keywords internal
#' @noRd
.tf_taglia <- function(braccio, universo) {
  sort(unique(intersect(as.character(braccio), universo)), method = "radix")
}

#' Indice di Rand corretto fra due partizioni degli stessi campioni
#'
#' Formula di Hubert e Arabie. Se le due partizioni sono banali allo stesso modo (un gruppo solo in tutte e due,
#' oppure tutti singoli in tutte e due) il denominatore e' zero e l'indice vale 1.
#' @keywords internal
#' @noRd
.tf_ari <- function(a, b) {
  n <- length(a)
  if (n < 2L) return(NA_real_)
  scegli2 <- function(x) sum(x * (x - 1) / 2)
  tavola <- table(a, b)
  somma_celle <- scegli2(as.numeric(tavola))
  somma_a <- scegli2(as.numeric(rowSums(tavola)))
  somma_b <- scegli2(as.numeric(colSums(tavola)))
  totale <- n * (n - 1) / 2
  atteso <- somma_a * somma_b / totale
  massimo <- (somma_a + somma_b) / 2
  if (isTRUE(all.equal(massimo, atteso))) return(1)
  (somma_celle - atteso) / (massimo - atteso)
}

#' Misura (a): i nostri gruppi contro i gruppi dei curatori di Atlas
#'
#' Le due partizioni si confrontano sui campioni comuni. I campioni non comuni si contano, non si tolgono in
#' silenzio.
#'
#' @param nostra,atlas vettori con nome: GSM -> gruppo.
#' @return lista con `classe` (`"identica"`; `"identica_sui_comuni"`: uguale sui campioni comuni, ma la nostra
#'   partizione omette campioni di Atlas (spec par. 5.5 punto 4, aggiornamento S12r2); `"piu_fine"`: ogni nostro
#'   gruppo sta in un gruppo di Atlas; `"piu_grossa"`; `"incrociata"`; `NA` senza campioni comuni), `ari` (indice
#'   di Rand corretto), `n_comuni`, `solo_nostri`, `solo_atlas`.
#' @keywords internal
tf_misura_gruppi <- function(nostra, atlas) {
  nostra <- .tf_controlla_partizione(nostra, "nostra")
  atlas <- .tf_controlla_partizione(atlas, "atlas")
  comuni <- sort(intersect(names(nostra), names(atlas)), method = "radix")
  esito <- list(classe = NA_character_, ari = NA_real_, n_comuni = length(comuni),
                solo_nostri = length(setdiff(names(nostra), names(atlas))),
                solo_atlas = length(setdiff(names(atlas), names(nostra))))
  if (length(comuni) == 0L) return(esito)
  x <- unname(nostra[comuni]); y <- unname(atlas[comuni])
  # ogni nostro gruppo sta in un solo gruppo di Atlas, e viceversa
  nostri_dentro <- all(tapply(y, x, function(v) length(unique(v))) == 1L)
  atlas_dentro <- all(tapply(x, y, function(v) length(unique(v))) == 1L)
  esito$classe <- if (nostri_dentro && atlas_dentro) {
    if (esito$solo_atlas == 0L) "identica" else "identica_sui_comuni"
  } else if (nostri_dentro) {
    "piu_fine"
  } else if (atlas_dentro) {
    "piu_grossa"
  } else {
    "incrociata"
  }
  esito$ari <- .tf_ari(x, y)
  esito
}

#' I livelli di un braccio in ogni fattore di Atlas
#' @return lista con nome (un elemento per fattore): i livelli distinti del braccio, ordinati.
#' @keywords internal
#' @noRd
.tf_livelli_braccio <- function(braccio, tabella) {
  liv <- tabella$livelli[braccio, , drop = FALSE]
  stats::setNames(lapply(names(liv), function(f) sort(unique(liv[[f]]), method = "radix")), names(liv))
}

#' I fattori di Atlas in cui due bracci hanno livelli diversi
#'
#' La stessa definizione di `tf_confronti()` ([.tf_dividi_differenze()]), applicata ai fattori di Atlas: un
#' fattore che uno dei due bracci non scrive non e' una differenza e si marca; un fattore annidato nel solo
#' fattore che cambia non conta. `annidato = FALSE` e `non_scritto_conta = TRUE` danno le letture intera e stretta
#' (spec par. 5.5 punto 3).
#' @return lista con `diversi`, `non_scritti`, `annidati` (ordinati) e `solo_x`.
#' @keywords internal
#' @noRd
.tf_fattori_diversi <- function(trattato, controllo, tabella, annidati = .tf_annidati(tabella$livelli),
                                annidato = TRUE, non_scritto_conta = FALSE) {
  parti <- .tf_dividi_differenze(.tf_livelli_braccio(trattato, tabella), .tf_livelli_braccio(controllo, tabella),
                                 annidati, annidato = annidato, non_scritto_conta = non_scritto_conta)
  ordina <- function(x) sort(x, method = "radix")
  list(diversi = ordina(parti$D), non_scritti = ordina(parti$N), annidati = ordina(parti$annidati),
       solo_x = parti$solo_x)
}

#' Classe di un valore di tempo: zero, successivo, altro
#'
#' `"zero"`: il valore contiene un solo numero e quel numero e' 0. `"successivo"`: un solo numero, maggiore di 0.
#' `"altro"`: nessun numero, piu' numeri, valore vuoto o `NA` (spec par. 5.5 punto 1, aggiornamento S12r2).
#' @keywords internal
#' @noRd
.tf_classe_tempo <- function(x) {
  x <- as.character(x); x[is.na(x)] <- ""
  numeri <- regmatches(x, gregexpr("[0-9]+([.,][0-9]+)?", x))
  uno <- lengths(numeri) == 1L
  valore <- rep(NA_real_, length(x))
  valore[uno] <- as.numeric(sub(",", ".", unlist(numeri[uno]), fixed = TRUE))
  ifelse(!uno, "altro", ifelse(valore == 0, "zero", "successivo"))
}

#' I campi di tempo di uno studio
#'
#' Un campo di tempo e' un fattore di Atlas, oppure una colonna non costante della tabella dei campioni di GEO,
#' il cui nome ha «time» all'inizio di una parola (spec par. 5.5 punto 1). La regola guarda il nome, non un elenco
#' di studi.
#'
#' @param atlas l'uscita di `atlas_tabella()`.
#' @param geo lista con nome, una voce per colonna di GEO: un vettore di caratteri con nome (GSM -> valore).
#'   `NULL` se non ci sono colonne di GEO.
#' @return lista con nome: per ogni campo (`atlas:<fattore>`, `geo:<colonna>`) il vettore GSM -> valore.
#' @keywords internal
tf_campi_di_tempo <- function(atlas, geo = NULL) {
  di_tempo <- function(nomi) grepl("(^|[^a-z])time", tolower(nomi))
  campi <- list()
  if (!is.null(atlas$tabella)) {
    liv <- atlas$tabella$livelli
    for (f in names(liv)[di_tempo(names(liv))]) {
      campi[[paste0("atlas:", f)]] <- stats::setNames(as.character(liv[[f]]), rownames(liv))
    }
  }
  if (!is.null(geo)) {
    forma <- is.list(geo) && !is.null(names(geo)) && all(nzchar(names(geo))) && !anyDuplicated(names(geo)) &&
      all(vapply(geo, function(v) is.atomic(v) && !is.null(names(v)) && !anyDuplicated(names(v)), TRUE))
    if (!forma) {
      .tf_abort("`geo` deve essere una lista con nome: per ogni colonna un vettore con nome (GSM -> valore).",
                "ingresso_non_valido")
    }
    for (colonna in names(geo)[di_tempo(names(geo))]) {
      v <- stats::setNames(as.character(geo[[colonna]]), names(geo[[colonna]]))
      if (length(unique(v)) > 1L) campi[[paste0("geo:", colonna)]] <- v
    }
  }
  campi
}

#' La marca `tempo_zero` di un confronto
#'
#' Vero quando, in almeno un campo di tempo, tutti i campioni di un braccio hanno un valore zero e l'altro
#' braccio non ha campioni a zero e ne ha almeno uno a un valore successivo. La regola non guarda quale braccio
#' i curatori chiamano riferimento: il verso si riporta a parte (spec par. 5.5 punto 1).
#'
#' @param trattato,controllo chr, i GSM dei due bracci.
#' @param campi l'uscita di `tf_campi_di_tempo()`.
#' @return lista con `tempo_zero` (logico), `verso` (`"zero_controllo"`, `"zero_trattato"`, `NA`) e `campo` (il
#'   primo campo, in ordine di nome, che da' la marca; `NA` se nessuno).
#' @keywords internal
tf_tempo_zero <- function(trattato, controllo, campi) {
  no <- list(tempo_zero = FALSE, verso = NA_character_, campo = NA_character_)
  if (length(trattato) == 0L || length(controllo) == 0L) return(no)
  for (campo in sort(as.character(names(campi)), method = "radix")) {
    v <- campi[[campo]]
    ct <- .tf_classe_tempo(unname(v[as.character(trattato)])); cc <- .tf_classe_tempo(unname(v[as.character(controllo)]))
    tutto_zero <- function(k) all(k == "zero")
    dopo <- function(k) !any(k == "zero") && any(k == "successivo")
    if (tutto_zero(cc) && dopo(ct)) return(list(tempo_zero = TRUE, verso = "zero_controllo", campo = campo))
    if (tutto_zero(ct) && dopo(cc)) return(list(tempo_zero = TRUE, verso = "zero_trattato", campo = campo))
  }
  no
}

#' I nomi dei fattori di Atlas che per la definizione sono un contesto
#'
#' Tipo cellulare, linea cellulare e tessuto (`organism part` nel vocabolario di Atlas): i tre contesti della
#' definizione dei tipi (spec par. 5.2 punto 3). Un fattore di contesto non ha livello di base, quindi il
#' costruttore non forma un confronto fra due contesti (spec par. 5.5, aggiornamento S12r3; decisione del PI
#' del 2026-11-11, ADR-0029).
#' @keywords internal
TF_FATTORI_CONTESTO_ATLAS <- c("cell type", "cell line", "organism part")

#' Il fattore di Atlas e' un contesto?
#'
#' La regola guarda il nome, uguale a uno di `TF_FATTORI_CONTESTO_ATLAS` a meno di maiuscole e spazi ai bordi.
#' Non vede un contesto che i curatori scrivono con un altro nome (per esempio `biopsy site`): quei confronti
#' restano nel riferimento.
#'
#' @param nomi chr, nomi di fattori di Atlas.
#' @return logico lungo quanto `nomi`; `NA` da' `FALSE`.
#' @keywords internal
tf_fattore_di_contesto <- function(nomi) {
  tolower(trimws(as.character(nomi))) %in% TF_FATTORI_CONTESTO_ATLAS
}

#' Classifica i confronti dei curatori di Atlas rispetto alla definizione
#'
#' @param atlas l'uscita di `atlas_tabella()`.
#' @param universo chr, i GSM che contano.
#' @param n_min numero minimo di campioni per braccio dopo il taglio all'universo.
#' @param annidato se `TRUE` (letture principale e stretta) vale la regola del fattore annidato; se `FALSE`
#'   (lettura intera) un livello `TF_NON_APPLICABILE` e' una differenza ordinaria.
#' @param non_scritto_conta se `TRUE` (lettura stretta) un fattore che un braccio non scrive conta come
#'   differenza.
#' @param campi_tempo l'uscita di `tf_campi_di_tempo()`; `NULL` se la marca `tempo_zero` non si calcola.
#' @return i confronti di Atlas con i bracci tagliati all'universo e le colonne `classe`, `fattori_diversi`,
#'   `fattori_non_scritti` (i fattori che uno dei due bracci non scrive: non contano come differenza, salvo
#'   `non_scritto_conta`), `fattori_annidati` (i fattori che la regola del fattore annidato toglie dal conto),
#'   `tempo_zero`, `tempo_zero_verso`, `tempo_zero_campo` (`NA` senza `campi_tempo`; la marca non dipende dalla
#'   classe), `solo_contesto` (la classe e' `"rispetta"` e il solo fattore che cambia e' un contesto secondo
#'   `tf_fattore_di_contesto()`). `classe`: `"rispetta"` (i due gruppi differiscono in un solo fattore di Atlas), `"piu_fattori"`,
#'   `"non_formabile"` (un braccio ha meno di `n_min` campioni nell'universo), `"nessuna_differenza"` (i due
#'   gruppi hanno gli stessi livelli in tutti i fattori di Atlas), `"non_applicabile"` (la sola differenza e' un
#'   livello `TF_NON_APPLICABILE`: per la definizione non e' un confronto).
#' @keywords internal
tf_classi_confronti_atlas <- function(atlas, universo, n_min = 2L, annidato = TRUE, non_scritto_conta = FALSE,
                                      campi_tempo = NULL) {
  k <- .tf_controlla_confronti(atlas$confronti, "atlas$confronti")
  universo <- as.character(universo)
  k$trattato <- lapply(k$trattato, .tf_taglia, universo = universo)
  k$controllo <- lapply(k$controllo, .tf_taglia, universo = universo)
  n <- nrow(k)
  classe <- character(n); diversi <- character(n); non_scritti <- character(n); annidati_k <- character(n)
  tz <- rep(NA, n); tz_verso <- rep(NA_character_, n); tz_campo <- rep(NA_character_, n)
  contesto <- rep(FALSE, n)
  annidati <- if (n > 0L && !is.null(atlas$tabella)) .tf_annidati(atlas$tabella$livelli) else NULL
  for (i in seq_len(n)) {
    tr <- k$trattato[[i]]; co <- k$controllo[[i]]
    if (!is.null(campi_tempo)) {
      z <- tf_tempo_zero(tr, co, campi_tempo)
      tz[i] <- z$tempo_zero; tz_verso[i] <- z$verso; tz_campo[i] <- z$campo
    }
    if (length(tr) < n_min || length(co) < n_min) {
      classe[i] <- "non_formabile"; diversi[i] <- NA_character_; non_scritti[i] <- NA_character_
      annidati_k[i] <- NA_character_
      next
    }
    fd <- .tf_fattori_diversi(tr, co, atlas$tabella, annidati, annidato = annidato,
                              non_scritto_conta = non_scritto_conta)
    d <- fd$diversi
    diversi[i] <- .tf_dettaglio(d); non_scritti[i] <- .tf_dettaglio(fd$non_scritti)
    annidati_k[i] <- .tf_dettaglio(fd$annidati)
    classe[i] <- if (length(d) > 1L) {
      "piu_fattori"
    } else if (length(d) == 0L) {
      "nessuna_differenza"
    } else if (fd$solo_x) {
      "non_applicabile"
    } else {
      "rispetta"
    }
    contesto[i] <- classe[i] == "rispetta" && tf_fattore_di_contesto(d)
  }
  k$classe <- classe
  k$fattori_diversi <- diversi
  k$fattori_non_scritti <- non_scritti
  k$fattori_annidati <- annidati_k
  k$tempo_zero <- tz
  k$tempo_zero_verso <- tz_verso
  k$tempo_zero_campo <- tz_campo
  k$solo_contesto <- contesto
  k
}

#' Chiave di un braccio: i GSM ordinati, uniti da un carattere che un GSM non contiene
#' @keywords internal
#' @noRd
.tf_chiave <- function(braccio) paste(braccio, collapse = "\x1f")

#' Per ogni confronto di Atlas: c'e' un nostro confronto con gli stessi due insiemi?
#' @return chr lungo quanto i confronti di Atlas: `"uguale"`, `"verso_opposto"`, `"no"`.
#' @keywords internal
#' @noRd
.tf_abbina <- function(nostri, atlas_confronti, universo) {
  nt <- vapply(nostri$trattato, function(b) .tf_chiave(.tf_taglia(b, universo)), "")
  nc <- vapply(nostri$controllo, function(b) .tf_chiave(.tf_taglia(b, universo)), "")
  pieni <- nzchar(nt) & nzchar(nc)                       # un braccio vuoto nell'universo non abbina niente
  dritti <- paste(nt, nc, sep = "\x1e")[pieni]; rovesci <- paste(nc, nt, sep = "\x1e")[pieni]
  at <- vapply(atlas_confronti$trattato, function(b) .tf_chiave(.tf_taglia(b, universo)), "")
  ac <- vapply(atlas_confronti$controllo, function(b) .tf_chiave(.tf_taglia(b, universo)), "")
  chiave <- paste(at, ac, sep = "\x1e")
  ifelse(!nzchar(at) | !nzchar(ac), "no",
         ifelse(chiave %in% dritti, "uguale", ifelse(chiave %in% rovesci, "verso_opposto", "no")))
}

#' Misura (b): i confronti dei curatori di Atlas che noi formiamo
#'
#' @param nostri i nostri confronti in forma comune.
#' @param atlas_classi l'uscita di `tf_classi_confronti_atlas()`.
#' @param universo chr, i GSM che contano: i nostri bracci si tagliano all'universo prima del confronto.
#' @return `atlas_classi` con la colonna `ritrovato`: `"uguale"` (stessi due insiemi, stesso verso),
#'   `"verso_opposto"`, `"no"`.
#' @keywords internal
tf_misura_ritrovati <- function(nostri, atlas_classi, universo) {
  .tf_controlla_confronti(nostri, "nostri"); .tf_controlla_confronti(atlas_classi, "atlas_classi")
  atlas_classi$ritrovato <- .tf_abbina(nostri, atlas_classi, as.character(universo))
  atlas_classi
}

#' Misura (c): i nostri confronti che Atlas non elenca, giudicati con i fattori di Atlas
#'
#' Un nostro confronto e' «elencato» se i suoi due insiemi, tagliati all'universo, sono quelli di un confronto di
#' Atlas, in qualunque verso.
#'
#' @param nostri i nostri confronti in forma comune.
#' @param atlas l'uscita di `atlas_tabella()`.
#' @param universo chr, i GSM che contano.
#' @param annidato,non_scritto_conta come in `tf_classi_confronti_atlas()`: la misura (c) usa la stessa
#'   classificazione della lettura.
#' @return i nostri confronti non elencati, con i bracci tagliati all'universo e la colonna `giudizio`:
#'   `"coerente"` (ogni braccio ha un solo livello in ogni fattore di Atlas e i due bracci differiscono in un
#'   solo fattore), `"piu_fattori"`, `"braccio_misto"`, `"nessuna_differenza"`, `"fuori_atlas"` (un braccio non
#'   ha campioni nell'universo), `"non_applicabile"` (la sola differenza e' un livello `TF_NON_APPLICABILE`:
#'   non si giudica, si conta a parte). Errore = `piu_fattori` o `braccio_misto`.
#' @keywords internal
tf_giudica_non_elencati <- function(nostri, atlas, universo, annidato = TRUE, non_scritto_conta = FALSE) {
  .tf_controlla_confronti(nostri, "nostri"); .tf_controlla_confronti(atlas$confronti, "atlas$confronti")
  universo <- as.character(universo)
  # Scambio i ruoli: per ogni NOSTRO confronto cerco un confronto di Atlas con gli stessi insiemi.
  elencato <- .tf_abbina(atlas$confronti, nostri, universo) != "no"
  fuori <- nostri[!elencato, , drop = FALSE]
  fuori$trattato <- lapply(fuori$trattato, .tf_taglia, universo = universo)
  fuori$controllo <- lapply(fuori$controllo, .tf_taglia, universo = universo)
  giudizio <- character(nrow(fuori))
  annidati <- if (nrow(fuori) > 0L && !is.null(atlas$tabella)) .tf_annidati(atlas$tabella$livelli) else NULL
  for (i in seq_len(nrow(fuori))) {
    tr <- fuori$trattato[[i]]; co <- fuori$controllo[[i]]
    if (length(tr) == 0L || length(co) == 0L) {
      giudizio[i] <- "fuori_atlas"
      next
    }
    misto <- any(lengths(.tf_livelli_braccio(tr, atlas$tabella)) > 1L) ||
      any(lengths(.tf_livelli_braccio(co, atlas$tabella)) > 1L)
    fd <- .tf_fattori_diversi(tr, co, atlas$tabella, annidati, annidato = annidato,
                              non_scritto_conta = non_scritto_conta)
    n_diversi <- length(fd$diversi)
    giudizio[i] <- if (misto) {
      "braccio_misto"
    } else if (n_diversi > 1L) {
      "piu_fattori"
    } else if (n_diversi == 1L && fd$solo_x) {
      "non_applicabile"
    } else if (n_diversi == 1L) {
      "coerente"
    } else {
      "nessuna_differenza"
    }
  }
  fuori$giudizio <- giudizio
  rownames(fuori) <- NULL
  fuori
}

#' Le tre misure su uno studio, in una riga
#'
#' @param studio chr, il nome dello studio.
#' @param nostra la nostra partizione (GSM -> gruppo); `character(0)` se non abbiamo gruppi.
#' @param nostri i nostri confronti in forma comune (anche zero righe).
#' @param atlas l'uscita di `atlas_tabella()`.
#' @param universo chr, i GSM che contano.
#' @param n_min numero minimo di campioni per braccio per i confronti di Atlas.
#' @param lettura la lettura del riferimento (spec par. 5.5 punto 3, aggiornamento S12r2), senza valore di
#'   default: `"principale"` (regola del fattore annidato, tempo zero fuori dal denominatore di (b), un fattore
#'   non scritto non conta), `"intera"` (nessuna regola del fattore annidato, tempo zero dentro: la definizione
#'   di S12r), `"stretta"` (come la principale, ma un fattore non scritto conta come differenza).
#' @param campi_tempo l'uscita di `tf_campi_di_tempo()`: obbligatoria per le letture principale e stretta (una
#'   lista vuota se lo studio non ha campi di tempo). Con la lettura intera e `NULL` la marca non si calcola.
#' @param contesto_fuori se `TRUE` i confronti di Atlas con la marca `solo_contesto` escono dal denominatore
#'   di (b) (spec par. 5.5, aggiornamento S12r3; decisione del PI del 2026-11-11). Vale per le letture principale
#'   e stretta; con la lettura intera e' un errore. Il default `FALSE` e' la misura della prova ripetuta S12r2.
#' @return lista con `riga` (data.frame di una riga con i conteggi), `atlas` (i confronti di Atlas con `classe`,
#'   `tempo_zero`, `solo_contesto`, `in_b` e `ritrovato`), `non_elencati` (i nostri confronti non elencati con `giudizio`). Nella
#'   riga, `n_b_den` e' il denominatore della misura (b) secondo la lettura e `n_b_uguale` il numeratore;
#'   `n_solo_contesto` conta i confronti con la marca `solo_contesto`, dentro o fuori dal denominatore.
#' @keywords internal
tf_misura_studio <- function(studio, nostra, nostri, atlas, universo, n_min = 2L, lettura, campi_tempo = NULL,
                             contesto_fuori = FALSE) {
  letture <- list(principale = list(annidato = TRUE, tempo_zero_fuori = TRUE, non_scritto_conta = FALSE),
                  intera = list(annidato = FALSE, tempo_zero_fuori = FALSE, non_scritto_conta = FALSE),
                  stretta = list(annidato = TRUE, tempo_zero_fuori = TRUE, non_scritto_conta = TRUE))
  if (missing(lettura) || !is.character(lettura) || length(lettura) != 1L || !(lettura %in% names(letture))) {
    .tf_abort(sprintf("`lettura` va dichiarata, una fra: %s.", paste(names(letture), collapse = ", ")),
              "ingresso_non_valido")
  }
  regola <- letture[[lettura]]
  if (regola$tempo_zero_fuori && is.null(campi_tempo)) {
    .tf_abort(sprintf(paste0("La lettura \"%s\" toglie i confronti col tempo zero: servono i campi di tempo ",
                             "(`tf_campi_di_tempo()`; una lista vuota se lo studio non ne ha)."), lettura),
              "ingresso_non_valido")
  }
  if (!is.logical(contesto_fuori) || length(contesto_fuori) != 1L || is.na(contesto_fuori)) {
    .tf_abort("`contesto_fuori` deve essere TRUE o FALSE.", "ingresso_non_valido")
  }
  if (contesto_fuori && lettura == "intera") {
    .tf_abort(paste0("La lettura \"intera\" e' la definizione di S12r: non toglie i confronti di solo contesto. ",
                     "Usa `contesto_fuori = FALSE`."), "ingresso_non_valido")
  }
  universo <- as.character(universo)
  nostra <- .tf_controlla_partizione(nostra, "nostra")
  g <- tf_misura_gruppi(nostra[names(nostra) %in% universo],
                        atlas$partizione[names(atlas$partizione) %in% universo])
  cl <- tf_classi_confronti_atlas(atlas, universo, n_min, annidato = regola$annidato,
                                  non_scritto_conta = regola$non_scritto_conta, campi_tempo = campi_tempo)
  cl <- tf_misura_ritrovati(nostri, cl, universo)
  ne <- tf_giudica_non_elencati(nostri, atlas, universo, annidato = regola$annidato,
                                non_scritto_conta = regola$non_scritto_conta)
  conta <- function(x, v) as.integer(sum(x %in% v))
  rispetta <- cl$classe == "rispetta"; piu <- cl$classe == "piu_fattori"
  zero <- cl$tempo_zero %in% TRUE
  cl$in_b <- rispetta & !(regola$tempo_zero_fuori & zero) & !(contesto_fuori & cl$solo_contesto)
  n_zero <- function(quali) if (is.null(campi_tempo)) NA_integer_ else as.integer(sum(zero & quali))
  riga <- data.frame(
    studio = studio, lettura = lettura, classe_gruppi = g$classe, ari = g$ari, n_universo = length(universo),
    n_comuni = g$n_comuni, solo_nostri = g$solo_nostri, solo_atlas = g$solo_atlas,
    n_atlas = nrow(cl), n_rispetta = conta(cl$classe, "rispetta"),
    n_rispetta_uguale = conta(cl$ritrovato[rispetta], "uguale"),
    n_rispetta_verso_opposto = conta(cl$ritrovato[rispetta], "verso_opposto"),
    n_b_den = as.integer(sum(cl$in_b)), n_b_uguale = conta(cl$ritrovato[cl$in_b], "uguale"),
    n_b_verso_opposto = conta(cl$ritrovato[cl$in_b], "verso_opposto"),
    n_solo_contesto = as.integer(sum(cl$solo_contesto)),
    n_tempo_zero = n_zero(TRUE), n_tempo_zero_rispetta = n_zero(rispetta),
    n_tempo_zero_controllo = n_zero(cl$tempo_zero_verso %in% "zero_controllo"),
    n_tempo_zero_trattato = n_zero(cl$tempo_zero_verso %in% "zero_trattato"),
    n_tempo_zero_formati = n_zero(cl$ritrovato %in% c("uguale", "verso_opposto")),
    n_non_applicabile_atlas = conta(cl$classe, "non_applicabile"),
    n_piu_fattori = conta(cl$classe, "piu_fattori"),
    n_piu_fattori_formati = conta(cl$ritrovato[piu], c("uguale", "verso_opposto")),
    n_non_formabile = conta(cl$classe, "non_formabile"),
    n_nessuna_differenza_atlas = conta(cl$classe, "nessuna_differenza"),
    n_nostri = nrow(nostri), n_non_elencati = nrow(ne),
    n_giudicabili = conta(ne$giudizio, c("coerente", "piu_fattori", "braccio_misto", "nessuna_differenza")),
    n_errori = conta(ne$giudizio, c("piu_fattori", "braccio_misto")),
    n_coerente = conta(ne$giudizio, "coerente"), n_piu_fattori_nostri = conta(ne$giudizio, "piu_fattori"),
    n_braccio_misto = conta(ne$giudizio, "braccio_misto"),
    n_nessuna_differenza = conta(ne$giudizio, "nessuna_differenza"),
    n_fuori_atlas = conta(ne$giudizio, "fuori_atlas"),
    n_non_applicabile_nostri = conta(ne$giudizio, "non_applicabile"), stringsAsFactors = FALSE)
  list(riga = riga, atlas = cl, non_elencati = ne)
}

#' Riassume le misure di piu' studi, con l'intervallo al 95% dal bootstrap sugli studi
#'
#' L'unita' del bootstrap e' lo studio: si ricampionano le righe di `per_studio` e si ricalcola la quota come
#' rapporto fra le somme. Il generatore globale di numeri casuali non cambia.
#'
#' @param per_studio data.frame: le righe `riga` di `tf_misura_studio()`, una per studio.
#' @param B numero di ricampionamenti.
#' @param seme seme del bootstrap.
#' @return data.frame con `misura`, `numeratore`, `denominatore`, `quota`, `ic_basso`, `ic_alto`. Numeri
#'   principali: `a_gruppi_identici` (studi con classe `identica` su studi misurati), `b_confronti_ritrovati`
#'   (`uguale` sul denominatore della lettura: `n_b_uguale` su `n_b_den`), `c_errori_non_elencati` (errori su
#'   confronti giudicabili). A parte: `a_identici_sui_comuni` (partizioni uguali sui campioni comuni che omettono
#'   campioni di Atlas), `verso_opposto`, `atlas_piu_fattori` (su tutti i confronti di Atlas),
#'   `atlas_piu_fattori_formati`, `atlas_non_formabile`, `atlas_tempo_zero` (confronti con la marca `tempo_zero`
#'   su tutti i confronti di Atlas; `NA` se la marca non e' stata calcolata), `ari_mediana` (la quota e' la
#'   mediana; il denominatore e' il numero di studi). Le righe devono venire tutte dalla stessa lettura.
#'   Con denominatore zero la quota e' `NA`.
#'   Uno studio con `classe_gruppi` `NA` esce dal denominatore di (a), con un avviso di classe
#'   `simulomicsr_tf_studi_senza_classe` che lo nomina.
#' @keywords internal
tf_riassumi_misure <- function(per_studio, B = 2000L, seme = 20261109L) {
  if (!is.data.frame(per_studio) || nrow(per_studio) == 0L) {
    .tf_abort("`per_studio` deve essere un data.frame con almeno uno studio.", "ingresso_non_valido")
  }
  if (length(unique(per_studio$lettura)) != 1L) {
    .tf_abort(sprintf("Le righe di `per_studio` vengono da letture diverse: %s.",
                      .tf_elenca(unique(per_studio$lettura))), "ingresso_non_valido")
  }
  misurato <- !is.na(per_studio$classe_gruppi)
  if (any(!misurato)) {
    # Nessuna uscita silenziosa dal denominatore: chi vuole questi studi in (a) scrive la classe prima di chiamare.
    rlang::warn(sprintf(paste0("%d studi su %d non hanno una classe dei gruppi (nessun campione comune) ed escono ",
                               "dal denominatore di (a): %s. Restano nei denominatori di (b) e di (c)."),
                        sum(!misurato), nrow(per_studio), .tf_elenca(per_studio$studio[!misurato])),
                class = "simulomicsr_tf_studi_senza_classe")
  }
  rapporti <- list(
    a_gruppi_identici = list(num = as.numeric(misurato & per_studio$classe_gruppi %in% "identica"),
                             den = as.numeric(misurato)),
    b_confronti_ritrovati = list(num = per_studio$n_b_uguale, den = per_studio$n_b_den),
    c_errori_non_elencati = list(num = per_studio$n_errori, den = per_studio$n_giudicabili),
    a_identici_sui_comuni = list(num = as.numeric(misurato & per_studio$classe_gruppi %in% "identica_sui_comuni"),
                                 den = as.numeric(misurato)),
    verso_opposto = list(num = per_studio$n_b_verso_opposto, den = per_studio$n_b_den),
    atlas_tempo_zero = list(num = per_studio$n_tempo_zero, den = per_studio$n_atlas),
    atlas_piu_fattori = list(num = per_studio$n_piu_fattori, den = per_studio$n_atlas),
    atlas_piu_fattori_formati = list(num = per_studio$n_piu_fattori_formati, den = per_studio$n_piu_fattori),
    atlas_non_formabile = list(num = per_studio$n_non_formabile, den = per_studio$n_atlas))
  quota <- function(num, den) if (sum(den) > 0) sum(num) / sum(den) else NA_real_
  mediana <- function(x) if (any(!is.na(x))) stats::median(x, na.rm = TRUE) else NA_real_

  # Il bootstrap non tocca il generatore globale.
  ha_seme <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  seme_prima <- if (ha_seme) get(".Random.seed", envir = globalenv(), inherits = FALSE) else NULL
  on.exit({
    if (ha_seme) {
      assign(".Random.seed", seme_prima, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  }, add = TRUE)
  set.seed(seme)
  n <- nrow(per_studio)
  estrazioni <- matrix(sample.int(n, n * B, replace = TRUE), nrow = B)
  ic <- function(f) {
    v <- apply(estrazioni, 1L, f)
    if (all(is.na(v))) return(c(NA_real_, NA_real_))
    unname(stats::quantile(v, c(0.025, 0.975), na.rm = TRUE, names = FALSE))
  }

  righe <- lapply(names(rapporti), function(m) {
    r <- rapporti[[m]]
    i <- ic(function(idx) quota(r$num[idx], r$den[idx]))
    data.frame(misura = m, numeratore = sum(r$num), denominatore = sum(r$den), quota = quota(r$num, r$den),
               ic_basso = i[1], ic_alto = i[2], stringsAsFactors = FALSE)
  })
  i <- ic(function(idx) mediana(per_studio$ari[idx]))
  righe[[length(righe) + 1L]] <- data.frame(
    misura = "ari_mediana", numeratore = NA_real_, denominatore = sum(!is.na(per_studio$ari)),
    quota = mediana(per_studio$ari), ic_basso = i[1], ic_alto = i[2], stringsAsFactors = FALSE)
  do.call(rbind, righe)
}
