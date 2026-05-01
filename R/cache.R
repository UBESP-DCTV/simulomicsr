#' Inizializza una cache locale append-only (JSONL + indice SQLite)
#'
#' La cache vive in una directory `dir`. Per ogni `namespace` (es.
#' `"stage1"`, `"stage2"`) crea due file: `<namespace>.jsonl` (record
#' append-only, una riga JSON per put) e `<namespace>.sqlite` (indice
#' chiave → offset/byte_size dell'ultima versione).
#'
#' Idempotente: chiamarla ripetutamente sulla stessa dir non altera lo stato.
#'
#' @param dir directory esistente o creabile dove vivono i file di cache
#' @param namespace nome corto della partizione di cache (es. `"stage1"`)
#' @return oggetto `cache` (list opaca) usato dalle altre funzioni `cache_*`
#' @keywords internal
cache_init <- function(dir, namespace = "default") {
  stopifnot(is.character(namespace), length(namespace) == 1L,
            grepl("^[A-Za-z0-9_-]+$", namespace))
  fs::dir_create(dir)

  jsonl_path  <- fs::path(dir, paste0(namespace, ".jsonl"))
  sqlite_path <- fs::path(dir, paste0(namespace, ".sqlite"))

  if (!fs::file_exists(jsonl_path))  fs::file_create(jsonl_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_path)
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS entries (
      key        TEXT PRIMARY KEY,
      offset     INTEGER NOT NULL,
      byte_size  INTEGER NOT NULL,
      put_at     TEXT NOT NULL
    )
  ")
  DBI::dbDisconnect(con)

  structure(
    list(
      dir         = fs::path_abs(dir),
      namespace   = namespace,
      jsonl_path  = jsonl_path,
      sqlite_path = sqlite_path
    ),
    class = "simulomicsr_cache"
  )
}

#' @keywords internal
cache_put <- function(cache, key, value, metadata = list()) {
  stopifnot(inherits(cache, "simulomicsr_cache"))
  stopifnot(is.character(key), length(key) == 1L)

  record <- list(
    key      = key,
    value    = value,
    metadata = metadata,
    put_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
  )
  # serializeJSON garantisce round-trip fedele dei tipi R (NA, NULL, ecc.).
  # Resta JSON una-riga-per-record e rimane leggibile per audit, anche
  # se più verboso di toJSON.
  line <- jsonlite::serializeJSON(record, digits = 8, pretty = FALSE)
  line <- paste0(line, "\n")

  # Determina offset e size PRIMA di scrivere
  offset <- if (fs::file_exists(cache$jsonl_path)) fs::file_size(cache$jsonl_path) else 0L
  byte_size <- nchar(line, type = "bytes")

  con <- file(cache$jsonl_path, open = "ab")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(line), con)

  db <- DBI::dbConnect(RSQLite::SQLite(), cache$sqlite_path)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  DBI::dbExecute(db,
    "INSERT INTO entries (key, offset, byte_size, put_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(key) DO UPDATE SET
       offset = excluded.offset,
       byte_size = excluded.byte_size,
       put_at = excluded.put_at",
    params = list(key, as.integer(offset), as.integer(byte_size), record$put_at)
  )

  invisible(cache)
}

#' @keywords internal
cache_has <- function(cache, key) {
  stopifnot(inherits(cache, "simulomicsr_cache"))
  db <- DBI::dbConnect(RSQLite::SQLite(), cache$sqlite_path)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  res <- DBI::dbGetQuery(db,
    "SELECT 1 FROM entries WHERE key = ? LIMIT 1",
    params = list(key)
  )
  nrow(res) > 0L
}

#' @keywords internal
cache_get <- function(cache, key) {
  stopifnot(inherits(cache, "simulomicsr_cache"))
  db <- DBI::dbConnect(RSQLite::SQLite(), cache$sqlite_path)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  res <- DBI::dbGetQuery(db,
    "SELECT offset, byte_size FROM entries WHERE key = ? LIMIT 1",
    params = list(key)
  )
  if (nrow(res) == 0L) return(NULL)

  con <- file(cache$jsonl_path, open = "rb")
  on.exit(close(con), add = TRUE)
  seek(con, where = res$offset, origin = "start")
  raw <- readBin(con, what = "raw", n = res$byte_size)
  json_line <- rawToChar(raw)
  jsonlite::unserializeJSON(json_line)
}

#' @keywords internal
cache_stats <- function(cache) {
  stopifnot(inherits(cache, "simulomicsr_cache"))
  db <- DBI::dbConnect(RSQLite::SQLite(), cache$sqlite_path)
  on.exit(DBI::dbDisconnect(db), add = TRUE)
  n <- DBI::dbGetQuery(db, "SELECT COUNT(*) AS n FROM entries")$n
  list(
    n_entries  = as.integer(n),
    jsonl_size = fs::file_size(cache$jsonl_path),
    sqlite_size = fs::file_size(cache$sqlite_path)
  )
}
