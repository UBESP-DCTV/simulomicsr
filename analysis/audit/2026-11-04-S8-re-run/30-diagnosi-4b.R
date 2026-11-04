#!/usr/bin/env Rscript
# S8: perche' il cancello 4(b) fallisce. NON cambia il cancello, non cambia lo stimatore: spiega il fallimento.
# Le prime righe sono quelle di 10-conto.R, fino alla stima.
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

setDTthreads(8L)
cat("\n== CONCENTRAZIONE DEGLI ARRIVI ==\n")
TS[, arr_tot := arr_s + pmin(arr_o, den_o)]
cat(sprintf("arrivi totali %d in %d studi su %d; primi 1, 3, 5 studi: %d, %d, %d\n", sum(TS$arr_tot), sum(TS$arr_tot > 0), nrow(TS),
  sum(sort(TS$arr_tot, TRUE)[1]), sum(sort(TS$arr_tot, TRUE)[1:3]), sum(sort(TS$arr_tot, TRUE)[1:5])))
cat(sprintf("coppie singole: %d in %d studi; primi 1, 3, 5 studi: %d, %d, %d\n", sum(TS$den_s + TS$den_o), sum(TS$den_s + TS$den_o > 0),
  sum(sort(TS$den_s + TS$den_o, TRUE)[1]), sum(sort(TS$den_s + TS$den_o, TRUE)[1:3]), sum(sort(TS$den_s + TS$den_o, TRUE)[1:5])))
print(TS[order(-arr_tot)][1:8, .(s, den_s, den_o, arr_s, arr_o, arr_tot)])
print(TS[order(-(den_s + den_o))][1:5, .(s, den_s, den_o, arr_s, arr_o, arr_tot)])

split_one <- function(i, tab, fn) { set.seed(SEME + i); idx <- sample.int(nrow(tab), nrow(tab) %/% 2L); c(fn(tab[idx], tab[-idx]), fn(tab[-idx], tab[idx])) }
rap_dep <- function(st, pr) { T <- tassi(st); p <- T["r_s"] * sum(pr$den_s) + T["r_o"] * sum(pr$den_o); o <- sum(pr$arr_s) + sum(pmin(pr$arr_o, pr$den_o)); unname(p) / max(o, .5) }
setDTthreads(1L)
R <- unlist(parallel::mclapply(1:500, split_one, tab = TS, fn = rap_dep, mc.cores = 60L))
cat("\n== 500 DIVISIONI, stimatore depositato: rapporto previsto/osservato ==\n")
print(round(quantile(R, c(.025, .25, .5, .75, .975)), 2))
cat(sprintf("divisioni con i due rapporti in [0,7; 1,3]: %d su 500\n", sum(sapply(seq(1, 999, 2), function(j) all(R[j:(j+1)] >= .7 & R[j:(j+1)] <= 1.3)))))

# togliendo gli studi piu' grandi: lo stimatore regge? (solo per capire la causa)
senza <- TS[!(s %in% TS[order(-arr_tot)][1:3, s])]
R2 <- unlist(parallel::mclapply(1:500, split_one, tab = senza, fn = rap_dep, mc.cores = 60L))
cat("senza i 3 studi con piu' arrivi:\n"); print(round(quantile(R2, c(.025, .25, .5, .75, .975)), 2))
cat(sprintf("divisioni con i due rapporti in [0,7; 1,3]: %d su 500; tassi: ", sum(sapply(seq(1, 999, 2), function(j) all(R2[j:(j+1)] >= .7 & R2[j:(j+1)] <= 1.3))))); print(round(tassi(senza), 4))
setDTthreads(8L)

cat("\n== IL FATTO SENZA STIMATORE ==\n")
sR <- unique(DR$st$study_id); sA <- unique(DA$st$study_id); entS <- setdiff(sA, sR)
dec <- merge(poolati[s %in% entS], PR[, .(s, ck)][, aveva := TRUE], by = c("s", "ck"), all.x = TRUE)
solo_nuove <- dec[, .(nuove = all(is.na(aveva))), by = s][nuove == TRUE, s]
n_non <- length(setdiff(A3, sR))
ci <- binom.test(length(solo_nuove), n_non)$conf.int
cat(sprintf("studi di A3 non poolati prima %d; entrati con sole chiavi nuove %d = %.2f%% [%.2f; %.2f]\n", n_non, length(solo_nuove), 100 * length(solo_nuove) / n_non, 100 * ci[1], 100 * ci[2]))
print(solo_nuove)
# gli studi usciti da A3: una verifica sul verso dello stesso meccanismo
print(PR[s %in% solo_nuove, .(chiavi_prima = uniqueN(ck), k_max = max(k)), by = s])
