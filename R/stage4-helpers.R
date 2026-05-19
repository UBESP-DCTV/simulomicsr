#' Calcola run_id deterministico per Stadio 4
#'
#' Hash di (input_hashes + config + schema_versions) -- 8-hex string. Re-run
#' con stesso input/config produce stesso run_id (idempotenza).
#'
#' @param input_hashes list con stage3 + h5 sha256
#' @param config stage4 config (vedi \code{stage4_default_config})
#' @param schema_versions list con anchor + stage3_algorithm + stage4_algorithm
#' @return character scalar 8-hex
#' @keywords internal
.run_id_for_stage4 <- function(input_hashes, config, schema_versions) {
  # workers/compute non parte del run_id (variabile machine-specific)
  canonical <- list(
    inputs = input_hashes,
    config = config[setdiff(names(config), "compute")],
    schema = schema_versions
  )
  full <- digest::digest(canonical, algo = "sha256", serialize = TRUE)
  substr(full, 1L, 8L)
}

#' Calcola hash sha256 di stage3 dir + h5 file per run_id
#'
#' @param stage3_dir path al directory Stadio 3 (verra' hashato
#'   \code{clusters.rds} se presente, altrimenti l'intera dir).
#' @param h5_path path al file ARCHS4 H5.
#' @return list con 2 elementi: \code{stage3}, \code{h5}.
#' @keywords internal
.compute_input_hashes <- function(stage3_dir, h5_path) {
  stage3_target <- file.path(stage3_dir, "clusters.rds")
  if (!file.exists(stage3_target)) {
    # fallback al directory intero (concat di sha256 dei file ordinati)
    files <- list.files(stage3_dir, full.names = TRUE, recursive = TRUE)
    files <- sort(files)
    stage3_hash <- digest::digest(
      sapply(files, digest::digest, algo = "sha256", file = TRUE,
             USE.NAMES = FALSE),
      algo = "sha256"
    )
  } else {
    stage3_hash <- digest::digest(stage3_target, algo = "sha256", file = TRUE)
  }

  h5_hash <- digest::digest(h5_path, algo = "sha256", file = TRUE)

  list(
    stage3 = substr(stage3_hash, 1L, 16L),
    h5     = substr(h5_hash, 1L, 16L)
  )
}

#' Helper consumer-facing: estrai per_study + pooled side-by-side per un cluster
#'
#' Utile per esplorazione interattiva e per la dashboard.
#'
#' @param s4 stage4_result object (output di \code{load_stage4} o
#'   \code{build_stage4_results}).
#' @param cluster_id string cluster_id.
#' @return list con 2 tibble: \code{per_study} e \code{pooled}.
#' @export
cluster_de_summary <- function(s4, cluster_id) {
  per_study <- s4$per_study_de[s4$per_study_de$cluster_id == cluster_id, ]
  pooled    <- s4$cluster_pooled[s4$cluster_pooled$cluster_id == cluster_id, ]
  list(per_study = per_study, pooled = pooled)
}
