# AUDIT DEL RESOLVER — passo 4: effetto MISURATO del fix sulla produzione.
#
# Si ri-esegue `recover_identity` (la funzione di produzione, ora con le guardie)
# sugli STESSI testi H5 e sugli STESSI campioni che avevano ricevuto un ID
# ontologico, e si confronta con la cache prodotta PRIMA del fix.
#
# Domande: (1) quante identita' cambiano? (2) quelle che spariscono erano
# davvero sbagliate? (3) quante identita' CORRETTE si perdono (costo in recall)?
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({library(dplyr)})
OUT <- "analysis/audit/2026-07-25-resolver-alias-audit"
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
oe <- .load_ontology_dicts()
t0 <- Sys.time()

cache <- readRDS("/home/user/.cache/R/simulomicsr/name-recovery-lookup/name-recovery-lookup-fae90f35.rds")
gsms <- ls(cache); rec <- lapply(gsms, function(g) get(g, envir = cache))
lk <- data.frame(gsm = gsms,
                 kind = vapply(rec, function(z) z$kind %||% NA_character_, ""),
                 id_old = vapply(rec, function(z) z$agent_id %||% NA_character_, ""),
                 nome_old = vapply(rec, function(z) z$canonical_name %||% NA_character_, ""),
                 src_old = vapply(rec, function(z) z$recovery_source %||% NA_character_, ""),
                 stringsAsFactors = FALSE)
onto <- lk[!is.na(lk$id_old) & grepl("^(CHEBI|MeSH|HGNC|CHEMBL|NCBITaxon):", lk$id_old), ]

H5 <- "analysis/input/human_gene_v2.5.h5"
gsm_all <- as.character(rhdf5::h5read(H5, "meta/samples/geo_accession"))
idx <- match(onto$gsm, gsm_all)
src <- as.character(rhdf5::h5read(H5, "meta/samples/source_name_ch1"))[idx]
chr <- as.character(rhdf5::h5read(H5, "meta/samples/characteristics_ch1"))[idx]
tit <- as.character(rhdf5::h5read(H5, "meta/samples/title"))[idx]
rhdf5::h5closeAll()
cat(sprintf("%s - ri-eseguo recover_identity su %d campioni...\n", format(Sys.time()), nrow(onto)))

id_new <- rep(NA_character_, nrow(onto)); nome_new <- rep(NA_character_, nrow(onto))
src_new <- rep(NA_character_, nrow(onto))
for (i in seq_len(nrow(onto))) {
  r <- try(recover_identity(src[i], chr[i], tit[i], onto$kind[i], oe), silent = TRUE)
  if (inherits(r, "try-error")) next
  id_new[i] <- r$agent_id %||% NA_character_
  nome_new[i] <- r$canonical_name %||% NA_character_
  src_new[i] <- r$recovery_source %||% NA_character_
  if (i %% 5000 == 0) cat(sprintf("  %d/%d\n", i, nrow(onto)))
}
onto$id_new <- id_new; onto$nome_new <- nome_new; onto$src_new <- src_new
onto$cambiato <- !identical(TRUE, FALSE) & (is.na(onto$id_new) | onto$id_new != onto$id_old)

cat("\n=== EFFETTO DEL FIX (campioni che avevano un ID ontologico) ===\n")
cat(sprintf("campioni                        : %d\n", nrow(onto)))
cat(sprintf("identita' INVARIATE             : %d (%.1f%%)\n", sum(!onto$cambiato), 100 * mean(!onto$cambiato)))
cat(sprintf("identita' CAMBIATE              : %d (%.1f%%)\n", sum(onto$cambiato), 100 * mean(onto$cambiato)))
cat(sprintf("  di cui ora senza ID ontologico: %d\n",
            sum(onto$cambiato & (is.na(onto$id_new) | grepl("^STR:", onto$id_new)))))
cat(sprintf("  di cui ID ontologico diverso  : %d\n",
            sum(onto$cambiato & !is.na(onto$id_new) & !grepl("^STR:", onto$id_new))))
cat("\n-- le identita' RIMOSSE, per ID vecchio (top 25) --\n")
rm_tab <- onto |> filter(cambiato) |> group_by(id_old, nome_old) |>
  summarise(n = n(), .groups = "drop") |> arrange(desc(n))
print(head(as.data.frame(rm_tab), 25), row.names = FALSE)
cat("\n-- verifica sulle collisioni ACCERTATE (devono sparire) --\n")
CONF <- c("HGNC:11795", "HGNC:1681", "HGNC:5417", "HGNC:6018", "CHEBI:80961",
          "CHEBI:16016", "CHEBI:15702", "CHEBI:25016", "CHEBI:17115", "NCBITaxon:6754")
for (id in CONF) {
  cat(sprintf("  %-16s prima %4d -> dopo %4d campioni\n", id,
              sum(onto$id_old == id, na.rm = TRUE), sum(onto$id_new == id, na.rm = TRUE)))
}
cat("\n-- NON-REGRESSIONE: entita' vere (devono restare) --\n")
for (id in c("CHEBI:16412", "CHEBI:16330", "CHEBI:63637", "CHEBI:68534", "NCBITaxon:2697049",
             "HGNC:11892", "MeSH:D006528")) {
  cat(sprintf("  %-18s prima %4d -> dopo %4d campioni\n", id,
              sum(onto$id_old == id, na.rm = TRUE), sum(onto$id_new == id, na.rm = TRUE)))
}
saveRDS(onto, file.path(OUT, "before-after.rds"))
write.csv(rm_tab, file.path(OUT, "identita-rimosse.csv"), row.names = FALSE)
cat(sprintf("\nfatto (%.1f min)\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
