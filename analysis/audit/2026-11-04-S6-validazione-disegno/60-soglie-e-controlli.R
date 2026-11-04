#!/usr/bin/env Rscript
# Che cosa puo' dire il test con il numero di meta-analisi disponibile, e che cosa regge il disegno.
# Nessun dato Level 5, nessun valore di cluster_pooled.
source("analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R")
cop <- fread(file.path(OUT6, "50-copertura-con-tahoe.csv"))
# ---- 1. soglie: valore minimo di successi perche' il limite inferiore esatto (Clopper-Pearson) superi T
lo <- function(x, n) if (x == 0L) 0 else qbeta(0.025, x, n - x + 1L)
minx <- function(n, T) { for (x in 0:n) if (lo(x, n) > T) return(x); NA_integer_ }
griglia <- CJ(n = c(19L, 53L, 72L), T = c(0.10, 0.17, 0.30))
griglia[, x_min := mapply(minx, n, T)]; griglia[, quota := round(x_min / n, 3)]
for (p in c(0.10, 0.17, 0.25, 0.35, 0.50, 0.70)) griglia[, paste0("pot_", p) := round(pbinom(x_min - 1L, n, p, lower.tail = FALSE), 3)]
cat("POTENZA: probabilita' di passare, se la quota vera e' p\n"); print(as.data.frame(griglia))
fwrite(griglia, file.path(OUT6, "60-soglie-potenza.csv"))
cat("\nmediana del percentile per puro caso, intervallo 95% (quantili della mediana di n uniformi):\n")
set.seed(SEME); for (n in c(19L, 53L, 72L)) { m <- replicate(20000L, median(runif(n))); cat(n, ":", round(quantile(m, c(.025, .975)), 3), "\n") }
# ---- 2. misurabili e verdetti della rilettura (identita' letta prima, senza LINCS)
i <- rbind(fread(file.path(S5, "80-insieme-40.csv"))[, .(cluster_id, verdetto, peso_contaminato)], fread(file.path(S5, "80-insieme-172.csv"))[, .(cluster_id, verdetto, peso_contaminato)])
i <- unique(i, by = "cluster_id")
m <- merge(cop[misurabile == TRUE & classe %in% c("piccola molecola", "ligando")], i, by = "cluster_id", all.x = TRUE)
cat("\nmisurabili per classe, insieme, verdetto\n"); print(m[, .N, keyby = .(classe, insieme, verdetto)])
cat("\nmetodo di aggancio dei misurabili\n"); print(m[, .N, keyby = .(classe, metodo_match)])
# ---- 3. doppioni: la stessa firma per due meta-analisi
a <- readRDS(file.path(OUT6, "10-aggancio.rds")); ra <- a$r
for (e in c("STR:atra", "STR:nutlin_3a", "STR:1_25_oh_2d3", "STR:r5020", "STR:nahs")) cat(e, "misurabile:", cop[contrast_entity == e, misurabile], "\n")
g <- as.data.table(fread(file.path(OUT6, "40-copertura-194.csv")))
cat("coppie note con la stessa molecola: atra / all-trans-retinoic acid; nutlin_3a / Nutlin-3; 1_25_oh_2d3 / calcitriol\n")
# ---- 4. stessa linea cellulare: quanti studi dei misurabili citano una linea con una firma attiva del loro composto
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
st <- d[cluster_id %in% m$cluster_id, .(gse = unlist(studies_in_cluster)), by = cluster_id]
system.time(tx <- fread(cmd = "python3 -c \"
import json,sys
for l in open('analysis/input/archs4-human-stage1-input-v2.jsonl'):
    j=json.loads(l); print(j['series_id'], j['string'].replace('\\t',' ').replace('\\n',' ')[:2000], sep='\\t')
\"", sep = "\t", header = FALSE, col.names = c("gse", "s"), quote = "", fill = TRUE))
tx <- tx[gse %in% st$gse]
tx[, n := gsub("[^A-Z0-9]", "", toupper(s))]
txs <- tx[, .(n = paste(unique(n), collapse = " ")), by = gse]
si <- readRDS(file.path(PES6, "si.rds"))
mp <- merge(m[, .(cluster_id, contrast_entity, classe)], fread(file.path(OUT6, "40-aggancio-con-elenco.csv"))[, .(contrast_entity, pert_id)], by = "contrast_entity", all.x = TRUE)
stopifnot(!anyDuplicated(mp$cluster_id))
linee <- function(p) { if (is.na(p) || !nzchar(p)) return(character()); unique(si[pert_type == "trt_cp" & pert_id %in% strsplit(p, ";", fixed = TRUE)[[1]] & is_exemplar_sig == "1" & tas >= 0.2, cell_iname]) }
ris <- rbindlist(lapply(which(mp$classe == "piccola molecola"), function(i) {
  li <- gsub("[^A-Z0-9]", "", toupper(linee(mp$pert_id[i]))); li <- li[nchar(li) >= 4L | li == "PC3"]
  gs <- st[cluster_id == mp$cluster_id[i], gse]; tt <- txs[gse %in% gs]
  data.table(cluster_id = mp$cluster_id[i], studi = length(gs), studi_stessa_linea = sum(vapply(tt$n, function(s) any(vapply(li, grepl, TRUE, x = s, fixed = TRUE)), TRUE)))
}))
ris <- merge(ris, cop[, .(cluster_id, nome, insieme)], by = "cluster_id")
cat("\nstessa linea (limite superiore: cerco il nome nel testo della serie intera)\n")
print(ris[, .(meta = .N, studi = sum(studi), studi_stessa_linea = sum(studi_stessa_linea), meta_con_almeno_uno = sum(studi_stessa_linea > 0L)), keyby = insieme])
fwrite(ris, file.path(OUT6, "60-stessa-linea.csv"))
# ---- 5. TCGA: gruppi, citazioni, serie che riportano TCGA
tum <- c("MeSH:D006528" = "TCGA-LIHC", "MeSH:D013274" = "TCGA-STAD", "MeSH:D015179" = "TCGA-COAD+READ", "MeSH:D001943" = "TCGA-BRCA", "MeSH:D002292" = "TCGA-KIRC/KIRP/KICH", "STR:oscc" = "TCGA-HNSC")
tg <- cop[contrast_entity %in% names(tum), .(contrast_entity, nome, insieme, k)]; tg[, progetto := tum[contrast_entity]]
print(as.data.frame(tg), right = FALSE)
gse_all <- unique(unlist(d$studies_in_cluster)); cat("GSE62944 nelle 194:", "GSE62944" %in% gse_all, "\n")
gs6 <- d[contrast_entity %in% names(tum), .(gse = unlist(studies_in_cluster)), by = contrast_entity]
tmp <- tempfile(); system(sprintf("grep -E 'TCGA|TARGET-' analysis/input/archs4-human-stage1-input-v2.jsonl > %s", tmp))
x <- rbindlist(lapply(readLines(tmp), function(l) { j <- jsonlite::fromJSON(l); data.table(gse = j$series_id) }))
cat("campioni del bacino che citano TCGA:", nrow(x), "; studi:", uniqueN(x$gse), "; dentro i 6 gruppi:", sum(gs6$gse %in% x$gse), "; dentro le 194:", length(intersect(gse_all, x$gse)), "\n")
print(as.data.frame(gs6[gse %in% x$gse]))
# ---- 6. taglia della lettura Level 5
sg <- si[pert_type == "trt_cp" & is_exemplar_sig == "1" & tas >= 0.2]
fondo <- sg[, .(linee = uniqueN(cell_iname)), by = pert_id][linee >= 3L, pert_id]
cat("\nfirme exemplar attive del fondo:", sg[pert_id %in% fondo, .N], "su", length(fondo), "composti\n")
cat("controllo positivo ascorbico: metodo sul v15 ", as.data.table(readRDS(file.path(OLD, "20-entita-con-firme.rds")))[contrast_entity == "CHEBI:29073", metodo_match], "\n")
