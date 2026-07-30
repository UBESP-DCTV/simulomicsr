# test-stage4-pooling-effectiveness.R --- TDD per R/stage4-pooling-effectiveness.R
#
# PERCHE' ESISTE. Il deliverable riporta `k_effective` — quanti studi entrano in
# una meta-analisi. Non dice quanto quegli studi CONTANO. In un random-effects il
# peso e' 1/(SE^2 + tau^2): uno studio grande puo' portare il 98% del peso e gli
# altri due essere comparse. Misurato sui 191 gruppi di v13: 105 (55%) hanno uno
# studio sopra il 50%, e 66 (35%) valgono meno di due studi efficaci — tutti
# marcati "coerenti", perche' coerenza e dominanza sono assi indipendenti.
#
# Il numero efficace di studi e' quello di Kish: (sum w)^2 / sum w^2. Vale k se
# i pesi sono uguali, tende a 1 se uno domina.
#
# LA COSA CHE QUESTI TEST DIFENDONO: l'UNITA' di misura. `per_study_de` ha una
# riga per BRACCIO, non per studio (TGF-beta1: 83 bracci, 49 studi), e il REM
# gira sugli studi DOPO il collasso inverse-variance dei bracci. Pesare i bracci
# da' un numero diverso e sbagliato — errore commesso davvero il 2026-07-31 e
# corretto misurando. Se il collasso sparisce, questi test devono fallire.

test_that(".collapse_arm_se_by_study combina i bracci con inverso della varianza", {
  # Due bracci dello stesso studio con SE 0.3 e 0.4 -> 1/SE^2 sommati.
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = "g1",
    study_id = c("GSE1", "GSE1", "GSE2"),
    SE = c(0.3, 0.4, 0.5),
    stringsAsFactors = FALSE
  )
  out <- .collapse_arm_se_by_study(per_arm)

  expect_equal(nrow(out), 2L)
  atteso <- sqrt(1 / (1 / 0.3^2 + 1 / 0.4^2))
  expect_equal(out$SE_study[out$study_id == "GSE1"], atteso, tolerance = 1e-12)
  # lo studio a braccio singolo non deve cambiare
  expect_equal(out$SE_study[out$study_id == "GSE2"], 0.5, tolerance = 1e-12)
  # il collasso RIDUCE l'errore standard: due bracci informano piu' di uno
  expect_lt(out$SE_study[out$study_id == "GSE1"], 0.3)
})

test_that(".collapse_arm_se_by_study scarta SE non utilizzabili senza fallire", {
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = "g1",
    study_id = c("GSE1", "GSE1", "GSE2", "GSE3"),
    SE = c(0.3, NA_real_, 0, -1),
    stringsAsFactors = FALSE
  )
  out <- .collapse_arm_se_by_study(per_arm)
  # GSE1 resta col solo braccio valido; GSE2 (SE=0) e GSE3 (SE<0) spariscono
  expect_equal(sort(out$study_id), "GSE1")
  expect_equal(out$SE_study, 0.3, tolerance = 1e-12)
})

test_that("il numero di Kish vale k quando i pesi sono uguali", {
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = "g1",
    study_id = c("A", "B", "C", "D"),
    SE = rep(0.2, 4),
    stringsAsFactors = FALSE
  )
  tau2 <- data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 0.01,
                     stringsAsFactors = FALSE)
  out <- compute_pooling_effectiveness(per_arm, tau2)

  expect_equal(out$k_kish, 4, tolerance = 1e-10)
  expect_equal(out$k_studies, 4L)
  expect_equal(out$quota_top1, 0.25, tolerance = 1e-10)
  expect_equal(out$frazione_efficace, 1, tolerance = 1e-10)
  expect_false(out$dominato)
})

test_that("il numero di Kish tende a 1 quando uno studio domina", {
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = "g1",
    study_id = c("grande", "piccolo1", "piccolo2"),
    SE = c(0.01, 1.5, 1.5),
    stringsAsFactors = FALSE
  )
  tau2 <- data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 0,
                     stringsAsFactors = FALSE)
  out <- compute_pooling_effectiveness(per_arm, tau2)

  expect_equal(out$k_studies, 3L)
  expect_lt(out$k_kish, 1.1)
  expect_gt(out$quota_top1, 0.99)
  expect_true(out$dominato)
})

test_that("tau^2 grande RIEQUILIBRA i pesi: e' cio' che fa un random-effects", {
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = "g1",
    study_id = c("grande", "piccolo1", "piccolo2"),
    SE = c(0.01, 1.5, 1.5),
    stringsAsFactors = FALSE
  )
  senza <- compute_pooling_effectiveness(
    per_arm, data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 0))
  con <- compute_pooling_effectiveness(
    per_arm, data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 100))

  expect_gt(con$k_kish, senza$k_kish)
  expect_lt(con$quota_top1, senza$quota_top1)
})

test_that("i BRACCI vengono collassati per studio prima di pesare", {
  # Uno studio con 10 bracci non deve valere 10 studi. Questa e' l'unita' che
  # sbagliai il 2026-07-31: senza collasso k_studies sarebbe 11.
  per_arm <- rbind(
    data.frame(cluster_id = "c1", gene_id = "g1",
               study_id = rep("molti_bracci", 10), SE = rep(0.5, 10),
               stringsAsFactors = FALSE),
    data.frame(cluster_id = "c1", gene_id = "g1",
               study_id = "un_braccio", SE = 0.5, stringsAsFactors = FALSE)
  )
  out <- compute_pooling_effectiveness(
    per_arm, data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 0))

  expect_equal(out$k_studies, 2L)
  expect_lte(out$k_kish, 2)
})

test_that("aggrega su piu' geni con la MEDIANA e tiene i cluster separati", {
  per_arm <- rbind(
    data.frame(cluster_id = "c1", gene_id = c("g1", "g1", "g2", "g2"),
               study_id = c("A", "B", "A", "B"), SE = c(0.2, 0.2, 0.01, 1.5),
               stringsAsFactors = FALSE),
    data.frame(cluster_id = "c2", gene_id = "g1",
               study_id = c("A", "B", "C"), SE = rep(0.2, 3),
               stringsAsFactors = FALSE)
  )
  tau2 <- data.frame(
    cluster_id = c("c1", "c1", "c2"), gene_id = c("g1", "g2", "g1"),
    tau2 = 0, stringsAsFactors = FALSE)
  out <- compute_pooling_effectiveness(per_arm, tau2)

  expect_equal(nrow(out), 2L)
  expect_setequal(out$cluster_id, c("c1", "c2"))
  expect_equal(out$k_kish[out$cluster_id == "c2"], 3, tolerance = 1e-10)
  # c1: un gene equilibrato (kish 2) e uno dominato (kish ~1) -> mediana 1.5
  expect_equal(out$k_kish[out$cluster_id == "c1"], 1.5, tolerance = 0.05)
})

test_that("un gene senza tau^2 non entra nel conto invece di propagare NA", {
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = c("g1", "g1", "g2", "g2"),
    study_id = c("A", "B", "A", "B"), SE = rep(0.2, 4),
    stringsAsFactors = FALSE)
  tau2 <- data.frame(cluster_id = "c1", gene_id = c("g1", "g2"),
                     tau2 = c(0, NA_real_), stringsAsFactors = FALSE)
  out <- compute_pooling_effectiveness(per_arm, tau2)

  expect_equal(nrow(out), 1L)
  expect_equal(out$n_geni, 1L)
  expect_false(is.na(out$k_kish))
})

test_that("un gene presente nei pesi ma non in tau^2 viene ESCLUSO, non assunto zero", {
  # Assumere tau^2=0 per un gene che non ce l'ha gonfierebbe la dominanza:
  # e' l'errore comodo, quello che spinge verso la conclusione che piace.
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = c("g1", "g1", "orfano", "orfano"),
    study_id = c("A", "B", "A", "B"), SE = c(0.2, 0.2, 0.01, 1.5),
    stringsAsFactors = FALSE)
  tau2 <- data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 0,
                     stringsAsFactors = FALSE)
  out <- compute_pooling_effectiveness(per_arm, tau2)

  expect_equal(out$n_geni, 1L)
  expect_equal(out$k_kish, 2, tolerance = 1e-10)
})

test_that("un cluster con un solo studio e' dominato per definizione", {
  per_arm <- data.frame(cluster_id = "c1", gene_id = "g1", study_id = "A",
                        SE = 0.2, stringsAsFactors = FALSE)
  out <- compute_pooling_effectiveness(
    per_arm, data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 0))

  expect_equal(out$k_studies, 1L)
  expect_equal(out$k_kish, 1, tolerance = 1e-10)
  expect_equal(out$quota_top1, 1, tolerance = 1e-10)
  expect_true(out$dominato)
})

test_that("input vuoto restituisce lo schema giusto, non un errore", {
  vuoto <- data.frame(cluster_id = character(), gene_id = character(),
                      study_id = character(), SE = numeric(),
                      stringsAsFactors = FALSE)
  out <- compute_pooling_effectiveness(
    vuoto, data.frame(cluster_id = character(), gene_id = character(),
                      tau2 = numeric()))

  expect_equal(nrow(out), 0L)
  expect_true(all(c("cluster_id", "k_studies", "k_kish", "quota_top1",
                    "frazione_efficace", "dominato", "n_geni") %in% names(out)))
})

test_that("riporta QUALE studio domina, non solo quanto", {
  # Serve per la domanda che il Layer B ha reso urgente: lo studio che porta il
  # peso e' un modello in vitro in un gruppo di pazienti? Senza il nome dello
  # studio quella domanda non si puo' nemmeno porre.
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = c("g1", "g1", "g1"),
    study_id = c("GSE_grande", "GSE_p1", "GSE_p2"),
    SE = c(0.01, 1.5, 1.5), stringsAsFactors = FALSE)
  out <- compute_pooling_effectiveness(
    per_arm, data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 0))

  expect_equal(out$studio_dominante, "GSE_grande")
})

test_that("lo studio dominante e' quello con la quota MEDIANA piu' alta sui geni", {
  # Non quello che vince su un gene solo: su g1 domina A, su g2 e g3 domina B.
  per_arm <- rbind(
    data.frame(cluster_id = "c1", gene_id = "g1", study_id = c("A", "B"),
               SE = c(0.01, 1.0), stringsAsFactors = FALSE),
    data.frame(cluster_id = "c1", gene_id = "g2", study_id = c("A", "B"),
               SE = c(1.0, 0.01), stringsAsFactors = FALSE),
    data.frame(cluster_id = "c1", gene_id = "g3", study_id = c("A", "B"),
               SE = c(1.0, 0.01), stringsAsFactors = FALSE)
  )
  tau2 <- data.frame(cluster_id = "c1", gene_id = c("g1", "g2", "g3"), tau2 = 0,
                     stringsAsFactors = FALSE)
  expect_equal(compute_pooling_effectiveness(per_arm, tau2)$studio_dominante, "B")
})

test_that("la soglia di dominanza e' un parametro, non un numero nascosto", {
  per_arm <- data.frame(
    cluster_id = "c1", gene_id = "g1", study_id = c("A", "B"),
    SE = c(0.1, 0.2), stringsAsFactors = FALSE)
  tau2 <- data.frame(cluster_id = "c1", gene_id = "g1", tau2 = 0,
                     stringsAsFactors = FALSE)
  # quota_top1 = (1/0.01)/(1/0.01+1/0.04) = 0.8
  expect_true(compute_pooling_effectiveness(per_arm, tau2, soglia_dominanza = 0.5)$dominato)
  expect_false(compute_pooling_effectiveness(per_arm, tau2, soglia_dominanza = 0.9)$dominato)
})
