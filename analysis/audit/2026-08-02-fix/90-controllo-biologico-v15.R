#!/usr/bin/env Rscript
# analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R
#
# LE META-ANALISI DI v15 HANNO SENSO BIOLOGICO?
#
# Il controllo non e' "l'I2 e' basso" o "il k e' alto": quelli dicono se il
# calcolo e' stabile, non se misura la cosa giusta. Il controllo vero e' se i
# geni che la letteratura da' per certi escono con il segno giusto, e se un
# ANTAGONISTA da' il segno OPPOSTO all'AGONISTA sugli STESSI geni — un controllo
# positivo e uno negativo nello stesso disegno, su gruppi costruiti
# separatamente e senza che nulla nella pipeline sappia che sono legati.
#
# I bersagli sono fissati QUI, dalla letteratura, PRIMA di guardare i risultati:
# scegliere i geni dopo aver visto i numeri sarebbe cercare conferme.
#
# Uso: POOL_DIR=<dir re-pool> Rscript analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R

suppressPackageStartupMessages({ library(arrow); library(cli); devtools::load_all(".", quiet = TRUE) })

pool_dir <- Sys.getenv("POOL_DIR", "")
if (!nzchar(pool_dir) || !dir.exists(pool_dir)) cli_abort("POOL_DIR mancante.")

D  <- readRDS(file.path(pool_dir, "deliverable-annotato.rds"))
cp <- as.data.frame(read_parquet(file.path(pool_dir, "cluster_pooled.parquet")))

# --- i bersagli attesi, dalla letteratura, dichiarati prima ---------------------
ATTESI <- list(
  list(ent = "CHEBI:16330",       nome = "DHT (agonista AR)",
       geni = c("KLK3","TMPRSS2","FKBP5","NKX3-1"), segno = +1),
  list(ent = "CHEBI:68534",       nome = "Enzalutamide (antagonista AR)",
       geni = c("KLK3","TMPRSS2","FKBP5","NKX3-1"), segno = -1),
  list(ent = "HGNC:11766",        nome = "TGF-beta1",
       geni = c("SERPINE1","CCN2","SMAD7","JUNB","TGFBI","COL1A1"), segno = +1),
  list(ent = "NCBITaxon:2697049", nome = "SARS-CoV-2",
       geni = c("IFIT1","ISG15","MX1","OAS1"), segno = +1),
  list(ent = "HGNC:5438",         nome = "IFN-gamma",
       geni = c("STAT1","GBP1","CXCL9","TAP1","IRF1"), segno = +1),
  list(ent = "CHEBI:16412",       nome = "LPS",
       geni = c("TNF","IL6","IL1B","CXCL8"), segno = +1),
  list(ent = "HGNC:5981",         nome = "IL17A (de-frammentato in v15)",
       geni = c("CXCL8","CCL20","CXCL1","LCN2"), segno = +1)
)

# ⚠️ CORRETTO 2026-08-10. Qui c'era `if ("gene_symbol" %in% names(cp)) "gene_symbol"`,
# cioe' il merge fra i due cluster avveniva sul SIMBOLO. ARCHS4 v2.5 ha 4.638
# simboli duplicati (paraloghi PAR/KIR/HLA), quindi il merge produceva un
# PRODOTTO CARTESIANO: fra i geni significativi ci sono 150 simboli duplicati nel
# DHT e 108 nell'enzalutamide. Effetto misurato: 1.441 righe invece di 1.299
# (+10,9%), e "1.408 di segno opposto" invece di 1.266. La direzione regge
# (97,7% contro 97,5%, Spearman -0,938 contro -0,939), il CONTEGGIO no.
# `gene_id` (Ensembl) e' l'asse su cui `.pool_rem_cluster` poola davvero (FASE E1).
# Stessa famiglia di errore gia' pagata due volte: §8 del 2026-07-31 e il forest
# del 2026-08-06.
gene_col <- "gene_id"
stopifnot(gene_col %in% names(cp))
# ⚠️ DUE COLONNE PER DUE USI DIVERSI (corretto il 2026-08-16). Il confronto
# DHT/enzalutamide deve usare `gene_id` (l'asse su cui il pooling lavora), ma i
# BERSAGLI attesi sono SIMBOLI (`STAT1`, `IFIT1`, `KLK3`...): cercarli in
# `gene_id` non trova mai niente. Dal 2026-08-10, quando `gene_col` e' passato a
# `gene_id` per chiudere il prodotto cartesiano, questo script ha stampato «non
# misurato» su OGNI bersaglio e concluso «0/0» -- cioe' ha smesso di controllare
# la biologia senza dirlo. Il gruppo veniva trovato (i `k` erano giusti), quindi
# l'esito sembrava un dato e non un guasto.
sym_col <- "gene_symbol"
stopifnot(sym_col %in% names(cp))
lfc_col  <- grep("^(logFC|estimate|beta)", names(cp), value = TRUE)[1]
fdr_col  <- grep("FDR", names(cp), value = TRUE)[1]
cli_alert_info("colonne usate: gene={gene_col} effetto={lfc_col} fdr={fdr_col}")

cli_h1("Controllo biologico -- v15")
# La guardia che mancava: se non si trova NESSUN bersaglio in NESSUN gruppo, la
# spiegazione non e' «la biologia non torna», e' che si sta cercando nella
# colonna sbagliata. Meglio fermarsi che stampare 0/0.
.trovati_totali <- 0L
tot_ok <- 0L; tot <- 0L
for (a in ATTESI) {
  r <- D[which(D$contrast_entity == a$ent), ]
  if (!nrow(r)) { cli_alert_warning("{a$nome}: ASSENTE dal deliverable"); next }
  sub <- cp[cp$cluster_id == r$cluster_id[1] & cp[[sym_col]] %in% a$geni, ]
  cli_h3(sprintf("%s -- k=%d, %d studi efficaci, n_sig=%d, coerenza=%s",
                 a$nome, r$k_effective[1], round(r$k_kish[1]), r$n_sig[1], r$coherence_verdict[1]))
  for (g in a$geni) {
    row <- sub[sub[[sym_col]] == g, ]
    if (!nrow(row)) { cat(sprintf("   %-9s non misurato\n", g)); next }
    .trovati_totali <- .trovati_totali + 1L
    lfc <- row[[lfc_col]][1]; fdr <- row[[fdr_col]][1]
    ok  <- sign(lfc) == a$segno && fdr < 0.05
    tot <- tot + 1L; tot_ok <- tot_ok + as.integer(ok)
    cat(sprintf("   %-9s %+6.2f  FDR %8.2e  %s\n", g, lfc, fdr,
                if (ok) "OK" else if (fdr >= 0.05) "non significativo" else "SEGNO SBAGLIATO"))
  }
}
if (.trovati_totali == 0L) {
  cli_abort(paste0("NESSUN bersaglio trovato in NESSUN gruppo: non e' un esito, ",
                   "e' un guasto dello strumento (colonna sbagliata, o ",
                   "`cluster_pooled` senza simboli). Fermarsi e guardare."))
}
cli_h2(sprintf("Bersagli attesi col segno giusto e significativi: %d/%d", tot_ok, tot))

# --- il controllo che vale doppio: agonista contro antagonista ------------------
cli_h2("DHT (agonista) CONTRO enzalutamide (antagonista), sugli stessi geni")
d <- D[D$contrast_entity == "CHEBI:16330", ]; e <- D[D$contrast_entity == "CHEBI:68534", ]
if (nrow(d) && nrow(e)) {
  gd <- cp[cp$cluster_id == d$cluster_id[1], ]; ge <- cp[cp$cluster_id == e$cluster_id[1], ]
  m <- merge(gd[, c(gene_col, lfc_col, fdr_col)], ge[, c(gene_col, lfc_col, fdr_col)],
             by = gene_col, suffixes = c("_dht","_enz"))
  sig <- m[m[[paste0(fdr_col,"_dht")]] < 0.05 & m[[paste0(fdr_col,"_enz")]] < 0.05, ]
  opp <- sign(sig[[paste0(lfc_col,"_dht")]]) != sign(sig[[paste0(lfc_col,"_enz")]])
  cat(sprintf("  geni significativi in ENTRAMBI: %d | di segno OPPOSTO: %d (%.1f%%)\n",
              nrow(sig), sum(opp), 100*mean(opp)))
  cat(sprintf("  correlazione di Spearman fra i due effetti: %.3f (atteso NEGATIVO)\n",
              suppressWarnings(cor(sig[[paste0(lfc_col,"_dht")]], sig[[paste0(lfc_col,"_enz")]],
                                   method = "spearman"))))
}

# --- quadro d'insieme -----------------------------------------------------------
cli_h2("Quadro d'insieme delle 214")
cat(sprintf("  meta-analisi           : %d\n", nrow(D)))
cat(sprintf("  con k >= 10            : %d\n", sum(D$k_effective >= 10, na.rm = TRUE)))
cat(sprintf("  geni significativi tot : %d\n", sum(D$n_sig, na.rm = TRUE)))
cat(sprintf("  I2 mediano             : %.1f\n", median(D$I2_med, na.rm = TRUE)))
cat(sprintf("  dominate da uno studio : %d (%.0f%%)\n", sum(D$dominato, na.rm = TRUE),
            100*mean(D$dominato, na.rm = TRUE)))
cat(sprintf("  meno di 2 studi eff.   : %d (%.0f%%)\n", sum(D$k_kish < 2, na.rm = TRUE),
            100*mean(D$k_kish < 2, na.rm = TRUE)))
cat(sprintf("  marcate incoerenti     : %d | coerenti %d | non lette (NA) %d\n",
            sum(D$coherence_verdict != "coherent", na.rm = TRUE),
            sum(D$coherence_verdict == "coherent", na.rm = TRUE),
            sum(is.na(D$coherence_verdict))))
