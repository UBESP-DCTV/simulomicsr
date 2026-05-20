#' Ordine canonical dei 13 segmenti dell'anchor v3
#'
#' Replica l'ordine canonical prodotto da \code{.extract_anchor_segments()}
#' (vedi \code{R/stage3-anchor-levels.R}). Tenuto qui localmente al modulo
#' Stage 4 per evitare dipendenza forzata da internal Stage 3.
#'
#' @return character(13)
#' @keywords internal
.canonical_anchor_order <- function() {
  c(
    "kind_effective", "agent_id", "variant_label",
    "dose_canonical", "duration_canonical", "phase_canonical",
    "cell_id", "context_kind", "cell_state",
    "subcellular", "tissue", "disease_status", "has_engineered"
  )
}

#' Segmenti attesi per un dato level (ordine canonical)
#'
#' Coerente con la semantica di \code{.build_anchor_for_level()}:
#' \itemize{
#'   \item L0..L3: tutti i 13 segmenti meno quelli dei tier droppati (D, C, B
#'         progressivamente). Hard_filters (\code{subcellular},
#'         \code{context_kind}) sono presenti.
#'   \item L4: solo tier S (3 segmenti: \code{kind_effective}, \code{agent_id},
#'         \code{tissue}). Hard_filters esclusi.
#' }
#'
#' @param level integer(1) in 0:4.
#' @param tier_assignment list dal config Stadio 3 (default
#'   \code{stage3_default_config()$tier_assignment}).
#' @return character vector di nomi di segmenti, nell'ordine canonical.
#' @keywords internal
.expected_segments_for_level <- function(level, tier_assignment = NULL) {
  stopifnot(length(level) == 1L, level %in% 0L:4L)
  if (is.null(tier_assignment)) {
    tier_assignment <- stage3_default_config()$tier_assignment
  }
  canonical <- .canonical_anchor_order()
  if (level == 4L) {
    return(canonical[canonical %in% tier_assignment$S])
  }
  dropped <- .dropped_segments_at_level(tier_assignment, level)
  canonical[!canonical %in% dropped]
}

#' Parsa un anchor_key group in una named list di segmenti
#'
#' Splitta su \code{|} e mappa nell'ordine canonical dei segmenti attesi per
#' il \code{level} indicato. Solleva errore se il count effettivo non matcha
#' lo schema atteso (segnale di corruzione del registry Stadio 3 o di un
#' anchor pair passato per errore).
#'
#' @param anchor_key character(1): anchor canonico v3 da un cluster
#'   \code{mode = "group"} (NON un pair anchor con \code{__VS__}).
#' @param level integer(1) in 0:4: deve essere il \code{level} del cluster
#'   da cui proviene l'anchor.
#' @param tier_assignment list dal config Stadio 3 (default
#'   \code{stage3_default_config()$tier_assignment}).
#' @return named list con i segmenti presenti al level, in ordine canonical.
#' @keywords internal
parse_anchor_canonical <- function(anchor_key, level, tier_assignment = NULL) {
  expected <- .expected_segments_for_level(level, tier_assignment)
  parts <- strsplit(anchor_key, "|", fixed = TRUE)[[1L]]
  if (length(parts) != length(expected)) {
    stop(sprintf(
      "anchor_key ha %d segmenti, atteso %d a level %d",
      length(parts), length(expected), level
    ))
  }
  setNames(as.list(parts), expected)
}

#' Parsa un anchor_key pair (forma \code{<treated>__VS__<control>__CT_<type>})
#'
#' Estrae il suffisso opzionale \code{__CT_<comparison_type>} (es.
#' \code{untreated}, \code{vehicle}, \code{genetic_negative}, ...), splitta
#' su \code{__VS__} e parsa ciascun lato con \code{parse_anchor_canonical}.
#'
#' @param pair_anchor_key character(1): anchor key di un cluster
#'   \code{mode = "pair"}.
#' @param level integer(1) in 0:4: deve essere il \code{level} del pair
#'   cluster.
#' @param tier_assignment list dal config Stadio 3 (default
#'   \code{stage3_default_config()$tier_assignment}).
#' @return list con elementi \code{treated} (named list parsata),
#'   \code{control} (named list parsata), \code{comparison_type}
#'   (character(1) o \code{NULL} se assente).
#' @keywords internal
parse_pair_anchor_key <- function(pair_anchor_key, level,
                                    tier_assignment = NULL) {
  comparison_type <- NULL
  ak <- pair_anchor_key
  # Suffisso __CT_<type> opzionale: estraiamo se presente
  ct_match <- regmatches(ak, regexec("__CT_(.+)$", ak))[[1L]]
  if (length(ct_match) == 2L) {
    comparison_type <- ct_match[2L]
    ak <- sub("__CT_.+$", "", ak)
  }
  vs_parts <- strsplit(ak, "__VS__", fixed = TRUE)[[1L]]
  if (length(vs_parts) != 2L) {
    stop("pair_anchor_key deve contenere esattamente un '__VS__'")
  }
  treated <- parse_anchor_canonical(vs_parts[1L], level, tier_assignment)
  control <- parse_anchor_canonical(vs_parts[2L], level, tier_assignment)
  list(
    treated         = treated,
    control         = control,
    comparison_type = comparison_type
  )
}

#' Match strict: tutti i segmenti uguali (string equality)
#'
#' @param a,b named list di segmenti parsati (output di
#'   \code{parse_anchor_canonical}).
#' @return logical(1).
#' @keywords internal
.match_anchor_strict <- function(a, b) {
  if (!identical(names(a), names(b))) {
    return(FALSE)
  }
  all(unlist(a) == unlist(b))
}

#' Match relaxed: tutti i segmenti non in \code{relaxed_segments} uguali
#'
#' I segmenti in \code{relaxed_segments} sono tollerati (qualunque valore
#' matcha). I segmenti restanti devono essere strict equal.
#'
#' @param a,b named list di segmenti parsati.
#' @param relaxed_segments character: nomi di segmenti tollerati.
#' @return logical(1).
#' @keywords internal
.match_anchor_relaxed <- function(a, b, relaxed_segments) {
  if (!identical(names(a), names(b))) {
    return(FALSE)
  }
  to_check <- setdiff(names(a), relaxed_segments)
  if (length(to_check) == 0L) {
    return(TRUE)
  }
  all(unlist(a[to_check]) == unlist(b[to_check]))
}

#' Classifica un contrasto MEGA-AUG in funzione dell'overlap di studi
#'
#' Tre categorie (spec sez. 6 del design MEGA-AUG bidirezionale):
#' \itemize{
#'   \item \code{"direct_overlap"}: almeno uno studio compare in entrambi
#'         i set (pair e baseline). E' il caso piu' robusto: il random
#'         effect \code{study} di dream puo' separare batch da treatment.
#'   \item \code{"indirect_partial"}: zero studi in comune, ma entrambi
#'         i set sono multi-studio (\code{|pair| >= 2} e
#'         \code{|baseline| >= 3}). E' un \emph{indirect comparison} NMA
#'         con buona transitivita' (sez. 4 Nodo 2 findings).
#'   \item \code{"indirect_disjoint"}: zero studi in comune E almeno uno
#'         dei due set ha un singolo studio (o baseline ha < 3 studi).
#'         Il contrasto e' formalmente indirect ma con poca robustezza
#'         alle differenze di batch tra studi.
#' }
#'
#' @param pair_studies character: identificativi studi (es. GSE accession)
#'   coinvolti nel pair cluster (treated + control samples).
#' @param baseline_studies character: identificativi studi del baseline pool
#'   aggiunto.
#' @return character(1) in \code{c("direct_overlap", "indirect_partial",
#'   "indirect_disjoint")}.
#' @keywords internal
.classify_comparison_kind <- function(pair_studies, baseline_studies) {
  ps <- unique(pair_studies)
  bs <- unique(baseline_studies)
  if (length(intersect(ps, bs)) >= 1L) return("direct_overlap")
  if (length(ps) >= 2L && length(bs) >= 3L) return("indirect_partial")
  "indirect_disjoint"
}

#' Crea una chiusura matcher per la policy scelta
#'
#' Factory che incapsula la policy (\code{strict} o \code{relaxed}) e
#' i relaxed_segments in una funzione \code{function(a, b) -> logical(1)}
#' usabile dai search loop di MEGA-AUG bidirezionale.
#'
#' @param policy character(1): \code{"strict"} o \code{"relaxed"}.
#' @param relaxed_segments character: solo per policy \code{"relaxed"}.
#'   Default \code{c("dose_canonical", "duration_canonical", "has_engineered")}
#'   (vedi spec \code{2026-05-20-p5-stadio4-mega-aug-bidirezionale-design.md}
#'   sez. 4.4).
#' @return function(a, b) ritornante logical(1).
#' @keywords internal
make_anchor_matcher <- function(policy = c("strict", "relaxed"),
                                  relaxed_segments = NULL) {
  policy <- match.arg(policy)
  if (policy == "strict") {
    return(function(a, b) .match_anchor_strict(a, b))
  }
  rs <- if (is.null(relaxed_segments)) {
    c("dose_canonical", "duration_canonical", "has_engineered")
  } else {
    relaxed_segments
  }
  function(a, b) .match_anchor_relaxed(a, b, rs)
}
