# analysis/audit/2026-08-08-deframmentazione/20-cecita-e-perdita-in-keff.R
# ---------------------------------------------------------------------------
# Approfondimenti di misura, tutti read-only:
#
# 5b. `bracci_sotto_n_min` scomposto: trattato, controllo, entrambi. E' la causa
#     che scarta il 56,5% dei record dei candidati -- va detto DOVE si rompe.
# 5c. Quale ramo di `.lookup_cmp` risolve i record: match ESATTO oppure fallback
#     sull'indice di occorrenza a tre segmenti (fix F2 del 2026-08-02). Se il
#     fallback non venisse mai esercitato, lo strumento starebbe leggendo il dato
#     con lo strumento sbagliato.
# 5d. Doppia referenza sul deliverable: k_eff dello strumento contro
#     `k_effective` E contro `n_studi_poolati` (due colonne diverse).
# 3b. La perdita della dedup misurata in k_eff (gate) e non solo in studi
#     censiti: vincente da solo contro vincente+scartati.
#
# Uso: Rscript analysis/audit/2026-08-08-deframmentazione/20-cecita-e-perdita-in-keff.R
# ---------------------------------------------------------------------------
suppressMessages({devtools::load_all(".", quiet = TRUE); library(arrow)})
source("analysis/audit/2026-08-08-deframmentazione/10-strumento-keff.R")

STAGE3 <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
STAGE4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT    <- "analysis/audit/2026-08-08-deframmentazione"

cl    <- readRDS(file.path(STAGE3, "clusters.rds"))
asg   <- arrow::read_parquet(file.path(STAGE3, "assignments.parquet"))
cand  <- readRDS(file.path(OUT, "01-candidati-351.rds"))
deliv <- readRDS(file.path(STAGE4, "deliverable-annotato.rds"))
ctx   <- carica_contesto_keff(assignments = asg)
s2_idx <- simulomicsr:::.index_stage2_master(ctx$stage2_master)

# =========================================================================
cat("=== 5b. bracci_sotto_n_min scomposto ===\n")
n_min <- 2L
det <- list()
for (cid in cand$cluster_id) {
  for (rid in ctx$asg_by_clid[[cid]]) {
    p <- simulomicsr:::.split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2_idx, inherits = FALSE)) next
    study <- get(p$series_id, envir = s2_idx, inherits = FALSE)
    cmp <- simulomicsr:::.lookup_cmp(study, p$suffix)
    if (is.null(cmp)) next
    tg <- simulomicsr:::.lookup_rg(study, cmp$treated_group)
    cg <- simulomicsr:::.lookup_rg(study, cmp$control_group)
    if (is.null(tg) || is.null(cg)) next
    nt <- length(as.character(unlist(tg$sample_ids)))
    nc <- length(as.character(unlist(cg$sample_ids)))
    det[[length(det) + 1L]] <- data.frame(
      cluster_id = cid, record_id = rid, study_id = p$series_id,
      n_treated = nt, n_control = nc, stringsAsFactors = FALSE)
  }
}
det <- do.call(rbind, det)
det$lato_rotto <- with(det, ifelse(n_treated < n_min & n_control < n_min, "entrambi",
                            ifelse(n_treated < n_min, "solo_trattato",
                            ifelse(n_control < n_min, "solo_controllo", "nessuno"))))
cat(sprintf("record con comparison e gruppi risolti: %d\n", nrow(det)))
print(table(det$lato_rotto))
cat("\ndistribuzione n_treated dei record scartati:\n")
print(table(det$n_treated[det$lato_rotto != "nessuno"]))
cat("distribuzione n_control dei record scartati:\n")
print(table(det$n_control[det$lato_rotto != "nessuno"]))
cat(sprintf("\nrecord con un braccio a UN SOLO campione (n=1): %d su %d scartati\n",
            sum(det$lato_rotto != "nessuno" & (det$n_treated == 1L | det$n_control == 1L)),
            sum(det$lato_rotto != "nessuno")))
cat(sprintf("record con un braccio a ZERO campioni: %d\n",
            sum(det$n_treated == 0L | det$n_control == 0L)))
write.csv(det, file.path(OUT, "05b-bracci-per-record.csv"), row.names = FALSE)

# =========================================================================
cat("\n=== 5c. quale ramo di .lookup_cmp risolve i record ===\n")
ramo <- vapply(cand$cluster_id, function(cid) NA_character_, character(1))
tab <- list()
for (cid in cand$cluster_id) {
  for (rid in ctx$asg_by_clid[[cid]]) {
    p <- simulomicsr:::.split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2_idx, inherits = FALSE)) {
      tab[[length(tab) + 1L]] <- "series_assente"; next
    }
    study <- get(p$series_id, envir = s2_idx, inherits = FALSE)
    esatto <- any(vapply(study$comparisons,
                         function(c) identical(c$comparison_id, p$suffix), logical(1)))
    m <- regmatches(p$suffix, regexec("^(.*)__([0-9]+)$", p$suffix))[[1L]]
    ha_indice <- length(m) == 3L
    tab[[length(tab) + 1L]] <- if (esatto) "match_esatto" else if (ha_indice) {
      base <- m[2L]; idx <- as.integer(m[3L])
      hits <- Filter(function(c) identical(c$comparison_id, base), study$comparisons)
      if (idx >= 1L && idx <= length(hits)) "fallback_indice_ok" else "fallback_indice_fuori_range"
    } else "comparison_assente_senza_indice"
  }
}
tb <- table(unlist(tab))
print(tb)
cat(sprintf("record_id con terzo segmento numerico (schema v15): %d\n",
            sum(grepl("__[0-9]+$", unlist(ctx$asg_by_clid[cand$cluster_id])))))
write.csv(data.frame(ramo = names(tb), n = as.integer(tb)),
          file.path(OUT, "05c-rami-lookup-cmp.csv"), row.names = FALSE)

# =========================================================================
cat("\n=== 5d. doppia referenza sul deliverable ===\n")
mio <- read.csv(file.path(OUT, "02-keff-mio-351.csv"), stringsAsFactors = FALSE)
d2 <- merge(deliv[, c("cluster_id", "k_effective", "n_studi_poolati",
                      "n_studi_censiti", "k")],
            mio[, c("cluster_id", "k_eff_mio")], by = "cluster_id")
cat(sprintf("k_eff_mio == k_effective     : %d / %d\n",
            sum(d2$k_eff_mio == d2$k_effective), nrow(d2)))
cat(sprintf("k_eff_mio == n_studi_poolati : %d / %d\n",
            sum(d2$k_eff_mio == d2$n_studi_poolati), nrow(d2)))
cat(sprintf("k_effective == n_studi_poolati: %d / %d\n",
            sum(d2$k_effective == d2$n_studi_poolati), nrow(d2)))
cat("scarto k_eff_mio - n_studi_poolati:\n")
print(table(d2$k_eff_mio - d2$n_studi_poolati))
cat(sprintf("\nk censito (Stadio 3) >= k_eff su tutte le righe: %s\n",
            all(d2$k >= d2$k_eff_mio)))
cat("summary(k_censito - k_eff_mio) = quanto il gate dei controlli interni costa:\n")
print(summary(d2$k - d2$k_eff_mio))
write.csv(d2, file.path(OUT, "05d-doppia-referenza.csv"), row.names = FALSE)

# =========================================================================
cat("\n=== 3b. perdita della dedup misurata in k_eff ===\n")
sc <- read.csv(file.path(OUT, "01-scartati-dedup.csv"), stringsAsFactors = FALSE)
vinc <- sub(".*assorbito da ([^ ]+) .*", "\\1", sc$details)
insiemi <- c(
  setNames(as.list(vinc), paste0("solo_", vinc)),
  setNames(lapply(seq_along(vinc), function(i) c(vinc[i], sc$cluster_id[i])),
           paste0("fusi_", vinc)))
res <- keff_di_gruppi(insiemi, ctx)
res$vincente <- sub("^(solo|fusi)_", "", res$gruppo)
res$caso <- sub("_.*", "", res$gruppo)
w <- reshape(res[, c("vincente", "caso", "k_eff")], idvar = "vincente",
             timevar = "caso", direction = "wide")
names(w) <- c("cluster_vincente", "k_eff_solo_vincente", "k_eff_fusi")
w$guadagno_keff <- w$k_eff_fusi - w$k_eff_solo_vincente
w$cluster_scartato <- sc$cluster_id[match(w$cluster_vincente, vinc)]
w$entita <- cand$contrast_entity[match(w$cluster_vincente, cand$cluster_id)]
w$etichetta <- cand$canonical_name[match(w$cluster_vincente, cand$cluster_id)]
per <- read.csv(file.path(OUT, "03-perdita-dedup-per-chiave.csv"), stringsAsFactors = FALSE)
w$studi_persi_censiti <- per$studi_persi_davvero[match(w$cluster_vincente, per$cluster_vincente)]
print(w[order(-w$guadagno_keff),
        c("entita", "etichetta", "cluster_vincente", "cluster_scartato",
          "k_eff_solo_vincente", "k_eff_fusi", "guadagno_keff",
          "studi_persi_censiti")], row.names = FALSE)
cat(sprintf("\nguadagno k_eff TOTALE se la dedup non scartasse nulla: %d\n",
            sum(w$guadagno_keff)))
cat(sprintf("studi persi CENSITI (studies_in_cluster): %d -> in k_eff valgono %d\n",
            sum(w$studi_persi_censiti), sum(w$guadagno_keff)))
write.csv(w, file.path(OUT, "03b-perdita-dedup-in-keff.csv"), row.names = FALSE)

cat("\n== FINE 20-cecita-e-perdita-in-keff.R ==\n")
