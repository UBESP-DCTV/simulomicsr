#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/22-fusione.R
# I fit di T3: una riga per ogni componente con 2+ bracci. Unione dei trattati contro unione dei
# controlli, stesse guardie di produzione, ruoli assegnati per nome.
# Uso: WORKERS=64 Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/22-fusione.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
library(parallel)
B <- readRDS(file.path(PESANTI, "bracci.rds"))
A <- B$A; corsie <- B$corsie
prendi_conte <- function(sid, gsm) {
  m <- .fetch_counts_cached(sid, gsm, h5_path = NULL, gene_biotype_filter = "protein_coding")
  stopifnot(setequal(colnames(m), gsm))
  m
}
fit_per_nome <- function(m, tratt, contr, cid, sid) {
  st <- attr(m, "gene_symbol")
  m <- m[, c(tratt, contr), drop = FALSE]; attr(m, "gene_symbol") <- st
  tr <- factor(c(rep("treated", length(tratt)), rep("control", length(contr))),
               levels = c("control", "treated"))
  cl <- .collapse_technical_lanes(m, tr, corsie)
  if (nrow(cl$log) > 0L) { attr(cl$counts, "gene_symbol") <- st; m <- cl$counts; tr <- cl$treatment }
  as.data.table(.run_limma_voom_de(m, tr, sid, cid, direction_flip = FALSE))
}

comp <- A[, .(idx = list(.I), n = .N), by = .(cluster_id, study_id, componente)][n > 1L]
cat(sprintf("componenti da fondere: %d\n", nrow(comp)))
fondi <- function(k) {
  cc <- comp[k]; ii <- cc$idx[[1]]
  tr <- unique(unlist(strsplit(A$gsm_t[ii], ",", fixed = TRUE)))
  co <- unique(unlist(strsplit(A$gsm_c[ii], ",", fixed = TRUE)))
  rc <- .drop_role_conflicts(tr, co, n_min = 2L, cluster_id = cc$cluster_id, study_id = cc$study_id,
                             lane_lookup = corsie)
  if (!rc$usable) return(data.table(cluster_id = cc$cluster_id, study_id = cc$study_id,
                                    componente = cc$componente, scartato = TRUE,
                                    tolti = rc$log$n_dropped))
  # si compongono le conte dalle matrici dei singoli bracci: nessuna riga nuova in cache
  mm <- lapply(ii, function(i) prendi_conte(A$study_id[i],
          c(strsplit(A$gsm_t[i], ",", fixed = TRUE)[[1]], strsplit(A$gsm_c[i], ",", fixed = TRUE)[[1]])))
  stopifnot(all(vapply(mm, function(m) identical(rownames(m), rownames(mm[[1]])), TRUE)))
  tutte <- do.call(cbind, mm); tutte <- tutte[, !duplicated(colnames(tutte)), drop = FALSE]
  attr(tutte, "gene_symbol") <- attr(mm[[1]], "gene_symbol")
  stopifnot(all(c(rc$treated, rc$control) %in% colnames(tutte)))
  f <- fit_per_nome(tutte, rc$treated, rc$control, cc$cluster_id, cc$study_id)
  f[, `:=`(componente = cc$componente, scartato = FALSE, tolti = sum(tr %in% co))]
  f[, .(cluster_id, study_id, componente, gene_id, gene_symbol, logFC, SE, n_treated, n_control, scartato, tolti)]
}
t0 <- Sys.time()
fu <- mclapply(seq_len(nrow(comp)), fondi, mc.cores = WORKERS, mc.preschedule = FALSE)
err <- vapply(fu, inherits, TRUE, "try-error")
if (any(err)) { print(fu[[which(err)[1]]]); stop("fusione in errore") }
fu <- rbindlist(fu, fill = TRUE)
scart <- unique(fu[scartato == TRUE, .(cluster_id, study_id, componente, tolti)])
cat(sprintf("fusione in %.1f min | componenti scartati dalla guardia n_min: %d | con conflitti tolti: %d\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins")), nrow(scart),
            uniqueN(fu[tolti > 0], by = c("cluster_id", "study_id", "componente"))))
write_parquet(fu[scartato == FALSE], file.path(PESANTI, "T3-fusi.parquet"))
fwrite(scart, file.path(OUT, "20-fusioni-scartate.csv"))
