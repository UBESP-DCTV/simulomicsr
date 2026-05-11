# Exp D2 — Test Op D revised su tutti i 23 pair ambiguous del gold.
# Rule decision tree:
#   1. Esattamente 1 GSE del pair ha SRP linked -> scegli quello (sub-method)
#   2. Entrambi hanno SRP -> truly ambiguous (2 sub legittime distinte), apply lower-accession fallback
#   3. Nessuno ha SRP -> fallback lower-accession + tag (pattern anomalo)
#
# Compara con baseline "rule lower-accession sempre" per misurare divergenza.

suppressMessages({
  library(rentrez)
  library(dplyr)
  library(stringr)
})

stopifnot(nzchar(Sys.getenv("NCBI_API_KEY")))
rentrez::set_entrez_key(Sys.getenv("NCBI_API_KEY"))

# ---- 1. Load ambiguous classification + identifica 23 pair ----
m <- readRDS("analysis/scratch/exp-a-multiseries-resolved.rds")
amb <- m[m$case == "ambiguous", ]
amb$pair_key <- paste(pmin(amb$primary, amb$secondary), pmax(amb$primary, amb$secondary), sep = "|")
pairs <- unique(amb$pair_key)
pair_split <- do.call(rbind, strsplit(pairs, "|", fixed = TRUE))
pair_df <- data.frame(
  pair_key = pairs,
  gse_a = pair_split[, 1],
  gse_b = pair_split[, 2],
  n_samples_in_pair = as.integer(table(amb$pair_key)[pairs]),
  stringsAsFactors = FALSE
)
cat(sprintf("23 pair ambiguous distinti, total %d sample\n", sum(pair_df$n_samples_in_pair)))

# ---- 2. Fetch extended metadata per tutti i GSE dei 23 pair ----
all_gses <- unique(c(pair_df$gse_a, pair_df$gse_b))
cat(sprintf("Fetching extended per %d GSE\n", length(all_gses)))

ext_cache_path <- "analysis/scratch/exp-d-entrez-extended.rds"
ext_cache <- if (file.exists(ext_cache_path)) readRDS(ext_cache_path) else list()

get_gse_uid <- function(gse) {
  s <- entrez_search(db = "gds", term = paste0(gse, "[Accession]"))
  if (length(s$ids) == 0) return(NA)
  gse_uids <- s$ids[grepl("^2[0-9]+$", s$ids)]
  if (length(gse_uids) > 0) gse_uids[1] else s$ids[1]
}

fetch_ext <- function(gse) {
  if (!is.null(ext_cache[[gse]])) return(ext_cache[[gse]])
  res <- tryCatch({
    uid <- get_gse_uid(gse)
    if (is.na(uid)) return(list(uid = NA, srp = NA, title = NA, pdat = NA, n_samples = NA))
    info <- entrez_summary(db = "gds", id = uid)
    srp <- NA
    if (length(info$extrelations) > 0 && is.data.frame(info$extrelations)) {
      sra_row <- info$extrelations[info$extrelations$relationtype == "SRA", ]
      if (nrow(sra_row) > 0) srp <- sra_row$targetobject[1]
    }
    list(
      uid = uid,
      srp = srp,
      title = info$title %||% NA,
      pdat = info$pdat %||% NA,
      n_samples = info$n_samples %||% NA,
      summary = info$summary %||% NA
    )
  }, error = function(e) list(uid = NA, srp = NA, title = NA, pdat = NA, n_samples = NA, error = conditionMessage(e)))
  ext_cache[[gse]] <<- res
  res
}

t0 <- Sys.time()
for (g in all_gses) fetch_ext(g)
saveRDS(ext_cache, ext_cache_path)
cat(sprintf("Fetch done in %.1f sec\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# ---- 3. Per ogni pair, classifica + apply Op D rule ----
detect_method_bracket <- function(title) {
  if (is.na(title)) return(FALSE)
  grepl("\\[(scRNA|RNA-Seq|RNA-seq|single-cell|bulk|ATAC|ChIP)|\\((scRNA|RNA-seq|bulk|ATAC|ChIP)", title, ignore.case = TRUE)
}

for (i in seq_len(nrow(pair_df))) {
  ga <- pair_df$gse_a[i]
  gb <- pair_df$gse_b[i]
  ea <- ext_cache[[ga]]
  eb <- ext_cache[[gb]]
  pair_df$srp_a[i] <- ea$srp %||% NA
  pair_df$srp_b[i] <- eb$srp %||% NA
  pair_df$title_a[i] <- substr(ea$title %||% "", 1, 100)
  pair_df$title_b[i] <- substr(eb$title %||% "", 1, 100)
  pair_df$n_a[i] <- ea$n_samples %||% NA
  pair_df$n_b[i] <- eb$n_samples %||% NA
  pair_df$pdat_a[i] <- ea$pdat %||% NA
  pair_df$pdat_b[i] <- eb$pdat %||% NA
  pair_df$has_method_a[i] <- detect_method_bracket(ea$title)
  pair_df$has_method_b[i] <- detect_method_bracket(eb$title)
}

# ---- 4. Apply Op D revised rule ----
classify_pair <- function(row) {
  has_a <- !is.na(row$srp_a) && nzchar(row$srp_a) && row$srp_a != "NA"
  has_b <- !is.na(row$srp_b) && nzchar(row$srp_b) && row$srp_b != "NA"
  if (has_a && !has_b) return(list(branch = "1_SRP_a_only", decision = row$gse_a))
  if (!has_a && has_b) return(list(branch = "1_SRP_b_only", decision = row$gse_b))
  if (has_a && has_b)  return(list(branch = "both_SRP_truly_ambiguous", decision = NA))  # tie
  return(list(branch = "no_SRP_fallback", decision = NA))  # tie
}

pair_df$branch <- NA_character_
pair_df$decision <- NA_character_
pair_df$tiebreak_used <- FALSE
for (i in seq_len(nrow(pair_df))) {
  c <- classify_pair(pair_df[i, ])
  pair_df$branch[i] <- c$branch
  if (!is.null(c$decision) && !is.na(c$decision)) {
    pair_df$decision[i] <- c$decision
  }
}

# Per i tie cases, lower-accession fallback
for (i in which(is.na(pair_df$decision))) {
  num_a <- as.numeric(gsub("GSE", "", pair_df$gse_a[i]))
  num_b <- as.numeric(gsub("GSE", "", pair_df$gse_b[i]))
  pair_df$decision[i] <- if (num_a < num_b) pair_df$gse_a[i] else pair_df$gse_b[i]
  pair_df$tiebreak_used[i] <- TRUE
}

# Compare with pure-rule baseline (always lower-accession)
pair_df$pure_rule_decision <- ifelse(
  as.numeric(gsub("GSE", "", pair_df$gse_a)) < as.numeric(gsub("GSE", "", pair_df$gse_b)),
  pair_df$gse_a, pair_df$gse_b
)
pair_df$op_d_vs_rule_agree <- pair_df$decision == pair_df$pure_rule_decision

# ---- 5. Report ----
cat("\n=== Distribuzione branch Op D ===\n")
print(table(pair_df$branch))
cat("\n=== Concordanza Op D vs Pure-Rule (lower-accession) ===\n")
cat(sprintf("Agree: %d / 23 (%.1f%%)\n",
            sum(pair_df$op_d_vs_rule_agree),
            100 * mean(pair_df$op_d_vs_rule_agree)))

cat("\n=== Tabella completa per pair ===\n")
print(pair_df[, c("pair_key", "n_samples_in_pair", "srp_a", "srp_b",
                  "has_method_a", "has_method_b",
                  "branch", "decision", "pure_rule_decision",
                  "op_d_vs_rule_agree", "tiebreak_used")])

cat("\n=== Sample-weighted distribution ===\n")
sw <- aggregate(n_samples_in_pair ~ branch, data = pair_df, sum)
print(sw)
cat(sprintf("Total sample con decisione SRP-driven: %d\n",
            sum(pair_df$n_samples_in_pair[grepl("^1_SRP", pair_df$branch)])))
cat(sprintf("Total sample con tiebreak fallback: %d\n",
            sum(pair_df$n_samples_in_pair[pair_df$tiebreak_used])))

# ---- 6. Save ----
write.csv(pair_df, "analysis/scratch/exp-d2-23pair-classification.csv", row.names = FALSE)
cat("\nSaved: analysis/scratch/exp-d2-23pair-classification.csv\n")
