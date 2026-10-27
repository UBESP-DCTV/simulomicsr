# 20-prova-funzionale.R — dopo `10-sposta-dati-su-micron.sh scambia`: la pipeline legge
# i dati attraverso i link? Una lettura vera per area, dai percorsi di SEMPRE (quelli
# scritti negli script e nei run_metadata), non da /mnt/micron.
# Uso (dalla radice del repo, SENZA --vanilla: con --vanilla mancano arrow e devtools):
#   Rscript analysis/audit/2026-10-27-dati-su-micron/20-prova-funzionale.R

ok <- function(cosa, espr) {
  r <- tryCatch(force(espr), error = function(e) structure(conditionMessage(e), class = "errore"))
  if (inherits(r, "errore")) {
    cat(sprintf("KO  %s: %s\n", cosa, r))
    quit(status = 1)
  }
  cat(sprintf("OK  %s: %s\n", cosa, r))
}

repo <- "/home/user/simulomicsr"
cache <- tools::R_user_dir("simulomicsr", "cache")

ok("input è un link", Sys.readlink(file.path(repo, "analysis/input")))
ok("cache R è un link", Sys.readlink(cache))

# H5 ARCHS4 attraverso il link della cartella E il link relativo già esistente
h5 <- file.path(repo, "analysis/input/archs4-human-gene-v2.5.h5")
ok("H5: dimensioni di data/expression", {
  d <- rhdf5::h5ls(h5)
  rhdf5::H5close()
  paste(d$dim[d$group == "/data" & d$name == "expression"], collapse = " ")
})
ok("H5: primi 3 gene_symbol", {
  g <- rhdf5::h5read(h5, "meta/genes/symbol", index = list(1:3))
  rhdf5::H5close()
  paste(g, collapse = ",")
})

# Stadio 3 A3: voce di p4-output diventata link
s3 <- file.path(repo, "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159")
ok("Stadio 3 A3: righe di assignments.parquet", nrow(arrow::read_parquet(file.path(s3, "assignments.parquet"))))
ok("Stadio 3 A3: run_metadata.json", length(jsonlite::read_json(file.path(s3, "run_metadata.json"))))

# file tracciato rimasto vero in p4-output
ok("p4-output: file tracciato non è un link", {
  stopifnot(!nzchar(Sys.readlink(file.path(repo, "analysis/p4-output/p4-beta-archs4-source.json"))))
  "file vero"
})

# cache R
ok("cache: hgnc-lookup.rds", class(readRDS(file.path(cache, "hgnc-lookup.rds")))[1])
ok("cache: file in stage4-counts", length(list.files(file.path(cache, "stage4-counts"), recursive = TRUE)))

# scrittura + rename nella cache, come fa stage4-counts-cache.R (temporaneo nella stessa cartella)
ok("cache: scrittura e rename atomico", {
  tmp <- tempfile(pattern = ".tmp-", tmpdir = cache, fileext = ".rds")
  fin <- file.path(cache, ".prova-rename-2026-10-27.rds")
  saveRDS(1, tmp)
  stopifnot(file.rename(tmp, fin))
  on.exit(unlink(fin))
  readRDS(fin)
})
cat("FINE: tutte le letture passano dai link\n")
