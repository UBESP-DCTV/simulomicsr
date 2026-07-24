suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
source("analysis/audit/2026-07-24-anchor-coherence-sim/contrast-sig-engine.R")
suppressPackageStartupMessages(devtools::load_all(".", quiet=TRUE))
pm <- readRDS(file.path(SC,"fase1-pm.rds"))
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")
pm <- merge(pm, cv[,c("cluster_id","canonical_name")], by="cluster_id", all.x=TRUE)

STOP <- c("cell","cells","human","disease","syndrome","acute","chronic","carcinoma","cancer",
  "neoplasm","neoplasms","virus","infection","control","normal","tissue","patient","treated","the","and")
toks <- function(nm){ if(is.na(nm)||!nzchar(nm)) return(character(0))
  t <- strsplit(gsub("[^a-z0-9 ]+"," ",tolower(nm))," ")[[1]]; unique(t[nchar(t)>=4 & !t %in% STOP]) }

## changed treated values (raw joined) + control-side delta values ---
delta_parts <- function(tfl, cfl){
  T <- .parse_fl_kv(tfl); C <- .parse_fl_kv(cfl); keys <- union(names(T),names(C))
  chT <- character(0); chC <- character(0); classes <- character(0)
  for(k in keys){
    tv <- if(k %in% names(T)) T[[k]] else ""; cv2 <- if(k %in% names(C)) C[[k]] else ""
    if(!identical(.norm_val(tv),.norm_val(cv2)) && .classify_key(k)!="nuisance"){
      chT<-c(chT,tv); chC<-c(chC,cv2); classes<-c(classes,.classify_key(k)) }
  }
  list(tval=paste(chT,collapse=" "), cval=chC, classes=classes)
}
clean_tok <- function(x){ x<-tolower(trimws(x)); x<-gsub("[^a-z ]+"," ",x)
  x<-gsub("\\b(patient|patients|case|cases|control|controls|healthy|donor|donors|sample|samples|primary|culture|cell|cells|from|the|and|of|with|vs|total|rna|tissue|line|human|treated|treatment|stimulated|infected|exposed|day|days|hour|hours|hr|hrs)\\b"," ",x)
  trimws(gsub("\\s+"," ",x)) }

n <- nrow(pm)
cat("v4 (hybrid on/off-contrast) su", n, "membri...\n")
ent <- character(n); ct <- character(n); dcls <- character(n); onc <- logical(n)
for(i in seq_len(n)){
  dp <- delta_parts(pm$treated_fl[i], pm$control_fl[i])
  if(length(dp$classes)==0){ ent[i]<-NA; ct[i]<-"NA"; dcls[i]<-NA; next }
  pri <- c("genetic","drug","infection","disease","environment","time","other")
  cls <- pri[pri %in% dp$classes][1]; dcls[i] <- cls
  # control_type dal lato-controllo del delta (collassa vehicle; NA->vehicle se vuoto)
  cvv <- dp$cval; cvv[!nzchar(trimws(cvv))] <- "untreated"
  ct[i] <- paste(sort(unique(vapply(cvv, .normalize_control_type, ""))), collapse="+")
  # ON-CONTRAST? l'entita' del cluster (canonical_name) e' nel delta trattato?
  tn <- toks(pm$canonical_name[i]); tval <- .norm_val(dp$tval)
  is_on <- length(tn)>0 && any(vapply(tn, function(z) grepl(z, tval, fixed=TRUE), logical(1)))
  onc[i] <- is_on
  if(is_on){ ent[i] <- paste0("NAME:", tolower(pm$canonical_name[i])) }  # entita' unica del cluster (coerente)
  else {  # off-contrast: risolvi il PROPRIO delta (ce_id ontologico se c'e', else STR pulito)
    if(!is.na(pm$ce_id[i]) && !startsWith(pm$ce_id[i],"STR:")) ent[i] <- pm$ce_id[i]
    else { tk <- clean_tok(dp$tval); ent[i] <- if(nzchar(tk)) paste0("STR:",gsub(" ","_",tk)) else NA }
  }
}
pm$entity<-ent; pm$ct_delta<-ct; pm$dom_cls<-dcls; pm$onc<-onc
pm$elig <- !pm$deg & !is.na(pm$dom_cls) & pm$dom_cls %in% c("drug","infection","disease","genetic","environment","other") & !is.na(pm$entity)
pm$ckey <- ifelse(pm$elig, paste(pm$entity, pm$ct_delta, sep="||"), NA)
elig <- pm[pm$elig,]
cat(sprintf("eleggibili: %d/%d | on-contrast: %d, off-contrast(risolti): %d\n", nrow(elig), n, sum(elig$onc), sum(!elig$onc)))
agg <- elig |> group_by(ckey) |> summarise(k=n_distinct(study_id), n=n(), .groups="drop")
cat(sprintf("\n=== v4 poolabili k>=3: %d | k>=5: %d (lower bound 126/26) ===\n", sum(agg$k>=3), sum(agg$k>=5)))
print(summary(agg$k[agg$k>=3]))
cat("\n=== SARS ===\n"); print(agg[grepl("sars", agg$ckey, ignore.case=TRUE) & agg$k>=2,])

coh <- cv$cluster_id[!is.na(cv$dd_verdict) & cv$contrast_verdict=="coherent"]
ckey_k <- setNames(agg$k, agg$ckey); res <- data.frame()
for(cid in coh){
  m <- pm[pm$cluster_id==cid & pm$elig,]; nm <- substr(cv$canonical_name[cv$cluster_id==cid][1],1,20)
  if(nrow(m)==0){ res<-rbind(res,data.frame(name=nm,k=0,n_ckey=0,dom_k=0,status="SPARITO")); next }
  tb<-sort(table(m$ckey),decreasing=TRUE); dk<-as.integer(ckey_k[names(tb)[1]]); dk<-ifelse(is.na(dk),0L,dk)
  st<-ifelse(length(tb)==1, ifelse(dk>=3,"OK","OK_lowk"), ifelse(dk>=3,"domK>=3","FRAMM"))
  res<-rbind(res,data.frame(name=nm,k=length(unique(m$study_id)),n_ckey=length(tb),dom_k=dk,status=st))
}
cat("\n=== NON-REGRESSIONE v4 (26 coerenti) ===\n"); print(table(res$status))
cat("contrasto preservato in forma poolabile (dom_k>=3):", sum(res$dom_k>=3), "/26 | intatti (1 ckey):", sum(res$n_ckey==1),"/26 | spariti:", sum(res$status=="SPARITO"),"\n\n")
print(res)
saveRDS(list(pm=pm,agg=agg,res=res), file.path(SC,"fase1-v4-results.rds"))
