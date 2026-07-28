#!/usr/bin/env Rscript
# Bundle di lettura per TUTTI i gruppi del deliverable v12 (dati VERI, non
# simulazione). Un bundle per gruppo: identita' del contrasto + ogni confronto
# tenuto (studio, trattato => controllo, coi factor_levels dei due bracci).
#
# Serve a rispondere a UNA domanda per gruppo: tutti i confronti che contiene
# misurano lo STESSO contrasto? Se si', il gruppo genera una meta-analisi
# difendibile. La forza (k, I2) si riporta accanto, non e' il gate.
#
# Stesso metro del censimento 2026-07-27, cosi' i numeri sono confrontabili:
# in particolare il TESSUTO non entra nella chiave e non e' di per se' un
# difetto (ADR-0025 §Negative, da dichiarare nei Methods).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V12 <- Sys.getenv("V13_DIR", "")
if (!nzchar(V12)) {
  cand <- sort(list.dirs("analysis/p4-output", recursive = FALSE))
  cand <- cand[grepl("stage3-v13-", cand)]
  if (!length(cand)) stop("nessuna dir stage3-v13- trovata; passare V13_DIR")
  V12 <- tail(cand, 1L)
}
OUT <- "analysis/audit/2026-07-28-censimento-v13"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

cat(format(Sys.time()), "- carico cluster v12...\n")
cl  <- readRDS(file.path(V12, "clusters.rds"))
sel <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
stopifnot(nrow(sel) > 0L, all(sel$method == "rem_group"))
cat("  deliverable:", nrow(sel), "gruppi\n")

cat(format(Sys.time()), "- carico assignments...\n")
asg <- arrow::read_parquet(file.path(V12, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% sel$cluster_id, ]
cat("  record assegnati ai gruppi del deliverable:", nrow(asg), "\n")

# --- mappa <series>__<comparison_id> -> etichette dei due bracci --------------
cat(format(Sys.time()), "- carico Stadio 2 e costruisco le etichette...\n")
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))),
        collapse = ";")
}
lab_of <- function(rg, gid) {
  if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
}
for (study in s2) {
  sid <- study$series_id
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", sid, cmp$comparison_id)
    if (!rid %in% need) next
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(rid, list(study = sid,
                     tl = lab_of(tg, cmp$treated_group),
                     cl = lab_of(cg, cmp$control_group),
                     tfl = fl_of(tg), cfl = fl_of(cg),
                     ct = cmp$control_type %||% NA_character_,
                     nt = length(tg$sample_ids), nc = length(cg$sample_ids)),
           envir = lab)
  }
}
cat("  etichette risolte:", length(ls(lab)), "/", length(need), "\n")

# --- confronto con le chiavi gia' censite il 2026-07-27 ----------------------
# Si rileggono SOLO i gruppi il cui insieme di membri e' cambiato piu' i nuovi:
# un gruppo con gli stessi identici record ha lo stesso verdetto: e' una verifica
# di identita', non un campionamento.
stati <- readRDS("analysis/audit/2026-07-28-censimento-v13/deliverable-v13.rds")
cen <- data.frame(ckey = character(0))
sel$ckey <- paste0(sel$contrast_entity, "||", sel$contrast_direction, "||",
                   sel$contrast_control_key)
sel$stato <- stati$stato[match(sel$cluster_id, stati$cluster_id)]
sel <- sel[!is.na(sel$stato) & sel$stato != "invariato", ]
sel$gia_letto <- sel$stato == "CAMBIATO"
cat("da rileggere:", nrow(sel), "gruppi\n")

# --- scrittura del bundle ----------------------------------------------------
sel <- sel[order(-sel$k, sel$ckey), ]
zz <- file(file.path(OUT, "bundle-v13-compatto.txt"), open = "wt")
sink(zz)
cat("BUNDLE COMPATTO DEI GRUPPI DEL DELIVERABLE v12 —", nrow(sel), "gruppi (dati VERI)\n")
cat("sorgente:", V12, "\n")
cat("Domanda per ogni gruppo: TUTTI i confronti misurano lo STESSO contrasto?\n")
cat("Confronti DEDUPLICATI per (studio, trattato, controllo); xN = quante volte ricorre.\n")
cat("[LETTO] = chiave gia' censita il 2026-07-27; [NUOVO] = mai letta.\n")
for (i in seq_len(nrow(sel))) {
  rid <- asg$record_id[asg$cluster_id == sel$cluster_id[i]]
  ee <- lapply(rid, function(r) get0(r, envir = lab, inherits = FALSE))
  ee <- ee[!vapply(ee, is.null, logical(1))]
  if (!length(ee)) next
  key <- vapply(ee, function(e) paste(e$study, e$tl, e$cl, sep = "\u0001"), character(1))
  tb <- table(key)
  uk <- names(tb)
  cat("\n\n=============================================================\n")
  cat(sprintf("[%03d/%03d] %s   %s\n", i, nrow(sel), sel$ckey[i],
              if (sel$gia_letto[i]) "[CAMBIATO]" else "[NUOVO]"))
  cat(sprintf("  nome: %s | k=%d studi | %d confronti (%d distinti) | n=%d campioni\n",
              sel$canonical_name[i] %||% "", sel$k[i], length(ee), length(uk), sel$n_total[i]))
  for (u in uk) {
    p <- strsplit(u, "\u0001", fixed = TRUE)[[1]]
    m <- if (tb[[u]] > 1L) sprintf(" x%d", tb[[u]]) else ""
    cat(sprintf("   %-11s %-58s => %s%s\n", p[1], substr(p[2], 1, 58), substr(p[3], 1, 40), m))
  }
}
sink(); close(zz)

write.csv(sel[, c("cluster_id", "ckey", "contrast_entity", "contrast_direction",
                  "contrast_control_key", "k", "n_total", "canonical_name", "gia_letto")],
          file.path(OUT, "indice-v13.csv"), row.names = FALSE)
cat(format(Sys.time()), "- scritti bundle-v12.txt e indice-v13.csv (", nrow(sel), "gruppi )\n")
cat("gia letti:", sum(sel$gia_letto), "| nuovi:", sum(!sel$gia_letto), "\n")
