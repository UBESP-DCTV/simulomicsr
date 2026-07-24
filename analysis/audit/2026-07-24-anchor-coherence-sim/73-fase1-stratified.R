suppressPackageStartupMessages(library(dplyr))
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC,"fase1-v4-results.rds")); pm <- r$pm; agg <- r$agg
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")

# stratifica i 26 coerenti per KIND (perturbation vs disease/other)
coh <- cv[!is.na(cv$dd_verdict) & cv$contrast_verdict=="coherent", c("cluster_id","kind","canonical_name")]
kc <- function(k){k<-k%||%"";if(grepl("disease",k))"disease" else if(grepl("genetic",k))"genetic" else if(grepl("pathogen|infect",k))"infection" else if(grepl("small_molecule|cytokine",k))"drug" else "other"}
`%||%`<-function(a,b) if(is.null(a)||is.na(a))b else a
coh$class <- vapply(coh$kind, kc, "")
ckey_k <- setNames(agg$k, agg$ckey)
coh$dom_k <- vapply(coh$cluster_id, function(cid){
  m<-pm[pm$cluster_id==cid & pm$elig,]; if(nrow(m)==0) return(0L)
  tb<-sort(table(m$ckey),decreasing=TRUE); d<-as.integer(ckey_k[names(tb)[1]]); ifelse(is.na(d),0L,d)}, 0L)
coh$preserved <- coh$dom_k>=3
cat("=== 26 coerenti: preservazione per classe di kind ===\n")
print(coh |> group_by(class) |> summarise(n=n(), preservati_domK3=sum(preserved), .groups="drop"))
cat("\nperturbativi (drug/infection/genetic):", sum(coh$class %in% c("drug","infection","genetic")),
    "-> preservati:", sum(coh$preserved & coh$class %in% c("drug","infection","genetic")), "\n")
cat("disease/other:", sum(coh$class %in% c("disease","other")),
    "-> preservati:", sum(coh$preserved & coh$class %in% c("disease","other")), "\n")

# poolabili v4 per classe
pm$src_class <- ifelse(startsWith(pm$entity %||% "z","NAME:"),"onc_name",
                ifelse(startsWith(ifelse(is.na(pm$entity),"z",pm$entity),"STR:"),"STR","onto"))
agg2 <- pm[pm$elig,] |> group_by(ckey) |> summarise(k=n_distinct(study_id), cls=dom_cls[1], onc=mean(onc), .groups="drop")
cat("\n=== poolabili v4 k>=3 per classe-delta ===\n")
print(agg2[agg2$k>=3,] |> group_by(cls) |> summarise(n_poolable=n(), k_med=median(k), k_max=max(k), .groups="drop") |> arrange(desc(n_poolable)))
cat("\ntotale poolabili k>=3:", sum(agg2$k>=3), " k>=5:", sum(agg2$k>=5),"\n")
