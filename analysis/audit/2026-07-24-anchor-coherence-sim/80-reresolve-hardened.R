# Ri-risoluzione dell'entita'-delta con CANDIDATI BLINDATI.
#
# Perche': la risoluzione di 70- passava al resolver (i) il treated_label INTERO
# (che contiene tipo cellulare, paziente, tempo -> "CD8 T cells..." => CD8A) e
# (ii) stringhe con unita' di dose ("GO 1 ug/ml" -> candidato "/ml" -> ImmPort
# sinonimo ML -> THPO). Entrambe producono entita' che NON sono la perturbazione.
#
# Regola: si risolve SOLO cio' che cambia tra trattato e controllo (il delta),
# ripulito da dosi/unita'/tempi, e mai il label intero. Deterministico.
#
# Output: fase1-pm2.rds = pm + ce2_id/ce2_name/ce2_cls/ce2_cand (+ delta raw).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
source(file.path(SC, "contrast-sig-engine.R"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

pm <- readRDS(file.path(SC, "fase1-pm.rds"))
cv <- readRDS("analysis/audit/2026-07-23-coherence/cluster-verdicts.rds")
pm <- merge(pm, cv[, c("cluster_id", "canonical_name")], by = "cluster_id", all.x = TRUE)
oe <- .load_ontology_dicts()

## ---- unita' di misura e parole non-entita' (mai candidati) ----
UNITS <- c("ml","ul","dl","l","ug","mg","ng","pg","kg","g","nm","um","mm","pm","cm","mol",
           "mmol","umol","nmol","moi","pfu","ffu","tcid","iu","hr","hrs","min","sec","h","d",
           "day","days","week","weeks","wk","month","months","hour","hours","hpi","dpi","rpm",
           "per","dose","doses","conc","final","approx","total","fold","percent")
NONENT <- c("none","control","controls","vehicle","untreated","treated","treatment","treatments",
            "mock","naive","baseline","normal","healthy","wildtype","wild","type","sample","samples",
            "patient","patients","case","cases","donor","donors","group","groups","condition",
            "conditions","cells","cell","tissue","line","lines","culture","cultured","medium","media",
            "experiment","replicate","replicates","therapy","therapies","after","before","post","pre",
            "with","without","from","the","and","for","anti","plus","versus","status","state","level",
            "levels","number","stage","grade","score","high","low","early","late","acute","chronic",
            "unknown","other","test","exposure","exposed","stimulated","infected","biopsy","blood",
            "serum","plasma","primary","secondary","human","male","female")

strip_units <- function(x) {
  x <- tolower(trimws(x))
  # dose/tempo: numero + unita'
  x <- gsub("\\b\\d+([.,]\\d+)?\\s*(ug|mg|ng|pg|kg|g|ul|ml|dl|l|nm|um|mm|pm|mol|mmol|umol|nmol|iu|moi|pfu|ffu|%)\\s*(/\\s*(ml|l|kg|g|ul))?\\b", " ", x, perl = TRUE)
  x <- gsub("\\b\\d+([.,]\\d+)?\\s*(h|hr|hrs|hour|hours|d|day|days|week|weeks|wk|min|sec|hpi|dpi)\\b", " ", x, perl = TRUE)
  x <- gsub("\\b(ug|mg|ng|pg|kg|ul|ml|dl|nm|um|mm|iu|moi|pfu|ffu)\\s*/\\s*(ml|l|kg|g|ul|min)\\b", " ", x, perl = TRUE)
  x <- gsub("[/\\\\]", " ", x)                       # separatori residui
  # numeri isolati SOLO fra spazi: "\\b\\d+\\b" distruggeva "sars-cov-2" -> "sars-cov"
  # (= SARS-CoV 2003, NCBITaxon:694009) e ogni nome con suffisso numerico (IL-6, MCF-7).
  x <- gsub("(^|\\s)\\d+([.,]\\d+)?(?=\\s|$)", " ", x, perl = TRUE)
  trimws(gsub("\\s+", " ", x))
}
is_unit_or_nonent <- function(tok) {
  t <- tolower(trimws(tok))
  t <- gsub("[^a-z0-9+-]", "", t)
  if (!nzchar(t)) return(TRUE)
  if (t %in% UNITS || t %in% NONENT) return(TRUE)
  if (!grepl("[a-z]", t)) return(TRUE)               # solo cifre
  if (nchar(t) < 3) return(TRUE)                     # sotto 3 char: mai (ml, go, us)
  FALSE
}

## Sanitizza una frase: toglie dosi/unita' E i token-unita' residui, altrimenti il
## resolver di produzione ri-estrae sotto-candidati sporchi ("ug/ml" -> "/ml" ->
## sinonimo ImmPort "ML" -> THPO).
## NB: si tolgono SOLO i token-unita'. Tagliare anche i token corti spezzerebbe i
## nomi veri ("SARS CoV 2" -> "sars cov", "IL 6" -> "il"): il filtro a >=3 char
## vale per i candidati-token isolati, non per la frase.
sanitize_phrase <- function(x) {
  s <- strip_units(x)
  w <- strsplit(s, "[^a-z0-9+-]+")[[1]]
  w <- w[nzchar(w) & !(w %in% UNITS)]
  trimws(paste(w, collapse = " "))
}

## candidati = il delta della classe dominante, sanitizzato.
## Il treated_label INTERO e' ammesso solo per classi dove il nome sta spesso solo
## nel label (infezione/malattia/genetico) e non per `drug`, dove e' la fonte
## documentata di entita' spurie (CD8 T cells -> CD8A).
build_candidates <- function(vals, tlabel = NA_character_, cls = NA_character_) {
  out <- character(0)
  for (v in vals) {
    if (is.na(v) || !nzchar(trimws(v))) next
    s <- sanitize_phrase(v)
    if (nzchar(s) && !is_unit_or_nonent(s)) out <- c(out, s)
    for (p in strsplit(s, "[,;+&]| and | plus | with ")[[1]]) {
      p <- trimws(p)
      if (nzchar(p) && !is_unit_or_nonent(p)) out <- c(out, p)
    }
    for (tk in strsplit(s, "[^a-z0-9-]+")[[1]]) if (!is_unit_or_nonent(tk)) out <- c(out, tk)
  }
  if (!is.na(cls) && cls %in% c("infection", "disease", "genetic") && !is.na(tlabel)) {
    s <- sanitize_phrase(tlabel)
    if (nzchar(s) && !is_unit_or_nonent(s)) out <- c(out, s)
  }
  unique(out[nzchar(out)])
}

## Guardia acronimi: le tabelle di sinonimi (ImmPort) contengono sigle di 2-3
## lettere che collidono col gergo sperimentale — "ML" (unita' di volume) e'
## sinonimo di THPO, "HGI" (high glucose incubation) risolve a IL6. Per un
## candidato corto si accetta SOLO se coincide col simbolo/nome risolto.
.alnum <- function(x) gsub("[^a-z0-9]", "", tolower(x))
acronym_ok <- function(cand, name) {
  a <- .alnum(cand)
  if (nchar(a) > 4) return(TRUE)
  !is.na(name) && nzchar(name) && identical(a, .alnum(name))
}
## cand_raw = valori grezzi (servono a ChEBI: gli alias hanno punteggiatura,
## "poly(I:C)" NON e' "poly i c"); cand_clean = sanitizzati (per i rami con
## sinonimi rumorosi).
resolve_by_class <- function(cls, cand_raw, cand_clean, oe) {
  is_canon <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  hit <- function(r, cand) c(r, list(cand = cand))
  if (cls == "drug") {
    for (cand in unique(c(cand_raw, cand_clean))) {
      r <- .normalize_compound_to_chebi(cand, oe)
      if (is_canon(r$id)) return(hit(r, cand))
    }
    for (cand in cand_clean) {
      r <- .normalize_cytokine_to_hgnc(cand, oe)
      if (is_canon(r$id) && acronym_ok(cand, r$name)) return(hit(r, cand))
    }
    # la classe viene dal NOME della chiave (`treatment` -> drug): se il valore e'
    # un patogeno ("SARS-CoV-2 Omicron"), il ramo drug non lo vede. Fallback.
    for (cand in unique(c(cand_raw, cand_clean))) {
      r <- .normalize_pathogen_to_taxid(cand, oe)
      if (is_canon(r$id) && acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (cls == "infection") {
    for (cand in unique(c(cand_raw, cand_clean))) {
      r <- .normalize_pathogen_to_taxid(cand, oe)
      if (is_canon(r$id) && acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (cls == "disease") {
    for (cand in unique(c(cand_raw, cand_clean))) {
      r <- .normalize_disease_to_mesh(cand, oe)
      if (is_canon(r$id) && acronym_ok(cand, r$name)) return(hit(r, cand))
    }
  } else if (cls == "genetic") {
    for (cand in cand_clean) {
      h <- .hgnc_lookup_symbol(cand, env = oe)
      if (!is.null(h) && !is.null(h$hgnc_int))
        return(hit(list(id = paste0("HGNC:", h$hgnc_int), name = h$primary_symbol, source = "HGNC"), cand))
    }
  }
  list(id = NA_character_, name = NA_character_, source = "UNRESOLVED", cand = NA_character_)
}

## delta grezzo (valori che cambiano T<->C, senza nuisance)
delta_raw <- function(tfl, cfl) {
  T <- .parse_fl_kv(tfl); C <- .parse_fl_kv(cfl); keys <- union(names(T), names(C))
  tv <- character(0); cvv <- character(0); cls <- character(0); ks <- character(0)
  for (k in keys) {
    a <- if (k %in% names(T)) T[[k]] else ""
    b <- if (k %in% names(C)) C[[k]] else ""
    if (!identical(.norm_val(a), .norm_val(b)) && .classify_key(k) != "nuisance") {
      tv <- c(tv, a); cvv <- c(cvv, b); cls <- c(cls, .classify_key(k)); ks <- c(ks, k)
    }
  }
  list(tval = tv, cval = cvv, classes = cls, keys = ks)
}

n <- nrow(pm)
cat(format(Sys.time()), "- ri-risolvo", n, "membri con candidati blindati...\n")
ce2_id <- rep(NA_character_, n); ce2_nm <- rep(NA_character_, n)
ce2_cls <- rep(NA_character_, n); ce2_cand <- rep(NA_character_, n)
tval_j <- rep("", n); cval_j <- rep("", n); cls_j <- rep("", n)
t0 <- Sys.time()
PRI <- c("genetic", "drug", "infection", "disease", "environment", "time", "other")
for (i in seq_len(n)) {
  d <- delta_raw(pm$treated_fl[i], pm$control_fl[i])
  tval_j[i] <- paste(d$tval, collapse = " | ")
  cval_j[i] <- paste(d$cval, collapse = " | ")
  cls_j[i]  <- paste(sort(unique(d$classes)), collapse = "+")
  if (length(d$classes) == 0L) next
  cls <- PRI[PRI %in% d$classes][1]; ce2_cls[i] <- cls
  vals <- d$tval[d$classes == cls]
  cand <- build_candidates(vals, pm$treated_label[i], cls)
  raw <- trimws(tolower(vals)); raw <- raw[nzchar(raw)]
  if (!length(cand) && !length(raw)) next
  r <- resolve_by_class(cls, raw, cand, oe)
  ce2_id[i] <- r$id %||% NA_character_; ce2_nm[i] <- r$name %||% NA_character_
  ce2_cand[i] <- r$cand %||% NA_character_
  if (i %% 5000 == 0) cat(sprintf("  %d/%d (%.0fs)\n", i, n, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
pm$ce2_id <- ce2_id; pm$ce2_name <- ce2_nm; pm$ce2_cls <- ce2_cls; pm$ce2_cand <- ce2_cand
pm$dtval <- tval_j; pm$dcval <- cval_j; pm$dclasses <- cls_j
saveRDS(pm, file.path(SC, "fase1-pm2.rds"))

cat("\n=== confronto risoluzione v6 (ce_id) vs blindata (ce2_id) ===\n")
canon <- function(x) !is.na(x) & nzchar(x) & !startsWith(x, "STR:")
cat(sprintf("ID canonici: prima %d, ora %d\n", sum(canon(pm$ce_id)), sum(canon(pm$ce2_id))))
cat(sprintf("THPO (HGNC:11795) da unita' ug/ml : prima %d membri, ora %d\n",
            sum(pm$ce_id == "HGNC:11795", na.rm = TRUE), sum(pm$ce2_id == "HGNC:11795", na.rm = TRUE)))
cat(sprintf("CD8A (HGNC:1706) da label intero  : prima %d membri, ora %d\n",
            sum(pm$ce_id == "HGNC:1706", na.rm = TRUE), sum(pm$ce2_id == "HGNC:1706", na.rm = TRUE)))
cat("\ncontrolli di NON-REGRESSIONE su entita' vere:\n")
for (E in c("CHEBI:16412", "CHEBI:16330", "CHEBI:63637", "CHEBI:68534", "NCBITaxon:2697049")) {
  cat(sprintf("  %-18s prima %4d -> ora %4d membri\n", E,
              sum(pm$ce_id == E, na.rm = TRUE), sum(pm$ce2_id == E, na.rm = TRUE)))
}
cat(format(Sys.time()), "- fatto, salvato fase1-pm2.rds\n")
