#!/usr/bin/env Rscript
# Ispeziona un confronto SPECIFICO con gli argomenti VERI del build: stesse
# etichette, stessi factor_levels, stesso anchor del campione trattato.
#
# Serve per non ripetere l'errore gia' pagato: chiamare .ca_member_contrast con
# factor_levels vuoti fa dire "no_delta" a tutto, compreso cio' che funziona, e
# porta ad accusare codice innocente.
#
# Uso:  Rscript 20-ispeziona.R GSE233083 GSE139963 ...
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

series <- commandArgs(trailingOnly = TRUE)
if (!length(series)) stop("passare almeno una serie GSE")

STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
STAGE1 <- "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl"

cat("carico Stadio 2...\n")
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
s2 <- s2[vapply(s2, function(s) s$series_id %in% series, logical(1))]
cat("  studi trovati:", length(s2), "\n")

# Stadio 1 solo per i GSM che servono
need <- unique(unlist(lapply(s2, function(st)
  unlist(lapply(st$replicate_groups, function(g) as.character(unlist(g$sample_ids)))))))
cat("carico Stadio 1 per", length(need), "GSM...\n")
lines <- readLines(STAGE1, warn = FALSE)
rid <- sub("^\\{\"record_id\"\\s*:\\s*\"([^\"]+)\".*", "\\1", lines)
tmp <- tempfile(fileext = ".jsonl"); writeLines(lines[rid %in% need], tmp); rm(lines); gc()
s1 <- simulomicsr:::.load_stage1_master(tmp); unlink(tmp)

oe <- simulomicsr:::.load_ontology_dicts()
fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";")
}
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid

for (study in s2) {
  cat("\n===============================", study$series_id, "===============================\n")
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    tgs <- tg$sample_ids[[1L]]; tf <- s1[[tgs]]
    segs <- if (is.null(tf)) NULL else
      simulomicsr:::.extract_anchor_segments(tf, stage2_role = "treated", ontology_env = oe)
    tm <- if (is.null(segs)) list() else attr(segs, "tracking_meta")
    v <- simulomicsr:::.ca_member_contrast(
      treated_label = lab_of(tg, cmp$treated_group),
      control_label = lab_of(cg, cmp$control_group),
      treated_fl    = fl_of(tg), control_fl = fl_of(cg),
      anchor_name   = tm$canonical_name    %||% NA_character_,
      anchor_id     = tm$agent_id_resolved %||% NA_character_,
      ontology_env  = oe)
    cat(sprintf("\n%s\n", cmp$comparison_id))
    cat(sprintf("  T: %s\n     fl: %s\n", lab_of(tg, cmp$treated_group), fl_of(tg)))
    cat(sprintf("  C: %s\n     fl: %s\n", lab_of(cg, cmp$control_group), fl_of(cg)))
    cat(sprintf("  anchor del trattato: %s (%s)\n", tm$canonical_name %||% "NA",
                tm$agent_id_resolved %||% "NA"))
    cat(sprintf("  => entita=%s | verso=%s | ctrl=%s | classe=%s | fonte=%s | drop=%s\n",
                v$entity %||% "NA", v$direction %||% "NA", v$control_key %||% "NA",
                v$contrast_class %||% "NA", v$entity_source %||% "NA",
                if (nzchar(v$drop_reason)) v$drop_reason else "-"))
  }
}
