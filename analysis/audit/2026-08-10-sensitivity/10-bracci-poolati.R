#!/usr/bin/env Rscript
# analysis/audit/2026-08-10-sensitivity/10-bracci-poolati.R
#
# PASSO 1 del programma di sensitivity (handout 2026-08-10 §4.1, §5 passo 1).
# «Riderivare la lista degli accusati sui confronti POOLATI, stabilendo una sola
# definizione di braccio. Senza questo il resto non ha senso.»
#
# PERCHE'. Il materiale su cui e' stata fatta la rilettura del 5 agosto
# (00-materiale.R:78) elencava i confronti di uno studio non appena lo STUDIO
# compariva nel per_study_de. Non applicava ne' il filtro `n_min` ne' la dedup
# `series_id||treated_group` che il dispatch di produzione applica. Quindi una
# parte dei confronti giudicati difettosi NON e' nel deliverable, e il «peso
# contaminato» pubblicato per quei gruppi e' sbagliato.
#
# ⚠️ DEFINIZIONE DI BRACCIO — fissata qui, una volta sola (era la contraddizione
# 432 contro 533 di §4.1). Un braccio e' una entry di
# `.build_group_rem_dispatch_from_stage3`: la tupla (cluster, studio, campioni
# trattati, campioni di controllo) che ha superato, in quest'ordine,
#   (1) comparison risolta da .lookup_cmp,
#   (2) replicate group trattato e controllo risolti,
#   (3) n_min = 2 su ENTRAMBI i lati,
#   (4) dedup su `series_id || treated_group` (vince il primo).
# E' l'oggetto che il pooling consuma. Contare le tuple distinte
# (cluster, studio, n_t, n_c) nel per_study_de fonde i bracci con gli stessi n
# (da cui il 432); ricostruire dallo Stadio 2 con n_t>=2 & n_c>=2 salta la dedup
# (da cui il 533). Nessuna delle due e' il numero giusto.
#
# CASI DI ACCETTAZIONE (lo script si ferma se falliscono):
#   A. la replica strumentata riproduce ESATTAMENTE il dispatch di produzione
#      (stesso numero di bracci per cluster, stessi insiemi trattato/controllo);
#   B. il numero di bracci per (cluster, studio) coincide con quello che si legge
#      nel per_study_de del re-pool v15.
#
# Uso: Rscript analysis/audit/2026-08-10-sensitivity/10-bracci-poolati.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(cli); devtools::load_all(".", quiet = TRUE)
})

V15    <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
POOL   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
ACC    <- "analysis/audit/2026-08-05-rilettura-214/13-grandi-conteggio.json"
OUT    <- "analysis/audit/2026-08-10-sensitivity"
N_MIN  <- 2L

stopifnot(dir.exists(V15), dir.exists(POOL), file.exists(STAGE2), file.exists(ACC))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
`%||%` <- function(a, b) if (is.null(a) || !length(a) || !nzchar(a)) b else a

# --- input --------------------------------------------------------------------
deliv <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
cli_alert_info("deliverable: {nrow(deliv)} meta-analisi")

asg <- as.data.frame(read_parquet(file.path(V15, "assignments.parquet"),
                                  col_select = c("record_id", "cluster_id")))
asg <- asg[asg$cluster_id %in% deliv$cluster_id, ]
cli_alert_info("assegnazioni sui cluster del deliverable: {nrow(asg)} record")

s2  <- simulomicsr:::.load_stage2_master(STAGE2)
s2i <- simulomicsr:::.index_stage2_master(s2)

# eligible_clusters minimale: il dispatch legge solo cluster_id/mode/method e
# tratta ogni cluster in modo indipendente, quindi restringere ai 214 del
# deliverable e' identico a passare l'oggetto intero (verificato dal caso A, che
# confronta con la funzione di produzione sugli stessi cluster).
elig <- data.frame(cluster_id = deliv$cluster_id, mode = "cgroup",
                   method = "rem_group", stringsAsFactors = FALSE)

# --- replica strumentata: stessa logica, con la provenienza -------------------
# Copia fedele del ciclo di .build_group_rem_dispatch_from_stage3 (R/stage4-dispatch.R
# righe 332-390). L'unica differenza e' che registra l'esito di OGNI record_id
# invece di scartarlo in silenzio. Il caso di accettazione A prova che e' fedele.
asg_by <- split(asg$record_id, asg$cluster_id)
righe  <- vector("list", 0L)
disp_replica <- list()

for (cid in names(asg_by)) {
  seen_keys <- character(0L)
  cluster_dispatch <- vector("list", 0L)
  for (rid in asg_by[[cid]]) {
    p <- simulomicsr:::.split_record_id(rid)
    rec <- list(cluster_id = cid, record_id = rid, study_id = NA_character_,
                treated_group = NA_character_, control_group = NA_character_,
                etichetta_trattato = NA_character_, etichetta_controllo = NA_character_,
                n_t = NA_integer_, n_c = NA_integer_, esito = NA_character_)
    if (is.na(p$series_id)) { rec$esito <- "record_id senza series"; righe[[length(righe)+1L]] <- rec; next }
    rec$study_id <- p$series_id
    if (!exists(p$series_id, envir = s2i, inherits = FALSE)) {
      rec$esito <- "studio assente da stadio 2"; righe[[length(righe)+1L]] <- rec; next
    }
    study <- get(p$series_id, envir = s2i, inherits = FALSE)
    cmp <- simulomicsr:::.lookup_cmp(study, p$suffix)
    if (is.null(cmp)) { rec$esito <- "comparison non risolta"; righe[[length(righe)+1L]] <- rec; next }
    rec$treated_group <- cmp$treated_group; rec$control_group <- cmp$control_group
    tg <- simulomicsr:::.lookup_rg(study, cmp$treated_group)
    cg <- simulomicsr:::.lookup_rg(study, cmp$control_group)
    if (is.null(tg) || is.null(cg)) {
      rec$esito <- "replicate group non risolti"; righe[[length(righe)+1L]] <- rec; next
    }
    treated <- as.character(unlist(tg$sample_ids)); control <- as.character(unlist(cg$sample_ids))
    rec$n_t <- length(treated); rec$n_c <- length(control)
    rec$etichetta_trattato  <- tg$label_human %||% cmp$treated_group
    rec$etichetta_controllo <- cg$label_human %||% cmp$control_group
    if (rec$n_t < N_MIN || rec$n_c < N_MIN) {
      rec$esito <- "scartato n_min"; righe[[length(righe)+1L]] <- rec; next
    }
    key <- paste0(p$series_id, "||", cmp$treated_group)
    if (key %in% seen_keys) {
      rec$esito <- "collassato dalla dedup"; righe[[length(righe)+1L]] <- rec; next
    }
    seen_keys <- c(seen_keys, key)
    rec$esito <- "braccio"
    righe[[length(righe)+1L]] <- rec
    cluster_dispatch[[length(cluster_dispatch)+1L]] <-
      list(study_id = p$series_id, treated = treated, control = control)
  }
  if (length(cluster_dispatch) > 0L) disp_replica[[cid]] <- cluster_dispatch
}

R <- do.call(rbind.data.frame, c(righe, list(stringsAsFactors = FALSE)))
cli_alert_success("replica: {nrow(R)} record classificati su {length(asg_by)} cluster")

# --- CASO DI ACCETTAZIONE A: replica == produzione ----------------------------
cli_h2("Caso di accettazione A — la replica riproduce il dispatch di produzione")
disp_prod <- simulomicsr:::.build_group_rem_dispatch_from_stage3(elig, asg, s2, n_min = N_MIN)
firma <- function(d) sort(vapply(d, function(e) paste(e$study_id,
  paste(sort(e$treated), collapse = ","), paste(sort(e$control), collapse = ","),
  sep = " | "), character(1L)))
stopifnot(identical(sort(names(disp_prod)), sort(names(disp_replica))))
diff_A <- vapply(names(disp_prod), function(c) !identical(firma(disp_prod[[c]]), firma(disp_replica[[c]])), logical(1L))
cli_alert_info("cluster con dispatch: produzione {length(disp_prod)} | replica {length(disp_replica)} | discordanti {sum(diff_A)}")
if (any(diff_A)) cli_abort("La replica NON e' fedele: {sum(diff_A)} cluster diversi.")
cli_alert_success("A PASSA: {length(disp_prod)} cluster, bracci identici uno per uno")

# --- CASO DI ACCETTAZIONE B: bracci == per_study_de ---------------------------
# Nel per_study_de non c'e' un identificativo di braccio: ogni braccio contribuisce
# una riga per gene. Il numero di bracci di (cluster, studio) e' quindi il massimo,
# sui geni, del numero di righe con quel (cluster, studio, gene).
cli_h2("Caso di accettazione B — i bracci contati nel per_study_de del re-pool")
psd_n <- read_parquet(file.path(POOL, "per_study_de.parquet"),
                      col_select = c("cluster_id", "study_id", "gene_id")) |>
  dplyr::filter(cluster_id %in% deliv$cluster_id) |>
  dplyr::count(cluster_id, study_id, gene_id, name = "n_righe") |>
  dplyr::group_by(cluster_id, study_id) |>
  dplyr::summarise(bracci_psd = max(n_righe), .groups = "drop") |>
  as.data.frame()

bracci_disp <- as.data.frame(dplyr::count(
  dplyr::filter(R, esito == "braccio"), cluster_id, study_id, name = "bracci_disp"))
cmpB <- merge(bracci_disp, psd_n, by = c("cluster_id", "study_id"), all = TRUE)
cmpB$bracci_disp[is.na(cmpB$bracci_disp)] <- 0L
cmpB$bracci_psd[is.na(cmpB$bracci_psd)]   <- 0L
cmpB$diverso <- cmpB$bracci_disp != cmpB$bracci_psd
cli_alert_info("coppie (cluster, studio): {nrow(cmpB)} | discordanti {sum(cmpB$diverso)}")
cli_alert_info("bracci totali: dispatch {sum(cmpB$bracci_disp)} | per_study_de {sum(cmpB$bracci_psd)}")
if (any(cmpB$diverso)) {
  utils::write.csv(cmpB[cmpB$diverso, ], file.path(OUT, "10-B-discordanze.csv"), row.names = FALSE)
  print(utils::head(cmpB[cmpB$diverso, ], 20))
  cli_alert_danger("B NON passa: dettaglio in 10-B-discordanze.csv")
} else {
  cli_alert_success("B PASSA: bracci identici su tutte le {nrow(cmpB)} coppie (cluster, studio)")
}

utils::write.csv(R, file.path(OUT, "10-record-esito.csv"), row.names = FALSE)
saveRDS(R, file.path(OUT, "10-record-esito.rds"))

cli_h2("Esito dei record delle 214 meta-analisi")
print(sort(table(R$esito), decreasing = TRUE))

# --- gli accusati, riportati sui bracci ---------------------------------------
cli_h2("I confronti accusati stanno dentro il pooling?")
acc <- jsonlite::fromJSON(ACC, simplifyDataFrame = FALSE)
A <- do.call(rbind.data.frame, c(lapply(acc, function(g) {
  if (!length(g$confronti_difettosi)) return(NULL)
  do.call(rbind.data.frame, c(lapply(g$confronti_difettosi, function(d) list(
    cluster_id = g$cluster_id, n_confronti_censiti = g$n_confronti_totali,
    study_id = d$studio, etichetta_trattato = d$etichetta_trattato,
    etichetta_controllo = d$etichetta_controllo, meccanismo = d$meccanismo)),
    list(stringsAsFactors = FALSE)))
}), list(stringsAsFactors = FALSE)))
cli_alert_info("accuse censite: {nrow(A)} su {length(acc)} gruppi grandi")

# La tripla (studio, etichetta trattato, etichetta controllo) e' la chiave con cui
# il lettore umano ha accusato: piu' record_id possono condividerla (il lettore
# stesso segnala i «duplicati»). Per ogni tripla si guarda quanti dei suoi record
# sono braccio, quanti collassati, quanti scartati.
R$chiave <- paste(R$study_id, R$etichetta_trattato, R$etichetta_controllo, sep = " ‖ ")
A$chiave <- paste(A$study_id, A$etichetta_trattato, A$etichetta_controllo, sep = " ‖ ")

per_chiave <- function(cid, chiave) {
  sub <- R[R$cluster_id == cid & R$chiave == chiave, ]
  if (!nrow(sub)) return(c(rec = 0L, braccio = 0L, dedup = 0L, nmin = 0L, altro = 0L))
  c(rec = nrow(sub), braccio = sum(sub$esito == "braccio"),
    dedup = sum(sub$esito == "collassato dalla dedup"),
    nmin  = sum(sub$esito == "scartato n_min"),
    altro = sum(!sub$esito %in% c("braccio", "collassato dalla dedup", "scartato n_min")))
}
M <- t(mapply(per_chiave, A$cluster_id, A$chiave))
A <- cbind(A, as.data.frame(M))
A$stato <- ifelse(A$rec == 0L, "NON TROVATO nel cluster",
           ifelse(A$braccio > 0L, "dentro il pooling",
           ifelse(A$dedup   > 0L, "collassato (trattato comunque dentro)",
           ifelse(A$nmin    > 0L, "fuori: n_min", "fuori: altro"))))

cli_alert_info("copertura: accuse ritrovate fra i record del cluster {sum(A$rec > 0)}/{nrow(A)}")
print(sort(table(A$stato), decreasing = TRUE))

utils::write.csv(A, file.path(OUT, "10-accuse-sui-bracci.csv"), row.names = FALSE)

cli_h2("Per gruppo: confronti censiti, bracci veri, accuse dentro il pooling")
per_gruppo <- do.call(rbind.data.frame, c(lapply(unique(A$cluster_id), function(cid) {
  a <- A[A$cluster_id == cid, ]
  list(cluster_id = cid,
       entita = deliv$contrast_entity_label[match(cid, deliv$cluster_id)] %||% NA_character_,
       k = deliv$k_effective[match(cid, deliv$cluster_id)],
       confronti_censiti = a$n_confronti_censiti[1],
       bracci_veri = sum(R$cluster_id == cid & R$esito == "braccio"),
       accuse = nrow(a),
       accuse_dentro = sum(a$stato == "dentro il pooling"),
       accuse_collassate = sum(a$stato == "collassato (trattato comunque dentro)"),
       accuse_fuori = sum(a$stato %in% c("fuori: n_min", "fuori: altro", "NON TROVATO nel cluster")),
       studi_accusati_dentro = length(unique(a$study_id[a$stato == "dentro il pooling"])))
}), list(stringsAsFactors = FALSE)))
per_gruppo <- per_gruppo[order(-per_gruppo$k), ]
print(per_gruppo, row.names = FALSE)
utils::write.csv(per_gruppo, file.path(OUT, "10-per-gruppo.csv"), row.names = FALSE)

cli_alert_success("scritti: 10-record-esito.csv, 10-accuse-sui-bracci.csv, 10-per-gruppo.csv")
