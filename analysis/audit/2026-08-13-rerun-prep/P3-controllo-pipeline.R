# §3 — IL CONTROLLO APPROFONDITO, PRIMA DEL LANCIO. Stadio per stadio.
#
# ⚠️ Nei JSONL gli scalari sono ARRAY DI UN ELEMENTO: `isTRUE(list(FALSE))` e'
# sempre FALSE e regala uno 0% con l'aria di un risultato. Qui si spacchetta
# sempre con [[1]].
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC <- "analysis/audit/2026-08-13-rerun-prep"
sez <- function(x) cat("\n========== ", x, " ==========\n")

sez("STADIO 1 — il guard is_zero_timepoint")
P1 <- "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl"
cat("master:", P1, "\n")
preds <- jsonlite::stream_in(file(P1), verbose = FALSE, simplifyVector = FALSE)
cat("record:", length(preds), "\n")
acc <- 0L; spe <- 0L; tot <- 0L; senza_pj <- 0L; n_dur <- 0L
for (rec in preds) {
  pj <- rec$parsed_json
  if (is.null(pj)) { senza_pj <- senza_pj + 1L; next }
  tot <- tot + 1L
  pert <- pj$perturbations
  if (is.null(pert) || !length(pert)) next
  for (p in pert) {
    d <- p$duration
    if (is.null(d) || !is.list(d)) next
    n_dur <- n_dur + 1L
    prima <- isTRUE(unlist(d$is_zero_timepoint)[1L])
    dopo  <- simulomicsr:::.has_zero_timepoint_evidence(d)
    if (!prima && dopo) acc <- acc + 1L
    if (prima && !dopo) spe <- spe + 1L
  }
}
cat("record con parsed_json:", tot, "| senza:", senza_pj, "| durate esaminate:", n_dur, "\n")
cat("guard: ACCENDE", acc, "| SPEGNE", spe, "| totale corretti", acc + spe, "\n")
cat("   (il riferimento del 2026-08-13 e' 2.882 flag corretti)\n")
res <- list(acc = acc, spe = spe, tot = tot)
rm(preds); invisible(gc())

sez("STADIO 2 — un record per studio")
s2 <- simulomicsr:::.load_stage2_master("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
cat("studi:", length(s2), "\n")
sid <- vapply(s2, function(x) as.character(x$series_id)[[1]], character(1))
cat("series_id distinti:", length(unique(sid)), "| duplicati:", sum(duplicated(sid)), "\n")
g <- tryCatch({ simulomicsr:::.assert_stage2_one_record_per_series(s2); "PASS" },
              error = function(e) paste("FAIL:", conditionMessage(e)))
cat("guardia .assert_stage2_one_record_per_series:", g, "\n")
ncmp <- sum(vapply(s2, function(x) length(x$comparisons), integer(1)))
nrg  <- sum(vapply(s2, function(x) length(x$replicate_groups), integer(1)))
cat("confronti:", ncmp, "| replicate_groups:", nrg, "\n")
saveRDS(res, file.path(SC, "P3-stadio1.rds"))
