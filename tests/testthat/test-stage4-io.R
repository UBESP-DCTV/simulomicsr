test_that("write_stage4_to_dir produce i 5 file attesi", {
  skip_if_not_installed("arrow")

  tmp <- withr::local_tempdir()
  s4 <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "abc12345", timestamp = Sys.time())
  )

  paths <- write_stage4_to_dir(s4, tmp)

  expect_true(file.exists(file.path(tmp, "per_study_de.parquet")))
  expect_true(file.exists(file.path(tmp, "cluster_pooled.parquet")))
  expect_true(file.exists(file.path(tmp, "qc_report.rds")))
  expect_true(file.exists(file.path(tmp, "non_processable.rds")))
  expect_true(file.exists(file.path(tmp, "run_metadata.json")))
})

test_that("write_stage4_to_dir scrive la provenienza dello Stadio 3 nel JSON su disco", {
  skip_if_not_installed("arrow")

  # Task 11: il campo deve arrivare nel FILE, non solo restare nell'oggetto
  # in memoria — e' il punto in cui questo genere di modifica fallisce piu'
  # spesso (write_stage4_to_dir costruisce `meta` a mano, non serializza
  # s4$run_metadata cosi' com'e').
  tmp <- withr::local_tempdir()
  s4 <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(
      run_id = "abc12345", timestamp = Sys.time(),
      stage3 = list(run_id = "364547a7",
                    dir = "/tmp/x-stage3-v15-364547a7",
                    clusters_sha256 = "deadbeef")
    )
  )

  write_stage4_to_dir(s4, tmp)
  meta_on_disk <- jsonlite::fromJSON(file.path(tmp, "run_metadata.json"),
                                     simplifyVector = TRUE)

  expect_identical(meta_on_disk$stage3$run_id, "364547a7")
  expect_identical(meta_on_disk$stage3$dir, "/tmp/x-stage3-v15-364547a7")
  expect_identical(meta_on_disk$stage3$clusters_sha256, "deadbeef")
})

test_that("write_stage4_to_dir resta valido senza provenienza Stadio 3 (retrocompat)", {
  skip_if_not_installed("arrow")

  # s4$run_metadata senza campo `stage3` (chiamante pre-Task11, o oggetto
  # costruito a mano come nel test sopra): niente errore, campo presente
  # con valore mancante.
  tmp <- withr::local_tempdir()
  s4 <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "abc12345", timestamp = Sys.time())
  )

  expect_no_error(write_stage4_to_dir(s4, tmp))
  raw_json <- paste(readLines(file.path(tmp, "run_metadata.json")), collapse = "\n")
  meta_on_disk <- jsonlite::fromJSON(file.path(tmp, "run_metadata.json"),
                                     simplifyVector = TRUE)
  # La chiave "stage3" e' scritta nel JSON (grep sul file, non solo
  # sull'oggetto in memoria) — jsonlite deserializza `null` a NULL, non NA:
  # e' "campo presente con valore mancante", non l'assenza della chiave.
  expect_true(grepl('"stage3"', raw_json, fixed = TRUE))
  expect_true("stage3" %in% names(meta_on_disk))
  expect_true(is.null(meta_on_disk$stage3$run_id))
  expect_true(is.null(meta_on_disk$stage3$dir))
  expect_true(is.null(meta_on_disk$stage3$clusters_sha256))
})

test_that("load_stage4 round-trip preserva contenuto", {
  skip_if_not_installed("arrow")

  tmp <- withr::local_tempdir()
  s4_orig <- list(
    per_study_de = .empty_per_study_de(),
    cluster_pooled = .empty_pooled_rem(),
    eligible_clusters = tibble::tibble(cluster_id = character()),
    qc_report = list(qc_drops_sample = tibble::tibble(),
                      qc_drops_study = tibble::tibble(),
                      qc_drops_cluster = tibble::tibble(),
                      pooling_warnings = tibble::tibble()),
    non_processable = tibble::tibble(),
    config = stage4_default_config(),
    run_metadata = list(run_id = "test1234", timestamp = "2026-05-19T12:00:00Z")
  )

  write_stage4_to_dir(s4_orig, tmp)
  s4_back <- load_stage4(tmp)

  expect_equal(s4_back$run_metadata$run_id, "test1234")
  expect_equal(s4_back$config$qc$lib_size_min, 500000L)
})
