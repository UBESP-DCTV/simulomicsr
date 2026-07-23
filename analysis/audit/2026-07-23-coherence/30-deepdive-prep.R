# P5 coherence Task 5: prepara i "bundle di evidenza" per il deep-dive LLM.
# Per ogni cluster target estrae, dai contrasti ricostruiti (Fase 0), la lista
# DEDUPLICATA dei contrasti reali "treated_label => control_label [design_kind]"
# con la frequenza. Questa e' l'unica evidenza data ai subagent (D1 ri-conteggio
# semantico dei control-type; D2 e' l'insieme UN contrasto o piu'?). Nessun
# verdetto atteso viene passato: i subagent vedono solo i dati grezzi.
#
# Default target = i 184 rem_group poolati (il deliverable). Estendibile via env.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(arrow); library(dplyr); library(jsonlite) })

S4  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032"
DIR <- "analysis/audit/2026-07-23-coherence"
OUT <- file.path(DIR, "deepdive-bundles.jsonl")

pm  <- read_parquet(file.path(DIR, "per-member-contrasts.parquet"))
sig <- readRDS(file.path(DIR, "per-cluster-signals.rds"))

# target: rem_group poolati (default) o insieme passato via env TARGET_IDS
meta <- open_dataset(file.path(S4, "cluster_pooled.parquet")) |>
  select(cluster_id, method) |> distinct() |> collect()
rem_group_ids <- unique(meta$cluster_id[meta$method == "rem_group"])
tenv <- trimws(Sys.getenv("TARGET_IDS", ""))
targets <- if (nzchar(tenv)) trimws(strsplit(tenv, ",")[[1L]]) else rem_group_ids
cat(sprintf("target cluster: %d\n", length(targets)))

con <- file(OUT, "w")
for (cid in targets) {
  s   <- sig[sig$cluster_id == cid, , drop = FALSE]
  mem <- pm[pm$cluster_id == cid, , drop = FALSE]
  if (nrow(mem) == 0L) next
  # tuple deduplicate treated => control [design_kind], con frequenza
  mem$tuple <- sprintf("%s  =>  %s   [%s]",
    substr(mem$treated_label, 1, 70), substr(mem$control_label, 1, 70), mem$design_kind)
  tab <- sort(table(mem$tuple), decreasing = TRUE)
  contrasts <- sprintf("%dx  %s", as.integer(tab), names(tab))
  bundle <- list(
    cluster_id     = cid,
    kind           = if (nrow(s)) s$kind else NA,
    canonical_name = if (nrow(s)) s$canonical_name else NA,
    k              = if (nrow(s)) s$k else NA,
    n_resolved     = if (nrow(s)) s$n_resolved else nrow(mem),
    n_control_types_deterministic = if (nrow(s)) s$n_control_types else NA,
    frac_degenerate = if (nrow(s)) s$frac_degenerate else NA,
    distinct_controls = unname(unique(mem$control_label)),
    contrasts_dedup   = unname(contrasts[seq_len(min(30L, length(contrasts)))]))
  writeLines(toJSON(bundle, auto_unbox = TRUE, null = "null"), con)
}
close(con)
cat(sprintf("scritto %s (%d bundle)\n", OUT, length(targets)))
