#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/40-collassi-e-rem.R
# Per ogni gruppo: stime per studio con T0, T1, T2, T3, poi REM gene per gene.
# La chiamata a metafor e' la stessa di .pool_rem_cluster (REML; un warning o un errore
# passano a DL). .pool_rem_cluster costruisce una tibble per gene e costa ~30 h: qui le colonne
# si raccolgono in vettori. Il cancello 2 prova che il numero non cambia.
# Uso: WORKERS=64 Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/40-collassi-e-rem.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
library(parallel)
B <- readRDS(file.path(PESANTI, "bracci.rds"))
A <- B$A; strutture <- B$strutture
x <- leggi_bracci_parquet(unique(A$cluster_id))
fu <- as.data.table(read_parquet(file.path(PESANTI, "T3-fusi.parquet")))
A[, chiave := paste(cluster_id, study_id, sep = "\r")]
DIR <- file.path(PESANTI, "studio"); dir.create(DIR, showWarnings = FALSE)

stime_coppia <- function(xs, s, fus, cid, sid) {
  bracci <- sort(unique(xs$braccio)); m <- length(bracci)
  if (m == 1L) {
    return(xs[, .(gene_id, gene_symbol, d0 = logFC, se0 = SE, se1 = SE, d2 = logFC, se2 = SE, d3 = logFC, se3 = SE)])
  }
  geni <- sort(unique(xs$gene_id))
  D <- matrix(NA_real_, length(geni), m); S <- D
  ig <- match(xs$gene_id, geni); ib <- match(xs$braccio, bracci)
  D[cbind(ig, ib)] <- xs$logFC; S[cbind(ig, ib)] <- xs$SE
  U <- 1 / S; U[is.na(U)] <- 0; Dz <- D; Dz[is.na(Dz)] <- 0
  sw <- rowSums(U^2)
  d0 <- rowSums(Dz * U^2) / sw; se0 <- sqrt(1 / sw)
  R <- s$R
  se1 <- sqrt(var_t1(U, R))
  # T2: GLS, per gruppi di geni con gli stessi bracci presenti
  pres <- U > 0
  motivo <- apply(pres, 1L, function(r) paste(which(r), collapse = ","))
  d2 <- d0; se2 <- se0
  for (mt in unique(motivo)) {
    ii <- which(motivo == mt); p <- as.integer(strsplit(mt, ",", fixed = TRUE)[[1]])
    Rp <- R[p, p, drop = FALSE]
    if (all(Rp[upper.tri(Rp)] == 0)) next
    Ri <- MASS::ginv(Rp)
    Up <- U[ii, p, drop = FALSE]
    a <- Up %*% Ri; den <- rowSums(a * Up)
    d2[ii] <- rowSums(a * (Dz[ii, p, drop = FALSE] * Up)) / den
    se2[ii] <- sqrt(1 / den)
  }
  out <- data.table(gene_id = geni, gene_symbol = xs$gene_symbol[match(geni, xs$gene_id)],
                    d0 = d0, se0 = se0, se1 = se1, d2 = d2, se2 = se2)
  # T3: componenti da un braccio restano; quelli da 2+ sono i fit fusi; poi varianza inversa
  comp <- s$comp
  righe <- list()
  for (cc in unique(comp)) {
    br <- bracci[comp == cc]
    if (length(br) == 1L) {
      righe[[length(righe) + 1L]] <- xs[braccio == br, .(gene_id, gene_symbol, logFC, SE)]
    } else {
      f <- fus[componente == cc]
      stopifnot(nrow(f) > 0L)
      righe[[length(righe) + 1L]] <- f[, .(gene_id, gene_symbol, logFC, SE)]
    }
  }
  t3 <- rbindlist(righe)[, {w <- 1 / SE^2; .(gene_symbol = gene_symbol[1L], d3 = sum(w * logFC) / sum(w), se3 = sqrt(1 / sum(w)))}, by = gene_id]
  out <- merge(out, t3, by = "gene_id", all = TRUE, suffixes = c("", ".f"))
  out[is.na(gene_symbol), gene_symbol := gene_symbol.f]
  out[, gene_symbol.f := NULL]
  out[]
}

stime_gruppo <- function(cid) {
  xg <- x[cluster_id == cid]; fg <- fu[cluster_id == cid]
  ris <- lapply(split(xg, by = "study_id"), function(xs) {
    sid <- xs$study_id[1L]
    s <- strutture[[paste(cid, sid, sep = "\r")]]
    st <- stime_coppia(xs, s, fg[study_id == sid], cid, sid)
    st[, study_id := sid]
    st
  })
  out <- rbindlist(ris, use.names = TRUE)
  out[, cluster_id := cid]
  saveRDS(out, file.path(DIR, paste0(cid, ".rds")))
  # segni di controllo per il cancello 5
  data.table(cluster_id = cid, n = nrow(out), scarto_t1_vs_t0_nei_singoli = max(0, out[se1 == se0, abs(d0 - d3)], na.rm = TRUE))
}

gruppi <- sort(unique(A$cluster_id))
stopifnot(length(gruppi) == 194L)
t0 <- Sys.time()
s <- mclapply(gruppi, function(g) tryCatch(stime_gruppo(g), error = function(e) data.table(cluster_id = g, errore = conditionMessage(e))),
              mc.cores = WORKERS, mc.preschedule = FALSE)
s <- rbindlist(s, fill = TRUE)
if ("errore" %in% names(s) && any(!is.na(s$errore))) { print(s[!is.na(errore)][1:5]); stop("collassi in errore") }
cat(sprintf("stime per studio di 194 gruppi: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
rm(x); gc()

# REM: T0 su tutti i gruppi, gli altri trattamenti solo dove la coppia ha rho non nullo.
# Altrove T1 = T2 = T3 = T0 per costruzione (il cancello 2 e la valutazione lo controllano).
toccati <- unique(A[condivide == TRUE, cluster_id])
cat(sprintf("gruppi con almeno una coppia con condivisione: %d\n", length(toccati)))
tratt <- list(T0 = c("d0", "se0"), T1 = c("d0", "se1"), T2 = c("d2", "se2"), T3 = c("d3", "se3"))
for (tn in names(tratt)) {
  gs <- if (tn == "T0") gruppi else toccati
  cols <- tratt[[tn]]
  t0 <- Sys.time()
  r <- mclapply(gs, function(g) {
    dt <- readRDS(file.path(DIR, paste0(g, ".rds")))
    dt <- dt[, .(gene_id, y = get(cols[1]), se = get(cols[2]))]
    tryCatch(rem_gruppo(dt, g), error = function(e) data.table(cluster_id = g, errore = conditionMessage(e)))
  }, mc.cores = WORKERS, mc.preschedule = FALSE)
  r <- rbindlist(r, fill = TRUE)
  if ("errore" %in% names(r) && any(!is.na(r$errore))) { print(r[!is.na(errore)][1:5]); stop("REM in errore ", tn) }
  write_parquet(r, file.path(PESANTI, paste0("rem-", tn, ".parquet")))
  cat(sprintf("REM %s: %d gruppi, %d righe, %.1f min\n", tn, length(gs), nrow(r), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
