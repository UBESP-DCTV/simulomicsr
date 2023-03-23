## Use this script to run exploratory code maybe before to put it into
## the pipeline


# setup -----------------------------------------------------------

library(tidyverse)
library(targets)
library(here)

# load all your custom functions
list.files(here("R"), pattern = "\\.R$", full.names = TRUE) |>
  lapply(source) |> invisible()


# Code here below -------------------------------------------------
# use `tar_read(target_name)` to load a target anywhere (note that
# `target_name` is NOT quoted!)

sample_db <- tar_read(h5Expression50Rand1)


sample_db[, seq_len(5^2)] |>
  pivot_longer(everything()) |>
  ggplot(aes(value)) +
  geom_histogram() +
  facet_wrap(~name, scales = "free")


r <- rhdf5::h5read(
  tar_read(h5DataPath),
  "meta/samples"
)[["characteristics_ch1"]]

res <- tibble(
  string = str_subset(r, "treatment"),
  treat =
)

slice_head(res, n = 98) |> print(n = Inf)
