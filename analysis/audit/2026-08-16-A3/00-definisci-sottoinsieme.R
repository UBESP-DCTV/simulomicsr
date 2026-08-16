#!/usr/bin/env Rscript
# =============================================================================
# A3 — DEFINIZIONE DEL SOTTOINSIEME, congelata PRIMA del run
#
# Il sottoinsieme A3 = tutti gli studi (GSE) che compaiono in almeno un cluster
# `cgroup` dello Stadio 3 con k >= 2 studi distinti, UNITI agli studi
# effettivamente poolati nel deliverable v16b.
#
# PERCHE' QUEL CONFINE: perche' un gruppo diventi una meta-analisi servono 3
# studi (`k_eff_min = 3`). Solo un gruppo gia' a k>=2 puo' realisticamente
# entrare o uscire cambiando UN membro. Un gruppo a k=1 dovrebbe guadagnarne due
# insieme: evento di secondo ordine, ed e' il punto cieco DICHIARATO di A3.
#
# PERCHE' L'UNIONE COI POOLATI: 13 studi poolati NON compaiono fra gli assegnati
# ai cluster candidati, perche' `.reassign_absorbed_records()` ha spostato i loro
# record sui cluster vincenti delle fusioni. Definire il sottoinsieme dalle sole
# assegnazioni li perderebbe IN SILENZIO. Caso di accettazione negativo sotto.
#
# Uso:
#   Rscript analysis/audit/2026-08-16-A3/00-definisci-sottoinsieme.R
# =============================================================================

suppressMessages({
  library(arrow)
  library(dplyr)
})

S3_DIR <- Sys.getenv(
  "STAGE3_DIR",
  "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159")
POOL_DIR <- Sys.getenv(
  "POOL_DIR",
  "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d")
S1_INPUT <- Sys.getenv(
  "S1_INPUT", "analysis/input/archs4-human-stage1-input-v2.jsonl")
OUT_DIR  <- Sys.getenv("OUT_DIR", "analysis/audit/2026-08-16-A3")

stopifnot(dir.exists(S3_DIR), dir.exists(POOL_DIR), file.exists(S1_INPUT))
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("== A3: definizione del sottoinsieme ==\n")
cat("Stadio 3 :", S3_DIR, "\n")
cat("Stadio 4 :", POOL_DIR, "\n\n")

# --- 1. studi POOLATI (l'oggetto vero: non il censito) -----------------------
deliv <- readRDS(file.path(POOL_DIR, "deliverable-annotato.rds"))
np    <- readRDS(file.path(POOL_DIR, "non_processable.rds"))

gse_poolati <- open_dataset(file.path(POOL_DIR, "per_study_de.parquet")) |>
  filter(cluster_id %in% unique(deliv$cluster_id)) |>
  distinct(study_id) |>
  collect() |>
  pull(study_id) |>
  as.character() |>
  unique()

cat(sprintf("deliverable      : %d righe\n", nrow(deliv)))
cat(sprintf("non processabili : %d\n", nrow(np)))
cat(sprintf("studi poolati    : %d\n", length(gse_poolati)))

# --- 2. studi nei cluster cgroup con k >= 2 ----------------------------------
asg <- open_dataset(file.path(S3_DIR, "assignments.parquet")) |>
  filter(mode == "cgroup") |>
  select(record_id, cluster_id) |>
  collect()
# il primo segmento del record_id e' la series (GSE...__GSE...__grp_a_vs_grp_b)
asg$gse <- sub("__.*$", "", asg$record_id)

k_per_cluster <- asg |>
  distinct(cluster_id, gse) |>
  count(cluster_id, name = "k")

cluster_k2 <- k_per_cluster$cluster_id[k_per_cluster$k >= 2L]
gse_k2 <- unique(asg$gse[asg$cluster_id %in% cluster_k2])

cat(sprintf("cluster cgroup   : %d (k>=2: %d, k>=3: %d)\n",
            length(unique(asg$cluster_id)), length(cluster_k2),
            sum(k_per_cluster$k >= 3L)))
cat(sprintf("studi in k>=2    : %d\n", length(gse_k2)))

# --- 3. il sottoinsieme A3 = unione ------------------------------------------
a3 <- sort(union(gse_poolati, gse_k2))
cat(sprintf("\nSOTTOINSIEME A3  : %d studi\n", length(a3)))

# --- 4. CASI DI ACCETTAZIONE -------------------------------------------------
# I negativi contano di piu': sono la direzione in cui lo strumento sbaglia
# senza dare segno.
cat("\n== casi di accettazione ==\n")
ok <- TRUE
chk <- function(nome, esito, atteso) {
  cat(sprintf("  [%s] %-58s %s\n", if (isTRUE(esito)) "OK" else "FALLITO",
              nome, atteso))
  if (!isTRUE(esito)) ok <<- FALSE
}

# POSITIVO: ogni studio poolato e' dentro A3 (l'unione non ne perde nessuno)
chk("positivo: tutti gli studi poolati sono in A3",
    all(gse_poolati %in% a3), sprintf("%d/%d", sum(gse_poolati %in% a3),
                                      length(gse_poolati)))

# NEGATIVO: la sola lista delle assegnazioni PERDE studi poolati -> se questo
# non fallisse, l'unione sarebbe inutile e il codice sopra sarebbe cosmetico.
persi_senza_unione <- setdiff(gse_poolati, gse_k2)
chk("negativo: senza l'unione si perderebbero studi poolati",
    length(persi_senza_unione) > 0L,
    sprintf("%d persi (fusioni: record riassegnati)", length(persi_senza_unione)))

# NEGATIVO: A3 non contiene sigle inventate
chk("negativo: nessuna sigla non canonica in A3",
    all(grepl("^GSE[0-9]+$", a3)), sprintf("%d/%d canoniche",
                                           sum(grepl("^GSE[0-9]+$", a3)),
                                           length(a3)))

# --- 5. copertura sull'input Stadio 1 ----------------------------------------
s1 <- jsonlite::stream_in(file(S1_INPUT), verbose = FALSE, simplifyVector = TRUE)
s1_gse <- as.character(s1$series_id)
n_tot <- length(s1_gse)

# NEGATIVO: ogni studio di A3 deve esistere nell'input Stadio 1. Se uno manca,
# il sottoinsieme e' definito su un oggetto che il run non puo' rigenerare.
mancanti <- setdiff(a3, unique(s1_gse))
chk("negativo: nessuno studio di A3 assente dall'input Stadio 1",
    length(mancanti) == 0L, sprintf("%d mancanti", length(mancanti)))

n_rec <- sum(s1_gse %in% a3)
cat(sprintf("\nrecord Stadio 1 nel sottoinsieme: %d / %d (%.2f%%)\n",
            n_rec, n_tot, 100 * n_rec / n_tot))

if (!ok) stop("CASI DI ACCETTAZIONE FALLITI: lo strumento e' rotto finche' non si dimostra il contrario.")

# --- 6. deposito -------------------------------------------------------------
out_txt <- file.path(OUT_DIR, "A3-studi.txt")
writeLines(a3, out_txt)
sha <- digest::digest(file = out_txt, algo = "sha256")

meta <- list(
  definito_il      = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  stage3_dir       = S3_DIR,
  pool_dir         = POOL_DIR,
  criterio         = "studi dei cluster cgroup con k>=2, uniti agli studi poolati nel deliverable",
  n_studi          = length(a3),
  n_record_stage1  = n_rec,
  n_record_stage1_totali = n_tot,
  frazione_stage1  = round(n_rec / n_tot, 6),
  studi_poolati    = length(gse_poolati),
  studi_k2         = length(gse_k2),
  recuperati_dall_unione = length(persi_senza_unione),
  sha256_lista     = sha
)
jsonlite::write_json(meta, file.path(OUT_DIR, "A3-definizione.json"),
                     auto_unbox = TRUE, pretty = TRUE)

cat("\n== depositato ==\n")
cat("  ", out_txt, "\n")
cat("   sha256:", sha, "\n")
cat("  ", file.path(OUT_DIR, "A3-definizione.json"), "\n")
