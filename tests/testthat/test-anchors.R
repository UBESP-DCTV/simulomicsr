test_that(".normalize_dose canonicalizza unita' SI", {
  expect_equal(simulomicsr:::.normalize_dose("10 nM"), "10nM")
  expect_equal(simulomicsr:::.normalize_dose("100 ng/ml"), "100ng/ml")
  expect_equal(simulomicsr:::.normalize_dose("1 uM"), "1uM")
  expect_equal(simulomicsr:::.normalize_dose("1 µM"), "1uM")  # micro symbol
  expect_equal(simulomicsr:::.normalize_dose("0.5 mM"), "0.5mM")
})

test_that(".normalize_dose mappa NULL/NA a 'nodose'", {
  expect_equal(simulomicsr:::.normalize_dose(NULL), "nodose")
  expect_equal(simulomicsr:::.normalize_dose(NA_character_), "nodose")
  expect_equal(simulomicsr:::.normalize_dose(""), "nodose")
})

test_that(".normalize_dose preserva 'standard' come placeholder", {
  expect_equal(simulomicsr:::.normalize_dose("standard"), "standard")
})

# .normalize_duration ------------------------------------------------------

test_that(".normalize_duration canonicalizza ore", {
  expect_equal(simulomicsr:::.normalize_duration("1 h"), "1h")
  expect_equal(simulomicsr:::.normalize_duration("24h"), "24h")
  expect_equal(simulomicsr:::.normalize_duration("3 hours"), "3h")
  expect_equal(simulomicsr:::.normalize_duration("90 min"), "1.5h")
  expect_equal(simulomicsr:::.normalize_duration("2 days"), "48h")
  expect_equal(simulomicsr:::.normalize_duration("6d"), "6d")  # giorni preservati per coltura lunga
})

test_that(".normalize_duration mappa NULL/NA a 'na'", {
  expect_equal(simulomicsr:::.normalize_duration(NULL), "na")
  expect_equal(simulomicsr:::.normalize_duration(NA_character_), "na")
  expect_equal(simulomicsr:::.normalize_duration(""), "na")
})

# .normalize_cell_id -------------------------------------------------------

test_that(".normalize_cell_id passa through Cellosaurus IDs", {
  expect_equal(simulomicsr:::.normalize_cell_id("CVCL_0030", "MCF-7"), "CVCL_0030")
})

test_that(".normalize_cell_id usa label_raw se Cellosaurus assente", {
  expect_equal(simulomicsr:::.normalize_cell_id(NULL, "HUVEC"), "HUVEC")
  expect_equal(simulomicsr:::.normalize_cell_id(NA_character_, "HEK293T"), "HEK293T")
})

test_that(".normalize_cell_id ritorna 'unclear' se entrambi vuoti", {
  expect_equal(simulomicsr:::.normalize_cell_id(NULL, NULL), "unclear")
  expect_equal(simulomicsr:::.normalize_cell_id("", ""), "unclear")
})
