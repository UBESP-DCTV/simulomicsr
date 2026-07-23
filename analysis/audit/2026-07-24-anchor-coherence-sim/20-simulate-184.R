Sys.setenv(OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1")
suppressPackageStartupMessages({library(arrow); library(dplyr)})
devtools::load_all(".", quiet=TRUE)  # per .normalize_control_type
source("analysis/audit/2026-07-24-anchor-coherence-sim/contrast-sig-engine.R")
DIR <- "analysis/audit/2026-07-23-coherence"
pm <- read_parquet(file.path(DIR,"per-member-contrasts.parquet"))
cv <- readRDS(file.path(DIR,"cluster-verdicts.rds"))

d184 <- cv[!is.na(cv$dd_verdict), c("cluster_id","kind","k","canonical_name",
             "n_resolved","contrast_verdict","consistency_score")]
ids <- d184$cluster_id
sub <- pm[pm$cluster_id %in% ids,]

# firma per membro
mc <- lapply(seq_len(nrow(sub)), function(i) .member_contrast(sub$treated_fl[i], sub$control_fl[i]))
sub$ct       <- vapply(seq_len(nrow(sub)), function(i) .normalize_control_type(sub$control_label[i]), "")
sub$dominant <- vapply(mc, `[[`, "", "dominant")
sub$dclass   <- vapply(mc, `[[`, "", "classes")
sub$entity   <- vapply(mc, `[[`, "", "entity")
# entita' disease dal treated_label quando la classe dominante e' disease/nuisance
norm_lab <- function(x){ x<-tolower(trimws(x)); x<-gsub("[^a-z ]+"," ",x)
  x<-gsub("\\b(patient|patients|case|cases|control|controls|healthy|donor|donors|sample|samples|primary|culture|cell|cells|from|the|and|of|with|vs|total|rna)\\b"," ",x)
  trimws(gsub("\\s+"," ",x)) }
sub$dis_entity <- ifelse(sub$dominant %in% c("disease","nuisance"),
                         vapply(sub$treated_label, norm_lab, ""), sub$entity)

# ---- design partition keys ----
sub$k0  <- sub$cluster_id
sub$kA  <- paste(sub$cluster_id, sub$ct, sep="||")
sub$kB  <- paste(sub$cluster_id, sub$ct, sub$dominant, sep="||")
# DC: per disease/nuisance aggiunge entita' malattia; per il resto aggiunge entita' delta
sub$entity_fine <- ifelse(sub$dominant %in% c("disease","nuisance"), sub$dis_entity, sub$entity)
sub$kC  <- paste(sub$cluster_id, sub$ct, sub$dominant, sub$entity_fine, sep="||")

# k = numero di STUDI (series) distinti in un sotto-cluster
count_sub <- function(keycol){
  df <- data.frame(orig=sub$cluster_id, key=sub[[keycol]], study=sub$study_id, stringsAsFactors=FALSE)
  agg <- df |> group_by(key) |> summarise(orig=orig[1], k=n_distinct(study), n=n(), .groups="drop")
  agg
}
for(design in c("k0","kA","kB","kC")){
  agg <- count_sub(design)
  poolable <- agg[agg$k>=3,]
  cat(sprintf("\n=== DESIGN %s ===\n", design))
  cat(sprintf("sotto-cluster totali: %d | con k>=3 (poolabili): %d | con k>=2: %d\n",
      nrow(agg), sum(agg$k>=3), sum(agg$k>=2)))
  cat("distribuzione k dei poolabili (k>=3):\n"); print(summary(poolable$k))
  cat("quanti orig-184 producono >=1 sotto-cluster k>=3:", length(unique(poolable$orig)), "\n")
}

# salva la tabella membrale per riuso
saveRDS(sub, "/tmp/claude-1000/-home-user-simulomicsr/86210ec5-4f17-44a5-bab9-706852ab2de8/scratchpad/sub184.rds")
cat("\nsalvato sub184.rds\n")

# quanti membri hanno la classe dominante = ? (diagnostica meccanismi)
cat("\n=== classe dominante del contrasto sui membri dei 184 ===\n")
print(sort(table(sub$dominant), decreasing=TRUE))
cat("\n=== quanti dei 157 minestrone sono 'multi-classe' (mescolano drug/infection/genetic/disease)? ===\n")
byorig <- sub |> group_by(cluster_id) |> summarise(n_dom=n_distinct(dominant), n_ct=n_distinct(ct), .groups="drop")
byorig <- merge(byorig, d184[,c("cluster_id","contrast_verdict")], by="cluster_id")
cat("tra i minestrone: mediana n classi-dominanti distinte:", median(byorig$n_dom[byorig$contrast_verdict=="minestrone"]), "\n")
cat("tra i minestrone: mediana n control-type distinti:", median(byorig$n_ct[byorig$contrast_verdict=="minestrone"]), "\n")
cat("tra i coherent:   mediana n classi-dominanti distinte:", median(byorig$n_dom[byorig$contrast_verdict=="coherent"]), "\n")
cat("tra i coherent:   mediana n control-type distinti:", median(byorig$n_ct[byorig$contrast_verdict=="coherent"]), "\n")
