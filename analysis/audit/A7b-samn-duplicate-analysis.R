#!/usr/bin/env Rscript
# A7b — Analisi paper-grade dei duplicati cross-GSE per BioSample SAMN.
#
# Scope: estende A7 misurando QUANTO i GSM duplicati su stesso SAMN sono
# simili (metadata diff cross-GSE + counts correlation) e QUANTI cluster
# Stadio 3 baseline (v3.1.1) sono potenzialmente colpiti (heuristic upper
# bound via studies_in_cluster overlap >= 2 con il GSE-set del SAMN).
#
# Output (analisi-only, niente codice produttivo, niente commit):
#   - analysis/audit/A7b-samn-duplicate-metadata.tsv   (425 GSM con metadata)
#   - analysis/audit/A7b-samn-duplicate-pairs.tsv      (176 SAMN diff flags)
#   - analysis/audit/A7b-samn-counts-correlation.tsv   (subset stratificato)
#   - analysis/audit/A7b-samn-cluster-impact.tsv       (upper bound)
#
# Decide E0b (a) drop / (b) average / (c) sotto-noise:
#   - metadata uniformi + counts correlation >=0.99 + cluster impact basso
#     => (c) giustificata.
#   - metadata mixed o counts cor << 1 => (b) average e' statisticamente
#     scorretta; (a) drop o (c) restano in gara.
#   - cluster impact alto => (a) drop necessaria.

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr)
  library(rhdf5); library(stringr); library(tibble)
})

set.seed(42)
H5 <- "analysis/input/human_gene_v2.5.h5"

cat("==============================================================\n")
cat("A7b — SAMN cross-GSE duplicate analysis\n")
cat("==============================================================\n\n")

# --- 1. Universo: i 425 GSM cross-GSE ----------------------------------------
a7 <- read_tsv("analysis/audit/A7-biosample-donor-coverage.tsv",
               show_col_types = FALSE)
cat(sprintf("A7 coverage TSV: %d rows\n", nrow(a7)))

cross <- a7 %>% filter(samn_is_cross)
cat(sprintf("GSM cross-GSE: %d\n", nrow(cross)))
cat(sprintf("SAMN duplicati: %d\n", dplyr::n_distinct(cross$samn)))

# --- 2. Fetch metadata extra da H5 (solo per i 425 GSM) ----------------------
all_gsm <- as.character(h5read(H5, "meta/samples/geo_accession"))
idx <- match(cross$geo, all_gsm)
stopifnot(!any(is.na(idx)))

fetch_field <- function(field) {
  v <- as.character(h5read(H5, sprintf("meta/samples/%s", field)))
  v[idx]
}

cat("\nFetching metadata extra da H5...\n")
meta <- cross %>%
  mutate(
    title           = fetch_field("title"),
    characteristics = fetch_field("characteristics_ch1"),
    molecule        = fetch_field("molecule_ch1"),
    instrument      = fetch_field("instrument_model"),
    data_processing = fetch_field("data_processing"),
    library_source  = fetch_field("library_source"),
    extract_protocol = fetch_field("extract_protocol_ch1"),
    scprob          = as.numeric(h5read(H5, "meta/samples/singlecellprobability"))[idx]
  )

# Join lib_size precalcolato A3 (post-filtri Stage 0 v2)
a3 <- read_tsv("analysis/audit/A3-libsize-scprob-bacino.tsv",
               show_col_types = FALSE)
meta <- meta %>% left_join(a3 %>% select(geo, lib_size_a3 = lib_size), by = "geo")

write_tsv(meta, "analysis/audit/A7b-samn-duplicate-metadata.tsv")
cat(sprintf("Written A7b-samn-duplicate-metadata.tsv (%d rows)\n", nrow(meta)))

# --- 3. Pair-wise diff per SAMN duplicato ------------------------------------
pair_diff <- meta %>%
  group_by(samn) %>%
  summarize(
    n_gsm           = dplyr::n(),
    n_gse           = dplyr::n_distinct(series),
    gsm_list        = paste(geo, collapse = ";"),
    gse_list        = paste(unique(series), collapse = ";"),
    instrument_uniq = dplyr::n_distinct(instrument),
    instrument_mix  = instrument_uniq > 1,
    dp_uniq         = dplyr::n_distinct(data_processing),
    dp_mix          = dp_uniq > 1,
    molecule_uniq   = dplyr::n_distinct(molecule),
    molecule_mix    = molecule_uniq > 1,
    libsrc_uniq     = dplyr::n_distinct(library_source),
    libsrc_mix      = libsrc_uniq > 1,
    extract_uniq    = dplyr::n_distinct(extract_protocol),
    extract_mix     = extract_uniq > 1,
    libsize_min     = suppressWarnings(min(lib_size_a3, na.rm = TRUE)),
    libsize_max     = suppressWarnings(max(lib_size_a3, na.rm = TRUE)),
    libsize_ratio   = ifelse(is.finite(libsize_min) & libsize_min > 0,
                              libsize_max / libsize_min, NA_real_),
    title_uniq      = dplyr::n_distinct(title),
    .groups = "drop"
  ) %>%
  arrange(desc(n_gsm))

write_tsv(pair_diff, "analysis/audit/A7b-samn-duplicate-pairs.tsv")
cat(sprintf("Written A7b-samn-duplicate-pairs.tsv (%d SAMN)\n", nrow(pair_diff)))

cat("\n--- Distribuzione n_gsm per SAMN duplicato ---\n")
print(table(pair_diff$n_gsm))

cat("\n--- Metadata diff cross-GSE (%% SAMN with mix) ---\n")
cat(sprintf("instrument_mix:     %5.2f%% (%d/%d)\n",
            100 * mean(pair_diff$instrument_mix),
            sum(pair_diff$instrument_mix), nrow(pair_diff)))
cat(sprintf("data_processing:    %5.2f%% (%d/%d)\n",
            100 * mean(pair_diff$dp_mix),
            sum(pair_diff$dp_mix), nrow(pair_diff)))
cat(sprintf("molecule_ch1:       %5.2f%% (%d/%d)\n",
            100 * mean(pair_diff$molecule_mix),
            sum(pair_diff$molecule_mix), nrow(pair_diff)))
cat(sprintf("library_source:     %5.2f%% (%d/%d)\n",
            100 * mean(pair_diff$libsrc_mix),
            sum(pair_diff$libsrc_mix), nrow(pair_diff)))
cat(sprintf("extract_protocol:   %5.2f%% (%d/%d)\n",
            100 * mean(pair_diff$extract_mix),
            sum(pair_diff$extract_mix), nrow(pair_diff)))

cat("\n--- libsize_ratio quartiles (max/min cross-GSE) ---\n")
print(quantile(pair_diff$libsize_ratio,
               probs = c(0.25, 0.5, 0.75, 0.9, 0.95, 1.0),
               na.rm = TRUE))

# --- 4. Counts correlation cross-GSE (subset stratificato) -------------------
sel_samn <- pair_diff %>%
  filter(n_gsm == 2L) %>%
  mutate(stratum = case_when(
    !instrument_mix & !dp_mix & !molecule_mix ~ "identical_meta",
    instrument_mix & !dp_mix                  ~ "instrument_mix",
    dp_mix                                     ~ "dp_mix",
    molecule_mix                               ~ "molecule_mix",
    TRUE                                       ~ "other_mix"
  )) %>%
  group_by(stratum) %>%
  slice_sample(n = 5, replace = FALSE) %>%
  ungroup()

cat("\n--- Selected SAMN per counts correlation ---\n")
print(table(sel_samn$stratum))

cat("\nFetching counts pair-wise da H5 (subset)...\n")
counts_cor <- vector("list", nrow(sel_samn))
for (i in seq_len(nrow(sel_samn))) {
  s <- sel_samn[i, ]
  gsms <- strsplit(s$gsm_list, ";")[[1]]
  if (length(gsms) < 2L) next
  g1 <- gsms[1]; g2 <- gsms[2]
  i1 <- match(g1, all_gsm); i2 <- match(g2, all_gsm)
  c1 <- as.numeric(h5read(H5, "data/expression", index = list(i1, NULL)))
  c2 <- as.numeric(h5read(H5, "data/expression", index = list(i2, NULL)))
  l1 <- log1p(c1); l2 <- log1p(c2)
  counts_cor[[i]] <- tibble(
    samn          = s$samn,
    gsm_a         = g1, gsm_b = g2,
    stratum       = s$stratum,
    pearson_log1p = cor(l1, l2, method = "pearson"),
    spearman      = cor(c1, c2, method = "spearman"),
    lib_a         = sum(c1),
    lib_b         = sum(c2),
    lib_ratio     = sum(c2) / sum(c1)
  )
}
counts_cor_df <- bind_rows(counts_cor)
write_tsv(counts_cor_df, "analysis/audit/A7b-samn-counts-correlation.tsv")

cat("\n--- Counts correlation per stratum ---\n")
print(counts_cor_df %>%
        group_by(stratum) %>%
        summarize(n               = dplyr::n(),
                  median_pearson  = round(median(pearson_log1p), 4),
                  min_pearson     = round(min(pearson_log1p), 4),
                  median_spearman = round(median(spearman), 4),
                  median_lib_ratio = round(median(lib_ratio), 3),
                  .groups = "drop"))

# --- 5. Cluster impact upper bound (heuristic studies_in_cluster overlap) ----
cl <- readRDS("analysis/p4-output/20260525T172032Z-stage3-v31-2655ecb0/clusters.rds")
cat(sprintf("\nclusters.rds v3.1.1 (2655ecb0): %d cluster\n", nrow(cl)))

# Per ogni SAMN duplicato, lista delle GSE in cui appare
samn_gse_lookup <- meta %>%
  group_by(samn) %>%
  summarize(gses = list(unique(series)), .groups = "drop")

# Pre-estraggo studies_in_cluster come char vec per evitare rowwise lento
studies_list <- cl$studies_in_cluster

cat("Computing cluster overlap (upper bound heuristic)...\n")
cluster_impact_rows <- list()
for (i in seq_len(nrow(samn_gse_lookup))) {
  samn_i <- samn_gse_lookup$samn[i]
  gses_i <- samn_gse_lookup$gses[[i]]
  # cheap pre-filter: SOLO i cluster il cui studies_in_cluster contiene almeno
  # uno dei GSE target. h5read studies_in_cluster e' list-col di chr vec.
  has_any <- vapply(studies_list, function(s) any(s %in% gses_i), logical(1))
  cand <- which(has_any)
  if (length(cand) == 0L) next
  overlap_cnt <- vapply(studies_list[cand],
                        function(s) length(intersect(s, gses_i)),
                        integer(1))
  hits <- cand[overlap_cnt >= 2L]
  if (length(hits) == 0L) next
  cluster_impact_rows[[length(cluster_impact_rows) + 1L]] <- tibble(
    samn          = samn_i,
    cluster_id    = cl$cluster_id[hits],
    mode          = cl$mode[hits],
    level         = cl$level[hits],
    kind          = cl$kind_effective_resolved[hits],
    n_gse_overlap = overlap_cnt[overlap_cnt >= 2L]
  )
}
ci_df <- bind_rows(cluster_impact_rows)

cat("\n--- Cluster impact upper bound ---\n")
cat(sprintf("SAMN con >=1 cluster a rischio: %d / %d\n",
            dplyr::n_distinct(ci_df$samn), nrow(samn_gse_lookup)))
cat(sprintf("Cluster_id unique a rischio: %d\n",
            dplyr::n_distinct(ci_df$cluster_id)))
cat("\nBy mode:\n"); print(table(ci_df$mode))
cat("\nBy level:\n"); print(table(ci_df$level))
cat("\nTop kind_effective_resolved:\n")
print(head(sort(table(ci_df$kind), decreasing = TRUE), 10))

write_tsv(ci_df, "analysis/audit/A7b-samn-cluster-impact.tsv")
cat(sprintf("\nWritten A7b-samn-cluster-impact.tsv (%d rows)\n", nrow(ci_df)))

cat("\n==============================================================\n")
cat("A7b DONE\n")
cat("==============================================================\n")
