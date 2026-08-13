# D2 — Il confine del marcatore genetico, misurato sui DATI VERI col codice di
# produzione (non su fixture: una regola che passa da script a pacchetto perde il
# vocabolario per strada, e' gia' successo il 2026-07-27).
#
# ACCETTAZIONE 1 (deliverable): esattamente 3 confronti con la genetica su un
#   braccio solo, in cgroup_L5_37942548 (ATRA) e cgroup_L5_35d1be10 (Nutlin-3a).
#   Se ne escono di piu', lo strumento e' sbagliato: ci si ferma e si leggono.
# ACCETTAZIONE 2 (corpus intero): il cambio va misurato su TUTTI i confronti,
#   non solo sul deliverable — il re-cluster gira su tutto. Si contano i cambi
#   nelle DUE direzioni: marcatore che si accende (l'intento) e marcatore che si
#   spegne (il costo di KO/KD case-sensitive).
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-rerun-prep"
OLD <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"

# ---- il marcatore VECCHIO, ricopiato tale e quale dal commit precedente ------
CS_OLD <- "\\b(sh|si|sg)[A-Z][A-Za-z0-9]{1,}\\b"
CI_OLD <- paste0("knock-?down|knock-?out|\\bko\\b|\\bkd\\b|crispr|cas9|transgen(e|ic)|",
                 "over-?express|\\bshrna\\b|\\bsirna\\b|\\bsgrna\\b|\\bgrna\\b|",
                 "empty vector|vector control|silenc|lentivir|\\bdegron\\b|\\bdtag\\b|\\bmaid\\b")
marker_old <- function(x) {
  s <- simulomicsr:::.rp_normalize_separators(x)
  grepl(CS_OLD, s, perl = TRUE) || grepl(CI_OLD, tolower(s), perl = TRUE)
}
marker_new <- simulomicsr:::.rp_has_genetic_marker
# controllo dello STRUMENTO di confronto: sui 5 casi noti il vecchio dice FALSE
stopifnot(!marker_old("p63shRNA"), !marker_old("A549siEGFR"),
          !marker_old("MCF7 RELA KO2"), marker_old("shTP53"),
          marker_new("p63shRNA"), !marker_new("Kd measurement"))

s2 <- readRDS(file.path(OLD, "s2.rds"))
idx <- simulomicsr:::.index_stage2_master(s2)
lab <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
flj <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";")
}

# ---- tutti i confronti del corpus ------------------------------------------
righe <- list()
for (study in s2) {
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    righe[[length(righe) + 1L]] <- data.frame(
      series_id = study$series_id, cmp_id = cmp$comparison_id %||% NA_character_,
      tl = lab(tg, cmp$treated_group), cl = lab(cg, cmp$control_group),
      tfl = flj(tg), cfl = flj(cg), stringsAsFactors = FALSE)
  }
}
M <- do.call(rbind, righe)
cat("confronti nel corpus:", nrow(M), "| studi:", length(unique(M$series_id)), "\n")

u <- unique(c(M$tl, M$cl))
mo <- vapply(u, marker_old, logical(1)); mn <- vapply(u, marker_new, logical(1))
cat("etichette distinte:", length(u),
    "| marcatore si ACCENDE su", sum(mn & !mo), "| si SPEGNE su", sum(!mn & mo), "\n")
sp <- u[!mn & mo]
if (length(sp)) { cat("\n  --- le etichette che PERDONO il marcatore (tutte) ---\n")
  for (x in head(sp, 40)) cat("   ", substr(x, 1, 110), "\n") }
ac <- u[mn & !mo]
cat("\n  --- un campione di quelle che lo ACQUISTANO ---\n")
for (x in head(ac, 15)) cat("   ", substr(x, 1, 110), "\n")

M$a_old <- vapply(seq_len(nrow(M)), function(i) marker_old(M$tl[i]) != marker_old(M$cl[i]), logical(1))
M$a_new <- vapply(seq_len(nrow(M)), function(i) marker_new(M$tl[i]) != marker_new(M$cl[i]), logical(1))
cat("\nasimmetria (solo marcatore, senza le esenzioni): vecchia", sum(M$a_old),
    "| nuova", sum(M$a_new), "| cambiati", sum(M$a_old != M$a_new), "\n")
saveRDS(M, file.path(SC, "D2-corpus.rds"))

# ---- ACCETTAZIONE 1: il deliverable, con la REGOLA INTERA -------------------
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
asg <- asg[asg$cluster_id %in% del$cluster_id, ]
ent_of <- setNames(del$contrast_entity, del$cluster_id)
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
  cls <- d$dominant_class
  ent <- unname(ent_of[asg$cluster_id[i]])
  out[[length(out) + 1L]] <- data.frame(
    cluster_id = asg$cluster_id[i], study_id = p$series_id,
    cls = cls %||% NA_character_, entity = ent %||% NA_character_,
    asim_old = simulomicsr:::.rp_genetic_asymmetry(tl, cl, cls, ent) &&
               (marker_old(tl) != marker_old(cl)),
    asim_new = simulomicsr:::.rp_genetic_asymmetry(tl, cl, cls, ent),
    trattato = substr(tl, 1, 90), controllo = substr(cl, 1, 90),
    stringsAsFactors = FALSE)
}
D <- do.call(rbind, out)
cat("\n=== ACCETTAZIONE 1 (deliverable) ===\n")
cat("confronti letti:", nrow(D), "(atteso 4726)\n")
z <- D[D$asim_new, ]
cat("genetica su un braccio solo, regola INTERA:", nrow(z), "(atteso 3) in",
    length(unique(z$cluster_id)), "gruppi (atteso 2)\n")
for (i in seq_len(nrow(z)))
  cat(sprintf("   %s  %s\n     T: %s\n     C: %s\n", z$cluster_id[i], z$study_id[i],
              z$trattato[i], z$controllo[i]))
cat("con la regola VECCHIA:", sum(D$asim_old), "(atteso 0)\n")
write.csv(z, file.path(SC, "D2-un-braccio-solo.csv"), row.names = FALSE)
saveRDS(D, file.path(SC, "D2-deliverable.rds"))
