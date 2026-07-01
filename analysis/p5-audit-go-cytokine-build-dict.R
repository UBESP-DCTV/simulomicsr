# analysis/p5-audit-go-cytokine-build-dict.R
# Build whitelist citochine umane da Gene Ontology.
# Sorgenti:
#   - go-basic.obo  (https://purl.obolibrary.org/obo/go/go-basic.obo)
#   - goa_human.gaf.gz (https://ftp.ebi.ac.uk/pub/databases/GO/goa/HUMAN/goa_human.gaf.gz)
#
# Strategia:
#   1. Scarica go-basic.obo: raccogli il set di termini GO = GO:0005125 (cytokine activity)
#      + tutti i suoi discendenti via relazioni is_a (traversal BFS della gerarchia).
#   2. Scarica goa_human.gaf.gz: tieni i gene symbol annotati ad almeno un termine del set.
#   3. Mappa symbol -> hgnc_int via .hgnc_lookup_symbol.
#   4. Salva vettore intermedio go_cytokine_hgnc_int consumato dal build ImmPort (Task 16).
#
# Nota precision-first: incluso solo GO:0005125 + discendenti (no GO:0005126/receptor binding).
#   Ragione: il brief richiede lista citochine stretta; GO:0005126 porta a ligandi non-citochina.
#
# Disco download: /mnt/wwn-0x5000039d58caca35/simulomicsr-biolex-build/
# Output intermedio: stessa BIG dir (go-cytokine-hgnc.rds)
# Provenienza: analysis/p4-output/go-cytokine-source-provenance.json

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(cli)
  library(digest)
  library(jsonlite)
})

cli_h1("GO cytokine-activity whitelist build (Task 15)")
t0_totale <- proc.time()

# ─── percorsi ─────────────────────────────────────────────────────────────────
BIG_DIR    <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-biolex-build"
OBO_URL    <- "https://purl.obolibrary.org/obo/go/go-basic.obo"
GAF_URL    <- "https://ftp.ebi.ac.uk/pub/databases/GO/goa/HUMAN/goa_human.gaf.gz"
OBO_FILE   <- file.path(BIG_DIR, "go-basic.obo")
GAF_FILE   <- file.path(BIG_DIR, "goa_human.gaf.gz")
OUT_RDS    <- file.path(BIG_DIR, "go-cytokine-hgnc.rds")
PROV_JSON  <- "analysis/p4-output/go-cytokine-source-provenance.json"

# Termine radice per cytokine activity
ROOT_TERM  <- "GO:0005125"

stopifnot("BIG_DIR non montato o assente" = dir.exists(BIG_DIR))
dir.create(dirname(PROV_JSON), showWarnings = FALSE, recursive = TRUE)
cli_alert_info(sprintf("BIG_DIR: %s", BIG_DIR))
cli_alert_info(sprintf("Root GO term: %s (cytokine activity)", ROOT_TERM))

# ─── download go-basic.obo (idempotente) ─────────────────────────────────────
if (file.exists(OBO_FILE)) {
  cli_alert_info(sprintf("go-basic.obo gia' presente (%.1f MB), salto download.",
                          file.size(OBO_FILE) / 1e6))
} else {
  cli_alert_info(sprintf("Download go-basic.obo da %s ...", OBO_URL))
  t_dl <- system.time({
    ret <- system2("wget", c("--no-verbose", "--show-progress",
                             "-O", OBO_FILE, OBO_URL))
    if (ret != 0L) stop(sprintf("wget go-basic.obo fallito con codice %d", ret))
  })
  cli_alert_success(sprintf("Download go-basic.obo in %.0f sec (%.1f MB)",
                             t_dl["elapsed"], file.size(OBO_FILE) / 1e6))
}

# ─── download goa_human.gaf.gz (idempotente) ─────────────────────────────────
if (file.exists(GAF_FILE)) {
  cli_alert_info(sprintf("goa_human.gaf.gz gia' presente (%.1f MB), salto download.",
                          file.size(GAF_FILE) / 1e6))
} else {
  cli_alert_info(sprintf("Download goa_human.gaf.gz da %s ...", GAF_URL))
  t_dl2 <- system.time({
    ret <- system2("wget", c("--no-verbose", "--show-progress",
                              "-O", GAF_FILE, GAF_URL))
    if (ret != 0L) stop(sprintf("wget goa_human.gaf.gz fallito con codice %d", ret))
  })
  cli_alert_success(sprintf("Download goa_human.gaf.gz in %.0f sec (%.1f MB)",
                             t_dl2["elapsed"], file.size(GAF_FILE) / 1e6))
}

# ─── SHA256 dei file scaricati ────────────────────────────────────────────────
cli_alert_info("Calcolo SHA256 (obo + gaf) ...")
sha256_obo <- digest::digest(OBO_FILE, algo = "sha256", file = TRUE)
sha256_gaf <- digest::digest(GAF_FILE, algo = "sha256", file = TRUE)
cli_alert_success(sprintf("SHA256 obo: %s", sha256_obo))
cli_alert_success(sprintf("SHA256 gaf: %s", sha256_gaf))

# ─── parse go-basic.obo: costruisci set termini GO discendenti di ROOT_TERM ───
# Il formato OBO 1.4 ha stanze [Term] con campi id:, is_a: <GO:NNNNNNN> ! <label>
# Strategia: costruisci la mappa is_a child->parent (children_of[parent] = c(children)),
# poi BFS a partire da ROOT_TERM per raccogliere tutti i discendenti.
cli_alert_info(sprintf("Parse go-basic.obo (%.1f MB) ...", file.size(OBO_FILE) / 1e6))
t_obo <- system.time({
  obo_lines <- readLines(OBO_FILE, warn = FALSE)
  n_lines   <- length(obo_lines)
  cli_alert_info(sprintf("  righe obo: %d", n_lines))

  # Stato parser: accumula id corrente e relazioni is_a
  # children_list[[parent_id]] = vector of child_id (inverte la direzione is_a)
  all_ids      <- character(0)  # tutti i GO ID trovati
  children_map <- list()        # parent -> c(child, child, ...)

  cur_id      <- NA_character_
  in_term     <- FALSE
  is_obsolete <- FALSE

  for (ln in obo_lines) {
    if (ln == "[Term]") {
      in_term     <- TRUE
      cur_id      <- NA_character_
      is_obsolete <- FALSE
      next
    }
    if (startsWith(ln, "[") && ln != "[Term]") {
      # Fine stanza [Term] (es. [Typedef])
      in_term     <- FALSE
      cur_id      <- NA_character_
      is_obsolete <- FALSE
      next
    }
    if (!in_term) next

    if (startsWith(ln, "id: ")) {
      cur_id <- sub("^id: ", "", ln)
      all_ids <- c(all_ids, cur_id)
      next
    }
    if (ln == "is_obsolete: true") {
      is_obsolete <- TRUE
      next
    }
    # is_a: GO:XXXXXXX ! label  (o con relazioni extra come regulates: ecc.)
    if (startsWith(ln, "is_a: ") && !is_obsolete && !is.na(cur_id)) {
      # estrai il GO ID padre (prima parola dopo "is_a: ")
      parent_id <- sub("^is_a: ([^ !]+).*", "\\1", ln)
      if (!is.null(children_map[[parent_id]])) {
        children_map[[parent_id]] <- c(children_map[[parent_id]], cur_id)
      } else {
        children_map[[parent_id]] <- cur_id
      }
      next
    }
  }

  n_terms_total <- length(unique(all_ids))
  cli_alert_info(sprintf("  termini GO totali nel file: %d", n_terms_total))
  cli_alert_info(sprintf("  relazioni is_a: %d", sum(lengths(children_map))))

  # BFS da ROOT_TERM per raccogliere tutti i discendenti (incluso ROOT_TERM stesso)
  go_set      <- character(0)
  queue       <- ROOT_TERM
  visited     <- new.env(hash = TRUE, size = 1000L)
  assign(ROOT_TERM, TRUE, envir = visited)

  while (length(queue) > 0L) {
    node  <- queue[1L]
    queue <- queue[-1L]
    go_set <- c(go_set, node)

    children <- children_map[[node]]
    if (!is.null(children)) {
      for (ch in children) {
        if (!exists(ch, envir = visited, inherits = FALSE)) {
          assign(ch, TRUE, envir = visited)
          queue <- c(queue, ch)
        }
      }
    }
  }
  go_set <- sort(unique(go_set))
  n_go_set <- length(go_set)
  cli_alert_success(sprintf("  termini GO in set (root + discendenti): %d", n_go_set))
})
cli_alert_success(sprintf("OBO parsato in %.0f sec", t_obo["elapsed"]))

# Sanity check: ROOT_TERM deve essere nel set
stopifnot("ROOT_TERM assente dal set GO!" = ROOT_TERM %in% go_set)

# ─── parse goa_human.gaf.gz ────────────────────────────────────────────────────
# Formato GAF 2.x (tab-separated), righe commento iniziano con '!'
# Colonna 3 = DB Object Symbol (gene symbol)
# Colonna 5 = GO ID (es. GO:0005125)
# Colonna 4 = Qualifier (se contiene "NOT" → escludiamo)
cli_alert_info(sprintf("Parse goa_human.gaf.gz (%.1f MB compressi) ...", file.size(GAF_FILE) / 1e6))
t_gaf <- system.time({
  con_gz  <- gzfile(GAF_FILE, "r")
  on.exit(try(close(con_gz), silent = TRUE), add = TRUE)

  symbols_set <- new.env(hash = TRUE, size = 5000L)
  n_lines_gaf <- 0L
  n_annot     <- 0L
  n_matched   <- 0L

  repeat {
    batch <- readLines(con_gz, n = 50000L, warn = FALSE)
    if (length(batch) == 0L) break
    n_lines_gaf <- n_lines_gaf + length(batch)

    # Filtra commenti (righe che iniziano con '!')
    batch <- batch[!startsWith(batch, "!")]
    if (length(batch) == 0L) next

    # Split su tab: prende colonne 3 (symbol), 4 (qualifier), 5 (go_id)
    # per evitare strsplit su tutte le 17 colonne, usiamo regexpr
    # Colonna 3 = terzo campo, 4 = quarto, 5 = quinto
    # Usiamo tstrsplit-like con strsplit ma solo fino a col 5
    parts <- strsplit(batch, "\t", fixed = TRUE)
    n_annot <- n_annot + length(parts)

    for (p in parts) {
      if (length(p) < 5L) next
      qualifier <- p[4L]
      go_id     <- p[5L]
      symbol    <- p[3L]

      # Escludi annotazioni NOT (segnalano assenza di funzione)
      if (nzchar(qualifier) && grepl("NOT", qualifier, fixed = TRUE)) next

      # Tieni solo annotazioni nel set GO
      if (!exists(go_id, envir = visited, inherits = FALSE)) next

      n_matched <- n_matched + 1L
      sym_key <- tolower(trimws(symbol))
      if (nzchar(sym_key)) assign(sym_key, TRUE, envir = symbols_set)
    }
  }
  close(con_gz)
  on.exit(NULL)  # rimuovi il finalizer dopo close esplicito

  symbols_found <- ls(envir = symbols_set)
  cli_alert_info(sprintf("  righe GAF totali (inc. commenti): ~%d", n_lines_gaf))
  cli_alert_info(sprintf("  annotazioni parse: %d", n_annot))
  cli_alert_info(sprintf("  annotazioni nel set GO (non-NOT): %d", n_matched))
  cli_alert_info(sprintf("  gene symbol unici trovati: %d", length(symbols_found)))
})
cli_alert_success(sprintf("GAF parsato in %.0f sec", t_gaf["elapsed"]))

# ─── carica il pacchetto per .hgnc_lookup_symbol ─────────────────────────────
cli_alert_info("Carico simulomicsr (per .hgnc_lookup_symbol) ...")
devtools::load_all(quiet = TRUE)
env <- simulomicsr:::.load_ontology_dicts()
cli_alert_success(sprintf("Dizionario HGNC caricato (%d geni)", env$hgnc$meta$n_genes))

# ─── mappa symbol -> hgnc_int ─────────────────────────────────────────────────
cli_alert_info("Mappa symbol -> hgnc_int ...")
t_map <- system.time({
  hgnc_int_vec <- integer(0)
  n_risolti    <- 0L
  n_non_risolti <- 0L

  for (sym in symbols_found) {
    hit <- simulomicsr:::.hgnc_lookup_symbol(sym, env)
    if (!is.null(hit) && !is.na(hit$hgnc_int)) {
      hgnc_int_vec <- c(hgnc_int_vec, as.integer(hit$hgnc_int))
      n_risolti <- n_risolti + 1L
    } else {
      n_non_risolti <- n_non_risolti + 1L
    }
  }
  go_cytokine_hgnc_int <- sort(unique(hgnc_int_vec))
})
cli_alert_success(sprintf("  symbol risolti in HGNC: %d", n_risolti))
cli_alert_info(sprintf("  symbol non risolti (scartati): %d", n_non_risolti))
cli_alert_success(sprintf("  hgnc_int unici nella whitelist: %d", length(go_cytokine_hgnc_int)))
cli_alert_success(sprintf("Mapping completato in %.0f sec", t_map["elapsed"]))

# ─── verifica geni noti ───────────────────────────────────────────────────────
# Attesi: IFNB1=5434, IL6=6018, TNF=11892
cli_h2("Verifica geni noti")
canary <- c(IFNB1 = 5434L, IL6 = 6018L, TNF = 11892L)
for (nm in names(canary)) {
  present <- canary[[nm]] %in% go_cytokine_hgnc_int
  if (present) {
    cli_alert_success(sprintf("  %s (hgnc_int=%d): PRESENTE", nm, canary[[nm]]))
  } else {
    cli_alert_warning(sprintf("  %s (hgnc_int=%d): ASSENTE - verifica annotazioni GO!", nm, canary[[nm]]))
    # Diagnosi: cerca il symbol direttamente nel GAF set
    sym_lower <- tolower(nm)
    if (exists(sym_lower, envir = symbols_set, inherits = FALSE)) {
      cli_alert_info(sprintf("    -> symbol '%s' TROVATO nel GAF ma non risolto in HGNC", nm))
    } else {
      cli_alert_info(sprintf("    -> symbol '%s' NON trovato nel GAF per GO:%s", nm, ROOT_TERM))
    }
  }
}

# ─── salva output intermedio .rds ────────────────────────────────────────────
meta_out <- list(
  source          = sprintf("GO:%s (cytokine activity) + discendenti is_a via go-basic.obo + goa_human.gaf.gz",
                             ROOT_TERM),
  root_term       = ROOT_TERM,
  n_go_terms      = n_go_set,
  n_symbols_raw   = length(symbols_found),
  n_hgnc_resolved = n_risolti,
  n_hgnc_dropped  = n_non_risolti,
  n               = length(go_cytokine_hgnc_int),
  release         = format(Sys.Date(), "%Y-%m-%d"),
  sha256_obo      = sha256_obo,
  sha256_gaf      = sha256_gaf,
  built_at        = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)

out <- list(go_cytokine_hgnc_int = go_cytokine_hgnc_int, meta = meta_out)

cli_alert_info(sprintf("Salvo go-cytokine-hgnc.rds in %s ...", BIG_DIR))
t_rds <- system.time(saveRDS(out, OUT_RDS))
cli_alert_success(sprintf("Salvato %s (%.1f MB) in %.0f sec",
                           OUT_RDS, file.size(OUT_RDS) / 1e6, t_rds["elapsed"]))

# ─── provenienza JSON ─────────────────────────────────────────────────────────
prov <- list(
  obo_url          = OBO_URL,
  gaf_url          = GAF_URL,
  obo_file         = OBO_FILE,
  gaf_file         = GAF_FILE,
  sha256_obo       = sha256_obo,
  sha256_gaf       = sha256_gaf,
  date             = format(Sys.Date(), "%Y-%m-%d"),
  root_go_term     = ROOT_TERM,
  n_go_terms       = n_go_set,
  n_symbols_raw    = length(symbols_found),
  n_hgnc_resolved  = n_risolti,
  n_hgnc_dropped   = n_non_risolti,
  n_cytokine_genes = length(go_cytokine_hgnc_int),
  out_rds          = OUT_RDS,
  rds_mb           = round(file.size(OUT_RDS) / 1e6, 2)
)
write(jsonlite::toJSON(prov, pretty = TRUE, auto_unbox = TRUE), PROV_JSON)
cli_alert_success(sprintf("Provenienza scritta in %s", PROV_JSON))

# ─── summary finale ───────────────────────────────────────────────────────────
t_tot <- proc.time() - t0_totale
cli_h2("Summary Task 15")
cli_alert_success(sprintf("Termini GO in set (GO:0005125 + discendenti): %d", n_go_set))
cli_alert_success(sprintf("Gene symbol GAF in set:                       %d", length(symbols_found)))
cli_alert_success(sprintf("Gene symbol risolti in HGNC:                  %d", n_risolti))
cli_alert_success(sprintf("hgnc_int UNICI nella whitelist:               %d", length(go_cytokine_hgnc_int)))
cli_alert_success(sprintf("Output RDS:   %s", OUT_RDS))
cli_alert_success(sprintf("Provenienza:  %s", PROV_JSON))
cli_alert_success(sprintf("Tempo totale: %.0f sec (%.1f min)", t_tot["elapsed"], t_tot["elapsed"] / 60))
cli_rule()
cli_alert_info("Prossimo: Task 16 (build ImmPort) legge go_cytokine_hgnc_int da questo .rds.")
