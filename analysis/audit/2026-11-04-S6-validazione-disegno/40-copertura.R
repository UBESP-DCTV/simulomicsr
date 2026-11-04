#!/usr/bin/env Rscript
# Il soffitto sulle 194: classi per identificativo e nome, aggancio a LINCS (composti e ligandi),
# misurabilita' dalla sola fonte, altre fonti. Nessun dato Level 5, nessuna stima del deliverable.
source("analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R")
library(arrow)
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
i40 <- fread(file.path(S5, "80-insieme-40.csv")); i172 <- fread(file.path(S5, "80-insieme-172.csv"))
d[, insieme := fcase(cluster_id %in% i40$cluster_id, "40", cluster_id %in% i172$cluster_id, "132", default = "fuori")]
d[, prefisso := sub(":.*", "", contrast_entity)]
# ---- classi. La colonna kind_effective_resolved non basta (TGFB1 small_molecule, IL6 genetic_knockout,
# g007_lk disease_vs_normal): la classe viene dall'identificativo e, per gli STR, da un elenco scritto
# a mano qui sotto, che va letto come tale.
str_mol <- c("STR:r5020","STR:atra","STR:nutlin_3a","STR:nahs","STR:1_25_oh_2d3","STR:ykl_5_124","STR:5_aza","STR:g007_lk","STR:vtp50469")
str_amb <- c("STR:hypoxia","STR:irradiation","STR:radiation","STR:pm2_5")
str_pat <- c("STR:covid_19","STR:tb_positive")
bio <- c("CHEBI:16412","CHEBI:84491","CHEBI:231601","CHEMBL:CHEMBL1201576","CHEMBL:CHEMBL1201577")
d[, classe := fcase(
  contrast_entity %in% bio, "biologico o aggregato",
  prefisso %in% c("CHEBI","CHEMBL") | contrast_entity %in% c(str_mol, "COMBO:ionomycin+pma"), "piccola molecola",
  prefisso == "HGNC" | contrast_entity == "STR:ifna", "ligando",
  prefisso == "NCBITaxon" | contrast_entity %in% str_pat, "patogeno",
  contrast_entity == "MeSH:D000074285" | contrast_entity %in% str_amb, "ambientale",
  contrast_entity %in% c("COMBO:taz+yap","STR:sirna_pool_against_igf2bp1"), "genetica",
  prefisso == "MeSH" | prefisso == "STR", "malattia",
  default = NA_character_)]
stopifnot(!anyNA(d$classe), nrow(d) == 194L)
cat("CLASSI\n"); print(addmargins(table(d$classe, d$insieme)))
cat("\nkind_effective_resolved contro classe (l'handout usa kind):\n"); print(table(d$kind_effective_resolved, d$classe))
# ---- composti
a <- readRDS(file.path(OUT6, "10-aggancio.rds")); r <- a$r; ci_u <- a$ci_u
# elenco a mano degli STR con una molecola. '5_aza' e' ambiguo (azacitidina o decitabina) e resta fuori.
cerca <- function(x) unique(ci_u[tolower(cmap_name) %in% x | tolower(compound_aliases) %in% x]$pert_id)
manu <- list("STR:r5020" = c("promegestone","r5020","r-5020"), "STR:atra" = c("tretinoin"), "STR:nutlin_3a" = c("nutlin-3"),
  "STR:nahs" = c("sodium-hydrosulfide"), "STR:1_25_oh_2d3" = c("calcitriol"), "STR:ykl_5_124" = c("ykl-5-124"),
  "STR:g007_lk" = c("g007-lk","g-007-lk"), "STR:vtp50469" = c("vtp-50469","vtp50469"))
rm <- rbindlist(lapply(names(manu), function(e) { p <- cerca(manu[[e]]); data.table(contrast_entity = e, metodo_match = if (length(p)) "nome_elenco_a_mano" else "nessuno", n_inchikey = NA_integer_, pert_id = paste(p, collapse = ";"), nome_risolto = manu[[e]][1], nuova_rispetto_al_v15 = NA) }))
ra <- rbind(r, rm)
fwrite(ra, file.path(OUT6, "40-aggancio-con-elenco.csv"))
si <- readRDS(file.path(PES6, "si.rds"))
misura <- function(x) x[, .(firme = .N, linee = uniqueN(cell_iname), exemplar = sum(is_exemplar_sig == "1"),
    attive = sum(is_exemplar_sig == "1" & tas >= 0.2, na.rm = TRUE), linee_attive = uniqueN(cell_iname[is_exemplar_sig == "1" & tas >= 0.2 & !is.na(tas)]),
    tas_mediana = median(tas[is_exemplar_sig == "1"], na.rm = TRUE), richiamo_mediano = median(median_recall_rank_spearman[is_exemplar_sig == "1"], na.rm = TRUE))]
cp <- si[pert_type == "trt_cp"]
ma <- rbindlist(lapply(seq_len(nrow(ra)), function(i) { p <- strsplit(ra$pert_id[i], ";", fixed = TRUE)[[1]]; cbind(ra[i, .(contrast_entity, metodo_match)], misura(cp[pert_id %in% p])) }))
# ---- ligandi: simbolo risolto dall'identificativo; contro trt_lig per nome esatto
hl <- readRDS("~/.cache/R/simulomicsr/hgnc-lookup.rds"); hid <- as.data.table(hl$by_hgnc_int)
lig <- si[pert_type == "trt_lig"]
cat("\nnomi trt_lig che contengono LPS, poly, TGF, IL1, IFN:", grep("^(LPS|POLY|TGF|IL1|IFN)", toupper(unique(lig$cmap_name)), value = TRUE), "\n")
hg <- d[classe == "ligando", .(contrast_entity)]
hg[, simbolo := hid$symbol[match(suppressWarnings(as.integer(sub("^HGNC:", "", contrast_entity))), hid$hgnc_int)]]
hg[contrast_entity == "STR:ifna", simbolo := "IFNA"]
ml <- rbindlist(lapply(seq_len(nrow(hg)), function(i) cbind(hg[i, .(contrast_entity, metodo_match = fifelse(toupper(simbolo) %in% toupper(lig$cmap_name), "simbolo_esatto_trt_lig", "nessuno"))], misura(lig[toupper(cmap_name) == toupper(hg$simbolo[i])]))))
cop <- rbind(ma, ml)
cop <- merge(d[, .(cluster_id, contrast_entity, nome = contrast_entity_label, classe, insieme, k = k_effective)], cop, by = "contrast_entity", all.x = TRUE)
cop[is.na(metodo_match), metodo_match := "fuori perimetro"]
for (v in c("firme","linee","exemplar","attive","linee_attive")) set(cop, which(is.na(cop[[v]])), v, 0L)
cop[, ha_firme := firme > 0L]
cop[, misurabile := linee_attive >= 3L]           # almeno 3 linee con una firma exemplar attiva (TAS >= 0,2)
cat("\nAGGANCIO, per classe e insieme: con almeno una firma / misurabile\n")
print(cop[, .(meta = .N, con_firme = sum(ha_firme), misurabili = sum(misurabile)), keyby = .(classe, insieme)])
cat("\nTOTALI\n"); print(cop[, .(meta = .N, con_firme = sum(ha_firme), misurabili = sum(misurabile)), keyby = .(insieme)])
cat(sprintf("\nP1 composti con firma, 194: %d\nP2 composti con firma, 40: %d\nP5 composti con firma che sono misurabili: %d su %d (%.1f%%)\nP6 ligandi con firma: %d\n",
  cop[classe == "piccola molecola", sum(ha_firme)], cop[classe == "piccola molecola" & insieme == "40", sum(ha_firme)],
  cop[classe == "piccola molecola" & ha_firme, sum(misurabile)], cop[classe == "piccola molecola", sum(ha_firme)], 100 * cop[classe == "piccola molecola" & ha_firme, mean(misurabile)], cop[classe == "ligando", sum(ha_firme)]))
fwrite(cop[order(insieme, classe, -k)], file.path(OUT6, "40-copertura-194.csv"))
options(width = 180)
print(as.data.frame(cop[insieme == "40"][order(classe, -k), .(nome = substr(nome, 1, 30), classe, k, metodo_match, firme, linee, exemplar, attive, linee_attive, tas = round(tas_mediana, 3))]), right = FALSE)
cat("\nfondo: composti trt_cp misurabili con lo stesso criterio\n")
sf <- cp[, .(linee_attive = uniqueN(cell_iname[is_exemplar_sig == "1" & tas >= 0.2 & !is.na(tas)])), by = pert_id]; cat(sf[linee_attive >= 3, .N], "su", nrow(sf), "\n")
sl <- lig[, .(linee_attive = uniqueN(cell_iname[is_exemplar_sig == "1" & tas >= 0.2 & !is.na(tas)])), by = cmap_name]; cat("ligandi misurabili:", sl[linee_attive >= 3, .N], "su", nrow(sl), "\n")
# ---- asse dei geni: identificativi soltanto, nessun valore
gi <- fread(file.path(LIN, "geneinfo_beta.txt"), sep = "\t", quote = "", colClasses = "character")
land <- gi[feature_space == "landmark"]; cat("\nlandmark:", nrow(land), "\n")
g <- as.data.table(read_parquet(file.path(POOL, "cluster_pooled.parquet"), col_select = c("cluster_id", "gene_id")))
g[, id := sub("[.].*", "", gene_id)]
cat("geni nel deliverable:", uniqueN(g$id), "; landmark con ensembl nel deliverable:", length(intersect(land$ensembl_id, g$id)), "\n")
pg <- g[id %in% land$ensembl_id, .(landmark = uniqueN(id)), by = cluster_id]; pg <- merge(pg, cop[, .(cluster_id, insieme)], by = "cluster_id")
print(pg[, .(gruppi = .N, min = min(landmark), mediana = as.numeric(median(landmark)), max = max(landmark)), keyby = insieme])
fwrite(pg, file.path(OUT6, "40-landmark-per-gruppo.csv"))
