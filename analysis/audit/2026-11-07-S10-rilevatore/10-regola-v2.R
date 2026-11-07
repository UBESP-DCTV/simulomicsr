# 10-regola-v2.R — S10: la regola di riga corretta, FUORI dal pacchetto.
#
# R/stage3-row-pairing.R NON si tocca. Questo file definisce quattro varianti
# cumulative della regola di riga, da misurare sugli stessi ingressi della
# produzione (catturati da 20-ingressi-regola.R):
#
#   V0  la regola di produzione, `.rp_row_defect()`, chiamata cosi' com'e';
#   V1  V0 + traduzione delle lettere greche (insieme G e traduzione della S9,
#       01-traduzione.R) nelle due etichette e nei testi da cui escono i token
#       dell'entita';
#   V2  V1 + soglia della combinazione: ">= 1 agente in piu' nel trattato DOPO
#       aver tolto l'entita' del gruppo", invece di ">= 2 agenti in piu'";
#   V3  V2 + regola nuova "materiale_diverso": i due bracci dichiarano due
#       sistemi biologici diversi (staminali, tridimensionale, linea, primaria,
#       tessuto, xenotrapianto).
#
# Ogni variante cambia UNA cosa rispetto alla precedente: la misura dice quanto
# porta ciascuna correzione. Tutto e' congelato con il commit delle previsioni,
# PRIMA di vedere un solo esito sui 1.903 confronti.
#
# "Togliere l'entita' del gruppo" (V2), definizione congelata. Un agente del
# trattato e' l'entita' se vale una di queste:
#   (a) il suo ID e' l'entita' del gruppo, o una parte di un'entita' COMBO:;
#   (b) il suo token e' uno dei token dell'entita' (gli stessi che la
#       produzione passa come `extra_stop`, piu' quelli dei testi tradotti);
#   (c) il suo ID e' l'ID che i resolver danno a uno dei token dell'entita'.
# (c) serve quando l'etichetta e l'entita' usano lo stesso nome ma il resolver
# lo porta a un ID diverso da quello del gruppo (misurato in S9: "TNF-alpha" ->
# ChEMBL invece di HGNC:11892). Per le entita' COMBO: la produzione esclude la
# regola; qui si tolgono le parti e si applica la soglia a ">= 1".
#
# La regola sull'agente vale per tutte le classi, come in produzione: nessuna
# eccezione nuova per le malattie.
#
# Uso: source() dopo devtools::load_all(".").

source("analysis/audit/2026-11-07-S9-greche-e-corsie/01-traduzione.R")
`%||%` <- function(a, b) if (is.null(a)) b else a

.tr <-function(x) as.vector(traduci_G(x))

#' Gli agenti di un'etichetta con il token che li ha prodotti.
#' Stessa tokenizzazione, stessa esclusione dei prefissi e stessa catena di
#' resolver di `.rp_agents()` (R/stage3-row-pairing.R:292): cambia solo che il
#' risultato tiene il token.
rp_agents_tok <- function(x, ontology_env, cache = NULL) {
  ns <- asNamespace("simulomicsr")
  tok <- strsplit(ns$.rp_strip_dose_time(gsub("[^A-Za-z0-9 -]", " ", x %||% "")), " +")[[1L]]
  tok <- unique(tok[nchar(gsub("[^a-z0-9]", "", tok)) >= 3L & !(tok %in% ns$.RP_NOT_AGENT)])
  if (length(tok) > 1L) {
    is_prefix <- vapply(tok, function(t) any(tok != t & startsWith(tok, t)), logical(1))
    tok <- tok[!is_prefix]
  }
  if (!length(tok)) return(data.frame(token = character(0), id = character(0)))
  ids <- vapply(tok, function(t) rp_resolve_token(t, ontology_env, cache), character(1))
  keep <- nzchar(ids)
  data.frame(token = tok[keep], id = unname(ids[keep]), stringsAsFactors = FALSE)
}

#' Un token -> ID canonico ("" se nessuno), con la catena di `.rp_agents()`.
rp_resolve_token <- function(t, ontology_env, cache = NULL) {
  ns <- asNamespace("simulomicsr")
  if (!is.null(cache) && exists(t, envir = cache, inherits = FALSE)) return(get(t, envir = cache))
  is_canonical <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  id <- ""
  r <- ns$.normalize_compound_to_chebi(t, ontology_env); if (is_canonical(r$id)) id <- r$id
  if (!nzchar(id)) { r <- ns$.normalize_cytokine_to_hgnc(t, ontology_env); if (is_canonical(r$id)) id <- r$id }
  if (!nzchar(id)) { r <- ns$.normalize_pathogen_to_taxid(t, ontology_env); if (is_canonical(r$id)) id <- r$id }
  if (!is.null(cache)) assign(t, id, envir = cache)
  id
}

#' V2: il trattato porta almeno un agente che il controllo non ha, tolta l'entita'.
rp_extra_agent_v2 <- function(tl, cl, entity, extra_stop, ontology_env, cache) {
  at <- rp_agents_tok(tl, ontology_env, cache)
  if (!nrow(at)) return(FALSE)
  ac <- rp_agents_tok(cl, ontology_env, cache)
  ent_ids <- character(0)
  if (length(entity) && !is.na(entity)) {
    ent_ids <- if (startsWith(entity, "COMBO:"))
      strsplit(sub("^COMBO:", "", entity), "+", fixed = TRUE)[[1L]] else entity
  }
  stop_tok <- unique(extra_stop[nzchar(extra_stop)])
  stop_ids <- vapply(stop_tok, function(t) rp_resolve_token(t, ontology_env, cache), character(1))
  stop_ids <- stop_ids[nzchar(stop_ids)]
  e <- at$id %in% ent_ids | at$token %in% stop_tok | at$id %in% stop_ids
  resto <- unique(at$id[!e])
  length(setdiff(resto, ac$id)) >= 1L
}

# ------------------------------------------------------- V3: il materiale ------
# Sistemi biologici dichiarati nell'etichetta. Parole intere, su testo minuscolo
# in cui `_`, `|` e i segni non alfanumerici sono separatori; ogni termine si
# cerca sia con i trattini sia con i trattini resi spazi ("iPSC-derived").
# I tempi si tolgono prima (`.rp_strip_dose_time`): "3d" e' tre giorni, non 3D.
# "primary" da solo NON basta ("primary tumor" non e' una coltura primaria).
.MAT_SISTEMI <- list(
  staminali      = c("ipsc", "ipscs", "hipsc", "hipscs", "ips cell", "ips cells",
                     "esc", "escs", "hesc", "hescs", "embryonic stem",
                     "induced pluripotent", "pluripotent stem"),
  tridimensionale = c("organoid", "organoids", "spheroid", "spheroids",
                      "three dimensional", "three-dimensional"),
  linea          = c("cell line", "cell lines", "immortalized", "immortalised"),
  primaria       = c("primary cell", "primary cells", "primary culture",
                     "primary cultures", "primary cultured", "freshly isolated"),
  tessuto        = c("tissue", "tissues", "biopsy", "biopsies", "resection",
                     "resected", "explant", "explants"),
  xenotrapianto  = c("xenograft", "xenografts", "pdx")
)

#' I sistemi biologici dichiarati in un'etichetta (vettore, anche vuoto).
rp_sistemi <- function(x) {
  ns <- asNamespace("simulomicsr")
  s <- ns$.rp_strip_dose_time(x %||% "")
  s <- gsub("[^a-z0-9 -]+", " ", s)
  p1 <- paste0(" ", gsub("\\s+", " ", trimws(s)), " ")
  p2 <- paste0(" ", gsub("\\s+", " ", trimws(gsub("-", " ", s))), " ")
  out <- character(0)
  # "primary" seguito da un tipo cellulare del gate ("primary human hepatocytes")
  ct <- paste(ns$.CG_CELLTYPES, collapse = "|")
  if (grepl(paste0(" primary (human |murine |mouse )?(", ct, ") "), p2, perl = TRUE)) out <- "primaria"
  for (nm in names(.MAT_SISTEMI)) {
    if (nm %in% out) next
    for (t in .MAT_SISTEMI[[nm]]) {
      tt <- paste0(" ", t, " ")
      if (grepl(tt, p1, fixed = TRUE) || grepl(tt, p2, fixed = TRUE)) { out <- c(out, nm); break }
    }
  }
  out
}

#' V3: i due bracci dichiarano sistemi biologici e non ne hanno uno in comune.
rp_material_mismatch <- function(tl, cl) {
  a <- rp_sistemi(tl); b <- rp_sistemi(cl)
  length(a) > 0L && length(b) > 0L && length(intersect(a, b)) == 0L
}

#' La regola di riga in una delle quattro varianti.
#'
#' @param tl,cl etichette dei due bracci (come in produzione)
#' @param cls,entity,extra_stop gli ingressi che la produzione passa a
#'   `.rp_row_defect()` per QUESTO confronto
#' @param tok_raw i testi da cui la produzione ha ricavato `extra_stop`
#'   (argomenti di `.ca_entity_tokens()`), per ricavarne i token tradotti
#' @return "" se la riga e' appaiata, altrimenti il nome della regola violata
rp_row_defect_var <- function(tl, cl, cls, entity, extra_stop, tok_raw, ontology_env,
                              cache, variante = c("V0", "V1", "V2", "V3")) {
  variante <- match.arg(variante)
  ns <- asNamespace("simulomicsr")
  if (variante == "V0")
    return(ns$.rp_row_defect(tl, cl, cls, entity, extra_stop, ontology_env, cache))
  tl <- .tr(tl); cl <- .tr(cl)
  raw <- unlist(tok_raw, use.names = FALSE)
  raw <- raw[!is.na(raw)]
  stop2 <- unique(c(extra_stop, if (length(raw)) ns$.ca_entity_tokens(.tr(raw)) else character(0)))
  if (ns$.rp_time_mismatch(tl, cl)) return("tempo_non_appaiato")
  if (ns$.rp_subject_mismatch(tl, cl, cls, stop2)) return("soggetto_diverso")
  if (ns$.rp_genetic_asymmetry(tl, cl, cls, entity)) return("genetica_asimmetrica")
  if (variante == "V3" && rp_material_mismatch(tl, cl)) return("materiale_diverso")
  if (variante == "V1") {
    if (ns$.rp_uncaptured_combination(tl, cl, entity, ontology_env, cache)) return("combinazione_non_vista")
  } else {
    if (rp_extra_agent_v2(tl, cl, entity, stop2, ontology_env, cache)) return("agente_in_piu")
  }
  ""
}
