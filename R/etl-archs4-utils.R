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

#' Filtra un sample per inclusione nella pipeline P4 beta (firma v2, ADR-0019).
#'
#' Implementa il filtro Stadio 0 v2 secondo ADR-0019 D1+D2+D3+D4: 7 check in
#' sequenza (organism, library_strategy, library_source, string length, regex
#' SC protocollo, lib_size, singlecellprobability). Ordine deterministico:
#' al primo fallimento esce con il reason code corrispondente.
#'
#' @param organism_ch1 Organism da ARCHS4 (`meta/samples/organism_ch1`).
#' @param library_strategy Library strategy (`meta/samples/library_strategy`).
#' @param library_source Library source (`meta/samples/library_source`).
#'   Whitelist `transcriptomic` (D1).
#' @param extract_protocol_ch1 Testo libero protocollo
#'   (`meta/samples/extract_protocol_ch1`). Passato a `is_single_cell_protocol`
#'   per il check D2.
#' @param title Title (`meta/samples/title`). Per title-bulk rescue D2.
#' @param source_name_ch1 Source name (`meta/samples/source_name_ch1`).
#'   Aggiunto al target del check D2.
#' @param string Stringa format B ricostruita (input prompt LLM Stadio 1).
#' @param singlecellprobability Predizione ML ARCHS4 0-1
#'   (`meta/samples/singlecellprobability`). NA semantica "unknown" → no drop.
#' @param lib_size Somma reads del sample (somma colonna `/data/expression`).
#'   Tipicamente pre-calcolato in `build_archs4_metadata_v2()` (FASE C3).
#' @param lib_size_min Soglia minima lib_size (default 500.000, ADR-0019 D4).
#' @return Lista con due elementi:
#'   - `keep` (logical): TRUE se il sample passa tutti i filtri.
#'   - `reason` (character): NA se keep=TRUE, altrimenti il primo reason code
#'      che ha fatto fallire il sample. Valori possibili: `not_human`,
#'      `not_bulk_rnaseq`, `library_source_not_transcriptomic`,
#'      `string_too_short`, `single_cell_protocol_match`,
#'      `lib_size_too_small`, `single_cell_probability_high`.
#' @keywords internal
is_sample_classifiable <- function(organism_ch1, library_strategy, library_source,
                                    extract_protocol_ch1, title, source_name_ch1,
                                    string, singlecellprobability, lib_size,
                                    lib_size_min = 500000L) {
  if (is.na(organism_ch1) || organism_ch1 != "Homo sapiens") {
    return(list(keep = FALSE, reason = "not_human"))
  }
  if (is.na(library_strategy) || library_strategy != "RNA-Seq") {
    return(list(keep = FALSE, reason = "not_bulk_rnaseq"))
  }
  if (is.na(library_source) || library_source != "transcriptomic") {
    return(list(keep = FALSE, reason = "library_source_not_transcriptomic"))
  }
  if (is.na(string) || nchar(string) < 20) {
    return(list(keep = FALSE, reason = "string_too_short"))
  }
  if (isTRUE(is_single_cell_protocol(extract_protocol_ch1, title, source_name_ch1))) {
    return(list(keep = FALSE, reason = "single_cell_protocol_match"))
  }
  if (!is.na(lib_size) && lib_size < lib_size_min) {
    return(list(keep = FALSE, reason = "lib_size_too_small"))
  }
  if (!is.na(singlecellprobability) && singlecellprobability >= 0.9) {
    return(list(keep = FALSE, reason = "single_cell_probability_high"))
  }
  list(keep = TRUE, reason = NA_character_)
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

# ============================================================================
# parse_aligner_class() — P5 audit RED_ALERT C3, ADR-0019 D8, spec B2
# ============================================================================
# Regex prioritizzate (ordine 1-8). Quando piu' aligner matchano lo stesso
# testo (es. "STAR + RSEM"), prevale il primo della lista.
#
# Note 2026-05-27 (deviazione da spec B2): la spec dichiara
# \bSTAR\b dovrebbe matchare "STAR_2.7.10a" e "STARSOLO" ma in perl regex
# `_` e lettere sono word-char → \b di chiusura blocca. Fix: rimuovo
# chiusura \b. Apertura \b mantenuta (parola che inizia con il pattern).
# FP teorici tipo "STARS gazing" accettati: data_processing ARCHS4 descrive
# pipeline computazionali, l'occorrenza di tali FP e' marginale e l'impatto
# come covariata batch e' nullo (ADR-0019 D8).
.aligner_patterns <- list(
  STAR     = "(?i)\\bSTAR",
  HISAT    = "(?i)\\bHISAT",
  Salmon   = "(?i)\\bSalmon",
  kallisto = "(?i)\\bkallisto",
  RSEM     = "(?i)\\bRSEM",
  BWA      = "(?i)\\bBWA",
  Bowtie   = "(?i)\\bBowtie",
  TopHat   = "(?i)\\bTop[- ]?Hat"
)

.aligner_levels <- c(names(.aligner_patterns), "other", "unknown")

#' Parsa data_processing in classe aligner enumerata.
#'
#' Trasforma il testo libero ARCHS4 \code{meta/samples/data_processing} in
#' un factor a livelli ordinati. Usato come covariata batch (D8 ADR-0019)
#' nei modelli DE limma-voom + dream per controllo drift tecnico
#' cross-studio.
#'
#' @param text character vector (uno o piu' sample) con
#'   \code{data_processing} ARCHS4 v2.5.
#' @return factor a 10 livelli ordinati: STAR, HISAT, Salmon, kallisto,
#'   RSEM, BWA, Bowtie, TopHat, other, unknown.
#'   - `other`: testo non vuoto ma nessun pattern noto matcha.
#'   - `unknown`: testo vuoto, NA o solo whitespace.
#' @keywords internal
parse_aligner_class <- function(text) {
  out <- vapply(text, function(x) {
    if (is.na(x) || !nzchar(trimws(x))) return("unknown")
    for (nm in names(.aligner_patterns)) {
      if (grepl(.aligner_patterns[[nm]], x, perl = TRUE)) return(nm)
    }
    "other"
  }, character(1L), USE.NAMES = FALSE)
  factor(out, levels = .aligner_levels)
}

# ============================================================================
# parse_biosample_id() — P5 audit RED_ALERT C3, ADR-0019 D9 (dedupe SAMN)
# ============================================================================

#' Estrae BioSample SAMN ID da ARCHS4 meta/samples/relation.
#'
#' Il campo \code{relation} contiene tipicamente
#' \code{"Reanalyzed by: GSE<n>, BioSample: https://.../SAMN<id>"}. Il
#' BioSample SAMN e' la chiave canonica NCBI per "stesso campione" usata
#' per dedupe cross-studio (D9 ADR-0019). Coverage attesa 99.98% sul
#' bacino A7 (vedi \code{analysis/audit/A7-synthesis-biosample-dedupe.md}).
#'
#' @param relation_text character vector con il campo
#'   \code{meta/samples/relation} ARCHS4.
#' @return character vector. Per ogni input: il primo \code{SAMN\\d+}
#'   matchato, o \code{NA_character_} se relation e' vuoto/NA o non
#'   contiene SAMN parsable.
#' @keywords internal
parse_biosample_id <- function(relation_text) {
  vapply(relation_text, function(x) {
    if (is.na(x) || !nzchar(x)) return(NA_character_)
    m <- regmatches(x, regexpr("SAMN\\d+", x))
    if (length(m) == 0L) NA_character_ else m
  }, character(1L), USE.NAMES = FALSE)
}

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
