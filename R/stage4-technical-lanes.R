# Le corsie di sequenziamento non sono repliche.
#
# IL DIFETTO. `n_min` (`R/stage4-dispatch.R`, riga 374) ammette un confronto se
# ogni braccio ha almeno due CAMPIONI. Ma quando un sottomettente deposita in GEO
# una libreria spezzata sulle corsie di un flowcell, ogni corsia diventa un GSM:
# due GSM possono essere lo stesso materiale biologico letto due volte. La
# varianza intra-braccio che limma-voom stima diventa allora rumore di
# SEQUENZIAMENTO, non biologia, l'errore standard esce troppo piccolo e nella
# meta-analisi a inverso della varianza quello studio pesa troppo.
#
# MISURA SUL DELIVERABLE v15 (2026-08-12, tutte e 2.152 le entry del dispatch):
# 9 entry toccate in 4 studi. Il caso grave e' GSE173902, 36 GSM = 18 campioni
# biologici x 2 corsie, con UN SOLO campione per condizione: i suoi confronti
# hanno un SE mediano da 0,19 a 0,39 volte quello dei pari nello stesso gruppo, e
# pesa il 76% in *Staphylococcus aureus* e in *S. epidermidis* (equipeso 25% e
# 33%). Sommando le corsie quei bracci restano con un campione l'uno e il
# confronto non e' piu' calcolabile — che e' la conclusione giusta.
#
# PERCHE' IL BIOSAMPLE NON BASTA, benche' copra il 100% dei campioni. In
# GSE178340 le quattro corsie della stessa libreria (`ATRA1_S4_L001..L004`) hanno
# QUATTRO BioSample distinti: l'identificativo eredita l'errore del
# sottomettente. E l'unico SAMN condiviso di tutto il poolato (GSE98984) copre
# quattro campioni che stanno sui DUE bracci opposti: dedurne identita' avrebbe
# unito trattato e controllo. Non e' un criterio, in nessuna delle due direzioni.
#
# PERCHE' NON BASTA NEMMENO IL PROFILO DI ESPRESSIONE. Due corsie della stessa
# libreria correlano a 0,977-0,996 (Pearson su log-CPM dei geni espressi), ma
# repliche BIOLOGICHE di linee cellulari arrivano a 0,9955: le due distribuzioni
# si toccano. La correlazione genera candidati, non verdetti.
#
# RESTA IL TITOLO, con tre guardie dettate dai FALSI POSITIVI trovati sul corpus.
# La regola nuda del titolo, applicata a tutto l'H5, produce 4.360 librerie
# collassanti di cui **solo il 45,3% ha `characteristics_ch1` identici**: unisce i
# POZZETTI di una piastra. In GSE145815 `1001703001_L1` ha `well: L1` e
# `1001703001_L10` ha `well: L10`, con `moi: 0` contro `moi: 0.1` — un controllo e
# un trattato. Le guardie portano le librerie da 4.360 a 1.717 e gli studi da 107
# a 50; i quattro studi del deliverable le superano tutte.
#
# COSA NON E' IMPLEMENTATO, e perche':
#   * il marcatore `run N`. In GSE62544 `STT516_run_1` e `STT516_run_2` possono
#     essere due letture della stessa libreria o due esperimenti: nessuna prova
#     nei metadati. Non tocca nessuna delle 214 (misurato: 0 entry). Una regola
#     che non si sa difendere non entra.
#   * il filtro sul single-cell. 836 delle 1.717 librerie superstiti vengono da
#     studi con `singlecellprobability > 0,5`; nessuna di esse e' nel deliverable.
#
# NB: il meccanismo e' SPENTO di default (`lane_lookup = NULL`); con NULL il
# comportamento e' identico a quello di oggi.

#' Numero massimo di corsie per libreria
#'
#' Vincolo fisico: un flowcell Illumina ha al piu' 8 corsie. Una "libreria" con
#' 23 o 24 membri non e' un insieme di corsie — sono pozzetti di una piastra.
#' @keywords internal
.LANE_MAX_PER_LIBRARY <- 8L

#' Toglie dal titolo i marcatori di corsia
#'
#' @param x character, i titoli GEO.
#' @return character, il titolo senza il marcatore di corsia.
#' @keywords internal
.lane_strip <- function(x) {
  y <- tolower(trimws(x))
  y <- gsub("[._-]l0*[0-9]{1,3}([._-]|$)", "\\1", y)
  y <- gsub("[._-]lane[ _-]?0*[0-9]{1,3}([._-]|$)", "\\1", y)
  gsub("[._-]+$", "", y)
}

#' Estrae l'indice di corsia dal titolo
#'
#' @param x character, i titoli GEO.
#' @return integer, l'indice di corsia o NA se il titolo non ne dichiara uno.
#' @keywords internal
.lane_index <- function(x) {
  y <- tolower(trimws(x))
  out <- rep(NA_integer_, length(y))
  for (rx in c("[._-]l0*[0-9]{1,3}([._-]|$)",
               "[._-]lane[ _-]?0*[0-9]{1,3}([._-]|$)")) {
    m <- regexpr(rx, y)
    k <- m > 0L & is.na(out)
    if (any(k)) {
      out[k] <- suppressWarnings(
        as.integer(gsub("[^0-9]", "", regmatches(y, m)[cumsum(m > 0L)[k]]))
      )
    }
  }
  out
}

#' Costruisce la corrispondenza campione -> libreria di sequenziamento
#'
#' Un campione entra nella corrispondenza SOLO se sta in una libreria da piu'
#' campioni che supera tutte e tre le guardie (vedi la testata del file). Gli
#' altri campioni non compaiono: chi consuma la corrispondenza li tratta come
#' librerie a se'.
#'
#' @param h5_metadata data.frame con \code{geo_accession}, \code{title},
#'   \code{series_id}, \code{characteristics_ch1}, \code{source_name_ch1}.
#' @param max_lanes integer, la guardia di cardinalita' (default 8).
#' @return named character: nome = \code{geo_accession}, valore = chiave della
#'   libreria. Lunghezza 0 se non c'e' nulla da unire. L'attributo
#'   \code{"scartate"} elenca le librerie candidate bloccate e da quale guardia.
#' @export
build_lane_library_lookup <- function(h5_metadata, max_lanes = .LANE_MAX_PER_LIBRARY) {
  serve <- c("geo_accession", "title", "series_id",
             "characteristics_ch1", "source_name_ch1")
  manca <- setdiff(serve, names(h5_metadata))
  if (length(manca) > 0L) {
    stop("h5_metadata non ha le colonne necessarie: ", paste(manca, collapse = ", "))
  }
  vuoto <- structure(character(0),
                     scartate = data.frame(lib = character(), n = integer(),
                                           motivo = character(),
                                           stringsAsFactors = FALSE))
  if (nrow(h5_metadata) == 0L) return(vuoto)

  gsm  <- as.character(h5_metadata$geo_accession)
  ti   <- as.character(h5_metadata$title)
  # La libreria vive DENTRO lo studio: due serie diverse non la condividono mai.
  chiave <- paste(as.character(h5_metadata$series_id), .lane_strip(ti), sep = "\r")

  # Titoli GIA' identici in partenza non sono un difetto di CORSIA (non e' la
  # regola a unirli): restano fuori, e chi li tratta e' la deduplica dei campioni.
  grezzo <- paste(as.character(h5_metadata$series_id), tolower(trimws(ti)), sep = "\r")
  tb_g <- table(grezzo)
  gia_uguali <- grezzo %in% names(tb_g)[tb_g > 1L]

  tb <- table(chiave)
  cand <- chiave %in% names(tb)[tb > 1L] & !gia_uguali
  if (!any(cand)) return(vuoto)

  idx <- split(which(cand), chiave[cand])
  lane <- .lane_index(ti)
  ch <- as.character(h5_metadata$characteristics_ch1)
  so <- as.character(h5_metadata$source_name_ch1)

  tenute <- character(0); scartate <- list()
  for (nm in names(idx)) {
    j <- idx[[nm]]
    motivo <- NA_character_
    if (length(j) > max_lanes) {
      motivo <- "cardinalita"                       # G1
    } else if (length(unique(ch[j])) > 1L || length(unique(so[j])) > 1L) {
      motivo <- "metadati_diversi"                  # G2
    } else if (anyNA(lane[j]) || any(lane[j] < 1L | lane[j] > max_lanes)) {
      motivo <- "indice_di_corsia"                  # G3
    }
    if (is.na(motivo)) {
      tenute <- c(tenute, nm)
    } else {
      scartate[[length(scartate) + 1L]] <-
        data.frame(lib = nm, n = length(j), motivo = motivo, stringsAsFactors = FALSE)
    }
  }
  sc <- if (length(scartate)) do.call(rbind, scartate) else
    data.frame(lib = character(), n = integer(), motivo = character(),
               stringsAsFactors = FALSE)
  if (length(tenute) == 0L) return(structure(character(0), scartate = sc))

  # `cand &` e non solo `chiave %in% tenute`: le guardie sono state valutate sui
  # soli campioni candidati, e un campione escluso prima (titolo gia' identico a
  # un altro) non deve rientrare dalla finestra ereditando la chiave di un gruppo
  # i cui metadati non sono mai stati controllati contro il suo.
  k <- cand & chiave %in% tenute
  structure(setNames(chiave[k], gsm[k]), scartate = sc)
}

#' Quante librerie distinte ci sono in un braccio
#'
#' Conta i CAMPIONI DISTINTI (un campione ripetuto nella stessa lista non e' una
#' replica) risolti in librerie. Un campione assente dalla corrispondenza vale
#' per se'.
#'
#' @param gsms character, i campioni del braccio.
#' @param lane_lookup output di \code{build_lane_library_lookup}, oppure NULL.
#' @return integer.
#' @keywords internal
.n_biological <- function(gsms, lane_lookup = NULL) {
  g <- unique(as.character(gsms))
  if (is.null(lane_lookup) || length(lane_lookup) == 0L) return(length(g))
  v <- lane_lookup[g]
  length(unique(ifelse(is.na(v), g, v)))
}

#' Somma le corsie della stessa libreria in una matrice di conte
#'
#' @param counts matrice geni x campioni, con i nomi di colonna.
#' @param treatment factor dei ruoli, allineato alle colonne.
#' @param lane_lookup output di \code{build_lane_library_lookup}, oppure NULL
#'   (allora non cambia nulla).
#' @return list con \code{counts}, \code{treatment} e \code{log} (una riga per
#'   libreria collassata).
#' @keywords internal
.collapse_technical_lanes <- function(counts, treatment, lane_lookup = NULL) {
  vuoto <- data.frame(libreria = character(), n_campioni = integer(),
                      campioni = character(), stringsAsFactors = FALSE)
  if (is.null(lane_lookup) || length(lane_lookup) == 0L || ncol(counts) == 0L) {
    return(list(counts = counts, treatment = treatment, log = vuoto))
  }
  cn <- colnames(counts)
  if (is.null(cn)) stop("counts deve avere i nomi di colonna (i campioni)")
  v <- lane_lookup[cn]
  chiave <- ifelse(is.na(v), cn, v)
  if (!anyDuplicated(chiave)) {
    return(list(counts = counts, treatment = treatment, log = vuoto))
  }
  ordine <- unique(chiave)                       # deterministico: prima comparsa
  lato <- vapply(ordine, function(k) {
    u <- unique(as.character(treatment)[chiave == k])
    if (length(u) > 1L) NA_character_ else u
  }, character(1))
  if (anyNA(lato)) {
    stop("una libreria di sequenziamento sta su tutti e due i bracci: ",
         paste(ordine[is.na(lato)], collapse = ", "))
  }
  m <- vapply(ordine, function(k) rowSums(counts[, chiave == k, drop = FALSE]),
              numeric(nrow(counts)))
  if (is.null(dim(m))) m <- matrix(m, nrow = nrow(counts))
  dimnames(m) <- list(rownames(counts), ordine)
  # Si torna a intero solo se ci sta: una somma di corsie puo' superare il
  # massimo di un intero R e diventerebbe NA con un warning, cioe' un gene perso
  # in silenzio dentro un fit.
  if (is.integer(counts) && all(is.finite(m)) && max(m) <= .Machine$integer.max) {
    storage.mode(m) <- "integer"
  }

  n_per <- as.integer(table(chiave)[ordine])
  lg <- data.frame(
    libreria = ordine[n_per > 1L], n_campioni = n_per[n_per > 1L],
    campioni = vapply(ordine[n_per > 1L],
                      function(k) paste(cn[chiave == k], collapse = ","), character(1)),
    stringsAsFactors = FALSE)
  list(counts = m,
       treatment = factor(lato, levels = levels(treatment)),
       log = lg)
}
