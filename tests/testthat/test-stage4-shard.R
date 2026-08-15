# SPEZZARE IL RE-POOL IN PEZZI, senza toccare il motore di calcolo.
#
# PERCHE'. Il ramo `rem_group` -- l'unico che produce il deliverable -- e' un
# ciclo `for` su un core solo: il re-pool v16 ha impiegato 32,5 h su una macchina
# da 128 core, con 31,6 h dentro i cluster. I cluster sono indipendenti fra loro,
# quindi si possono calcolare in processi separati e unire i risultati.
#
# IL VINCOLO CHE RENDE LA COSA SICURA: il sottoinsieme si applica DOPO
# l'identificazione Layer A. La dedup per entita' e le fusioni dipendono
# dall'insieme COMPLETO dei cluster (chi vince e' quello col `k` maggiore); se
# ogni pezzo ripetesse l'identificazione sul proprio sottoinsieme, i pezzi
# vedrebbero vincitori diversi e il risultato non sarebbe piu' quello del run
# intero. Questo test si intesta quel vincolo.

.sh_clusters <- function() {
  tibble::tibble(
    cluster_id = c("cgroup_L5_a", "cgroup_L5_b", "cgroup_L5_c"),
    mode = "cgroup", level = 5L, k = c(5L, 4L, 3L), n_total = c(20L, 16L, 12L),
    n_studies = c(5L, 4L, 3L), usable_rem_strict = FALSE, usable_rem_relaxed = FALSE,
    usable_mega_strict = FALSE,
    kind_effective_resolved = "cytokine_stim",
    agent_id_resolved = c("HGNC:1", "HGNC:2", "HGNC:3"),
    contrast_entity = c("HGNC:1", "HGNC:2", "HGNC:3"),
    contrast_direction = "gain", contrast_control_key = "vehicle_untreated",
    studies_in_cluster = list(paste0("GSE", 1:5), paste0("GSE", 6:9), paste0("GSE", 10:12)))
}

test_that("senza sottoinsieme il comportamento e' quello di sempre", {
  cl <- .sh_clusters()
  a <- .identify_layer_a_clusters(cl, stage4_default_config())
  b <- .apply_cluster_subset(a, NULL)
  expect_equal(b$cluster_id, a$cluster_id)
  expect_identical(attributes(b)$fusioni, attributes(a)$fusioni)
})

test_that("il sottoinsieme tiene solo i cluster chiesti e conserva gli attributi", {
  cl <- .sh_clusters()
  a <- .identify_layer_a_clusters(cl, stage4_default_config())
  b <- .apply_cluster_subset(a, c("cgroup_L5_a", "cgroup_L5_c"))
  expect_equal(sort(b$cluster_id), c("cgroup_L5_a", "cgroup_L5_c"))
  expect_false(is.null(attr(b, "fusioni")))
  expect_false(is.null(attr(b, "scartati")))
})

test_that("i pezzi ricompongono ESATTAMENTE l'insieme intero", {
  cl <- .sh_clusters()
  a <- .identify_layer_a_clusters(cl, stage4_default_config())
  p1 <- .apply_cluster_subset(a, a$cluster_id[c(TRUE, FALSE, FALSE)])
  p2 <- .apply_cluster_subset(a, a$cluster_id[c(FALSE, TRUE, FALSE)])
  p3 <- .apply_cluster_subset(a, a$cluster_id[c(FALSE, FALSE, TRUE)])
  unito <- rbind(p1, p2, p3)
  expect_equal(sort(unito$cluster_id), sort(a$cluster_id))
  expect_equal(unito$k[match(a$cluster_id, unito$cluster_id)], a$k)
})

test_that("un cluster_id inesistente nel sottoinsieme e' un errore, non un pezzo vuoto", {
  # un refuso nel nome di un pezzo produrrebbe un file di output vuoto e la
  # ricomposizione perderebbe quei cluster senza dirlo.
  cl <- .sh_clusters()
  a <- .identify_layer_a_clusters(cl, stage4_default_config())
  expect_error(.apply_cluster_subset(a, c("cgroup_L5_a", "NON_ESISTE")),
               "non sono fra i cluster ammessi")
})

test_that("il `k` di un pezzo e' quello calcolato sull'insieme COMPLETO", {
  # due scritture della stessa entita': la fusione le unisce e il vincente porta
  # k=7. Se un pezzo rifacesse l'identificazione da solo, vedrebbe k=5.
  cl <- rbind(.sh_clusters(),
              tibble::tibble(
                cluster_id = "cgroup_L5_d", mode = "cgroup", level = 5L, k = 3L,
                n_total = 12L, n_studies = 3L, usable_rem_strict = FALSE,
                usable_rem_relaxed = FALSE, usable_mega_strict = FALSE,
                kind_effective_resolved = "cytokine_stim",
                agent_id_resolved = "CHEMBL:X", contrast_entity = "CHEMBL:X",
                contrast_direction = "gain", contrast_control_key = "vehicle_untreated",
                studies_in_cluster = list(paste0("GSE", 20:22))))
  cfg <- stage4_default_config()
  cfg$rem_group$entity_canonical <- c("CHEMBL:X" = "HGNC:1")
  a <- .identify_layer_a_clusters(cl, cfg)
  k_intero <- a$k[a$cluster_id == "cgroup_L5_a"]
  expect_equal(k_intero, 8L)                       # 5 + 3 studi disgiunti
  p <- .apply_cluster_subset(a, "cgroup_L5_a")
  expect_equal(p$k, k_intero)
})

# ---- LA CACHE DELLE CONTE, CON PIU' PROCESSI ---------------------------------
# `saveRDS(counts, cache_file)` scrive DIRETTAMENTE sul file finale. Con un solo
# processo non e' un problema; con piu' pezzi in parallelo due processi possono
# vedere `file.exists() == FALSE` per la stessa chiave, calcolare, e scrivere
# contemporaneamente sullo stesso file — oppure un terzo puo' leggerlo mentre e'
# scritto a meta'. La scrittura va fatta su un file temporaneo NELLA STESSA
# directory e poi rinominata: il rename dentro lo stesso filesystem e' atomico.

test_that("la cache non lascia file a meta' se la scrittura fallisce", {
  d <- withr::local_tempdir()
  boom <- function(gse, sample_ids) stop("fetch fallito")
  expect_error(.fetch_counts_cached("GSE1", c("S1", "S2"), cache_dir = d,
                                    fetch_fn = boom), "fetch fallito")
  expect_length(list.files(d, pattern = "\\.rds$"), 0L)
})

test_that("la cache scrive con rename atomico, non direttamente sul file finale", {
  d <- withr::local_tempdir()
  m <- matrix(1:6, nrow = 3, dimnames = list(paste0("G", 1:3), c("S1", "S2")))
  res <- .fetch_counts_cached("GSE1", c("S1", "S2"), cache_dir = d,
                              fetch_fn = function(g, s) m)
  expect_equal(res, m)
  f <- list.files(d, pattern = "\\.rds$")
  expect_length(f, 1L)
  # il file finale c'e' e si rilegge; nessun temporaneo rimasto
  expect_equal(readRDS(file.path(d, f)), m)
  expect_length(list.files(d, pattern = "^\\."), 0L)
})

test_that("due scritture della stessa chiave non si corrompono a vicenda", {
  d <- withr::local_tempdir()
  m1 <- matrix(1L, nrow = 2, ncol = 2, dimnames = list(c("G1","G2"), c("S1","S2")))
  a <- .fetch_counts_cached("GSE1", c("S1","S2"), cache_dir = d, fetch_fn = function(g,s) m1)
  b <- .fetch_counts_cached("GSE1", c("S1","S2"), cache_dir = d, fetch_fn = function(g,s) m1)
  expect_equal(a, b)
  expect_length(list.files(d, pattern = "\\.rds$"), 1L)
})

# ---- RICOMPORRE I PEZZI ------------------------------------------------------
# La prima ricomposizione (un `rbind` delle due tabelle) ha dato dati IDENTICI
# ma ha perso i REGISTRI, che viaggiano come attributi: `role_conflicts`,
# `lane_collapses`, `covariate_drop_log`, `pooling_warnings`. Sono gli stessi
# registri che finiscono in `qc_report` — cioe' cio' che rende auditabile uno
# scarto. Unire i pezzi significa unire anche quelli.

.sh_shard <- function(cids, role = 0L, lane = 0L) {
  psd <- data.frame(cluster_id = rep(cids, each = 2), study_id = "GSE1",
                    gene_id = c("G1", "G2"), logFC = 1, SE = 0.1,
                    stringsAsFactors = FALSE)
  attr(psd, "role_conflicts") <- if (role > 0L)
    data.frame(cluster_id = rep(cids[1], role), study_id = "GSE1",
               stringsAsFactors = FALSE) else .empty_role_conflict_log()
  attr(psd, "lane_collapses") <- data.frame(
    libreria = character(lane), n_campioni = integer(lane),
    campioni = character(lane), stringsAsFactors = FALSE)
  structure(list(
    per_study_de = psd,
    cluster_pooled = data.frame(cluster_id = cids, gene_id = "G1",
                                logFC_pool = 1, stringsAsFactors = FALSE),
    eligible_clusters = data.frame(cluster_id = cids, method = "rem_group",
                                   stringsAsFactors = FALSE),
    qc_report = list(dispatch_drops = data.frame(cluster_id = cids, motivo = "n_min",
                                                 stringsAsFactors = FALSE),
                     role_conflicts = .empty_role_conflict_log()),
    non_processable = data.frame(cluster_id = character(0), reason = character(0),
                                 stringsAsFactors = FALSE),
    config = list(a = 1), run_metadata = list(run_id = "x")),
    class = "stage4_result")
}

test_that("la ricomposizione somma le righe di tutte le tabelle", {
  m <- merge_stage4_shards(list(.sh_shard(c("c1", "c2")), .sh_shard("c3")))
  expect_equal(nrow(m$cluster_pooled), 3L)
  expect_equal(nrow(m$per_study_de), 6L)
  expect_equal(sort(m$eligible_clusters$cluster_id), c("c1", "c2", "c3"))
})

test_that("la ricomposizione somma anche i REGISTRI, non solo le righe", {
  m <- merge_stage4_shards(list(.sh_shard("c1", role = 2L), .sh_shard("c2", role = 3L)))
  expect_equal(nrow(m$qc_report$dispatch_drops), 2L)
  expect_equal(nrow(attr(m$per_study_de, "role_conflicts")), 5L)
  expect_false(is.null(attr(m$per_study_de, "lane_collapses")))
})

test_that("pezzi che si sovrappongono sono un errore, non una somma silenziosa", {
  # due pezzi che calcolano lo stesso cluster raddoppierebbero le sue righe nel
  # deliverable senza che nulla lo dica.
  expect_error(merge_stage4_shards(list(.sh_shard(c("c1", "c2")), .sh_shard("c2"))),
               "in piu' di un pezzo")
})

test_that("pezzi con configurazione diversa sono un errore", {
  a <- .sh_shard("c1"); b <- .sh_shard("c2"); b$config <- list(a = 2)
  expect_error(merge_stage4_shards(list(a, b)), "configurazione")
})

test_that("un solo pezzo torna se stesso, registri compresi", {
  a <- .sh_shard(c("c1", "c2"), role = 1L)
  m <- merge_stage4_shards(list(a))
  expect_equal(nrow(m$per_study_de), nrow(a$per_study_de))
  expect_equal(nrow(attr(m$per_study_de, "role_conflicts")), 1L)
})

# ---- IL REGISTRO DELLE COVARIATE SI PERDEVA PER STRADA -----------------------
# Trovato dal test di equivalenza sui dati veri: il run seriale riportava 2
# righe (un cluster), i pezzi 4 (due cluster). Non era una divergenza fra i due
# modi: `covariate_drop_log` e' attaccato a OGNI risultato per-studio e
# `rbind` ne conserva solo il primo. Va accumulato come `role_conflicts` e
# `lane_collapses`, che quella lezione l'hanno gia' imparata.
test_that("il registro delle covariate scartate raccoglie TUTTI i cluster", {
  eligible <- data.frame(cluster_id = c("cgroup_L5_x", "cgroup_L5_y"),
                         method = "rem_group", direction_check = NA_character_,
                         stringsAsFactors = FALSE)
  attr(eligible, "study_dispatch") <- list(
    cgroup_L5_x = list(list(study_id = "GSE1", treated = c("S1","S2"), control = c("S3","S4"))),
    cgroup_L5_y = list(list(study_id = "GSE2", treated = c("S5","S6"), control = c("S7","S8"))))
  fetch <- function(gse, sample_ids)
    matrix(rpois(length(sample_ids) * 30L, 200), nrow = 30L,
           dimnames = list(paste0("G", 1:30), sample_ids))
  # metadata_extra senza le colonne delle covariate: entrambi i cluster le scartano
  res <- suppressWarnings(.run_per_study_de_all(
    eligible, fetch_fn = fetch,
    metadata_extra = data.frame(sample_id = paste0("S", 1:8), gsm = paste0("S", 1:8),
                                gse = rep(c("GSE1","GSE2"), each = 4),
                                stringsAsFactors = FALSE),
    de_covariates = c("instrument_model", "aligner_class")))
  log <- attr(res, "covariate_drop_log")
  expect_false(is.null(log))
  expect_setequal(unique(log$cluster_id), c("cgroup_L5_x", "cgroup_L5_y"))
})
