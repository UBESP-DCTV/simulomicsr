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
)

to_use <- str_detect(r[["characteristics_ch1"]], "treatment")

res <- tibble(
  string = r[["characteristics_ch1"]][to_use],
  geo_accession = r[["geo_accession"]][to_use],
  series_id = r[["series_id"]][to_use],
  treat = extract_treatment(string),
  trtctr = trt2casecontrol(treat)
) |>
  map_dfc(as.character) |>
  remove_missing() |>
  with_groups(series_id, dplyr::filter, any(trtctr == "control")) |>
  mutate(trtctr = if_else(trtctr != "control", "treated", trtctr)) |>
  with_groups(series_id, dplyr::filter, any(trtctr == "treated")) |>
  depigner::view_in_excel()




readr::write_rds(res, file = "relevant_sample.rds")

slice_head(res, n = 98) |> print(n = Inf)

res$treat |>
  trt2casecontrol() |>
  unique()
