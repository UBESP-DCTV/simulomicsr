# analysis/p5-audit-fragmentation.R
#
# Misura il "cluster fragmentation rate" indotto dal LLM-only agent_id
# canonicalization. Question: quanti studi sullo stesso composto sono finiti
# in cluster Stage 3 distinti perche' il LLM ha emesso piu' rappresentazioni
# per lo stesso composto (es. "CHEBI:17126" vs "17126" vs "Carnitine")?
#
# Metodologia:
#   1. Per ogni cluster Stage 3, risolvi agent_id -> canonical_compound_id
#      (es. ChEBI int o HGNC int o MeSH UI), via la stessa logica del scan.
#   2. Per ogni cluster, estrai lista degli studi (studies_in_cluster).
#   3. Raggruppa per (canonical_compound, mode, level, kind_effective) e
#      conta in quanti cluster diversi gli stessi studi appaiono.
#   4. Stima studi-pair "lost" = pair di studi sullo stesso composto in cluster
#      diversi che SAREBBERO STATI pooled se la canonicalization fosse stata
#      consistente.
#
# Output: analysis/p4-output/p5-audit-fragmentation.rds + summary.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(dplyr); library(tibble); library(cli); library(stringr); library(tidyr)
  devtools::load_all(".", quiet = TRUE)
})

CACHE <- tools::R_user_dir("simulomicsr","cache")
chebi <- readRDS(file.path(CACHE, "chebi", "chebi-lookup.rds"))
hgnc  <- readRDS(file.path(CACHE, "hgnc-lookup.rds"))
mesh  <- readRDS(file.path(CACHE, "mesh-lookup.rds"))
audit <- readRDS("analysis/p4-output/p5-audit-agent-id-validation.rds")

cli_h1("Cluster fragmentation analysis")

s3 <- load_stage3("analysis/p4-output/20260519T055547Z-stage3-2153addc")

# Build canonical compound id per ogni cluster
# Strategy:
#   - <DB>:<num> validato -> sprintf("%s:%d", DB, num) o recovered_db
#   - numerico puro che valida CHEBI -> "CHEBI:%d"
#   - MeSH naked Dxxxxxx -> "MeSH:Dxxxxxx"
#   - ChEMBL naked CHEMBLnnnn -> "ChEMBL:nnnn"
#   - stringa nome con alias_hit -> usa il VOCABULARY:ID risolto
#   - stringa nome senza match -> "STR:lowercase"
#   - unknown -> "UNK"
#
# Tutto in caratteri normalizzati.

agent_ids <- audit$agent_ids
kind_effs <- audit$kind_effs

n_total <- length(agent_ids)
canonical <- rep(NA_character_, n_total)

# PATH 2: <DB>:<num>
df_num <- audit$df_num
for (i in seq_len(nrow(df_num))) {
  idx <- df_num$idx[i]
  if (df_num$validation[i] == "VALID_PRIMARY") {
    canonical[idx] <- sprintf("%s:%d", df_num$db[i], df_num$num_int[i])
  } else if (!is.na(df_num$recovered_db[i])) {
    rd <- df_num$recovered_db[i]
    rd <- sub("_via_HGNC$", "", rd) # ENTREZ_via_HGNC -> ENTREZ
    canonical[idx] <- sprintf("%s:%d", rd, df_num$num_int[i])
  } else {
    canonical[idx] <- sprintf("HALLUC:%s", agent_ids[idx])
  }
}

# PATH 1: numerico puro
df_purenum <- audit$df_purenum
for (i in seq_len(nrow(df_purenum))) {
  idx <- df_purenum$idx[i]
  rd <- df_purenum$resolved_db[i]
  if (!is.na(rd)) {
    rd <- sub("_via_HGNC$", "", rd)
    canonical[idx] <- sprintf("%s:%d", rd, df_purenum$num_int[i])
  } else {
    canonical[idx] <- sprintf("HALLUC_NUM:%s", df_purenum$agent_id[i])
  }
}

# PATH 4: MeSH naked
df_mesh_naked <- audit$df_mesh_naked
for (i in seq_len(nrow(df_mesh_naked))) {
  idx <- df_mesh_naked$idx[i]
  if (df_mesh_naked$ck[i] == "PRIMARY") {
    canonical[idx] <- sprintf("MeSH:%s", df_mesh_naked$agent_id[i])
  } else {
    canonical[idx] <- sprintf("HALLUC_MESH:%s", df_mesh_naked$agent_id[i])
  }
}

# PATH 4: ChEMBL naked
chembl_idx <- which(grepl("^CHEMBL[0-9]+$", agent_ids) & is.na(canonical))
canonical[chembl_idx] <- sprintf("ChEMBL:%s", agent_ids[chembl_idx])

# PATH 4: stringa nome
df_string <- audit$df_string
for (i in seq_len(nrow(df_string))) {
  idx <- df_string$idx[i]
  if (!is.na(df_string$chebi_match_id[i])) {
    canonical[idx] <- sprintf("CHEBI:%d", df_string$chebi_match_id[i])
  } else if (!is.na(df_string$hgnc_int_match[i])) {
    canonical[idx] <- sprintf("HGNC:%d", df_string$hgnc_int_match[i])
  } else if (!is.na(df_string$mesh_ui_match[i])) {
    canonical[idx] <- sprintf("MeSH:%s", df_string$mesh_ui_match[i])
  } else {
    canonical[idx] <- sprintf("STR:%s", df_string$agent_lower[i])
  }
}

# Unknown / unhandled
canonical[is.na(canonical)] <- "UNK"

cli_alert_info(sprintf("Canonical resolved: %d / %d (%.1f%%)",
                       sum(!grepl("^(UNK|HALLUC|STR:)", canonical)), n_total,
                       100*mean(!grepl("^(UNK|HALLUC|STR:)", canonical))))

# Fragmentation: per ogni cluster, ho canonical + mode + level + kind_effective.
# Studies del cluster sono in studies_in_cluster (list-col).
fragmentation_tbl <- tibble(
  cluster_id  = s3$clusters$cluster_id,
  mode        = s3$clusters$mode,
  level       = s3$clusters$level,
  agent_id    = agent_ids,
  canonical,
  kind_eff    = kind_effs,
  studies_set = s3$clusters$studies_in_cluster,
  n_studies   = s3$clusters$n_studies
)

# Per ogni canonical_compound (escludendo STR/UNK/HALLUC) misuro:
#   - n_clusters distinct rappresentano quel composto (a fix mode+level+kind_eff)
#   - studi totali e studi-unique cross-cluster
group_key <- paste(fragmentation_tbl$canonical,
                   fragmentation_tbl$mode,
                   fragmentation_tbl$level,
                   fragmentation_tbl$kind_eff,
                   sep = "|")
fragmentation_tbl$group_key <- group_key

# Solo canonical legittimo
legit <- !grepl("^(UNK|HALLUC|STR:)", fragmentation_tbl$canonical)
frag_legit <- fragmentation_tbl |> filter(legit)

# Per ogni canonical (qualunque level+kind_eff), conta cluster_id distinct con
# studi distinti effettivi
frag_compound <- frag_legit |>
  group_by(canonical) |>
  summarise(
    n_clusters = n(),
    n_studies_total = sum(n_studies, na.rm = TRUE),
    n_studies_unique = length(unique(unlist(studies_set))),
    levels_seen = paste(sort(unique(level)), collapse = ","),
    modes_seen  = paste(sort(unique(mode)), collapse = ","),
    kinds_seen  = paste(sort(unique(kind_eff)), collapse = ","),
    cluster_ids = list(cluster_id),
    .groups = "drop"
  )
cli_alert_info(sprintf("Distinct canonical compounds: %d", nrow(frag_compound)))

# Fragmentation rate: compounds con >1 cluster vs total
frag_summary <- frag_compound |>
  mutate(is_fragmented = n_clusters > 1) |>
  summarise(
    n_compounds_total = n(),
    n_fragmented      = sum(is_fragmented),
    pct_fragmented    = 100*mean(is_fragmented),
    median_n_clusters_per_compound = median(n_clusters),
    max_n_clusters_per_compound    = max(n_clusters)
  )
print(frag_summary, width = Inf)

cli_h2("Distribuzione cluster-per-compound (top 20)")
print(frag_compound |> arrange(desc(n_clusters)) |> head(20) |>
        select(canonical, n_clusters, n_studies_total, n_studies_unique, levels_seen, modes_seen, kinds_seen),
      width = Inf)

# Per stima paper-relevant: limitiamo a compounds con almeno 2 studi unique
# (sotto questa soglia il fragmentation non e' meaningful per il pooling DE).
frag_meaningful <- frag_compound |> filter(n_studies_unique >= 2)
cli_h2("Fragmentation tra compounds con >= 2 studi unique (clinically meaningful)")
print(frag_meaningful |>
        mutate(is_fragmented = n_clusters > 1) |>
        summarise(
          n_compounds_meaningful = n(),
          n_fragmented           = sum(is_fragmented),
          pct_fragmented         = 100*mean(is_fragmented)
        ), width = Inf)

# Anche: stesso compound a level=0 mode=group dovrebbe rappresentare TUTTI gli
# studi su quel composto trasversalmente. Se appare in N cluster level=0 mode=group,
# c'e' fragmentation strutturale.
cli_h2("Fragmentation a livello fisso (level=0, mode=group)")
frag_L0G <- frag_legit |>
  filter(level == 0L, mode == "group") |>
  group_by(canonical) |>
  summarise(n_clusters = n(), .groups = "drop")
print(frag_L0G |>
        mutate(is_fragmented = n_clusters > 1) |>
        summarise(
          n_compounds_L0G = n(),
          n_fragmented_L0G = sum(is_fragmented),
          pct_fragmented_L0G = 100*mean(is_fragmented),
          median_clusters = median(n_clusters),
          max_clusters    = max(n_clusters)
        ), width = Inf)

# Persisti
saveRDS(list(
  meta = list(built_at = Sys.time(), n_total_stage3 = n_total),
  fragmentation_tbl = fragmentation_tbl,
  frag_compound = frag_compound,
  frag_summary  = frag_summary,
  frag_meaningful_summary = frag_meaningful |>
    mutate(is_fragmented = n_clusters > 1) |>
    summarise(n = n(), n_frag = sum(is_fragmented), pct = 100*mean(is_fragmented)),
  frag_L0G_summary = frag_L0G |>
    mutate(is_fragmented = n_clusters > 1) |>
    summarise(n = n(), n_frag = sum(is_fragmented), pct = 100*mean(is_fragmented))
), "analysis/p4-output/p5-audit-fragmentation.rds")
cli_alert_success("Saved analysis/p4-output/p5-audit-fragmentation.rds")
