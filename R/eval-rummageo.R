# Findings esplorazione API RummaGEO (P3.5-B Task 5.1, 2026-05-02):
#
# Tentativo 1 — GraphQL POST /graphql
#   Risposta: 200 OK, schema PostGraphile completo (29524 gseInfos).
#   La risorsa chiave e' `gseInfos { nodes { gse title sampleGroups } }`.
#   `sampleGroups` e' un campo JSON con struttura:
#     { "titles": { "1": "<label>", "2": "<label>" },
#       "samples": { "1": ["GSMxxx", ...], "2": ["GSMxxx", ...] } }
#   Gli indici sono stringhe intere; il gruppo a indice piu' basso corrisponde
#   tipicamente al braccio perturbato (es. "ko", "10Gy"), il gruppo a indice
#   piu' alto al controllo.
#   PROBLEMA: `gseInfos` non ha filtro per GSE via `condition` (l'unico campo
#   disponibile in `GseInfoCondition` e' `id` UUID). La ricerca testuale via
#   `geneSetTermSearch` non restituisce risultati per i GSE del nostro fixture
#   (es. GSE145941 non e' indicizzato in RummaGEO).
#
# Tentativo 2 — REST GET /api/signatures?gse=GSE145941
#   Risposta: HTTP 200 con corpo vuoto. Endpoint non funzionale.
#
# Tentativo 3 — HTML /study/<gse>  e /gse/<gse>
#   Risposta: HTTP 404 per entrambi.
#
# Tentativo 4 — gsmMetaByGsm(gsm: "GSM4340018")
#   Risposta: null (GSM4340018 non e' nel database RummaGEO).
#
# Tentativo 5 — gseTermByGseAndSpecies(gse: "GSE145941", species: "human")
#   Risposta: permission denied per la tabella `gse_terms`.
#
# CONCLUSIONE: GSE145941 (e i 15 GSE del fixture) non sono indicizzati in
# RummaGEO. La API GraphQL e' funzionante per le serie che RummaGEO conosce,
# ma NON copre arbitrariamente tutti i GSE di GEO.
#
# STRATEGIA SCELTA (da ADR-0006 opzione A/B/C):
#   Strategia B — fetch reale con graceful abort + fallback.
#   `fetch_rummageo_signatures` usa GraphQL; se il GSE non e' in RummaGEO,
#   lancia `simulomicsr_rummageo_unavailable`. Il chiamante (Task 7) usa
#   il fallback interno `rummageo_baseline_internal` in quel caso.
#   La cassetta mock + `parse_rummageo_labels` sono implementate e testate sul
#   formato reale `gseInfos.sampleGroups`, cosi' il codice e' pronto quando
#   un GSE e' effettivamente in RummaGEO.
#
# FORMATO sampleGroups (schema reale da API):
#   { "titles": { "1": "label gruppo 1", "2": "label gruppo 2" },
#     "samples": { "1": ["GSMaaa", "GSMbbb"], "2": ["GSMccc", "GSMddd"] } }
#   Convenzione treated/control: indice numerico piu' basso = treated,
#   indice piu' alto = control (validato su 2 esempi reali dall'API).

`%||%` <- function(x, y) if (is.null(x) || (length(x) == 1L && is.na(x))) y else x

# Query GraphQL per recuperare sampleGroups di un GSE
.rummageo_graphql_query <- function(gse, api_base) {
  query <- sprintf(
    paste0(
      '{ gseInfos(first: 50) { nodes { gse sampleGroups } } }'
    )
  )
  # Non esiste un filtro diretto per gse in gseInfos condition (solo id UUID).
  # Scarichiamo batch e filtriamo in R — accettabile perche' la chiamata e'
  # cachata e il dataset e' ~30k righe max (paginiamo solo se serve).
  # Per GSE comuni, di solito si trovano nei primi batch.
  url <- paste0(api_base, "/graphql")
  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_headers("Content-Type" = "application/json") |>
      httr2::req_body_json(list(query = query)) |>
      httr2::req_retry(max_tries = 3L, backoff = function(n) 2^(n - 1L)) |>
      httr2::req_perform(),
    error = function(e) {
      rlang::abort(
        sprintf("RummaGEO fetch failed per %s: %s", gse, conditionMessage(e)),
        class = "simulomicsr_rummageo_unavailable"
      )
    }
  )

  if (httr2::resp_status(resp) >= 400L) {
    rlang::abort(
      sprintf("RummaGEO HTTP %d per %s", httr2::resp_status(resp), gse),
      class = "simulomicsr_rummageo_unavailable"
    )
  }

  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  nodes <- body$data$gseInfos$nodes %||% list()

  # Filtra per gse (il campo puo' contenere piu' GSE come "GSE1,GSE2")
  matched <- Filter(
    function(n) {
      gse_field <- n$gse %||% ""
      gse %in% strsplit(gse_field, ",")[[1L]]
    },
    nodes
  )

  if (length(matched) == 0L) {
    # Paginazione: RummaGEO ha 29k+ studi. Se non trovato nei primi 50,
    # proviamo con piu' pagine (fino a 3 pagine da 1000).
    matched <- .rummageo_graphql_paginate(gse, api_base)
  }

  if (length(matched) == 0L) {
    rlang::abort(
      sprintf("GSE '%s' non trovato in RummaGEO", gse),
      class = "simulomicsr_rummageo_unavailable"
    )
  }

  node <- matched[[1L]]
  list(
    gse = gse,
    sampleGroups = node$sampleGroups %||% list()
  )
}

# Paginazione GraphQL per GSE non trovati nei primi 50 nodi
.rummageo_graphql_paginate <- function(gse, api_base) {
  url <- paste0(api_base, "/graphql")
  page_size <- 1000L
  # Limita a 3 pagine (3000 studi) per evitare call eccessive
  for (page in seq_len(3L)) {
    offset <- (page - 1L) * page_size
    query <- sprintf(
      '{ gseInfos(first: %d, offset: %d) { nodes { gse sampleGroups } } }',
      page_size,
      offset
    )
    resp <- tryCatch(
      httr2::request(url) |>
        httr2::req_headers("Content-Type" = "application/json") |>
        httr2::req_body_json(list(query = query)) |>
        httr2::req_retry(max_tries = 2L, backoff = function(n) 2^(n - 1L)) |>
        httr2::req_perform(),
      error = function(e) NULL
    )
    if (is.null(resp) || httr2::resp_status(resp) >= 400L) next
    body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
    nodes <- body$data$gseInfos$nodes %||% list()
    matched <- Filter(
      function(n) {
        gse_field <- n$gse %||% ""
        gse %in% strsplit(gse_field, ",")[[1L]]
      },
      nodes
    )
    if (length(matched) > 0L) return(matched)
    if (length(nodes) < page_size) break  # ultimo batch
  }
  list()
}

#' Recupera le signature group RummaGEO per un GSE con cache filesystem
#'
#' Interroga il GraphQL di RummaGEO (`/graphql`) per ottenere i `sampleGroups`
#' del GSE. Il risultato viene cachato come file JSON in `cache_dir` per evitare
#' chiamate ripetute. Se il GSE non e' indicizzato in RummaGEO, lancia
#' `simulomicsr_rummageo_unavailable`.
#'
#' Formato restituito (identico al formato della cassetta mock):
#' ```
#' list(
#'   gse = "GSExxx",
#'   sampleGroups = list(
#'     titles = list("1" = "label1", "2" = "label2"),
#'     samples = list("1" = list("GSMaaa", ...), "2" = list("GSMbbb", ...))
#'   )
#' )
#' ```
#'
#' @param gse GSE accession (es. "GSE145941")
#' @param cache_dir Directory di cache per i risultati JSON (NULL = disattivata)
#' @param api_base URL base API RummaGEO (default: "https://rummageo.com")
#' @return list con campi `gse` e `sampleGroups`
#' @export
fetch_rummageo_signatures <- function(gse,
                                      cache_dir = NULL,
                                      api_base = "https://rummageo.com") {
  if (!grepl("^GSE[0-9]+$", gse)) {
    rlang::abort(
      sprintf("series_id non valido: '%s'", gse),
      class = "simulomicsr_invalid_series_id"
    )
  }

  # Cache hit
  if (!is.null(cache_dir)) {
    cache_path <- fs::path(cache_dir, paste0(gse, ".json"))
    if (fs::file_exists(cache_path)) {
      return(jsonlite::read_json(cache_path, simplifyVector = FALSE))
    }
  }

  out <- .rummageo_graphql_query(gse, api_base)

  # Salva in cache
  if (!is.null(cache_dir)) {
    fs::dir_create(cache_dir, recurse = TRUE)
    jsonlite::write_json(
      out,
      fs::path(cache_dir, paste0(gse, ".json")),
      auto_unbox = TRUE,
      null = "null",
      pretty = TRUE
    )
  }

  out
}

#' Estrae assegnazione control/treated per GSM dai sampleGroups RummaGEO
#'
#' Converte il campo `sampleGroups` (formato `gseInfos` di RummaGEO) in un
#' tibble GSM -> label. La convenzione e': il gruppo con indice numerico piu'
#' basso e' classificato "treated" (tipicamente il braccio perturbato),
#' il gruppo con indice piu' alto e' "control" (basale/controllo).
#' Questo e' consistente con i pattern osservati nell'API reale (2026-05-02).
#'
#' Se `data$sampleGroups` e' vuoto o assente, ritorna un tibble vuoto.
#'
#' @param data list ritornato da `fetch_rummageo_signatures()`
#' @return tibble con colonne `geo_accession` e `rummageo_label`
#'   (`"treated"` o `"control"`)
#' @export
parse_rummageo_labels <- function(data) {
  sg <- data$sampleGroups %||% list()
  samples <- sg$samples %||% list()

  if (length(samples) == 0L) {
    return(tibble::tibble(
      geo_accession = character(0),
      rummageo_label = character(0)
    ))
  }

  # Ordina gli indici numericamente
  idx_numeric <- suppressWarnings(as.integer(names(samples)))
  order_idx <- order(idx_numeric, na.last = TRUE)
  idx_sorted <- names(samples)[order_idx]

  n_groups <- length(idx_sorted)
  rows <- list()

  for (i in seq_along(idx_sorted)) {
    idx <- idx_sorted[[i]]
    gsms <- samples[[idx]] %||% list()
    # Primo gruppo (indice minore) = treated, ultimo (indice maggiore) = control
    # Gruppi intermedi (se n > 2) = treated
    label <- if (i == n_groups) "control" else "treated"
    for (gsm in gsms) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        geo_accession = as.character(gsm),
        rummageo_label = label
      )
    }
  }

  out <- dplyr::bind_rows(rows)
  out <- out[!duplicated(out$geo_accession), ]
  out
}

# Keyword di control per il fallback K-means+keyword (per Marino 2024)
.RUMMAGEO_CONTROL_KEYWORDS <- c(
  "ctrl", "control", "wildtype", "wild-type", "wild type", "wt",
  "dmso", "vehicle", "untreated", "mock", "uninfected", "naive",
  "non-targeting", "scrambled", "sint", "sineg", "shnt",
  "empty vector", "ev", "parental"
)

#' Replica fallback dell'algoritmo RummaGEO (Marino 2024)
#'
#' Quando l'API ufficiale non e' disponibile (es. GSE non indicizzato in
#' RummaGEO), applichiamo internamente lo stesso algoritmo di base:
#' keyword matching su control terms + default "treated" per il resto.
#' Questo NON e' equivalente al benchmark "vs RummaGEO ufficiale" —
#' controlliamo noi il metodo. Documentato come baseline interno nel
#' report.
#'
#' Differenza vs Marino 2024: NON facciamo K-means (non ha senso su
#' subset di 15 GSE; Marino lo usa per gestire studi grandi). Solo
#' keyword matching word-boundary per evitare match parziali.
#'
#' @param samples tibble con colonne geo_accession, string
#' @return tibble con colonne geo_accession, rummageo_label (treated/control)
#' @export
rummageo_baseline_internal <- function(samples) {
  stopifnot(all(c("geo_accession", "string") %in% names(samples)))
  rows <- lapply(seq_len(nrow(samples)), function(i) {
    s <- tolower(samples$string[i])
    is_ctrl <- any(vapply(
      .RUMMAGEO_CONTROL_KEYWORDS,
      function(kw) grepl(paste0("\\b", kw, "\\b"), s, fixed = FALSE),
      logical(1)
    ))
    tibble::tibble(
      geo_accession = samples$geo_accession[i],
      rummageo_label = if (is_ctrl) "control" else "treated"
    )
  })
  dplyr::bind_rows(rows)
}
