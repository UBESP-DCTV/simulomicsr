h5_summary <- function(h5_filepath) {
  NULL
}

h5_gene_names <- function(h5_filepath) {
  rhdf5::h5read(h5_filepath, "meta/genes")[["gene_symbol"]]
}

h5_expression_data <- function(h5_filepath) {
  NULL
}
