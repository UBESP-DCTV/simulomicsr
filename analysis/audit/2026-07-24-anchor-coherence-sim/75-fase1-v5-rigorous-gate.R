suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
source("analysis/audit/2026-07-24-anchor-coherence-sim/contrast-sig-engine.R")
suppressPackageStartupMessages(devtools::load_all(".", quiet=TRUE))
pm <- readRDS(file.path(SC,"fase1-pm.rds"))
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")
pm <- merge(pm, cv[,c("cluster_id","canonical_name")], by="cluster_id", all.x=TRUE)

## ============ STOPLIST/GATE RIGOROSI (niente slop) ============
# parole generiche / nomi-di-classe che NON sono MAI un'entità
GENERIC <- c("none","control","controls","vehicle","untreated","treated","treatment","treatments",
  "dmso","pbs","saline","mock","naive","baseline","normal","healthy","wildtype","wt","ko","knockout",
  "knockdown","overexpression","genetic","genetic_knockdown","genetic_overexpression","genetic_modification",
  "sirna","shrna","sgrna","crispr","transfection","transfected","transduced","infected","infection",
  "exposed","exposure","stimulated","stimulation","condition","conditions","sample","samples","patient",
  "patients","case","cases","disease","drug","compound","agent","stimulus","perturbation","perturbations",
  "treatment_group","group","other","unknown","unclear","na","test","experiment","combination","combo",
  "induced","inducible","expression","cells","cell","tissue","line","type","status","state")
# induttori (sistemi inducibili): l'entita' vera e' il transgene, non l'induttore
INDUCERS <- c("doxycycline","dox","doxy","tetracycline","tet","iptg","auxin","iaa","indole-3-acetic acid",
  "4-ht","4-oht","tamoxifen-inducible","blasticidin","puromycin","g418","geneticin","hygromycin","cumate")
# nomi-ombrello ontologici (categorie troppo larghe)
UMBRELLA_NAME_RX <- "^(neoplasms?|carcinomas?|adenocarcinomas?|tumou?rs?|cancers?|inflammation|infections?|disease|diseases|leukemi|lymphoma|sarcoma|neoplasm, |neoplastic)$"
UMBRELLA_ID <- c("MeSH:D009369","MeSH:D009361","MeSH:D002277","MeSH:D004194","MeSH:D007239","MeSH:D007249",
  "MeSH:D009371","CHEBI:17499","CHEBI:24431","CHEBI:23367","CHEBI:33232","CHEBI:50906")

is_generic_tok <- function(tok){
  if(is.na(tok)||!nzchar(tok)) return(TRUE)
  t <- tolower(trimws(tok))
  if(nchar(gsub("[^a-z0-9]","",t)) < 4) return(TRUE)          # < 4 char utili -> spazzatura (es. 't','d','e','dox')
  if(!grepl("[a-z]", t)) return(TRUE)                          # nessuna lettera -> numero puro
  words <- strsplit(t, "[^a-z0-9]+")[[1]]; words <- words[nzchar(words)]
  if(length(words)>0 && all(words %in% GENERIC)) return(TRUE)  # solo parole generiche
  if(length(words)==1 && words %in% GENERIC) return(TRUE)
  FALSE
}
is_inducer <- function(x){ if(is.na(x)) return(FALSE); any(vapply(INDUCERS, function(z) grepl(paste0("\\b",z,"\\b"), tolower(x)), logical(1))) }

## ---- delta + entita' (come v4) ----
STOP <- c("cell","cells","human","disease","syndrome","acute","chronic","carcinoma","cancer","neoplasm",
  "neoplasms","virus","infection","control","normal","tissue","patient","treated","the","and")
toks <- function(nm){ if(is.na(nm)||!nzchar(nm)) return(character(0))
  t <- strsplit(gsub("[^a-z0-9 ]+"," ",tolower(nm))," ")[[1]]; unique(t[nchar(t)>=4 & !t %in% STOP]) }
clean_tok <- function(x){ x<-tolower(trimws(x)); x<-gsub("[^a-z ]+"," ",x)
  x<-gsub("\\b(patient|patients|case|cases|control|controls|healthy|donor|donors|sample|samples|primary|culture|cell|cells|from|the|and|of|with|vs|total|rna|tissue|line|human|treated|treatment|stimulated|infected|exposed|day|days|hour|hours|hr|hrs)\\b"," ",x)
  trimws(gsub("\\s+"," ",x)) }
delta_parts <- function(tfl, cfl){
  T <- .parse_fl_kv(tfl); C <- .parse_fl_kv(cfl); keys <- union(names(T),names(C))
  chT<-character(0); chC<-character(0); classes<-character(0)
  for(k in keys){ tv <- if(k %in% names(T)) T[[k]] else ""; cv2 <- if(k %in% names(C)) C[[k]] else ""
    if(!identical(.norm_val(tv),.norm_val(cv2)) && .classify_key(k)!="nuisance"){ chT<-c(chT,tv);chC<-c(chC,cv2);classes<-c(classes,.classify_key(k)) } }
  list(tval=paste(chT,collapse=" "), cval=chC, classes=classes)
}

n <- nrow(pm); ent<-character(n); ct<-character(n); dcls<-character(n); onc<-logical(n); drop_reason<-character(n)
for(i in seq_len(n)){
  dp <- delta_parts(pm$treated_fl[i], pm$control_fl[i])
  if(length(dp$classes)==0){ ent[i]<-NA; ct[i]<-"NA"; dcls[i]<-NA; drop_reason[i]<-"no_delta"; next }
  pri <- c("genetic","drug","infection","disease","environment","time","other")
  cls <- pri[pri %in% dp$classes][1]; dcls[i]<-cls
  cvv <- dp$cval; cvv[!nzchar(trimws(cvv))]<-"untreated"
  ct[i] <- paste(sort(unique(vapply(cvv, .normalize_control_type, ""))), collapse="+")
  tn <- toks(pm$canonical_name[i]); tval <- .norm_val(dp$tval)
  is_on <- length(tn)>0 && any(vapply(tn, function(z) grepl(z, tval, fixed=TRUE), logical(1)))
  onc[i] <- is_on
  # candidato entita'
  e <- NA_character_
  if(is_on && !is.na(pm$canonical_name[i]) && nzchar(pm$canonical_name[i])){
    e <- paste0("NAME:", tolower(pm$canonical_name[i]))
  } else if(!is.na(pm$ce_id[i]) && !startsWith(pm$ce_id[i],"STR:")){
    e <- pm$ce_id[i]
  } else { tk <- clean_tok(dp$tval); if(nzchar(tk)) e <- paste0("STR:", gsub(" ","_",tk)) }
  # ===== GATE RIGOROSI =====
  if(is.na(e)){ drop_reason[i]<-"no_entity"; ent[i]<-NA; next }
  raw <- sub("^(NAME|STR):","", e); nm_low <- tolower(raw)
  if(startsWith(e,"STR:") && is_generic_tok(raw)){ drop_reason[i]<-"str_generico"; ent[i]<-NA; next }
  if(startsWith(e,"NAME:") && grepl(UMBRELLA_NAME_RX, nm_low)){ drop_reason[i]<-"nome_ombrello"; ent[i]<-NA; next }
  if(e %in% UMBRELLA_ID){ drop_reason[i]<-"id_ombrello"; ent[i]<-NA; next }
  if(is_inducer(raw) && cls=="drug"){ drop_reason[i]<-"induttore"; ent[i]<-NA; next }
  ent[i]<-e; drop_reason[i]<-"ok"
}
pm$entity<-ent; pm$ct_delta<-ct; pm$dom_cls<-dcls; pm$onc<-onc; pm$drop_reason<-drop_reason

## ---- data-driven umbrella: un'entita' che assorbe troppe malattie/nomi distinti ----
pm$clean_tval <- vapply(seq_len(n), function(i){ dp<-delta_parts(pm$treated_fl[i],pm$control_fl[i]); clean_tok(dp$tval) }, "")
ent_diversity <- pm[!is.na(pm$entity),] |> group_by(entity) |>
  summarise(n_distinct_tok=n_distinct(clean_tval[nzchar(clean_tval)]), .groups="drop")
umbrella_ids <- ent_diversity$entity[ent_diversity$n_distinct_tok >= 12]  # soglia: >=12 nomi diversi = ombrello
cat("entita' ombrello data-driven (>=12 nomi distinti):", length(umbrella_ids), "\n")
pm$entity[pm$entity %in% umbrella_ids] <- NA
pm$drop_reason[pm$cluster_id!="" & pm$entity %in% umbrella_ids] <- "ombrello_datadriven"

pm$elig <- !pm$deg & !is.na(pm$dom_cls) & pm$dom_cls %in% c("drug","infection","disease","genetic","environment","other") & !is.na(pm$entity)
pm$ckey <- ifelse(pm$elig, paste(pm$entity, pm$ct_delta, sep="||"), NA)
cat("\n=== drop reasons (membri) ===\n"); print(sort(table(pm$drop_reason), decreasing=TRUE))
elig <- pm[pm$elig,]
agg <- elig |> group_by(ckey) |> summarise(k=n_distinct(study_id), n=n(), ent=entity[1],
  src=ifelse(startsWith(entity[1],"NAME:"),"NAME",ifelse(startsWith(entity[1],"STR:"),"STR","onto")), .groups="drop") |> filter(k>=3)
cat(sprintf("\n=== v5 poolabili k>=3: %d (v4 era 287) | k>=5: %d ===\n", nrow(agg), sum(agg$k>=5)))
cat("per fonte:\n"); print(table(agg$src))
saveRDS(list(pm=pm, agg=agg), file.path(SC,"fase1-v5-results.rds"))
cat("\nsalvato fase1-v5-results.rds\n")
