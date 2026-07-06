suppressWarnings(suppressMessages({library(dplyr); library(jsonlite)}))
raw <- stream_in(file("/tmp/claude-1000/-home-user-simulomicsr/087652e0-525a-4100-ae1b-60fa251ac2f1/scratchpad/popB_gsm_raw.jsonl"), verbose=FALSE)
txt <- setNames(tolower(raw$string), raw$geo_accession); ser <- setNames(raw$series_id, raw$geo_accession)
d <- readRDS("/tmp/claude-1000/-home-user-simulomicsr/087652e0-525a-4100-ae1b-60fa251ac2f1/scratchpad/popB.rds"); B <- d$B
byc <- readRDS("/tmp/claude-1000/-home-user-simulomicsr/087652e0-525a-4100-ae1b-60fa251ac2f1/scratchpad/popB_gsms.rds")
gmap <- setNames(byc$gsms, byc$cluster_id)

# stoplist: SOLO boilerplate GEO + inglese generico + termini esperimento generici (NON biologia)
boiler <- c("title","source","sample","samples","name","human","homo","sapiens","rna","seq","rnaseq","mrna",
 "total","cell","cells","celltype","line","lines","tissue","treatment","treated","control","controls","ctrl",
 "rep","replicate","replicates","donor","donors","patient","patients","day","days","hour","hours","time","point",
 "timepoint","group","groups","condition","conditions","wildtype","expression","transcriptome","sequencing",
 "library","gene","genes","protein","batch","passage","stage","status","male","female","gender","age","sex",
 "primary","derived","culture","cultured","vitro","vivo","whole","fraction","assay","data","processing",
 "characteristics","subject","individual","the","and","for","with","from","not","was","were","are","seq",
 "type","types","number","level","levels","set","study","analysis","profiling","single","bulk","input","output",
 "high","low","poly","seqrep","protocol","code","hg38","grch38","polya","nuclear","cytosolic","fresh","frozen",
 "biological","technical","untreated","baseline","normal","versus","using","per","min","hrs","yrs","old","year",
 "gsm","gse","srr","srx","exp","run","lib","size","mapped","reads","count","counts")
tok <- function(s){ t<-unlist(strsplit(s,"[^a-z0-9]+")); t<-t[nchar(t)>=3 & !(t %in% boiler) & !grepl("^[0-9]+$",t)]; t }
namestem <- function(nm){ t<-unlist(strsplit(tolower(nm),"[^a-z0-9]+")); t<-t[nchar(t)>=4 & !(t%in%c("neoplasms","neoplasm","disease","syndrome","agents","carcinoma","cancer"))]; ifelse(nchar(t)>6,substr(t,1,6),t) }

R <- bind_rows(lapply(seq_len(nrow(B)), function(i){
  cid<-B$cluster_id[i]; nm<-B$canonical_name[i] %||% NA
  gsms<-gmap[[cid]]; present<-gsms[gsms %in% names(txt)]; if(length(present)<2) return(NULL)
  studies<-unique(ser[present]); ns<-length(studies)
  # per token: in quanti STUDI compare
  study_tokens<-lapply(studies, function(s){ g<-present[ser[present]==s]; unique(unlist(lapply(txt[g],tok))) })
  allt<-table(unlist(study_tokens)); cov<-sort(allt/ns, decreasing=TRUE)
  top<-head(cov,5); homog<-as.numeric(top[1])
  # name match: qualche stem del nome fra i token con copertura>=0.5?
  stems<-namestem(nm); hit<-any(sapply(stems, function(st) any(grepl(st, names(cov)[cov>=0.5]))))
  data.frame(cluster_id=cid,name=nm,kind=B$kind_effective_resolved[i],k=B$k[i],n_studies=ns,
    homog=round(homog,2), top_theme=paste(names(top),collapse=","), name_ok=isTRUE(hit), stringsAsFactors=FALSE)
}))
`%||%`<-function(a,b) if(is.null(a)||is.na(a)) b else a
E <- R %>% group_by(name) %>% slice_max(k,n=1,with_ties=FALSE) %>% ungroup()
E <- E %>% mutate(cls=case_when(
  kind %in% c("vehicle_only","none") ~ "vehicle/none",
  homog>=0.60 & name_ok ~ "OMOGENEO+ben_nominato",
  homog>=0.60 & !name_ok ~ "OMOGENEO+MAL_nominato",
  homog<0.60 ~ "ETEROGENEO(sospetto)"))
cat("===== ESTENSIONE CODA-NOME (197 entità Pop.B) =====\n")
print(E %>% count(cls) %>% arrange(desc(n)))
cat("\n--- OMOGENEO ma MAL nominato (meta-analisi vere sotto nome sbagliato): esempi ---\n")
print(E %>% filter(cls=="OMOGENEO+MAL_nominato") %>% arrange(desc(k)) %>% transmute(name=substr(name,1,26),k,homog,theme=substr(top_theme,1,42)) %>% head(20) %>% as.data.frame(), row.names=FALSE)
cat("\n--- ETEROGENEO (possibile minestrone vero): esempi ---\n")
print(E %>% filter(cls=="ETEROGENEO(sospetto)") %>% arrange(desc(k)) %>% transmute(name=substr(name,1,26),k,homog,theme=substr(top_theme,1,42)) %>% head(20) %>% as.data.frame(), row.names=FALSE)
cat("\n--- OMOGENEO+ben nominato: esempi ---\n")
print(E %>% filter(cls=="OMOGENEO+ben_nominato") %>% arrange(desc(k)) %>% transmute(name=substr(name,1,26),k,homog,theme=substr(top_theme,1,38)) %>% head(15) %>% as.data.frame(), row.names=FALSE)
write.csv(E,"/tmp/claude-1000/-home-user-simulomicsr/087652e0-525a-4100-ae1b-60fa251ac2f1/scratchpad/nametail.csv",row.names=FALSE)
