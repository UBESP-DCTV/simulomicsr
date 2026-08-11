#!/usr/bin/env Rscript
# 20-predittori.R --- PASSO 4, passo 2: i giudici divergono su che cosa?
#
# Due bersagli distinti, tenuti separati apposta:
#   Y1 = i due giudici CONCORDANO (qualunque livello)
#   Y2 = NUCLEO SOLIDO: entrambi dicono "coerente"  <- e' quello che un gate
#        deterministico dovrebbe saper predire
#
# ⚠️ CIRCOLARITA' DICHIARATA: `gse_accusati` e il numero di confronti imperfetti
# vengono dalla STESSA lettura umana che produce uno dei due verdetti. Sono
# descrittori, NON candidati per un gate. Sono marcati `circolare` e riportati
# a parte.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

OUT <- "analysis/audit/2026-08-09-passo4"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OLD <- "/tmp/claude-1000/-home-user-simulomicsr/632a8932-ecdb-46bf-887a-78492b79f0e2/scratchpad"

M <- readRDS(file.path(OUT, "10-matrice.rds"))
d <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
i <- match(M$cluster_id, d$cluster_id); stopifnot(!anyNA(i))

M$Y1 <- M$umano == M$mistral_b
M$Y2 <- M$umano == "coerente" & M$mistral_b == "coerente"
cat("base:", nrow(M), " concordi:", sum(M$Y1), " nucleo solido:", sum(M$Y2), "\n")

# --- predittori DETERMINISTICI (calcolabili senza leggere nulla) --------------
P <- data.frame(
  k_effective        = d$k_effective[i],
  k_kish             = d$k_kish[i],
  quota_top1         = d$quota_top1[i],
  frazione_efficace  = d$frazione_efficace[i],
  I2_med             = d$I2_med[i],
  n_sig              = d$n_sig[i],
  n_studi_poolati    = d$n_studi_poolati[i],
  n_studi_censiti    = d$n_studi_censiti[i],
  studi_caduti       = d$studi_caduti[i],
  n_studi_model      = d$n_studi_model[i],
  n_studi_unknown    = d$n_studi_unknown[i],
  stringsAsFactors = FALSE
)
B <- data.frame(
  dominato            = as.logical(d$dominato[i]),
  materiale_misto     = as.logical(d$materiale_misto[i]),
  dominato_da_modello = as.logical(d$dominato_da_modello[i]),
  stessi_membri       = as.logical(d$stessi_membri[i]),
  entita_STR          = startsWith(d$contrast_entity[i], "STR:"),
  entita_MeSH         = startsWith(d$contrast_entity[i], "MeSH:"),
  entita_NCBITaxon    = startsWith(d$contrast_entity[i], "NCBITaxon:"),
  ramo_anchor         = d$contrast_entity_source[i] == "anchor",
  controllo_veicolo   = grepl("vehicle", d$contrast_control_key[i], fixed = TRUE),
  verso_gain          = d$contrast_direction[i] == "gain",
  stringsAsFactors = FALSE
)
# frazione degli studi che sono modelli in vitro
P$frac_model <- with(d[i, ], n_studi_model / pmax(1, n_studi_poolati))

# --- descrittori CIRCOLARI (dalla lettura umana) ------------------------------
um <- utils::read.csv("analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv",
                      stringsAsFactors = FALSE)
j <- match(M$cluster_id, um$cluster_id)
n_acc <- vapply(strsplit(um$gse_accusati[j] %||% "", ";"), function(x) sum(nzchar(trimws(x))), integer(1L))
`%||%` <- function(a, b) if (is.null(a)) b else a
C <- data.frame(n_gse_accusati = n_acc,
                frac_gse_accusati = n_acc / pmax(1, P$n_studi_poolati),
                stringsAsFactors = FALSE)

# --- misura: dimensione dell'effetto, non p-value -----------------------------
coh_d <- function(x, g) {
  a <- x[g]; b <- x[!g]
  a <- a[is.finite(a)]; b <- b[is.finite(b)]
  if (length(a) < 3 || length(b) < 3) return(NA_real_)
  s <- sqrt(((length(a)-1)*stats::var(a) + (length(b)-1)*stats::var(b)) /
            (length(a)+length(b)-2))
  if (!is.finite(s) || s == 0) return(NA_real_)
  (mean(a) - mean(b)) / s
}
riga_num <- function(nm, x, g, tag) data.frame(
  predittore = nm, tipo = tag,
  media_si = round(mean(x[g], na.rm = TRUE), 3),
  media_no = round(mean(x[!g], na.rm = TRUE), 3),
  d_cohen  = round(coh_d(x, g), 3), stringsAsFactors = FALSE)
riga_bin <- function(nm, x, g, tag) data.frame(
  predittore = nm, tipo = tag,
  media_si = round(mean(x[g], na.rm = TRUE), 3),
  media_no = round(mean(x[!g], na.rm = TRUE), 3),
  d_cohen  = round(mean(x[g], na.rm = TRUE) - mean(x[!g], na.rm = TRUE), 3),
  stringsAsFactors = FALSE)

analizza <- function(Y, etichetta) {
  cat("\n\n########## BERSAGLIO:", etichetta, " (si =", sum(Y), " no =", sum(!Y), ") ##########\n")
  r <- rbind(
    do.call(rbind, lapply(names(P), function(n) riga_num(n, P[[n]], Y, "num"))),
    do.call(rbind, lapply(names(B), function(n) riga_bin(n, B[[n]], Y, "bin"))),
    do.call(rbind, lapply(names(C), function(n) riga_num(n, C[[n]], Y, "CIRCOLARE")))
  )
  r <- r[order(-abs(r$d_cohen)), ]
  print(r, row.names = FALSE)
  invisible(r)
}
r1 <- analizza(M$Y1, "i due giudici CONCORDANO")
r2 <- analizza(M$Y2, "NUCLEO SOLIDO (entrambi coerente)")

utils::write.csv(r1, file.path(OUT, "20-predittori-concordanza.csv"), row.names = FALSE)
utils::write.csv(r2, file.path(OUT, "20-predittori-nucleo.csv"), row.names = FALSE)
saveRDS(list(M = M, P = P, B = B, C = C), file.path(OUT, "20-dati.rds"))
cat("\nscritto in", OUT, "\n")
