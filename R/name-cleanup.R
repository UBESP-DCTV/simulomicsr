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
    # Usa il simbolo canonico ritornato dall'accessor (NON l'input grezzo):
    # .hgnc_lookup_symbol risolve sia simboli primari che alias storici (es.
    # "BSF2" -> IL6), quindi l'ID va costruito sul primary_symbol per non
    # rompere il dedup cross-studio (mirror di R/anchors.R HGNC path).
    list(resolved_id = paste0("HGNC:", hit$primary_symbol),
         resolved_name = hit$primary_symbol %||% nm, match_strength = "STRONG")
  }
  try_taxon <- function() {
    hit <- .taxonomy_lookup_name(nm, env)
    if (is.null(hit)) return(NULL)
    list(resolved_id = paste0("NCBITaxon:", hit$taxid), resolved_name = nm, match_strength = "STRONG")
  }

  # Guardia difensiva: switch() richiede EXPR scalare non-NA. Un `kind`
  # character(0)/NA/multi-elemento (possibile da JSON LLM malformato) cade
  # sulla catena catch-all invece di andare in errore.
  if (length(kind) != 1L || is.na(kind)) kind <- ""

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

#' Applica la policy di override precision-gated (pulizia-nomi, scope A).
#'
#' Decide l'azione da applicare a un cluster dato l'esito Mistral (relabel +
#' `confidence`) e la risoluzione ontologica deterministica (`.resolve_canonical_to_id`).
#' Regole (precision-gated: override SOLO su match forte e non-ambiguo):
#' - match `NONE` o `mistral_confidence == "low"`: `"keep"` (nessun cambio),
#'   `name_llm_unvalidatable = TRUE` (il cluster resta irrisolto, tracciato per audit).
#' - match `STRONG` con `resolved_id` identico all'ID attuale: `"noop"` (gia' corretto).
#' - match `STRONG` con `resolved_id` diverso su un cluster `canary` (gia' ben
#'   nominato, controllo di non-regressione): `"flag_review"` — NON si applica
#'   l'override in automatico, il disaccordo va rivisto a mano.
#' - match `STRONG` con `resolved_id` diverso su un cluster `candidate` (coda
#'   mal-etichettata): `"override"`, source `"mistral_fallback"`.
#'
#' @param current_id character(1) ID anchor attuale del cluster.
#' @param mistral_confidence character(1) confidence del relabel LLM (`high`/`medium`/`low`).
#' @param resolution lista `list(resolved_id, resolved_name, match_strength)`,
#'   esito di `.resolve_canonical_to_id`.
#' @param role character(1) `"candidate"` o `"canary"` (da `.load_name_cleanup_candidates`).
#' @return lista `list(action, new_id, new_name, name_recovery_source, name_llm_unvalidatable)`.
#' @keywords internal
#' @noRd
.apply_name_cleanup_policy <- function(current_id, mistral_confidence, resolution, role) {
  keep <- list(action = "keep", new_id = NA_character_, new_name = NA_character_,
               name_recovery_source = NA_character_, name_llm_unvalidatable = TRUE)
  if (!identical(resolution$match_strength, "STRONG") || identical(mistral_confidence, "low"))
    return(keep)
  if (identical(resolution$resolved_id, current_id))
    return(list(action = "noop", new_id = resolution$resolved_id,
                new_name = resolution$resolved_name,
                name_recovery_source = NA_character_, name_llm_unvalidatable = FALSE))
  if (identical(role, "canary"))
    return(list(action = "flag_review", new_id = NA_character_, new_name = NA_character_,
                name_recovery_source = NA_character_, name_llm_unvalidatable = FALSE))
  list(action = "override", new_id = resolution$resolved_id,
       new_name = resolution$resolved_name,
       name_recovery_source = "mistral_fallback", name_llm_unvalidatable = FALSE)
}

#' Orchestratore pulizia-nomi: per ogni candidato chiama l'LLM, risolve l'ID
#' deterministicamente, applica la policy, ritorna la side-table.
#'
#' Per ciascuna riga di `candidates` costruisce i messaggi (Task 4), chiama
#' `llm_fn` (iniettato: in produzione un wrapper su
#' `llm_call_structured(provider="vllm", ..., cache=..., cache_namespace_version=
#' .NAME_CLEANUP_CACHE_VERSION)`), risolve il nome canonico via
#' `.resolve_canonical_to_id` (Task 6, chiamata come funzione libera cosi'
#' e' mockabile), applica la policy precision-gated (Task 7) e assembla la
#' side-table finale. Un fallimento di `llm_fn` (errore o output senza
#' `canonical_name`) degrada all'esito NONE/low = nessun override, cluster
#' marcato `name_llm_unvalidatable`.
#'
#' @param candidates tibble da `.load_name_cleanup_candidates` (colonne
#'   `cluster_id, name, kind, k, top_theme, role`).
#' @param current_ids chr con nomi, `cluster_id -> old_id` (l'anchor_key attuale).
#' @param member_metadata lista `cluster_id -> stringa metadati grezzi` (da
#'   `.build_cluster_member_metadata`).
#' @param llm_fn function(messages) -> list(canonical_name, kind, confidence, evidence).
#' @param env environment dizionari ontologia. Default: `.load_ontology_dicts()`.
#' @return tibble side-table: `cluster_id, old_id, old_label, new_canonical,
#'   new_id, new_kind, match_strength, confidence, action,
#'   name_recovery_source, name_llm_unvalidatable, evidence`.
#' @keywords internal
#' @noRd
run_name_cleanup <- function(candidates, current_ids, member_metadata, llm_fn,
                             env = .load_ontology_dicts()) {
  rows <- lapply(seq_len(nrow(candidates)), function(i) {
    cid <- candidates$cluster_id[i]
    msgs <- .build_name_cleanup_messages(candidates$name[i], candidates$kind[i],
                                         member_metadata[[cid]] %||% "")
    out <- tryCatch(llm_fn(msgs), error = function(e) NULL)
    if (is.null(out) || is.null(out$canonical_name)) {
      res <- .none_resolution(); conf <- "low"; ckind <- NA_character_; ev <- NA_character_
    } else {
      ckind <- out$kind %||% candidates$kind[i]
      conf <- out$confidence %||% "low"; ev <- out$evidence %||% NA_character_
      res <- .resolve_canonical_to_id(out$canonical_name, ckind, env)
    }
    pol <- .apply_name_cleanup_policy(unname(current_ids[cid]), conf, res, candidates$role[i])
    tibble::tibble(
      cluster_id = cid, old_id = unname(current_ids[cid]), old_label = candidates$name[i],
      new_canonical = res$resolved_name, new_id = pol$new_id, new_kind = ckind,
      match_strength = res$match_strength, confidence = conf, action = pol$action,
      name_recovery_source = pol$name_recovery_source,
      name_llm_unvalidatable = pol$name_llm_unvalidatable, evidence = ev)
  })
  dplyr::bind_rows(rows)
}
