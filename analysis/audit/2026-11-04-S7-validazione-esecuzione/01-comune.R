# analysis/audit/2026-11-04-S7-validazione-esecuzione/01-comune.R
# Rscript SENZA --vanilla: con --vanilla mancano arrow e devtools.
# Disegno: docs/superpowers/specs/2026-11-04-validazione-esterna-design.md (congelato).
suppressPackageStartupMessages(library(data.table))
E7   <- "analysis/audit/2026-11-04-S7-validazione-esecuzione"
S6   <- "analysis/audit/2026-11-04-S6-validazione-disegno"
S5   <- "analysis/audit/2026-11-03-S5-gate-e-insiemi"
POOL <- Sys.getenv("POOL_DIR", "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d")
LIN  <- "/mnt/wwn-0x5000039d58caca35/lincs-meta"
LV5  <- file.path(LIN, "level5")
PES7 <- Sys.getenv("PES7", "/mnt/micron/simulomicsr-dati/2026-11-04-S7-validazione-esecuzione")
dir.create(PES7, showWarnings = FALSE, recursive = TRUE)
SEME <- 20261104L
BOOT <- 2000L
GCTX_CP  <- file.path(LV5, "level5_beta_trt_cp_n720216x12328.gctx")
GCTX_LIG <- file.path(LV5, "level5_beta_trt_misc_n8283x12328.gctx")
options(width = 180)

leggi_si <- function() {
  si <- fread(file.path(LIN, "siginfo_beta.txt"), sep = "\t", quote = "", colClasses = "character",
              select = c("sig_id","pert_id","pert_type","cmap_name","cell_iname","tas","is_exemplar_sig","qc_pass"))
  si[, tas := suppressWarnings(as.numeric(tas))]
  si
}
attive <- function(si) si[is_exemplar_sig == "1" & !is.na(tas) & tas >= 0.2]
landmark <- function() fread(file.path(LIN, "geneinfo_beta.txt"), sep = "\t", quote = "", colClasses = "character")[feature_space == "landmark"]

# Firma: media delle z dentro la linea, poi media fra le linee (disegno §5).
# M: geni x firme, con colnames = sig_id. sg: data.table(sig_id, gruppo, cell_iname).
firme_per_gruppo <- function(M, sg) {
  sg <- sg[sig_id %in% colnames(M)]
  sg[, chiave := paste(gruppo, cell_iname, sep = "\r")]
  tm <- t(M[, sg$sig_id, drop = FALSE])
  somma <- rowsum(tm, sg$chiave, reorder = FALSE)
  n <- as.numeric(table(sg$chiave)[rownames(somma)])
  L <- somma / n                                  # (gruppo, linea) x geni
  g <- sub("\r.*", "", rownames(L))
  sl <- rowsum(L, g, reorder = FALSE)
  nl <- as.numeric(table(g)[rownames(sl)])
  t(sl / nl)                                      # geni x gruppi
}

# Ranghi per colonna, senza valori mancanti (Level 5 e' completo: lo controlla 20-firme.R).
ranghi <- function(F) { R <- apply(F, 2L, rank, ties.method = "average"); dimnames(R) <- dimnames(F); R }
# Spearman di una query con una matrice, sui geni in comune: equivale a
# cor(q, F, method = "spearman", use = "pairwise.complete.obs"), controllato da 30-controllo-l1000.R.
sim_q <- function(q, F) {
  g <- intersect(names(q)[!is.na(q)], rownames(F))
  drop(cor(rank(q[g]), ranghi(F[g, , drop = FALSE])))
}
# Il rango del disegno §5: quota del fondo con sim minore di quella del composto giusto.
rango_p <- function(s_giusto, s_fondo) mean(s_fondo < s_giusto)

cp_lim <- function(x, n, lato) if (lato == "lo") { if (x == 0L) 0 else qbeta(.025, x, n - x + 1L) } else { if (x == n) 1 else qbeta(.975, x + 1L, n - x) }

pulisci <- function(x) gsub("[^a-z0-9]", "", tolower(x))
