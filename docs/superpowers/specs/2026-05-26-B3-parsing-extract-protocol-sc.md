# B3 — Mini-spec parsing `extract_protocol_ch1` single-cell

> **Data**: 2026-05-26. **Scope**: RED ALERT FASE B3.
> **Implementazione**: FASE C2 (`is_sample_classifiable` extended).

## Obiettivo

Funzione riusabile + deterministica per stabilire se un sample è
single-cell sulla base del testo libero `extract_protocol_ch1` ARCHS4
(+ title + source_name_ch1).

Implementa **D2** dell'ADR-0019: regex SC (gruppo K kit-specific + gruppo
S semantica) + title-bulk rescue.

## API contratto

```r
#' Verifica se un sample e' single-cell tramite parsing testuale
#'
#' Match su union di extract_protocol_ch1, title, source_name_ch1.
#' Rescue title-based: sample con regex SC match ma title contenente
#' "bulk" word-bounded -> NON marcato SC (multi-modality study).
#'
#' @param extract_protocol_ch1 character (single sample o vector)
#' @param title character
#' @param source_name_ch1 character
#' @return logical vector. TRUE = single-cell (drop), FALSE = bulk (keep).
#' @keywords internal
is_single_cell_protocol <- function(extract_protocol_ch1,
                                     title,
                                     source_name_ch1) { ... }
```

## Pattern Gruppo K — kit/platform specifici (alta confidenza)

Lista approvata 2026-05-26 (post-tightening A2b validation FPR cluster-based).

```r
patterns_K <- c(
  # 10x: richiede contesto Genomics / Chromium / chip per evitare match
  # con "10x SDS buffer", "10x SSC", "10x diluted" (10.377 FP rimossi
  # dalla validation A2b vs pattern grezzo `\\b10[xX]\\b`).
  "10x_Chromium"        = "(?i)\\b10[xX]\\s*Genomics\\b|\\bChromium\\b|\\b10[xX]\\s*chip\\b|\\b10[xX]\\s*chromium\\b",
  # SmartSeq: solo SmartSeq/SmartSeq2/SmartSeq3 (SC, Picelli 2014/2018);
  # esclude esplicitamente Smart-3SEQ (Foley 2019, bulk 3'-tag).
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
```

## Pattern Gruppo S — semantica single-cell

```r
patterns_S <- c(
  "single_cell_literal" = "(?i)\\bsingle[- ]?cell\\b",
  "single_nucle"        = "(?i)\\bsingle[- ]?nucle[ari]+\\b",
  "snRNA"               = "(?i)\\bsn[- ]?RNA(-?seq)?\\b|\\bNuc[- ]?seq\\b",
  "scRNA"               = "(?i)\\bsc[- ]?RNA(-?seq)?\\b"
)
```

## Title-bulk rescue

Sample che matchano regex K o S ma il cui `title` contiene `bulk`
esplicito vengono **escluse dal drop** (sono bulk-low-input in studi
multi-modality, vedi A2b validation: 0/20 false rescue su random,
~70% riduzione FP).

```r
title_bulk_rescue_pattern <- "(?i)\\bbulk\\b|\\bbulkRNA"
```

## Algoritmo

```r
is_single_cell_protocol <- function(extract_protocol_ch1, title, source_name_ch1) {
  target_text <- paste(extract_protocol_ch1, title, source_name_ch1, sep = " || ")
  hit_K <- Reduce(`|`, lapply(patterns_K, function(p) grepl(p, target_text, perl = TRUE)))
  hit_S <- Reduce(`|`, lapply(patterns_S, function(p) grepl(p, target_text, perl = TRUE)))
  any_sc <- hit_K | hit_S
  title_bulk <- grepl(title_bulk_rescue_pattern, title, perl = TRUE)
  any_sc & !title_bulk
}
```

## Test fixture (definizione vincolante per C5 tests)

Positive (devono restituire TRUE = SC):

| context | testo |
|---|---|
| K 10x | `extract`: `10x Genomics Chromium Single Cell 3' v3 Kit` |
| K SmartSeq2 | `extract`: `Single cells were sorted into 96-well plates and Smart-seq2 protocol was applied` |
| K Fluidigm | `extract`: `C1 Single-Cell Auto Prep IFC (Fluidigm) for SC capture` |
| K ICELL8 | `extract`: `ICELL8 single cell platform (Wafergen)` |
| K Drop-seq | `extract`: `Drop-seq beads + microfluidic device` |
| K Seq-Well | `extract`: `Seq-Well protocol on 86k cells` |
| K BD Rhapsody | `extract`: `BD Rhapsody cartridge` |
| K CellPlex | `extract`: `3' CellPlex Kit multiplexing` |
| K CellTag | `title`: `celltag1_ispinesib_day3_CellTag` |
| S single_cell_literal | `extract`: `Single cell RNAseq was performed per Picelli et al.` |
| S single_nucle | `extract`: `Single nuclear capture and Dounce homogenization` |
| S snRNA | `extract`: `snRNA-seq libraries from Drop-seq adaptation` |
| S scRNA | `extract`: `scRNA-seq libraries Chromium platform` |

Negative (devono restituire FALSE = bulk):

| context | testo | nota |
|---|---|---|
| empty | `""` empty | bulk default |
| bulk explicit | `extract`: `TRIzol total RNA + TruSeq Stranded mRNA Library Prep Kit` | bulk standard |
| 10x false positive | `extract`: `10x SDS buffer + 10x SSC wash` | richiesto Genomics/Chromium/chip — non matcha |
| Smart-3SEQ | `extract`: `Smart-3SEQ Foley 2019 bulk 3'-tag RNA-seq` | esplicitamente escluso |
| QuantSeq | `extract`: `Lexogen QuantSeq 3' mRNA-Seq Library Prep Kit` | bulk-low-input non SC |
| PAXgene | `extract`: `PAXgene Blood RNA Kit + GlobinClear + Illumina mRNA-Seq` | bulk standard |
| Title-bulk rescue (multi-modal) | `extract`: `Single cells sorted Smart-seq2` + `title`: `Sample-106 (Total Bulk RNA-seq)` | rescue title-bulk → FALSE |
| Title-bulk rescue (low-input) | `extract`: `For bulk RNA-seq, 100 sorted cells using Smart-seq2 protocol` + `title`: `Bulk_RNA-Seq_HSC_donor1` | rescue → FALSE |

## Integrazione FASE C2

In `R/etl-archs4-h5.R::is_sample_classifiable()`:

```r
is_sample_classifiable <- function(organism_ch1, library_strategy, library_source,
                                    extract_protocol_ch1, title, source_name_ch1,
                                    string, singlecellprobability, lib_size,
                                    lib_size_min = 500000L) {
  if (organism_ch1 != "Homo sapiens") return(list(keep = FALSE, reason = "not_human"))
  if (library_strategy != "RNA-Seq")  return(list(keep = FALSE, reason = "not_bulk_rnaseq"))
  if (library_source != "transcriptomic") return(list(keep = FALSE, reason = "library_source_not_transcriptomic"))
  if (nchar(string) < 20)             return(list(keep = FALSE, reason = "string_too_short"))
  if (isTRUE(is_single_cell_protocol(extract_protocol_ch1, title, source_name_ch1))) {
    return(list(keep = FALSE, reason = "single_cell_protocol_match"))
  }
  if (lib_size < lib_size_min) return(list(keep = FALSE, reason = "lib_size_too_small"))
  if (!is.na(singlecellprobability) && singlecellprobability >= 0.9) {
    return(list(keep = FALSE, reason = "single_cell_probability_high"))
  }
  list(keep = TRUE, reason = NA_character_)
}
```

Reason codes esposti per skip log + supplementary paper.

## Riferimenti

- `analysis/audit/A2-synthesis-protocol-regex.md` — sintesi A2 con FPR
  Wilson CI per pattern volumetrici (SmartSeq 0.70% [0.34-1.45%],
  single_cell_literal 1.00% [0.55-1.83%]).
- `analysis/audit/A2-extract-protocol-sc.R` — implementazione di
  riferimento (script audit) di cui FASE C2 è la versione "produttiva".
- ADR-0019 §D2.
