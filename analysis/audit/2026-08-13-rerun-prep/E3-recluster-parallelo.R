# Il re-cluster PARALLELO contro quello SERIALE, sui dati veri e per intero.
# I due output devono essere identici: `identical()` su tutto l'oggetto, non
# soltanto sui valori.
suppressMessages(library(arrow))
SER <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"   # 9h21m, 1 worker
PAR <- "analysis/p4-output/20260815T231154Z-stage3-v16-7f986159"   # 2h28m, 8 worker
ok <- TRUE
for (f in c("clusters.rds", "non_clusterable.rds", "record_summary.rds")) {
  a <- readRDS(file.path(SER, f)); b <- readRDS(file.path(PAR, f))
  id <- identical(a, b)
  cat(sprintf("  %-22s righe %7d vs %7d | colonne %2d vs %2d | identical: %s\n",
              f, nrow(a), nrow(b), ncol(a), ncol(b), id))
  if (!id) { ok <- FALSE
    for (cc in intersect(names(a), names(b)))
      if (!identical(a[[cc]], b[[cc]])) cat("     DIVERSA:", cc, "\n")
    cat("     colonne solo in uno:", paste(setdiff(union(names(a),names(b)),
                                                   intersect(names(a),names(b))), collapse=","), "\n") }
}
a <- as.data.frame(read_parquet(file.path(SER, "assignments.parquet")))
b <- as.data.frame(read_parquet(file.path(PAR, "assignments.parquet")))
id <- identical(a, b)
cat(sprintf("  %-22s righe %7d vs %7d | identical: %s\n", "assignments.parquet",
            nrow(a), nrow(b), id))
if (!id) { ok <- FALSE
  for (cc in names(a)) if (!identical(a[[cc]], b[[cc]])) cat("     DIVERSA:", cc, "\n") }
ra <- jsonlite::fromJSON(file.path(SER, "run_metadata.json"))
rb <- jsonlite::fromJSON(file.path(PAR, "run_metadata.json"))
cat(sprintf("  %-22s %s vs %s | uguale: %s\n", "run_id", ra$run_id, rb$run_id,
            identical(ra$run_id, rb$run_id)))
cat("\nVERDETTO:", if (ok) "IDENTICI" else "DIVERSI", "\n")
quit(status = if (ok) 0L else 1L)
