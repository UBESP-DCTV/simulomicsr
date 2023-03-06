pull_pxd_listfile <- function(pdxs) {
  pdxs |>
    purrr::map(purrr::possibly(
      ~ rpx::pxfiles(rpx::PXDataset2(.x), n = 0L),
      otherwise = NA_character_
    )) |>
    purrr::set_names(pdxs)
}


have_proteingroups <- function(pxd_list) {
  are_to_retain <- pxd_list |>
    purrr::map_lgl(~any(stringr::str_detect(.x, "proteinGroups\\.txt")))
}

extract_with_proteins <- function(pxd_list) {
  names(pxd_list[have_proteingroups(pxd_list)])
}

get_proteingroups_filepath <- function(pxd_list) {
  pxd_list |>
    purrr::map(rpx::PXDataset2) |>
    purrr::map_chr(~{
      rpx::pxget(.x, "proteinGroups.txt") |>
        normalizePath()
    })
}

read_proteingroups <- function(filepath) {
  readr::read_tsv(filepath, show_col_types = FALSE)
}
