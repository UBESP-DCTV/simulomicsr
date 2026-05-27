#' Helper interni: gene axis Ensembl per il pool Stadio 4 (FASE E1 ADR-0019 D6)
#'
#' Cambio di axis (decisione utente 2026-05-27): la chiave gene del DE
#' diventa \code{ensembl_gene} (univoco per costruzione, 67186 ID distinti
#' in ARCHS4 v2.5, 0 NA). HGNC \code{symbol} resta come annotation separata
#' (4638 simboli duplicati cross-paralogi: KIR3DL2 x43, HLA, ...).
#'
#' Risolve in modo deterministico il bug paralogi documentato in ADR-0016
#' Decision 2 (sub-finding "dream silent fallback to limma"): la patch
#' \code{make.unique()} sui simboli produceva rownames sintetici
#' (\code{KIR3DL2.1}, \code{KIR3DL2.2}, ...) che mescolavano Ensembl ID
#' distinti sotto un nome scelto arbitrariamente. Con Ensembl come axis,
#' ogni gene ha la sua identita' univoca e il symbol e' solo label.
#'
#' Vedi: \code{docs/decisions/0019-archs4-metadata-exploitation-v2.md §D6}.
#'
#' @keywords internal
NULL

#' Valida e impacchetta i due vettori gene-level letti da ARCHS4 H5
#'
#' Helper puro stateless usato da \code{.h5_gene_axis()} per separare la
#' logica di validazione dalla I/O su H5 (test in isolamento).
#'
#' @param ensembl character vector di Ensembl gene ID (axis univoco).
#'   Accetta anche factor (coerced a character).
#' @param symbol character vector di HGNC symbol parallelo a
#'   \code{ensembl}. Stessa lunghezza. NA accettato (gene non annotato
#'   HGNC). Duplicati ammessi (paralogi).
#' @return list con due componenti character:
#'   \describe{
#'     \item{\code{ensembl_gene}}{Ensembl ID, univoco per definizione.}
#'     \item{\code{gene_symbol}}{HGNC symbol, possibili duplicati + NA.}
#'   }
#' @keywords internal
.parse_gene_axis <- function(ensembl, symbol) {
  ensembl <- as.character(ensembl)
  symbol  <- as.character(symbol)

  if (length(ensembl) != length(symbol)) {
    stop(sprintf(
      "ensembl e symbol devono avere stessa lunghezza (ricevuti %d vs %d)",
      length(ensembl), length(symbol)
    ), call. = FALSE)
  }

  if (length(ensembl) == 0L) {
    return(list(ensembl_gene = character(0), gene_symbol = character(0)))
  }

  # Ensembl deve essere axis univoco e popolato (early fail).
  if (any(is.na(ensembl))) {
    stop(sprintf(
      "ensembl contiene %d NA: axis non puo' essere axis se mancante (ARCHS4 v2.5 ha 0 NA confermato)",
      sum(is.na(ensembl))
    ), call. = FALSE)
  }
  if (any(ensembl == "")) {
    stop(sprintf(
      "ensembl contiene %d stringhe vuote: axis non puo' essere vuoto",
      sum(ensembl == "")
    ), call. = FALSE)
  }
  if (anyDuplicated(ensembl) > 0L) {
    dup_n <- sum(duplicated(ensembl))
    dup_first <- ensembl[anyDuplicated(ensembl)]
    stop(sprintf(
      "ensembl contiene %d duplicati (es. '%s'): axis non puo' essere axis se duplicato",
      dup_n, dup_first
    ), call. = FALSE)
  }

  list(
    ensembl_gene = ensembl,
    gene_symbol  = symbol
  )
}

#' Attacca gene_axis a una count matrix Stadio 4
#'
#' Imposta \code{rownames(counts) = ensembl_gene} (axis univoco) e salva
#' la mappatura HGNC \code{gene_symbol} come \code{attr(counts,
#' "gene_symbol")} named vector con \code{names = ensembl_gene}. Il named
#' attribute consente lookup di un sottoinsieme post-\code{filterByExpr}:
#' \code{attr(counts, "gene_symbol")[rownames(fit)]} restituisce i symbol
#' per i geni sopravvissuti, NA-aware.
#'
#' La matrice originale viene restituita modificata in-place (rownames
#' + attr); il contenuto numerico non e' toccato.
#'
#' @param counts matrice numerica (geni x sample) come da
#'   \code{.fetch_counts_from_h5}. \code{nrow(counts)} deve eguagliare
#'   \code{length(gene_axis$ensembl_gene)}.
#' @param gene_axis list con \code{ensembl_gene} + \code{gene_symbol}
#'   (output di \code{.parse_gene_axis}).
#' @return matrix con \code{rownames = ensembl_gene} e
#'   \code{attr("gene_symbol")} named.
#' @keywords internal
.attach_gene_annotation <- function(counts, gene_axis) {
  if (nrow(counts) != length(gene_axis$ensembl_gene)) {
    stop(sprintf(
      "nrow(counts)=%d non eguale a length(gene_axis$ensembl_gene)=%d",
      nrow(counts), length(gene_axis$ensembl_gene)
    ), call. = FALSE)
  }
  rownames(counts) <- gene_axis$ensembl_gene
  attr(counts, "gene_symbol") <- setNames(
    gene_axis$gene_symbol,
    gene_axis$ensembl_gene
  )
  counts
}
