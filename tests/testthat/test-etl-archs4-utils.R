test_that("build_sample_string_format_B concatena title + source + characteristics", {
  result <- build_sample_string_format_B(
    title = "RNA-seq of MCF7 tamoxifen 24h",
    source_name_ch1 = "MCF7 cell line",
    characteristics_ch1 = "cell line: MCF7,treatment: tamoxifen 1uM,timepoint: 24h"
  )
  expect_equal(
    result,
    "title: RNA-seq of MCF7 tamoxifen 24h,source: MCF7 cell line,cell line: MCF7,treatment: tamoxifen 1uM,timepoint: 24h"
  )
})

test_that("build_sample_string_format_B gestisce NA/empty graceful", {
  expect_equal(
    build_sample_string_format_B(NA, "src", "key: value"),
    "source: src,key: value"
  )
  expect_equal(
    build_sample_string_format_B("", "", "key: value"),
    "key: value"
  )
  expect_equal(
    build_sample_string_format_B(NA, NA, NA),
    ""
  )
})

test_that("is_sample_classifiable filtra organism, library_strategy, string length", {
  expect_true(is_sample_classifiable("Homo sapiens", "RNA-Seq", "title: x,key: very long enough metadata"))
  expect_false(is_sample_classifiable("Mus musculus", "RNA-Seq", "title: x,key: y val"))
  expect_false(is_sample_classifiable("Homo sapiens", "scRNA-seq", "title: x,key: very long metadata"))
  expect_false(is_sample_classifiable("Homo sapiens", "RNA-Seq", "short"))
})
