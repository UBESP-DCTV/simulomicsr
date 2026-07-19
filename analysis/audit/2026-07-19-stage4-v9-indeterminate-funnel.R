# analysis/audit/2026-07-19-stage4-v9-indeterminate-funnel.R
# ---------------------------------------------------------------------------
# Passi 1-2 dell'indagine LLM-fallback finale (sessione 2026-07-19+).
#
#   1. TABELLA-FUNNEL DI ALLOCAZIONE dei cluster Stadio 3 v9-final:
#      quanti cluster risolti in OGNI passaggio (via recovery_source raggruppato
#      per stadio) + breakdown per prefisso agent_id_resolved. In n. CLUSTER e in
#      n. STUDI-membri (sum k) e CAMPIONI (sum n_total). Casi totali in cima,
#      indeterminati in fondo.
#   2. CARATTERIZZAZIONE DEGLI INDETERMINATI (agent UNK + STR: finali): totale,
#      split UNK vs STR:, distribuzione per k (k=1 vs k>=2), per
#      kind_effective_resolved, per tessuto; + resolution_source (perche' sono
#      indeterminati). Questo dimensiona il run Mistral.
#
# Read-only: NON tocca la pipeline, NON richiede DGX. Output = console + CSV.
# Uso: Rscript analysis/audit/2026-07-19-stage4-v9-indeterminate-funnel.R
# ---------------------------------------------------------------------------
suppressMessages({library(dplyr)})

STAGE3 <- Sys.getenv("STAGE3",
  "analysis/p4-output/20260717T171550Z-stage3-v9-364547a7")
OUT_DIR <- "analysis/audit"

cl <- readRDS(file.path(STAGE3, "clusters.rds"))
cat(sprintf("clusters.rds: %d cluster x %d colonne\n\n", nrow(cl), ncol(cl)))

# --- helper: prefisso ontologico dell'agent_id finale --------------------
agent_prefix <- function(x) {
  ifelse(is.na(x), "<NA>",
   ifelse(grepl("^UNK", x), "UNK",
    ifelse(grepl(":", x), sub("^([A-Za-z]+):.*$", "\\1", x), "<other>")))
}
cl$apref <- agent_prefix(cl$agent_id_resolved)
# tessuto = 3o campo pipe dell'anchor_key (kind|agent_id|tissue|...)
cl$tissue <- vapply(strsplit(cl$anchor_key, "|", fixed = TRUE),
                    function(p) if (length(p) >= 3L) p[[3L]] else "", character(1))

# --- mappatura recovery_source -> stadio del funnel ----------------------
stage_of <- function(rs) {
  dplyr::case_when(
    rs == "MESH_NAME" ~ "1_disease",
    rs %in% c("CHEBI_ALIAS", "CHEMBL_ALIAS", "CHEMBL_VIA_CHEBI",
              "COMPOUND_COMBO") ~ "2_farmaci",
    rs == "K2_GENETIC" ~ "3_geni",
    rs %in% c("CYTOKINE_HGNC", "CYTOKINE_IMMPORT", "CYTOKINE_UNIPROT",
              "PATHOGEN_TAXID", "PATHOGEN_VERNACULAR", "PAMP_WHITELIST",
              "K3_MISTYPE_cytokine", "K3_MISTYPE_pathogen",
              "K3_MISTYPE_pathogen_pamp") ~ "4_biologici",
    rs == "LLM_NAME_CLEANUP" ~ "5_name_cleanup_v9",
    rs %in% c("STR_FALLBACK", "NO_RECOVERY") ~ "6_INDETERMINATI",
    TRUE ~ "9_altro")
}
cl$stage <- stage_of(cl$recovery_source)

# =========================================================================
# PASSO 1a — FUNNEL per stadio (vista recovery_source, grouping utente)
# =========================================================================
funnel_stage <- cl %>%
  group_by(stage) %>%
  summarise(n_cluster = n(),
            studi_membri_sumk = sum(k, na.rm = TRUE),
            campioni_sum_ntot = sum(n_total, na.rm = TRUE),
            .groups = "drop") %>%
  arrange(stage)
cat("=== PASSO 1a — FUNNEL per stadio (recovery_source) ===\n")
print(as.data.frame(funnel_stage))
cat(sprintf("\nTOTALE: %d cluster, sum k = %d, sum n_total = %d\n\n",
            sum(funnel_stage$n_cluster), sum(funnel_stage$studi_membri_sumk),
            sum(funnel_stage$campioni_sum_ntot)))

# dettaglio per singolo recovery_source
funnel_rs <- cl %>%
  group_by(stage, recovery_source) %>%
  summarise(n_cluster = n(),
            studi_membri_sumk = sum(k, na.rm = TRUE),
            campioni_sum_ntot = sum(n_total, na.rm = TRUE),
            .groups = "drop") %>%
  arrange(stage, desc(n_cluster))
cat("=== PASSO 1a-bis — dettaglio per recovery_source ===\n")
print(as.data.frame(funnel_rs))
cat("\n")

# =========================================================================
# PASSO 1b — BREAKDOWN per prefisso agent_id_resolved (stato FINALE onesto)
# =========================================================================
funnel_pref <- cl %>%
  mutate(resolved = !(apref %in% c("UNK", "STR"))) %>%
  group_by(apref, resolved) %>%
  summarise(n_cluster = n(),
            studi_membri_sumk = sum(k, na.rm = TRUE),
            campioni_sum_ntot = sum(n_total, na.rm = TRUE),
            .groups = "drop") %>%
  arrange(desc(resolved), desc(n_cluster))
cat("=== PASSO 1b — breakdown per prefisso agent_id_resolved ===\n")
print(as.data.frame(funnel_pref))
n_resolved <- sum(funnel_pref$n_cluster[funnel_pref$resolved])
n_indet    <- sum(funnel_pref$n_cluster[!funnel_pref$resolved])
cat(sprintf("\nRISOLTI (prefisso forte): %d | INDETERMINATI (UNK|STR): %d\n\n",
            n_resolved, n_indet))

# --- riconciliazione: recovery INDETERMINATI vs final UNK|STR ------------
cat("=== RICONCILIAZIONE recovery_source-INDETERMINATI vs final-state ===\n")
recov_indet <- cl$recovery_source %in% c("STR_FALLBACK", "NO_RECOVERY")
cat(sprintf("recovery_source in {STR_FALLBACK,NO_RECOVERY}: %d cluster\n",
            sum(recov_indet)))
cat(sprintf("  di cui con agent FINALE forte (gia' risolti da LLM+resolver): %d\n",
            sum(recov_indet & !(cl$apref %in% c("UNK", "STR")))))
cat(sprintf("  di cui agent FINALE UNK|STR (veri indeterminati): %d\n",
            sum(recov_indet & cl$apref %in% c("UNK", "STR"))))
cat(sprintf("Veri indeterminati TOTALI (final UNK|STR, ovunque): %d\n\n", n_indet))

# =========================================================================
# PASSO 2 — CARATTERIZZAZIONE DEGLI INDETERMINATI (final UNK|STR)
# =========================================================================
ind <- cl[cl$apref %in% c("UNK", "STR"), , drop = FALSE]
cat("=== PASSO 2 — INDETERMINATI: caratterizzazione ===\n")
cat(sprintf("Totale: %d  (UNK %d | STR %d)\n\n",
            nrow(ind), sum(ind$apref == "UNK"), sum(ind$apref == "STR")))

cat("--- split per k (k=1 vs k>=2) ---\n")
ind$k_class <- ifelse(ind$k >= 2L, "k>=2", "k=1")
print(as.data.frame(ind %>% group_by(apref, k_class) %>%
  summarise(n = n(), sum_k = sum(k), sum_ntot = sum(n_total), .groups = "drop")))
cat(sprintf("\nk>=2 indeterminati (candidati merge reali): %d  | k=1 (rumore isolato): %d\n\n",
            sum(ind$k >= 2L), sum(ind$k < 2L)))

cat("--- distribuzione k (indeterminati) ---\n")
print(table(pmin(ind$k, 10L), dnn = "k (cap a 10)"))
cat("\n")

cat("--- per kind_effective_resolved (top 20) ---\n")
print(as.data.frame(ind %>% group_by(kind_effective_resolved) %>%
  summarise(n = n(), k_ge2 = sum(k >= 2L), .groups = "drop") %>%
  arrange(desc(n)) %>% head(20)))
cat("\n")

cat("--- per tessuto (top 20) ---\n")
print(as.data.frame(ind %>% group_by(tissue) %>%
  summarise(n = n(), k_ge2 = sum(k >= 2L), .groups = "drop") %>%
  arrange(desc(n)) %>% head(20)))
cat("\n")

cat("--- per resolution_source (PERCHE' indeterminati) ---\n")
print(as.data.frame(ind %>% group_by(resolution_source) %>%
  summarise(n = n(), k_ge2 = sum(k >= 2L), .groups = "drop") %>%
  arrange(desc(n))))
cat("\n")

# =========================================================================
# OUTPUT CSV (artefatti auditabili)
# =========================================================================
write.csv(funnel_stage, file.path(OUT_DIR, "2026-07-19-v9-funnel-stage.csv"), row.names = FALSE)
write.csv(funnel_rs,    file.path(OUT_DIR, "2026-07-19-v9-funnel-recovery-source.csv"), row.names = FALSE)
write.csv(funnel_pref,  file.path(OUT_DIR, "2026-07-19-v9-funnel-agent-prefix.csv"), row.names = FALSE)
ind_summary <- ind %>% group_by(apref, k_class, kind_effective_resolved) %>%
  summarise(n = n(), sum_ntot = sum(n_total), .groups = "drop") %>% arrange(desc(n))
write.csv(ind_summary,  file.path(OUT_DIR, "2026-07-19-v9-indeterminate-breakdown.csv"), row.names = FALSE)
cat("CSV scritti in analysis/audit/2026-07-19-v9-*.csv\n")
