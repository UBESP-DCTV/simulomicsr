Sys.setenv(OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1")
suppressPackageStartupMessages({library(arrow); library(dplyr)})
devtools::load_all(".", quiet=TRUE)
source("analysis/audit/2026-07-24-anchor-coherence-sim/contrast-sig-engine.R")
DIR <- "analysis/audit/2026-07-23-coherence"
pm <- read_parquet(file.path(DIR,"per-member-contrasts.parquet"))
cv <- readRDS(file.path(DIR,"cluster-verdicts.rds"))

cat("membri risolti totali:", nrow(pm), " cluster con >=1 risolto:", length(unique(pm$cluster_id)), "\n")
t0 <- Sys.time()
mc <- lapply(seq_len(nrow(pm)), function(i) .member_contrast(pm$treated_fl[i], pm$control_fl[i]))
pm$ct       <- vapply(seq_len(nrow(pm)), function(i) .normalize_control_type(pm$control_label[i]), "")
pm$dominant <- vapply(mc, `[[`, "", "dominant")
pm$entity   <- vapply(mc, `[[`, "", "entity")
norm_lab <- function(x){ x<-tolower(trimws(x)); x<-gsub("[^a-z ]+"," ",x)
  x<-gsub("\\b(patient|patients|case|cases|control|controls|healthy|donor|donors|sample|samples|primary|culture|cell|cells|from|the|and|of|with|vs|total|rna|tissue|line|human)\\b"," ",x)
  trimws(gsub("\\s+"," ",x)) }
pm$entity_fine <- ifelse(pm$dominant %in% c("disease","nuisance"),
                         vapply(pm$treated_label, norm_lab, ""), pm$entity)
cat("firma calcolata in", round(as.numeric(difftime(Sys.time(),t0,units="secs")),1), "s\n")

# design keys
pm$kA <- paste(pm$cluster_id, pm$ct, sep="||")
pm$kB <- paste(pm$cluster_id, pm$ct, pm$dominant, sep="||")
pm$kC <- paste(pm$cluster_id, pm$ct, pm$dominant, pm$entity_fine, sep="||")

# quale cluster e' poolabile oggi? (k>=3 studi). Nota: pm ha solo membri RISOLTI.
count_design <- function(keycol){
  df <- data.frame(key=pm[[keycol]], study=pm$study_id, orig=pm$cluster_id, kind=NA, stringsAsFactors=FALSE)
  df |> group_by(key) |> summarise(orig=orig[1], k=n_distinct(study), n=n(), .groups="drop")
}
res <- list()
for(d in c("kA","kB","kC")){
  agg <- count_design(d)
  res[[d]] <- agg
  cat(sprintf("\n=== SCALA (tutti i risolvibili) DESIGN %s ===\n", d))
  cat(sprintf("sotto-cluster: %d | k>=2: %d | k>=3: %d | k>=5: %d\n",
      nrow(agg), sum(agg$k>=2), sum(agg$k>=3), sum(agg$k>=5)))
  cat("somma k dei poolabili k>=3 (studi-slot totali):", sum(agg$k[agg$k>=3]), "\n")
}
# baseline: cluster originali con >=3 studi risolti
base <- pm |> group_by(cluster_id) |> summarise(k=n_distinct(study_id), .groups="drop")
cat(sprintf("\n=== BASELINE cluster originali (risolti) ===\nk>=2: %d | k>=3: %d | k>=5: %d\n",
    sum(base$k>=2), sum(base$k>=3), sum(base$k>=5)))

saveRDS(list(pm=pm, res=res, base=base),
  "/tmp/claude-1000/-home-user-simulomicsr/86210ec5-4f17-44a5-bab9-706852ab2de8/scratchpad/simall.rds")
cat("\nsalvato simall.rds\n")
