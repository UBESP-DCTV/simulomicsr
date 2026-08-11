#!/usr/bin/env Rscript
# 10-matrice-giudici.R --- PASSO 4, passo 1: mettere i giudici sulla stessa base
# e misurare dove divergono. Nessun predittore ancora: prima la matrice.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(jsonlite) })

OLD <- "/tmp/claude-1000/-home-user-simulomicsr/632a8932-ecdb-46bf-887a-78492b79f0e2/scratchpad"
OUT <- "analysis/audit/2026-08-09-passo4"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# --- 1. lettura umana del 5 agosto -------------------------------------------
um <- utils::read.csv("analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv",
                      stringsAsFactors = FALSE)
cat("lettura 5 agosto:", nrow(um), "righe\n")
print(table(um$verdetto_finale, useNA = "ifany"))

# --- 2. Mistral: 5 giri, con e senza flag ------------------------------------
leggi_mistral <- function(path) {
  ln <- readLines(path, warn = FALSE)
  ln <- ln[nzchar(ln)]
  out <- lapply(ln, function(l) {
    x <- tryCatch(jsonlite::fromJSON(l, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(x)) return(NULL)
    rid <- x$record_id %||% NA_character_
    pj  <- x$parsed_json
    v   <- if (!is.null(pj) && !is.null(pj$verdetto_contrasto)) as.character(pj$verdetto_contrasto) else NA_character_
    cid <- sub("__g[0-9]+$", "", rid)
    giro <- sub("^.*__g", "", rid)
    data.frame(cluster_id = cid, giro = giro, verdetto = v, stringsAsFactors = FALSE)
  })
  do.call(rbind, out[!vapply(out, is.null, logical(1L))])
}
`%||%` <- function(a, b) if (is.null(a)) b else a

mn <- leggi_mistral(file.path(OLD, "mistral", "pred5x.jsonl"))
mb <- leggi_mistral(file.path(OLD, "mistral", "bi_coe.jsonl"))
cat("\nMistral senza flag: righe", nrow(mn), " cluster", length(unique(mn$cluster_id)),
    " schema fallito", sum(is.na(mn$verdetto)), "\n")
cat("Mistral con flag  : righe", nrow(mb), " cluster", length(unique(mb$cluster_id)),
    " schema fallito", sum(is.na(mb$verdetto)), "\n")

maggioranza <- function(d) {
  s <- split(d$verdetto, d$cluster_id)
  data.frame(
    cluster_id = names(s),
    verdetto = vapply(s, function(v) {
      v <- v[!is.na(v)]
      if (!length(v)) return(NA_character_)
      t <- table(v); names(t)[which.max(t)]
    }, character(1L)),
    n_giri  = vapply(s, function(v) sum(!is.na(v)), integer(1L)),
    stabile = vapply(s, function(v) { v <- v[!is.na(v)]; length(unique(v)) == 1L }, logical(1L)),
    stringsAsFactors = FALSE, row.names = NULL)
}
MN <- maggioranza(mn); MB <- maggioranza(mb)
cat("\nMistral SENZA flag, maggioranza:\n"); print(table(MN$verdetto, useNA = "ifany"))
cat("stabili su tutti i giri:", sum(MN$stabile), "/", nrow(MN), "\n")
cat("\nMistral CON flag, maggioranza:\n"); print(table(MB$verdetto, useNA = "ifany"))
cat("stabili su tutti i giri:", sum(MB$stabile), "/", nrow(MB), "\n")

# --- 3. base comune ----------------------------------------------------------
d <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
comuni <- Reduce(intersect, list(um$cluster_id, MN$cluster_id, MB$cluster_id, d$cluster_id))
cat("\n=== BASE COMUNE ai tre giudici e al deliverable:", length(comuni), "===\n")
cat("persi rispetto a 214:", 214 - length(comuni), "\n")
fuori <- setdiff(d$cluster_id, comuni)
if (length(fuori)) {
  cat("cluster fuori dalla base comune:", paste(fuori, collapse = " "), "\n")
  for (f in fuori) {
    cat("  ", f, ": umano=", ("%in%"(f, um$cluster_id)),
        " mistral_noflag=", ("%in%"(f, MN$cluster_id)),
        " mistral_flag=", ("%in%"(f, MB$cluster_id)), "\n", sep = "")
  }
}

M <- data.frame(cluster_id = comuni, stringsAsFactors = FALSE)
M$umano     <- um$verdetto_finale[match(M$cluster_id, um$cluster_id)]
M$mistral_n <- MN$verdetto[match(M$cluster_id, MN$cluster_id)]
M$mistral_b <- MB$verdetto[match(M$cluster_id, MB$cluster_id)]
M$mb_stabile <- MB$stabile[match(M$cluster_id, MB$cluster_id)]

# normalizzazione dei tre livelli (il lettore umano usa "incerto", Mistral "dubbio")
norm3 <- function(x) {
  x <- tolower(trimws(x))
  x[x %in% c("incerto", "dubbio", "dubbia", "incerta")] <- "dubbio"
  x[x %in% c("coerente", "coerenti")] <- "coerente"
  x[x %in% c("incoerente", "incoerenti")] <- "incoerente"
  x
}
M$umano <- norm3(M$umano); M$mistral_n <- norm3(M$mistral_n); M$mistral_b <- norm3(M$mistral_b)
# TAGLIO DICHIARATO: 1 cluster ha 5 fallimenti di schema su 5 giri in ENTRAMBE le
# esecuzioni Mistral -> non ha verdetto da quel giudice. Si esclude, e si dice.
senza <- is.na(M$mistral_b) | is.na(M$mistral_n) | is.na(M$umano)
cat("\nESCLUSI per assenza di verdetto:", sum(senza),
    if (any(senza)) paste0(" (", paste(M$cluster_id[senza], collapse=" "), ")") else "", "\n")
M <- M[!senza, , drop = FALSE]
cat("base finale:", nrow(M), "\n")
cat("\nlivelli osservati:\n")
print(lapply(M[c("umano","mistral_n","mistral_b")], function(x) table(x, useNA="ifany")))

# --- 4. accordo --------------------------------------------------------------
cat("\n=== MATRICE umano x mistral_con_flag (3 livelli) ===\n")
tt <- table(umano = M$umano, mistral_flag = M$mistral_b)
print(addmargins(tt))
acc3 <- mean(M$umano == M$mistral_b)
cat(sprintf("\naccordo a 3 livelli: %.1f%% (%d/%d)\n", 100*acc3, sum(M$umano==M$mistral_b), nrow(M)))

bin <- function(x) ifelse(x == "coerente", "coerente", "non_coerente")
accb <- mean(bin(M$umano) == bin(M$mistral_b))
cat(sprintf("accordo binario (coerente vs resto): %.1f%% (%d/%d)\n",
            100*accb, sum(bin(M$umano)==bin(M$mistral_b)), nrow(M)))

ord <- c(coerente = 1L, dubbio = 2L, incoerente = 3L)
M$sev_u <- ord[M$umano]; M$sev_b <- ord[M$mistral_b]
M$delta <- M$sev_u - M$sev_b
disc <- M$delta != 0
cat(sprintf("\ndiscordi: %d/%d (%.1f%%)\n", sum(disc), nrow(M), 100*mean(disc)))
cat(sprintf("  umano PIU' severo: %d (%.1f%% dei discordi)\n",
            sum(M$delta > 0), 100*mean(M$delta[disc] > 0)))
cat(sprintf("  Mistral PIU' severo: %d (%.1f%% dei discordi)\n",
            sum(M$delta < 0), 100*mean(M$delta[disc] < 0)))

cat("\n=== IL NUCLEO SOLIDO ===\n")
cat("entrambi 'coerente' :", sum(M$umano=="coerente" & M$mistral_b=="coerente"), "\n")
cat("entrambi 'incoerente':", sum(M$umano=="incoerente" & M$mistral_b=="incoerente"), "\n")
cat("entrambi d'accordo (qualunque livello):", sum(!disc), "\n")

cat("\n=== effetto della flag sul solo Mistral ===\n")
cat("verdetto cambiato fra senza-flag e con-flag:", sum(M$mistral_n != M$mistral_b), "/", nrow(M), "\n")

saveRDS(M, file.path(OUT, "10-matrice.rds"))
utils::write.csv(M, file.path(OUT, "10-matrice.csv"), row.names = FALSE)
cat("\nscritto:", file.path(OUT, "10-matrice.csv"), "\n")
