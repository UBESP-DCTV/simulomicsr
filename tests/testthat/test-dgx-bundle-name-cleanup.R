# Task 10 (RED_ALERT F6, pulizia-nomi Stadio 3 scope A): stage `name_cleanup`
# nel bundle/runner DGX. Verifica additiva — NON deve alterare stage1/stage2
# (vedi test di regressione stage1 in fondo a questo file, oltre a
# test-dgx-bundle.R esistente che resta invariato).

test_that("dgx_p4_build_bundle() stage name_cleanup crea bundle valido", {
  cfg <- dgx_config()
  td  <- withr::local_tempdir()

  # Input jsonl minimale a 2 record: campi record_id/current_label/kind/
  # member_metadata (R/name-cleanup.R::.build_name_cleanup_messages()).
  inp <- fs::path(td, "name-cleanup-in.jsonl")
  writeLines(c(
    jsonlite::toJSON(list(
      record_id = "cluster_L2_abc123",
      current_label = "STR:carnitine_exposed",
      kind = "small_molecule",
      member_metadata = "carnitine 10mM 24h treated | control untreated"
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      record_id = "cluster_L4_def456",
      current_label = "STR:sars_cov_2_infected",
      kind = "pathogen_or_aggregate_exposure",
      member_metadata = "SARS-CoV-2 infected lung | mock infected control"
    ), auto_unbox = TRUE)
  ), inp)

  bundle <- dgx_p4_build_bundle(
    input_jsonl     = inp,
    stage           = "name_cleanup",
    config          = cfg,
    metadata        = list(slug = "test-name-cleanup"),
    bundle_dir_root = td
  )

  expect_s3_class(bundle, "simulomicsr_dgx_bundle")
  expect_identical(bundle$stage, "name_cleanup")
  expect_identical(bundle$record_count, 2L)

  # prompt.txt deve contenere il testo del system prompt name-cleanup
  # (R/name-cleanup.R::.name_cleanup_system_prompt()).
  prompt_txt <- paste(readLines(fs::path(bundle$bundle_dir, "prompt.txt")),
                      collapse = "\n")
  expect_identical(prompt_txt, simulomicsr:::.name_cleanup_system_prompt())
  expect_match(prompt_txt, "canonical_name", fixed = TRUE)

  # schema.json deve combaciare con inst/schemas/name_cleanup.v1.json
  schema_bundled <- jsonlite::read_json(fs::path(bundle$bundle_dir, "schema.json"))
  schema_src <- jsonlite::read_json(
    system.file("schemas", "name_cleanup.v1.json", package = "simulomicsr")
  )
  expect_identical(schema_bundled, schema_src)
  expect_identical(schema_bundled$title, "name_cleanup.v1")

  # manifest.json: stage == "name_cleanup"
  m <- jsonlite::read_json(fs::path(bundle$bundle_dir, "manifest.json"))
  expect_identical(m$stage, "name_cleanup")
  expect_identical(m$schema_file, "name_cleanup.v1.json")
  expect_identical(m$record_count, 2L)

  # generation.json: max_tokens/max_model_len/microbatch dal blocco yaml
  # stages.name_cleanup (Step 2).
  gen <- jsonlite::read_json(fs::path(bundle$bundle_dir, "generation.json"))
  expect_identical(gen$max_tokens, 1024L)
  expect_identical(gen$max_model_len, 8192L)
  expect_identical(gen$microbatch, 50L)
  expect_identical(gen$temperature, 0)
  expect_identical(gen$repetition_penalty, 1.1)
})

test_that("dgx_p4_build_bundle() stage1 resta invariato (regressione)", {
  cfg <- dgx_config()
  td  <- withr::local_tempdir()

  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage       = "stage1",
    config      = cfg,
    metadata    = list(slug = "test-stage1-regression"),
    bundle_dir_root = td
  )

  expect_identical(bundle$stage, "stage1")
  m <- jsonlite::read_json(fs::path(bundle$bundle_dir, "manifest.json"))
  expect_identical(m$stage, "stage1")
  expect_identical(m$schema_file, "sample_facts.stage1.v3.json")

  gen <- jsonlite::read_json(fs::path(bundle$bundle_dir, "generation.json"))
  expect_identical(gen$max_tokens, 2048L)

  prompt_txt <- paste(readLines(fs::path(bundle$bundle_dir, "prompt.txt")),
                      collapse = "\n")
  expect_identical(prompt_txt, simulomicsr:::.stage1_system_prompt())
})
