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
  # scheduler_reserve_full_isl: rimosso dal yaml 2026-05-08 dopo bootstrap
  # fail job 19879 (vLLM 0.10.0 non accetta il kwarg Python). Path C
  # (chunk_size=25) resta il primary defense Issue #39734. La propagazione
  # resta nel codice (per future versioni vLLM) ma il default non la include.
  expect_null(gen$scheduler_reserve_full_isl)
  # SAFE-MODE 2026-05-08 (ADR-0009): max_num_seqs=1 + microbatch=1 →
  # elimina concorrenza inter-request → deadlock-proof per costruzione.
  # Sostituisce Path C come primary defense Issue #39734 (Path C era
  # probabilistico, vedi worker 1 stall job 19948 alpha-stage2-cs25).
  expect_identical(gen$max_num_seqs, 1L)
  expect_identical(gen$microbatch, 1L)

  m <- jsonlite::read_json(fs::path(bundle$bundle_dir, "manifest.json"))
  expect_identical(m$stage, "stage2")
  expect_identical(m$record_count, 3L)
  expect_false(m$tiered_max_tokens %||% FALSE)
})

test_that(".dgx_tier_max_tokens() classifica per soglia byte", {
  KB <- 1024L
  out <- simulomicsr:::.dgx_tier_max_tokens(c(
    5  * KB,             # S
    14 * KB - 1L,        # S (sotto 15 KB)
    15 * KB,             # M
    20 * KB,             # M
    25 * KB,             # L
    34 * KB,             # L
    35 * KB,             # XL
    100 * KB             # XL
  ))
  expect_identical(out$tier, c("S", "S", "M", "M", "L", "L", "XL", "XL"))
  expect_identical(out$max_tokens, c(4096L, 4096L, 8192L, 8192L,
                                      16384L, 16384L, 32768L, 32768L))
})

test_that("dgx_p4_build_bundle(tiered_max_tokens=TRUE) annota per-record", {
  cfg <- dgx_config()
  td  <- withr::local_tempdir()

  # Costruisco un input jsonl sintetico con 4 record di tier diversi.
  # Uso campo "padding" per gonfiare il record fino al tier desiderato.
  KB <- 1024L
  mk <- function(rid, target_kb) {
    base <- list(record_id = rid, study_summary = "synthetic",
                 samples = list(list(geo_accession = "GSM1")))
    j <- jsonlite::toJSON(base, auto_unbox = TRUE)
    cur <- nchar(j, type = "bytes")
    pad_size <- target_kb * KB - cur - 50L  # 50 bytes di overhead per "padding":""
    if (pad_size < 0) pad_size <- 0L
    base$padding <- strrep("x", pad_size)
    jsonlite::toJSON(base, auto_unbox = TRUE)
  }
  inp <- fs::path(td, "in.jsonl")
  writeLines(c(
    mk("REC_S",  5L),
    mk("REC_M", 20L),
    mk("REC_L", 30L),
    mk("REC_XL", 40L)
  ), inp)

  bundle <- dgx_p4_build_bundle(
    input_jsonl       = inp,
    stage             = "stage2",
    config            = cfg,
    metadata          = list(slug = "test-tiered"),
    bundle_dir_root   = td,
    tiered_max_tokens = TRUE
  )

  # tier_summary nel return
  expect_identical(bundle$tier_summary$S,  1L)
  expect_identical(bundle$tier_summary$M,  1L)
  expect_identical(bundle$tier_summary$L,  1L)
  expect_identical(bundle$tier_summary$XL, 1L)

  # input.jsonl deve avere field max_tokens per ogni record
  out_lines <- readLines(fs::path(bundle$bundle_dir, "input.jsonl"))
  rec_S  <- jsonlite::fromJSON(out_lines[1], simplifyVector = FALSE)
  rec_M  <- jsonlite::fromJSON(out_lines[2], simplifyVector = FALSE)
  rec_L  <- jsonlite::fromJSON(out_lines[3], simplifyVector = FALSE)
  rec_XL <- jsonlite::fromJSON(out_lines[4], simplifyVector = FALSE)
  expect_identical(rec_S$max_tokens,  4096L)
  expect_identical(rec_M$max_tokens,  8192L)
  expect_identical(rec_L$max_tokens,  16384L)
  expect_identical(rec_XL$max_tokens, 32768L)

  # generation.json: max_tokens globale = max(tier) = 32768; max_model_len = 65536 (L/XL bump)
  gen <- jsonlite::read_json(fs::path(bundle$bundle_dir, "generation.json"))
  expect_identical(gen$max_tokens, 32768L)
  expect_identical(gen$max_model_len, 65536L)

  # manifest registra il flag
  m <- jsonlite::read_json(fs::path(bundle$bundle_dir, "manifest.json"))
  expect_true(isTRUE(m$tiered_max_tokens))
})

test_that("tiered_max_tokens stage1 errore (unsupported)", {
  cfg <- dgx_config()
  td  <- withr::local_tempdir()
  expect_error(
    dgx_p4_build_bundle(
      input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
      stage = "stage1", config = cfg,
      bundle_dir_root = td, tiered_max_tokens = TRUE
    ),
    class = "simulomicsr_dgx_tiered_stage1_unsupported"
  )
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
