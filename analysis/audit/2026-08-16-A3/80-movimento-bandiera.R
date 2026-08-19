#!/usr/bin/env Rscript
# analysis/audit/2026-08-16-A3/80-movimento-bandiera.R
#
# IL METRO DEL MOVIMENTO, misurato sullo Stadio 3.
#
# Il gate del re-cluster ha segnalato tre entita' bandiera sotto il pavimento
# ("FERMARSI E MISURARE"). Questo script fa quella misura, in tre passi:
#
#   1. il calo esiste gia' nel run di RIFERIMENTO (master vecchi) o nasce con
#      A3? -- senza questo, un pavimento stale verrebbe scambiato per un
#      effetto del re-run;
#   2. gli studi usciti dove sono finiti: spariti a monte, o riassegnati?
#   3. che cosa cambia nella chiave del cluster: l'entita', il tipo di
#      controllo, o l'eleggibilita'?
#
# L'unita' di conteggio e' lo STUDIO, non la destinazione: uno studio di
# screening con duecento composti (GSE199800) altrimenti domina il conteggio
# da solo.
#
# La definizione di k e' quella del gate (p4-fase-f13, righe 641-655): il
# massimo k fra i cluster `cgroup` con quella `contrast_entity`. Usarne
# un'altra qui renderebbe i numeri non confrontabili con la riga di log che
# ha fatto scattare la misura.
#
# Uso: Rscript analysis/audit/2026-08-16-A3/80-movimento-bandiera.R

suppressPackageStartupMessages({ library(arrow); library(cli); devtools::load_all(".", quiet = TRUE) })

RIF <- Sys.getenv("RIF_DIR", "analysis/p4-output/20260815T231154Z-stage3-v16-7f986159")
A3D <- Sys.getenv("A3_DIR",  "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159")
OUT <- "analysis/audit/2026-08-16-A3"

PAV <- c("NCBITaxon:2697049" = 38L, "HGNC:11766" = 61L, "CHEBI:16412" = 41L,
         "CHEBI:68534" = 29L, "CHEBI:63637" = 19L)
NOMI <- c("NCBITaxon:2697049" = "SARS-CoV-2", "HGNC:11766" = "TGFB1",
          "CHEBI:16412" = "LPS", "CHEBI:68534" = "enzalutamide",
          "CHEBI:63637" = "vemurafenib")

carica <- function(d) {
  cl <- readRDS(file.path(d, "clusters.rds"))
  a  <- as.data.frame(read_parquet(file.path(d, "assignments.parquet")))
  a$series <- vapply(strsplit(a$record_id, "__", fixed = TRUE), `[`, character(1), 1L)
  list(cl = cl, as = a)
}
R <- carica(RIF); A <- carica(A3D)
cg <- function(X) !is.na(X$cl$mode) & X$cl$mode == "cgroup"
cluster_di <- function(X, id) {
  s <- cg(X) & !is.na(X$cl$contrast_entity) & X$cl$contrast_entity == id
  if (!any(s)) return(NA_character_)
  X$cl$cluster_id[s][which.max(X$cl$k[s])]
}
studi_di <- function(X, id) {
  cid <- cluster_di(X, id)
  if (is.na(cid)) return(character(0))
  sort(unique(X$as$series[X$as$cluster_id == cid]))
}
k_di <- function(X, id) {
  s <- cg(X) & !is.na(X$cl$contrast_entity) & X$cl$contrast_entity == id
  if (any(s)) max(X$cl$k[s], na.rm = TRUE) else 0L
}

a3_studi <- readLines(file.path(OUT, "A3-studi.txt"))

# --- 1. il calo nasce con A3, o c'era gia'? -----------------------------------
cli_h2("1. Il calo esiste gia' nel riferimento?")
righe <- lapply(names(PAV), function(id) {
  data.frame(entita = NOMI[[id]], pavimento = PAV[[id]],
             k_rif = k_di(R, id), k_a3 = k_di(A, id), stringsAsFactors = FALSE)
})
tab1 <- do.call(rbind, righe)
tab1$lettura <- ifelse(tab1$k_rif < tab1$pavimento, "il calo c'era gia' nel riferimento",
                ifelse(tab1$k_a3 < tab1$pavimento, "sceso CON A3", "sopra in entrambi"))
print(tab1, row.names = FALSE)

# --- 2. e 3. dove vanno gli studi usciti, e che cosa cambia -------------------
cli_h2("2-3. Gli studi usciti: dove finiscono e che cosa cambia")
res <- list(); bil <- list()
for (id in names(PAV)) {
  sr <- studi_di(R, id); sa <- studi_di(A, id)
  usciti <- setdiff(sr, sa); entrati <- setdiff(sa, sr)
  bil[[length(bil) + 1L]] <- data.frame(
    entita = NOMI[[id]], k_rif = length(sr), k_a3 = length(sa),
    usciti = length(usciti), entrati = length(entrati),
    quota_rigenerata_da_A3 = sum(sr %in% a3_studi), stringsAsFactors = FALSE)
  for (s in usciti) {
    dst <- unique(A$as$cluster_id[A$as$series == s])
    dst <- dst[dst %in% A$cl$cluster_id[cg(A)]]
    cat_ <- if (!length(dst)) {
      "esce da cgroup"
    } else if (any(A$cl$contrast_entity[match(dst, A$cl$cluster_id)] == id, na.rm = TRUE)) {
      "stessa entita', controllo diverso"
    } else {
      "entita' diversa"
    }
    res[[length(res) + 1L]] <- data.frame(
      entita = NOMI[[id]], studio = s, categoria = cat_,
      rigenerato_da_A3 = s %in% a3_studi,
      ancora_negli_assignment = s %in% A$as$series, stringsAsFactors = FALSE)
  }
}
tab2 <- do.call(rbind, bil); d <- do.call(rbind, res)
print(tab2, row.names = FALSE)
cli_h3("Categoria, per STUDIO")
print(table(d$categoria))
print(table(d$entita, d$categoria))

# --- i due controlli che rendono leggibile il risultato ----------------------
cli_h3("Controlli")
cli_alert_info("studi usciti che NON erano nel sottoinsieme A3: {sum(!d$rigenerato_da_A3)} (atteso 0)")
cli_alert_info("studi usciti spariti da OGNI assignment: {sum(!d$ancora_negli_assignment)} (atteso 0)")

utils::write.csv(d, file.path(OUT, "studi-persi-bandiera.csv"), row.names = FALSE)
utils::write.csv(tab2, file.path(OUT, "bilancio-bandiera.csv"), row.names = FALSE)
cli_alert_success("Scritti studi-persi-bandiera.csv e bilancio-bandiera.csv in {.path {OUT}}")
