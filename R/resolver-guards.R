# Guardie di precisione per il recupero-nome ontologico.
#
# PERCHE'. I vocabolari di riferimento (ChEBI, ImmPort, HGNC, MeSH, NCBI
# Taxonomy) contengono sinonimi CORTI o AMBIGUI che collidono con il gergo di
# laboratorio. Il resolver, che accetta il primo candidato che matcha, assegna
# allora un'identita' molecolare sbagliata in modo SILENZIOSO. Casi misurati
# sull'audit 2026-07-25 (`analysis/audit/2026-07-25-resolver-alias-audit/`):
#
#   "ug/ml"      -> candidato "ml"     -> sinonimo ImmPort di THPO (trombopoietina)
#   "Her/Lap"    -> candidato "lap"    -> sinonimo ImmPort di TGFB1 (Latency
#                                         Associated Peptide), ma qui Lap =
#                                         lapatinib
#   "mitoxantrone (MIT)" -> "mit"      -> 3-iodo-L-tirosina
#   "cancer"                           -> genere di granchi *Cancer* (Taxonomy)
#   "5-FU"                             -> 5-formiluracile (invece del
#                                         5-fluorouracile, CHEBI:46345)
#   "DHA"                              -> diidrossiacetone (invece dell'acido
#                                         docosaesaenoico)
#   "TPA"                              -> acido tereftalico (invece del forbolo)
#   "PD1"                              -> protectina D1 (invece di PDCD1)
#   "HGF"/"TPO"/"HGI"                  -> IL6 (sinonimi storici di ImmPort)
#
# COSA FANNO QUESTE GUARDIE. Scartano il CANDIDATO, non il termine: la catena di
# lookup prosegue col candidato successivo. Meglio nessun nome che un nome
# sbagliato: un'identita' molecolare errata si propaga fino alla meta-analisi.
#
# COSA NON FANNO. Non ri-mappano al bersaglio giusto (5-FU -> CHEBI:46345):
# ri-mappare significherebbe asserire un'identita' sulla base di un'inferenza,
# ed e' esattamente cio' che ha prodotto il problema. Si rifiuta e basta.

#' Token che non identificano MAI un'entita' (unita' di misura e parametri)
#'
#' Strutturale: nessuna di queste stringhe puo' essere il nome di una
#' perturbazione, per quanto compaia nelle tabelle di sinonimi.
#' @keywords internal
#' @noRd
.UNRELIABLE_UNIT_TOKENS <- c(
  "ml", "ul", "dl", "l", "ug", "mg", "ng", "pg", "kg", "g", "mcg",
  "nm", "um", "mm", "pm", "cm", "mol", "mmol", "umol", "nmol", "pmol",
  "iu", "moi", "pfu", "ffu", "tcid", "rpm", "rcf", "psi", "hz", "ph",
  "hr", "hrs", "min", "sec", "msec", "kb", "bp", "mb", "gb", "od"
)

#' Parole funzionali/di laboratorio che collidono con sinonimi ontologici
#'
#' Strutturale: sono parole del discorso, non nomi di entita'. Senza questa
#' guardia "in" risolve al gene CD44 e "donor" a "hydrogen donor".
#' @keywords internal
#' @noRd
.UNRELIABLE_WORD_TOKENS <- c(
  "in", "on", "at", "by", "of", "or", "and", "no", "not", "with", "without",
  "for", "from", "the", "a", "an", "as", "is", "are", "was", "per", "via",
  "lead", "donor", "donors", "control", "controls", "case", "cases", "sample",
  "samples", "type", "cell", "cells", "tissue", "patient", "patients", "human",
  "age", "sex", "male", "female", "id", "name", "group", "level", "levels",
  "media", "medium", "buffer", "input", "pool", "mix", "set", "run", "test",
  "cancer", "tumor", "tumour", "disease", "normal", "healthy"
)

#' Collisioni alias->entita' accertate una per una (audit 2026-07-25)
#'
#' Ogni riga e' stata giudicata sui dati veri: l'alias e' un sinonimo formalmente
#' presente nel vocabolario, ma nel linguaggio dei metadati trascrittomici indica
#' quasi sempre un'altra cosa. Il numero e' l'impatto misurato in campioni di
#' produzione (cache del recupero-nome, 28.556 campioni con ID ontologico).
#' Formato: "alias|ID_sbagliato".
#' @keywords internal
#' @noRd
.ALIAS_COLLISIONS <- c(
  "tumor|MeSH:D009369",       # Neoplasms (217)
  "cancer|MeSH:D009369",      # Neoplasms (134)
  "ml|HGNC:11795",            # THPO (105)
  "ifn|HGNC:5417",            # IFNA1 (100)
  "in|HGNC:1681",             # CD44 (94)
  "ifna|HGNC:5417",           # IFNA1 (62)
  "lead|CHEBI:25016",         # lead atom (52)
  "iaa|CHEBI:16411",          # indole-3-acetic acid (40)
  "dha|CHEBI:16016",          # dihydroxyacetone (24)
  "ser|CHEBI:17115",          # L-serine (23)
  "hgf|HGNC:6018",            # IL6 (22)
  "apg|CHEBI:155879",         # Ala-Pro-Gly (20)
  "il1|HGNC:5991",            # IL1A (20)
  "tpa|CHEBI:15702",          # terephthalic acid (19)
  "5fu|CHEBI:80961",          # 5-formyluracil (18)
  "activin|HGNC:24029",       # INHBE (16)
  "ifna|HGNC:5423",           # IFNA2 (12)
  "pal|CHEBI:59043",          # PAL (12)
  "tpo|HGNC:6018",            # IL6 (12)
  "pvp|CHEBI:53245",          # poly(vinylpyridine) (11)
  "hgi|HGNC:6018",            # IL6 (10)
  "csf|HGNC:2434",            # CSF2 (9)
  "egf|CHEBI:140739",         # Glu-Gly-Phe (9)
  "igm|HGNC:11935",           # CD40LG (9)
  "il27|HGNC:5984",           # IL17D (9)
  "sel|CHEBI:24866",          # salt (9)
  "amo|CHEBI:53705",          # amoxicilloyl group (8)
  "mc|CHEBI:34342",           # 3-methylcholanthrene (8)
  "bap|CHEBI:29022",          # N-benzyladenine (7)
  "c6|HGNC:1339",             # C6 (7)
  "chop|CHEBI:18132",         # phosphocholine (7)
  "donor|CHEBI:17499",        # hydrogen donor (7)
  "pd1|CHEBI:138655",         # protectin D1 (7)
  "ph|MeSH:D006863",          # Hydrogen-Ion Concentration (7)
  "ampk|HGNC:9377",           # PRKAA2 (6)
  "c|HGNC:11768",             # TGFB2 (6)
  "dec|CHEBI:23574",          # decanoyl group (6)
  "male|CHEBI:30780",         # maleate(2−) (6)
  "nrg1|HGNC:30142",          # GDF15 (6)
  "pdx|CHEBI:138653",         # (4Z,7Z,10S,11 (6)
  "tac|CHEBI:53498",          # triacetylcellulose (6)
  "tmp|CHEBI:9533",           # thiamine(1+) monophosphate (6)
  "vitamin|CHEBI:33229",      # vitamin (role) (6)
  "can|CHEBI:91238",          # calcium ammonium nitrate (5)
  "tad|CHEBI:2659",           # aminophylline (5)
  "acf|CHEBI:191932",         # acetyl fluoride (4)
  "akm|CHEBI:31255",          # bekanamycin sulfate (4)
  "aps|CHEBI:17709",          # 5'-adenylyl sulfate (4)
  "dpn|MeSH:D009243",         # NAD (4)
  "eto|CHEBI:27561",          # oxirane (4)
  "ffa|CHEBI:42638",          # flufenamic acid (4)
  "ilt|HGNC:5977",            # IL15 (4)
  "lp|HGNC:6667",             # LPA (4)
  "mek|CHEBI:28398",          # butan-2-one (4)
  "mrna|CHEBI:33699",         # messenger RNA (4)
  "oxa|CHEBI:53076",          # 4-(ethoxymethylene)-2-phenyloxazol (4)
  "shh|CHEBI:45716",          # vorinostat (4)
  "tnt|CHEBI:27135",          # trinitrotoluene (4)
  "tsa|HGNC:9353",            # PRDX2 (4)
  "doc|CHEBI:16973",          # 11-deoxycorticosterone (3)
  "dpn|CHEBI:15846",          # NAD+ (3)
  "ifna8|HGNC:5427",          # IFNA6 (3)
  "iso|CHEBI:167830",         # isorhapontigenin (3)
  "ky|HGNC:26576",            # KY (3)
  "l3|HGNC:10332",            # RPL3 (3)
  "mk|HGNC:11905",            # TNFRSF10B (3)
  "nmda|CHEBI:6121",          # ketamine (3)
  "palb|HGNC:12405",          # TTR (3)
  "a20|HGNC:5735",            # IGKV1-27 (2)
  "ach|HGNC:3690",            # FGFR3 (2)
  "act|HGNC:16",              # SERPINA3 (2)
  "bg|HGNC:616",              # APOH (2)
  "c10|CHEBI:87148",          # (Z)-13-methyltetradec-2-eno (2)
  "c5a|HGNC:1331",            # C5 (2)
  "mit|CHEBI:27847",          # 3-iodo-L-tyrosine (1)
  "lap|HGNC:11766"           # TGFB1: "Lap" e' lapatinib, LAP e' il peptide (cluster TGFB1)
)

#' Il candidato e' un token che non puo' identificare un'entita'?
#'
#' @param cand character(1) candidato estratto dal testo.
#' @return TRUE se il candidato va saltato.
#' @keywords internal
#' @noRd
.is_unreliable_candidate <- function(cand) {
  if (length(cand) != 1L || is.na(cand) || !nzchar(cand)) return(TRUE)
  tok <- gsub("[^a-z0-9]", "", tolower(trimws(cand)))
  if (!nzchar(tok)) return(TRUE)
  if (!grepl("[a-z]", tok)) return(TRUE)            # solo cifre
  tok %in% .UNRELIABLE_UNIT_TOKENS || tok %in% .UNRELIABLE_WORD_TOKENS
}

#' La coppia (candidato, ID risolto) e' una collisione accertata?
#'
#' @param cand character(1) candidato che ha prodotto il match.
#' @param id character(1) ID ontologico ottenuto (es. "HGNC:11795").
#' @return TRUE se la coppia e' nella tabella delle collisioni accertate.
#' @keywords internal
#' @noRd
.is_alias_collision <- function(cand, id) {
  if (length(cand) != 1L || is.na(cand) || length(id) != 1L || is.na(id)) return(FALSE)
  tok <- gsub("[^a-z0-9]", "", tolower(trimws(cand)))
  paste0(tok, "|", id) %in% .ALIAS_COLLISIONS
}

#' Guardia unica: questo match va rifiutato?
#'
#' @param cand character(1) candidato.
#' @param id character(1) ID ontologico proposto.
#' @return TRUE se il match non e' affidabile e va scartato.
#' @keywords internal
#' @noRd
.reject_unreliable_match <- function(cand, id) {
  .is_unreliable_candidate(cand) || .is_alias_collision(cand, id)
}
