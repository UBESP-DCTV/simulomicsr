#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/00-materiale.R
#
# Prepara il materiale per leggere TUTTE e 194 le meta-analisi del deliverable
# A3, e dare a ciascuna un verdetto di CORRETTEZZA.
#
# TRE DIFFERENZE DALLO SCRIPT DEL 2026-08-05, ognuna per un errore gia' pagato:
#
# 1. I CONFRONTI SONO QUELLI POOLATI, NON I CENSITI. Lo script del 5 agosto
#    filtrava per STUDIO ("lo studio compare nel per_study_de"), non per
#    CONFRONTO: 47 accuse su 85 riguardavano confronti che nel deliverable non
#    c'erano. Qui la lista dei confronti e' la REPLICA DEL DISPATCH DI
#    PRODUZIONE (n_min biologico dopo il collasso delle corsie + dedup
#    series||treated_group), e passa da DUE prove di accettazione (sotto).
#
# 2. LE ETICHETTE SONO INTERE. Il progetto ha dato tre verdetti su mezza frase.
#    Lo script misura la distribuzione delle lunghezze e stampa i picchi: vanno
#    ispezionati uno per uno, non ignorati.
#
# 3. C'E' LA COLONNA COMPARATIVA. Per ogni studio: dov'era nel run di
#    riferimento (v16b) e dov'e' ora. Dove le due esecuzioni divergono, la
#    domanda diventa «quale delle due assegnazioni e' giusta», che e' molto piu'
#    facile della domanda assoluta. ⚠️ Le etichette del riferimento si leggono
#    dal SUO master Stadio 2, non da quello di A3: i due master differiscono su
#    2.273 studi su 24.394, e leggere le etichette vecchie dal master nuovo
#    mostrerebbe un confronto che nel run vecchio non esisteva.
#
# PROVE DI ACCETTAZIONE (lo script si ferma se falliscono):
#   A. il registro degli scarti della replica e' IDENTICO a
#      qc_report$dispatch_drops di produzione (righe, motivi, conteggi);
#   B. le coppie (cluster, studio) dei confronti tenuti coincidono ESATTAMENTE
#      con quelle di per_study_de.parquet.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/00-materiale.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(cli); devtools::load_all(".", quiet = TRUE)
})

A3_POOL   <- Sys.getenv("A3_POOL",   "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d")
A3_S3     <- Sys.getenv("A3_S3",     "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159")
A3_S2     <- Sys.getenv("A3_S2",     "analysis/p4-output/A3-stage2-master-innestato.jsonl")
RIF_POOL  <- Sys.getenv("RIF_POOL",  "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d")
RIF_S3    <- Sys.getenv("RIF_S3",    "analysis/p4-output/20260815T231154Z-stage3-v16-7f986159")
RIF_S2    <- Sys.getenv("RIF_S2",    "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
H5        <- Sys.getenv("H5_PATH",   "analysis/input/human_gene_v2.5.h5")
OUT       <- "analysis/audit/2026-08-20-rilettura-194"
N_MIN     <- 2L

stopifnot(dir.exists(A3_POOL), dir.exists(A3_S3), file.exists(A3_S2),
          dir.exists(RIF_POOL), dir.exists(RIF_S3), file.exists(RIF_S2),
          file.exists(H5))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
`%||%` <- function(a, b) if (is.null(a) || !length(a) || !nzchar(a)) b else a

# ---------------------------------------------------------------------------
# 1. Replica del dispatch, strumentata (registra anche le etichette)
# ---------------------------------------------------------------------------
replica_dispatch <- function(cluster_ids, asg, s2i, lane_lookup) {
  asg <- asg[asg$cluster_id %in% cluster_ids, ]
  # stesso ordine di produzione: split() sull'ordine di riga di assignments
  asg_by <- split(asg$record_id, asg$cluster_id)

  tenuti <- vector("list", 0L); scarti <- vector("list", 0L)
  for (cid in names(asg_by)) {
    seen_keys <- character(0L)
    for (rid in asg_by[[cid]]) {
      p <- simulomicsr:::.split_record_id(rid)
      if (is.na(p$series_id)) {
        scarti[[length(scarti)+1L]] <- data.frame(cluster_id=cid, study_id=NA_character_,
          treated_group=rid, motivo="record_id_non_risolto", n_treated=NA_integer_,
          n_control=NA_integer_, n_bio_treated=NA_integer_, n_bio_control=NA_integer_,
          stringsAsFactors=FALSE); next
      }
      if (!exists(p$series_id, envir = s2i, inherits = FALSE)) {
        scarti[[length(scarti)+1L]] <- data.frame(cluster_id=cid, study_id=p$series_id,
          treated_group=p$suffix, motivo="studio_assente_dallo_stadio2", n_treated=NA_integer_,
          n_control=NA_integer_, n_bio_treated=NA_integer_, n_bio_control=NA_integer_,
          stringsAsFactors=FALSE); next
      }
      study <- get(p$series_id, envir = s2i, inherits = FALSE)
      cmp <- simulomicsr:::.lookup_cmp(study, p$suffix)
      if (is.null(cmp)) {
        scarti[[length(scarti)+1L]] <- data.frame(cluster_id=cid, study_id=p$series_id,
          treated_group=p$suffix, motivo="confronto_non_trovato", n_treated=NA_integer_,
          n_control=NA_integer_, n_bio_treated=NA_integer_, n_bio_control=NA_integer_,
          stringsAsFactors=FALSE); next
      }
      tg <- simulomicsr:::.lookup_rg(study, cmp$treated_group)
      cg <- simulomicsr:::.lookup_rg(study, cmp$control_group)
      if (is.null(tg) || is.null(cg)) {
        scarti[[length(scarti)+1L]] <- data.frame(cluster_id=cid, study_id=p$series_id,
          treated_group=cmp$treated_group, motivo="braccio_non_trovato", n_treated=NA_integer_,
          n_control=NA_integer_, n_bio_treated=NA_integer_, n_bio_control=NA_integer_,
          stringsAsFactors=FALSE); next
      }
      treated <- as.character(unlist(tg$sample_ids))
      control <- as.character(unlist(cg$sample_ids))
      bt <- simulomicsr:::.n_biological(treated, lane_lookup)
      bc <- simulomicsr:::.n_biological(control, lane_lookup)
      if (bt < N_MIN || bc < N_MIN) {
        collasso <- !is.null(lane_lookup) && length(lane_lookup) > 0L &&
          length(unique(treated)) >= N_MIN && length(unique(control)) >= N_MIN
        scarti[[length(scarti)+1L]] <- data.frame(cluster_id=cid, study_id=p$series_id,
          treated_group=cmp$treated_group,
          motivo=if (collasso) "n_min_dopo_collasso_corsie" else "n_min",
          n_treated=length(unique(treated)), n_control=length(unique(control)),
          n_bio_treated=bt, n_bio_control=bc, stringsAsFactors=FALSE); next
      }
      key <- paste0(p$series_id, "||", cmp$treated_group)
      if (key %in% seen_keys) {
        scarti[[length(scarti)+1L]] <- data.frame(cluster_id=cid, study_id=p$series_id,
          treated_group=cmp$treated_group, motivo="doppione_studio_braccio",
          n_treated=length(unique(treated)), n_control=length(unique(control)),
          n_bio_treated=bt, n_bio_control=bc, stringsAsFactors=FALSE); next
      }
      seen_keys <- c(seen_keys, key)
      tenuti[[length(tenuti)+1L]] <- data.frame(
        cluster_id = cid, study_id = p$series_id, record_id = rid,
        treated_group = cmp$treated_group, control_group = cmp$control_group,
        etichetta_trattato  = tg$label_human %||% cmp$treated_group,
        etichetta_controllo = cg$label_human %||% cmp$control_group,
        n_t = bt, n_c = bc,
        n_gsm_t = length(unique(treated)), n_gsm_c = length(unique(control)),
        # I CAMPIONI, non solo il loro numero: servono a distinguere una
        # divergenza VERA (cambiano i campioni poolati, cambia il risultato) da
        # una COSMETICA (stessi campioni, l'LLM ha solo riscritto l'etichetta).
        # Senza questo, «1.034 divergenze» resta un numero che non dice nulla.
        gsm_t = paste(sort(unique(treated)), collapse = ","),
        gsm_c = paste(sort(unique(control)), collapse = ","),
        stringsAsFactors = FALSE)
    }
  }
  list(tenuti = if (length(tenuti)) do.call(rbind, tenuti) else NULL,
       scarti = if (length(scarti)) do.call(rbind, scarti) else NULL)
}

# ---------------------------------------------------------------------------
# 2. Ricostruzione dello STATO che la produzione passa al dispatch
#
# ⚠️ La prima versione di questo script sbagliava qui, e la PROVA A l'ha presa:
# costruiva le corsie sui soli campioni dei 194 cluster del deliverable e
# leggeva `assignments.parquet` cosi' com'e'. La produzione fa due cose in piu',
# entrambe PRIMA del dispatch (R/stage4-build.R:190-240):
#   (a) sposta sul cluster vincente i record dei cluster ASSORBITI dalle fusioni
#       (.reassign_absorbed_records; senza questo, sul re-pool v16 il TNF
#       dichiarava k=48 e il dispatch ne risolveva 32);
#   (b) costruisce le corsie su TUTTI i campioni del Layer A (351 cluster
#       candidati), non sui soli 194 sopravvissuti.
# Con lo stato sbagliato mancavano 21 scarti n_min su 2.487. Ora si replica la
# produzione passo per passo.
# ---------------------------------------------------------------------------
# PRE-FILTRO DEL MASTER STADIO 2 CONTRO L'ASSE DEI CAMPIONI DELL'H5.
# Copia fedele di .filter_stage2_master_to_h5() dello script di re-pool
# (p4-fase-f5-...-v16.R:196-215). E' il PRIMO passo della produzione e senza di
# esso la replica non torna: toglie 15 campioni su 491.071 che non esistono in
# ARCHS4 v2.5, e uno di quei quindici (GSM6849338) bastava a portare i campioni
# del Layer A da 27.788 a 27.789 e a far CADERE build_lane_library_lookup() sul
# titolo NA. Togliendoli, i bracci cambiano di dimensione: e' un passo che tocca
# il gate n_min, non una pulizia cosmetica.
filtra_su_h5 <- function(s2, h5_samples) {
  hs <- new.env(hash = TRUE, parent = emptyenv())
  for (x in h5_samples) assign(x, TRUE, envir = hs)
  n_tot <- 0L; n_drop <- 0L
  for (i in seq_along(s2)) {
    rgs <- s2[[i]]$replicate_groups
    for (j in seq_along(rgs)) {
      sids <- as.character(unlist(rgs[[j]]$sample_ids))
      n_tot <- n_tot + length(sids)
      ok <- sids[vapply(sids, exists, logical(1L), envir = hs, inherits = FALSE)]
      n_drop <- n_drop + (length(sids) - length(ok))
      s2[[i]]$replicate_groups[[j]]$sample_ids <- as.list(ok)
    }
  }
  cli_alert_info("pre-filtro H5: {n_drop}/{n_tot} campioni tolti (non in ARCHS4 v2.5)")
  s2
}

stato_produzione <- function(s3_dir, s2_path) {
  s3  <- load_stage3(s3_dir)
  s2  <- simulomicsr:::.load_stage2_master(s2_path)
  s2  <- filtra_su_h5(s2, as.character(rhdf5::h5read(H5, "meta/samples/geo_accession")))
  rhdf5::h5closeAll()
  s2i <- simulomicsr:::.index_stage2_master(s2)
  config <- simulomicsr:::stage4_default_config()

  layer_a <- simulomicsr:::.identify_layer_a_clusters(s3$clusters, config)
  cli_alert_info("Layer A: {nrow(layer_a)} cluster candidati")
  asg <- as.data.frame(s3$assignments)
  rel <- asg[asg$cluster_id %in% layer_a$cluster_id, ]

  # ⚠️ COPIA FEDELE di collect_sids() dello script di re-pool
  # (p4-fase-f5-...-v16.R:293-309), match ESATTO sul group_id via rg_lookup[[ ]].
  # NON si usa .lookup_rg(): quella risolve anche gruppi che il match esatto non
  # trova, e la differenza non e' teorica — pescava un campione in piu'
  # (GSM6849338, assente dall'H5) che portava h5_metadata da 27.788 a 27.789 e
  # faceva CADERE build_lane_library_lookup() sul titolo NA. Il dispatch invece
  # usa .lookup_rg(), ed e' giusto cosi': sono due punti diversi della catena.
  collect_sids <- function(rid) {
    p <- simulomicsr:::.split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2i, inherits = FALSE)) return(character(0))
    st <- get(p$series_id, envir = s2i, inherits = FALSE)
    rgl <- stats::setNames(st$replicate_groups,
                           vapply(st$replicate_groups, `[[`, character(1L), "group_id"))
    cmp <- simulomicsr:::.lookup_cmp(st, p$suffix)
    if (!is.null(cmp)) {
      tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
      if (is.null(tg) || is.null(cg)) return(character(0))
      return(c(as.character(unlist(tg$sample_ids)), as.character(unlist(cg$sample_ids))))
    }
    rg <- rgl[[p$suffix]]
    if (!is.null(rg)) return(as.character(unlist(rg$sample_ids)))
    character(0)
  }
  sids <- unique(unlist(lapply(rel$record_id, collect_sids)))
  cli_alert_info("campioni Layer A: {length(sids)}")

  gse <- character(length(sids)); names(gse) <- sids
  for (st in s2) for (rg in st$replicate_groups) {
    h <- intersect(as.character(unlist(rg$sample_ids)), sids)
    if (length(h)) gse[h] <- st$series_id
  }
  ok <- !(gse == "" | is.na(gse)); sids <- sids[ok]; gse <- gse[ok]

  f <- c("geo_accession","title","series_id","characteristics_ch1","source_name_ch1")
  all5 <- lapply(stats::setNames(f, f), function(x)
    as.character(rhdf5::h5read(H5, paste0("meta/samples/", x))))
  rhdf5::h5closeAll()
  i <- match(sids, all5$geo_accession)
  h5m <- tibble::tibble(sample_id = sids, gsm = sids, gse = unname(gse), lib_size = 1e7L,
    geo_accession = sids, title = all5$title[i], series_id = all5$series_id[i],
    characteristics_ch1 = all5$characteristics_ch1[i], source_name_ch1 = all5$source_name_ch1[i])

  qc <- simulomicsr:::.qc_filter_samples_and_studies(s3$clusters, h5m, config)
  fus <- attr(qc$eligible_clusters, "fusioni")
  if (!is.null(fus) && nrow(fus) > 0L) {
    asg <- simulomicsr:::.reassign_absorbed_records(asg, fus)
    cli_alert_info("fusioni: record di {nrow(fus)} cluster assorbiti spostati sul vincente")
  } else cli_alert_info("nessuna fusione da applicare")

  lane <- simulomicsr:::build_lane_library_lookup(h5m)
  cli_alert_info("corsie: {length(lane)} campioni in {length(unique(lane))} librerie")
  list(asg = asg, s2i = s2i, lane = lane, elig = qc$eligible_clusters)
}

cli_h1("A3 — il deliverable da leggere")
dA3 <- readRDS(file.path(A3_POOL, "deliverable-annotato.rds"))
cli_alert_info("meta-analisi: {nrow(dA3)}")
SA3 <- stato_produzione(A3_S3, A3_S2)
RA3 <- replica_dispatch(SA3$elig$cluster_id, SA3$asg, SA3$s2i, SA3$lane)

cli_h2("PROVA A — il registro degli scarti coincide con quello di produzione?")
prod <- readRDS(file.path(A3_POOL, "qc_report.rds"))$dispatch_drops
mia  <- RA3$scarti
norm <- function(x) { x <- x[order(x$cluster_id, x$study_id, x$treated_group, x$motivo,
                                   x$n_treated, x$n_control), ]; rownames(x) <- NULL; x }
pn <- norm(prod); mn <- norm(mia)
cli_alert_info("produzione: {nrow(pn)} scarti | replica: {nrow(mn)} scarti")
if (!isTRUE(all.equal(pn, mn, check.attributes = FALSE))) {
  print(table(pn$motivo)); print(table(mn$motivo))
  cli_abort("PROVA A FALLITA: la replica non riproduce il dispatch di produzione.")
}
cli_alert_success("PROVA A superata: {nrow(mn)} scarti identici, motivo per motivo.")

cli_h2("PROVA B — i confronti tenuti danno le stesse coppie cluster-studio del pool?")
psd <- unique(as.data.frame(read_parquet(file.path(A3_POOL, "per_study_de.parquet"),
                                         col_select = c("cluster_id", "study_id"))))
psd <- psd[psd$cluster_id %in% dA3$cluster_id, ]
ten <- RA3$tenuti[RA3$tenuti$cluster_id %in% dA3$cluster_id, ]
kp <- sort(paste(psd$cluster_id, psd$study_id))
km <- sort(unique(paste(ten$cluster_id, ten$study_id)))
cli_alert_info("per_study_de: {length(kp)} coppie | replica: {length(km)} coppie")
if (!identical(kp, km)) {
  cli_alert_danger("solo nel pool: {length(setdiff(kp,km))} | solo nella replica: {length(setdiff(km,kp))}")
  print(utils::head(setdiff(kp, km), 10)); print(utils::head(setdiff(km, kp), 10))
  cli_abort("PROVA B FALLITA.")
}
cli_alert_success("PROVA B superata: {length(kp)} coppie cluster-studio identiche.")
saveRDS(list(tenuti = ten, scarti = RA3$scarti), file.path(OUT, "dispatch-A3.rds"))

cli_h1("Riferimento v16b — per il giudizio comparativo")
dRIF <- readRDS(file.path(RIF_POOL, "deliverable-annotato.rds"))
cli_alert_info("meta-analisi: {nrow(dRIF)}")
SR <- stato_produzione(RIF_S3, RIF_S2)
RR <- replica_dispatch(SR$elig$cluster_id, SR$asg, SR$s2i, SR$lane)
prodR <- readRDS(file.path(RIF_POOL, "qc_report.rds"))$dispatch_drops
if (!isTRUE(all.equal(norm(prodR), norm(RR$scarti), check.attributes = FALSE)))
  cli_abort("PROVA A FALLITA sul riferimento.")
cli_alert_success("PROVA A superata sul riferimento: {nrow(RR$scarti)} scarti identici.")
psdR <- unique(as.data.frame(read_parquet(file.path(RIF_POOL, "per_study_de.parquet"),
                                          col_select = c("cluster_id", "study_id"))))
psdR <- psdR[psdR$cluster_id %in% dRIF$cluster_id, ]
tenR <- RR$tenuti[RR$tenuti$cluster_id %in% dRIF$cluster_id, ]
if (!identical(sort(paste(psdR$cluster_id, psdR$study_id)),
               sort(unique(paste(tenR$cluster_id, tenR$study_id)))))
  cli_abort("PROVA B FALLITA sul riferimento.")
cli_alert_success("PROVA B superata sul riferimento: {nrow(psdR)} coppie identiche.")
saveRDS(list(tenuti = tenR, scarti = RR$scarti), file.path(OUT, "dispatch-RIF.rds"))
cli_alert_success("Dispatch di entrambe le esecuzioni ricostruiti e validati.")
