# Bundle DGX dello Stadio 2b (S12p, prova cieca su tre modelli). Ingresso
# sintetico: nessun accession GEO (cancello C5 di S12 sui test dello Stadio 2b).

.s2b_ingresso_bundle <- function(dir, righe = NULL) {
  p <- fs::path(dir, "ingresso-stage2b.jsonl")
  if (is.null(righe)) {
    righe <- c(
      jsonlite::toJSON(list(record_id = "conf_1", testo = "# Comparison under review\nTreated arm label (from the pipeline): compound K17"), auto_unbox = TRUE),
      jsonlite::toJSON(list(record_id = "conf_2", testo = "# Comparison under review\nTreated arm label (from the pipeline): factor Q2 µM"), auto_unbox = TRUE)
    )
  }
  writeLines(righe, p, useBytes = TRUE)
  p
}

test_that("dgx_p4_build_bundle() stage2b: schema, prompt identico, generazione della spec", {
  td <- withr::local_tempdir()
  b <- dgx_p4_build_bundle(.s2b_ingresso_bundle(td), stage = "stage2b",
                           config = dgx_config(), metadata = list(slug = "test-s2b"),
                           bundle_dir_root = td)
  schema <- jsonlite::read_json(fs::path(b$bundle_dir, "schema.json"))
  expect_identical(schema$title, "comparison_check.stage2b.v1")
  # Il prompt del bundle e' byte per byte il messaggio di sistema dello Stadio 2b,
  # senza un a capo aggiunto in coda.
  p <- readChar(fs::path(b$bundle_dir, "prompt.txt"),
                fs::file_info(fs::path(b$bundle_dir, "prompt.txt"))$size, useBytes = TRUE)
  Encoding(p) <- "UTF-8"
  expect_identical(p, .s2b_prompt_sistema())
  gen <- jsonlite::read_json(fs::path(b$bundle_dir, "generation.json"))
  expect_identical(gen$max_tokens, .S2B_RISERVA_RISPOSTA)
  expect_identical(gen$max_model_len, .S2B_MAX_MODEL_LEN)
  expect_identical(gen$temperature, 0)
  expect_identical(gen$repetition_penalty, 1.1)
  expect_identical(gen$model_id, "mistralai/Mistral-Small-3.2-24B-Instruct-2506")
  m <- jsonlite::read_json(fs::path(b$bundle_dir, "manifest.json"))
  expect_identical(m$stage, "stage2b")
  expect_identical(m$record_count, 2L)
  expect_identical(m$model_id, gen$model_id)
})

test_that("dgx_p4_build_bundle() stage2b: il modello si cambia, il resto della generazione no", {
  td <- withr::local_tempdir()
  ing <- .s2b_ingresso_bundle(td)
  b0 <- dgx_p4_build_bundle(ing, stage = "stage2b", config = dgx_config(),
                            metadata = list(slug = "s2b-a"), bundle_dir_root = td)
  mod <- list(model_id = "google/gemma-4-31B-it", tokenizer_mode = "auto",
              config_format = "auto", load_format = "auto",
              llm_extra = list(limit_mm_per_prompt = list(image = 0L)))
  b1 <- dgx_p4_build_bundle(ing, stage = "stage2b", config = dgx_config(),
                            metadata = list(slug = "s2b-b"), bundle_dir_root = td,
                            modello = mod)
  g0 <- jsonlite::read_json(fs::path(b0$bundle_dir, "generation.json"))
  g1 <- jsonlite::read_json(fs::path(b1$bundle_dir, "generation.json"))
  expect_identical(g1$model_id, "google/gemma-4-31B-it")
  expect_identical(g1$tokenizer_mode, "auto")
  expect_identical(g1$llm_extra$limit_mm_per_prompt$image, 0L)
  campi_modello <- c(names(mod))
  expect_identical(g0[setdiff(names(g0), campi_modello)], g1[setdiff(names(g1), campi_modello)])
  m1 <- jsonlite::read_json(fs::path(b1$bundle_dir, "manifest.json"))
  expect_identical(m1$model_id, "google/gemma-4-31B-it")
  # prompt e schema non dipendono dal modello
  for (f in c("prompt.txt", "schema.json"))
    expect_identical(unname(tools::md5sum(fs::path(b0$bundle_dir, f))),
                     unname(tools::md5sum(fs::path(b1$bundle_dir, f))))
})

test_that("dgx_p4_build_bundle(): un campo del modello sconosciuto ferma il bundle", {
  td <- withr::local_tempdir()
  expect_error(
    dgx_p4_build_bundle(.s2b_ingresso_bundle(td), stage = "stage2b", config = dgx_config(),
                        bundle_dir_root = td, modello = list(model_id = "x", temperatura = 1)),
    class = "simulomicsr_dgx_modello_campo_sconosciuto"
  )
})

test_that("dgx_p4_build_bundle() stage2b: ogni riga dell'ingresso ha record_id e testo", {
  td <- withr::local_tempdir()
  cattivo <- .s2b_ingresso_bundle(td, righe = c(
    jsonlite::toJSON(list(record_id = "conf_1", testo = "a"), auto_unbox = TRUE),
    jsonlite::toJSON(list(record_id = "conf_2"), auto_unbox = TRUE)))
  expect_error(
    dgx_p4_build_bundle(cattivo, stage = "stage2b", config = dgx_config(), bundle_dir_root = td),
    class = "simulomicsr_dgx_stage2b_ingresso_non_valido"
  )
})
