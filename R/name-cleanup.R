# Pulizia-nomi (scope A): relabel della coda mal-etichettata via Mistral +
# risoluzione ontologica deterministica. Vedi
# docs/superpowers/specs/2026-07-06-name-cleanup-mistral-design.md.

.NAME_CLEANUP_CACHE_VERSION <- "nameclean.v1"

# Entità HTML comuni nei nomi ChEBI -> unicode.
.NAME_MARKUP_ENTITIES <- c(
  "&alpha;" = "α", "&beta;" = "β", "&gamma;" = "γ", "&delta;" = "δ",
  "&#945;" = "α", "&#946;" = "β", "&#947;" = "γ", "&middot;" = "·", "&amp;" = "&")

#' @keywords internal
#' @noRd
.strip_name_markup <- function(x) {
  s <- .normalize_key_chr(x)
  if (is.na(s)) return(NA_character_)
  s <- gsub("<[^>]+>", "", s)                    # tag HTML
  for (e in names(.NAME_MARKUP_ENTITIES)) s <- gsub(e, .NAME_MARKUP_ENTITIES[[e]], s, fixed = TRUE)
  s <- gsub("&#[0-9]+;", "", s)                  # entità numeriche residue
  s <- trimws(s)
  if (!nzchar(s)) NA_character_ else s
}

#' Carica i candidati alla pulizia-nomi dal triage CSV.
#'
#' Legge il triage (`cluster_id,name,kind,k,n_studies,homog,top_theme,name_ok,cls`)
#' e restituisce solo i cluster rilevanti per il relabel: `candidate` = coda
#' mal-etichettata (`OMOGENEO+MAL_nominato` o `ETEROGENEO(sospetto)`), `canary`
#' = gia' ben nominato (controllo di non-regressione). `vehicle/none` escluso
#' (non e' materia di pulizia-nomi).
#'
#' @keywords internal
#' @noRd
.load_name_cleanup_candidates <- function(triage_csv_path) {
  d <- utils::read.csv(triage_csv_path, stringsAsFactors = FALSE, check.names = FALSE)
  d <- d[d$cls != "vehicle/none", , drop = FALSE]
  d$role <- ifelse(d$cls == "OMOGENEO+ben_nominato", "canary", "candidate")
  tibble::tibble(cluster_id = as.character(d$cluster_id), name = as.character(d$name),
                 kind = as.character(d$kind), k = as.integer(d$k),
                 top_theme = as.character(d$top_theme), role = d$role)
}

#' Costruisce i metadati grezzi dei membri per ciascun cluster.
#'
#' Per ogni `cluster_id` risolve i `record_id` assegnati (`assignments`) in
#' GSM via `rec_env` (output di `build_record_gsm_lookup`), recupera il testo
#' grezzo corrispondente da `gsm_text`, deduplica e concatena con `" | "`,
#' troncando a `char_budget` caratteri (prompt Mistral non deve esplodere su
#' cluster con migliaia di membri).
#'
#' @keywords internal
#' @noRd
.build_cluster_member_metadata <- function(cluster_ids, assignments, rec_env,
                                           gsm_text, char_budget = 6000L) {
  out <- vector("list", length(cluster_ids)); names(out) <- cluster_ids
  for (cid in cluster_ids) {
    recs <- assignments$record_id[assignments$cluster_id == cid]
    gsms <- unique(unlist(lapply(recs, function(r)
      get0(r, envir = rec_env, inherits = FALSE)), use.names = FALSE))
    txt <- unique(gsm_text[intersect(gsms, names(gsm_text))])
    joined <- paste(txt, collapse = " | ")
    if (nchar(joined) > char_budget) joined <- substr(joined, 1L, char_budget)
    out[[cid]] <- joined
  }
  out
}

#' Prompt di sistema per il relabel LLM (pulizia-nomi, scope A).
#'
#' Istruisce Mistral a identificare l'entita' biologica REALE (composto,
#' citochina, patogeno, malattia) dietro un'etichetta di cluster sospetta,
#' usando solo i metadati grezzi dei campioni membri (NON il `top_theme`,
#' che resta un oracolo indipendente per la validazione a valle). Risposta
#' vincolata allo schema `name_cleanup.v1.json`.
#'
#' @keywords internal
#' @noRd
.name_cleanup_system_prompt <- function() {
  paste0(
    "Sei un curatore esperto di metadati GEO/RNA-seq. Ricevi l'etichetta ATTUALE ",
    "(potenzialmente sbagliata) di un gruppo di campioni e i loro metadati grezzi. ",
    "Identifica l'entita' biologica REALE (composto, citochina, patogeno, malattia) ",
    "che accomuna i campioni trattati/caso. Rispondi SOLO con un JSON: ",
    "{canonical_name, kind, confidence(high|medium|low), evidence}. ",
    "canonical_name = nome canonico piu' riconoscibile (es. 'lipopolysaccharide', ",
    "non una sigla ambigua). Se i metadati non bastano, confidence='low'.")
}

#' Costruisce i messaggi (system+user) per il relabel LLM di un cluster.
#'
#' Il messaggio utente incapsula SOLO l'etichetta attuale, il kind atteso e i
#' metadati grezzi dei membri: NON include `top_theme` (oracolo indipendente
#' tenuto fuori dal prompt per non contaminare la valutazione a valle).
#'
#' @param current_label etichetta attuale sospetta del cluster
#' @param kind kind atteso (es. "small_molecule", "cytokine_stim")
#' @param member_metadata metadati grezzi dei campioni membri (stringa concatenata)
#' @return lista di 2 messaggi `list(role=,content=)`, system poi user
#' @keywords internal
#' @noRd
.build_name_cleanup_messages <- function(current_label, kind, member_metadata) {
  user <- paste0(
    "Etichetta attuale (sospetta): ", current_label, "\n",
    "Kind atteso: ", kind, "\n",
    "Metadati grezzi dei campioni membri:\n", member_metadata)
  list(list(role = "system", content = .name_cleanup_system_prompt()),
       list(role = "user",   content = user))
}

#' Esito di risoluzione ontologica vuoto (nessun match).
#'
#' @keywords internal
#' @noRd
.none_resolution <- function() {
  list(resolved_id = NA_character_, resolved_name = NA_character_, match_strength = "NONE")
}

#' Risolve un nome canonico a un ID di ontologia controllata (precision gate).
#'
#' Dispatcha sull'accessor giusto in base al `kind` atteso e ritorna un match
#' "STRONG" solo su hit esatto dell'accessor deterministico (nessun fuzzy
#' matching qui: quello e' compito del passo LLM a monte). Kind ignoto prova
#' tutte le ontologie in ordine (ChEBI, MeSH, HGNC, taxonomy).
#'
#' @param canonical_name character(1) nome canonico (es. da relabel LLM).
#' @param kind character(1) kind atteso (`small_molecule`, `vehicle_only`,
#'   `disease_vs_normal`, `cytokine_stim`, `pathogen_or_aggregate_exposure`,
#'   o altro).
#' @param env environment dizionari ontologia. Default: `.load_ontology_dicts()`.
#' @return lista `list(resolved_id, resolved_name, match_strength)`.
#' @keywords internal
#' @noRd
.resolve_canonical_to_id <- function(canonical_name, kind, env = .load_ontology_dicts()) {
  nm <- .strip_name_markup(canonical_name)
  if (is.na(nm)) return(.none_resolution())

  try_chebi <- function() {
    hit <- .chebi_lookup_alias(nm, env)
    if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("CHEBI:", hit$chebi_id), resolved_name = nm, match_strength = "STRONG")
  }
  try_mesh <- function() {
    hit <- .mesh_lookup_term(nm, env)
    if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("MeSH:", hit$ui), resolved_name = nm, match_strength = "STRONG")
  }
  try_hgnc <- function() {
    hit <- .hgnc_lookup_symbol(nm, env)
    if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("HGNC:", toupper(nm)), resolved_name = nm, match_strength = "STRONG")
  }
  try_taxon <- function() {
    hit <- .taxonomy_lookup_name(nm, env)
    if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("NCBITaxon:", hit$taxid), resolved_name = nm, match_strength = "STRONG")
  }

  chain <- switch(kind,
    small_molecule = list(try_chebi),
    vehicle_only   = list(try_chebi),
    disease_vs_normal = list(try_mesh),
    cytokine_stim  = list(try_hgnc, try_chebi),
    pathogen_or_aggregate_exposure = list(try_taxon, try_chebi),
    list(try_chebi, try_mesh, try_hgnc, try_taxon))  # kind ignoto: prova tutto

  for (f in chain) {
    r <- f()
    if (!is.null(r)) return(r)
  }
  .none_resolution()
}
