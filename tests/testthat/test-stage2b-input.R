# Ingresso dello Stadio 2b (ADR-0028): il testo grezzo dei campioni dei due
# bracci, senza tagli. Un campo uguale in tutti i campioni si scrive una volta;
# un campo che cambia si scrive per campione. Dati sintetici.

braccio <- function(acc, title, chars, proto = "RNA extracted with kit Z",
                    proc = "reads aligned to genome", instr = "Seq A") {
  data.frame(geo_accession = acc, title = title, source_name_ch1 = "cell line ZX-4",
             characteristics_ch1 = chars, extract_protocol_ch1 = proto,
             data_processing = proc, instrument_model = instr,
             stringsAsFactors = FALSE)
}

t_df <- braccio(c("acc_t2", "acc_t1"), c("K17_rep2", "K17_rep1"),
                "treatment: compound K17,time: 24 h")
c_df <- braccio(c("acc_c1", "acc_c2"), c("veh_rep1", "veh_rep2"),
                "treatment: vehicle,time: 24 h")
costruisci <- function(...) simulomicsr:::.s2b_costruisci_ingresso(...)

test_that("un campo uguale in tutti i campioni dei due bracci si scrive una volta", {
  ing <- costruisci(t_df, c_df, "K17 24h", "vehicle 24h", "compound K17")
  n <- lengths(regmatches(ing$testo, gregexpr("RNA extracted with kit Z", ing$testo, fixed = TRUE)))
  expect_identical(n, 1L)
  expect_match(ing$testo, "Fields identical in every sample of both arms", fixed = TRUE)
})

test_that("un campo uguale dentro un braccio ma diverso fra i bracci si scrive una volta per braccio", {
  ing <- costruisci(t_df, c_df, "K17 24h", "vehicle 24h", "compound K17")
  for (v in c("treatment: compound K17,time: 24 h", "treatment: vehicle,time: 24 h")) {
    n <- lengths(regmatches(ing$testo, gregexpr(v, ing$testo, fixed = TRUE)))
    expect_identical(n, 1L, info = v)
  }
})

test_that("un campo che cambia dentro un braccio si scrive per campione, ordinato per accession", {
  ing <- costruisci(t_df, c_df, "K17 24h", "vehicle 24h", "compound K17")
  expect_match(ing$testo, "T1 [title] K17_rep1", fixed = TRUE)
  expect_match(ing$testo, "T2 [title] K17_rep2", fixed = TRUE)
  expect_match(ing$testo, "C1 [title] veh_rep1", fixed = TRUE)
  # l'ordine delle righe in ingresso non cambia il testo
  ing2 <- costruisci(t_df[2:1, ], c_df[2:1, ], "K17 24h", "vehicle 24h", "compound K17")
  expect_identical(ing$testo, ing2$testo)
})

test_that("nessun accession GEO dei campioni nel testo", {
  ing <- costruisci(t_df, c_df, "K17 24h", "vehicle 24h", "compound K17")
  expect_false(grepl("acc_", ing$testo, fixed = TRUE))
})

test_that("etichette ed entita' proposta in testa; entita' assente = not given", {
  ing <- costruisci(t_df, c_df, "K17 24h", "vehicle 24h", "compound K17")
  expect_match(ing$testo, "Proposed entity (from the pipeline): compound K17", fixed = TRUE)
  ing <- costruisci(t_df, c_df, "K17 24h", "vehicle 24h", NA_character_)
  expect_match(ing$testo, "Proposed entity (from the pipeline): not given", fixed = TRUE)
})

test_that("un campo lungo diverso per campione resta intero (controllo positivo contro i tagli)", {
  lungo <- vapply(1:2, function(i) paste0(strrep("long protocol text ", 400), "sample ", i), "")
  t2 <- t_df; t2$data_processing <- lungo
  ing <- costruisci(t2, c_df, "K17 24h", "vehicle 24h", "compound K17")
  for (v in lungo) expect_true(grepl(v, ing$testo, fixed = TRUE))
  expect_true(simulomicsr:::.s2b_ingresso_contiene_tutto(ing$testo, t2, c_df))
})

test_that("il controllo d'integrita' vede un valore mancante (controllo positivo)", {
  ing <- costruisci(t_df, c_df, "K17 24h", "vehicle 24h", "compound K17")
  expect_true(simulomicsr:::.s2b_ingresso_contiene_tutto(ing$testo, t_df, c_df))
  c_alt <- c_df; c_alt$characteristics_ch1[1] <- "treatment: something else"
  expect_false(simulomicsr:::.s2b_ingresso_contiene_tutto(ing$testo, t_df, c_alt))
})

test_that("gli spazi si normalizzano: a capo e spazi multipli diventano uno spazio", {
  t2 <- t_df; t2$source_name_ch1 <- "cell line\n  ZX-4"
  ing <- costruisci(t2, c_df, "K17 24h", "vehicle 24h", "compound K17")
  expect_match(ing$testo, "cell line ZX-4", fixed = TRUE)
  expect_true(simulomicsr:::.s2b_ingresso_contiene_tutto(ing$testo, t2, c_df))
})

test_that("valori vuoti: non scritti se vuoti ovunque, «(empty)» se vuoti solo in alcuni campioni", {
  t2 <- t_df; t2$instrument_model <- c("", "Seq A")
  ing <- costruisci(t2, c_df, "K17 24h", "vehicle 24h", "compound K17")
  expect_match(ing$testo, "[instrument_model] (empty)", fixed = TRUE)
  t3 <- t_df; c3 <- c_df; t3$instrument_model <- ""; c3$instrument_model <- ""
  ing <- costruisci(t3, c3, "K17 24h", "vehicle 24h", "compound K17")
  expect_false(grepl("instrument_model", ing$testo, fixed = TRUE))
})

test_that("il prompt: messaggio di sistema dal file, ingresso come messaggio utente, stima dei token", {
  ing <- costruisci(t_df, c_df, "K17 24h", "vehicle 24h", "compound K17")
  p <- simulomicsr:::build_prompt_stage2b(ing)
  expect_length(p$messages, 2L)
  expect_identical(p$messages[[1]]$role, "system")
  expect_identical(p$messages[[2]]$content, ing$testo)
  expect_true(nzchar(p$messages[[1]]$content))
  expect_true(file.exists(p$schema_path))
  expect_identical(p$token_stimati,
                   as.integer(ceiling((nchar(p$messages[[1]]$content) + nchar(ing$testo)) / 3)))
  expect_true(p$completo)
  p2 <- simulomicsr:::build_prompt_stage2b(ing, limite_token = 10L)
  expect_false(p2$completo)
})

test_that("la codifica UTF-8 doppia dell'H5 si ripara; il testo corretto resta com'e'", {
  rip <- simulomicsr:::.s2b_norm_testo
  buono <- "TGF-β1 10 ng/ml, 37 °C, manufacturer’s kit"
  doppio <- iconv(enc2utf8(buono), from = "latin1", to = "UTF-8")   # come nell'H5
  expect_false(identical(doppio, buono))
  expect_identical(rip(doppio), buono)
  expect_identical(rip(buono), buono)                  # gia' corretto: invariato
  expect_identical(rip("5 µg in café"), "5 µg in café")
  expect_identical(rip("plain ascii"), "plain ascii")
  expect_identical(rip(NA_character_), "")
  # l'ingresso mostra la lettera greca e il controllo d'integrita' regge
  t2 <- t_df; t2$characteristics_ch1 <- doppio
  ing <- costruisci(t2, c_df, "K17 24h", "vehicle 24h", "compound K17")
  expect_match(ing$testo, "TGF-β1", fixed = TRUE)
  expect_true(simulomicsr:::.s2b_ingresso_contiene_tutto(ing$testo, t2, c_df))
})

test_that("la codifica tripla si ripara in piu' passi", {
  rip <- simulomicsr:::.s2b_norm_testo
  buono <- "Gefitinib 1 µM, TGF-β1"
  doppio <- iconv(enc2utf8(buono), from = "latin1", to = "UTF-8")
  triplo <- iconv(doppio, from = "latin1", to = "UTF-8")
  expect_identical(rip(triplo), buono)
  expect_identical(rip(c(triplo, doppio, buono)), rep(buono, 3))
})
