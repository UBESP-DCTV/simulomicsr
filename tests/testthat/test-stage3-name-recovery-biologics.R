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
  # Test canonico dal brief: IFN-beta con dose -> ImmPort -> gene IFNB1.
  # L'ID e' HGNC:<numero> (identita' stabile, coerente con R/anchors.R); il
  # simbolo e' l'etichetta leggibile in $name. Usare la sigla come ID
  # frammenterebbe lo stesso gene in due entita' (HGNC:5434 vs HGNC:IFNB1).
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx7)
  r <- .normalize_cytokine_to_hgnc("IFN-β 10 ng/ml", env)
  expect_match(r$id, "^HGNC:[0-9]+$")
  expect_equal(r$name, "IFNB1")
  expect_equal(r$source, "CYTOKINE_IMMPORT")
  # generico -> STR_FALLBACK
  expect_equal(.normalize_cytokine_to_hgnc("interferon", env)$source, "STR_FALLBACK")
  # vuoto -> NO_TERM
  expect_equal(.normalize_cytokine_to_hgnc("", env)$source, "NO_TERM")
})

test_that(".normalize_cytokine_to_hgnc: percorso HGNC diretto (simbolo alias non in ImmPort)", {
  # BSF2 (B-cell stimulatory factor 2) e' alias HGNC di IL6 (hgnc_int=6018)
  # NON e' nel mini-fixture ImmPort -> deve colpire il path HGNC.
  # L'ID e' il numero canonico del gene, il simbolo va in $name.
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx7)
  r <- .normalize_cytokine_to_hgnc("BSF2", env)
  expect_equal(r$id, "HGNC:6018")
  expect_equal(r$name, "IL6")
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

# ---------------------------------------------------------------------------
# Fix estrazione pathogen (2026-07-02): dose/tempo/verbo/via tolleranti.
# Root cause: .normalize_pathogen_to_taxid faceva SOLO match esatto del termine
# collassato -> le stringhe GEO rumorose ("LPS exposed for 24 hours",
# "SARS-CoV-2 infected", "poly(I:C) 10 ug/ml") non risolvevano e cadevano a STR,
# creando minestroni (LPS->CHEBI:16412 mescolato con STR:lps_exposed_for_24_hours).
# Fix: iterare i candidati da .extract_compound_candidates (come .normalize_cytokine_to_hgnc).
# ---------------------------------------------------------------------------

test_that("pathogen rumoroso: 'LPS exposed for 24 hours' -> CHEBI:16412 (PAMP)", {
  r <- .normalize_pathogen_to_taxid("LPS exposed for 24 hours")
  expect_equal(r$id, "CHEBI:16412")
  expect_equal(r$source, "PAMP_WHITELIST")
})

test_that("pathogen rumoroso: 'intravenous LPS' -> CHEBI:16412", {
  r <- .normalize_pathogen_to_taxid("intravenous LPS")
  expect_equal(r$id, "CHEBI:16412")
})

test_that("pathogen rumoroso: 'poly(I:C) 10 ug/ml' -> CHEBI:84491 (PAMP)", {
  r <- .normalize_pathogen_to_taxid("poly(I:C) 10 ug/ml")
  expect_equal(r$id, "CHEBI:84491")
  expect_equal(r$source, "PAMP_WHITELIST")
})

test_that("pathogen rumoroso: 'SARS-CoV-2 infected' -> NCBITaxon:2697049 (vernacolo)", {
  r <- .normalize_pathogen_to_taxid("SARS-CoV-2 infected")
  expect_equal(r$id, "NCBITaxon:2697049")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("pathogen rumoroso: 'SARS-CoV-2 infection at MOI 1 during 24 h' -> NCBITaxon:2697049", {
  r <- .normalize_pathogen_to_taxid("SARS-CoV-2 infection at MOI 1 during 24 h")
  expect_equal(r$id, "NCBITaxon:2697049")
})

test_that("pathogen: 'M tuberculosis' (abbreviazione genere) -> NCBITaxon:1773 (vernacolo)", {
  r <- .normalize_pathogen_to_taxid("M tuberculosis")
  expect_equal(r$id, "NCBITaxon:1773")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

# --- Canary di PRECISIONE (guardie di regressione: NON devono falso-positivare) ---

test_that("CANARY pathogen: 'LPS' pulito resta CHEBI:16412 (no regressione)", {
  r <- .normalize_pathogen_to_taxid("LPS")
  expect_equal(r$id, "CHEBI:16412")
})

test_that("CANARY host-species: 'human infected' -> STR (MAI NCBITaxon:9606)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx8)
  r <- .normalize_pathogen_to_taxid("human infected", env)
  expect_equal(r$source, "STR_FALLBACK")
  expect_false(identical(r$id, "NCBITaxon:9606"))
})

test_that("CANARY host-species: 'mouse infected' -> STR (MAI taxid murino)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx8)
  r <- .normalize_pathogen_to_taxid("mouse infected", env)
  expect_equal(r$source, "STR_FALLBACK")
})

test_that("CANARY rumore non-patogeno: 'BxPC 3 exosomes' -> STR (no match spurio)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx8)
  r <- .normalize_pathogen_to_taxid("BxPC 3 exosomes", env)
  expect_equal(r$source, "STR_FALLBACK")
})

# ---------------------------------------------------------------------------
# Task 9: .detect_biological_mistype + dispatch biologico in recover_identity
# ---------------------------------------------------------------------------

.fx9 <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")

test_that(".detect_biological_mistype: LPS (small_molecule mal-tipizzato) -> pathogen hit", {
  # LPS e' in PAMP_WHITELIST -> CHEBI:16412 -> il check pathogeno da hit forte
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx9)
  r <- .detect_biological_mistype("lps", env)
  expect_false(is.null(r))
  expect_equal(r$kind, "pathogen_or_aggregate_exposure")
  expect_equal(r$id, "CHEBI:16412")
})

test_that(".detect_biological_mistype: osimertinib (small_molecule vero) -> NULL", {
  # osimertinib non e' ne' citochina ne' patogeno nel fixture -> precision-first -> NULL
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx9)
  r <- .detect_biological_mistype("osimertinib", env)
  expect_null(r)
})

test_that(".detect_biological_mistype: IFN-beta (potrebbe essere small_mol errato) -> cytokine hit", {
  # ifn-beta normalizzato trova IFNB1 via ImmPort -> hit forte HGNC: -> citochina
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx9)
  r <- .detect_biological_mistype("ifn-beta", env)
  expect_false(is.null(r))
  expect_equal(r$kind, "cytokine_stim")
  expect_match(r$id, "^HGNC:[0-9]+$")   # ID gene = numero canonico (stabile)
})

test_that(".detect_biological_mistype: termine sconosciuto -> NULL (precision-first)", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx9)
  r <- .detect_biological_mistype("xyzzy_nonexistent_agent", env)
  expect_null(r)
})

test_that("recover_identity dispatcha cytokine/pathogen e fa K3 su small_molecule", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx9)
  # Dispatch citochina: IFN-beta etichettato cytokine_stim -> HGNC:IFNB1
  rc <- recover_identity("", "agent: IFN-beta", "", "cytokine_stim", env)
  expect_match(rc$agent_id, "^HGNC:[0-9]+$")   # ID gene = numero canonico
  expect_equal(rc$canonical_name, "IFNB1")     # simbolo = etichetta leggibile
  expect_equal(rc$kind, "cytokine_stim")
  # Dispatch patogeno: SARS-CoV-2 etichettato pathogen -> NCBITaxon:2697049
  rp <- recover_identity("", "agent: SARS-CoV-2", "", "pathogen_or_aggregate_exposure", env)
  expect_equal(rp$agent_id, "NCBITaxon:2697049")
  expect_equal(rp$kind, "pathogen_or_aggregate_exposure")
  # K3: LPS etichettato small_molecule -> ri-tipizzato pathogen_or_aggregate_exposure
  rk <- recover_identity("", "treatment: LPS", "", "small_molecule", env)
  expect_equal(rk$kind, "pathogen_or_aggregate_exposure")
  expect_equal(rk$agent_id, "CHEBI:16412")
  expect_true(startsWith(rk$recovery_source, "K3_MISTYPE"))
  # small_molecule VERO (osimertinib) NON flippato
  rs <- recover_identity("", "compound: osimertinib", "", "small_molecule", env)
  expect_equal(rs$kind, "small_molecule")
})

test_that("recover_identity: cytokine_stim senza termine -> NO_RECOVERY (retrocompat)", {
  # Nessuna chiave agent nel characteristics -> U1 regime invariato
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx9)
  r <- recover_identity("cells", "tissue: lung", "rep1", "cytokine_stim", env)
  expect_true(is.na(r$agent_id))
  expect_equal(r$kind, "cytokine_stim")
  expect_equal(r$recovery_source, "NO_RECOVERY")
})

test_that("recover_identity: K3 recovery_source include suffisso kind (Fix-A: pamp)", {
  # Fix-A: LPS risolto come composto (CHEBI:16412) poi controllato vs PAMP_WHITELIST
  # -> suffisso specifico K3_MISTYPE_pathogen_pamp (non K3_MISTYPE_pathogen generico)
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx9)
  rk <- recover_identity("", "treatment: LPS", "", "small_molecule", env)
  expect_true(rk$recovery_source %in% c("K3_MISTYPE_pathogen_pamp", "K3_MISTYPE_cytokine"))
  expect_equal(rk$recovery_source, "K3_MISTYPE_pathogen_pamp")
})

# ---------------------------------------------------------------------------
# Fix-A: K3 compound-first (TDD — fase RED -> GREEN)
# Spec: il ramo small_molecule risolve PRIMA come composto; K3 biologico solo
# come last-resort per composti non risolti (STR:).
# ---------------------------------------------------------------------------

.fxa <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")

test_that("Fix-A: .is_pamp_chebi identifica PAMP e non-PAMP per ID ChEBI integer", {
  # Helper: as.integer(chebi_int) %in% .PAMP_WHITELIST (valori interi del named vector)
  expect_true(.is_pamp_chebi(16412L))    # LPS -> PAMP
  expect_true(.is_pamp_chebi(36706L))    # resiquimod -> PAMP
  expect_true(.is_pamp_chebi(84491L))    # poly(I:C) -> PAMP
  expect_false(.is_pamp_chebi(17126L))   # L-carnitina NON e' un PAMP
  expect_false(.is_pamp_chebi(16236L))   # etanolo NON e' un PAMP
  expect_false(.is_pamp_chebi(28748L))   # doxorubicin NON e' un PAMP
  expect_false(.is_pamp_chebi(NA_integer_))  # NA -> FALSE (guard difensivo)
})

test_that("Fix-A LPS PAMP: source K3_MISTYPE_pathogen_pamp (compound-first via ChEBI)", {
  # LPS risolve a CHEBI:16412 (compound lookup), poi PAMP_WHITELIST conferma ->
  # re-tipizzato a patogeno con source K3_MISTYPE_pathogen_pamp, NON K3_MISTYPE_pathogen
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fxa)
  r <- recover_identity("", "treatment: LPS", "", "small_molecule", env)
  expect_equal(r$kind, "pathogen_or_aggregate_exposure")
  expect_equal(r$agent_id, "CHEBI:16412")
  expect_equal(r$recovery_source, "K3_MISTYPE_pathogen_pamp")
})

test_that("Fix-A canary L-carnitina: CHEBI:17126 (non-PAMP) rimane small_molecule", {
  # L-carnitina risolve a CHEBI:17126; 17126 NON e' in PAMP_WHITELIST values ->
  # nessun flip, rimane small_molecule. Previene falsi positivi K3.
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fxa)
  r <- recover_identity("", "treatment: carnitine", "", "small_molecule", env)
  expect_equal(r$kind, "small_molecule")
  expect_equal(r$agent_id, "CHEBI:17126")
  expect_false(startsWith(r$recovery_source, "K3_MISTYPE"))
})

test_that("Fix-A canary osimertinib: STR (non in fixture) rimane small_molecule", {
  # osimertinib non e' nel mini-fixture -> STR:osimertinib ->
  # K3 last-resort: non e' citochina ne' patogeno -> rimane small_molecule con STR
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fxa)
  r <- recover_identity("", "compound: osimertinib", "", "small_molecule", env)
  expect_equal(r$kind, "small_molecule")
  expect_true(startsWith(r$agent_id, "STR:"))
})

test_that("Fix-A TNF last-resort: STR (non composto) -> K3 citochina via ImmPort", {
  # TNF non e' in ChEBI/ChEMBL -> STR:tnf -> Passo 4 K3 last-resort ->
  # ImmPort trova hgnc_int=11892 in cytokine whitelist -> kind=cytokine_stim
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fxa)
  r <- recover_identity("", "treatment: TNF", "", "small_molecule", env)
  expect_equal(r$kind, "cytokine_stim")
  expect_true(startsWith(r$agent_id, "HGNC:"))
  expect_equal(r$recovery_source, "K3_MISTYPE_cytokine")
})

test_that("Fix-A combo non-PAMP: due ChEBI restano small_molecule (COMPOUND_COMBO)", {
  # ethanol (CHEBI:16236) + doxorubicin (CHEBI:28748): nessuno e' PAMP ->
  # comp$id = "CHEBI:16236+CHEBI:28748" -> Passo 3 -> kind=small_molecule invariato
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fxa)
  r <- recover_identity("", "treatment: ethanol and doxorubicin", "", "small_molecule", env)
  expect_equal(r$kind, "small_molecule")
  expect_equal(r$recovery_source, "COMPOUND_COMBO")
  expect_true(grepl("\\+", r$agent_id))
})

# ---------------------------------------------------------------------------
# Fix-B: estrazione pathogen via nuove chiavi .AGENT_KEYS + vernacolo esteso
# ---------------------------------------------------------------------------

# Fix-B1: .AGENT_KEYS ora include "infection", "virus", "bacteria", ecc.
test_that("Fix-B1: .extract_agent_term estrae da chiave 'infection'", {
  # 'infection: influenza A' -> chiave 'infection' ora matcha .AGENT_KEYS
  r <- .extract_agent_term("", "infection: influenza A", "rep1")
  expect_equal(r, "influenza a")
})

test_that("Fix-B1: .extract_agent_term estrae da chiave 'virus'", {
  # 'virus: IAV' -> chiave 'virus' ora matcha .AGENT_KEYS
  # NB: .parse_characteristics_kv usa ':' come separatore; chiavi multi-parola
  # ('virus strain') non corrispondono al pattern che usa match esatto.
  r <- .extract_agent_term("", "virus: IAV", "")
  expect_equal(r, "iav")
})

test_that("Fix-D I-1: chiave 'bacteria' rimossa da .AGENT_KEYS -> NA (Fix-B1 aggiornato)", {
  # Fix-D I-1: 'bacteria' rimosso da .AGENT_KEYS (0 hit reali, superficie di collisione).
  # L'organismo ora va estratto tramite 'infection:', non 'bacteria:'.
  r <- .extract_agent_term("", "bacteria: Staphylococcus aureus", "")
  expect_true(is.na(r))
})

test_that("Fix-B1: recover_identity pathogen con chiave 'infection' -> NCBITaxon", {
  # 'infection: SARS-CoV-2' -> estrazione funziona dopo Fix-B1 -> NCBITaxon:2697049
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fx8)
  r <- recover_identity("", "infection: SARS-CoV-2", "", "pathogen_or_aggregate_exposure", env)
  expect_equal(r$agent_id, "NCBITaxon:2697049")
  expect_equal(r$kind, "pathogen_or_aggregate_exposure")
})

# Fix-B2: .PATHOGEN_VERNACULAR esteso con abbreviazioni comuni
test_that("Fix-B2: vernacolo IAV -> NCBITaxon:11320 (senza env)", {
  r <- .normalize_pathogen_to_taxid("IAV")
  expect_equal(r$id, "NCBITaxon:11320")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo IVB -> NCBITaxon:11520", {
  r <- .normalize_pathogen_to_taxid("IVB")
  expect_equal(r$id, "NCBITaxon:11520")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo HIV -> NCBITaxon:11676", {
  r <- .normalize_pathogen_to_taxid("HIV")
  expect_equal(r$id, "NCBITaxon:11676")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo HIV-1 -> NCBITaxon:11676", {
  r <- .normalize_pathogen_to_taxid("HIV-1")
  expect_equal(r$id, "NCBITaxon:11676")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo HSV-1 -> NCBITaxon:10298", {
  r <- .normalize_pathogen_to_taxid("HSV-1")
  expect_equal(r$id, "NCBITaxon:10298")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo HSV-2 -> NCBITaxon:10310", {
  r <- .normalize_pathogen_to_taxid("HSV-2")
  expect_equal(r$id, "NCBITaxon:10310")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo CMV -> NCBITaxon:10359", {
  r <- .normalize_pathogen_to_taxid("CMV")
  expect_equal(r$id, "NCBITaxon:10359")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo EBV -> NCBITaxon:10376", {
  r <- .normalize_pathogen_to_taxid("EBV")
  expect_equal(r$id, "NCBITaxon:10376")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo RSV -> NCBITaxon:12814 (corretto, non 11250)", {
  r <- .normalize_pathogen_to_taxid("RSV")
  expect_equal(r$id, "NCBITaxon:12814")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo HBV -> NCBITaxon:10407", {
  r <- .normalize_pathogen_to_taxid("HBV")
  expect_equal(r$id, "NCBITaxon:10407")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo HCV -> NCBITaxon:3052230 (Orthohepacivirus, corretto)", {
  r <- .normalize_pathogen_to_taxid("HCV")
  expect_equal(r$id, "NCBITaxon:3052230")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo EV-D68 -> NCBITaxon:42789", {
  r <- .normalize_pathogen_to_taxid("EV-D68")
  expect_equal(r$id, "NCBITaxon:42789")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo HPV -> NCBITaxon:10566", {
  r <- .normalize_pathogen_to_taxid("HPV")
  expect_equal(r$id, "NCBITaxon:10566")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo SARS-CoV -> NCBITaxon:694009 (SARS-CoV-1)", {
  r <- .normalize_pathogen_to_taxid("SARS-CoV")
  expect_equal(r$id, "NCBITaxon:694009")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo MERS-CoV -> NCBITaxon:1335626", {
  r <- .normalize_pathogen_to_taxid("MERS-CoV")
  expect_equal(r$id, "NCBITaxon:1335626")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo saureus (da 'S. aureus') -> NCBITaxon:1280", {
  # 'S. aureus' normalizzato -> 'saureus' -> in vernacolo
  r <- .normalize_pathogen_to_taxid("S. aureus")
  expect_equal(r$id, "NCBITaxon:1280")
  expect_equal(r$source, "PATHOGEN_VERNACULAR")
})

test_that("Fix-B2: vernacolo retrocompat (flu/tb/mtb/sarscov2 invariati)", {
  expect_equal(.normalize_pathogen_to_taxid("flu")$id,      "NCBITaxon:11320")
  expect_equal(.normalize_pathogen_to_taxid("TB")$id,       "NCBITaxon:1773")
  expect_equal(.normalize_pathogen_to_taxid("SARS-CoV-2")$id, "NCBITaxon:2697049")
})

# ---------------------------------------------------------------------------
# Fix-D I-1: trim .AGENT_KEYS (rimuovi organism/microbe/bacteria/bacterial/viral)
# ---------------------------------------------------------------------------

.fxd <- system.file("extdata", "ontology-fixtures-mini", package = "simulomicsr")

test_that("Fix-D I-1: .AGENT_KEYS non contiene piu' le chiavi rimosse", {
  # Verifica che le 5 chiavi rimovibili non siano presenti nel pattern
  expect_false(grepl("\\borganism\\b", .AGENT_KEYS))
  expect_false(grepl("\\bmicrobe\\b",  .AGENT_KEYS))
  expect_false(grepl("\\bbacteria\\b", .AGENT_KEYS))
  expect_false(grepl("\\bbacterial\\b", .AGENT_KEYS))
  expect_false(grepl("\\bviral\\b",    .AGENT_KEYS))
})

test_that("Fix-D I-1: .AGENT_KEYS mantiene le chiavi utili (infection/virus/pathogen)", {
  # Chiavi Fix-B mantenute
  expect_true(grepl("infection", .AGENT_KEYS, fixed = TRUE))
  expect_true(grepl("virus",     .AGENT_KEYS, fixed = TRUE))
  expect_true(grepl("pathogen",  .AGENT_KEYS, fixed = TRUE))
  expect_true(grepl("inoculation", .AGENT_KEYS, fixed = TRUE))
  expect_true(grepl("challenge", .AGENT_KEYS, fixed = TRUE))
})

test_that("Fix-D I-1: .extract_agent_term('organism: human') -> NA (organism non e' agente)", {
  # 'organism: human' prima estraeva 'human' come agente (bug I-1).
  # Dopo il trim 'organism' non e' piu' in .AGENT_KEYS -> NA.
  r <- .extract_agent_term("", "tissue: cortex, organism: human", "")
  expect_true(is.na(r))
})

test_that("Fix-D I-1: .extract_agent_term('infection: influenza A') ancora funziona", {
  # Regression: chiave 'infection' mantenuta -> estrazione invariata
  r <- .extract_agent_term("", "infection: influenza A", "rep1")
  expect_equal(r, "influenza a")
})

test_that("Fix-D I-1: .extract_agent_term('virus: IAV') ancora funziona", {
  # Regression: chiave 'virus' mantenuta -> estrazione invariata
  r <- .extract_agent_term("", "virus: IAV", "")
  expect_equal(r, "iav")
})

test_that("Fix-D I-1: recover_identity organism:human NON flippa a pathogen", {
  env <- .load_ontology_dicts(refresh = TRUE, fixture_dir = .fxd)
  # 'organism: human' non estrae piu' un agente -> NO_RECOVERY, kind invariato
  r <- recover_identity("", "organism: human", "", "small_molecule", env)
  expect_equal(r$recovery_source, "NO_RECOVERY")
  expect_true(is.na(r$agent_id))
  expect_equal(r$kind, "small_molecule")
  # Invariante principale: agent_id NON deve essere NCBITaxon:9606
  expect_false(identical(r$agent_id, "NCBITaxon:9606"))
})

# ---------------------------------------------------------------------------
# Fix-D I-1b: .HOST_SPECIES_STOPLIST + guardia in .normalize_pathogen_to_taxid
# ---------------------------------------------------------------------------

test_that("Fix-D I-1b: .HOST_SPECIES_STOPLIST e' definito e contiene le specie-ospite", {
  expect_true(is.character(.HOST_SPECIES_STOPLIST))
  expect_gt(length(.HOST_SPECIES_STOPLIST), 0L)
  # Forme normalizzate attese (output di .normalize_biological_mention)
  expect_true("human"            %in% .HOST_SPECIES_STOPLIST)
  expect_true("homosapiens"      %in% .HOST_SPECIES_STOPLIST)
  expect_true("mouse"            %in% .HOST_SPECIES_STOPLIST)
  expect_true("musmusculus"      %in% .HOST_SPECIES_STOPLIST)
  expect_true("rat"              %in% .HOST_SPECIES_STOPLIST)
  expect_true("rattusnorvegicus" %in% .HOST_SPECIES_STOPLIST)
  expect_true("patient"          %in% .HOST_SPECIES_STOPLIST)
  expect_true("donor"            %in% .HOST_SPECIES_STOPLIST)
  expect_true("subject"          %in% .HOST_SPECIES_STOPLIST)
})

test_that("Fix-D I-1b: .normalize_pathogen_to_taxid('human') -> STR (host-species stoplist)", {
  # 'human' normalizzato -> 'human' -> in .HOST_SPECIES_STOPLIST -> STR_FALLBACK
  # PRIMA del lookup taxdump che avrebbe prodotto NCBITaxon:9606
  r <- .normalize_pathogen_to_taxid("human")
  expect_equal(r$source, "STR_FALLBACK")
  expect_true(startsWith(r$id, "STR:"))
  # invariante principale: mai NCBITaxon:9606
  expect_false(identical(r$id, "NCBITaxon:9606"))
})

test_that("Fix-D I-1b: .normalize_pathogen_to_taxid('Homo sapiens') -> STR (host-species)", {
  r <- .normalize_pathogen_to_taxid("Homo sapiens")
  expect_equal(r$source, "STR_FALLBACK")
  expect_false(identical(r$id, "NCBITaxon:9606"))
})

test_that("Fix-D I-1b: .normalize_pathogen_to_taxid('mouse') -> STR (host-species)", {
  r <- .normalize_pathogen_to_taxid("mouse")
  expect_equal(r$source, "STR_FALLBACK")
  expect_true(startsWith(r$id, "STR:"))
})

test_that("Fix-D I-1b: .normalize_pathogen_to_taxid('patient') -> STR (host-species)", {
  r <- .normalize_pathogen_to_taxid("patient")
  expect_equal(r$source, "STR_FALLBACK")
  expect_true(startsWith(r$id, "STR:"))
})

test_that("Fix-D I-1b: .normalize_pathogen_to_taxid('donor') -> STR (host-species)", {
  r <- .normalize_pathogen_to_taxid("donor")
  expect_equal(r$source, "STR_FALLBACK")
  expect_true(startsWith(r$id, "STR:"))
})

test_that("Fix-D I-1b: patogeni reali NON bloccati da host-species stoplist", {
  # Regression: flu, SARS-CoV-2, LPS NON sono nella stoplist -> restano invariati
  expect_equal(.normalize_pathogen_to_taxid("flu")$id,    "NCBITaxon:11320")
  expect_equal(.normalize_pathogen_to_taxid("LPS")$id,    "CHEBI:16412")
  expect_equal(.normalize_pathogen_to_taxid("SARS-CoV-2")$id, "NCBITaxon:2697049")
})

test_that("Fix-D I-1b: 'human adenovirus' NON bloccato (stoplist su forma normalizzata esatta)", {
  # "human adenovirus" normalizzato -> "humanadenovirus" -> NON in stoplist
  # (match esatto: solo "human" puro e' nella lista, non prefisso)
  r <- .normalize_pathogen_to_taxid("human adenovirus")
  # Non deve essere NCBITaxon:9606; puo' essere STR o un taxon se nel dump
  expect_false(identical(r$id, "NCBITaxon:9606"))
})

# ---------------------------------------------------------------------------
# Fix-D I-2: .AGENT_CONTROL esteso con pattern infection-negativo
# ---------------------------------------------------------------------------

test_that("Fix-D I-2: .AGENT_CONTROL include i pattern infection-negativo", {
  expect_true(grepl("uninfected",    .AGENT_CONTROL, fixed = TRUE))
  expect_true(grepl("non-?infected", .AGENT_CONTROL, fixed = TRUE))
  expect_true(grepl("noninfection",  .AGENT_CONTROL, fixed = TRUE))
})

test_that("Fix-D I-2: 'infection: uninfected' -> .extract_agent_term -> NA (controllo infection-neg)", {
  # 'uninfected' ora in .AGENT_CONTROL -> il valore viene scartato come controllo
  r <- .extract_agent_term("", "infection: uninfected", "")
  expect_true(is.na(r))
})

test_that("Fix-D I-2: 'infection: non-infected' -> .extract_agent_term -> NA", {
  r <- .extract_agent_term("", "infection: non-infected", "")
  expect_true(is.na(r))
})

test_that("Fix-D I-2: 'infection: noninfection' -> .extract_agent_term -> NA", {
  r <- .extract_agent_term("", "infection: noninfection", "")
  expect_true(is.na(r))
})

test_that("Fix-D I-2: 'infection: not infected' -> .extract_agent_term -> NA", {
  r <- .extract_agent_term("", "infection: not infected", "")
  expect_true(is.na(r))
})

test_that("Fix-D I-2: 'infection: no infection' -> .extract_agent_term -> NA", {
  r <- .extract_agent_term("", "infection: no infection", "")
  expect_true(is.na(r))
})

test_that("Fix-D I-2: 'infection: influenza A' non bloccato da infection-neg (positivo resta)", {
  # 'influenza a' NON matcha i pattern infection-negativi -> viene estratto correttamente
  r <- .extract_agent_term("", "infection: influenza A", "")
  expect_equal(r, "influenza a")
})

test_that("Fix-D I-2: retrocompat untreated/mock/vehicle ancora bloccati", {
  # Pattern preesistenti in .AGENT_CONTROL non devono essere stati rimossi
  expect_true(is.na(.extract_agent_term("", "treatment: untreated", "")))
  expect_true(is.na(.extract_agent_term("", "agent: mock",          "")))
  expect_true(is.na(.extract_agent_term("", "compound: vehicle",    "")))
})
