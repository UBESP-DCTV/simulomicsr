#!/usr/bin/env Rscript
# 50-materiale-44.R --- materiale per leggere a mano i 44 gruppi che il
# censimento 40-id-vs-membri-v15.R ha filtrato (esito != "nome per esteso").
#
# Le etichette sono INTERE: il troncamento a 40/58 caratteri e' gia' costato un
# verdetto dato su mezza frase (2026-07-30). Lo script misura la distribuzione
# delle lunghezze e segnala i picchi, cosi' un eventuale troncamento a monte si
# vede invece di passare inosservato.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V15    <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
OUT    <- "analysis/audit/2026-08-09-passo1"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

r <- utils::read.csv(file.path(OUT, "id-vs-membri-v15.csv"), stringsAsFactors = FALSE)
d <- r[as.logical(r$nel_deliverable) & r$esito != "nome per esteso", ]
d <- d[order(-d$k), ]
cat("gruppi da leggere:", nrow(d), " studi-slot:", sum(d$k), "\n")

asg <- arrow::read_parquet(file.path(V15, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% d$cluster_id, ]
need <- unique(asg$record_id)
need_env <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
for (x in need) assign(x, TRUE, envir = need_env)

lab <- new.env(hash = TRUE, parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (is.null(fl) || !length(fl)) return("")
  paste(vapply(names(fl), function(k) paste0(k, "=", paste(unlist(fl[[k]]), collapse = "/")),
               character(1L)), collapse = "; ")
}
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
for (study in s2) {
  sid <- study$series_id
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  cmp_seen <- new.env(hash = TRUE, parent = emptyenv())
  for (cmp in study$comparisons) {
    n_seen <- (get0(cmp$comparison_id, envir = cmp_seen, ifnotfound = 0L)) + 1L
    assign(cmp$comparison_id, n_seen, envir = cmp_seen)
    rid <- sprintf("%s__%s__%d", sid, cmp$comparison_id, n_seen)
    if (is.null(get0(rid, envir = need_env, inherits = FALSE))) next
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(rid, list(sid = sid,
                     t = lab_of(tg, cmp$treated_group), c = lab_of(cg, cmp$control_group),
                     tfl = fl_of(tg), cfl = fl_of(cg)), envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

coperti <- sum(vapply(need, function(x) !is.null(get0(x, envir = lab, inherits = FALSE)), logical(1L)))
cat(sprintf("CASO DI ACCETTAZIONE copertura: %d/%d = %.2f%%\n", coperti, length(need),
            100 * coperti / length(need)))
stopifnot(coperti / length(need) >= 0.98)

# --- controllo del troncamento ----------------------------------------------
tutte <- unlist(lapply(need, function(x) { v <- get0(x, envir = lab, inherits = FALSE)
  if (is.null(v)) NULL else c(v$t, v$c) }))
len <- nchar(tutte)
cat(sprintf("etichette: %d, lunghezza min %d mediana %d max %d\n",
            length(len), min(len), stats::median(len), max(len)))
tab <- sort(table(len), decreasing = TRUE)
picchi <- tab[as.integer(names(tab)) >= 30 & tab >= 5]
cat("picchi di lunghezza (>=30 char, >=5 occorrenze) = sospetto troncamento:",
    if (length(picchi)) paste(names(picchi), "x", as.vector(picchi), collapse = " | ") else "nessuno", "\n\n")

rid_by <- split(asg$record_id, asg$cluster_id)
con <- file(file.path(OUT, "materiale-44.txt"), open = "wt")
for (i in seq_len(nrow(d))) {
  writeLines(sprintf("\n================ [%02d/%d] %s", i, nrow(d), d$cluster_id[i]), con)
  writeLines(sprintf("ENTITA': %s   etichetta risolta: %s", d$contrast_entity[i], d$label_id[i]), con)
  writeLines(sprintf("k=%s  ramo=%s  recovery=%s  esito=%s  alias-che-matcha=%s",
                     d$k[i], d$entity_source[i], d$recovery_source[i], d$esito[i],
                     d$alias_che_matcha[i]), con)
  for (rr in rid_by[[d$cluster_id[i]]]) {
    v <- get0(rr, envir = lab, inherits = FALSE); if (is.null(v)) next
    writeLines(sprintf("  %s\n     TRATTATO : %s\n        [%s]\n     CONTROLLO: %s\n        [%s]",
                       v$sid, v$t, v$tfl, v$c, v$cfl), con)
  }
}
close(con)
cat("materiale:", file.path(OUT, "materiale-44.txt"), "\n")
