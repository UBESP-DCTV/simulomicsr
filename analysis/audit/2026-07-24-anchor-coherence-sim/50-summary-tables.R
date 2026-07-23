suppressPackageStartupMessages({library(dplyr); library(jsonlite)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
OUT <- "analysis/audit/2026-07-24-anchor-coherence-sim"
S <- readRDS(file.path(OUT,"simall.rds")); pm <- S$pm
count_pool <- function(k) list(k3=sum(k>=3), k5=sum(k>=5), sumk=sum(k[k>=3]))
b <- S$base
rows <- list()
rows[["baseline_anchor_attuale"]] <- c(subcluster=length(unique(pm$cluster_id)), k3=sum(b$k>=3), k5=sum(b$k>=5))
for(d in c("kA","kB","kC")){ a<-S$res[[d]]; rows[[d]] <- c(subcluster=nrow(a), k3=sum(a$k>=3), k5=sum(a$k>=5)) }
tab <- as.data.frame(do.call(rbind, rows)); tab$design <- rownames(tab)
tab$label <- c("Baseline (anchor v10, comparison-blind)","DA contrast-anchor (solo control-type)",
               "DB +classe-contrasto","DC +delta-entity (fine, coerente-per-costruzione)")
tab$llm_coherence_sample <- c(NA, "3/28 = 11%", NA, "16/20 = 80% (89% escl. <none>)")
tab <- tab[,c("design","label","subcluster","k3","k5","llm_coherence_sample")]
write.csv(tab, file.path(OUT,"design-comparison.csv"), row.names=FALSE)
print(tab)
# tabella per classe della granularita' disease (costo k)
pm$kC <- paste(pm$cluster_id,pm$ct,pm$dominant,pm$entity_fine,sep="||")
dc <- pm |> group_by(kC) |> summarise(k=n_distinct(study_id), dom=names(sort(table(dominant),decreasing=TRUE))[1], .groups="drop") |> filter(k>=3)
byclass <- dc |> group_by(dom) |> summarise(n_poolable=n(), k_median=median(k), k_max=max(k), .groups="drop") |> arrange(desc(n_poolable))
write.csv(byclass, file.path(OUT,"dc-poolable-by-class.csv"), row.names=FALSE)
cat("\n=== DC poolable per classe (costo-k) ===\n"); print(byclass)
