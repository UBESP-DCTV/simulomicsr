#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/60-movimento.R
# P12: il gate a 2 ridurrebbe il movimento fra le due esecuzioni della stessa catena?
# Unita': lo studio. Riproduce prima i 271 studi usciti con il gate a 3.
# Uso: Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/60-movimento.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
A <- readRDS(file.path(PES5, "dispatch-A3.rds")); R <- readRDS(file.path(PES5, "dispatch-RIF.rds"))
lev <- fread(file.path(RIL, "leva-chiave-contrasto.csv"))
dov <- fread(file.path(RIL, "usciti-dove-finiscono.csv"))
studi <- function(D, g) unique(D$tenuti[cluster_id %in% D$candidati[k_eff >= g, cluster_id], study_id])
chiavi <- function(D, g) D$candidati[k_eff >= g, paste(contrast_entity, contrast_direction, contrast_control_key, sep = "||")]
a3 <- studi(A, 3L); r3 <- studi(R, 3L); a2 <- studi(A, 2L); r2 <- studi(R, 2L)
u3 <- setdiff(r3, a3); u2 <- setdiff(r2, a2)
cat(sprintf("gate 3: studi nel riferimento %d, nel deliverable %d, usciti %d (%.1f%%), entrati %d\n", length(r3), length(a3), length(u3), 100 * length(u3) / length(r3), length(setdiff(a3, r3))))
cat(sprintf("gate 2: studi nel riferimento %d, nel deliverable %d, usciti %d (%.1f%%), entrati %d\n", length(r2), length(a2), length(u2), 100 * length(u2) / length(r2), length(setdiff(a2, r2))))
ver <- lev[esito == "esce del tutto dal deliverable", study_id]
cat(sprintf("riproduzione: i 271 del finding coincidono con i miei usciti a gate 3: %s (%d e %d)\n", setequal(ver, u3), length(ver), length(u3)))
tornano <- intersect(u3, a2)
cat(sprintf("dei %d usciti a gate 3, stanno a gate 2 nel deliverable: %d (%.1f%%)\n", length(u3), length(tornano), 100 * length(tornano) / length(u3)))
g <- dov[grepl("gate", esito), study_id]
cat(sprintf("dei %d usciti per il gate (stessa chiave), tornano con il gate a 2: %d (%.1f%%)\n", length(g), length(intersect(g, a2)), 100 * length(intersect(g, a2)) / length(g)))
tab <- data.table(study_id = union(r2, r3))
tab[, `:=`(in3 = study_id %in% r3, out3 = study_id %in% u3, in2 = study_id %in% r2, out2 = study_id %in% u2)]
rapp <- function(x) (sum(x$out2) / sum(x$in2)) / (sum(x$out3) / sum(x$in3))
set.seed(SEME)
b <- replicate(B_BOOT, rapp(tab[sample(.N, replace = TRUE)]))
cat(sprintf("=== P12 quota di usciti gate 2 / gate 3: %.3f [%.3f; %.3f] (unita' studio, %d studi)\n", rapp(tab), quantile(b, .025), quantile(b, .975), nrow(tab)))
for (gg in 3:2) {
  kr <- chiavi(R, gg); ka <- chiavi(A, gg)
  cat(sprintf("meta-analisi, gate %d: riferimento %d, deliverable %d, in comune %d, Jaccard %.3f, del riferimento perse %.1f%%\n", gg, length(kr), length(ka), length(intersect(kr, ka)), length(intersect(kr, ka)) / length(union(kr, ka)), 100 * (1 - length(intersect(kr, ka)) / length(kr))))
}
# coppie (chiave, studio): lo stesso studio resta nello stesso gruppo?
cop <- function(D, g) { x <- merge(D$tenuti[, .(cluster_id, study_id)], D$candidati[k_eff >= g, .(cluster_id, chiave = paste(contrast_entity, contrast_direction, contrast_control_key, sep = "||"))], by = "cluster_id"); unique(paste(x$chiave, x$study_id)) }
for (gg in 3:2) {
  cr <- cop(R, gg); ca <- cop(A, gg)
  cat(sprintf("coppie (meta-analisi, studio), gate %d: riferimento %d, deliverable %d, in comune %d, del riferimento perse %.1f%%\n", gg, length(cr), length(ca), length(intersect(cr, ca)), 100 * (1 - length(intersect(cr, ca)) / length(cr))))
}
# il confine a k=2 si muove come quello a k=3? gruppi a k_eff=2 nei due run, per chiave
k2r <- R$candidati[k_eff == 2L, paste(contrast_entity, contrast_direction, contrast_control_key, sep = "||")]
k2a <- A$candidati[k_eff == 2L, paste(contrast_entity, contrast_direction, contrast_control_key, sep = "||")]
k3r <- R$candidati[k_eff == 3L, paste(contrast_entity, contrast_direction, contrast_control_key, sep = "||")]
k3a <- chiavi(A, 3L)
cat(sprintf("gruppi a k_eff=2 nel riferimento: %d, presenti come k>=2 nel deliverable: %d (%.1f%%); gruppi a k_eff=3 nel riferimento: %d, presenti come k>=3 nel deliverable: %d (%.1f%%)\n",
            length(k2r), length(intersect(k2r, chiavi(A, 2L))), 100 * length(intersect(k2r, chiavi(A, 2L))) / length(k2r), length(k3r), length(intersect(k3r, k3a)), 100 * length(intersect(k3r, k3a)) / length(k3r)))
