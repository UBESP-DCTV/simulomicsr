# CONTROLLO: esiste un confronto in cui la stessa libreria sta sui DUE bracci?
# Se esistesse, `.collapse_technical_lanes` si ferma (giustamente: sommare le due
# corsie metterebbe lo stesso materiale sul trattato e sul controllo), e
# l'orchestratore lascerebbe le conte com'erano segnalandolo.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC <- "analysis/audit/2026-08-12-corsie"
R  <- readRDS(file.path(SC, "30-entry-annotate.rds")); R <- R[R$esito == "ambessa" | R$esito == "ammessa", ]
lk <- readRDS(file.path(SC, "94-lookup.rds"))
n <- 0L
for (i in seq_len(nrow(R))) {
  gt <- strsplit(R$gsm_treated[i], ",")[[1]]; gc_ <- strsplit(R$gsm_control[i], ",")[[1]]
  a <- unique(lk[gt]); b <- unique(lk[gc_])
  com <- intersect(a[!is.na(a)], b[!is.na(b)])
  if (length(com)) { n <- n + 1L
    cat("SUI DUE BRACCI:", R$cluster_id[i], R$study_id[i], "->", paste(com, collapse=", "), "\n") }
}
cat("confronti con una libreria sui due bracci:", n, "su", nrow(R), "\n")
# e la stessa cosa sui CAMPIONI (il conflitto di ruolo gia' noto)
m <- sum(vapply(seq_len(nrow(R)), function(i)
  length(intersect(strsplit(R$gsm_treated[i], ",")[[1]],
                   strsplit(R$gsm_control[i], ",")[[1]])) > 0L, logical(1)))
cat("confronti con un CAMPIONE sui due bracci (conflitto di ruolo noto):", m, "\n")
