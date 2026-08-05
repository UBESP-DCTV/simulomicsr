# test-layer-b-plot-corpus-overview.R --- TDD: "Il corpus" e' la figura vera
# (tre pannelli: k_effective, I2_med, n_sig), non prosa statica ricopiata.
#
# PERCHE' ESISTE (fix richiesto dal coordinatore dopo la revisione del
# Task 9). Il deliverable annotato (deliverable-annotato.rds, collegato al
# build dal Task 7bis) ha una riga per ognuna delle 214 meta-analisi con le
# colonne k_effective/I2_med/n_sig -- esattamente le tre distribuzioni che
# la spec §3.2 chiede in una figura sola. I numeri devono venire dal file, MAI
# essere ricopiati: .build_corpus_overview() legge SEMPRE il data.frame che
# riceve. .corpus_overview_from_bundle() copre l'altro vincolo -- se il
# deliverable annotato non e' raggiungibile da questo render, si dichiara il
# perche' invece di un buco silenzioso o di un crash.

test_that(".build_corpus_overview produce un PNG con tre pannelli dalle colonne del deliverable", {
  set.seed(1)
  d <- data.frame(
    cluster_id  = paste0("cgroup_L5_", seq_len(214)),
    k_effective = sample(3:60, 214, replace = TRUE),
    I2_med      = runif(214, 0, 100),
    n_sig       = sample(c(0L, 10L, 100L, 1000L, 300000L), 214, replace = TRUE),
    stringsAsFactors = FALSE
  )
  out_dir <- tempfile("corpus_ov_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  res <- simulomicsr:::.build_corpus_overview(d, out_dir = out_dir,
                                              config = layer_b_default_config())

  expect_true(file.exists(res$png_path))
  expect_equal(res$n_gruppi, 214L)
  expect_match(res$caption, "214")
})

test_that(".build_corpus_overview salva anche l'SVG quando config$save_svg e' TRUE", {
  d <- data.frame(k_effective = c(3L, 10L, 59L), I2_med = c(20, 50, 90),
                  n_sig = c(5L, 500L, 50000L), stringsAsFactors = FALSE)
  out_dir <- tempfile("corpus_ov_svg_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  cfg <- layer_b_default_config()
  res <- simulomicsr:::.build_corpus_overview(d, out_dir = out_dir, config = cfg)
  expect_true(file.exists(res$svg_path))

  cfg$save_svg <- FALSE
  res2 <- simulomicsr:::.build_corpus_overview(d, out_dir = out_dir, config = cfg)
  expect_true(is.na(res2$svg_path))
})

test_that(".build_corpus_overview segnala le colonne mancanti invece di produrre un grafico incompleto", {
  d <- data.frame(cluster_id = "x", k_effective = 5L, stringsAsFactors = FALSE)
  out_dir <- tempfile("corpus_ov_bad_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  expect_error(
    simulomicsr:::.build_corpus_overview(d, out_dir = out_dir, config = layer_b_default_config()),
    "I2_med"
  )
})

# --- .corpus_overview_from_bundle(): i DUE rami (disponibile / non disponibile) ---

test_that(".corpus_overview_from_bundle genera la figura quando il deliverable annotato e' raggiungibile", {
  d <- data.frame(
    cluster_id  = c("cgroup_L5_a", "cgroup_L5_b"),
    k_effective = c(23L, 59L),
    I2_med      = c(85.1, 93.5),
    n_sig       = c(4875L, 7909L),
    stringsAsFactors = FALSE
  )
  stage4_dir <- tempfile("stage4_ov_")
  dir.create(stage4_dir)
  on.exit(unlink(stage4_dir, recursive = TRUE))
  deliverable_path <- file.path(stage4_dir, "deliverable-annotato.rds")
  saveRDS(d, deliverable_path)

  lb <- structure(
    list(
      dir = tempfile("lb_ov_dispon_"),
      run_metadata = list(
        input_files = list(
          deliverable_annotato = list(path = deliverable_path, disponibile = TRUE)
        ),
        config = layer_b_default_config()
      )
    ),
    class = "layer_b_result"
  )
  dir.create(lb$dir)
  on.exit(unlink(lb$dir, recursive = TRUE), add = TRUE)

  out <- simulomicsr:::.corpus_overview_from_bundle(lb)
  expect_true(isTRUE(out$disponibile))
  expect_true(file.exists(out$plot$png_path))
  expect_equal(out$plot$n_gruppi, 2L)
})

test_that(".corpus_overview_from_bundle dichiara l'assenza quando il file non e' raggiungibile", {
  lb <- structure(
    list(
      dir = tempfile("lb_ov_assente_"),
      run_metadata = list(
        input_files = list(
          deliverable_annotato = list(
            path = "/percorso/che/non/esiste/deliverable-annotato.rds",
            disponibile = FALSE,
            motivo_assenza = "deliverable-annotato.rds assente in /percorso/che/non/esiste"
          )
        ),
        config = layer_b_default_config()
      )
    ),
    class = "layer_b_result"
  )
  dir.create(lb$dir)
  on.exit(unlink(lb$dir, recursive = TRUE), add = TRUE)

  out <- simulomicsr:::.corpus_overview_from_bundle(lb)
  expect_false(isTRUE(out$disponibile))
  expect_match(out$motivo, "assente")
  expect_null(out$plot)
  # nessun file scritto quando il ramo e' "non disponibile"
  expect_length(list.files(lb$dir, pattern = "corpus_overview"), 0L)
})

test_that(".corpus_overview_from_bundle dichiara l'assenza quando run_metadata non porta l'informazione", {
  # bundle costruito prima del collegamento (Task 7bis): niente
  # input_files$deliverable_annotato in run_metadata -- ripiego dichiarato,
  # mai un crash.
  lb <- structure(
    list(dir = tempfile("lb_ov_vecchio_"),
        run_metadata = list(input_files = list(), config = layer_b_default_config())),
    class = "layer_b_result"
  )
  dir.create(lb$dir)
  on.exit(unlink(lb$dir, recursive = TRUE), add = TRUE)

  out <- simulomicsr:::.corpus_overview_from_bundle(lb)
  expect_false(isTRUE(out$disponibile))
  expect_true(nzchar(out$motivo))
})

test_that(".corpus_overview_from_bundle dichiara l'assenza quando il file esiste ma non ha le colonne giuste", {
  stage4_dir <- tempfile("stage4_ov_bad_")
  dir.create(stage4_dir)
  on.exit(unlink(stage4_dir, recursive = TRUE))
  deliverable_path <- file.path(stage4_dir, "deliverable-annotato.rds")
  saveRDS(data.frame(cluster_id = "x", stringsAsFactors = FALSE), deliverable_path)

  lb <- structure(
    list(
      dir = tempfile("lb_ov_nocols_"),
      run_metadata = list(
        input_files = list(
          deliverable_annotato = list(path = deliverable_path, disponibile = TRUE)
        ),
        config = layer_b_default_config()
      )
    ),
    class = "layer_b_result"
  )
  dir.create(lb$dir)
  on.exit(unlink(lb$dir, recursive = TRUE), add = TRUE)

  out <- simulomicsr:::.corpus_overview_from_bundle(lb)
  expect_false(isTRUE(out$disponibile))
  expect_match(out$motivo, "k_effective")
})
