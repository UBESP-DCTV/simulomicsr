#!/usr/bin/env Rscript
# 60-rilevatore-deterministico.R --- se la regola di aggregazione e' "almeno un
# confronto difettoso su k", allora per metterla in codice serve un rilevatore
# DETERMINISTICO dei confronti difettosi. Ne esiste gia' uno: `.rp_row_defect`
# (R/stage3-row-pairing.R, 2026-07-26). Quanto ci va vicino?
#
# Metro di riferimento: la lettura umana del 5 agosto ha trovato 85 confronti
# imperfetti su 843 nei 13 gruppi grandi = 10,08%.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V15 <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
OUT <- "analysis/audit/2026-08-09-passo4"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

X <- readRDS(file.path(OUT, "20-dati.rds")); M <- X$M
cl <- readRDS(file.path(V15, "clusters.rds"))
asg <- arrow::read_parquet(file.path(V15, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% M$cluster_id, ]
need <- unique(asg$record_id)
ne <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
for (x in need) assign(x, TRUE, envir = ne)
cat("confronti da esaminare:", length(need), "\n")

ontology_env <- simulomicsr:::.load_ontology_dicts()
# ⚠️ La memoizzazione di `.rp_row_defect` NON e' opzionale a questa scala: con
# `cache = NULL` il ramo `.rp_uncaptured_combination` rifa' le ricerche in
# ontologia per ogni confronto, e i 4.549 confronti non finiscono in 7 ore
# (misurato il 2026-08-09: processo fermato a 7h25m senza esito).
.rp_cache <- new.env(hash = TRUE, parent = emptyenv())
ci <- match(M$cluster_id, cl$cluster_id)
cls_of <- setNames(cl$contrast_entity[ci], M$cluster_id)

lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
fl_of  <- function(rg) rg$factor_levels
rec <- new.env(hash = TRUE, parent = emptyenv())
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
for (study in s2) {
  sid <- study$series_id
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  seen <- new.env(hash = TRUE, parent = emptyenv())
  for (cmp in study$comparisons) {
    n <- (get0(cmp$comparison_id, envir = seen, ifnotfound = 0L)) + 1L
    assign(cmp$comparison_id, n, envir = seen)
    rid <- sprintf("%s__%s__%d", sid, cmp$comparison_id, n)
    if (is.null(get0(rid, envir = ne, inherits = FALSE))) next
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(rid, list(sid = sid, t = lab_of(tg, cmp$treated_group),
                     c = lab_of(cg, cmp$control_group),
                     tfl = fl_of(tg), cfl = fl_of(cg)), envir = rec)
  }
}
rm(s2); gc(verbose = FALSE)
cop <- sum(vapply(need, function(x) !is.null(get0(x, envir = rec, inherits = FALSE)), logical(1L)))
cat(sprintf("CASO DI ACCETTAZIONE copertura: %d/%d = %.2f%%\n", cop, length(need), 100*cop/length(need)))
stopifnot(cop / length(need) >= 0.98)

# --- il rilevatore di produzione ---------------------------------------------
cl_by <- split(asg$record_id, asg$cluster_id)
res <- do.call(rbind, lapply(names(cl_by), function(cid) {
  rids <- cl_by[[cid]]
  dif <- vapply(rids, function(r) {
    v <- get0(r, envir = rec, inherits = FALSE); if (is.null(v)) return(NA_character_)
    tryCatch(simulomicsr:::.rp_row_defect(v$t, v$c, NA_character_, cls_of[[cid]],
                                          character(0), ontology_env, .rp_cache),
             error = function(e) "")
  }, character(1L))
  dif[is.na(dif)] <- ""
  data.frame(cluster_id = cid, n_confronti = length(rids),
             n_difettosi = sum(nzchar(dif)),
             motivi = paste(unique(dif[nzchar(dif)]), collapse = "|"),
             stringsAsFactors = FALSE)
}))
res$frazione <- res$n_difettosi / pmax(1L, res$n_confronti)
res$almeno_uno <- res$n_difettosi > 0L

cat("\n=== IL RILEVATORE DETERMINISTICO SUI", sum(res$n_confronti), "CONFRONTI DELLE 213 ===\n")
cat(sprintf("confronti segnalati difettosi: %d/%d = %.2f%%\n",
            sum(res$n_difettosi), sum(res$n_confronti),
            100*sum(res$n_difettosi)/sum(res$n_confronti)))
cat(sprintf("metro della lettura umana (5 agosto, 13 gruppi grandi): 85/843 = %.2f%%\n",
            100*85/843))
cat(sprintf("RAPPORTO: la lettura umana trova %.1f volte piu' difetti\n",
            (85/843) / max(1e-9, sum(res$n_difettosi)/sum(res$n_confronti))))
cat("\nmotivi trovati:\n")
print(sort(table(unlist(strsplit(res$motivi[nzchar(res$motivi)], "|", fixed = TRUE))), decreasing = TRUE))

cat("\n=== se si applicasse la regola 'almeno uno' col rilevatore DI CODICE ===\n")
cat(sprintf("gruppi condannati: %d/%d = %.1f%%\n",
            sum(res$almeno_uno), nrow(res), 100*mean(res$almeno_uno)))
cat(sprintf("la lettura umana ne condanna: %d/%d = %.1f%%\n",
            sum(M$umano == "incoerente"), nrow(M), 100*mean(M$umano == "incoerente")))

i <- match(res$cluster_id, M$cluster_id)
cat("\naccordo del rilevatore col verdetto umano (incoerente vs no):\n")
print(table(rilevatore = res$almeno_uno, umano = M$umano[i] == "incoerente"))
acc <- mean(res$almeno_uno == (M$umano[i] == "incoerente"))
cat(sprintf("accordo: %.1f%%   base (dire sempre 'no'): %.1f%%\n",
            100*acc, 100*mean(M$umano[i] != "incoerente")))

utils::write.csv(res, file.path(OUT, "60-rilevatore-per-cluster.csv"), row.names = FALSE)
cat("\nscritto:", file.path(OUT, "60-rilevatore-per-cluster.csv"), "\n")
