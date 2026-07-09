# Triage sospetti/canary/skip da clusters.rds v9-pre re-cluster (v9 Fase C).
# Vedi docs/superpowers/{specs,plans}/2026-06-28-stage3-perturbative-name-recovery-B-*
# §2 (portata generosa) e .superpowers/sdd/task-7-brief.md. Generalizza la
# logica esplorativa di analysis/audit/2026-07-05-stage4-popB-coherence-check.R,
# ma opera SOLO sulle colonne di clusters.rds (NIENTE H5: e' un triage
# pre-recluster, non un controllo di supporto sui metadati grezzi membro-per-membro).

# Stoplist di nomi interi improbabili come perturbazione specifica (classi
# generiche ChEBI/MeSH: "carcinoma"/"agents" da soli non sono mai l'entita'
# reale dietro un cluster, sono residuo di risoluzione troppo larga). Match
# sul nome INTERO (trim+lower), non per token: evita falsi positivi su nomi
# specifici che contengono la parola (es. "Alzheimer's disease" non e'
# "disease"). Sottoinsieme dello stop-token-list esplorativa del coherence
# check 2026-07-05, ristretto a termini plausibili come nome-intero.
.GARBAGE_NAME_STOPLIST <- c(
  "neoplasms", "neoplasm", "disease", "diseases", "disorder", "disorders",
  "syndrome", "syndromes", "agents", "agent", "cell", "cells", "carcinoma",
  "tumor", "tumour", "inhibitors", "antineoplastic agents", "unknown",
  "other", "control", "none", "na")

#' Segnala un nome cluster "garbage/formale" (candidato a pulizia-nomi).
#'
#' Euristiche riprese da \code{analysis/audit/2026-07-05-stage4-popB-coherence-check.R}
#' (\code{is_formal}): un nome con markup HTML residuo, molte cifre, tanti
#' trattini o lettere greche e' tipicamente un nome ChEBI/MeSH sistematico
#' poco leggibile — non necessariamente SBAGLIATO, ma abbastanza opaco da
#' giustificare una verifica Mistral in piu' (costo basso: la policy a valle
#' e' precision-gated, un cluster gia' corretto torna semplicemente "noop").
#' Va chiamata sul \code{canonical_name} GREZZO (pre \code{.strip_name_markup}):
#' il markup HTML e' proprio il segnale che lo strip rimuoverebbe, quindi va
#' controllato PRIMA dello strip.
#'
#' @param name character(1) nome grezzo del cluster (\code{canonical_name},
#'   eventualmente con markup HTML residuo). \code{NA} o stringa vuota conta
#'   come garbage (nulla su cui fare affidamento).
#' @return logical(1).
#' @keywords internal
.is_garbage_name <- function(name) {
  if (length(name) != 1L || is.na(name) || !nzchar(trimws(name))) return(TRUE)
  if (grepl("<[^>]+>", name)) return(TRUE)                 # tag HTML residuo
  if (grepl("[0-9].*[0-9].*[0-9]", name)) return(TRUE)      # >= 3 cifre
  if (grepl("(-.*){3,}", name)) return(TRUE)                 # > 2 trattini
  if (grepl("α|β|γ", name)) return(TRUE)      # lettere greche alfa/beta/gamma
  if (tolower(trimws(name)) %in% .GARBAGE_NAME_STOPLIST) return(TRUE)
  FALSE
}

#' Estrae il 3o campo pipe-delimited (tissue/context) da un `anchor_key`.
#'
#' @param anchor_key character(1) `anchor_key` v3.1 (`kind|agent_id|tissue|...`).
#' @return character(1) il 3o campo, o `""` se `anchor_key` e' NA o ha meno di
#'   3 campi.
#' @keywords internal
.anchor_key_top_theme <- function(anchor_key) {
  if (length(anchor_key) != 1L || is.na(anchor_key)) return("")
  parts <- strsplit(anchor_key, "|", fixed = TRUE)[[1]]
  if (length(parts) >= 3L) parts[[3L]] else ""
}

#' Triage sospetti/canary/skip da `clusters.rds` (v9-pre re-cluster, Fase C).
#'
#' Classifica ogni cluster in candidato alla pulizia-nomi Mistral
#' (`role = "candidate"`), canary (nome gia' noto-buono, controllo di
#' non-regressione, `role = "canary"`) o skip (non materia di pulizia-nomi,
#' `role = NA`). Opera SOLO sulle colonne di `clusters` passate in input —
#' NESSUN accesso H5 (il triage e' pre-recluster; "portata generosa" per
#' design: include anche frammenti piccoli con nome-spazzatura, meglio un
#' falso sospetto in piu' — costa un giro Mistral in piu', precision-gated a
#' valle — che un vero mal-nominato lasciato fuori).
#'
#' **Classificazione** (in ordine di precedenza):
#' 1. **skip per kind** (precede TUTTO): `kind_effective_resolved` in
#'    `c("vehicle_only", "none")` non e' mai una perturbazione da
#'    nome-pulire, a prescindere dagli altri segnali.
#' 2. **sospetto** (batte canary se entrambi scatterebbero): `agent_id_resolved`
#'    e' `NA`, inizia per `"STR:"` o `"UNK"`; oppure `kind_chebi_zero_roles`;
#'    oppure `kind_confidence` in `c("NONE", "WEAK")`; oppure il nome e'
#'    "garbage/formale" (\code{\link{.is_garbage_name}}, valutata sul
#'    `canonical_name` GREZZO — vedi nota su markup HTML li').
#' 3. **canary**: non sospetto, `agent_id_resolved` ha un prefisso ontologico
#'    forte (`HGNC|CHEBI|NCBITaxon|CHEMBL|MeSH`), `kind_confidence == "STRONG"`
#'    e `k >= 3`.
#' 4. **skip** (default): tutto il resto (es. nome forte ma `k < 3`: non
#'    abbastanza studi per fidarsi come canary, ma nemmeno un segnale di
#'    sospetto — resta fuori dal batch).
#'
#' Mantiene lo SCHEMA CSV legacy atteso da `.load_name_cleanup_candidates()`
#' (`cluster_id,name,kind,k,n_studies,homog,top_theme,name_ok,cls`),
#' incluso il vocabolario di `cls` (`OMOGENEO+ben_nominato`,
#' `OMOGENEO+MAL_nominato`, `vehicle/none`), cosi' che `run_name_cleanup()`
#' (INVARIATA) la consumi senza modifiche e un round-trip CSV attraverso
#' `.load_name_cleanup_candidates()` riproduca lo stesso `role` calcolato qui
#' — e' il meccanismo di sicurezza dei canary (validato in T13).
#'
#' @param clusters tibble `clusters.rds`. Richiede le colonne `cluster_id,
#'   anchor_key, kind_effective_resolved, canonical_name, agent_id_resolved,
#'   k, n_studies, kind_confidence, kind_chebi_zero_roles`; le altre colonne
#'   sono ignorate (robusto a schema piu' ampio).
#' @param min_k integer(1), soglia minima di `k` per includere un cluster nel
#'   triage (default `1L` = nessun filtro). Cluster con `k < min_k` sono
#'   esclusi del tutto (non compaiono in output, nemmeno come skip).
#' @return tibble `cluster_id, name, kind, k, n_studies, homog, top_theme,
#'   name_ok, cls, role`. `name` = `canonical_name` ripulito dal markup
#'   (\code{\link{.strip_name_markup}}). `homog` = `NA_character_` (placeholder
#'   di compatibilita' schema: la coerenza-membri richiede H5, non disponibile
#'   qui). `name_ok` = `TRUE` solo sui cluster classificati canary.
#' @keywords internal
.build_suspect_triage <- function(clusters, min_k = 1L) {
  empty <- tibble::tibble(
    cluster_id = character(0), name = character(0), kind = character(0),
    k = integer(0), n_studies = integer(0), homog = character(0),
    top_theme = character(0), name_ok = logical(0), cls = character(0),
    role = character(0))
  if (nrow(clusters) == 0L) return(empty)

  keep <- !is.na(clusters$k) & clusters$k >= min_k
  cl <- clusters[keep, , drop = FALSE]
  if (nrow(cl) == 0L) return(empty)

  agent <- cl$agent_id_resolved

  # Sospetto: ID debole/mancante, zero-roles ChEBI, confidence bassa, o nome
  # garbage/formale (grepl() e' NA-safe -> FALSE su agent NA, quindi
  # is.na(agent) va aggiunto esplicitamente).
  is_str_unk  <- is.na(agent) | grepl("^STR:", agent) | grepl("^UNK", agent)
  is_zero_rl  <- !is.na(cl$kind_chebi_zero_roles) & cl$kind_chebi_zero_roles
  is_weak_cnf <- cl$kind_confidence %in% c("NONE", "WEAK")
  is_garbage  <- vapply(cl$canonical_name, .is_garbage_name, logical(1))
  is_suspect  <- is_str_unk | is_zero_rl | is_weak_cnf | is_garbage

  # Canary: solo se NON sospetto, ID ontologico forte, confidence STRONG, k>=3.
  strong_agent <- grepl("^(HGNC|CHEBI|NCBITaxon|CHEMBL|MeSH):", agent)
  strong_conf  <- cl$kind_confidence %in% "STRONG"
  k_ge3        <- !is.na(cl$k) & cl$k >= 3L
  is_canary    <- !is_suspect & strong_agent & strong_conf & k_ge3

  # Skip per kind: mai una perturbazione, precede sospetto e canary.
  is_skip_kind <- cl$kind_effective_resolved %in% c("vehicle_only", "none")

  cls <- ifelse(is_skip_kind, "vehicle/none",
          ifelse(is_suspect, "OMOGENEO+MAL_nominato",
           ifelse(is_canary, "OMOGENEO+ben_nominato", "vehicle/none")))
  role <- ifelse(cls == "OMOGENEO+ben_nominato", "canary",
           ifelse(cls == "vehicle/none", NA_character_, "candidate"))

  name      <- vapply(cl$canonical_name, .strip_name_markup, character(1))
  top_theme <- vapply(cl$anchor_key, .anchor_key_top_theme, character(1))

  tibble::tibble(
    cluster_id = cl$cluster_id, name = unname(name), kind = cl$kind_effective_resolved,
    k = as.integer(cl$k), n_studies = as.integer(cl$n_studies),
    homog = NA_character_, top_theme = unname(top_theme),
    name_ok = cls == "OMOGENEO+ben_nominato", cls = cls, role = role)
}
