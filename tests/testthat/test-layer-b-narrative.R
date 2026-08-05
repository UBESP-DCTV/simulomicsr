# test-layer-b-narrative.R --- TDD: la narrativa in bozza compone frasi solo
# dai numeri che riceve.
#
# PERCHE' ESISTE. Ogni case study Layer B ha oggi tre sezioni ("Biological
# context", "Findings", "Discussion") che sono stub vuoti (vedi
# .write_narrative_template() in R/layer-b-summary-card.R): nessuna figura,
# per quanto curata, compensa un documento che non dice cosa significa quello
# che mostra. .narrativa_bozza() produce un TESTO, non un'altra tabella --
# ma un testo composto SOLO dai valori ricevuti come argomenti: nessuna
# tabella interna di conoscenza biologica, nessuna affermazione sulla
# letteratura non verificabile nel deliverable, nessuna deduzione di
# meccanismo. Le attese di letteratura arrivano da `bersagli_attesi`, un
# argomento del chiamante -- non un dizionario dentro questa funzione. Il
# testo e' marcato BOZZA in modo visibile: e' testo scientifico che l'utente
# dovra' leggere e firmare.

test_that(".narrativa_bozza e' marcata come bozza e cita solo numeri passati", {
  riga <- data.frame(contrast_entity_label = "TGF-beta1", k_effective = 59L,
                     k_kish = 54.5, I2_med = 93.5, n_sig = 7909L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(
    riga,
    bersagli_attesi = c("SERPINE1", "SMAD7"),
    trovati = data.frame(gene = c("SERPINE1", "SMAD7"), logFC = c(2.43, 1.41),
                         stringsAsFactors = FALSE),
    imperfetti = list(n = 29L, tot = 145L, peso = 0.067))
  expect_match(txt, "BOZZA")
  expect_match(txt, "SERPINE1")
  expect_match(txt, "2,43|2\\.43")
  expect_match(txt, "29")
})

test_that(".narrativa_bozza esce come UNA sola stringa markdown con tre paragrafi", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 3L,
                     k_kish = 2.1, I2_med = 10, n_sig = 5L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_type(txt, "character")
  expect_length(txt, 1L)
  expect_match(txt, "Contesto")
  expect_match(txt, "Cosa si vede")
  expect_match(txt, "Limiti di questo gruppo")
})

test_that("l'intestazione di bozza compare per prima, riconoscibile a colpo d'occhio", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 3L,
                     k_kish = 2.1, I2_med = 10, n_sig = 5L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_match(txt, "^> BOZZA")
})

test_that("senza etichetta leggibile il ripiego sull'id grezzo del contrasto e' dichiarato", {
  riga <- data.frame(contrast_entity_label = NA_character_,
                     contrast_entity = "HGNC:11766", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_match(txt, "HGNC:11766")
  expect_match(txt, "non disponibile|ripiego|grezzo", ignore.case = TRUE)
})

test_that("senza etichetta ne' id grezzo, la narrativa lo dichiara invece di tacere", {
  riga <- data.frame(contrast_entity_label = NA_character_,
                     contrast_entity = NA_character_, k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_match(txt, "non disponibile")
})

test_that("senza bersagli_attesi la narrativa lo dichiara, non finge zero aspettative", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga, bersagli_attesi = character(0))
  expect_match(txt, "nessun bersaglio atteso|non sono stati forniti bersagli",
              ignore.case = TRUE)
})

test_that("bersagli attesi ma nessuno ritrovato: dichiarato esplicitamente", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(
    riga, bersagli_attesi = c("SMAD7", "SERPINE1"), trovati = NULL)
  expect_match(txt, "[Nn]essuno dei 2 bersagli attesi")
})

test_that("bersagli parzialmente ritrovati: il conteggio e' onesto (M su N), il paragrafo 'cosa si vede' non finge trovati inesistenti", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  trovati <- data.frame(gene = "SMAD7", logFC = 1.41, stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(
    riga, bersagli_attesi = c("SMAD7", "SERPINE1", "FSTL3"), trovati = trovati)
  expect_match(txt, "SMAD7")
  # SERPINE1 e FSTL3 compaiono nel paragrafo "Contesto" (sono comunque
  # dichiarati come attesi), ma il paragrafo "Cosa si vede" deve elencare
  # solo SMAD7 come ritrovato -- isolato dal resto del testo.
  cosa_si_vede <- sub("(?s).*\\*\\*Cosa si vede\\.\\*\\*", "", txt, perl = TRUE)
  cosa_si_vede <- sub("(?s)\\*\\*Limiti.*", "", cosa_si_vede, perl = TRUE)
  expect_false(grepl("SERPINE1", cosa_si_vede))
  expect_false(grepl("FSTL3", cosa_si_vede))
  expect_match(txt, "1 sono stati ritrovati|1.*ritrovat")
})

test_that("trovati con colonna FDR: il valore compare nel testo", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  trovati <- data.frame(gene = "SMAD7", logFC = 1.41, FDR = 1e-22,
                        stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(
    riga, bersagli_attesi = "SMAD7", trovati = trovati)
  expect_match(txt, "1.4|1,4")
  expect_match(txt, "1e-22|1\\.0?e-22", ignore.case = TRUE)
})

test_that("imperfetti = NULL e' dichiarato 'non misurato', non omesso", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga, imperfetti = NULL)
  expect_match(txt, "non misurato")
})

test_that("un verdetto di coerenza NON coerente e' segnalato, non taciuto", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     coherence_verdict = "incoherent", stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_match(txt, "INCOHERENT|incoerent", ignore.case = TRUE)
})

test_that("verdetto NA e' dichiarato non disponibile, non stampato come 'NA' nudo", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     coherence_verdict = NA_character_, stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_match(txt, "verdetto di coerenza non e' disponibile|verdetto.*non disponibile")
  expect_false(grepl("coherence_verdict: NA|verdetto: NA", txt))
})

test_that("uno studio dominante (colonna 'dominato' a monte) e' segnalato nei limiti", {
  riga <- data.frame(contrast_entity_label = "Parkinson", k_effective = 10L,
                     k_kish = 1.8, I2_med = 50, n_sig = 3L, quota_top1 = 0.73,
                     studio_dominante = "GSE181029", dominato = TRUE,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_match(txt, "GSE181029")
  expect_match(txt, "pesa piu' della meta'|dominante", ignore.case = TRUE)
})

test_that("materiale misto e' dichiarato quando la colonna e' TRUE", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     materiale_misto = TRUE, stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_match(txt, "misto", ignore.case = TRUE)
})

test_that("materiale non misto non produce nessuna frase su 'misto'", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     materiale_misto = FALSE, stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_false(grepl("misto", txt, ignore.case = TRUE))
})

# --- correzione post-review: Important 1, taglio silenzioso sulla dominanza -
# Quando ne' `dominato` ne' `quota_top1` sono disponibili, il vecchio codice
# assorbiva il ramo in `else ""`: silenzio indistinguibile da "verificato,
# nessuno studio domina". Deve essere dichiarato, come gia' fa
# .summary_card_v2() quando manca quota_top1.

test_that("dominanza non calcolabile (ne' 'dominato' ne' quota_top1): dichiarata, non taciuta", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  expect_match(txt, "peso del singolo studio.*non e' disponibile")
  expect_false(grepl("pesa piu' della meta'", txt))
})

test_that("dominanza non calcolabile ma quota_top1 nota e sotto soglia: NON dominante, nessuna frase di indisponibilita' nei limiti", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L, quota_top1 = 0.1,
                     studio_dominante = "GSE1", coherence_verdict = "coherent",
                     stringsAsFactors = FALSE)
  txt <- simulomicsr:::.narrativa_bozza(riga)
  limiti <- sub("(?s).*\\*\\*Limiti di questo gruppo\\.\\*\\*", "", txt, perl = TRUE)
  expect_false(grepl("pesa piu' della meta'", limiti))
  expect_false(grepl("non e' disponibile", limiti))
})

# --- correzione post-review: Important 2, helper condivisi con la scheda ---

test_that("il parametro soglia_dominanza e' letto davvero (ripiego, non colonna 'dominato')", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 10L,
                     k_kish = 3.0, I2_med = 50, n_sig = 3L, quota_top1 = 0.3,
                     studio_dominante = "GSE9", stringsAsFactors = FALSE)
  # 0.3 e' sotto il default (0.5): nessuna segnalazione
  txt_default <- simulomicsr:::.narrativa_bozza(riga)
  expect_false(grepl("pesa piu' della meta'", txt_default))
  # abbassando il parametro a 0.25, 0.3 diventa dominante
  txt_soglia_bassa <- simulomicsr:::.narrativa_bozza(riga, soglia_dominanza = 0.25)
  expect_match(txt_soglia_bassa, "pesa piu' della meta'")
})

test_that("il parametro soglia_dominanza ha default 0.5, come .summary_card_v2()", {
  expect_equal(formals(simulomicsr:::.narrativa_bozza)$soglia_dominanza, 0.5)
})

# --- correzione post-review: Minor, guardia su 'trovati' senza colonna gene -

test_that("'trovati' non vuoto senza colonna 'gene' e' un errore esplicito, non un crash su vapply", {
  riga <- data.frame(contrast_entity_label = "X", k_effective = 5L,
                     k_kish = 4.0, I2_med = 20, n_sig = 1L,
                     stringsAsFactors = FALSE)
  trovati_malformato <- data.frame(logFC = 1.41, stringsAsFactors = FALSE)
  expect_error(
    simulomicsr:::.narrativa_bozza(riga, bersagli_attesi = "SMAD7",
                                   trovati = trovati_malformato),
    "gene")
})

# --- correzione post-review: helper condivisi, verifica diretta -------------
# Gli helper .lb_*() sono la fonte unica delle cinque regole segnalate dal
# revisore come duplicate. Testati qui direttamente (non solo attraverso
# .narrativa_bozza()) perche' sono anche usati da .summary_card_v2().

test_that(".lb_soggetto_da_contrasto: ripiego etichetta -> id grezzo -> non_disponibile del chiamante", {
  expect_equal(simulomicsr:::.lb_soggetto_da_contrasto("Y", "HGNC:1", "N/D"), "Y")
  expect_match(simulomicsr:::.lb_soggetto_da_contrasto(NA_character_, "HGNC:1", "N/D"),
              "HGNC:1")
  expect_equal(simulomicsr:::.lb_soggetto_da_contrasto(NA_character_, NA_character_, "N/D"),
              "N/D")
})

test_that(".lb_verdetto_coerenza_txt: tre rami, template del chiamante", {
  expect_equal(
    simulomicsr:::.lb_verdetto_coerenza_txt(NA_character_, "na", "coer", "ALTRO: %s"),
    "na")
  expect_equal(
    simulomicsr:::.lb_verdetto_coerenza_txt("coherent", "na", "coer", "ALTRO: %s"),
    "coer")
  expect_equal(
    simulomicsr:::.lb_verdetto_coerenza_txt("incoherent", "na", "coer", "ALTRO: %s"),
    "ALTRO: INCOHERENT")
})

test_that(".lb_dominato_flag: la colonna vince sempre sul ricalcolo da quota_top1", {
  expect_true(simulomicsr:::.lb_dominato_flag(TRUE, 0.1))
  expect_false(simulomicsr:::.lb_dominato_flag(FALSE, 0.9))
  expect_true(simulomicsr:::.lb_dominato_flag(NA, 0.6, soglia_dominanza = 0.5))
  expect_false(simulomicsr:::.lb_dominato_flag(NA, 0.3, soglia_dominanza = 0.5))
  expect_true(is.na(simulomicsr:::.lb_dominato_flag(NA, NA_real_)))
})

test_that(".lb_confronti_imperfetti_txt e .lb_materiale_misto_txt: clausole condivise", {
  expect_equal(simulomicsr:::.lb_confronti_imperfetti_txt(NULL),
              "non misurato per questo gruppo")
  expect_match(simulomicsr:::.lb_confronti_imperfetti_txt(list(n = 1L, tot = 2L, peso = 0.5)),
              "1 confronti imperfetti su 2")
  expect_equal(simulomicsr:::.lb_materiale_misto_txt(FALSE), "")
  expect_match(simulomicsr:::.lb_materiale_misto_txt(TRUE), "misto")
})
