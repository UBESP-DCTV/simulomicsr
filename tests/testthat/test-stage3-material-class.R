# test-stage3-material-class.R --- TDD per R/stage3-material-class.R
#
# PERCHE' ESISTE. Il Layer B ha mostrato che il gruppo Parkinson mescola cervello
# post-mortem di paziente e neuroni derivati da iPSC, col modello cellulare che
# porta il 73% del peso. Leggendo tutti e 20 i gruppi di malattia si e' visto che
# NON e' un caso isolato: almeno 6 su 20 hanno la stessa forma. Ritrattare il
# verdetto del solo Parkinson sarebbe stata una lista scritta a mano; serve un
# segnale misurabile su tutti.
#
# COSA QUESTO NON E'. Non e' un classificatore di materiale biologico. E' un
# rilevatore di UN segnale dichiarato — "questo braccio nomina un sistema in
# vitro" — con un vocabolario esplicito, confrontato con la lettura a mano dei
# 20 gruppi di malattia. Il suo compito e' aggiungere una colonna al deliverable,
# non cambiare un verdetto.
#
# LA COSA CHE QUESTI TEST DIFENDONO: che lo strumento veda il dato per intero.
# Tre volte in questo progetto un rilevatore e' stato cieco (alias corti, lettere
# greche cancellate, testo troncato a 58 caratteri). Qui: match a PAROLA INTERA
# (non "esc" dentro "obsolescence"), underscore trattato come separatore (non e'
# un carattere di parola per questo scopo), e nessun limite di lunghezza.

test_that("riconosce i sistemi in vitro nominati per esteso", {
  expect_equal(.classify_material("Neural progenitors, PARK2, PD case"), "model")
  expect_equal(.classify_material("iPSC-derived macrophage"), "model")
  expect_equal(.classify_material("Mesenchymal Stem Cells (iPSC-derived)"), "model")
  expect_equal(.classify_material("Colon Organoid Polyp"), "model")
  expect_equal(.classify_material("CRC patient-derived spheroids"), "model")
  expect_equal(.classify_material("Renal Cell Carcinoma Cultures (Donor 80)"), "model")
  expect_equal(.classify_material("hESC-derived cardiomyocytes"), "model")
  expect_equal(.classify_material("LNCaP cells treated with DHT"), "model")
})

test_that("riconosce il materiale primario di paziente o donatore", {
  expect_equal(.classify_material("Parkinson's disease substantia nigra"), "primary")
  expect_equal(.classify_material("Hepatocellular carcinoma tissue"), "primary")
  expect_equal(.classify_material("HCC PBMC"), "primary")
  expect_equal(.classify_material("Adjacent Normal Stomach Tissue"), "primary")
  expect_equal(.classify_material("Placental biopsy, preeclampsia"), "primary")
  expect_equal(.classify_material("RA blood neutrophils"), "primary")
})

test_that("il segnale in vitro VINCE sul segnale primario", {
  # "patient-derived spheroids" contiene entrambi: e' comunque un sistema in
  # vitro. Il marcatore in vitro e' piu' specifico e va tenuto per primo.
  expect_equal(.classify_material("CRC patient-derived spheroids (untreated)"), "model")
  expect_equal(.classify_material("Parkinson's Disease Patient-Derived Dopamine Neurons"), "model")
  expect_equal(.classify_material("Astrocyte Progenitor Cell Huntington's Disease Male"), "model")
})

test_that("senza segnale dichiara ignoto invece di indovinare", {
  expect_equal(.classify_material("Crohn's Disease"), "unknown")
  expect_equal(.classify_material("Healthy Control"), "unknown")
  expect_equal(.classify_material("Case T1a Grade1"), "unknown")
  expect_equal(.classify_material(""), "unknown")
  expect_equal(.classify_material(NA_character_), "unknown")
})

test_that("il match e' a PAROLA INTERA: niente sottostringhe", {
  # "esc" dentro "obsolescence"/"descending", "ips" dentro "eclipse",
  # "line" dentro "linear": nessuno deve accendere il rilevatore.
  expect_equal(.classify_material("descending segment"), "unknown")
  expect_equal(.classify_material("obsolescence marker"), "unknown")
  expect_equal(.classify_material("linear model output"), "unknown")
  expect_equal(.classify_material("eclipse phase"), "unknown")
  # controprova: la stessa frase con un marcatore VERO deve accendersi, cosi'
  # il test di cui sopra non passa solo perche' il rilevatore e' spento.
  expect_equal(.classify_material("descending colon"), "primary")
})

test_that("l'underscore separa le parole", {
  # `_` E' un carattere di parola per le regex: se non lo si tratta, `\\borganoid\\b`
  # non trova `lung_organoid`. E' l'errore gia' pagato il 2026-07-26.
  expect_equal(.classify_material("lung_organoid_treated"), "model")
  expect_equal(.classify_material("tumor_tissue_patient_12"), "primary")
})

test_that("non c'e' nessun limite di lunghezza: lo strumento vede tutto", {
  lunga <- paste0(strrep("condizione sperimentale molto descrittiva ", 20), "organoid")
  expect_gt(nchar(lunga), 500)
  expect_equal(.classify_material(lunga), "model")
})

test_that("e' vettorizzato e conserva l'ordine", {
  out <- .classify_material(c("Colon Organoid", "tumor tissue", "qualcosa"))
  expect_equal(out, c("model", "primary", "unknown"))
})

test_that("detect_mixed_material marca un gruppo che mescola modello e paziente", {
  membri <- data.frame(
    cluster_id = rep("c1", 4),
    study_id   = c("GSE1", "GSE2", "GSE3", "GSE4"),
    label      = c("Parkinson's disease substantia nigra",
                   "Parkinson's disease amygdala",
                   "Neural progenitors, PARK2, PD case",
                   "Parkinson's Disease"),
    stringsAsFactors = FALSE
  )
  out <- detect_mixed_material(membri)

  expect_equal(nrow(out), 1L)
  expect_true(out$materiale_misto)
  expect_equal(out$n_studi_model, 1L)
  expect_equal(out$n_studi_primary, 2L)
  expect_equal(out$n_studi_unknown, 1L)
})

test_that("un gruppo tutto primario, o tutto modello, NON e' misto", {
  solo_primario <- data.frame(
    cluster_id = "c1", study_id = c("GSE1", "GSE2"),
    label = c("colon tissue", "colon biopsy"), stringsAsFactors = FALSE)
  solo_modello <- data.frame(
    cluster_id = "c2", study_id = c("GSE1", "GSE2"),
    label = c("LNCaP cells", "Colon Organoid"), stringsAsFactors = FALSE)

  expect_false(detect_mixed_material(solo_primario)$materiale_misto)
  expect_false(detect_mixed_material(solo_modello)$materiale_misto)
})

test_that("gli IGNOTI da soli non bastano a marcare: si dichiara, non si indovina", {
  membri <- data.frame(
    cluster_id = "c1", study_id = c("GSE1", "GSE2", "GSE3"),
    label = c("Crohn's Disease", "Healthy Control", "colon tissue"),
    stringsAsFactors = FALSE)
  out <- detect_mixed_material(membri)
  expect_false(out$materiale_misto)
  expect_equal(out$n_studi_unknown, 2L)
})

test_that("uno studio con etichette discordanti conta UNA volta, dal segnale piu' forte", {
  # Un solo studio con due bracci, uno che nomina l'organoide e uno no, non deve
  # far sembrare misto un gruppo che ha un solo studio.
  membri <- data.frame(
    cluster_id = "c1", study_id = c("GSE1", "GSE1"),
    label = c("Colon Organoid treated", "untreated"), stringsAsFactors = FALSE)
  out <- detect_mixed_material(membri)

  expect_equal(out$n_studi_model, 1L)
  expect_equal(out$n_studi_primary, 0L)
  expect_false(out$materiale_misto)
})

test_that("piu' cluster restano separati e l'input vuoto da' lo schema giusto", {
  membri <- data.frame(
    cluster_id = c("c1", "c1", "c2", "c2"),
    study_id   = c("A", "B", "A", "B"),
    label      = c("brain tissue", "iPSC neurons", "colon tissue", "colon biopsy"),
    stringsAsFactors = FALSE)
  out <- detect_mixed_material(membri)
  expect_equal(nrow(out), 2L)
  expect_true(out$materiale_misto[out$cluster_id == "c1"])
  expect_false(out$materiale_misto[out$cluster_id == "c2"])

  vuoto <- detect_mixed_material(
    data.frame(cluster_id = character(), study_id = character(),
               label = character(), stringsAsFactors = FALSE))
  expect_equal(nrow(vuoto), 0L)
  expect_true(all(c("cluster_id", "materiale_misto", "n_studi_model",
                    "n_studi_primary", "n_studi_unknown") %in% names(vuoto)))
})
