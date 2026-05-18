# test-stage3-helpers.R — test di filter_clusters e cluster_records

test_that("filter_clusters(mode='pair', usability='strict') restituisce usable_rem_strict", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)

  result <- filter_clusters(s3, mode = "pair", usability = "strict")
  expect_true(all(result$mode == "pair"))
  # Tutti i cluster passati devono avere usable_rem_strict TRUE, oppure result e' vuoto
  if (nrow(result) > 0L) {
    expect_true(all(result$usable_rem_strict))
  }
})

test_that("filter_clusters(mode='any', usability='any') restituisce tutti", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  result <- filter_clusters(s3, mode = "any", usability = "any")
  expect_equal(nrow(result), nrow(s3$clusters))
})

test_that("cluster_records ritorna records di un cluster specifico", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)

  if (nrow(s3$clusters) > 0L) {
    first_cl <- s3$clusters$cluster_id[1]
    recs <- cluster_records(s3, first_cl)
    expect_true(nrow(recs) > 0L)
    expect_true(all(recs$cluster_id == first_cl))
  }
})

test_that("filter_clusters(mode='pair', usability='relaxed') restituisce solo usable_rem_relaxed", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  result <- filter_clusters(s3, mode = "pair", usability = "relaxed")
  expect_true(all(result$mode == "pair"))
  if (nrow(result) > 0L) {
    expect_true(all(result$usable_rem_relaxed))
  }
})

test_that("filter_clusters(mode='group', usability='strict') restituisce solo usable_mega_strict", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  result <- filter_clusters(s3, mode = "group", usability = "strict")
  expect_true(all(result$mode == "group"))
  if (nrow(result) > 0L) {
    expect_true(all(result$usable_mega_strict))
  }
})

test_that("filter_clusters(mode='any', usability='strict') restituisce cluster usable in almeno un modo", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  result <- filter_clusters(s3, mode = "any", usability = "strict")
  if (nrow(result) > 0L) {
    usable_either <- result$usable_rem_strict | result$usable_mega_strict
    # Rimuovi NA prima del controllo
    expect_true(all(.isTRUE_vec(usable_either)))
  }
})

test_that("filter_clusters con s3 non-stage3_result genera errore", {
  expect_error(filter_clusters(list(), mode = "any"), class = "simpleError")
})

test_that("cluster_records con s3 non-stage3_result genera errore", {
  expect_error(cluster_records(list(), "cl_001"), class = "simpleError")
})

test_that("cluster_records con cluster_id inesistente restituisce 0 righe", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master)
  recs <- cluster_records(s3, "cluster_inesistente_xyz")
  expect_equal(nrow(recs), 0L)
})
