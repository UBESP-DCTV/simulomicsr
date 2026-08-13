# D2b — L'effetto VERO del confine allargato: sui confronti POOLATI, non su
# quelli assegnati. (Lezione del 2026-08-10: il censito non e' il poolato.)
#
# Tre domande, tre misure:
#   1. i confronti segnalati passano il gate `n_min`? Solo quelli contano;
#   2. quanto costa il case-SENSITIVE di KO/KD: quali etichette perdono il
#      marcatore, e quanti confronti poolati ne sono toccati;
#   3. l'effetto sul `k` dei gruppi del deliverable.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-rerun-prep"
OLD <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"

CS_OLD <- "\\b(sh|si|sg)[A-Z][A-Za-z0-9]{1,}\\b"
CI_OLD <- paste0("knock-?down|knock-?out|\\bko\\b|\\bkd\\b|crispr|cas9|transgen(e|ic)|",
                 "over-?express|\\bshrna\\b|\\bsirna\\b|\\bsgrna\\b|\\bgrna\\b|",
                 "empty vector|vector control|silenc|lentivir|\\bdegron\\b|\\bdtag\\b|\\bmaid\\b")
marker_old <- function(x) {
  s <- simulomicsr:::.rp_normalize_separators(x)
  grepl(CS_OLD, s, perl = TRUE) || grepl(CI_OLD, tolower(s), perl = TRUE)
}
marker_new <- simulomicsr:::.rp_has_genetic_marker
stopifnot(marker_new("LNCaP-abl shKDM3B1 t=7"), marker_new("p63shRNA"),
          !marker_new("Kd measurement"), !marker_old("p63shRNA"))

del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
asg <- asg[asg$cluster_id %in% del$cluster_id, ]
s2  <- readRDS(file.path(OLD, "s2.rds")); idx <- simulomicsr:::.index_stage2_master(s2)
lk  <- readRDS(file.path(SC, "D1-lookup.rds"))
ent_of <- setNames(del$contrast_entity, del$cluster_id)
lab <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
flj <- function(rg) { fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";") }

out <- list()
for (i in seq_len(nrow(asg))) {
  p <- simulomicsr:::.split_record_id(asg$record_id[i])
  if (is.na(p$series_id) || !exists(p$series_id, envir = idx, inherits = FALSE)) next
  st <- get(p$series_id, envir = idx, inherits = FALSE)
  cmp <- simulomicsr:::.lookup_cmp(st, p$suffix); if (is.null(cmp)) next
  tg <- simulomicsr:::.lookup_rg(st, cmp$treated_group)
  cg <- simulomicsr:::.lookup_rg(st, cmp$control_group)
  if (is.null(tg) || is.null(cg)) next
  tl <- lab(tg, cmp$treated_group); cl <- lab(cg, cmp$control_group)
  d <- simulomicsr:::.ca_delta(flj(tg), flj(cg))
  ent <- unname(ent_of[asg$cluster_id[i]])
  trt <- as.character(unlist(tg$sample_ids)); ctr <- as.character(unlist(cg$sample_ids))
  out[[length(out) + 1L]] <- data.frame(
    cluster_id = asg$cluster_id[i], study_id = p$series_id,
    treated_group = cmp$treated_group,
    asim_new = simulomicsr:::.rp_genetic_asymmetry(tl, cl, d$dominant_class, ent),
    asim_old = simulomicsr:::.rp_genetic_asymmetry(tl, cl, d$dominant_class, ent) &&
               (marker_old(tl) != marker_old(cl)),
    mark_perso_t = marker_old(tl) && !marker_new(tl),
    mark_perso_c = marker_old(cl) && !marker_new(cl),
    n_bio_t = .n_biological(trt, lk), n_bio_c = .n_biological(ctr, lk),
    trattato = substr(tl, 1, 95), controllo = substr(cl, 1, 95),
    stringsAsFactors = FALSE)
}
D <- do.call(rbind, out)
D$poolato <- D$n_bio_t >= 2L & D$n_bio_c >= 2L
cat("confronti assegnati:", nrow(D), "| poolati (n_min + corsie):", sum(D$poolato), "\n\n")

cat("=== 1. GENETICA SU UN BRACCIO SOLO ===\n")
z <- D[D$asim_new, ]
cat("segnalati:", nrow(z), "| di questi POOLATI:", sum(z$poolato), "\n")
for (i in seq_len(nrow(z)))
  cat(sprintf("  %s %s %s  n_bio %d vs %d\n    T: %s\n    C: %s\n",
              ifelse(z$poolato[i], "[POOLATO]", "[fuori]"), z$cluster_id[i], z$study_id[i],
              z$n_bio_t[i], z$n_bio_c[i], z$trattato[i], z$controllo[i]))
cat("con la regola vecchia:", sum(D$asim_old), "\n")
write.csv(z, file.path(SC, "D2-un-braccio-solo.csv"), row.names = FALSE)

cat("\n=== 2. COSTO DEL CASE-SENSITIVE (marcatore perso) ===\n")
pp <- D[(D$mark_perso_t | D$mark_perso_c), ]
cat("confronti con almeno un'etichetta che perde il marcatore:", nrow(pp),
    "| poolati:", sum(pp$poolato), "\n")
cat("di questi, quelli in cui la PERDITA cambia il verdetto di asimmetria:\n")
camb <- pp[pp$asim_new != (marker_old(pp$trattato) != marker_old(pp$controllo)), ]
cat("  ", nrow(camb), "\n")
if (nrow(pp)) for (i in seq_len(min(nrow(pp), 25)))
  cat(sprintf("   %s  T: %s | C: %s\n", ifelse(pp$poolato[i], "[POOL]", "[fuori]"),
              substr(pp$trattato[i], 1, 60), substr(pp$controllo[i], 1, 60)))

cat("\n=== 3. EFFETTO SUL k DEI GRUPPI ===\n")
P <- D[D$poolato, ]
k_ora  <- tapply(P$study_id, P$cluster_id, function(x) length(unique(x)))
Q <- P[!P$asim_new, ]
k_dopo <- tapply(Q$study_id, Q$cluster_id, function(x) length(unique(x)))
cid <- names(k_ora); k2 <- ifelse(is.na(k_dopo[cid]), 0L, k_dopo[cid])
cambiati <- cid[k_ora != k2]
for (c0 in cambiati)
  cat(sprintf("  %s  k %d -> %d  (%s)\n", c0, k_ora[c0], k2[c0],
              del$canonical_name[match(c0, del$cluster_id)]))
cat("gruppi che scendono sotto k>=3:", sum(k2 < 3L), "\n")
saveRDS(D, file.path(SC, "D2b-deliverable.rds"))
