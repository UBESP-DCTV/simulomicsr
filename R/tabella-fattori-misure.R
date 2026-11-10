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
#' @return lista con `classe` (`"identica"`, `"piu_fine"`: ogni nostro gruppo sta in un gruppo di Atlas,
#'   `"piu_grossa"`, `"incrociata"`; `NA` senza campioni comuni), `ari` (indice di Rand corretto), `n_comuni`,
#'   `solo_nostri`, `solo_atlas`.
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
    "identica"
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
#' @keywords internal
#' @noRd
.tf_fattori_diversi <- function(trattato, controllo, tabella) {
  lt <- .tf_livelli_braccio(trattato, tabella); lc <- .tf_livelli_braccio(controllo, tabella)
  diverso <- !vapply(names(lt), function(f) identical(lt[[f]], lc[[f]]), TRUE)
  # Come in `tf_confronti()`: un fattore che uno dei due bracci non scrive non e' una differenza, si marca.
  non_scritto <- vapply(names(lt), function(f) {
    identical(lt[[f]], TF_NON_SCRITTO) || identical(lc[[f]], TF_NON_SCRITTO)
  }, TRUE)
  list(diversi = names(lt)[diverso & !non_scritto], non_scritti = names(lt)[diverso & non_scritto])
}

#' Classifica i confronti dei curatori di Atlas rispetto alla definizione
#'
#' @param atlas l'uscita di `atlas_tabella()`.
#' @param universo chr, i GSM che contano.
#' @param n_min numero minimo di campioni per braccio dopo il taglio all'universo.
#' @return i confronti di Atlas con i bracci tagliati all'universo e le colonne `classe`, `fattori_diversi` e
#'   `fattori_non_scritti` (i fattori che uno dei due bracci non scrive: non contano come differenza).
#'   `classe`: `"rispetta"` (i due gruppi differiscono in un solo fattore di Atlas), `"piu_fattori"`,
#'   `"non_formabile"` (un braccio ha meno di `n_min` campioni nell'universo), `"nessuna_differenza"` (i due
#'   gruppi hanno gli stessi livelli in tutti i fattori di Atlas).
#' @keywords internal
tf_classi_confronti_atlas <- function(atlas, universo, n_min = 2L) {
  k <- .tf_controlla_confronti(atlas$confronti, "atlas$confronti")
  universo <- as.character(universo)
  k$trattato <- lapply(k$trattato, .tf_taglia, universo = universo)
  k$controllo <- lapply(k$controllo, .tf_taglia, universo = universo)
  classe <- character(nrow(k)); diversi <- character(nrow(k)); non_scritti <- character(nrow(k))
  for (i in seq_len(nrow(k))) {
    tr <- k$trattato[[i]]; co <- k$controllo[[i]]
    if (length(tr) < n_min || length(co) < n_min) {
      classe[i] <- "non_formabile"; diversi[i] <- NA_character_; non_scritti[i] <- NA_character_
      next
    }
    fd <- .tf_fattori_diversi(tr, co, atlas$tabella)
    d <- fd$diversi
    diversi[i] <- .tf_dettaglio(d); non_scritti[i] <- .tf_dettaglio(fd$non_scritti)
    classe[i] <- if (length(d) == 1L) "rispetta" else if (length(d) > 1L) "piu_fattori" else "nessuna_differenza"
  }
  k$classe <- classe
  k$fattori_diversi <- diversi
  k$fattori_non_scritti <- non_scritti
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
#' @return i nostri confronti non elencati, con i bracci tagliati all'universo e la colonna `giudizio`:
#'   `"coerente"` (ogni braccio ha un solo livello in ogni fattore di Atlas e i due bracci differiscono in un
#'   solo fattore), `"piu_fattori"`, `"braccio_misto"`, `"nessuna_differenza"`, `"fuori_atlas"` (un braccio non
#'   ha campioni nell'universo). Errore = `piu_fattori` o `braccio_misto`.
#' @keywords internal
tf_giudica_non_elencati <- function(nostri, atlas, universo) {
  .tf_controlla_confronti(nostri, "nostri"); .tf_controlla_confronti(atlas$confronti, "atlas$confronti")
  universo <- as.character(universo)
  # Scambio i ruoli: per ogni NOSTRO confronto cerco un confronto di Atlas con gli stessi insiemi.
  elencato <- .tf_abbina(atlas$confronti, nostri, universo) != "no"
  fuori <- nostri[!elencato, , drop = FALSE]
  fuori$trattato <- lapply(fuori$trattato, .tf_taglia, universo = universo)
  fuori$controllo <- lapply(fuori$controllo, .tf_taglia, universo = universo)
  giudizio <- character(nrow(fuori))
  for (i in seq_len(nrow(fuori))) {
    tr <- fuori$trattato[[i]]; co <- fuori$controllo[[i]]
    if (length(tr) == 0L || length(co) == 0L) {
      giudizio[i] <- "fuori_atlas"
      next
    }
    misto <- any(lengths(.tf_livelli_braccio(tr, atlas$tabella)) > 1L) ||
      any(lengths(.tf_livelli_braccio(co, atlas$tabella)) > 1L)
    n_diversi <- length(.tf_fattori_diversi(tr, co, atlas$tabella)$diversi)
    giudizio[i] <- if (misto) {
      "braccio_misto"
    } else if (n_diversi > 1L) {
      "piu_fattori"
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
#' @return lista con `riga` (data.frame di una riga con i conteggi), `atlas` (i confronti di Atlas con `classe`
#'   e `ritrovato`), `non_elencati` (i nostri confronti non elencati con `giudizio`).
#' @keywords internal
tf_misura_studio <- function(studio, nostra, nostri, atlas, universo, n_min = 2L) {
  universo <- as.character(universo)
  nostra <- .tf_controlla_partizione(nostra, "nostra")
  g <- tf_misura_gruppi(nostra[names(nostra) %in% universo],
                        atlas$partizione[names(atlas$partizione) %in% universo])
  cl <- tf_misura_ritrovati(nostri, tf_classi_confronti_atlas(atlas, universo, n_min), universo)
  ne <- tf_giudica_non_elencati(nostri, atlas, universo)
  conta <- function(x, v) as.integer(sum(x %in% v))
  rispetta <- cl$classe == "rispetta"; piu <- cl$classe == "piu_fattori"
  riga <- data.frame(
    studio = studio, classe_gruppi = g$classe, ari = g$ari, n_universo = length(universo),
    n_comuni = g$n_comuni, solo_nostri = g$solo_nostri, solo_atlas = g$solo_atlas,
    n_atlas = nrow(cl), n_rispetta = conta(cl$classe, "rispetta"),
    n_rispetta_uguale = conta(cl$ritrovato[rispetta], "uguale"),
    n_rispetta_verso_opposto = conta(cl$ritrovato[rispetta], "verso_opposto"),
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
    n_fuori_atlas = conta(ne$giudizio, "fuori_atlas"), stringsAsFactors = FALSE)
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
#'   (`uguale` su confronti di classe `rispetta`), `c_errori_non_elencati` (errori su confronti giudicabili).
#'   A parte: `verso_opposto`, `atlas_piu_fattori` (su tutti i confronti di Atlas), `atlas_piu_fattori_formati`,
#'   `atlas_non_formabile`, `ari_mediana` (la quota e' la mediana; il denominatore e' il numero di studi).
#'   Con denominatore zero la quota e' `NA`.
#' @keywords internal
tf_riassumi_misure <- function(per_studio, B = 2000L, seme = 20261109L) {
  if (!is.data.frame(per_studio) || nrow(per_studio) == 0L) {
    .tf_abort("`per_studio` deve essere un data.frame con almeno uno studio.", "ingresso_non_valido")
  }
  misurato <- !is.na(per_studio$classe_gruppi)
  rapporti <- list(
    a_gruppi_identici = list(num = as.numeric(misurato & per_studio$classe_gruppi %in% "identica"),
                             den = as.numeric(misurato)),
    b_confronti_ritrovati = list(num = per_studio$n_rispetta_uguale, den = per_studio$n_rispetta),
    c_errori_non_elencati = list(num = per_studio$n_errori, den = per_studio$n_giudicabili),
    verso_opposto = list(num = per_studio$n_rispetta_verso_opposto, den = per_studio$n_rispetta),
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
