# Cache in-memory del dump HGNC (chiave = source_path)
.hgnc_cache <- new.env(parent = emptyenv())

#' Path canonico al dump HGNC nella cache utente
#'
#' Il dump completo si scarica da `https://www.genenames.org/download/archive/`
#' (nome file: `hgnc_complete_set.txt`, ~10 MB). In P1 NON scarichiamo
#' automaticamente: l'utente o il futuro plan di setup popola questo path.
#'
#' @return path (non garantito esistente)
#' @export
hgnc_dump_path <- function() {
  fs::path(tools::R_user_dir("simulomicsr", which = "cache"),
           "hgnc_complete_set.tsv")
}

#' Carica e indicizza il dump HGNC (TSV) in memoria
#' @keywords internal
.load_hgnc <- function(source_path) {
  if (!is.null(.hgnc_cache[[source_path]])) {
    return(.hgnc_cache[[source_path]])
  }
  stopifnot(fs::file_exists(source_path))

  raw <- readr::read_tsv(
    source_path,
    show_col_types = FALSE,
    progress = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )

  required <- c("hgnc_id", "symbol", "alias_symbol", "prev_symbol")
  missing  <- setdiff(required, names(raw))
  if (length(missing) > 0L) {
    rlang::abort(
      glue::glue("Dump HGNC manca colonne: {paste(missing, collapse = ', ')}"),
      class = "simulomicsr_lookup_bad_dump"
    )
  }

  raw$symbol_lower <- tolower(raw$symbol)

  # Aliases: split by `|` e long-format
  aliases <- raw[, c("hgnc_id", "symbol", "alias_symbol")]
  aliases <- aliases[!is.na(aliases$alias_symbol) & nzchar(aliases$alias_symbol), ]
  if (nrow(aliases) > 0L) {
    aliases <- do.call(rbind, lapply(seq_len(nrow(aliases)), function(i) {
      parts <- strsplit(aliases$alias_symbol[i], "|", fixed = TRUE)[[1]]
      data.frame(
        hgnc_id = aliases$hgnc_id[i],
        symbol  = aliases$symbol[i],
        alias   = parts,
        alias_lower = tolower(parts),
        stringsAsFactors = FALSE
      )
    }))
  } else {
    aliases <- data.frame(hgnc_id = character(), symbol = character(),
                          alias = character(), alias_lower = character())
  }

  prev <- raw[, c("hgnc_id", "symbol", "prev_symbol")]
  prev <- prev[!is.na(prev$prev_symbol) & nzchar(prev$prev_symbol), ]
  if (nrow(prev) > 0L) {
    prev <- do.call(rbind, lapply(seq_len(nrow(prev)), function(i) {
      parts <- strsplit(prev$prev_symbol[i], "|", fixed = TRUE)[[1]]
      data.frame(
        hgnc_id = prev$hgnc_id[i],
        symbol  = prev$symbol[i],
        prev    = parts,
        prev_lower = tolower(parts),
        stringsAsFactors = FALSE
      )
    }))
  } else {
    prev <- data.frame(hgnc_id = character(), symbol = character(),
                       prev = character(), prev_lower = character())
  }

  out <- list(symbols = raw, aliases = aliases, prev = prev)
  .hgnc_cache[[source_path]] <- out
  out
}

#' Normalizza un nome di gene human a un record canonico HGNC
#'
#' Strategia di matching (in ordine, primo match vince):
#' 1. `symbol` esatto case-insensitive
#' 2. `alias_symbol` esatto case-insensitive
#' 3. `prev_symbol` esatto case-insensitive
#'
#' @param name nome di gene da normalizzare (es. "VEGF", "vegfa", "c-Myc")
#' @param organism in P1 solo `"human"` è supportato
#' @param source_path path al dump HGNC TSV. Default: `hgnc_dump_path()`
#'
#' @return lista con `id`, `preferred_name`, `resolved_via`
#'   (`"symbol"|"alias_symbol"|"prev_symbol"`), oppure `NULL` se non trovato
#' @export
normalize_gene <- function(name,
                           organism = "human",
                           source_path = hgnc_dump_path()) {
  stopifnot(is.character(name), length(name) == 1L, !is.na(name), nzchar(name))

  if (!identical(organism, "human")) {
    rlang::abort(
      glue::glue("In P1 normalize_gene supporta solo organism='human', ricevuto '{organism}'."),
      class = "simulomicsr_lookup_unsupported_organism",
      organism = organism
    )
  }

  hgnc <- .load_hgnc(source_path)
  needle <- tolower(name)

  hit <- hgnc$symbols[hgnc$symbols$symbol_lower == needle, , drop = FALSE]
  if (nrow(hit) >= 1L) {
    return(list(
      id             = hit$hgnc_id[1],
      preferred_name = hit$symbol[1],
      resolved_via   = "symbol"
    ))
  }

  hit <- hgnc$aliases[hgnc$aliases$alias_lower == needle, , drop = FALSE]
  if (nrow(hit) >= 1L) {
    return(list(
      id             = hit$hgnc_id[1],
      preferred_name = hit$symbol[1],
      resolved_via   = "alias_symbol"
    ))
  }

  hit <- hgnc$prev[hgnc$prev$prev_lower == needle, , drop = FALSE]
  if (nrow(hit) >= 1L) {
    return(list(
      id             = hit$hgnc_id[1],
      preferred_name = hit$symbol[1],
      resolved_via   = "prev_symbol"
    ))
  }

  NULL
}
