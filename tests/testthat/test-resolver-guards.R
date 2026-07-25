# Guardie di precisione del resolver: i casi sono quelli MISURATI sull'audit
# 2026-07-25, non esempi inventati.

test_that(".is_unreliable_candidate scarta unita' di misura", {
  for (u in c("ml", "ML", "ug", "mg", "nM", "moi", "pfu", "ph", "hr")) {
    expect_true(.is_unreliable_candidate(u), info = u)
  }
})

test_that(".is_unreliable_candidate scarta parole funzionali che collidono", {
  for (w in c("in", "on", "of", "no", "lead", "donor", "cancer", "tumor", "cell", "type")) {
    expect_true(.is_unreliable_candidate(w), info = w)
  }
})

test_that(".is_unreliable_candidate NON scarta nomi di entita' veri", {
  for (g in c("lps", "dht", "tnf", "il6", "vemurafenib", "enzalutamide", "sars-cov-2",
              "poly(I:C)", "tgf-beta1", "doxorubicin")) {
    expect_false(.is_unreliable_candidate(g), info = g)
  }
})

test_that(".is_unreliable_candidate gestisce input degeneri", {
  expect_true(.is_unreliable_candidate(NA_character_))
  expect_true(.is_unreliable_candidate(""))
  expect_true(.is_unreliable_candidate("123"))
  expect_true(.is_unreliable_candidate(character(0)))
})

test_that(".is_alias_collision riconosce le collisioni accertate", {
  expect_true(.is_alias_collision("ml", "HGNC:11795"))     # unita' -> THPO
  expect_true(.is_alias_collision("LAP", "HGNC:11766"))    # lapatinib -> TGFB1
  expect_true(.is_alias_collision("HGF", "HGNC:6018"))     # HGF -> IL6
  expect_true(.is_alias_collision("5-FU", "CHEBI:80961"))  # -> 5-formiluracile
  expect_true(.is_alias_collision("DHA", "CHEBI:16016"))   # -> diidrossiacetone
  expect_true(.is_alias_collision("IFN", "HGNC:5417"))     # famiglia -> IFNA1
})

test_that(".is_alias_collision non tocca le coppie legittime", {
  expect_false(.is_alias_collision("lps", "CHEBI:16412"))
  expect_false(.is_alias_collision("il6", "HGNC:6018"))
  expect_false(.is_alias_collision("tnf", "HGNC:11892"))
  expect_false(.is_alias_collision("dht", "CHEBI:16330"))
  expect_false(.is_alias_collision("hgf", "HGNC:4893"))    # HGF vero (non IL6)
})

test_that(".reject_unreliable_match combina le due guardie", {
  expect_true(.reject_unreliable_match("ml", "HGNC:11795"))
  expect_true(.reject_unreliable_match("ml", "CHEBI:1"))    # unita': sempre
  expect_true(.reject_unreliable_match("lap", "HGNC:11766"))
  expect_false(.reject_unreliable_match("lap", "CHEBI:49603"))  # Lap = lapatinib: ok
  expect_false(.reject_unreliable_match("vemurafenib", "CHEBI:63637"))
})

# I test end-to-end richiedono i dizionari REALI. Nella suite completa
# `.load_ontology_dicts()` puo' restituire il singleton FIXTURE caricato da un file
# di test precedente: in quel caso si salta, altrimenti si misurerebbe la fixture.
.real_ontology_or_skip <- function() {
  skip_if_not(dir.exists(file.path(tools::R_user_dir("simulomicsr", "cache"), "chebi")),
              "dizionari ontologici reali non disponibili")
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari caricati come fixture (isolamento suite)")
  oe
}

# ---- effetto end-to-end sui resolver di produzione -------------------------

test_that("una dose in ug/ml non produce piu' una citochina", {
  oe <- .real_ontology_or_skip()
  expect_false(identical(.normalize_cytokine_to_hgnc("GO 1 ug/ml 28 days", oe)$id, "HGNC:11795"))
  expect_false(identical(.normalize_cytokine_to_hgnc("Doxorubicin 0.5 ug/ml 24h", oe)$id, "HGNC:11795"))
})

test_that("'Her/Lap' non produce piu' TGFB1", {
  oe <- .real_ontology_or_skip()
  expect_false(identical(.normalize_cytokine_to_hgnc("Her/Lap", oe)$id, "HGNC:11766"))
})

test_that("NON-REGRESSIONE: le entita' vere continuano a risolvere", {
  oe <- .real_ontology_or_skip()
  expect_identical(.normalize_compound_to_chebi("LPS", oe)$id, "CHEBI:16412")
  expect_identical(.normalize_compound_to_chebi("DHT", oe)$id, "CHEBI:16330")
  expect_identical(.normalize_compound_to_chebi("vemurafenib", oe)$id, "CHEBI:63637")
  expect_identical(.normalize_cytokine_to_hgnc("TNF", oe)$id, "HGNC:11892")
  expect_identical(.normalize_pathogen_to_taxid("SARS-CoV-2", oe)$id, "NCBITaxon:2697049")
})
