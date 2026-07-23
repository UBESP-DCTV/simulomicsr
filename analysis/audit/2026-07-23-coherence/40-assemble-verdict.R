# P5 coherence Task 6a: assembla il verdetto per-cluster unendo
#   - segnali A/C (per-cluster-signals.rds, 13.287)          [Fase 0/A/C]
#   - consistenza (consistency-pooled.csv, 714 poolati)      [Fase B, ADR-0021]
#   - deep-dive LLM D1/D2 (deepdive-verdicts/verdict-*.jsonl, 184 rem_group)  [Fase D]
#
# Due assi ONESTI e SEPARATI (la domanda dell'utente e' "stesso contrasto?"):
#   (1) contrast_verdict = {coherent | minestrone | degenerate | uncertain}
#       = "questi studi misurano lo STESSO contrasto?" (D2 dove disponibile, altrimenti
#         deterministico A/C). E' la risposta diretta alla domanda dello studio.
#   (2) consistency_score/median_I2/pi_frac_excl0 = "quanto segnale?" (solo poolati).
#   (3) meta_analysis_valid (AND multi-asse, scelta utente) = TRUE solo se
#       contrast_verdict=="coherent" E non-degenere E consistency_score>=0.5.
#       = "cosa sopravvive come meta-analisi difendibile".
#
# confidence: high (184 deep-dived) | medium (poolato con consistenza, no deep-dive) |
#             low (solo deterministico, spesso bassa copertura).

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)   # per .coherence_verdict / .meta_analysis_valid
  library(dplyr); library(jsonlite); library(readr)
})

DIR <- "analysis/audit/2026-07-23-coherence"
CONS_OK <- 0.5   # soglia consistenza per meta_analysis_valid (documentata nel finding)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

sig  <- readRDS(file.path(DIR, "per-cluster-signals.rds"))
cons <- read_csv(file.path(DIR, "consistency-pooled.csv"), show_col_types = FALSE)

# deep-dive: concatena tutti i verdict-*.jsonl
vfiles <- list.files(file.path(DIR, "deepdive-verdicts"), pattern = "^verdict-.*\\.jsonl$",
                     full.names = TRUE)
dd <- if (length(vfiles)) {
  do.call(rbind, lapply(vfiles, function(f)
    do.call(rbind, lapply(readLines(f), function(l) {
      x <- fromJSON(l)
      data.frame(cluster_id = x$cluster_id,
                 n_control_types_semantic = x$n_control_types_semantic %||% NA_integer_,
                 dd_verdict = x$contrast_verdict %||% NA_character_,
                 dd_reason  = x$reason %||% NA_character_, stringsAsFactors = FALSE)
    }))))
} else data.frame(cluster_id = character(0))

cat(sprintf("signals=%d  consistenza=%d  deepdive=%d\n", nrow(sig), nrow(cons), nrow(dd)))

df <- sig |>
  left_join(cons |> select(cluster_id, method, consistency_score, median_I2, pi_frac_excl0),
            by = "cluster_id") |>
  left_join(dd, by = "cluster_id")
df$pooled <- !is.na(df$method)

# --- asse (1): contrast_verdict --- (usa l'helper testato R/stage3-coherence.R, D2 autoritativo)
df$contrast_verdict <- vapply(seq_len(nrow(df)), function(i)
  simulomicsr:::.coherence_verdict(
    list(n_resolved = df$n_resolved[i], frac_degenerate = df$frac_degenerate[i],
         n_control_types = df$n_control_types[i]),
    deepdive = df$dd_verdict[i]),
  character(1))

# confidence
df$confidence <- ifelse(!is.na(df$dd_verdict), "high",
                 ifelse(df$pooled & !is.na(df$consistency_score), "medium", "low"))

# --- asse (3): meta_analysis_valid (AND multi-asse) --- (helper testato)
df$meta_analysis_valid <- mapply(simulomicsr:::.meta_analysis_valid,
  df$contrast_verdict, df$frac_degenerate, df$consistency_score,
  MoreArgs = list(cons_ok = CONS_OK))

saveRDS(df, file.path(DIR, "cluster-verdicts.rds"))

# --- summary committabili ---
cat("\n=== contrast_verdict su TUTTI i 13.287 ===\n"); print(table(df$contrast_verdict, useNA="ifany"))
cat("\n=== contrast_verdict x confidence ===\n"); print(table(df$contrast_verdict, df$confidence, useNA="ifany"))
cat("\n=== 184 rem_group poolati (deep-dived, HIGH conf): il DELIVERABLE ===\n")
d184 <- df[!is.na(df$dd_verdict), ]
print(table(d184$contrast_verdict))
cat(sprintf("meta_analysis_valid (coherent + non-degenere + consistency>=%.1f): %d / %d\n",
    CONS_OK, sum(d184$meta_analysis_valid, na.rm=TRUE), nrow(d184)))

# distribuzione per kind e per fascia k (contrast_verdict)
df$kband <- cut(df$k, breaks=c(1,2,3,5,10,20,Inf), labels=c("2","3","4-5","6-10","11-20",">20"))
by_kind <- as.data.frame.matrix(table(df$kind, df$contrast_verdict))
by_kband <- as.data.frame.matrix(table(df$kband, df$contrast_verdict))
write.csv(cbind(kind=rownames(by_kind), by_kind), file.path(DIR,"verdict-by-kind.csv"), row.names=FALSE)
write.csv(cbind(kband=rownames(by_kband), by_kband), file.path(DIR,"verdict-by-kband.csv"), row.names=FALSE)
# summary compatto committabile del deliverable
readr::write_csv(d184 |> select(cluster_id, kind, canonical_name, k, n_resolved,
  n_control_types, n_control_types_semantic, frac_degenerate, consistency_score, median_I2,
  pi_frac_excl0, dd_verdict, contrast_verdict, meta_analysis_valid, dd_reason),
  file.path(DIR,"deliverable-184-verdicts.csv"))
cat("\nscritti: cluster-verdicts.rds, verdict-by-kind.csv, verdict-by-kband.csv, deliverable-184-verdicts.csv\n")
