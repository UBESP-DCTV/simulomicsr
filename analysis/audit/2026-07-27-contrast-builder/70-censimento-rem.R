# Censimento del ramo REM (12 meta-analisi poolate in v10).
#
# La sessione MEGA ha misurato 10 minestroni su 12. Qui si rilegge in proprio:
# per ogni cluster rem si ricostruiscono i confronti (mode pair -> .lookup_cmp) e
# si guarda che cosa misura ciascun membro, con il motore del delta del builder.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({library(arrow); library(dplyr); devtools::load_all(".", quiet = TRUE)})
S4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032"
S3 <- "analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"
OUT <- "analysis/audit/2026-07-27-contrast-builder"
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

cp <- open_dataset(file.path(S4, "cluster_pooled.parquet")) |>
  select(cluster_id, method) |> distinct() |> collect()
rem_ids <- cp$cluster_id[cp$method == "rem"]
cl  <- readRDS(file.path(S3, "clusters.rds"))
asg <- read_parquet(file.path(S3, "assignments.parquet"))
by  <- split(asg$record_id, asg$cluster_id)
s2  <- .load_stage2_master("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
s2i <- .index_stage2_master(s2)
oe  <- .load_ontology_dicts()
caches <- list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))
fl_of <- function(rg) { fl <- rg$factor_levels; if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";") }
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid

cat("=== RAMO REM:", length(rem_ids), "meta-analisi poolate in v10 ===\n")
sink(file.path(OUT, "bundle-rem.txt"))
for (cid in rem_ids) {
  info <- cl[cl$cluster_id == cid, ]
  cat("\n\n===============================================================\n")
  cat(sprintf("%s | k=%s | %s | %s\n", cid, info$k[1], info$kind_effective_resolved[1],
              info$canonical_name[1] %||% "(senza nome)"))
  cat(sprintf("anchor: %s\n", substr(info$anchor_key[1], 1, 150)))
  ents <- character(0)
  for (rid in by[[cid]]) {
    p <- .split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2i, inherits = FALSE)) next
    st <- get(p$series_id, envir = s2i, inherits = FALSE)
    cmp <- .lookup_cmp(st, p$suffix); if (is.null(cmp)) next
    tg <- .lookup_rg(st, cmp$treated_group); cg <- .lookup_rg(st, cmp$control_group)
    if (is.null(tg) || is.null(cg)) next
    v <- .ca_member_contrast(lab_of(tg, cmp$treated_group), lab_of(cg, cmp$control_group),
                             fl_of(tg), fl_of(cg), ontology_env = oe, caches = caches)
    if (!nzchar(v$drop_reason) && !is.na(v$entity)) ents <- c(ents, v$entity)
    cat(sprintf("  %-12s %-52s => %-38s [%s]\n", p$series_id,
                substr(lab_of(tg, cmp$treated_group), 1, 52),
                substr(lab_of(cg, cmp$control_group), 1, 38),
                if (nzchar(v$drop_reason)) v$drop_reason else v$entity))
  }
  cat(sprintf("  --> entita' distinte del delta: %d (%s)\n", length(unique(ents)),
              paste(unique(ents), collapse = " | ")))
}
sink()
cat("scritto bundle-rem.txt\n")
