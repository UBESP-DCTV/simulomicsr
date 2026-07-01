# analysis/p5-audit-taxonomy-build-dict.R
# Build dizionario NCBI Taxonomy: nomi normalizzati → taxid + catena parent/rank.
# Usato da R/ontology-lookup.R: .build_taxonomy_index / .taxonomy_lookup_name /
#   .taxonomy_rollup_to_species per risoluzione nomi di patogeni nei cluster S3.
#
# Sorgente: new_taxdump.tar.gz  (ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/)
#
# Struttura .rds attesa da .build_taxonomy_index (vedere R/ontology-lookup.R:543):
#   list(
#     names = data.frame(name_norm chr, taxid int, name_class chr),
#     nodes = data.frame(taxid int, parent_taxid int, rank chr),
#     meta  = list(source, release, sha256, built_at, n_names, n_nodes)
#   )
#
# Strategia filtro nomi (NB: NON filtriamo per rank):
#   - names: teniamo le 5 name_class rilevanti su TUTTI i taxid.
#     Motivo: .taxonomy_rollup_to_species risale l'albero via by_taxid e ha
#     bisogno dell'intera catena (antenati a qualunque livello).
#   - nodes: teniamo TUTTI i nodi (catena parent completa garantita).
#   Dimensione prevista .rds: ~100-200 MB gzip (accettabile su NVMe, 178G liberi).
#
# NB paper-grade (Minor noto): scientific_name in by_taxid è il name_norm
#   (forma canonica normalizzata, non il raw) perché .build_taxonomy_index usa
#   nm$name_norm[sci_idx]; comportamento by-design per coerenza lookup key.
#
# Disco download + estrazione (4T, evita NVMe):
#   /mnt/wwn-0x5000039d58caca35/simulomicsr-biolex-build/
# Cache finale (.rds):
#   ~/.cache/R/simulomicsr/taxonomy/taxonomy-lookup.rds
# Provenienza:
#   analysis/p4-output/taxonomy-source-provenance.json

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(data.table)
  library(cli)
  library(digest)
  library(jsonlite)
})

cli_h1("NCBI Taxonomy lookup dictionary build")
t0_totale <- proc.time()

# ─── percorsi ─────────────────────────────────────────────────────────────────
BIG_DIR      <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-biolex-build"
CACHE_DIR    <- file.path(tools::R_user_dir("simulomicsr", "cache"), "taxonomy")
PROV_JSON    <- "analysis/p4-output/taxonomy-source-provenance.json"
TAXDUMP_URL  <- "https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/new_taxdump/new_taxdump.tar.gz"
TAXDUMP_FILE <- file.path(BIG_DIR, "new_taxdump.tar.gz")
NAMES_DMP    <- file.path(BIG_DIR, "names.dmp")
NODES_DMP    <- file.path(BIG_DIR, "nodes.dmp")
OUT_RDS      <- file.path(CACHE_DIR, "taxonomy-lookup.rds")

stopifnot("BIG_DIR non montato o assente" = dir.exists(BIG_DIR))
dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)
cli_alert_info(sprintf("Cache dir: %s", CACHE_DIR))
cli_alert_info(sprintf("Output RDS: %s", OUT_RDS))

# ─── download (idempotente: salta se già presente) ────────────────────────────
if (file.exists(TAXDUMP_FILE)) {
  cli_alert_info(sprintf("Tarball già presente (%.0f MB), salto download.",
                          file.size(TAXDUMP_FILE) / 1e6))
} else {
  cli_alert_info(sprintf("Download %s ...", TAXDUMP_URL))
  t_dl <- system.time({
    ret <- system2("wget", c("--no-verbose", "--show-progress",
                             "-O", TAXDUMP_FILE, TAXDUMP_URL))
    if (ret != 0L) stop(sprintf("wget fallito con codice %d", ret))
  })
  cli_alert_success(sprintf("Download completato in %.0f sec (%.0f MB)",
                             t_dl["elapsed"], file.size(TAXDUMP_FILE) / 1e6))
}

# ─── SHA256 del tarball ───────────────────────────────────────────────────────
cli_alert_info("Calcolo SHA256 del tarball ...")
sha256 <- digest::digest(TAXDUMP_FILE, algo = "sha256", file = TRUE)
cli_alert_success(sprintf("SHA256: %s", sha256))

# ─── estrazione (idempotente) ─────────────────────────────────────────────────
if (file.exists(NAMES_DMP) && file.exists(NODES_DMP)) {
  cli_alert_info("names.dmp e nodes.dmp già estratti, salto untar.")
} else {
  cli_alert_info("Estrazione names.dmp + nodes.dmp ...")
  t_tar <- system.time(
    untar(TAXDUMP_FILE, files = c("names.dmp", "nodes.dmp"), exdir = BIG_DIR)
  )
  stopifnot(file.exists(NAMES_DMP), file.exists(NODES_DMP))
  cli_alert_success(sprintf("Estratti in %.0f sec", t_tar["elapsed"]))
}
cli_alert_info(sprintf("names.dmp: %.0f MB", file.size(NAMES_DMP) / 1e6))
cli_alert_info(sprintf("nodes.dmp: %.0f MB", file.size(NODES_DMP) / 1e6))

# ─── carica il pacchetto per .normalize_biological_mention ────────────────────
# Serve per garantire coerenza con la funzione canonica del pacchetto.
cli_alert_info("Carico simulomicsr (per .normalize_biological_mention) ...")
devtools::load_all(quiet = TRUE)
cli_alert_success("Pacchetto caricato")

# ─── parse names.dmp ──────────────────────────────────────────────────────────
# Formato linea: taxid\t|\tname_txt\t|\tunique_name\t|\tname_class\t|\n
# Con sep="\t": V1=taxid, V2="|", V3=name_txt, V4="|", V5=unique_name,
#               V6="|", V7=name_class, V8="|" (trailing prima di \n)
# → selezioniamo colonne 1, 3, 7 (taxid, name_txt, name_class).
NAME_CLASSES <- c("scientific name", "synonym", "equivalent name",
                  "genbank common name", "common name")

cli_alert_info(sprintf("Parse names.dmp (%.0f MB) ...", file.size(NAMES_DMP) / 1e6))
t_names <- system.time({
  nm_raw <- fread(
    NAMES_DMP,
    sep        = "\t",
    header     = FALSE,
    quote      = "",
    select     = c(1L, 3L, 7L),
    col.names  = c("taxid", "name_txt", "name_class"),
    fill       = TRUE,
    encoding   = "UTF-8",
    showProgress = TRUE
  )
  n_totale <- nrow(nm_raw)
  cli_alert_info(sprintf("  righe totali: %d", n_totale))

  # Filtro name_class rilevanti
  nm_raw <- nm_raw[name_class %in% NAME_CLASSES]
  cli_alert_info(sprintf("  righe dopo filtro name_class: %d", nrow(nm_raw)))

  # Normalizzazione via funzione canonica del pacchetto
  # (vapply garantisce coerenza con i lookup a runtime in stage3/stage4)
  cli_alert_info("  Normalizzazione nomi (vapply, può richiedere 1-2 min) ...")
  t_norm <- proc.time()
  nm_raw[, name_norm := vapply(name_txt,
                                simulomicsr:::.normalize_biological_mention,
                                character(1L))]
  cli_alert_info(sprintf("  Normalizzazione completata in %.0f sec",
                         (proc.time() - t_norm)["elapsed"]))

  # Scarta nomi con name_norm vuoto (non accadrebbe su NCBI curato, ma defensivo)
  nm_raw <- nm_raw[nzchar(name_norm)]
  cli_alert_info(sprintf("  righe dopo filtro name_norm vuoto: %d", nrow(nm_raw)))
})
cli_alert_success(sprintf("names.dmp parsato in %.0f sec (%d righe finali su %d totali)",
                           t_names["elapsed"], nrow(nm_raw), n_totale))

# ─── parse nodes.dmp ──────────────────────────────────────────────────────────
# Formato: taxid\t|\tparent_taxid\t|\trank\t|\t<molti altri campi>
# Con sep="\t": V1=taxid, V2="|", V3=parent_taxid, V4="|", V5=rank
# → selezioniamo colonne 1, 3, 5 (taxid, parent_taxid, rank).
cli_alert_info(sprintf("Parse nodes.dmp (%.0f MB) ...", file.size(NODES_DMP) / 1e6))
t_nodes <- system.time({
  nd_raw <- fread(
    NODES_DMP,
    sep        = "\t",
    header     = FALSE,
    quote      = "",
    select     = c(1L, 3L, 5L),
    col.names  = c("taxid", "parent_taxid", "rank"),
    fill       = TRUE,
    encoding   = "UTF-8",
    showProgress = TRUE
  )
  # Converti in integer (fread li legge come double se molto grandi)
  nd_raw[, taxid        := as.integer(taxid)]
  nd_raw[, parent_taxid := as.integer(parent_taxid)]
})
cli_alert_success(sprintf("nodes.dmp parsato in %.0f sec (%d nodi totali)",
                           t_nodes["elapsed"], nrow(nd_raw)))

# Sanity check: ogni taxid in names deve avere un nodo in nodes
taxid_names <- unique(nm_raw$taxid)
taxid_nodes <- unique(nd_raw$taxid)
n_orfani    <- sum(!taxid_names %in% taxid_nodes)
cli_alert_info(sprintf("Taxid orfani (in names, non in nodes): %d (atteso 0 o pochi)",
                        n_orfani))
if (n_orfani > 1000L) {
  warning(sprintf("Numero insolito di taxid orfani: %d. Verificare parsing.", n_orfani))
}

# ─── costruisci output ────────────────────────────────────────────────────────
# Converti in data.frame base (richiesto da .build_taxonomy_index che usa $[i])
names_df <- as.data.frame(nm_raw[, .(name_norm, taxid, name_class)])
nodes_df <- as.data.frame(nd_raw[, .(taxid, parent_taxid, rank)])

meta <- list(
  source   = "ncbi-new_taxdump",
  release  = format(Sys.Date(), "%Y-%m-%d"),
  sha256   = sha256,
  built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  n_names  = nrow(names_df),
  n_nodes  = nrow(nodes_df)
)

out <- list(names = names_df, nodes = nodes_df, meta = meta)

# ─── salva .rds ───────────────────────────────────────────────────────────────
cli_alert_info("Salvo taxonomy-lookup.rds (compressione gzip) ...")
t_rds <- system.time(saveRDS(out, OUT_RDS))
rds_mb <- file.size(OUT_RDS) / 1e6
cli_alert_success(sprintf("Salvato %s (%.1f MB) in %.0f sec",
                           OUT_RDS, rds_mb, t_rds["elapsed"]))

# ─── provenienza JSON ─────────────────────────────────────────────────────────
prov <- list(
  url              = TAXDUMP_URL,
  sha256           = sha256,
  date             = format(Sys.Date(), "%Y-%m-%d"),
  n_names          = nrow(names_df),
  n_nodes          = nrow(nodes_df),
  out_rds          = OUT_RDS,
  rds_mb           = round(rds_mb, 1),
  name_classes_kept = NAME_CLASSES
)
dir.create(dirname(PROV_JSON), showWarnings = FALSE, recursive = TRUE)
write(toJSON(prov, pretty = TRUE, auto_unbox = TRUE), PROV_JSON)
cli_alert_success(sprintf("Provenienza scritta in %s", PROV_JSON))

# ─── summary ──────────────────────────────────────────────────────────────────
t_tot <- proc.time() - t0_totale
cli_h2("Summary")
cli_alert_success(sprintf("Nomi totali (5 classi): %d", nrow(names_df)))
cli_alert_success(sprintf("Nodi totali:           %d", nrow(nodes_df)))
cli_alert_success(sprintf("RDS:                   %s (%.1f MB)", OUT_RDS, rds_mb))
cli_alert_success(sprintf("Tempo totale:          %.0f sec", t_tot["elapsed"]))
cli_rule()
cli_alert_info("Verifica rapida:")
cli_alert_info("Rscript -e 'devtools::load_all(q=TRUE); e<-simulomicsr:::.load_ontology_dicts(refresh=TRUE); cat(\"has_taxonomy:\", e$has_taxonomy, \"\\n\"); print(simulomicsr:::.taxonomy_lookup_name(\"SARS-CoV-2\", e))'")
