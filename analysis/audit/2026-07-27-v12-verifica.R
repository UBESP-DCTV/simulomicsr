#!/usr/bin/env Rscript
# Verifica del re-cluster v12 sull'output VERO (ADR-0025 materializzato).
#
# Non e' un censimento di coerenza: quello si fa leggendo i gruppi uno per uno,
# dopo il re-pool. Qui si misura solo cio' che si puo' misurare adesso:
#   1. il ramo dal-contrasto esiste ed e' ben formato;
#   2. i pavimenti bandiera tengono;
#   3. la selezione dello Stadio 4 (ADR-0026) prende i cgroup e nient'altro;
#   4. i rami pair/group non sono cambiati rispetto a v10 (non-regressione).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V12 <- Sys.getenv("V12_DIR", "")
if (!nzchar(V12)) {
  cand <- sort(list.dirs("analysis/p4-output", recursive = FALSE))
  cand <- cand[grepl("stage3-v12-", cand)]
  if (!length(cand)) stop("nessuna dir stage3-v12- trovata; passare V12_DIR")
  V12 <- tail(cand, 1L)
}
V10 <- "analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"
cat("v12:", V12, "\nv10:", V10, "\n\n")

cl <- readRDS(file.path(V12, "clusters.rds"))
cat("cluster totali:", nrow(cl), "\n")

# --- 1. il ramo dal-contrasto ------------------------------------------------
cg <- cl[!is.na(cl$mode) & cl$mode == "cgroup", ]
cat("\n=== 1. RAMO DAL-CONTRASTO ===\n")
cat("cluster cgroup:", nrow(cg), "\n")
cat("level distinti:", paste(unique(cg$level), collapse = ","), "(atteso 5)\n")
cat("cluster_id con prefisso cgroup_L5_:", sum(startsWith(cg$cluster_id, "cgroup_L5_")), "/", nrow(cg), "\n")
for (co in c("contrast_entity", "contrast_direction", "contrast_control_key")) {
  cat(sprintf("  %-22s popolate: %d/%d\n", co, sum(!is.na(cg[[co]])), nrow(cg)))
}
cat("poolabili k>=3:", sum(cg$k >= 3L, na.rm = TRUE),
    "| k>=5:", sum(cg$k >= 5L, na.rm = TRUE),
    "| k max:", max(cg$k, na.rm = TRUE), "\n")

# --- 2. pavimenti bandiera ---------------------------------------------------
# Censimento 2026-07-27 DOPO le tre correzioni del 2026-07-26.
pav <- c("NCBITaxon:2697049" = 28L, "HGNC:11766" = 38L, "CHEBI:16412" = 26L,
         "CHEBI:68534" = 24L, "CHEBI:63637" = 13L)
nomi <- c("NCBITaxon:2697049" = "SARS-CoV-2", "HGNC:11766" = "TGFB1",
          "CHEBI:16412" = "LPS", "CHEBI:68534" = "enzalutamide",
          "CHEBI:63637" = "vemurafenib")
cat("\n=== 2. BANDIERA ===\n")
band <- do.call(rbind, lapply(names(pav), function(id) {
  s <- cg[!is.na(cg$contrast_entity) & cg$contrast_entity == id, ]
  k <- if (nrow(s)) max(s$k, na.rm = TRUE) else 0L
  data.frame(entita = id, nome = unname(nomi[id]), pavimento = pav[[id]],
             k_ottenuto = k, esito = if (k >= pav[[id]]) "OK" else "SOTTO",
             n_gruppi = nrow(s), stringsAsFactors = FALSE)
}))
print(band, row.names = FALSE)
if (any(band$esito == "SOTTO")) cat("\n*** ALMENO UNA BANDIERA SOTTO IL PAVIMENTO: FERMARSI E MISURARE ***\n")

# --- 3. selezione Stadio 4 (ADR-0026) ---------------------------------------
cat("\n=== 3. SELEZIONE STADIO 4 ===\n")
cfg <- stage4_default_config()
cat("deliverable_methods:", paste(cfg$deliverable_methods, collapse = ","), "\n")
sel <- simulomicsr:::.identify_layer_a_clusters(cl, cfg)
cat("cluster selezionati:", nrow(sel), "\n")
if (nrow(sel)) {
  print(table(sel$method))
  cat("k: min", min(sel$k), "| mediana", stats::median(sel$k), "| max", max(sel$k), "\n")
  cat("studi-slot totali (somma k):", sum(sel$k), "\n")
}
# contro-prova: coi quattro rami quanti sarebbero
cfg_all <- cfg; cfg_all$deliverable_methods <- c("rem", "mega", "mega_aug", "rem_group")
sel_all <- simulomicsr:::.identify_layer_a_clusters(cl, cfg_all)
cat("\ncontro-prova (tutti e quattro i rami):", nrow(sel_all), "cluster ->\n")
print(table(sel_all$method))

# --- 4. non-regressione pair/group vs v10 ------------------------------------
cat("\n=== 4. NON-REGRESSIONE vs v10 ===\n")
if (dir.exists(V10)) {
  cl10 <- readRDS(file.path(V10, "clusters.rds"))
  for (m in c("pair", "group")) {
    a <- sum(!is.na(cl$mode)   & cl$mode   == m)
    b <- sum(!is.na(cl10$mode) & cl10$mode == m)
    cat(sprintf("  mode=%-6s v12=%-7d v10=%-7d %s\n", m, a, b,
                if (a == b) "identico" else "DIVERSO (attenzione: le guardie del resolver 2026-07-25 possono spiegarlo)"))
  }
} else cat("  dir v10 assente, salto\n")

saveRDS(list(band = band, n_cgroup = nrow(cg), n_sel = nrow(sel), dir = V12),
        "analysis/audit/2026-07-27-v12-verifica.rds")
cat("\nfatto.\n")
