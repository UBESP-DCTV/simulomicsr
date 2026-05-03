`%||%` <- function(x, y) if (is.null(x) || (length(x) == 1L && is.na(x))) y else x

#' @noRd
.parse_rummageo_index_response <- function(body) {
  nodes <- body$data$gseInfos$nodes %||% list()
  rows <- list()
  for (node in nodes) {
    gse_field <- node$gse %||% ""
    if (nchar(gse_field) == 0L) next
    n_sig <- sum(vapply(
      node$sampleGroups$samples %||% list(),
      function(s) length(s),
      integer(1)
    ))
    for (gse in strsplit(gse_field, ",")[[1L]]) {
      gse_clean <- trimws(gse)
      if (nchar(gse_clean) == 0L) next
      rows[[length(rows) + 1L]] <- tibble::tibble(
        gse = gse_clean,
        n_signatures = as.integer(n_sig)
      )
    }
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(gse = character(0), n_signatures = integer(0)))
  }
  out <- dplyr::bind_rows(rows)
  out <- out[!duplicated(out$gse), ]
  out
}

#' @noRd
.fetch_rummageo_index_page <- function(api_base, page_size, offset) {
  url <- paste0(api_base, "/graphql")
  query <- sprintf(
    '{ gseInfos(first: %d, offset: %d) { nodes { gse sampleGroups } } }',
    page_size, offset
  )
  resp <- httr2::request(url) |>
    httr2::req_headers("Content-Type" = "application/json") |>
    httr2::req_body_json(list(query = query)) |>
    httr2::req_retry(max_tries = 3L,
                     backoff = function(n) 2^(n - 1L)) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400L) {
    rlang::abort(
      sprintf("RummaGEO index fetch HTTP %d", httr2::resp_status(resp)),
      class = "simulomicsr_rummageo_index_unavailable"
    )
  }
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}

#' Scarica indice completo GSE da RummaGEO con cache filesystem
#'
#' Pagina via GraphQL gseInfos(first: 1000, offset: ...) finche' i nodi
#' ritornati sono < page_size (ultimo batch). Salva il risultato come
#' <cache_dir>/rummageo-index.json. Se il file esiste, lo legge senza
#' rifare il fetch. Splitta GSE multipli (SuperSeries "GSE1,GSE2") in righe
#' separate per atomicita' di intersezione downstream.
#'
#' @param cache_dir directory cache (NULL = no cache, sempre fetch live)
#' @param api_base URL base API (default "https://rummageo.com")
#' @param page_size dimensione pagina (default 1000)
#' @param max_pages limite paginazione difensivo (default 50, ~50k studi)
#' @return tibble con colonne gse (atomic GSE accession), n_signatures (somma sample nei sampleGroups)
#' @export
load_rummageo_index <- function(cache_dir = NULL,
                                 api_base = "https://rummageo.com",
                                 page_size = 1000L,
                                 max_pages = 50L) {
  if (!is.null(cache_dir)) {
    cache_path <- file.path(cache_dir, "rummageo-index.json")
    if (file.exists(cache_path)) {
      cached <- jsonlite::read_json(cache_path, simplifyVector = TRUE)
      return(tibble::as_tibble(cached))
    }
  }
  all_rows <- list()
  for (page in seq_len(max_pages)) {
    offset <- (page - 1L) * page_size
    body <- .fetch_rummageo_index_page(api_base, page_size, offset)
    parsed <- .parse_rummageo_index_response(body)
    if (nrow(parsed) == 0L) break
    all_rows[[length(all_rows) + 1L]] <- parsed
    nodes_returned <- length(body$data$gseInfos$nodes %||% list())
    if (nodes_returned < page_size) break
  }
  out <- if (length(all_rows) == 0L) {
    tibble::tibble(gse = character(0), n_signatures = integer(0))
  } else {
    dplyr::bind_rows(all_rows)
  }
  out <- out[!duplicated(out$gse), ]
  if (!is.null(cache_dir)) {
    fs::dir_create(cache_dir, recurse = TRUE)
    jsonlite::write_json(out, file.path(cache_dir, "rummageo-index.json"),
                         auto_unbox = TRUE, pretty = TRUE)
  }
  out
}
