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
#' @param biotype character vector di Ensembl gene biotype parallelo a
#'   \code{ensembl} (FASE E2 ADR-0019 D7). Stessa lunghezza. NA accettato.
#'   Default NULL = riempito con \code{NA_character_} (retrocompat
#'   pre-E2: i chiamatori che non passano biotype ottengono comunque la
#'   colonna gene_biotype piena di NA).
#' @return list con tre componenti character:
#'   \describe{
#'     \item{\code{ensembl_gene}}{Ensembl ID, univoco per definizione.}
#'     \item{\code{gene_symbol}}{HGNC symbol, possibili duplicati + NA.}
#'     \item{\code{gene_biotype}}{Ensembl biotype (protein_coding,
#'       lncRNA, miRNA, ...). NA per gene non annotato.}
#'   }
#' @keywords internal
.parse_gene_axis <- function(ensembl, symbol, biotype = NULL) {
  ensembl <- as.character(ensembl)
  symbol  <- as.character(symbol)

  if (length(ensembl) != length(symbol)) {
    stop(sprintf(
      "ensembl e symbol devono avere stessa lunghezza (ricevuti %d vs %d)",
      length(ensembl), length(symbol)
    ), call. = FALSE)
  }

  if (is.null(biotype)) {
    biotype <- rep(NA_character_, length(ensembl))
  } else {
    biotype <- as.character(biotype)
    if (length(biotype) != length(ensembl)) {
      stop(sprintf(
        "biotype deve avere stessa lunghezza di ensembl (ricevuti %d vs %d)",
        length(biotype), length(ensembl)
      ), call. = FALSE)
    }
  }

  if (length(ensembl) == 0L) {
    return(list(
      ensembl_gene = character(0),
      gene_symbol  = character(0),
      gene_biotype = character(0)
    ))
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
    gene_symbol  = symbol,
    gene_biotype = biotype
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
  # FASE E2 ADR-0019 D7: gene_biotype attr named per consentire lookup +
  # tracciabilita' downstream. Setato solo se presente in axis (post-E2);
  # pre-E2 axis 2-componenti -> attr non setato (retrocompat).
  if (!is.null(gene_axis$gene_biotype)) {
    attr(counts, "gene_biotype") <- setNames(
      gene_axis$gene_biotype,
      gene_axis$ensembl_gene
    )
  }
  counts
}

#' Subset counts + gene_axis a un sotto-insieme di biotype
#'
#' Helper puro stateless usato da \code{.fetch_counts_from_h5} per applicare
#' il filtro \code{gene_biotype_filter} (FASE E2 ADR-0019 D7, default
#' \code{"protein_coding"}). NA biotype non matcha nessun filter -> droppato.
#'
#' @param counts matrix (geni x sample) con rownames = ensembl_gene.
#' @param gene_axis list 3-componenti (output di \code{.parse_gene_axis}).
#' @param gene_biotype_filter character vector di biotype da mantenere
#'   (es. \code{"protein_coding"} o \code{c("protein_coding", "lncRNA")}).
#'   NULL = no filter (ritorna invariato).
#' @return list \code{(counts, gene_axis)} entrambi subsetati al filter.
#' @keywords internal
.apply_biotype_filter <- function(counts, gene_axis, gene_biotype_filter) {
  if (is.null(gene_biotype_filter)) {
    return(list(counts = counts, gene_axis = gene_axis))
  }

  # T7a Fix 3.1: errore esplicito se axis manca gene_biotype (es. axis
  # pre-E2 o input malformato). Pre-E2 il drop sarebbe stato 100% perche'
  # %in% NULL = FALSE per tutto -> errore '0 geni' generico downstream.
  if (is.null(gene_axis$gene_biotype)) {
    stop("gene_axis manca colonna gene_biotype: usa .parse_gene_axis con ",
         "biotype non-NULL o passa gene_biotype_filter = NULL",
         call. = FALSE)
  }

  # T7a Fix 3.2: filter character(0) e' input degenere semantico.
  # NULL = "no filter" e' la convenzione ufficiale; character(0) e'
  # confuso (potrebbe essere "0 biotype ammessi"?). Errore esplicito.
  if (length(gene_biotype_filter) == 0L) {
    stop("gene_biotype_filter vuoto (character(0)): usa NULL per disabilitare ",
         "il filter",
         call. = FALSE)
  }

  # T7a Fix 4: NA biotype + filter attivo -> warning con count.
  # ARCHS4 v2.5 ha 0 NA confermato, ma forward-compat ARCHS4 future + axis
  # alternativi. Senza warning, drop sarebbe silenzioso (impatta universe,
  # normalizzazione, DE) e il revisore del paper non saprebbe.
  n_na_biotype <- sum(is.na(gene_axis$gene_biotype))
  if (n_na_biotype > 0L) {
    warning(sprintf(
      "gene_axis contiene %d geni con biotype=NA: droppati silenziosamente dal filter '%s'",
      n_na_biotype, paste(gene_biotype_filter, collapse = "|")
    ), call. = FALSE)
  }

  keep_mask <- gene_axis$gene_biotype %in% gene_biotype_filter
  # NB: %in% restituisce FALSE su NA -> NA biotype droppato automaticamente.

  # T7a Fix 3.3: filter typo / mismatch produce 0 geni -> errore mostra
  # biotypes presenti per aiutare il debugging (top 20 unique, no NA).
  if (!any(keep_mask)) {
    biotypes_present <- unique(gene_axis$gene_biotype)
    biotypes_present <- biotypes_present[!is.na(biotypes_present)]
    show_n <- min(length(biotypes_present), 20L)
    stop(sprintf(
      "gene_biotype_filter c('%s') non matcha alcun biotype in gene_axis. Biotypes presenti (primi %d): %s",
      paste(gene_biotype_filter, collapse = "','"),
      show_n,
      paste(biotypes_present[seq_len(show_n)], collapse = ", ")
    ), call. = FALSE)
  }

  counts_filt <- counts[keep_mask, , drop = FALSE]
  axis_filt <- list(
    ensembl_gene = gene_axis$ensembl_gene[keep_mask],
    gene_symbol  = gene_axis$gene_symbol[keep_mask],
    gene_biotype = gene_axis$gene_biotype[keep_mask]
  )
  list(counts = counts_filt, gene_axis = axis_filt)
}
