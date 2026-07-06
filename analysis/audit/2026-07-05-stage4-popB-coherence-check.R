suppressWarnings(suppressMessages({library(dplyr); library(jsonlite)}))
raw <- stream_in(file("/tmp/claude-1000/-home-user-simulomicsr/087652e0-525a-4100-ae1b-60fa251ac2f1/scratchpad/popB_gsm_raw.jsonl"), verbose=FALSE)
txt <- setNames(tolower(raw$string), raw$geo_accession)
d <- readRDS("/tmp/claude-1000/-home-user-simulomicsr/087652e0-525a-4100-ae1b-60fa251ac2f1/scratchpad/popB.rds"); B <- d$B
byc <- readRDS("/tmp/claude-1000/-home-user-simulomicsr/087652e0-525a-4100-ae1b-60fa251ac2f1/scratchpad/popB_gsms.rds")
gmap <- setNames(byc$gsms, byc$cluster_id)
stop <- c("neoplasms","neoplasm","disease","diseases","disorder","disorders","syndrome","syndromes",
  "agents","agent","cell","cells","human","cancer","tumor","tumour","carcinoma","acid","acids","factor",
  "receptor","protein","proteins","chronic","acute","primary","complex","related","type","subunit",
  "member","family","group","system","antigen","gene","genes","experimental","histologic")
# token -> stem (primo 6 char); match come substring
tokize <- function(nm){ t <- unlist(strsplit(tolower(nm), "[^a-z0-9]+")); t <- t[nchar(t)>=4 & !(t %in% stop)]
  st <- ifelse(nchar(t)>6, substr(t,1,6), t); unique(st) }
# flag nome "formale/chimico": tag html, molte cifre, o >2 trattini
is_formal <- function(nm) grepl("<|>|[0-9].*[0-9].*[0-9]|(-.*){3,}|α|β|γ|·", nm)
broad_pat <- "agents$|inhibitors$|^neoplasms$|^carcinoma$|antineoplastic|antiprotozoal|antispermatogenic|nondepolarizing|^genes, viral$"

R <- bind_rows(lapply(seq_len(nrow(B)), function(i){
  cid<-B$cluster_id[i]; nm<-B$canonical_name[i]; terms<-tokize(nm)
  gsms<-gmap[[cid]]; present<-gsms[gsms %in% names(txt)]
  supp<- if(length(terms)==0||is.na(nm)) NA else mean(grepl(paste(terms,collapse="|"), txt[present]))
  data.frame(cluster_id=cid,name=nm,kind=B$kind_effective_resolved[i],k=B$k[i],level=B$level[i],
    n_gsm=length(present),support=round(supp,3),formal=is_formal(nm %||% ""),
    broad=grepl(broad_pat,tolower(nm %||% "")), non_pert=B$kind_effective_resolved[i]%in%c("vehicle_only","none"),
    stringsAsFactors=FALSE)
}))
`%||%`<-function(a,b) if(is.null(a)||is.na(a)) b else a
E <- R %>% group_by(name) %>% slice_max(k,n=1,with_ties=FALSE) %>% ungroup() %>%
  mutate(bucket=case_when(
    non_pert ~ "EXCLUDE_vehicle",
    broad ~ "BROAD_class",
    !is.na(support) & support>=0.80 ~ "SOLID",
    !is.na(support) & support>=0.40 ~ "PARTIAL(inspect)",
    formal ~ "FORMAL_name(dict-needed)",
    TRUE ~ "GARBAGE?(low+plain-name)"))
cat("===== TRIAGE stem-based, 197 entità =====\n"); print(E %>% count(bucket, sort=TRUE))
cat("\n=== SOLID (support>=0.80) — count:", sum(E$bucket=="SOLID"), "===\n")
print(E %>% filter(bucket=="SOLID") %>% arrange(desc(k)) %>% pull(name))
cat("\n=== GARBAGE? nome piano ma supporto ~0 (probabili errori risoluzione MeSH) ===\n")
print(E %>% filter(bucket=="GARBAGE?(low+plain-name)") %>% arrange(desc(k)) %>% transmute(name=substr(name,1,32),k,kind,supp=support) %>% as.data.frame(), row.names=FALSE)
cat("\n=== PARTIAL (0.40-0.80, da ispezionare) ===\n")
print(E %>% filter(grepl("PARTIAL",bucket)) %>% arrange(support) %>% transmute(name=substr(name,1,32),k,kind,supp=support) %>% as.data.frame(), row.names=FALSE)
write.csv(E,"/tmp/claude-1000/-home-user-simulomicsr/087652e0-525a-4100-ae1b-60fa251ac2f1/scratchpad/popB_triage2.csv",row.names=FALSE)
