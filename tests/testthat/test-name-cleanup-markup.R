# tests/testthat/test-name-cleanup-markup.R
test_that(".strip_name_markup rimuove tag e entita' preservando il nome", {
  expect_equal(.strip_name_markup("(<i>S</i>)-laudanosine(1+)"), "(S)-laudanosine(1+)")
  expect_equal(.strip_name_markup("17&beta;-estradiol"), "17β-estradiol")
  expect_equal(.strip_name_markup("2-hydroxy-6-oxohexa-2,4-dienoic acid"),
               "2-hydroxy-6-oxohexa-2,4-dienoic acid")
  expect_equal(.strip_name_markup(NA_character_), NA_character_)
  expect_equal(.strip_name_markup(character(0)), NA_character_)
})
