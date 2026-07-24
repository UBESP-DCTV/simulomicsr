suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
source("analysis/audit/2026-07-24-anchor-coherence-sim/contrast-sig-engine.R")
suppressPackageStartupMessages(devtools::load_all(".", quiet=TRUE))
pm <- readRDS(file.path(SC,"fase1-pm.rds"))
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")
pm <- merge(pm, cv[,c("cluster_id","canonical_name")], by="cluster_id", all.x=TRUE)

## ===== STOPLIST/BLACKLIST ESTESE (v6) =====
GENERIC <- c("none","control","controls","vehicle","untreated","treated","treatment","treatments",
  "dmso","pbs","saline","mock","naive","baseline","normal","healthy","wildtype","wt","ko","knockout",
  "knockdown","overexpression","overexpressed","genetic","genetic_knockdown","genetic_overexpression",
  "genetic_modification","sirna","shrna","sgrna","crispr","transfection","transfected","transduced",
  "infected","infection","exposed","exposure","stimulated","stimulation","condition","conditions",
  "sample","samples","patient","patients","case","cases","disease","drug","compound","agent","stimulus",
  "perturbation","perturbations","treatment_group","group","other","unknown","unclear","na","test",
  "experiment","combination","combo","induced","inducible","expression","cells","cell","tissue","line",
  "type","status","state",
  # v6: parole di confronto/ordinali generiche (slop tipo STR:t)
  "high","low","positive","negative","present","absent","mutant","wildtype","post","pre","on","off",
  "early","late","responder","nonresponder","non","sensitive","resistant","primary","recurrent",
  "chemotherapy","differentiation","differentiated","environmental","behavioral","transgene","stable",
  "up","down","yes","no","before","after","day","week","month","stage","grade","level","score",
  "activated","resting","stimulus","treated_group","poly","mrna","rna","dna","organic","cation","anion",
  "steroid","steroids","small","molecule","molecules","vector","empty","parental","derived")
INDUCERS <- c("doxycycline","dox","doxy","tetracycline","tet","iptg","auxin","iaa","blasticidin",
  "puromycin","g418","geneticin","hygromycin","cumate")
UMBRELLA_NAME_RX <- "^(neoplasms?|carcinomas?|adenocarcinomas?|tumou?rs?|cancers?|inflammation|infections?|disease|diseases|leukemi|lymphoma|sarcoma|lesional|non-small|small molecule|organic cation|steroid)$"
## v6: blacklist ID ontologici (induttori, veicoli, classi troppo larghe emerse dal censimento)
BLACKLIST_ID <- c("MeSH:D009369","MeSH:D009361","MeSH:D002277","MeSH:D004194","MeSH:D007239","MeSH:D007249",
  "MeSH:D009371","CHEBI:17499","CHEBI:24431","CHEBI:23367","CHEBI:33232","CHEBI:50906",
  "CHEBI:50845",  # doxycycline (induttore)
  "CHEBI:28262",  # dmso (veicolo)
  "CHEBI:25367",  # organic cation (classe)
  "CHEBI:35341",  # steroid (classe)
  "CHEBI:33699",  # mRNA
  "CHEBI:84123",  # classe generica
  "CHEBI:16236")  # ethanol (spesso veicolo)
VEHICLE_MATERIALS <- c("plasma","serum","cell-free","cfrna","liquid biopsy","exosome")

is_generic_tok <- function(tok){
  if(is.na(tok)||!nzchar(tok)) return(TRUE)
  t <- tolower(trimws(tok))
  if(nchar(gsub("[^a-z0-9]","",t)) < 4) return(TRUE)
  if(!grepl("[a-z]", t)) return(TRUE)
  words <- strsplit(t, "[^a-z0-9]+")[[1]]; words <- words[nzchar(words)]
  if(length(words)>0 && all(words %in% GENERIC)) return(TRUE)     # solo parole generiche
  FALSE
}
is_inducer_name <- function(x){ if(is.na(x)) return(FALSE); any(vapply(INDUCERS, function(z) grepl(paste0("\\b",z,"\\b"), tolower(x)), logical(1))) }

## delta parts (come v5) + rilevamento COMBO + materiale-controllo
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
## COMBO: il trattato aggiunge un 2° agente (rispetto al controllo) -> es. "Enza + Simirosertib" vs "Vehicle"
is_combo <- function(tlabel, tval){
  s <- tolower(paste(tlabel, tval))
  # segnali di combinazione di 2 agenti
  grepl("\\+", s) || grepl("\\b(and|plus|combination|combo|co-treat|cotreat)\\b", s)
}
## materiale del controllo (per non fondere tessuto-vs-plasma)
ctrl_material <- function(cval){
  s <- tolower(paste(cval, collapse=" "))
  if(grepl("plasma|serum|cell-free|cfrna|liquid biops|exosome", s)) return("_liquid")
  ""
}

n <- nrow(pm); ent<-character(n); ct<-character(n); dcls<-character(n); onc<-logical(n); dr<-character(n)
for(i in seq_len(n)){
  dp <- delta_parts(pm$treated_fl[i], pm$control_fl[i])
  if(length(dp$classes)==0){ ent[i]<-NA; ct[i]<-"NA"; dcls[i]<-NA; dr[i]<-"no_delta"; next }
  pri <- c("genetic","drug","infection","disease","environment","time","other")
  cls <- pri[pri %in% dp$classes][1]; dcls[i]<-cls
  cvv <- dp$cval; cvv[!nzchar(trimws(cvv))]<-"untreated"
  ctb <- paste(sort(unique(vapply(cvv, .normalize_control_type, ""))), collapse="+")
  ct[i] <- paste0(ctb, ctrl_material(dp$cval))          # material-aware
  tn <- toks(pm$canonical_name[i]); tvaln <- .norm_val(dp$tval)
  is_on <- length(tn)>0 && any(vapply(tn, function(z) grepl(z, tvaln, fixed=TRUE), logical(1)))
  onc[i]<-is_on
  e <- NA_character_
  if(is_on && !is.na(pm$canonical_name[i]) && nzchar(pm$canonical_name[i])) e <- paste0("NAME:", tolower(pm$canonical_name[i]))
  else if(!is.na(pm$ce_id[i]) && !startsWith(pm$ce_id[i],"STR:")) e <- pm$ce_id[i]
  else { tk <- clean_tok(dp$tval); if(nzchar(tk)) e <- paste0("STR:", gsub(" ","_",tk)) }
  if(is.na(e)){ dr[i]<-"no_entity"; ent[i]<-NA; next }
  raw <- sub("^(NAME|STR):","", e); nm_low <- tolower(raw)
  # GATE
  if(startsWith(e,"STR:") && is_generic_tok(raw)){ dr[i]<-"str_generico"; ent[i]<-NA; next }
  if(startsWith(e,"NAME:") && grepl(UMBRELLA_NAME_RX, nm_low)){ dr[i]<-"nome_ombrello"; ent[i]<-NA; next }
  if(e %in% BLACKLIST_ID){ dr[i]<-"id_blacklist"; ent[i]<-NA; next }
  if(is_inducer_name(raw)){ dr[i]<-"induttore"; ent[i]<-NA; next }
  # COMBO -> entita' distinta (decisione utente #5)
  if(cls %in% c("drug") && is_combo(pm$treated_label[i], dp$tval)) e <- paste0(e, "+COMBO")
  ent[i]<-e; dr[i]<-"ok"
}
pm$entity<-ent; pm$ct_delta<-ct; pm$dom_cls<-dcls; pm$onc<-onc; pm$dr<-dr
pm$clean_tval <- vapply(seq_len(n), function(i){ dp<-delta_parts(pm$treated_fl[i],pm$control_fl[i]); clean_tok(dp$tval) }, "")
edi <- pm[!is.na(pm$entity),] |> group_by(entity) |> summarise(nd=n_distinct(clean_tval[nzchar(clean_tval)]), .groups="drop")
umb <- edi$entity[edi$nd>=12]; pm$entity[pm$entity %in% umb]<-NA
pm$elig <- !pm$deg & !is.na(pm$dom_cls) & pm$dom_cls %in% c("drug","infection","disease","genetic","environment","other") & !is.na(pm$entity)
pm$ckey <- ifelse(pm$elig, paste(pm$entity, pm$ct_delta, sep="||"), NA)
cat("=== drop reasons v6 ===\n"); print(sort(table(pm$dr),decreasing=TRUE))
elig <- pm[pm$elig,]
agg <- elig |> group_by(ckey) |> summarise(k=n_distinct(study_id), n=n(), src=ifelse(startsWith(entity[1],"NAME:"),"NAME",ifelse(startsWith(entity[1],"STR:"),"STR","onto")), .groups="drop") |> filter(k>=3)
cat(sprintf("\n=== v6 poolabili k>=3: %d (v5 219) | k>=5: %d ===\n", nrow(agg), sum(agg$k>=5)))
print(table(agg$src))
saveRDS(list(pm=pm, agg=agg), file.path(SC,"fase1-v6-results.rds"))
cat("salvato fase1-v6-results.rds\n")
