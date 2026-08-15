# LA FUSIONE DEVE SPOSTARE I RECORD, NON SOLO L'ETICHETTA.
#
# IL DIFETTO (misurato sul re-pool v16, 2026-08-15). `.dedup_rem_group_by_entity`
# toglie il cluster assorbito e riscrive il `k` del vincente con gli studi
# dell'unione — ma i `record_id` dell'assorbito restano attaccati a lui negli
# `assignments`, ed e' da li' che il dispatch pesca. Risultato sui dati veri: il
# TNF dichiarava k=48 e il dispatch ne risolveva 32; la riga assorbita (6 studi
# poolati) spariva dal deliverable senza che quei 6 studi entrassero nel
# vincente. Una perdita, non un guadagno.
#
# I test del meccanismo di fusione (2026-08-08) guardavano il data.frame dei
# cluster: `k` giusto, `fusioni` giusto. Nessuno guardava il DISPATCH. Questi
# test guardano il dispatch.

.fr_fusioni <- function() data.frame(
  cluster_id_assorbito = "cgroup_L5_ass", cluster_id_vincente = "cgroup_L5_vin",
  chiave = "x", k_vincente_prima = 2L, k_dopo_fusione = 4L,
  entity_vincente_prima = "HGNC:1", control_key_vincente_prima = "vehicle_untreated",
  stringsAsFactors = FALSE)

.fr_asg <- function() data.frame(
  cluster_id = c("cgroup_L5_vin", "cgroup_L5_vin", "cgroup_L5_ass", "cgroup_L5_altro"),
  record_id = c("GSE1__cmp1", "GSE2__cmp1", "GSE3__cmp1", "GSE4__cmp1"),
  stringsAsFactors = FALSE)

test_that("i record dell'assorbito passano al vincente", {
  a <- .reassign_absorbed_records(.fr_asg(), .fr_fusioni())
  expect_equal(sum(a$cluster_id == "cgroup_L5_vin"), 3L)
  expect_equal(sum(a$cluster_id == "cgroup_L5_ass"), 0L)
  expect_equal(sum(a$cluster_id == "cgroup_L5_altro"), 1L)   # gli altri non si toccano
  expect_equal(nrow(a), 4L)                                   # nessun record perso
})

test_that("senza fusioni gli assignments non vengono toccati", {
  asg <- .fr_asg()
  vuoto <- .fr_fusioni()[0, , drop = FALSE]
  expect_identical(.reassign_absorbed_records(asg, vuoto), asg)
  expect_identical(.reassign_absorbed_records(asg, NULL), asg)
})

test_that("una catena di fusioni finisce tutta sul vincente finale", {
  fus <- rbind(.fr_fusioni(),
               data.frame(cluster_id_assorbito = "cgroup_L5_ass2",
                          cluster_id_vincente = "cgroup_L5_vin",
                          chiave = "x", k_vincente_prima = 2L, k_dopo_fusione = 5L,
                          entity_vincente_prima = "HGNC:1",
                          control_key_vincente_prima = "vehicle_untreated",
                          stringsAsFactors = FALSE))
  asg <- rbind(.fr_asg(), data.frame(cluster_id = "cgroup_L5_ass2",
                                     record_id = "GSE5__cmp1", stringsAsFactors = FALSE))
  a <- .reassign_absorbed_records(asg, fus)
  expect_equal(sum(a$cluster_id == "cgroup_L5_vin"), 4L)
})

test_that("il dispatch del vincente risolve gli studi di ENTRAMBI i cluster", {
  # e' l'invariante che mancava: il `k` dichiarato dalla fusione deve essere
  # quello che il pooling realizza davvero.
  eligible <- data.frame(cluster_id = "cgroup_L5_vin", mode = "cgroup",
                         method = "rem_group", stringsAsFactors = FALSE)
  s2 <- lapply(1:3, function(i) list(
    series_id = paste0("GSE", i),
    replicate_groups = list(
      list(group_id = "g1", sample_ids = list(paste0("T", i, "a"), paste0("T", i, "b"))),
      list(group_id = "g2", sample_ids = list(paste0("C", i, "a"), paste0("C", i, "b")))),
    comparisons = list(list(comparison_id = "cmp1", treated_group = "g1",
                            control_group = "g2"))))
  asg <- data.frame(
    cluster_id = c("cgroup_L5_vin", "cgroup_L5_vin", "cgroup_L5_ass"),
    record_id = c("GSE1__cmp1", "GSE2__cmp1", "GSE3__cmp1"), stringsAsFactors = FALSE)
  prima <- .build_group_rem_dispatch_from_stage3(eligible, asg, s2, n_min = 2L)
  expect_length(prima[["cgroup_L5_vin"]], 2L)          # il difetto: solo 2 studi
  dopo <- .build_group_rem_dispatch_from_stage3(
    eligible, .reassign_absorbed_records(asg, .fr_fusioni()), s2, n_min = 2L)
  expect_length(dopo[["cgroup_L5_vin"]], 3L)           # corretto: 3
  expect_setequal(vapply(dopo[["cgroup_L5_vin"]], function(x) x$study_id, character(1)),
                  c("GSE1", "GSE2", "GSE3"))
})
