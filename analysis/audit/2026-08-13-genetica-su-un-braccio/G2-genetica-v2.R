# ⚠️ IL PRIMO RILEVATORE (G1) ERA CIECO, e l'ha detto il suo stesso caso di
# accettazione: zero delta di classe `genetic` in tutto il deliverable, mentre
# nelle 214 ci sono SEI gruppi il cui `kind` e' genetico (3 knockdown, 2
# knockout, 1 sovraespressione) e negli 11.536 cgroup sono 3.948.
#
# LA CAUSA, letta nel codice: `.ca_classify_key()` classifica il NOME DEL CAMPO,
# non il contenuto. Uno studio che scrive `perturbation=shTP53` finisce in classe
# **drug**, perche' "perturbation" sta nella lista dei nomi-di-campo del farmaco.
# La manipolazione genetica si nasconde sotto un nome di campo generico.
#
# G2 usa il rilevatore DI PRODUZIONE `.rp_has_genetic_marker()`
# (R/stage3-row-pairing.R), che guarda il TESTO e ha gia' pagato i suoi falsi
# allarmi: i pattern sh/si/sg valgono solo seguiti da maiuscola, perche' in
# minuscolo catturano "single", "sigmoid", "significant" (21 falsi misurati).
# Non se ne scrive uno nuovo: e' la lezione del 2026-07-27.
#
# LA REGOLA: la genetica e' IL CONTRASTO se compare su un braccio e non
# sull'altro. Se compare su tutti e due e' il CONTESTO (entrambi i bracci in un
# fondo knockout), e non e' cio' che si sta misurando.
#
# CASI DI ACCETTAZIONE, depositati prima dell'esito:
#   A1. il gruppo TNF `cgroup_L5_d9e23e09` deve avere ZERO membri a contrasto
#       genetico (48 etichette lette a mano: proteina esogena vs veicolo).
#   A2. i SEI gruppi con `kind` genetico devono risultare a contrasto genetico.
#       Se non lo sono, il rilevatore e' cieco di nuovo e il risultato non vale.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-genetica-su-un-braccio"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"

del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
s2  <- readRDS(file.path("analysis/audit/2026-08-12-corsie", "s2.rds"))
idx <- simulomicsr:::.index_stage2_master(s2)
asg <- asg[asg$cluster_id %in% del$cluster_id, ]

cat("=== CONTROLLO DEL RILEVATORE su casi noti (positivi e negativi) ===\n")
pos <- c("shTP53", "siRNA against MYC", "CRISPR KO clone 3", "MYC overexpression",
         "lentiviral vector expressing GFP", "dTAG-13 degron", "sgRNA targeting EGFR",
         "TP53 knockdown", "empty vector control")
neg <- c("simvastatin 10uM", "sirolimus", "single cell suspension", "serum depletion",
         "shear stress", "sitagliptin", "silica particles", "TNF-alpha 10ng/ml",
         "wild-type strain", "significant response", "sigmoid colon")
for (x in pos) { r <- simulomicsr:::.rp_has_genetic_marker(x)
  cat(sprintf("  [%s] POS %s\n", if (r) "OK  " else "CIECO", x)) }
for (x in neg) { r <- simulomicsr:::.rp_has_genetic_marker(x)
  cat(sprintf("  [%s] NEG %s\n", if (!r) "OK  " else "FALSO ALLARME", x)) }

testo <- function(rg) {
  fl <- rg$factor_levels
  v <- if (length(fl)) vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L)) else character(0)
  paste(c(rg$label_human %||% "", v), collapse = " ; ")
}
righe <- list()
for (i in seq_len(nrow(asg))) {
  p <- simulomicsr:::.split_record_id(asg$record_id[i])
  if (is.na(p$series_id) || !exists(p$series_id, envir = idx, inherits = FALSE)) next
  st <- get(p$series_id, envir = idx, inherits = FALSE)
  cmp <- simulomicsr:::.lookup_cmp(st, p$suffix)
  if (is.null(cmp)) next
  tg <- simulomicsr:::.lookup_rg(st, cmp$treated_group)
  cg <- simulomicsr:::.lookup_rg(st, cmp$control_group)
  if (is.null(tg) || is.null(cg)) next
  tt <- testo(tg); ct <- testo(cg)
  gt <- simulomicsr:::.rp_has_genetic_marker(tt)
  gc_ <- simulomicsr:::.rp_has_genetic_marker(ct)
  righe[[length(righe) + 1L]] <- data.frame(
    cluster_id = asg$cluster_id[i], study_id = p$series_id,
    gen_trattato = gt, gen_controllo = gc_,
    stato = if (gt && gc_) "contesto" else if (gt || gc_) "CONTRASTO_GENETICO" else "trattamento",
    trattato = substr(tt, 1, 78), controllo = substr(ct, 1, 52),
    stringsAsFactors = FALSE)
}
M <- do.call(rbind, righe)
cat("\nmembri:", nrow(M), "\n"); print(table(M$stato))

cat("\n=== ACCETTAZIONE ===\n")
tnf <- M[M$cluster_id == "cgroup_L5_d9e23e09", ]
cat("  A1 gruppo TNF: membri", nrow(tnf), "| a contrasto genetico:",
    sum(tnf$stato == "CONTRASTO_GENETICO"), "(atteso 0)\n")
gen6 <- del$cluster_id[grepl("^genetic", del$kind_effective_resolved)]
for (cc in gen6) {
  z <- M[M$cluster_id == cc, ]
  cat(sprintf("  A2 %s (%s): membri %d | a contrasto genetico %d\n", cc,
      del$kind_effective_resolved[del$cluster_id == cc], nrow(z),
      sum(z$stato == "CONTRASTO_GENETICO")))
}

per <- lapply(split(M, M$cluster_id), function(z) data.frame(
  cluster_id = z$cluster_id[1], n = nrow(z),
  n_gen = sum(z$stato == "CONTRASTO_GENETICO"),
  n_trt = sum(z$stato == "trattamento"),
  n_ctx = sum(z$stato == "contesto"), stringsAsFactors = FALSE))
P <- do.call(rbind, per)
P$misto <- P$n_gen > 0L & P$n_trt > 0L
P <- merge(P, del[, c("cluster_id", "contrast_entity_label", "contrast_direction",
                      "kind_effective_resolved", "k_effective", "n_sig")], by = "cluster_id")
cat("\n=== ESITO SU TUTTE E 214 ===\n")
cat("gruppi con SOLO contrasti genetici:", sum(P$n_gen > 0 & P$n_trt == 0), "\n")
cat("gruppi con SOLO trattamenti:", sum(P$n_gen == 0), "\n")
cat("GRUPPI MISTI (genetica + trattamento):", sum(P$misto), "su", nrow(P), "\n\n")
if (any(P$misto)) {
  Q <- P[P$misto, ]; Q <- Q[order(-Q$k_effective), ]
  print(Q[, c("cluster_id", "contrast_entity_label", "contrast_direction",
              "kind_effective_resolved", "k_effective", "n", "n_gen", "n_trt")],
        row.names = FALSE)
}
saveRDS(list(M = M, P = P), file.path(SC, "G2-genetica.rds"))
write.csv(P, file.path(SC, "G2-gruppi.csv"), row.names = FALSE)
write.csv(M, file.path(SC, "G2-membri.csv"), row.names = FALSE)
cat("\nscritto.\n")
