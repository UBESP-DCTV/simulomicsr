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

# ---------------------------------------------------------------------------
# Task 6: .GENERIC_BIOLOGICAL_STOPLIST + .is_generic_biological
# ---------------------------------------------------------------------------

test_that(".GENERIC_BIOLOGICAL_STOPLIST e' un character vector non vuoto", {
  expect_true(is.character(.GENERIC_BIOLOGICAL_STOPLIST))
  expect_gt(length(.GENERIC_BIOLOGICAL_STOPLIST), 0L)
  # deve contenere almeno i termini attesi dal brief
  expect_true("cytokine"   %in% .GENERIC_BIOLOGICAL_STOPLIST)
  expect_true("interferon" %in% .GENERIC_BIOLOGICAL_STOPLIST)
  expect_true("virus"      %in% .GENERIC_BIOLOGICAL_STOPLIST)
  expect_true("infection"  %in% .GENERIC_BIOLOGICAL_STOPLIST)
})

test_that(".is_generic_biological: termini nudi generici -> TRUE", {
  expect_true(.is_generic_biological("interferon"))
  expect_true(.is_generic_biological("cytokine"))
  expect_true(.is_generic_biological("virus"))
  expect_true(.is_generic_biological("infection"))
})

test_that(".is_generic_biological: alias specifici -> FALSE", {
  expect_false(.is_generic_biological("ifnbeta"))
  expect_false(.is_generic_biological("sarscov2"))
})

test_that(".is_generic_biological: alias corti (<3 alnum) -> TRUE", {
  expect_true(.is_generic_biological("il"))   # 2 caratteri alfanumerici
  expect_true(.is_generic_biological("fc"))   # 2 caratteri alfanumerici
})

test_that(".is_generic_biological: normalizza prima di controllare la stoplist", {
  # "Interferon" maiuscolo -> normalizzato a "interferon" -> in stoplist
  expect_true(.is_generic_biological("Interferon"))
  # "Virus" con maiuscola -> TRUE
  expect_true(.is_generic_biological("Virus"))
})

test_that(".is_generic_biological: input vuoto/NA -> TRUE (termini non informativi)", {
  expect_true(.is_generic_biological(NA_character_))
  expect_true(.is_generic_biological(""))
})
