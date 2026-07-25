# Verdetti del censimento di coerenza, letti UNO PER UNO su bundle-gruppi.txt.
#
# Criterio (definizione utente 2026-07-24): un gruppo e' COERENTE se genera una
# meta-analisi difendibile, cioe' se tutti i confronti che contiene misurano lo
# STESSO contrasto. La forza (k, I2) si riporta accanto, non e' il gate.
#
# I verdetti qui sotto sono giudizi di lettura, non l'output di una regola: la
# regola che li produrrebbe automaticamente, dove esiste, e' indicata nel motivo.
suppressPackageStartupMessages(library(dplyr))
OUT <- "analysis/audit/2026-07-27-contrast-builder"
agg <- readRDS(file.path(OUT, "equivalenza-builder.rds"))$agg

# --- gruppi giudicati INCOERENTI (tutti gli altri sono coerenti) --------------
incoerenti <- tibble::tribble(
  ~entita,          ~motivo,
  "HGNC:2434",      paste("CSF2: due studi stimolano con GM-CSF contro mock, il terzo confronta",
                          "macrofagi M1 (GM-CSF + IFN-gamma) contro M0. La polarizzazione M1/M0 non",
                          "e' la stimolazione con GM-CSF: cambia anche IFN-gamma e il controllo e'",
                          "uno stato di differenziamento, non un veicolo. Gia' incoerente nel",
                          "censimento del 2026-07-25."),
  "STR:ptsd",       paste("PTSD: due studi sono caso-controllo (PTSD contro sano), il terzo confronta",
                          "una perturbazione DENTRO i malati di PTSD (Current PTSD perturbation contro",
                          "Current no perturbation). Non e' lo stesso contrasto. Gia' incoerente nel",
                          "censimento del 2026-07-25."),
  "NCBITaxon:12814", paste("RSV: mescola sorveglianza CLINICA (pazienti positivi a RSV contro controlli)",
                          "e infezione SPERIMENTALE (H292 e epitelio polmonare infettati contro mock).",
                          "E' esattamente l'asse che la regola clinico-vs-sperimentale separa, ma qui",
                          "non scatta perche' il controllo clinico non usa le parole del vocabolario.",
                          "Gia' incoerente nel censimento del 2026-07-25."),
  "MeSH:D012008",   paste("Recurrence (gruppo NUOVO): il contrasto e' recidiva contro diagnosi nelle",
                          "leucemie, ma un membro confronta 'Untreated' contro 'Diagnosis' (non una",
                          "recidiva) e due membri appaiano pazienti DIVERSI. L'entita' e' uno stato",
                          "clinico, non una perturbazione.")
)

agg$verdetto <- ifelse(agg$entita %in% incoerenti$entita, "incoerente", "coerente")
agg <- left_join(agg, incoerenti, by = "entita")

cat("=== CENSIMENTO DI COERENZA — TUTTI i", nrow(agg), "gruppi letti uno per uno ===\n")
print(table(agg$verdetto))
cat(sprintf("\ncoerenti: %d / %d = %.1f%%\n", sum(agg$verdetto == "coerente"), nrow(agg),
            100 * mean(agg$verdetto == "coerente")))
cat("\nstudi-slot nei coerenti:", sum(agg$k[agg$verdetto == "coerente"]),
    "su", sum(agg$k), "\n")
cat("\nforza dei coerenti:\n")
print(table(cut(agg$k[agg$verdetto == "coerente"], breaks = c(2, 4, 9, 19, Inf),
                labels = c("k=3-4", "k=5-9", "k=10-19", "k>=20"))))
cat("\n=== gli incoerenti ===\n")
print(as.data.frame(agg[agg$verdetto == "incoerente", c("ckey", "k", "n")]), row.names = FALSE)

write.csv(agg[, c("ckey", "entita", "verso", "k", "n", "verdetto", "motivo")],
          file.path(OUT, "censimento-verdetti.csv"), row.names = FALSE)
cat("\nsalvato censimento-verdetti.csv\n")
