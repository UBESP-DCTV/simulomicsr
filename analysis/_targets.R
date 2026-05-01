library(targets)
library(tarchetypes)

# Carica tutte le funzioni della libreria simulomicsr
list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE) |>
  lapply(source) |>
  invisible()

tar_option_set(
  error = "continue",
  workspace_on_error = TRUE
)

# Pipeline reale popolata in P3 (vedi
# docs/superpowers/specs/2026-04-29-classificatore-llm-design.md §5.2 e
# il futuro plan P3). In P1 questo file è uno scheletro per non rompere
# `targets::tar_make()` quando viene invocato durante setup.
list(
)
