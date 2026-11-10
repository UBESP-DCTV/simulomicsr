test_that("configurazione: 4 gruppi da 4 run, 3 confronti con riferimento g4", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml"))
  expect_equal(as.integer(table(k$gruppi$gruppo)), c(4L, 4L, 4L, 4L))
  expect_setequal(k$gruppi$run[k$gruppi$gruppo == "g4"], c("SRR1039508", "SRR1039520", "SRR1039512", "SRR1039516"))
  expect_equal(k$confronti$id, c("g4_g1", "g4_g3", "g4_g2"))
  expect_true(all(k$confronti$riferimento == "g4")); expect_equal(k$confronti$test, c("g1", "g3", "g2"))
  s <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml"), solo_id = TRUE)
  expect_true(all(is.na(s$gruppi$etichetta))); expect_true(all(is.na(s$confronti$nome)))
})
test_that("sdrf: un fattore (treatment), 16 run, 4 livelli", {
  s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  f <- s[s$ruolo == "factor", ]
  expect_equal(unique(f$nome), "treatment"); expect_equal(nrow(f), 16L)
  expect_setequal(f$valore, c("untreated", "dexamethasone", "albuterol", "albuterol and dexamethasone"))
})
test_that("atlas_tabella: GSM al posto dei run, confronti in forma comune", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml")); s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  a <- atlas_tabella(k, s, legame_finto(unique(k$gruppi$run)))
  expect_equal(nrow(tf_gruppi(a$tabella)), 4L)
  c1 <- a$confronti[a$confronti$id == "g4_g1", ]
  expect_true("GSM1275862" %in% c1$controllo[[1]]); expect_equal(length(c1$trattato[[1]]), 4L)
})
test_that("più run per GSM si riducono al GSM; un GSM in due gruppi ferma lo studio (Review Focus 2)", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml")); s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  l <- legame_finto(unique(k$gruppi$run))
  l$gsm[l$run == "SRR1039520"] <- "GSM1275862"                      # due run di g4 sullo stesso GSM
  expect_equal(length(atlas_tabella(k, s, l)$tabella$campioni), 15L)
  l$gsm[l$run == "SRR1039509"] <- "GSM1275862"                      # un run di g3 sullo stesso GSM
  expect_error(atlas_tabella(k, s, l), class = "simulomicsr_tf_atlas_gsm_in_due_gruppi")
  l2 <- legame_finto(unique(k$gruppi$run)); l2 <- l2[l2$run != "SRR1039508", ]
  expect_equal(atlas_tabella(k, s, l2)$esclusi$run, "SRR1039508")
})
test_that("atlas_tabella: la partizione dei curatori, i confronti con i gruppi, un run senza fattori è un errore", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml")); s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  a <- atlas_tabella(k, s, legame_finto(unique(k$gruppi$run)))
  expect_equal(length(a$partizione), 16L); expect_equal(a$partizione[["GSM1275862"]], "g4")
  expect_equal(a$tabella$fattori$tipo, "contesto"); expect_true(is.na(a$tabella$fattori$base))
  expect_equal(a$tabella$livelli["GSM1275862", "treatment"], "untreated")
  c1 <- a$confronti[a$confronti$id == "g4_g1", ]
  expect_equal(c1$riferimento, "g4"); expect_equal(c1$test, "g1"); expect_equal(c1$nome, "'albuterol' vs 'untreated'")
  expect_equal(nrow(a$esclusi), 0L)
  s2 <- s[!(s$run == "SRR1039510" & s$ruolo == "factor"), ]
  expect_error(atlas_tabella(k, s2, legame_finto(unique(k$gruppi$run))), class = "simulomicsr_tf_atlas_run_senza_fattori")
})
test_that("atlas_tabella: un gruppo senza GSM lascia il confronto con un braccio vuoto, e i run esclusi si contano", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml")); s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  l <- legame_finto(unique(k$gruppi$run)); l <- l[!(l$run %in% k$gruppi$run[k$gruppi$gruppo == "g1"]), ]
  a <- atlas_tabella(k, s, l)
  expect_equal(nrow(a$esclusi), 4L); expect_equal(unique(a$esclusi$gruppo), "g1")
  expect_equal(nrow(a$confronti), 3L)
  expect_equal(length(a$confronti$trattato[[which(a$confronti$id == "g4_g1")]]), 0L)
  expect_equal(length(a$tabella$campioni), 12L)
})
test_that("solo_id non porta etichette nemmeno in atlas_tabella", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml"), solo_id = TRUE)
  expect_false(any(grepl("albuterol|dexamethasone|untreated", unlist(k))))
})
