pull_pxd_listfile <- function(pdxs) {
  pdxs |>
    purrr::map(purrr::possibly(
      ~ rpx::pxfiles(rpx::PXDataset(.x)),
      otherwise = NA_character_
    )) |>
    purrr::set_names(pdxs)
}
