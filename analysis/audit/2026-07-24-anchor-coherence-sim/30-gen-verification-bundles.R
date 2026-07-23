Sys.setenv(OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1")
suppressPackageStartupMessages({library(arrow); library(dplyr); library(jsonlite)})
S <- readRDS("/tmp/claude-1000/-home-user-simulomicsr/86210ec5-4f17-44a5-bab9-706852ab2de8/scratchpad/simall.rds")
pm <- S$pm
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")
d184 <- cv[!is.na(cv$dd_verdict), c("cluster_id","dd_verdict","canonical_name","kind")]
set.seed(NULL)  # deterministico sotto: uso ordinamento, non random

bundle_for <- function(members, sub_key, design){
  m <- members
  m$tuple <- sprintf("%s  =>  %s   [%s]", substr(m$treated_label,1,70), substr(m$control_label,1,70), m$design_kind)
  tab <- sort(table(m$tuple), decreasing=TRUE)
  parent <- m$cluster_id[1]
  pv <- d184$dd_verdict[d184$cluster_id==parent]
  list(sub_id=sub_key, design=design, parent_cluster=parent,
       parent_verdict=if(length(pv)) pv else "NA",
       parent_name=cv$canonical_name[cv$cluster_id==parent][1],
       kind=cv$kind[cv$cluster_id==parent][1],
       k_studies=length(unique(m$study_id)), n_members=nrow(m),
       distinct_controls=unname(unique(m$control_label))[1:min(12,length(unique(m$control_label)))],
       contrasts_dedup=unname(sprintf("%dx  %s", as.integer(tab), names(tab)))[seq_len(min(25,length(tab)))])
}

# --- campione DA: sotto-cluster k>=3 il cui PARENT e' tra i 184 (minestrone noto) ---
pm184 <- pm[pm$cluster_id %in% d184$cluster_id,]
daA <- pm184 |> group_by(kA) |> filter(n_distinct(study_id)>=3) |> ungroup()
subkeys <- unique(daA$kA)
# stratifica: prendi fino a 28, ordinati per k decrescente ma con varieta' di parent
ks <- sapply(subkeys, function(k) length(unique(daA$study_id[daA$kA==k])))
subkeys <- subkeys[order(-ks)]
# limita a max 1 sub per parent per varieta', poi riempi
parent_of <- sapply(subkeys, function(k) daA$cluster_id[daA$kA==k][1])
sel_da <- character(0); seen <- character(0)
for(k in subkeys){ p<-parent_of[k]; if(!(p %in% seen)){ sel_da<-c(sel_da,k); seen<-c(seen,p)}; if(length(sel_da)>=28) break }

con <- file("/tmp/claude-1000/-home-user-simulomicsr/86210ec5-4f17-44a5-bab9-706852ab2de8/scratchpad/bundles_DA.jsonl","w")
for(k in sel_da){ b <- bundle_for(daA[daA$kA==k,], k, "DA"); writeLines(toJSON(b, auto_unbox=TRUE, null="null"), con) }
close(con)
cat("DA bundles:", length(sel_da), "\n")

# --- campione DC: sotto-cluster k>=3 (coerente per costruzione) su TUTTO il corpus ---
dcC <- pm |> group_by(kC) |> filter(n_distinct(study_id)>=3) |> ungroup()
subkeys2 <- unique(dcC$kC)
ks2 <- sapply(subkeys2, function(k) length(unique(dcC$study_id[dcC$kC==k])))
subkeys2 <- subkeys2[order(-ks2)]
parent2 <- sapply(subkeys2, function(k) dcC$cluster_id[dcC$kC==k][1])
sel_dc <- character(0); seen2 <- character(0)
for(k in subkeys2){ p<-parent2[k]; if(!(p %in% seen2)){ sel_dc<-c(sel_dc,k); seen2<-c(seen2,p)}; if(length(sel_dc)>=20) break }
con <- file("/tmp/claude-1000/-home-user-simulomicsr/86210ec5-4f17-44a5-bab9-706852ab2de8/scratchpad/bundles_DC.jsonl","w")
for(k in sel_dc){ b <- bundle_for(dcC[dcC$kC==k,], k, "DC"); writeLines(toJSON(b, auto_unbox=TRUE, null="null"), con) }
close(con)
cat("DC bundles:", length(sel_dc), "\n")
cat("esempio DA:\n"); cat(readLines("/tmp/claude-1000/-home-user-simulomicsr/86210ec5-4f17-44a5-bab9-706852ab2de8/scratchpad/bundles_DA.jsonl",n=1),"\n")
