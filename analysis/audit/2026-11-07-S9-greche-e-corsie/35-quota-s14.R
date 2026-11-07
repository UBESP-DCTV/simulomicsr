#!/usr/bin/env Rscript
# 35-quota-s14.R — S9, previsione P5: la quota di confronti con caratteri di G nel
# master dello Stadio 2 rifatto da zero (S14) contro il master A3.
#
# Stessa enumerazione sui due master (confronti con due bracci esistenti e non
# vuoti), quattro stringhe (etichette e factor_levels dei due bracci): l'anchor
# richiede lo Stadio 1 e qui non serve, perche' P5 e' un RAPPORTO fra due master
# misurati nello stesso modo. IC 95% con bootstrap APPAIATO per studio (gli studi
# sono quasi gli stessi nei due master), B = 2000, seme 20261107.
#
# Uso: Rscript analysis/audit/2026-11-07-S9-greche-e-corsie/35-quota-s14.R
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-11-07-S9-greche-e-corsie"
source(file.path(OUT, "01-traduzione.R"))
MASTER <- c(A3  = "analysis/p4-output/A3-stage2-master-innestato.jsonl",
            S14 = "analysis/p4-output/S14-stage2-master.jsonl")
SHA <- c(A3  = "b9947746ab19589d934c155fe245b5266d080b8ad428c2edf7df1dbf5cc05dd3")

fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";")
}
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid

per_studio <- list()
for (nm in names(MASTER)) {
  sha <- digest::digest(file = MASTER[[nm]], algo = "sha256")
  if (!is.na(SHA[nm]) && !identical(sha, unname(SHA[nm]))) stop("SHA-256 diverso per ", nm)
  cli_alert_info("{nm}: {MASTER[[nm]]} sha256 {substr(sha, 1, 12)}...")
  s2 <- simulomicsr:::.load_stage2_master(MASTER[[nm]])
  r <- lapply(s2, function(study) {
    rgl <- stats::setNames(study$replicate_groups,
             vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
    n <- 0L; g <- 0L; cat <- character(0)
    for (cmp in study$comparisons) {
      tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
      if (is.null(tg) || is.null(cg)) next
      if (length(tg$sample_ids) == 0L || length(cg$sample_ids) == 0L) next
      s <- paste(lab_of(tg, cmp$treated_group), lab_of(cg, cmp$control_group), fl_of(tg), fl_of(cg))
      n <- n + 1L
      if (ha_G(s)) { g <- g + 1L; cat <- c(cat, categoria_G(s)) }
    }
    data.frame(study = study$series_id, n = n, g = g,
               cat = paste(cat, collapse = ","), stringsAsFactors = FALSE)
  })
  per_studio[[nm]] <- do.call(rbind, r)
  rm(s2); invisible(gc())
}

a <- per_studio$A3; s <- per_studio$S14
quota <- function(d) sum(d$g) / sum(d$n)
q_a <- quota(a); q_s <- quota(s)
u <- union(a$study, s$study)
na <- stats::setNames(numeric(length(u)), u); ga <- na; ns <- na; gs <- na
na[a$study] <- a$n; ga[a$study] <- a$g; ns[s$study] <- s$n; gs[s$study] <- s$g
set.seed(20261107)
B <- 2000L
bt <- replicate(B, {
  i <- sample.int(length(u), replace = TRUE)
  qa <- sum(ga[i]) / sum(na[i]); qs <- sum(gs[i]) / sum(ns[i])
  c(qa, qs, qs / qa)
})
ic <- apply(bt, 1L, stats::quantile, probs = c(0.025, 0.975))
tab_cat <- function(d) table(unlist(strsplit(d$cat[nzchar(d$cat)], ",")))

righe <- c(
  sprintf("A3 : confronti %d, con G %d, quota %.4f%% [%.4f; %.4f]", sum(a$n), sum(a$g),
          100 * q_a, 100 * ic[1, 1], 100 * ic[2, 1]),
  sprintf("S14: confronti %d, con G %d, quota %.4f%% [%.4f; %.4f]", sum(s$n), sum(s$g),
          100 * q_s, 100 * ic[1, 2], 100 * ic[2, 2]),
  sprintf("P5 rapporto S14/A3: %.3f [%.3f; %.3f]  (B = %d, seme 20261107, bootstrap appaiato su %d studi)",
          q_s / q_a, ic[1, 3], ic[2, 3], B, length(u)),
  "categorie A3:", capture.output(print(tab_cat(a))),
  "categorie S14:", capture.output(print(tab_cat(s))))
writeLines(righe, file.path(OUT, "35-quota-s14.txt"))
cat(righe, sep = "\n")
