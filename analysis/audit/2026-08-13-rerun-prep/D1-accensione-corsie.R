# D1 — L'INTERRUTTORE ACCESO, misurato sui DATI VERI col codice di produzione.
#
# Non basta che i test passino: il default e' un valore di configurazione, e la
# catena che lo consuma (config -> build_lane_library_lookup(h5_metadata) ->
# .build_group_rem_dispatch_from_stage3) va percorsa sui dati veri. Qui la
# corrispondenza NON viene passata a mano: si costruisce come la costruisce il
# build, leggendo `stage4_default_config()`.
#
# ACCETTAZIONE POSITIVA: 2.152 -> 2.146 entry, e i 6 cluster con `k` cambiato
#   sono ESATTAMENTE i 6 di 50-k-prima-dopo.csv.
# ACCETTAZIONE NEGATIVA: con il flag spento il dispatch e' identico a quello di
#   produzione (2.152 entry, stessi GSM). Se non lo e', il cambio ha toccato
#   qualcosa che non doveva.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-rerun-prep"
OLD <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"

del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
cl  <- readRDS(file.path(S3D, "clusters.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
s2_rds <- file.path(OLD, "s2.rds")
s2 <- if (file.exists(s2_rds)) readRDS(s2_rds) else {
  x <- jsonlite::stream_in(file("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"),
                           verbose = FALSE, simplifyVector = FALSE)
  saveRDS(x, s2_rds); x
}
elig <- cl[cl$cluster_id %in% del$cluster_id, ]; elig$method <- "rem_group"
stopifnot(nrow(elig) == nrow(del))

cfg <- stage4_default_config()
cat("config: collapse_technical_lanes =", cfg$rem_group$collapse_technical_lanes, "\n")
stopifnot(isTRUE(cfg$rem_group$collapse_technical_lanes))

# --- la corrispondenza, come la costruisce il build --------------------------
lk_rds <- file.path(SC, "D1-lookup.rds")
if (file.exists(lk_rds)) {
  lk <- readRDS(lk_rds)
} else {
  h5 <- "analysis/input/human_gene_v2.5.h5"
  H <- data.frame(
    geo_accession       = as.character(rhdf5::h5read(h5, "meta/samples/geo_accession")),
    title               = as.character(rhdf5::h5read(h5, "meta/samples/title")),
    series_id           = as.character(rhdf5::h5read(h5, "meta/samples/series_id")),
    characteristics_ch1 = as.character(rhdf5::h5read(h5, "meta/samples/characteristics_ch1")),
    source_name_ch1     = as.character(rhdf5::h5read(h5, "meta/samples/source_name_ch1")),
    stringsAsFactors = FALSE)
  rhdf5::h5closeAll()
  cat("H5:", nrow(H), "campioni\n")
  lk <- build_lane_library_lookup(H)
  saveRDS(lk, lk_rds)
}
cat("corsie: campioni mappati", length(lk), "| librerie", length(unique(lk)),
    "| candidate scartate", nrow(attr(lk, "scartate")), "\n")

n_min <- cfg$rem_group$n_min %||% 2L
disp_off <- .build_group_rem_dispatch_from_stage3(elig, asg, s2, n_min = n_min)
disp_on  <- .build_group_rem_dispatch_from_stage3(elig, asg, s2, n_min = n_min,
                                                  lane_lookup = lk)
e_off <- sum(vapply(disp_off, length, integer(1)))
e_on  <- sum(vapply(disp_on,  length, integer(1)))
cat("\nentry: spento", e_off, "| acceso", e_on, "| differenza", e_off - e_on, "\n")

k_of <- function(d) vapply(d, function(x)
  length(unique(vapply(x, function(e) e$study_id, character(1)))), integer(1))
k0 <- k_of(disp_off); k1 <- k_of(disp_on)
comuni <- intersect(names(k0), names(k1))
camb <- comuni[k0[comuni] != k1[comuni]]
persi <- setdiff(names(k0), names(k1))

atteso <- read.csv(file.path(OLD, "50-k-prima-dopo.csv"), stringsAsFactors = FALSE)
att6 <- sort(atteso$cluster_id[atteso$k_ora != atteso$k_dopo])
cat("\n=== ACCETTAZIONE POSITIVA ===\n")
cat("  cluster con k cambiato:", length(camb), "(atteso 6) | cluster persi:",
    length(persi), "\n")
cat("  insieme identico ai 6 attesi:", identical(sort(camb), att6), "\n")
for (cid in sort(camb))
  cat(sprintf("   %s  k %d -> %d  (%s)\n", cid, k0[cid], k1[cid],
              del$canonical_name[match(cid, del$cluster_id)]))
sotto <- names(k1)[k1 < 3L]
cat("  sotto k>=3 dopo il collasso:", paste(sotto, collapse = ", "),
    "->", paste(del$canonical_name[match(sotto, del$cluster_id)], collapse = ", "), "\n")
cat("  deliverable:", nrow(del), "->", nrow(del) - length(sotto), "\n")

cat("\n=== ACCETTAZIONE NEGATIVA (spento = come oggi) ===\n")
gsm_of <- function(d) sort(unlist(lapply(d, function(x) vapply(x, function(e)
  paste(e$study_id, paste(e$treated, collapse = ","), paste(e$control, collapse = ","),
        sep = "|"), character(1))), use.names = FALSE))
disp_null <- .build_group_rem_dispatch_from_stage3(elig, asg, s2, n_min = n_min,
                                                   lane_lookup = NULL)
cat("  spento == NULL, entry per entry e GSM per GSM:",
    identical(gsm_of(disp_off), gsm_of(disp_null)), "| entry", e_off, "(atteso 2152)\n")

saveRDS(list(k_off = k0, k_on = k1, cambiati = camb, entry_off = e_off,
             entry_on = e_on), file.path(SC, "D1-esito.rds"))
