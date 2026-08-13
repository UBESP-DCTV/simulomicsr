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

test_that("si fondono anche due CHIAVI DI CONTROLLO che sono lo stesso controllo", {
  # Misurato il 2026-08-08 leggendo le etichette intere di 237 confronti:
  # `.normalize_control_type()` ha una lista di sinonimi che diventano
  # `vehicle_untreated` e una di controlli tenuti distinti. `mock` sta fra i
  # sinonimi, `uninfected` NON sta in nessuna delle due e ricade su se stesso:
  # e' una dimenticanza di vocabolario, non una distinzione semantica. Cosi'
  # SARS-CoV-2 finisce in due cluster (34 e 2 studi) e la dedup ne BUTTA uno.
  # `normoxia` invece e' distinta di proposito, ma la misura mostra che il
  # confine non tiene: il cluster vincente dell'ipossia pool­a gia' controlli
  # scritti `Untreated` e `Control`, e lo scartato ne ha tre che nominano la
  # normossia. Decisione utente 2026-08-08: si ribalta.
  cl <- .s4df_cl(c("vince", "assorbito"), "STR:hypoxia", "gain",
                 c("normoxia", "vehicle_untreated"), c(25L, 12L),
                 studies = list(paste0("GSE", 1:25), paste0("GSE", 20:31)))
  out <- .dedup_rem_group_by_entity(
    cl, control_canonical = c("normoxia" = "vehicle_untreated"))
  expect_equal(out$cluster_id, "vince")
  fus <- attr(out, "fusioni")
  expect_equal(nrow(fus), 1L)
  expect_equal(fus$cluster_id_assorbito, "assorbito")
  expect_equal(nrow(attr(out, "scartati")), 0L)   # fuso, non scartato
  expect_equal(out$k, 31L)                        # unione di GSE1..GSE31
})

test_that("dopo una fusione il vincente porta la chiave CANONICA, e l'originale resta scritto", {
  cl <- .s4df_cl(c("vince", "assorbito"), "STR:hypoxia", "gain",
                 c("normoxia", "vehicle_untreated"), c(25L, 12L))
  out <- .dedup_rem_group_by_entity(
    cl, control_canonical = c("normoxia" = "vehicle_untreated"))
  # il gruppo ora pool­a entrambi i controlli: l'etichetta deve dirlo
  expect_equal(out$contrast_control_key, "vehicle_untreated")
  expect_equal(attr(out, "fusioni")$control_key_vincente_prima, "normoxia")
})

test_that("dopo una fusione di scritture il vincente porta l'entita' CANONICA", {
  cl <- .s4df_cl(c("vince", "assorbito"), c("CHEMBL:265582", "HGNC:11892"),
                 "gain", "vehicle_untreated", c(30L, 5L))
  out <- .dedup_rem_group_by_entity(
    cl, entity_canonical = c("CHEMBL:265582" = "HGNC:11892"))
  expect_equal(out$cluster_id, "vince")            # vince sul k
  expect_equal(out$contrast_entity, "HGNC:11892")  # ma porta l'ID canonico
  expect_equal(attr(out, "fusioni")$entity_vincente_prima, "CHEMBL:265582")
})

test_that("senza nessuna delle due mappe le chiavi non vengono toccate", {
  cl <- .s4df_cl(c("a", "b"), "STR:hypoxia", "gain",
                 c("normoxia", "vehicle_untreated"), c(25L, 12L))
  out <- .dedup_rem_group_by_entity(cl)
  expect_equal(out$cluster_id, "a")
  expect_equal(out$contrast_control_key, "normoxia")
  expect_equal(nrow(attr(out, "fusioni")), 0L)
  expect_equal(nrow(attr(out, "scartati")), 1L)
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

# ---- LA CHIAVE DI CONTROLLO CONDIZIONATA ALL'ENTITA' (2026-08-13, D4) --------
# `uninfected` NON si puo' rendere generale. Da solo produce 10 fusioni, di cui
# due con DOPPIO CONTEGGIO (ATRA e HSV-1: gli stessi campioni contati due volte
# contro due controlli diversi dello stesso studio) e una MINESTRONE (RSV: un
# secondo studio clinico dentro un gruppo sperimentale). Per SARS-CoV-2 invece
# i 5 membri sono `infected` contro `Uninfected` dentro lo studio, stesso tipo
# cellulare, zero difetti. La decisione utente e' fondere quello e nessun altro:
# serve poter dire «questa equivalenza vale SOLO per questa entita'».
#
# Forma della chiave: `entita||chiave_di_controllo` per la voce condizionata,
# `chiave_di_controllo` nuda per quella generale. La condizionata vince.

test_that("una voce condizionata vale SOLO per la sua entita'", {
  cl <- rbind(
    .s4df_cl(c("sars_v", "sars_a"), "NCBITaxon:2697049", "gain",
             c("vehicle_untreated", "uninfected"), c(34L, 2L),
             studies = list(paste0("GSE", 1:34), paste0("GSE", 40:41))),
    .s4df_cl(c("rsv_v", "rsv_a"), "NCBITaxon:11250", "gain",
             c("vehicle_untreated", "uninfected"), c(5L, 3L),
             studies = list(paste0("GSE", 50:54), paste0("GSE", 60:62))))
  out <- .dedup_rem_group_by_entity(
    cl, control_canonical = c("NCBITaxon:2697049||uninfected" = "vehicle_untreated"))
  fus <- attr(out, "fusioni")
  expect_equal(nrow(fus), 1L)
  expect_equal(fus$cluster_id_assorbito, "sars_a")
  expect_equal(out$k[out$cluster_id == "sars_v"], 36L)
  # l'RSV NON si fonde: resta scartato dalla dedup di sempre (chiave diversa)
  expect_true("rsv_v" %in% out$cluster_id)
  expect_false("rsv_a" %in% out$cluster_id)
  expect_equal(out$k[out$cluster_id == "rsv_v"], 5L)
})

test_that("una voce generale continua a valere per tutte le entita'", {
  cl <- rbind(
    .s4df_cl(c("ipo_v", "ipo_a"), "STR:hypoxia", "gain",
             c("normoxia", "vehicle_untreated"), c(25L, 12L),
             studies = list(paste0("GSE", 1:25), paste0("GSE", 20:31))),
    .s4df_cl(c("alt_v", "alt_a"), "STR:altro", "gain",
             c("normoxia", "vehicle_untreated"), c(4L, 2L),
             studies = list(paste0("GSE", 70:73), paste0("GSE", 80:81))))
  out <- .dedup_rem_group_by_entity(
    cl, control_canonical = c("normoxia" = "vehicle_untreated"))
  expect_equal(nrow(attr(out, "fusioni")), 2L)
  expect_equal(sort(out$cluster_id), c("alt_v", "ipo_v"))
})

test_that("la voce condizionata vince su quella generale", {
  # generale: uninfected -> vehicle_untreated; condizionata: per QUESTA entita'
  # uninfected resta se stesso (equivalenza negata caso per caso)
  cl <- .s4df_cl(c("v", "a"), "NCBITaxon:11250", "gain",
                 c("vehicle_untreated", "uninfected"), c(5L, 3L))
  out <- .dedup_rem_group_by_entity(
    cl, control_canonical = c("uninfected" = "vehicle_untreated",
                              "NCBITaxon:11250||uninfected" = "uninfected"))
  expect_equal(nrow(attr(out, "fusioni")), 0L)
  expect_equal(out$cluster_id, "v")
})

test_that("la qualificazione usa l'entita' CANONICA, non la scrittura", {
  # se l'entita' viene rimappata da entity_canonical, la voce condizionata deve
  # essere scritta sul codice canonico: e' quello che identifica il gruppo.
  cl <- .s4df_cl(c("v", "a"), c("HGNC:11892", "CHEMBL:CHEMBL265582"), "gain",
                 c("vehicle_untreated", "uninfected"), c(32L, 6L),
                 studies = list(paste0("GSE", 1:32), paste0("GSE", 40:45)))
  out <- .dedup_rem_group_by_entity(
    cl,
    entity_canonical  = c("CHEMBL:CHEMBL265582" = "HGNC:11892"),
    control_canonical = c("HGNC:11892||uninfected" = "vehicle_untreated"))
  expect_equal(nrow(attr(out, "fusioni")), 1L)
  expect_equal(out$k, 38L)
})

# ---- LE DUE MAPPE DI PRODUZIONE (2026-08-13, D3+D4) -------------------------
# Le mappe sono una DECISIONE, non un dettaglio di implementazione: chi le
# cambia deve rompere un test. Le tre entita' respinte sono qui per nome: una
# regressione che le rimettesse dentro passerebbe altrimenti inosservata.
test_that("le mappe di produzione contengono esattamente cio' che e' stato deciso", {
  rg <- stage4_default_config()$rem_group
  expect_equal(sort(names(rg$entity_canonical)),
               sort(c("CHEMBL:CHEMBL265582", "MeSH:D015850", "CHEMBL:CHEMBL4297989",
                      "CHEMBL:CHEMBL437472", "CHEMBL:CHEMBL1852688")))
  expect_equal(unname(rg$entity_canonical[["CHEMBL:CHEMBL265582"]]), "HGNC:11892")
  # respinte con la prova: IL-10 (verso invertito), GM-CSF (differenziazione),
  # "Compound 4" (non e' la stessa molecola)
  for (x in c("CHEMBL:CHEMBL4297771", "CHEMBL:CHEMBL2107881", "CHEBI:220491"))
    expect_false(x %in% names(rg$entity_canonical))
  # i controlli: due voci, ENTRAMBE condizionate all'entita'
  expect_equal(sort(names(rg$control_canonical)),
               sort(c("STR:hypoxia||normoxia", "NCBITaxon:2697049||uninfected")))
  expect_false("uninfected" %in% names(rg$control_canonical))
  expect_false("normoxia" %in% names(rg$control_canonical))
})

test_that("`normoxia` generale porterebbe dentro una fusione a guadagno zero", {
  # cgroup_L5_06b5da4a (STR:atra, chiave `normoxia`, k=1) ha un solo studio,
  # GSE202458, che e' GIA' nel gruppo ATRA vincente: fondere non aggiunge studi
  # e mette gli stessi campioni trattati contro due controlli diversi.
  cl <- rbind(
    .s4df_cl(c("ipo_v", "ipo_a"), "STR:hypoxia", "gain",
             c("normoxia", "vehicle_untreated"), c(37L, 14L),
             studies = list(paste0("GSE", 1:37), paste0("GSE", 30:43))),
    .s4df_cl(c("atra_v", "atra_a"), "STR:atra", "gain",
             c("vehicle_untreated", "normoxia"), c(9L, 1L),
             studies = list(paste0("GSE", 50:58), "GSE58")))
  gen <- .dedup_rem_group_by_entity(cl, control_canonical = c("normoxia" = "vehicle_untreated"))
  expect_equal(nrow(attr(gen, "fusioni")), 2L)                 # anche ATRA
  expect_equal(gen$k[gen$cluster_id == "atra_v"], 9L)          # guadagno zero
  cond <- .dedup_rem_group_by_entity(
    cl, control_canonical = c("STR:hypoxia||normoxia" = "vehicle_untreated"))
  expect_equal(nrow(attr(cond, "fusioni")), 1L)                # solo l'ipossia
  expect_equal(attr(cond, "fusioni")$cluster_id_assorbito, "ipo_a")
  expect_equal(cond$k[cond$cluster_id == "ipo_v"], 43L)
})
