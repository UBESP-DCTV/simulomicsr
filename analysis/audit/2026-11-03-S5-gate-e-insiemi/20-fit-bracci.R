#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/20-fit-bracci.R
# Fit limma-voom di tutti i bracci dei gruppi a k_eff 1 e 2 con k censito >= 3 (sono nel parquet:
# cancello 3 e P13) e dei gruppi a k censito 2 che arrivano a k_eff 2 (non sono nel parquet).
# Ruoli PER NOME di campione. Per i bracci del parquet si prova anche il fit PER POSIZIONE, come
# .run_per_study_de_all: la cache delle conte non conserva l'ordine dei campioni.
# Stesse guardie di produzione: .drop_role_conflicts, .collapse_technical_lanes.
# Le conte che non stanno in cache si leggono dall'H5 e NON si scrivono da nessuna parte: la cache
# di produzione resta com'e'.
# Uso: WORKERS=48 Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/20-fit-bracci.R [N_PROVA]
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
library(parallel)
args <- commandArgs(TRUE); N_PROVA <- if (length(args)) as.integer(args[1]) else NA_integer_
D <- readRDS(file.path(PES5, "dispatch-A3.rds"))
cand <- D$candidati; corsie <- D$lane
nel_parquet <- cand[k_censito >= 3L & k_eff %in% 1:2, cluster_id]
nuovi <- cand[k_censito == 2L & k_eff == 2L, cluster_id]
A <- D$tenuti[cluster_id %in% c(nel_parquet, nuovi)]
A[, braccio := seq_len(.N), by = .(cluster_id, study_id)]
A[, nel_parquet := cluster_id %in% nel_parquet]
cat(sprintf("gruppi nel parquet %d (bracci %d) | gruppi nuovi %d (bracci %d)\n",
            length(nel_parquet), A[nel_parquet == TRUE, .N], length(nuovi), A[nel_parquet == FALSE, .N]))
x <- leggi_bracci_parquet(nel_parquet); setkey(x, cluster_id, study_id, braccio)
stopifnot(all(x$direction_applied == "none"))
nb <- x[, .(n = uniqueN(braccio)), by = .(cluster_id, study_id)]
chk <- merge(A[nel_parquet == TRUE, .(m = .N), by = .(cluster_id, study_id)], nb, by = c("cluster_id", "study_id"), all = TRUE)
cat(sprintf("bracci per coppia uguali fra dispatch e parquet in %d coppie su %d\n", chk[m == n, .N], nrow(chk)))

CACHE <- .default_stage4_cache_dir()
FILT <- "protein_coding"
prendi_conte <- function(sid, gsm) {
  f <- file.path(CACHE, paste0(.cache_key_for_fetch(sid, gsm, gene_biotype_filter = FILT), ".rds"))
  m <- if (file.exists(f)) readRDS(f) else .fetch_counts_from_h5(sid, gsm, H5, gene_biotype_filter = FILT)
  stopifnot(setequal(colnames(m), gsm))
  list(m = m, da_cache = file.exists(f))
}
fit_su <- function(m, tr, cid, sid) {
  st <- attr(m, "gene_symbol")
  cl <- .collapse_technical_lanes(m, tr, corsie)
  n_corsie <- nrow(cl$log)
  if (n_corsie > 0L) { attr(cl$counts, "gene_symbol") <- st; m <- cl$counts; tr <- cl$treatment }
  list(f = as.data.table(.run_limma_voom_de(m, tr, sid, cid, direction_flip = FALSE)), n_corsie = n_corsie)
}
lavoro <- function(i) {
  a <- A[i]
  t0 <- strsplit(a$gsm_t, ",", fixed = TRUE)[[1]]; c0 <- strsplit(a$gsm_c, ",", fixed = TRUE)[[1]]
  rc <- .drop_role_conflicts(t0, c0, n_min = 2L, cluster_id = a$cluster_id, study_id = a$study_id, lane_lookup = corsie)
  esito <- data.table(i = i, conflitto = nrow(rc$log), usabile = rc$usable, da_cache = NA, n_corsie = 0L,
                      geni = NA_integer_, d_logFC = NA_real_, d_SE = NA_real_, ruoli_giusti_per_posizione = NA,
                      pos_d_logFC = NA_real_, pos_d_SE = NA_real_, errore = NA_character_)
  if (!rc$usable) return(list(esito = esito, fit = NULL))
  tr <- rc$treated; co <- rc$control
  p <- prendi_conte(a$study_id, c(tr, co)); m <- p$m
  esito[, da_cache := p$da_cache]
  st <- attr(m, "gene_symbol")
  mn <- m[, c(tr, co), drop = FALSE]; attr(mn, "gene_symbol") <- st
  ruolo <- factor(c(rep("treated", length(tr)), rep("control", length(co))), levels = c("control", "treated"))
  r <- fit_su(mn, ruolo, a$cluster_id, a$study_id); f <- r$f
  esito[, `:=`(n_corsie = r$n_corsie, geni = nrow(f))]
  if (a$nel_parquet) {
    v <- x[.(a$cluster_id, a$study_id, a$braccio)]
    j <- match(v$gene_id, f$gene_id)
    esito[, `:=`(d_logFC = max(abs(v$logFC - f$logFC[j]), na.rm = TRUE), d_SE = max(abs(v$SE - f$SE[j]), na.rm = TRUE))]
    primi <- colnames(m)[seq_along(tr)]
    esito[, ruoli_giusti_per_posizione := all(primi %in% tr)]
    if (!all(primi %in% tr)) {
      rp <- fit_su(m, ruolo, a$cluster_id, a$study_id)$f
      jp <- match(v$gene_id, rp$gene_id)
      esito[, `:=`(pos_d_logFC = max(abs(v$logFC - rp$logFC[jp]), na.rm = TRUE), pos_d_SE = max(abs(v$SE - rp$SE[jp]), na.rm = TRUE))]
    }
  }
  list(esito = esito, fit = f[, .(cluster_id = a$cluster_id, study_id = a$study_id, braccio = a$braccio, gene_id, gene_symbol, logFC, SE, n_treated, n_control)])
}
indici <- seq_len(nrow(A))
if (!is.na(N_PROVA)) { set.seed(SEME); indici <- sample(indici, N_PROVA) }
invisible(prendi_conte(A$study_id[A$nel_parquet == FALSE][1], unlist(strsplit(c(A$gsm_t[A$nel_parquet == FALSE][1], A$gsm_c[A$nel_parquet == FALSE][1]), ",", fixed = TRUE))))
rhdf5::h5closeAll()
t0 <- Sys.time()
ris <- mclapply(indici, function(i) tryCatch(lavoro(i), error = function(e)
  list(esito = data.table(i = i, errore = conditionMessage(e)), fit = NULL)), mc.cores = WORKERS, mc.preschedule = FALSE)
secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("%d bracci in %.1f min con %d processi (%.1f s per braccio x processo)\n", length(indici), secs / 60, WORKERS, secs * WORKERS / length(indici)))
es <- rbindlist(lapply(ris, `[[`, "esito"), fill = TRUE)
es <- cbind(A[es$i, .(cluster_id, study_id, braccio, n_t, n_c, nel_parquet)], es)
cat(sprintf("errori: %d | braccio non usabile per conflitto: %d | bracci con conflitto: %d | da cache: %d, dall'H5: %d\n",
            sum(!is.na(es$errore)), sum(es$usabile == FALSE, na.rm = TRUE), sum(es$conflitto > 0, na.rm = TRUE), sum(es$da_cache == TRUE, na.rm = TRUE), sum(es$da_cache == FALSE, na.rm = TRUE)))
if (any(!is.na(es$errore))) print(es[!is.na(errore), .(cluster_id, study_id, errore)][1:min(.N, 10)])
if (is.na(N_PROVA)) {
  p <- es[nel_parquet == TRUE]
  ok_nome <- p[, !is.na(d_logFC) & d_logFC < 1e-6 & d_SE < 1e-6]
  ok_pos <- p[, !is.na(pos_d_logFC) & pos_d_logFC < 1e-6 & pos_d_SE < 1e-6]
  cat(sprintf("=== CANCELLO 3, bracci del parquet: %d | per nome %d | per posizione %d | senza spiegazione %d\n",
              nrow(p), sum(ok_nome), sum(!ok_nome & ok_pos), sum(!ok_nome & !ok_pos)))
  cat(sprintf("=== P13 bracci con ruoli sbagliati nel parquet fuori dalle 194: %d\n", sum(!ok_nome & ok_pos)))
  print(p[!ok_nome, .(cluster_id, study_id, braccio, n_t, n_c, d_logFC, pos_d_logFC)])
  fwrite(es, file.path(OUT5, "20-esito-bracci.csv"))
  fit <- rbindlist(lapply(ris, `[[`, "fit"))
  write_parquet(fit, file.path(PES5, "fit-bracci.parquet"))
  saveRDS(A, file.path(PES5, "bracci-k2.rds"))
}
