Sys.setenv(OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1")
suppressPackageStartupMessages({library(dplyr)})
S <- readRDS("/tmp/claude-1000/-home-user-simulomicsr/86210ec5-4f17-44a5-bab9-706852ab2de8/scratchpad/simall.rds")
pm <- S$pm
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")
d184 <- cv[!is.na(cv$dd_verdict),]

## (1) Evidenza comparison-blind: n classi-contrasto distinte per cluster (scala) ---
byc <- pm |> group_by(cluster_id) |>
  summarise(k=n_distinct(study_id), n_dom=n_distinct(dominant),
            n_ct=n_distinct(ct), n=n(), .groups="drop")
byc <- merge(byc, cv[,c("cluster_id","contrast_verdict","kind")], by="cluster_id", all.x=TRUE)
cat("=== (1) tra i cluster RISOLVIBILI con k>=3 ===\n")
k3 <- byc[byc$k>=3,]
cat("n cluster k>=3:", nrow(k3), "\n")
cat("frazione con >=2 classi-contrasto distinte (mescola drug/infection/genetic/disease):",
    round(mean(k3$n_dom>=2),3), "\n")
cat("frazione con >=3 classi-contrasto distinte:", round(mean(k3$n_dom>=3),3), "\n")
cat("frazione con >=2 tipi-controllo distinti:", round(mean(k3$n_ct>=2),3), "\n")
cat("mediana n classi-contrasto:", median(k3$n_dom), " mediana n control-type:", median(k3$n_ct), "\n")

## (2) DC poolabili: breakdown per classe dominante + k ---
dc <- S$res$kC
dc3 <- dc[dc$k>=3,]
# classe dominante del sub-cluster = moda dei membri
pm$kC <- paste(pm$cluster_id, pm$ct, pm$dominant, pm$entity_fine, sep="||")
dommap <- pm |> group_by(kC) |> summarise(dom=names(sort(table(dominant),decreasing=TRUE))[1], .groups="drop")
dc3 <- merge(dc3, dommap, by.x="key", by.y="kC", all.x=TRUE)
cat("\n=== (2) DC poolabili k>=3 (n=",nrow(dc3),") per classe dominante ===\n")
print(dc3 |> group_by(dom) |> summarise(n_subcluster=n(), k_med=median(k), k_max=max(k), .groups="drop") |> arrange(desc(n_subcluster)))

## (2b) confronto: quante meta-analisi DIFENDIBILI per classe, DA vs DC ---
da <- S$res$kA; da3 <- da[da$k>=3,]
dommapA <- pm |> mutate(kA=paste(cluster_id,ct,sep="||")) |> group_by(kA) |>
  summarise(dom=names(sort(table(dominant),decreasing=TRUE))[1], .groups="drop")
da3 <- merge(da3, dommapA, by.x="key", by.y="kA", all.x=TRUE)
cat("\n=== DA poolabili k>=3 (n=",nrow(da3),") per classe dominante ===\n")
print(da3 |> group_by(dom) |> summarise(n_subcluster=n(), k_med=median(k), .groups="drop") |> arrange(desc(n_subcluster)))

## (3) I 26 coherent attuali: sopravvivono ai design? (si spezzano in troppi pezzi?) ---
coh <- d184$cluster_id[d184$contrast_verdict=="coherent"]
cat("\n=== (3) i 26 coherent attuali: n sotto-cluster prodotti da ogni design ===\n")
for(design in c("kA","kC")){
  key <- if(design=="kA") "kA" else "kC"
  sub <- pm[pm$cluster_id %in% coh,]
  agg <- sub |> group_by(cluster_id) |>
    summarise(n_sub=n_distinct(.data[[key]]),
              n_sub_k3=sum(table(.data[[key]][ave(study_id,.data[[key]],FUN=function(x) length(unique(x)))>=3])>0),
              .groups="drop")
  # semplice: quanti sotto-cluster e quanti mantengono k>=3
  tmp <- sub |> group_by(cluster_id, subk=.data[[key]]) |> summarise(k=n_distinct(study_id), .groups="drop")
  keptk3 <- tmp |> group_by(cluster_id) |> summarise(n_sub=n(), n_k3=sum(k>=3), maxk=max(k), .groups="drop")
  cat(sprintf("design %s: dei 26 coherent, quanti mantengono >=1 sotto-cluster k>=3: %d/26; mediana n_sub: %g; mediana maxk sotto-cluster: %g\n",
      design, sum(keptk3$n_k3>=1), median(keptk3$n_sub), median(keptk3$maxk)))
}

## (4) quanti dei 184 sono 'disease-dominant' (meccanismo 2) vs 'perturbation'? ---
dommap184 <- pm[pm$cluster_id %in% d184$cluster_id,] |> group_by(cluster_id) |>
  summarise(dom=names(sort(table(dominant),decreasing=TRUE))[1], frac_dis=mean(dominant %in% c("disease","nuisance")), .groups="drop")
dommap184 <- merge(dommap184, d184[,c("cluster_id","contrast_verdict")], by="cluster_id")
cat("\n=== (4) i 184: classe dominante del cluster x verdetto ===\n")
print(table(dommap184$dom, dommap184$contrast_verdict))
