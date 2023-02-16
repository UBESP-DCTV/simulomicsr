h5_summary <- function(h5_filepath) {
  rhdf5::h5ls(h5_filepath) |>
    tibble::as_tibble() |>
    separate_h5_summary_dims()
}

h5_gene_names <- function(h5_filepath) {
  rhdf5::h5read(h5_filepath, "meta/genes")[["gene_symbol"]]
}

h5_expression_data <- function(h5_filepath) {
  NULL
}
