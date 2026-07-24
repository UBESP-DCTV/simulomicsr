suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
pm <- readRDS(file.path(SC,"fase1-pm.rds"))
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")

## (1) DOVE va il 71% non-eleggibile? (drop corretto vs risoluzione fallita) ---
pm$bucket <- with(pm, ifelse(deg, "degenere(drop OK)",
  ifelse(ce_cls %in% c("<none>","nuisance"), "nuisance/none(drop OK)",
  ifelse(is.na(ce_id), "entita NA(perso)",
  ifelse(startsWith(ce_id,"STR:"), "STR non risolto(perso-FIXABILE)", "risolto(eleggibile)")))))
cat("=== dove finiscono i 38.440 membri ===\n"); print(sort(table(pm$bucket), decreasing=TRUE))
cat("\n=== STR non risolti per classe (il perso-fixable) ===\n")
str_lost <- pm[startsWith(pm$ce_id %||% "", "STR:") & pm$ce_cls %in% c("drug","infection","disease","genetic"),]
`%||%` <- function(a,b) ifelse(is.na(a),b,a)
str_lost <- pm[!is.na(pm$ce_id) & startsWith(pm$ce_id,"STR:") & pm$ce_cls %in% c("drug","infection","disease","genetic"),]
print(sort(table(str_lost$ce_cls), decreasing=TRUE))
cat("\nesempi STR persi (disease):\n"); print(head(unique(str_lost$ce_name[str_lost$ce_cls=="disease"]),15))
cat("\nesempi STR persi (drug):\n"); print(head(unique(str_lost$ce_name[str_lost$ce_cls=="drug"]),10))

## (2) I 10 coerenti frammentati: control_type o entita'? ---
coh <- cv$cluster_id[!is.na(cv$dd_verdict) & cv$contrast_verdict=="coherent"]
cat("\n=== i 26 coerenti: come si comportano sotto l'anchor canonico ===\n")
for(cid in coh){
  m <- pm[pm$cluster_id==cid & !pm$deg & pm$ce_cls %in% c("drug","infection","disease","genetic") & !is.na(pm$ce_id) & !startsWith(pm$ce_id,"STR:"),]
  if(nrow(m)==0){ cat(sprintf("  %s [%s]: 0 membri eleggibili (entita' non risolta)\n", substr(cid,1,20), cv$canonical_name[cv$cluster_id==cid][1])); next }
  n_ent <- length(unique(m$ce_id)); n_ct <- length(unique(m$ct)); n_key <- length(unique(paste(m$ce_id,m$ct)))
  k <- length(unique(m$study_id))
  cat(sprintf("  %s [%s]: k=%d | entita' distinte=%d | control_type distinti=%d | ckey=%d %s\n",
      substr(cid,1,18), substr(cv$canonical_name[cv$cluster_id==cid][1],1,22), k, n_ent, n_ct, n_key,
      ifelse(n_key>1, ifelse(n_ent>1,"<-FRAMM.ENTITA","<-FRAMM.CONTROL"), "OK")))
}
