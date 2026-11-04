#!/usr/bin/env Rscript
# S8b: quanti studi arrivano e che cosa si muove. Attese: 00-previsioni.md.
suppressPackageStartupMessages({ library(arrow); library(data.table) })
DIR <- "analysis/audit/2026-11-04-S8b-prova"
S3A <- "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159"; S3P <- readLines(file.path(DIR, "stadio3-prova.txt"))
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
NUOVI <- readLines(file.path(DIR, "campione-nuovi.txt")); A3 <- readLines("analysis/audit/2026-08-16-A3/A3-studi.txt"); SCALA <- 21828 / length(NUOVI)
sink(file.path(DIR, "70-out.txt"), split = TRUE)
coppie <- function(d) {
  cl <- as.data.table(readRDS(file.path(d, "clusters.rds")))[mode == "cgroup", .(cluster_id, e = contrast_entity, v = contrast_direction, c = contrast_control_key)]
  a <- as.data.table(read_parquet(file.path(d, "assignments.parquet"), col_select = c("record_id", "cluster_id", "mode")))[mode == "cgroup"]
  a[, s := sub("__.*$", "", record_id)]
  x <- unique(merge(a[, .(s, cluster_id)], cl, by = "cluster_id")); x[, k := uniqueN(s), by = cluster_id]; x[, ck := paste(e, v, c, sep = "||")]; x
}
PA <- coppie(S3A); PP <- coppie(S3P)
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds"))); d[, ck := paste(contrast_entity, contrast_direction, contrast_control_key, sep = "||")]
i41 <- fread("analysis/audit/2026-11-03-S5-gate-e-insiemi/50-insieme-41.csv"); i40 <- fread("analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv")
ck41 <- d[cluster_id %in% i41$cluster_id, ck]; ck40 <- d[cluster_id %in% i40$cluster_id, ck]
cic <- function(x, n) { ic <- if (n > 0) binom.test(x, n)$conf.int else c(NA, NA); sprintf("%d su %d = %.2f%% [%.2f; %.2f]", x, n, 100 * x / n, 100 * ic[1], 100 * ic[2]) }
scala <- function(x, n) { ic <- binom.test(x, n)$conf.int; sprintf("%.0f [%.0f; %.0f]", 21828 * x / n, 21828 * ic[1], 21828 * ic[2]) }
cat(sprintf("Stadio 3 della prova: %s\ncluster cgroup: agosto %d, prova %d\n", S3P, uniqueN(PA$cluster_id), uniqueN(PP$cluster_id)))

cat("\n== Q3: GLI ARRIVI ==\n")
arr <- PP[s %in% NUOVI & ck %in% d$ck]
nA <- uniqueN(arr$s)
cat(sprintf("arrivi fra gli studi nuovi del campione: %s\nscalati su 21.828: %s\n", cic(nA, length(NUOVI)), scala(nA, length(NUOVI))))
cat(sprintf("copertura: chiavi del deliverable nel calcolo %d su %d\n", uniqueN(d$ck), nrow(d)))
print(arr[, .(s, e, v, c, k)][order(e)])
tocc <- unique(arr$ck)
cat(sprintf("meta-analisi toccate nel campione: %d su 194; fra le 41: %d; fra le 40: %d\n", length(tocc), sum(tocc %in% ck41), sum(tocc %in% ck40)))
# Se ogni arrivo vale una volta, in tutto il corpus una meta-analisi con a arrivi nel campione ne riceve a*SCALA.
cat(sprintf("meta-analisi con almeno un arrivo atteso nel corpus, somma 1-exp(-a*scala): %.1f su 194\n", sum(1 - exp(-table(arr$ck) * SCALA))))

cat("\n== Q4: LA RISERVA ==\n")
senza <- setdiff(NUOVI, PA$s); con <- intersect(NUOVI, PA$s)
ott <- intersect(senza, PP$s); per <- setdiff(con, PP$s)
cat(sprintf("studi del campione senza coppie in agosto: %d; ne ottengono una: %s\nstudi del campione con coppie in agosto: %d; le perdono tutte: %s\n", length(senza), cic(length(ott), length(senza)), length(con), cic(length(per), length(con))))
cn <- PA[s %in% con, .(s, ck)]; pn <- PP[s %in% con, .(s, ck)]
ug <- merge(cn[, .(a = paste(sort(unique(ck)), collapse = "|")), by = s], pn[, .(p = paste(sort(unique(ck)), collapse = "|")), by = s], by = "s", all = TRUE)
cat(sprintf("studi del campione con coppie in agosto: stesse chiavi: %s\n", cic(sum(ug$a == ug$p, na.rm = TRUE), length(con))))
# gli arrivi senza coppie prima: la riserva arriva davvero alle meta-analisi?
cat(sprintf("arrivi da studi senza coppie in agosto: %d; da studi con coppie: %d\n", length(intersect(unique(arr$s), senza)), length(intersect(unique(arr$s), con))))

cat("\n== GRUPPI NUOVI ==\n")
eDel <- unique(d$contrast_entity)
k3a <- unique(PA[k >= 3, ck]); k3p <- unique(PP[k >= 3, .(ck, e, k)])
nuovi3 <- k3p[!(ck %in% k3a)]
cat(sprintf("gruppi a k>=3 nuovi rispetto ad agosto: %d, con entita' senza meta-analisi: %d\n", nrow(nuovi3), nrow(nuovi3[!(e %in% eDel)])))
print(nuovi3[order(-k)][1:min(30, .N)])

cat("\n== Q5: GLI STUDI NON RIGENERATI ==\n")
fermi <- setdiff(unique(c(PA$s, PP$s)), NUOVI)
a <- PA[s %in% fermi, .(a = paste(sort(unique(ck)), collapse = "|")), by = s]; p <- PP[s %in% fermi, .(p = paste(sort(unique(ck)), collapse = "|")), by = s]
m <- merge(a, p, by = "s", all = TRUE); m[, diverso := is.na(a) | is.na(p) | a != p]
cat(sprintf("studi non rigenerati con chiavi cambiate: %s\n", cic(sum(m$diverso), nrow(m))))
cat(sprintf("  dentro i 2.566: %d; fuori: %d\n", sum(m$diverso & m$s %in% A3), sum(m$diverso & !m$s %in% A3)))
print(m[diverso == TRUE][1:min(20, .N), .(s, a = substr(a, 1, 70), p = substr(p, 1, 70))])
# meta-analisi del deliverable con composizione cambiata, per qualunque causa, nello Stadio 3
ca <- PA[ck %in% d$ck, .(sa = paste(sort(unique(s)), collapse = "|")), by = ck]; cp <- PP[ck %in% d$ck, .(sp = paste(sort(unique(s)), collapse = "|")), by = ck]
mm <- merge(ca, cp, by = "ck", all = TRUE); mm[, cambia := is.na(sa) | is.na(sp) | sa != sp]
cat(sprintf("meta-analisi con membri diversi nello Stadio 3: %d su %d\n", sum(mm$cambia), nrow(mm)))
sink()
