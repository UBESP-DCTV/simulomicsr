# ⚠️ I 23 DI G3 SONO IN GRAN PARTE FALSI POSITIVI MIEI: il testo che davo al
# marcatore era "chiave=valore", e cosi' `genetic_knockdown=no knockdown`,
# `TET1_knockdown=wild_type`, `overexpression=None` risultano "genetici" per il
# NOME DEL CAMPO mentre il valore dice il contrario. E' lo stesso errore del
# primo rilevatore, al rovescio.
# Qui il marcatore vede SOLO I VALORI e l'etichetta umana.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-genetica-su-un-braccio"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
asg <- asg[asg$cluster_id %in% del$cluster_id, ]
s2  <- readRDS(file.path(SC, "s2.rds")); idx <- simulomicsr:::.index_stage2_master(s2)

CS2 <- "(^|[^A-Za-z])(sh|si|sg)[A-Z][A-Za-z0-9]{1,}"
CI2 <- "(^|[^a-z])(ko|kd)[0-9]?([^a-z]|$)"
# valori che NEGANO la modifica: non sono marcatori
NEG <- "^(no|none|non|nessun|wild.?type|wt|control|ctrl|scramble|scr|parental|empty|na|-)$"
marc <- function(x) {
  v <- trimws(as.character(x)); v <- v[nzchar(v)]
  v <- v[!grepl(NEG, tolower(v))]
  if (!length(v)) return(FALSE)
  s <- simulomicsr:::.rp_normalize_separators(paste(v, collapse = " ; "))
  grepl(CS2, s, perl = TRUE) || grepl(CI2, tolower(s), perl = TRUE) ||
    simulomicsr:::.rp_has_genetic_marker(paste(v, collapse = " ; "))
}
valori <- function(rg) {
  fl <- rg$factor_levels
  c(rg$label_human %||% "",
    if (length(fl)) vapply(fl, function(z) as.character(z$value), character(1L)) else character(0))
}
out <- list()
for (i in seq_len(nrow(asg))) {
  p <- simulomicsr:::.split_record_id(asg$record_id[i])
  if (is.na(p$series_id) || !exists(p$series_id, envir = idx, inherits = FALSE)) next
  st <- get(p$series_id, envir = idx, inherits = FALSE)
  cmp <- simulomicsr:::.lookup_cmp(st, p$suffix); if (is.null(cmp)) next
  tg <- simulomicsr:::.lookup_rg(st, cmp$treated_group); cg <- simulomicsr:::.lookup_rg(st, cmp$control_group)
  if (is.null(tg) || is.null(cg)) next
  vt <- valori(tg); vc <- valori(cg)
  out[[length(out)+1L]] <- data.frame(cluster_id = asg$cluster_id[i], study_id = p$series_id,
    gt = marc(vt), gc = marc(vc),
    trattato = substr(paste(vt, collapse=" ; "), 1, 100),
    controllo = substr(paste(vc, collapse=" ; "), 1, 100), stringsAsFactors = FALSE)
}
M <- do.call(rbind, out)
M$stato <- ifelse(M$gt & M$gc, "contesto", ifelse(M$gt | M$gc, "UN BRACCIO SOLO", "trattamento"))
cat("confronti:", nrow(M), "\n"); print(table(M$stato))
z <- M[M$stato == "UN BRACCIO SOLO", ]
cat("\ngruppi coinvolti:", length(unique(z$cluster_id)), "\n\n")
for (i in seq_len(nrow(z))) cat(sprintf("%2d %-11s\n   T: %s\n   C: %s\n", i, z$study_id[i], z$trattato[i], z$controllo[i]))
write.csv(z, file.path(SC, "G4-un-braccio-solo.csv"), row.names = FALSE)
