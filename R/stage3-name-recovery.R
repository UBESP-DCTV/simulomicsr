# Recupero deterministico di identita' (malattia/composto/gene) dai metadati GEO
# grezzi + correzione tipi palesemente sbagliati (K2). Spec:
# docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md

# Fallback %||% se non disponibile da rlang
if (!exists("%||%")) {
  `%||%` <- function(a, b) {
    if (is.null(a) || length(a) == 0L) b else a
  }
}

.DISEASE_KEYS <- "^(disease|disease state|diagnosis|condition|histology|tumor type|cancer type|subtype|group|patient group)$"
.CONTROL_VALS <- "healthy|normal|control|non-?malignant|baseline|unaffected|^na$|^none$"
.AGENT_KEYS    <- "^(treatment|agent|compound|drug|chemical|stimulus|stimulation|ligand|exposure|reagent)$"
.AGENT_CONTROL <- paste0(.CONTROL_VALS, "|vehicle|dmso|\\bpbs\\b|untreated|mock|scramble|vector|water")

#' Parsa "key: value, key: value" in vettore nominato (chiavi/valori lowercased)
#' @keywords internal
.parse_characteristics_kv <- function(text) {
  if (length(text) != 1L || is.na(text) || !nzchar(text)) return(character(0))
  pairs <- strsplit(text, ",", fixed = TRUE)[[1L]]
  out <- character(0)
  for (p in pairs) {
    kv <- strsplit(p, ":", fixed = TRUE)[[1L]]
    if (length(kv) >= 2L) {
      k <- tolower(trimws(kv[1L]))
      v <- tolower(trimws(paste(kv[-1L], collapse = ":")))
      if (nzchar(k) && nzchar(v)) out[[k]] <- v
    }
  }
  out
}

#' Estrae il termine-malattia dai metadati (chiavi malattia + fallback source/title)
#' @keywords internal
.extract_disease_term <- function(source, characteristics, title) {
  kv <- .parse_characteristics_kv(characteristics)
  if (length(kv) > 0L) {
    hit <- names(kv)[grepl(.DISEASE_KEYS, names(kv), ignore.case = TRUE)]
    for (k in hit) {
      v <- kv[[k]]
      if (nzchar(v) && !grepl(.CONTROL_VALS, v, ignore.case = TRUE)) return(v)
    }
  }
  # fallback: source/title se contengono un marcatore tumore/malattia esplicito
  blob <- tolower(paste(source %||% "", title %||% ""))
  if (grepl("tumou?r|cancer|carcinoma|neoplas|leukemia|lymphoma", blob) &&
      !grepl(.CONTROL_VALS, blob, ignore.case = TRUE)) {
    return(tolower(trimws(gsub("\\s+", " ", source %||% title))))
  }
  NA_character_
}

#' Estrae il termine-agente (composto) dai metadati
#' @keywords internal
.extract_agent_term <- function(source, characteristics, title) {
  kv <- .parse_characteristics_kv(characteristics)
  if (length(kv) > 0L) {
    hit <- names(kv)[grepl(.AGENT_KEYS, names(kv))]
    for (k in hit) {
      v <- kv[[k]]
      if (nzchar(v) && !grepl(.AGENT_CONTROL, v)) return(v)
    }
  }
  NA_character_
}

.GENETIC_SIGNALS <- c(
  knockout       = "knock-?out|\\bko\\b|crispr|\\bcas9\\b|sgrna|gene deletion",
  knockdown      = "knock-?down|\\bshrna\\b|\\bsirna\\b|sh[A-Z][A-Z0-9]+|si[A-Z][A-Z0-9]+|dtag|\\baid\\b|auxin|\\biaa\\b|degron|fkbp12|depletion",
  overexpression = "over-?expression|overexpress|\\boe\\b|ectopic expression")

#' Rileva perturbazione genetica inequivocabile (K2) + gene bersaglio se possibile
#' @keywords internal
.detect_genetic_perturbation <- function(source, characteristics, title) {
  blob <- paste(source %||% "", characteristics %||% "", title %||% "")
  none <- list(is_genetic = FALSE, genetic_kind = NA_character_, target = NA_character_)
  kind <- NA_character_
  for (nm in names(.GENETIC_SIGNALS)) {
    if (grepl(.GENETIC_SIGNALS[[nm]], blob, perl = TRUE, ignore.case = TRUE)) {
      kind <- paste0("genetic_", nm); break
    }
  }
  if (is.na(kind)) return(none)
  # estrai gene bersaglio: token in MAIUSCOLO adiacente a un segnale (es. XRN2-dTAG, shTP53)
  m <- regmatches(blob, regexpr("\\b[A-Z][A-Z0-9]{1,6}(?=[- ]?(dTAG|AID|degron|KO|KD))", blob, perl = TRUE))
  m2 <- regmatches(blob, regexpr("(?<=\\b(sh|si))[A-Z][A-Z0-9]{1,6}", blob, perl = TRUE))
  target <- c(m, m2)
  list(is_genetic = TRUE, genetic_kind = kind,
       target = if (length(target)) target[[1L]] else NA_character_)
}
