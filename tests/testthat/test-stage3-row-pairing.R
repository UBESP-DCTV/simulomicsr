# Regole di appaiamento della RIGA (confronto trattato-vs-controllo dentro un
# gruppo). I casi sono quelli MISURATI sulla verifica riga per riga dei 143
# gruppi coerenti (2026-07-25), non esempi inventati: ogni expect_true e' una
# riga vera scartata, ogni expect_false una riga vera tenuta.

# ---------------------------------------------------------------- tempo -------

test_that(".rp_time_hours normalizza le unita' in ore", {
  expect_equal(.rp_time_hours("24h"), 24)
  expect_equal(.rp_time_hours("1 day"), 24)
  expect_equal(.rp_time_hours("7D"), 168)
  expect_equal(.rp_time_hours("30 min"), 0.5)
  expect_equal(.rp_time_hours("2 weeks"), 336)
  expect_equal(.rp_time_hours("48hpi"), 48)
})

test_that(".rp_time_hours legge i tempi anche dentro gli underscore", {
  # "_" e' carattere di parola per \\b: senza normalizzazione dei separatori
  # "osimertinib_10day" non conteneva alcun tempo (31 righe non viste).
  expect_equal(.rp_time_hours("H1650_osimertinib_10day"), 240)
  expect_equal(.rp_time_hours("H1650_DMSO_4hr"), 4)
})

test_that(".rp_time_hours ignora i numeri che non sono tempi", {
  expect_length(.rp_time_hours("Erlotinib-treated MSN08"), 0L)
  expect_length(.rp_time_hours("Panc-410, Taxol"), 0L)
  expect_length(.rp_time_hours(NA_character_), 0L)
})

test_that(".rp_time_mismatch riconosce i bracci a tempi diversi", {
  expect_true(.rp_time_mismatch("shCTL DHT 96h", "shCTL untreated 0h"))
  expect_true(.rp_time_mismatch("A375 Vemurafenib 1uM 7D", "A375 DMSO 0.1% 48h"))
  expect_true(.rp_time_mismatch("Influenza B 24hpi", "Mock 48hpi"))
  expect_true(.rp_time_mismatch("H1650_osimertinib_1day", "H1650_DMSO_4hr"))
})

test_that(".rp_time_mismatch non segnala i bracci appaiati o senza tempo", {
  expect_false(.rp_time_mismatch("MCF7_olaparib_50uM_3_days", "MCF7_DMSO_3_days"))
  expect_false(.rp_time_mismatch("1 day treatment", "24h treatment"))  # stesso tempo
  expect_false(.rp_time_mismatch("Erlotinib", "DMSO"))
  expect_false(.rp_time_mismatch("SARS-CoV-2 24h", "Mock"))            # tempo su un lato solo
})

# ------------------------------------------------- soggetto / linea cellulare --

test_that(".rp_identifiers separa i soggetti dichiarati dai codici di linea", {
  x <- .rp_identifiers("Erlotinib-treated MSN08")
  expect_equal(x$codes, "msn08")
  expect_length(x$subjects, 0L)
  y <- .rp_identifiers("Dasatinib-treated (Donor 32)")
  expect_equal(y$subjects, "32")
})

test_that(".rp_identifiers riconosce i codici con la cifra non nel primo segmento", {
  # "CWR-22Rv1": l'espressione regolare che pretendeva la cifra nel primo
  # segmento perdeva questo codice (difetto vero non visto).
  expect_true("cwr-22rv1" %in% .rp_identifiers("CWR-22Rv1 Vehicle")$codes)
})

test_that(".rp_identifiers scarta dosi, tempi, sigle biologiche e ID di archivio", {
  expect_length(.rp_identifiers("LPS 12H")$codes, 0L)
  expect_length(.rp_identifiers("Sunitinib 3 uM")$codes, 0L)
  expect_length(.rp_identifiers("IL-1 beta stimulation")$codes, 0L)
  expect_length(.rp_identifiers("hALO Mock (GSM4711201)")$codes, 0L)
  expect_length(.rp_identifiers("Control (25-year-old female)")$codes, 0L)
})

test_that(".rp_subject_mismatch riconosce donatori e linee diverse nei trattamenti", {
  expect_true(.rp_subject_mismatch("Erlotinib-treated MSN08",
                                   "DMSO-treated MSN01 cardiac myocytes", "drug"))
  expect_true(.rp_subject_mismatch("LAPC4 Enzalutamide", "CWR-22Rv1 Vehicle", "drug"))
  expect_true(.rp_subject_mismatch("Donor1 HBV D6", "Donor2 Mock D6", "drug"))
  expect_true(.rp_subject_mismatch("NCI-H1793 Bosutinib 10 uM 24h", "PANC-1 DMSO 24h", "drug"))
  expect_true(.rp_subject_mismatch("CaCO2 SARS-CoV2 passage 0", "HRT18 mock-infected", "infection"))
})

test_that(".rp_subject_mismatch non segnala i confronti appaiati", {
  expect_false(.rp_subject_mismatch("LPS 12H Donor_1", "DMSO 12H Donor_1", "drug"))
  expect_false(.rp_subject_mismatch("MSR-A549_JQ1", "MSR-A549_DMSO", "drug"))
  # stesso soggetto in due condizioni: "LS4" (lung SARS) / "LM4" (lung mock)
  expect_false(.rp_subject_mismatch("LS4 SARS-CoV-2 Infected", "LM4 Mock Infected", "infection"))
  # un codice contiene l'altro: stessa linea, dettaglio diverso
  expect_false(.rp_subject_mismatch("R1-AD1 FLAGHA-H3F3A, R1881", "H3F3A knock-in cells, Vehicle", "drug"))
})

test_that(".rp_subject_mismatch non si applica ai caso-controllo", {
  # nei disegni malattia-vs-sano i soggetti sono per forza persone diverse
  # (decisione utente 2026-07-25): non e' un difetto di appaiamento.
  expect_false(.rp_subject_mismatch("Psoriasis Case Donor 7314",
                                    "Healthy Control Donor 7360", "disease"))
  # caso-controllo clinico travestito da trattamento
  expect_false(.rp_subject_mismatch("HIV-positive Subject 14",
                                    "Untreated Subject 12 (HIV-negative)", "infection"))
})

# ------------------------------------------------------- genetica asimmetrica --

test_that(".rp_has_genetic_marker riconosce i marcatori espliciti", {
  expect_true(.rp_has_genetic_marker("HLMVECs + shMfn2 RNA + TNF"))
  expect_true(.rp_has_genetic_marker("Keloid (Transgenic Fibroblasts)"))
  expect_true(.rp_has_genetic_marker("MCF-7 + knockdown control (iluc)"))
  expect_true(.rp_has_genetic_marker("Control_siRNA_1"))     # underscore
  expect_true(.rp_has_genetic_marker("MDA-MB-231 + Vector control + Olaparib"))
})

test_that(".rp_has_genetic_marker non scambia parole comuni per marcatori", {
  # "sigmoid", "single", "significant" venivano catturati da si[a-z]+ (21 falsi
  # allarmi misurati). Il pattern e' case-sensitive: sh/si/sg + MAIUSCOLA.
  expect_false(.rp_has_genetic_marker("Crohn's disease, sigmoid colon"))
  expect_false(.rp_has_genetic_marker("Active Ulcerative Colitis (single sample)"))
  expect_false(.rp_has_genetic_marker("PCOS secretory phase"))
  # "wild-type" dice che una modifica NON c'e'
  expect_false(.rp_has_genetic_marker("wildtype HSV-1"))
})

test_that(".rp_genetic_asymmetry segnala la modifica presente su un braccio solo", {
  expect_true(.rp_genetic_asymmetry("HLMVECs + shMfn2 RNA + TNF", "HLMVECs + DMSO", "drug", NA_character_))
  expect_true(.rp_genetic_asymmetry("Cisplatin-treated R-H460",
                                    "Vehicle-treated R-H460 with transgene", "drug", NA_character_))
  expect_true(.rp_genetic_asymmetry("Keloid (Transgenic Fibroblasts)",
                                    "Normal (Fibroblasts)", "disease", NA_character_))
})

test_that(".rp_genetic_asymmetry non si applica quando la genetica E' l'entita'", {
  expect_false(.rp_genetic_asymmetry("RBM4 knockdown", "Control (vehicle)", "drug", "STR:rbm_knockdown"))
  expect_false(.rp_genetic_asymmetry("YAP TAZ knockdown", "Control siRNA 1", "drug", "COMBO:taz+yap"))
  expect_false(.rp_genetic_asymmetry("shMETTL3", "shControl", "genetic", "HGNC:31386"))
})

# --------------------------------------------------- combinazione non catturata

# I dizionari veri servono solo qui. Nella suite completa `.load_ontology_dicts()`
# puo' restituire il singleton FIXTURE caricato da un altro file di test: in quel
# caso si salta (stesso schema di test-resolver-guards.R).
.rp_real_ontology_or_skip <- function() {
  skip_if_not(dir.exists(file.path(tools::R_user_dir("simulomicsr", "cache"), "chebi")),
              "dizionari ontologici non presenti in cache")
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari caricati come fixture (isolamento suite)")
  oe
}

test_that(".rp_agents non conta due volte lo stesso agente", {
  oe <- .rp_real_ontology_or_skip()
  # "mitoxantrone (MIT)": una molecola sola. La sigla e' il prefisso della parola
  # accanto (e "MIT" da solo risolve a 3-iodo-L-tirosina, collisione nota).
  expect_length(.rp_agents("mitoxantrone (MIT)", oe), 1L)
  # "IAV (H1N1)": un virus solo, il sierotipo non e' un secondo agente
  expect_length(.rp_agents("IAV (H1N1) 48hpi", oe), 1L)
})

test_that(".rp_uncaptured_combination riconosce due agenti in piu' nel trattato", {
  oe <- .rp_real_ontology_or_skip()
  expect_true(.rp_uncaptured_combination("TNF-alpha IL-1alpha", "Control", "HGNC:11892", oe))
})

test_that(".rp_uncaptured_combination non segnala i gruppi che SONO combinazioni", {
  oe <- .rp_real_ontology_or_skip()
  expect_false(.rp_uncaptured_combination("Palbociclib and Indisulam", "Untreated",
                                          "COMBO:indisulam+palbociclib", oe))
})

test_that(".rp_uncaptured_combination non segnala l'agente unico col suo veicolo", {
  oe <- .rp_real_ontology_or_skip()
  expect_false(.rp_uncaptured_combination("Erlotinib 1 uM", "DMSO", "CHEBI:114785", oe))
})

# ------------------------------------------------------------------ verdetto --

test_that(".rp_row_defect restituisce il nome della regola violata", {
  expect_equal(.rp_row_defect("shCTL DHT 96h", "shCTL untreated 0h", "drug", "CHEBI:16330"),
               "tempo_non_appaiato")
  expect_equal(.rp_row_defect("Erlotinib-treated MSN08", "DMSO-treated MSN01", "drug", "CHEBI:114785"),
               "soggetto_diverso")
  expect_equal(.rp_row_defect("HLMVECs + shMfn2 RNA + TNF", "HLMVECs + DMSO", "drug", "HGNC:11892"),
               "genetica_asimmetrica")
})

test_that(".rp_row_defect restituisce stringa vuota sulle righe appaiate", {
  expect_identical(.rp_row_defect("Erlotinib", "DMSO", "drug", "CHEBI:114785"), "")
  expect_identical(.rp_row_defect("MSR-A549_JQ1", "MSR-A549_DMSO", "drug", "CHEBI:137113"), "")
  expect_identical(.rp_row_defect("Psoriasis Case Donor 7314", "Healthy Control Donor 7360",
                                  "disease", "STR:psoriasis"), "")
})

test_that(".rp_row_defect gestisce input degeneri senza errori", {
  expect_identical(.rp_row_defect(NA_character_, NA_character_, "drug", NA_character_), "")
  expect_identical(.rp_row_defect("", "", "drug", NA_character_), "")
})
