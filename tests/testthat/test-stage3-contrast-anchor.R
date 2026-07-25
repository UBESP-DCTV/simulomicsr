# Anchor derivato dal CONTRASTO (ADR-0025).
#
# Ogni caso e' una riga VERA del corpus
# (analysis/audit/2026-07-24-anchor-coherence-sim/fase1-v11-results.rds), mai
# inventata: label e factor_levels sono copiati dal dato, non ricostruiti.

# ------------------------------------------------------------------ delta -----

test_that(".ca_parse_factor_levels legge entrambe le forme", {
  lst <- list(list(key = "cell_line", value = "LNCaP"),
              list(key = "treatment", value = "Enzalutamide"))
  expect_equal(.ca_parse_factor_levels(lst),
               c(cell_line = "LNCaP", treatment = "Enzalutamide"))
  expect_equal(.ca_parse_factor_levels("cell_line=LNCaP;treatment=Enzalutamide"),
               c(cell_line = "LNCaP", treatment = "Enzalutamide"))
  expect_length(.ca_parse_factor_levels(NA_character_), 0L)
  expect_length(.ca_parse_factor_levels(list()), 0L)
})

test_that(".ca_normalize_value toglie dosi, tempi e numeri", {
  expect_equal(.ca_normalize_value("Enzalutamide"), "enzalutamide")
  expect_equal(.ca_normalize_value("  "), "")
  # dose e tempo spariscono: 24h e MOI 1 non fanno parte dell'identita'
  expect_false(grepl("24", .ca_normalize_value("SARS-CoV-2 MOI 1 24h")))
  expect_true(grepl("sars", .ca_normalize_value("SARS-CoV-2 MOI 1 24h")))
})

test_that(".ca_classify_key riconosce le classi dal nome della chiave", {
  expect_equal(.ca_classify_key("treatment"), "drug")
  expect_equal(.ca_classify_key("genetic_modification"), "genetic")
  expect_equal(.ca_classify_key("infection"), "infection")
  expect_equal(.ca_classify_key("disease_state"), "disease")
  expect_equal(.ca_classify_key("time"), "time")
})

test_that(".ca_classify_key marca come identitarie le chiavi che non sono contrasti", {
  expect_equal(.ca_classify_key("cell_line"), "nuisance")
  expect_equal(.ca_classify_key("donor"), "nuisance")
  expect_equal(.ca_classify_key("tissue"), "nuisance")
  expect_equal(.ca_classify_key("age"), "nuisance")
})

test_that(".ca_delta isola cio' che cambia fra i due bracci (GSE147876, enzalutamide)", {
  d <- .ca_delta("cell_line=LNCaP;treatment=Enzalutamide",
                 "cell_line=LNCaP;treatment=Vehicle")
  expect_equal(d$dominant_class, "drug")
  expect_equal(d$treated_values, "Enzalutamide")
  expect_equal(d$control_values, "Vehicle")
  expect_equal(d$classes_signature, "drug")   # cell_line non cambia -> non entra
})

test_that(".ca_delta e' vuoto quando i due bracci sono identici (GSE72509)", {
  d <- .ca_delta("disease_state=healthy;treatment=control",
                 "disease_state=healthy;treatment=control")
  expect_true(is.na(d$dominant_class))
  expect_equal(d$classes_signature, "")
})

test_that(".ca_delta ignora le chiavi identitarie che cambiano da sole", {
  d <- .ca_delta("donor=D1;tissue=lung", "donor=D2;tissue=lung")
  expect_true(is.na(d$dominant_class))
})

test_that(".ca_delta sceglie la classe dominante per priorita'", {
  d <- .ca_delta("genetic_modification=shTP53;treatment=DMSO",
                 "genetic_modification=shControl;treatment=Palbociclib")
  expect_equal(d$dominant_class, "genetic")     # genetic > drug
  expect_equal(d$classes_signature, "drug+genetic")
})

# ------------------------------------------------------- entita' del delta ----

test_that(".ca_strip_units toglie dosi e unita' senza spezzare i nomi", {
  expect_equal(.ca_strip_units("GO 1 ug/ml"), "go")
  # il numero attaccato al nome NON si tocca: "sars-cov-2" non deve diventare
  # "sars-cov" (= SARS 2003, un'altra specie: bug misurato su 166 membri)
  expect_true(grepl("sars-cov-2", .ca_strip_units("SARS-CoV-2 infected")))
  expect_true(grepl("il-6", .ca_strip_units("IL-6 10 ng/ml")))
  expect_false(grepl("24", .ca_strip_units("SARS-CoV-2 MOI 1 24h")))
})

test_that(".ca_is_unit_or_nonentity riconosce cio' che non e' mai un'entita'", {
  expect_true(.ca_is_unit_or_nonentity("ml"))
  expect_true(.ca_is_unit_or_nonentity("untreated"))
  expect_true(.ca_is_unit_or_nonentity("24"))
  expect_true(.ca_is_unit_or_nonentity("go"))     # sotto i 3 caratteri
  expect_false(.ca_is_unit_or_nonentity("enzalutamide"))
})

test_that(".ca_acronym_ok blocca le sigle corte che non coincidono col nome risolto", {
  # "ML" e' sinonimo ImmPort di Thrombopoietin: e' un'unita' di volume
  expect_false(.ca_acronym_ok("ml", "Thrombopoietin"))
  expect_true(.ca_acronym_ok("lps", "LPS"))
  expect_true(.ca_acronym_ok("enzalutamide", "enzalutamide"))
})

test_that(".ca_candidates non passa il label intero per la classe drug", {
  cand <- .ca_candidates("Enzalutamide", "LNCaP CD8 T cells Enzalutamide Treated", "drug")
  expect_true("enzalutamide" %in% cand)
  expect_false(any(grepl("cd8", cand)))
  # per infection il label intero e' ammesso: il nome del patogeno spesso sta solo li'
  cand2 <- .ca_candidates("infected", "Calu-3 infected with SARS-CoV-2", "infection")
  expect_true(any(grepl("sars-cov-2", cand2)))
})

test_that(".ca_resolve_entity risolve le entita' vere (dizionari reali)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  expect_equal(.ca_resolve_entity("drug", "Enzalutamide",
                                  .ca_candidates("Enzalutamide", NA, "drug"), oe)$id,
               "CHEBI:68534")
  expect_equal(.ca_resolve_entity("drug", "SARS-CoV-2 MOI 1 24h",
                                  .ca_candidates("SARS-CoV-2 MOI 1 24h", NA, "drug"), oe)$id,
               "NCBITaxon:2697049")
  expect_true(is.na(.ca_resolve_entity("drug", "untreated",
                                       .ca_candidates("untreated", NA, "drug"), oe)$id))
})

test_that(".ca_resolve_entity non trasforma le unita' di misura in entita'", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_resolve_entity("drug", "GO 1 ug/ml", .ca_candidates("GO 1 ug/ml", NA, "drug"), oe)
  expect_false(identical(r$id, "HGNC:11795"))   # THPO
})

# ------------------------------------------------------------- combinazioni ---

test_that(".ca_combo_parts vede la combinazione dentro il valore (GSE197602)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  expect_setequal(.ca_combo_parts("Palbociclib+Indisulam", oe), c("palbociclib", "indisulam"))
  expect_length(.ca_combo_parts("Enzalutamide", oe), 0L)
  # "/" e "_" contano solo se >=2 parti sono agenti veri: "SARS-CoV-2_MOI_1" no
  expect_length(.ca_combo_parts("SARS-CoV-2_MOI_1", oe), 0L)
})

test_that(".ca_combo_parts vede la combinazione separata da / e da _ (regressione)", {
  # Misurato dall'equivalenza 2026-07-27: .ca_strip_units trasforma "/" in spazio,
  # quindi il separatore spariva PRIMA dello split e "Bleomycin/Alpha-Lipoic Acid"
  # diventava la sola bleomicina. Le dosi vanno tolte preservando i separatori.
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  expect_length(.ca_combo_parts("Bleomycin/Alpha-Lipoic Acid", oe), 2L)
  expect_length(.ca_combo_parts("Vemurafenib_Acalabrutinib", oe), 2L)
  # ma "/" fra un agente e del rumore NON e' una combinazione
  expect_length(.ca_combo_parts("LPS 10 ug/ml", oe), 0L)
})

test_that(".ca_combo_from_labels non conta gli agenti tenuti costanti", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # SARS sta su entrambi i bracci: il contrasto e' su ruxolitinib, non una combo
  expect_length(.ca_combo_from_labels("SARS-CoV-2 + Ruxolitinib", "SARS-CoV-2", oe), 0L)
})

test_that(".ca_agent_id riconosce un agente vero e rifiuta il rumore", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  expect_true(nzchar(.ca_agent_id("palbociclib", oe)))
  expect_equal(.ca_agent_id("moi", oe), "")
  expect_equal(.ca_agent_id("053", oe), "")
})

# ------------------------------------------------- verdetto per-membro --------
# Le righe sono copiate da fase1-v11-results.rds: label, factor_levels e verdetto
# atteso sono quelli MISURATI dal gate v11.

test_that(".ca_member_contrast tiene un contrasto pulito (GSE147876, enzalutamide)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast(
    treated_label = "LNCaP Enzalutamide Treated", control_label = "LNCaP Vehicle Control",
    treated_fl = "cell_line=LNCaP;treatment=Enzalutamide",
    control_fl = "cell_line=LNCaP;treatment=Vehicle",
    ontology_env = oe)
  expect_equal(r$drop_reason, "")
  expect_equal(r$entity, "CHEBI:68534")
  expect_equal(r$direction, "gain")
  expect_equal(r$control_key, "vehicle_untreated")
})

test_that(".ca_member_contrast ricompone SARS-CoV-2 sotto l'ID del patogeno", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast("Calu-3 SARS-CoV-2 infected", "mock",
                           "treatment=SARS-CoV-2 MOI 1 24h", "treatment=mock",
                           ontology_env = oe)
  expect_equal(r$drop_reason, "")
  expect_equal(r$entity, "NCBITaxon:2697049")
})

test_that(".ca_member_contrast marca la combinazione come entita' a se' (GSE197602)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast("A549 cells treated with Palbociclib and Indisulam",
                           "Untreated A549 cells",
                           "cell_line=A549;treatment=Palbociclib+Indisulam",
                           "cell_line=A549;treatment=untreated",
                           ontology_env = oe)
  expect_equal(r$entity, "COMBO:indisulam+palbociclib")
  expect_equal(r$entity_source, "COMBO")
  expect_equal(r$drop_reason, "")
})

test_that(".ca_member_contrast scarta il delta vuoto (GSE72509)", {
  r <- .ca_member_contrast("Healthy Control", "Healthy Control",
                           "disease_state=healthy;treatment=control",
                           "disease_state=healthy;treatment=control",
                           ontology_env = .load_ontology_dicts())
  expect_equal(r$drop_reason, "no_delta")
  expect_true(is.na(r$entity))
})

test_that(".ca_member_contrast scarta la riga mal appaiata sul tempo (GSE218827)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast("HEK293T treated with siCont for 24 hours",
                           "HEK293T treated with DMSO for 0 hours (control)",
                           "time=24h;treatment=siCont", "time=0h;treatment=DMSO",
                           ontology_env = oe)
  expect_equal(r$drop_reason, "riga_tempo_non_appaiato")
})

test_that(".ca_member_contrast scarta quando l'entita' e' tenuta costante (GSE97326)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast("HEK293T_MLL3_G368V_mutation", "HEK293T_wild_type_MLL3",
                           "cell_line=HEK293T;genetic_modification=MLL3 G368V mutation",
                           "cell_line=HEK293T;genetic_modification=wild type MLL3",
                           ontology_env = oe)
  expect_equal(r$drop_reason, "entita_costante")
})

test_that(".ca_member_contrast usa il nome dell'anchor quando il delta lo nomina", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # on-contrast: il delta nomina l'entita' che il resolver ha gia' risolto
  # nell'anchor di QUESTO record (nel build il nome del cluster non esiste ancora)
  r <- .ca_member_contrast("HUVEC hypoxia", "HUVEC normoxia",
                           "oxygen=hypoxia", "oxygen=normoxia",
                           anchor_name = "hypoxia", anchor_id = "STR:hypoxia",
                           ontology_env = oe)
  expect_equal(r$entity_source, "anchor")
  expect_equal(r$entity, "STR:hypoxia")
})

test_that("un nome risolto che e' una sigla corta NON e' un nome generico (GSE231460)", {
  # Bug misurato dall'equivalenza (2026-07-27): usare l'euristica sui token
  # (< 4 caratteri = generico) sul NOME RISOLTO scartava 565 membri di entita'
  # vere — TNF, IL6, RSV, CMV, HBV, M. tuberculosis. Il gate misurato controlla
  # l'appartenenza al vocabolario, non la lunghezza.
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # NB: la riga vera scrive "TNFα" con la lettera greca. Scritta ASCII
  # ("TNF-alpha") il resolver trova prima un alias ChEMBL: sono due stringhe
  # diverse, e il test deve usare quella del dato.
  r <- .ca_member_contrast("TNFα stimulated", "Control (vehicle)",
                           "cell_type=HUVECs;time=26 hours;treatment=TNFα",
                           "cell_type=HUVECs;time=26 hours;treatment=vehicle_only",
                           ontology_env = oe)
  expect_equal(r$drop_reason, "")
  expect_equal(r$entity, "HGNC:11892")
})

test_that(".ca_member_contrast scarta il contrasto rotto e il controllo non valido", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  rotto <- .ca_member_contrast("HNSCC tumor tissue", "Healthy blood platelets",
                               "disease_state=HNSCC", "disease_state=healthy",
                               ontology_env = oe)
  expect_equal(rotto$drop_reason, "contrasto_rotto")
  nonctrl <- .ca_member_contrast("A549 LPS", "total RNA",
                                 "treatment=LPS", "treatment=total RNA",
                                 ontology_env = oe)
  expect_equal(nonctrl$drop_reason, "controllo_non_valido")
})
