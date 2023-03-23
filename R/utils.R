
# Here below put your small tiny supporting functions -------------


view_in_excel <- function(.data) {
  if (interactive()) {
    tmp <- fs::file_temp("excel", ext = "csv")
    readr::write_excel_csv(.data, tmp)
    fs::file_show(tmp)
  }
  invisible(.data)
}


trt2casecontrol <- function(string) {
  lowered <- stringr::str_to_lower(string)
  ctrs <- paste(
    paste0(
      "(",
      c(
        "none", "control", "non-treated", "vehicle", "dmso", "demso",
        "dmem", "dsmo", "dpbs", "na", "no[ _]treat", "untreated", "^no$",
        "^normal$", "ctrl", "mock", "no *drug", "normoxia", "placebo",
        "Unstimulated", "empty *vector", "^0$", "Media", "medium",
        "without", "Non-stimulated", "((\\s|^)0 ?../.?l)",
        "((\\s|^)0 ?..(\\s|$))", "No *treatment", "Empty", "ctr",
        "No \\S+ treatment", "health *individual", "healthy *donor",
        "GFP only", "FBS", "EtOH", "ethonol", "^et$", "^doxy?-$",
        "distilled water", "dmo[gs]", "MethodBlank_0", "pbs", "ctl",
        "^nt$", "(pre|un)[ -_]?treat(ment|ed)?", "Uninfected", "NO Dox",
        "no_treament", "no .+ treatment", "^pre$", "pre-guadecitabine",
        "baseline", "normal growing"

      ),
      ")",
      collapse = "|"
    ),
    sep = "|",
    collapse = "|"
  ) |>
    stringr::str_to_lower()
  trts <- paste(
    paste0("(^",
      c(
        "yes", "treatment", "treated", "treat", "exercise", "Drug.*",
        "infected", "flu-infected", "^\\w+mab$"
      ),
    "$)", collapse = "|"),
    "Compound",
    "([123456789]\\d*)",
    "([123456789]\\d* ?../.?l)",
    "([123456789]\\d* ?.mol)",
    sep = "|",
    collapse = "|"
  ) |>
    stringr::str_to_lower()

  is_ctr <- stringr::str_detect(lowered, ctrs)
  is_trt <- stringr::str_detect(lowered, trts)

  dplyr::case_when(
    is_ctr ~ "control",
    is_trt ~ "treated",
    TRUE ~ string
  )
}

extract_treatment <- function(string) {
  stringr::str_extract(string, "(?<=treatment: )[^,]+(?=,?)")
}

extract_fct_names <- function(path) {
  readr::read_lines(path) |>
    stringr::str_extract_all("^.*(?=`? ?<- ?function)") |>
    unlist() |>
    purrr::compact() |>
    stringr::str_remove_all("[\\s`]+")
}



get_input_data_path <- function(x) {
  file.path(
    Sys.getenv("PRJ_SHARED_PATH"),
    Sys.getenv("INPUT_DATA_FOLDER"),
    x
  ) |>
    normalizePath()
}

get_output_data_path <- function(x) {
  file.path(
    Sys.getenv("PRJ_SHARED_PATH"),
    Sys.getenv("OUTPUT_DATA_FOLDER"),
    x
  ) |>
    normalizePath()
}


share_objects <- function(obj_list) {
  file_name <- paste0(names(obj_list), ".rds")

  obj_paths <- file.path(get_output_data_path(file_name)) |>
    normalizePath(mustWork = FALSE) |>
    purrr::set_names(names(obj_list))

  # Those must be RDS
  purrr::walk2(obj_list, obj_paths, readr::write_rds)
  obj_paths
}


`%||%` <- function(x, y) if (is.null(x)) y else x









