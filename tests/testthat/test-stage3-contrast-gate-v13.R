# Le cinque cause misurate dal censimento del 2026-07-28 (finding
# docs/findings/2026-07-28-censimento-v12-dati-veri.md). Ogni test nasce da un
# gruppo VERO del deliverable, non da un caso inventato.
#
# Non sono liste di casi: ognuna chiude un difetto del vocabolario o del punto in
# cui una regola gia' esistente viene applicata.

# --- 1. controlli sinonimi tenuti separati (frammentazione, 16 entita') --------
# .normalize_control_type cercava i BIGRAMMI ("no treatment") in una lista
# confrontata per TOKEN: non poteva matchare. Costo misurato: TGFB1 61+3,
# LPS 41+3, IFN-gamma 30+3, DHT 27+3 in gruppi separati.

test_that("i sinonimi di non-trattato collassano in vehicle_untreated", {
  for (lab in c("No Treatment", "no treatment", "Not Treated", "Untreated",
                "Unstimulated", "unstimulated control", "RPMI media",
                "control media", "normal medium", "Vehicle Control",
                "Ethanol (Vehicle Control)", "EtOH", "DMSO", "Mock")) {
    expect_equal(.normalize_control_type(lab), "vehicle_untreated",
                 info = lab)
  }
})

test_that("i controlli SPECIFICI restano distinti (non si fonde per comodita')", {
  # normossia, scramble e dieta sono controlli di un contrasto preciso: fonderli
  # creerebbe minestroni. Scelta dichiarata in .normalize_control_type.
  expect_false(.normalize_control_type("Normoxia") == "vehicle_untreated")
  expect_false(.normalize_control_type("scrambled siRNA") == "vehicle_untreated")
  expect_false(.normalize_control_type("standard diet") == "vehicle_untreated")
})

# --- 2. notazione genetica di perdita (TP53: KO + sovraespressione insieme) ----

test_that("la notazione -/- e' letta come perdita di funzione", {
  expect_equal(.cg_direction("TP53(-/-)"), "block")
  expect_equal(.cg_direction("ESCO2 (-/mut)"), "block")
  expect_equal(.cg_direction("RPE1-hTert TP53 (-/-) clone"), "block")
})

test_that("il verso di guadagno non cambia", {
  expect_equal(.cg_direction("TP53 Overexpression"), "gain")
  expect_equal(.cg_direction("TGF-beta1"), "gain")
})

test_that("il valore VERO del delta di GSE211349 e' letto come perdita", {
  # La regola opera sui VALORI DEL DELTA, non sull'etichetta: il test va scritto
  # sul dato che il gate vede davvero (fl genetic_perturbation di GSE211349).
  expect_equal(.cg_direction("TP53(-/-) + ESCO2 (-/mut)"), "block")
})

# --- 3. l'entita' e' una CLASSE, non una molecola ------------------------------
# (a) "cytokine stimulation": l'ombrello era ancorato ^...$ e non vedeva il
#     termine quando seguito da una parola generica.
# (b) "MEK inhibitor" -> U0126: il nome di classe ha agganciato un membro
#     specifico della classe. Il controllo va fatto sul CANDIDATO del resolver.

test_that("un termine-classe resta ombrello anche con parole generiche accanto", {
  expect_true(.cg_is_umbrella_name("cytokine stimulation"))
  expect_true(.cg_is_umbrella_name("cytokines"))
  expect_true(.cg_is_umbrella_name("chemokine exposure"))
  expect_true(.cg_is_umbrella_name("androgen treatment"))
})

test_that("cio' che e' fatto di soli token generici lo prende l'altra regola", {
  # "small molecule treatment" non passa dall'ombrello ma da .cg_is_generic_token:
  # sono due porte diverse per lo stesso scarto, e va detto quale delle due agisce.
  expect_false(.cg_is_umbrella_name("small molecule treatment"))
  expect_true(.cg_is_generic_token("small molecule treatment"))
})

test_that("i nomi di classe farmacologica sono ombrelli", {
  for (nm in c("MEK inhibitor", "ERK1/2 inhibitor", "MAPK inhibitors",
               "JNK Inhibitor", "proteasome inhibitor", "HDAC inhibitors",
               "beta agonist", "receptor antagonist")) {
    expect_true(.cg_is_umbrella_name(nm), info = nm)
  }
})

test_that("una molecola vera non diventa un ombrello", {
  for (nm in c("U0126", "vemurafenib", "TGFB1", "SARS-CoV-2", "enzalutamide",
               "trametinib", "poly(I:C)")) {
    expect_false(.cg_is_umbrella_name(nm), info = nm)
  }
})

test_that("affected/unaffected sono parole di stato, non entita'", {
  expect_true(.cg_is_generic_token("affected"))
  expect_true(.cg_is_generic_token("unaffected"))
})

# --- 4. induttori di sistemi condizionali -------------------------------------
# .cg_is_inducer riceveva `raw`, che per un ID ontologico e' "CHEBI:16411": non
# vedeva mai il nome. L'auxina e il dTAG degradano una proteina DIVERSA in ogni
# studio: l'entita' comune e' il reagente, non la biologia.

test_that("gli induttori sono riconosciuti dal NOME risolto", {
  for (nm in c("indole-3-acetic acid", "auxin", "doxycycline", "dTAGv-1",
               "dTAG-13", "puromycin", "IPTG")) {
    expect_true(.cg_is_inducer(nm), info = nm)
  }
})

test_that("una molecola terapeutica non e' un induttore", {
  for (nm in c("vemurafenib", "cisplatin", "TGFB1", "dexamethasone")) {
    expect_false(.cg_is_inducer(nm), info = nm)
  }
})

# --- 5. infezione clinica vs sperimentale (influenza, HIV-1) ------------------
# Il segnale piu' affidabile e' sul TRATTATO, ma il vocabolario non conosceva
# ne' "subject"/"donor" ne' l'eta' del soggetto.

test_that("il trattato che nomina un soggetto umano e' clinico", {
  cx <- function(t, c = "Control") .cg_infection_context("infection", c, t)
  expect_equal(cx("HIV-1 (39-year-old male)"), "_clin")
  expect_equal(cx("Diabetic Adipose Tissue HIV-positive Subject 14"), "_clin")
  expect_equal(cx("Influenza B Visit 2a", "Control Visit 2a"), "_clin")
  expect_equal(cx("COVID-19 patient 048", "Healthy donor 059"), "_clin")
})

test_that("l'infezione sperimentale resta sperimentale", {
  cx <- function(t, c) .cg_infection_context("infection", c, t)
  expect_equal(cx("SARS-CoV-2 infected Calu-3 cells", "Mock-infected Calu-3"), "")
  expect_equal(cx("MRC5 cells exposed to CMV/AD169", "MRC5 cells mock-infected"), "")
  expect_equal(cx("Influenza virus PR8", "Mock infection"), "")
  expect_equal(cx("HFF-1, HIV-1, 4 hours post-infection", "HFF-1, mock infection"), "")
})

# --- 6. la chiave e' una quantita', non un'entita' ("STR:2_gram") -------------

test_that("numeri e unita' di misura non sono un'entita'", {
  expect_true(.cg_is_generic_token("2 gram"))
  expect_true(.cg_is_generic_token("500 mg"))
  expect_true(.cg_is_generic_token("10 ng ml"))
})

test_that("un'entita' con un numero dentro resta un'entita'", {
  # la correzione del 2026-07-26 ("le cifre restano nel nome") non va disfatta
  expect_false(.cg_is_generic_token("rbm4"))
  expect_false(.cg_is_generic_token("u0126"))
  expect_false(.cg_is_generic_token("p16ink4a"))
})
