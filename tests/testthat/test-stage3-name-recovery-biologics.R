# Test per .normalize_biological_mention (Task 5 — biologici greco-aware)
# File: tests/testthat/test-stage3-name-recovery-biologics.R

test_that(".normalize_biological_mention collassa grafie greco/trattino/spazio", {
  expect_equal(.normalize_biological_mention("IFN-β"), "ifnbeta")
  expect_equal(.normalize_biological_mention("interferon beta"), "interferonbeta")
  expect_equal(.normalize_biological_mention("TNF-α"), "tnfalpha")
  expect_equal(.normalize_biological_mention("poly(I:C)"), "polyic")
  expect_equal(.normalize_biological_mention(NA_character_), "")
})

test_that(".normalize_biological_mention: input vuoto -> stringa vuota", {
  expect_equal(.normalize_biological_mention(""), "")
  expect_equal(.normalize_biological_mention(NA_character_), "")
})

test_that(".normalize_biological_mention: altre lettere greche supportate", {
  expect_equal(.normalize_biological_mention("IL-γ"), "ilgamma")
  expect_equal(.normalize_biological_mention("TGF-β"), "tgfbeta")
  expect_equal(.normalize_biological_mention("NF-κβ"), "nfkappabeta")
  expect_equal(.normalize_biological_mention("omega-3"), "omega3")
})

test_that(".normalize_biological_mention: caratteri speciali e punteggiatura eliminati", {
  expect_equal(.normalize_biological_mention("poly(I:C)"), "polyic")
  expect_equal(.normalize_biological_mention("LPS (E. coli)"), "lpsecoli")
  expect_equal(.normalize_biological_mention("anti-CD3/CD28"), "anticd3cd28")
})

test_that(".normalize_biological_mention: lunghezza input != 1 -> stringa vuota", {
  expect_equal(.normalize_biological_mention(character(0)), "")
  expect_equal(.normalize_biological_mention(c("IFN-β", "TNF-α")), "")
})
