test_that(".resolve_canonical_to_id risolve small_molecule via ChEBI", {
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("aspirin", "small_molecule", env = list()),
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "aspirin"))
      list(chebi_id = 15365L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "CHEBI:15365")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id ritorna NONE su miss", {
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("qwerty", "small_molecule", env = list()),
    .chebi_lookup_alias = function(alias, env) NULL, .package = "simulomicsr")
  expect_true(is.na(res$resolved_id))
  expect_equal(res$match_strength, "NONE")
})

test_that(".resolve_canonical_to_id risolve disease via MeSH e pathogen via taxonomy", {
  d <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("Breast Neoplasms", "disease_vs_normal", env = list()),
    .mesh_lookup_term = function(term, env) list(ui = "D001943"), .package = "simulomicsr")
  expect_equal(d$resolved_id, "MeSH:D001943")
  p <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("SARS-CoV-2", "pathogen_or_aggregate_exposure", env = list()),
    .taxonomy_lookup_name = function(term, env) list(taxid = 2697049L), .package = "simulomicsr")
  expect_equal(p$resolved_id, "NCBITaxon:2697049")
})

test_that(".resolve_canonical_to_id su alias HGNC ritorna il gene canonico, non l'input grezzo", {
  # "BSF2" e' un alias storico di IL6: l'accessor risolve all'alias ma ritorna
  # il gene canonico. L'ID deve riflettere IL6 (HGNC:6015), non "BSF2" (bug
  # critico: prima usava toupper(nm) sull'input grezzo, rompendo il dedup).
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("BSF2", "cytokine_stim", env = list()),
    .immport_lookup_synonym = function(term, env) NULL,
    .uniprot_lookup_name = function(term, env) NULL,
    .hgnc_lookup_symbol = function(symbol, env) if (identical(tolower(symbol), "bsf2"))
      list(hgnc_int = 6015L, primary_symbol = "IL6", match_type = "ALIAS") else NULL,
    .is_cytokine_symbol = function(hgnc_int, env) TRUE,
    .hgnc_lookup_hgnc = function(hgnc_int, env) list(symbol = "IL6"),
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "HGNC:6015")
  expect_equal(res$resolved_name, "IL6")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id cytokine_stim ricade su ChEBI quando HGNC non risolve", {
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("poly(I:C)", "cytokine_stim", env = list()),
    .hgnc_lookup_symbol = function(symbol, env) NULL,
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "poly(i:c)"))
      list(chebi_id = 84491L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "CHEBI:84491")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id con kind character(0)/NA non va in errore (fallback catch-all)", {
  res0 <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("aspirin", character(0), env = list()),
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "aspirin"))
      list(chebi_id = 15365L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res0$resolved_id, "CHEBI:15365")

  resNA <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("aspirin", NA_character_, env = list()),
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "aspirin"))
      list(chebi_id = 15365L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(resNA$resolved_id, "CHEBI:15365")
})

# ---------------------------------------------------------------------------
# Fix resolver citochine + kind grezzo Mistral + variante estradiolo
# (smoke 2026-07-07: Mistral emette kind libero "cytokine" e full-name che
# non sono symbol HGNC; il catch-all faceva MeSH>HGNC. Vedi handout
# 2026-07-07-name-cleanup-resolver-fix.)
# ---------------------------------------------------------------------------

test_that(".canonicalize_resolver_kind allinea il vocabolario libero Mistral agli enum", {
  expect_equal(.canonicalize_resolver_kind("cytokine"), "cytokine_stim")
  expect_equal(.canonicalize_resolver_kind("chemokine"), "cytokine_stim")
  expect_equal(.canonicalize_resolver_kind("interleukin"), "cytokine_stim")
  expect_equal(.canonicalize_resolver_kind("interferon"), "cytokine_stim")
  expect_equal(.canonicalize_resolver_kind("growth_factor"), "cytokine_stim")
  expect_equal(.canonicalize_resolver_kind("pathogen"), "pathogen_or_aggregate_exposure")
  expect_equal(.canonicalize_resolver_kind("infection"), "pathogen_or_aggregate_exposure")
  expect_equal(.canonicalize_resolver_kind("vehicle_control"), "vehicle_only")
  expect_equal(.canonicalize_resolver_kind("vehicle"), "vehicle_only")
  # canonici invariati
  expect_equal(.canonicalize_resolver_kind("cytokine_stim"), "cytokine_stim")
  expect_equal(.canonicalize_resolver_kind("small_molecule"), "small_molecule")
  expect_equal(.canonicalize_resolver_kind("disease_vs_normal"), "disease_vs_normal")
  # varianti di FORMATO di un enum canonico -> normalizzate alla forma dello
  # switch (altrimenti cadrebbero sul default case-sensitive: MeSH>HGNC di nuovo)
  expect_equal(.canonicalize_resolver_kind("Cytokine_Stim"), "cytokine_stim")
  expect_equal(.canonicalize_resolver_kind("cytokine stim"), "cytokine_stim")
  expect_equal(.canonicalize_resolver_kind("Disease vs normal"), "disease_vs_normal")
  # ignoto e vuoto -> passano tali quali (catch-all a valle)
  expect_equal(.canonicalize_resolver_kind("qwerty"), "qwerty")
  expect_equal(.canonicalize_resolver_kind(""), "")
})

test_that(".resolve_canonical_to_id risolve la citochina full-name col kind grezzo 'cytokine' (ImmPort whole-string)", {
  # Mistral emette kind="cytokine" (non "cytokine_stim") e "interleukin-6"
  # (non il symbol "IL6"). Il dispatch va normalizzato e la citochina risolta
  # via lookup ImmPort WHOLE-STRING (non token-extraction) + gate whitelist.
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("interleukin-6", "cytokine", env = list()),
    .immport_lookup_synonym = function(term, env)
      if (identical(tolower(term), "interleukin-6"))
        list(hgnc_int = 6018L, primary_symbol = "IL6") else NULL,
    .is_cytokine_symbol = function(hgnc_int, env) identical(as.integer(hgnc_int), 6018L),
    .hgnc_lookup_hgnc = function(hgnc_int, env) list(symbol = "IL6"),
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "HGNC:6018")
  expect_equal(res$resolved_name, "IL6")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id cytokine preferisce HGNC su MeSH (non risolve a MeSH:D016899)", {
  # Regressione dello smoke: "interferon beta" col catch-all andava a
  # MeSH:D016899 invece del gene IFNB1. La citochina deve vincere sul MeSH.
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("interferon beta", "cytokine", env = list()),
    .immport_lookup_synonym = function(term, env)
      list(hgnc_int = 5434L, primary_symbol = "IFNB1"),
    .is_cytokine_symbol = function(hgnc_int, env) TRUE,
    .hgnc_lookup_hgnc = function(hgnc_int, env) list(symbol = "IFNB1"),
    .mesh_lookup_term = function(term, env) list(ui = "D016899"),
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "HGNC:5434")
})

test_that(".resolve_canonical_to_id cytokine NON ruba un token (whole-string): 'IL-6 receptor' -> NONE, non HGNC:IL6", {
  # PRECISION LEAK (review adversariale): il resolver NON deve fare
  # token-extraction. "IL-6 receptor" e' IL6R, non IL6. Il mock ImmPort
  # riproduce il comportamento REALE: colpisce sul token "il6" ma NON sul
  # nome intero "il6receptor". Un resolver che spezza in token risolverebbe a
  # HGNC:IL6 (spurio); un resolver whole-string colleziona NULL -> NONE.
  imp <- function(term, env) {
    key <- gsub("[^a-z0-9]", "", tolower(term))
    if (identical(key, "il6")) list(hgnc_int = 6018L, primary_symbol = "IL6") else NULL
  }
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("IL-6 receptor", "cytokine_stim", env = list()),
    .immport_lookup_synonym = imp,
    .is_cytokine_symbol = function(hgnc_int, env) TRUE,
    .hgnc_lookup_hgnc = function(hgnc_int, env) list(symbol = "IL6"),
    .hgnc_lookup_symbol = function(symbol, env) NULL,
    .uniprot_lookup_name = function(term, env) NULL,
    .chebi_lookup_alias = function(alias, env) NULL,
    .package = "simulomicsr")
  expect_true(is.na(res$resolved_id))
  expect_equal(res$match_strength, "NONE")
})

test_that(".resolve_canonical_to_id cytokine_stim gate whitelist: gene non-citochina non emette HGNC dal path citochina", {
  # ImmPort puo' mappare un sinonimo a un gene NON-citochina (es. un recettore):
  # il gate .is_cytokine_symbol FALSE deve far proseguire la catena, non
  # emettere un HGNC dal ramo citochina. Qui prosegue a ChEBI.
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("poly(I:C)", "cytokine_stim", env = list()),
    .immport_lookup_synonym = function(term, env) NULL,
    .hgnc_lookup_symbol = function(symbol, env) NULL,
    .uniprot_lookup_name = function(term, env) NULL,
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "poly(i:c)"))
      list(chebi_id = 84491L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "CHEBI:84491")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".normalize_greek_stereo compatta i descrittori stereo numero-greca", {
  b <- "β"  # β
  expect_equal(.normalize_greek_stereo("17-beta-estradiol"), paste0("17", b, "-estradiol"))
  expect_equal(.normalize_greek_stereo("17beta-estradiol"), paste0("17", b, "-estradiol"))
  expect_equal(.normalize_greek_stereo(paste0("17-", b, "-estradiol")), paste0("17", b, "-estradiol"))
  # senza cifra prima: invariato (evita falsi positivi)
  expect_equal(.normalize_greek_stereo("beta-estradiol"), "beta-estradiol")
  # nessun descrittore: invariato
  expect_equal(.normalize_greek_stereo("aspirin"), "aspirin")
})

## ---------------------------------------------------------------------------
## Identita' del gene: ID canonico = HGNC:<numero> (stabile; i simboli vengono
## rinominati). Il simbolo resta come etichetta leggibile — stesso pattern di
## gene_id/gene_symbol nello Stadio 4 (FASE E1). Misura 2026-07-07: negli anchor
## v7 lo stesso gene compare come HGNC:6407 e HGNC:KRAS -> 80 gruppi non si
## fondono (3 meta-analisi perse: PF4, TGFB1, TNF).
## ---------------------------------------------------------------------------

test_that(".canonicalize_gene_id porta qualunque forma HGNC al numero canonico", {
  hs <- function(symbol, env) switch(tolower(symbol),
    kras = list(hgnc_int = 6407L, primary_symbol = "KRAS", match_type = "PRIMARY"),
    bsf2 = list(hgnc_int = 6018L, primary_symbol = "IL6", match_type = "ALIAS"),
    NULL)
  testthat::with_mocked_bindings({
    expect_equal(.canonicalize_gene_id("HGNC:KRAS", env = list()), "HGNC:6407")
    # gia' canonico: invariato (nessun lookup necessario)
    expect_equal(.canonicalize_gene_id("HGNC:6407", env = list()), "HGNC:6407")
    # alias storico -> gene canonico (BSF2 e' IL6)
    expect_equal(.canonicalize_gene_id("HGNC:BSF2", env = list()), "HGNC:6018")
    # simbolo non risolvibile: invariato (nessuna invenzione)
    expect_equal(.canonicalize_gene_id("HGNC:QWERTY", env = list()), "HGNC:QWERTY")
    # non-gene: invariato
    expect_equal(.canonicalize_gene_id("CHEBI:16469", env = list()), "CHEBI:16469")
    expect_equal(.canonicalize_gene_id(NA_character_, env = list()), NA_character_)
  }, .hgnc_lookup_symbol = hs, .package = "simulomicsr")
})

test_that(".canonicalize_resolver_kind mappa il vocabolario genetico di Mistral", {
  # kind realmente emessi dal full run T13
  expect_equal(.canonicalize_resolver_kind("genetic_variant"), "genetic_perturbation")
  expect_equal(.canonicalize_resolver_kind("genetic_knockdown"), "genetic_perturbation")
  expect_equal(.canonicalize_resolver_kind("gene_mutation"), "genetic_perturbation")
  expect_equal(.canonicalize_resolver_kind("genetic_mutation"), "genetic_perturbation")
  expect_equal(.canonicalize_resolver_kind("genetic_overexpression"), "genetic_perturbation")
  expect_equal(.canonicalize_resolver_kind("protein_overexpression"), "genetic_perturbation")
  expect_equal(.canonicalize_resolver_kind("chemical"), "small_molecule")
})

test_that(".resolve_canonical_to_id sui kind genetici risolve il GENE (HGNC), non MeSH", {
  # Caso reale APOE (group_L4_451d0812): i metadati sono genotipi APOE e4/e3.
  # Mistral emette kind="genetic_variant" e nome "APOE": deve risolvere al gene,
  # NON a MeSH:D001057 (Apolipoproteins E, la proteina) come faceva il catch-all.
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("APOE", "genetic_variant", env = list()),
    .hgnc_lookup_symbol = function(symbol, env) if (identical(tolower(symbol), "apoe"))
      list(hgnc_int = 613L, primary_symbol = "APOE", match_type = "PRIMARY") else NULL,
    .mesh_lookup_term = function(term, env) list(ui = "D001057"),
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "HGNC:613")
  expect_equal(res$resolved_name, "APOE")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id sui kind genetici risolve il NOME ESTESO del gene via UniProt", {
  # "androgen receptor" e' il nome esteso del gene AR (non il simbolo): il
  # lookup per simbolo manca, UniProt (whole-string) lo mappa a HGNC:644.
  # Senza questo, un knockdown di AR restava sull'ID MeSH del recettore-proteina
  # (namespace sbagliato per una perturbazione genetica) o non si risolveva.
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("androgen receptor", "genetic_knockdown", env = list()),
    .hgnc_lookup_symbol = function(symbol, env) NULL,             # non e' un simbolo
    .uniprot_lookup_name = function(term, env) if (identical(tolower(term), "androgen receptor"))
      list(hgnc_int = 644L) else NULL,
    .hgnc_lookup_hgnc = function(hgnc_int, env) list(symbol = "AR"),
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "HGNC:644")
  expect_equal(res$resolved_name, "AR")
  expect_equal(res$match_strength, "STRONG")
})

test_that(".resolve_canonical_to_id kind genetico: nome non-gene NON diventa un gene spurio", {
  # Precision gate: GFP / siRNA / varianti non sono geni umani -> nessun HGNC.
  # E un composto etichettato per errore come genetico deve cadere su ChEBI,
  # non su un gene inventato.
  gfp <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("Green Fluorescent Protein", "protein_overexpression", env = list()),
    .hgnc_lookup_symbol = function(symbol, env) NULL,
    .uniprot_lookup_name = function(term, env) NULL,
    .chebi_lookup_alias = function(alias, env) NULL,
    .package = "simulomicsr")
  expect_true(is.na(gfp$resolved_id))
  expect_equal(gfp$match_strength, "NONE")

  tam <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("tamoxifen", "genetic_knockdown", env = list()),
    .hgnc_lookup_symbol = function(symbol, env) NULL,
    .uniprot_lookup_name = function(term, env) NULL,
    .chebi_lookup_alias = function(alias, env) if (identical(tolower(alias), "tamoxifen"))
      list(chebi_id = 41774L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(tam$resolved_id, "CHEBI:41774")
})

test_that(".resolve_canonical_to_id emette l'ID gene nel formato canonico numerico", {
  # Il resolver deve emettere HGNC:<numero>, non HGNC:<sigla>: e' l'ID stabile
  # e coerente con R/anchors.R (37.160 cluster). Il simbolo va in resolved_name.
  cyt <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("interleukin-6", "cytokine", env = list()),
    .immport_lookup_synonym = function(term, env) list(hgnc_int = 6018L, primary_symbol = "IL6"),
    .is_cytokine_symbol = function(hgnc_int, env) TRUE,
    .hgnc_lookup_hgnc = function(hgnc_int, env) list(symbol = "IL6"),
    .package = "simulomicsr")
  expect_equal(cyt$resolved_id, "HGNC:6018")
  expect_equal(cyt$resolved_name, "IL6")

  gen <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("KRAS", "genetic_knockdown", env = list()),
    .hgnc_lookup_symbol = function(symbol, env) if (identical(tolower(symbol), "kras"))
      list(hgnc_int = 6407L, primary_symbol = "KRAS", match_type = "PRIMARY") else NULL,
    .package = "simulomicsr")
  expect_equal(gen$resolved_id, "HGNC:6407")
})

test_that(".resolve_canonical_to_id risolve '17-beta-estradiol' via ChEBI dopo normalizzazione stereo", {
  # ChEBI ha l'alias "17β-estradiol" (CHEBI:16469) ma non "17-beta-estradiol":
  # il resolver deve ritentare col descrittore stereo compattato.
  b <- "β"
  res <- testthat::with_mocked_bindings(
    .resolve_canonical_to_id("17-beta-estradiol", "small_molecule", env = list()),
    .chebi_lookup_alias = function(alias, env)
      if (identical(tolower(alias), paste0("17", b, "-estradiol")))
        list(chebi_id = 16469L, type = "NAME") else NULL,
    .package = "simulomicsr")
  expect_equal(res$resolved_id, "CHEBI:16469")
  expect_equal(res$match_strength, "STRONG")
})
