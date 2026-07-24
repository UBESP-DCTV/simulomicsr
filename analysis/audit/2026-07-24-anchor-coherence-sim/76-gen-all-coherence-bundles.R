suppressPackageStartupMessages({library(dplyr); library(jsonlite)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC,"fase1-v5-results.rds")); pm <- r$pm; agg <- r$agg
elig <- pm[pm$elig,]
ids <- agg$ckey
cat("cluster da verificare (TUTTI i poolabili k>=3):", length(ids), "\n")
dir <- file.path(SC,"allbundles"); dir.create(dir, showWarnings=FALSE)
con <- file(file.path(SC,"all_bundles.jsonl"),"w")
for(kk in ids){
  m <- elig[elig$ckey==kk,]
  m$tuple <- sprintf("%s  =>  %s   [%s]", substr(m$treated_label,1,68), substr(m$control_label,1,68), m$design_kind)
  tab <- sort(table(m$tuple), decreasing=TRUE)
  b <- list(ckey=kk, k_studies=length(unique(m$study_id)), n_members=nrow(m),
            contrasts_dedup=unname(sprintf("%dx  %s", as.integer(tab), names(tab)))[seq_len(min(20,length(tab)))])
  writeLines(toJSON(b, auto_unbox=TRUE, null="null"), con)
}
close(con)
cat("scritto all_bundles.jsonl (", length(ids), "cluster )\n")
