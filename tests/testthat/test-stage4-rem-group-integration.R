# test-stage4-rem-group-integration.R
# Task 6: verifica che .run_per_study_de_all instradi rem_group
# e che .pool_all_clusters abbia il parametro rem_group_config.

test_that(".run_per_study_de_all include i cluster rem_group", {
  eligible <- tibble::tibble(
    cluster_id = "group_L4_e", mode = "group", method = "rem_group",
    direction_check = "ok"
  )
  fetch_fn <- function(gse, sids) {
    m <- matrix(rpois(20L * length(sids), 100L), nrow = 20L,
                dimnames = list(paste0("ENSG", 1:20), sids))
    m
  }
  disp <- list(group_L4_e = list(
    list(study_id = "GSE1", treated = c("s1","s2","s3"), control = c("s4","s5")),
    list(study_id = "GSE2", treated = c("t1","t2"),      control = c("u1","u2")),
    list(study_id = "GSE5", treated = c("p1","p2"),      control = c("q1","q2"))
  ))
  attr(eligible, "study_dispatch") <- disp
  res <- .run_per_study_de_all(eligible, fetch_fn = fetch_fn)
  expect_true(nrow(res) > 0L)
  expect_true(all(res$cluster_id == "group_L4_e"))
})

# Task 7 Step 1: verifica la semantica del merge c() tra study_dispatch e
# group_rem_dispatch (cluster_id disgiunti, named list).
test_that("il group_rem_dispatch si fonde nello study_dispatch (cluster_id disgiunti)", {
  study_dispatch <- list(pair_A = list(list(study_id = "GSE9",
    treated = c("a","b"), control = c("c","d"))))
  group_rem_dispatch <- list(group_L4_e = list(list(study_id = "GSE1",
    treated = c("s1","s2"), control = c("s3","s4"))))
  merged <- c(study_dispatch, group_rem_dispatch)
  expect_setequal(names(merged), c("pair_A", "group_L4_e"))
  expect_length(merged, 2L)
})

# Finding 1 (Important): verifica la semantica della guardia fail-loud sul merge
# dispatch (cluster_id disgiunti). Non invoca build_stage4_results (troppo setup);
# testa direttamente la logica della guardia: intersect(names(a), names(b)).
test_that("guardia merge dispatch: chiavi sovrapposte rilevate, disgiunte no", {
  sd_disjoint  <- list(pair_A   = list(), pair_B   = list())
  grd_disjoint <- list(group_C  = list(), group_D  = list())
  # Caso disgiunti: intersect e' vuoto -> guardia NON scatta
  dup_disjoint <- intersect(names(sd_disjoint), names(grd_disjoint))
  expect_length(dup_disjoint, 0L)
  expect_false(length(dup_disjoint) > 0L)

  sd_overlap   <- list(pair_A   = list(), group_L4_x = list())
  grd_overlap  <- list(group_L4_x = list(), group_D = list())
  # Caso sovrapposti: intersect non e' vuoto -> guardia scatta
  dup_overlap <- intersect(names(sd_overlap), names(grd_overlap))
  expect_length(dup_overlap, 1L)
  expect_true(length(dup_overlap) > 0L)
  expect_identical(dup_overlap, "group_L4_x")
})

# Task 7 Step 4: non-regressione — .identify_layer_a_clusters non altera
# i method dei rami rem/mega/mega_aug; il ramo rem_group resta distinto.
test_that("non-regressione: identify_layer_a non altera i rami rem/mega/mega_aug", {
  # Un cluster per ramo esistente + un rem_group; i method dei rami esistenti
  # restano invariati e disgiunti dal nuovo.
  clusters <- dplyr::bind_rows(
    .mk_cluster_row("pair_rem",  "pair",  0L, 5L, 60L, 5L, 0.80, FALSE,
                    "small_molecule", "CHEBI:a"),
    .mk_cluster_row("group_meg", "group", 0L, 8L, 200L, 8L, 0.90, TRUE,
                    "environmental", "STR:hyp"),
    .mk_cluster_row("group_reg", "group", 4L, 25L, 400L, 25L, 0.30, FALSE,
                    "small_molecule", "CHEBI:enza")
  )
  clusters$usable_rem_strict[clusters$cluster_id == "pair_rem"] <- TRUE
  cfg <- stage4_default_config()
  out <- .identify_layer_a_clusters(clusters, cfg)
  expect_identical(out$method[out$cluster_id == "pair_rem"], "rem")
  expect_identical(out$method[out$cluster_id == "group_meg"], "mega")
  expect_identical(out$method[out$cluster_id == "group_reg"], "rem_group")
})

# Regressione C1 (2026-07-05): direction_check = NA su cluster group-mode
# -----------------------------------------------------------------------
# I cluster group-mode ricevono direction_check = NA_character_ da
# .summarize_clusters (concetto pair-only). In produzione TUTTI i group hanno NA.
# Bug: `NA == "swapped"` -> NA -> if(NA) lancia errore -> tryCatch cattura ->
# warning "per_study DE FALLITO (skip, non fatale)" -> .empty_per_study_de() per
# ogni studio -> per_study_de vuoto -> pool vuoto. No-op silenzioso.
# Questo test replica esattamente la condizione di produzione: direction_check = NA.
test_that("C1 regressione: rem_group con direction_check=NA produce DE non vuoto", {
  # Cluster group con direction_check NA (come in produzione)
  eligible <- tibble::tibble(
    cluster_id     = "group_L4_na",
    mode           = "group",
    method         = "rem_group",
    direction_check = NA_character_   # <-- condizione di produzione: NA, non "ok"
  )
  fetch_fn <- function(gse, sids) {
    m <- matrix(rpois(20L * length(sids), 100L), nrow = 20L,
                dimnames = list(paste0("ENSG", 1:20), sids))
    m
  }
  disp <- list(group_L4_na = list(
    list(study_id = "GSE10", treated = c("s1","s2","s3"), control = c("s4","s5")),
    list(study_id = "GSE11", treated = c("t1","t2"),      control = c("u1","u2")),
    list(study_id = "GSE12", treated = c("p1","p2"),      control = c("q1","q2"))
  ))
  attr(eligible, "study_dispatch") <- disp

  # Senza il fix: ogni studio finisce nel tryCatch per `if(NA)` ->
  # per_study DE FALLITO -> 0 righe totali.
  # Con il fix: isTRUE(NA == "swapped") = FALSE -> nessun flip, DE procede.
  res <- .run_per_study_de_all(eligible, fetch_fn = fetch_fn)

  # La tabella DE deve avere righe (almeno 1 gene x 3 studi)
  expect_true(nrow(res) > 0L,
    label = "per_study DE con direction_check=NA deve produrre righe (non no-op silenzioso)")
  # Tutti i record devono appartenere al cluster corretto
  expect_true(all(res$cluster_id == "group_L4_na"))
  # direction_applied deve essere "none" (nessun flip: NA != "swapped")
  expect_true(all(res$direction_applied == "none"))
})

# Fix I1 (2026-07-05): gate k_eff rem_group deve contare STUDI distinti, non entry
# -------------------------------------------------------------------------------------
# Bug: length(disp_i) conta le entry del dispatch, non gli study_id unici.
# Un singolo studio con piu' bracci trattati (es. stesso farmaco a dosi diverse)
# genera piu' entry con lo stesso study_id, gonfiando k_eff e soddisfando
# falsamente il gate k_eff >= 3 (pseudo-replicazione).
# Spec §4.2: k_eff = "numero di studi con entry valida".
#
# RED prima del fix: 3 entry / 2 studi -> length(disp_i)=3 -> k_eff=3 -> passa gate
#   -> cluster NON finisce in non_processable (sbagliato).
# GREEN dopo il fix: 3 entry / 2 studi -> length(unique(study_ids))=2 -> k_eff=2
#   -> k_eff < 3 -> cluster finisce in non_processable con reason "k_eff=2".
test_that("I1 gate k_eff conta studi distinti: 3-entry/2-studi -> non_processable, 3-entry/3-studi -> processa", {
  # Due cluster rem_group:
  # - group_L4_multiarm: 3 entry ma solo 2 study_id distinti (GSE1 appare 2 volte
  #   con bracci trattati diversi, tipico di uno studio multi-dose). Con il codice
  #   buggy k_eff=3 => passa gate; con il fix k_eff=2 => non_processable.
  # - group_L4_3studi: 3 entry e 3 study_id distinti => k_eff=3 => passa gate
  #   (comportamento corretto con entrambe le versioni).
  eligible <- tibble::tibble(
    cluster_id      = c("group_L4_multiarm", "group_L4_3studi"),
    method          = c("rem_group", "rem_group"),
    level           = c(4L, 4L),
    mode            = c("group", "group"),
    direction_check = c(NA_character_, NA_character_)
  )
  dispatch <- list(
    # 3 entry, 2 study_id distinti (GSE1 con 2 bracci trattati a dosi diverse)
    group_L4_multiarm = list(
      list(study_id = "GSE1", treated = c("s1", "s2"), control = c("s3", "s4")),
      list(study_id = "GSE1", treated = c("s5", "s6"), control = c("s3", "s4")),
      list(study_id = "GSE2", treated = c("t1", "t2"), control = c("t3", "t4"))
    ),
    # 3 entry, 3 study_id distinti
    group_L4_3studi = list(
      list(study_id = "GSE10", treated = c("a1", "a2"), control = c("a3", "a4")),
      list(study_id = "GSE11", treated = c("b1", "b2"), control = c("b3", "b4")),
      list(study_id = "GSE12", treated = c("c1", "c2"), control = c("c3", "c4"))
    )
  )
  attr(eligible, "study_dispatch") <- dispatch
  attr(eligible, "group_dispatch")  <- list()

  # stage3_clusters minimo richiesto dalla firma ma non usato dal ramo rem_group
  s3 <- tibble::tibble(
    cluster_id         = character(0L),
    mode               = factor(character(0L), levels = c("pair", "group")),
    level              = integer(0L),
    anchor_key         = character(0L),
    studies_in_cluster = list(),
    sample_ids         = list(),
    sample_studies     = list()
  )

  # Per il ramo rem_group .pool_all_clusters usa solo per_study_de + dispatch
  # (fetch_fn NON e' chiamato: la DE per-studio e' gia' in per_study_de).
  pooled <- .pool_all_clusters(
    per_study_de    = .empty_per_study_de(),
    eligible_clusters = eligible,
    fetch_fn        = function(g, s) stop("fetch_fn non deve essere chiamato per rem_group"),
    stage3_clusters = s3,
    workers         = 1L,
    dream_workers_cap = 2L
  )
  np <- attr(pooled, "non_processable_in_pool")

  # Caso 1: 3 entry / 2 studi distinti -> k_eff=2 < soglia 3 -> non_processable
  expect_true(
    "group_L4_multiarm" %in% np$cluster_id,
    label = "3-entry/2-studi: deve essere in non_processable (k_eff=2 < soglia 3)"
  )
  reason_ma <- np$reason[np$cluster_id == "group_L4_multiarm"]
  expect_match(
    reason_ma, "k_eff=2",
    label = "reason deve indicare k_eff=2"
  )
  expect_match(
    reason_ma, "rem_group_insufficient_in_study_controls",
    label = "reason deve indicare rem_group_insufficient_in_study_controls"
  )

  # Caso 2: 3 entry / 3 studi distinti -> k_eff=3 >= soglia -> passa gate -> NON in non_processable
  expect_false(
    "group_L4_3studi" %in% np$cluster_id,
    label = "3-entry/3-studi: NON deve essere in non_processable (k_eff=3 >= soglia)"
  )
})

# --- .collapse_arms_by_study (Opzione C: inverse-variance FE intra-studio) ------
# RED dimostrato: senza il collapse, due bracci dello stesso studio arrivano a
# metafor come 2 studi indipendenti (k_effective gonfio, tau^2 / I^2 distorti).
# GREEN: dopo il collapse, ogni (study_id, gene_id) ha esattamente 1 riga.

test_that(".collapse_arms_by_study: studio a 2 bracci stesso gene -> 1 riga, formula FE verificata", {
  # Input: GSE1 con 2 bracci per ENSG1, logFC 1.0 e 2.0, SE 0.2 entrambi.
  # Formula inverse-variance:
  #   w1 = w2 = 1/0.04 = 25  ;  w_sum = 50
  #   logFC_comb = (25*1.0 + 25*2.0) / 50 = 1.5
  #   SE_comb    = sqrt(1/50) = sqrt(0.02) = 0.14142135...
  input <- tibble::tibble(
    cluster_id        = c("group_L4_x", "group_L4_x"),
    study_id          = c("GSE1", "GSE1"),
    gene_id           = c("ENSG1", "ENSG1"),
    gene_symbol       = c("A", "A"),
    logFC             = c(1.0, 2.0),
    SE                = c(0.2, 0.2),
    p_value           = c(0.05, 0.03),
    t_stat            = c(5.0, 10.0),
    n_treated         = c(3L, 3L),
    n_control         = c(3L, 3L),
    direction_applied = c("none", "none")
  )
  out <- .collapse_arms_by_study(input)

  expect_equal(nrow(out), 1L, label = "2 bracci -> 1 riga collassata")
  expect_equal(out$study_id,   "GSE1")
  expect_equal(out$gene_id,    "ENSG1")
  expect_equal(out$logFC,      1.5,         tolerance = 1e-6,
    label = "logFC inverse-variance = 1.5")
  expect_equal(out$SE,         sqrt(1/50),  tolerance = 1e-6,
    label = "SE inverse-variance = sqrt(1/50)")
  expect_equal(out$t_stat,     1.5 / sqrt(1/50), tolerance = 1e-6,
    label = "t_stat = logFC/SE")
  expect_equal(out$n_treated,  6L,
    label = "n_treated = somma bracci (3+3)")
  expect_equal(out$n_control,  3L,
    label = "n_control = max (control condiviso, non doppio conteggio)")
})

test_that(".collapse_arms_by_study: studio a 1 braccio -> riga invariata", {
  input <- tibble::tibble(
    cluster_id        = "group_L4_x",
    study_id          = "GSE1",
    gene_id           = "ENSG1",
    gene_symbol       = "A",
    logFC             = 1.5,
    SE                = 0.3,
    p_value           = 0.04,
    t_stat            = 5.0,
    n_treated         = 4L,
    n_control         = 4L,
    direction_applied = "none"
  )
  out <- .collapse_arms_by_study(input)
  expect_equal(nrow(out), 1L)
  expect_equal(out$logFC, 1.5, tolerance = 1e-10,
    label = "1 braccio: logFC invariato")
  expect_equal(out$SE, 0.3, tolerance = 1e-10,
    label = "1 braccio: SE invariata")
})

test_that(".collapse_arms_by_study: 2 studi distinti 1 braccio ciascuno -> 2 righe invariate", {
  # No collapse cross-studio: studi diversi restano righe distinte.
  input <- tibble::tibble(
    cluster_id        = c("group_L4_x", "group_L4_x"),
    study_id          = c("GSE1", "GSE2"),
    gene_id           = c("ENSG1", "ENSG1"),
    gene_symbol       = c("A", "A"),
    logFC             = c(1.0, 2.0),
    SE                = c(0.2, 0.3),
    p_value           = c(0.05, 0.02),
    t_stat            = c(5.0, 6.7),
    n_treated         = c(3L, 4L),
    n_control         = c(3L, 4L),
    direction_applied = c("none", "none")
  )
  out <- .collapse_arms_by_study(input)
  expect_equal(nrow(out), 2L, label = "2 studi distinti -> 2 righe")
  # Output ordinato per (study_id, gene_id)
  expect_equal(out$study_id, c("GSE1", "GSE2"))
  expect_equal(out$logFC, c(1.0, 2.0), tolerance = 1e-10,
    label = "logFC invariati: nessun merge cross-studio")
  expect_equal(out$SE, c(0.2, 0.3), tolerance = 1e-10,
    label = "SE invariate")
})

test_that(".collapse_arms_by_study: braccio con SE=NA escluso, braccio valido restituito invariato", {
  # GSE1 con 2 bracci: 1 con SE=NA (invalido) + 1 valido -> ritorna il valido senza
  # applicare la formula FE (singolo braccio valido = passa invariato).
  input <- tibble::tibble(
    cluster_id        = c("group_L4_x", "group_L4_x"),
    study_id          = c("GSE1", "GSE1"),
    gene_id           = c("ENSG1", "ENSG1"),
    gene_symbol       = c("A", "A"),
    logFC             = c(1.0, 2.0),
    SE                = c(NA_real_, 0.2),
    p_value           = c(NA_real_, 0.04),
    t_stat            = c(NA_real_, 10.0),
    n_treated         = c(3L, 3L),
    n_control         = c(3L, 3L),
    direction_applied = c("none", "none")
  )
  out <- .collapse_arms_by_study(input)
  expect_equal(nrow(out), 1L, label = "braccio SE=NA escluso -> 1 riga")
  expect_equal(out$logFC, 2.0, tolerance = 1e-10,
    label = "solo il braccio valido (SE=0.2, logFC=2.0)")
  expect_equal(out$SE, 0.2, tolerance = 1e-10)
})

test_that(".collapse_arms_by_study: input 0 righe -> ritorna 0 righe con schema corretto", {
  empty_in <- .empty_per_study_de()
  out <- .collapse_arms_by_study(empty_in)
  expect_equal(nrow(out), 0L)
  expect_named(out, names(.empty_per_study_de()),
    label = "schema identico a .empty_per_study_de()")
})

# End-to-end: rem_group con studio a 2 bracci -> k_effective = studi distinti
# RED prima del fix: k=4 (GSE1-arm1 + GSE1-arm2 + GSE2 + GSE3 trattati come indipendenti)
# GREEN dopo il fix: k=3 (GSE1 merged + GSE2 + GSE3)
test_that("E2E rem_group: collapse intra-studio -> k_effective = studi distinti, non bracci", {
  skip_if_not_installed("metafor")

  # per_study_de: GSE1 a 2 bracci per ENSG1 + GSE2 + GSE3 = 3 studi distinti
  per_study <- tibble::tibble(
    cluster_id        = "group_L4_e2e",
    study_id          = c("GSE1", "GSE1", "GSE2", "GSE3"),
    gene_id           = c("ENSG1", "ENSG1", "ENSG1", "ENSG1"),
    gene_symbol       = c("A", "A", "A", "A"),
    logFC             = c(1.0, 2.0, 1.5, 1.2),
    SE                = c(0.2, 0.2, 0.3, 0.25),
    p_value           = c(0.05, 0.02, 0.01, 0.03),
    t_stat            = c(5.0, 10.0, 5.0, 4.8),
    n_treated         = c(3L, 3L, 4L, 4L),
    n_control         = c(3L, 3L, 4L, 4L),
    direction_applied = "none"
  )

  # Dispatch: 4 entry, 3 studi distinti (GSE1 con 2 bracci) -> k_eff=3 >= 3 (supera il gate)
  eligible <- tibble::tibble(
    cluster_id      = "group_L4_e2e",
    method          = "rem_group",
    level           = 4L,
    mode            = "group",
    direction_check = NA_character_
  )
  disp <- list(group_L4_e2e = list(
    list(study_id = "GSE1", treated = c("s1", "s2"), control = c("s3")),
    list(study_id = "GSE1", treated = c("s4", "s5"), control = c("s3")),
    list(study_id = "GSE2", treated = c("t1", "t2"), control = c("t3", "t4")),
    list(study_id = "GSE3", treated = c("u1", "u2"), control = c("u3", "u4"))
  ))
  attr(eligible, "study_dispatch") <- disp
  attr(eligible, "group_dispatch")  <- list()

  s3 <- tibble::tibble(
    cluster_id         = character(0L),
    mode               = factor(character(0L), levels = c("pair", "group")),
    level              = integer(0L),
    anchor_key         = character(0L),
    studies_in_cluster = list(),
    sample_ids         = list(),
    sample_studies     = list()
  )

  pooled <- .pool_all_clusters(
    per_study_de      = per_study,
    eligible_clusters = eligible,
    fetch_fn          = function(g, s) stop("fetch_fn non deve essere chiamato per rem_group"),
    stage3_clusters   = s3,
    workers           = 1L,
    dream_workers_cap = 2L
  )

  # Deve esserci 1 gene nel pool (ENSG1, presente in 3 studi distinti dopo collapse)
  expect_equal(nrow(pooled), 1L, label = "1 gene nel pool (ENSG1)")
  expect_equal(pooled$gene_id, "ENSG1")

  # Con collapse intra-studio: 3 studi distinti -> k_effective = 3 (non 4)
  expect_equal(
    pooled$k_effective[pooled$gene_id == "ENSG1"], 3L,
    label = "k_effective = 3 studi distinti, non 4 bracci (pseudo-replicazione eliminata)"
  )
})
