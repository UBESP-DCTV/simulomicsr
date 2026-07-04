# analysis/p5-stage4-layer-b-shortlist-v7.R
# RE-SELECTION Layer B sul rework END-TO-END v7 (recupero-nome deterministico:
# malattie MeSH + farmaci ChEBI/ChEMBL + biologici HGNC/NCBITaxon). Copia del
# -shortlist.R con path v7 + summary/output v7-dedicati + smoke pin azzerati.
# Genera una shortlist di cluster_id candidati per il Layer B paper-grade a
# partire dal Layer A output v7 (cluster_pooled.parquet) + Stage 3 v7 metadata.
#
# Output: analysis/p4-output/layer-b-shortlist-v7.csv (paper-grade).
#
# Razionale (paper Methods, da consolidare in ADR-0017 Addendum / spec Layer B):
#
#   Layer B case study = drop-into-paper showcase. Vogliamo cluster che:
#     1. abbiano potenza statistica sufficiente (k_effective >= 4 studi);
#     2. abbiano segnale DE robusto (n_sig_05 >= 50, max_abs_logFC >= 1.5);
#     3. abbiano un'interpretazione biologica chiara (kind_effective
#        non-degenere: NO "none", "vehicle_only", "unknown");
#     4. coprano diversi assi biologici (kind_effective + tissue + agent_id);
#     5. coprano entrambe le strade della pipeline (mega vs mega_aug,
#        group-mode vs pair-mode).
#
# Dedup gerarchia: stage3$clusters tiene lo stesso "studi pool" replicato su
# piu' level (L0..L4) della gerarchia anchor v3. Per evitare di selezionare
# 10 cluster e ritrovarne solo 5 unici, dedup-iamo PER (mode, studies_in_cluster
# signature) tenendo il level piu' specifico.
#
# Smoke pin: NESSUNO per v7. I 3 pin del run pre-rework (56b911e6) erano
# cluster_id costruiti su anchor pre-rework che il re-clustering v7 NON
# riproduce piu'. Su v7 non c'e' ancora uno smoke Layer B validato, quindi
# la shortlist e' interamente data-driven (nessun pin forzato).
#
# Usage:
#   Rscript analysis/p5-stage4-layer-b-shortlist-v7.R
#
# Pre-requisiti:
#   - analysis/p4-output/layer-b-cluster-summary-v7.rds (rigenerato se manca)
#   - Layer A output v7 in /mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v7/
#     20260703T230632Z-stage4-v7-4f7ea215/
#   - Stage 3 output v7 in analysis/p4-output/20260703T113045Z-stage3-v7-364547a7/

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tibble); library(cli)
  devtools::load_all(".", quiet = TRUE)
})

stage4_dir <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v7/20260703T230632Z-stage4-v7-4f7ea215"
stage3_dir <- "analysis/p4-output/20260703T113045Z-stage3-v7-364547a7"
summary_rds <- "analysis/p4-output/layer-b-cluster-summary-v7.rds"
out_csv    <- "analysis/p4-output/layer-b-shortlist-v7.csv"

# v7 re-selection interamente data-driven: nessun pin (vedi header).
SMOKE_PINS <- character(0)

# -----------------------------------------------------------------------------
# Step 1 — load (o rigenera) summary aggregato per-cluster
# -----------------------------------------------------------------------------
cli_h1("Layer B — Shortlist generation")

build_summary <- function() {
  cli_alert_info("Building summary aggregato per-cluster (full scan parquet)...")
  ds <- arrow::open_dataset(file.path(stage4_dir, "cluster_pooled.parquet"))
  t0 <- Sys.time()
  agg <- ds |>
    group_by(cluster_id, method) |>
    summarise(
      n_genes              = n(),
      k_effective          = max(k_effective, na.rm = TRUE),
      n_baseline_augmented = max(n_baseline_studies_augmented, na.rm = TRUE),
      n_sig_05             = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
      n_sig_01             = sum(FDR_BH_within_cluster < 0.01, na.rm = TRUE),
      n_sig_strong         = sum(FDR_BH_within_cluster < 0.05 & abs(logFC_pool) > 1, na.rm = TRUE),
      n_sig_05_up          = sum(FDR_BH_within_cluster < 0.05 & logFC_pool > 0, na.rm = TRUE),
      n_sig_05_dn          = sum(FDR_BH_within_cluster < 0.05 & logFC_pool < 0, na.rm = TRUE),
      max_abs_logFC        = max(abs(logFC_pool), na.rm = TRUE),
      median_abs_logFC_sig = median(if_else(FDR_BH_within_cluster < 0.05, abs(logFC_pool), NA_real_), na.rm = TRUE),
      SE_pool_median       = median(SE_pool, na.rm = TRUE),
      .groups              = "drop"
    ) |>
    collect()
  cli_alert_success(sprintf("agg parquet: %.1fs, nrow=%d", as.numeric(difftime(Sys.time(), t0, units = "secs")), nrow(agg)))

  s3 <- load_stage3(stage3_dir)
  s3c <- s3$clusters |>
    filter(cluster_id %in% agg$cluster_id) |>
    select(cluster_id, mode, level, anchor_key, n_total, n_treated, n_control,
           safety_min, n_studies, studies_in_cluster,
           # v7: nome risolto + flag di validita' della label biologica (ADR-0018)
           canonical_name, resolution_source, kind_overridden, kind_override_reason,
           kind_unvalidatable, kind_chebi_zero_roles)
  parsed <- Map(extract_anchor_summary, s3c$anchor_key, s3c$level, s3c$mode)
  s3c$kind_effective <- vapply(parsed, function(x) x$kind_effective, character(1L))
  s3c$agent_id       <- vapply(parsed, function(x) x$agent_id, character(1L))
  s3c$tissue         <- vapply(parsed, function(x) x$tissue, character(1L))
  s3c$studies_sig    <- vapply(s3c$studies_in_cluster, function(x) {
    paste(sort(unique(x)), collapse = "|")
  }, character(1L))

  # Dedup gerarchia: tieni il level piu' specifico per ogni studies_sig (per mode).
  # Eccezione: se uno smoke pin e' duplicato a level inferiore, lo teniamo
  # comunque (override).
  dedup <- s3c |>
    group_by(mode, studies_sig) |>
    slice_max(level, n = 1, with_ties = FALSE) |>
    ungroup()
  pinned_to_force_in <- setdiff(SMOKE_PINS, dedup$cluster_id)
  if (length(pinned_to_force_in) > 0) {
    extra <- s3c |> filter(cluster_id %in% pinned_to_force_in)
    dedup <- bind_rows(dedup, extra)
    cli_alert_info(sprintf("smoke pin %s ripristinati (erano stati deduplicati su level piu' specifico)",
                           paste(pinned_to_force_in, collapse = ", ")))
  }

  final <- agg |>
    inner_join(dedup, by = "cluster_id") |>
    select(cluster_id, method, mode, level,
           kind_effective, agent_id, tissue, canonical_name, resolution_source,
           kind_overridden, kind_override_reason, kind_unvalidatable, kind_chebi_zero_roles,
           k_effective, n_baseline_augmented, n_total, n_treated, n_control,
           n_genes, n_sig_05, n_sig_01, n_sig_strong, n_sig_05_up, n_sig_05_dn,
           max_abs_logFC, median_abs_logFC_sig, SE_pool_median,
           safety_min, anchor_key)
  saveRDS(final, summary_rds)
  cli_alert_success(sprintf("Saved %s (n=%d cluster unici post-dedup)", summary_rds, nrow(final)))
  final
}

summary_tbl <- if (file.exists(summary_rds)) {
  cli_alert_info(sprintf("Loading cached summary: %s", summary_rds))
  readRDS(summary_rds)
} else {
  build_summary()
}
cli_alert_info(sprintf("Working set: %d cluster (post-dedup gerarchia anchor v3)", nrow(summary_tbl)))

# -----------------------------------------------------------------------------
# Step 2 — filtri dura (publication-grade)
# -----------------------------------------------------------------------------
# Razionale: per i cluster mega (group-mode, anchor coarse a L0/L1) il
# kind_effective e' frequentemente "none" perche' l'anchor parser semplifica
# i livelli alti della gerarchia. NON e' una "non-classifiability" semantica
# (l'anchor e' ancora valido su tissue+disease+cell_context). Quindi
# rilassiamo il filtro kind SOLO per i mega, e lo manteniamo stringente per
# i mega_aug (pair-mode, anchor L4 specifico — qui "none" sarebbe davvero
# degenere).
DEGENERATE_KIND <- c("none", "vehicle_only", "unknown")

filtered <- summary_tbl |>
  mutate(
    is_smoke_pin = cluster_id %in% SMOKE_PINS,
    pass_k        = k_effective >= 4L,
    pass_sig      = n_sig_05    >= 50L,
    pass_magn     = max_abs_logFC >= 1.5,
    pass_kind     = dplyr::if_else(
      method == "mega",
      # mega: accettiamo anche kind="none" se tissue non-vuoto (anchor su tissue/disease)
      !is.na(tissue) & tissue != "",
      # mega_aug: filtro stringente sulla kind_effective
      !(kind_effective %in% DEGENERATE_KIND)
    ),
    # v7 (ADR-0018 Layer B filter): escludi le label biologiche flaggate come
    # contraddizione LLM NON risolta (compound-as-pathogen/cytokine, es. Carnitina).
    # Gli override RIUSCITI (ONTOLOGY_OVERRIDE_STRONG / DISEASE_KIND_CONTRADICTED)
    # sono correzioni valide e restano candidabili.
    pass_label_trust = is.na(kind_override_reason) |
                       kind_override_reason != "LLM_CONTRADICTION_DETECTED",
    pass_all      = pass_k & pass_sig & pass_magn & pass_kind & pass_label_trust
  )

cli_h2("Filtri (hard gates)")
filter_stats <- tibble(
  filter = c("k_effective >= 4", "n_sig_05 >= 50", "max_abs_logFC >= 1.5",
             "kind_effective non-degenere", "label_trust (no LLM_CONTRADICTION)", "ALL gates"),
  n_pass = c(sum(filtered$pass_k), sum(filtered$pass_sig),
             sum(filtered$pass_magn), sum(filtered$pass_kind),
             sum(filtered$pass_label_trust), sum(filtered$pass_all)),
  n_total = nrow(filtered)
) |> mutate(rate_pct = round(100 * n_pass / n_total, 1))
print(filter_stats)

# -----------------------------------------------------------------------------
# Step 3 — scoring composito (4 dimensioni, ognuna scalata [0,1])
# -----------------------------------------------------------------------------
# - magnitude_score:  log10(n_sig_strong + 1)  -> normalizzato sul max della classe filtered
# - effect_score:     log10(max_abs_logFC + 1) -> normalizzato sul max
# - power_score:      log10(k_effective + 1)   -> normalizzato sul max
# - precision_score:  inverse SE_pool_median   -> normalizzato sul max
#
# score = mean(4 dimensioni). Tutti i pesi uguali (no opinione sull'importanza
# relativa, restiamo trasparenti per il paper).

candidates <- filtered |> filter(pass_all | is_smoke_pin)

if (nrow(candidates) == 0L) {
  cli_abort("Nessun candidato passa i filtri.")
}

candidates <- candidates |>
  mutate(
    magnitude_raw = log10(n_sig_strong + 1),
    effect_raw    = log10(max_abs_logFC + 1),
    power_raw     = log10(k_effective + 1),
    precision_raw = 1 / (1 + SE_pool_median),
    magnitude_score = magnitude_raw / max(magnitude_raw, na.rm = TRUE),
    effect_score    = effect_raw    / max(effect_raw,    na.rm = TRUE),
    power_score     = power_raw     / max(power_raw,     na.rm = TRUE),
    precision_score = precision_raw / max(precision_raw, na.rm = TRUE),
    score = (magnitude_score + effect_score + power_score + precision_score) / 4
  )

# -----------------------------------------------------------------------------
# Step 4 — stratified shortlist (mix method/mode + diversita' biologica)
# -----------------------------------------------------------------------------
# Quote: ~15 mega + ~25 mega_aug + 3 smoke pin (sovrapposti) = 30-40 totali
# Garantiamo per quote-class top-N per score, ma con cap-per-(kind_effective,
# tissue) per non monopolizzare.
#
# Cap diversita': max 3 per kind_effective, max 4 per tissue.

stratified_pick <- function(df, quota, cap_kind = 3, cap_tissue = 4) {
  taken <- df[0, ]
  kind_count <- integer(0); tissue_count <- integer(0)
  for (i in seq_len(nrow(df))) {
    r <- df[i, ]
    kk <- r$kind_effective; tt <- r$tissue
    cur_kind   <- if (is.null(kind_count[kk]) || is.na(kind_count[kk])) 0L else kind_count[kk]
    cur_tissue <- if (is.null(tissue_count[tt]) || is.na(tissue_count[tt])) 0L else tissue_count[tt]
    if (cur_kind >= cap_kind || cur_tissue >= cap_tissue) next
    taken <- bind_rows(taken, r)
    kind_count[kk]   <- cur_kind + 1L
    tissue_count[tt] <- cur_tissue + 1L
    if (nrow(taken) >= quota) break
  }
  taken
}

mega_sorted     <- candidates |> filter(method == "mega")     |> arrange(desc(score))
mega_aug_sorted <- candidates |> filter(method == "mega_aug") |> arrange(desc(score))

mega_pick     <- stratified_pick(mega_sorted,     quota = 12, cap_kind = 4, cap_tissue = 4)
mega_aug_pick <- stratified_pick(mega_aug_sorted, quota = 25, cap_kind = 3, cap_tissue = 4)

shortlist <- bind_rows(mega_pick, mega_aug_pick) |>
  arrange(desc(score)) |>
  distinct(cluster_id, .keep_all = TRUE)

# Garantisci che gli smoke pin siano nella shortlist
missing_pins <- setdiff(SMOKE_PINS, shortlist$cluster_id)
if (length(missing_pins) > 0) {
  extra <- candidates |> filter(cluster_id %in% missing_pins)
  shortlist <- bind_rows(shortlist, extra) |> arrange(desc(score))
  cli_alert_info(sprintf("Aggiunto %d smoke pin a posteriori: %s",
                         length(missing_pins), paste(missing_pins, collapse = ", ")))
}

cli_h2(sprintf("Shortlist: %d cluster (%d mega + %d mega_aug)",
               nrow(shortlist),
               sum(shortlist$method == "mega"),
               sum(shortlist$method == "mega_aug")))

# -----------------------------------------------------------------------------
# Step 5 — output CSV (review umana)
# -----------------------------------------------------------------------------
out_tbl <- shortlist |>
  mutate(
    label_paper_suggested = sprintf("%s / %s / %s",
                                    kind_effective,
                                    ifelse(is.na(agent_id) | agent_id == "", "no_agent", agent_id),
                                    ifelse(is.na(tissue) | tissue == "", "no_tissue", tissue)),
    is_smoke_pin = cluster_id %in% SMOKE_PINS
  ) |>
  select(
    cluster_id, method, mode, level, score,
    label_paper_suggested, kind_effective, agent_id, canonical_name, tissue,
    resolution_source, kind_override_reason, kind_unvalidatable, kind_chebi_zero_roles,
    k_effective, n_baseline_augmented, n_total, n_treated, n_control,
    n_sig_05, n_sig_strong, n_sig_05_up, n_sig_05_dn,
    max_abs_logFC, median_abs_logFC_sig, SE_pool_median, safety_min,
    is_smoke_pin
  ) |>
  mutate(
    score                = round(score, 4),
    max_abs_logFC        = round(max_abs_logFC, 3),
    median_abs_logFC_sig = round(median_abs_logFC_sig, 3),
    SE_pool_median       = round(SE_pool_median, 4),
    safety_min           = round(safety_min, 4)
  )

readr::write_csv(out_tbl, out_csv)
cli_alert_success(sprintf("Saved shortlist: %s (n=%d)", out_csv, nrow(out_tbl)))

cli_h2("Coverage summary")
print(out_tbl |> count(method, name = "n_clusters"))
print(out_tbl |> count(kind_effective, sort = TRUE))
print(out_tbl |> count(tissue, sort = TRUE))
print(out_tbl |> count(level, name = "n_clusters"))

cat("\n--- TOP 10 della shortlist ---\n")
print(out_tbl |> select(cluster_id, method, level, score, label_paper_suggested,
                        k_effective, n_sig_strong, max_abs_logFC, is_smoke_pin) |>
      head(10), width = Inf)
