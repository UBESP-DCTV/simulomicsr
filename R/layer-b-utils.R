#' Genera run_id deterministico per Layer B
#'
#' Hash a 8-hex di canonical-form(stage4_run_id + selection_csv_sha256 +
#' config + schema_versions). Idempotenza: stesso input -> stesso run_id.
#' Ordina i campi `config` e `schema_versions` per stabilita cross-platform
#' (insensibile a ordine di insert).
#'
#' @param stage4_run_id character (1).
#' @param selection_sha256 character (1).
#' @param config list (vedi `layer_b_default_config()`).
#' @param schema_versions list (es. `list(layer_b_algorithm = "v1", stage4_algorithm = "v1")`).
#'
#' @return character 8-hex.
#' @keywords internal
.run_id_for_layer_b <- function(stage4_run_id, selection_sha256, config, schema_versions) {
  payload <- list(
    stage4_run_id = stage4_run_id,
    selection_sha256 = selection_sha256,
    config = config[order(names(config))],
    schema_versions = schema_versions[order(names(schema_versions))]
  )
  substr(digest::digest(payload, algo = "sha256"), 1L, 8L)
}

#' SHA-256 di un file (helper per selection_sha256)
#'
#' Wrapper attorno a `digest::digest(file = path, algo = "sha256")`.
#'
#' @param path character path-to-file esistente.
#'
#' @return character SHA-256 hex.
#' @keywords internal
.sha256_of_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}
