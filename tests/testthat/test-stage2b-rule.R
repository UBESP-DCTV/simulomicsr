# Regola deterministica dello Stadio 2b (ADR-0028, spec 2026-11-07-stadio-2b-design.md).
# Ogni segnale ha un controllo positivo (scatta) e il confronto pulito fa da
# controllo negativo (passa senza segnali).

segnali <- function(ck, ...) simulomicsr:::.s2b_segnali(ck, ...)
decidi <- function(ck, ...) simulomicsr:::stage2b_decide(ck, ...)

test_that("il confronto pulito passa senza segnali (controllo negativo)", {
  ck <- .s2b_check_pulito()
  expect_identical(segnali(ck), character())
  d <- decidi(ck)
  expect_true(d$passa)
  expect_identical(d$motivi, character())
  expect_identical(d$avvisi, character())
  expect_identical(d$differenza, "agente")
  expect_identical(d$entita_isolata, "compound K17")
})

test_that("il caso-controllo pulito passa: donatori diversi solo con avviso", {
  ck <- .s2b_check_condizione()
  d <- decidi(ck)
  expect_true(d$passa)
  expect_identical(d$differenza, "condizione")
  expect_identical(d$entita_isolata, "disease Q")
  expect_true("DONATORI_DIVERSI_CONDIZIONE" %in% d$avvisi)
  expect_true("TEMPO_NON_DETTO" %in% d$avvisi)
})

test_that("ingresso incompleto e lista non valida non passano", {
  expect_true("INGRESSO_INCOMPLETO" %in% segnali(.s2b_check_pulito(), ingresso_completo = FALSE))
  expect_false(decidi(.s2b_check_pulito(), ingresso_completo = FALSE)$passa)
  expect_identical(segnali(NULL), "LISTA_NON_VALIDA")
  expect_identical(segnali(list(agents = list())), "LISTA_NON_VALIDA")
  expect_false(decidi(NULL)$passa)
})

test_that("controllo a tempo zero: TEMPO_ZERO (decisione del PI, sempre errore)", {
  ck <- .s2b_check_pulito()
  ck$collection_time$control <- .s2b_tempo_t(list(0), "all")
  s <- segnali(ck)
  expect_true("TEMPO_ZERO" %in% s)
  expect_false(decidi(ck)$passa)
  # tempo zero in una parte del controllo
  ck$collection_time$control <- .s2b_tempo_t(list(0, 24), "some")
  expect_true("TEMPO_ZERO" %in% segnali(ck))
  # tempo zero senza ore scritte, trattato senza tempo: scatta lo stesso
  ck$collection_time$control <- .s2b_tempo_t(list(), "all")
  ck$collection_time$treated <- .s2b_tempo_t(list(), "not_stated")
  expect_true("TEMPO_ZERO" %in% segnali(ck))
})

test_that("entrambi i bracci a tempo zero: nessun TEMPO_ZERO", {
  ck <- .s2b_check_pulito()
  ck$collection_time$treated <- .s2b_tempo_t(list(0), "all")
  ck$collection_time$control <- .s2b_tempo_t(list(0), "all")
  expect_false(any(c("TEMPO_ZERO", "TEMPO_DIVERSO") %in% segnali(ck)))
})

test_that("tempi diversi: TEMPO_DIVERSO, dalle ore o dalla relazione", {
  ck <- .s2b_check_pulito()
  ck$collection_time$control <- .s2b_tempo_t(list(6))
  expect_true("TEMPO_DIVERSO" %in% segnali(ck))
  # le ore uguali scritte in due modi (1 giorno = 24 h) non scattano
  ck$collection_time$control <- .s2b_tempo_t(list(24.0))
  expect_false("TEMPO_DIVERSO" %in% segnali(ck))
  # la relazione dichiarata dal modello basta
  ck$collection_time$relation <- "partial"
  expect_true("TEMPO_DIVERSO" %in% segnali(ck))
  # trattato a tempo zero, controllo no
  ck <- .s2b_check_pulito()
  ck$collection_time$treated <- .s2b_tempo_t(list(0), "all")
  ck$collection_time$control <- .s2b_tempo_t(list(), "none")
  expect_true("TEMPO_DIVERSO" %in% segnali(ck))
})

test_that("ore come scalari o come liste di un elemento danno lo stesso esito", {
  ck1 <- .s2b_check_pulito(); ck2 <- .s2b_check_pulito()
  ck1$collection_time$control$hours <- list(6)
  ck2$collection_time$control$hours <- 6
  expect_identical(segnali(ck1), segnali(ck2))
})

test_that("tempo non detto e tempi multipli: avvisi", {
  ck <- .s2b_check_pulito()
  ck$collection_time$control <- .s2b_tempo_t(list(), "not_stated")
  expect_true("TEMPO_NON_DETTO" %in% segnali(ck))
  expect_true(decidi(ck)$passa)
  ck <- .s2b_check_pulito()
  ck$collection_time$treated <- .s2b_tempo_t(list(6, 24))
  ck$collection_time$control <- .s2b_tempo_t(list(24, 6))
  s <- segnali(ck)
  expect_true("TEMPI_MULTIPLI" %in% s)
  expect_false("TEMPO_DIVERSO" %in% s)
})

test_that("seconda perturbazione solo nel trattato: SECONDO_AGENTE", {
  ck <- .s2b_check_pulito()
  ck$agents[[3]] <- .s2b_agente_t("stressor W", kind = "physical")
  expect_true("SECONDO_AGENTE" %in% segnali(ck))
  expect_false(decidi(ck)$passa)
})

test_that("entità di combinazione: due agenti che sono entrambi l'entità passano", {
  ck <- .s2b_check_pulito()
  ck$agents[[3]] <- .s2b_agente_t("compound M2", is_proposed_entity = "yes")
  expect_false("SECONDO_AGENTE" %in% segnali(ck))
  d <- decidi(ck)
  expect_true(d$passa)
  expect_identical(d$entita_isolata, c("compound K17", "compound M2"))
})

test_that("senza entità proposta due agenti nel solo trattato scattano sempre", {
  ck <- .s2b_check_pulito()
  ck$agents[[1]]$is_proposed_entity <- "not_given"
  ck$agents[[3]] <- .s2b_agente_t("compound M2", is_proposed_entity = "not_given")
  ck$proposed_entity <- list(match = "not_given", evidence = NULL)
  expect_true("SECONDO_AGENTE" %in% segnali(ck))
})

test_that("agente del trattato non detto nel controllo: avviso", {
  ck <- .s2b_check_pulito()
  ck$agents[[3]] <- .s2b_agente_t("supplement R", in_control = "not_stated")
  s <- segnali(ck)
  expect_true("AGENTE_NON_DETTO_CONTROLLO" %in% s)
  expect_false("SECONDO_AGENTE" %in% s)
  expect_true(decidi(ck)$passa)
})

test_that("agente solo nel controllo: AGENTE_SOLO_CONTROLLO", {
  ck <- .s2b_check_pulito()
  ck$agents[[3]] <- .s2b_agente_t("compound M2", in_treated = "none", in_control = "all")
  expect_true("AGENTE_SOLO_CONTROLLO" %in% segnali(ck))
  # il veicolo solo nel controllo non conta
  ck <- .s2b_check_pulito()
  ck$agents[[2]]$in_treated <- "none"
  expect_identical(segnali(ck), character())
})

test_that("agente in una parte di un braccio: BRACCIO_MISTO", {
  ck <- .s2b_check_pulito()
  ck$agents[[1]]$in_treated <- "some"
  expect_true("BRACCIO_MISTO" %in% segnali(ck))
  ck <- .s2b_check_pulito()
  ck$agents[[3]] <- .s2b_agente_t("compound M2", in_treated = "all", in_control = "some")
  expect_true("BRACCIO_MISTO" %in% segnali(ck))
})

test_that("nessuna differenza isolata: NESSUNA_DIFFERENZA", {
  ck <- .s2b_check_pulito()
  ck$agents[[1]]$in_control <- "all"            # l'entità sta in entrambi i bracci
  expect_true("NESSUNA_DIFFERENZA" %in% segnali(ck))
  expect_false(decidi(ck)$passa)
  ck <- .s2b_check_condizione()
  ck$axes$disease_or_condition$relation <- "same"
  expect_true("NESSUNA_DIFFERENZA" %in% segnali(ck))
})

test_that("entità proposta diversa dalla differenza: ENTITA_DIVERSA; incerta: avviso", {
  ck <- .s2b_check_pulito()
  ck$proposed_entity$match <- "no"
  expect_true("ENTITA_DIVERSA" %in% segnali(ck))
  ck$proposed_entity$match <- "unclear"
  s <- segnali(ck)
  expect_true("ENTITA_INCERTA" %in% s)
  expect_true(decidi(ck)$passa)
})

test_that("entità confermata ma nessun agente marcato come entità: INCOERENZA_ENTITA (avviso)", {
  ck <- .s2b_check_pulito()
  ck$agents[[1]]$is_proposed_entity <- "no"
  expect_true("INCOERENZA_ENTITA" %in% segnali(ck))
})

test_that("condizione diversa in un confronto con un agente: CONDIZIONE_CON_AGENTE", {
  ck <- .s2b_check_pulito()
  ck$axes$disease_or_condition <- .s2b_asse_t("different", "carcinoma", "normal")
  expect_true("CONDIZIONE_CON_AGENTE" %in% segnali(ck))
  expect_false(decidi(ck)$passa)
})

test_that("condizione parziale: PARZIALE_CONDIZIONE", {
  ck <- .s2b_check_condizione()
  ck$axes$disease_or_condition$relation <- "partial"
  expect_true("PARZIALE_CONDIZIONE" %in% segnali(ck))
  expect_false(decidi(ck)$passa)
})

test_that("donatori diversi in un confronto con un agente: DIVERSO_DONATORE", {
  ck <- .s2b_check_pulito()
  ck$axes$donor <- .s2b_asse_t("different", "donor 1", "donor 2")
  expect_true("DIVERSO_DONATORE" %in% segnali(ck))
  expect_false(decidi(ck)$passa)
})

test_that("ogni asse diverso fa scattare il suo segnale e scarta il confronto", {
  codici <- c(material = "MATERIALE", cell_line = "LINEA", genotype = "GENOTIPO",
              sex = "SESSO", age_or_stage = "ETA_STADIO", anatomical_site = "SEDE",
              compartment = "COMPARTIMENTO", culture_conditions = "COLTURA",
              technique = "TECNICA")
  for (a in names(codici)) {
    ck <- .s2b_check_pulito()
    ck$axes[[a]]$relation <- "different"
    expect_true(paste0("DIVERSO_", codici[[a]]) %in% segnali(ck), info = a)
    expect_false(decidi(ck)$passa, info = a)
  }
})

test_that("asse parziale: errore per le condizioni dell'esperimento, avviso per i soggetti", {
  errore <- c(material = "MATERIALE", cell_line = "LINEA", genotype = "GENOTIPO",
              anatomical_site = "SEDE", compartment = "COMPARTIMENTO",
              culture_conditions = "COLTURA", technique = "TECNICA")
  avviso <- c(donor = "DONATORE", sex = "SESSO", age_or_stage = "ETA_STADIO")
  for (a in names(errore)) {
    ck <- .s2b_check_pulito(); ck$axes[[a]]$relation <- "partial"
    expect_true(paste0("PARZIALE_", errore[[a]]) %in% segnali(ck), info = a)
    expect_false(decidi(ck)$passa, info = a)
  }
  for (a in names(avviso)) {
    ck <- .s2b_check_pulito(); ck$axes[[a]]$relation <- "partial"
    expect_true(paste0("PARZIALE_", avviso[[a]]) %in% segnali(ck), info = a)
    expect_true(decidi(ck)$passa, info = a)
  }
})

test_that("asse non detto: avviso, il confronto passa (ADR-0028)", {
  for (a in names(.s2b_check_pulito()$axes)) {
    ck <- .s2b_check_pulito(); ck$axes[[a]]$relation <- "not_stated"
    d <- decidi(ck)
    expect_true(d$passa, info = a)
    expect_length(d$avvisi, 1L)
    expect_match(d$avvisi, "^NON_DETTO_", info = a)
  }
})

test_that("altra differenza sistematica: ALTRA_DIFFERENZA", {
  ck <- .s2b_check_pulito()
  ck$other_differences <- list(list(description = "harvest protocol",
                                    evidence_treated = "a", evidence_control = "b"))
  expect_true("ALTRA_DIFFERENZA" %in% segnali(ck))
  expect_false(decidi(ck)$passa)
})

test_that("tecnica dai campi strutturati dell'H5: disgiunta e parziale", {
  ck <- .s2b_check_pulito()
  t_df <- data.frame(instrument_model = c("Seq A", "Seq A"), molecule_ch1 = c("total RNA", "total RNA"))
  c_same <- t_df
  c_disg <- data.frame(instrument_model = c("Seq B", "Seq B"), molecule_ch1 = c("total RNA", "total RNA"))
  c_parz <- data.frame(instrument_model = c("Seq A", "Seq B"), molecule_ch1 = c("total RNA", "total RNA"))
  th <- simulomicsr:::.s2b_tecnica_h5
  expect_identical(th(t_df, c_same), c(instrument_model = "uguale", molecule_ch1 = "uguale"))
  expect_identical(th(t_df, c_disg)[["instrument_model"]], "disgiunta")
  expect_identical(th(t_df, c_parz)[["instrument_model"]], "parziale")
  expect_true("TECNICA_H5_DISGIUNTA" %in% segnali(ck, tecnica_h5 = th(t_df, c_disg)))
  expect_true("TECNICA_H5_PARZIALE" %in% segnali(ck, tecnica_h5 = th(t_df, c_parz)))
  expect_identical(segnali(ck, tecnica_h5 = th(t_df, c_same)), character())
  # valori vuoti non contano come valori
  c_vuoto <- data.frame(instrument_model = c("", ""), molecule_ch1 = c("total RNA", "total RNA"))
  expect_identical(th(t_df, c_vuoto)[["instrument_model"]], "vuota")
  expect_false(decidi(ck, tecnica_h5 = th(t_df, c_disg))$passa)
})

test_that("ogni segnale prodotto dalla regola ha un esito nella tabella", {
  tab <- simulomicsr:::stage2b_esiti_default()
  expect_true(all(tab %in% c("errore", "avviso")))
  expect_true(all(simulomicsr:::.s2b_tutti_i_segnali() %in% names(tab)))
  expect_true(all(names(tab) %in% simulomicsr:::.s2b_tutti_i_segnali()))
})

test_that("un segnale senza esito nella tabella ferma la regola", {
  tab <- simulomicsr:::stage2b_esiti_default()
  tab <- tab[names(tab) != "TEMPO_ZERO"]
  ck <- .s2b_check_pulito()
  ck$collection_time$control <- .s2b_tempo_t(list(0), "all")
  expect_error(decidi(ck, esiti = tab), class = "simulomicsr_stage2b_esito_mancante")
})

test_that("i valori fuori dallo schema fermano la regola", {
  ck <- .s2b_check_pulito()
  ck$axes$sex$relation <- "similar"
  expect_identical(segnali(ck), "LISTA_NON_VALIDA")
})
