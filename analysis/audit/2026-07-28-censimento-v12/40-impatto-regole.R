#!/usr/bin/env Rscript
# Ricalcola il verdetto del gate su TUTTI i record `cgroup` di v12 e scrive il
# risultato. Si lancia DUE volte — una col codice vecchio (git stash) e una col
# nuovo — e i due esiti si confrontano: cosi' l'effetto delle regole e' isolato
# da quello dell'anchor.
#
# Le regole nuove (induttore sul nome risolto, ombrello sul candidato, verso -/-,
# quantita', clinico, sinonimi di controllo) NON passano dall'anchor: si valutano
# su `res$name`/`res$candidate` e sulle etichette, che sono le stesse in entrambi
# i rami. Per questo la misura con anchor = NA e' fedele per cio' che si misura.
#
# Uso: Rscript 40-impatto-regole.R <file-di-uscita.rds>
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

out_path <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(out_path)) stop("passare il file di uscita")

V12 <- "analysis/p4-output/20260727T204316Z-stage3-v12-364547a7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

cl <- readRDS(file.path(V12, "clusters.rds"))
cg <- cl[!is.na(cl$mode) & cl$mode == "cgroup", ]
asg <- arrow::read_parquet(file.path(V12, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% cg$cluster_id, ]
cat("record cgroup:", nrow(asg), "in", nrow(cg), "cluster\n")

cat("carico Stadio 2...\n")
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
env <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";")
}
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", study$series_id, cmp$comparison_id)
    if (!rid %in% need) next
    tg <- rgl[[cmp$treated_group]]; cg2 <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg2)) next
    assign(rid, list(study = study$series_id,
                     tl = lab_of(tg, cmp$treated_group), cl = lab_of(cg2, cmp$control_group),
                     tfl = fl_of(tg), cfl = fl_of(cg2)), envir = env)
  }
}
rm(s2); gc()

oe <- simulomicsr:::.load_ontology_dicts()
caches <- list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))

cat("ricalcolo il verdetto su", nrow(asg), "record...\n")
res <- vector("list", nrow(asg)); t0 <- Sys.time()
for (i in seq_len(nrow(asg))) {
  if (i %% 2000 == 0) cat("  ", i, "/", nrow(asg), "(",
                          round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min )\n")
  e <- get0(asg$record_id[i], envir = env, inherits = FALSE)
  if (is.null(e)) next
  v <- simulomicsr:::.ca_member_contrast(
    treated_label = e$tl, control_label = e$cl,
    treated_fl = e$tfl, control_fl = e$cfl,
    anchor_name = NA_character_, anchor_id = NA_character_,
    ontology_env = oe, caches = caches)
  res[[i]] <- data.frame(
    record_id = asg$record_id[i], study = e$study,
    entita = v$entity %||% NA_character_, verso = v$direction %||% NA_character_,
    ctrl = v$control_key %||% NA_character_,
    drop = if (nzchar(v$drop_reason)) v$drop_reason else "",
    stringsAsFactors = FALSE)
}
r <- do.call(rbind, res)
saveRDS(r, out_path)
cat("scritto", out_path, "-", nrow(r), "righe\n")
cat("scartati:", sum(nzchar(r$drop)), "| tenuti:", sum(!nzchar(r$drop)), "\n")
print(sort(table(r$drop[nzchar(r$drop)]), decreasing = TRUE)[1:12])
