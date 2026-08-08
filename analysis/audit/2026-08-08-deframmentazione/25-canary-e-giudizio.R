# =============================================================================
# CONTROLLO DI PRECISIONE
#   1. CANARY: entita' che NON devono fondersi. Cercate nel dato VERO (non
#      inventate) e verificate: la regola deve dare loro codici DIVERSI.
#   2. GIUDIZIO: le fusioni proposte, giudicate una per una.
#      ⚠️ Il brief chiedeva "un campione casuale di 40 fusioni". Le fusioni
#      applicate al corpus sono 13: un campione di 40 su 13 non esiste, e
#      giudicarle TUTTE e' piu' forte di campionarle. Il campione di 40 si
#      prende quindi sull'insieme dove ha senso — le 1.367 equivalenze fra
#      registri che la regola sa produrre (la maggior parte ha un solo lato nel
#      corpus): li' misura la precisione della REGOLA, non del suo effetto.
#      Seme dichiarato: 20260808.
# =============================================================================

suppressWarnings(suppressMessages(devtools::load_all(".", quiet = TRUE)))
OUT  <- "analysis/audit/2026-08-08-deframmentazione"
DICT <- "/home/user/.cache/R/simulomicsr"
say <- function(...) cat(sprintf(...), "\n", sep = "")
E <- readRDS(file.path(OUT, "21-regola-esito.rds"))
cg <- E$cg; canon <- E$canon_id; k_per_id <- E$k_per_id
ponti <- utils::read.csv(file.path(OUT, "22-ponti-fra-registri.csv"), stringsAsFactors = FALSE)

.strip_markup <- function(x) gsub("<[^>]*>", "", x)
# nomi canonici, letti dai registri (mai da `canonical_name` del cluster, che
# dissente dal nome vero: JQ1 vi compare come "D-cycloserine")
NOMI <- local({
  n <- character(0); id <- character(0)
  d <- readRDS(file.path(DICT, "chebi", "chebi-lookup.rds"))
  id <- c(id, paste0("CHEBI:", d$by_id$chebi_id)); n <- c(n, .strip_markup(d$by_id$primary_name))
  ali_chebi <- d$aliases
  d <- readRDS(file.path(DICT, "hgnc-lookup.rds"))
  id <- c(id, paste0("HGNC:", d$by_hgnc_int$hgnc_int))
  n <- c(n, paste0(d$by_hgnc_int$symbol, " (", d$by_hgnc_int$name, ")"))
  d <- readRDS(file.path(DICT, "mesh-lookup.rds"))
  id <- c(id, paste0("MeSH:", d$by_ui$ui)); n <- c(n, d$by_ui$mh)
  d <- readRDS(file.path(DICT, "chembl", "chembl-lookup.rds"))
  id <- c(id, paste0("CHEMBL:", d$by_id$chembl_id)); n <- c(n, d$by_id$pref_name)
  d <- readRDS(file.path(DICT, "taxonomy", "taxonomy-lookup.rds"))
  sci <- d$names$name_class == "scientific name"
  id <- c(id, paste0("NCBITaxon:", d$names$taxid[sci])); n <- c(n, d$names$name_norm[sci])
  list(mappa = setNames(n, id), chebi_alias = ali_chebi)
})
nome <- function(id) { v <- NOMI$mappa[id]; ifelse(is.na(v), "<ignoto>", v) }

# --------------------------------------------------------------------------
# 1. CANARY — cercati nel dato vero
# --------------------------------------------------------------------------
# Ogni canary si cerca per NOME nei registri, poi si controlla che almeno un
# ramo esista nel corpus; il verdetto e' sull'esito della regola.
trova <- function(term) {
  a <- NOMI$chebi_alias
  h <- unique(a$chebi_id[a$alias_lower == tolower(term)])
  if (length(h)) paste0("CHEBI:", h) else character(0)
}
CANARY <- list(
  "5-azacytidine vs decitabina" = c(trova("5-azacytidine")[1], "CHEBI:50131"),
  "testosterone vs DHT"         = c(trova("testosterone")[1], "CHEBI:16330"),
  "tamoxifene vs afimoxifene"   = c(trova("tamoxifen")[1], "CHEBI:44616"),
  "JQ1 vs birabresib"           = c(trova("jq1")[1], trova("birabresib")[1]),
  "JQ1 vs mivebresib"           = c(trova("jq1")[1], trova("mivebresib")[1]),
  "JQ1 vs ABBV-744"             = c(trova("jq1")[1], trova("abbv-744")[1]),
  "TGF-beta1 vs TGF-beta2"      = c("HGNC:11766", "HGNC:11768"),
  "IFNA1 vs IFNA2"              = c("HGNC:5417", "HGNC:5423")
)
say("=== 1. CANARY: coppie che NON devono fondersi ===")
esiti <- list()
for (nm in names(CANARY)) {
  ids <- CANARY[[nm]]
  if (any(is.na(ids)) || length(ids) < 2L) {
    say("  %-30s NON TROVATO nei registri (%s) -> canary non eseguibile",
        nm, paste(ids, collapse = ","))
    esiti[[nm]] <- "non_eseguibile"; next
  }
  nel_corpus <- ids %in% cg$contrast_entity
  ca <- ifelse(ids %in% names(canon), canon[ids], ids)
  ok <- ca[1L] != ca[2L]
  say("  %-30s %s(%s, k=%s, corpus=%s) vs %s(%s, k=%s, corpus=%s) -> canonici %s / %s : %s",
      nm, ids[1L], nome(ids[1L]), ifelse(is.na(k_per_id[ids[1L]]), 0, k_per_id[ids[1L]]), nel_corpus[1L],
      ids[2L], nome(ids[2L]), ifelse(is.na(k_per_id[ids[2L]]), 0, k_per_id[ids[2L]]), nel_corpus[2L],
      ca[1L], ca[2L], if (ok) "DISTINTI (passa)" else "FUSI (DIFETTO)")
  esiti[[nm]] <- if (ok) "passa" else "DIFETTO"
}
# PMA da solo contro la combinazione ionomicina+PMA: si legge dal corpus
pma <- cg[grepl("phorbol|CHEBI:37537|CHEBI:39867", cg$contrast_entity, ignore.case = TRUE) |
          grepl("ionomycin", cg$contrast_entity, ignore.case = TRUE) |
          grepl("ionomycin|phorbol|pma", cg$canonical_name, ignore.case = TRUE), ]
combo_pma <- cg[startsWith(cg$contrast_entity, "COMBO:") &
                grepl("CHEBI:37537|CHEBI:39867", cg$contrast_entity), ]
say("  PMA / ionomicina: cluster con entita' mono che potrebbero essere PMA: %d; COMBO con PMA: %d",
    nrow(pma), nrow(combo_pma))
if (nrow(combo_pma)) {
  say("    esempi COMBO: %s", paste(head(unique(combo_pma$contrast_entity), 4), collapse = " ; "))
  say("    la canonicalizzazione di un COMBO resta un COMBO: %s",
      paste(head(unique(combo_pma$entita_canonica), 4), collapse = " ; "))
  say("    verdetto: un COMBO non si fonde mai con un mono (il prefisso lo impedisce per costruzione)")
}
say("--- esito canary: %d passano, %d difetti, %d non eseguibili ---",
    sum(unlist(esiti) == "passa"), sum(unlist(esiti) == "DIFETTO"),
    sum(unlist(esiti) == "non_eseguibile"))

# --------------------------------------------------------------------------
# 2a. GIUDIZIO su TUTTE le fusioni applicate al corpus
# --------------------------------------------------------------------------
say("")
say("=== 2a. LE FUSIONI APPLICATE, tutte (non un campione) ===")
appl <- ponti[ponti$entrambi_nel_corpus == TRUE, ]
appl$nome_a <- nome(appl$id_a); appl$nome_b <- nome(appl$id_b)
appl$k_a <- ifelse(is.na(k_per_id[appl$id_a]), 0L, k_per_id[appl$id_a])
appl$k_b <- ifelse(is.na(k_per_id[appl$id_b]), 0L, k_per_id[appl$id_b])
appl <- appl[order(-pmax(appl$k_a, appl$k_b)), ]
for (i in seq_len(nrow(appl))) say("[%2d] %-9s '%s'\n     %s (%s) k=%d\n     %s (%s) k=%d",
    i, sub("_.*$", "", appl$tier[i]), appl$chiave[i],
    appl$id_a[i], appl$nome_a[i], appl$k_a[i], appl$id_b[i], appl$nome_b[i], appl$k_b[i])
utils::write.csv(appl, file.path(OUT, "25a-fusioni-applicate-da-giudicare.csv"), row.names = FALSE)

# --------------------------------------------------------------------------
# 2b. CAMPIONE DI 40 sulle equivalenze che la regola sa produrre
# --------------------------------------------------------------------------
set.seed(20260808)
camp <- ponti[sample(nrow(ponti), 40L), ]
camp$nome_a <- nome(camp$id_a); camp$nome_b <- nome(camp$id_b)
camp <- camp[order(camp$tier), ]
say("")
say("=== 2b. CAMPIONE CASUALE DI 40 (seme 20260808) sulle %d equivalenze ===", nrow(ponti))
for (i in seq_len(nrow(camp))) say("[%2d] %-9s '%s'  |  %s (%s)  ==  %s (%s)  [corpus2lati=%s]",
    i, sub("_.*$", "", camp$tier[i]), camp$chiave[i],
    camp$id_a[i], camp$nome_a[i], camp$id_b[i], camp$nome_b[i], camp$entrambi_nel_corpus[i])
utils::write.csv(camp, file.path(OUT, "25b-campione-40-da-giudicare.csv"), row.names = FALSE)
print(table(camp$tier))
