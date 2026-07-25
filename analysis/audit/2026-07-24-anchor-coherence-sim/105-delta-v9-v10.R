# Che cosa cambia fra il gate v9 (145 poolabili, 143 coerenti) e il gate v10
# (v9 + scarto delle righe mal appaiate). Serve a sapere quali gruppi vanno
# RI-GIUDICATI: quelli invariati conservano il verdetto, gli altri no.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
v9 <- readRDS(file.path(SC, "fase1-v9-results.rds"))
v10 <- readRDS(file.path(SC, "fase1-v10-results.rds"))
ver <- read.csv(file.path(SC, "v10-census-verdicts-FINAL.csv"), stringsAsFactors = FALSE)

cat("=== righe scartate dalle regole di riga ===\n")
sc <- v10$pm$dr[startsWith(v10$pm$dr, "riga_")]
print(sort(table(sc), decreasing = TRUE))
cat(sprintf("membri scartati: %d su %d (%.1f%%)\n", length(sc), nrow(v10$pm),
            100 * length(sc) / nrow(v10$pm)))
## quante COPPIE distinte (studio, trattato, controllo) — l'unita' verificata a mano
w <- v10$pm[startsWith(v10$pm$dr, "riga_"), ]
cat(sprintf("coppie (studio, trattato, controllo) distinte scartate: %d\n",
            nrow(unique(w[, c("study_id", "treated_label", "control_label")]))))

a9 <- v9$agg; a10 <- v10$agg
cat(sprintf("\n=== poolabili k>=3: v9 %d -> v10 %d ===\n", nrow(a9), nrow(a10)))
persi <- setdiff(a9$ckey, a10$ckey); nuovi <- setdiff(a10$ckey, a9$ckey)
comuni <- intersect(a9$ckey, a10$ckey)
k9 <- setNames(a9$k, a9$ckey); k10 <- setNames(a10$k, a10$ckey)
v <- setNames(ver$verdetto, ver$ckey)
cat(sprintf("persi: %d | nuovi: %d | comuni: %d\n", length(persi), length(nuovi), length(comuni)))
if (length(persi)) {
  cat("\n-- gruppi PERSI (scesi sotto k=3) --\n")
  print(data.frame(ckey = persi, k_v9 = k9[persi], verdetto_v9 = v[persi]), row.names = FALSE)
}
if (length(nuovi)) {
  cat("\n-- gruppi NUOVI (mai giudicati: da giudicare) --\n")
  print(data.frame(ckey = nuovi, k_v10 = k10[nuovi]), row.names = FALSE)
}
camb <- comuni[k9[comuni] != k10[comuni]]
cat(sprintf("\n-- gruppi comuni con k CAMBIATO: %d (da ri-guardare) --\n", length(camb)))
if (length(camb)) print(data.frame(ckey = camb, k_v9 = k9[camb], k_v10 = k10[camb],
                                   verdetto_v9 = v[camb])[order(-k9[camb]), ], row.names = FALSE)
inv <- comuni[k9[comuni] == k10[comuni]]
cat(sprintf("\ngruppi INVARIATI (verdetto conservabile): %d\n", length(inv)))
cat(sprintf("di cui coerenti in v9: %d\n", sum(v[inv] == "COERENTE", na.rm = TRUE)))
saveRDS(list(persi = persi, nuovi = nuovi, cambiati = camb, invariati = inv),
        file.path(SC, "delta-v9-v10.rds"))

## --- composizione: k invariato NON significa membri invariati ---
m9 <- v9$pm[v9$pm$elig, ] |> group_by(ckey) |> summarise(n9 = n(), .groups = "drop")
m10 <- v10$pm[v10$pm$elig, ] |> group_by(ckey) |> summarise(n10 = n(), .groups = "drop")
cmp <- inner_join(m9, m10, by = "ckey") |> filter(ckey %in% comuni, n9 != n10)
cat(sprintf("\n=== gruppi comuni con MEMBRI cambiati (k anche invariato): %d ===\n", nrow(cmp)))
print(as.data.frame(cmp |> mutate(persi = n9 - n10) |> arrange(desc(persi))), row.names = FALSE)
cat(sprintf("\ngruppi con composizione IDENTICA a v9: %d\n", length(comuni) - nrow(cmp)))
