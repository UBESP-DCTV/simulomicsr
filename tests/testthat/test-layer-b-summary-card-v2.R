# test-layer-b-summary-card-v2.R --- TDD: la scheda risponde a cinque domande,
# non elenca campi tecnici.
#
# PERCHE' ESISTE. La scheda attuale (.build_summary_card, testata in
# test-layer-b-summary-card.R e test-layer-b-summary-effectiveness.R, NON
# toccata da questo file) e' un dump di campi: `safety_min: 0.06`,
# `direction_applied distribution: none: 19687`, `Anchor: contrast/gain x
# HGNC:11766`. Un biologo che apre il case study di TGF-beta1 non ci capisce
# niente, e il "Top gene" e' scelto per solo FDR (cornulina, che con la via del
# TGF-beta non c'entra). .summary_card_v2() e' la sostituzione: cinque righe
# che rispondono a cinque domande, dalla riga gia' calcolata del deliverable
# annotato -- non dal parquet grezzo.

test_that(".summary_card_v2 risponde alle cinque domande e nasconde gli id interni", {
  riga <- data.frame(
    cluster_id = "cgroup_L5_2e16719f", contrast_entity = "HGNC:11766",
    contrast_entity_label = "TGF-beta1", k_effective = 59L, k_kish = 54.5,
    I2_med = 93.5, n_sig = 7909L, quota_top1 = 0.021,
    studio_dominante = "GSE155832", materiale_misto = TRUE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(
    riga,
    bersagli_trovati = c("SMAD7 +1,41", "SERPINE1 +2,43"),
    confronti_imperfetti = list(n = 29L, tot = 145L, peso = 0.067))

  expect_match(md, "59")            # su quanti studi
  expect_match(md, "54")            # quanto pesano davvero
  expect_match(md, "SMAD7")         # cosa si trova
  expect_match(md, "6,7|6\\.7")     # quanto e' sporco
  # gli identificativi interni non stanno nel corpo, ma nel blocco provenienza
  corpo <- sub("(?s)PROVENIENZA.*", "", md, perl = TRUE)
  expect_false(grepl("cgroup_L5_", corpo))
})

test_that(".summary_card_v2 esce come UNA sola stringa markdown", {
  riga <- data.frame(
    cluster_id = "cl_x", contrast_entity = "CHEBI:1", contrast_entity_label = "X",
    k_effective = 3L, k_kish = 2.1, I2_med = 10, n_sig = 5L, quota_top1 = 0.4,
    studio_dominante = "GSE1", materiale_misto = FALSE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  expect_type(md, "character")
  expect_length(md, 1L)
})

test_that("senza etichetta leggibile il ripiego sull'id grezzo e' dichiarato, mai silenzioso", {
  riga <- data.frame(
    cluster_id = "cl_no_label", contrast_entity = "MeSH:D999999",
    contrast_entity_label = NA_character_, k_effective = 4L, k_kish = 3.0,
    I2_med = 20, n_sig = 1L, quota_top1 = 0.9, studio_dominante = "GSE9",
    materiale_misto = FALSE, coherence_verdict = "coherent",
    stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  # l'id grezzo del contrasto compare (non e' cluster_id: e' informazione, non
  # un identificativo tecnico interno) ma il ripiego e' dichiarato a parole
  expect_match(md, "MeSH:D999999")
  expect_match(md, "non disponibile|ripiego|grezzo", ignore.case = TRUE)
})

test_that("senza etichetta ne' id grezzo, la scheda lo dice invece di stampare cluster_id", {
  riga <- data.frame(
    cluster_id = "cgroup_L5_deadbeef", contrast_entity = NA_character_,
    contrast_entity_label = NA_character_, k_effective = 4L, k_kish = 3.0,
    I2_med = 20, n_sig = 1L, quota_top1 = 0.9, studio_dominante = "GSE9",
    materiale_misto = FALSE, coherence_verdict = "coherent",
    stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  corpo <- sub("(?s)PROVENIENZA.*", "", md, perl = TRUE)
  expect_false(grepl("cgroup_L5_", corpo))
  expect_match(corpo, "non disponibile")
})

test_that("un verdetto NON coerente e' segnalato in modo evidente, non taciuto", {
  riga <- data.frame(
    cluster_id = "cl_inc", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 5L, k_kish = 4.0, I2_med = 30, n_sig = 2L, quota_top1 = 0.3,
    studio_dominante = "GSE2", materiale_misto = FALSE,
    coherence_verdict = "incoherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  expect_match(md, "INCOHERENT|incoerent", ignore.case = TRUE)
})

test_that("un verdetto NA e' dichiarato non disponibile, non stampato come 'NA'", {
  riga <- data.frame(
    cluster_id = "cl_na_v", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 5L, k_kish = 4.0, I2_med = 30, n_sig = 2L, quota_top1 = 0.3,
    studio_dominante = "GSE2", materiale_misto = FALSE,
    coherence_verdict = NA_character_, stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  expect_match(md, "verdetto di coerenza non disponibile")
})

test_that("nessun bersaglio trovato e' dichiarato, non lasciato in bianco", {
  riga <- data.frame(
    cluster_id = "cl_nob", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 5L, k_kish = 4.0, I2_med = 30, n_sig = 0L, quota_top1 = 0.3,
    studio_dominante = "GSE2", materiale_misto = FALSE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga, bersagli_trovati = character(0))
  expect_match(md, "nessun bersaglio")
})

test_that("confronti_imperfetti NULL e' dichiarato 'non misurato', non omesso", {
  riga <- data.frame(
    cluster_id = "cl_nc", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 5L, k_kish = 4.0, I2_med = 30, n_sig = 2L, quota_top1 = 0.3,
    studio_dominante = "GSE2", materiale_misto = FALSE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga, confronti_imperfetti = NULL)
  expect_match(md, "non misurato")
})

test_that("uno studio che pesa piu' della meta' e' segnalato come dominante", {
  riga <- data.frame(
    cluster_id = "cl_dom", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 10L, k_kish = 1.8, I2_med = 50, n_sig = 3L, quota_top1 = 0.73,
    studio_dominante = "GSE181029", materiale_misto = FALSE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  expect_match(md, "GSE181029")
  expect_match(md, "73")
  expect_match(md, "pesa piu' della meta'|dominante", ignore.case = TRUE)
})

test_that("uno studio dominante sotto soglia NON e' segnalato come dominante", {
  riga <- data.frame(
    cluster_id = "cl_nodom", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 59L, k_kish = 54.5, I2_med = 93.5, n_sig = 7909L,
    quota_top1 = 0.021, studio_dominante = "GSE155832", materiale_misto = FALSE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  expect_false(grepl("pesa piu' della meta'", md))
})

test_that("il materiale misto e' dichiarato quando presente", {
  riga <- data.frame(
    cluster_id = "cl_mm", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 5L, k_kish = 4.0, I2_med = 30, n_sig = 2L, quota_top1 = 0.3,
    studio_dominante = "GSE2", materiale_misto = TRUE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  expect_match(md, "misto", ignore.case = TRUE)
})

test_that("run_id e sha256 finiscono in PROVENIENZA quando presenti nella riga", {
  riga <- data.frame(
    cluster_id = "cl_prov", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 5L, k_kish = 4.0, I2_med = 30, n_sig = 2L, quota_top1 = 0.3,
    studio_dominante = "GSE2", materiale_misto = FALSE,
    coherence_verdict = "coherent", run_id = "d29545c7",
    sha256 = "abc123def456", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  expect_match(md, "d29545c7")
  expect_match(md, "abc123def456")
  corpo <- sub("(?s)PROVENIENZA.*", "", md, perl = TRUE)
  expect_false(grepl("d29545c7", corpo))
  expect_false(grepl("abc123def456", corpo))
})

test_that("run_id e sha256 assenti dalla riga escono N/A, non errore ne' NA nudo", {
  riga <- data.frame(
    cluster_id = "cl_noprov", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 5L, k_kish = 4.0, I2_med = 30, n_sig = 2L, quota_top1 = 0.3,
    studio_dominante = "GSE2", materiale_misto = FALSE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  md <- simulomicsr:::.summary_card_v2(riga)
  expect_match(md, "run_id.*N/A")
  expect_match(md, "sha256.*N/A")
})

test_that("un I2 basso si legge come alta concordanza, uno alto come bassa", {
  bassa <- data.frame(
    cluster_id = "cl_i2a", contrast_entity = "HGNC:1", contrast_entity_label = "Y",
    k_effective = 5L, k_kish = 4.0, I2_med = 5, n_sig = 2L, quota_top1 = 0.3,
    studio_dominante = "GSE2", materiale_misto = FALSE,
    coherence_verdict = "coherent", stringsAsFactors = FALSE)
  alta <- bassa
  alta$I2_med <- 95
  md_bassa <- simulomicsr:::.summary_card_v2(bassa)
  md_alta  <- simulomicsr:::.summary_card_v2(alta)
  expect_match(md_bassa, "alta concordanza")
  expect_false(grepl("alta concordanza", md_alta))
})
