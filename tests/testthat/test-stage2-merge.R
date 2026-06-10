# TDD per .merge_chunked_designs() — fusione dei chunk di uno studio (F4 opzione C).
#
# Studi chunkati: N study_design (1/chunk, a rappresentanti). I controlli sono
# broadcastati in ogni chunk -> lo stesso gruppo (per insieme di rappresentanti)
# compare in piu' chunk e va deduplicato in uno solo; i group_id per-chunk
# collidono e vanno rigenerati canonici; i comparisons si uniscono e si rimappano.
# I confronti sono gia' intra-chunk (controllo presente per broadcast) -> nessuna
# ricostruzione cross-chunk.

mg_g <- function(gid, reps, role = "treated") {
  list(group_id = gid, sample_ids = as.list(reps), primary_role = role,
       label_human = gid, factor_levels = list())
}
mg_c <- function(cid, tg, cg, ct = "vehicle") {
  list(comparison_id = cid, treated_group = tg, control_group = cg,
       control_type = ct)
}
mg_d <- function(series = "GSE1", kind = "treatment_vs_vehicle", summary = "s",
                 groups = list(), comps = list()) {
  list(series_id = series, design_kind = kind, design_summary = summary,
       factors = list(), replicate_groups = groups, comparisons = comps,
       extraction = list(schema_version = "stage2.v2"))
}

# due chunk con controllo broadcast GSMc (group_id diverso per chunk)
two_chunks <- function() list(
  mg_d(groups = list(mg_g("a", "GSMa", "treated"),
                     mg_g("c1", "GSMc", "control")),
       comps = list(mg_c("k1", "a", "c1"))),
  mg_d(kind = "unclear",
       groups = list(mg_g("b", "GSMb", "treated"),
                     mg_g("c2", "GSMc", "unclear")),
       comps = list(mg_c("k2", "b", "c2")))
)

test_that("un solo design -> ritornato invariato", {
  d <- mg_d(groups = list(mg_g("a", "GSMa")))
  expect_identical(.merge_chunked_designs(list(d)), d)
})

test_that("controllo broadcast deduplicato: 3 insiemi distinti -> 3 gruppi", {
  out <- .merge_chunked_designs(two_chunks())
  expect_length(out$replicate_groups, 3L)
  reps <- lapply(out$replicate_groups, function(g) sort(as.character(unlist(g$sample_ids))))
  expect_true(list("GSMc") %in% reps)
  expect_true(list("GSMa") %in% reps)
  expect_true(list("GSMb") %in% reps)
})

test_that("group_id canonici e unici", {
  out <- .merge_chunked_designs(two_chunks())
  gids <- vapply(out$replicate_groups, function(g) g$group_id, character(1))
  expect_length(unique(gids), 3L)
})

test_that("comparisons uniti e rimappati a group_id validi", {
  out <- .merge_chunked_designs(two_chunks())
  gids <- vapply(out$replicate_groups, function(g) g$group_id, character(1))
  expect_length(out$comparisons, 2L)
  for (cmp in out$comparisons) {
    expect_true(cmp$treated_group %in% gids)
    expect_true(cmp$control_group %in% gids)
  }
})

test_that("primary_role: control vince sul conflitto del controllo broadcast", {
  out <- .merge_chunked_designs(two_chunks())
  gc <- Filter(function(g) identical(as.character(unlist(g$sample_ids)), "GSMc"),
               out$replicate_groups)[[1]]
  expect_identical(gc$primary_role, "control")
})

test_that("design_kind = moda non-unclear", {
  out <- .merge_chunked_designs(two_chunks())  # kinds: treatment_vs_vehicle, unclear
  expect_identical(out$design_kind, "treatment_vs_vehicle")
})

test_that("design_summary dal chunk con piu' comparisons", {
  designs <- list(
    mg_d(summary = "due", groups = list(mg_g("a", "GSMa"), mg_g("c1", "GSMc", "control")),
         comps = list(mg_c("k1", "a", "c1"), mg_c("k1b", "a", "c1", "untreated"))),
    mg_d(summary = "uno", groups = list(mg_g("b", "GSMb"), mg_g("c2", "GSMc", "control")),
         comps = list(mg_c("k2", "b", "c2")))
  )
  out <- .merge_chunked_designs(designs)
  expect_identical(out$design_summary, "due")
})
