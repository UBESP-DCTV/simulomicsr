# Aiutanti dei test dello Stadio 2b (ADR-0028). Le liste di controllo sono
# sintetiche: nomi inventati («composto K17», «linea ZX-4»), nessun esempio
# preso dai confronti del deliverable.

.s2b_asse_t <- function(rel = "same", t = "x", c = "x") {
  list(relation = rel, treated = t, control = c,
       evidence_treated = t, evidence_control = c)
}

.s2b_agente_t <- function(name, kind = "chemical", in_treated = "all",
                          in_control = "none", is_proposed_entity = "no") {
  list(name = name, kind = kind, in_treated = in_treated,
       in_control = in_control, is_proposed_entity = is_proposed_entity,
       evidence = name)
}

.s2b_tempo_t <- function(hours = list(24), time_zero = "none") {
  list(value_raw = if (length(hours)) paste(unlist(hours), "h") else NULL,
       hours = hours, time_zero = time_zero, evidence = NULL)
}

# Il confronto pulito: composto K17 contro veicolo, stessa linea, stesso tempo.
.s2b_check_pulito <- function() {
  list(
    agents = list(
      .s2b_agente_t("compound K17", is_proposed_entity = "yes"),
      .s2b_agente_t("vehicle", kind = "vehicle_or_mock",
                    in_treated = "not_stated", in_control = "all")
    ),
    collection_time = list(treated = .s2b_tempo_t(), control = .s2b_tempo_t(),
                           relation = "same"),
    axes = list(
      material = .s2b_asse_t(t = "cell line", c = "cell line"),
      cell_line = .s2b_asse_t(t = "ZX-4", c = "ZX-4"),
      donor = .s2b_asse_t("not_applicable", NULL, NULL),
      genotype = .s2b_asse_t(t = "wild type", c = "wild type"),
      sex = .s2b_asse_t(t = "female", c = "female"),
      age_or_stage = .s2b_asse_t("not_applicable", NULL, NULL),
      anatomical_site = .s2b_asse_t(t = "lung", c = "lung"),
      compartment = .s2b_asse_t(t = "whole cell", c = "whole cell"),
      disease_or_condition = .s2b_asse_t(t = "carcinoma", c = "carcinoma"),
      culture_conditions = .s2b_asse_t(t = "RPMI 10% FBS", c = "RPMI 10% FBS"),
      technique = .s2b_asse_t(t = "paired-end", c = "paired-end")
    ),
    other_differences = list(),
    proposed_entity = list(match = "yes", evidence = "compound K17"),
    isolated_difference = list(name = "compound K17", kind = "agent")
  )
}

# Il confronto caso-controllo pulito: malattia Q contro sani, donatori diversi.
.s2b_check_condizione <- function() {
  ck <- .s2b_check_pulito()
  ck$agents <- list()
  ck$collection_time <- list(treated = .s2b_tempo_t(list(), "not_stated"),
                             control = .s2b_tempo_t(list(), "not_stated"),
                             relation = "not_stated")
  ck$axes$material <- .s2b_asse_t(t = "tissue", c = "tissue")
  ck$axes$cell_line <- .s2b_asse_t("not_applicable", NULL, NULL)
  ck$axes$donor <- .s2b_asse_t("different", "patients", "healthy donors")
  ck$axes$disease_or_condition <- .s2b_asse_t("different", "disease Q", "healthy")
  ck$axes$culture_conditions <- .s2b_asse_t("not_applicable", NULL, NULL)
  ck$proposed_entity <- list(match = "yes", evidence = "disease Q")
  ck$isolated_difference <- list(name = "disease Q", kind = "disease_or_condition")
  ck
}
