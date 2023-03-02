BiocManager::install("lgatto/rpx")

library(rpx)
# id <- "PXD000001"
# px <- PXDataset(id)
#
# txt <- pxfiles(px) |> as.data.frame()

# FILTRARE PER SPECIES!

library(tidyverse)

# define the range of IDs to process
id_range <- sprintf("PXD%06d", 1:20)

# use purrr::map with possibly to skip any IDs that result in an error

results <- map(
    id_range,
    possibly(~ pxfiles(PXDataset(.)), otherwise = NA_character_))

names(results) <- id_range

has_protein_groups <- map_lgl(results,
                              ~ any(str_detect(.x, "proteinGroups.txt")))

results_with_proteingroups <- results[has_protein_groups]









