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

# ---------------------------------------------------------------------------
# Task 7: .normalize_cytokine_to_hgnc
# ---------------------------------------------------------------------------

# Helper fixture comune (riusato in tutti i test Task 7)
.fx7 <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")

test_that(".normalize_cytokine_to_hgnc: input vuoto/NA -> NO_TERM", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx7)
  r_empty <- .normalize_cytokine_to_hgnc("", env)
  expect_equal(r_empty$source, "NO_TERM")
  expect_true(is.na(r_empty$id))
  r_na <- .normalize_cytokine_to_hgnc(NA_character_, env)
  expect_equal(r_na$source, "NO_TERM")
})

test_that(".normalize_cytokine_to_hgnc: termine generico -> STR_FALLBACK", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx7)
  # "interferon" e' nella GENERIC_BIOLOGICAL_STOPLIST -> fallback senza lookup
  r <- .normalize_cytokine_to_hgnc("interferon", env)
  expect_equal(r$source, "STR_FALLBACK")
  expect_equal(r$id, "STR:interferon")
})

test_that(".normalize_cytokine_to_hgnc risolve IFN-beta a HGNC e gatekeepa i generici", {
  # Test canonico dal brief: IFN-beta con dose -> ImmPort -> HGNC:IFNB1
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx7)
  r <- .normalize_cytokine_to_hgnc("IFN-β 10 ng/ml", env)
  expect_equal(r$id, "HGNC:IFNB1")
  expect_equal(r$source, "CYTOKINE_IMMPORT")
  # generico -> STR_FALLBACK
  expect_equal(.normalize_cytokine_to_hgnc("interferon", env)$source, "STR_FALLBACK")
  # vuoto -> NO_TERM
  expect_equal(.normalize_cytokine_to_hgnc("", env)$source, "NO_TERM")
})

test_that(".normalize_cytokine_to_hgnc: percorso HGNC diretto (simbolo alias non in ImmPort)", {
  # BSF2 (B-cell stimulatory factor 2) e' alias HGNC di IL6 (hgnc_int=6018)
  # NON e' nel mini-fixture ImmPort -> deve colpire il path HGNC
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx7)
  r <- .normalize_cytokine_to_hgnc("BSF2", env)
  expect_equal(r$id, "HGNC:IL6")
  expect_equal(r$source, "CYTOKINE_HGNC")
})

test_that(".normalize_cytokine_to_hgnc: gene non-citochina -> gateato -> STR_FALLBACK", {
  # EGFR e' in HGNC ma NON nella whitelist citochine -> il gate lo scarta
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx7)
  r <- .normalize_cytokine_to_hgnc("EGFR", env)
  expect_equal(r$source, "STR_FALLBACK")
  expect_match(r$id, "^STR:")
})

test_that(".normalize_cytokine_to_hgnc: restituisce lista con campi id/name/source", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx7)
  r <- .normalize_cytokine_to_hgnc("IFN-β 10 ng/ml", env)
  expect_named(r, c("id", "name", "source"), ignore.order = TRUE)
  expect_type(r$id, "character")
  expect_type(r$name, "character")
  expect_type(r$source, "character")
})

# ---------------------------------------------------------------------------
# Task 8: .PAMP_WHITELIST + .normalize_pathogen_to_taxid
# ---------------------------------------------------------------------------

# Helper fixture comune (riusato in tutti i test Task 8)
.fx8 <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")

test_that(".PAMP_WHITELIST e' un named integer vector con LPS a 16412", {
  expect_true(is.integer(.PAMP_WHITELIST))
  # Chiavi attese (form normalizzata via .normalize_biological_mention)
  expect_true("lps" %in% names(.PAMP_WHITELIST))
  expect_true("lipopolysaccharide" %in% names(.PAMP_WHITELIST))
  # ID LPS verificato
  expect_equal(.PAMP_WHITELIST[["lps"]], 16412L)
  expect_equal(.PAMP_WHITELIST[["lipopolysaccharide"]], 16412L)
})

test_that(".normalize_pathogen_to_taxid: input vuoto/NA -> NO_TERM", {
  r_na    <- .normalize_pathogen_to_taxid(NA_character_)
  r_empty <- .normalize_pathogen_to_taxid("")
  expect_equal(r_na$source, "NO_TERM")
  expect_true(is.na(r_na$id))
  expect_equal(r_empty$source, "NO_TERM")
  expect_true(is.na(r_empty$id))
})

test_that(".normalize_pathogen_to_taxid: termine generico -> STR_FALLBACK (senza env)", {
  r <- .normalize_pathogen_to_taxid("virus")
  expect_equal(r$source, "STR_FALLBACK")
  expect_equal(r$id, "STR:virus")
})

test_that(".normalize_pathogen_to_taxid: PAMP LPS -> CHEBI:16412 senza env", {
  r <- .normalize_pathogen_to_taxid("LPS")
  expect_equal(r$id, "CHEBI:16412")
  expect_equal(r$source, "PAMP_WHITELIST")
})

test_that(".normalize_pathogen_to_taxid: PAMP alias lipopolysaccharide -> CHEBI:16412", {
  r <- .normalize_pathogen_to_taxid("lipopolysaccharide")
  expect_equal(r$id, "CHEBI:16412")
  expect_equal(r$source, "PAMP_WHITELIST")
})

test_that(".normalize_pathogen_to_taxid: SARS-CoV-2 -> NCBITaxon:2697049 (fixture env)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx8)
  r <- .normalize_pathogen_to_taxid("SARS-CoV-2", env)
  expect_equal(r$id, "NCBITaxon:2697049")
})

test_that(".normalize_pathogen_to_taxid: virus generico -> STR_FALLBACK (con env)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx8)
  r <- .normalize_pathogen_to_taxid("virus", env)
  expect_equal(r$source, "STR_FALLBACK")
})

test_that(".normalize_pathogen_to_taxid: vernacolo flu -> NCBITaxon:11320 (no env)", {
  r <- .normalize_pathogen_to_taxid("flu")
  expect_equal(r$id, "NCBITaxon:11320")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that(".normalize_pathogen_to_taxid: vernacolo tb -> NCBITaxon:1773 (no env)", {
  r <- .normalize_pathogen_to_taxid("TB")
  expect_equal(r$id, "NCBITaxon:1773")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that(".normalize_pathogen_to_taxid: taxdump M. tuberculosis -> NCBITaxon:1773", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx8)
  r <- .normalize_pathogen_to_taxid("Mycobacterium tuberculosis", env)
  expect_equal(r$id, "NCBITaxon:1773")
  expect_equal(r$source, "PATHOGEN_TAXID")
})

test_that(".normalize_pathogen_to_taxid: organismo non in dict -> STR_FALLBACK", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx8)
  r <- .normalize_pathogen_to_taxid("Listeria monocytogenes", env)
  expect_equal(r$source, "STR_FALLBACK")
  expect_match(r$id, "^STR:")
})

test_that(".normalize_pathogen_to_taxid: restituisce lista con campi id/name/source", {
  r <- .normalize_pathogen_to_taxid("LPS")
  expect_named(r, c("id", "name", "source"), ignore.order = TRUE)
  expect_type(r$id, "character")
  expect_type(r$name, "character")
  expect_type(r$source, "character")
})

test_that(".normalize_pathogen_to_taxid: env NULL -> no taxdump, STR su organismo sconosciuto", {
  # Senza env il ramo taxdump viene saltato: un organismo non in whitelist/vernacolo
  # deve cadere a STR_FALLBACK piuttosto che crashare
  r <- .normalize_pathogen_to_taxid("Escherichia coli", ontology_env = NULL)
  expect_equal(r$source, "STR_FALLBACK")
  expect_match(r$id, "^STR:")
})
