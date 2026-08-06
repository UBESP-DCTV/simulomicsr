test_that(".lb_titolo mette entita e numero di studi nel titolo", {
  expect_equal(simulomicsr:::.lb_titolo("TGF-beta1", 59L),
               "TGF-beta1 · 59 studies")
  expect_equal(simulomicsr:::.lb_titolo("TGF-beta1", 59L, "strongest genes"),
               "TGF-beta1 · 59 studies · strongest genes")
  expect_equal(simulomicsr:::.lb_titolo("X", 1L), "X · 1 study")
})

test_that(".lb_titolo con k=NA non stampa 'NA studi' (minor, 2026-08-06)", {
  expect_equal(simulomicsr:::.lb_titolo("X", NA_integer_), "X")
  expect_false(grepl("NA", simulomicsr:::.lb_titolo("X", NA_integer_), fixed = TRUE))
  expect_equal(simulomicsr:::.lb_titolo("X", NA_integer_, "extra"), "X · extra")
})

test_that(".lb_theme e' un tema ggplot2 e .LB_COLORI ha le cinque tinte", {
  expect_s3_class(simulomicsr:::.lb_theme(), "theme")
  expect_setequal(names(simulomicsr:::.LB_COLORI),
                  c("su", "giu", "neutro", "evidenza", "per_studio"))
})
