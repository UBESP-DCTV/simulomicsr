# D2e — Lo smoke v16 e' IDENTICO al v15: 3.052 non_clusterable, 69
# `riga_genetica_asimmetrica`, 297 cgroup, zero k cambiati. Due spiegazioni
# possibili, e vanno distinte: (a) il subset non contiene i casi toccati, (b) il
# codice nuovo NON e' chiamato dal percorso di produzione. La (b) e' il difetto
# che questo progetto ha gia' pagato tre volte.
suppressMessages(devtools::load_all(".", quiet = TRUE))
OLD <- "analysis/audit/2026-08-12-corsie"
s2  <- readRDS(file.path(OLD, "s2.rds")); idx <- simulomicsr:::.index_stage2_master(s2)
lab <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
flj <- function(rg) { fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";") }
oe <- simulomicsr:::.load_ontology_dicts()

verdetto <- function(gse, cmp_id) {
  st <- get(gse, envir = idx, inherits = FALSE)
  cmp <- simulomicsr:::.lookup_cmp(st, cmp_id)
  tg <- simulomicsr:::.lookup_rg(st, cmp$treated_group)
  cg <- simulomicsr:::.lookup_rg(st, cmp$control_group)
  v <- simulomicsr:::.ca_member_contrast(
    treated_label = lab(tg, cmp$treated_group), control_label = lab(cg, cmp$control_group),
    treated_fl = flj(tg), control_fl = flj(cg), ontology_env = oe)
  v$drop_reason
}

cat("=== (b) il codice nuovo E' chiamato dal gate di produzione? ===\n")
# i due confronti veri di GSE111009 (Nutlin-3a): con la regola vecchia passavano
casi <- list(c("GSE111009", "GSE111009__grp_0007_vs_grp_0001"),
             c("GSE111009", "GSE111009__grp_0008_vs_grp_0001"))
st <- get("GSE111009", envir = idx, inherits = FALSE)
ids <- vapply(st$comparisons, function(c0) c0$comparison_id %||% "", character(1))
tro <- 0L
for (c0 in st$comparisons) {
  tg <- simulomicsr:::.lookup_rg(st, c0$treated_group)
  if (is.null(tg) || !grepl("p63shRNA", lab(tg, c0$treated_group))) next
  r <- verdetto("GSE111009", c0$comparison_id)
  tro <- tro + 1L
  cat(sprintf("  %-40s -> %s\n", substr(lab(tg, c0$treated_group), 1, 40), r))
}
cat("confronti p63shRNA trovati:", tro, "\n")

cat("\n=== (a) i 3 studi dello smoke toccati dal marcatore: perche' non cambiano ===\n")
M <- readRDS("analysis/audit/2026-08-13-rerun-prep/D2d-corpus.rds")
z <- M[M$series_id %in% c("GSE149035", "GSE162186", "GSE172506") & M$a_new != M$a_old, ]
for (i in seq_len(nrow(z))) {
  r <- tryCatch(verdetto(z$series_id[i], z$cmp_id[i]), error = function(e) paste("ERR", conditionMessage(e)))
  cat(sprintf("  %s  marcatore %s->%s | gate: %s\n     T: %s\n     C: %s\n",
              z$series_id[i], z$a_old[i], z$a_new[i], if (nzchar(r)) r else "TENUTO",
              substr(z$tl[i], 1, 70), substr(z$cl[i], 1, 70)))
}
