# analysis/p5-audit-uniprot-build-dict.R
# Build dizionario UniProt Swiss-Prot human: nomi proteina normalizzati → accession + HGNC.
# Usato da R/ontology-lookup.R: .build_uniprot_index / .uniprot_lookup_name
# per risoluzione nomi proteici di citochine/proteine nei cluster S3.
#
# Sorgente: uniprot_sprot_human.dat.gz (divisione tassonomica umana, Swiss-Prot reviewed)
#   URL primario: ftp.uniprot.org/pub/databases/uniprot/current_release/
#                 knowledgebase/taxonomic_divisions/uniprot_sprot_human.dat.gz
#
# Struttura .rds attesa da .build_uniprot_index (vedere R/ontology-lookup.R):
#   list(
#     names = data.frame(name_norm chr, accession chr, hgnc_int int),
#     meta  = list(source, url, release, sha256, built_at, n,
#                  n_entries_total, n_entries_mapped, n_entries_no_hgnc,
#                  n_entries_no_de)
#   )
#
# Strategia:
#   Per ogni entry Swiss-Prot human:
#     AC → accession primario (primo token della prima riga AC)
#     GN → Name= + Synonyms= → mappa via .hgnc_lookup_symbol → hgnc_int
#     DE → RecName:/AltName: Full= + Short= → normalizza via
#          .normalize_biological_mention → name_norm
#   Scarta entry senza HGNC o senza DE.
#   Deduplicazione per name_norm (first-wins).
#
# Include sanity check .PAMP_WHITELIST (Task 17 gate): verifica che ogni
# CHEBI:<int> esista nella nostra ChEBI dict e documenta i ruoli trovati.
#
# Disco download (evita NVMe):
#   /mnt/wwn-0x5000039d58caca35/simulomicsr-biolex-build/
# Cache finale (.rds):
#   ~/.cache/R/simulomicsr/uniprot/uniprot-lookup.rds
# Provenienza:
#   analysis/p4-output/uniprot-source-provenance.json

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(cli)
  library(digest)
  library(jsonlite)
})

cli_h1("UniProt Swiss-Prot human lookup dictionary build")
t0_totale <- proc.time()

# ─── percorsi ─────────────────────────────────────────────────────────────────
BIG_DIR      <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-biolex-build"
CACHE_DIR    <- file.path(tools::R_user_dir("simulomicsr", "cache"), "uniprot")
PROV_JSON    <- "analysis/p4-output/uniprot-source-provenance.json"
UNIPROT_URL  <- paste0("https://ftp.uniprot.org/pub/databases/uniprot/",
                       "current_release/knowledgebase/taxonomic_divisions/",
                       "uniprot_sprot_human.dat.gz")
UNIPROT_FILE <- file.path(BIG_DIR, "uniprot_sprot_human.dat.gz")
OUT_RDS      <- file.path(CACHE_DIR, "uniprot-lookup.rds")

stopifnot("BIG_DIR non montato o assente" = dir.exists(BIG_DIR))
dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)
cli_alert_info(sprintf("Cache dir: %s", CACHE_DIR))
cli_alert_info(sprintf("Output RDS: %s", OUT_RDS))
cli_alert_info(sprintf("URL sorgente: %s", UNIPROT_URL))

# ─── download (idempotente: salta se già presente) ────────────────────────────
if (file.exists(UNIPROT_FILE)) {
  cli_alert_info(sprintf("File già presente (%.0f MB), salto download.",
                          file.size(UNIPROT_FILE) / 1e6))
} else {
  cli_alert_info(sprintf("Download %s ...", UNIPROT_URL))
  t_dl <- system.time({
    ret <- system2("wget", c("--no-verbose", "--show-progress",
                              "-O", UNIPROT_FILE, UNIPROT_URL))
    if (ret != 0L) stop(sprintf("wget fallito con codice %d", ret))
  })
  cli_alert_success(sprintf("Download completato in %.0f sec (%.0f MB)",
                              t_dl["elapsed"], file.size(UNIPROT_FILE) / 1e6))
}

# ─── SHA256 del file ──────────────────────────────────────────────────────────
cli_alert_info("Calcolo SHA256 ...")
sha256 <- digest::digest(UNIPROT_FILE, algo = "sha256", file = TRUE)
cli_alert_success(sprintf("SHA256: %s", sha256))

# ─── carica pacchetto per helper interni ─────────────────────────────────────
# .normalize_biological_mention, .hgnc_lookup_symbol, .chebi_lookup_id,
# .chebi_roles, .load_ontology_dicts, .PAMP_WHITELIST
cli_alert_info("Carico simulomicsr (devtools::load_all) ...")
devtools::load_all(quiet = TRUE)
cli_alert_success("Pacchetto caricato")

# Per la mappatura HGNC usiamo solo l'indice HGNC (evita di caricare ChEBI 16MB
# + Taxonomy 39MB che non servono al parse). Per il sanity PAMP servono anche
# ChEBI; carichiamo il full dict una volta sola.
cli_alert_info("Carico dizionari ontologia (ChEBI + HGNC + MeSH per sanity PAMP) ...")
env <- simulomicsr:::.load_ontology_dicts(refresh = TRUE)
cli_alert_success(sprintf("Dizionari caricati: HGNC %d geni",
                           env$hgnc$meta$n_genes))

# ─── lettura del flat-file .dat.gz ────────────────────────────────────────────
# Il file è in formato UniProtKB flat-file: entry separate da "//".
# Ogni riga ha un tag a 2 caratteri (AC, GN, DE, ...) seguito da 3 spazi.
# Usiamo readLines su connessione gzip per streaming efficiente in memoria.
cli_alert_info(sprintf("Lettura linee da %s (%.0f MB) ...",
                        basename(UNIPROT_FILE), file.size(UNIPROT_FILE)/1e6))
t_read <- system.time({
  con   <- gzfile(UNIPROT_FILE, open = "r", encoding = "UTF-8")
  lines <- readLines(con, warn = FALSE)
  close(con)
})
cli_alert_success(sprintf("Lette %d righe in %.0f sec",
                           length(lines), t_read["elapsed"]))

# Trova posizioni dei separatori "//" (una per entry)
sep_idx <- which(lines == "//")
n_raw   <- length(sep_idx)
cli_alert_info(sprintf("Entry totali nel file: %d", n_raw))

# Calcola start/end di ogni entry (esclude la riga "//")
starts <- c(1L, sep_idx[-length(sep_idx)] + 1L)
ends   <- sep_idx - 1L

# ─── helper per il parse dei campi UniProt ────────────────────────────────────

# Estrai accession primario dall'insieme di linee AC.
# Formato: "AC   P01574; A8K5D7; Q6FHF4;"
# Primary = primo token della prima riga AC.
.extract_uniprot_accession <- function(ac_lines) {
  if (length(ac_lines) == 0L) return(NA_character_)
  first_line <- trimws(sub("^AC   ", "", ac_lines[1L]))
  tokens     <- trimws(strsplit(first_line, "[;[:space:]]+")[[1L]])
  tokens     <- tokens[nzchar(tokens)]
  if (length(tokens) == 0L) return(NA_character_)
  tokens[1L]
}

# Estrai gene symbol(s) da linee GN.
# Formato: "GN   Name=IFNB1; Synonyms=IFN-B, IFNB;"
# Le evidenze inline {ECO:...} vengono rimosse prima dell'estrazione.
.extract_uniprot_gene_tokens <- function(gn_lines) {
  if (length(gn_lines) == 0L) return(character(0))
  gn_text  <- paste(trimws(sub("^GN   ", "", gn_lines)), collapse = " ")
  # Rimuovi tags evidenza {ECO:...} e simili
  gn_clean <- gsub("\\{[^}]*\\}", "", gn_text)
  # Name=...;
  m_name   <- regmatches(gn_clean, gregexpr("Name=[^;]+", gn_clean))[[1L]]
  names_v  <- trimws(sub("^Name=", "", m_name))
  # Synonyms=..., ...;  (lista comma-separata)
  m_syn    <- regmatches(gn_clean, gregexpr("Synonyms=[^;]+", gn_clean))[[1L]]
  syns_v   <- character(0)
  for (s in m_syn) {
    val    <- trimws(sub("^Synonyms=", "", s))
    parts  <- trimws(strsplit(val, ",")[[1L]])
    syns_v <- c(syns_v, parts[nzchar(parts)])
  }
  # ORFNames e OrderedLocusNames li ignoriamo (non sono gene symbol HGNC-risolvibili)
  unique(c(names_v, syns_v)[nzchar(c(names_v, syns_v))])
}

# Estrai nomi proteina da linee DE.
# Formato: "DE   RecName: Full=Interferon beta;"
#          "DE            Short=IFN-beta;"
#          "DE   AltName: Full=Fibroblast interferon;"
# Cattura Full=... e Short=... da tutte le linee DE (RecName + AltName).
.extract_uniprot_protein_names <- function(de_lines) {
  if (length(de_lines) == 0L) return(character(0))
  de_text  <- paste(trimws(sub("^DE   ", "", de_lines)), collapse = " ")
  # Rimuovi tags evidenza
  de_clean <- gsub("\\{[^}]*\\}", "", de_text)
  # Cerca Full=...;  e  Short=...;
  # Non catturiamo "Includes:" / "Contains:" / "Flags:" (non sono nomi principali)
  # Non catturiamo "SubName:" (solo TrEMBL unreviewed, assente in Swiss-Prot)
  m_all    <- regmatches(de_clean, gregexpr("(?:Full|Short)=[^;]+", de_clean))[[1L]]
  if (length(m_all) == 0L) return(character(0))
  nms      <- trimws(sub("^(?:Full|Short)=", "", m_all))
  unique(nms[nzchar(nms)])
}

# ─── loop principale: parse + mappatura HGNC ──────────────────────────────────
cli_alert_info("Parse entry UniProt + mappatura HGNC ...")
t_parse <- proc.time()

# Pre-alloco lista risultati (un elemento per entry → data.frame o NULL)
results_list  <- vector("list", n_raw)
n_mapped      <- 0L
n_no_hgnc     <- 0L
n_no_de       <- 0L
n_no_ac       <- 0L

for (i in seq_len(n_raw)) {
  el <- lines[starts[i]:ends[i]]
  if (length(el) == 0L) next

  # Prefissi a 2 caratteri per indicizzare efficientemente i campi
  pfx <- substr(el, 1L, 2L)

  # 1. Accession primario
  accession <- .extract_uniprot_accession(el[pfx == "AC"])
  if (is.na(accession)) {
    n_no_ac <- n_no_ac + 1L
    next
  }

  # 2. Gene tokens → primo hgnc_int valido via HGNC dict
  gene_tokens <- .extract_uniprot_gene_tokens(el[pfx == "GN"])
  hgnc_int    <- NA_integer_
  for (tok in gene_tokens) {
    hit <- simulomicsr:::.hgnc_lookup_symbol(tolower(tok), env)
    if (!is.null(hit)) {
      hgnc_int <- as.integer(hit$hgnc_int)
      break
    }
  }
  if (is.na(hgnc_int)) {
    n_no_hgnc <- n_no_hgnc + 1L
    next
  }

  # 3. Protein names → normalizza → scarta vuoti
  prot_names <- .extract_uniprot_protein_names(el[pfx == "DE"])
  if (length(prot_names) == 0L) {
    n_no_de <- n_no_de + 1L
    next
  }
  norms <- vapply(prot_names, simulomicsr:::.normalize_biological_mention,
                  character(1L))
  keep  <- nzchar(norms)
  if (!any(keep)) {
    n_no_de <- n_no_de + 1L
    next
  }

  n_mapped       <- n_mapped + 1L
  results_list[[i]] <- data.frame(
    name_norm = norms[keep],
    accession = rep(accession, sum(keep)),
    hgnc_int  = rep(hgnc_int, sum(keep)),
    stringsAsFactors = FALSE
  )

  # Progresso ogni 1000 entry
  if (i %% 1000L == 0L) {
    cli_alert_info(sprintf("  entry %d/%d | mappate=%d | no_hgnc=%d | no_de=%d",
                            i, n_raw, n_mapped, n_no_hgnc, n_no_de))
  }
}

dt_parse <- (proc.time() - t_parse)["elapsed"]
cli_alert_success(sprintf("Parse completato in %.0f sec: %d/%d entry mappate",
                           dt_parse, n_mapped, n_raw))
cli_alert_info(sprintf("  senza AC: %d | senza HGNC: %d | senza DE: %d",
                        n_no_ac, n_no_hgnc, n_no_de))

# Rilascia la memoria delle linee (non più necessarie)
rm(lines)
gc(verbose = FALSE)

# ─── costruisci data.frame finale ─────────────────────────────────────────────
cli_alert_info("Assemblaggio data.frame e deduplicazione per name_norm ...")
non_null <- Filter(Negate(is.null), results_list)
names_df_raw <- do.call(rbind, non_null)
rownames(names_df_raw) <- NULL

# Deduplica per name_norm (first-wins — l'ordinamento rispecchia l'ordine del file)
dup_mask <- duplicated(names_df_raw$name_norm)
names_df <- names_df_raw[!dup_mask, ]
rownames(names_df) <- NULL
cli_alert_success(sprintf("name_norm unici: %d (su %d pre-dedup; %d duplicati rimossi)",
                           nrow(names_df), nrow(names_df_raw),
                           sum(dup_mask)))
rm(names_df_raw, results_list, non_null)
gc(verbose = FALSE)

# ─── sanity PAMP_WHITELIST (Task 17 gate) ────────────────────────────────────
# Verifica che ogni CHEBI:<int> in .PAMP_WHITELIST esista nella nostra ChEBI dict
# e documenta i ruoli diretti. Ruoli target attesi (almeno uno dei seguenti):
# "immunostimulant", "adjuvant", "immunological adjuvant",
# "toll-like receptor agonist" o simili.
# I composti TLR agonist curati non sempre hanno un ruolo esplicito di questo tipo
# in ChEBI (la copertura ruoli ChEBI è incompleta); l'importante è che l'ID ESISTA.
cli_h2("Sanity PAMP_WHITELIST")
PAMP_ROLES_TARGET <- c(
  "immunostimulant", "adjuvant", "immunological adjuvant",
  "toll-like receptor agonist", "tlr agonist",
  "lipopolysaccharide", "antigen"
)
pamp_report <- list()
pamp_errors <- character(0)
pamp_warns  <- character(0)

for (nm in names(.PAMP_WHITELIST)) {
  cid      <- as.character(.PAMP_WHITELIST[[nm]])
  info     <- simulomicsr:::.chebi_lookup_id(cid, env)
  roles    <- simulomicsr:::.chebi_roles(cid, env)
  has_role_target <- any(tolower(roles) %in% PAMP_ROLES_TARGET) ||
                     any(grepl("immun|adjuv|toll|tlr|agonist|lipopoly",
                               tolower(roles)))
  found    <- !is.null(info)
  pri_name <- if (found) info$primary_name else NA_character_
  roles_3  <- paste(roles[seq_len(min(5L, length(roles)))], collapse = "; ")

  status <- if (!found) {
    msg <- sprintf("CHEBI:%s [%s] NOT FOUND in ChEBI dict", cid, nm)
    pamp_errors <- c(pamp_errors, msg)
    "ERROR"
  } else if (!has_role_target && length(roles) == 0L) {
    msg <- sprintf("CHEBI:%s [%s] trovato (%s) ma SENZA RUOLI in ChEBI dict (copertura incompleta, atteso)",
                   cid, nm, pri_name)
    pamp_warns <- c(pamp_warns, msg)
    "WARN_NO_ROLES"
  } else if (!has_role_target) {
    msg <- sprintf("CHEBI:%s [%s] trovato (%s) ma ruoli non includono target (ruoli: %s)",
                   cid, nm, pri_name, roles_3)
    pamp_warns <- c(pamp_warns, msg)
    "WARN_ROLE_MISMATCH"
  } else {
    "OK"
  }

  pamp_report[[nm]] <- list(
    key      = nm,
    chebi_id = .PAMP_WHITELIST[[nm]],
    found    = found,
    primary_name = pri_name,
    has_role_target = has_role_target,
    roles    = roles_3,
    status   = status
  )
  icon <- switch(status, "OK" = "v", "ERROR" = "x", "w")
  cli_alert_info(sprintf("  CHEBI:%s [%-15s] %s | %s | ruoli: %s",
                          cid, nm, icon, if(found) pri_name else "NOT FOUND",
                          if(nzchar(roles_3)) roles_3 else "(nessuno)"))
}

if (length(pamp_errors) > 0L) {
  cli_alert_danger(sprintf("PAMP_WHITELIST: %d ID non trovati in ChEBI → CORREGGERE:",
                            length(pamp_errors)))
  for (e in pamp_errors) cli_alert_danger(sprintf("  %s", e))
  stop("PAMP_WHITELIST contiene ID ChEBI non validi. Correggere prima del commit.")
} else {
  cli_alert_success(sprintf("PAMP_WHITELIST: tutti i %d ID presenti in ChEBI dict",
                              length(.PAMP_WHITELIST)))
}
if (length(pamp_warns) > 0L) {
  for (w in pamp_warns) cli_alert_warning(w)
  cli_alert_warning(sprintf(
    "%d WARN ruoli (ChEBI ha copertura ruoli incompleta — non bloccante)", length(pamp_warns)))
}

# ─── release date dall'header del file ───────────────────────────────────────
# Il file HTTP Last-Modified era: 10 Jun 2026 (da wget headers / curl -I).
# Usiamo la data di download come proxy della release UniProt.
release_date <- "2026-06-10"   # Last-Modified header verificato via curl -I

# ─── costruisci meta e output ─────────────────────────────────────────────────
meta <- list(
  source            = "uniprot_sprot_human",
  url               = UNIPROT_URL,
  release           = release_date,
  sha256            = sha256,
  built_at          = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  n                 = nrow(names_df),
  n_entries_total   = n_raw,
  n_entries_mapped  = n_mapped,
  n_entries_no_hgnc = n_no_hgnc,
  n_entries_no_de   = n_no_de,
  n_entries_no_ac   = n_no_ac
)
out <- list(names = names_df, meta = meta)

# ─── salva RDS ────────────────────────────────────────────────────────────────
cli_alert_info("Salvo uniprot-lookup.rds ...")
t_rds <- system.time(saveRDS(out, OUT_RDS))
rds_mb <- file.size(OUT_RDS) / 1e6
cli_alert_success(sprintf("Salvato %s (%.1f MB) in %.0f sec",
                           OUT_RDS, rds_mb, t_rds["elapsed"]))

# ─── provenienza JSON ─────────────────────────────────────────────────────────
prov <- list(
  url             = UNIPROT_URL,
  sha256          = sha256,
  release         = release_date,
  date            = format(Sys.Date(), "%Y-%m-%d"),
  n_names         = nrow(names_df),
  n_entries_total = n_raw,
  n_entries_mapped = n_mapped,
  out_rds         = OUT_RDS,
  rds_mb          = round(rds_mb, 1L),
  pamp_whitelist_sanity = pamp_report,
  pamp_errors     = pamp_errors,
  pamp_warns      = pamp_warns
)
dir.create(dirname(PROV_JSON), showWarnings = FALSE, recursive = TRUE)
write(toJSON(prov, pretty = TRUE, auto_unbox = TRUE), PROV_JSON)
cli_alert_success(sprintf("Provenienza scritta in %s", PROV_JSON))

# ─── summary ──────────────────────────────────────────────────────────────────
t_tot <- (proc.time() - t0_totale)["elapsed"]
cli_h2("Summary")
cli_alert_success(sprintf("URL usato:              %s", UNIPROT_URL))
cli_alert_success(sprintf("Entry totali:           %d", n_raw))
cli_alert_success(sprintf("Entry mappate HGNC:     %d (%.1f%%)",
                           n_mapped, 100 * n_mapped / max(n_raw, 1L)))
cli_alert_success(sprintf("Entry senza HGNC:       %d (senza GN o gene non in HGNC)",
                           n_no_hgnc))
cli_alert_success(sprintf("Entry senza DE:         %d", n_no_de))
cli_alert_success(sprintf("name_norm unici:        %d", nrow(names_df)))
cli_alert_success(sprintf("RDS:                    %s (%.1f MB)", OUT_RDS, rds_mb))
cli_alert_success(sprintf("Tempo totale:           %.0f sec", t_tot))
cli_alert_success(sprintf("PAMP sanity:            %d OK / %d WARN / %d ERROR",
                           sum(sapply(pamp_report, function(x) x$status == "OK")),
                           length(pamp_warns),
                           length(pamp_errors)))
cli_rule()
cli_alert_info("Verifica rapida (eseguire separatamente dopo la build):")
cli_alert_info(paste0(
  "Rscript -e 'devtools::load_all(quiet=TRUE);",
  " e<-simulomicsr:::.load_ontology_dicts(refresh=TRUE);",
  " cat(\"has_uniprot:\", e$has_uniprot, \"\\n\");",
  " print(simulomicsr:::.uniprot_lookup_name(\"interferon beta\", e));",
  " print(simulomicsr:::.uniprot_lookup_name(\"interleukin-6\", e))'"
))
