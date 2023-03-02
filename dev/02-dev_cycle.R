
# Project packages (TO BE UPDATED EVERY NEW PACKAGE USED) ----------

{
  meta_pkgs <- c()  # e.g., tidyverse, tidymodels, ...
  renv::install(meta_pkgs)


  prj_pkgs <- c(
    "dplyr", "fs", "purrr", "readr", "rhdf5", "stringr", "tibble",
    "tidyr", "tidyselect", "usethis"
  )
  renv::install(prj_pkgs)
  purrr::walk(prj_pkgs, usethis::use_package)

  bioc_pkgs <- c("rhdf5")
  renv::install(paste0("bioc::", bioc_pkgs))
  purrr::walk(bioc_pkgs, usethis::use_package)

  gh_prj_pkgs <- c()  # e.g. CorradoLanera/autotestthat
  renv::install(gh_prj_pkgs)
  purrr::walk(gh_prj_pkgs, ~{
    package_name <- stringr::str_extract(.x, "[\\w\\.]+$")
    usethis::use_dev_package(package_name, remote = .x)
  })

  dev_pkgs <- c(
    "checkmate", "covr", "devtools", "distill", "here",
    "htmltools", "knitr", "lintr", "qs", "rstudioapi",
    "spelling", "targets", "tarchetypes", "testthat", "withr"
  )
  renv::install(dev_pkgs)
  purrr::walk(dev_pkgs, usethis::use_package, type = "Suggests")


  bioc_dev_pkgs <- c("rpx")
  renv::install(paste0("bioc::", bioc_dev_pkgs))
  purrr::walk(bioc_dev_pkgs, usethis::use_package, type = "Suggests")


  usethis::use_tidy_description()
  devtools::document()
  renv::status()
}

renv::snapshot()

# Functions definitions -------------------------------------------

## if you need more structure respect to include your functions inside
## `R/functions.R`, you can create other couple of test/function-script
## by running the following lines of code as needed.

setup_func <- function(name) {
  usethis::use_test(name) |>
    basename() |>
    usethis::use_r()
}

setup_func("h5_functionalities")
setup_func("h5_utils")
setup_func("prot_func")
setup_func("prot_utils")



