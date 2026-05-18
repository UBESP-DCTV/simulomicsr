# test-stage3-io.R — test round-trip write_stage3_to_dir + load_stage3

test_that("write_stage3_to_dir produce 5 file attesi", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  tmp_dir <- withr::local_tempdir()

  write_stage3_to_dir(s3, tmp_dir)

  expected_files <- c("assignments.parquet", "clusters.rds",
                      "record_summary.rds", "non_clusterable.rds",
                      "run_metadata.json")
  for (f in expected_files) {
    expect_true(file.exists(file.path(tmp_dir, f)), info = f)
  }
})

test_that("load_stage3 round-trip identico", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  input <- make_mock_stage3_input()
  s3_orig <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  tmp_dir <- withr::local_tempdir()
  write_stage3_to_dir(s3_orig, tmp_dir)

  s3_loaded <- load_stage3(tmp_dir)

  # Check key fields equal (tibble compare per valore)
  expect_equal(nrow(s3_loaded$assignments), nrow(s3_orig$assignments))
  expect_equal(nrow(s3_loaded$clusters), nrow(s3_orig$clusters))
  expect_equal(s3_loaded$run_metadata$run_id, s3_orig$run_metadata$run_id)
})

test_that("load_stage3 restituisce oggetto S3 class stage3_result", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  input <- make_mock_stage3_input()
  s3_orig <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  tmp_dir <- withr::local_tempdir()
  write_stage3_to_dir(s3_orig, tmp_dir)

  s3_loaded <- load_stage3(tmp_dir)
  expect_s3_class(s3_loaded, "stage3_result")
})

test_that("write_stage3_to_dir crea la directory se non esiste", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  base_dir <- withr::local_tempdir()
  new_dir <- file.path(base_dir, "subdir_nuovo")
  expect_false(dir.exists(new_dir))

  write_stage3_to_dir(s3, new_dir)
  expect_true(dir.exists(new_dir))
})

test_that("write_stage3_to_dir restituisce invisible paths (5 elementi)", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  tmp_dir <- withr::local_tempdir()

  paths <- write_stage3_to_dir(s3, tmp_dir)
  expect_length(paths, 5L)
  expect_true(all(file.exists(paths)))
})

test_that("write_stage3_to_dir fallisce su oggetto non-stage3_result", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  tmp_dir <- withr::local_tempdir()
  expect_error(write_stage3_to_dir(list(a = 1), tmp_dir))
})

test_that("load_stage3 fallisce su directory inesistente", {
  expect_error(load_stage3("/percorso/non/esiste"))
})
