library(targets)
library(tarchetypes)
# This is an example _targets.R file. Every
# {targets} pipeline needs one.
# Use tar_script() to create _targets.R and tar_edit()
# to open it again for editing.
# Then, run tar_make() to run the pipeline
# and tar_read(result) to view the results.

# Define custom functions and other global objects.
# This is where you write source(\"R/functions.R\")
# if you keep your functions in external scripts.
list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE) |>
  lapply(source) |> invisible()

# Set target-specific options such as packages.
tar_option_set(
  error = "continue",
  workspace_on_error = TRUE,
  format = "qs"
)

# End this file with a list of target objects.
list(

  tar_target(
    h5DataPath,
    get_input_data_path("RNAseq/archs4_gene_human_v2.1.2.h5"),
    format = "file"
  ),

  tar_target(h5GeneNames, h5_gene_names(h5DataPath)),
  tar_target(h5Summary, h5_summary(h5DataPath))

  # # compile yor report
  # tar_render(report, here::here("reports/report.Rmd")),
  #
  #
  # # Decide what to share with other, and do it in a standard RDS format
  # tar_target(
  #   objectToShare,
  #   list(
  #     relevant_result = relevantResult
  #   )
  # ),
  # tar_target(
  #   shareOutput,
  #   share_objects(objectToShare),
  #   format = "file",
  #   pattern = map(objectToShare)
  # )
)
