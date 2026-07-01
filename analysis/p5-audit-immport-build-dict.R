# analysis/p5-audit-immport-build-dict.R
# Build dizionario ImmPort citochine: sinonimi → HGNC + whitelist "è-citochina".
#
# Input:
#   - analysis/p4-output/cytokine-registry-immport-2015.xls (foglio "Registry",
#     275 righe × 30 colonne, SHA256 dc626e...bcc)
#   - API ImmPort lkProteinName  (Bearer token da env IMMPORT_API_KEY)
#   - GO whitelist (Task 15): /mnt/.../go-cytokine-hgnc.rds
#     Elemento $go_cytokine_hgnc_int (213 interi)
#
# Output:
#   - cache/immport/immport-lookup.rds  (via tools::R_user_dir)
#       list(synonyms=<df>, cytokine_hgnc_int=<int>, meta=<list>)
#   - analysis/p4-output/immport-source-provenance.json  (senza API key)
#
# Esecuzione:
#   IMMPORT_API_KEY=<token> Rscript analysis/p5-audit-immport-build-dict.R
# oppure senza la variabile (degradato: registry + GO senza API):
#   Rscript analysis/p5-audit-immport-build-dict.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(readxl)
  library(httr2)
  library(jsonlite)
  library(cli)
  library(digest)
})

cli_h1("ImmPort dizionario citochine — build")
t0 <- proc.time()

# ─── percorsi ─────────────────────────────────────────────────────────────────
XLS_PATH   <- "analysis/p4-output/cytokine-registry-immport-2015.xls"
GO_RDS     <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-biolex-build/go-cytokine-hgnc.rds"
CACHE_DIR  <- file.path(tools::R_user_dir("simulomicsr", "cache"), "immport")
OUT_RDS    <- file.path(CACHE_DIR, "immport-lookup.rds")
PROV_JSON  <- "analysis/p4-output/immport-source-provenance.json"
SHA256_XLS <- "dc626e4e6ff9e4e848e7547be1a76a64f0f0f24cb0859c5520e07cd36cc01bcc"
API_URL    <- "https://www.immport.org/data/query/api/lookup/lkProteinName?format=json"

stopifnot("XLS Registry non trovato" = file.exists(XLS_PATH))
dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)
cli_alert_info(sprintf("Output RDS: %s", OUT_RDS))

# ─── carica pacchetto (per .normalize_biological_mention + accessori HGNC) ───
cli_alert_info("Carico simulomicsr (devtools::load_all) ...")
devtools::load_all(quiet = TRUE)
cli_alert_success("Pacchetto caricato")

# Per il build del dizionario ImmPort serve SOLO l'indice HGNC (per i lookup
# API lkProteinName). Carichiamo solo il file HGNC per evitare di caricare
# tutto il pacchetto dizionari (ChEBI 16MB + Taxonomy 39MB → timeout).
# .load_ontology_dicts() completo viene usato SOLO nella verifica finale.
cli_alert_info("Carico solo indice HGNC (ottimizzazione: evita carico taxonomy 39MB) ...")
hgnc_cache <- file.path(tools::R_user_dir("simulomicsr", "cache"), "hgnc-lookup.rds")
stopifnot("hgnc-lookup.rds non trovato (build via p5-audit-hgnc-mesh-build-dict.R)" =
            file.exists(hgnc_cache))
hgnc_raw <- readRDS(hgnc_cache)
hgnc_idx <- simulomicsr:::.build_hgnc_index(hgnc_raw)
# Env minimale compatibile con .hgnc_lookup_symbol(symbol, env)
env <- new.env(parent = emptyenv())
env$hgnc <- hgnc_idx
cli_alert_success(sprintf("HGNC caricato: %d geni", hgnc_idx$meta$n_genes))

# ─── helper: split alias multi-valore da una cella Excel ─────────────────────
# Separatore: ";" oppure newline. Trimma gli spazi e scarta le parti vuote.
split_aliases <- function(x) {
  if (is.na(x) || !nzchar(trimws(x))) return(character(0))
  parts <- unlist(strsplit(x, "[;\n\r]+"))
  parts <- trimws(parts)
  parts[nzchar(parts)]
}

# ─── helper: parse HGNC ID colonna → integer ──────────────────────────────────
# Input: "HGNC:5434" → 5434L; oppure NA se mancante o non parsabile.
parse_hgnc_id <- function(x) {
  if (length(x) != 1L || is.na(x) || !nzchar(trimws(x))) return(NA_integer_)
  m <- regmatches(x, regexpr("[0-9]+", x))
  if (length(m) == 0L) return(NA_integer_)
  as.integer(m)
}

# =============================================================================
# 1. Parse Registry ImmPort XLS
# =============================================================================
cli_h2("1. Registry ImmPort XLS")
cli_alert_info(sprintf("Leggo %s (foglio 'Registry') ...", XLS_PATH))
registry <- read_excel(XLS_PATH, sheet = "Registry")
cli_alert_success(sprintf("Letto: %d righe × %d colonne", nrow(registry), ncol(registry)))

# Colonne da cui estrarre alias (tutte le fonti di sinonimi)
ALIAS_COLS <- c(
  "REFERENCE NAME",
  "EntrezGene official name (Human)",
  "EntrezGene Symbol (Human)",
  "EntrezGene Aliases (Human)",
  "EntrezGene Additional Names (Human)",
  "UniProt protein name (Human)",
  "UniProt protein alternative names (Human)",
  "Typographical variations",
  "IX Synonyms",
  "Protein Ontology synonyms"
)
# Verifica presenza (tutte devono esserci, warn se mancano)
missing_cols <- setdiff(ALIAS_COLS, names(registry))
if (length(missing_cols) > 0L) {
  cli_alert_warning(sprintf(
    "Colonne alias non trovate nel foglio (verifica nomi): %s",
    paste(missing_cols, collapse = ", ")
  ))
  ALIAS_COLS <- intersect(ALIAS_COLS, names(registry))
}
cli_alert_info(sprintf("Colonne alias usate: %d", length(ALIAS_COLS)))

# Scansione riga per riga
syn_rows_reg    <- list()
registry_hgnc   <- integer(0)
n_righe_valide  <- 0L
n_alias_grezzi  <- 0L

for (i in seq_len(nrow(registry))) {
  hgnc_int <- parse_hgnc_id(registry[["HGNC ID"]][i])
  if (is.na(hgnc_int)) next              # scarta righe senza HGNC ID valido

  primary_symbol <- as.character(registry[["EntrezGene Symbol (Human)"]][i])
  reference_name <- as.character(registry[["REFERENCE NAME"]][i])
  if (is.na(primary_symbol) || primary_symbol == "NA") primary_symbol <- NA_character_
  if (is.na(reference_name) || reference_name == "NA") reference_name <- NA_character_

  registry_hgnc <- c(registry_hgnc, hgnc_int)
  n_righe_valide <- n_righe_valide + 1L

  for (col in ALIAS_COLS) {
    aliases_raw <- split_aliases(registry[[col]][i])
    n_alias_grezzi <- n_alias_grezzi + length(aliases_raw)
    for (alias in aliases_raw) {
      syn_norm <- simulomicsr:::.normalize_biological_mention(alias)
      if (!nzchar(syn_norm)) next
      syn_rows_reg[[length(syn_rows_reg) + 1L]] <- list(
        syn_norm       = syn_norm,
        hgnc_int       = hgnc_int,
        primary_symbol = primary_symbol,
        reference_name = reference_name
      )
    }
  }
}

registry_hgnc <- sort(unique(registry_hgnc))
cli_alert_success(sprintf(
  "Registry: %d righe con HGNC ID, %d alias grezzi, %d sinonimi normalizzati, %d HGNC unici",
  n_righe_valide, n_alias_grezzi, length(syn_rows_reg), length(registry_hgnc)
))

# =============================================================================
# 2. API ImmPort lkProteinName
# =============================================================================
cli_h2("2. API ImmPort lkProteinName")
api_key     <- Sys.getenv("IMMPORT_API_KEY", "")
api_hgnc    <- integer(0)
syn_rows_api <- list()
api_concern  <- character(0)

if (!nzchar(api_key)) {
  api_concern <- "IMMPORT_API_KEY non impostata — API saltata (degradato: solo registry + GO)"
  cli_alert_warning(api_concern)
} else {
  cli_alert_info(sprintf("GET %s ...", API_URL))
  resp <- tryCatch(
    request(API_URL) |>
      req_headers(Authorization = paste("Bearer", api_key)) |>
      req_timeout(60L) |>
      req_perform(),
    error = function(e) {
      msg <- sprintf("Chiamata API fallita: %s", conditionMessage(e))
      api_concern <<- msg
      cli_alert_warning(msg)
      NULL
    }
  )

  if (!is.null(resp) && resp_status(resp) == 200L) {
    api_data <- resp_body_json(resp, simplifyVector = TRUE)
    n_api    <- if (is.data.frame(api_data)) nrow(api_data) else length(api_data)
    cli_alert_success(sprintf("API: %d record ricevuti", n_api))

    n_resolved <- 0L
    for (i in seq_len(n_api)) {
      gene_name <- if (is.data.frame(api_data)) api_data$uniprot_gene_name[i]
                   else api_data[[i]][["uniprot_gene_name"]]
      if (is.null(gene_name) || is.na(gene_name) || !nzchar(gene_name)) next

      hit <- simulomicsr:::.hgnc_lookup_symbol(gene_name, env)
      if (is.null(hit)) next

      n_resolved <- n_resolved + 1L
      h <- as.integer(hit$hgnc_int)
      api_hgnc <- c(api_hgnc, h)

      # gene_name come sinonimo normalizzato
      sn_gene <- simulomicsr:::.normalize_biological_mention(gene_name)
      if (nzchar(sn_gene)) {
        syn_rows_api[[length(syn_rows_api) + 1L]] <- list(
          syn_norm       = sn_gene,
          hgnc_int       = h,
          primary_symbol = as.character(hit$primary_symbol),
          reference_name = NA_character_
        )
      }

      # name (UniProt accession) come sinonimo aggiuntivo
      prot_name <- if (is.data.frame(api_data)) api_data$name[i]
                   else api_data[[i]][["name"]]
      if (!is.null(prot_name) && !is.na(prot_name) && nzchar(prot_name)) {
        sn_prot <- simulomicsr:::.normalize_biological_mention(prot_name)
        if (nzchar(sn_prot)) {
          syn_rows_api[[length(syn_rows_api) + 1L]] <- list(
            syn_norm       = sn_prot,
            hgnc_int       = h,
            primary_symbol = as.character(hit$primary_symbol),
            reference_name = NA_character_
          )
        }
      }
    }

    api_hgnc <- sort(unique(api_hgnc))
    cli_alert_success(sprintf(
      "API: %d/%d uniprot_gene_name risolti a HGNC, %d HGNC unici",
      n_resolved, n_api, length(api_hgnc)
    ))
  } else if (!is.null(resp)) {
    api_concern <- sprintf("API HTTP %d — saltata (degradato)", resp_status(resp))
    cli_alert_warning(api_concern)
  }
}

# =============================================================================
# 3. GO whitelist (Task 15)
# =============================================================================
cli_h2("3. GO whitelist (Task 15)")
go_hgnc  <- integer(0)
has_go   <- FALSE

if (file.exists(GO_RDS)) {
  go_raw   <- readRDS(GO_RDS)
  go_hgnc  <- sort(unique(as.integer(go_raw$go_cytokine_hgnc_int)))
  go_hgnc  <- go_hgnc[!is.na(go_hgnc)]
  has_go   <- TRUE
  cli_alert_success(sprintf("GO whitelist: %d HGNC ID", length(go_hgnc)))
} else {
  cli_alert_warning(sprintf(
    "GO whitelist non trovata in '%s' — has_go=FALSE (concern: riduzione whitelist)", GO_RDS
  ))
}

# =============================================================================
# 4. Unione sinonimi e deduplicazione (first-wins su syn_norm)
# =============================================================================
cli_h2("4. Unione e deduplicazione sinonimi")
all_rows <- c(syn_rows_reg, syn_rows_api)
n_totale <- length(all_rows)
cli_alert_info(sprintf("Sinonimi prima della dedup: %d", n_totale))

synonyms <- data.frame(
  syn_norm       = vapply(all_rows, `[[`, character(1L), "syn_norm"),
  hgnc_int       = vapply(all_rows, function(x) as.integer(x$hgnc_int), integer(1L)),
  primary_symbol = vapply(all_rows, function(x) {
    s <- x$primary_symbol
    if (is.null(s) || is.na(s) || identical(s, "NA")) NA_character_ else as.character(s)
  }, character(1L)),
  reference_name = vapply(all_rows, function(x) {
    r <- x$reference_name
    if (is.null(r) || is.na(r) || identical(r, "NA")) NA_character_ else as.character(r)
  }, character(1L)),
  stringsAsFactors = FALSE
)
# First-wins per syn_norm (registry prima dell'API = priorità registry)
synonyms <- synonyms[!duplicated(synonyms$syn_norm), ]
cli_alert_success(sprintf(
  "Sinonimi dopo dedup: %d (da %d → %d rimossi duplicati)",
  nrow(synonyms), n_totale, n_totale - nrow(synonyms)
))

# =============================================================================
# 5. Whitelist HGNC citochine (unione registry + API + GO)
# =============================================================================
cytokine_hgnc_int <- sort(unique(c(registry_hgnc, api_hgnc, go_hgnc)))
cli_alert_success(sprintf(
  "Whitelist citochine: %d HGNC ID totali (registry=%d + API=%d + GO=%d, con sovrapposizione)",
  length(cytokine_hgnc_int), length(registry_hgnc), length(api_hgnc), length(go_hgnc)
))

# =============================================================================
# 6. Salva RDS
# =============================================================================
cli_h2("6. Salva output")
out <- list(
  synonyms          = synonyms,
  cytokine_hgnc_int = cytokine_hgnc_int,
  meta = list(
    source      = "immport-registry-2015 + lkProteinName + GO",
    release     = "2015-11 + api",
    has_go      = has_go,
    n_syn       = nrow(synonyms),
    n_whitelist = length(cytokine_hgnc_int),
    sha256_xls  = SHA256_XLS,
    built_at    = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
)
saveRDS(out, OUT_RDS)
rds_kb <- file.size(OUT_RDS) / 1024
cli_alert_success(sprintf("Scritto %s (%.0f KB)", OUT_RDS, rds_kb))

# =============================================================================
# 7. Provenienza JSON (senza API key)
# =============================================================================
prov <- list(
  registry_xls    = XLS_PATH,
  sha256_xls      = SHA256_XLS,
  api_url         = API_URL,
  go_rds          = GO_RDS,
  n_syn           = nrow(synonyms),
  n_whitelist     = length(cytokine_hgnc_int),
  n_registry_hgnc = length(registry_hgnc),
  n_api_hgnc      = length(api_hgnc),
  n_go_hgnc       = length(go_hgnc),
  has_go          = has_go,
  out_rds         = OUT_RDS,
  built_at        = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)
if (length(api_concern) > 0L) prov$api_concern <- api_concern
dir.create(dirname(PROV_JSON), showWarnings = FALSE, recursive = TRUE)
write(toJSON(prov, pretty = TRUE, auto_unbox = TRUE), PROV_JSON)
cli_alert_success(sprintf("Provenienza scritta in %s", PROV_JSON))

# =============================================================================
# Summary
# =============================================================================
t_tot <- proc.time() - t0
cli_h2("Summary")
cli_alert_success(sprintf("Sinonimi totali:     %d", nrow(synonyms)))
cli_alert_success(sprintf("Whitelist citochine: %d HGNC ID", length(cytokine_hgnc_int)))
cli_alert_success(sprintf("has_go:              %s", has_go))
cli_alert_success(sprintf("Tempo totale:        %.0f sec", t_tot["elapsed"]))
if (length(api_concern) > 0L) {
  cli_alert_warning(sprintf("CONCERN API: %s", api_concern))
}
cli_rule()
cli_alert_info("Verifica:")
cli_alert_info(paste0(
  "Rscript -e 'devtools::load_all(quiet=TRUE);",
  " e<-.load_ontology_dicts(refresh=TRUE);",
  " cat(\"has_immport:\", e$has_immport, \"has_go_cytokine:\", e$has_go_cytokine, \"\\n\");",
  " print(.immport_lookup_synonym(\"IFN-beta\", e));",
  " print(.immport_lookup_synonym(\"beta interferon\", e));",
  " cat(\"is_cytokine IFNB1(5434):\", .is_cytokine_symbol(5434L, e), \"\\n\")'"
))
