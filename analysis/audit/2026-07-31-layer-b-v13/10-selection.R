# analysis/audit/2026-07-31-layer-b-v13/10-selection.R
# Genera analysis/layer-b-selection-v13.csv DAL deliverable annotato v13.
#
# Perche' generata e non scritta a mano: k, n_sig, I2 e il verdetto di coerenza
# devono venire dal dato, non da una trascrizione. Le uniche scelte umane sono
# (a) QUALI cluster (decisione utente 2026-07-30, ADR-0027) e (b) l'etichetta
# d'uso per il paper, tenuta in una tabella esplicita accanto all'ID.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/10-selection.R

suppressPackageStartupMessages({
  library(cli)
})

DELIV <- "analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds"
OUT   <- "analysis/layer-b-selection-v13.csv"

d <- readRDS(DELIV)
stopifnot(nrow(d) == 191L)

# ---------------------------------------------------------------------------
# La selezione, per ID di entita' (ADR-0027). L'etichetta per il paper e' ASCII
# di proposito: e' finita in file di testo e HTML, e in questo progetto le
# lettere greche sono gia' state cancellate una volta da uno strumento cieco.
# ---------------------------------------------------------------------------
sel <- rbind(
  # --- MAIN PAPER ---------------------------------------------------------
  data.frame(entity = "CHEBI:16330",       label = "DHT (dihydrotestosterone) -- AR agonist", priority = 1L,
             role = "main-fig1-agonist"),
  data.frame(entity = "CHEBI:68534",       label = "Enzalutamide -- AR antagonist",           priority = 1L,
             role = "main-fig1-antagonist"),
  data.frame(entity = "HGNC:11766",        label = "TGF-beta1",                               priority = 1L,
             role = "main-fig2-candidate-high-k"),
  data.frame(entity = "CHEBI:16412",       label = "LPS (lipopolysaccharide)",                priority = 1L,
             role = "main-fig2-candidate-high-k"),
  # --- SUPPLEMENTARI ------------------------------------------------------
  data.frame(entity = "NCBITaxon:2697049", label = "SARS-CoV-2 infection",                    priority = 2L,
             role = "supp-pathogen"),
  data.frame(entity = "HGNC:5438",         label = "IFN-gamma",                               priority = 2L,
             role = "supp-cytokine"),
  data.frame(entity = "CHEBI:137113",      label = "JQ1 (BET bromodomain inhibitor)",         priority = 2L,
             role = "supp-small-molecule"),
  data.frame(entity = "MeSH:D010300",      label = "Parkinson disease vs normal",             priority = 2L,
             role = "supp-disease-candidate"),
  data.frame(entity = "MeSH:D006528",      label = "Hepatocellular carcinoma vs normal",      priority = 2L,
             role = "supp-disease-candidate"),
  # --- INCOERENTI DICHIARATI ---------------------------------------------
  data.frame(entity = "HGNC:5991",         label = "IL1A -- DECLARED INCOHERENT",             priority = 3L,
             role = "supp-incoherent"),
  data.frame(entity = "HGNC:5417",         label = "IFNA1 -- DECLARED INCOHERENT",            priority = 3L,
             role = "supp-incoherent"),
  data.frame(entity = "CHEBI:59132",       label = "antigen (umbrella class) -- DECLARED INCOHERENT", priority = 3L,
             role = "supp-incoherent")
)

# ---------------------------------------------------------------------------
# Join sul deliverable. FAIL LOUD se un'entita' non esiste o non e' unica:
# una selezione che punta a un cluster che non c'e' e' esattamente il bug del
# 2026-07-23, e deve fermare lo script, non produrre una riga vuota.
# ---------------------------------------------------------------------------
missing <- setdiff(sel$entity, d$contrast_entity)
if (length(missing) > 0L) {
  cli_abort("Entita' assenti dal deliverable poolato: {missing}")
}
dupes <- sel$entity[sel$entity %in% names(which(table(d$contrast_entity) > 1L))]
if (length(dupes) > 0L) {
  cli_abort("Entita' con piu' di un cluster poolato (ambigue): {dupes}")
}

idx <- match(sel$entity, d$contrast_entity)
row <- d[idx, ]

notes <- sprintf(
  "%s | entita=%s | etichetta risolta dall'ID=%s (fonte %s) | canonical_name vecchio=%s | verso=%s | controllo=%s | k_eff=%d | n_sig(FDR<0,05)=%d | I2 mediano=%.1f | coerenza=%s%s | studi censiti=%d -> poolati=%d%s",
  sel$role,
  row$contrast_entity,
  row$contrast_entity_label,
  row$contrast_entity_label_source,
  row$canonical_name,
  row$contrast_direction,
  row$contrast_control_key,
  row$k_effective,
  row$n_sig,
  row$I2_med,
  row$coherence_verdict,
  ifelse(is.na(row$coherence_reason) | !nzchar(row$coherence_reason), "",
         paste0(" (", row$coherence_reason, ")")),
  row$n_studi_censiti,
  row$n_studi_poolati,
  ifelse(row$stessi_membri, " | stesso insieme di studi",
         sprintf(" | studi caduti nel pooling: %s", row$studi_caduti))
)

out <- data.frame(
  cluster_id  = row$cluster_id,
  label_paper = sel$label,
  priority    = sel$priority,
  notes       = notes,
  stringsAsFactors = FALSE
)

# Controllo di non-troncamento (§0.3 dell'handout): nessuna nota deve toccare
# un limite. Qui non c'e' un limite imposto, ma il controllo si scrive comunque
# perche' e' esattamente cio' che mancava le tre volte in cui uno strumento e'
# stato cieco.
cli_alert_info("note: lunghezza min={min(nchar(out$notes))} max={max(nchar(out$notes))} (nessun troncamento applicato)")

write.csv(out, OUT, row.names = FALSE)
cli_alert_success("Scritta {.path {OUT}} — {nrow(out)} case study.")

for (i in seq_len(nrow(out))) {
  cat(sprintf("  [p%d] %-22s %-46s k=%2d n_sig=%5d I2=%5.1f %s\n",
              out$priority[i], out$cluster_id[i], out$label_paper[i],
              row$k_effective[i], row$n_sig[i], row$I2_med[i],
              row$coherence_verdict[i]))
}
