#!/usr/bin/env Rscript
# 180-guadagno-dopo-il-gate.R --- se si fondessero i gruppi frammentati, quanti
# studi arriverebbero DAVVERO nel pool?
#
# La frammentazione si misura in studi-slot censiti, ma il gate dei controlli
# interni ne scarta il 43% (2.158 -> 1.234). Un guadagno di 14 studi-slot su
# TGF-beta1 non e' un guadagno di 14 studi poolati. Qui si usa la funzione di
# dispatch VERA — la stessa del run — sull'unione degli assignment, cosi' il
# numero e' quello che si otterrebbe, non una proporzione.
#
# Serve a decidere se il re-cluster ha contenuto scientifico. Non lo si suppone.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/180-guadagno-dopo-il-gate.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(cli) })

V13    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT    <- "analysis/audit/2026-07-31-layer-b-v13"

cl <- readRDS(file.path(V13, "clusters.rds"))
gr <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
s2 <- simulomicsr:::.load_stage2_master(STAGE2)

# Le fusioni candidate, con il giudizio di ammissibilita' scritto accanto.
# `STR:ifna` NON e' in lista: la stringa "IFNa" non dice se e' IFNA1 o IFNA2, e
# il rilevatore la aggancia a ENTRAMBI. Fonderla in uno dei due sarebbe un
# errore di identita' — la stessa classe che questo rework ha eliminato.
fusioni <- list(
  list(nome = "TGF-beta1", dest = "HGNC:11766", src = c("STR:tgfb", "STR:tgf_b"),
       giudizio = "AMMISSIBILE: il gruppo HGNC:11766 contiene GIA' membri etichettati solo 'TGF-beta'/'TGFbeta'; tenere fuori 'TGFb' e' un'incoerenza ortografica, non scientifica"),
  list(nome = "Glioblastoma", dest = "MeSH:D005909", src = "STR:glioblastoma",
       giudizio = "AMMISSIBILE: tutti e 6 i membri sono glioblastoma contro cervello normale"),
  list(nome = "IL17A", dest = "HGNC:5981", src = "STR:il17",
       giudizio = "DA DECIDERE: 'IL17' senza qualificatore e' IL-17A per convenzione forte, ma IL-17F esiste")
)

simula <- function(dest, src) {
  cid_dest <- gr$cluster_id[gr$contrast_entity == dest]
  cid_src  <- gr$cluster_id[gr$contrast_entity %in% src]
  meta <- gr[gr$cluster_id == cid_dest, ]
  meta$method <- "rem_group"

  a_dest <- asg[asg$cluster_id %in% cid_dest, ]
  a_un   <- asg[asg$cluster_id %in% c(cid_dest, cid_src), ]
  a_un$cluster_id <- cid_dest   # l'unione, sotto l'ID di destinazione

  d0 <- simulomicsr:::.build_group_rem_dispatch_from_stage3(meta, a_dest, s2, n_min = 2L)
  d1 <- simulomicsr:::.build_group_rem_dispatch_from_stage3(meta, a_un,  s2, n_min = 2L)
  n <- function(d) if (is.null(d[[cid_dest]])) 0L else
    length(unique(vapply(d[[cid_dest]], function(x) x$study_id, character(1L))))
  c(prima = n(d0), dopo = n(d1))
}

cli_h1("Guadagno reale, dopo il gate dei controlli interni")
righe <- list()
for (f in fusioni) {
  k_cens_dest <- gr$k[gr$contrast_entity == f$dest]
  k_cens_src  <- sum(gr$k[gr$contrast_entity %in% f$src])
  g <- simula(f$dest, f$src)
  cat(sprintf("\n%s (%s <- %s)\n", f$nome, f$dest, paste(f$src, collapse = " + ")))
  cat(sprintf("  censiti:  %2d -> %2d  (+%d)\n", k_cens_dest,
              k_cens_dest + k_cens_src, k_cens_src))
  cat(sprintf("  POOLATI:  %2d -> %2d  (+%d)   <- il numero che conta\n",
              g[["prima"]], g[["dopo"]], g[["dopo"]] - g[["prima"]]))
  cat(sprintf("  %s\n", f$giudizio))
  righe[[length(righe) + 1L]] <- data.frame(
    entita = f$nome, dest = f$dest, src = paste(f$src, collapse = " "),
    k_censito_prima = k_cens_dest, k_censito_dopo = k_cens_dest + k_cens_src,
    k_poolato_prima = g[["prima"]], k_poolato_dopo = g[["dopo"]],
    giudizio = f$giudizio, stringsAsFactors = FALSE)
}
tab <- do.call(rbind, righe)

cli_h2("Bilancio")
amm <- tab[!grepl("^DA DECIDERE", tab$giudizio), ]
cat(sprintf("  fusioni ammissibili: %d\n", nrow(amm)))
cat(sprintf("  studi POOLATI guadagnati: %d\n",
            sum(amm$k_poolato_dopo - amm$k_poolato_prima)))
cat(sprintf("  gruppi che cambierebbero composizione (da rileggere): %d\n", nrow(tab)))
cat(sprintf("  gruppi che sparirebbero (assorbiti): %d\n",
            sum(vapply(fusioni, function(f) length(f$src), integer(1L)))))

write.csv(tab, file.path(OUT, "guadagno-dopo-il-gate.csv"), row.names = FALSE)
cli_alert_success("Scritta guadagno-dopo-il-gate.csv")
