# P5 coherence Task 6b: diagnosi del gate di selezione (ADR-0022) e simulazione di
# un gate di coerenza. Il gate rem_group attuale (.identify_layer_a_clusters) e'
# PURAMENTE STRUTTURALE: level in {L2,L3,L4} + mode==group + method==rem_group +
# k_eff>=3 + dedup per entita'. ZERO check di coerenza di contrasto. Quantifichiamo
# quanti dei 184 poolati sono in realta' minestrone/degenere, e quanti passerebbero
# un gate di coerenza.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(dplyr) })
DIR <- "analysis/audit/2026-07-23-coherence"
df  <- readRDS(file.path(DIR, "cluster-verdicts.rds"))
d184 <- df[!is.na(df$dd_verdict), ]   # i 184 rem_group deep-dived

cat("=== GATE ATTUALE (ADR-0022, strutturale): ammette TUTTI i 184 ===\n")
cat("cluster ammessi al pooling dal gate strutturale: ", nrow(d184), "\n")
cat("contrast_verdict di quei 184:\n"); print(table(d184$contrast_verdict))
cat(sprintf("=> il gate strutturale ammette %d minestrone + %d degenere + %d uncertain (%.0f%% NON coerenti)\n",
  sum(d184$contrast_verdict=="minestrone"), sum(d184$contrast_verdict=="degenerate"),
  sum(d184$contrast_verdict=="uncertain"),
  100*mean(d184$contrast_verdict!="coherent")))

cat("\n=== GATE DI COERENZA PROPOSTO (simulazione) ===\n")
# porta 1: contrasto coerente (D2 one_contrast / control-omogeneo) E non-degenere
gate_contrast <- d184$contrast_verdict=="coherent" & d184$frac_degenerate==0
cat(sprintf("porta 1 [coerente + non-degenere]: %d / 184 passano\n", sum(gate_contrast, na.rm=TRUE)))
# porta 2 (AND multi-asse completo, scelta utente): + consistenza >= 0.5
cat(sprintf("porta 2 [porta1 + consistency>=0.5] (meta_analysis_valid): %d / 184 passano\n",
  sum(d184$meta_analysis_valid, na.rm=TRUE)))

cat("\n=== i cluster che sopravvivono (meta_analysis_valid) ===\n")
surv <- d184[which(d184$meta_analysis_valid), ]
if (nrow(surv)) print(surv[order(-surv$consistency_score),
  c("cluster_id","kind","canonical_name","k","n_resolved","n_control_types_semantic",
    "consistency_score","median_I2")], row.names=FALSE) else cat("(nessuno)\n")

# verdetto vetrina Layer B v10: i 9 showcase KEEP
showcase9 <- c("group_L4_c8600f54","group_L4_7b3e137b","group_L4_7059e6f2","group_L4_1f404c0b",
  "group_L4_eda28231","group_L4_b128b80d","group_L4_b6a3eabd","group_L4_274f387d","group_L4_c51b10c1")
cat("\n=== VERDETTO VETRINA LAYER B v10 (9 showcase KEEP) ===\n")
sc <- df[df$cluster_id %in% showcase9, ]
print(sc[, c("cluster_id","canonical_name","k","n_resolved","n_control_types_semantic",
  "frac_degenerate","consistency_score","dd_verdict","contrast_verdict","meta_analysis_valid")],
  row.names=FALSE)
cat(sprintf("\nshowcase coerenti (meta_analysis_valid): %d / 9\n", sum(sc$meta_analysis_valid, na.rm=TRUE)))
