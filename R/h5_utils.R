separate_h5_summary_dims <- function(x) {
  x |>
    tidyr::separate_wider_delim(
      all_of("dim"),
      delim = " x ",
      too_few = "align_start",
      names = c("n_datasets", "n_genes")
    ) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(c("n_datasets", "n_genes")),
        as.integer
      ),
      n_genes = dplyr::if_else(
        is.na(.data[["n_genes"]]) &
          .data[["n_datasets"]] == max(.data[["n_genes"]], na.rm = TRUE),
        .data[["n_datasets"]],
        .data[["n_genes"]]
      ),
      n_datasets = dplyr::if_else(
        .data[["n_datasets"]] < max(.data[["n_datasets"]], na.rm = TRUE),
        NA_integer_,
        .data[["n_datasets"]]
      )
    )
}
