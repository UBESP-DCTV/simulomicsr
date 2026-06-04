#!/usr/bin/env Rscript
# analysis/audit/F4-chunk-collision-repro.R
#
# RED ALERT FASE F4 — riproduzione minimale del difetto di risoluzione campioni
# per studi chunked (vedi docs/findings/2026-06-01-stage3-stage4-chunked-study-
# sample-resolution-bug.md).
#
# Difetto: i record_id di Stadio 3 sono `sprintf("%s__%s", series_id, suffix)`
# e Stadio 4 indicizza lo stage2_master per `series_id` (.index_stage2_master,
# assign last-wins). Uno studio splittato in N chunk (per il limite di contesto
# LLM, cs50) compare come N record con la STESSA series_id: a valle sopravvive
# solo l'ultimo chunk -> i campioni degli altri chunk vengono droppati o
# misrisolti.
#
# Esecuzione: Rscript analysis/audit/F4-chunk-collision-repro.R

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
source("tests/testthat/helper-stage3-fixtures.R")

run3 <- function(s1, s2) suppressMessages(build_stage3_clusters(s1, s2))
mk_chunk <- function(series, gid, sids, role = "treated") {
  list(series_id = series,
       replicate_groups = list(list(group_id = gid, sample_ids = as.list(sids),
                                    n = length(sids), primary_role = role)),
       comparisons = list())
}

# ── Stadio 3: il fix (riassemblaggio) risolve la collisione record_id ──────────
# Due chunk dello stesso studio, stesso label di gruppo, campioni DISGIUNTI.
# PRE-FIX: i due record collassavano su un solo record_id "GSET__tumor"
# (.summarize_clusters last-wins, GSM1/GSM2 persi per identita').
# POST-FIX: build_stage3_clusters riassembla e namespacizza per chunk ->
# 2 record_id distinti, entrambi vivi.
fact <- make_test_sample_fact()
s1 <- list(GSM1 = fact, GSM2 = fact, GSM3 = fact, GSM4 = fact)

A <- run3(s1, list(mk_chunk("GSET", "tumor", c("GSM1", "GSM2")),
                   mk_chunk("GSET", "tumor", c("GSM3", "GSM4"))))
asgA <- A$assignments[A$assignments$mode == "group" & A$assignments$level == 0, ]
cat("== Stadio 3, group_id collidente (post-fix) ==\n")
cat("record_id distinti nelle assignment del cluster L0:",
    paste(unique(asgA$record_id), collapse = ", "), "\n")
stopifnot(length(unique(asgA$record_id)) == 2L)
cat("  -> 2 record_id distinti (namespaced per chunk): collisione risolta.\n\n")

# I 2 record namespaced restano nello STESSO cluster: l'anchor fa il merge
# biologico (cluster_id deriva dall'anchor, non dal record_id).
cat("un solo cluster group L0:",
    length(unique(asgA$cluster_id)) == 1L, "\n\n")

# ── Stadio 4: dispatch perde i campioni dei chunk non-ultimi ──────────────────
# Studio a 2 chunk SENZA collisione group_id: il dispatch risolve solo l'ultimo.
stage2_chunked <- list(
  list(series_id = "GSE_X",
       replicate_groups = list(list(group_id = "A", sample_ids = list("GSM1", "GSM2"),
                                    primary_role = "treated")),
       comparisons = list()),
  list(series_id = "GSE_X",
       replicate_groups = list(list(group_id = "B", sample_ids = list("GSM3", "GSM4"),
                                    primary_role = "treated")),
       comparisons = list())
)
stage2_merged <- list(  # riassemblato: un record/series, union dei gruppi
  list(series_id = "GSE_X",
       replicate_groups = list(
         list(group_id = "A", sample_ids = list("GSM1", "GSM2"), primary_role = "treated"),
         list(group_id = "B", sample_ids = list("GSM3", "GSM4"), primary_role = "treated")),
       comparisons = list())
)
ec  <- tibble::tibble(cluster_id = "CL1", mode = "group", method = "mega")
asg <- tibble::tibble(record_id = c("GSE_X__A", "GSE_X__B"),
                      cluster_id = c("CL1", "CL1"), mode = "group",
                      level = 0L, anchor_key = "k")
got <- function(s2) {
  d <- simulomicsr:::.build_group_dispatch_from_stage3(ec, asg, s2)
  sort(unique(unlist(lapply(d[["CL1"]], function(x) x$sample_ids))))
}
cat("== Stadio 4, dispatch ==\n")
cat("chunked (bug):", paste(got(stage2_chunked), collapse = ","), "\n")
cat("merged (fix) :", paste(got(stage2_merged),  collapse = ","), "\n")
