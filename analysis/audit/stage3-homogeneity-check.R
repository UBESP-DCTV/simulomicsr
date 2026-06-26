# Gate di omogeneita' Stadio 3 — misura la frazione di cluster "minestrone"
# (cluster che mescolano >=2 malattie o >=2 composti distinti).
#
# UTILIZZO:
#   Rscript analysis/audit/stage3-homogeneity-check.R \
#       [stage3_dir] [h5_path] [max_clusters] [max_samples_per_study]
#
# Valori default (se non passati come argomenti):
#   stage3_dir            = "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
#   h5_path               = "analysis/input/human_gene_v2.5.h5"
#   max_clusters          = 500   (Inf = full run; usa Inf per la produzione)
#   max_samples_per_study = 20    (campiona fino a N campioni per serie per velocita')
#
# OUTPUT:
#   analysis/audit/stage3-homogeneity-check-out.csv  (tabella per-cluster)
#   analysis/audit/stage3-homogeneity-check-out.txt  (summary stampato)
#
# RUNNER CORRETTO (renv attivo, devtools disponibile):
#   Rscript analysis/audit/stage3-homogeneity-check.R
# oppure con argomenti espliciti:
#   Rscript analysis/audit/stage3-homogeneity-check.R <stage3_dir> <h5> <max_cl> <max_sp>
#
# DRY: riusa le funzioni del modulo R/stage3-name-recovery.R via devtools::load_all().
# NON duplica i pattern .DISEASE_KEYS / .AGENT_KEYS / .CONTROL_VALS.
# La normalizzazione avviene tramite recover_identity() di simulomicsr.

suppressPackageStartupMessages({
  library(rhdf5)
  library(dplyr)
  library(arrow)
})

# ---------------------------------------------------------------------------
# 0. Parametri CLI e setup
# ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
stage3_dir            <- if (length(args) >= 1) args[1] else
  "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
h5_path               <- if (length(args) >= 2) args[2] else
  "analysis/input/human_gene_v2.5.h5"
max_clusters          <- if (length(args) >= 3) as.numeric(args[3]) else 500
max_samples_per_study <- if (length(args) >= 4) as.integer(args[4])  else 20L

# Normalizza percorsi relativi alla radice del pacchetto
pkg_root <- here::here()  # fallback se here non disponibile
if (!requireNamespace("here", quietly = TRUE)) {
  pkg_root <- normalizePath(".")
} else {
  pkg_root <- here::here()
}

if (!is.character(stage3_dir) || !file.exists(stage3_dir)) {
  stop("stage3_dir non trovata: ", stage3_dir)
}
if (!file.exists(h5_path)) {
  stop("H5 non trovato: ", h5_path)
}

cat("=== Gate omogeneita' Stadio 3 ===\n")
cat("  stage3_dir           :", stage3_dir, "\n")
cat("  h5_path              :", h5_path, "\n")
cat("  max_clusters         :", if (is.infinite(max_clusters)) "Inf (full run)" else max_clusters, "\n")
cat("  max_samples_per_study:", max_samples_per_study, "\n\n")

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
stopifnot(existsFunction <- exists(".load_ontology_dicts", envir = asNamespace("simulomicsr")))
.load_ontology_dicts_fn <- get(".load_ontology_dicts", envir = asNamespace("simulomicsr"))

# ---------------------------------------------------------------------------
# 2. Carica l'ontologia (singleton, richiesto da recover_identity)
# ---------------------------------------------------------------------------

cat("[2/6] Caricamento ontologia (MeSH + ChEBI + HGNC) — ~25s...\n")
t_onto <- system.time(onto <- .load_ontology_dicts_fn())
cat("  Ontologia caricata in", round(t_onto[3], 1), "sec\n\n")

# ---------------------------------------------------------------------------
# 3. Carica metadati H5 in bulk (fast: 888k x 4 campi in ~3s)
# ---------------------------------------------------------------------------

cat("[3/6] Lettura metadati campioni dall'H5...\n")
t_h5 <- system.time({
  h5_series_id  <- h5read(h5_path, "meta/samples/series_id")
  h5_geo_acc    <- h5read(h5_path, "meta/samples/geo_accession")
  h5_source     <- h5read(h5_path, "meta/samples/source_name_ch1")
  h5_char       <- h5read(h5_path, "meta/samples/characteristics_ch1")
  h5_title      <- h5read(h5_path, "meta/samples/title")
})
n_h5 <- length(h5_series_id)
cat("  Letti", n_h5, "campioni in", round(t_h5[3], 1), "sec\n")

# Costruisci indice series -> posizioni H5 (token match: comma-joined)
cat("  Costruzione indice series->posizioni...\n")
t_idx <- system.time({
  tokens_list    <- strsplit(h5_series_id, ",", fixed = TRUE)
  n_tokens       <- lengths(tokens_list)
  h5_positions   <- rep(seq_len(n_h5), n_tokens)
  flat_series    <- trimws(unlist(tokens_list, use.names = FALSE))
  series_index   <- split(h5_positions, flat_series)  # named list: series -> int[]
})
cat("  Indice pronto:", length(series_index), "series in", round(t_idx[3], 1), "sec\n\n")

# ---------------------------------------------------------------------------
# 4. Carica clusters.rds e filtra per audit
# ---------------------------------------------------------------------------

cat("[4/6] Caricamento cluster Stadio 3...\n")
clusters_path <- file.path(stage3_dir, "clusters.rds")
if (!file.exists(clusters_path)) stop("clusters.rds non trovato in: ", stage3_dir)
cl_all <- readRDS(clusters_path)
cat("  Cluster totali:", nrow(cl_all), "\n")

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
# 5. Elaborazione per-cluster
# ---------------------------------------------------------------------------

cat("[5/6] Estrazione identita' per cluster...\n")

# Helper: dato un cluster, restituisce le identita' distinte nominate per studi
.process_cluster <- function(cluster_id, kind, studies_in_cluster) {
  # Determina il llm_kind da passare a recover_identity
  llm_kind <- kind  # kind_effective_resolved (gia' corretto da v3.1.1)

  all_ids <- character(0)  # agent_id normalizzati raccolti
  n_studies_processed <- 0L

  for (series in studies_in_cluster) {
    # Lookup posizioni H5 per questa serie
    pos <- series_index[[series]]
    if (is.null(pos) || length(pos) == 0L) next
    n_studies_processed <- n_studies_processed + 1L

    # Campionamento campioni per studio
    if (length(pos) > max_samples_per_study) {
      set.seed(sum(utf8ToInt(cluster_id)) %% 10000L)
      pos <- sample(pos, max_samples_per_study)
    }

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
  }

  # Identita' distinte normalizzate (MeSH:D..., CHEBI:..., STR:<slug>)
  # recover_identity() normalizza sinonimi via lookup ontologico:
  # - se trovato in MeSH/ChEBI: stessa entita' -> stesso ID -> no falso minestrone
  # - se non trovato (STR fallback): slug lessicale, puo' divergere per riformulazioni
  named_ids    <- all_ids[!is.na(all_ids) & nzchar(all_ids)]
  distinct_ids <- unique(named_ids)

  # Conta per tipo di cluster
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
    n_studies_processed = n_studies_processed,
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
    results[[j]] <- .process_cluster(
      cluster_id       = row$cluster_id,
      kind             = row$kind_effective_resolved,
      studies_in_cluster = row$studies_in_cluster[[1L]]
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

.add("=== GATE OMOGENEITA' STADIO 3 ===")
.add("Data: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"))
.add("Stage3 dir: ", stage3_dir)
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
