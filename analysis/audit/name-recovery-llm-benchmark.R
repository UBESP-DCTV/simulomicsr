# Benchmark recupero-nome LLM vs deterministico su cluster UNK (Stadio 3)
#
# SCOPO (eval, NON produzione):
#   Misura se un LLM mirato recupererebbe meglio i casi `agent_id_resolved == "UNK"`
#   rispetto alla pipeline deterministica (recover_identity). La "decisione C"
#   (aggiungere un fallback LLM in produzione) viene presa con l'utente SOLO se
#   l'LLM supera la soglia concordata.
#
# PASSI:
#   1. Campiona N cluster UNK (default 200) stratificati per kind_effective_resolved.
#   2. Per ogni cluster: ottieni un GSM rappresentante (primo del braccio treated/case).
#   3. Estrazione deterministica: recover_identity() su source/characteristics/title.
#   4. [GATED] Estrazione LLM mirata: chiama l'endpoint configurato.
#   5. Genera template gold ~50 record (CSV vuoto, da compilare a mano dall'utente).
#   6. [GATED] Scoring: accuratezza det vs gold, accuratezza LLM vs gold, copertura
#      LLM sui casi dove det da' NA. Gira SOLO se il gold CSV compilato esiste.
#
# GATE UTENTE (non eseguito in automatico):
#   - Passo 4 richiede l'endpoint LLM (vLLM/DGX o OpenRouter) configurato
#     tramite variabili d'ambiente (vedi sezione CONFIG).
#   - Passo 6 richiede che l'utente compili `name-recovery-gold-template.csv`
#     (colonna `disease_or_compound_gold` valorizzata per i ~50 record campionati).
#   - La "decisione C" (LLM fallback in produzione) e' gated all'utente dopo
#     aver visto i numeri di scoring.
#
# UTILIZZO:
#   # Smoke (solo deterministico + template gold, senza LLM):
#   Rscript analysis/audit/name-recovery-llm-benchmark.R
#
#   # Con LLM via OpenRouter (imposta OPENROUTER_API_KEY prima):
#   OPENROUTER_API_KEY=sk-or-xxx Rscript analysis/audit/name-recovery-llm-benchmark.R
#
#   # Con LLM via vLLM DGX (tunnel SSH port-forward 8000, imposta VLLM_BASE_URL):
#   VLLM_BASE_URL=http://localhost:8000/v1/chat/completions \
#   VLLM_MODEL=mistralai/Mistral-Small-3.2-24B-Instruct-2506 \
#   Rscript analysis/audit/name-recovery-llm-benchmark.R
#
# OUTPUT:
#   analysis/audit/name-recovery-llm-benchmark-out.csv  (tabella per-cluster)
#   analysis/audit/name-recovery-gold-template.csv       (template gold da compilare)
#   analysis/audit/name-recovery-llm-benchmark-out.txt  (summary)
#
# RUNNER CORRETTO (renv attivo: rhdf5 + arrow + devtools disponibili):
#   Rscript analysis/audit/name-recovery-llm-benchmark.R

suppressPackageStartupMessages({
  library(rhdf5)
  library(dplyr)
  library(arrow)
  library(jsonlite)
})

# ===========================================================================
# CONFIG (parametrizzazione — modifica qui o passa via variabili d'ambiente)
# ===========================================================================

# Percorsi dati (stessi defaults di stage3-homogeneity-check.R)
args <- commandArgs(trailingOnly = TRUE)
STAGE3_DIR    <- if (length(args) >= 1) args[1] else
  "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
H5_PATH       <- if (length(args) >= 2) args[2] else
  "analysis/input/human_gene_v2.5.h5"
STAGE2_MASTER <- if (length(args) >= 3) args[3] else
  "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

# Campionamento
N_SAMPLE      <- as.integer(Sys.getenv("N_SAMPLE",      "200"))  # cluster UNK da campionare
N_GOLD        <- as.integer(Sys.getenv("N_GOLD",        "50"))   # record per template gold

# Config LLM (passo 4, GATED)
# Provider: "openrouter" (usa OPENROUTER_API_KEY) oppure "vllm" (usa VLLM_BASE_URL)
LLM_PROVIDER  <- Sys.getenv("LLM_PROVIDER",   "openrouter")
LLM_MODEL     <- Sys.getenv("LLM_MODEL",      "mistralai/mistral-small-3.2-24b-instruct")
VLLM_BASE_URL <- Sys.getenv("VLLM_BASE_URL",  "http://localhost:8000/v1/chat/completions")
# Produzione: modello Mistral-Small-3.2 self-hosted via vLLM DGX UniPD.
# Per accedervi: port-forward SSH e imposta VLLM_BASE_URL + LLM_PROVIDER=vllm.

# Percorsi output
OUT_CSV       <- "analysis/audit/name-recovery-llm-benchmark-out.csv"
OUT_TXT       <- "analysis/audit/name-recovery-llm-benchmark-out.txt"
GOLD_TEMPLATE <- "analysis/audit/name-recovery-gold-template.csv"

# Kind da auditare (stessi di homogeneity-check.R)
AUDIT_KINDS <- c(
  "disease_vs_normal",
  "small_molecule",
  "cytokine_stim",
  "pathogen_or_aggregate_exposure"
)

# ===========================================================================
# 0. Verifica file di input
# ===========================================================================

cat("=== Benchmark recupero-nome LLM vs deterministico (cluster UNK) ===\n")
cat("  stage3_dir    :", STAGE3_DIR, "\n")
cat("  h5_path       :", H5_PATH, "\n")
cat("  stage2_master :", STAGE2_MASTER, "\n")
cat("  N_SAMPLE      :", N_SAMPLE, "\n")
cat("  N_GOLD        :", N_GOLD, "\n\n")

for (f in c(STAGE3_DIR, H5_PATH, STAGE2_MASTER)) {
  if (!file.exists(f)) stop("File/directory non trovato: ", f)
}

# ===========================================================================
# 1. Carica il pacchetto (DRY: recover_identity + .load_ontology_dicts)
# ===========================================================================

cat("[1/9] Caricamento pacchetto simulomicsr...\n")
if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all(quiet = TRUE)
} else if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(quiet = TRUE)
} else {
  stop("devtools o pkgload necessari per caricare il pacchetto.")
}
stopifnot(exists("recover_identity"))
.load_ontology_dicts_fn <- get(".load_ontology_dicts", envir = asNamespace("simulomicsr"))

# ===========================================================================
# 2. Carica ontologia
# ===========================================================================

cat("[2/9] Caricamento ontologia (MeSH + ChEBI + HGNC) — ~25s...\n")
t_onto <- system.time(onto <- .load_ontology_dicts_fn())
cat("  Ontologia caricata in", round(t_onto[3], 1), "sec\n\n")

# ===========================================================================
# 3. Carica metadati H5 in bulk (stessa logica di stage3-homogeneity-check.R)
# ===========================================================================

cat("[3/9] Lettura metadati campioni dall'H5...\n")
t_h5 <- system.time({
  h5_geo_acc <- h5read(H5_PATH, "meta/samples/geo_accession")
  h5_source  <- h5read(H5_PATH, "meta/samples/source_name_ch1")
  h5_char    <- h5read(H5_PATH, "meta/samples/characteristics_ch1")
  h5_title   <- h5read(H5_PATH, "meta/samples/title")
})
n_h5 <- length(h5_geo_acc)
cat("  Letti", n_h5, "campioni in", round(t_h5[3], 1), "sec\n\n")

# ===========================================================================
# 4. Carica clusters.rds + filtra UNK auditabili
# ===========================================================================

cat("[4/9] Caricamento cluster Stadio 3...\n")
clusters_path <- file.path(STAGE3_DIR, "clusters.rds")
if (!file.exists(clusters_path)) stop("clusters.rds non trovato in: ", STAGE3_DIR)
cl_all <- readRDS(clusters_path)
cat("  Cluster totali:", nrow(cl_all), "\n")

# Filtra: agent_id_resolved == "UNK" + kind auditabile + k >= 2
cl_unk <- cl_all |>
  filter(
    agent_id_resolved == "UNK",
    kind_effective_resolved %in% AUDIT_KINDS,
    n_studies >= 2
  )
cat("  Cluster UNK auditabili (kind OK + k>=2):", nrow(cl_unk), "\n")
cat("  Split per kind:\n")
print(table(cl_unk$kind_effective_resolved))

# Campionamento stratificato per kind (deterministico, seed=42)
set.seed(42L)
if (nrow(cl_unk) > N_SAMPLE) {
  kind_counts <- table(cl_unk$kind_effective_resolved)
  kind_quota  <- ceiling(N_SAMPLE * kind_counts / nrow(cl_unk))
  sampled_rows <- lapply(names(kind_quota), function(k) {
    sub <- cl_unk[cl_unk$kind_effective_resolved == k, ]
    n_k <- min(kind_quota[[k]], nrow(sub))
    sub[sample(nrow(sub), n_k), ]
  })
  cl_sample <- do.call(rbind, sampled_rows)
} else {
  cl_sample <- cl_unk
}
cat("\n  Campione stratificato:", nrow(cl_sample), "cluster\n")
cat("  Split campione per kind:\n")
print(table(cl_sample$kind_effective_resolved))
cat("\n")

# ===========================================================================
# 4b. Costruisce mappa record_id -> GSM membri (DRY: stessa logica di
#     stage3-homogeneity-check.R — NON duplicare la logica, rispecchiarla)
# ===========================================================================

cat("[4b] Costruzione mappa record_id -> GSM dal master Stadio 2...\n")

assignments_path <- file.path(STAGE3_DIR, "assignments.parquet")
if (!file.exists(assignments_path)) stop("assignments.parquet non trovato in: ", STAGE3_DIR)
assignments <- read_parquet(assignments_path)

t_map <- system.time({
  master_lines <- readLines(STAGE2_MASTER, warn = FALSE)
  rec_env <- new.env(parent = emptyenv())
  for (ln in master_lines) {
    st  <- jsonlite::fromJSON(ln, simplifyVector = FALSE)
    sid <- st$series_id
    if (is.null(sid) || !nzchar(sid)) next
    rg_lookup <- list()
    for (rg in st$replicate_groups) {
      gid  <- rg$group_id
      sids <- as.character(unlist(rg$sample_ids, use.names = FALSE))
      rg_lookup[[gid]] <- sids
      assign(paste0(sid, "__", gid), sids, envir = rec_env)
    }
    if (length(st$comparisons)) {
      for (cmp in st$comparisons) {
        tg <- rg_lookup[[cmp$treated_group]]
        if (is.null(tg)) next
        assign(paste0(sid, "__", cmp$comparison_id), tg, envir = rec_env)
      }
    }
  }
})
cat("  Mappa pronta:", length(ls(rec_env)), "record_id in", round(t_map[3], 1), "sec\n")

# Per ogni cluster campionato: record_id -> unione GSM, poi PRIMO GSM come rappresentante
cluster_records <- split(assignments$record_id, assignments$cluster_id)

.get_first_gsm <- function(cluster_id) {
  rids <- unique(cluster_records[[cluster_id]])
  if (length(rids) == 0L) return(NA_character_)
  gsms <- unique(unlist(
    lapply(rids, function(r) get0(r, envir = rec_env, ifnotfound = NULL)),
    use.names = FALSE
  ))
  if (length(gsms) == 0L) return(NA_character_)
  gsms[[1L]]  # primo GSM deterministico (lista non ordinata, ma riproducibile)
}

# Lookup GSM -> riga H5
union_gsm  <- unique(unlist(lapply(cl_sample$cluster_id, .get_first_gsm), use.names = FALSE))
union_gsm  <- union_gsm[!is.na(union_gsm)]
idx_by_gsm <- match(union_gsm, h5_geo_acc)
names(idx_by_gsm) <- union_gsm
n_in_h5 <- sum(!is.na(idx_by_gsm))
cat("  GSM rappresentanti distinti:", length(union_gsm),
    "| presenti in H5:", n_in_h5,
    sprintf("(%.1f%%)\n\n", if (length(union_gsm) > 0) 100 * n_in_h5 / length(union_gsm) else 0))

# ===========================================================================
# 5. Estrazione deterministica per ogni cluster campionato
# ===========================================================================

cat("[5/9] Estrazione deterministica (recover_identity) su", nrow(cl_sample), "cluster...\n")

.run_deterministic <- function(cluster_id, kind) {
  gsm <- .get_first_gsm(cluster_id)
  if (is.na(gsm)) {
    return(list(
      gsm           = NA_character_,
      source_text   = NA_character_,
      char_text     = NA_character_,
      title_text    = NA_character_,
      det_agent_id  = NA_character_,
      det_name      = NA_character_,
      det_source    = "NO_GSM",
      det_is_na     = TRUE
    ))
  }
  h5_idx <- idx_by_gsm[[gsm]]
  if (is.na(h5_idx)) {
    return(list(
      gsm           = gsm,
      source_text   = NA_character_,
      char_text     = NA_character_,
      title_text    = NA_character_,
      det_agent_id  = NA_character_,
      det_name      = NA_character_,
      det_source    = "GSM_NOT_IN_H5",
      det_is_na     = TRUE
    ))
  }
  src   <- h5_source[h5_idx]
  chars <- h5_char[h5_idx]
  ttl   <- h5_title[h5_idx]

  result <- tryCatch(
    recover_identity(
      source          = src,
      characteristics = chars,
      title           = ttl,
      llm_kind        = kind,
      ontology_env    = onto
    ),
    error = function(e) list(
      agent_id        = NA_character_,
      canonical_name  = NA_character_,
      recovery_source = paste0("ERROR:", conditionMessage(e))
    )
  )
  list(
    gsm           = gsm,
    source_text   = src,
    char_text     = chars,
    title_text    = ttl,
    det_agent_id  = result$agent_id,
    det_name      = result$canonical_name,
    det_source    = result$recovery_source,
    det_is_na     = (is.null(result$agent_id) || is.na(result$agent_id))
  )
}

det_results <- vector("list", nrow(cl_sample))
t_det <- system.time({
  for (j in seq_len(nrow(cl_sample))) {
    row <- cl_sample[j, ]
    det_results[[j]] <- .run_deterministic(row$cluster_id, row$kind_effective_resolved)
    if (j %% 50L == 0L || j == nrow(cl_sample)) {
      cat("  Processati", j, "/", nrow(cl_sample), "...\n")
    }
  }
})
cat("  Elaborazione deterministica:", round(t_det[3], 1), "sec\n\n")

# Assembla tabella base
det_df <- bind_cols(
  cl_sample |> select(cluster_id, kind = kind_effective_resolved, mode, n_studies,
                      anchor_key, agent_id_llm_original),
  bind_rows(lapply(det_results, as.data.frame, stringsAsFactors = FALSE))
)

# ===========================================================================
# 6. Riepilogo risultati deterministici
# ===========================================================================

cat("[6/9] Riepilogo estrazione deterministica:\n")
n_total      <- nrow(det_df)
n_det_ok     <- sum(!det_df$det_is_na, na.rm = TRUE)
n_det_na     <- sum(det_df$det_is_na,  na.rm = TRUE)
pct_ok       <- round(100 * n_det_ok / n_total, 1)
pct_na       <- round(100 * n_det_na / n_total, 1)
cat(sprintf("  Totale campionati  : %d\n", n_total))
cat(sprintf("  Det recuperati     : %d (%.1f%%)\n", n_det_ok, pct_ok))
cat(sprintf("  Det NA (U1)        : %d (%.1f%%)\n", n_det_na, pct_na))

cat("  Per kind:\n")
for (k in AUDIT_KINDS) {
  sub_k <- det_df[det_df$kind == k, ]
  if (nrow(sub_k) == 0) next
  n_ok_k <- sum(!sub_k$det_is_na, na.rm = TRUE)
  cat(sprintf("    %-40s : %3d cluster | det OK: %3d (%.0f%%)\n",
              k, nrow(sub_k), n_ok_k, 100 * n_ok_k / nrow(sub_k)))
}
cat("  Per recovery_source:\n")
print(table(det_df$det_source))
cat("\n")

# ===========================================================================
# 7. Genera template gold (~N_GOLD record, stratificati per kind)
# ===========================================================================

cat("[7/9] Generazione template gold (", N_GOLD, "record per revisione umana)...\n")

# Stratifica N_GOLD proporzionalmente ai kind presenti nel campione
kind_counts_sample <- table(det_df$kind)
gold_quota <- ceiling(N_GOLD * kind_counts_sample / nrow(det_df))
set.seed(123L)  # seed distinto per il gold (riproducibile separatamente)
gold_rows <- lapply(names(gold_quota), function(k) {
  sub <- det_df[det_df$kind == k, ]
  n_k <- min(gold_quota[[k]], nrow(sub))
  sub[sample(nrow(sub), n_k), ]
})
gold_df <- do.call(rbind, gold_rows)

# Costruisce il CSV template: campi human-readable + colonna vuota gold
gold_template <- gold_df |>
  select(
    cluster_id, kind, n_studies, gsm,
    source_text, char_text, title_text,
    det_agent_id, det_name, det_source
  ) |>
  mutate(
    disease_or_compound_gold = NA_character_  # COMPILARE A MANO: nome leggibile della malattia/composto
  )

if (file.exists(GOLD_TEMPLATE)) {
  cat("  ATTENZIONE: template gold gia' esistente, NON sovrascritto:", GOLD_TEMPLATE, "\n")
  cat("  Rinomina o elimina il file esistente per rigenerarlo.\n")
} else {
  write.csv(gold_template, GOLD_TEMPLATE, row.names = FALSE, quote = TRUE, na = "")
  cat("  Template gold scritto:", GOLD_TEMPLATE, "(", nrow(gold_template), "righe)\n")
  cat("  >>> Compila la colonna 'disease_or_compound_gold' per abilitare il passo 9 (scoring).\n")
}
cat("\n")

# ===========================================================================
# 8. [GATED] Estrazione LLM mirata
#
# Richiede:
#   - LLM_PROVIDER=openrouter + OPENROUTER_API_KEY, oppure
#   - LLM_PROVIDER=vllm + VLLM_BASE_URL + VLLM_MODEL (default vedi header)
#
# Se le variabili non sono impostate o l'endpoint non e' raggiungibile,
# il passo viene saltato con un messaggio chiaro (senza errore fatale).
# ===========================================================================

cat("[8/9] [GATED] Estrazione LLM mirata...\n")

# Controlla disponibilita' LLM
.llm_available <- function() {
  if (LLM_PROVIDER == "openrouter") {
    key <- Sys.getenv("OPENROUTER_API_KEY", unset = "")
    if (!nzchar(key)) {
      cat("  SKIP: OPENROUTER_API_KEY non impostata (provider=openrouter).\n")
      return(FALSE)
    }
    return(TRUE)
  } else if (LLM_PROVIDER == "vllm") {
    key <- Sys.getenv("VLLM_API_KEY", unset = "none")  # vLLM accetta qualunque valore
    # Verifica raggiungibilita' dell'endpoint con timeout breve
    reachable <- tryCatch({
      resp <- httr2::request(VLLM_BASE_URL) |>
        httr2::req_method("GET") |>
        httr2::req_timeout(seconds = 5) |>
        httr2::req_error(is_error = function(r) FALSE) |>
        httr2::req_perform()
      TRUE
    }, error = function(e) FALSE)
    if (!reachable) {
      cat("  SKIP: vLLM endpoint non raggiungibile:", VLLM_BASE_URL, "\n")
      cat("  Imposta VLLM_BASE_URL (es. http://localhost:8000/v1/chat/completions)\n")
      cat("  e avvia il port-forward SSH verso il DGX prima di rieseguire.\n")
      return(FALSE)
    }
    return(TRUE)
  } else {
    cat("  SKIP: LLM_PROVIDER non riconosciuto:", LLM_PROVIDER, "\n")
    return(FALSE)
  }
}

# Schema JSON per la risposta LLM (minimal: solo il nome dell'entita')
# Creato come file temporaneo — NON in inst/ (questo e' script eval, non produzione).
.write_name_recovery_schema <- function() {
  schema <- list(
    type = "object",
    properties = list(
      entity_name = list(
        type = "string",
        description = paste(
          "Nome testuale dell'entita' biologica. Per malattie: nome MeSH preferito",
          "(es. 'Lung Neoplasms', 'Alzheimer Disease'). Per composti/stimoli:",
          "nome IUPAC o nome comune (es. 'lipopolysaccharide', 'ethanol', 'IFN-beta').",
          "Usa NA se non determinabile dal testo."
        )
      ),
      confidence = list(
        type = "string",
        enum = c("high", "medium", "low", "not_determinable")
      )
    ),
    required = c("entity_name", "confidence"),
    additionalProperties = FALSE
  )
  tmp <- tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(schema, auto_unbox = TRUE, pretty = TRUE), tmp)
  tmp
}

# Prompt per l'LLM (tipo-dipendente)
.build_llm_prompt <- function(kind, gsm, source_text, char_text, title_text) {
  # Pulisce i campi NA
  src   <- if (!is.na(source_text) && nzchar(source_text)) source_text else "(missing)"
  chars <- if (!is.na(char_text)   && nzchar(char_text))   char_text   else "(missing)"
  ttl   <- if (!is.na(title_text)  && nzchar(title_text))  title_text  else "(missing)"

  task_desc <- if (kind == "disease_vs_normal") {
    paste(
      "Questo campione proviene da un cluster 'disease_vs_normal' (caso-malattia vs sano).",
      "Estrai il NOME DELLA MALATTIA specifica (es. 'Alzheimer Disease', 'Lung Adenocarcinoma',",
      "'Rheumatoid Arthritis'). NON riportare 'normal', 'healthy', 'control'.",
      "Se non determinabile, rispondi con entity_name='NA'."
    )
  } else {
    paste(
      "Questo campione proviene da un cluster perturbativo (kind:", kind, ").",
      "Estrai il NOME DEL COMPOSTO, STIMOLO O AGENTE specifico",
      "(es. 'lipopolysaccharide', 'IFN-beta', 'poly(I:C)', 'ethanol').",
      "NON riportare 'vehicle', 'control', 'untreated', 'DMSO'.",
      "Se non determinabile, rispondi con entity_name='NA'."
    )
  }

  sys_msg <- paste0(
    "Sei un curatore esperto di metadati GEO RNAseq. Dato un record di metadati GEO, ",
    "estrai UNA SOLA entita' biologica chiave. Rispondi SOLO con il JSON richiesto."
  )
  user_msg <- paste0(
    task_desc, "\n\n",
    "METADATI GEO (GSM: ", gsm, "):\n",
    "  source_name: ", src, "\n",
    "  characteristics: ", chars, "\n",
    "  title: ", ttl
  )
  list(
    list(role = "system", content = sys_msg),
    list(role = "user",   content = user_msg)
  )
}

# Chiama l'LLM (openrouter o vllm, json_object mode)
.call_llm_name <- function(kind, gsm, source_text, char_text, title_text, schema_path) {
  msgs <- .build_llm_prompt(kind, gsm, source_text, char_text, title_text)

  if (LLM_PROVIDER == "openrouter") {
    res <- tryCatch(
      llm_call_structured(
        provider        = "openrouter",
        model           = LLM_MODEL,
        messages        = msgs,
        response_schema = schema_path,
        temperature     = 0.0,
        max_tokens      = 256L
      ),
      error = function(e) list(value = NULL, error = conditionMessage(e))
    )
    val <- res$value
  } else if (LLM_PROVIDER == "vllm") {
    # Chiamata diretta httr2 (openai-compatible, json_object mode)
    # vLLM supporta response_format=json_object universalmente.
    vllm_key <- Sys.getenv("VLLM_API_KEY", unset = "none")
    vllm_model <- Sys.getenv("VLLM_MODEL", LLM_MODEL)
    body <- list(
      model           = vllm_model,
      messages        = msgs,
      response_format = list(type = "json_object"),
      temperature     = 0.0,
      max_tokens      = 256L
    )
    req <- httr2::request(VLLM_BASE_URL) |>
      httr2::req_method("POST") |>
      httr2::req_headers(
        Authorization  = paste("Bearer", vllm_key),
        `Content-Type` = "application/json"
      ) |>
      httr2::req_body_raw(
        charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")),
        type = "application/json"
      ) |>
      httr2::req_timeout(seconds = 60) |>
      httr2::req_retry(max_tries = 2L, backoff = function(i) 5)
    resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
    if (is.null(resp)) return(list(entity_name = NA_character_, confidence = "not_determinable"))
    resp_body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
    content   <- resp_body$choices[[1]]$message$content
    val <- tryCatch(jsonlite::fromJSON(content, simplifyVector = FALSE), error = function(e) NULL)
  } else {
    return(list(entity_name = NA_character_, confidence = "not_determinable"))
  }

  if (is.null(val) || !is.list(val)) {
    return(list(entity_name = NA_character_, confidence = "not_determinable"))
  }
  val
}

# Esegui passo 8 solo se LLM disponibile
llm_col_name    <- rep(NA_character_, nrow(det_df))
llm_col_conf    <- rep(NA_character_, nrow(det_df))
llm_ran         <- FALSE

if (.llm_available()) {
  cat("  LLM disponibile (provider:", LLM_PROVIDER, "| model:", LLM_MODEL, ")\n")
  cat("  Chiamo l'LLM per", nrow(det_df), "record...\n")
  schema_tmp <- .write_name_recovery_schema()
  on.exit(unlink(schema_tmp), add = TRUE)

  t_llm <- system.time({
    for (j in seq_len(nrow(det_df))) {
      row <- det_df[j, ]
      r   <- .call_llm_name(
        kind        = row$kind,
        gsm         = row$gsm,
        source_text = row$source_text,
        char_text   = row$char_text,
        title_text  = row$title_text,
        schema_path = schema_tmp
      )
      llm_col_name[[j]] <- r$entity_name %||% NA_character_
      llm_col_conf[[j]] <- r$confidence  %||% NA_character_
      if (j %% 20L == 0L || j == nrow(det_df)) {
        cat("  LLM:", j, "/", nrow(det_df), "\n")
      }
    }
  })
  cat("  LLM completato in", round(t_llm[3], 1), "sec\n\n")
  llm_ran <- TRUE
} else {
  cat("  Passo 8 saltato — esegui con LLM configurato per completare il benchmark.\n\n")
}

det_df$llm_name       <- llm_col_name
det_df$llm_confidence <- llm_col_conf

# ===========================================================================
# 9. [GATED] Scoring vs gold umano
#
# Richiede che l'utente abbia compilato la colonna `disease_or_compound_gold`
# nel file GOLD_TEMPLATE. Il file viene riletto (non usa l'oggetto in memoria)
# per catturare le modifiche manuali.
# ===========================================================================

cat("[9/9] [GATED] Scoring vs gold umano...\n")

scoring_df <- NULL

if (!file.exists(GOLD_TEMPLATE)) {
  cat("  SKIP: template gold non trovato:", GOLD_TEMPLATE, "\n")
  cat("  Genera prima il template (passo 7) e compila la colonna 'disease_or_compound_gold'.\n\n")
} else {
  gold_read <- tryCatch(
    read.csv(GOLD_TEMPLATE, stringsAsFactors = FALSE, na.strings = c("", "NA")),
    error = function(e) NULL
  )
  if (is.null(gold_read)) {
    cat("  ERRORE lettura gold template:", GOLD_TEMPLATE, "\n\n")
  } else if (!("disease_or_compound_gold" %in% names(gold_read))) {
    cat("  SKIP: colonna 'disease_or_compound_gold' mancante nel gold template.\n\n")
  } else {
    gold_filled <- gold_read |>
      filter(!is.na(disease_or_compound_gold) & nzchar(disease_or_compound_gold))
    n_gold_filled <- nrow(gold_filled)
    if (n_gold_filled == 0) {
      cat("  SKIP: nessun record gold compilato (colonna 'disease_or_compound_gold' vuota).\n")
      cat("  Compila il template e rilancia lo script per lo scoring.\n\n")
    } else {
      cat("  Record gold compilati:", n_gold_filled, "su", nrow(gold_read), "\n")

      # Unisce gold con i risultati del benchmark
      scoring_df <- det_df |>
        inner_join(
          gold_filled |> select(cluster_id, gold = disease_or_compound_gold),
          by = "cluster_id"
        )

      # Normalizzazione case-insensitive per il confronto
      .norm <- function(x) tolower(trimws(x))

      # Metrica: il nome recuperato corrisponde al gold? (match parziale: gold %in% nome o viceversa)
      # Usiamo grepl(gold, nome, ignore.case=TRUE) come proxy fuzzy (sufficiente per la decisione C).
      .match_gold <- function(name, gold) {
        if (is.na(name) || is.na(gold)) return(NA)
        grepl(.norm(gold), .norm(name), fixed = TRUE) |
          grepl(.norm(name), .norm(gold), fixed = TRUE)
      }

      scoring_df$det_match <- mapply(.match_gold, scoring_df$det_name, scoring_df$gold)
      scoring_df$llm_match <- mapply(.match_gold, scoring_df$llm_name, scoring_df$gold)

      # Accuratezza complessiva
      n_sc        <- nrow(scoring_df)
      acc_det     <- sum(scoring_df$det_match, na.rm = TRUE) / n_sc
      acc_det_na  <- sum(is.na(scoring_df$det_name)) / n_sc

      cat(sprintf("\n  Accuratezza deterministico (det_name vs gold) : %.1f%% (%d/%d)\n",
                  100 * acc_det, sum(scoring_df$det_match, na.rm = TRUE), n_sc))
      cat(sprintf("  Copertura det (non-NA)                        : %.1f%%\n",
                  100 * (1 - acc_det_na)))

      if (llm_ran) {
        acc_llm  <- sum(scoring_df$llm_match, na.rm = TRUE) / n_sc
        acc_llm_na <- sum(is.na(scoring_df$llm_name) |
                          scoring_df$llm_name == "NA", na.rm = TRUE) / n_sc
        # Copertura LLM sui casi dove det e' NA
        det_na_rows <- scoring_df[is.na(scoring_df$det_name), ]
        llm_cov_det_na <- if (nrow(det_na_rows) > 0)
          sum(!is.na(det_na_rows$llm_name) & det_na_rows$llm_name != "NA") / nrow(det_na_rows)
        else NA_real_

        cat(sprintf("  Accuratezza LLM (llm_name vs gold)           : %.1f%% (%d/%d)\n",
                    100 * acc_llm, sum(scoring_df$llm_match, na.rm = TRUE), n_sc))
        cat(sprintf("  Copertura LLM (non-NA)                       : %.1f%%\n",
                    100 * (1 - acc_llm_na)))
        cat(sprintf("  Copertura LLM sui casi det-NA                : %.1f%%\n",
                    if (!is.na(llm_cov_det_na)) 100 * llm_cov_det_na else 0))
      } else {
        cat("  [Scoring LLM saltato — LLM non disponibile in questa sessione]\n")
      }
      cat("\n")
    }
  }
}

# ===========================================================================
# Salvataggio output e summary
# ===========================================================================

cat("Salvataggio output...\n")
write.csv(det_df, OUT_CSV, row.names = FALSE, quote = TRUE, na = "")
cat("  Tabella benchmark salvata:", OUT_CSV, "\n")

summary_lines <- character(0)
.add <- function(...) summary_lines <<- c(summary_lines, paste0(...))

.add("=== BENCHMARK RECUPERO-NOME LLM vs DETERMINISTICO ===")
.add("Data    : ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"))
.add("Stage3  : ", STAGE3_DIR)
.add("")
.add("--- Campione cluster UNK ---")
.add(sprintf("  UNK auditabili (kind OK + k>=2) : %d", nrow(cl_unk)))
.add(sprintf("  Campionati (stratificati)        : %d", nrow(cl_sample)))
.add("")
.add("--- Estrazione deterministica ---")
.add(sprintf("  Recuperati (non-NA) : %d (%.1f%%)", n_det_ok, pct_ok))
.add(sprintf("  NA (regime U1)      : %d (%.1f%%)", n_det_na, pct_na))
for (k in AUDIT_KINDS) {
  sub_k <- det_df[det_df$kind == k, ]
  if (nrow(sub_k) == 0) next
  n_ok_k <- sum(!sub_k$det_is_na, na.rm = TRUE)
  .add(sprintf("    %-40s : %3d | det OK: %3d (%.0f%%)",
               k, nrow(sub_k), n_ok_k, 100 * n_ok_k / nrow(sub_k)))
}
.add("")
.add("--- Template gold ---")
.add(sprintf("  File: %s", GOLD_TEMPLATE))
.add(sprintf("  Righe: %d", if (file.exists(GOLD_TEMPLATE)) nrow(gold_template) else 0))
.add("")
.add("--- Scoring (gated) ---")
if (!is.null(scoring_df) && nrow(scoring_df) > 0) {
  .add(sprintf("  Gold compilati: %d", nrow(scoring_df)))
  .add(sprintf("  Acc. det:       %.1f%%", 100 * acc_det))
  if (llm_ran) {
    .add(sprintf("  Acc. LLM:       %.1f%%", 100 * acc_llm))
    .add(sprintf("  Cov. LLM/det-NA:%.1f%%",
                 if (!is.na(llm_cov_det_na)) 100 * llm_cov_det_na else 0))
  } else {
    .add("  LLM: non eseguito")
  }
} else {
  .add("  Gold non compilato — scoring sospeso")
}
.add("")
.add("--- Prossimi passi (GATE UTENTE) ---")
.add("  1. Compila 'disease_or_compound_gold' in name-recovery-gold-template.csv")
.add("  2. Configura LLM (OPENROUTER_API_KEY o VLLM_BASE_URL) e rilancia")
.add("  3. Valuta numeri scoring con l'utente -> decisione C (LLM fallback in produzione)")

cat(paste(summary_lines, collapse = "\n"), "\n")
writeLines(summary_lines, OUT_TXT)
cat("\n  Summary salvato:", OUT_TXT, "\n")
cat("\nFINE benchmark recupero-nome.\n")
