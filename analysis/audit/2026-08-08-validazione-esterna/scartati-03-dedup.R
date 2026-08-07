# Ricostruisce l'insieme dei cluster tolti dalla DEDUP per entita' (che il run
# NON persiste: attr "scartati" e' locale a .identify_layer_a_clusters).
# Sono l'unica popolazione che puo' avere entita'+direzione IDENTICHE a una
# delle 214, perche' la dedup gira PRIMA del gate k_eff.
# Replay read-only del filtro con la config vera del run.
suppressPackageStartupMessages({library(arrow); library(dplyr)})

`%||%` <- function(a, b) if (is.null(a)) b else a
S4  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3  <- "/home/user/simulomicsr/analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
OUT <- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"

cl  <- as.data.frame(readRDS(file.path(S3, "clusters.rds")))
np  <- as.data.frame(readRDS(file.path(S4, "non_processable.rds")))
del <- as.data.frame(readRDS(file.path(S4, "deliverable-annotato.rds")))
psd <- arrow::open_dataset(file.path(S4, "per_study_de.parquet"))
asg <- arrow::open_dataset(file.path(S3, "assignments.parquet"))

EXCL <- c("vehicle_only", "none", "")
KMIN <- 3L
cand <- cl[cl$mode == "cgroup" &
           !cl$usable_mega_strict &
           !(cl$kind_effective_resolved %in% EXCL) &
           !is.na(cl$agent_id_resolved) & nzchar(cl$agent_id_resolved) &
           cl$k >= KMIN, ]
cat("=== REPLAY DEL FILTRO PRE-DEDUP ===\n")
cat("candidati cgroup pre-dedup:", nrow(cand), "\n")

dirv <- cand$contrast_direction; dirv[is.na(dirv)] <- ""
ce   <- cand$contrast_entity
entk <- ifelse(!is.na(ce) & nzchar(ce), paste0(ce,"||",dirv),
               paste0(cand$kind_effective_resolved,"||",cand$agent_id_resolved,"||",dirv))
ord  <- order(entk, -cand$k, -cand$n_total, -cand$level, cand$cluster_id)
rg <- cand[ord,]; ek <- entk[ord]; keep <- !duplicated(ek)
vinc <- rg[keep,];  vinc$entk <- ek[keep]
pers <- rg[!keep,]; pers$entk <- ek[!keep]
pers$assorbito_da <- vinc$cluster_id[match(pers$entk, vinc$entk)]

cat("vincitori post-dedup:", nrow(vinc), " (atteso 214+137 = 351)\n")
cat("scartati dalla dedup :", nrow(pers), "\n")
cat("verifica vincitori == deliverable + non_processable:",
    setequal(vinc$cluster_id, c(del$cluster_id, np$cluster_id)), "\n")

## chi assorbe: una delle 214 (poolata) o uno dei 137 (a sua volta scartato)?
pers$assorbito_e_poolato <- pers$assorbito_da %in% del$cluster_id
cat("\n=== LIVELLO (a) VERO: dedup-scartati assorbiti da una delle 214 ===\n")
cat("gruppi:", sum(pers$assorbito_e_poolato),
    " | assorbiti da uno dei 137 a loro volta scartati:",
    sum(!pers$assorbito_e_poolato), "\n")
pa <- pers[pers$assorbito_e_poolato, ]
cat("meta-analisi delle 214 toccate:", length(unique(pa$assorbito_da)), "/214\n")
cat("entita' distinte:", length(unique(pa$contrast_entity)), "\n")
cat("k stage3 (pre-QC) sommato:", sum(pa$k), " mediana:", median(pa$k), "\n")

## Questi cluster NON hanno per_study_de (mai entrati nell'eligible set):
n_psd <- psd |> filter(cluster_id %in% pa$cluster_id) |> select(cluster_id) |>
  distinct() |> collect() |> nrow()
cat("quanti hanno righe in per_study_de:", n_psd,
    "-> il controllo interno NON e' mai stato valutato per loro\n")

## GSE dei membri (PRE-QC: e' tutto cio' che esiste per questi)
a <- asg |> filter(cluster_id %in% pa$cluster_id) |> select(cluster_id, record_id) |>
  collect() |> as.data.frame()
a$gse <- sub("__.*$", "", a$record_id)
a <- distinct(a[, c("cluster_id","gse")])
a <- merge(a, pa[, c("cluster_id","assorbito_da","contrast_entity",
                     "contrast_direction","contrast_control_key","k")], by="cluster_id")

pool_psd <- psd |> filter(cluster_id %in% del$cluster_id) |>
  select(cluster_id, study_id) |> distinct() |> collect() |> as.data.frame()
gse_pool_all <- unique(pool_psd$study_id)
gse_cens_all <- unique(unlist(del$studies_in_cluster))
pool_by <- split(pool_psd$study_id, pool_psd$cluster_id)
cens_by <- setNames(del$studies_in_cluster, del$cluster_id)

a$gia_nel_pool_stesso <- mapply(function(g,t) g %in% (pool_by[[t]] %||% character(0)),
                                a$gse, a$assorbito_da)
a$gia_censito_stesso  <- mapply(function(g,t) g %in% (cens_by[[t]] %||% character(0)),
                                a$gse, a$assorbito_da)
a$in_qualche_pool <- a$gse %in% gse_pool_all
a$in_qualche_cens <- a$gse %in% gse_cens_all

cat("\n=== INDIPENDENZA DEI MEMBRI (PRE-QC) DEI DEDUP-SCARTATI DI LIVELLO (a) ===\n")
cat("coppie (cluster,GSE):", nrow(a), " GSE distinti:", length(unique(a$gse)), "\n")
cat("  gia' POOLATI nella stessa meta-analisi (circolari):", sum(a$gia_nel_pool_stesso),
    "coppie /", length(unique(a$gse[a$gia_nel_pool_stesso])), "GSE\n")
cat("  gia' CENSITI nella stessa meta-analisi:", sum(a$gia_censito_stesso),
    "coppie /", length(unique(a$gse[a$gia_censito_stesso])), "GSE\n")
cat("  poolati in QUALUNQUE delle 214:", sum(a$in_qualche_pool),
    "coppie /", length(unique(a$gse[a$in_qualche_pool])), "GSE\n")
cat("  in NESSUN pool delle 214 (indipendenti):", sum(!a$in_qualche_pool),
    "coppie /", length(unique(a$gse[!a$in_qualche_pool])), "GSE\n")
cat("  in nessun pool ne' censimento:", sum(!a$in_qualche_pool & !a$in_qualche_cens),
    "coppie /", length(unique(a$gse[!a$in_qualche_pool & !a$in_qualche_cens])), "GSE\n")
ii <- a[!a$in_qualche_pool, ]
cat("  entita' distinte coperte:", length(unique(ii$contrast_entity)),
    " meta-analisi delle 214 raggiunte:", length(unique(ii$assorbito_da)), "\n")

## tabelle
ind_by <- ii |> group_by(cluster_id) |>
  summarise(n_gse_indip = n_distinct(gse),
            gse_indip = paste(sort(unique(gse)), collapse=";"), .groups="drop")
tot_by <- a |> group_by(cluster_id) |>
  summarise(n_gse_membri = n_distinct(gse),
            n_gse_circolari = sum(gia_nel_pool_stesso), .groups="drop")
tab <- pa[, c("cluster_id","assorbito_da","contrast_entity","contrast_direction",
              "contrast_control_key","canonical_name","k","n_total","anchor_key")] |>
  left_join(tot_by, by="cluster_id") |> left_join(ind_by, by="cluster_id")
tab$n_gse_indip[is.na(tab$n_gse_indip)] <- 0L
tab <- tab[order(-tab$n_gse_indip, -tab$k), ]
write.csv(tab, file.path(OUT,"scartati-dedup-livello-a.csv"), row.names=FALSE)

pe <- tab |> group_by(contrast_entity, contrast_direction) |>
  summarise(n_gruppi_dedup = n(), gse_membri = sum(n_gse_membri),
            gse_indipendenti = sum(n_gse_indip),
            meta214 = paste(sort(unique(assorbito_da)), collapse=";"),
            nome = paste(sort(unique(canonical_name)), collapse=" | "), .groups="drop")
pe <- pe |> left_join(del[,c("cluster_id","k_effective","n_sig","contrast_entity_label")],
                      by=c("meta214"="cluster_id"))
pe <- pe[order(-pe$gse_indipendenti, -pe$gse_membri), ]
write.csv(pe, file.path(OUT,"scartati-dedup-per-entita.csv"), row.names=FALSE)
cat("\n=== TOP 20 per GSE indipendenti ===\n")
print(as.data.frame(head(pe, 20)))
cat("\nCSV scritti.\n")
