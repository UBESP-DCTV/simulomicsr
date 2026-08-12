# FASE 3 — L'ESPERIMENTO: una variabile sola, le corsie sommate contro le corsie
# contate come repliche. Stessa funzione DE di produzione, stessi campioni,
# stessi geni. Cambia SOLO se le corsie della stessa libreria vengono sommate.
#
# PREVISIONE DEPOSITATA PRIMA DI GUARDARE (scritta qui, nel codice):
#   P1. GSE173902: sommando le corsie ogni braccio resta con UN campione: il
#       confronto non e' piu' calcolabile. Il crollo dell'SE osservato (0,19-0,39
#       volte i pari) e' quindi varianza di sequenziamento, non biologia.
#   P2. GSE178340 e GSE115542 (4 corsie): l'SE deve CRESCERE di circa sqrt(4)=2
#       volte, e la sd stimata deve restare simile (la varianza fra le 12 e' gia'
#       dominata dai 3 biologici).
#   P3. GSE116899 (2 corsie): crescita di circa sqrt(2)=1,41.
#   P4. Il logFC deve cambiare POCO (sommare corsie non sposta la media).
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC <- "analysis/audit/2026-08-12-corsie"
R  <- readRDS(file.path(SC, "30-entry-annotate.rds"))
M  <- readRDS(file.path(SC, "20-metadati.rds"))
h5 <- "analysis/input/human_gene_v2.5.h5"

tit  <- setNames(M$title, M$gsm)
scar <- function(x) gsub("[._-]+$", "", gsub("[._-]l0*[0-9]{1,3}([._-]|$)", "\\1",
                                             tolower(trimws(x))))
acc  <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))
gid  <- as.character(rhdf5::h5read(h5, "meta/genes/ensembl_gene"))
leggi <- function(gsms) {
  i <- match(gsms, acc); stopifnot(!anyNA(i))
  x <- rhdf5::h5read(h5, "data/expression", index = list(i, NULL))
  m <- t(x); rownames(m) <- gid; colnames(m) <- gsms; m
}

T <- R[R$tocca, ]
out <- list()
for (r in seq_len(nrow(T))) {
  gt <- strsplit(T$gsm_treated[r], ",")[[1]]; gc_ <- strsplit(T$gsm_control[r], ",")[[1]]
  gsms <- c(gt, gc_)
  cnt <- leggi(gsms)
  trt <- factor(c(rep("treated", length(gt)), rep("control", length(gc_))),
                levels = c("control", "treated"))

  a <- tryCatch(.run_limma_voom_de(cnt, trt, T$study_id[r], T$cluster_id[r]),
                error = function(e) { cat("  come-e': ERRORE:", conditionMessage(e), "\n"); NULL })

  # --- unica variabile che cambia: le corsie della stessa libreria si SOMMANO ---
  lib <- scar(tit[gsms])
  agg <- sapply(split(seq_along(gsms), lib), function(j) rowSums(cnt[, j, drop = FALSE]))
  lib_u <- colnames(agg)
  lato  <- vapply(split(seq_along(gsms), lib), function(j) {
    v <- ifelse(j <= length(gt), "treated", "control")
    if (length(unique(v)) > 1L) "MISTO" else v[1]
  }, character(1))
  if (any(lato == "MISTO")) cat("  ATTENZIONE: una libreria sta su tutti e due i bracci\n")
  trt2 <- factor(lato[lib_u], levels = c("control", "treated"))
  n_t2 <- sum(trt2 == "treated"); n_c2 <- sum(trt2 == "control")
  b <- if (n_t2 < 2L || n_c2 < 2L) NULL else
    tryCatch(.run_limma_voom_de(agg, trt2, T$study_id[r], T$cluster_id[r]),
             error = function(e) { cat("  sommato: ERRORE:", conditionMessage(e), "\n"); NULL })

  riga <- data.frame(study = T$study_id[r], cluster = T$cluster_id[r],
                     n_t = length(gt), n_c = length(gc_), n_t_bio = n_t2, n_c_bio = n_c2,
                     stringsAsFactors = FALSE)
  if (!is.null(a) && !is.null(b)) {
    m <- merge(a[, c("gene_id", "logFC", "SE")], b[, c("gene_id", "logFC", "SE")],
               by = "gene_id", suffixes = c("_corsie", "_sommato"))
    m <- m[is.finite(m$SE_corsie) & is.finite(m$SE_sommato), ]
    riga$n_geni <- nrow(m)
    riga$SE_corsie <- stats::median(m$SE_corsie)
    riga$SE_sommato <- stats::median(m$SE_sommato)
    riga$rapporto_SE <- stats::median(m$SE_sommato / m$SE_corsie)
    riga$cor_logFC <- stats::cor(m$logFC_corsie, m$logFC_sommato, method = "spearman")
    riga$scarto_logFC_med <- stats::median(abs(m$logFC_sommato - m$logFC_corsie))
  } else {
    riga$n_geni <- NA_integer_; riga$SE_corsie <- NA_real_; riga$SE_sommato <- NA_real_
    riga$rapporto_SE <- NA_real_; riga$cor_logFC <- NA_real_; riga$scarto_logFC_med <- NA_real_
  }
  cat(sprintf("%-11s %s  %2d/%2d -> %2d/%2d  rapporto SE %s\n", riga$study,
              substr(riga$cluster, 1, 18), riga$n_t, riga$n_c, riga$n_t_bio, riga$n_c_bio,
              if (is.na(riga$rapporto_SE)) "NON CALCOLABILE" else sprintf("%.3f", riga$rapporto_SE)))
  out[[length(out) + 1L]] <- riga
}
rhdf5::h5closeAll()
E <- do.call(rbind, out)
cat("\n=== ESITO ===\n"); print(E, row.names = FALSE)
write.csv(E, file.path(SC, "80-esperimento-corsie.csv"), row.names = FALSE)
saveRDS(E, file.path(SC, "80-esperimento-corsie.rds"))
