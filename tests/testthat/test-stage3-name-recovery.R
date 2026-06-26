test_that(".parse_characteristics_kv: estrae coppie chiave:valore", {
  kv <- .parse_characteristics_kv("tissue: Blood, disease state: AD, cell type: PBMC")
  expect_equal(unname(kv[["disease state"]]), "ad")
  expect_equal(unname(kv[["tissue"]]), "blood")
  expect_equal(length(kv), 3L)
})

test_that(".parse_characteristics_kv: input vuoto/NA -> character(0)", {
  expect_length(.parse_characteristics_kv(NA_character_), 0L)
  expect_length(.parse_characteristics_kv(""), 0L)
})
