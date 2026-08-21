#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/C2-controllo-condiviso.R
#
# I NUMERI DELLA SESSIONE S13, che senza questo file sarebbero asseriti.
#
# 26 verdetti su 194 nominano lo stesso fenomeno: nello stesso (gruppo, studio)
# compaiono DUE entry con l'etichetta identica. L'arbitro l'ha chiamato
# «duplicazione» e l'ha escluso da difetti.csv perche' «non rompe il contrasto» —
# giusto per il suo compito, ma la parola e' sbagliata, e la differenza e'
# operativa:
#
#   - se fosse duplicazione (stessi campioni due volte), la cura sarebbe
#     deduplicare;
#   - se e' CONTROLLO CONDIVISO (trattati diversi, stesso pool di controllo),
#     deduplicare butterebbe via campioni veri.
#
# Questo script misura quale delle due sia, e quanto tocchi `quota_top1` — il
# criterio che porta il setaccio da 113 a 37.
#
# ⚠️ DUE CATENE DIVERSE, e vanno guardate entrambe:
#   - `quota_top1` lo calcola `.collapse_arm_se_by_study()`
#     (R/stage4-pooling-effectiveness.R), via `compute_pooling_effectiveness()`;
#   - le STIME poolate le calcola `.collapse_arms_by_study()`
#     (R/stage4-orchestrator.R:218).
# Confonderle manda a misurare la cosa sbagliata.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/C2-controllo-condiviso.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli) })
OUT  <- "analysis/audit/2026-08-20-rilettura-194"
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"

A <- readRDS(file.path(OUT, "dispatch-A3.rds"))$tenuti
d <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
stopifnot("gsm_t" %in% names(A))

# --- 1. quante entry hanno l'etichetta identica nello stesso (gruppo, studio) --
A$et  <- paste(A$etichetta_trattato, "||", A$etichetta_controllo)
chiave <- paste(A$cluster_id, A$study_id, A$et)
dupk  <- unique(chiave[duplicated(chiave)])
D     <- A[chiave %in% dupk, ]

cli_h1("Il fenomeno")
cli_alert_info("entry con etichetta identica nello stesso (gruppo, studio): {nrow(D)}")
cli_alert_info("chiavi distinte: {length(dupk)} | studi: {length(unique(D$study_id))} | gruppi: {length(unique(D$cluster_id))}")

# --- 2. e' duplicazione o controllo condiviso? --------------------------------
sp <- split(D, paste(D$cluster_id, D$study_id, D$et))
tid <- sum(vapply(sp, function(g) length(unique(g$gsm_t)) == 1L, logical(1)))
cid <- sum(vapply(sp, function(g) length(unique(g$gsm_c)) == 1L, logical(1)))
cli_h2("Duplicazione, o controllo condiviso?")
cli_alert_info("chiavi in cui i TRATTATI sono gli stessi campioni : {tid} su {length(sp)}")
cli_alert_info("chiavi in cui i CONTROLLI sono gli stessi campioni: {cid} su {length(sp)}")
if (tid == 0L) {
  cli_alert_success("Nessuna chiave ha i trattati identici: NON e' duplicazione, e' controllo condiviso.")
  cli_alert_warning("Deduplicare butterebbe via campioni veri: NON e' la cura.")
}

# --- 3. quanto tocca il setaccio 113 -> 37 ------------------------------------
# i 113 = senza difetti letti + verdetto 'corretta' + etichetta che chiude
v <- utils::read.csv(file.path(OUT, "verdetti-194.csv"), stringsAsFactors = FALSE)
i <- match(v$cluster_id, d$cluster_id)
v$quota_top1 <- d$quota_top1[i]
sel113 <- v$n_studi_difettosi == 0 & v$verdetto_finale == "corretta" &
  v$etichetta_non_chiude != "True"
cli_h2("Quanto tocca il taglio 113 -> 37")
cli_alert_info("i 113: {sum(sel113)} | di cui nei 37 (quota<=0,5): {sum(sel113 & !is.na(v$quota_top1) & v$quota_top1 <= 0.5)}")

tocc <- unique(D$cluster_id)
cli_alert_info("gruppi col fenomeno: {length(tocc)} | di cui nei 113: {sum(sel113 & v$cluster_id %in% tocc)}")
q <- v$quota_top1[sel113 & v$cluster_id %in% tocc]
cli_alert_info("  gia' dentro i 37: {sum(q <= 0.5, na.rm = TRUE)} | fuori: {sum(q > 0.5, na.rm = TRUE)}")
vic <- sort(q[q > 0.5 & q < 0.60])
cli_alert_info("  SUL CONFINE (quota fra 0,50 e 0,60): {length(vic)} -> {paste(sprintf('%.2f', vic), collapse=' ')}")

# quanti dei 113 hanno lo studio dominante con piu' di un braccio: e' la stessa
# famiglia, ed e' piu' larga del fenomeno delle etichette identiche
nb <- table(paste(A$cluster_id, A$study_id))
dom <- d$studio_dominante[match(v$cluster_id, d$cluster_id)]
multi <- vapply(seq_len(nrow(v)), function(k) {
  if (is.na(dom[k])) return(FALSE)
  n <- nb[[paste(v$cluster_id[k], dom[k])]]
  !is.null(n) && n > 1L
}, logical(1))
cli_alert_info("dei 113, con lo studio DOMINANTE a piu' di un braccio: {sum(sel113 & multi)}")

utils::write.csv(
  data.frame(cluster_id = D$cluster_id, study_id = D$study_id,
             etichetta = D$et, n_t = D$n_t, n_c = D$n_c,
             gsm_t = D$gsm_t, gsm_c = D$gsm_c, stringsAsFactors = FALSE),
  file.path(OUT, "C2-controllo-condiviso.csv"), row.names = FALSE)
cli_alert_success("Scritto C2-controllo-condiviso.csv")
