# B2 — Mini-spec parsing `data_processing` → `aligner_class`

> **Data**: 2026-05-26. **Scope**: RED ALERT FASE B2.
> **Implementazione**: FASE E3 (covariate batch DE).

## Obiettivo

Trasformare il campo testuale libero `meta/samples/data_processing`
(ARCHS4 H5) in una **classe aligner enumerata**, da usare come
covariata fissa nei modelli DE (limma-voom + dream `~ treatment +
instrument_model + aligner_class + (1|study)`).

## API contratto

```r
#' Parsa data_processing in classe aligner
#'
#' @param text character vector (uno o più sample) con
#'   `data_processing` ARCHS4 v2.5.
#' @return factor a livelli ordinati: STAR, HISAT, Salmon, kallisto, RSEM,
#'   BWA, Bowtie, TopHat, other, unknown.
#' @keywords internal
parse_aligner_class <- function(text) { ... }
```

Vettoriale: input vector → output vector stessa lunghezza.

## Lista pattern (ordine priorità decrescente)

Quando il testo cita più aligner (es. `STAR mapping; RSEM counting`),
prevale il primo della lista che matcha. L'ordine riflette la
prevalenza dei pipeline RNA-Seq human bulk 2020-2025:

| ordine | aligner_class | regex (perl=TRUE) | note |
|---:|---|---|---|
| 1 | `STAR` | `(?i)\bSTAR\b` | word-bounded, case-insensitive |
| 2 | `HISAT` | `(?i)\bHISAT[12]?\b` | matcha HISAT, HISAT2 |
| 3 | `Salmon` | `(?i)\bSalmon\b` | |
| 4 | `kallisto` | `(?i)\bkallisto\b` | |
| 5 | `RSEM` | `(?i)\bRSEM\b` | |
| 6 | `BWA` | `(?i)\bBWA\b` | |
| 7 | `Bowtie` | `(?i)\bBowtie[12]?\b` | matcha Bowtie, Bowtie2 |
| 8 | `TopHat` | `(?i)\bTop[- ]?Hat[12]?\b` | matcha TopHat, TopHat2 |

Fallback:
- **`other`**: testo non vuoto ma nessuno dei pattern 1-8 matcha
  (es. "Custom BBMap pipeline").
- **`unknown`**: testo vuoto, NA o solo whitespace.

## Edge cases attesi

- **Multi-aligner string** (es. "STAR + RSEM"): prevale STAR (ordine 1).
  La perdita di informazione sul counting step (RSEM) è accettata: la
  covariata batch principale è l'aligner, il counting tool è correlato.
- **Versioni**: `STAR_2.7.10a` matcha STAR via `\bSTAR\b` perché `_` è
  word char. Verificare con fixture test.
- **Case mixing**: pattern usano `(?i)` quindi `star`, `Star`, `STAR`,
  `sTaR` tutti matchano.

## Test fixture (definizione vincolante per C5 tests)

Positive (devono matchare nel right bucket):

| testo | aligner_class atteso |
|---|---|
| `STAR mapping, HTSeq-count gene counting` | STAR |
| `Reads were aligned with HISAT2 against hg38` | HISAT |
| `kallisto pseudo-alignment to GRCh38 transcriptome` | kallisto |
| `Salmon quant in selective alignment mode` | Salmon |
| `STAR aligner + RSEM expression estimation` | STAR (priority) |
| `Bowtie2 with default parameters` | Bowtie |
| `TopHat2 v2.1.0` | TopHat |
| `BWA-MEM alignment to hg19` | BWA |

Negative (devono restituire other o unknown):

| testo | aligner_class atteso |
|---|---|
| `""` (empty) | unknown |
| `NA` | unknown |
| `"   "` (whitespace only) | unknown |
| `Custom BBMap pipeline` | other |
| `STARSOLO single-cell quantification` | STAR (matcha STAR via \bSTAR\b) — NB: STARSOLO è solo SC e quei sample dovrebbero essere già stati droppati da A1/A2 |

## Integrazione FASE E3

In `R/stage4-mega-aug.R` + `R/stage4-mega-safe.R`:

```r
design_formula <- if (!is.null(aligner_class) && length(unique(aligner_class)) > 1L) {
  ~ treatment + instrument_model + aligner_class + (1|study)
} else {
  # Drop covariate degenere per il cluster
  qc_log$warn(sprintf("[cluster %s] aligner_class single-level, dropped from formula", cluster_id))
  ~ treatment + instrument_model + (1|study)
}
```

Lo stesso pattern per `instrument_model` (singolo livello → drop).
