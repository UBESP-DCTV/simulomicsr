#' Recupera il summary di uno studio GEO (GSE)
#'
#' Wrapper su `rentrez::entrez_summary(db="gds", ...)` con cache filesystem
#' opzionale. Ritorna i campi title, summary, overall_design utilizzati
#' come input dello Stadio 2 (vedi spec sec.4 e sec.5.2).
#'
#' La cache su disco (un JSON per GSE) e' raccomandata in produzione per
#' evitare hammering di NCBI EUtils (rate limit 3 req/sec senza API key).
#'
#' @param series_id GSE accession (es. "GSE41166"). Validato contro pattern
#'   `^GSE[0-9]+$`.
#' @param cache_dir Directory di cache (NULL = disattivata). Se esiste un
#'   file `<cache_dir>/<series_id>.json`, viene letto senza chiamata di rete.
#'
#' @return Lista con campi `series_id`, `title`, `summary`, `overall_design`.
#'   `overall_design` puo' essere `NA_character_` se non parsabile
#'   dall'XML EUtils (comportamento attuale -- vedi dettagli).
#'
#' @details
#' `entrez_summary(db = "gds", ...)` non espone `overall_design` nel record
#' summary. Una seconda chiamata `entrez_fetch(db = "gds", rettype = "xml")`
#' sarebbe necessaria per estrarlo. Per ora questo campo viene restituito
#' come `NA_character_` -- lo Stadio 2 prompt funziona comunque perche'
#' la maggior parte dell'informazione e' nel campo `summary`.
#'
#' @export
fetch_study_summary <- function(series_id, cache_dir = NULL) {
  if (!grepl("^GSE[0-9]+$", series_id)) {
    rlang::abort(
      sprintf("series_id non valido: '%s' (atteso pattern '^GSE[0-9]+$')", series_id),
      class = "simulomicsr_invalid_series_id"
    )
  }

  # Cache hit: leggi da disco senza toccare la rete
  if (!is.null(cache_dir)) {
    cache_path <- fs::path(cache_dir, paste0(series_id, ".json"))
    if (fs::file_exists(cache_path)) {
      cached <- jsonlite::read_json(cache_path, simplifyVector = FALSE)
      return(.geo_normalize_cached(cached))
    }
  }

  # Cerca l'UID GDS associato a questo GSE
  search_term <- sprintf("%s[ACCN] AND gse[ETYP]", series_id)
  search_res <- .geo_call_with_retry(
    rentrez::entrez_search,
    db = "gds", term = search_term, retmax = 1
  )
  if (length(search_res$ids) == 0L) {
    rlang::abort(
      sprintf("Nessun record GDS trovato per %s", series_id),
      class = "simulomicsr_geo_not_found"
    )
  }
  uid <- search_res$ids[[1L]]

  # Fetch summary record
  summary_res <- .geo_call_with_retry(
    rentrez::entrez_summary,
    db = "gds", id = uid
  )

  # entrez_summary puo' restituire una lista con l'uid come chiave oppure
  # il record direttamente (dipende dalla versione di rentrez)
  rec <- summary_res[[as.character(uid)]]
  if (is.null(rec)) {
    rec <- summary_res
  }

  out <- list(
    series_id      = series_id,
    title          = rec$title %||% NA_character_,
    summary        = rec$summary %||% NA_character_,
    overall_design = NA_character_  # non esposto da entrez_summary GDS
  )

  # Cache miss: scrivi su disco per i run successivi
  if (!is.null(cache_dir)) {
    fs::dir_create(cache_dir, recurse = TRUE)
    jsonlite::write_json(
      out,
      cache_path,
      auto_unbox = TRUE,
      null = "null"
    )
  }

  out
}

# Normalizza un record letto dalla cache su disco
#' @noRd
.geo_normalize_cached <- function(cached) {
  list(
    series_id      = cached$series_id %||% NA_character_,
    title          = cached$title %||% NA_character_,
    summary        = cached$summary %||% NA_character_,
    overall_design = cached$overall_design %||% NA_character_
  )
}

# Chiama fn(...) con retry esponenziale su errori transitori (429 / 5xx)
#' @noRd
.geo_call_with_retry <- function(fn, ..., max_attempts = 3L,
                                 base_delay_sec = 1.0) {
  for (attempt in seq_len(max_attempts)) {
    res <- tryCatch(fn(...), error = function(e) e)
    if (!inherits(res, "error")) return(res)
    msg <- conditionMessage(res)
    is_transient <- grepl("429|500|502|503|504|timeout|temporarily",
                          msg, ignore.case = TRUE)
    if (attempt == max_attempts || !is_transient) {
      rlang::abort(
        sprintf("rentrez call fallita dopo %d tentativi: %s", attempt, msg),
        class = "simulomicsr_geo_fetch_error"
      )
    }
    Sys.sleep(base_delay_sec * (2L ^ (attempt - 1L)))
  }
}
