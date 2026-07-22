# analysis/p5-stage4-layer-b-select-v10.R
# ---------------------------------------------------------------------------
# SELECTION Layer B v10 — DETERMINISTICA, rem_group-focused. Il deliverable v10
# sono le 184 meta-analisi cross-studio NOMINATE (rem_group). La shortlist
# generica (p5-...-shortlist-v10.R) ranka in cima i mega_aug (n_sig piu' alto) e
# schiaccia i rem_group nel pick stratificato → qui selezioniamo DIRETTAMENTE dai
# rem_group gate-passing (k_eff>=4, n_sig_05>=50, max_logFC>=1.5, kind non-degenere,
# label_trust), con i flagship GARANTITI (uno per entita', al max n_sig_strong) +
# diversita' per kind. Output: analysis/layer-b-selection-v10.csv (per il build).
#
# Nessuna scelta umana: top-N deterministico. Uso:
#   Rscript analysis/p5-stage4-layer-b-select-v10.R
# ---------------------------------------------------------------------------
suppressPackageStartupMessages({ library(dplyr); library(cli) })
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L || is.na(a)) b else a

SUMMARY <- "analysis/p4-output/layer-b-cluster-summary-v10.rds"
OUT     <- "analysis/layer-b-selection-v10.csv"
N_TARGET <- 18L          # case study target
PER_KIND_CAP <- 5L       # max per kind_effective (diversita')
DEG <- c("none", "vehicle_only", "unknown")

# Flagship: entita' validate (opzione C = re-gate v10). Una case study garantita
# per ciascuna (il cluster col n_sig_strong massimo).
FLAGSHIP <- c("MeSH:D001943", "MeSH:D015179", "MeSH:D006528", "MeSH:D011471",
              "CHEBI:68534", "CHEBI:41774", "CHEBI:31638", "NCBITaxon:2697049",
              "NCBITaxon:1773", "CHEBI:16412")

s <- readRDS(SUMMARY)
rg <- s |>
  filter(method == "rem_group",
         k_effective >= 4L, n_sig_05 >= 50L, max_abs_logFC >= 1.5,
         !(kind_effective %in% DEG),
         is.na(kind_override_reason) | kind_override_reason != "LLM_CONTRADICTION_DETECTED")
cli_alert_info("rem_group gate-passing: {nrow(rg)}")

# una riga per ENTITA' (agent_id): il cluster col n_sig_strong massimo
by_entity <- rg |> group_by(agent_id) |>
  slice_max(n_sig_strong, n = 1, with_ties = FALSE) |> ungroup()
cli_alert_info("entita' distinte (agent_id): {nrow(by_entity)}")

# 1) flagship garantiti
flag_rows <- by_entity |> filter(agent_id %in% FLAGSHIP)
# 2) riempi fino a N_TARGET dagli altri, per n_sig_strong, con cap per kind
rest <- by_entity |> filter(!(agent_id %in% FLAGSHIP)) |> arrange(desc(n_sig_strong))
picked <- flag_rows
kind_count <- table(factor(picked$kind_effective, levels = unique(by_entity$kind_effective)))
for (i in seq_len(nrow(rest))) {
  if (nrow(picked) >= N_TARGET) break
  k <- rest$kind_effective[i]
  if ((kind_count[k] %||% 0L) >= PER_KIND_CAP) next
  picked <- bind_rows(picked, rest[i, ])
  kind_count[k] <- (kind_count[k] %||% 0L) + 1L
}
picked <- picked |> arrange(desc(kind_effective %in% "disease_vs_normal"), desc(n_sig_strong))
cli_alert_success("selezionati: {nrow(picked)} case study ({sum(picked$agent_id %in% FLAGSHIP)} flagship + {sum(!(picked$agent_id %in% FLAGSHIP))} extra)")

# label_paper leggibile: <nome-pulito>_<tissue>_<agent_id compatto>
clean <- function(x) {
  x <- gsub("<[^>]+>", "", x)                 # markup
  x <- gsub("[^A-Za-z0-9]+", "_", trimws(x))  # non-alfanumerici -> _
  x <- gsub("_+", "_", x); gsub("^_|_$", "", x)
}
sel <- picked |> transmute(
  cluster_id = cluster_id,
  label_paper = paste0(substr(clean(canonical_name), 1, 40), "_", clean(tissue), "_",
                       gsub("[:]", "_", agent_id)),
  priority = ifelse(agent_id %in% FLAGSHIP, 1L, 2L),
  notes = sprintf("%s (%s) in %s; rem_group nominato. k_eff=%d, n_sig_05=%d, n_sig_strong=%d, max_logFC=%.1f.%s",
                  canonical_name, agent_id, tissue, k_effective, n_sig_05, n_sig_strong, max_abs_logFC,
                  ifelse(agent_id %in% FLAGSHIP, " FLAGSHIP (validato opzione C).", ""))
)
utils::write.csv(sel, OUT, row.names = FALSE)
cli_alert_success("Scritto {OUT} ({nrow(sel)} case study)")
cli_h2("Selection v10")
print(as.data.frame(sel[, c("cluster_id", "label_paper", "priority")]), row.names = FALSE)
