rec <- function() list(series_id = "GSE1",
  replicate_groups = list(list(group_id = "grp_0001", sample_ids = list("GSM1", "GSM2")),
                          list(group_id = "grp_0002", sample_ids = "GSM3")),      # scalare: Review Focus 1
  comparisons = list(list(comparison_id = "c1", treated_group = "grp_0002", control_group = "grp_0001")))
test_that("tf_da_stage2: sample_ids scalare o lista, confronti in forma comune", {
  r <- tf_da_stage2(rec())
  expect_equal(r$partizione, c(GSM1 = "grp_0001", GSM2 = "grp_0001", GSM3 = "grp_0002"))
  expect_equal(r$confronti$trattato[[1]], "GSM3"); expect_equal(r$confronti$controllo[[1]], c("GSM1", "GSM2"))
  expect_equal(r$confronti$studio, "GSE1")
})
test_that("tf_da_stage2: nessun confronto dà una tabella vuota; un campione in due gruppi è un errore", {
  x <- rec(); x$comparisons <- list()
  expect_equal(nrow(tf_da_stage2(x)$confronti), 0L)
  x <- rec(); x$replicate_groups[[2]]$sample_ids <- "GSM1"
  expect_error(tf_da_stage2(x), class = "simulomicsr_tf_stage2_campione_in_due_gruppi")
})
test_that("tf_da_stage2: record senza gruppi, colonne giuste a zero righe, gruppo ignoto in un confronto", {
  x <- rec(); x$replicate_groups <- NULL; x$comparisons <- NULL
  r <- tf_da_stage2(x)
  expect_length(r$partizione, 0L); expect_equal(nrow(r$confronti), 0L)
  expect_true(all(c("studio", "id", "trattato", "controllo") %in% names(r$confronti)))
  expect_true(is.list(r$confronti$trattato))
  x <- rec(); x$comparisons[[1]]$control_group <- "grp_9999"
  expect_error(tf_da_stage2(x), class = "simulomicsr_tf_stage2_gruppo_ignoto")
  x <- rec(); x$replicate_groups[[1]]$sample_ids <- list("GSM2", "GSM1")
  expect_equal(tf_da_stage2(x)$confronti$controllo[[1]], c("GSM1", "GSM2"))     # i bracci sono ordinati
  expect_equal(tf_da_stage2(x)$confronti$id, "c1")
})
test_that("tf_da_stage2: un GSM ripetuto in un gruppo dà un avviso che lo nomina; l'ordine non dipende dal locale (M6)", {
  x <- rec(); x$replicate_groups[[1]]$sample_ids <- list("GSM2", "GSM1", "GSM2")
  expect_warning(r <- tf_da_stage2(x), "GSM2", class = "simulomicsr_tf_stage2_campione_ripetuto")
  expect_equal(r$confronti$controllo[[1]], c("GSM1", "GSM2"))
  x <- rec(); x$replicate_groups[[1]]$sample_ids <- list("GSMb", "GSMB", "GSMa")
  expect_equal(names(tf_da_stage2(x)$partizione)[1:3], c("GSMB", "GSMa", "GSMb"))   # ordine dei byte
})
test_that("tf_da_stage2: un confronto senza un gruppo dà un errore che nomina studio e confronto (M6)", {
  x <- rec(); x$comparisons[[1]]$control_group <- NULL
  expect_error(tf_da_stage2(x), "GSE1.*c1", class = "simulomicsr_tf_stage2_record_non_valido")
  x <- rec(); x$comparisons[[1]]$treated_group <- list()
  expect_error(tf_da_stage2(x), "GSE1.*c1", class = "simulomicsr_tf_stage2_record_non_valido")
})
