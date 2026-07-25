# Equivalenza: il verdetto del CODICE DI PACCHETTO (.ca_member_contrast) contro
# il gate gia' misurato (109-fase1-v11-gate.R) sugli stessi 38.440 contrasti.
#
# Non e' un test unitario: e' la prova che il codice che verra' eseguito dice la
# stessa cosa dello script su cui sono stati misurati i 144 gruppi. Le differenze
# attese riguardano il ramo on-contrast (che nel build usa il nome dell'anchor
# del record, non il nome del cluster). Qualunque differenza su una regola del
# gate o di riga e' un bug e va indagata prima di proseguire.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(dplyr)
  devtools::load_all(".", quiet = TRUE)
})

SC  <- "analysis/audit/2026-07-24-anchor-coherence-sim"
OUT <- "analysis/audit/2026-07-27-contrast-builder"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

pm <- readRDS(file.path(SC, "fase1-v11-results.rds"))$pm
oe <- .load_ontology_dicts()
caches <- list(agent = new.env(parent = emptyenv()),
               token = new.env(parent = emptyenv()))

# PROXY DELL'ANCHOR DEL RECORD.
# Nel build il ramo on-contrast prende nome e ID gia' risolti nell'anchor del
# campione TRATTATO di quel record (tracking_meta: canonical_name +
# agent_id_resolved). Qui quell'ID non c'e', ma il nome del cluster nasce dallo
# stesso anchor: canonicalizzandolo con gli stessi resolver si ottiene il
# proxy piu' fedele. Senza, il ramo on-contrast resta spento e il confronto e'
# ingiusto (prima misura: 853 differenze tutte di questa natura).
.anchor_cache <- new.env(parent = emptyenv())
anchor_id_proxy <- function(nome, cls) {
  if (is.na(nome) || !nzchar(nome) || is.na(cls)) return(NA_character_)
  key <- paste0(cls, "||", tolower(nome))
  if (exists(key, envir = .anchor_cache, inherits = FALSE)) return(get(key, envir = .anchor_cache))
  is_canon <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  r <- NA_character_
  if (cls == "drug") {
    x <- .normalize_compound_to_chebi(nome, oe); if (is_canon(x$id)) r <- x$id
    if (is.na(r)) { x <- .normalize_cytokine_to_hgnc(nome, oe); if (is_canon(x$id)) r <- x$id }
  } else if (cls == "infection") {
    x <- .normalize_pathogen_to_taxid(nome, oe); if (is_canon(x$id)) r <- x$id
  } else if (cls == "disease") {
    x <- .normalize_disease_to_mesh(nome, oe); if (is_canon(x$id)) r <- x$id
  } else if (cls == "genetic") {
    h <- .hgnc_lookup_symbol(nome, env = oe)
    if (!is.null(h) && !is.null(h$hgnc_int)) r <- paste0("HGNC:", h$hgnc_int)
  }
  # nome non canonicalizzabile: nel build l'anchor avrebbe comunque un ID
  # (spesso STR:), quindi si usa la forma NAME: come faceva il gate.
  if (is.na(r) && nzchar(nome)) r <- paste0("NAME:", tolower(nome))
  assign(key, r, envir = .anchor_cache); r
}

n <- nrow(pm)
cat(format(Sys.time()), "- verdetto di pacchetto su", n, "membri...\n")
ent <- rep(NA_character_, n); dr <- character(n); src <- rep(NA_character_, n)
ck  <- rep(NA_character_, n); vs <- rep(NA_character_, n)
t0 <- Sys.time()
PRI <- c("genetic", "drug", "infection", "disease", "environment", "time", "other")
for (i in seq_len(n)) {
  cls_i <- PRI[PRI %in% strsplit(pm$dclasses[i], "+", fixed = TRUE)[[1L]]][1L]
  v <- .ca_member_contrast(
    treated_label = pm$treated_label[i], control_label = pm$control_label[i],
    treated_fl    = pm$treated_fl[i],    control_fl    = pm$control_fl[i],
    anchor_name   = pm$canonical_name[i],
    anchor_id     = anchor_id_proxy(pm$canonical_name[i], cls_i),
    ontology_env = oe, caches = caches)
  ent[i] <- v$entity; dr[i] <- v$drop_reason; src[i] <- v$entity_source
  ck[i]  <- v$control_key; vs[i] <- v$direction
  if (i %% 5000 == 0) {
    cat(sprintf("  %d/%d (%.0fs)\n", i, n,
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
}
pm$new_entity <- ent
pm$new_dr     <- ifelse(nzchar(dr), dr, "ok")
pm$new_src    <- src
pm$new_ct     <- ck
pm$new_verso  <- vs

# Il pacchetto non distingue "ok" da "ok_combo": la combo si riconosce dalla
# fonte dell'entita'. Senza questa normalizzazione le transizioni mentono
# (una combo riscritta appena diversa sembrava una combo persa).
pm$new_dr_lab <- ifelse(pm$new_dr == "ok" & pm$new_src == "COMBO", "ok_combo", pm$new_dr)
old_dr <- ifelse(pm$dr %in% c("ok", "ok_combo"), "ok", pm$dr)
tenuti_da_entrambi <- old_dr == "ok" & pm$new_dr == "ok"

cat("\n=== esito per-membro: pacchetto vs gate misurato ===\n")
cat("membri:", n, "\n")
cat("verdetto identico (tenuto/scartato):",
    sum((old_dr == "ok") == (pm$new_dr == "ok")),
    sprintf("(%.2f%%)\n", 100 * mean((old_dr == "ok") == (pm$new_dr == "ok"))))
cat("tenuti da entrambi:", sum(tenuti_da_entrambi), "\n")
cat("entita' identica sui tenuti da entrambi:",
    sum(tenuti_da_entrambi & pm$entity == pm$new_entity, na.rm = TRUE), "\n")

cat("\n=== ragioni di scarto: gate misurato vs pacchetto ===\n")
print(merge(
  as.data.frame(table(gate = old_dr), stringsAsFactors = FALSE),
  as.data.frame(table(gate = pm$new_dr), stringsAsFactors = FALSE),
  by = "gate", all = TRUE, suffixes = c("_v11", "_pacchetto")
), row.names = FALSE)

diff <- pm[(old_dr == "ok") != (pm$new_dr == "ok") |
           (tenuti_da_entrambi & pm$entity != pm$new_entity), ]
cat("\ndifferenze totali:", nrow(diff), "\n")
cat("\ntransizioni piu' frequenti (vecchio -> nuovo):\n")
print(head(sort(table(paste(diff$dr, "->", diff$new_dr_lab)), decreasing = TRUE), 25))
write.csv(diff[, c("study_id", "treated_label", "control_label", "dr", "new_dr",
                   "entity", "new_entity", "new_src")],
          file.path(OUT, "equivalenza-builder.csv"), row.names = FALSE)

# Ricostruzione dei gruppi con le entita' del pacchetto
el <- pm[pm$new_dr == "ok" & !is.na(pm$new_entity), ]
el$ckey <- paste(el$new_entity, el$new_verso, el$new_ct, sep = "||")
agg <- el |> group_by(ckey) |>
  summarise(k = n_distinct(study_id), n = n(), .groups = "drop") |>
  filter(k >= 3)
agg$entita <- sub("\\|\\|.*$", "", agg$ckey)
agg$verso  <- sub("^[^|]*\\|\\|([^|]*)\\|\\|.*$", "\\1", agg$ckey)
agg <- agg |> group_by(entita, verso) |> slice_max(k, n = 1, with_ties = FALSE) |> ungroup()

cat("\n=== gruppi poolabili k>=3 col codice di pacchetto:", nrow(agg),
    " (gate misurato: 144) ===\n")
cat("k>=5:", sum(agg$k >= 5), "\n")
cat("\n=== gruppi bandiera ===\n")
for (E in c("NCBITaxon:2697049", "CHEBI:16412", "HGNC:11766", "CHEBI:68534", "CHEBI:63637")) {
  h <- agg[agg$entita == E, ]
  cat(sprintf("  %-20s k=%s\n", E, if (nrow(h)) paste(h$k, collapse = ",") else "ASSENTE"))
}
saveRDS(list(pm = pm, agg = agg), file.path(OUT, "equivalenza-builder.rds"))
cat("\n", format(Sys.time()), "- salvato equivalenza-builder.rds\n")
