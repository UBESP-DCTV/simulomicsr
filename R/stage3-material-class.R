# R/stage3-material-class.R --- il gruppo mescola materiale di paziente e
# sistemi in vitro?
#
# NATO DA UNA MISURA. Il Layer B del 2026-07-31 ha mostrato che il gruppo
# Parkinson (k=10, marcato "coerente") ha il 73% del peso su GSE181029, che non
# e' cervello di paziente ma progenitori e neuroni derivati da iPSC con mutazione
# PARK2. Leggendo TUTTI e 20 i gruppi di malattia si e' visto che la stessa forma
# c'e' in almeno sei: Huntington (progenitori gliali, 57%), spondilite anchilosante
# (differenziamento adipogenico, 80%), colorettale (sferoidi, 47%), carcinoma
# renale (colture, 31%), diabete gestazionale (progenitori endoteliali, 11%).
# Ritrattare il verdetto del solo Parkinson sarebbe stata una lista scritta a
# mano — l'errore che questo progetto ha gia' pagato.
#
# CHE COSA E' E CHE COSA NON E'. Non e' un classificatore di materiale biologico
# e non decide la coerenza. E' un rilevatore di UN segnale dichiarato — "questo
# braccio nomina un sistema in vitro" — con un vocabolario esplicito e visibile,
# che aggiunge una colonna al deliverable. La lettura del testo resta il metro;
# questo dice solo DOVE guardare, su tutti e 191 invece che sui pochi capitati
# sotto gli occhi.
#
# LIMITE DICHIARATO. Il vocabolario e' costruito sui gruppi di malattia letti a
# mano e non copre i nomi propri delle linee cellulari (ce ne sono migliaia).
# Un gruppo interamente su linee cellulari senza la parola "cell(s)"/"line"
# risultera' `unknown`, non `model`. L'accordo col giudizio umano e' misurato in
# `analysis/audit/2026-07-31-layer-b-v13/`, disaccordi compresi.

# Sistemi in vitro. Ogni voce e' una PAROLA INTERA o una sequenza di parole
# intere; l'underscore vale come separatore (per le regex `_` e' carattere di
# parola, ed e' gia' costato una regola cieca il 2026-07-26).
.MATERIAL_MODEL_TERMS <- c(
  "ipsc", "ipscs", "ips", "hipsc", "hipscs",
  "esc", "escs", "hesc", "hescs", "embryonic stem",
  "induced pluripotent", "pluripotent",
  "organoid", "organoids", "spheroid", "spheroids",
  "cell line", "cell lines", "immortalized", "immortalised",
  "passage", "xenograft", "xenografts",
  "in vitro", "cultured", "culture", "cultures",
  "progenitor", "progenitors",
  "derived", "differentiation", "differentiated",
  "cells", "transfected", "transduced"
)

# Materiale primario di paziente o donatore.
.MATERIAL_PRIMARY_TERMS <- c(
  "tissue", "tissues", "biopsy", "biopsies", "resection", "specimen",
  "post-mortem", "postmortem", "autopsy", "necropsy",
  "pbmc", "pbmcs", "whole blood", "blood", "plasma", "serum",
  "mucosa", "cortex", "nigra", "amygdala", "gyrus", "placenta", "placental",
  "patient", "patients", "donor", "donors", "subject", "subjects",
  "brain", "liver", "kidney", "colon", "lung", "skin", "muscle"
)

#' Classifica un'etichetta di braccio: sistema in vitro, materiale primario, ignoto
#'
#' Il segnale "in vitro" ha la precedenza: `"patient-derived spheroids"` nomina
#' entrambi ma resta un sistema in vitro, e il marcatore in vitro e' il piu'
#' specifico dei due.
#'
#' Il confronto e' a **parola intera** su testo normalizzato in cui gli
#' underscore diventano spazi: senza questo `"lung_organoid"` non verrebbe
#' riconosciuto, e `"descending"` accenderebbe `"esc"`.
#'
#' @param label character (vettorizzato). `NA` e stringa vuota danno `"unknown"`.
#' @return character dello stesso ordine e lunghezza: `"model"`, `"primary"`
#'   oppure `"unknown"`.
#' @keywords internal
.classify_material <- function(label) {
  if (length(label) == 0L) return(character(0L))
  x <- tolower(as.character(label))
  x[is.na(x)] <- ""
  # underscore, trattini e punteggiatura diventano separatori, cosi' il match a
  # parola intera vede davvero le parole
  x <- gsub("[^a-z0-9 ]+", " ", x)
  x <- gsub("\\s+", " ", trimws(x))
  # spazi ai bordi: cosi' " parola " matcha anche a inizio/fine stringa
  padded <- paste0(" ", x, " ")

  has_any <- function(termini) {
    Reduce(`|`, lapply(termini, function(t) {
      grepl(paste0(" ", gsub("[^a-z0-9 ]+", " ", t), " "), padded, fixed = TRUE)
    }), init = rep(FALSE, length(padded)))
  }

  model   <- has_any(.MATERIAL_MODEL_TERMS)
  primary <- has_any(.MATERIAL_PRIMARY_TERMS)

  out <- rep("unknown", length(padded))
  out[primary] <- "primary"
  out[model] <- "model"   # il segnale in vitro vince, e va applicato per ultimo
  out[!nzchar(x)] <- "unknown"
  out
}

#' Marca i cluster che mescolano sistemi in vitro e materiale primario
#'
#' Uno studio conta **una volta sola**, col segnale piu' forte fra le sue
#' etichette (in vitro > primario > ignoto): altrimenti un solo studio con due
#' bracci diversamente descritti farebbe sembrare misto un gruppo che non lo e'.
#'
#' Gli `unknown` **non** contribuiscono alla marcatura: si dichiara ciò che si
#' vede, non si indovina il resto.
#'
#' @param membri data.frame con `cluster_id`, `study_id`, `label` (una riga per
#'   braccio o per confronto; le etichette dei due bracci vanno passate come
#'   righe separate).
#' @return data.frame con `cluster_id`, `materiale_misto`, `n_studi_model`,
#'   `n_studi_primary`, `n_studi_unknown`.
#' @export
detect_mixed_material <- function(membri) {
  if (nrow(membri) == 0L) {
    return(data.frame(cluster_id = character(), materiale_misto = logical(),
                      n_studi_model = integer(), n_studi_primary = integer(),
                      n_studi_unknown = integer(), stringsAsFactors = FALSE))
  }
  cls <- .classify_material(membri$label)
  rango <- c(unknown = 0L, primary = 1L, model = 2L)

  chiave <- paste(membri$cluster_id, membri$study_id, sep = "\r")
  per_studio <- vapply(split(rango[cls], chiave), max, integer(1L))
  cluster_di <- sub("\r.*$", "", names(per_studio))

  conta <- function(v) {
    vapply(split(per_studio == v, cluster_di), sum, integer(1L))
  }
  n_model   <- conta(2L)
  n_primary <- conta(1L)
  n_unknown <- conta(0L)

  out <- data.frame(
    cluster_id      = names(n_model),
    materiale_misto = as.logical(n_model > 0L & n_primary > 0L),
    n_studi_model   = as.integer(n_model),
    n_studi_primary = as.integer(n_primary),
    n_studi_unknown = as.integer(n_unknown),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}
