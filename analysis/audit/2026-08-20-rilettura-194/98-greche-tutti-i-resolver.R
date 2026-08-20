#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/98-greche-tutti-i-resolver.R
#
# LE LETTERE GRECHE, SU TUTTI I PUNTI CHE RISOLVONO UN NOME — non su uno.
#
# PERCHE' QUESTO SCRIPT ESISTE. Le lettere greche sono gia' state «corrette» due
# volte:
#   - 2026-07-07, commit 36756ac: `.normalize_greek_stereo`, nel name-cleanup;
#   - 2026-07-26, commit 3bb5446: `.ca_latinize_greek`, nel contrast anchor. Il
#     messaggio di commit dice testualmente «LE LETTERE GRECHE SI TRADUCONO...
#     Regola generale, non una lista».
# Non era una regola generale: era una funzione. `R/stage3-row-pairing.R`, scritto
# il GIORNO PRIMA (2026-07-25), non l'ha mai avuta, e `.rp_agents` sanitizza con
# `gsub("[^A-Za-z0-9 -]", " ", x)`, che CANCELLA la greca e lascia «tgf- 1» —
# esattamente il difetto che il commit del 26 luglio descriveva a parole mentre lo
# correggeva altrove.
#
# La lezione non e' «manca una riga in .rp_agents». E' che «corretto» e' stato
# dichiarato due volte senza che nessuno contasse QUANTI punti di risoluzione
# esistono. Sono dieci. Questo script li interroga tutti con la stessa tabella, e
# rende «corretto» uno stato MISURABILE invece che un'affermazione: chi in futuro
# sistema una funzione sola vedra' le altre ancora rosse.
#
# La tabella non e' una lista di casi da far passare: sono coppie
# (forma greca, forma ASCII) della STESSA entita'. Il criterio non e' «risolve»,
# ma «risolve alla STESSA COSA della forma ASCII». Una forma greca che risolve a
# un ID DIVERSO e' peggio di una che non risolve: e' un'identita' sbagliata.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/98-greche-tutti-i-resolver.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-08-20-rilettura-194"
ont <- simulomicsr:::.load_ontology_dicts()

# coppie (greco, ascii) della stessa entita', prese dalle etichette VERE del
# deliverable — non inventate
COPPIE <- list(
  c("TGF-β1",  "TGF-beta1"),
  c("TGF-β",   "TGF-beta"),
  c("IFN-γ",   "IFN-gamma"),
  c("IFN-α",   "IFN-alpha"),
  c("IFN-β",   "IFN-beta"),
  c("IL-1β",   "IL-1beta"),
  c("IL-1α",   "IL-1alpha"),
  c("TNF-α",   "TNF-alpha"),
  c("17β-estradiol", "17beta-estradiol"),
  c("NF-κB",   "NF-kappaB")
)

# i dieci punti che risolvono un testo in un ID. Ognuno restituisce una cosa
# diversa: si normalizza a una stringa confrontabile.
id_di <- function(x) {
  if (is.null(x) || length(x) == 0L) return("")
  if (is.list(x)) {
    v <- x$id %||% x$hgnc_id %||% x[[1L]]
    return(if (is.null(v) || (length(v) == 1L && is.na(v))) "" else paste(v, collapse = ","))
  }
  paste(x[!is.na(x)], collapse = ",")
}
`%||%` <- function(a, b) if (is.null(a)) b else a

RESOLVER <- list(
  ".rp_agents"                   = function(s) id_di(simulomicsr:::.rp_agents(s, ont)),
  ".ca_agent_id"                 = function(s) id_di(simulomicsr:::.ca_agent_id(s, ont)),
  ".normalize_cytokine_to_hgnc"  = function(s) id_di(simulomicsr:::.normalize_cytokine_to_hgnc(s, ont)),
  ".normalize_compound_to_chebi" = function(s) id_di(simulomicsr:::.normalize_compound_to_chebi(s, ont)),
  ".normalize_disease_to_mesh"   = function(s) id_di(simulomicsr:::.normalize_disease_to_mesh(s, ont)),
  ".normalize_pathogen_to_taxid" = function(s) id_di(simulomicsr:::.normalize_pathogen_to_taxid(s, ont)),
  ".hgnc_lookup_symbol"          = function(s) id_di(simulomicsr:::.hgnc_lookup_symbol(s, env = ont)),
  ".extract_compound_candidates" = function(s) id_di(simulomicsr:::.extract_compound_candidates(s)),
  ".normalize_biological_mention"= function(s) id_di(simulomicsr:::.normalize_biological_mention(s, ont))
)

righe <- list()
for (nome in names(RESOLVER)) {
  f <- RESOLVER[[nome]]
  for (p in COPPIE) {
    g <- tryCatch(f(p[1]), error = function(e) "<errore>")
    a <- tryCatch(f(p[2]), error = function(e) "<errore>")
    esito <- if (identical(g, a)) {
      if (nzchar(a)) "uguale" else "entrambe vuote"
    } else if (!nzchar(g)) "GRECA CIECA" else "GRECA DIVERSA"
    righe[[length(righe) + 1L]] <- data.frame(
      resolver = nome, greco = p[1], ascii = p[2],
      id_greco = g, id_ascii = a, esito = esito, stringsAsFactors = FALSE)
  }
}
tab <- do.call(rbind, righe)

cli_h1("Le lettere greche, su tutti i punti di risoluzione")
cli_alert_info("resolver interrogati: {length(RESOLVER)} | coppie: {length(COPPIE)} | prove: {nrow(tab)}")

cli_h2("Esito complessivo")
print(table(tab$esito))

cli_h2("Per resolver (solo dove la forma ASCII risolve qualcosa: li' la greca DOVREBBE)")
rilevanti <- tab[nzchar(tab$id_ascii), ]
t <- table(rilevanti$resolver, rilevanti$esito)
print(t)

cli_h2("I casi in cui la forma greca da' un'IDENTITA' DIVERSA (peggio del silenzio)")
brutti <- tab[tab$esito == "GRECA DIVERSA" & nzchar(tab$id_ascii), ]
if (nrow(brutti) == 0) cli_alert_success("nessuno")
for (i in seq_len(nrow(brutti))) cli_alert_danger(sprintf(
  "%-30s  %-18s -> %-22s   ma  %-18s -> %s",
  brutti$resolver[i], brutti$greco[i], brutti$id_greco[i], brutti$ascii[i], brutti$id_ascii[i]))

utils::write.csv(tab, file.path(OUT, "98-greche-tutti-i-resolver.csv"), row.names = FALSE)
cli_alert_success("Scritto 98-greche-tutti-i-resolver.csv")
