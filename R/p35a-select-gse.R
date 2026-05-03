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

# Pattern regex per keyword proxy. Ordine = priorita' (top wins).
# Ogni pattern e' una list(pattern = ..., ignore_case = TRUE/FALSE):
# pattern di keyword inglesi -> ignore_case=TRUE; pattern di gene-symbol
# (siGAPDH, shTP53) richiedono case-sensitive per non collidere con parole
# comuni (es. "sham" matcherebbe falsamente sh[A-Z][A-Z0-9]+ in ignore.case).
.DESIGN_KIND_PATTERNS <- list(
  factorial = list(
    list(pattern = "factorial", ignore_case = TRUE),
    list(pattern = "\\+\\w+\\s+\\+\\w+", ignore_case = TRUE),
    list(pattern = "\\+\\w+\\s+-\\w+", ignore_case = TRUE)
  ),
  mediated_effect = list(
    list(pattern = "conditioned\\s+media", ignore_case = TRUE),
    list(pattern = "transwell", ignore_case = TRUE),
    list(pattern = "co-?culture", ignore_case = TRUE),
    list(pattern = "paracrine", ignore_case = TRUE),
    list(pattern = "bystander\\s+effect", ignore_case = TRUE)
  ),
  treatment_vs_untreated = list(
    list(pattern = "(\\d+\\s*[Gg]y\\b.*){2,}", ignore_case = FALSE),
    list(pattern = "(0\\s*[Gg]y).*(\\d+\\s*[Gg]y)", ignore_case = FALSE),
    list(pattern = "irradiat", ignore_case = TRUE),
    list(pattern = "untreated.*treated", ignore_case = TRUE),
    list(pattern = "sham.*irradiat", ignore_case = TRUE)
  ),
  time_course = list(
    list(pattern = "(\\d+\\s*[hd]\\b.*){2,}", ignore_case = TRUE),
    list(pattern = "time\\s*course", ignore_case = TRUE),
    list(pattern = "kinetic", ignore_case = TRUE)
  ),
  knockdown_panel = list(
    list(pattern = "\\bsiRNA\\b", ignore_case = TRUE),
    list(pattern = "\\bshRNA\\b", ignore_case = TRUE),
    list(pattern = "knockdown", ignore_case = TRUE),
    list(pattern = "knock-?down", ignore_case = TRUE),
    # gene-symbol: case-sensitive per evitare false positive (es. "sham")
    list(pattern = "\\bsi-?[A-Z][A-Z0-9]+\\b", ignore_case = FALSE),
    list(pattern = "\\bsh-?[A-Z][A-Z0-9]+\\b", ignore_case = FALSE),
    list(pattern = "[+-]\\s*[Dd]ox\\b", ignore_case = FALSE),
    list(pattern = "inducible.*[Dd]ox", ignore_case = TRUE),
    list(pattern = "[Dd]ox.*induc", ignore_case = TRUE),
    list(pattern = "tetracycline.*induc", ignore_case = TRUE)
  ),
  knockout_vs_wt = list(
    list(pattern = "\\bknockout\\b", ignore_case = TRUE),
    list(pattern = "\\bKO\\b", ignore_case = FALSE),
    list(pattern = "-/-", ignore_case = FALSE),
    list(pattern = "\\+/\\+", ignore_case = FALSE),
    list(pattern = "\\bWT\\b", ignore_case = FALSE),
    list(pattern = "wild-?type", ignore_case = TRUE)
  ),
  disease_vs_normal = list(
    list(pattern = "\\bdisease\\b", ignore_case = TRUE),
    list(pattern = "\\bcancer\\b", ignore_case = TRUE),
    list(pattern = "\\btumor\\b", ignore_case = TRUE),
    list(pattern = "\\btumour\\b", ignore_case = TRUE),
    list(pattern = "patient", ignore_case = TRUE),
    list(pattern = "carcinoma", ignore_case = TRUE),
    list(pattern = "glioblastoma", ignore_case = TRUE),
    list(pattern = "leukemia", ignore_case = TRUE),
    list(pattern = "lymphoma", ignore_case = TRUE),
    list(pattern = "(healthy|normal).*(control|tissue|cortex|donor)",
         ignore_case = TRUE)
  ),
  treatment_vs_vehicle = list(
    list(pattern = "\\bDMSO\\b", ignore_case = TRUE),
    list(pattern = "\\bvehicle\\b", ignore_case = TRUE),
    list(pattern = "\\bdrug\\b", ignore_case = TRUE),
    list(pattern = "compound", ignore_case = TRUE),
    list(pattern = "\\b\\d+\\s*[uM]M\\b", ignore_case = FALSE),
    list(pattern = "\\b\\d+\\s*nM\\b", ignore_case = FALSE)
  )
)

#' @noRd
.match_one_kind <- function(s) {
  for (kind in names(.DESIGN_KIND_PATTERNS)) {
    patterns <- .DESIGN_KIND_PATTERNS[[kind]]
    for (p in patterns) {
      if (grepl(p$pattern, s, perl = TRUE, ignore.case = p$ignore_case)) {
        return(kind)
      }
    }
  }
  "unknown"
}

#' Inferisce un design_kind candidato da metadata strings via keyword proxy
#'
#' Applica regex con priorita' fissa (factorial -- mediated_effect --
#' treatment_vs_untreated -- time_course -- knockdown_panel -- knockout_vs_wt
#' -- disease_vs_normal -- treatment_vs_vehicle -- unknown). Usato SOLO per
#' stratificazione del pool; la classificazione vera e' Stage 2 LLM
#' downstream.
#'
#' @param strings character vector (tipicamente concatenazione dei `string`
#'   xlsx dei sample di un GSE)
#' @return character vector di design_kind con stessa lunghezza
#' @export
keyword_design_kind_proxy <- function(strings) {
  vapply(strings, .match_one_kind, character(1), USE.NAMES = FALSE)
}

#' Intersezione tre-vie GSE: RummaGEO official, xlsx gold, ARCHS4 studies
#'
#' Produce il pool candidato per la selezione. Ogni GSE deve essere presente
#' in tutti e tre. Se archs4_studies = NULL, salta il filtro ARCHS4 (utile
#' per dev offline; la prod imposta ARCHS4 path).
#'
#' @param rummageo_index tibble da load_rummageo_index() (col: gse, n_signatures)
#' @param xlsx_df tibble da read_samples_input() (col: geo_accession,
#'   series_id, string, trtctr_EP)
#' @param archs4_studies character vector di GSE in ARCHS4 (NULL = no filter)
#' @return tibble con colonne gse, n_signatures, n_samples_xlsx,
#'   in_archs4 (TRUE/FALSE/NA), concat_strings (concatenazione dei string
#'   xlsx per il GSE, usata downstream da keyword_design_kind_proxy)
#' @export
intersect_with_xlsx_and_archs4 <- function(rummageo_index, xlsx_df,
                                            archs4_studies = NULL) {
  stopifnot("gse" %in% names(rummageo_index),
            all(c("series_id", "string") %in% names(xlsx_df)))
  xlsx_per_gse <- xlsx_df |>
    dplyr::group_by(.data$series_id) |>
    dplyr::summarise(
      n_samples_xlsx = dplyr::n(),
      concat_strings = paste(.data$string, collapse = " || "),
      .groups = "drop"
    ) |>
    dplyr::rename(gse = "series_id")
  joined <- dplyr::inner_join(rummageo_index, xlsx_per_gse, by = "gse")
  joined$in_archs4 <- if (is.null(archs4_studies)) {
    NA
  } else {
    joined$gse %in% archs4_studies
  }
  if (!is.null(archs4_studies)) {
    joined <- joined[joined$in_archs4, ]
  }
  tibble::as_tibble(joined)
}

#' Stratified sampling deterministico dal pool candidato
#'
#' Per ogni categoria k in target, prende min(target\[k\], n_disponibili) GSE
#' (random uniform su quelli con design_kind_proxy == k). Categoria povera
#' (n_disponibili < target) -> prendi tutti, deficit ridistribuito su
#' treatment_vs_vehicle. GSE con design_kind_proxy = "unknown" sono
#' esclusi dalla selezione (non aggiungono diversita' nota).
#'
#' Determinismo garantito da seed esplicito (default 1812 per consistenza
#' con P2/P3).
#'
#' @param pool tibble con colonne gse, design_kind_proxy, n_signatures,
#'   n_samples_xlsx, in_archs4 (opzionale)
#' @param target named integer vector (es.
#'   c(factorial = 15, time_course = 15, ...)); somma = N totale desiderato
#' @param seed seed RNG (default 1812)
#' @return tibble con stessi campi di pool filtrato ai GSE selezionati
#' @export
stratified_sample_gse <- function(pool, target, seed = 1812L) {
  stopifnot(all(c("gse", "design_kind_proxy") %in% names(pool)),
            length(target) > 0L,
            !is.null(names(target)))
  pool <- pool[pool$design_kind_proxy != "unknown", ]
  set.seed(seed)
  selected <- list()
  deficit_total <- 0L
  for (kind in names(target)) {
    avail <- pool$gse[pool$design_kind_proxy == kind]
    want <- as.integer(target[[kind]])
    n_take <- min(want, length(avail))
    if (n_take > 0L) {
      take <- sample(avail, n_take)
      selected[[kind]] <- take
    }
    deficit_total <- deficit_total + max(0L, want - n_take)
  }
  if (deficit_total > 0L) {
    fallback_kind <- "treatment_vs_vehicle"
    already_taken <- unlist(selected, use.names = FALSE)
    extra_avail <- setdiff(
      pool$gse[pool$design_kind_proxy == fallback_kind],
      already_taken
    )
    if (length(extra_avail) > 0L) {
      n_extra <- min(deficit_total, length(extra_avail))
      selected[[paste0(fallback_kind, "_fallback")]] <-
        sample(extra_avail, n_extra)
    }
  }
  selected_gse <- unlist(selected, use.names = FALSE)
  out <- pool[pool$gse %in% selected_gse, ]
  out
}
