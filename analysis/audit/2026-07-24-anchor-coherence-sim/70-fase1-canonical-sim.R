Sys.setenv(OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1")
suppressPackageStartupMessages({library(arrow); library(dplyr)})
devtools::load_all(".", quiet=TRUE)
source("analysis/audit/2026-07-24-anchor-coherence-sim/contrast-sig-engine.R")
`%||%` <- function(a,b) if(is.null(a)||length(a)==0L) b else a
DIR <- "analysis/audit/2026-07-23-coherence"
SC  <- "analysis/audit/2026-07-24-anchor-coherence-sim"
t0 <- Sys.time()
cat(format(Sys.time()),"- carico dizionari ontologici...\n")
oe <- .load_ontology_dicts()
cat(format(Sys.time()),"- dicts OK (", round(as.numeric(difftime(Sys.time(),t0,units="secs"))),"s)\n")

pm <- read_parquet(file.path(DIR,"per-member-contrasts.parquet"))
cv <- readRDS(file.path(DIR,"cluster-verdicts.rds"))

## --- estrai i VALORI trattati delle chiavi che cambiano (raw, non stripped) ---
changed_treated_vals <- function(tfl, cfl){
  T <- .parse_fl_kv(tfl); C <- .parse_fl_kv(cfl)
  keys <- union(names(T), names(C)); out <- character(0)
  for(k in keys){
    tv <- if(k %in% names(T)) T[[k]] else ""
    cv2 <- if(k %in% names(C)) C[[k]] else ""
    if(!identical(.norm_val(tv), .norm_val(cv2)) && nzchar(trimws(tv)))
      out <- c(out, setNames(tv, .classify_key(k)))
  }
  out  # named vector: names=classe, values=valore trattato raw
}

## --- resolver per classe: prova candidati, ritorna primo ID canonico (non STR/NA) ---
resolve_by_class <- function(cls, candidates, oe){
  is_canon <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  try_one <- function(cand){
    if(is.na(cand)||!nzchar(trimws(cand))) return(NULL)
    if(cls=="drug"){
      r <- .normalize_compound_to_chebi(cand, oe); if(is_canon(r$id)) return(r)
      r <- .normalize_cytokine_to_hgnc(cand, oe);  if(is_canon(r$id)) return(r)
    } else if(cls=="infection"){
      r <- .normalize_pathogen_to_taxid(cand, oe); if(is_canon(r$id)) return(r)
    } else if(cls=="disease"){
      r <- .normalize_disease_to_mesh(cand, oe);   if(is_canon(r$id)) return(r)
    } else if(cls=="genetic"){
      h <- .hgnc_lookup_symbol(cand, env=oe)
      if(!is.null(h) && !is.null(h$hgnc_int)) return(list(id=paste0("HGNC:",h$hgnc_int), name=h$primary_symbol, source="HGNC"))
    }
    NULL
  }
  for(cand in candidates){ r <- try_one(cand); if(!is.null(r)) return(r) }
  list(id=NA_character_, name=NA_character_, source="UNRESOLVED")
}

## --- entita'-delta canonica per membro ---
canon_entity <- function(tlabel, tfl, cfl, oe){
  ct <- .normalize_control_type(cfl_lab <- NA)  # placeholder, ct calcolato fuori
  cv_vals <- changed_treated_vals(tfl, cfl)
  classes <- setdiff(unique(names(cv_vals)), "nuisance")
  if(length(classes)==0L) return(list(cls="<none>", id=NA_character_, name=NA_character_))
  pri <- c("genetic","drug","infection","disease","environment","time","other")
  cls <- pri[pri %in% classes][1]
  # candidati: valori trattati della classe dominante, poi il treated_label intero
  cand <- c(unname(cv_vals[names(cv_vals)==cls]), tlabel)
  r <- resolve_by_class(cls, cand, oe)
  # environment/time/other: nessun resolver -> usa valore normalizzato come STR
  if(is.na(r$id) && cls %in% c("environment","time","other")){
    v <- .norm_val(cv_vals[names(cv_vals)==cls][1]); r$id <- paste0("STR:", gsub(" ","_",v)); r$name <- v
  }
  list(cls=cls, id=r$id %||% NA_character_, name=r$name %||% NA_character_)
}

n <- nrow(pm)
cat(format(Sys.time()),"- canonicalizzo", n, "membri...\n")
ce_cls <- character(n); ce_id <- character(n); ce_name <- character(n)
tc <- Sys.time()
for(i in seq_len(n)){
  r <- canon_entity(pm$treated_label[i], pm$treated_fl[i], pm$control_fl[i], oe)
  ce_cls[i] <- r$cls; ce_id[i] <- r$id %||% NA_character_; ce_name[i] <- r$name %||% NA_character_
  if(i %% 5000 == 0) cat(sprintf("  %d/%d (%.0fs)\n", i, n, as.numeric(difftime(Sys.time(),tc,units="secs"))))
}
pm$ce_cls <- ce_cls; pm$ce_id <- ce_id; pm$ce_name <- ce_name
pm$ct <- vapply(seq_len(n), function(i) .normalize_control_type(pm$control_label[i]), "")
# degenere (drop): treated_fl == control_fl
pm$deg <- pm$treated_fl == pm$control_fl
saveRDS(pm, file.path(SC,"fase1-pm.rds"))
cat(format(Sys.time()),"- canonicalizzazione fatta, salvato fase1-pm.rds\n")

## ---------- MISURE ----------
# universo poolabile: escludi degeneri, classe <none>/nuisance, entita' non risolta STR
elig <- pm[!pm$deg & pm$ce_cls %in% c("drug","infection","disease","genetic") &
           !is.na(pm$ce_id) & !startsWith(pm$ce_id,"STR:"), ]
cat(sprintf("\nmembri eleggibili (non-deg, classe risolvibile, ID canonico): %d / %d\n", nrow(elig), n))

# CHIAVE CONTRASTO CANONICA (cross-cluster): (entita' canonica, control_type)
elig$ckey <- paste(elig$ce_id, elig$ct, sep="||")
agg <- elig |> group_by(ckey) |> summarise(k=n_distinct(study_id), n=n(),
         ent=ce_id[1], name=ce_name[1], cls=ce_cls[1], .groups="drop")
cat(sprintf("\n=== CANONICAL contrast-anchor (cross-cluster) ===\n"))
cat(sprintf("cluster-contrasto totali: %d | k>=2: %d | k>=3: %d | k>=5: %d\n",
    nrow(agg), sum(agg$k>=2), sum(agg$k>=3), sum(agg$k>=5)))
cat("distribuzione k (poolabili k>=3):\n"); print(summary(agg$k[agg$k>=3]))
cat("\nper classe (poolabili k>=3):\n")
print(agg[agg$k>=3,] |> group_by(cls) |> summarise(n=n(), k_med=median(k), k_max=max(k), .groups="drop"))

# CONFRONTO col LOWER BOUND (raw-label within-cluster, DC): 126 poolabili
cat(sprintf("\n=== vs LOWER BOUND di stanotte (DC raw within-cluster = 126 poolabili k>=3) ===\n"))
cat(sprintf("canonical cross-cluster poolabili k>=3: %d\n", sum(agg$k>=3)))

# SARS: deve tornare ~k=15 sotto NCBITaxon:2697049
cat("\n=== SARS (NCBITaxon:2697049) sotto anchor canonico ===\n")
sars <- agg[grepl("NCBITaxon:2697049", agg$ent),]
print(sars)

# I 26 coerenti attuali: sono preservati? (i loro membri finiscono in un cluster canonico k>=3?)
d184 <- cv[!is.na(cv$dd_verdict),]
coh <- d184$cluster_id[d184$contrast_verdict=="coherent"]
coh_members <- pm[pm$cluster_id %in% coh,]
coh_members$ckey <- paste(coh_members$ce_id, coh_members$ct, sep="||")
# per ogni cluster coerente: il suo ckey dominante ha k>=3 nell'universo canonico?
ckey_k <- setNames(agg$k, agg$ckey)
coh_summary <- coh_members |> filter(!deg & ce_cls %in% c("drug","infection","disease","genetic") & !is.na(ce_id) & !startsWith(ce_id,"STR:")) |>
  group_by(cluster_id) |> summarise(dom_ckey=names(sort(table(ckey),decreasing=TRUE))[1],
     n_ckey=n_distinct(ckey), .groups="drop")
coh_summary$dom_k <- ckey_k[coh_summary$dom_ckey]
cat(sprintf("\n=== NON-REGRESSIONE: dei %d cluster coerenti attuali ===\n", length(coh)))
cat("con membri eleggibili:", nrow(coh_summary), "\n")
cat("il cui contrasto canonico dominante ha k>=3 (preservato/rafforzato):",
    sum(coh_summary$dom_k>=3, na.rm=TRUE), "\n")
cat("che si spezzano in >1 ckey (frammentati dal canonico):", sum(coh_summary$n_ckey>1), "\n")
saveRDS(list(agg=agg, coh_summary=coh_summary), file.path(SC,"fase1-results.rds"))
cat("\nsalvato fase1-results.rds\n")
cat(format(Sys.time()),"- FASE 1 FINITA (", round(as.numeric(difftime(Sys.time(),t0,units="mins")),1),"min)\n")
