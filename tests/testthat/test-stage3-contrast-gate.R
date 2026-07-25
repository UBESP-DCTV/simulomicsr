# Regole del gate di coerenza del contrasto. Ogni caso qui sotto e' un caso VERO
# misurato durante il rework dell'anchor (v6->v10, 2026-07-24/26): i commenti
# dicono quale cluster o quale falso positivo la regola ha chiuso.

# ------------------------------------------------------------- token generici --

test_that(".cg_is_generic_token riconosce cio' che non e' un'entita'", {
  for (t in c("control", "vehicle", "untreated", "high", "low", "mutant", "vector",
              "biopsy", "specimen", "placebo", "timepoint", "cohort",
              "tumor", "cancer", "neoplasms", "carcinoma", "genotype")) {
    expect_true(.cg_is_generic_token(t), info = t)
  }
})

test_that(".cg_is_generic_token NON scarta le entita' vere", {
  for (t in c("enzalutamide", "sars-cov-2", "lipopolysaccharide", "tgf-beta1",
              "vemurafenib", "hypoxia", "psoriasis")) {
    expect_false(.cg_is_generic_token(t), info = t)
  }
})

test_that(".cg_is_generic_token scarta i token troppo corti o senza lettere", {
  expect_true(.cg_is_generic_token("abc"))
  expect_true(.cg_is_generic_token("123456"))
  expect_true(.cg_is_generic_token(NA_character_))
  expect_true(.cg_is_generic_token(""))
})

test_that(".cg_is_generic_token: i connettori non salvano una stringa generica", {
  # "control with vehicle" e' generica quanto "control": i connettori vanno tolti
  # prima di decidere (regola v7).
  expect_true(.cg_is_generic_token("control with vehicle"))
  expect_false(.cg_is_generic_token("control with enzalutamide"))
})

# ------------------------------------------------------------------ induttori --

test_that(".cg_is_inducer riconosce gli induttori dei sistemi condizionali", {
  expect_true(.cg_is_inducer("doxycycline"))
  expect_true(.cg_is_inducer("IAA treatment"))     # auxina nei sistemi degron
  expect_true(.cg_is_inducer("1 ug/ml dox"))
  expect_false(.cg_is_inducer("dexamethasone"))
  expect_false(.cg_is_inducer("doxorubicin"))      # non e' doxiciclina
})

# ----------------------------------------------------------- verso del delta --

test_that(".cg_direction distingue perdita, blocco e guadagno", {
  expect_equal(.cg_direction("glucose deprivation"), "loss")
  expect_equal(.cg_direction("serum starvation"), "loss")
  expect_equal(.cg_direction("MEK inhibitor"), "block")
  expect_equal(.cg_direction("shRNA knockdown"), "block")
  expect_equal(.cg_direction("estradiol addition"), "gain")
  expect_equal(.cg_direction("agonist stimulation"), "gain")
})

test_that(".cg_direction vede i marcatori anche dopo un underscore", {
  # "_" e' carattere di parola: in "calcium_low" il marcatore di verso non veniva
  # visto e i due versi opposti finivano nello stesso gruppo (bug misurato v7b).
  expect_equal(.cg_direction("calcium_low"), "loss")
  expect_equal(.cg_direction("calcium_high"), "gain")
})

test_that(".cg_direction segnala il verso ambiguo", {
  # agonista e antagonista insieme: il verso non e' determinabile -> il gruppo si
  # scarta (decisione utente 2026-07-25).
  expect_equal(.cg_direction("androgen deprivation and androgen addition"), "ambiguo")
})

test_that(".cg_direction su valore vuoto assume la presenza dell'agente", {
  expect_equal(.cg_direction(""), "gain")
  expect_equal(.cg_direction(NA_character_), "gain")
})

# ----------------------------------------------------------------- anatomia ---

test_that(".cg_anatomy legge l'anatomia indipendentemente dalle maiuscole", {
  # bug misurato: il gsub girava PRIMA di tolower, "Acute Myeloid Leukemia (Blood)"
  # diventava "cute yeloid eukemia lood" e il contrasto AML-vs-polmone passava.
  expect_true("blood" %in% .cg_anatomy("Acute Myeloid Leukemia (Blood)"))
  expect_true("lung" %in% .cg_anatomy("Normal Lung"))
})

test_that(".cg_anatomy normalizza i sinonimi d'organo", {
  expect_equal(.cg_anatomy("renal cell carcinoma"), "kidney")
  expect_equal(.cg_anatomy("pulmonary fibroblasts"), "lung")
  expect_equal(.cg_anatomy("hepatic tissue"), "liver")
})

test_that(".cg_broken_contrast riconosce i bracci su anatomie disgiunte", {
  expect_true(.cg_broken_contrast("Acute Myeloid Leukemia (Blood)", "Normal Lung tissue"))
  # sinonimi: NON e' un contrasto rotto (falso positivo misurato)
  expect_false(.cg_broken_contrast("renal cell carcinoma", "normal KIDNEY tissue"))
})

test_that(".cg_broken_contrast riconosce il materiale diverso fra i bracci", {
  expect_true(.cg_broken_contrast("HNSCC tumor tissue", "Healthy blood platelets"))
  expect_true(.cg_broken_contrast("HCC tumor tissue", "control plasma"))
  expect_false(.cg_broken_contrast("HCC tumor tissue", "adjacent tissue"))
})

test_that(".cg_broken_contrast riconosce i tipi cellulari disgiunti", {
  expect_true(.cg_broken_contrast("stimulated macrophages", "resting fibroblasts"))
  expect_false(.cg_broken_contrast("stimulated macrophages", "resting macrophages"))
})

# --------------------------------------------------- materiale e baseline -----

test_that(".cg_material_arm distingue il materiale liquido", {
  expect_equal(.cg_material_arm("plasma sample"), "liquid")
  expect_equal(.cg_material_arm("serum exosomes"), "liquid")
  expect_equal(.cg_material_arm("tumor tissue"), "solid")
})

test_that(".cg_baseline_kind riconosce la baseline propria (longitudinale)", {
  expect_equal(.cg_baseline_kind("Baseline"), "_ownbase")
  expect_equal(.cg_baseline_kind("week 0"), "_ownbase")
  expect_equal(.cg_baseline_kind("pre-treatment biopsy"), "_ownbase")
  expect_equal(.cg_baseline_kind("Healthy control"), "")
})

# ----------------------------------------- infezione clinica vs sperimentale --

test_that(".cg_infection_context separa l'infezione clinica da quella sperimentale", {
  # "MRC5 esposte a CMV" vs "mock" e' sperimentale; "CMV viremia" in un paziente
  # e' uno stato clinico: non sono lo stesso contrasto (regola v8b).
  expect_equal(.cg_infection_context("infection", "mock-infected cells", "MRC5 + CMV"), "")
  expect_equal(.cg_infection_context("infection", "control", "CMV viremia"), "_clin")
  expect_equal(.cg_infection_context("infection", "healthy donors", "HBV infected"), "_clin")
  # fuori dalla classe infection la regola non si applica
  expect_equal(.cg_infection_context("drug", "healthy donors", "enzalutamide"), "")
})

# --------------------------------------------- resistenza, controlli, classi --

test_that(".cg_resistance_mismatch riconosce lo stato di resistenza su un braccio solo", {
  expect_true(.cg_resistance_mismatch("resistant cells + drug", "parental cells + vehicle"))
  expect_false(.cg_resistance_mismatch("resistant cells + drug", "resistant cells + vehicle"))
})

test_that(".cg_is_noncontrol riconosce i controlli che non sono controlli", {
  expect_true(.cg_is_noncontrol("total RNA"))
  expect_true(.cg_is_noncontrol("input"))
  expect_true(.cg_is_noncontrol("genomic DNA"))
  expect_false(.cg_is_noncontrol("untreated cells"))
})

test_that(".cg_is_multiclass riconosce i delta che muovono piu' di una classe", {
  # "LSCC + tobacco smoking" muove malattia E ambiente: non isola una cosa sola.
  expect_true(.cg_is_multiclass("drug+disease"))
  expect_true(.cg_is_multiclass("disease+environment"))
  expect_false(.cg_is_multiclass("drug"))
  expect_false(.cg_is_multiclass("drug+nuisance"))
  expect_false(.cg_is_multiclass(""))
})

test_that(".cg_is_umbrella_name riconosce i nomi-classe", {
  for (n in c("Neoplasms", "carcinoma", "cytokines", "syndrome", "steroid", "vectors")) {
    expect_true(.cg_is_umbrella_name(n), info = n)
  }
  for (n in c("enzalutamide", "lipopolysaccharide", "psoriasis")) {
    expect_false(.cg_is_umbrella_name(n), info = n)
  }
})

test_that(".cg_is_control_like_treated riconosce il trattato che e' un controllo", {
  expect_true(.cg_is_control_like_treated("WT"))
  expect_true(.cg_is_control_like_treated("no mutation"))
  expect_true(.cg_is_control_like_treated("healthy"))
  expect_false(.cg_is_control_like_treated("BRAF V600E"))
})

# --------------------------------------------------- entita' on-contrast ------

test_that(".cg_distinctive_tokens toglie anatomia, parole generiche e termini-classe", {
  # "lung adenocarcinoma" e' anatomia + termine-classe: NESSUN token distintivo,
  # quindi non puo' rivendicare nessun contrasto (ed e' cosi' che smette di
  # inghiottire "SSc lung fibroblasts").
  expect_length(.cg_distinctive_tokens("lung adenocarcinoma"), 0L)
  expect_length(.cg_distinctive_tokens("lung tissue"), 0L)
  expect_setequal(.cg_distinctive_tokens("heat shock"), c("heat", "shock"))
  expect_equal(.cg_distinctive_tokens("enzalutamide"), "enzalutamide")
  expect_setequal(.cg_distinctive_tokens("respiratory syncytial virus"),
                  c("respiratory", "syncytial"))
})

test_that(".cg_matches_all_words richiede TUTTI i token a parola intera", {
  # "lung adenocarcinoma" non deve inghiottire "SSc lung fibroblasts", e
  # "heat shock" non deve inghiottire "HEATed tobacco" (regola v7 R1).
  expect_false(.cg_matches_all_words(.cg_distinctive_tokens("lung adenocarcinoma"),
                                     "SSc lung fibroblasts"))
  expect_false(.cg_matches_all_words(.cg_distinctive_tokens("heat shock"),
                                     "HEATed tobacco product"))
  expect_true(.cg_matches_all_words(.cg_distinctive_tokens("heat shock"),
                                    "cells after heat shock at 42C"))
  expect_false(.cg_matches_all_words(character(0), "qualunque cosa"))
})
