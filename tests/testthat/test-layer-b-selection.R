test_that(".load_layer_b_selection reads CSV with required columns", {
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv))
  writeLines(c(
    "cluster_id,label_paper,priority,notes",
    "pair_L0_abc123,IFN_A549,1,Type-I interferon canonical",
    "group_L0_def456,LNCaP_androgen,2,"
  ), csv)

  sel <- simulomicsr:::.load_layer_b_selection(csv)
  expect_s3_class(sel, "tbl_df")
  expect_named(sel, c("cluster_id", "label_paper", "priority", "notes"))
  expect_equal(nrow(sel), 2L)
  expect_type(sel$priority, "integer")
  expect_equal(sel$cluster_id, c("pair_L0_abc123", "group_L0_def456"))
})

test_that(".load_layer_b_selection accepts data.frame directly (polimorfismo)", {
  df <- tibble::tibble(
    cluster_id  = c("pair_L0_xxx", "group_L0_yyy"),
    label_paper = c("Case A", "Case B"),
    priority    = c(1L, 2L),
    notes       = c("", "test")
  )
  sel <- simulomicsr:::.load_layer_b_selection(df)
  expect_s3_class(sel, "tbl_df")
  expect_equal(nrow(sel), 2L)
})

test_that(".load_layer_b_selection fails on missing required columns", {
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv))
  writeLines(c("cluster_id,label_paper", "pair_L0_abc,IFN"), csv)
  expect_error(
    simulomicsr:::.load_layer_b_selection(csv),
    "missing required column"
  )
})

test_that(".load_layer_b_selection fails on duplicate cluster_id", {
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv))
  writeLines(c(
    "cluster_id,label_paper,priority,notes",
    "pair_L0_dup,A,1,",
    "pair_L0_dup,B,2,"
  ), csv)
  expect_error(
    simulomicsr:::.load_layer_b_selection(csv),
    "duplicate cluster_id"
  )
})
