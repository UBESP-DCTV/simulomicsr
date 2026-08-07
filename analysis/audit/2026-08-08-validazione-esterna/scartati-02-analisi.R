# Scout di copertura: i 137 gruppi candidati scartati dal gate dello Stadio 4.
# Sola lettura. Conta, non giudica.
suppressPackageStartupMessages({library(arrow); library(dplyr)})
`%||%` <- function(a, b) if (is.null(a)) b else a

S4  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3  <- "/home/user/simulomicsr/analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
OUT <- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"

np  <- as.data.frame(readRDS(file.path(S4, "non_processable.rds")))
del <- as.data.frame(readRDS(file.path(S4, "deliverable-annotato.rds")))
cl  <- as.data.frame(readRDS(file.path(S3, "clusters.rds")))
psd <- arrow::open_dataset(file.path(S4, "per_study_de.parquet"))
asg <- arrow::open_dataset(file.path(S3, "assignments.parquet"))

cat("=== 0. INPUT ===\n")
cat("scartati:", nrow(np), " deliverable:", nrow(del), " clusters stage3:", nrow(cl), "\n")
stopifnot(nrow(np) == 137L, nrow(del) == 214L)
stopifnot(all(grepl("^rem_group_insufficient_in_study_controls", np$reason)))

## ---- 1. ENTITA' DEI 137 SCARTATI -------------------------------------------
key_cols <- c("cluster_id","mode","level","anchor_key","k","n_studies",
              "studies_in_cluster","contrast_entity","contrast_direction",
              "contrast_control_key","contrast_entity_source","canonical_name")
sc <- merge(np, cl[, key_cols], by = "cluster_id", all.x = TRUE)
cat("\n=== 1. AGGANCIO ALLO STADIO 3 ===\n")
cat("agganciati:", sum(!is.na(sc$anchor_key)), "/", nrow(sc), "\n")
cat("NON agganciati (dichiarati):",
    paste(sc$cluster_id[is.na(sc$anchor_key)], collapse=", "), "\n")
cat("contrast_entity NA fra gli agganciati:", sum(is.na(sc$contrast_entity)), "\n")
cat("mode:\n"); print(table(sc$mode, useNA="ifany"))
cat("direction:\n"); print(table(sc$contrast_direction, useNA="ifany"))
cat("entita' distinte fra i 137:", length(unique(sc$contrast_entity)), "\n")

## ---- 2. STUDI CHE HANNO SUPERATO IL GATE (da per_study_de) ------------------
# Il DE per-studio (Step 5 di build_stage4_results) gira PRIMA del gate k_eff
# (Step 6): per_study_de contiene percio' le righe dei cluster poi scartati, e
# i suoi study_id sono ESATTAMENTE gli studi entrati nel dispatch, cioe' quelli
# con controllo interno risolto. Verifica di identita' sotto.
sc_psd <- psd |> filter(cluster_id %in% np$cluster_id) |>
  select(cluster_id, study_id) |> distinct() |> collect() |> as.data.frame()
chk <- merge(np[, c("cluster_id","qc_final_k")],
             count(sc_psd, cluster_id, name = "k_psd"), by = "cluster_id", all.x = TRUE)
chk$k_psd[is.na(chk$k_psd)] <- 0L
cat("\n=== 2. IDENTITA' DEGLI STUDI SOPRAVVISSUTI AL GATE ===\n")
cat("accordo qc_final_k == n studi in per_study_de:",
    sum(chk$qc_final_k == chk$k_psd), "/", nrow(chk), "\n")
cat("studi-slot totali (coppie cluster-studio):", nrow(sc_psd),
    " somma qc_final_k:", sum(np$qc_final_k), "\n")
cat("GSE distinti fra gli studi sopravvissuti:", length(unique(sc_psd$study_id)), "\n")

# membri PRE-QC dallo Stadio 3 (per confronto dichiarato)
sc_asg <- asg |> filter(cluster_id %in% np$cluster_id) |>
  select(cluster_id, record_id) |> collect() |> as.data.frame()
sc_asg$gse <- sub("__.*$", "", sc_asg$record_id)
pre <- distinct(sc_asg[, c("cluster_id","gse")])
cat("membri PRE-QC (coppie cluster-GSE, stage3):", nrow(pre),
    " GSE distinti:", length(unique(pre$gse)), "\n")

## ---- 3. SOVRAPPOSIZIONE CON LE 214 -----------------------------------------
del$ent_dir <- paste(del$contrast_entity, del$contrast_direction, sep="||")
del$ent_dir_ctl <- paste(del$contrast_entity, del$contrast_direction,
                         del$contrast_control_key, sep="||")
sc$ent_dir <- paste(sc$contrast_entity, sc$contrast_direction, sep="||")
sc$ent_dir_ctl <- paste(sc$contrast_entity, sc$contrast_direction,
                        sc$contrast_control_key, sep="||")

# livelli, sui GRUPPI SCARTATI
sc$liv <- ifelse(sc$ent_dir_ctl %in% del$ent_dir_ctl, "a_identico",
          ifelse(sc$ent_dir     %in% del$ent_dir,     "a_ent_dir",
          ifelse(sc$contrast_entity %in% del$contrast_entity, "b_solo_entita",
                 "c_assente")))
cat("\n=== 3. SOVRAPPOSIZIONE (vista sui 137 gruppi scartati) ===\n")
tb <- sc |> group_by(liv) |>
  summarise(n_gruppi = n(), studi_slot = sum(qc_final_k),
            entita_distinte = n_distinct(contrast_entity), .groups="drop")
print(as.data.frame(tb))

# livelli, sulle 214 META-ANALISI (quante ne beneficiano)
del$liv_a_strict <- del$ent_dir_ctl %in% sc$ent_dir_ctl
del$liv_a        <- del$ent_dir     %in% sc$ent_dir
del$liv_b        <- del$contrast_entity %in% sc$contrast_entity
cat("\n(vista sulle 214 meta-analisi)\n")
cat("(a-strict) 214 con >=1 scartato a entita'+direzione+controllo identici:",
    sum(del$liv_a_strict), "\n")
cat("(a)        214 con >=1 scartato a stessa entita' E stessa direzione:",
    sum(del$liv_a), "\n")
cat("(b)        214 con >=1 scartato a stessa entita' (dir/controllo qualunque):",
    sum(del$liv_b), "\n")
cat("(b-solo)   214 agganciate solo per entita', non per entita'+direzione:",
    sum(del$liv_b & !del$liv_a), "\n")
cat("(c)        entita' dei 137 assenti dalle 214:",
    length(setdiff(sc$contrast_entity, del$contrast_entity)),
    "su", length(unique(sc$contrast_entity)), "entita' distinte scartate\n")

# studi-slot per livello, aggregati (a >= a-strict; b esclude a)
ss <- function(f) sum(sc$qc_final_k[f])
cat("\nstudi-slot (somma qc_final_k) per livello, sui gruppi scartati:\n")
cat("  a-strict (ent+dir+ctl identici):", ss(sc$ent_dir_ctl %in% del$ent_dir_ctl), "\n")
cat("  a        (ent+dir identici)    :", ss(sc$ent_dir %in% del$ent_dir), "\n")
cat("  b-solo   (solo entita')        :", ss(!(sc$ent_dir %in% del$ent_dir) &
                                              sc$contrast_entity %in% del$contrast_entity), "\n")
cat("  c        (entita' assente)     :", ss(!(sc$contrast_entity %in% del$contrast_entity)), "\n")

## ---- 4. SONO STUDI MAI VISTI? ----------------------------------------------
# universo A: studi effettivamente POOLATI nelle 214 (da per_study_de)
pool_psd <- psd |> filter(cluster_id %in% del$cluster_id) |>
  select(cluster_id, study_id) |> distinct() |> collect() |> as.data.frame()
gse_poolati_tutti <- unique(pool_psd$study_id)
# universo B: censimento stage3 delle 214 (studies_in_cluster, superset pre-QC)
gse_censiti_tutti <- unique(unlist(del$studies_in_cluster))
cat("\n=== 4. INDIPENDENZA DEGLI STUDI ===\n")
cat("GSE poolati in almeno una delle 214 (per_study_de):", length(gse_poolati_tutti), "\n")
cat("GSE censiti in almeno una delle 214 (studies_in_cluster, pre-QC):",
    length(gse_censiti_tutti), "\n")

# mappa cluster scartato -> meta-analisi agganciate (livello a: ent+dir)
del_by_ed  <- split(del$cluster_id, del$ent_dir)
pool_by_cl <- split(pool_psd$study_id, pool_psd$cluster_id)
cens_by_cl <- setNames(del$studies_in_cluster, del$cluster_id)

sc_psd <- merge(sc_psd, sc[, c("cluster_id","ent_dir","contrast_entity","liv")],
                by = "cluster_id", all.x = TRUE)
sc_psd$stesso_pool <- FALSE   # GSE gia' nel pool della/e meta-analisi agganciata/e
sc_psd$stesso_cens <- FALSE   # GSE gia' nel censimento stage3 della/e agganciata/e
for (i in seq_len(nrow(sc_psd))) {
  tg <- del_by_ed[[ sc_psd$ent_dir[i] ]]
  if (is.null(tg)) next
  sc_psd$stesso_pool[i] <- sc_psd$study_id[i] %in% unlist(pool_by_cl[tg])
  sc_psd$stesso_cens[i] <- sc_psd$study_id[i] %in% unlist(cens_by_cl[tg])
}
sc_psd$altrove_pool <- sc_psd$study_id %in% gse_poolati_tutti
sc_psd$altrove_cens <- sc_psd$study_id %in% gse_censiti_tutti

agg <- sc_psd[sc_psd$liv %in% c("a_identico","a_ent_dir"), ]
cat("\n-- studi-slot dei gruppi scartati che agganciano un'entita'+direzione delle 214 --\n")
cat("totale studi-slot agganciati:", nrow(agg), " GSE distinti:",
    length(unique(agg$study_id)), "\n")
cat("  gia' POOLATI nella STESSA meta-analisi (circolari):",
    sum(agg$stesso_pool), "slot /", length(unique(agg$study_id[agg$stesso_pool])), "GSE\n")
cat("  gia' CENSITI nella stessa meta-analisi (pre-QC):",
    sum(agg$stesso_cens), "slot /", length(unique(agg$study_id[agg$stesso_cens])), "GSE\n")
cat("  poolati in QUALUNQUE delle 214 (altra entita'):",
    sum(agg$altrove_pool), "slot /", length(unique(agg$study_id[agg$altrove_pool])), "GSE\n")
cat("  in nessun pool delle 214 (INDIPENDENTI):",
    sum(!agg$altrove_pool), "slot /", length(unique(agg$study_id[!agg$altrove_pool])), "GSE\n")
cat("  in nessun pool NE' censimento delle 214 (indipendenti, criterio severo):",
    sum(!agg$altrove_pool & !agg$altrove_cens), "slot /",
    length(unique(agg$study_id[!agg$altrove_pool & !agg$altrove_cens])), "GSE\n")
ind <- agg[!agg$altrove_pool, ]
cat("  entita' distinte coperte dagli indipendenti:",
    length(unique(ind$contrast_entity)), "\n")
cat("  meta-analisi delle 214 raggiunte dagli indipendenti:",
    length(unique(unlist(del_by_ed[unique(ind$ent_dir)]))), "\n")

cat("\n-- stesso conteggio su TUTTI e 206 gli studi-slot scartati (qualunque livello) --\n")
cat("  poolati in qualunque delle 214:", sum(sc_psd$altrove_pool), "slot /",
    length(unique(sc_psd$study_id[sc_psd$altrove_pool])), "GSE\n")
cat("  in nessun pool delle 214:", sum(!sc_psd$altrove_pool), "slot /",
    length(unique(sc_psd$study_id[!sc_psd$altrove_pool])), "GSE\n")
cat("  in nessun pool ne' censimento:", sum(!sc_psd$altrove_pool & !sc_psd$altrove_cens),
    "slot /", length(unique(sc_psd$study_id[!sc_psd$altrove_pool & !sc_psd$altrove_cens])), "GSE\n")

## ---- 5. TABELLE ------------------------------------------------------------
# per-gruppo scartato
gse_ok  <- split(sc_psd$study_id, sc_psd$cluster_id)
gse_ind <- split(sc_psd$study_id[!sc_psd$altrove_pool], sc_psd$cluster_id[!sc_psd$altrove_pool])
pre_by  <- split(pre$gse, pre$cluster_id)
sc$gse_superstiti <- vapply(sc$cluster_id, function(x)
  paste(sort(gse_ok[[x]] %||% character(0)), collapse=";"), character(1))
sc$gse_indipendenti <- vapply(sc$cluster_id, function(x)
  paste(sort(gse_ind[[x]] %||% character(0)), collapse=";"), character(1))
sc$n_gse_indipendenti <- vapply(sc$cluster_id, function(x)
  length(gse_ind[[x]] %||% character(0)), integer(1))
sc$n_membri_preqc <- vapply(sc$cluster_id, function(x)
  length(pre_by[[x]] %||% character(0)), integer(1))
sc$meta214_agganciate <- vapply(sc$ent_dir, function(x)
  paste(del_by_ed[[x]] %||% character(0), collapse=";"), character(1))

tab_gruppi <- sc[, c("cluster_id","liv","qc_final_k","n_membri_preqc",
                     "contrast_entity","contrast_direction","contrast_control_key",
                     "canonical_name","n_gse_indipendenti","gse_superstiti",
                     "gse_indipendenti","meta214_agganciate","anchor_key")]
tab_gruppi <- tab_gruppi[order(tab_gruppi$liv, -tab_gruppi$qc_final_k), ]
write.csv(tab_gruppi, file.path(OUT,"scartati-137-gruppi.csv"), row.names=FALSE)

# per-entita'
ent <- sc |> group_by(contrast_entity) |>
  summarise(n_gruppi_scartati = n(),
            studi_slot = sum(qc_final_k),
            gse_superstiti = n_distinct(unlist(strsplit(paste(gse_superstiti,collapse=";"),";"))),
            direzioni = paste(sort(unique(contrast_direction)), collapse=","),
            controlli  = paste(sort(unique(contrast_control_key)), collapse=","),
            nome = paste(sort(unique(canonical_name)), collapse=" | "),
            livello_max = min(liv), .groups="drop")
ind_by_ent <- ind |> group_by(contrast_entity) |>
  summarise(gse_indipendenti = n_distinct(study_id),
            lista_indipendenti = paste(sort(unique(study_id)), collapse=";"), .groups="drop")
d214 <- del |> group_by(contrast_entity) |>
  summarise(meta214 = n(), k_effective_214 = paste(k_effective, collapse=","),
            n_sig_214 = paste(n_sig, collapse=","), .groups="drop")
ent <- ent |> left_join(ind_by_ent, by="contrast_entity") |>
  left_join(d214, by="contrast_entity")
ent$gse_indipendenti[is.na(ent$gse_indipendenti)] <- 0L
ent$meta214[is.na(ent$meta214)] <- 0L
ent <- ent[order(-ent$studi_slot, -ent$gse_indipendenti), ]
write.csv(ent, file.path(OUT,"scartati-per-entita.csv"), row.names=FALSE)

# studi-slot dettaglio
write.csv(sc_psd[order(sc_psd$liv, sc_psd$cluster_id), ],
          file.path(OUT,"scartati-studi-slot.csv"), row.names=FALSE)

cat("\n=== 5. TOP ENTITA' AGGANCIATE, PER STUDI-SLOT ===\n")
print(as.data.frame(head(ent[ent$meta214>0,
   c("contrast_entity","nome","n_gruppi_scartati","studi_slot",
     "gse_indipendenti","meta214","k_effective_214")], 25)))
cat("\nCSV scritti in", OUT, "\n")
