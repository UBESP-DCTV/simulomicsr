test_that(".lb_titolo mette entita e numero di studi nel titolo", {
  expect_equal(simulomicsr:::.lb_titolo("TGF-beta1", 59L),
               "TGF-beta1 · 59 studi")
  expect_equal(simulomicsr:::.lb_titolo("TGF-beta1", 59L, "geni piu' forti"),
               "TGF-beta1 · 59 studi · geni piu' forti")
  expect_equal(simulomicsr:::.lb_titolo("X", 1L), "X · 1 studio")
})

test_that(".lb_theme e' un tema ggplot2 e .LB_COLORI ha le quattro tinte", {
  expect_s3_class(simulomicsr:::.lb_theme(), "theme")
  expect_setequal(names(simulomicsr:::.LB_COLORI),
                  c("su", "giu", "neutro", "evidenza"))
})
