BiocManager::install("lgatto/rpx")

library(rpx)
id <- "PXD000001"
px <- PXDataset(id)

txt <- pxfiles(px) |> as.data.frame()


library(purrr)

get_pxfiles_dataframe <- function() {
  # define the range of IDs to process
  id_range <- sprintf("PXD%06d", 1:20)

  # use purrr::map with possibly to skip any IDs that result in an error
  results <- map(
    id_range,
    possibly(~ pxfiles(PXDataset(.)), otherwise = NA_character_)
  )

  # convert the results to a dataframe with columns named after the IDs
  # df <- as.data.frame(results)
  # colnames(df) <- id_range

  return(results)
}













