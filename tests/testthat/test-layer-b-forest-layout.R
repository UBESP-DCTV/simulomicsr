test_that(".forest_layout_pannelli: le altezze sono proporzionate al numero di righe", {
  layout_pochi <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 6L)
  layout_tanti <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 60L)

  # il rapporto altezza-inferiore/altezza-superiore cresce col numero di studi:
  # il vecchio heights=c(2,1) era fisso qualunque fosse il conteggio.
  rapporto_pochi <- layout_pochi$heights[2] / layout_pochi$heights[1]
  rapporto_tanti <- layout_tanti$heights[2] / layout_tanti$heights[1]
  expect_gt(rapporto_tanti, rapporto_pochi)
})

test_that(".forest_layout_pannelli: l'altezza totale ha un tetto stampabile", {
  h_60  <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 60L)$h_inch
  h_600 <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 600L)$h_inch

  # entrambe al tetto: crescere di 10x gli studi non cresce piu' l'altezza
  expect_equal(h_60, h_600)
  expect_lte(h_600, 12)
})

test_that(".forest_layout_pannelli: l'altezza cresce col numero di studi sotto il tetto", {
  h_6  <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 6L)$h_inch
  h_20 <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 20L)$h_inch
  h_60 <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 60L)$h_inch

  expect_lt(h_6, h_20)
  expect_lte(h_20, h_60)
})

test_that(".forest_layout_pannelli: nessun diradamento per cluster piccoli", {
  layout <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 6L)
  expect_equal(layout$label_stride, 1L)
  expect_lt(layout$h_inch, 8)
})

test_that(".forest_layout_pannelli: con molti studi le etichette si diradano invece di sovrapporsi", {
  # Caso reale: TGF-beta1 v15, 10 geni bersaglio + 59 studi (60 righe col
  # pooled) -- il PNG uscito 2400x6720px con heights=c(2,1) fisso.
  layout <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = 60L)
  expect_gt(layout$label_stride, 1L)
})

test_that(".forest_layout_pannelli: mai un diradamento negativo o nullo", {
  for (n in c(1L, 2L, 5L, 15L, 40L, 100L, 1000L)) {
    layout <- simulomicsr:::.forest_layout_pannelli(n_top = 10L, n_bottom = n)
    expect_gte(layout$label_stride, 1L)
    expect_true(is.finite(layout$h_inch))
    expect_gte(layout$h_inch, 4)
  }
})
