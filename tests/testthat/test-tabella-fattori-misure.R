p <- function(...) { x <- c(...); stats::setNames(unname(x), names(x)) }

# Atlas finto a due fattori: 2 x 2 gruppi da due campioni. `rif` e `test` scelgono il confronto di Atlas.
atlas_2x2 <- function(rif = "g1", test = "g4") {
  campioni <- sprintf("GSM%d", 1:8)
  livelli <- data.frame(farmaco = rep(c("nessuno", "X", "nessuno", "X"), each = 2),
                        linea = rep(c("A", "A", "B", "B"), each = 2),
                        row.names = campioni, stringsAsFactors = FALSE)
  fattori <- data.frame(nome = c("farmaco", "linea"), tipo = "contesto", base = NA_character_)
  partizione <- stats::setNames(rep(c("g1", "g2", "g3", "g4"), each = 2), campioni)
  membri <- function(g) names(partizione)[partizione == g]
  confronti <- data.frame(studio = "GSE0", id = paste0(rif, "_", test), nome = NA_character_,
                          riferimento = rif, test = test, stringsAsFactors = FALSE)
  confronti$trattato <- lapply(test, membri); confronti$controllo <- lapply(rif, membri)
  list(tabella = tf_tabella(campioni, livelli, fattori), partizione = partizione, confronti = confronti,
       esclusi = data.frame(run = character(0), gruppo = character(0)))
}
nostro <- function(t, c, id = "x") {
  d <- data.frame(studio = "GSE0", id = id, stringsAsFactors = FALSE); d$trattato <- list(t); d$controllo <- list(c); d
}
atlas_vero <- function() {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml"))
  s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  list(k = k, a = atlas_tabella(k, s, legame_finto(unique(k$gruppi$run))))
}

test_that("tf_misura_gruppi: le quattro classi e il conto dei campioni non comuni (Review Focus 3)", {
  atlas <- p(GSM1 = "a", GSM2 = "a", GSM3 = "b", GSM4 = "b")
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "x", GSM3 = "y", GSM4 = "y"), atlas)$classe, "identica")
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "z", GSM3 = "y", GSM4 = "y"), atlas)$classe, "piu_fine")
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "x", GSM3 = "x", GSM4 = "x"), atlas)$classe, "piu_grossa")
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "y", GSM3 = "x", GSM4 = "y"), atlas)$classe, "incrociata")
  m <- tf_misura_gruppi(p(GSM1 = "x", GSM2 = "x", GSM3 = "y", GSM9 = "y"), atlas)
  expect_equal(m$n_comuni, 3L); expect_equal(m$solo_nostri, 1L); expect_equal(m$solo_atlas, 1L)
  expect_equal(tf_misura_gruppi(atlas, atlas)$ari, 1)
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "y", GSM3 = "x", GSM4 = "y"), atlas)$ari, -0.5)
})
test_that("tf_misura_gruppi: nessun campione comune non dà una classe, e i casi degeneri dell'indice di Rand", {
  atlas <- p(GSM1 = "a", GSM2 = "a", GSM3 = "b", GSM4 = "b")
  m <- tf_misura_gruppi(p(GSM8 = "x", GSM9 = "x"), atlas)
  expect_true(is.na(m$classe)); expect_true(is.na(m$ari)); expect_equal(m$n_comuni, 0L)
  expect_equal(m$solo_nostri, 2L); expect_equal(m$solo_atlas, 4L)
  m0 <- tf_misura_gruppi(character(0), atlas)
  expect_true(is.na(m0$classe)); expect_equal(m0$solo_atlas, 4L)
  un_gruppo <- p(GSM1 = "a", GSM2 = "a")
  expect_equal(tf_misura_gruppi(un_gruppo, p(GSM1 = "k", GSM2 = "k"))$ari, 1)      # un gruppo solo in tutti e due
  expect_equal(tf_misura_gruppi(un_gruppo, p(GSM1 = "k", GSM2 = "j"))$ari, 0)      # uno contro due singoli
  expect_error(tf_misura_gruppi(c("x", "y"), atlas), class = "simulomicsr_tf_ingresso_non_valido")
  expect_error(tf_misura_gruppi(p(GSM1 = "x", GSM1 = "y"), atlas), class = "simulomicsr_tf_ingresso_non_valido")
})
test_that("sul vero E-GEOD-52778: Atlas contro Atlas è perfetto, i confronti di Atlas rispettano la definizione", {
  v <- atlas_vero(); a <- v$a; u <- a$tabella$campioni
  cl <- tf_classi_confronti_atlas(a, u); expect_equal(cl$classe, rep("rispetta", 3))
  r <- tf_misura_ritrovati(a$confronti, cl, u); expect_equal(r$ritrovato, rep("uguale", 3))
  inv <- a$confronti; inv[c("trattato", "controllo")] <- inv[c("controllo", "trattato")]
  expect_equal(tf_misura_ritrovati(inv, cl, u)$ritrovato, rep("verso_opposto", 3))
  senza <- setdiff(u, a$confronti$trattato[[1]][1:3])
  expect_equal(tf_classi_confronti_atlas(a, senza)$classe[1], "non_formabile")
})
test_that("tf_misura_ritrovati: i nostri bracci si tagliano all'universo, e senza confronti nostri è «no»", {
  v <- atlas_vero(); a <- v$a; u <- a$tabella$campioni
  cl <- tf_classi_confronti_atlas(a, u)
  largo <- a$confronti[1, ]; largo$trattato[[1]] <- c(largo$trattato[[1]], "GSM1")   # un campione fuori dall'universo
  expect_equal(tf_misura_ritrovati(largo, cl, u)$ritrovato, c("uguale", "no", "no"))
  expect_equal(tf_misura_ritrovati(a$confronti[0, ], cl, u)$ritrovato, rep("no", 3))
  stretto <- a$confronti[1, ]; stretto$trattato[[1]] <- stretto$trattato[[1]][1:3]    # un campione in meno
  expect_equal(tf_misura_ritrovati(stretto, cl, u)$ritrovato, rep("no", 3))
})
test_that("tf_giudica_non_elencati: le cinque classi", {
  v <- atlas_vero(); a <- v$a; k <- v$k; u <- a$tabella$campioni
  gr <- function(g) sort(legame_finto(k$gruppi$run[k$gruppi$gruppo == g])$gsm)
  nostro <- function(t, c) { d <- data.frame(studio = "GSE52778", id = "x"); d$trattato <- list(t); d$controllo <- list(c); d }
  expect_equal(tf_giudica_non_elencati(nostro(gr("g2"), gr("g3")), a, u)$giudizio, "coerente")
  expect_equal(tf_giudica_non_elencati(nostro(c(gr("g1"), gr("g2")), gr("g4")), a, u)$giudizio, "braccio_misto")
  expect_equal(tf_giudica_non_elencati(nostro(gr("g1")[1:2], gr("g1")[3:4]), a, u)$giudizio, "nessuna_differenza")
  expect_equal(tf_giudica_non_elencati(nostro(c("GSM1", "GSM2"), gr("g4")), a, u)$giudizio, "fuori_atlas")
  expect_equal(nrow(tf_giudica_non_elencati(a$confronti, a, u)), 0L)
  inv <- a$confronti; inv[c("trattato", "controllo")] <- inv[c("controllo", "trattato")]
  expect_equal(nrow(tf_giudica_non_elencati(inv, a, u)), 0L)                 # il verso opposto è «elencato»
  expect_true("giudizio" %in% names(tf_giudica_non_elencati(a$confronti, a, u)))
})
test_that("due fattori che cambiano: «piu_fattori» nei confronti di Atlas e nei nostri non elencati", {
  a <- atlas_2x2("g1", "g4"); u <- a$tabella$campioni
  expect_equal(tf_classi_confronti_atlas(a, u)$classe, "piu_fattori")
  expect_equal(tf_classi_confronti_atlas(atlas_2x2("g1", "g2"), u)$classe, "rispetta")
  g <- function(x) names(a$partizione)[a$partizione == x]
  expect_equal(tf_giudica_non_elencati(nostro(g("g2"), g("g3")), a, u)$giudizio, "piu_fattori")
  expect_equal(tf_giudica_non_elencati(nostro(g("g2"), g("g1")), a, u)$giudizio, "coerente")
})
test_that("tf_misura_studio: Atlas contro Atlas dà la riga perfetta, e uno studio senza nostri confronti dà zeri", {
  v <- atlas_vero(); a <- v$a; u <- a$tabella$campioni
  m <- tf_misura_studio("GSE52778", a$partizione, a$confronti, a, u, lettura = "intera")
  r <- m$riga
  expect_equal(nrow(r), 1L); expect_equal(r$classe_gruppi, "identica"); expect_equal(r$ari, 1)
  expect_equal(c(r$n_atlas, r$n_rispetta, r$n_rispetta_uguale, r$n_rispetta_verso_opposto), c(3L, 3L, 3L, 0L))
  expect_equal(c(r$n_nostri, r$n_non_elencati, r$n_giudicabili, r$n_errori), c(3L, 0L, 0L, 0L))
  expect_equal(m$atlas$ritrovato, rep("uguale", 3)); expect_equal(nrow(m$non_elencati), 0L)
  vuoto <- tf_misura_studio("GSE52778", character(0), a$confronti[0, c("studio", "id", "trattato", "controllo")], a, u, lettura = "intera")
  expect_true(is.na(vuoto$riga$classe_gruppi)); expect_equal(vuoto$riga$n_rispetta_uguale, 0L)
  expect_equal(vuoto$riga$n_rispetta, 3L); expect_equal(vuoto$riga$n_nostri, 0L)
})
test_that("tf_misura_studio: i conti dei non elencati e degli errori", {
  a <- atlas_2x2("g1", "g2"); u <- a$tabella$campioni
  g <- function(x) names(a$partizione)[a$partizione == x]
  miei <- rbind(nostro(g("g2"), g("g1"), "c1"),                # elencato
                nostro(g("g4"), g("g1"), "c2"),                # due fattori: errore
                nostro(g("g4"), g("g3"), "c3"),                # coerente
                nostro(c("GSM98", "GSM99"), g("g3"), "c4"))    # fuori da Atlas
  r <- tf_misura_studio("GSE0", a$partizione, miei, a, u, lettura = "intera")$riga
  expect_equal(c(r$n_nostri, r$n_non_elencati, r$n_giudicabili, r$n_errori), c(4L, 3L, 2L, 1L))
  expect_equal(c(r$n_coerente, r$n_piu_fattori_nostri, r$n_braccio_misto, r$n_fuori_atlas), c(1L, 1L, 0L, 1L))
  expect_equal(r$n_rispetta_uguale, 1L)
})
test_that("tf_riassumi_misure: numeratori, denominatori, quote e intervalli dal bootstrap sugli studi", {
  v <- atlas_vero(); a <- v$a; u <- a$tabella$campioni
  buono <- tf_misura_studio("s1", a$partizione, a$confronti, a, u, lettura = "intera")$riga
  vuoto <- tf_misura_studio("s2", character(0), a$confronti[0, c("studio", "id", "trattato", "controllo")], a, u, lettura = "intera")$riga
  a2 <- atlas_2x2("g1", "g4"); g <- function(x) names(a2$partizione)[a2$partizione == x]
  misto <- tf_misura_studio("s3", stats::setNames(rep("x", 8), names(a2$partizione)),
                            nostro(g("g2"), g("g3")), a2, a2$tabella$campioni, lettura = "intera")$riga
  per_studio <- rbind(buono, vuoto, misto)
  # `vuoto` non ha campioni comuni: classe NA, fuori dal denominatore di (a) con un avviso (test a parte).
  tf_riassumi_misure <- function(...) suppressWarnings(simulomicsr:::tf_riassumi_misure(...),
                                                       classes = "simulomicsr_tf_studi_senza_classe")
  r <- tf_riassumi_misure(per_studio, B = 200L, seme = 1L)
  riga <- function(m) r[r$misura == m, ]
  expect_equal(c(riga("a_gruppi_identici")$numeratore, riga("a_gruppi_identici")$denominatore), c(1, 2))
  expect_equal(c(riga("b_confronti_ritrovati")$numeratore, riga("b_confronti_ritrovati")$denominatore), c(3, 6))
  expect_equal(riga("b_confronti_ritrovati")$quota, 0.5)
  expect_equal(c(riga("c_errori_non_elencati")$numeratore, riga("c_errori_non_elencati")$denominatore), c(1, 1))
  expect_equal(c(riga("atlas_piu_fattori")$numeratore, riga("atlas_piu_fattori")$denominatore), c(1, 7))
  expect_true(all(r$ic_basso <= r$quota + 1e-12 & r$quota <= r$ic_alto + 1e-12, na.rm = TRUE))
  expect_equal(r, tf_riassumi_misure(per_studio, B = 200L, seme = 1L))            # stesso seme, stesso esito
  tutti_buoni <- tf_riassumi_misure(rbind(buono, buono), B = 50L, seme = 1L)
  b <- tutti_buoni[tutti_buoni$misura == "b_confronti_ritrovati", ]
  expect_equal(c(b$quota, b$ic_basso, b$ic_alto), c(1, 1, 1))
  cc <- tutti_buoni[tutti_buoni$misura == "c_errori_non_elencati", ]
  expect_equal(cc$denominatore, 0); expect_true(is.na(cc$quota))                   # denominatore zero: quota NA
  seme_prima <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
  tf_riassumi_misure(per_studio, B = 10L, seme = 1L)
  seme_dopo <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
  expect_identical(seme_prima, seme_dopo)                                            # non tocca il generatore globale
})

test_that("tf_riassumi_misure: uno studio senza classe dei gruppi esce dal denominatore di (a) con un avviso che lo nomina", {
  v <- atlas_vero(); a <- v$a; u <- a$tabella$campioni
  buono <- tf_misura_studio("s1", a$partizione, a$confronti, a, u, lettura = "intera")$riga
  vuoto <- tf_misura_studio("s2", character(0), a$confronti[0, c("studio", "id", "trattato", "controllo")], a, u, lettura = "intera")$riga
  expect_true(is.na(vuoto$classe_gruppi))
  expect_warning(r <- tf_riassumi_misure(rbind(buono, vuoto), B = 20L, seme = 1L),
                 regexp = "s2", class = "simulomicsr_tf_studi_senza_classe")
  expect_equal(r$denominatore[r$misura == "a_gruppi_identici"], 1)
  expect_no_warning(tf_riassumi_misure(rbind(buono, buono), B = 20L, seme = 1L))
})

# Atlas finto con un fattore che i curatori non scrivono per il controllo: la dose.
atlas_dose <- function() {
  campioni <- sprintf("GSM%d", 1:8)
  livelli <- data.frame(farmaco = rep(c("nessuno", "X", "X", "nessuno"), each = 2),
                        dose = rep(c(TF_NON_SCRITTO, "5 uM", "10 uM", TF_NON_SCRITTO), each = 2),
                        linea = rep(c("A", "A", "A", "B"), each = 2),
                        row.names = campioni, stringsAsFactors = FALSE)
  fattori <- data.frame(nome = c("farmaco", "dose", "linea"), tipo = "contesto", base = NA_character_)
  partizione <- stats::setNames(rep(c("g1", "g2", "g3", "g4"), each = 2), campioni)
  membri <- function(g) names(partizione)[partizione == g]
  rif <- c("g1", "g2", "g4", "g4"); test <- c("g2", "g3", "g1", "g3")
  confronti <- data.frame(studio = "GSE0", id = paste0(rif, "_", test), nome = NA_character_,
                          riferimento = rif, test = test, stringsAsFactors = FALSE)
  confronti$trattato <- lapply(test, membri); confronti$controllo <- lapply(rif, membri)
  list(tabella = tf_tabella(campioni, livelli, fattori), partizione = partizione, confronti = confronti,
       esclusi = data.frame(run = character(0), gruppo = character(0)))
}
test_that("un fattore «non scritto» in un braccio non è una differenza, e si scrive a parte", {
  a <- atlas_dose(); u <- names(a$partizione)
  cl <- tf_classi_confronti_atlas(a, u)
  # controllo senza dose contro farmaco con dose: cambia solo il farmaco
  expect_equal(cl$classe[1], "rispetta"); expect_equal(cl$fattori_diversi[1], "farmaco")
  expect_equal(cl$fattori_non_scritti[1], "dose")
  # due dosi scritte: cambia la dose
  expect_equal(cl$classe[2], "rispetta"); expect_equal(cl$fattori_diversi[2], "dose")
  expect_equal(cl$fattori_non_scritti[2], "")
  # tutti e due senza dose: «non scritto» contro «non scritto» è uguale
  expect_equal(cl$classe[3], "rispetta"); expect_equal(cl$fattori_diversi[3], "linea")
  # farmaco e linea cambiano, la dose non scritta non si aggiunge al conto
  expect_equal(cl$classe[4], "piu_fattori"); expect_equal(cl$fattori_diversi[4], "farmaco, linea")
  expect_equal(cl$fattori_non_scritti[4], "dose")
  # un nostro confronto non elencato fra controllo senza dose e farmaco a 10 uM è coerente
  ne <- tf_giudica_non_elencati(nostro(c("GSM5", "GSM6"), c("GSM1", "GSM2")), a, u)
  expect_equal(ne$giudizio, "coerente")
  # un braccio che unisce campioni con dose e senza dose resta un braccio misto
  ne2 <- tf_giudica_non_elencati(nostro(c("GSM3", "GSM4", "GSM7", "GSM8"), c("GSM1", "GSM2")), a, u)
  expect_equal(ne2$giudizio, "braccio_misto")
})

# --- S12r2: le tre letture del riferimento (spec 5.5) -----------------------
test_that("tf_misura_gruppi: «identica» chiede tutti i campioni di Atlas (minore M5)", {
  atlas <- p(GSM1 = "a", GSM2 = "a", GSM3 = "b", GSM4 = "b")
  m <- tf_misura_gruppi(p(GSM1 = "x", GSM2 = "x", GSM3 = "y"), atlas)
  expect_equal(m$classe, "identica_sui_comuni"); expect_equal(m$solo_atlas, 1L)
  # un nostro campione in più non è un campione di Atlas omesso
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "x", GSM3 = "y", GSM4 = "y", GSM9 = "y"), atlas)$classe, "identica")
})

# Atlas finto con un fattore annidato: lo stadio vale solo per i malati.
atlas_stadio <- function() {
  campioni <- sprintf("GSM%d", 1:8)
  livelli <- data.frame(malattia = rep(c("normal", "CD", "CD", "normal"), each = 2),
                        stadio = rep(c(TF_NON_APPLICABILE, "B1", "B2", TF_NON_APPLICABILE), each = 2),
                        sede = rep(c("ileo", "ileo", "ileo", "colon"), each = 2),
                        row.names = campioni, stringsAsFactors = FALSE)
  fattori <- data.frame(nome = c("malattia", "stadio", "sede"), tipo = "contesto", base = NA_character_)
  partizione <- stats::setNames(rep(c("g1", "g2", "g3", "g4"), each = 2), campioni)
  membri <- function(g) names(partizione)[partizione == g]
  rif <- c("g1", "g2", "g4", "g1"); test <- c("g2", "g3", "g3", "g4")
  confronti <- data.frame(studio = "GSE0", id = paste0(rif, "_", test), nome = NA_character_,
                          riferimento = rif, test = test, stringsAsFactors = FALSE)
  confronti$trattato <- lapply(test, membri); confronti$controllo <- lapply(rif, membri)
  list(tabella = tf_tabella(campioni, livelli, fattori), partizione = partizione, confronti = confronti,
       esclusi = data.frame(run = character(0), gruppo = character(0)))
}
test_that("il fattore annidato nei confronti di Atlas: con la regola non conta, senza è una differenza ordinaria", {
  a <- atlas_stadio(); u <- names(a$partizione)
  cl <- tf_classi_confronti_atlas(a, u)
  expect_equal(cl$classe, c("rispetta", "rispetta", "piu_fattori", "rispetta"))
  expect_equal(cl$fattori_diversi, c("malattia", "stadio", "malattia, sede, stadio", "sede"))
  expect_equal(cl$fattori_annidati, c("stadio", "", "", ""))
  senza <- tf_classi_confronti_atlas(a, u, annidato = FALSE)
  expect_equal(senza$classe, c("piu_fattori", "rispetta", "piu_fattori", "rispetta"))
  expect_equal(senza$fattori_diversi, c("malattia, stadio", "stadio", "malattia, sede, stadio", "sede"))
  # (c): un nostro confronto non elencato fra malati B2 e sani dello stesso ileo è coerente con la regola
  ne <- tf_giudica_non_elencati(nostro(c("GSM5", "GSM6"), c("GSM1", "GSM2")), a, u)
  expect_equal(ne$giudizio, "coerente")
  expect_equal(tf_giudica_non_elencati(nostro(c("GSM5", "GSM6"), c("GSM1", "GSM2")), a, u, annidato = FALSE)$giudizio,
               "piu_fattori")
})
test_that("un confronto di Atlas che differisce solo in un livello «non applicabile» non rispetta la definizione", {
  a <- atlas_stadio(); t <- unclass(a$tabella)
  t$livelli$malattia <- NULL; t$fattori <- t$fattori[t$fattori$nome != "malattia", ]
  a$tabella <- tf_tabella(t$campioni, t$livelli, t$fattori)
  cl <- tf_classi_confronti_atlas(a, names(a$partizione))
  expect_equal(cl$classe[1], "non_applicabile"); expect_equal(cl$fattori_diversi[1], "stadio")
  expect_equal(tf_classi_confronti_atlas(a, names(a$partizione), annidato = FALSE)$classe[1], "rispetta")
})
test_that("la lettura stretta: un fattore non scritto in un braccio conta come differenza", {
  a <- atlas_dose(); u <- names(a$partizione)
  cl <- tf_classi_confronti_atlas(a, u, non_scritto_conta = TRUE)
  expect_equal(cl$classe, c("piu_fattori", "rispetta", "rispetta", "piu_fattori"))
  expect_equal(cl$fattori_diversi[c(1, 4)], c("dose, farmaco", "dose, farmaco, linea"))
  ne <- tf_giudica_non_elencati(nostro(c("GSM5", "GSM6"), c("GSM1", "GSM2")), a, u, non_scritto_conta = TRUE)
  expect_equal(ne$giudizio, "piu_fattori")
})

test_that(".tf_classe_tempo: un solo numero uguale a zero, un solo numero maggiore di zero, il resto", {
  v <- c("0", "00h", "0 hour", "0 min", "day 0", "2 hour", "24hrs after treatment", "embryoid body, day 17", "0.5 h",
         "control", "", "0 to 2 h", "pre-LVAD", NA)
  expect_equal(.tf_classe_tempo(v), c(rep("zero", 5), rep("successivo", 4), rep("altro", 5)))
})
test_that("tf_tempo_zero: un braccio tutto a zero contro un braccio con un tempo successivo, in ogni verso", {
  campo <- list(tempo = c(GSM1 = "0 hour", GSM2 = "0 hour", GSM3 = "2 hour", GSM4 = "2 hour", GSM5 = "control",
                          GSM6 = "control", GSM7 = "4 hour"))
  z <- function(t, c, k = campo) tf_tempo_zero(t, c, k)
  expect_equal(z(c("GSM3", "GSM4"), c("GSM1", "GSM2")), list(tempo_zero = TRUE, verso = "zero_controllo", campo = "tempo"))
  expect_equal(z(c("GSM1", "GSM2"), c("GSM3", "GSM4"))$verso, "zero_trattato")
  expect_false(z(c("GSM1", "GSM2"), c("GSM5", "GSM6"))$tempo_zero)          # zero contro un valore senza numero
  expect_false(z(c("GSM3", "GSM4"), c("GSM7"))$tempo_zero)                  # nessun braccio a zero
  expect_false(z(c("GSM1", "GSM3"), c("GSM4", "GSM7"))$tempo_zero)          # un braccio misto non è «tutto a zero»
  expect_false(z(c("GSM3", "GSM1"), c("GSM1", "GSM2"))$tempo_zero)          # l'altro braccio ha un campione a zero
  expect_true(z(c("GSM3", "GSM5"), c("GSM1", "GSM2"))$tempo_zero)           # basta un campione a un tempo successivo
  expect_false(z(c("GSM3", "GSM4"), c("GSM1", "GSM2"), list())$tempo_zero)  # nessun campo di tempo
  expect_true(is.na(z(c("GSM3", "GSM4"), c("GSM7"))$verso))
  # un campione senza valore nel campo non è a zero
  expect_false(z(c("GSM3", "GSM4"), c("GSM1", "GSM99"))$tempo_zero)
  # basta un campo su due
  due <- c(campo, list(altro = c(GSM1 = "x", GSM2 = "x", GSM3 = "y", GSM4 = "y")))
  expect_true(tf_tempo_zero(c("GSM3", "GSM4"), c("GSM1", "GSM2"), due[c("altro", "tempo")])$tempo_zero)
})
test_that("tf_campi_di_tempo: il nome ha «time» all'inizio di una parola; fattori di Atlas e colonne non costanti di GEO", {
  a <- atlas_2x2(); t <- unclass(a$tabella)
  names(t$livelli) <- c("Sampling Time point", "linea"); t$fattori$nome <- names(t$livelli)
  a$tabella <- tf_tabella(t$campioni, t$livelli, t$fattori)
  gsm <- a$tabella$campioni
  geo <- list(timepoint = stats::setNames(rep(c("0", "2"), 4), gsm), `time-point` = stats::setNames(rep("0", 8), gsm),
              daytime = stats::setNames(rep(c("am", "pm"), 4), gsm), duration = stats::setNames(rep(c("0", "2"), 4), gsm),
              `differentiation time` = stats::setNames(rep(c("d1", "d2"), 4), gsm))
  k <- tf_campi_di_tempo(a, geo)
  expect_setequal(names(k), c("atlas:Sampling Time point", "geo:timepoint", "geo:differentiation time"))
  expect_equal(k[["geo:timepoint"]][["GSM2"]], "2")
  expect_equal(names(tf_campi_di_tempo(a, NULL)), "atlas:Sampling Time point")
  expect_error(tf_campi_di_tempo(a, list(time = c("0", "2"))), class = "simulomicsr_tf_ingresso_non_valido")
})

# Atlas finto con un tempo zero usato come controllo: 0 h, veicolo a 24 h, farmaco a 24 h.
atlas_tempo <- function() {
  campioni <- sprintf("GSM%d", 1:6)
  livelli <- data.frame(farmaco = rep(c("nessuno", "nessuno", "X"), each = 2),
                        time = rep(c("0 hour", "24 hour", "24 hour"), each = 2),
                        row.names = campioni, stringsAsFactors = FALSE)
  fattori <- data.frame(nome = c("farmaco", "time"), tipo = "contesto", base = NA_character_)
  partizione <- stats::setNames(rep(c("g1", "g2", "g3"), each = 2), campioni)
  membri <- function(g) names(partizione)[partizione == g]
  rif <- c("g1", "g2", "g1"); test <- c("g2", "g3", "g3")
  confronti <- data.frame(studio = "GSE0", id = paste0(rif, "_", test), nome = NA_character_,
                          riferimento = rif, test = test, stringsAsFactors = FALSE)
  confronti$trattato <- lapply(test, membri); confronti$controllo <- lapply(rif, membri)
  list(tabella = tf_tabella(campioni, livelli, fattori), partizione = partizione, confronti = confronti,
       esclusi = data.frame(run = character(0), gruppo = character(0)))
}
test_that("la marca tempo_zero è indipendente dalla classe e decide il denominatore di (b) secondo la lettura", {
  a <- atlas_tempo(); u <- names(a$partizione); campi <- tf_campi_di_tempo(a, NULL)
  cl <- tf_classi_confronti_atlas(a, u, campi_tempo = campi)
  expect_equal(cl$classe, c("rispetta", "rispetta", "piu_fattori"))
  expect_equal(cl$tempo_zero, c(TRUE, FALSE, TRUE))
  expect_equal(cl$tempo_zero_verso, c("zero_controllo", NA, "zero_controllo"))
  # noi formiamo tutti e tre i confronti di Atlas
  m <- function(lettura, ...) tf_misura_studio("GSE0", a$partizione, forma(a$confronti), a, u, lettura = lettura, ...)$riga
  forma <- function(k) k[c("studio", "id", "trattato", "controllo")]
  pr <- m("principale", campi_tempo = campi)
  expect_equal(c(pr$n_rispetta, pr$n_b_den, pr$n_b_uguale, pr$n_tempo_zero, pr$n_tempo_zero_rispetta), c(2L, 1L, 1L, 2L, 1L))
  int <- m("intera", campi_tempo = campi)
  expect_equal(c(int$n_rispetta, int$n_b_den, int$n_b_uguale, int$n_tempo_zero), c(2L, 2L, 2L, 2L))
  st <- m("stretta", campi_tempo = campi)
  expect_equal(c(st$n_b_den, st$n_b_uguale), c(1L, 1L))
  expect_equal(c(pr$lettura, int$lettura, st$lettura), c("principale", "intera", "stretta"))
  # la lettura si dichiara sempre, e la principale e la stretta chiedono i campi di tempo
  expect_error(tf_misura_studio("GSE0", a$partizione, forma(a$confronti), a, u), class = "simulomicsr_tf_ingresso_non_valido")
  expect_error(m("principale"), class = "simulomicsr_tf_ingresso_non_valido")
  expect_error(m("larga", campi_tempo = campi), class = "simulomicsr_tf_ingresso_non_valido")
  expect_equal(m("intera")$n_b_den, 2L); expect_true(is.na(m("intera")$n_tempo_zero))
})
test_that("tf_riassumi_misure: la misura (b) usa il denominatore della lettura, e le identiche con campioni omessi stanno a parte", {
  a <- atlas_tempo(); u <- names(a$partizione); campi <- tf_campi_di_tempo(a, NULL)
  forma <- function(k) k[c("studio", "id", "trattato", "controllo")]
  pr <- tf_misura_studio("s1", a$partizione, forma(a$confronti)[1, ], a, u, lettura = "principale", campi_tempo = campi)$riga
  # ritroviamo solo il confronto col tempo zero: nella lettura principale non conta
  r <- tf_riassumi_misure(pr, B = 20L, seme = 1L); riga <- function(m) r[r$misura == m, ]
  expect_equal(c(riga("b_confronti_ritrovati")$numeratore, riga("b_confronti_ritrovati")$denominatore), c(0, 1))
  expect_equal(c(riga("atlas_tempo_zero")$numeratore, riga("atlas_tempo_zero")$denominatore), c(2, 3))
  omessi <- tf_misura_studio("s2", a$partizione[-1], forma(a$confronti)[0, ], a, u, lettura = "principale", campi_tempo = campi)$riga
  expect_equal(omessi$classe_gruppi, "identica_sui_comuni")
  r2 <- tf_riassumi_misure(rbind(pr, omessi), B = 20L, seme = 1L); riga <- function(m) r2[r2$misura == m, ]
  expect_equal(c(riga("a_gruppi_identici")$numeratore, riga("a_gruppi_identici")$denominatore), c(1, 2))
  expect_equal(c(riga("a_identici_sui_comuni")$numeratore, riga("a_identici_sui_comuni")$denominatore), c(1, 2))
})
