test_that(".qc_filter_samples_and_studies marca sample sotto lib_size_min", {
  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  result <- .qc_filter_samples_and_studies(
    stage3_clusters = input$clusters,
    h5_metadata = input$h5_metadata,
    config = cfg
  )

  expect_named(result, c("eligible_clusters", "qc_drops_sample",
                          "qc_drops_study", "qc_drops_cluster"),
               ignore.order = TRUE)
  expect_true(nrow(result$qc_drops_sample) >= 0L)
  expect_true(all(result$qc_drops_sample$lib_size < 500000L))
})

test_that("identify_layer_a_clusters filtra correttamente i 3 path", {
  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  la <- .identify_layer_a_clusters(input$clusters, stage4_config = cfg)

  expect_true(all(la$method %in% c("rem", "mega", "mega_aug")))
  expect_equal(sum(la$method == "rem"), 1L)
  expect_equal(sum(la$method == "mega"), 1L)
})

test_that("cluster con tutti sample droppati va in qc_drops_cluster", {
  input <- make_test_stage4_input(seed = 42L)
  # forza lib_size = 100k per tutti i sample di GSE001
  input$h5_metadata$lib_size[input$h5_metadata$gse == "GSE001"] <- 100000L

  cfg <- stage4_default_config()
  result <- .qc_filter_samples_and_studies(input$clusters, input$h5_metadata, cfg)

  expect_true(any(result$qc_drops_study$study_id == "GSE001"))
})
