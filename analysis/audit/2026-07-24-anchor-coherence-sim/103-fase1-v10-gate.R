# GATE v10 — v9 + SCARTO DELLE RIGHE MAL APPAIATE (regole di riga).
#
# Decisione utente 2026-07-25: le righe mal appaiate dentro i gruppi coerenti si
# scartano, accettando di perdere i gruppi che scendono sotto i 3 studi. Le
# quattro regole vivono in regole-riga.R (tempo non appaiato, controllo di
# linea/donatore diverso, combinazione non vista, genetica su un braccio solo) e
# si applicano al MEMBRO, come gia' fa "contrasto_rotto".
#
# Sotto: il gate v9, invariato.
#
# GATE v8 — v7 + SCARTO DETERMINISTICO del residuo incoerente.
#
# Decisione utente 2026-07-25: gli 11 cluster incoerenti residui non sono
# recuperabili -> si scartano. Ma NON con una lista di chiavi scritta a mano (non
# sarebbe pubblicabile): con regole generali che descrivono la CAUSA misurata.
#   v8a co-infezione/combo: la soglia dei 3 caratteri va sulla PARTE, non sui
#       token ("M.tb + CMV" non veniva visto); la virgola separa agenti.
#   v8b infezione clinica vs sperimentale decisa sul TRATTATO (viremia,
#       carcinoma, paziente) e non solo sul controllo.
#   v8c controllo che non e' un controllo ("total RNA", "input").
#   v8d stato di resistenza presente su un solo braccio.
#   v8e delta che muove >=2 classi perturbative (malattia+farmaco, ...):
#       non isola una cosa sola.
#
# Sotto: le regole v7, invariate.
#
# Rispetto a v6 (81% coerente su TUTTI), sette regole, tutte DETERMINISTICHE e
# tutte derivate dall'ispezione dei falliti veri (78-inspect-failures.R):
#
#  R1 on-contrast a PAROLA INTERA su token DISTINTIVI (no anatomia/generici).
#     -> "lung adenocarcinoma" non inghiotte piu' "SSc lung fibroblasts";
#        "heat shock" non inghiotte "HEATed tobacco".
#  R2 entita' del cluster CANONICALIZZATA (stesso spazio-ID degli off-contrast)
#     -> NAME e onto non si frammentano piu' sullo stesso oggetto biologico.
#  R3 VERSO del delta nella chiave (gain / loss / block); verso ambiguo = SCARTO
#     (decisione utente 2026-07-25) -> glucosio depriv-vs-agg, androgeno
#     agonista-vs-degrader, estrogeno, TNF inib-vs-stim.
#  R4 COMBO = entita' a se' con la SUA composizione (COMBO:a+b), separatori
#     + / _ & "and" "plus"; non piu' un bucket "+COMBO" che lumpa combo diverse.
#  R5 MATERIALE del contrasto (liquido vs no) su ENTRAMBI i bracci -> HCC
#     tessuto-vs-plasma, liver_cancer, lung-adeno-plasma.
#  R6 BASELINE PROPRIA (longitudinale) separata dal controllo trasversale
#     -> artrite reumatoide settimane-vs-baseline, heart failure baseline.
#  R7 RIPULITURA per-membro: contrasto rotto (anatomia dei due bracci disgiunta)
#     -> heart failure vs "Baseline Kidney".
#  + gate generico esteso (connettori strippati, "biopsy" non e' entita').
#
# Input: fase1-pm2.rds (risoluzione blindata, script 80).
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
source(file.path(SC, "contrast-sig-engine.R"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
source(file.path(SC, "regole-riga.R"))     # v10: scarto delle righe mal appaiate
pm <- readRDS(file.path(SC, "fase1-pm2.rds"))
oe <- .load_ontology_dicts()

## v10 — verdetto di riga, memorizzato per (trattato, controllo, classe, entita'):
## le stesse coppie di etichette ricorrono su molti membri.
.rr_cache_tok <- new.env(parent = emptyenv())
.rr_cache_row <- new.env(parent = emptyenv())
difetto_riga <- function(tl, cl, cls, ent, extra_stop) {
  k <- paste(tl, cl, cls, ent, sep = "\r")
  if (exists(k, envir = .rr_cache_row, inherits = FALSE)) return(get(k, envir = .rr_cache_row))
  v <- rr_difetto_riga(tl, cl, cls, ent, oe, .rr_cache_tok, extra_stop)
  assign(k, v, envir = .rr_cache_row); v
}
## i token del nome dell'entita' non sono identificatori di linea ("R1881",
## "AD169" appartengono al nome del composto o del ceppo)
tok_entita <- function(...) {
  s <- tolower(paste(stats::na.omit(c(...)), collapse = " "))
  t <- strsplit(gsub("[^a-z0-9 -]+", " ", s), " +")[[1]]
  unique(t[nzchar(t)])
}

## ============================ vocabolari ====================================
GENERIC <- c("none","control","controls","vehicle","untreated","treated","treatment","treatments",
  "dmso","pbs","saline","mock","naive","baseline","normal","healthy","wildtype","wt","ko","knockout",
  "knockdown","overexpression","overexpressed","genetic","genetic_knockdown","genetic_overexpression",
  "genetic_modification","sirna","shrna","sgrna","crispr","transfection","transfected","transduced",
  "infected","infection","exposed","exposure","stimulated","stimulation","condition","conditions",
  "sample","samples","patient","patients","case","cases","disease","drug","compound","agent","stimulus",
  "perturbation","perturbations","treatment_group","group","other","unknown","unclear","na","test",
  "experiment","combination","combo","induced","inducible","expression","cells","cell","tissue","line",
  "type","status","state","high","low","positive","negative","present","absent","mutant","post","pre",
  "on","off","early","late","responder","nonresponder","non","sensitive","resistant","primary",
  "recurrent","chemotherapy","differentiation","differentiated","environmental","behavioral","transgene",
  "stable","up","down","yes","no","before","after","day","week","month","stage","grade","level","score",
  "activated","resting","treated_group","poly","mrna","rna","dna","organic","cation","anion","steroid",
  "steroids","small","molecule","molecules","vector","empty","parental","derived",
  # v7: aggiunte misurate sui falliti
  "biopsy","biopsies","specimen","therapy","therapies","challenge","prechallenge","placebo","dose",
  "doses","concentration","timepoint","time","duration","subject","subjects","volunteer","volunteers",
  "cohort","arm","visit","week0","baselines","standard","conventional","usual",
  # v7b: emerse dal censimento (entita' che non sono entita')
  "only","alone","viral","virus","bacterial","infectious","car","carrier","construct","plasmid",
  # v10: termini-ombrello di malattia. Servono qui perche' il resolver, quando
  # la guardia blocca "tumor"->MeSH:Neoplasms, ripiega su STR:tumor: senza
  # questa riga diventerebbe un'entita' e rifarebbe il minestrone (k=19).
  "tumor","tumors","tumour","tumours","cancer","cancers","neoplasm","neoplasms","neoplasia",
  "carcinoma","carcinomas","malignant","malignancy","metastasis","metastatic","adenocarcinoma",
  "overexpressed","knockdowns","mutation","mutations","variant","variants","genotype","phenotype")
CONNECTORS <- c("or","and","of","the","with","without","vs","versus","for","from","to","in","at","by",
  "a","an","de","del","per","plus","its")
INDUCERS <- c("doxycycline","dox","doxy","tetracycline","tet","iptg","auxin","iaa","blasticidin",
  "puromycin","g418","geneticin","hygromycin","cumate")
UMBRELLA_NAME_RX <- paste0("^(neoplasms?|carcinomas?|adenocarcinomas?|tumou?rs?|cancers?|inflammation|",
  "infections?|disease|diseases|leukemi\\w*|lymphoma|sarcoma|lesional|non-small|small molecule|",
  "organic cation|steroid|androgens?|estrogens?|cytokines?|chemokines?|hormones?|antibiotics?|",
  # v7b: termini-classe emersi dal censimento
  "syndrome|syndromes|arteries|artery|cardiomyopathies|fibrosis|vector|vectors)$")
BLACKLIST_ID <- c("MeSH:D009369","MeSH:D009361","MeSH:D002277","MeSH:D004194","MeSH:D007239","MeSH:D007249",
  "MeSH:D009371","CHEBI:17499","CHEBI:24431","CHEBI:23367","CHEBI:33232","CHEBI:50906",
  "CHEBI:50845","CHEBI:28262","CHEBI:25367","CHEBI:35341","CHEBI:33699","CHEBI:84123","CHEBI:16236",
  "CHEBI:197439")  # v7c: "Recombinant TNF alpha (Zebrafish)" — ID di specie sbagliata per TNF umano
# anatomia: non e' MAI un token distintivo di identita' (serve a R1 e a R7)
ANATOMY <- c("lung","lungs","liver","hepatic","kidney","renal","heart","cardiac","myocardium","brain",
  "cerebral","neural","colon","colorectal","rectum","intestine","ileum","gastric","stomach","breast",
  "mammary","prostate","ovary","ovarian","uterus","uterine","testis","testicular","pancreas",
  "pancreatic","spleen","thymus","thyroid","skin","cutaneous","dermal","epidermis","blood","plasma",
  "serum","bone","marrow","muscle","skeletal","placenta","retina","cornea","bladder","esophagus",
  "esophageal","oral","nasal","airway","bronchial","alveolar","synovial","adipose","aorta","artery",
  "vein","lymph","node","nodes","cervix","cervical","head","neck","tongue","salivary","pituitary",
  "adrenal","gallbladder","bile","duodenum","jejunum","tonsil","gingival","periodontal")

is_generic_tok <- function(tok) {
  if (is.na(tok) || !nzchar(tok)) return(TRUE)
  t <- tolower(trimws(tok))
  if (nchar(gsub("[^a-z0-9]", "", t)) < 4) return(TRUE)
  if (!grepl("[a-z]", t)) return(TRUE)
  w <- strsplit(t, "[^a-z0-9]+")[[1]]; w <- w[nzchar(w)]
  w <- setdiff(w, CONNECTORS)                    # v7: i connettori non salvano una stringa generica
  if (length(w) == 0L) return(TRUE)
  if (all(w %in% GENERIC)) return(TRUE)
  FALSE
}
is_inducer_name <- function(x) {
  if (is.na(x)) return(FALSE)
  any(vapply(INDUCERS, function(z) grepl(paste0("\\b", z, "\\b"), tolower(x)), logical(1)))
}
clean_tok <- function(x) {
  x <- tolower(trimws(x)); x <- gsub("[^a-z ]+", " ", x)
  x <- gsub(paste0("\\b(patient|patients|case|cases|control|controls|healthy|donor|donors|sample|samples|",
                   "primary|culture|cell|cells|from|the|and|of|with|vs|total|rna|tissue|line|human|treated|",
                   "treatment|stimulated|infected|exposed|day|days|hour|hours|hr|hrs)\\b"), " ", x)
  trimws(gsub("\\s+", " ", x))
}

## ============================ R3 — VERSO =====================================
LOSS_RX  <- paste0("deprivat|depleti|starv|withdraw|removal|removed|restrict|fasting|\\bno\\b|\\bnon-|",
  "without|[a-z]-free\\b|\\bfree (medium|media)|absence|\\bloss\\b|silenc|",
  "\\blow\\b|reduced|decreas")   # v7b: "calcium_low" vs "calcium_high" era un verso opposto non visto
BLOCK_RX <- paste0("inhibitor|inhibiti|antagonist|blockade|blocking|blocker|neutraliz|degrader|protac|",
  "knockdown|knockout|\\bko\\b|\\bshrna|\\bsirna|\\bsgrna|crispr|deficien|\\bnull\\b|\\banti-[a-z0-9]")
GAIN_RX  <- "addition|added|supplement|agonist|overexpress|\\bhigh\\b|stimulat|activation|induction|\\bplus\\b"
verso_of <- function(tval) {
  # "_" e' un carattere di PAROLA per \\b: in "calcium_low" il marcatore di verso
  # non veniva visto. Si normalizzano i separatori prima di cercare i marcatori.
  s <- gsub("[_/|]+", " ", tolower(paste(tval, collapse = " ")))
  if (!nzchar(trimws(s))) return("gain")
  loss <- grepl(LOSS_RX, s, perl = TRUE)
  blk  <- grepl(BLOCK_RX, s, perl = TRUE)
  gain <- grepl(GAIN_RX, s, perl = TRUE)
  if (loss && gain) return("ambiguo")            # verso non determinabile -> SCARTO
  if (loss) return("loss")
  if (blk)  return("block")
  "gain"                                          # agente presente nel trattato, assente nel controllo
}

## ============================ R4 — COMBO =====================================
drop_doses <- function(x) {
  x <- tolower(paste(x, collapse = " "))
  x <- gsub("\\b\\d+([.,]\\d+)?\\s*(ug|mg|ng|pg|kg|g|ul|ml|dl|l|nm|um|mm|pm|iu|moi|pfu|ffu|%)\\s*(/\\s*(ml|l|kg|g|ul))?", " ", x, perl = TRUE)
  x <- gsub("\\b\\d+([.,]\\d+)?\\s*(h|hr|hrs|hour|hours|d|day|days|week|weeks|min|hpi|dpi)\\b", " ", x, perl = TRUE)
  x <- gsub("\\b(ug|mg|ng|kg|ul|ml|nm|um|iu|moi|pfu)\\s*/\\s*(ml|l|kg|g|ul|min)\\b", " ", x, perl = TRUE)
  trimws(gsub("\\s+", " ", x))
}
## un agente e' "vero" se risolve a un ID canonico (non basta essere informativo:
## "MOI", "Contact", "053" sono informativi ma non sono agenti).
.agent_cache <- new.env(parent = emptyenv())
resolves_to_agent <- function(p) {
  p <- trimws(p); if (!nzchar(p) || nchar(p) < 3) return(FALSE)
  if (exists(p, envir = .agent_cache, inherits = FALSE)) return(get(p, envir = .agent_cache))
  ok <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  r <- ok(.normalize_compound_to_chebi(p, oe)$id) ||
       ok(.normalize_cytokine_to_hgnc(p, oe)$id) ||
       ok(.normalize_pathogen_to_taxid(p, oe)$id) ||
       (!is.null(.hgnc_lookup_symbol(sub("^(sh|si|sg)", "", p), env = oe)))
  assign(p, r, envir = .agent_cache); r
}
## v8: la soglia va sui caratteri ALFANUMERICI DELLA PARTE, non su ogni token:
## "M.tb" e' fatto di token da 1 e 2 caratteri e veniva buttato, per cui la
## co-infezione "M.tb + CMV" non veniva vista come combinazione.
norm_part <- function(p) {
  w <- strsplit(gsub("[^a-z0-9 -]", " ", p), "[^a-z0-9-]+")[[1]]
  w <- w[nzchar(w) & !(w %in% GENERIC) & !(w %in% CONNECTORS)]
  s <- paste(w, collapse = " ")
  if (nchar(gsub("[^a-z0-9]", "", s)) >= 3) s else ""
}
## ID dell'agente contenuto in una parte (whole-part o singolo token)
.aid_cache <- new.env(parent = emptyenv())
agent_id_of <- function(p) {
  p <- trimws(p); if (!nzchar(p)) return("")
  if (exists(p, envir = .aid_cache, inherits = FALSE)) return(get(p, envir = .aid_cache))
  ok <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  res <- ""
  for (cand in unique(c(p, strsplit(p, " ")[[1]]))) {
    if (nchar(cand) < 3) next
    r <- .normalize_compound_to_chebi(cand, oe); if (ok(r$id)) { res <- r$id; break }
    r <- .normalize_cytokine_to_hgnc(cand, oe);  if (ok(r$id) && nchar(cand) > 4) { res <- r$id; break }
    r <- .normalize_pathogen_to_taxid(cand, oe); if (ok(r$id) && nchar(cand) > 4) { res <- r$id; break }
    h <- .hgnc_lookup_symbol(sub("^(sh|si|sg)", "", cand), env = oe)
    if (!is.null(h) && !is.null(h$hgnc_int) && nchar(cand) > 3) { res <- paste0("HGNC:", h$hgnc_int); break }
  }
  assign(p, res, envir = .aid_cache); res
}
## Combo dal LABEL: molte combinazioni stanno nel label e NON nel delta
## (misurato: "Estradiol and Fulvestrant", "Bleomycin/Alpha-Lipoic Acid",
## "Palbociclib and Indisulam"). Si contano solo gli agenti ASSENTI dal controllo:
## cosi' "SARS-CoV-2 + Ruxolitinib vs SARS-CoV-2" resta un contrasto su ruxolitinib.
## v9: si contano gli AGENTI (token che risolvono a un ID canonico) presenti nel
## braccio trattato e ASSENTI dal controllo. Non serve un separatore: "M1
## macrophage GMCSF INFG activated" e' una combinazione anche senza "+".
## Restano fuori i casi in cui l'agente sta su entrambi i lati (e' held-constant,
## non fa parte del delta): "SARS-CoV-2 + Ruxolitinib vs SARS-CoV-2" = ruxolitinib.
agents_of_label <- function(lab) {
  s <- drop_doses(lab)
  toks <- strsplit(gsub("[^a-z0-9 -]", " ", s), "[^a-z0-9-]+")[[1]]
  toks <- toks[nzchar(toks) & nchar(gsub("[^a-z0-9]", "", toks)) >= 3 &
                 !(toks %in% GENERIC) & !(toks %in% CONNECTORS)]
  ids <- character(0); nms <- character(0)
  for (tk in unique(toks)) {
    a <- agent_id_of(tk)
    if (nzchar(a)) { ids <- c(ids, a); nms <- c(nms, tk) }
  }
  stats::setNames(ids, nms)
}
combo_from_labels <- function(tl, cl) {
  at <- agents_of_label(tl); ac <- agents_of_label(cl)
  keep <- at[!(at %in% ac)]
  if (length(unique(keep)) >= 2) unique(names(keep)) else character(0)
}
## Combo = combinazione DENTRO il valore di UNA chiave (mai attraverso chiavi diverse).
## "+", "and", "plus" bastano da soli; "/" e "_" solo se >=2 parti sono agenti veri
## (cosi' "Bleomycin/Alpha-Lipoic Acid" e "Vemurafenib_Acalabrutinib" passano,
## "SARS-CoV-2_MOI_1" e "Contact_Pulmonary" no).
combo_parts <- function(tval) {
  best <- character(0)
  for (v in strsplit(tval, " | ", fixed = TRUE)[[1]]) {
    s <- drop_doses(v); if (!nzchar(s)) next
    strong <- trimws(strsplit(s, "\\s*[+&]\\s*|\\s+and\\s+|\\s+plus\\s+", perl = TRUE)[[1]])
    ps <- unique(vapply(strong, norm_part, "")); ps <- ps[nzchar(ps)]
    if (length(ps) >= 2 && sum(vapply(ps, resolves_to_agent, logical(1))) >= 1) {
      if (length(ps) > length(best)) best <- ps
      next
    }
    weak <- trimws(strsplit(s, "\\s*[/_]\\s*", perl = TRUE)[[1]])
    pw <- unique(vapply(weak, norm_part, "")); pw <- pw[nzchar(pw)]
    if (length(pw) >= 2 && sum(vapply(pw, resolves_to_agent, logical(1))) >= 2) {
      if (length(pw) > length(best)) best <- pw
    }
  }
  best
}

## ============================ R5/R6/R7 =======================================
LIQUID_RX <- paste0("\\bplasma\\b|\\bserum\\b|cell-?free|\\bcfrna\\b|\\bcfdna\\b|liquid biops|\\bexosom|",
  "extracellular vesicle|\\bplatelets?\\b")
## Materiale PER BRACCIO: se un braccio e' liquido e l'altro no, il contrasto e'
## rotto (misurato: "HNSCC tumor tissue => Healthy blood platelets"). Prima si
## prendeva l'OR dei due bracci e i due casi finivano nello stesso bucket.
material_arm <- function(lab, fl) if (grepl(LIQUID_RX, tolower(paste(lab, fl)), perl = TRUE)) "liquid" else "solid"
CELLTYPE <- c("chondrocyte","chondrocytes","mesenchymal","msc","macrophage","macrophages","monocyte",
  "monocytes","neutrophil","neutrophils","platelet","platelets","fibroblast","fibroblasts",
  "keratinocyte","keratinocytes","endothelial","epithelial","astrocyte","astrocytes","neuron",
  "neurons","lymphocyte","lymphocytes","hepatocyte","hepatocytes","cardiomyocyte","cardiomyocytes",
  "osteoblast","adipocyte","adipocytes","dendritic","myotube","myotubes","spheroid","spheroids")
celltype_of <- function(x) {
  w <- strsplit(gsub("[^a-z ]+", " ", tolower(x %||% "")), "\\s+")[[1]]
  unique(w[w %in% CELLTYPE])
}
OWNBASE_RX <- paste0("\\bbaseline\\b|pre-?treatment|pre-?therapy|before treatment|\\bweek 0\\b|\\bday 0\\b|",
  "\\bt0\\b|timepoint 0|pre-?challenge|pre-?infusion|pre-?dose|\\bpre\\b")
baseline_kind <- function(cl) if (grepl(OWNBASE_RX, tolower(cl %||% ""), perl = TRUE)) "_ownbase" else ""
## Infezione SPERIMENTALE (controllo mock/veicolo) vs infezione CLINICA (controllo
## soggetti sani): non sono lo stesso contrasto. Si applica solo alla classe
## infection, altrimenti spaccherebbe i case-control su "Healthy" vs "Control".
EXP_RX  <- "\\bmock\\b|uninfected|non-?infected|vehicle|\\bdmso\\b|\\buntreated\\b|no treatment|media|medium|scramble|non-?targeting|\\bpbs\\b|saline"
CLIN_RX <- "healthy|\\bdonors?\\b|volunteer|\\bsubjects?\\b|adjacent|\\bpatients?\\b|non-?tumou?r"
## v8: il segnale piu' affidabile e' sul TRATTATO. "CMV viremia", "HBV in
## epatocarcinoma" sono STATI CLINICI di un paziente; "MRC5 esposte a CMV/AD169"
## e' un'infezione sperimentale. Non sono lo stesso contrasto.
CLIN_TREATED_RX <- paste0("viremia|viraemia|seropositiv|carrier|chronic infect|",
  "carcinoma|\\bcancer\\b|tumou?r|hepatitis|\\bpatients?\\b|\\bcase\\b|positive status")
infection_ctx <- function(cls, cl, tl = "") {
  if (!identical(cls, "infection")) return("")
  if (grepl(CLIN_TREATED_RX, tolower(tl %||% ""), perl = TRUE)) return("_clin")
  s <- tolower(cl %||% "")
  if (grepl(EXP_RX, s, perl = TRUE)) return("")
  if (grepl(CLIN_RX, s, perl = TRUE)) return("_clin")
  ""
}
## v8: controlli che NON sono controlli biologici (artefatti di saggio) e
## asimmetria dello stato di resistenza fra i due bracci.
NONCONTROL_RX <- "\\btotal rna\\b|\\binput\\b|genomic dna|\\bunsorted\\b|\\blibrary\\b|\\bmock idr\\b"
resistance_mismatch <- function(tl, cl) {
  rt <- grepl("resistan|refractor", tolower(tl %||% ""))
  rc <- grepl("resistan|refractor", tolower(cl %||% ""))
  rt != rc
}
## v8: il delta muove PIU' DI UNA classe perturbativa (malattia+farmaco,
## farmaco+genetico, ...): il contrasto non isola una cosa sola -> si scarta
## (decisione utente 2026-07-25: gli incoerenti non sono recuperabili).
is_multiclass <- function(dclasses) {
  cs <- strsplit(dclasses, "+", fixed = TRUE)[[1]]
  length(intersect(c("drug", "disease", "infection", "genetic", "environment"), cs)) >= 2
}
## trattato che e' in realta' un controllo (WT, nessuna mutazione): non e' una
## perturbazione, il contrasto e' controllo-vs-controllo.
CTRLLIKE_RX <- "^(wt|wild ?type|no( specified)? mutation|none|control|normal|healthy|unspecified)$"
## firma delle classi che cambiano nel delta: un contrasto che muove malattia E
## farmaco insieme non e' lo stesso di quello che muove solo la malattia
## (misurato: "LSCC + tobacco smoking" finiva sotto l'entita' tabacco).
class_sig <- function(dclasses) {
  cs <- strsplit(dclasses, "+", fixed = TRUE)[[1]]
  cs <- intersect(c("drug", "disease", "infection", "genetic", "environment"), cs)
  if (length(cs) <= 1) "" else paste0("_multi:", paste(sort(cs), collapse = "+"))
}
## sinonimi d'organo: senza questa mappa "renal cell carcinoma" vs "normal KIDNEY
## tissue" risultava un contrasto rotto (falso positivo misurato).
ORGAN_SYN <- c(lungs="lung", pulmonary="lung", alveolar="lung", bronchial="lung", airway="lung",
  hepatic="liver", renal="kidney", cardiac="heart", myocardium="heart", cerebral="brain",
  neural="brain", mammary="breast", gastric="stomach", colorectal="colon", rectum="colon",
  esophageal="esophagus", uterine="uterus", ovarian="ovary", pancreatic="pancreas",
  testicular="testis", cervical="cervix", cutaneous="skin", dermal="skin", epidermis="skin",
  skeletal="muscle", marrow="bone", nodes="node", lymph="node", vein="artery", aorta="artery")
## NB: tolower PRIMA di togliere i non-[a-z]. Nell'ordine inverso "Acute Myeloid
## Leukemia (Blood)" diventava "cute yeloid eukemia lood" e la regola R7 non
## vedeva nessuna anatomia (bug misurato: AML-vs-Normal-Lung passava indenne).
anatomy_of <- function(x) {
  w <- strsplit(gsub("[^a-z ]+", " ", tolower(x %||% "")), "\\s+")[[1]]
  a <- unique(w[w %in% ANATOMY])
  unique(ifelse(a %in% names(ORGAN_SYN), ORGAN_SYN[a], a))
}
## R7: i due bracci misurano materiali/tessuti/tipi cellulari esplicitamente
## diversi -> il contrasto non isola la perturbazione, e' rotto. Si droppa il MEMBRO.
broken_contrast <- function(tl, cl, tfl, cfl) {
  a <- setdiff(anatomy_of(tl), c("plasma", "serum")); b <- setdiff(anatomy_of(cl), c("plasma", "serum"))
  if (length(a) > 0 && length(b) > 0 && length(intersect(a, b)) == 0) return(TRUE)
  if (!identical(material_arm(tl, tfl), material_arm(cl, cfl))) return(TRUE)
  ca <- celltype_of(tl); cb <- celltype_of(cl)
  if (length(ca) > 0 && length(cb) > 0 && length(intersect(ca, cb)) == 0) return(TRUE)
  FALSE
}

## ============================ R1/R2 — entita' ================================
distinctive_toks <- function(nm) {
  if (is.na(nm) || !nzchar(nm)) return(character(0))
  t <- strsplit(gsub("[^a-z0-9 ]+", " ", tolower(nm)), " ")[[1]]
  t <- unique(t[nchar(t) >= 4])
  setdiff(t, c(ANATOMY, GENERIC, CONNECTORS,
               c("carcinoma","cancer","neoplasm","neoplasms","virus","syndrome","acute","chronic","human")))
}
match_all_words <- function(toks, txt) {          # R1: parola intera, TUTTI i token distintivi
  if (!length(toks)) return(FALSE)
  s <- tolower(gsub("[^a-z0-9]+", " ", txt))
  all(vapply(toks, function(z) grepl(paste0("(^| )", z, "( |$)"), s), logical(1)))
}
## R2: canonicalizza il nome del cluster nello stesso spazio-ID (cache per nome+classe)
.name_cache <- new.env(parent = emptyenv())
canon_name_id <- function(nm, cls) {
  if (is.na(nm) || !nzchar(nm) || is.na(cls)) return(NA_character_)
  key <- paste0(cls, "||", tolower(nm))
  if (exists(key, envir = .name_cache, inherits = FALSE)) return(get(key, envir = .name_cache))
  is_canon <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  r <- NA_character_
  if (cls == "drug") {
    x <- .normalize_compound_to_chebi(nm, oe); if (is_canon(x$id)) r <- x$id
    if (is.na(r)) { x <- .normalize_cytokine_to_hgnc(nm, oe); if (is_canon(x$id)) r <- x$id }
  } else if (cls == "infection") {
    x <- .normalize_pathogen_to_taxid(nm, oe); if (is_canon(x$id)) r <- x$id
  } else if (cls == "disease") {
    x <- .normalize_disease_to_mesh(nm, oe); if (is_canon(x$id)) r <- x$id
  } else if (cls == "genetic") {
    h <- .hgnc_lookup_symbol(nm, env = oe); if (!is.null(h) && !is.null(h$hgnc_int)) r <- paste0("HGNC:", h$hgnc_int)
  }
  assign(key, r, envir = .name_cache); r
}

## ============================== LOOP =========================================
n <- nrow(pm)
ent <- rep(NA_character_, n); ct <- rep(NA_character_, n); dcls <- rep(NA_character_, n)
vs <- rep(NA_character_, n); mat <- rep("", n); bas <- rep("", n)
onc <- rep(FALSE, n); dr <- rep("", n)
PRI <- c("genetic","drug","infection","disease","environment","time","other")
for (i in seq_len(n)) {
  tval <- pm$dtval[i]; cval <- pm$dcval[i]
  cls_set <- strsplit(pm$dclasses[i], "+", fixed = TRUE)[[1]]
  if (!nzchar(pm$dclasses[i])) { dr[i] <- "no_delta"; next }
  cls <- PRI[PRI %in% cls_set][1]; dcls[i] <- cls
  # R7 — contrasto rotto (anatomia disgiunta): il MEMBRO si droppa
  if (broken_contrast(pm$treated_label[i], pm$control_label[i], pm$treated_fl[i], pm$control_fl[i])) {
    dr[i] <- "contrasto_rotto"; next
  }
  # v8 — scarti deterministici del residuo (decisione utente: non recuperabili)
  if (grepl(NONCONTROL_RX, tolower(pm$control_label[i]), perl = TRUE)) {
    dr[i] <- "controllo_non_valido"; next
  }
  if (resistance_mismatch(pm$treated_label[i], pm$control_label[i])) {
    dr[i] <- "resistenza_asimmetrica"; next
  }
  if (is_multiclass(pm$dclasses[i])) { dr[i] <- "delta_multiclasse"; next }
  # v9: contrasto degenere per etichetta (i due bracci sono scritti uguale)
  if (identical(tolower(trimws(pm$treated_label[i])), tolower(trimws(pm$control_label[i])))) {
    dr[i] <- "label_degenere"; next
  }
  # control_type dal lato-controllo del delta (come v6) + R5 materiale + R6 baseline
  cvv <- strsplit(cval, " | ", fixed = TRUE)[[1]]; cvv[!nzchar(trimws(cvv))] <- "untreated"
  if (!length(cvv)) cvv <- "untreated"
  # trattato = controllo mascherato (WT / nessuna mutazione): niente perturbazione
  if (any(grepl(CTRLLIKE_RX, trimws(tolower(strsplit(tval, " | ", fixed = TRUE)[[1]])), perl = TRUE))) {
    dr[i] <- "trattato_e_un_controllo"; next
  }
  ctb <- paste(sort(unique(vapply(cvv, .normalize_control_type, ""))), collapse = "+")
  mat[i] <- if (identical(material_arm(pm$treated_label[i], pm$treated_fl[i]), "liquid")) "_liquid" else ""
  bas[i] <- baseline_kind(pm$control_label[i])
  # l'asse clinico/sperimentale vale per ogni contrasto su un PATOGENO, non solo
  # quando la chiave si chiama "infection" (misurato: HIV arrivava come cls=drug).
  is_path <- identical(cls, "infection") ||
    (!is.na(pm$ce2_id[i]) && startsWith(pm$ce2_id[i], "NCBITaxon:"))
  ct[i] <- paste0(ctb, mat[i], bas[i],
                  infection_ctx(if (is_path) "infection" else cls,
                                pm$control_label[i], pm$treated_label[i]))
  # R3 — verso
  v <- verso_of(tval); vs[i] <- v
  if (identical(v, "ambiguo")) { dr[i] <- "verso_ambiguo"; next }
  # R4 — combo (drug o infection): entita' = la combinazione specifica
  cp <- combo_parts(tval)
  # v9: il rilevatore dal label va interrogato anche quando quello dal delta ha
  # trovato UNA sola parte (prima si attivava solo a zero: la co-infezione
  # "M.tb + CMV" restava fuori).
  if (length(cp) < 2) cp <- combo_from_labels(pm$treated_label[i], pm$control_label[i])
  if (cls %in% c("drug", "infection") && length(cp) >= 2) {
    e <- paste0("COMBO:", paste(sort(cp), collapse = "+"))
    # v10 — la riga deve essere anche APPAIATA, non solo sull'entita' giusta
    es <- tok_entita(pm$canonical_name[i], pm$ce2_name[i], cp)
    d <- difetto_riga(pm$treated_label[i], pm$control_label[i], cls, e, es)
    if (nzchar(d)) { dr[i] <- paste0("riga_", d); next }
    ent[i] <- e; dr[i] <- "ok_combo"; next
  }
  # R1/R2 — entita': on-contrast (nome del cluster, canonicalizzato) o propria
  dt <- distinctive_toks(pm$canonical_name[i])
  is_on <- match_all_words(dt, tval)
  onc[i] <- is_on
  e <- NA_character_
  if (is_on) {
    cid <- canon_name_id(pm$canonical_name[i], cls)
    e <- if (!is.na(cid)) cid else paste0("NAME:", tolower(pm$canonical_name[i]))
  } else if (!is.na(pm$ce2_id[i]) && !startsWith(pm$ce2_id[i], "STR:")) {
    e <- pm$ce2_id[i]
  } else {
    tk <- clean_tok(tval); if (nzchar(tk)) e <- paste0("STR:", gsub(" ", "_", tk))
  }
  if (is.na(e)) { dr[i] <- "no_entity"; next }
  raw <- sub("^(NAME|STR):", "", e); nm_low <- tolower(raw)
  if (startsWith(e, "STR:") && is_generic_tok(raw)) { dr[i] <- "str_generico"; next }
  if (startsWith(e, "NAME:") && grepl(UMBRELLA_NAME_RX, nm_low)) { dr[i] <- "nome_ombrello"; next }
  if (e %in% BLACKLIST_ID) { dr[i] <- "id_blacklist"; next }
  if (is_inducer_name(raw)) { dr[i] <- "induttore"; next }
  # nome risolto che e' una parola generica ("vector", "car", "syndrome", "arteries"):
  # e' un ID valido ma non identifica una perturbazione ne' una malattia.
  rn <- tolower(pm$ce2_name[i] %||% "")
  if (nzchar(rn) && !grepl(" ", rn) && (rn %in% GENERIC || rn %in% ANATOMY)) { dr[i] <- "nome_generico"; next }
  if (nzchar(rn) && grepl(UMBRELLA_NAME_RX, rn)) { dr[i] <- "nome_ombrello"; next }
  # v9: l'entita' e' TENUTA COSTANTE fra i due bracci -> quel membro non misura
  # quell'entita' (il delta e' altro). Es. "Current PTSD, PTSD perturbation vs
  # Current PTSD, no perturbation": il contrasto non e' "PTSD vs sano".
  probe <- if (!is.na(pm$ce2_cand[i]) && nzchar(pm$ce2_cand[i])) pm$ce2_cand[i] else sub("^(NAME|STR):", "", e)
  probe <- gsub("[^a-z0-9 ]+", " ", tolower(probe)); probe <- trimws(probe)
  if (nzchar(probe) && nchar(gsub("[^a-z0-9]", "", probe)) >= 3) {
    cl_norm <- gsub("[^a-z0-9]+", " ", tolower(pm$control_label[i]))
    if (grepl(paste0("(^| )", probe, "( |$)"), cl_norm)) { dr[i] <- "entita_costante"; next }
  }
  # v10 — la riga deve essere anche APPAIATA (tempo, soggetto/linea, combinazione,
  # genetica): il gruppo dice CHE COSA si misura, la riga COME e' stato confrontato.
  es <- tok_entita(pm$canonical_name[i], pm$ce2_name[i], raw)
  d <- difetto_riga(pm$treated_label[i], pm$control_label[i], cls, e, es)
  if (nzchar(d)) { dr[i] <- paste0("riga_", d); next }
  ent[i] <- e; dr[i] <- "ok"
}
pm$entity <- ent; pm$ct_delta <- ct; pm$dom_cls <- dcls; pm$verso <- vs; pm$onc <- onc; pm$dr <- dr
pm$clean_tval <- vapply(pm$dtval, clean_tok, "")

## NB v7: rimossa l'euristica v6 "nd>=12 forme di label distinte = ombrello".
## Misurata: uccideva NAME:sars-cov-2 (231 membri, 34 studi) — cioe' proprio il
## cluster che il design deve ricomporre — perche' conta le VARIANTI DI SCRITTURA,
## non le entita'. Sostituita a valle da un test sulle entita' risolte davvero
## distinte dentro il cluster (vedi umbrella_check dopo l'aggregazione).

pm$elig <- !pm$deg & !is.na(pm$dom_cls) &
  pm$dom_cls %in% c("drug","infection","disease","genetic","environment","other") & !is.na(pm$entity)
## CHIAVE v7 = entita' || verso || (control_type + materiale + baseline)
pm$ckey <- ifelse(pm$elig, paste(pm$entity, pm$verso, pm$ct_delta, sep = "||"), NA)

cat("=== drop reasons v10 ===\n"); print(sort(table(pm$dr[nzchar(pm$dr)]), decreasing = TRUE))
elig <- pm[pm$elig, ]
agg <- elig |> group_by(ckey) |>
  summarise(k = n_distinct(study_id), n = n(),
            src = ifelse(startsWith(entity[1], "NAME:"), "NAME",
                  ifelse(startsWith(entity[1], "STR:"), "STR",
                  ifelse(startsWith(entity[1], "COMBO:"), "COMBO", "onto"))),
            verso = verso[1], cls = dom_cls[1], .groups = "drop") |> filter(k >= 3)
## umbrella_check: quante entita' canoniche DIVERSE risolvono i membri del cluster?
## (1 = tutti misurano la stessa cosa; molte = l'entita' condivisa e' una classe)
ce2_distinct <- elig |> filter(!is.na(ce2_id), !startsWith(ce2_id, "STR:")) |>
  group_by(ckey) |> summarise(n_ce2 = n_distinct(ce2_id), .groups = "drop")
agg <- left_join(agg, ce2_distinct, by = "ckey")
agg$n_ce2[is.na(agg$n_ce2)] <- 0L
cat("\n=== distribuzione entita' canoniche distinte per cluster (umbrella check) ===\n")
print(table(pmin(agg$n_ce2, 6)))
## v9 — DEDUP per (entita', verso): una meta-analisi per entita', al k massimo.
## E' la stessa policy gia' in vigore nello Stadio 4 (ADR-0022). Toglie i
## frammenti minori della stessa entita' (stesso oggetto biologico spezzato dal
## tipo di controllo), che sono ridondanti e spesso i piu' contaminati.
agg$entita <- sub("\\|\\|.*$", "", agg$ckey)
agg$verso_k <- sub("^[^|]*\\|\\|([^|]*)\\|\\|.*$", "\\1", agg$ckey)
dup <- agg |> group_by(entita, verso_k) |> filter(n() > 1) |> ungroup()
if (nrow(dup)) {
  cat("\n=== DEDUP per entita' (si tiene il k massimo) ===\n")
  print(as.data.frame(dup |> arrange(entita, desc(k)) |> select(ckey, k, n)), row.names = FALSE)
}
agg <- agg |> group_by(entita, verso_k) |> slice_max(k, n = 1, with_ties = FALSE) |> ungroup()
cat(sprintf("\n=== v10 poolabili k>=3: %d (v9 145) | k>=5: %d ===\n", nrow(agg), sum(agg$k >= 5)))
print(table(agg$src)); cat("\nper verso:\n"); print(table(agg$verso))
cat("\nper classe:\n"); print(table(agg$cls))
cat("\n=== controlli bandiera ===\n")
for (P in c("2697049", "vemurafenib", "63637", "enzalutamide", "68534", "16412", "bleomycin")) {
  h <- agg[grepl(P, agg$ckey, ignore.case = TRUE), ]
  if (nrow(h)) { cat("--", P, "\n"); print(as.data.frame(h[, c("ckey","k","n","verso")]), row.names = FALSE) }
}
saveRDS(list(pm = pm, agg = agg), file.path(SC, "fase1-v10-results.rds"))
cat("\nsalvato fase1-v10-results.rds\n")
