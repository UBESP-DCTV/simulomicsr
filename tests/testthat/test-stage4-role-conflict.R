# Un campione non puo' essere trattato E controllo dello stesso confronto.
#
# IL PROBLEMA (misurato il 2026-08-09 su tutti i 2.152 confronti che entrano nel
# pooling del deliverable v15). L'orchestratore costruisce il vettore dei ruoli
# per POSIZIONE:
#     samples   <- c(d$treated, d$control)
#     treatment <- factor(c(rep("treated", ...), rep("control", ...)))
# Se un campione compare in ENTRAMBE le liste, entra due volte -- una per lato --
# e lo stesso profilo di espressione finisce su tutti e due i bracci del
# contrasto. La stima viene tirata verso zero e i gradi di liberta' contano
# repliche che non esistono.
#
# IL CASO REALE, uno su 2.152: `GSE158765` dentro la meta-analisi dell'acido
# acetilsalicilico (`cgroup_L5_ff78d2a8`, k_effective 3, marcata *coerente*).
# 94 trattati, 61 controlli, **59 dei controlli sono anche trattati**: il 97% del
# braccio di riferimento. I metadati dicono perche': e' uno studio longitudinale
# ENTRO SOGGETTO (`subject_id`, `visit_number`, "81 mg Aspirin"), dove lo stesso
# soggetto sta prima e dopo, e i due bracci si sovrappongono.
#
# PERCHE' NON SI COPIA DAL RAMO `mega`. Una guardia equivalente esiste in
# `.build_mega_metadata_safe()`, ma quel ramo e' FUORI dal deliverable (ADR-0026)
# e non e' piu' sviluppato: prenderlo a modello legherebbe il ramo vivo a codice
# fermo. Questa guardia sta nel punto dell'orchestratore che i TRE rami per-studio
# (`rem`, `mega_aug`, `rem_group`) attraversano tutti, e vale per tutti.
#
# LA REGOLA, e perche' questa e non un'altra:
#   - il campione in conflitto si toglie da ENTRAMBI i bracci. Assegnarlo a uno
#     dei due sarebbe scegliere un ruolo arbitrario su un dato che ne dichiara
#     due; e tenerlo com'e' e' il difetto che si sta chiudendo.
#   - se dopo lo scarto un braccio scende sotto `n_min`, il confronto NON entra:
#     un contrasto che sopravvive solo grazie ai campioni ambigui non e' un
#     contrasto.
#   - lo scarto e' SEMPRE registrato. Una selezione silenziosa non e' auditabile,
#     e questa toglie campioni da una stima pubblicata.

test_that("senza conflitti i due bracci restano identici", {
  r <- .drop_role_conflicts(c("A", "B", "C"), c("D", "E"), n_min = 2L)
  expect_equal(r$treated, c("A", "B", "C"))
  expect_equal(r$control, c("D", "E"))
  expect_length(r$dropped, 0L)
  expect_true(r$usable)
})

test_that("il campione ambiguo esce da entrambi i bracci, non da uno solo", {
  r <- .drop_role_conflicts(c("A", "B", "X"), c("X", "C", "D"), n_min = 2L)
  expect_equal(r$treated, c("A", "B"))
  expect_equal(r$control, c("C", "D"))
  expect_equal(r$dropped, "X")
  expect_true(r$usable)
})

test_that("piu' campioni ambigui escono tutti, in ordine stabile", {
  r <- .drop_role_conflicts(c("A", "X", "Y"), c("Y", "X", "B", "C"), n_min = 2L)
  expect_equal(r$treated, "A")
  expect_equal(r$control, c("B", "C"))
  expect_equal(r$dropped, c("X", "Y"))
  expect_false(r$usable)   # il braccio trattato scende a 1 < n_min
})

test_that("il confronto non e' utilizzabile se un braccio scende sotto n_min", {
  r <- .drop_role_conflicts(c("A", "X"), c("X", "B", "C"), n_min = 2L)
  expect_equal(r$treated, "A")
  expect_false(r$usable)
})

test_that("un confronto interamente sovrapposto non e' utilizzabile", {
  r <- .drop_role_conflicts(c("A", "B"), c("A", "B"), n_min = 2L)
  expect_length(r$treated, 0L)
  expect_length(r$control, 0L)
  expect_equal(r$dropped, c("A", "B"))
  expect_false(r$usable)
})

test_that("il caso reale dell'aspirina: 59 campioni su 61 controlli sono anche trattati", {
  treated <- paste0("GSM", 1:94)
  control <- c(paste0("GSM", 36:94), "GSMx", "GSMy")   # 59 condivisi + 2 propri
  r <- .drop_role_conflicts(treated, control, n_min = 2L)
  expect_length(r$dropped, 59L)
  expect_equal(r$treated, paste0("GSM", 1:35))
  expect_equal(r$control, c("GSMx", "GSMy"))
  # sopravvive, ma con 2 controlli invece di 61: il fatto va registrato
  expect_true(r$usable)
})

test_that("n_min piu' alto rende inutilizzabile lo stesso confronto", {
  treated <- paste0("GSM", 1:94)
  control <- c(paste0("GSM", 36:94), "GSMx", "GSMy")
  expect_false(.drop_role_conflicts(treated, control, n_min = 3L)$usable)
})

test_that("i duplicati dentro lo stesso braccio non sono un conflitto di ruolo", {
  # lo stesso campione ripetuto nella stessa lista non e' ambiguo sul ruolo:
  # va deduplicato, non scartato.
  r <- .drop_role_conflicts(c("A", "A", "B"), c("C", "D"), n_min = 2L)
  expect_equal(r$treated, c("A", "B"))
  expect_length(r$dropped, 0L)
  expect_true(r$usable)
})

test_that("bracci vuoti non fanno esplodere la guardia", {
  r <- .drop_role_conflicts(character(0), c("A", "B"), n_min = 2L)
  expect_length(r$treated, 0L)
  expect_false(r$usable)
  expect_length(r$dropped, 0L)
})

test_that("il registro dello scarto dice cluster, studio e quanti campioni", {
  r <- .drop_role_conflicts(c("A", "X"), c("X", "B", "C"), n_min = 2L,
                            cluster_id = "cgroup_L5_test", study_id = "GSE1")
  expect_equal(nrow(r$log), 1L)
  expect_equal(r$log$cluster_id, "cgroup_L5_test")
  expect_equal(r$log$study_id, "GSE1")
  expect_equal(r$log$n_dropped, 1L)
  expect_equal(r$log$reason, "role_conflict_treated_and_control")
  expect_false(r$log$usable)
})

test_that("senza conflitti il registro e' vuoto ma ha lo schema giusto", {
  r <- .drop_role_conflicts(c("A", "B"), c("C", "D"), n_min = 2L,
                            cluster_id = "c1", study_id = "GSE1")
  expect_equal(nrow(r$log), 0L)
  expect_equal(names(r$log),
               c("cluster_id", "study_id", "n_treated_before", "n_control_before",
                 "n_dropped", "dropped_samples", "usable", "reason"))
})
