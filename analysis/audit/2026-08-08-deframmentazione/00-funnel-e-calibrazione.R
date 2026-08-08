# analysis/audit/2026-08-08-deframmentazione/00-funnel-e-calibrazione.R
# ---------------------------------------------------------------------------
# SCOUT DI MISURA — calibrazione dello strumento k_eff prima di qualsiasi
# simulazione di fusione. READ-ONLY: nessun re-pool, nessun tocco a R/.
#
# 1. Riproduce il funnel del gate rem_group su Stadio 3 v15 (atteso 351
#    candidati post-dedup).
# 2. Calcola k_eff col dispatch VERO per tutti i candidati e lo confronta con
#    la colonna `k_effective` del deliverable a 214 righe + con i 137
#    non_processable.
# 3. Misura quanto butta via la deduplica per entita'||direzione.
# 5. Controllo di cecita' dello strumento (limiti di lunghezza, record non
#    risolti categorizzati per causa).
#
# Il punto 4 (funzione riusabile) vive in 10-strumento-keff.R.
#
# Uso: Rscript analysis/audit/2026-08-08-deframmentazione/00-funnel-e-calibrazione.R
# ---------------------------------------------------------------------------
suppressMessages({devtools::load_all(".", quiet = TRUE); library(arrow)})

STAGE3 <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
STAGE4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT    <- "analysis/audit/2026-08-08-deframmentazione"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

cat("================================================================\n")
cat("PUNTO 1 — RIPRODUZIONE DEL FUNNEL\n")
cat("================================================================\n")

cl  <- readRDS(file.path(STAGE3, "clusters.rds"))
asg <- arrow::read_parquet(file.path(STAGE3, "assignments.parquet"))
cfg <- stage4_default_config()
cat(sprintf("clusters.rds: %d righe x %d colonne\n", nrow(cl), ncol(cl)))
cat(sprintf("assignments : %d righe\n", nrow(asg)))
cat(sprintf("deliverable_methods di default: %s\n",
            paste(cfg$deliverable_methods, collapse = ",")))
cat("mode nei cluster:\n"); print(table(cl$mode))

# --- il gate vero, condizione per condizione (nessun taglio silenzioso) -----
mega_strict_col <- simulomicsr:::.col_or_default(cl, "usable_mega_strict", FALSE)
kind_col        <- simulomicsr:::.col_or_default(cl, "kind_effective_resolved", NA_character_)
agent_col       <- simulomicsr:::.col_or_default(cl, "agent_id_resolved",       NA_character_)
excl_kinds <- cfg$rem_group$excluded_kinds %||% c("vehicle_only", "none", "")
min_k_raw  <- cfg$rem_group$k_eff_min %||% 3L

c_mode  <- cl$mode == "cgroup"
c_mega  <- !mega_strict_col
c_kind  <- !(kind_col %in% excl_kinds)
c_agent <- !is.na(agent_col) & nzchar(agent_col, keepNA = FALSE)
c_k     <- cl$k >= min_k_raw

funnel <- data.frame(
  passo = c("tutti i cluster", "mode==cgroup", "+ !usable_mega_strict",
            sprintf("+ kind non in {%s}", paste(excl_kinds, collapse = ",")),
            "+ agent_id_resolved non-NA e non-vuoto",
            sprintf("+ k >= %d  (= PRE-DEDUP)", min_k_raw)),
  n = c(nrow(cl), sum(c_mode), sum(c_mode & c_mega),
        sum(c_mode & c_mega & c_kind),
        sum(c_mode & c_mega & c_kind & c_agent),
        sum(c_mode & c_mega & c_kind & c_agent & c_k)),
  stringsAsFactors = FALSE)
funnel$scartati_a_questo_passo <- c(NA_integer_, diff(funnel$n))
print(funnel, row.names = FALSE)

pre_dedup <- cl[c_mode & c_mega & c_kind & c_agent & c_k, , drop = FALSE]
pre_dedup$method <- "rem_group"
n_pre <- nrow(pre_dedup)

dedup      <- simulomicsr:::.dedup_rem_group_by_entity(pre_dedup)
scartati   <- attr(dedup, "scartati")
n_post     <- nrow(dedup)

cat(sprintf("\nCGROUP che passano il gate PRIMA della dedup : %d\n", n_pre))
cat(sprintf("CANDIDATI post-dedup                        : %d  (attesi 351)\n", n_post))
cat(sprintf("scartati dalla dedup                        : %d\n", nrow(scartati)))
stopifnot(n_pre == n_post + nrow(scartati))
if (n_post != 351L) {
  cat(sprintf("!! ATTENZIONE: %d != 351 attesi. NON aggiusto: diagnostico sotto.\n", n_post))
} else {
  cat("   -> 351 RIPRODOTTO ESATTAMENTE\n")
}

# controprova: stessa cosa passando dalla funzione di produzione
layer_a <- simulomicsr:::.identify_layer_a_clusters(cl, cfg)
cat(sprintf("controprova .identify_layer_a_clusters(): %d righe, method=%s\n",
            nrow(layer_a), paste(unique(layer_a$method), collapse = ",")))
stopifnot(setequal(layer_a$cluster_id, dedup$cluster_id))
cat("   -> insieme di cluster_id IDENTICO alla mia riproduzione\n")

write.csv(funnel, file.path(OUT, "01-funnel-gate.csv"), row.names = FALSE)
saveRDS(dedup, file.path(OUT, "01-candidati-351.rds"))
write.csv(scartati, file.path(OUT, "01-scartati-dedup.csv"), row.names = FALSE)

# ===========================================================================
cat("\n================================================================\n")
cat("PUNTO 2 — CALIBRAZIONE DI k_eff SUI 214 VERI\n")
cat("================================================================\n")

cat("Carico il master Stadio 2...\n")
stage2_master <- simulomicsr:::.load_stage2_master(STAGE2)
cat(sprintf("studi nel master Stadio 2: %d\n", length(stage2_master)))

eligible <- data.frame(cluster_id = dedup$cluster_id, mode = "cgroup",
                       method = "rem_group", stringsAsFactors = FALSE)
cat("Dispatch sui candidati (funzione di produzione)...\n")
t0 <- Sys.time()
disp <- simulomicsr:::.build_group_rem_dispatch_from_stage3(
  eligible, asg, stage2_master, n_min = 2L)
cat(sprintf("dispatch: %d cluster con almeno un contrasto valido (%.1f s)\n",
            length(disp), as.numeric(difftime(Sys.time(), t0, units = "secs"))))

keff_of <- function(clid) {
  d <- disp[[clid]]
  if (is.null(d)) return(0L)
  length(unique(vapply(d, function(x) x$study_id, character(1))))
}
mio <- data.frame(cluster_id = dedup$cluster_id,
                  k_eff_mio  = vapply(dedup$cluster_id, keff_of, integer(1)),
                  k_censito  = dedup$k,
                  n_studi_censiti = dedup$n_studies,
                  entita     = dedup$contrast_entity,
                  direzione  = dedup$contrast_direction,
                  control_key = dedup$contrast_control_key,
                  stringsAsFactors = FALSE)
cat("distribuzione k_eff_mio sui candidati:\n"); print(summary(mio$k_eff_mio))
cat(sprintf("candidati con k_eff_mio >= 3 (gate): %d / %d\n",
            sum(mio$k_eff_mio >= 3L), nrow(mio)))
cat(sprintf("candidati con k_eff_mio < 3        : %d\n", sum(mio$k_eff_mio < 3L)))

# --- confronto coi 214 del deliverable -------------------------------------
deliv <- readRDS(file.path(STAGE4, "deliverable-annotato.rds"))
cat(sprintf("\ndeliverable: %d righe\n", nrow(deliv)))
cat(sprintf("cluster_id del deliverable presenti fra i candidati: %d / %d\n",
            sum(deliv$cluster_id %in% mio$cluster_id), nrow(deliv)))

cmp <- merge(deliv[, c("cluster_id", "k_effective", "n_studi_poolati",
                       "contrast_entity", "contrast_entity_label",
                       "contrast_direction", "contrast_control_key")],
             mio[, c("cluster_id", "k_eff_mio", "k_censito", "n_studi_censiti")],
             by = "cluster_id", all.x = TRUE)
cmp$scarto <- cmp$k_eff_mio - cmp$k_effective
cat(sprintf("\nrighe confrontabili: %d (NA nel join: %d)\n",
            sum(!is.na(cmp$scarto)), sum(is.na(cmp$scarto))))
cat(sprintf("COMBACIANO ESATTAMENTE (scarto == 0): %d / %d  (%.1f%%)\n",
            sum(cmp$scarto == 0L, na.rm = TRUE), nrow(cmp),
            100 * mean(cmp$scarto == 0L, na.rm = TRUE)))
cat("distribuzione dello scarto (k_eff_mio - k_effective):\n")
print(table(cmp$scarto, useNA = "ifany"))
cat("summary scarto:\n"); print(summary(cmp$scarto))

cat("\n--- i 15 scarti peggiori in valore assoluto ---\n")
worst <- cmp[order(-abs(cmp$scarto)), ]
print(head(as.data.frame(worst[, c("cluster_id", "contrast_entity_label",
                                  "contrast_direction", "k_effective",
                                  "k_eff_mio", "scarto", "k_censito")]), 15),
      row.names = FALSE)

cat("\n--- i tre controlli nominati ---\n")
tre <- c(TGFB1 = "cgroup_L5_2e16719f", LPS = "cgroup_L5_c548d053",
         `SARS-CoV-2` = "cgroup_L5_871ae09e")
atteso <- c(TGFB1 = 59L, LPS = 35L, `SARS-CoV-2` = 34L)
ctrl <- data.frame(
  nome = names(tre), cluster_id = unname(tre), atteso = unname(atteso),
  k_effective_deliverable = deliv$k_effective[match(tre, deliv$cluster_id)],
  k_eff_mio = mio$k_eff_mio[match(tre, mio$cluster_id)],
  stringsAsFactors = FALSE)
ctrl$scarto_vs_atteso <- ctrl$k_eff_mio - ctrl$atteso
print(ctrl, row.names = FALSE)

# --- i 137 non_processable -------------------------------------------------
np <- readRDS(file.path(STAGE4, "non_processable.rds"))
cat(sprintf("\nnon_processable: %d righe\n", nrow(np)))
np$reason_keff <- sub(".*k_eff=", "", np$reason)
np$k_eff_dichiarato <- suppressWarnings(as.integer(np$reason_keff))
np$k_eff_mio <- mio$k_eff_mio[match(np$cluster_id, mio$cluster_id)]
cat(sprintf("non_processable presenti fra i candidati: %d / %d\n",
            sum(!is.na(np$k_eff_mio)), nrow(np)))
np$scarto <- np$k_eff_mio - np$k_eff_dichiarato
cat("scarto (k_eff_mio - k_eff dichiarato nel reason):\n")
print(table(np$scarto, useNA = "ifany"))
cat("tabella incrociata: k_eff dichiarato (righe) x k_eff_mio (colonne)\n")
print(table(dichiarato = np$k_eff_dichiarato, mio = np$k_eff_mio, useNA = "ifany"))

# copertura totale: 214 + 137 = 351?
cat(sprintf("\nCOPERTURA: 214 deliverable + %d non_processable = %d; candidati = %d\n",
            nrow(np), nrow(deliv) + nrow(np), nrow(mio)))
orfani <- setdiff(mio$cluster_id, c(deliv$cluster_id, np$cluster_id))
cat(sprintf("candidati che NON sono ne' nel deliverable ne' nei non_processable: %d\n",
            length(orfani)))
if (length(orfani)) print(head(orfani, 20))

write.csv(mio, file.path(OUT, "02-keff-mio-351.csv"), row.names = FALSE)
write.csv(cmp[order(-abs(cmp$scarto)), ], file.path(OUT, "02-calibrazione-214.csv"),
          row.names = FALSE)
write.csv(np, file.path(OUT, "02-calibrazione-non-processable-137.csv"), row.names = FALSE)

# ===========================================================================
cat("\n================================================================\n")
cat("PUNTO 3 — QUANTO BUTTA VIA LA DEDUPLICA\n")
cat("================================================================\n")

# chiave di dedup, ricostruita con la stessa regola di .dedup_rem_group_by_entity
dedup_key <- function(df) {
  direction <- simulomicsr:::.col_or_default(df, "contrast_direction", NA_character_)
  direction[is.na(direction)] <- ""
  ce <- simulomicsr:::.col_or_default(df, "contrast_entity", NA_character_)
  ifelse(!is.na(ce) & nzchar(ce), paste0(ce, "||", direction),
         paste0(df$kind_effective_resolved, "||", df$agent_id_resolved, "||", direction))
}
pre_dedup$key <- dedup_key(pre_dedup)
vincente <- dedup$cluster_id
pre_dedup$ruolo <- ifelse(pre_dedup$cluster_id %in% vincente, "vincente", "scartato")

cat(sprintf("cluster pre-dedup: %d = %d vincenti + %d scartati\n",
            nrow(pre_dedup), sum(pre_dedup$ruolo == "vincente"),
            sum(pre_dedup$ruolo == "scartato")))
cat(sprintf("chiavi entita'||direzione distinte: %d\n", length(unique(pre_dedup$key))))
kt <- table(table(pre_dedup$key))
cat("cluster per chiave (1 = nessuna dedup):\n"); print(kt)

studi_di <- function(idx) unique(unlist(pre_dedup$studies_in_cluster[idx], use.names = FALSE))
keys_con_scarti <- unique(pre_dedup$key[pre_dedup$ruolo == "scartato"])
cat(sprintf("chiavi che perdono almeno un cluster: %d\n", length(keys_con_scarti)))

rows <- lapply(keys_con_scarti, function(k) {
  iw <- which(pre_dedup$key == k & pre_dedup$ruolo == "vincente")
  il <- which(pre_dedup$key == k & pre_dedup$ruolo == "scartato")
  sw <- studi_di(iw); sl <- studi_di(il)
  persi <- setdiff(sl, sw)
  data.frame(
    chiave = k,
    entita = pre_dedup$contrast_entity[iw][1],
    direzione = pre_dedup$contrast_direction[iw][1],
    cluster_vincente = pre_dedup$cluster_id[iw][1],
    control_key_vincente = pre_dedup$contrast_control_key[iw][1],
    n_cluster_scartati = length(il),
    cluster_scartati = paste(pre_dedup$cluster_id[il], collapse = ";"),
    control_key_scartati = paste(unique(pre_dedup$contrast_control_key[il]), collapse = ";"),
    k_vincente = pre_dedup$k[iw][1],
    studi_nel_vincente = length(sw),
    studi_negli_scartati = length(sl),
    studi_persi_davvero = length(persi),
    studi_persi_lista = paste(persi, collapse = ";"),
    stringsAsFactors = FALSE)
})
perdite <- do.call(rbind, rows)
perdite <- perdite[order(-perdite$studi_persi_davvero), ]

tot_scartati <- sum(pre_dedup$ruolo == "scartato")
studi_negli_scartati_tot <- length(studi_di(which(pre_dedup$ruolo == "scartato")))
cat(sprintf("\ncluster scartati dalla dedup                       : %d\n", tot_scartati))
cat(sprintf("somma studi_in_cluster degli scartati (con doppioni): %d\n",
            sum(vapply(pre_dedup$studies_in_cluster[pre_dedup$ruolo == "scartato"],
                       length, integer(1)))))
cat(sprintf("studi DISTINTI dentro gli scartati                 : %d\n",
            studi_negli_scartati_tot))
cat(sprintf("studi-slot persi DAVVERO (non nel vincente), somma per chiave: %d\n",
            sum(perdite$studi_persi_davvero)))
cat(sprintf("  di cui chiavi con perdita ZERO (pura duplicazione): %d / %d\n",
            sum(perdite$studi_persi_davvero == 0L), nrow(perdite)))
cat(sprintf("  chiavi con perdita > 0                            : %d\n",
            sum(perdite$studi_persi_davvero > 0L)))
cat("distribuzione studi_persi_davvero per chiave:\n")
print(table(perdite$studi_persi_davvero))

cat("\n--- i 15 casi con la perdita maggiore ---\n")
print(head(as.data.frame(perdite[, c("entita", "direzione", "control_key_vincente",
                                     "control_key_scartati", "n_cluster_scartati",
                                     "studi_nel_vincente", "studi_negli_scartati",
                                     "studi_persi_davvero")]), 15), row.names = FALSE)

write.csv(perdite, file.path(OUT, "03-perdita-dedup-per-chiave.csv"), row.names = FALSE)
write.csv(pre_dedup[, c("cluster_id", "key", "ruolo", "contrast_entity",
                        "contrast_direction", "contrast_control_key", "k",
                        "n_studies", "level")],
          file.path(OUT, "03-pre-dedup-ruoli.csv"), row.names = FALSE)

# ===========================================================================
cat("\n================================================================\n")
cat("PUNTO 5 — CONTROLLO DI CECITA' DELLO STRUMENTO\n")
cat("================================================================\n")

# --- 5a. limiti di lunghezza sulle stringhe che uso -----------------------
len_report <- function(nome, x) {
  x <- x[!is.na(x)]
  if (!length(x)) return(NULL)
  n <- nchar(x)
  tb <- sort(table(n), decreasing = TRUE)
  data.frame(campo = nome, n_valori = length(x), min = min(n), mediana = median(n),
             max = max(n), n_al_max = sum(n == max(n)),
             lunghezza_piu_frequente = as.integer(names(tb)[1]),
             quanti_a_quella = as.integer(tb[1]),
             a_40 = sum(n == 40L), a_58 = sum(n == 58L),
             stringsAsFactors = FALSE)
}
asg_cg <- asg[asg$mode == "cgroup", ]
sp <- lapply(asg_cg$record_id, simulomicsr:::.split_record_id)
series_v <- vapply(sp, function(p) p$series_id, character(1))
suffix_v <- vapply(sp, function(p) p$suffix,    character(1))
lens <- do.call(rbind, list(
  len_report("cluster_id (candidati)",       dedup$cluster_id),
  len_report("contrast_entity (candidati)",  dedup$contrast_entity),
  len_report("contrast_direction",           dedup$contrast_direction),
  len_report("contrast_control_key",         dedup$contrast_control_key),
  len_report("canonical_name (candidati)",   dedup$canonical_name),
  len_report("anchor_key (candidati)",       dedup$anchor_key),
  len_report("record_id (assignments cgroup)", asg_cg$record_id),
  len_report("series_id estratto",           series_v),
  len_report("comparison_id estratto",       suffix_v)))
print(lens, row.names = FALSE)
cat("\nInterpretazione: un limite di troncamento si vede come PICCO di valori\n")
cat("esattamente al massimo. Colonne n_al_max / a_40 / a_58 sopra.\n")
write.csv(lens, file.path(OUT, "05-limiti-lunghezza.csv"), row.names = FALSE)

# --- 5b. record non risolti, categorizzati per causa ----------------------
# Rispecchia ESATTAMENTE i rami di .build_group_rem_dispatch_from_stage3;
# la coerenza e' verificata sotto confrontando i k_eff ricalcolati col dispatch.
s2_idx <- simulomicsr:::.index_stage2_master(stage2_master)
asg_by_clid <- split(asg$record_id, asg$cluster_id)

diagnostica_cluster <- function(cid, n_min = 2L) {
  rids <- asg_by_clid[[cid]]
  if (is.null(rids)) return(data.frame(cluster_id = cid, record_id = NA_character_,
                                       esito = "cluster_senza_assignments",
                                       study_id = NA_character_, stringsAsFactors = FALSE))
  seen <- character(0L)
  out <- vector("list", length(rids))
  for (j in seq_along(rids)) {
    rid <- rids[[j]]
    esito <- NA_character_; sid <- NA_character_
    parsed <- simulomicsr:::.split_record_id(rid)
    if (is.na(parsed$series_id)) {
      esito <- "record_id_non_splittabile"
    } else {
      sid <- parsed$series_id
      if (!exists(sid, envir = s2_idx, inherits = FALSE)) {
        esito <- "series_assente_in_stadio2"
      } else {
        study <- get(sid, envir = s2_idx, inherits = FALSE)
        cmp <- simulomicsr:::.lookup_cmp(study, parsed$suffix)
        if (is.null(cmp)) {
          esito <- "comparison_assente_nello_studio"
        } else {
          tg <- simulomicsr:::.lookup_rg(study, cmp$treated_group)
          cg <- simulomicsr:::.lookup_rg(study, cmp$control_group)
          if (is.null(tg) || is.null(cg)) {
            esito <- "replicate_group_assente"
          } else {
            nt <- length(as.character(unlist(tg$sample_ids)))
            nc <- length(as.character(unlist(cg$sample_ids)))
            if (nt < n_min || nc < n_min) {
              esito <- "bracci_sotto_n_min"
            } else {
              key <- paste0(sid, "||", cmp$treated_group)
              if (key %in% seen) esito <- "duplicato_stesso_braccio_trattato"
              else { seen <- c(seen, key); esito <- "RISOLTO" }
            }
          }
        }
      }
    }
    out[[j]] <- data.frame(cluster_id = cid, record_id = rid, esito = esito,
                           study_id = sid, stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

cat("Diagnostica record-per-record sui candidati...\n")
diag <- do.call(rbind, lapply(dedup$cluster_id, diagnostica_cluster))
cat(sprintf("record esaminati (assignments dei %d candidati): %d\n",
            nrow(dedup), nrow(diag)))
tb <- sort(table(diag$esito), decreasing = TRUE)
esiti <- data.frame(esito = names(tb), n = as.integer(tb),
                    pct = round(100 * as.integer(tb) / nrow(diag), 2),
                    stringsAsFactors = FALSE)
print(esiti, row.names = FALSE)
cat(sprintf("\nPERCENTUALE DI RECORD RISOLTI: %.2f%% (%d / %d)\n",
            100 * mean(diag$esito == "RISOLTO"), sum(diag$esito == "RISOLTO"),
            nrow(diag)))

# controllo di coerenza: la diagnostica deve ridare gli stessi k_eff del dispatch
keff_diag <- tapply(diag$study_id[diag$esito == "RISOLTO"],
                    diag$cluster_id[diag$esito == "RISOLTO"],
                    function(z) length(unique(z)))
chk <- data.frame(cluster_id = dedup$cluster_id,
                  k_dispatch = mio$k_eff_mio,
                  k_diag = as.integer(keff_diag[dedup$cluster_id]),
                  stringsAsFactors = FALSE)
chk$k_diag[is.na(chk$k_diag)] <- 0L
cat(sprintf("coerenza diagnostica vs dispatch: %d / %d identici (differenze: %d)\n",
            sum(chk$k_dispatch == chk$k_diag), nrow(chk),
            sum(chk$k_dispatch != chk$k_diag)))
if (any(chk$k_dispatch != chk$k_diag)) print(chk[chk$k_dispatch != chk$k_diag, ])

# quanti cluster perdono studi per ciascuna causa
per_causa <- aggregate(list(n_record = diag$record_id),
                       by = list(esito = diag$esito), FUN = length)
per_causa$n_cluster_toccati <- vapply(per_causa$esito, function(e)
  length(unique(diag$cluster_id[diag$esito == e])), integer(1))
per_causa$n_studi_distinti <- vapply(per_causa$esito, function(e)
  length(unique(na.omit(diag$study_id[diag$esito == e]))), integer(1))
cat("\n--- per causa: record, cluster toccati, studi distinti ---\n")
print(per_causa[order(-per_causa$n_record), ], row.names = FALSE)

write.csv(diag, file.path(OUT, "05-diagnostica-record.csv"), row.names = FALSE)
write.csv(esiti, file.path(OUT, "05-esiti-risoluzione.csv"), row.names = FALSE)
write.csv(per_causa, file.path(OUT, "05-cause-per-cluster.csv"), row.names = FALSE)
write.csv(chk, file.path(OUT, "05-coerenza-diag-vs-dispatch.csv"), row.names = FALSE)

cat("\n== FINE 00-funnel-e-calibrazione.R ==\n")
