# Gate di omogeneita' Stadio 3 — misura la frazione di cluster "minestrone"
# (cluster che mescolano >=2 malattie o >=2 composti distinti).
#
# REVIEW FIX (2026-06-26): il gate conta le identita' SOLO sui GSM che sono
# membri effettivi del cluster, lato treated/case (il braccio caratterizzante).
# La versione precedente prendeva `clusters.rds$studies_in_cluster` (le SERIE
# GSE) e contava le identita' su TUTTI i campioni di ogni serie via l'H5. Ma una
# serie contiene di solito piu' trattamenti + controlli; se il cluster usa solo
# un braccio, contare l'intera serie includeva composti/controlli NON membri del
# cluster -> sovrastima dei minestroni (smoke v3: 84.8%, gonfiato).
#
# UTILIZZO:
#   Rscript analysis/audit/stage3-homogeneity-check.R \
#       [stage3_dir] [h5_path] [max_clusters] [max_samples_per_cluster] [stage2_master]
#
# Valori default (se non passati come argomenti):
#   stage3_dir              = "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
#   h5_path                 = "analysis/input/human_gene_v2.5.h5"
#   max_clusters            = 500   (Inf = full run; usa Inf per la produzione)
#   max_samples_per_cluster = Inf   (campiona fino a N GSM membri per cluster;
#                                    Inf = tutti. Sostituisce il vecchio
#                                    max_samples_per_study: ora si campiona sui
#                                    membri del cluster, non sui campioni di serie)
#   stage2_master           = "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
#
# OUTPUT:
#   analysis/audit/stage3-homogeneity-check-out.csv  (tabella per-cluster)
#   analysis/audit/stage3-homogeneity-check-out.txt  (summary stampato)
#
# RUNNER CORRETTO (renv attivo: rhdf5 + arrow + devtools disponibili):
#   Rscript analysis/audit/stage3-homogeneity-check.R
# oppure con argomenti espliciti:
#   Rscript analysis/audit/stage3-homogeneity-check.R <stage3_dir> <h5> <max_cl> <max_sp> <master>
#
# DRY: riusa le funzioni del modulo R/stage3-name-recovery.R via devtools::load_all().
# NON duplica i pattern .DISEASE_KEYS / .AGENT_KEYS / .CONTROL_VALS.
# La normalizzazione avviene tramite recover_identity() di simulomicsr.

suppressPackageStartupMessages({
  library(rhdf5)
  library(dplyr)
  library(arrow)
  library(jsonlite)
})

# ---------------------------------------------------------------------------
# 0. Parametri CLI e setup
# ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
stage3_dir              <- if (length(args) >= 1) args[1] else
  "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
h5_path                 <- if (length(args) >= 2) args[2] else
  "analysis/input/human_gene_v2.5.h5"
max_clusters            <- if (length(args) >= 3) as.numeric(args[3]) else 500
max_samples_per_cluster <- if (length(args) >= 4) as.numeric(args[4]) else Inf
stage2_master_path      <- if (length(args) >= 5) args[5] else
  "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

if (!is.character(stage3_dir) || !file.exists(stage3_dir)) {
  stop("stage3_dir non trovata: ", stage3_dir)
}
if (!file.exists(h5_path)) {
  stop("H5 non trovato: ", h5_path)
}
if (!file.exists(stage2_master_path)) {
  stop("Stage2 master non trovato: ", stage2_master_path)
}

cat("=== Gate omogeneita' Stadio 3 (membri-only) ===\n")
cat("  stage3_dir             :", stage3_dir, "\n")
cat("  h5_path                :", h5_path, "\n")
cat("  stage2_master          :", stage2_master_path, "\n")
cat("  max_clusters           :", if (is.infinite(max_clusters)) "Inf (full run)" else max_clusters, "\n")
cat("  max_samples_per_cluster:", if (is.infinite(max_samples_per_cluster)) "Inf (tutti)" else max_samples_per_cluster, "\n\n")

# ---------------------------------------------------------------------------
# 1. Carica il pacchetto (DRY: accesso a recover_identity + funzioni interne)
# ---------------------------------------------------------------------------

cat("[1/6] Caricamento pacchetto simulomicsr...\n")
if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all(quiet = TRUE)
} else {
  # Fallback se devtools non e' disponibile: usa pkgload
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(quiet = TRUE)
  } else {
    stop("devtools o pkgload necessari per caricare il pacchetto.")
  }
}
# Verifica che le funzioni interne siano accessibili
stopifnot(exists("recover_identity"))
stopifnot(exists(".load_ontology_dicts", envir = asNamespace("simulomicsr")))
.load_ontology_dicts_fn <- get(".load_ontology_dicts", envir = asNamespace("simulomicsr"))

# ---------------------------------------------------------------------------
# 2. Carica l'ontologia (singleton, richiesto da recover_identity)
# ---------------------------------------------------------------------------

cat("[2/6] Caricamento ontologia (MeSH + ChEBI + HGNC) — ~25s...\n")
t_onto <- system.time(onto <- .load_ontology_dicts_fn())
cat("  Ontologia caricata in", round(t_onto[3], 1), "sec\n\n")

# ---------------------------------------------------------------------------
# 3. Carica metadati H5 in bulk (fast: 888k x 4 campi in ~3s)
#    Lookup DIRETTO per geo_accession (GSM univoco): niente piu' indice
#    series->posizioni con match comma-joined per-token. La risoluzione dei
#    membri avviene a monte (record_id -> GSM, sez. 4b), quindi qui basta
#    mappare GSM -> riga H5.
# ---------------------------------------------------------------------------

cat("[3/6] Lettura metadati campioni dall'H5...\n")
t_h5 <- system.time({
  h5_geo_acc <- h5read(h5_path, "meta/samples/geo_accession")
  h5_source  <- h5read(h5_path, "meta/samples/source_name_ch1")
  h5_char    <- h5read(h5_path, "meta/samples/characteristics_ch1")
  h5_title   <- h5read(h5_path, "meta/samples/title")
})
n_h5 <- length(h5_geo_acc)
cat("  Letti", n_h5, "campioni in", round(t_h5[3], 1), "sec\n\n")

# ---------------------------------------------------------------------------
# 4. Carica clusters.rds + assignments.parquet e filtra per audit
# ---------------------------------------------------------------------------

cat("[4/6] Caricamento cluster + assignments Stadio 3...\n")
clusters_path    <- file.path(stage3_dir, "clusters.rds")
assignments_path <- file.path(stage3_dir, "assignments.parquet")
if (!file.exists(clusters_path))    stop("clusters.rds non trovato in: ", stage3_dir)
if (!file.exists(assignments_path)) stop("assignments.parquet non trovato in: ", stage3_dir)
cl_all      <- readRDS(clusters_path)
assignments <- read_parquet(assignments_path)
cat("  Cluster totali:", nrow(cl_all), " | assignment rows:", nrow(assignments), "\n")

# Kind da auditare: disease_vs_normal + perturbativi (small_molecule, cytokine, pathogen)
AUDIT_KINDS <- c(
  "disease_vs_normal",
  "small_molecule",
  "cytokine_stim",
  "pathogen_or_aggregate_exposure"
)
# Filtra: kind auditabile + k >= 2 (k=1 non puo' essere minestrone tra studi)
cl_audit <- cl_all |>
  filter(kind_effective_resolved %in% AUDIT_KINDS, n_studies >= 2)

cat("  Cluster auditabili (kind OK + k>=2):", nrow(cl_audit), "\n")
cat("  Split per kind:\n")
print(table(cl_audit$kind_effective_resolved))

# Campionamento per smoke (stratificato per kind in proporzione)
if (!is.infinite(max_clusters) && nrow(cl_audit) > max_clusters) {
  set.seed(42L)
  n_tot_audit <- nrow(cl_audit)
  kind_counts <- table(cl_audit$kind_effective_resolved)
  kind_quota  <- ceiling(max_clusters * kind_counts / n_tot_audit)
  sampled_rows <- lapply(names(kind_quota), function(k) {
    sub <- cl_audit[cl_audit$kind_effective_resolved == k, ]
    n_k <- min(kind_quota[[k]], nrow(sub))
    sub[sample(nrow(sub), n_k), ]
  })
  cl_audit <- do.call(rbind, sampled_rows)
  cat("\n  [SMOKE] Campione stratificato:", nrow(cl_audit), "cluster\n")
}
cat("\n")

# ---------------------------------------------------------------------------
# 4b. Mappa record_id -> GSM membri (lato treated/case) dallo Stadio 2 master
#
#     Lo Stadio 3 costruisce (R/stage3-build.R):
#       - PAIR  : record_id = sprintf("%s__%s", series_id, comparison_id)
#                 membri caratterizzanti = sample_ids del treated_group
#                 referenziato dalla comparison (lato treated/case).
#       - GROUP : record_id = sprintf("%s__%s", series_id, group_id)
#                 membri caratterizzanti = sample_ids di quel replicate_group
#                 (e' il braccio caratterizzante per costruzione: case per
#                 disease, treated per i perturbativi).
#
#     I record sintetici `*__completeness_uncovered` (REGOLA 4 guard,
#     R/stage2-normalize.R) NON sono nel master su disco: sono aggiunti in
#     memoria a stage3-build con primary_role='unclear', inerti al pooling
#     treated/control. Per intento del gate (contare SOLO il braccio
#     caratterizzante) NON vanno risolti -> get0() ritorna NULL e si saltano.
#     Verificato: 0 cluster auditabili perde tutti i membri per questo skip.
#
#     Mappa costruita UNA volta sola in un environment (lookup O(1)).
# ---------------------------------------------------------------------------

source("analysis/audit/_gsm-lookup-helper.R")
rec_env <- build_record_gsm_lookup(stage2_master_path)

# Per ogni cluster auditato: record_id -> unione dei GSM membri.
cluster_records <- split(assignments$record_id, assignments$cluster_id)
cluster_gsm <- lapply(cl_audit$cluster_id, function(cid) {
  rids <- unique(cluster_records[[cid]])
  if (length(rids) == 0L) return(character(0))
  unique(unlist(lapply(rids, function(r) get0(r, envir = rec_env, ifnotfound = NULL)),
                use.names = FALSE))
})
names(cluster_gsm) <- cl_audit$cluster_id

# Lookup GSM -> riga H5 costruito UNA volta sull'unione (un solo match O(n_h5)).
union_gsm <- unique(unlist(cluster_gsm, use.names = FALSE))
idx_by_gsm <- match(union_gsm, h5_geo_acc)
names(idx_by_gsm) <- union_gsm
n_union   <- length(union_gsm)
n_in_h5   <- sum(!is.na(idx_by_gsm))
cat("  GSM membri distinti (audit):", n_union,
    "| presenti in H5:", n_in_h5,
    sprintf(" (%.1f%%)\n\n", if (n_union > 0) 100 * n_in_h5 / n_union else 0))

# ---------------------------------------------------------------------------
# 5. Elaborazione per-cluster (solo sui GSM membri)
# ---------------------------------------------------------------------------

cat("[5/6] Estrazione identita' per cluster (membri-only)...\n")

# Helper: dato un cluster, restituisce le identita' distinte nominate sui suoi
# GSM membri (lato treated/case).
.process_cluster <- function(cluster_id, kind, member_gsm) {
  # Determina il llm_kind da passare a recover_identity
  llm_kind <- kind  # kind_effective_resolved (gia' corretto da v3.1.1)

  # Risolvi i GSM membri -> righe H5 (lookup diretto per geo_accession).
  pos <- idx_by_gsm[member_gsm]
  pos <- pos[!is.na(pos)]
  n_members_resolved <- length(pos)

  # Campionamento opzionale dei membri (default Inf = tutti). Deterministico per
  # cluster_id: per un gate basta trovare >=2 identita' distinte.
  if (is.finite(max_samples_per_cluster) && length(pos) > max_samples_per_cluster) {
    set.seed(sum(utf8ToInt(cluster_id)) %% 10000L)
    pos <- sample(pos, max_samples_per_cluster)
  }

  all_ids <- character(0)  # agent_id normalizzati raccolti
  for (i in pos) {
    # Chiama recover_identity() dal modulo (DRY)
    result <- tryCatch(
      recover_identity(
        source          = h5_source[i],
        characteristics = h5_char[i],
        title           = h5_title[i],
        llm_kind        = llm_kind,
        ontology_env    = onto
      ),
      error = function(e) list(agent_id = NA_character_, recovery_source = "ERROR")
    )
    aid <- result$agent_id
    if (!is.null(aid) && !is.na(aid) && nzchar(aid)) {
      all_ids <- c(all_ids, aid)
    }
  }

  # Identita' distinte normalizzate (MeSH:D..., CHEBI:..., STR:<slug>).
  # CAVEAT (STR-slug sinonimi): recover_identity() normalizza i sinonimi via
  # lookup ontologico (MeSH/ChEBI) -> stessa entita' -> stesso ID -> nessun
  # falso minestrone. Ma se un termine NON e' in MeSH/ChEBI ripiega su STR:<slug>
  # lessicale: due riformulazioni dello STESSO concetto possono dare slug
  # distinti -> possibile falso minestrone residuo. Il gate resta percio'
  # leggermente conservativo (puo' sovrastimare) sui termini fuori-ontologia.
  distinct_ids <- unique(all_ids)

  # Conta per tipo di cluster. NB: n_named_* conta gli agent_id DISTINTI (puo'
  # includere STR slug, non solo MeSH/ChEBI canonici).
  if (kind == "disease_vs_normal") {
    n_named_diseases  <- length(distinct_ids)  # tutti gli ID: MeSH o STR
    n_named_compounds <- 0L
  } else {
    # Perturbativi (small_molecule, cytokine_stim, pathogen_or_aggregate_exposure)
    n_named_diseases  <- 0L
    n_named_compounds <- length(distinct_ids)  # tutti gli ID: CHEBI o STR
  }

  # is_minestrone: >=2 identita' nominate distinte nello stesso cluster
  is_minestrone <- (n_named_diseases >= 2L || n_named_compounds >= 2L)

  list(
    n_members           = length(member_gsm),
    n_members_resolved  = as.integer(n_members_resolved),
    n_named_diseases    = as.integer(n_named_diseases),
    n_named_compounds   = as.integer(n_named_compounds),
    n_distinct_ids      = length(distinct_ids),
    distinct_id_sample  = paste(head(sort(distinct_ids), 5), collapse = "|"),
    is_minestrone       = is_minestrone
  )
}

# Elabora tutti i cluster in loop (progress ogni 50)
n_cl <- nrow(cl_audit)
results <- vector("list", n_cl)
t_proc <- system.time({
  for (j in seq_len(n_cl)) {
    row <- cl_audit[j, ]
    cid <- row$cluster_id
    results[[j]] <- .process_cluster(
      cluster_id = cid,
      kind       = row$kind_effective_resolved,
      member_gsm = cluster_gsm[[cid]]
    )
    if (j %% 50L == 0L || j == n_cl) {
      cat("  Processati", j, "/", n_cl, "cluster...\n")
    }
  }
})
cat("  Elaborazione completata in", round(t_proc[3], 1), "sec\n\n")

# Assembla tabella risultati
res_df <- bind_cols(
  cl_audit |> select(cluster_id, kind = kind_effective_resolved, mode, n_studies,
                     agent_id_resolved, canonical_name),
  bind_rows(lapply(results, as.data.frame))
)

# ---------------------------------------------------------------------------
# 6. Summary e salvataggio
# ---------------------------------------------------------------------------

cat("[6/6] Summary e salvataggio output...\n")

out_csv <- file.path("analysis/audit", "stage3-homogeneity-check-out.csv")
out_txt <- file.path("analysis/audit", "stage3-homogeneity-check-out.txt")

write.csv(res_df, out_csv, row.names = FALSE, quote = TRUE)
cat("  Tabella salvata:", out_csv, "\n")

# Costruisce summary
summary_lines <- character(0)
.add <- function(...) summary_lines <<- c(summary_lines, paste0(...))

.add("=== GATE OMOGENEITA' STADIO 3 (membri-only) ===")
.add("Data: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"))
.add("Stage3 dir: ", stage3_dir)
.add("Conteggio identita' su: GSM membri del cluster (lato treated/case)")
.add("Max cluster (smoke): ", if (is.infinite(max_clusters)) "Inf" else max_clusters)
.add("")

for (k in AUDIT_KINDS) {
  sub <- res_df[res_df$kind == k, ]
  if (nrow(sub) == 0) next
  # "provati" = almeno 1 identita' nominata estratta
  has_name <- sub$n_distinct_ids >= 1L
  n_provati <- sum(has_name)
  n_min     <- sum(sub$is_minestrone, na.rm = TRUE)
  pct_min   <- if (n_provati > 0) round(100 * n_min / n_provati, 1) else NA

  .add(sprintf("%-40s : %4d cluster | %4d provati | %4d minestroni | %5.1f%%",
               k, nrow(sub), n_provati, n_min,
               if (is.na(pct_min)) 0 else pct_min))
}

.add("")
.add("--- Split per metodo (mode) ---")
# group = mega + mega_aug (indistinguibili in Stage 3); pair ~= rem.
for (m in sort(unique(res_df$mode))) {
  sub <- res_df[res_df$mode == m, ]
  n_min_mode <- sum(sub$is_minestrone, na.rm = TRUE)
  pct_mode   <- round(100 * n_min_mode / nrow(sub), 1)
  .add(sprintf("  %-10s: %4d cluster | %4d minestroni | %5.1f%%",
               m, nrow(sub), n_min_mode, pct_mode))
}

.add("")
.add("--- Totale cluster auditati ---")
n_tot     <- nrow(res_df)
n_provati_tot <- sum(res_df$n_distinct_ids >= 1L)
n_min_tot <- sum(res_df$is_minestrone, na.rm = TRUE)
pct_min_tot <- round(100 * n_min_tot / n_provati_tot, 1)
.add(sprintf("  Cluster auditati: %d | Provati: %d | Minestroni: %d | %% minestrone: %.1f%%",
             n_tot, n_provati_tot, n_min_tot, pct_min_tot))

cat(paste(summary_lines, collapse = "\n"), "\n")
writeLines(summary_lines, out_txt)
cat("\n  Summary salvato:", out_txt, "\n")
cat("\nFINE gate omogeneita'.\n")
