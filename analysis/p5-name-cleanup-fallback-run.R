# analysis/p5-name-cleanup-fallback-run.R --- LLM-FALLBACK FINALE sugli INDETERMINATI.
# ---------------------------------------------------------------------------
# Passo 3 dell'indagine 2026-07-19+: manda Mistral su TUTTI gli indeterminati
# veri (agent_id_resolved UNK|STR:) del v9-final, SENZA filtro k, SENZA
# campionamento. Scope deciso con l'utente: STR:/UNK (esclusi vehicle/none
# by-design del triage). I 107.937 gia'-nominati weak/garbage NON sono
# indeterminati (hanno ID forte, in gran parte falsi allarmi euristici) ->
# fuori scope.
#
# Differenze da analysis/p5-name-cleanup-run.R (T13, validato a 193 record):
#   - triage FILTRATO a candidate STR:/UNK + canary (non tutti i 220k suspects);
#   - raccolta GSM membri + metadati OTTIMIZZATA via split() dell'assignments
#     (O(n) invece di O(n^2): a 113k cluster il pattern `assignments$cluster_id
#     == cid` in loop e' intrattabile);
#   - path di output SEPARATI (non tocca la side-table v9 name-cleanup-side-table-v1.rds).
#
# Uso:
#   STAGE3=... TRIAGE=... Rscript analysis/p5-name-cleanup-fallback-run.R triage
#   Rscript analysis/p5-name-cleanup-fallback-run.R submit   # build input + submit (setsid!)
#   Rscript analysis/p5-name-cleanup-fallback-run.R eval     # collect + assemble (dopo COMPLETED)
# ---------------------------------------------------------------------------
suppressMessages(devtools::load_all("."))
library(cli)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
ACTION <- (commandArgs(trailingOnly = TRUE)[1] %||% "submit")

STAGE3   <- Sys.getenv("STAGE3", "analysis/p4-output/20260717T171550Z-stage3-v9-364547a7")
STAGE2   <- Sys.getenv("STAGE2", "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
S1_INPUT <- "analysis/input/archs4-human-stage1-input.jsonl"   # geo_accession -> string
TRIAGE   <- Sys.getenv("TRIAGE", "analysis/audit/2026-07-19-v9-fallback-triage-strunk.csv")
JSONL    <- "analysis/audit/name-cleanup-fallback-input.jsonl"
STATE    <- "analysis/p4-output/name-cleanup-fallback-state.rds"
SIDE_RDS <- "analysis/p4-output/name-cleanup-fallback-side-table.rds"
FRAG_CSV <- "analysis/p4-output/name-cleanup-fallback-fragmentation.csv"

agent_prefix <- function(x) ifelse(is.na(x), "<NA>",
  ifelse(grepl("^UNK", x), "UNK",
   ifelse(grepl(":", x), sub("^([A-Za-z]+):.*$", "\\1", x), "<other>")))

if (ACTION == "triage") {
  cli_h1("Fallback — genera triage STR:/UNK (indeterminati veri, no filtro k)")
  cl <- load_stage3(STAGE3)$clusters
  tr <- simulomicsr:::.build_suspect_triage(cl)
  pref_by <- setNames(agent_prefix(cl$agent_id_resolved), cl$cluster_id)
  tr$apref <- unname(pref_by[tr$cluster_id])
  # candidate SOLO se STR/UNK; canary tenuti tutti (controllo non-regressione).
  keep <- !is.na(tr$role) & tr$cls != "vehicle/none" &
    ((tr$role == "candidate" & tr$apref %in% c("STR", "UNK")) | tr$role == "canary")
  tr_out <- tr[keep, setdiff(names(tr), "apref"), drop = FALSE]
  utils::write.csv(tr_out, TRIAGE, row.names = FALSE)
  cli_alert_success(
    "Triage fallback: {nrow(tr_out)} righe ({sum(tr_out$role=='candidate')} candidate STR/UNK + {sum(tr_out$role=='canary')} canary) -> {TRIAGE}")

} else if (ACTION == "submit") {
  cli_h1("Fallback RUN — build input (ottimizzato) + submit")
  cand <- simulomicsr:::.load_name_cleanup_candidates(TRIAGE)
  cli_alert_info("Candidati: {nrow(cand)} ({sum(cand$role=='candidate')} candidate + {sum(cand$role=='canary')} canary)")

  s3 <- load_stage3(STAGE3)
  # Indice O(n): cluster_id -> record_id[] (UNA volta, non per-cid nel loop).
  cli_alert_info("Indice assignments (split)...")
  asg_by <- split(s3$assignments$record_id, s3$assignments$cluster_id)

  # current_ids = ID ontologico estratto dall'anchor_key (NON l'anchor_key intero).
  ak_full <- setNames(s3$clusters$anchor_key, s3$clusters$cluster_id)[cand$cluster_id]
  ak_lvl  <- as.integer(sub("^[a-z]+_L([0-9])_.*$", "\\1", cand$cluster_id))
  ak_mode <- sub("^([a-z]+)_L[0-9]_.*$", "\\1", cand$cluster_id)
  cli_alert_info("current_ids da anchor_key ({nrow(cand)} cluster)...")
  current_ids <- setNames(vapply(seq_along(ak_full), function(i)
    extract_anchor_summary(ak_full[i], level = ak_lvl[i], mode = ak_mode[i])$agent_id %||% NA_character_,
    character(1)), cand$cluster_id)

  source("analysis/audit/_gsm-lookup-helper.R")
  rec_env <- build_record_gsm_lookup(STAGE2)

  # Record membri dei candidati (union) -> risolvi record -> GSM UNA volta.
  cli_alert_info("Record membri dei candidati (union)...")
  cand_recs <- unique(unlist(asg_by[cand$cluster_id], use.names = FALSE))
  cand_recs <- cand_recs[!is.na(cand_recs)]
  rec_to_gsms <- setNames(
    lapply(cand_recs, function(r) get0(r, envir = rec_env, inherits = FALSE)),
    cand_recs)
  member_gsms <- unique(unlist(rec_to_gsms, use.names = FALSE))
  cli_alert_info("GSM membri distinti: {length(member_gsms)}")

  # Stream Stadio 1 input per gsm_text (solo i GSM membri).
  cli_alert_info("Stream Stadio 1 input per gsm_text (subset)...")
  want <- new.env(hash = TRUE, parent = emptyenv())
  for (g in member_gsms) assign(g, TRUE, envir = want)
  gsm_text <- character(0)
  con <- file(S1_INPUT, "r"); on.exit(close(con), add = TRUE)
  nseen <- 0L
  repeat {
    ln <- readLines(con, n = 50000L, warn = FALSE); if (!length(ln)) break
    for (l in ln) {
      j <- tryCatch(jsonlite::fromJSON(l, simplifyVector = TRUE), error = function(e) NULL)
      if (is.null(j) || is.null(j$geo_accession)) next
      ga <- as.character(j$geo_accession)
      if (exists(ga, envir = want, inherits = FALSE)) gsm_text[ga] <- as.character(j$string %||% "")
    }
    nseen <- nseen + length(ln)
    cli_alert_info("  ... {nseen} righe S1 scandite, {length(gsm_text)}/{length(member_gsms)} testi raccolti")
  }
  cli_alert_success("gsm_text raccolti: {length(gsm_text)}/{length(member_gsms)}")

  # Metadati membri per cluster (INLINE, O(n) via asg_by + rec_to_gsms).
  cli_alert_info("Metadati membri per cluster (inline)...")
  char_budget <- 6000L
  member <- vector("list", nrow(cand)); names(member) <- cand$cluster_id
  for (i in seq_len(nrow(cand))) {
    cid  <- cand$cluster_id[i]
    recs <- asg_by[[cid]]
    gsms <- unique(unlist(rec_to_gsms[recs], use.names = FALSE))
    txt  <- unique(gsm_text[intersect(gsms, names(gsm_text))])
    joined <- paste(txt, collapse = " | ")
    if (nchar(joined) > char_budget) joined <- substr(joined, 1L, char_budget)
    member[[cid]] <- joined
  }

  simulomicsr:::.build_name_cleanup_input_jsonl(cand, member, JSONL)
  cli_alert_success("Input jsonl: {JSONL} ({nrow(cand)} record)")

  cfg <- dgx_config()
  bundle <- dgx_p4_build_bundle(JSONL, stage = "name_cleanup", config = cfg)
  job <- dgx_p4_submit(bundle, time = "72:00:00", config = cfg)
  saveRDS(list(job = job, cand = cand, current_ids = current_ids, s3_clusters = s3$clusters), STATE)
  cli_alert_success("SUBMIT OK — run_id {job$run_id} slurm {job$slurm_job_id}. Stato: {STATE}")

} else if (ACTION == "eval") {
  cli_h1("Fallback RUN — collect + assemble")
  st <- readRDS(STATE)
  res <- dgx_p4_collect(st$job)
  predictions_by_id <- setNames(res$predictions$parsed_json, res$predictions$record_id)
  cli_alert_info("Predictions: {nrow(res$predictions)} (valid_schema {sum(res$predictions$valid_schema)})")

  env <- simulomicsr:::.load_ontology_dicts()
  side <- simulomicsr:::.assemble_side_table_from_predictions(st$cand, st$current_ids, predictions_by_id, env)
  saveRDS(side, SIDE_RDS)

  k_by <- setNames(st$s3_clusters$k, st$s3_clusters$cluster_id)
  fr <- simulomicsr:::.measure_fragmentation(side, k_by)
  utils::write.csv(fr, FRAG_CSV, row.names = FALSE)

  cli_h2("Riepilogo side-table fallback")
  cli_dl(list(
    "override"    = sum(side$action == "override"),
    "flag_review" = sum(side$action == "flag_review"),
    "noop"        = sum(side$action == "noop"),
    "keep"        = sum(side$action == "keep"),
    "frammenti (entita' con >=2 cluster)" = nrow(fr),
    "max k_merged_est" = if (nrow(fr)) max(fr$k_merged_est) else 0L
  ))
  cli_alert_success("Side-table: {SIDE_RDS} | frammentazione: {FRAG_CSV}")
} else {
  cli_abort("Azione sconosciuta: {ACTION}. Usa 'triage', 'submit' o 'eval'.")
}
