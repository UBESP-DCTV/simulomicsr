test_that(".qc_filter_samples_and_studies marca sample sotto lib_size_min", {
  input <- make_test_stage4_input(seed = 42L)
  cfg <- stage4_default_config()

  result <- .qc_filter_samples_and_studies(
    stage3_clusters = input$clusters,
    h5_metadata = input$h5_metadata,
    config = cfg
  )

  expect_named(result, c("eligible_clusters", "qc_drops_sample",
                          "qc_drops_study", "qc_drops_cluster"),
               ignore.order = TRUE)
  expect_true(nrow(result$qc_drops_sample) >= 0L)
  expect_true(all(result$qc_drops_sample$lib_size < 500000L))
})

test_that("identify_layer_a_clusters filtra correttamente i 3 path", {
  input <- make_test_stage4_input(seed = 42L)
  # ADR-0026: la fixture e' anteriore al ramo dal-contrasto (nessun cluster
  # "cgroup"), e col deliverable di default darebbe una selezione vuota. Qui si
  # verifica la classificazione nei tre path storici, quindi si chiedono.
  cfg <- stage4_default_config()
  cfg$deliverable_methods <- c("rem", "mega", "mega_aug", "rem_group")

  la <- .identify_layer_a_clusters(input$clusters, stage4_config = cfg)

  expect_true(all(la$method %in% c("rem", "mega", "mega_aug")))
  expect_equal(sum(la$method == "rem"), 1L)
  expect_equal(sum(la$method == "mega"), 1L)
})

test_that("cluster con tutti sample droppati va in qc_drops_cluster", {
  input <- make_test_stage4_input(seed = 42L)
  # forza lib_size = 100k per tutti i sample di GSE001
  input$h5_metadata$lib_size[input$h5_metadata$gse == "GSE001"] <- 100000L

  # Come sopra: la fixture non ha cluster "cgroup", quindi il deliverable di
  # default sarebbe vuoto e non ci sarebbe nulla su cui misurare i drop.
  cfg <- stage4_default_config()
  cfg$deliverable_methods <- c("rem", "mega", "mega_aug", "rem_group")
  result <- .qc_filter_samples_and_studies(input$clusters, input$h5_metadata, cfg)

  expect_true(any(result$qc_drops_study$study_id == "GSE001"))
})

test_that("la dedup dei cgroup usa l'entita' del CONTRASTO, non l'anchor del primo membro", {
  # Misurato su v13: agent_id_resolved != contrast_entity in 188 cluster su 358.
  # Con la chiave vecchia il tamoxifene (k=7) veniva ucciso da afimoxifene (k=9)
  # perche' condividevano l'anchor, pur non avendo NESSUN record in comune.
  df <- data.frame(
    cluster_id = c("cgroup_L5_aaa", "cgroup_L5_bbb"),
    kind_effective_resolved = c("small_molecule", "small_molecule"),
    agent_id_resolved = c("CHEBI:44616", "CHEBI:44616"),   # stesso anchor, sbagliato
    contrast_entity = c("CHEBI:41774", "CHEBI:44616"),      # tamoxifene vs afimoxifene
    contrast_direction = c("gain", "gain"),
    k = c(7L, 9L), n_total = c(161L, 120L), level = c(5L, 5L),
    stringsAsFactors = FALSE)
  out <- simulomicsr:::.dedup_rem_group_by_entity(df)
  expect_equal(nrow(out), 2L)
  expect_setequal(out$contrast_entity, c("CHEBI:41774", "CHEBI:44616"))
})

test_that("la dedup toglie i duplicati VERI della stessa entita' e tiene il k massimo", {
  df <- data.frame(
    cluster_id = c("cgroup_L5_lo", "cgroup_L5_hi"),
    kind_effective_resolved = c("environmental", "environmental"),
    agent_id_resolved = c("STR:hypoxia", "STR:hypoxia"),
    contrast_entity = c("STR:hypoxia", "STR:hypoxia"),
    contrast_direction = c("gain", "gain"),
    k = c(14L, 37L), n_total = c(100L, 300L), level = c(5L, 5L),
    stringsAsFactors = FALSE)
  out <- simulomicsr:::.dedup_rem_group_by_entity(df)
  expect_equal(nrow(out), 1L)
  expect_equal(out$k, 37L)
  sc <- attr(out, "scartati")
  expect_equal(nrow(sc), 1L)
  expect_equal(sc$cluster_id, "cgroup_L5_lo")
  expect_match(sc$reason, "dedup_entita_duplicata")
})

test_that("i cluster legacy senza contrast_entity usano la chiave di prima", {
  df <- data.frame(
    cluster_id = c("group_L4_aaa", "group_L4_bbb"),
    kind_effective_resolved = c("disease_vs_normal", "disease_vs_normal"),
    agent_id_resolved = c("MeSH:D001943", "MeSH:D001943"),
    k = c(3L, 8L), n_total = c(30L, 80L), level = c(4L, 4L),
    stringsAsFactors = FALSE)
  out <- simulomicsr:::.dedup_rem_group_by_entity(df)
  expect_equal(nrow(out), 1L)
  expect_equal(out$k, 8L)
})
