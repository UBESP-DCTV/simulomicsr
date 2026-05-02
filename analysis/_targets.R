library(targets)
library(tarchetypes)

# Carica tutte le funzioni della libreria simulomicsr
list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE) |>
  lapply(source) |>
  invisible()

tar_option_set(
  packages = c("tibble", "dplyr", "readxl"),
  format   = "qs",
  error    = "continue",
  workspace_on_error = TRUE
)

list(
  tar_target(
    samples_input_path,
    here::here("data-raw", "relevant_sample_classified.xlsx"),
    format = "file"
  ),

  tar_target(
    samples_input,
    read_samples_input(samples_input_path)
  ),

  tar_target(
    samples_dev_set,
    build_dev_set(samples_input, n = 100L, seed = 1812L)
  )
)
