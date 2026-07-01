# Smoke di copertura PRE-fullrun: recupero biologici (citochine + patogeni)
# con i dizionari REALI (ImmPort, NCBITaxon taxdump, UniProt).
#
# SCOPO (Task 19 — gate decisionale):
#   Misura quanto `recover_identity()` con i dizionari biologici completi
#   recupera sui cluster v5 residuali (agent_id_resolved UNK o STR:*) per
#   kind cytokine_stim e pathogen_or_aggregate_exposure.
#   Valida inoltre due canary di precisione:
#     - CANARY I2: cluster small_molecule gia' risolti (CHEBI:/CHEMBL:) non
#       devono essere flippati a biologici da K3.
#     - CANARY generici: termini-classe nudi non producono ID forti.
#
# UTILIZZO:
#   Rscript analysis/audit/stage3-biologics-smoke.R \
#       [stage3_dir] [h5_path] [stage2_master]
#
# Defaults:
#   stage3_dir   = analysis/p4-output/20260629T041343Z-stage3-v5-364547a7
#   h5_path      = analysis/input/human_gene_v2.5.h5
#   stage2_master= analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl
#
# OUTPUT:
#   analysis/audit/stage3-biologics-smoke-out.csv   (tabella per-cluster)
#   analysis/audit/stage3-biologics-smoke-out.txt   (summary)
#
# RUNNER (renv attivo — rhdf5, arrow, devtools disponibili):
#   Rscript analysis/audit/stage3-biologics-smoke.R

suppressPackageStartupMessages({
  library(rhdf5)
  library(dplyr)
  library(arrow)
  library(jsonlite)
})

# ---------------------------------------------------------------------------
# 0. Parametri CLI
# ---------------------------------------------------------------------------

args            <- commandArgs(trailingOnly = TRUE)
STAGE3_DIR      <- if (length(args) >= 1) args[1] else
  "analysis/p4-output/20260629T041343Z-stage3-v5-364547a7"
H5_PATH         <- if (length(args) >= 2) args[2] else
  "analysis/input/human_gene_v2.5.h5"
STAGE2_MASTER   <- if (length(args) >= 3) args[3] else
  "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

# Campionamento (parametrizzabile via env)
N_CYT   <- as.integer(Sys.getenv("N_CYT",   "400"))  # campione cytokine residui
N_PAT   <- as.integer(Sys.getenv("N_PAT",   "400"))  # campione pathogen residui
N_K3    <- as.integer(Sys.getenv("N_K3",    "200"))  # campione small_mol per canary I2

OUT_CSV <- "analysis/audit/stage3-biologics-smoke-out.csv"
OUT_TXT <- "analysis/audit/stage3-biologics-smoke-out.txt"

cat("=== Smoke copertura biologici (citochine + patogeni) ===\n")
cat("  stage3_dir   :", STAGE3_DIR, "\n")
cat("  h5_path      :", H5_PATH, "\n")
cat("  stage2_master:", STAGE2_MASTER, "\n")
cat("  N_CYT =", N_CYT, "| N_PAT =", N_PAT, "| N_K3 =", N_K3, "\n\n")

for (f in c(STAGE3_DIR, H5_PATH, STAGE2_MASTER)) {
  if (!file.exists(f)) stop("File/directory non trovato: ", f)
}

# ---------------------------------------------------------------------------
# 1. Carica pacchetto simulomicsr (DRY: recover_identity + .load_ontology_dicts)
# ---------------------------------------------------------------------------

cat("[1/8] Caricamento pacchetto simulomicsr...\n")
if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all(quiet = TRUE)
} else if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(quiet = TRUE)
} else {
  stop("devtools o pkgload necessari per caricare il pacchetto.")
}
stopifnot(exists("recover_identity"))
.load_ontology_dicts_fn <- get(".load_ontology_dicts", envir = asNamespace("simulomicsr"))

# ---------------------------------------------------------------------------
# 2. Carica ontologia COMPLETA (inclusi ImmPort, NCBITaxon, UniProt)
# ---------------------------------------------------------------------------

cat("[2/8] Caricamento ontologia COMPLETA (MeSH + ChEBI + HGNC + ImmPort + Taxon + UniProt) ~5min...\n")
t_onto <- system.time(onto <- .load_ontology_dicts_fn())
cat(sprintf("  Ontologia caricata in %.1f sec\n", t_onto[3]))
cat("  has_immport   :", isTRUE(onto$has_immport), "\n")
cat("  has_taxonomy  :", isTRUE(onto$has_taxonomy), "\n")
cat("  has_uniprot   :", isTRUE(onto$has_uniprot), "\n\n")
# Gate: senza i dizionari biologici lo smoke non e' valido
if (!isTRUE(onto$has_immport))  stop("ImmPort non disponibile — costruire prima il dict.")
if (!isTRUE(onto$has_taxonomy)) stop("NCBITaxon non disponibile — costruire prima il dict.")

# ---------------------------------------------------------------------------
# 3. Carica metadati H5 in bulk
# ---------------------------------------------------------------------------

cat("[3/8] Lettura metadati campioni dall'H5...\n")
t_h5 <- system.time({
  h5_geo_acc <- h5read(H5_PATH, "meta/samples/geo_accession")
  h5_source  <- h5read(H5_PATH, "meta/samples/source_name_ch1")
  h5_char    <- h5read(H5_PATH, "meta/samples/characteristics_ch1")
  h5_title   <- h5read(H5_PATH, "meta/samples/title")
})
cat(sprintf("  Letti %d campioni in %.1f sec\n\n", length(h5_geo_acc), t_h5[3]))

# Indice GSM -> posizione H5 (vettorizzato, O(1) successivo via names())
idx_by_gsm              <- seq_along(h5_geo_acc)
names(idx_by_gsm)       <- h5_geo_acc

# ---------------------------------------------------------------------------
# 4. Carica clusters.rds + assignments + stage2 master
# ---------------------------------------------------------------------------

cat("[4/8] Caricamento cluster Stadio 3 v5...\n")
cl_all <- readRDS(file.path(STAGE3_DIR, "clusters.rds"))
cat("  Cluster totali:", nrow(cl_all), "\n")
cat("  kind_effective_resolved:\n")
print(table(cl_all$kind_effective_resolved, useNA = "ifany"))

# Assignments: mappa cluster_id -> record_id
asgn_path <- file.path(STAGE3_DIR, "assignments.parquet")
if (!file.exists(asgn_path)) stop("assignments.parquet non trovato in: ", STAGE3_DIR)
asgn        <- read_parquet(asgn_path)
cl_records  <- split(asgn$record_id, asgn$cluster_id)

# Mappa record_id -> GSM trattati (DRY: helper condiviso audit)
source("analysis/audit/_gsm-lookup-helper.R")
rec_env <- build_record_gsm_lookup(STAGE2_MASTER)

# Helper: restituisce il PRIMO GSM trattato di un cluster (deterministico)
.get_first_gsm <- function(cid) {
  rids <- unique(cl_records[[cid]])
  if (!length(rids)) return(NA_character_)
  gsms <- unique(unlist(
    lapply(rids, function(r) get0(r, envir = rec_env, ifnotfound = NULL)),
    use.names = FALSE
  ))
  if (!length(gsms)) return(NA_character_)
  gsms[[1L]]
}

# Helper: legge source/char/title dall'H5 per un GSM
.get_h5_meta <- function(gsm) {
  idx <- idx_by_gsm[[gsm]]
  if (is.na(idx) || is.null(idx)) {
    return(list(source = NA_character_, char = NA_character_, title = NA_character_,
                in_h5 = FALSE))
  }
  list(source = h5_source[idx], char = h5_char[idx], title = h5_title[idx],
       in_h5 = TRUE)
}

# ---------------------------------------------------------------------------
# 5. Selezione cluster residuali (UNK o STR:*) per cytokine e pathogen
# ---------------------------------------------------------------------------

cat("\n[5/8] Selezione cluster residuali (UNK / STR:*)...\n")

.is_residual <- function(agent_id) {
  agent_id == "UNK" | startsWith(as.character(agent_id), "STR:")
}

# Cytokine: residui
cl_cyt_all  <- cl_all[cl_all$kind_effective_resolved == "cytokine_stim" &
                       .is_residual(cl_all$agent_id_resolved), ]
cat(sprintf("  Cytokine residuali: %d su %d (%.1f%%)\n",
            nrow(cl_cyt_all),
            sum(cl_all$kind_effective_resolved == "cytokine_stim"),
            100 * nrow(cl_cyt_all) /
              max(1, sum(cl_all$kind_effective_resolved == "cytokine_stim"))))
cat("  breakdown:\n")
print(table(cl_cyt_all$agent_id_resolved == "UNK"))

# Pathogen: residui
cl_pat_all  <- cl_all[cl_all$kind_effective_resolved == "pathogen_or_aggregate_exposure" &
                       .is_residual(cl_all$agent_id_resolved), ]
cat(sprintf("  Pathogen residuali : %d su %d (%.1f%%)\n",
            nrow(cl_pat_all),
            sum(cl_all$kind_effective_resolved == "pathogen_or_aggregate_exposure"),
            100 * nrow(cl_pat_all) /
              max(1, sum(cl_all$kind_effective_resolved == "pathogen_or_aggregate_exposure"))))

# Campionamento deterministico (seed=42)
set.seed(42L)
cl_cyt <- if (nrow(cl_cyt_all) > N_CYT)
  cl_cyt_all[sample(nrow(cl_cyt_all), N_CYT), ] else cl_cyt_all
cl_pat <- if (nrow(cl_pat_all) > N_PAT)
  cl_pat_all[sample(nrow(cl_pat_all), N_PAT), ] else cl_pat_all

cat(sprintf("  Campione cytokine : %d cluster\n", nrow(cl_cyt)))
cat(sprintf("  Campione pathogen : %d cluster\n", nrow(cl_pat)))

# ---------------------------------------------------------------------------
# 6. Funzione core: recupero deterministico via recover_identity
# ---------------------------------------------------------------------------

.run_recovery <- function(cluster_id, kind) {
  gsm  <- .get_first_gsm(cluster_id)
  if (is.na(gsm)) {
    return(list(gsm = NA_character_, in_h5 = FALSE,
                agent_id = NA_character_, canon = NA_character_,
                src = "NO_GSM", is_strong = FALSE))
  }
  m <- .get_h5_meta(gsm)
  if (!m$in_h5) {
    return(list(gsm = gsm, in_h5 = FALSE,
                agent_id = NA_character_, canon = NA_character_,
                src = "GSM_NOT_IN_H5", is_strong = FALSE))
  }
  res <- tryCatch(
    recover_identity(
      source          = m$source,
      characteristics = m$char,
      title           = m$title,
      llm_kind        = kind,
      ontology_env    = onto
    ),
    error = function(e) list(
      agent_id        = NA_character_,
      canonical_name  = NA_character_,
      recovery_source = paste0("ERROR:", conditionMessage(e))
    )
  )
  # "forte" = HGNC: per citochina; NCBITaxon: o CHEBI: per patogeno/PAMP
  strong <- if (kind == "cytokine_stim") {
    !is.null(res$agent_id) && !is.na(res$agent_id) && startsWith(res$agent_id, "HGNC:")
  } else {
    !is.null(res$agent_id) && !is.na(res$agent_id) &&
      (startsWith(res$agent_id, "NCBITaxon:") | startsWith(res$agent_id, "CHEBI:"))
  }
  list(
    gsm      = gsm,
    in_h5    = TRUE,
    agent_id = res$agent_id,
    canon    = res$canonical_name,
    src      = res$recovery_source,
    is_strong = strong
  )
}

# ---------------------------------------------------------------------------
# 6a. Esegui recovery su citochine
# ---------------------------------------------------------------------------

cat("\n[6a/8] Recovery deterministico su cluster cytokine_stim residuali...\n")
res_cyt <- vector("list", nrow(cl_cyt))
t_cyt <- system.time({
  for (j in seq_len(nrow(cl_cyt))) {
    res_cyt[[j]] <- .run_recovery(cl_cyt$cluster_id[j], "cytokine_stim")
    if (j %% 100L == 0L || j == nrow(cl_cyt))
      cat("  ... cytokine", j, "/", nrow(cl_cyt), "\n")
  }
})
cat(sprintf("  Tempo: %.1f sec\n", t_cyt[3]))

# Tabella risultati citochine
df_cyt <- data.frame(
  cluster_id       = cl_cyt$cluster_id,
  kind             = "cytokine_stim",
  agent_id_v5      = cl_cyt$agent_id_resolved,
  n_studies        = cl_cyt$n_studies,
  gsm              = vapply(res_cyt, `[[`, character(1), "gsm"),
  in_h5            = vapply(res_cyt, `[[`, logical(1), "in_h5"),
  new_agent_id     = vapply(res_cyt, `[[`, character(1), "agent_id"),
  new_canon        = vapply(res_cyt, `[[`, character(1), "canon"),
  new_src          = vapply(res_cyt, `[[`, character(1), "src"),
  is_strong        = vapply(res_cyt, `[[`, logical(1), "is_strong"),
  stringsAsFactors = FALSE
)

# Riepilogo citochine
n_cyt        <- nrow(df_cyt)
n_cyt_h5     <- sum(df_cyt$in_h5, na.rm = TRUE)
n_cyt_strong <- sum(df_cyt$is_strong, na.rm = TRUE)
cat("\n  === RISULTATI CYTOKINE ===\n")
cat(sprintf("  Cluster campionati   : %d\n", n_cyt))
cat(sprintf("  GSM trovati in H5    : %d (%.1f%%)\n", n_cyt_h5, 100 * n_cyt_h5 / n_cyt))
cat(sprintf("  Recuperati HGNC:     : %d / %d GSM-in-H5 = %.1f%%\n",
            n_cyt_strong, n_cyt_h5,
            100 * n_cyt_strong / max(1, n_cyt_h5)))
cat("  Breakdown per recovery_source:\n")
print(table(df_cyt$new_src, useNA = "ifany"))

# ---------------------------------------------------------------------------
# 6b. Esegui recovery su patogeni
# ---------------------------------------------------------------------------

cat("\n[6b/8] Recovery deterministico su cluster pathogen residuali...\n")
res_pat <- vector("list", nrow(cl_pat))
t_pat <- system.time({
  for (j in seq_len(nrow(cl_pat))) {
    res_pat[[j]] <- .run_recovery(cl_pat$cluster_id[j], "pathogen_or_aggregate_exposure")
    if (j %% 100L == 0L || j == nrow(cl_pat))
      cat("  ... pathogen", j, "/", nrow(cl_pat), "\n")
  }
})
cat(sprintf("  Tempo: %.1f sec\n", t_pat[3]))

df_pat <- data.frame(
  cluster_id       = cl_pat$cluster_id,
  kind             = "pathogen_or_aggregate_exposure",
  agent_id_v5      = cl_pat$agent_id_resolved,
  n_studies        = cl_pat$n_studies,
  gsm              = vapply(res_pat, `[[`, character(1), "gsm"),
  in_h5            = vapply(res_pat, `[[`, logical(1), "in_h5"),
  new_agent_id     = vapply(res_pat, `[[`, character(1), "agent_id"),
  new_canon        = vapply(res_pat, `[[`, character(1), "canon"),
  new_src          = vapply(res_pat, `[[`, character(1), "src"),
  is_strong        = vapply(res_pat, `[[`, logical(1), "is_strong"),
  stringsAsFactors = FALSE
)

n_pat        <- nrow(df_pat)
n_pat_h5     <- sum(df_pat$in_h5, na.rm = TRUE)
n_pat_strong <- sum(df_pat$is_strong, na.rm = TRUE)
cat("\n  === RISULTATI PATHOGEN ===\n")
cat(sprintf("  Cluster campionati   : %d\n", n_pat))
cat(sprintf("  GSM trovati in H5    : %d (%.1f%%)\n", n_pat_h5, 100 * n_pat_h5 / n_pat))
cat(sprintf("  Recuperati NCBITaxon:/CHEBI: : %d / %d GSM-in-H5 = %.1f%%\n",
            n_pat_strong, n_pat_h5,
            100 * n_pat_strong / max(1, n_pat_h5)))
cat("  Breakdown per recovery_source:\n")
print(table(df_pat$new_src, useNA = "ifany"))

# ---------------------------------------------------------------------------
# 7. CANARY I2 — K3 mistype su small_molecule gia' risolti
# ---------------------------------------------------------------------------

cat("\n[7/8] CANARY I2: K3 mistype su cluster small_molecule gia' risolti...\n")

# Seleziona cluster small_molecule con CHEBI: o CHEMBL: gia' risolto
cl_sm_resolved <- cl_all[
  cl_all$kind_effective_resolved == "small_molecule" &
    (startsWith(as.character(cl_all$agent_id_resolved), "CHEBI:") |
     startsWith(as.character(cl_all$agent_id_resolved), "CHEMBL:")), ]
cat(sprintf("  small_molecule CHEBI/CHEMBL gia' risolti: %d cluster\n", nrow(cl_sm_resolved)))
set.seed(99L)
cl_sm_k3 <- if (nrow(cl_sm_resolved) > N_K3)
  cl_sm_resolved[sample(nrow(cl_sm_resolved), N_K3), ] else cl_sm_resolved
cat(sprintf("  Campione K3 canary: %d cluster\n\n", nrow(cl_sm_k3)))

# Funzione K3: per small_molecule, controlla se viene flippato
.run_k3_check <- function(cluster_id) {
  gsm <- .get_first_gsm(cluster_id)
  if (is.na(gsm)) return(list(gsm = NA_character_, src = "NO_GSM", flipped = FALSE))
  m   <- .get_h5_meta(gsm)
  if (!m$in_h5) return(list(gsm = gsm, src = "GSM_NOT_IN_H5", flipped = FALSE))
  res <- tryCatch(
    recover_identity(
      source          = m$source,
      characteristics = m$char,
      title           = m$title,
      llm_kind        = "small_molecule",
      ontology_env    = onto
    ),
    error = function(e) list(recovery_source = paste0("ERROR:", conditionMessage(e)))
  )
  flipped <- !is.null(res$recovery_source) &&
    startsWith(as.character(res$recovery_source), "K3_MISTYPE_")
  list(gsm = gsm, src = res$recovery_source %||% "UNKNOWN", flipped = isTRUE(flipped),
       new_agent = res$agent_id %||% NA_character_,
       new_kind  = res$kind %||% NA_character_)
}

res_k3 <- vector("list", nrow(cl_sm_k3))
t_k3 <- system.time({
  for (j in seq_len(nrow(cl_sm_k3))) {
    res_k3[[j]] <- .run_k3_check(cl_sm_k3$cluster_id[j])
    if (j %% 50L == 0L || j == nrow(cl_sm_k3))
      cat("  ... K3 canary", j, "/", nrow(cl_sm_k3), "\n")
  }
})
cat(sprintf("  Tempo: %.1f sec\n", t_k3[3]))

df_k3 <- data.frame(
  cluster_id       = cl_sm_k3$cluster_id,
  agent_id_v5      = cl_sm_k3$agent_id_resolved,
  gsm              = vapply(res_k3, `[[`, character(1), "gsm"),
  new_src          = vapply(res_k3, `[[`, character(1), "src"),
  flipped          = vapply(res_k3, `[[`, logical(1), "flipped"),
  new_agent        = sapply(res_k3, function(r) r$new_agent %||% NA_character_),
  new_kind         = sapply(res_k3, function(r) r$new_kind %||% NA_character_),
  stringsAsFactors = FALSE
)

n_k3         <- nrow(df_k3)
n_k3_flipped <- sum(df_k3$flipped, na.rm = TRUE)
cat("\n  === CANARY I2 (K3 mistype su small_molecule risolti) ===\n")
cat(sprintf("  Cluster testati    : %d\n", n_k3))
cat(sprintf("  Flippati a biologic: %d / %d = %.2f%%\n",
            n_k3_flipped, n_k3, 100 * n_k3_flipped / max(1, n_k3)))
if (n_k3_flipped > 0) {
  cat("  ATTENZIONE: falsi positivi K3 trovati:\n")
  fp <- df_k3[df_k3$flipped, c("cluster_id", "agent_id_v5", "new_agent", "new_kind", "new_src")]
  print(fp)
} else {
  cat("  OK: nessun falso positivo K3 (0 flip). Gate PASS.\n")
}

# ---------------------------------------------------------------------------
# 8. CANARY generici — termini-classe nudi NON devono produrre ID forti
# ---------------------------------------------------------------------------

cat("\n[8/8] CANARY generici (termini nudi 'interferon', 'virus', ecc.)...\n")

.GENERIC_BIOLOGICAL_STOPLIST <- get(".GENERIC_BIOLOGICAL_STOPLIST",
                                     envir = asNamespace("simulomicsr"))

# Termini generici da testare per ogni kind
canary_terms <- list(
  cytokine_stim = c(
    "interferon", "cytokine", "interleukin", "chemokine",
    "stimulation", "growth factor"
  ),
  pathogen_or_aggregate_exposure = c(
    "virus", "bacteria", "infection", "pathogen",
    "exposure", "bacteria infection"
  )
)

canary_results <- list()
for (kind in names(canary_terms)) {
  for (term in canary_terms[[kind]]) {
    # Usa source/characteristics/title fittizi con il termine
    # (simula un campione con solo la caratteristica)
    res <- tryCatch(
      recover_identity(
        source          = paste("cells treated with", term),
        characteristics = paste0("treatment: ", term),
        title           = paste("RNA-seq", term, "treatment"),
        llm_kind        = kind,
        ontology_env    = onto
      ),
      error = function(e) list(agent_id = NA_character_, recovery_source = "ERROR")
    )
    strong <- if (kind == "cytokine_stim") {
      !is.null(res$agent_id) && !is.na(res$agent_id) && startsWith(res$agent_id, "HGNC:")
    } else {
      !is.null(res$agent_id) && !is.na(res$agent_id) &&
        (startsWith(res$agent_id, "NCBITaxon:") | startsWith(res$agent_id, "CHEBI:"))
    }
    canary_results[[length(canary_results) + 1L]] <- list(
      kind = kind, term = term,
      agent_id = res$agent_id %||% NA_character_,
      src      = res$recovery_source %||% NA_character_,
      strong   = strong
    )
  }
}

df_canary <- do.call(rbind, lapply(canary_results, function(r) {
  data.frame(kind = r$kind, term = r$term, agent_id = r$agent_id,
             src = r$src, strong = r$strong, stringsAsFactors = FALSE)
}))

cat("\n  === CANARY GENERICI ===\n")
print(df_canary)
n_generic_strong <- sum(df_canary$strong, na.rm = TRUE)
if (n_generic_strong > 0) {
  cat(sprintf("\n  ATTENZIONE: %d termini generici hanno prodotto un ID forte!\n", n_generic_strong))
  print(df_canary[df_canary$strong, ])
} else {
  cat("\n  OK: tutti i termini generici -> STR/NA (0 falsi positivi). Gate PASS.\n")
}

# ---------------------------------------------------------------------------
# Salvataggio output e riepilogo finale
# ---------------------------------------------------------------------------

cat("\n=== RIEPILOGO FINALE ===\n")
cat(sprintf("(a) CYTOKINE recupero HGNC   : %d / %d = %.1f%%\n",
            n_cyt_strong, n_cyt_h5, 100 * n_cyt_strong / max(1, n_cyt_h5)))
cat(sprintf("(b) PATHOGEN recupero forte  : %d / %d = %.1f%%\n",
            n_pat_strong, n_pat_h5, 100 * n_pat_strong / max(1, n_pat_h5)))
cat(sprintf("(c) K3 falsi positivi        : %d / %d = %.2f%%\n",
            n_k3_flipped, n_k3, 100 * n_k3_flipped / max(1, n_k3)))
cat(sprintf("(d) Canary generici forti    : %d / %d\n",
            n_generic_strong, nrow(df_canary)))

# Tabella aggregata output
df_all <- bind_rows(
  df_cyt |> select(cluster_id, kind, agent_id_v5, n_studies, gsm, in_h5,
                   new_agent_id, new_canon, new_src, is_strong),
  df_pat |> select(cluster_id, kind, agent_id_v5, n_studies, gsm, in_h5,
                   new_agent_id, new_canon, new_src, is_strong)
)

write.csv(df_all, OUT_CSV, row.names = FALSE, quote = TRUE, na = "")
cat("\n  Tabella salvata:", OUT_CSV, "\n")

# Summary testuale
lines <- character(0)
.a <- function(...) lines <<- c(lines, paste0(...))
.a("=== SMOKE COPERTURA BIOLOGICI (Task 19) ===")
.a("Data     : ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"))
.a("Stage3   : ", STAGE3_DIR)
.a("")
.a("--- Dizionari caricati ---")
.a("  has_immport   : ", isTRUE(onto$has_immport))
.a("  has_taxonomy  : ", isTRUE(onto$has_taxonomy))
.a("  has_uniprot   : ", isTRUE(onto$has_uniprot))
.a("  has_go_cytokine:", isTRUE(onto$has_go_cytokine))
.a("")
.a("--- Residui v5 (UNK + STR:*) ---")
.a(sprintf("  cytokine_stim       residuali: %d su %d (%.1f%%)",
           nrow(cl_cyt_all),
           sum(cl_all$kind_effective_resolved == "cytokine_stim"),
           100 * nrow(cl_cyt_all) / max(1, sum(cl_all$kind_effective_resolved == "cytokine_stim"))))
.a(sprintf("  pathogen            residuali: %d su %d (%.1f%%)",
           nrow(cl_pat_all),
           sum(cl_all$kind_effective_resolved == "pathogen_or_aggregate_exposure"),
           100 * nrow(cl_pat_all) / max(1, sum(cl_all$kind_effective_resolved == "pathogen_or_aggregate_exposure"))))
.a("")
.a("--- (a) Recovery CYTOKINE (ImmPort + HGNC + UniProt) ---")
.a(sprintf("  Campione: %d cluster | GSM in H5: %d (%.1f%%)",
           n_cyt, n_cyt_h5, 100 * n_cyt_h5 / max(1, n_cyt)))
.a(sprintf("  Recuperati HGNC: : %d / %d = %.1f%%",
           n_cyt_strong, n_cyt_h5, 100 * n_cyt_strong / max(1, n_cyt_h5)))
cyt_src_tab <- table(df_cyt$new_src)
for (nm in sort(names(cyt_src_tab))) {
  .a(sprintf("    %-35s : %d", nm, cyt_src_tab[[nm]]))
}
.a("")
.a("--- (b) Recovery PATHOGEN (PAMP_WHITELIST + VERNACULAR + NCBITaxon taxdump) ---")
.a(sprintf("  Campione: %d cluster | GSM in H5: %d (%.1f%%)",
           n_pat, n_pat_h5, 100 * n_pat_h5 / max(1, n_pat)))
.a(sprintf("  Recuperati NCBITaxon:/CHEBI: : %d / %d = %.1f%%",
           n_pat_strong, n_pat_h5, 100 * n_pat_strong / max(1, n_pat_h5)))
pat_src_tab <- table(df_pat$new_src)
for (nm in sort(names(pat_src_tab))) {
  .a(sprintf("    %-35s : %d", nm, pat_src_tab[[nm]]))
}
.a("")
.a("--- (c) CANARY I2 (K3 mistype — small_molecule CHEBI:/CHEMBL: risolti) ---")
.a(sprintf("  Campione: %d cluster", n_k3))
.a(sprintf("  Flippati a biologic (K3_MISTYPE_*): %d / %d = %.2f%%",
           n_k3_flipped, n_k3, 100 * n_k3_flipped / max(1, n_k3)))
if (n_k3_flipped > 0) {
  .a("  FALSI POSITIVI:")
  for (i in seq_len(nrow(df_k3[df_k3$flipped, ]))) {
    fp_i <- df_k3[df_k3$flipped, ][i, ]
    .a(sprintf("    %s : %s -> %s (%s)", fp_i$cluster_id, fp_i$agent_id_v5,
               fp_i$new_agent, fp_i$new_src))
  }
} else {
  .a("  Gate PASS: 0 falsi positivi K3")
}
.a("")
.a("--- (d) CANARY GENERICI ---")
for (i in seq_len(nrow(df_canary))) {
  r <- df_canary[i, ]
  stato <- if (r$strong) "FORTE (FALSO POSITIVO!)" else "STR/NA (ok)"
  .a(sprintf("  [%s] '%s' -> %s (%s) = %s", r$kind, r$term, r$agent_id, r$src, stato))
}
n_gen_fp <- sum(df_canary$strong, na.rm = TRUE)
.a(sprintf("  Gate PASS: %d / %d forti (atteso 0)", n_gen_fp, nrow(df_canary)))
.a("")
.a("--- RACCOMANDAZIONE ---")
go_nogo <- if (n_k3_flipped == 0 && n_gen_fp == 0 &&
               (n_cyt_strong > 0 || n_pat_strong > 0)) {
  "GO: copertura positiva + precision gate PASS -> autorizzato re-cluster v6"
} else if (n_k3_flipped > 5 || n_gen_fp > 0) {
  "NO-GO: gate di precisione fallito (K3 falsi positivi o generici forti)"
} else {
  "CONDIZIONALE: rivedere i numeri con l'utente"
}
.a(go_nogo)

cat(paste(lines, collapse = "\n"), "\n")
writeLines(lines, OUT_TXT)
cat("\n  Summary salvato:", OUT_TXT, "\n")
cat("\nFINE smoke copertura biologici.\n")
