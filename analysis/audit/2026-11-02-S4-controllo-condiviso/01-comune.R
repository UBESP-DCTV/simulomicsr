# analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R
# Percorsi e funzioni comuni agli script della sessione sul controllo condiviso.
# Rscript SENZA --vanilla: con --vanilla mancano arrow e devtools.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(data.table)
  devtools::load_all(".", quiet = TRUE)
})
OUT  <- "analysis/audit/2026-11-02-S4-controllo-condiviso"
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
# I file pesanti stanno fuori dal repository: si rifanno rilanciando gli script.
PESANTI <- "/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso"
dir.create(PESANTI, showWarnings = FALSE, recursive = TRUE)
RIL <- "analysis/audit/2026-08-20-rilettura-194"
SEME <- 20261102L
WORKERS <- as.integer(Sys.getenv("WORKERS", "64"))

# Il parquet non nomina i bracci. Dentro un braccio i geni seguono l'ordine dell'asse H5, quindi
# un braccio nuovo comincia dove la posizione sull'asse non cresce, o dove cambia (n_treated,
# n_control).
# La regola di 2026-11-02-inversioni-194 («dove un gene si ripete») sposta righe: se il braccio
# seguente ha gli stessi n e il suo primo gene manca da quello corrente, quella riga finisce
# nel braccio sbagliato. Trovato col cancello 3 su GSE237177 (S4).
segna_bracci <- function(pos, nt, nc) {
  n <- length(pos)
  if (n < 2L) return(rep(1L, n))
  cumsum(c(TRUE, diff(pos) <= 0L | nt[-1L] != nt[-n] | nc[-1L] != nc[-n]))
}

asse_geni <- function() {
  # l'asse viene da una matrice qualunque in cache: i geni codificanti, nell'ordine dell'H5
  f <- list.files(.default_stage4_cache_dir(), pattern = "[.]rds$", full.names = TRUE)[1L]
  rownames(readRDS(f))
}

leggi_bracci_parquet <- function(gruppi) {
  x <- as.data.table(read_parquet(file.path(POOL, "per_study_de.parquet"),
    col_select = c("cluster_id", "study_id", "gene_id", "gene_symbol", "logFC", "SE",
                   "n_treated", "n_control", "direction_applied")))
  x <- x[cluster_id %in% gruppi]
  asse <- asse_geni()
  x[, pos_asse := match(gene_id, asse)]
  stopifnot(!anyNA(x$pos_asse))
  x[, braccio := segna_bracci(pos_asse, n_treated, n_control), by = .(cluster_id, study_id)]
  x[, pos_asse := NULL]
  x[]
}

# Corsie: il registro di produzione dice quali campioni sono la stessa libreria.
leggi_corsie <- function() {
  l <- as.data.frame(readRDS(file.path(POOL, "qc_report.rds"))$lane_collapses)
  cam <- strsplit(l$campioni, ",", fixed = TRUE)
  v <- rep(l$libreria, lengths(cam)); names(v) <- unlist(cam)
  v[!duplicated(names(v))]
}
librerie <- function(gsm, corsie) {
  v <- corsie[gsm]
  unique(unname(ifelse(is.na(v), gsm, v)))
}

# Correlazione fra due bracci, dal disegno. Vedi 00-previsioni.md.
rho_bracci <- function(Ti, Ci, Tj, Cj) {
  nti <- length(Ti); nci <- length(Ci); ntj <- length(Tj); ncj <- length(Cj)
  num <- length(intersect(Ti, Tj)) / (nti * ntj) + length(intersect(Ci, Cj)) / (nci * ncj) -
    length(intersect(Ti, Cj)) / (nti * ncj) - length(intersect(Ci, Tj)) / (nci * ntj)
  num / sqrt((1 / nti + 1 / nci) * (1 / ntj + 1 / ncj))
}

# Matrice di correlazione di una coppia (gruppo, studio) e i suoi componenti connessi:
# due bracci sono legati se condividono un campione con lo STESSO ruolo.
struttura_coppia <- function(TT, CC) {
  m <- length(TT); R <- diag(1, m); legame <- matrix(FALSE, m, m)
  opposti <- 0L
  if (m > 1L) for (i in seq_len(m - 1L)) for (j in (i + 1L):m) {
    R[i, j] <- R[j, i] <- rho_bracci(TT[[i]], CC[[i]], TT[[j]], CC[[j]])
    legame[i, j] <- legame[j, i] <-
      length(intersect(TT[[i]], TT[[j]])) > 0L || length(intersect(CC[[i]], CC[[j]])) > 0L
    if (length(intersect(TT[[i]], CC[[j]])) > 0L || length(intersect(CC[[i]], TT[[j]])) > 0L)
      opposti <- opposti + 1L
  }
  comp <- seq_len(m)
  repeat {
    nuovo <- comp
    for (i in seq_len(m)) nuovo[i] <- min(comp[legame[i, ] | seq_len(m) == i])
    if (identical(nuovo, comp)) break
    comp <- nuovo
  }
  list(R = R, comp = match(comp, unique(comp)), coppie_ruolo_opposto = opposti)
}

# T1: varianza dello stimatore di produzione. U = matrice geni x bracci di 1/S, 0 se manca.
var_t1 <- function(U, R) rowSums((U %*% R) * U) / rowSums(U^2)^2

# REM gene per gene: la stessa chiamata a metafor di .pool_rem_cluster (REML; un warning o un
# errore passano a DL; BH dentro il gruppo). dt ha le colonne gene_id, y, se.
rem_gruppo <- function(dt, cid) {
  ok <- is.finite(dt$y) & is.finite(dt$se)
  dt <- dt[ok]
  ig <- split(seq_len(nrow(dt)), dt$gene_id)
  ig <- ig[lengths(ig) >= 2L]
  n <- length(ig)
  if (n == 0L) return(data.table())
  m <- matrix(NA_real_, n, 7L)
  y <- dt$y; se <- dt$se
  for (i in seq_len(n)) {
    j <- ig[[i]]
    res <- tryCatch(metafor::rma(yi = y[j], sei = se[j], method = "REML"),
                    error = function(e) NULL, warning = function(w) NULL)
    if (is.null(res)) res <- tryCatch(metafor::rma(yi = y[j], sei = se[j], method = "DL"),
                                      error = function(e) NULL)
    if (is.null(res)) next
    m[i, ] <- c(as.numeric(res$b), res$se, res$pval, res$tau2, res$I2, res$k, 1)
  }
  tieni <- !is.na(m[, 7L])
  out <- data.table(cluster_id = cid, gene_id = names(ig)[tieni], logFC_pool = m[tieni, 1L], SE_pool = m[tieni, 2L],
                    p_value_pool = m[tieni, 3L], tau2 = m[tieni, 4L], I2 = m[tieni, 5L], k_effective = as.integer(m[tieni, 6L]))
  out[, FDR := p.adjust(p_value_pool, method = "BH")]
  out[]
}
