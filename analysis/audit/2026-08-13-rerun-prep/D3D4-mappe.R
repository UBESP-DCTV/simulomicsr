# D3+D4 — Le due mappe accese, misurate sui DATI VERI col gate di produzione.
#
# ACCETTAZIONE POSITIVA: TNF 32 -> 38 studi poolati; ipossia 25 -> 33;
#   SARS-CoV-2 34 -> 36; infigratinib nasce a k=3.
# ACCETTAZIONE NEGATIVA (piu' importante): NESSUN'ALTRA fusione oltre a quelle
#   decise. In particolare `uninfected` NON deve fondersi per RSV, ATRA, HSV-1,
#   epatite C, KSHV, Zika: la voce e' condizionata a SARS-CoV-2 e questo va
#   verificato sui dati, non sul sorgente.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-rerun-prep"
OLD <- "analysis/audit/2026-08-12-corsie"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"

cl  <- readRDS(file.path(S3D, "clusters.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
s2  <- readRDS(file.path(OLD, "s2.rds"))
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
lk  <- readRDS(file.path(SC, "D1-lookup.rds"))

cfg_on  <- stage4_default_config()
cfg_off <- cfg_on
cfg_off$rem_group$entity_canonical  <- NULL
cfg_off$rem_group$control_canonical <- NULL
cat("mappe accese: entita", length(cfg_on$rem_group$entity_canonical),
    "| controlli", length(cfg_on$rem_group$control_canonical), "\n")

sel <- function(cfg) {
  a <- .identify_layer_a_clusters(cl, cfg)
  a[a$method == "rem_group", , drop = FALSE]
}
A_off <- sel(cfg_off); A_on <- sel(cfg_on)
cat("candidati rem_group: spento", nrow(A_off), "| acceso", nrow(A_on), "\n")

fus <- attr(.identify_layer_a_clusters(cl, cfg_on), "fusioni")
if (is.null(fus)) {
  rg <- cl[cl$mode == "cgroup" & !.col_or_default(cl, "usable_mega_strict", FALSE) &
           !(.col_or_default(cl, "kind_effective_resolved", NA) %in%
             cfg_on$rem_group$excluded_kinds) &
           !is.na(.col_or_default(cl, "agent_id_resolved", NA)), ]
  rg$method <- "rem_group"
  d <- .dedup_rem_group_by_entity(rg,
        entity_canonical = cfg_on$rem_group$entity_canonical,
        control_canonical = cfg_on$rem_group$control_canonical)
  fus <- attr(d, "fusioni")
}
cat("\n=== FUSIONI APPLICATE ===\n"); print(nrow(fus))
if (nrow(fus)) print(fus[, c("cluster_id_assorbito", "cluster_id_vincente",
                             "entity_vincente_prima", "control_key_vincente_prima",
                             "k_vincente_prima", "k_dopo_fusione")])

# --- k_eff col dispatch di produzione, corsie ACCESE -------------------------
asg_by <- split(asg$record_id, asg$cluster_id)
keff <- function(cids, n_min = 2L) {
  rid <- unlist(asg_by[intersect(cids, names(asg_by))], use.names = FALSE)
  if (!length(rid)) return(0L)
  synth <- data.frame(record_id = rid, cluster_id = "__X__", stringsAsFactors = FALSE)
  el <- data.frame(cluster_id = "__X__", mode = "cgroup", method = "rem_group",
                   stringsAsFactors = FALSE)
  d <- .build_group_rem_dispatch_from_stage3(el, synth, s2, n_min = n_min,
                                             lane_lookup = lk)
  if (!length(d)) return(0L)
  length(unique(vapply(d[["__X__"]], function(x) x$study_id, character(1))))
}
keff0 <- function(cids, n_min = 2L) {
  rid <- unlist(asg_by[intersect(cids, names(asg_by))], use.names = FALSE)
  if (!length(rid)) return(0L)
  synth <- data.frame(record_id = rid, cluster_id = "__X__", stringsAsFactors = FALSE)
  el <- data.frame(cluster_id = "__X__", mode = "cgroup", method = "rem_group",
                   stringsAsFactors = FALSE)
  d <- .build_group_rem_dispatch_from_stage3(el, synth, s2, n_min = n_min)
  if (!length(d)) return(0L)
  length(unique(vapply(d[["__X__"]], function(x) x$study_id, character(1))))
}
cat("\n=== k_eff PRIMA e DOPO le fusioni (corsie accese) ===\n")
if (nrow(fus)) {
  for (w in unique(fus$cluster_id_vincente)) {
    a <- fus$cluster_id_assorbito[fus$cluster_id_vincente == w]
    nm <- del$canonical_name[match(w, del$cluster_id)]
    cat(sprintf("  %-20s %-28s k_eff %2d -> %2d   (assorbe %s)\n", w,
                substr(ifelse(is.na(nm), A_on$contrast_entity[match(w, A_on$cluster_id)], nm), 1, 28),
                keff(w), keff(c(w, a)), paste(a, collapse = ",")))
  }
}
cat("\n=== k_eff con le corsie SPENTE (controllo) ===\n")
if (nrow(fus)) for (w in unique(fus$cluster_id_vincente)) {
  a <- fus$cluster_id_assorbito[fus$cluster_id_vincente == w]
  cat(sprintf("  %-20s k_eff %2d -> %2d\n", w, keff0(w), keff0(c(w, a))))
}
cat("\n=== I GRUPPI NOMINATI DALLA DECISIONE ===\n")
ent_col <- .col_or_default(A_on, "contrast_entity", NA_character_)
for (e in c("HGNC:11892", "STR:hypoxia", "NCBITaxon:2697049", "CHEBI:63451",
            "HGNC:6018", "HGNC:5977", "CHEBI:80240")) {
  k <- A_on$cluster_id[which(ent_col == e)]
  for (c0 in k) cat(sprintf("  %-20s %-22s k=%3d  k_eff=%2d  %s\n", e, c0,
                            A_on$k[A_on$cluster_id == c0], keff(c0),
                            ifelse(c0 %in% del$cluster_id, "nel 214", "NUOVO/fuori")))
}
saveRDS(list(off = A_off, on = A_on, fusioni = fus), file.path(SC, "D3D4-esito.rds"))
