# La deduplica dello Stadio 4 deve poter FONDERE, non solo scartare.
#
# IL PROBLEMA (misurato il 2026-08-08). `.dedup_rem_group_by_entity()` tiene un
# solo cluster per chiave `contrast_entity || contrast_direction` e **butta gli
# altri**: i loro studi si perdono. Finche' le due scritture della stessa entita'
# hanno `contrast_entity` DIVERSO la dedup non le vede nemmeno, e nel deliverable
# convivono due righe per la stessa cosa -- il TNF come gene (`HGNC:11892`, 32
# studi poolati) e come proteina ricombinante (`CHEMBL:CHEMBL265582`, 6), stesso
# verso e stessa chiave di controllo.
#
# PERCHE' CANONICALIZZARE SENZA FONDERE PEGGIORA. Se si canonicalizza l'entita'
# e si lascia la dedup a scartare, le due righe del TNF diventano UNA da 32
# studi e i 6 dell'altra si perdono: peggio di oggi. La canonicalizzazione
# RICHIEDE la fusione, e le due cose vanno insieme o non vanno.
#
# LA REGOLA, IN DUE PASSI DISTINTI (perche' sono due decisioni diverse):
#   1. stessa entita' canonica + stesso verso + **stessa chiave di controllo**
#      -> FUSIONE: i record del perdente vengono attribuiti al vincente e
#      poolati insieme. Sono due scritture della stessa cosa, non due contrasti.
#   2. stessa entita' canonica + stesso verso + chiave di controllo DIVERSA
#      -> resta lo SCARTO di oggi. Fondere due CONTROLLI diversi e' un'altra
#      decisione, e alla data di questo test non e' stata presa.
#
# Il verso non si fonde MAI (decisione utente 2026-07-25).

.s4df_cl <- function(cluster_id, contrast_entity, contrast_direction,
                     contrast_control_key, k, studies = NULL) {
  if (is.null(studies)) {
    studies <- lapply(seq_along(cluster_id), function(i)
      paste0("GSE", cluster_id[i], "_", seq_len(k[i])))
  }
  tibble::tibble(
    cluster_id              = cluster_id,
    mode                    = "cgroup",
    level                   = 5L,
    k                       = as.integer(k),
    n_total                 = as.integer(k) * 4L,
    kind_effective_resolved = "cytokine_stim",
    agent_id_resolved       = contrast_entity,
    contrast_entity         = contrast_entity,
    contrast_direction      = contrast_direction,
    contrast_control_key    = contrast_control_key,
    studies_in_cluster      = studies
  )
}

test_that("senza mappa canonica il comportamento e' identico a prima", {
  cl <- .s4df_cl(c("a", "b"), c("HGNC:11892", "CHEMBL:265582"), "gain",
                 "vehicle_untreated", c(41L, 7L))
  out <- .dedup_rem_group_by_entity(cl)
  # entita' diverse -> chiavi diverse -> sopravvivono entrambe, come oggi
  expect_setequal(out$cluster_id, c("a", "b"))
  expect_equal(nrow(attr(out, "scartati")), 0L)
  expect_equal(nrow(attr(out, "fusioni")), 0L)
})

test_that("con la mappa canonica le due scritture dello STESSO controllo si FONDONO", {
  cl <- .s4df_cl(c("a", "b"), c("HGNC:11892", "CHEMBL:265582"), "gain",
                 "vehicle_untreated", c(41L, 7L))
  mappa <- c("CHEMBL:265582" = "HGNC:11892")
  out <- .dedup_rem_group_by_entity(cl, entity_canonical = mappa)

  expect_equal(out$cluster_id, "a")           # vince il k maggiore
  fus <- attr(out, "fusioni")
  expect_equal(nrow(fus), 1L)
  expect_equal(fus$cluster_id_assorbito, "b")
  expect_equal(fus$cluster_id_vincente, "a")
  # una FUSIONE non e' uno SCARTO: i record di "b" vanno poolati con "a", quindi
  # non deve comparire fra gli scartati (che invece si perdono).
  expect_equal(nrow(attr(out, "scartati")), 0L)
})

test_that("chiavi di controllo DIVERSE restano scartate, anche con la mappa", {
  cl <- .s4df_cl(c("a", "b"), c("STR:hypoxia", "STR:hypoxia"), "gain",
                 c("normoxia", "vehicle_untreated"), c(25L, 12L))
  out <- .dedup_rem_group_by_entity(cl, entity_canonical = c(x = "y"))
  expect_equal(out$cluster_id, "a")
  expect_equal(nrow(attr(out, "fusioni")), 0L)
  expect_equal(nrow(attr(out, "scartati")), 1L)
  expect_equal(attr(out, "scartati")$cluster_id, "b")
})

test_that("il verso non si fonde mai, nemmeno con la mappa", {
  cl <- .s4df_cl(c("a", "b"), c("HGNC:11892", "CHEMBL:265582"),
                 c("gain", "block"), "vehicle_untreated", c(41L, 7L))
  mappa <- c("CHEMBL:265582" = "HGNC:11892")
  out <- .dedup_rem_group_by_entity(cl, entity_canonical = mappa)
  expect_setequal(out$cluster_id, c("a", "b"))
  expect_equal(nrow(attr(out, "fusioni")), 0L)
})

test_that("vince il k maggiore anche quando la scrittura canonica e' la piu' piccola", {
  # il vincente deve essere scelto sul k, NON sul fatto di portare l'ID canonico
  cl <- .s4df_cl(c("piccolo", "grande"), c("HGNC:11892", "CHEMBL:265582"),
                 "gain", "vehicle_untreated", c(3L, 30L))
  mappa <- c("CHEMBL:265582" = "HGNC:11892")
  out <- .dedup_rem_group_by_entity(cl, entity_canonical = mappa)
  expect_equal(out$cluster_id, "grande")
  expect_equal(attr(out, "fusioni")$cluster_id_assorbito, "piccolo")
})

test_that("il k del vincente diventa il numero di studi DISTINTI dell'unione", {
  # Il gate del deliverable filtra su `k`. Se dopo una fusione `k` resta quello
  # del solo vincente, il gate giudica un gruppo che non esiste piu' -- ed e' il
  # motivo per cui IL6 e IL15 non si fondevano: le loro scritture piccole
  # cadevano al filtro `k >= 3` PRIMA che la dedup le vedesse. Filtrare i pezzi
  # prima di fonderli e' lo stesso errore della frammentazione, in altra forma.
  cl <- .s4df_cl(c("vince", "assorbito"), c("HGNC:5977", "CHEMBL:4297989"),
                 "gain", "vehicle_untreated", c(3L, 2L),
                 studies = list(c("GSE1", "GSE2", "GSE3"), c("GSE3", "GSE4")))
  out <- .dedup_rem_group_by_entity(cl, entity_canonical = c("CHEMBL:4297989" = "HGNC:5977"))
  expect_equal(out$cluster_id, "vince")
  # unione = GSE1..GSE4: quattro studi, NON 3+2=5 (GSE3 e' condiviso)
  expect_equal(out$k, 4L)
  expect_setequal(unlist(out$studies_in_cluster), c("GSE1", "GSE2", "GSE3", "GSE4"))
  # il k di partenza resta scritto, per l'audit
  expect_equal(attr(out, "fusioni")$k_vincente_prima, 3L)
  expect_equal(attr(out, "fusioni")$k_dopo_fusione, 4L)
})

test_that("senza fusioni il k non viene toccato", {
  cl <- .s4df_cl(c("a", "b"), c("STR:hypoxia", "STR:hypoxia"), "gain",
                 c("normoxia", "vehicle_untreated"), c(25L, 12L))
  out <- .dedup_rem_group_by_entity(cl)
  expect_equal(out$k, 25L)
})

test_that("tre scritture della stessa entita' si fondono tutte nel vincente", {
  cl <- .s4df_cl(c("a", "b", "c"),
                 c("HGNC:5977", "CHEMBL:4297989", "STR:il15"), "gain",
                 "vehicle_untreated", c(4L, 2L, 1L))
  mappa <- c("CHEMBL:4297989" = "HGNC:5977", "STR:il15" = "HGNC:5977")
  out <- .dedup_rem_group_by_entity(cl, entity_canonical = mappa)
  expect_equal(out$cluster_id, "a")
  expect_setequal(attr(out, "fusioni")$cluster_id_assorbito, c("b", "c"))
  expect_true(all(attr(out, "fusioni")$cluster_id_vincente == "a"))
})
