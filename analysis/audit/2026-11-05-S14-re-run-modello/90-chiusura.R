#!/usr/bin/env Rscript
# S14, due passi col modello: controlli di chiusura dopo «CATENA FINITA».
# Rscript senza --vanilla (CLAUDE.md §3). Si lancia dalla radice del repository.
#
# Scrive, in questa cartella:
#   90-manifesto-fine.txt     cancello 1: il manifesto SHA-256 del deliverable passa ancora
#   90-riferimenti-fine.txt   cancello 1: SHA-256 dei master di riferimento, confrontati con 10-riferimenti-inizio.txt
#   90-master-sha256.txt      SHA-256 dei due master nuovi e degli input dello Stadio 2
#   90-sacct.txt              cancello 3: tutti i job della sessione, stato e nodo; nessun job doppio
#   90-flag.txt               cancello 3: VLLM_BATCH_INVARIANT=1 in container-env.txt di ogni run, anche del job fermato
# e copia i due master in /mnt/micron/simulomicsr-salvataggio/S14-master-2026-11-07/, con verifica.

suppressMessages(pkgload::load_all(".", quiet = TRUE))
DIR <- "analysis/audit/2026-11-05-S14-re-run-modello"
DEST <- "/mnt/micron/simulomicsr-salvataggio/S14-master-2026-11-07"
esito <- character()
annota <- function(...) { s <- sprintf(...); esito <<- c(esito, s); cat(s, "\n") }

# --- cancello 1: deliverable e riferimenti ---------------------------------------------------------
m <- system2("analysis/audit/2026-08-21-S2-deliverable-in-salvo/10-manifesto-e-copia.sh", "verifica", stdout = TRUE, stderr = TRUE)
writeLines(m, file.path(DIR, "90-manifesto-fine.txt"))
annota("cancello 1, manifesto del deliverable alla fine: %s", tail(m, 1))

ini <- read.table(file.path(DIR, "10-riferimenti-inizio.txt"), col.names = c("sha", "file"), stringsAsFactors = FALSE)
fin <- data.frame(sha = unname(vapply(ini$file, function(f) strsplit(system2("sha256sum", f, stdout = TRUE), " ")[[1]][1], "")), file = ini$file)
writeLines(sprintf("%s  %s", fin$sha, fin$file), file.path(DIR, "90-riferimenti-fine.txt"))
annota("cancello 1, file di riferimento con SHA-256 uguale all'inizio: %d su %d", sum(fin$sha == ini$sha), nrow(ini))

# --- SHA-256 dei master nuovi -----------------------------------------------------------------------
nuovi <- c("analysis/p4-output/S14-stage1-master.jsonl", "analysis/p4-output/S14-stage2-master.jsonl",
           "analysis/input/S14-stage2-input.jsonl", "analysis/input/S14-stage2-rescue.jsonl")
sh <- system2("sha256sum", nuovi, stdout = TRUE)
writeLines(sh, file.path(DIR, "90-master-sha256.txt"))
annota("SHA-256 dei master nuovi in 90-master-sha256.txt: %d file", length(sh))

# --- cancello 3: tutti i job, stato, nodo, flag -----------------------------------------------------
rds <- c(fs::dir_ls(file.path(DIR, "jobs"), glob = "*.rds"), fs::dir_ls(file.path(DIR, "jobs", "fermati"), glob = "*.rds"))
j <- lapply(rds, readRDS)
tab <- data.frame(file = basename(rds), slurm = vapply(j, function(x) as.character(x$slurm_job_id), ""),
                  run_id = vapply(j, function(x) x$run_id, ""), stringsAsFactors = FALSE)
cfg <- dgx_config()
r <- .dgx_ssh(cfg, sprintf("sacct -X -n -P -j %s -o JobID,State,Elapsed,NodeList", paste(tab$slurm, collapse = ",")))
s <- do.call(rbind, strsplit(grep("[|]", strsplit(r$stdout, "\n")[[1]], value = TRUE), "|", fixed = TRUE))
tab$stato <- s[match(tab$slurm, s[, 1]), 2]; tab$durata <- s[match(tab$slurm, s[, 1]), 3]; tab$nodo <- s[match(tab$slurm, s[, 1]), 4]
# Tutti i job dell'utente dall'inizio della sessione: un job inviato due volte (errore ssh a meta') comparirebbe qui.
r2 <- .dgx_ssh(cfg, "sacct -u u0044 -S 2026-11-05T17:00:00 -E 2026-11-07T04:00:00 -X -n -P -o JobID,JobName%80,State,NodeList")
tutti <- do.call(rbind, strsplit(grep("[|]", strsplit(r2$stdout, "\n")[[1]], value = TRUE), "|", fixed = TRUE))
extra <- setdiff(tutti[, 1], tab$slurm)
write.table(tab, file.path(DIR, "90-sacct.txt"), sep = "\t", quote = FALSE, row.names = FALSE)
cat(sprintf("\n# job dell'utente dal 2026-11-05 17:00 non registrati dalla catena: %d\n", length(extra)), file = file.path(DIR, "90-sacct.txt"), append = TRUE)
if (length(extra)) write.table(tutti[tutti[, 1] %in% extra, , drop = FALSE], file.path(DIR, "90-sacct.txt"), sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE, append = TRUE)
annota("cancello 3, job registrati: %d; su poddgx02: %d; stati: %s", nrow(tab), sum(tab$nodo == "poddgx02", na.rm = TRUE),
       paste(names(table(tab$stato)), table(tab$stato), collapse = ", "))
annota("cancello 3, job dell'utente nel periodo non registrati dalla catena: %d", length(extra))

cmd <- paste(sprintf("f=/home/u0044/simulomicsr-dgx/runs/%s/container-env.txt; if grep -qx 'VLLM_BATCH_INVARIANT=1' $f 2>/dev/null; then echo '%s|si'; else echo '%s|no'; fi", tab$run_id, tab$run_id, tab$run_id), collapse = "; ")
fl <- do.call(rbind, strsplit(grep("[|]", strsplit(.dgx_ssh(cfg, cmd)$stdout, "\n")[[1]], value = TRUE), "|", fixed = TRUE))
writeLines(sprintf("%s\t%s", fl[, 1], fl[, 2]), file.path(DIR, "90-flag.txt"))
annota("cancello 3, run con VLLM_BATCH_INVARIANT=1 in container-env.txt: %d su %d", sum(fl[, 2] == "si"), nrow(fl))

# --- copia dei due master su micron -----------------------------------------------------------------
fs::dir_create(DEST)
for (f in nuovi[1:2]) fs::file_copy(f, fs::path(DEST, basename(f)), overwrite = FALSE)
writeLines(sub("  analysis/p4-output/", "  ", sh[1:2]), fs::path(DEST, "SHA256SUMS.txt"))
v <- system2("bash", c("-c", shQuote(sprintf("cd %s && sha256sum -c SHA256SUMS.txt", DEST))), stdout = TRUE, stderr = TRUE)
annota("copia su micron (%s): %s", DEST, paste(v, collapse = "; "))

writeLines(esito, file.path(DIR, "90-chiusura.txt"))
