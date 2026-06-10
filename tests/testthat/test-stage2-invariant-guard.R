# TDD per .assert_stage2_one_record_per_series() — RED ALERT F4 opzione C.
#
# Sostituisce .reassemble_stage2_chunks (superata da opzione C). Lo Stadio 2 v3
# produce UN record per studio; se il master contiene series_id duplicati (input
# chunked inatteso) il guard FALLISCE rumorosamente invece di riassemblare in
# silenzio nel modo sbagliato (la vecchia reassemble perdeva i confronti
# cross-chunk, finding 2026-06-01).

test_that("master 1-record-per-series passa invariato", {
  m <- list(list(series_id = "GSE1", replicate_groups = list()),
            list(series_id = "GSE2", replicate_groups = list()))
  expect_identical(.assert_stage2_one_record_per_series(m), m)
})

test_that("series_id duplicato -> errore esplicito", {
  m <- list(list(series_id = "GSE1"), list(series_id = "GSE1"))
  expect_error(.assert_stage2_one_record_per_series(m), "Invariante Stadio 2")
})

test_that("il messaggio nomina le series colpevoli", {
  m <- list(list(series_id = "GSE7"), list(series_id = "GSE7"))
  expect_error(.assert_stage2_one_record_per_series(m), "GSE7")
})

test_that("record senza series_id non innescano errore", {
  m <- list(list(series_id = "GSE1"), list(replicate_groups = list()))
  expect_identical(.assert_stage2_one_record_per_series(m), m)
})

test_that("lista vuota -> lista vuota", {
  expect_identical(.assert_stage2_one_record_per_series(list()), list())
})
