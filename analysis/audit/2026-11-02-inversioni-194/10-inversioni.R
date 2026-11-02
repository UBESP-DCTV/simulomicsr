#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-inversioni-194/10-inversioni.R
#
# Ogni studio contro la mediana degli altri studi del gruppo, su tutte le 194, con
# un nullo empirico fatto di gruppi estratti a caso. Metodo e soglie: 00-previsioni.md.
# Un candidato non e' un'inversione: va letto sui metadati (20-materiale-candidati.py).
#
# Uso: Rscript analysis/audit/2026-11-02-inversioni-194/10-inversioni.R
#      SOLO=<cluster_id,...> restringe gli studi misurati (il nullo resta su tutti i gruppi)
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(matrixStats); library(cli)
  devtools::load_all(".", quiet = TRUE)
})
OUT  <- "analysis/audit/2026-11-02-inversioni-194"
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
SEME <- 20261102L; N_NULLO <- 20L; N_NULLO_BRACCIO <- 5L; TOP <- 500L; MIN_GENI <- 1000L
SOLO <- strsplit(Sys.getenv("SOLO", ""), ",")[[1]]

d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
stopifnot(nrow(d) == 194L)
x <- as.data.table(read_parquet(file.path(POOL, "per_study_de.parquet"),
       col_select = c("cluster_id", "study_id", "gene_id", "logFC", "SE", "n_treated", "n_control")))
x <- x[cluster_id %in% d$cluster_id & is.finite(logFC) & is.finite(SE) & SE > 0]
cli_alert_info("righe per braccio sulle 194: {nrow(x)}")

# I bracci di uno studio stanno in righe contigue ma il parquet non li nomina: un
# braccio finisce dove cambia (n_treated, n_control) o dove un gene si ripete.
segna_bracci <- function(gene, nt, nc) {
  n <- length(gene); b <- integer(n); corrente <- 1L; i <- 1L
  cambio <- c(FALSE, nt[-1L] != nt[-n] | nc[-1L] != nc[-n])
  while (i <= n) {
    fine <- n
    tratto <- i:n
    dup <- duplicated(gene[tratto]) | (cambio[tratto] & tratto != i)
    if (any(dup)) fine <- tratto[which(dup)[1L]] - 1L
    b[i:fine] <- corrente; corrente <- corrente + 1L; i <- fine + 1L
  }
  b
}
x[, braccio := segna_bracci(gene_id, n_treated, n_control), by = .(cluster_id, study_id)]
controllo <- x[, .(n = .N, dup = anyDuplicated(gene_id) > 0L), by = .(cluster_id, study_id, braccio)]
stopifnot(!any(controllo$dup))
cli_alert_info("studi nei gruppi: {nrow(unique(x[, .(cluster_id, study_id)]))} | bracci: {nrow(controllo)}")

# stessa formula di .collapse_arms_by_study, che su queste dimensioni non finisce
st <- x[, {w <- 1 / SE^2; .(logFC = sum(w * logFC) / sum(w), SE = sqrt(1 / sum(w)))},
        by = .(cluster_id, study_id, gene_id)]
prova <- d[contrast_entity_label == "IFNA1", cluster_id]
if (length(prova) == 1L) {
  q <- as.data.frame(x[cluster_id == prova, .(cluster_id, study_id, gene_id, gene_symbol = gene_id, logFC, SE,
         p_value = NA_real_, t_stat = NA_real_, n_treated, n_control, direction_applied = "none")])
  ref <- as.data.table(.collapse_arms_by_study(q))
  mio <- st[cluster_id == prova]
  setkey(ref, study_id, gene_id); setkey(mio, study_id, gene_id)
  stopifnot(isTRUE(all.equal(ref$logFC, mio$logFC)), isTRUE(all.equal(ref$SE, mio$SE)))
  cli_alert_success("collasso identico a .collapse_arms_by_study su IFNA1")
}

geni <- sort(unique(st$gene_id)); G <- length(geni)
st[, ig := match(gene_id, geni)]; x[, ig := match(gene_id, geni)]
vettore <- function(ig, v) { o <- rep(NA_real_, G); o[ig] <- v; o }
gruppi <- sort(d$cluster_id)
MAT <- lapply(setNames(gruppi, gruppi), function(cid) {
  s <- st[cluster_id == cid]; studi <- sort(unique(s$study_id))
  L <- matrix(NA_real_, G, length(studi), dimnames = list(NULL, studi)); T <- L
  j <- match(s$study_id, studi)
  L[cbind(s$ig, j)] <- s$logFC; T[cbind(s$ig, j)] <- s$logFC / s$SE
  list(L = L, T = T, studi = studi)
})
RIF_INTERO <- lapply(MAT, function(m) list(L = rowMedians(m$L, na.rm = TRUE), T = rowMedians(m$T, na.rm = TRUE)))
studi_in <- lapply(MAT, `[[`, "studi")

rho <- function(a, ref, tref) {
  ok <- which(is.finite(a) & is.finite(ref) & is.finite(tref))
  if (length(ok) < MIN_GENI) return(c(tutti = NA_real_, top = NA_real_, n = length(ok)))
  top <- ok[order(-abs(tref[ok]))[seq_len(min(TOP, length(ok)))]]
  c(tutti = suppressWarnings(cor(a[ok], ref[ok], method = "spearman")),
    top = suppressWarnings(cor(a[top], ref[top], method = "spearman")), n = length(ok))
}
set.seed(SEME)
misura_gruppi <- if (length(SOLO)) intersect(gruppi, SOLO) else gruppi
righe <- list(); nullo <- list(); righe_b <- list(); nullo_b <- list()
t0 <- Sys.time()
for (ic in seq_along(misura_gruppi)) {
  cid <- misura_gruppi[ic]; m <- MAT[[cid]]
  for (s in m$studi) {
    altri <- setdiff(m$studi, s); if (!length(altri)) next
    rifL <- rowMedians(m$L[, altri, drop = FALSE], na.rm = TRUE)
    rifT <- rowMedians(m$T[, altri, drop = FALSE], na.rm = TRUE)
    r <- rho(m$L[, s], rifL, rifT)
    coppie <- vapply(altri, function(o) suppressWarnings(cor(m$L[, s], m$L[, o], use = "pairwise.complete.obs", method = "spearman")), 0)
    righe[[length(righe) + 1L]] <- data.table(cluster_id = cid, study_id = s, k = length(m$studi),
      rho_tutti = r[["tutti"]], rho_top = r[["top"]], n_geni = r[["n"]],
      n_altri = length(altri), n_altri_negativi = sum(coppie < 0, na.rm = TRUE),
      rho_coppia_min = min(coppie, na.rm = TRUE), rho_coppia_max = max(coppie, na.rm = TRUE))
    estranei <- gruppi[vapply(gruppi, function(g) !(s %in% studi_in[[g]]), TRUE)]
    for (g in sample(estranei, min(N_NULLO, length(estranei)))) {
      n <- rho(m$L[, s], RIF_INTERO[[g]]$L, RIF_INTERO[[g]]$T)
      nullo[[length(nullo) + 1L]] <- data.table(cluster_id = cid, study_id = s, altro = g, rho_tutti = n[["tutti"]], rho_top = n[["top"]])
    }
    bb <- x[cluster_id == cid & study_id == s]
    if (uniqueN(bb$braccio) > 1L) {
      for (b in sort(unique(bb$braccio))) {
        q <- bb[braccio == b]; v <- vettore(q$ig, q$logFC)
        r2 <- rho(v, rifL, rifT)
        righe_b[[length(righe_b) + 1L]] <- data.table(cluster_id = cid, study_id = s, braccio = b,
          n_treated = q$n_treated[1L], n_control = q$n_control[1L], rho_tutti = r2[["tutti"]], rho_top = r2[["top"]], n_geni = r2[["n"]])
        for (g in sample(estranei, min(N_NULLO_BRACCIO, length(estranei)))) {
          n <- rho(v, RIF_INTERO[[g]]$L, RIF_INTERO[[g]]$T)
          nullo_b[[length(nullo_b) + 1L]] <- data.table(rho_tutti = n[["tutti"]], rho_top = n[["top"]])
        }
      }
    }
  }
  if (ic %% 20L == 0L) cli_alert_info("{ic}/{length(misura_gruppi)} gruppi, {round(difftime(Sys.time(), t0, units = 'mins'), 1)} min")
}
R <- rbindlist(righe); N <- rbindlist(nullo); RB <- rbindlist(righe_b); NB <- rbindlist(nullo_b, fill = TRUE)
qq <- function(v) quantile(v, c(.001, .01, .05, .5, .95, .99), na.rm = TRUE)
Q <- rbind(studio_tutti = qq(N$rho_tutti), studio_top = qq(N$rho_top),
           braccio_tutti = if (nrow(NB)) qq(NB$rho_tutti), braccio_top = if (nrow(NB)) qq(NB$rho_top))
cat("\nquantili del nullo:\n"); print(round(Q, 3))
R[, candidato := rho_tutti < Q["studio_tutti", "1%"] | rho_top < Q["studio_top", "1%"]]
R[, entrambe := rho_tutti < Q["studio_tutti", "1%"] & rho_top < Q["studio_top", "1%"]]
if (nrow(RB)) RB[, candidato := rho_tutti < Q["braccio_tutti", "1%"] | rho_top < Q["braccio_top", "1%"]]
nomi <- d[, .(cluster_id, nome = fifelse(is.na(contrast_entity_label), contrast_entity, contrast_entity_label), controllo = contrast_control_key)]
R <- nomi[R, on = "cluster_id"]; if (nrow(RB)) RB <- nomi[RB, on = "cluster_id"]
suf <- if (length(SOLO)) "-prova" else ""
fwrite(R[order(rho_tutti)], file.path(OUT, sprintf("inversioni-per-studio%s.csv", suf)))
if (nrow(RB)) fwrite(RB[order(rho_tutti)], file.path(OUT, sprintf("inversioni-per-braccio%s.csv", suf)))
write.csv(round(Q, 4), file.path(OUT, sprintf("nullo-quantili%s.csv", suf)))
cat(sprintf("\ncoppie gruppo-studio misurate: %d | candidati: %d (%.1f%%) | su entrambe le misure: %d\n",
            nrow(R), sum(R$candidato, na.rm = TRUE), 100 * mean(R$candidato, na.rm = TRUE), sum(R$entrambe, na.rm = TRUE)))
if (nrow(RB)) cat(sprintf("bracci di studi multi-braccio: %d | candidati: %d\n", nrow(RB), sum(RB$candidato, na.rm = TRUE)))
cat("\ncontrollo positivo:\n"); print(R[study_id == "GSE144269", .(nome, study_id, rho_tutti, rho_top, candidato, entrambe)])
cat(sprintf("\ndurata: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
