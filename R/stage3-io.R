# stage3-io.R — I/O round-trip per stage3_result

#' Scrive un stage3_result in directory convenzionale (5 file)
#'
#' Layout della directory output:
#' \itemize{
#'   \item \code{assignments.parquet} (via \pkg{arrow})
#'   \item \code{clusters.rds}
#'   \item \code{record_summary.rds}
#'   \item \code{non_clusterable.rds}
#'   \item \code{run_metadata.json} (pretty-printed, auto_unbox)
#' }
#'
#' @param s3 oggetto \code{stage3_result} da \code{\link{build_stage3_clusters}}.
#' @param dir path directory di output (creata se non esiste).
#' @return invisible character vector dei 5 path scritti.
#' @seealso \code{\link{load_stage3}}
#' @export
write_stage3_to_dir <- function(s3, dir) {
  stopifnot(inherits(s3, "stage3_result"))
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Il pacchetto 'arrow' e' necessario per write_stage3_to_dir(). ",
         "Installare con: install.packages('arrow')")
  }
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)

  paths <- c(
    file.path(dir, "assignments.parquet"),
    file.path(dir, "clusters.rds"),
    file.path(dir, "record_summary.rds"),
    file.path(dir, "non_clusterable.rds"),
    file.path(dir, "run_metadata.json")
  )

  arrow::write_parquet(s3$assignments, paths[1])
  saveRDS(s3$clusters,        paths[2])
  saveRDS(s3$record_summary,  paths[3])
  saveRDS(s3$non_clusterable, paths[4])
  writeLines(
    jsonlite::toJSON(s3$run_metadata, pretty = TRUE, auto_unbox = TRUE),
    paths[5]
  )

  invisible(paths)
}

#' Legge stage3_result da directory scritta con \code{write_stage3_to_dir()}
#'
#' Ricostruisce il \code{stage3_result} S3 leggendo i 5 file nella directory:
#' \code{assignments.parquet}, \code{clusters.rds}, \code{record_summary.rds},
#' \code{non_clusterable.rds}, \code{run_metadata.json}.
#'
#' @param dir path directory scritta da \code{\link{write_stage3_to_dir}}.
#' @return \code{stage3_result} S3 object con le 5 componenti.
#' @seealso \code{\link{write_stage3_to_dir}}
#' @export
load_stage3 <- function(dir) {
  stopifnot(dir.exists(dir))
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Il pacchetto 'arrow' e' necessario per load_stage3(). ",
         "Installare con: install.packages('arrow')")
  }

  structure(
    list(
      assignments     = arrow::read_parquet(file.path(dir, "assignments.parquet")),
      clusters        = readRDS(file.path(dir, "clusters.rds")),
      record_summary  = readRDS(file.path(dir, "record_summary.rds")),
      non_clusterable = readRDS(file.path(dir, "non_clusterable.rds")),
      run_metadata    = jsonlite::fromJSON(
        file.path(dir, "run_metadata.json"),
        simplifyVector = TRUE
      )
    ),
    class = "stage3_result"
  )
}
