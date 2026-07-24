# Catalogo dei verdetti del CENSIMENTO v7 su TUTTI i 150 poolabili k>=3.
#
# Giudice: Claude (audit INTERNO, mai dentro la pipeline), rubrica applicata a
# tutti i cluster: COERENTE = ogni contrasto elencato isola la STESSA entita',
# nello stesso verso, contro un controllo dello stesso tipo. Un solo studio con
# una variante minore (una combo isolata, un controllo di linea diversa) resta
# COERENTE con nota; >=2 studi discordi, o un contrasto che isola un'altra cosa,
# = INCOERENTE. Rubrica PIU' SEVERA di quella del censimento v6 (81%): i due
# numeri NON sono confrontabili fra loro, il confronto valido e' la chiusura
# uno-per-uno dei falliti catalogati in v6 (vedi FASE1-RESULT.md).
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v7-results.rds")); agg <- r$agg

FAIL <- c(
  "HGNC:11766||gain||vehicle_untreated"                  = "entita_estranea|Her/Lap (trastuzumab/lapatinib) dentro il cluster TGFB1",
  "NCBITaxon:10359||gain||vehicle_untreated"             = "clinico_vs_sperimentale|CMV viremia in pazienti + infezione MRC5 in vitro",
  "NCBITaxon:10407||gain||vehicle_untreated"             = "clinico_vs_sperimentale|stato HBV in HCC (clinico) + infezione epatociti in vitro",
  "NCBITaxon:1773||gain||vehicle_untreated"              = "co_infezione|M.tb da solo mescolato con M.tb+CMV",
  "NCBITaxon:12814||gain||vehicle_untreated"             = "co_infezione|RSV da solo mescolato con RSV+rhinovirus",
  "CHEBI:46345||gain||vehicle_untreated"                 = "controllo_incongruo|controllo 'total RNA' + linea 5-FU-resistente senza farmaco",
  "CHEBI:16412||gain||rpmi media"                        = "combo_non_catturata|'T3 and LPS' (T3 = 2 caratteri, sotto la soglia del rilevatore)",
  "CHEBI:230508||gain||vehicle_untreated"                = "combo_non_catturata|E2+OTX015; + un contrasto degenere OTX015-vs-OTX015",
  "CHEBI:44185||gain||vehicle_untreated_multi:disease+drug" = "disegno_misto|artrite+metotrexato vs sano: isola malattia E terapia insieme",
  "HGNC:2434||gain||vehicle_untreated"                   = "disegno_misto|polarizzazione M1-vs-M0 mescolata a stimolo GM-CSF",
  "STR:ptsd||gain||vehicle_untreated"                    = "disegno_misto|perturbazione dentro-PTSD mescolata a caso-controllo"
)

agg$verdetto <- ifelse(agg$ckey %in% names(FAIL), "INCOERENTE", "COERENTE")
agg$causa <- ifelse(agg$ckey %in% names(FAIL), sub("\\|.*$", "", FAIL[agg$ckey]), "")
agg$nota  <- ifelse(agg$ckey %in% names(FAIL), sub("^[^|]*\\|", "", FAIL[agg$ckey]), "")
agg <- agg |> arrange(verdetto, desc(k))
write.csv(agg, file.path(SC, "v7-census-verdicts.csv"), row.names = FALSE)

n <- nrow(agg); nc <- sum(agg$verdetto == "COERENTE")
cat(sprintf("=== CENSIMENTO v7 (TUTTI i cluster, nessun campione) ===\n"))
cat(sprintf("poolabili k>=3 : %d\n", n))
cat(sprintf("COERENTI       : %d (%.1f%%)\n", nc, 100 * nc / n))
cat(sprintf("INCOERENTI     : %d (%.1f%%)\n", n - nc, 100 * (n - nc) / n))
cat(sprintf("studi-slot coperti dai coerenti: %d su %d\n",
            sum(agg$k[agg$verdetto == "COERENTE"]), sum(agg$k)))
cat("\n-- coerenti per forza (k) --\n")
print(table(cut(agg$k[agg$verdetto == "COERENTE"], c(2, 4, 9, 19, Inf),
                labels = c("k=3-4", "k=5-9", "k=10-19", "k>=20"))))
cat("\n-- incoerenti per causa --\n"); print(table(agg$causa[agg$verdetto == "INCOERENTE"]))
cat("\n-- coerenti per classe --\n"); print(table(agg$cls[agg$verdetto == "COERENTE"]))

## FRAMMENTAZIONE: stessa entita' biologica spezzata in piu' cluster
cat("\n=== FRAMMENTAZIONE residua (costa k, NON coerenza) ===\n")
fr <- list(
  "LPS"          = c("CHEBI:16412||gain||vehicle_untreated", "CHEBI:16412||gain||rpmi media"),
  "SARS-CoV-2"   = c("NCBITaxon:2697049||gain||vehicle_untreated", "NAME:sars-cov-2||gain||vehicle_untreated"),
  "enzalutamide" = c("CHEBI:68534||gain||vehicle_untreated", "STR:enza||gain||vehicle_untreated"),
  "decitabina"   = c("CHEBI:50131||gain||vehicle_untreated", "STR:aza_cdr||gain||vehicle_untreated"),
  "nutlin"       = c("CHEBI:46742||gain||vehicle_untreated", "CHEBI:46741||gain||vehicle_untreated"),
  "R1881"        = c("CHEBI:379896||gain||vehicle_untreated", "CHEBI:379896||gain||ethanol"),
  "asma"         = c("STR:asthma||gain||vehicle_untreated", "STR:asthmatic||gain||vehicle_untreated"),
  "TGFB1"        = c("HGNC:11766||gain||vehicle_untreated", "STR:tgfb||gain||vehicle_untreated"),
  "ipossia"      = c("NAME:hypoxia||gain||normoxia", "STR:hypoxia||gain||normoxia", "NAME:hypoxia||gain||vehicle_untreated")
)
tot <- 0
for (nm in names(fr)) {
  kk <- agg[agg$ckey %in% fr[[nm]], ]
  if (nrow(kk) > 1) {
    tot <- tot + nrow(kk) - 1
    cat(sprintf("  %-13s %d cluster (k: %s) -> potenziale k unito ~%d\n", nm, nrow(kk),
                paste(kk$k, collapse = "+"), sum(kk$k)))
  }
}
cat(sprintf("cluster in eccesso per frammentazione: ~%d\n", tot))
cat("\nscritto v7-census-verdicts.csv\n")
