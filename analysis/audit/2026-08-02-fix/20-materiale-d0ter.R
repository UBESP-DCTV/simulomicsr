#!/usr/bin/env Rscript
# 20-materiale-d0ter.R --- prepara il materiale per la FASE D0ter ESTESA.
#
# PERCHE'. La correzione della dedup (Task 5) fa rientrare nel deliverable 49
# gruppi che il censimento del 2026-07-28 non ha MAI visto: erano stati
# cancellati a monte da una chiave sbagliata, e nessun essere umano li ha letti.
# Senza un verdetto, `.annotate_coherence()` li marca `coherent` per difetto,
# con una `coherence_source` che attesta una rilettura mai avvenuta. Decisione
# dell'utente del 2026-08-03: si leggono.
#
# COSA PRODUCE. Un bundle di testo, un gruppo per blocco, con TUTTE le etichette
# dei membri PER INTERO.
#
# ⚠️ LE ETICHETTE NON SI TRONCANO. Il 2026-07-30 un bundle di censimento
# tagliava a 58/40 caratteri e un verdetto fu dato su mezza frase (il pezzo
# tagliato era «and IFN-alpha for 18 hours»). Ampiezza dell'errore: 8,6% dei
# confronti, 52% dei gruppi. Qui si stampa tutto, e si misura quanto e' lunga
# l'etichetta piu' lunga: se qualcosa tocca un limite, si vede.
#
# COSA NON PUO' FARE. La composizione definitiva dei gruppi si conosce solo
# DOPO il re-cluster v15. Di questi 49, pero', solo quelli toccati dalla
# de-frammentazione cambiano: gli altri hanno in v15 la stessa composizione che
# hanno in v13, e si possono leggere adesso. Lo script marca quali sono quali.
#
# Uso: Rscript analysis/audit/2026-08-02-fix/20-materiale-d0ter.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13  <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT  <- "analysis/audit/2026-08-02-fix"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

cl  <- readRDS(file.path(V13, "clusters.rds"))
asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
cfg <- stage4_default_config()

# --- chi rientra: la differenza fra la dedup vecchia e quella nuova ----------
dedup_vecchia <- function(x) {
  if (nrow(x) == 0L) return(x)
  d <- simulomicsr:::.col_or_default(x, "contrast_direction", NA_character_)
  d[is.na(d)] <- ""
  ent <- paste0(x$kind_effective_resolved, "||", x$agent_id_resolved, "||", d)
  o <- order(ent, -x$k, -x$n_total, -x$level, x$cluster_id)
  y <- x[o, , drop = FALSE]
  y[!duplicated(ent[o]), , drop = FALSE]
}
prima <- testthat::with_mocked_bindings(
  .dedup_rem_group_by_entity = dedup_vecchia, .package = "simulomicsr",
  simulomicsr:::.identify_layer_a_clusters(cl, cfg))
dopo  <- simulomicsr:::.identify_layer_a_clusters(cl, cfg)

rientrano <- setdiff(dopo$cluster_id, prima$cluster_id)
sel <- dopo[dopo$cluster_id %in% rientrano, , drop = FALSE]
sel <- sel[order(-sel$k), , drop = FALSE]
cat("gruppi che rientrano con la dedup corretta:", nrow(sel), "\n")
cat("distribuzione k: ");  print(table(sel$k))

# --- le etichette VERE dei membri, per intero -------------------------------
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
lab <- new.env(hash = TRUE, parent = emptyenv())
for (st in s2) {
  if (length(st$comparisons) == 0L) next
  rgl <- stats::setNames(st$replicate_groups,
    vapply(st$replicate_groups, function(g) g$group_id, character(1L)))
  lof <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
  n <- new.env(hash = TRUE, parent = emptyenv())
  for (cmp in st$comparisons) {
    k <- cmp$comparison_id
    i <- (get0(k, envir = n, ifnotfound = 0L)) + 1L; assign(k, i, envir = n)
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(sprintf("%s__%s__%d", st$series_id, k, i),
           list(t = lof(tg, cmp$treated_group), c = lof(cg, cmp$control_group)),
           envir = lab)
    # anche la forma a due segmenti: v13 la usa
    assign(sprintf("%s__%s", st$series_id, k),
           list(t = lof(tg, cmp$treated_group), c = lof(cg, cmp$control_group)),
           envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

# --- quali cambieranno con v15 ----------------------------------------------
# Solo i gruppi bersaglio della de-frammentazione cambiano composizione.
toccati <- c("HGNC:11766", "HGNC:5981")

f <- file.path(OUT, "20-bundle-d0ter-49-gruppi.txt")
con <- file(f, "w"); ncs <- integer(0)
for (i in seq_len(nrow(sel))) {
  r <- sel[i, ]
  rid <- asg$record_id[asg$cluster_id == r$cluster_id]
  writeLines(c(strrep("=", 100),
    sprintf("### GRUPPO %d/%d  %s", i, nrow(sel), r$cluster_id),
    sprintf("entita'      : %s", r$contrast_entity),
    sprintf("verso        : %s   controllo: %s", r$contrast_direction, r$contrast_control_key),
    sprintf("k (studi)    : %d   membri: %d", r$k, length(rid)),
    sprintf("kind/anchor  : %s / %s  <-- l'anchor SBAGLIATO che lo faceva cancellare",
            r$kind_effective_resolved, r$agent_id_resolved),
    sprintf("composizione in v15: %s",
            if (r$contrast_entity %in% toccati) "CAMBIA (bersaglio della de-frammentazione): rileggere DOPO v15"
            else "INVARIATA rispetto a v13: leggibile adesso"),
    "", "-- membri (etichette INTERE, trattato  <<VS>>  controllo) --"), con)
  for (x in rid) {
    L <- get0(x, envir = lab, inherits = FALSE)
    if (is.null(L)) { writeLines(sprintf("  [%s] (etichette non trovate)", x), con); next }
    ncs <- c(ncs, nchar(L$t), nchar(L$c))
    writeLines(sprintf("  %s\n      %s\n   <<VS>> %s", x, L$t, L$c), con)
  }
  writeLines("", con)
}
close(con)

cat("\nscritto:", f, "\n")
cat("[strumento] etichetta piu' lunga:", if (length(ncs)) max(ncs) else 0, "caratteri\n")
for (lim in c(40, 58, 64, 100, 128, 255))
  cat("            == ", lim, ": ", sum(ncs == lim), "\n", sep = "")
cat("[strumento] se un limite ha un picco, le etichette sono TRONCATE a monte: fermarsi.\n")

utils::write.csv(
  data.frame(cluster_id = sel$cluster_id, contrast_entity = sel$contrast_entity,
             contrast_direction = sel$contrast_direction,
             contrast_control_key = sel$contrast_control_key, k = sel$k,
             anchor_sbagliato = sel$agent_id_resolved,
             cambia_in_v15 = sel$contrast_entity %in% toccati,
             stringsAsFactors = FALSE),
  file.path(OUT, "20-indice-d0ter-49.csv"), row.names = FALSE)
cat("scritto: 20-indice-d0ter-49.csv\n")
