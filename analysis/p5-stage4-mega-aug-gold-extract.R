# Estrazione candidati hand-curated per test 5.1 (findings MEGA-AUG bidirezionale)
#
# Genera un CSV in inst/extdata/p5-mega-aug-anchor-matching-gold.csv con
# 30 coppie (pair_cluster, baseline_cluster) candidate al match anchor.
#
# Stratificazione:
# - 10 candidati STRICT-OK   : strict e relaxed concordano TRUE.
# - 10 candidati RELAXED-ONLY: strict = FALSE, relaxed = TRUE (la zona grigia
#                              su cui il sensitivity test 5.3 si gioca).
# - 10 candidati MISMATCH    : entrambi FALSE (controllo: la matrice attesa
#                              "non-match" non deve essere etichettata match
#                              dall'utente).
#
# L'utente etichetta a mano la colonna `human_label`:
#   match    = baseline biologicamente valido come braccio della pair
#   dubbio   = caso ambiguo (commento richiesto in `human_note`)
#   no_match = baseline NON usabile (commento richiesto)
#
# Output: inst/extdata/p5-mega-aug-anchor-matching-gold.csv (TBD per
# annotation), con colonne:
#   stratum, pair_cluster_id, pair_level, pair_anchor_key,
#   pair_treated_anchor, pair_control_anchor, pair_comparison_type,
#   baseline_cluster_id, baseline_anchor_key,
#   baseline_n_total, baseline_n_studies, baseline_studies,
#   strict_match, relaxed_match, human_label, human_note
#
# Run:
#   Rscript --vanilla analysis/p5-stage4-mega-aug-gold-extract.R

suppressPackageStartupMessages({
  library(simulomicsr)
})

set.seed(42L)

CLUSTERS_RDS <- "analysis/p4-output/20260519T055547Z-stage3-2153addc/clusters.rds"
OUT_CSV      <- "inst/extdata/p5-mega-aug-anchor-matching-gold.csv"

stopifnot(file.exists(CLUSTERS_RDS))

clusters <- readRDS(CLUSTERS_RDS)
cat("Clusters totali:", nrow(clusters), "\n")

# --- 1. Filtra Layer A pair + group baseline pool ---------------------------
layer_a <- clusters[
  clusters$usable_mega_strict | clusters$usable_mega_relaxed |
    clusters$usable_rem_strict | clusters$usable_rem_relaxed,
]
pair_la  <- layer_a[layer_a$mode == "pair", ]
group_la <- layer_a[layer_a$mode == "group", ]
cat("Pair cluster Layer A:    ", nrow(pair_la), "\n")
cat("Group cluster Layer A:   ", nrow(group_la), "\n")

# Per ogni pair, splitta l'anchor in treated|control via parse_pair_anchor_key.
# Skippiamo pair con parsing che fallisce (anchor malformati / level mismatch).
pair_parsed <- vector("list", nrow(pair_la))
for (i in seq_len(nrow(pair_la))) {
  parsed <- tryCatch(
    parse_pair_anchor_key(pair_la$anchor_key[i], level = pair_la$level[i]),
    error = function(e) NULL
  )
  pair_parsed[[i]] <- parsed
}
ok_pair <- which(!vapply(pair_parsed, is.null, logical(1L)))
cat("Pair anchor parsabili:   ", length(ok_pair), "/", nrow(pair_la), "\n")

# --- 2. Per ogni pair, cerca group baseline candidati al match control ------
# Approccio: indicizza i group baseline per level + tier S
# (kind_effective + agent_id + tissue) per ridurre la ricerca.
matcher_strict  <- make_anchor_matcher("strict")
matcher_relaxed <- make_anchor_matcher("relaxed")

# Pre-parse di tutti i group baseline (per level).
group_parsed <- vector("list", nrow(group_la))
for (i in seq_len(nrow(group_la))) {
  parsed <- tryCatch(
    parse_anchor_canonical(group_la$anchor_key[i], level = group_la$level[i]),
    error = function(e) NULL
  )
  group_parsed[[i]] <- parsed
}
ok_group <- which(!vapply(group_parsed, is.null, logical(1L)))
cat("Group anchor parsabili: ", length(ok_group), "/", nrow(group_la), "\n")

# --- 3. Collect candidates -------------------------------------------------
# Per ogni pair, scan group baseline allo stesso level con stesso tier S su
# control_anchor. Classify match per strict + relaxed.
candidates <- list()
for (pi in ok_pair) {
  pair_row <- pair_la[pi, ]
  parsed   <- pair_parsed[[pi]]
  ctrl     <- parsed$control

  # Filter group: stesso level + match veloce su S (kind+agent+tissue)
  gidx <- ok_group[group_la$level[ok_group] == pair_row$level]
  for (gi in gidx) {
    gparsed <- group_parsed[[gi]]
    # Quick filter: tier S match (S sempre presente)
    if (!identical(gparsed[["kind_effective"]], ctrl[["kind_effective"]])) next
    if (!identical(gparsed[["agent_id"]], ctrl[["agent_id"]])) next
    if (!identical(gparsed[["tissue"]], ctrl[["tissue"]])) next
    # Slow filter: full match strict / relaxed
    sm <- matcher_strict(ctrl, gparsed)
    rm <- matcher_relaxed(ctrl, gparsed)
    candidates[[length(candidates) + 1L]] <- list(
      pi = pi, gi = gi, strict = sm, relaxed = rm
    )
  }
}
cat("Candidati totali (pair x group con tier S match):", length(candidates), "\n")

if (length(candidates) == 0L) {
  stop("Nessun candidato — impossibile generare il mini-gold")
}

cand_df <- data.frame(
  pi      = vapply(candidates, function(x) x$pi, integer(1L)),
  gi      = vapply(candidates, function(x) x$gi, integer(1L)),
  strict  = vapply(candidates, function(x) x$strict, logical(1L)),
  relaxed = vapply(candidates, function(x) x$relaxed, logical(1L))
)
cat("\nDistribuzione candidati per (strict, relaxed):\n")
print(table(strict = cand_df$strict, relaxed = cand_df$relaxed))

# --- 4. Stratificazione -----------------------------------------------------
# 10 strict TRUE + relaxed TRUE (full match)
# 10 strict FALSE + relaxed TRUE (zona grigia, sensitivity)
# 10 strict FALSE + relaxed FALSE (controllo non-match nonostante tier S match)
N_PER_STRATUM <- 10L

pool_strict_ok  <- cand_df[cand_df$strict & cand_df$relaxed, ]
pool_relax_only <- cand_df[!cand_df$strict & cand_df$relaxed, ]
pool_mismatch   <- cand_df[!cand_df$strict & !cand_df$relaxed, ]

sample_or_all <- function(df, n) {
  if (nrow(df) <= n) return(df)
  df[sample(nrow(df), n), , drop = FALSE]
}

picked <- rbind(
  cbind(stratum = "strict_ok",     sample_or_all(pool_strict_ok,  N_PER_STRATUM)),
  cbind(stratum = "relaxed_only",  sample_or_all(pool_relax_only, N_PER_STRATUM)),
  cbind(stratum = "mismatch",      sample_or_all(pool_mismatch,   N_PER_STRATUM))
)
cat("\nPicked per stratum:\n")
print(table(picked$stratum))

# --- 5. Tibble di output ----------------------------------------------------
out_rows <- list()
for (k in seq_len(nrow(picked))) {
  r        <- picked[k, ]
  pair_row <- pair_la[r$pi, ]
  group_row <- group_la[r$gi, ]
  parsed   <- pair_parsed[[r$pi]]
  # Render treated/control re-encoded
  treated_str <- paste(unlist(parsed$treated), collapse = "|")
  control_str <- paste(unlist(parsed$control), collapse = "|")
  out_rows[[k]] <- data.frame(
    stratum               = r$stratum,
    pair_cluster_id       = pair_row$cluster_id,
    pair_level            = pair_row$level,
    pair_anchor_key       = pair_row$anchor_key,
    pair_treated_anchor   = treated_str,
    pair_control_anchor   = control_str,
    pair_comparison_type  = parsed$comparison_type %||% NA_character_,
    baseline_cluster_id   = group_row$cluster_id,
    baseline_anchor_key   = group_row$anchor_key,
    baseline_n_total      = group_row$n_total,
    baseline_n_studies    = group_row$n_studies,
    baseline_studies      = paste(unlist(group_row$studies_in_cluster), collapse = ","),
    strict_match          = r$strict,
    relaxed_match         = r$relaxed,
    human_label           = "TBD",
    human_note            = "",
    stringsAsFactors      = FALSE
  )
}
out <- do.call(rbind, out_rows)

dir.create(dirname(OUT_CSV), showWarnings = FALSE, recursive = TRUE)
write.csv(out, OUT_CSV, row.names = FALSE)
cat("\n[OK] Mini-gold CSV scritto a:", OUT_CSV, "\n")
cat("Righe totali:", nrow(out), "\n\n")

cat("Preview prime 3 righe per stratum:\n")
print(out[c(1L, N_PER_STRATUM + 1L, 2L * N_PER_STRATUM + 1L),
          c("stratum", "pair_cluster_id", "baseline_cluster_id",
            "strict_match", "relaxed_match")])
