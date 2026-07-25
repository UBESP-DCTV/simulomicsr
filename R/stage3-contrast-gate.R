# Gate di coerenza del contrasto — regole deterministiche dello Stadio 3.
#
# Un gruppo e' difendibile quando i suoi membri misurano LO STESSO CONTRASTO. La
# coerenza nasce per costruzione dell'anchor (entita' del delta canonicalizzata +
# verso + tipo di controllo) e da queste regole di scarto, non da un giudice a
# runtime: nessun LLM e' coinvolto.
#
# Ogni regola qui dentro e' stata derivata da falliti VERI, ispezionati uno per
# uno durante il rework dell'anchor (censimenti v5->v10, 2026-07-24/26). I test
# in tests/testthat/test-stage3-contrast-gate.R pinnano quei casi.

# --------------------------------------------------------------- vocabolari ---

#' Parole che non identificano un'entita' biologica
#' @keywords internal
.CG_GENERIC <- c(
  "none", "control", "controls", "vehicle", "untreated", "treated", "treatment", "treatments",
  "dmso", "pbs", "saline", "mock", "naive", "baseline", "normal", "healthy", "wildtype", "wt",
  "ko", "knockout", "knockdown", "overexpression", "overexpressed", "genetic", "sirna", "shrna",
  "sgrna", "crispr", "transfection", "transfected", "transduced", "infected", "infection",
  "exposed", "exposure", "stimulated", "stimulation", "condition", "conditions", "sample",
  "samples", "patient", "patients", "case", "cases", "disease", "drug", "compound", "agent",
  "stimulus", "perturbation", "perturbations", "group", "other", "unknown", "unclear", "na",
  "test", "experiment", "combination", "combo", "induced", "inducible", "expression", "cells",
  "cell", "tissue", "line", "type", "status", "state", "high", "low", "positive", "negative",
  "present", "absent", "mutant", "post", "pre", "on", "off", "early", "late", "responder",
  "nonresponder", "non", "sensitive", "resistant", "primary", "recurrent", "chemotherapy",
  "differentiation", "differentiated", "environmental", "behavioral", "transgene", "stable",
  "up", "down", "yes", "no", "before", "after", "day", "week", "month", "stage", "grade",
  "level", "score", "activated", "resting", "poly", "mrna", "rna", "dna", "organic", "cation",
  "anion", "steroid", "steroids", "small", "molecule", "molecules", "vector", "empty",
  "parental", "derived",
  # v7: misurate sui falliti
  "biopsy", "biopsies", "specimen", "therapy", "therapies", "challenge", "prechallenge",
  "placebo", "dose", "doses", "concentration", "timepoint", "time", "duration", "subject",
  "subjects", "volunteer", "volunteers", "cohort", "arm", "visit", "standard", "conventional",
  "usual", "only", "alone", "viral", "virus", "bacterial", "infectious", "car", "carrier",
  "construct", "plasmid",
  # v10: termini-ombrello di malattia. Servono perche' quando la guardia blocca
  # "tumor"->MeSH:Neoplasms il resolver ripiega su STR:tumor: senza questa riga
  # tornerebbe a essere un'entita' e rifarebbe il minestrone.
  "tumor", "tumors", "tumour", "tumours", "cancer", "cancers", "neoplasm", "neoplasms",
  "neoplasia", "carcinoma", "carcinomas", "malignant", "malignancy", "metastasis", "metastatic",
  "adenocarcinoma", "knockdowns", "mutation", "mutations", "variant", "variants", "genotype",
  "phenotype")

#' @keywords internal
.CG_CONNECTORS <- c("or", "and", "of", "the", "with", "without", "vs", "versus", "for", "from",
                    "to", "in", "at", "by", "a", "an", "de", "del", "per", "plus", "its")

# induttori dei sistemi condizionali: non sono la perturbazione studiata
#' @keywords internal
.CG_INDUCERS <- c("doxycycline", "dox", "doxy", "tetracycline", "tet", "iptg", "auxin", "iaa",
                  "blasticidin", "puromycin", "g418", "geneticin", "hygromycin", "cumate")

# anatomia: non e' MAI un token distintivo di identita'
#' @keywords internal
.CG_ANATOMY <- c("lung", "lungs", "liver", "hepatic", "kidney", "renal", "heart", "cardiac",
  "myocardium", "brain", "cerebral", "neural", "colon", "colorectal", "rectum", "intestine",
  "ileum", "gastric", "stomach", "breast", "mammary", "prostate", "ovary", "ovarian", "uterus",
  "uterine", "testis", "testicular", "pancreas", "pancreatic", "spleen", "thymus", "thyroid",
  "skin", "cutaneous", "dermal", "epidermis", "blood", "plasma", "serum", "bone", "marrow",
  "muscle", "skeletal", "placenta", "retina", "cornea", "bladder", "esophagus", "esophageal",
  "oral", "nasal", "airway", "bronchial", "alveolar", "synovial", "adipose", "aorta", "artery",
  "vein", "lymph", "node", "nodes", "cervix", "cervical", "head", "neck", "tongue", "salivary",
  "pituitary", "adrenal", "gallbladder", "bile", "duodenum", "jejunum", "tonsil", "gingival",
  "periodontal", "pulmonary")

# senza questa mappa "renal cell carcinoma" vs "normal KIDNEY tissue" risultava un
# contrasto rotto (falso positivo misurato)
#' @keywords internal
.CG_ORGAN_SYNONYMS <- c(lungs = "lung", pulmonary = "lung", alveolar = "lung", bronchial = "lung",
  airway = "lung", hepatic = "liver", renal = "kidney", cardiac = "heart", myocardium = "heart",
  cerebral = "brain", neural = "brain", mammary = "breast", gastric = "stomach",
  colorectal = "colon", rectum = "colon", esophageal = "esophagus", uterine = "uterus",
  ovarian = "ovary", pancreatic = "pancreas", testicular = "testis", cervical = "cervix",
  cutaneous = "skin", dermal = "skin", epidermis = "skin", skeletal = "muscle", marrow = "bone",
  nodes = "node", lymph = "node", vein = "artery", aorta = "artery")

#' @keywords internal
.CG_CELLTYPES <- c("chondrocyte", "chondrocytes", "mesenchymal", "msc", "macrophage",
  "macrophages", "monocyte", "monocytes", "neutrophil", "neutrophils", "platelet", "platelets",
  "fibroblast", "fibroblasts", "keratinocyte", "keratinocytes", "endothelial", "epithelial",
  "astrocyte", "astrocytes", "neuron", "neurons", "lymphocyte", "lymphocytes", "hepatocyte",
  "hepatocytes", "cardiomyocyte", "cardiomyocytes", "osteoblast", "adipocyte", "adipocytes",
  "dendritic", "myotube", "myotubes", "spheroid", "spheroids")

#' @keywords internal
.CG_UMBRELLA_RX <- paste0("^(neoplasms?|carcinomas?|adenocarcinomas?|tumou?rs?|cancers?|",
  "inflammation|infections?|disease|diseases|leukemi\\w*|lymphoma|sarcoma|lesional|non-small|",
  "small molecule|organic cation|steroid|androgens?|estrogens?|cytokines?|chemokines?|",
  "hormones?|antibiotics?|syndrome|syndromes|arteries|artery|cardiomyopathies|fibrosis|",
  "vector|vectors)$")

#' @keywords internal
.CG_LIQUID_RX <- paste0("\\bplasma\\b|\\bserum\\b|cell-?free|\\bcfrna\\b|\\bcfdna\\b|",
                        "liquid biops|\\bexosom|extracellular vesicle|\\bplatelets?\\b")

#' @keywords internal
.CG_OWNBASE_RX <- paste0("\\bbaseline\\b|pre-?treatment|pre-?therapy|before treatment|",
                         "\\bweek 0\\b|\\bday 0\\b|\\bt0\\b|timepoint 0|pre-?challenge|",
                         "pre-?infusion|pre-?dose|\\bpre\\b")

# controlli che non sono controlli biologici: sono artefatti di saggio
#' @keywords internal
.CG_NONCONTROL_RX <- "\\btotal rna\\b|\\binput\\b|genomic dna|\\bunsorted\\b|\\blibrary\\b|\\bmock idr\\b"

#' @keywords internal
.CG_CONTROLLIKE_RX <- "^(wt|wild ?type|no( specified)? mutation|none|control|normal|healthy|unspecified)$"

# ------------------------------------------------------------------- utilita' --

#' Normalizza i separatori: "_" e "|" non sono lettere
#' @keywords internal
.cg_normalize <- function(x) {
  if (length(x) == 0L || is.na(x[1L])) return("")
  trimws(gsub("\\s+", " ", gsub("[_/|]+", " ", paste(x, collapse = " "))))
}

#' Il token e' generico (non identifica un'entita')
#'
#' I connettori vengono tolti prima di decidere: "control with vehicle" e'
#' generica quanto "control".
#' @keywords internal
.cg_is_generic_token <- function(token) {
  if (length(token) == 0L || is.na(token[1L]) || !nzchar(token[1L])) return(TRUE)
  t <- tolower(trimws(token[1L]))
  if (nchar(gsub("[^a-z0-9]", "", t)) < 4L) return(TRUE)
  if (!grepl("[a-z]", t)) return(TRUE)
  w <- strsplit(t, "[^a-z0-9]+")[[1L]]
  w <- setdiff(w[nzchar(w)], .CG_CONNECTORS)
  if (!length(w)) return(TRUE)
  all(w %in% .CG_GENERIC)
}

#' L'etichetta nomina un induttore di sistema condizionale
#' @keywords internal
.cg_is_inducer <- function(x) {
  s <- tolower(.cg_normalize(x))
  if (!nzchar(s)) return(FALSE)
  any(vapply(.CG_INDUCERS, function(z) grepl(paste0("\\b", z, "\\b"), s), logical(1)))
}

#' Il nome e' un termine-classe (ombrello), non un'entita'
#' @keywords internal
.cg_is_umbrella_name <- function(x) {
  if (length(x) == 0L || is.na(x[1L])) return(FALSE)
  grepl(.CG_UMBRELLA_RX, tolower(trimws(x[1L])))
}

# ------------------------------------------------------------ verso del delta --

.CG_LOSS_RX <- paste0("deprivat|depleti|starv|withdraw|removal|removed|restrict|fasting|\\bno\\b|",
  "\\bnon-|without|[a-z]-free\\b|\\bfree (medium|media)|absence|\\bloss\\b|silenc|\\blow\\b|",
  "reduced|decreas")
.CG_BLOCK_RX <- paste0("inhibitor|inhibiti|antagonist|blockade|blocking|blocker|neutraliz|",
  "degrader|protac|knockdown|knockout|\\bko\\b|\\bshrna|\\bsirna|\\bsgrna|crispr|deficien|",
  "\\bnull\\b|\\banti-[a-z0-9]")
.CG_GAIN_RX <- "addition|added|supplement|agonist|overexpress|\\bhigh\\b|stimulat|activation|induction|\\bplus\\b"

#' Verso del delta: guadagno, perdita, blocco o ambiguo
#'
#' Il verso entra nella chiave del gruppo: agonista e antagonista della stessa
#' entita' NON si fondono (decisione utente 2026-07-25). Verso ambiguo (marcatori
#' di perdita e di guadagno insieme) = il gruppo si scarta.
#' @keywords internal
.cg_direction <- function(delta_value) {
  s <- tolower(.cg_normalize(delta_value))
  if (!nzchar(trimws(s))) return("gain")
  loss <- grepl(.CG_LOSS_RX, s, perl = TRUE)
  blk <- grepl(.CG_BLOCK_RX, s, perl = TRUE)
  gain <- grepl(.CG_GAIN_RX, s, perl = TRUE)
  if (loss && gain) return("ambiguo")
  if (loss) return("loss")
  if (blk) return("block")
  "gain"
}

# ------------------------------------------------------- anatomia e materiale --

#' Organi nominati nell'etichetta, normalizzati sui sinonimi
#'
#' \code{tolower} PRIMA di togliere i caratteri non alfabetici: nell'ordine
#' inverso "Acute Myeloid Leukemia (Blood)" diventava "cute yeloid eukemia lood" e
#' il contrasto leucemia-vs-polmone passava indenne (bug misurato).
#' @keywords internal
.cg_anatomy <- function(x) {
  w <- strsplit(gsub("[^a-z ]+", " ", tolower(.cg_normalize(x))), "\\s+")[[1L]]
  a <- unique(w[w %in% .CG_ANATOMY])
  if (!length(a)) return(character(0))
  unique(unname(ifelse(a %in% names(.CG_ORGAN_SYNONYMS), .CG_ORGAN_SYNONYMS[a], a)))
}

#' Tipi cellulari nominati nell'etichetta
#' @keywords internal
.cg_celltypes <- function(x) {
  w <- strsplit(gsub("[^a-z ]+", " ", tolower(.cg_normalize(x))), "\\s+")[[1L]]
  unique(w[w %in% .CG_CELLTYPES])
}

#' Materiale del braccio: liquido o solido
#' @keywords internal
.cg_material_arm <- function(...) {
  if (grepl(.CG_LIQUID_RX, tolower(.cg_normalize(paste(...))), perl = TRUE)) "liquid" else "solid"
}

#' Il contrasto e' rotto: i due bracci misurano materiali diversi
#'
#' Anatomia disgiunta, materiale diverso (tessuto vs plasma) o tipi cellulari
#' disgiunti: il confronto non isola la perturbazione. Il membro si droppa.
#' @keywords internal
.cg_broken_contrast <- function(treated_label, control_label,
                                treated_extra = "", control_extra = "") {
  a <- setdiff(.cg_anatomy(treated_label), c("plasma", "serum"))
  b <- setdiff(.cg_anatomy(control_label), c("plasma", "serum"))
  if (length(a) > 0L && length(b) > 0L && length(intersect(a, b)) == 0L) return(TRUE)
  if (!identical(.cg_material_arm(treated_label, treated_extra),
                 .cg_material_arm(control_label, control_extra))) return(TRUE)
  ca <- .cg_celltypes(treated_label); cb <- .cg_celltypes(control_label)
  if (length(ca) > 0L && length(cb) > 0L && length(intersect(ca, cb)) == 0L) return(TRUE)
  FALSE
}

#' Il controllo e' una baseline propria (disegno longitudinale)
#' @keywords internal
.cg_baseline_kind <- function(control_label) {
  if (grepl(.CG_OWNBASE_RX, tolower(.cg_normalize(control_label)), perl = TRUE)) "_ownbase" else ""
}

# ------------------------------------------- infezione clinica vs sperimentale --

.CG_EXPERIMENTAL_RX <- paste0("\\bmock\\b|uninfected|non-?infected|vehicle|\\bdmso\\b|",
  "\\buntreated\\b|no treatment|media|medium|scramble|non-?targeting|\\bpbs\\b|saline")
.CG_CLINICAL_RX <- "healthy|\\bdonors?\\b|volunteer|\\bsubjects?\\b|adjacent|\\bpatients?\\b|non-?tumou?r"
# il segnale piu' affidabile e' sul TRATTATO: "CMV viremia", "HBV in epatocarcinoma"
# sono stati clinici di un paziente; "MRC5 esposte a CMV" e' un'infezione sperimentale.
.CG_CLINICAL_TREATED_RX <- paste0("viremia|viraemia|seropositiv|carrier|chronic infect|carcinoma|",
  "\\bcancer\\b|tumou?r|hepatitis|\\bpatients?\\b|\\bcase\\b|positive status")

#' Asse clinico/sperimentale di un contrasto d'infezione
#'
#' Si applica solo ai contrasti su patogeno, altrimenti spaccherebbe i
#' caso-controllo su "Healthy" vs "Control".
#' @keywords internal
.cg_infection_context <- function(contrast_class, control_label, treated_label = "") {
  if (!identical(contrast_class, "infection")) return("")
  if (grepl(.CG_CLINICAL_TREATED_RX, tolower(.cg_normalize(treated_label)), perl = TRUE)) return("_clin")
  s <- tolower(.cg_normalize(control_label))
  if (grepl(.CG_EXPERIMENTAL_RX, s, perl = TRUE)) return("")
  if (grepl(.CG_CLINICAL_RX, s, perl = TRUE)) return("_clin")
  ""
}

# ------------------------------------------------ resistenza, controlli, classi --

#' Lo stato di resistenza c'e' su un braccio solo
#' @keywords internal
.cg_resistance_mismatch <- function(treated_label, control_label) {
  grepl("resistan|refractor", tolower(.cg_normalize(treated_label))) !=
    grepl("resistan|refractor", tolower(.cg_normalize(control_label)))
}

#' Il controllo non e' un controllo biologico ma un artefatto di saggio
#' @keywords internal
.cg_is_noncontrol <- function(control_label) {
  grepl(.CG_NONCONTROL_RX, tolower(.cg_normalize(control_label)), perl = TRUE)
}

#' Il braccio "trattato" e' in realta' un controllo (WT, nessuna mutazione)
#' @keywords internal
.cg_is_control_like_treated <- function(treated_value) {
  any(grepl(.CG_CONTROLLIKE_RX,
            trimws(tolower(strsplit(.cg_normalize(treated_value), " \\| ")[[1L]])), perl = TRUE))
}

#' Il delta muove piu' di una classe perturbativa
#'
#' Un contrasto che muove malattia E farmaco insieme non isola una cosa sola.
#' @keywords internal
.cg_is_multiclass <- function(delta_classes) {
  if (length(delta_classes) == 0L || is.na(delta_classes[1L]) || !nzchar(delta_classes[1L]))
    return(FALSE)
  cs <- strsplit(delta_classes[1L], "+", fixed = TRUE)[[1L]]
  length(intersect(c("drug", "disease", "infection", "genetic", "environment"), cs)) >= 2L
}

# ---------------------------------------------------- entita' on-contrast ------

#' Token distintivi del nome di un gruppo
#'
#' Anatomia, parole generiche e termini di classe non distinguono un'identita'.
#' @keywords internal
.cg_distinctive_tokens <- function(name) {
  if (length(name) == 0L || is.na(name[1L]) || !nzchar(name[1L])) return(character(0))
  t <- strsplit(gsub("[^a-z0-9 ]+", " ", tolower(.cg_normalize(name))), " ")[[1L]]
  t <- unique(t[nchar(t) >= 4L])
  setdiff(t, c(.CG_ANATOMY, .CG_GENERIC, .CG_CONNECTORS,
               c("carcinoma", "cancer", "neoplasm", "neoplasms", "virus", "syndrome",
                 "acute", "chronic", "human")))
}

#' Tutti i token compaiono nel testo a parola intera
#'
#' A parola intera: "lung adenocarcinoma" non inghiotte "SSc lung fibroblasts" e
#' "heat shock" non inghiotte "HEATed tobacco".
#' @keywords internal
.cg_matches_all_words <- function(tokens, text) {
  if (!length(tokens)) return(FALSE)
  s <- tolower(gsub("[^a-z0-9]+", " ", .cg_normalize(text)))
  all(vapply(tokens, function(z) grepl(paste0("(^| )", z, "( |$)"), s), logical(1)))
}
