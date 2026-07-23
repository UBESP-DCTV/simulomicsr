# Engine per la firma di CONTRASTO per-membro + simulazione di re-partition.
# Riusa i contrasti gia' ricostruiti (per-member-contrasts.parquet). NON re-cluster.
#
# Idea: il contrasto di un membro = ciò che il confronto ISOLA = il DELTA tra i
# factor_levels del trattato e del controllo. Codifichiamo:
#   - ct           : classe del controllo (.normalize_control_type esistente)
#   - delta_class  : insieme delle CLASSI semantiche delle chiavi che cambiano T<->C
#                    (drug/infection/genetic/disease/diet/time). = "cosa cambia".
#   - delta_entity : per la classe disease, l'entita' malattia specifica normalizzata
#                    del trattato (granularita' mancante nell'anchor coarse).
#
# La firma del contrasto = (delta_class principale, delta_entity) e serve a re-partizionare
# ogni cluster in sotto-cluster coerenti PER COSTRUZIONE, poi si misura la coerenza.

# ---- parsing factor_levels "k=v;k=v" ----
.parse_fl_kv <- function(s){
  if(is.na(s)||!nzchar(s)) return(character(0))
  parts <- strsplit(s,";",fixed=TRUE)[[1]]
  keys <- character(length(parts)); vals <- character(length(parts))
  for(i in seq_along(parts)){
    p <- parts[i]; j <- regexpr("=", p)
    if(j>0){ keys[i] <- substr(p,1,j-1); vals[i] <- substr(p,j+1,nchar(p)) }
    else   { keys[i] <- p; vals[i] <- "" }
  }
  setNames(vals, tolower(trimws(keys)))
}

.norm_val <- function(x){
  x <- tolower(trimws(x))
  x <- gsub("\\b\\d+(\\.\\d+)?\\s?(nm|um|µm|mm|mg|ng|ug|µg|%|h|hr|hrs|hpi|dpi|day|days|d|week|weeks|min|moi|pfu|ml)\\b"," ",x, perl=TRUE)
  x <- gsub("\\b\\d+(\\.\\d+)?\\b"," ",x)
  x <- gsub("[^a-z ]+"," ",x)
  trimws(gsub("\\s+"," ",x))
}

# ---- classificatore chiave -> classe semantica del contrasto ----
# nuisance = covariate identitarie che NON definiscono un contrasto biologico.
.NUISANCE_KEYS <- c("donor","donor_id","patient","subject","individual","age","sex",
  "gender","ancestry","ancestry_or_population","ethnicity","race","population",
  "replicate","batch","rep","biological_replicate","technical_replicate",
  "cell_line","cell_type","cell_type_or_line_raw","cell_context",
  "cell_context.cell_type_or_line_raw","tissue","tissue_type","tissue_segment",
  "tissue_source","cell_source","context_kind","passage","passage_or_state",
  "cell line","cell_state","id","sample_id","geo_accession","name","title")

.classify_key <- function(k){
  k <- tolower(trimws(k))
  if(k %in% .NUISANCE_KEYS) return("nuisance")
  # ordine di priorita': genetic > drug > infection > disease > diet/env > time
  if(grepl("genet|genotype|transgene|knock|sirna|shrna|sgrna|crispr|mutat|mutant|overexpress|engineer|guide|vector|construct|allele|\\boe\\b|perturbation_type|gene", k)) return("genetic")
  if(grepl("treat|drug|compound|dose|concentr|perturbation|exposure|agent|stimul|ligand|inhibitor|cytokine|small_molecule|molecule|chemical|smallmolecule", k)) return("drug")
  if(grepl("infect|virus|viral|pathogen|bacteri|\\bmoi\\b|inocul|vaccin", k)) return("infection")
  if(grepl("disease|diagnos|clinical|tumor|tumour|cancer|malign|severity|grade|patholog|condition|response|remission|\\bstage\\b|status|phenotype|subtype", k)) return("disease")
  if(grepl("diet|hypox|oxygen|normox|glucose|fasting|temperature|irradiat|radiat|starv|nutrient|media|medium|serum", k)) return("environment")
  if(grepl("time|timepoint|time_point|duration|hour|\\bday\\b|week|developmental|differentiat", k)) return("time")
  "other"
}

# ---- delta di un membro: classi che cambiano + entita' della classe dominante ----
# ritorna list(classes=chr set senza nuisance, dominant=chr1, entity=chr1)
.member_contrast <- function(tfl, cfl){
  T <- .parse_fl_kv(tfl); C <- .parse_fl_kv(cfl)
  keys <- union(names(T), names(C))
  changed <- character(0); entity_by_class <- list()
  for(k in keys){
    tv <- .norm_val(if(k %in% names(T)) T[[k]] else "")
    cv <- .norm_val(if(k %in% names(C)) C[[k]] else "")
    if(!identical(tv,cv)){
      cls <- .classify_key(k)
      changed <- c(changed, cls)
      # entita' = valore trattato normalizzato (per granularita' disease/drug)
      if(nzchar(tv)) entity_by_class[[cls]] <- c(entity_by_class[[cls]], tv)
    }
  }
  changed_nn <- setdiff(unique(changed), "nuisance")
  if(length(changed_nn)==0){
    # solo nuisance cambia -> contrasto identitario (disease case-control mascherato)
    # o degenere. Usa 'nuisance' come classe.
    dominant <- if(length(changed)) "nuisance" else "<none>"
    return(list(classes="<nuisance>", dominant=dominant, entity=""))
  }
  # priorita' per la classe dominante
  pri <- c("genetic","drug","infection","disease","environment","time","other")
  dominant <- pri[pri %in% changed_nn][1]
  ent <- entity_by_class[[dominant]]
  ent <- if(length(ent)) paste(sort(unique(ent)), collapse=" ") else ""
  list(classes=paste(sort(changed_nn), collapse="+"), dominant=dominant, entity=ent)
}
