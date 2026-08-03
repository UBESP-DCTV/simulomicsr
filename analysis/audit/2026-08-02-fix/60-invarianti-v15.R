#!/usr/bin/env Rscript
# analysis/audit/2026-08-02-fix/60-invarianti-v15.R
#
# Le CINQUE INVARIANTI ri-misurate sull'OUTPUT VERO del re-cluster v15
# (clusters.rds + assignments.parquet), NON sul dump `impatto-membri-*.rds`.
#
# Perche' non basta il dump (00-atteso-v15.md §6bis): il dump chiama
# `.ca_member_contrast()` isolatamente, etichetta per etichetta, e per
# costruzione NON vede il ramo `anchor` (R/stage3-contrast-anchor.R:700-702),
# che precede la de-frammentazione nella pipeline reale. E' esattamente il
# meccanismo per cui glioblastoma e' stata tolta dalle fusioni: il dump isolato
# l'avrebbe dichiarata "si fonde e basta", mentre sull'output vero lo split
# restava aperto.
#
# Le post-condizioni gia' verificate DENTRO lo script di re-cluster
# (n_dfg > 0, k TGFB1 > 65, k IL17A > 8, nessun residuo STR:, pavimenti
# bandiera) NON sono ripetute qui: questo script copre cio' che quello NON fa.
#
# Uso:
#   V15_DIR=analysis/p4-output/<dir del run v15> \
#     Rscript analysis/audit/2026-08-02-fix/60-invarianti-v15.R

suppressPackageStartupMessages({
  library(arrow)
  devtools::load_all(".", quiet = TRUE)
})

v15_dir <- Sys.getenv("V15_DIR", "")
v13_dir <- Sys.getenv("V13_DIR",
                      "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7")

if (!nzchar(v15_dir) || !dir.exists(v15_dir))
  stop("V15_DIR mancante o inesistente. Uso: V15_DIR=<dir> Rscript ",
       "analysis/audit/2026-08-02-fix/60-invarianti-v15.R")
if (!dir.exists(v13_dir))
  stop("V13_DIR inesistente: ", v13_dir)

# Entita' fuse dalla de-frammentazione (.CA_DEFRAG_ACCEPT dopo il 2026-08-02:
# glioblastoma TOLTA il 2026-08-02, deve restare invariata).
DEST      <- c("HGNC:11766", "HGNC:5981")            # TGFB1, IL17A
SORGENTI  <- c("STR:tgfb", "STR:tgf_b", "STR:il17", "STR:il_17")
GLIO      <- "MeSH:D005909"

cat("\n=== INVARIANTI v15 sull'OUTPUT VERO ===\n")
cat("v15:", v15_dir, "\n")
cat("v13:", v13_dir, "\n\n")

cl15 <- readRDS(file.path(v15_dir, "clusters.rds"))
cl13 <- readRDS(file.path(v13_dir, "clusters.rds"))
as15 <- as.data.frame(arrow::read_parquet(file.path(v15_dir, "assignments.parquet")))
as13 <- as.data.frame(arrow::read_parquet(file.path(v13_dir, "assignments.parquet")))

esiti <- list()
segna <- function(nome, ok, dettaglio = "") {
  esiti[[length(esiti) + 1L]] <<- list(nome = nome, ok = ok, dettaglio = dettaglio)
  cat(sprintf("[%s] %s%s\n", if (ok) " OK " else "FERMA", nome,
              if (nzchar(dettaglio)) paste0(" -- ", dettaglio) else ""))
}

is_cg15 <- cl15$mode == "cgroup"
is_cg13 <- cl13$mode == "cgroup"

# --- 0. run_id: deve essere diverso da 364547a7 --------------------------------
rm15 <- jsonlite::fromJSON(file.path(v15_dir, "run_metadata.json"))
rid15 <- as.character(rm15$run_id)[1]
segna("0. run_id diverso da 364547a7", !identical(rid15, "364547a7"),
      sprintf("run_id=%s", rid15))

# --- mappa record -> (cluster, entita', control_key, direction) ----------------
# Il record_id v15 porta un TERZO segmento (indice 1-based dell'occorrenza,
# Effetto 3): per confrontare con v13 va normalizzato togliendo quel segmento.
base_rid <- function(x) sub("__[0-9]+$", "", x)

mappa <- function(assign, clus, is_cg) {
  cg_ids <- clus$cluster_id[is_cg]
  a <- assign[assign$cluster_id %in% cg_ids, c("cluster_id", "record_id")]
  idx <- match(a$cluster_id, clus$cluster_id)
  data.frame(
    record_id   = a$record_id,
    base        = base_rid(a$record_id),
    cluster_id  = a$cluster_id,
    entity      = clus$contrast_entity[idx],
    control_key = clus$contrast_control_key[idx],
    direction   = clus$contrast_direction[idx],
    source      = clus$contrast_entity_source[idx],
    stringsAsFactors = FALSE
  )
}

m15 <- mappa(as15, cl15, is_cg15)
m13 <- mappa(as13, cl13, is_cg13)

cat(sprintf("\nmembri cgroup: v13=%d  v15=%d\n\n", nrow(m13), nrow(m15)))

# --- 5. destinazioni inattese --------------------------------------------------
# Ogni cluster con entita' dalla de-frammentazione deve puntare SOLO a TGFB1 o
# IL17A, e MAI a glioblastoma.
dfg_cl <- cl15[is_cg15 & !is.na(cl15$contrast_entity_source) &
                 cl15$contrast_entity_source == "defrag", ]
dest_osservate <- sort(unique(dfg_cl$contrast_entity))
segna("5a. destinazioni della de-frammentazione solo TGFB1/IL17A",
      length(setdiff(dest_osservate, DEST)) == 0L,
      sprintf("osservate: %s", paste(dest_osservate, collapse = ", ")))
segna("5b. glioblastoma MAI fra le destinazioni",
      !(GLIO %in% dest_osservate),
      sprintf("cluster defrag: %d", nrow(dfg_cl)))

k_of <- function(clus, is_cg, id) {
  s <- is_cg & !is.na(clus$contrast_entity) & clus$contrast_entity == id
  if (any(s)) max(clus$k[s], na.rm = TRUE) else 0L
}
k_glio13 <- k_of(cl13, is_cg13, GLIO)
k_glio15 <- k_of(cl15, is_cg15, GLIO)
segna("5c. glioblastoma invariato rispetto a v13",
      identical(as.integer(k_glio13), as.integer(k_glio15)),
      sprintf("k v13=%d, k v15=%d (atteso uguale)", k_glio13, k_glio15))

# --- 1. nessun membro partito da un'entita' gia' risolta -----------------------
# I membri finiti nei cluster de-frammentati devono venire, in v13, o dalle
# scritture STR: fuse, o dall'entita' di destinazione stessa. Qualunque altra
# provenienza e' una fusione che non doveva avvenire.
m15_dfg <- m15[m15$cluster_id %in% dfg_cl$cluster_id, ]
# base ambigue = stessa (serie, comparison) su piu' bracci: sono l'Effetto 3,
# non confrontabili 1:1 con v13. Dichiarate, non nascoste.
amb13 <- names(which(table(m13$base) > 1L))
conf  <- m15_dfg[!(m15_dfg$base %in% amb13), ]
conf$entity13      <- m13$entity[match(conf$base, m13$base)]
conf$control_key13 <- m13$control_key[match(conf$base, m13$base)]
conf$direction13   <- m13$direction[match(conf$base, m13$base)]
noti <- !is.na(conf$entity13)

fuori <- conf[noti & !(conf$entity13 %in% c(SORGENTI, DEST)), ]
segna("1. nessun membro partito da un'entita' gia' risolta",
      nrow(fuori) == 0L,
      sprintf("%d membri fuori norma%s | confrontati %d, ambigui esclusi %d, nuovi in v15 %d",
              nrow(fuori),
              if (nrow(fuori)) paste0(" (", paste(unique(fuori$entity13), collapse = ", "), ")") else "",
              sum(noti), sum(m15_dfg$base %in% amb13), sum(!noti)))

# --- 3. e 4. control_key e direction invariati ---------------------------------
div_ck <- conf[noti & conf$control_key != conf$control_key13, ]
div_dr <- conf[noti & conf$direction   != conf$direction13, ]
segna("3. nessun control_key divergente", nrow(div_ck) == 0L,
      sprintf("%d divergenti su %d", nrow(div_ck), sum(noti)))
segna("4. nessuna direzione divergente", nrow(div_dr) == 0L,
      sprintf("%d divergenti su %d", nrow(div_dr), sum(noti)))

# --- 2. nessun membro perso ----------------------------------------------------
# Il totale dei membri sulle entita' coinvolte non deve calare: la fusione
# sposta i membri, non li butta.
conta <- function(m, ids) sum(m$entity %in% ids, na.rm = TRUE)
n13_tgf <- conta(m13, c("HGNC:11766", "STR:tgfb", "STR:tgf_b"))
n15_tgf <- conta(m15, "HGNC:11766")
n13_il  <- conta(m13, c("HGNC:5981", "STR:il17", "STR:il_17"))
n15_il  <- conta(m15, "HGNC:5981")
segna("2a. membri TGFB1 non calati", n15_tgf >= n13_tgf,
      sprintf("v13=%d (65+9+..)  v15=%d  delta=%+d", n13_tgf, n15_tgf, n15_tgf - n13_tgf))
segna("2b. membri IL17A non calati", n15_il >= n13_il,
      sprintf("v13=%d  v15=%d  delta=%+d", n13_il, n15_il, n15_il - n13_il))

# --- k censiti, contro l'atteso ------------------------------------------------
cat("\n--- k censiti (Stadio 3), contro 00-atteso-v15.md §2 ---\n")
for (x in list(list(id = "HGNC:11766", nome = "TGFB1", v13 = 65L, atteso = 78L),
               list(id = "HGNC:5981",  nome = "IL17A", v13 = 8L,  atteso = 12L))) {
  cat(sprintf("  %-6s %s: v13=%d  v15=%d  (atteso %d)\n",
              x$nome, x$id, x$v13, k_of(cl15, is_cg15, x$id), x$atteso))
}
cat(sprintf("  residui STR: fusi ancora presenti: %d\n",
            sum(is_cg15 & cl15$contrast_entity %in% SORGENTI, na.rm = TRUE)))

# --- 6. candidati pre-pooling ---------------------------------------------------
# Misurato col gate di produzione vero, PRIMA di impegnare 28 h di re-pool: se
# il numero non torna, il fix della dedup non si e' comportato come su v13.
#
# ATTESO, depositato il 2026-08-03 PRIMA di vedere l'output v15, misurando sui
# cluster v13 col codice attuale (non e' una spiegazione a posteriori):
#   - candidati su v13 col codice di oggi: 354 (contro i 305 pre-fix della dedup
#     -> il Delta +49 di 00-atteso-v15.md §3 e' CONFERMATO, e su v13, quindi
#     indipendentemente da come andra' v15);
#   - di quei 354, TRE hanno un'entita' che la de-frammentazione fonde:
#     STR:tgfb (k=11), STR:tgf_b (k=3), STR:il17 (k=3). Su v15 non esistono piu'
#     come righe a se': confluiscono in TGFB1 e IL17A.
#   => atteso su v15: 354 - 3 = 351, al netto di eventuali cluster che la
#      fusione porta SOPRA la soglia k>=3 (che alzerebbero il conto).
#
# NB: 351 e' il conteggio dei CANDIDATI pre-pooling. E' un numero diverso dal
# "-1 riga" di 00-atteso-v15.md §2, che parla del DELIVERABLE POOLATO: dei tre
# cluster fusi solo STR:tgfb supera il gate del pooling e compare fra le 191
# righe. Due conteggi diversi in due punti diversi della catena: non vanno
# confrontati fra loro.
CAND_ATTESI <- 351L
cat("\n--- candidati pre-pooling (00-atteso-v15.md §3) ---\n")
cand <- tryCatch({
  nrow(simulomicsr:::.identify_layer_a_clusters(
    cl15, simulomicsr::stage4_default_config()))
}, error = function(e) {
  cat("  (non misurabile qui:", conditionMessage(e), ")\n"); NA_integer_
})
if (!is.na(cand)) {
  cat(sprintf("  candidati v15: %d  (v13 col codice attuale = 354; atteso %d = 354 - 3 fusi)\n",
              cand, CAND_ATTESI))
  cat(sprintf("  scomposizione: 305 pre-fix dedup  ->  354 post-fix (+49)  ->  %d dopo la fusione (-3)\n",
              CAND_ATTESI))
  segna(sprintf("6. candidati pre-pooling = %d", CAND_ATTESI),
        identical(as.integer(cand), CAND_ATTESI),
        sprintf("osservati %d (scarto %+d sull'atteso)", cand, cand - CAND_ATTESI))
}

# --- verdetto ------------------------------------------------------------------
cat("\n=== VERDETTO ===\n")
ko <- Filter(function(e) !e$ok, esiti)
if (length(ko) == 0L) {
  cat("Tutte le invarianti tornano. Si puo' procedere al re-pool.\n")
} else {
  cat(sprintf("%d invarianti NON tornano -- FERMARSI:\n", length(ko)))
  for (e in ko) cat("  -", e$nome, "--", e$dettaglio, "\n")
}
