#' Costruisce la stringa input stage1 in formato B (ADR-spec P4 beta).
#'
#' @param title Sample title da ARCHS4 H5 `/meta/samples/title`.
#' @param source_name_ch1 Sample source name da ARCHS4 H5 `/meta/samples/source_name_ch1`.
#' @param characteristics_ch1 Characteristics_ch1 da ARCHS4 H5 `/meta/samples/characteristics_ch1`.
#' @return Stringa concatenata pronta per stage1 prompt.
#' @keywords internal
build_sample_string_format_B <- function(title, source_name_ch1, characteristics_ch1) {
  parts <- c()
  if (!is.na(title) && nzchar(title)) parts <- c(parts, paste0("title: ", title))
  if (!is.na(source_name_ch1) && nzchar(source_name_ch1)) parts <- c(parts, paste0("source: ", source_name_ch1))
  if (!is.na(characteristics_ch1) && nzchar(characteristics_ch1)) parts <- c(parts, characteristics_ch1)
  paste(parts, collapse = ",")
}

#' Filtra un sample per inclusione nella pipeline P4 beta (human, bulk RNA-seq, metadata non-trivial).
#'
#' @param organism Organism da ARCHS4 (`organism_ch1`).
#' @param library_strategy Library strategy (`library_strategy`).
#' @param string Stringa format B ricostruita.
#' @return Logical TRUE se passa i filtri.
#' @keywords internal
is_sample_classifiable <- function(organism, library_strategy, string) {
  if (is.na(organism) || organism != "Homo sapiens") return(FALSE)
  if (is.na(library_strategy) || library_strategy != "RNA-Seq") return(FALSE)
  if (is.na(string) || nchar(string) < 20) return(FALSE)
  TRUE
}

# ============================================================================
# is_single_cell_protocol() — P5 audit RED_ALERT C2, ADR-0019 D2, spec B3
# ============================================================================
# Pattern Gruppo K (kit-specific, alta confidenza) — ristretti post-A2b
# validation cluster-based FPR (10x_Chromium richiede contesto
# Genomics/Chromium/chip; SmartSeq esclude Smart-3SEQ bulk 3'-tag Foley 2019).
.patterns_sc_K <- c(
  "10x_Chromium"        = "(?i)\\b10[xX]\\s*Genomics\\b|\\bChromium\\b|\\b10[xX]\\s*chip\\b|\\b10[xX]\\s*chromium\\b",
  "SmartSeq"            = "(?i)(?<!3-)(?<!3)\\bSmart[- ]?Seq[23]?\\b",
  "Fluidigm_C1"         = "(?i)Fluidigm|\\bC1 chip\\b|\\bC1 IFC\\b",
  "ICELL8"              = "(?i)ICELL8",
  "Drop-seq_inDrop"     = "(?i)Drop[- ]?seq|inDrop",
  "CEL-seq_MARS-seq"    = "(?i)CEL[- ]?seq|MARS[- ]?seq",
  "Seq-Well"            = "(?i)Seq[- ]?Well",
  "BD_Rhapsody"         = "(?i)BD\\s*Rhapsody|Rhapsody",
  "Digital_microfluid"  = "(?i)Digital microfluidic",
  "CellPlex"            = "(?i)CellPlex|3'\\s*CellPlex",
  "CellTag"             = "(?i)CellTag",
  "Multi-seq"           = "(?i)Multi[- ]?seq",
  "snDrop"              = "(?i)snDrop"
)

# Pattern Gruppo S (semantica single-cell).
# Underscore-aware (fix paper-grade 2026-05-26): apertura non-prefix-word
# tramite `(^|[^a-z0-9])` + separatore interno opzionale `[- _]?` per gestire
# title/extract con underscore (es. "single_cell_RNA", "scRNA_seq", "sn_RNA").
# Chiusura `(?![a-z0-9])` permette boundary su _ . - ( ) spazio ma non su
# alphanum (evita match su "scRNA-seq3" come SC-vero-not-droppato? — gestito
# dal gruppo `[23]?`). Conferma test: vedi `analysis/audit/A2-regex-ultrathink.md`.
.patterns_sc_S <- c(
  "single_cell_literal" = "(?i)(^|[^a-z0-9])single[- _]?cell(?![a-z0-9])",
  "single_nucle"        = "(?i)(^|[^a-z0-9])single[- _]?nucle[ari]+(?![a-z0-9])",
  "snRNA"               = "(?i)(^|[^a-z0-9])sn[- _]?RNA(-?seq[23]?)?(?![a-z0-9])|(^|[^a-z0-9])Nuc[- _]?seq(?![a-z0-9])",
  "scRNA"               = "(?i)(^|[^a-z0-9])sc[- _]?RNA(-?seq[23]?)?(?![a-z0-9])"
)

# Title-bulk rescue pattern.
# Underscore-aware (fix paper-grade 2026-05-26): rescue corretto su title
# come `Bulk_RNA-Seq_NSCLC_12_TIL`, `Bulk_24h_C1`. Vecchia regex `\bbulk\b`
# falliva su underscore (perl `_` e' word-char → no boundary). Impatto: +1.517
# bulk salvati dal drop A2 erroneo.
.pattern_title_bulk_rescue <- "(?i)(^|[^a-z0-9])bulk([^a-z0-9]|$)|(^|[^a-z0-9])bulkRNA(?![a-z0-9])"

#' Verifica se un sample e' single-cell tramite parsing testuale.
#'
#' Match su union di `extract_protocol_ch1`, `title`, `source_name_ch1`.
#' Rescue title-based: sample con regex SC match ma title contenente "bulk"
#' word-bounded vengono marcati FALSE (bulk-low-input in studi
#' multi-modality, vedi A2b validation cluster-based 0/20 false rescue su
#' random).
#'
#' Implementa D2 dell'ADR-0019 (P5 audit RED_ALERT Stadio 0). Specifica
#' completa: `docs/superpowers/specs/2026-05-26-B3-parsing-extract-protocol-sc.md`.
#'
#' Pattern Gruppo K (kit-specific, 13 pattern): 10x Genomics/Chromium,
#' SmartSeq (escluso Smart-3SEQ bulk), Fluidigm C1, ICELL8, Drop-seq/inDrop,
#' CEL-seq/MARS-seq, Seq-Well, BD Rhapsody, Digital microfluidics, CellPlex,
#' CellTag, Multi-seq, snDrop.
#'
#' Pattern Gruppo S (semantica, 4 pattern): single_cell_literal,
#' single_nucle, snRNA, scRNA.
#'
#' @param extract_protocol_ch1 character vector. Testo libero ARCHS4
#'   `meta/samples/extract_protocol_ch1` (es. nome kit / protocollo).
#' @param title character vector. ARCHS4 `meta/samples/title`.
#' @param source_name_ch1 character vector. ARCHS4
#'   `meta/samples/source_name_ch1`.
#' @return Logical vector stessa lunghezza degli input. TRUE = single-cell
#'   (drop), FALSE = bulk (keep). NA in input coerce-ate a "".
#' @keywords internal
is_single_cell_protocol <- function(extract_protocol_ch1, title, source_name_ch1) {
  # Coerce NA -> "" per evitare match accidentali su "NA" letterale.
  extract_protocol_ch1 <- ifelse(is.na(extract_protocol_ch1), "", extract_protocol_ch1)
  title                <- ifelse(is.na(title),                "", title)
  source_name_ch1      <- ifelse(is.na(source_name_ch1),      "", source_name_ch1)
  target_text <- paste(extract_protocol_ch1, title, source_name_ch1, sep = " || ")
  hit_K <- Reduce(`|`, lapply(.patterns_sc_K, function(p) grepl(p, target_text, perl = TRUE)))
  hit_S <- Reduce(`|`, lapply(.patterns_sc_S, function(p) grepl(p, target_text, perl = TRUE)))
  any_sc <- hit_K | hit_S
  title_bulk <- grepl(.pattern_title_bulk_rescue, title, perl = TRUE)
  any_sc & !title_bulk
}
