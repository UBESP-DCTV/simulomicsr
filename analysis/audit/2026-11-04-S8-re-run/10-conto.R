#!/usr/bin/env Rscript
# S8: riproduce il conto dell'handout e stima gli ingressi dagli studi mai rigenerati.
# Stimatore, cancelli e previsioni: 00-previsioni.md (commit 665f102).
# Uso: Rscript analysis/audit/2026-11-04-S8-re-run/10-conto.R   (senza --vanilla)
suppressPackageStartupMessages({ library(arrow); library(data.table) })
OUT   <- "analysis/audit/2026-11-04-S8-re-run"
A3P   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
RIFP  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/archivio/20260815T193851Z-stage4-v16-3e31e59d"
S3A   <- "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159"
S3R   <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"
SEME  <- 20261104L; B <- 2000L
A3    <- readLines("analysis/audit/2026-08-16-A3/A3-studi.txt")
DEF   <- jsonlite::fromJSON("analysis/audit/2026-08-16-A3/A3-definizione.json")

coppie <- function(d) {
  cl <- as.data.table(readRDS(file.path(d, "clusters.rds")))[mode == "cgroup",
          .(cluster_id, e = contrast_entity, v = contrast_direction, c = contrast_control_key)]
  a <- as.data.table(read_parquet(file.path(d, "assignments.parquet"), col_select = c("record_id", "cluster_id", "mode")))[mode == "cgroup"]
  a[, s := sub("__.*$", "", record_id)]
  x <- unique(merge(a[, .(s, cluster_id)], cl, by = "cluster_id"))
  x[, k := uniqueN(s), by = cluster_id]
  unique(x)
}
cat("carico gli Stadi 3...\n")
PA <- coppie(S3A); PR <- coppie(S3R)

del <- function(P) {
  d <- as.data.table(readRDS(file.path(P, "deliverable-annotato.rds")))
  st <- unique(as.data.table(open_dataset(file.path(P, "per_study_de.parquet")) |> dplyr::distinct(cluster_id, study_id) |> dplyr::collect()))
  st[, study_id := as.character(study_id)]
  list(d = d, st = st[cluster_id %in% d$cluster_id])
}
DA <- del(A3P); DR <- del(RIFP)
key <- function(e, v, c) paste(e, v, c, sep = "||")
DA$d[, ck := key(contrast_entity, contrast_direction, contrast_control_key)]
DR$d[, ck := key(contrast_entity, contrast_direction, contrast_control_key)]
PA[, ck := key(e, v, c)]; PR[, ck := key(e, v, c)]
PA[, ev := paste(e, v, sep = "||")]; PR[, ev := paste(e, v, sep = "||")]

# ---- Cancello 2: il conto dell'handout ---------------------------------------
sA <- unique(DA$st$study_id); sR <- unique(DR$st$study_id)
esce <- setdiff(DR$d$ck, DA$d$ck); entra <- setdiff(DA$d$ck, DR$d$ck); resta <- intersect(DR$d$ck, DA$d$ck)
dk <- DA$d[match(resta, ck), k_effective] - DR$d[match(resta, ck), k_effective]
uscS <- setdiff(sR, sA); entS <- setdiff(sA, sR)
cat(sprintf("\n== CANCELLO 2 ==\nA3 %d studi, record %d su %d\nmeta-analisi %d -> %d, escono %d, entrano %d, comuni %d\nstudi poolati %d -> %d, usciti %d, entrati %d\nk invariato %d, in calo %d, in crescita %d\n",
  length(A3), DEF$n_record_stage1, DEF$n_record_stage1_totali, nrow(DR$d), nrow(DA$d), length(esce), length(entra), length(resta),
  length(sR), length(sA), length(uscS), length(entS), sum(dk == 0), sum(dk < 0), sum(dk > 0)))
c2 <- length(A3) == 2566 && nrow(DR$d) == 211 && nrow(DA$d) == 194 && length(esce) == 38 && length(entra) == 21 && length(resta) == 173 &&
  length(sR) == 1123 && length(sA) == 993 && length(uscS) == 271 && length(entS) == 141 && all(c(sum(dk == 0), sum(dk < 0), sum(dk > 0)) == c(68, 76, 29))
cat("cancello 2:", if (c2) "PASSA" else "NON PASSA", "\n")

# una meta-analisi per entita'?
cat(sprintf("\nmeta-analisi 194: entita' distinte %d; studi poolati fuori da A3: %d\n", uniqueN(DA$d$contrast_entity), length(setdiff(sA, A3))))

# ---- gli studi fuori -----------------------------------------------------------
con <- pipe("python3 -c \"import sys,json\nfor l in open(sys.argv[1]):\n    print(json.loads(l)['series_id'])\" analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
TUTTI <- unique(readLines(con)); close(con)
FUORI <- setdiff(TUTTI, A3)
cat(sprintf("\nstudi nel master %d; A3 fuori dal master %d; fuori da A3 %d\n", length(TUTTI), length(setdiff(A3, TUTTI)), length(FUORI)))
PF <- PA[s %in% FUORI]   # lo Stadio 3 A3 tiene i record non rigenerati cosi' come sono
n_con <- uniqueN(PF$s)
cat(sprintf("P1: fuori con almeno una coppia cgroup: %d su %d = %.1f%%\n", n_con, length(FUORI), 100 * n_con / length(FUORI)))
cat(sprintf("fuori in gruppi con k>=2 nello Stadio 3 A3: %d studi; con k>=3: %d studi; nel deliverable: %d\n",
  uniqueN(PF[k >= 2, s]), uniqueN(PF[k >= 3, s]), length(intersect(FUORI, sA))))
cat("distribuzione coppie per studio fuori:\n"); print(quantile(PF[, .N, by = s]$N, c(.5, .9, .99, 1)))

evDel <- unique(paste(DA$d$contrast_entity, DA$d$contrast_direction, sep = "||"))
eDel  <- unique(DA$d$contrast_entity)
PF[, in_ev := ev %in% evDel]
nP2 <- uniqueN(PF[in_ev == TRUE, s])
cat(sprintf("P2: fuori con entita' e verso di una delle 194: %d = %.1f%% di %d (coppie %d su %d)\n", nP2, 100 * nP2 / length(FUORI), length(FUORI), sum(PF$in_ev), nrow(PF)))

# ---- Tassi sugli studi di A3 --------------------------------------------------
keyDel <- DA$d$ck
poolati <- merge(DA$st, DA$d[, .(cluster_id, ck)], by = "cluster_id")[, .(s = study_id, ck)]
poolati[, pool := TRUE]
keyK2 <- unique(PA[k >= 2, ck])
evK2  <- unique(PA[k >= 2, ev])

tassi_per_studio <- function(studi) {
  R <- PR[s %in% studi]; N <- PA[s %in% studi]
  rs <- R[k == 1L]
  rs[, ha_ev := ev %in% evDel]; rs[, ha_ev2 := ev %in% evK2]
  # nuove chiavi per studio, non presenti prima nello stesso studio
  N2 <- N[!R[, .(s, ck)], on = .(s, ck)]
  N2[, inDel := ck %in% keyDel]
  N2 <- merge(N2, poolati, by = c("s", "ck"), all.x = TRUE); N2[is.na(pool), pool := FALSE]
  R_ent <- unique(R[, .(s, e)])
  # stessa entita' e verso, altro controllo
  uni <- rs[, .(s, ev, c)]
  arr_st <- N2[inDel == TRUE, .(s, ev, ck, pool)]
  m <- merge(uni[rs$ha_ev], arr_st, by = c("s", "ev"), allow.cartesian = TRUE)
  m1 <- m[, .(arr = TRUE, pool = any(pool)), by = .(s, ev, c)]
  r1 <- merge(uni[rs$ha_ev], m1, by = c("s", "ev", "c"), all.x = TRUE)
  r1[is.na(arr), `:=`(arr = FALSE, pool = FALSE)]
  # stessa cosa verso chiavi con k>=2
  arr_k2 <- N2[k >= 2L, .(s, ev, ck)]
  m2 <- unique(merge(uni[rs$ha_ev2], arr_k2, by = c("s", "ev"), allow.cartesian = TRUE)[, .(s, ev, c)])
  m2[, arr := TRUE]
  r2 <- merge(uni[rs$ha_ev2], m2, by = c("s", "ev", "c"), all.x = TRUE); r2[is.na(arr), arr := FALSE]
  # altra entita': chiavi del deliverable nuove, con un'entita' che lo studio non aveva
  arr_o <- N2[inDel == TRUE][!R_ent, on = .(s, e)]
  dt <- data.table(s = studi)
  dt <- merge(dt, r1[, .(den_s = .N, arr_s = sum(arr), pool_s = sum(pool)), by = s], by = "s", all.x = TRUE)
  dt <- merge(dt, r2[, .(den_k2 = .N, arr_k2 = sum(arr)), by = s], by = "s", all.x = TRUE)
  dt <- merge(dt, rs[ha_ev == FALSE, .(den_o = .N), by = s], by = "s", all.x = TRUE)
  dt <- merge(dt, arr_o[, .(arr_o = uniqueN(ck), pool_o = uniqueN(ck[pool])), by = s], by = "s", all.x = TRUE)
  for (j in setdiff(names(dt), "s")) set(dt, which(is.na(dt[[j]])), j, 0L)
  dt
}
TS <- tassi_per_studio(intersect(A3, unique(PR$s)))
tassi <- function(t) {
  r_s <- sum(t$arr_s) / sum(t$den_s); r_k <- sum(t$arr_k2) / sum(t$den_k2)
  # l'altra via ha un numeratore per studio: lo limito al denominatore del singolo studio
  a_o <- pmin(t$arr_o, t$den_o); r_o <- sum(a_o) / sum(t$den_o)
  f <- (sum(t$pool_s) + sum(pmin(t$pool_o, t$den_o))) / max(1, sum(t$arr_s) + sum(a_o))
  c(r_s = r_s, r_k = r_k, r_o = r_o, f = f)
}
T0 <- tassi(TS)
cat(sprintf("\nstudi di A3 nel calcolo %d; coppie singole con entita' e verso nel deliverable %d; senza %d\n", nrow(TS), sum(TS$den_s), sum(TS$den_o)))
cat(sprintf("r_stessa %.4f, r_stessa_k2 %.4f (den %d), r_altra %.4f, f_pool %.3f\n", T0["r_s"], T0["r_k"], sum(TS$den_k2), T0["r_o"], T0["f"]))

# ---- Le coppie fuori e la previsione -------------------------------------------
nF <- PF[, .(n_s = sum(in_ev), n_o = sum(!in_ev)), by = s]
quota <- DA$d[, .(ck, ev = paste(contrast_entity, contrast_direction, sep = "||"), entita = contrast_entity, n = n_studi_poolati)]
quota[, q := n / sum(n), by = ev]
arrEv <- PF[in_ev == TRUE, .N, by = ev]
# entita' senza meta-analisi: gruppi con due studi nello Stadio 3 A3
g2 <- unique(PA[k == 2L & !(e %in% eDel), .(ck, ev, e)])
altKey <- unique(PA[k >= 2L, .(ck, ev, k)])[, .(ck, ev, qk = k / sum(k)), by = ev]
arrK2 <- PF[, .N, by = ev]

prevedi <- function(T) {
  ps <- T["r_s"] * T["f"]; po <- T["r_o"] * T["f"]
  P3 <- sum(1 - (1 - ps)^nF$n_s * (1 - po)^nF$n_o)
  q <- merge(quota, arrEv, by = "ev", all.x = TRUE); q[is.na(N), N := 0L]
  q[, a := N * ps * q]
  # l'altra via si distribuisce in proporzione agli studi di ogni chiave
  q[, a := a + sum(nF$n_o) * po * n / sum(quota$n)]
  q[, tocca := 1 - exp(-a)]
  g <- merge(g2, altKey[, .(ck, qk)], by = "ck", all.x = TRUE); g <- merge(g, arrK2, by = "ev", all.x = TRUE); g[is.na(N), N := 0L]
  g[, a := N * T["r_k"] * qk]
  g[, nuova := 1 - exp(-a)]
  # una meta-analisi per entita': l'entita' nasce se almeno un suo gruppo arriva a tre studi
  P6 <- sum(g[, .(p = 1 - prod(1 - nuova)), by = e]$p)
  list(P3 = P3, P4 = sum(q$tocca), q = q, P6 = P6)
}
PR0 <- prevedi(T0)
i41 <- fread("analysis/audit/2026-11-03-S5-gate-e-insiemi/50-insieme-41.csv")
i40 <- fread("analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv")
colcid <- function(x) if ("cluster_id" %in% names(x)) x$cluster_id else x[[1]]
ck41 <- DA$d[cluster_id %in% colcid(i41), ck]; ck40 <- DA$d[cluster_id %in% colcid(i40), ck]
cat(sprintf("\n41 agganciate: %d; 40 agganciate: %d\n", length(ck41), length(ck40)))
top <- function(pr) c(P3 = pr$P3, P4 = pr$P4, P5 = sum(pr$q[ck %in% ck41, tocca]), P5_40 = sum(pr$q[ck %in% ck40, tocca]), P6 = pr$P6)

# Bootstrap in parallele: la scelta del PI consente fino al 90% dei processori (2026-11-04). Il seme resta quello depositato.
RNGkind("L'Ecuyer-CMRG"); set.seed(SEME)
setDTthreads(1L)
boot <- do.call(rbind, parallel::mclapply(seq_len(B), function(b) {
  t <- TS[sample.int(nrow(TS), replace = TRUE)]
  top(prevedi(tassi(t)))
}, mc.cores = 60L, mc.set.seed = TRUE))
setDTthreads(0L)
stopifnot(nrow(boot) == B, is.numeric(boot))
ic <- apply(boot, 2, quantile, c(.025, .975))
est <- top(PR0)
cat("\n== PREVISIONI (stima, IC95 bootstrap sugli studi di A3) ==\n")
for (n in names(est)) cat(sprintf("%-6s %8.1f  [%.1f; %.1f]\n", n, est[[n]], ic[1, n], ic[2, n]))
cat("copertura q:", nrow(PR0$q), "meta-analisi su", nrow(DA$d), "\n")
fwrite(PR0$q[, .(ck, entita, n, N_coppie_fuori = N, arrivi_attesi = round(a, 3), p_toccata = round(tocca, 3))][order(-p_toccata)], file.path(OUT, "10-toccate-per-meta-analisi.csv"))

# ---- Cancello 4(a): lo strumento vede i 141? ------------------------------------
vis <- entS %in% PA[ck %in% keyDel, s]
cat(sprintf("\n== CANCELLO 4a == entrati visti in una chiave del deliverable: %d su %d\n", sum(vis), length(entS)))
# il meccanismo dei 141: chiave nuova per lo studio o chiave che aveva gia'
dec <- merge(poolati[s %in% entS], PR[, .(s, ck, k_old = k)], by = c("s", "ck"), all.x = TRUE)
dec1 <- dec[, .(stessa = any(!is.na(k_old)), k_old_max = if (any(!is.na(k_old))) as.numeric(max(k_old, na.rm = TRUE)) else NA_real_), by = s]
cat(sprintf("141: con una chiave che lo studio aveva gia' %d; solo chiavi nuove %d\n", sum(dec1$stessa), sum(!dec1$stessa)))
cat("k della chiave che avevano gia' (riferimento):\n"); print(table(pmin(dec1[stessa == TRUE, k_old_max], 5)))
uni_arr <- sum(TS$pool_s)

# ---- Cancello 4(b): validazione incrociata --------------------------------------
oss_prev <- function(ts_stima, ts_prova) {
  T <- tassi(ts_stima)
  prev <- T["r_s"] * sum(ts_prova$den_s) + T["r_o"] * sum(ts_prova$den_o)
  oss  <- sum(ts_prova$arr_s) + sum(pmin(ts_prova$arr_o, ts_prova$den_o))
  c(prev = unname(prev), oss = oss, rapporto = unname(prev) / oss)
}
set.seed(SEME)
idx <- sample.int(nrow(TS), nrow(TS) %/% 2L)
v1 <- oss_prev(TS[idx], TS[-idx]); v2 <- oss_prev(TS[-idx], TS[idx])
cat("\n== CANCELLO 4b ==\n"); print(rbind(v1, v2))

# ---- il conto del flusso ---------------------------------------------------------
fu <- length(setdiff(A3, sR))
cat(sprintf("\nFLUSSI: poolati %d, escono %d = %.1f%%; non poolati dentro A3 %d, entrano %d = %.1f%%; fuori da A3 %d, entrano %d\n",
  length(sR), length(uscS), 100 * length(uscS) / length(sR), fu, length(entS), 100 * length(entS) / fu, length(FUORI), length(intersect(FUORI, sA))))
cat(sprintf("per annullare il netto -130 bastano 130 ingressi = %.2f%% dei fuori\n", 100 * 130 / length(FUORI)))

# ---- Entita' candidate a un gruppo nuovo (senza stima) ---------------------------
ev3 <- PA[!(e %in% eDel), .(n = uniqueN(s)), by = .(e, v)]
cat(sprintf("\nentita'+verso senza meta-analisi con almeno 3 studi su tutti i controlli: %d; di cui con entita' nominata %d\n", sum(ev3$n >= 3), sum(ev3$n >= 3 & !grepl("^(STR|UNK)", ev3$e))))
cat(sprintf("gruppi con k=2 per entita' senza meta-analisi: %d, entita' %d\n", nrow(g2), uniqueN(g2$e)))
saveRDS(list(T0 = T0, est = est, ic = ic), file.path(OUT, "10-stima.rds"))

# ---- Aggiunte dopo aver visto P1 e P2 smentite: NON depositate, si dichiarano come tali ----
cat("\n== AGGIUNTE NON DEPOSITATE ==\n")
# (1) da quale via vengono gli ingressi attesi
ps <- T0["r_s"] * T0["f"]; po <- T0["r_o"] * T0["f"]
cat(sprintf("arrivi attesi, via stessa entita': %.1f (coppie %d); via altra entita': %.1f (coppie %d)\n", sum(nF$n_s) * ps, sum(nF$n_s), sum(nF$n_o) * po, sum(nF$n_o)))
# (2) r_altra senza gli studi in cui si e' mosso un gruppo condiviso: la chiave nuova non puo' venire da li'
Rk2 <- PR[k >= 2L & s %in% TS$s, .(s, ck)]
perso <- unique(Rk2[!PA[, .(s, ck)], on = .(s, ck)]$s)
TSf <- TS[!(s %in% perso)]
Tf <- tassi(TSf)
cat(sprintf("studi di A3 senza gruppi condivisi persi: %d su %d; r_altra %.4f (den %d), r_stessa %.4f (den %d), f_pool %.3f\n", nrow(TSf), nrow(TS), Tf["r_o"], sum(TSf$den_o), Tf["r_s"], sum(TSf$den_s), Tf["f"]))
est2 <- top(prevedi(Tf))
cat("stima con questi tassi:\n"); print(round(est2, 1))
# (3) gli studi fuori senza coppie: hanno confronti nello Stadio 2?
Z <- fread(file.path(OUT, "22-comparisons-per-studio.tsv"))
Z[, ha_coppia := s %in% PA$s]
Zf <- Z[in_a3 == 0L]
cat(sprintf("\nfuori da A3 nel master innestato: %d; senza coppie %d; di questi con almeno un confronto nello Stadio 2 %d; senza confronti %d\n",
  nrow(Zf), sum(!Zf$ha_coppia), sum(!Zf$ha_coppia & Zf$n_cmp > 0), sum(!Zf$ha_coppia & Zf$n_cmp == 0)))
cat("disegno degli studi fuori senza coppie:\n"); print(Zf[ha_coppia == FALSE, .N, by = design_kind][order(-N)])
NC <- as.data.table(readRDS(file.path(S3A, "non_clusterable.rds")))
NC[, s := sub("__.*$", "", record_id)]
nof <- Zf[ha_coppia == FALSE & n_cmp > 0, s]
cat("motivi per i record dei fuori con confronti e senza coppie:\n"); print(NC[s %in% nof, .(record = .N, studi = uniqueN(s)), by = reason][order(-studi)])
# se questi studi producessero una coppia con la stessa probabilita' di arrivo: limite della riserva
nres <- sum(!Zf$ha_coppia & Zf$n_cmp > 0)
cat(sprintf("riserva: %d studi x r_altra %.4f x f_pool %.3f = %.1f ingressi, se ogni studio avesse una sola coppia\n", nres, T0["r_o"], T0["f"], nres * T0["r_o"] * T0["f"]))
# (4) i 21 e i 38 per k del riferimento o del deliverable
cat("\nk_effective delle 21 nuove:\n"); print(table(DA$d[ck %in% entra, pmin(k_effective, 6)]))
cat("k_effective delle 38 uscite:\n"); print(table(DR$d[ck %in% esce, pmin(k_effective, 6)]))
# (5) le entita' delle 21 nuove erano nuove o gia' nel riferimento sotto altra chiave?
cat(sprintf("delle 21 nuove, entita' gia' nel riferimento con altra chiave: %d; delle 38 uscite, entita' ancora nel deliverable con altra chiave: %d\n",
  sum(DA$d[ck %in% entra, contrast_entity] %in% DR$d$contrast_entity), sum(DR$d[ck %in% esce, contrast_entity] %in% DA$d$contrast_entity)))
# (6) quanto del peso delle 41 e delle 194 e' in meta-analisi con arrivi attesi alti
qq <- PR0$q[order(-tocca)]
cat("\nle dieci piu' esposte:\n"); print(qq[1:10, .(entita, n, coppie_fuori = N, arrivi = round(a, 2), p = round(tocca, 2))])

