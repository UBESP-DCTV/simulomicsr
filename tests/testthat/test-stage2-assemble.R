# TDD per .assemble_stage2_study() — integrazione collect per UNO studio (F4 C).
# Lega .merge_chunked_designs + .build_member_lookup + .expand_study_design:
# da (record input v3 dello studio) + (output LLM per record_id) -> study_design
# finale a campioni reali.

ia_input <- function(series, conds, chunked = FALSE) {
  # conds: list of list(geo, members)
  mk_rec <- function(rid, cc) {
    samples <- lapply(seq_along(cc), function(i) list(
      geo_accession = cc[[i]]$geo, sample_facts = list(),
      n_replicates = length(cc[[i]]$members),
      member_sample_ids = as.list(cc[[i]]$members),
      condition_id = sprintf("cond_%04d", i)))
    list(record_id = rid, series_id = series, samples = samples)
  }
  if (!chunked) list(mk_rec(series, conds))
  else lapply(seq_along(conds), function(i)
    mk_rec(sprintf("%s#%dof%d", series, i, length(conds)), conds[[i]]))
}

ia_design <- function(series, groups, comps = list(), kind = "treatment_vs_vehicle") {
  list(series_id = series, design_kind = kind, design_summary = "s",
       factors = list(), replicate_groups = groups, comparisons = comps,
       extraction = list(schema_version = "stage2.v2"))
}
ia_g <- function(gid, reps, role = "treated") list(group_id = gid,
  sample_ids = as.list(reps), primary_role = role, label_human = gid,
  factor_levels = list())

test_that("studio non chunkato: 1 record + 1 output -> espanso a membri reali", {
  inp <- ia_input("GSE1", list(list(geo = "GSM1", members = c("GSM1", "GSM2")),
                               list(geo = "GSM3", members = c("GSM3", "GSM4"))))
  out_llm <- list(GSE1 = ia_design("GSE1", list(
    ia_g("g1", "GSM1", "treated"), ia_g("g2", "GSM3", "control"))))
  res <- .assemble_stage2_study(inp, out_llm)
  expect_setequal(as.character(res$replicate_groups[[1]]$sample_ids), c("GSM1", "GSM2"))
  expect_setequal(as.character(res$replicate_groups[[2]]$sample_ids), c("GSM3", "GSM4"))
})

test_that("studio chunkato: 2 record + 2 output -> fusi ed espansi", {
  # controllo broadcast GSMc (membri GSMc,GSMc2) in entrambi i chunk
  ctrl <- list(geo = "GSMc", members = c("GSMc", "GSMc2"))
  inp <- ia_input("GSE2", list(
    list(list(geo = "GSMa", members = c("GSMa", "GSMa2")), ctrl),
    list(list(geo = "GSMb", members = c("GSMb", "GSMb2")), ctrl)),
    chunked = TRUE)
  out_llm <- list(
    `GSE2#1of2` = ia_design("GSE2", list(ia_g("a", "GSMa"), ia_g("c1", "GSMc", "control")),
                            list(list(comparison_id = "k1", treated_group = "a",
                                      control_group = "c1", control_type = "vehicle"))),
    `GSE2#2of2` = ia_design("GSE2", list(ia_g("b", "GSMb"), ia_g("c2", "GSMc", "control")),
                            list(list(comparison_id = "k2", treated_group = "b",
                                      control_group = "c2", control_type = "vehicle"))))
  res <- .assemble_stage2_study(inp, out_llm)
  # 3 gruppi (GSMa, GSMb, GSMc broadcast dedup), tutti espansi
  expect_length(res$replicate_groups, 3L)
  allids <- sort(unique(unlist(lapply(res$replicate_groups,
    function(g) as.character(unlist(g$sample_ids))))))
  expect_setequal(allids, c("GSMa", "GSMa2", "GSMb", "GSMb2", "GSMc", "GSMc2"))
  expect_length(res$comparisons, 2L)
})

test_that("nessun output LLM per lo studio -> NULL", {
  inp <- ia_input("GSE9", list(list(geo = "GSM1", members = "GSM1")))
  expect_null(.assemble_stage2_study(inp, list()))
})
