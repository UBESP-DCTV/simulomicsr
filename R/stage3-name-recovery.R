# Recupero deterministico di identita' (malattia/composto/gene) dai metadati GEO
# grezzi + correzione tipi palesemente sbagliati (K2). Spec:
# docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md

# Fallback %||% se non disponibile da rlang
if (!exists("%||%")) {
  `%||%` <- function(a, b) {
    if (is.null(a) || length(a) == 0L) b else a
  }
}

.DISEASE_KEYS <- "^(disease|disease state|diagnosis|condition|histology|tumor type|cancer type|subtype|group|patient group)$"
.CONTROL_VALS <- "healthy|normal|control|non-?malignant|baseline|unaffected|^na$|^none$"
.AGENT_KEYS    <- "^(treatment|agent|compound|drug|chemical|stimulus|stimulation|ligand|exposure|reagent)$"
.AGENT_CONTROL <- paste0(.CONTROL_VALS, "|vehicle|dmso|\\bpbs\\b|untreated|mock|scramble|vector|water")

#' Parsa "key: value, key: value" in vettore nominato (chiavi/valori lowercased)
#' @keywords internal
.parse_characteristics_kv <- function(text) {
  if (length(text) != 1L || is.na(text) || !nzchar(text)) return(character(0))
  pairs <- strsplit(text, ",", fixed = TRUE)[[1L]]
  out <- character(0)
  for (p in pairs) {
    kv <- strsplit(p, ":", fixed = TRUE)[[1L]]
    if (length(kv) >= 2L) {
      k <- tolower(trimws(kv[1L]))
      v <- tolower(trimws(paste(kv[-1L], collapse = ":")))
      if (nzchar(k) && nzchar(v)) out[[k]] <- v
    }
  }
  out
}

#' Estrae il termine-malattia dai metadati (chiavi malattia + fallback source/title)
#' @keywords internal
.extract_disease_term <- function(source, characteristics, title) {
  kv <- .parse_characteristics_kv(characteristics)
  if (length(kv) > 0L) {
    hit <- names(kv)[grepl(.DISEASE_KEYS, names(kv), ignore.case = TRUE)]
    for (k in hit) {
      v <- kv[[k]]
      if (nzchar(v) && !grepl(.CONTROL_VALS, v, ignore.case = TRUE)) return(v)
    }
  }
  # fallback: source/title se contengono un marcatore tumore/malattia esplicito
  blob <- tolower(paste(source %||% "", title %||% ""))
  if (grepl("tumou?r|cancer|carcinoma|neoplas|leukemia|lymphoma", blob) &&
      !grepl(.CONTROL_VALS, blob, ignore.case = TRUE)) {
    return(tolower(trimws(gsub("\\s+", " ", source %||% title))))
  }
  NA_character_
}

#' Estrae il termine-agente (composto) dai metadati
#' @keywords internal
.extract_agent_term <- function(source, characteristics, title) {
  kv <- .parse_characteristics_kv(characteristics)
  if (length(kv) > 0L) {
    hit <- names(kv)[grepl(.AGENT_KEYS, names(kv))]
    for (k in hit) {
      v <- kv[[k]]
      if (nzchar(v) && !grepl(.AGENT_CONTROL, v)) return(v)
    }
  }
  NA_character_
}

# ---------------------------------------------------------------------------
# Task 5 -- .slugify + .normalize_disease_to_mesh
# ---------------------------------------------------------------------------

#' Produce uno slug ASCII minuscolo (spazi e punteggiatura -> underscore)
#' @keywords internal
.slugify <- function(x) {
  s <- tolower(trimws(gsub("[^a-z0-9]+", "_", tolower(x))))
  gsub("^_+|_+$", "", s)
}

#' Normalizza un termine-malattia testuale a MeSH (sinonimi -> stesso UI) oppure
#' al fallback STR:<slug> se non trovato in dizionario, oppure NA se termine assente.
#'
#' Flusso:
#' 1. Guardia su input mancante/vuoto -> id=NA, source="NO_TERM".
#' 2. Lookup nome/sinonimo via \code{.mesh_lookup_term} (indice \code{by_entry_lower}).
#' 3. Se trovato: recupera nome leggibile \code{$mh} via \code{.mesh_lookup_ui} ->
#'    id="MeSH:Dxxxxxx", source="MESH_NAME".
#' 4. Altrimenti: id="STR:<slug>", name=term, source="STR_FALLBACK".
#'
#' @param term character(1) termine-malattia estratto dai metadati GEO.
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#' @return lista con campi \code{id}, \code{name}, \code{source}.
#' @keywords internal
.normalize_disease_to_mesh <- function(term, ontology_env) {
  if (length(term) != 1L || is.na(term) || !nzchar(term)) {
    return(list(id = NA_character_, name = NA_character_, source = "NO_TERM"))
  }
  hit <- .mesh_lookup_term(term, env = ontology_env)
  if (!is.null(hit) && !is.null(hit$ui)) {
    full <- .mesh_lookup_ui(hit$ui, env = ontology_env)
    return(list(
      id     = paste0("MeSH:", hit$ui),
      name   = if (!is.null(full) && !is.null(full$mh)) full$mh else term,
      source = "MESH_NAME"
    ))
  }
  list(id = paste0("STR:", .slugify(term)), name = term, source = "STR_FALLBACK")
}

# Termini di RUOLO/classe generici che sono anche alias ChEBI/ChEMBL ma NON
# identificano un composto specifico: vanno rifiutati come match (precision-first,
# evitano fusioni spurie tipo due "*_inhibitor" diversi -> stesso CHEBI:35222).
.GENERIC_COMPOUND_STOPLIST <- c(
  "drug","drugs","compound","compounds","chemical","chemicals","agent","agents",
  "acid","base","peptide","peptides","protein","proteins","agonist","agonists",
  "antagonist","antagonists","inhibitor","inhibitors","activator","activators",
  "ligand","ligands","hormone","hormones","vehicle","solvent","water","medium",
  "media","buffer","salt","salts","metabolite","substrate","enzyme","rna","dna",
  "antibiotic","antibiotics","reagent","small molecule"
)

# ---------------------------------------------------------------------------
# Task 2 -- .extract_compound_candidates
# ---------------------------------------------------------------------------

#' Estrae candidati-composto da un termine rumoroso (dose/tempo/combo).
#' Restituisce un vettore ordinato di stringhe da provare contro le ontologie.
#' Conservativo: prova prima la stringa intera (cosi' i nomi con separatori
#' interni come "kj pyr 9" non si frantumano), poi la versione spogliata da
#' dose/tempo, poi le sotto-stringhe spezzate sulle congiunzioni.
#' @keywords internal
.extract_compound_candidates <- function(term) {
  if (length(term) != 1L || is.na(term) || !nzchar(term)) return(character(0))
  base <- tolower(trimws(gsub("\\s+", " ", term)))
  cands <- base
  stripped <- base
  stripped <- gsub("\\b[0-9]+(\\.[0-9]+)?\\s*(µm|um|nm|mm|ng/?ml|ng|mg|ug|iu|u|m)\\b", " ", stripped, perl = TRUE)
  stripped <- gsub("\\bfor\\s+[0-9]+\\s*(h|hr|hrs|hours|d|days|min|minutes)\\b", " ", stripped, perl = TRUE)
  stripped <- gsub("\\b[0-9]+\\s*(h|hr|hrs|d|days|min)\\b", " ", stripped, perl = TRUE)
  stripped <- gsub("\\b(treated|treatment|exposed|exposure|stimulated|stimulation|condition|induction|induced|of)\\b", " ", stripped, perl = TRUE)
  stripped <- trimws(gsub("\\s+", " ", stripped))
  if (nzchar(stripped) && stripped != base) cands <- c(cands, stripped)
  # sotto-stringhe da congiunzioni (combo "A and B" / "A + B")
  parts <- unlist(strsplit(stripped, "\\s+(and|plus|with)\\s+|\\s*[+&]\\s*", perl = TRUE))
  parts <- trimws(gsub("\\s+", " ", parts))
  parts <- parts[nzchar(parts) & !(parts %in% c(base, stripped))]
  cands <- c(cands, parts)
  # token whitespace singoli (cattura name+code "cobimetinib gdc0973" e combo
  # separati da spazi). Il gate di precisione vive in .resolve_one_compound:
  # len>=3 + non-numerico + match esatto -> token spuri/corti/numerici non risolvono.
  toks <- unlist(strsplit(stripped, "\\s+"))
  toks <- trimws(toks)
  cands <- c(cands, toks[nzchar(toks)])
  unique(cands[nzchar(cands)])
}

# ---------------------------------------------------------------------------
# Task 3 -- .resolve_one_compound + .normalize_compound_to_chebi (riscritta)
# ---------------------------------------------------------------------------

#' Risolve UN candidato-composto: gate precisione + catena ChEBI -> ChEMBL ->
#' ChEBI-via-pref_name (de-frammentazione) -> CHEMBL nativo. NULL se non risolve.
#'
#' Gate di precisione: un candidato viene processato solo se, dopo rimozione
#' dei caratteri non-alfanumerici, ha lunghezza >=3 e non e' puramente numerico.
#' Questo previene che token corti o numerici (es. da "10 nm 1") producano ID.
#'
#' @param cand character(1) stringa-candidato gia' estratta da
#'   \code{.extract_compound_candidates}.
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#' @return lista con campi \code{id}, \code{name}, \code{source}, oppure NULL
#'   se il candidato non supera il gate o non risolve in nessun dizionario.
#' @keywords internal
.resolve_one_compound <- function(cand, ontology_env) {
  c2   <- trimws(cand)
  alnum <- gsub("[^a-z0-9]", "", tolower(c2))
  # Gate di precisione: blocca i token singoli troppo corti (<3 char alfanumerici)
  # o puramente numerici (es. "1", "so" estratti da "10 nm 1") cosi' non producono
  # mai un ID. La stringa intera rumorosa (es. "10 nm 1") puo' invece raggiungere
  # il lookup DI PROPOSITO -- e' necessaria per i nomi multi-parola (es. "retinoic
  # acid") -- e resta non-recuperata via dict-miss (STR_FALLBACK), NON via questo
  # gate. La precisione sui token spurii e' garantita dal match esatto contro
  # l'alias controllato nel dizionario ontologico.
  if (nchar(alnum) < 3L) return(NULL)           # gate: troppo corto
  if (grepl("^[0-9]+$", alnum)) return(NULL)    # gate: puramente numerico
  if (tolower(c2) %in% .GENERIC_COMPOUND_STOPLIST) return(NULL)  # termine generico -> non-match
  # 1. ChEBI diretto
  hit <- .chebi_lookup_alias(c2, env = ontology_env)
  if (!is.null(hit) && !is.null(hit$chebi_id)) {
    full <- .chebi_lookup_id(hit$chebi_id, env = ontology_env)
    return(list(
      id     = paste0("CHEBI:", hit$chebi_id),
      name   = if (!is.null(full) && !is.null(full$primary_name)) full$primary_name else c2,
      source = "CHEBI_ALIAS"
    ))
  }
  # 2. ChEMBL -> pref_name -> ChEBI (de-frammentazione) oppure CHEMBL nativo
  ch <- .chembl_lookup_alias(c2, env = ontology_env)
  if (!is.null(ch) && !is.null(ch$chembl_id)) {
    mol  <- .chembl_lookup_id(ch$chembl_id, env = ontology_env)
    pref <- if (!is.null(mol) && !is.null(mol$pref_name)) mol$pref_name else NA_character_
    if (!is.na(pref) && nzchar(pref)) {
      chebi2 <- .chebi_lookup_alias(pref, env = ontology_env)
      if (!is.null(chebi2) && !is.null(chebi2$chebi_id)) {
        full <- .chebi_lookup_id(chebi2$chebi_id, env = ontology_env)
        return(list(
          id     = paste0("CHEBI:", chebi2$chebi_id),
          name   = if (!is.null(full) && !is.null(full$primary_name)) full$primary_name else pref,
          source = "CHEMBL_VIA_CHEBI"
        ))
      }
    }
    return(list(
      id     = paste0("CHEMBL:", ch$chembl_id),
      name   = pref %||% c2,
      source = "CHEMBL_ALIAS"
    ))
  }
  NULL
}

#' Normalizza un termine-composto testuale a ChEBI/ChEMBL (o STR/combo).
#'
#' Flusso (riscritta Task 3):
#' 1. Guardia su input mancante/vuoto -> id=NA, source="NO_TERM".
#' 2. Estrazione candidati via \code{.extract_compound_candidates}.
#' 3. Per ogni candidato: \code{.resolve_one_compound} (gate + catena
#'    ChEBI -> ChEMBL -> de-frammentazione via pref_name -> CHEMBL nativo).
#' 4. Dedup per ID (named list, ultimo vince in caso di collisione).
#' 5. 0 risolti -> STR:<slug> fallback; 1 risolto -> quell'ID;
#'    2 o piu' distinti -> combo: \code{paste(sort(ids), collapse="+")}
#'    source "COMPOUND_COMBO".
#'
#' @param term character(1) termine-composto estratto dai metadati GEO.
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#' @return lista con campi \code{id}, \code{name}, \code{source}.
#' @keywords internal
.normalize_compound_to_chebi <- function(term, ontology_env) {
  if (length(term) != 1L || is.na(term) || !nzchar(term)) {
    return(list(id = NA_character_, name = NA_character_, source = "NO_TERM"))
  }
  cands    <- .extract_compound_candidates(term)
  resolved <- list()
  for (cand in cands) {
    r <- .resolve_one_compound(cand, ontology_env)
    if (!is.null(r)) {
      # Dedup per ID: se lo stesso ID e' raggiunto da candidati diversi (es.
      # nome + codice dello stesso farmaco), vince l'ultimo per campo source
      # (l'ordine dei candidati e' deterministico). Il campo name e' invariante
      # perche' deriva dal primary_name/pref_name canonico dell'ontologia, quindi
      # la scelta del source non cambia l'identita' del composto.
      resolved[[r$id]] <- r
    }
  }
  ids <- names(resolved)
  if (length(ids) == 0L) {
    return(list(id = paste0("STR:", .slugify(term)), name = term, source = "STR_FALLBACK"))
  }
  if (length(ids) == 1L) {
    r <- resolved[[1L]]
    return(list(id = r$id, name = r$name, source = r$source))
  }
  ord <- sort(ids, method = "radix")   # radix: C-locale, deterministico cross-locale
  list(
    id     = paste(ord, collapse = "+"),
    name   = paste(vapply(ord, function(i) resolved[[i]]$name %||% i, character(1L)), collapse = " + "),
    source = "COMPOUND_COMBO"
  )
}

# ---------------------------------------------------------------------------
# Task 7 -- recover_identity (orchestratore pubblico)
# ---------------------------------------------------------------------------

#' Recupera l'identita' biologica di un campione dai metadati GEO grezzi.
#'
#' Orchestratore che compone le funzioni interne Task 1-6 in un flusso
#' prioritario: (1) correzione K2 genetica, (2) normalizzazione malattia,
#' (3) normalizzazione composto/citochina/patogeno, (4) nessun recupero
#' (regime U1). Il campo \code{kind} restituito e' corretto (K2) o invariato
#' rispetto a \code{llm_kind}.
#'
#' @param source character(1) campo \code{source} GEO del campione.
#' @param characteristics character(1) campo \code{characteristics_ch1} GEO.
#' @param title character(1) campo \code{title} GEO del campione.
#' @param llm_kind character(1) \code{kind_effective} emesso dall'LLM Stadio 2.
#' @param ontology_env environment caricato da \code{.load_ontology_dicts()}.
#' @return Lista con quattro campi:
#'   \describe{
#'     \item{kind}{character(1) kind corretto (es. \code{"genetic_knockdown"})
#'       oppure invariato rispetto a \code{llm_kind}.}
#'     \item{agent_id}{character(1) ID ontologico canonico (es.
#'       \code{"MeSH:D011471"}, \code{"CHEBI:16236"}, \code{"HGNC:XRN2"},
#'       \code{"STR:<slug>"}) oppure \code{NA} se non recuperabile.}
#'     \item{canonical_name}{character(1) nome leggibile dell'entita' oppure
#'       \code{NA}.}
#'     \item{recovery_source}{character(1) sorgente del recupero:
#'       \code{"K2_GENETIC"}, \code{"MESH_NAME"}, \code{"CHEBI_ALIAS"},
#'       \code{"STR_FALLBACK"}, \code{"NO_RECOVERY"}.}
#'   }
#' @export
recover_identity <- function(source, characteristics, title, llm_kind, ontology_env) {
  .perturbative_kinds <- c(
    "small_molecule",
    "cytokine_stim",
    "pathogen_or_aggregate_exposure"
  )

  # Passo 1: K2 — perturbazione genetica mal-etichettata come perturbativa
  g <- .detect_genetic_perturbation(source, characteristics, title)
  if (isTRUE(g$is_genetic) && !is.na(llm_kind) && llm_kind %in% .perturbative_kinds) {
    # I2 (review fix): il target K2 va VALIDATO contro HGNC prima di emettere un
    # ID "HGNC:". Un token grezzo estratto dalla forma (es. "DTMYC" da una linea
    # dTAG-MYC) non e' un simbolo gene -> NON fabbricare un ID HGNC inesistente.
    # Se il simbolo risolve -> HGNC:<symbol canonico>; se non risolve -> fallback
    # STR:<slug>; se nessun target -> agent_id NA.
    agent_id       <- NA_character_
    canonical_name <- g$target
    if (!is.na(g$target)) {
      hgnc_hit <- .hgnc_lookup_symbol(g$target, env = ontology_env)
      if (!is.null(hgnc_hit) && !is.null(hgnc_hit$primary_symbol)) {
        agent_id       <- paste0("HGNC:", hgnc_hit$primary_symbol)
        canonical_name <- hgnc_hit$primary_symbol
      } else {
        agent_id <- paste0("STR:", .slugify(g$target))
      }
    }
    return(list(
      kind            = g$genetic_kind,
      agent_id        = agent_id,
      canonical_name  = canonical_name,
      recovery_source = "K2_GENETIC"
    ))
  }

  # Passo 2: disease_vs_normal -> MeSH (o STR fallback) o U1
  if (!is.na(llm_kind) && llm_kind == "disease_vs_normal") {
    t <- .extract_disease_term(source, characteristics, title)
    if (!is.na(t)) {
      n <- .normalize_disease_to_mesh(t, ontology_env)
      return(list(
        kind            = "disease_vs_normal",
        agent_id        = n$id,
        canonical_name  = n$name,
        recovery_source = n$source
      ))
    }
    # Regime U1: nessun termine estraibile
    return(list(
      kind            = "disease_vs_normal",
      agent_id        = NA_character_,
      canonical_name  = NA_character_,
      recovery_source = "NO_RECOVERY"
    ))
  }

  # Passo 3: composto/citochina/patogeno -> ChEBI (o STR fallback)
  if (!is.na(llm_kind) && llm_kind %in% .perturbative_kinds) {
    t <- .extract_agent_term(source, characteristics, title)
    if (!is.na(t)) {
      n <- .normalize_compound_to_chebi(t, ontology_env)
      return(list(
        kind            = llm_kind,
        agent_id        = n$id,
        canonical_name  = n$name,
        recovery_source = n$source
      ))
    }
    return(list(
      kind            = llm_kind,
      agent_id        = NA_character_,
      canonical_name  = NA_character_,
      recovery_source = "NO_RECOVERY"
    ))
  }

  # Passo 4: altri kind (time_course, genetic_*, ecc.) -> nessun recupero
  list(
    kind            = llm_kind,
    agent_id        = NA_character_,
    canonical_name  = NA_character_,
    recovery_source = "NO_RECOVERY"
  )
}

# ---------------------------------------------------------------------------
# Task 6 -- .GENERIC_BIOLOGICAL_STOPLIST + .is_generic_biological
# ---------------------------------------------------------------------------

# Termini biologici generici che NON identificano un agente specifico: citochine
# di classe, virus "nudo", infezione generica, ecc. Usata da Task 7 (citochine)
# e Task 8 (patogeni) per bloccare alias troppo vaghi prima di ogni lookup
# ontologico, analogamente a .GENERIC_COMPOUND_STOPLIST per i farmaci.
#' @keywords internal
.GENERIC_BIOLOGICAL_STOPLIST <- c(
  "cytokine", "cytokines", "interferon", "interleukin", "chemokine",
  "growthfactor", "virus", "viral", "bacteria", "bacterium", "bacterial",
  "pathogen", "infection", "stimulation", "stimulus", "exposure",
  "ligand", "tlr", "agonist"
)

#' Controlla se un termine biologico e' generico (non informativo per il lookup).
#'
#' Un termine e' considerato generico se, dopo normalizzazione via
#' \code{.normalize_biological_mention}, (a) ha meno di 3 caratteri alfanumerici
#' oppure (b) appartiene a \code{.GENERIC_BIOLOGICAL_STOPLIST}.
#' Input vuoto o NA restituisce TRUE (non informativo).
#'
#' @param term character(1) termine da valutare.
#' @return logical(1): TRUE se il termine e' generico/non informativo.
#' @keywords internal
.is_generic_biological <- function(term) {
  norm <- .normalize_biological_mention(term)   # "" su NA/vuoto/lunghezza!=1
  if (!nzchar(norm)) return(TRUE)               # vuoto -> non informativo
  if (nchar(norm) < 3L) return(TRUE)            # alias corto -> non informativo
  norm %in% .GENERIC_BIOLOGICAL_STOPLIST
}

# ---------------------------------------------------------------------------
# Task 5b -- .normalize_biological_mention (forma canonica greco-aware)
# Usata dai dizionari biologici (taxonomy/immport/uniprot) per collassare
# grafie diverse della stessa citochina/patogeno in un'unica chiave di lookup.
# ---------------------------------------------------------------------------

#' Normalizza una menzione biologica a stringa canonica ASCII-alfanumerica.
#'
#' Flusso: (1) guardia su input mancante/vuoto/lunghezza!=1 -> ""; (2) lower +
#' trim; (3) sostituzione lettere greche comuni con il nome latino (fixed=TRUE);
#' (4) rimozione di tutti i caratteri non-[a-z0-9].
#'
#' Esempi: "IFN-β" -> "ifnbeta", "TNF-α" -> "tnfalpha",
#' "poly(I:C)" -> "polyic".
#'
#' @param x character(1) stringa da normalizzare.
#' @return character(1) forma canonica; "" su input vuoto/NA/lunghezza!=1.
#' @keywords internal
.normalize_biological_mention <- function(x) {
  if (length(x) != 1L || is.na(x) || !nzchar(x)) return("")
  s <- tolower(trimws(x))
  # Sostituzione lettere greche comuni (caratteri UTF-8 diretti nel sorgente)
  greci <- c(
    "α" = "alpha",   # α
    "β" = "beta",    # β
    "γ" = "gamma",   # γ
    "δ" = "delta",   # δ
    "κ" = "kappa",   # κ
    "ω" = "omega"    # ω
  )
  for (g in names(greci)) s <- gsub(g, greci[[g]], s, fixed = TRUE)
  gsub("[^a-z0-9]+", "", s)
}

# Segnali genetici (K2). Spec: is_genetic SOLO su segnali inequivocabili.
#
# DUE famiglie di pattern testate separatamente per ogni kind:
# - CI (case-INsensitive): termini robustamente inequivocabili che NON dipendono
#   dal case (knockout, knockdown, shRNA, siRNA, crispr, cas9, sgrna, dtag,
#   degron, fkbp12, overexpression). Il depletion e' ristretto a
#   (protein|targeted|degron)[ -]?depletion per NON catturare "serum depletion"
#   o "glucose depletion".
# - CS (case-SENSITIVE): pattern di FORMA (sh/si minuscolo + simbolo gene
#   MAIUSCOLO; KO/AID maiuscoli; oe minuscolo). Con ignore.case questi
#   annullerebbero il loro intento e flipperebbero "simvastatin", "sirolimus",
#   "Resiquimod", "single cell", "signal transduction" a genetic_* (review C1).
# auxin/IAA NON sono piu' trigger autonomi: contano solo accompagnati da
# degron/AID, che gia' triggerano per conto loro.
.GENETIC_SIGNALS_CI <- c(
  knockout       = "knock-?out|crispr|\\bcas9\\b|sgrna|gene deletion",
  knockdown      = paste0("knock-?down|\\bshrna\\b|\\bsirna\\b|dtag|degron|fkbp12|",
                          "(protein|targeted|degron)[ -]?depletion"),
  overexpression = "over-?expression|overexpress|ectopic expression")

.GENETIC_SIGNALS_CS <- c(
  knockout       = "\\bKO\\b|\\bAID\\b",
  knockdown      = "sh[A-Z][A-Z0-9]+|si[A-Z][A-Z0-9]+",
  overexpression = "\\boe\\b")

#' Rileva perturbazione genetica inequivocabile (K2) + gene bersaglio se possibile
#' @keywords internal
.detect_genetic_perturbation <- function(source, characteristics, title) {
  blob <- paste(source %||% "", characteristics %||% "", title %||% "")
  none <- list(is_genetic = FALSE, genetic_kind = NA_character_, target = NA_character_)
  kind <- NA_character_
  for (nm in names(.GENETIC_SIGNALS_CI)) {
    ci_pat <- .GENETIC_SIGNALS_CI[[nm]]
    cs_pat <- .GENETIC_SIGNALS_CS[[nm]]
    ci_hit <- nzchar(ci_pat) && grepl(ci_pat, blob, perl = TRUE, ignore.case = TRUE)
    cs_hit <- nzchar(cs_pat) && grepl(cs_pat, blob, perl = TRUE, ignore.case = FALSE)
    if (ci_hit || cs_hit) {
      kind <- paste0("genetic_", nm); break
    }
  }
  if (is.na(kind)) return(none)
  # estrai gene bersaglio: token in MAIUSCOLO adiacente a un segnale (es. XRN2-dTAG, shTP53)
  m <- regmatches(blob, regexpr("\\b[A-Z][A-Z0-9]{1,6}(?=[- ]?(dTAG|AID|degron|KO|KD))", blob, perl = TRUE))
  m2 <- regmatches(blob, regexpr("(?<=\\b(sh|si))[A-Z][A-Z0-9]{1,6}", blob, perl = TRUE))
  target <- c(m, m2)
  list(is_genetic = TRUE, genetic_kind = kind,
       target = if (length(target)) target[[1L]] else NA_character_)
}
