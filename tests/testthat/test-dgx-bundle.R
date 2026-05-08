test_that("dgx_p4_build_bundle() stage1 crea bundle valido", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()

  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage       = "stage1",
    config      = cfg,
    metadata    = list(slug = "test-stage1"),
    bundle_dir_root = td
  )

  expect_s3_class(bundle, "simulomicsr_dgx_bundle")
  expect_true(fs::dir_exists(bundle$bundle_dir))

  # Files richiesti
  for (fn in c("manifest.json", "input.jsonl", "prompt.txt",
               "schema.json", "generation.json", "status.json")) {
    expect_true(fs::file_exists(fs::path(bundle$bundle_dir, fn)),
                info = paste("file mancante:", fn))
  }

  # Manifest content
  m <- jsonlite::read_json(fs::path(bundle$bundle_dir, "manifest.json"))
  expect_identical(m$stage, "stage1")
  expect_identical(m$record_count, 5L)
  expect_identical(m$model_id, "mistralai/Mistral-Small-3.2-24B-Instruct-2506")
  expect_match(m$run_id, "^\\d{8}T\\d{6}Z-test-stage1-[a-f0-9]{6}$")

  # Schema embedded valido (vedi inst/schemas/sample_facts.stage1.v3.json)
  schema <- jsonlite::read_json(fs::path(bundle$bundle_dir, "schema.json"))
  expect_identical(schema$title, "sample_facts.stage1.v3")

  # Prompt.txt non vuoto
  prompt_size <- fs::file_info(fs::path(bundle$bundle_dir, "prompt.txt"))$size
  expect_gt(prompt_size, 500L)

  # input.jsonl ha 5 righe
  lines <- readLines(fs::path(bundle$bundle_dir, "input.jsonl"))
  expect_length(lines, 5L)

  # Generation config max_tokens 2048 per stage1 (bumpato da 1024 dopo
  # investigation 211 residual fails 2026-05-07 — vedi ADR-0008 addendum).
  gen <- jsonlite::read_json(fs::path(bundle$bundle_dir, "generation.json"))
  expect_identical(gen$max_tokens, 2048L)
  expect_identical(gen$temperature, 0)
  # repetition_penalty 1.1 e' il default da 0.0.0.9010.
  expect_identical(gen$repetition_penalty, 1.1)

  # Status iniziale
  st <- jsonlite::read_json(fs::path(bundle$bundle_dir, "status.json"))
  expect_identical(st$state, "created")
})

test_that("dgx_p4_build_bundle() stage2 usa schema e max_tokens corretti", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage2.jsonl"),
    stage       = "stage2",
    config      = cfg,
    metadata    = list(slug = "test-stage2"),
    bundle_dir_root = td
  )

  schema <- jsonlite::read_json(fs::path(bundle$bundle_dir, "schema.json"))
  expect_identical(schema$title, "study_design.stage2.v2")

  gen <- jsonlite::read_json(fs::path(bundle$bundle_dir, "generation.json"))
  # max_tokens 4096 (Task 22 RESOLVED 2026-05-08): smoke T5h 500 record cs25
  # → 97% schema validity con 4096 vs 60% con 1024 (40% truncation a 1024).
  # I 3% residui hanno output >3000 token, rescue post-hoc con max_tokens=8192.
  expect_identical(gen$max_tokens, 4096L)
  # scheduler_reserve_full_isl=false: workaround vLLM Issue #39734 (Task 22
  # RESOLVED 2026-05-08). Defense-in-depth — Path C (chunk_size=25) gia'
  # evita la zona-bug.
  expect_identical(gen$scheduler_reserve_full_isl, FALSE)

  m <- jsonlite::read_json(fs::path(bundle$bundle_dir, "manifest.json"))
  expect_identical(m$stage, "stage2")
  expect_identical(m$record_count, 3L)
})

test_that("dgx_p4_build_bundle() rifiuta stage non noto", {
  cfg <- dgx_config()
  expect_error(
    dgx_p4_build_bundle(
      input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
      stage = "stage42",
      config = cfg
    ),
    class = "simulomicsr_dgx_unknown_stage"
  )
})

test_that("dgx_p4_build_bundle() rifiuta input_jsonl inesistente", {
  cfg <- dgx_config()
  expect_error(
    dgx_p4_build_bundle(
      input_jsonl = "/tmp/does-not-exist-zzzz.jsonl",
      stage = "stage1",
      config = cfg
    ),
    class = "simulomicsr_dgx_input_missing"
  )
})
