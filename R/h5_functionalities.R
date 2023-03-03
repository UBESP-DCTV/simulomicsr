h5_summary <- function(h5_filepath) {
  rhdf5::h5ls(h5_filepath) |>
    tibble::as_tibble() |>
    separate_h5_summary_dims()
}

h5_gene_names <- function(h5_filepath) {
  rhdf5::h5read(h5_filepath, "meta/genes")[["gene_symbol"]]
}

h5_expression_data <- function(
    h5_filepath,
    n_datasets = 50,
    seed = 1
) {
  set.seed(seed)
  gene_names <- h5_gene_names(h5_filepath)
  n_genes <- length(gene_names)
  max_n_datasets <- h5_summary(h5_filepath)[["n_datasets"]] |>
    max(na.rm = TRUE)

  if (n_datasets > max_n_datasets) {
    usethis::ui_stop(paste0(
      "{usethis::ui_field('n_datasets')} provided is ",
      "{usethis::ui_value(n_datasets)}.\n",
      "There are {usethis::ui_value(max_n_datasets)} datasets only.\n",
      "Please, provide a lower {usethis::ui_field('n_datasets')}."
    ))
  }

  datasets <- sample.int(max_n_datasets, n_datasets)

  h5_filepath |>
    rhdf5:::h5read(
      "data/expression",
      index = list(datasets, seq_len(n_genes))
    ) |>
    tibble::as_tibble(.name_repair = "minimal") |>
    purrr::set_names(gene_names)
}
