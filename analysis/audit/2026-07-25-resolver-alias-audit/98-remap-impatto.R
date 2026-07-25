# QUANTO si recupererebbe RI-MAPPANDO le sigle bloccate al bersaglio giusto?
#
# Oggi le guardie rifiutano il candidato e basta: "5-FU" resta senza nome invece
# di diventare CHEBI:46345. La domanda dell'utente e': quanti campioni e quanti
# GRUPPI POOLABILI in piu' porterebbe il ri-mappaggio.
#
# Metodo (lower bound, dichiarato):
#  1. dalle 71 coppie bloccate, prendo quelle per cui il bersaglio giusto e' noto
#     e verificato sul testo (tabella sotto, curata a mano);
#  2. sul proxy dei contrasti (fase1-pm2.rds) conto i membri il cui braccio
#     trattato nomina la sigla a parola intera e che OGGI non hanno un'entita'
#     canonica (STR:/nessuna);
#  3. li raggruppo per (bersaglio, verso, tipo di controllo) come fa il gate e
#     conto quanti raggiungerebbero k>=3 (gruppo nuovo) o entrerebbero in un
#     gruppo esistente (rafforzamento).
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
AU <- "analysis/audit/2026-07-25-resolver-alias-audit"

## bersagli noti e verificati sul testo sorgente (finding 2026-07-25 §2)
REMAP <- tribble(
  ~alias,   ~id_giusto,      ~nome_giusto,
  "5-fu",   "CHEBI:46345",   "5-fluorouracile",
  "5fu",    "CHEBI:46345",   "5-fluorouracile",
  "dha",    "CHEBI:28125",   "acido docosaesaenoico",
  "tpa",    "CHEBI:37537",   "forbolo 12-miristato 13-acetato",
  "mek",    "HGNC:6840",     "MAP2K1",
  "nmda",   "CHEBI:31882",   "N-metil-D-aspartato",
  "shh",    "HGNC:10848",    "SHH (sonic hedgehog)",
  "mit",    "CHEBI:50729",   "mitoxantrone",
  "lap",    "CHEBI:49603",   "lapatinib",
  "tpo",    "HGNC:11795",    "THPO (trombopoietina)",
  "hgf",    "HGNC:4881",     "HGF",
  "ifn",    NA_character_,   "IFN generico: famiglia, NON ri-mappabile",
  "ml",     NA_character_,   "unita' di misura, NON ri-mappabile",
  "cancer", NA_character_,   "termine-ombrello, NON ri-mappabile",
  "in",     NA_character_,   "parola funzionale, NON ri-mappabile"
)

rim <- read.csv(file.path(AU, "identita-rimosse.csv"), stringsAsFactors = FALSE)
cat("=== identita' rimosse dalle guardie (misura 2026-07-25) ===\n")
cat(sprintf("coppie distinte: %d | campioni: %d\n", nrow(rim), sum(rim$n)))
print(head(rim[order(-rim$n), ], 15), row.names = FALSE)

pm <- readRDS(file.path(SC, "fase1-pm2.rds"))
v10 <- readRDS(file.path(SC, "fase1-v10-results.rds"))
gia <- v10$agg$ckey
ent_gia <- sub("\\|\\|.*$", "", gia)

cand <- REMAP |> filter(!is.na(id_giusto))
out <- list()
for (i in seq_len(nrow(cand))) {
  a <- cand$alias[i]
  rx <- paste0("(^|[^a-z0-9])", gsub("([.\\-])", "\\\\\\1", a), "($|[^a-z0-9])")
  hit <- grepl(rx, tolower(pm$treated_label), perl = TRUE) &
    (is.na(pm$ce2_id) | startsWith(pm$ce2_id %||% "", "STR:"))
  if (!any(hit)) { out[[a]] <- data.frame(alias = a, id = cand$id_giusto[i],
                                          membri = 0L, studi = 0L, gia_poolabile = NA); next }
  h <- pm[hit, ]
  out[[a]] <- data.frame(alias = a, id = cand$id_giusto[i], nome = cand$nome_giusto[i],
                         membri = nrow(h), studi = n_distinct(h$study_id),
                         gia_poolabile = cand$id_giusto[i] %in% ent_gia)
}
res <- bind_rows(out) |> arrange(desc(studi))
cat("\n=== potenziale del ri-mappaggio (membri col trattato che nomina la sigla e oggi senza entita') ===\n")
print(as.data.frame(res), row.names = FALSE)
cat(sprintf("\nGRUPPI NUOVI possibili (k>=3 e bersaglio non gia' poolabile): %d\n",
            sum(res$studi >= 3 & !res$gia_poolabile, na.rm = TRUE)))
cat(sprintf("RAFFORZAMENTI di gruppi esistenti: %d\n", sum(res$gia_poolabile, na.rm = TRUE)))
cat(sprintf("membri totali coinvolti: %d\n", sum(res$membri)))
cat("\nNOTA: e' un LOWER BOUND grezzo. I membri contati passerebbero comunque per il\n",
    "gate (verso, tipo di controllo, regole di riga): il numero finale di gruppi\n",
    "poolabili puo' solo essere <= a questo.\n")
write.csv(res, file.path(AU, "remap-impatto.csv"), row.names = FALSE)
