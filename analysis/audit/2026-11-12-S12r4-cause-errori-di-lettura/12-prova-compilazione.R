#!/usr/bin/env Rscript
# PROVA DA BUTTARE
# 12-prova-compilazione.R — S12r4, prima delle corse (01-carta.md par. 8): vLLM 0.20.2 compila gli schemi delle
# 31 forme? Base: 12-prova-compilazione.R di S12r3.
#
# Che cosa prova. Molte forme cambiano solo il prompt: le 31 forme hanno meno di 31 schemi diversi. Per ogni
# CLASSE di schema (forme con gli stessi 48 schemi, carattere per carattere) vanno al modello:
#   - 47 record, uno per studio di sviluppo, con lo schema di quello studio e un messaggio NEUTRO (nessun testo
#     di studio: «scrivi una tabella senza fattori»). Comprende lo schema piu' grande di ogni forma;
#   - lo studio finto GSE0 (lo stesso del controllo positivo di 10-forme.R) col messaggio che detta la tabella;
#   - lo stesso GSE0 con un messaggio che chiede un'uscita che gli schemi chiusi NON ammettono (colonna e valore
#     inventati): se la grammatica vincola, l'uscita finita passa lo stesso lo schema della forma.
# NESSUN TESTO DI STUDIO VA AL MODELLO e il prompt di sistema e' una frase sola: nessuna uscita vera esiste prima
# delle corse. Gli schemi portano i nomi delle colonne e i valori dei 47 studi di sviluppo, come in S12r3.
#
# Esito, per classe: (1) il job finisce e ogni record ha un'uscita (lo schema compila); (2) ogni uscita con fine
# `stop` passa lo schema della forma (validatore_forma); (3) quante uscite finiscono per `length` (le forme con
# una lista aperta possono ripetere fino a max_tokens: non e' un difetto di compilazione, si riporta);
# (4) GSE0: lo strumento (adatta_forma) chiude lo studio? Con quanti gruppi e confronti?
#
# Uso: Rscript analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/12-prova-compilazione.R  (SENZA --vanilla)
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti.R")   # cfg (solo poddgx02), ENV_JOB, attendi(), raccogli(), K5
S12R <- DIR
DIR <- "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs")
for (d in c(LOG, JOBS)) fs::dir_create(d)
source(file.path(DIR, "10-forme.R"))
OUT <- file.path(DIR, "12-out.txt")
nota <- function(...) { scrivi(...); cat(sprintf(...), "\n", sep = "", file = OUT, append = TRUE) }
INGRESSO <- "analysis/input/S12r4-prova-compilazione-ingresso.jsonl"
REV_M <- "95a6d26c4bfb886c58daf9d3f7332c857cb27b43"
MODELLO <- list(model_id = "mistralai/Mistral-Small-3.2-24B-Instruct-2506", llm_extra = list(revision = REV_M, tokenizer_revision = REV_M))
F_VISTE <- file.path(S12R, "60-viste-v0.jsonl")
stopifnot(identical(unname(tools::sha256sum(F_VISTE)), "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"))
viste <- lapply(readLines(F_VISTE, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
id <- vapply(viste, `[[`, "", "record_id"); solo_sviluppo(id); stopifnot(identical(id, studi_sviluppo()))
names(viste) <- id

NEUTRO <- "This is a test of the output format. There is no study and there are no samples. Write a table with zero factors and zero items in not_understood. Give the role uninformative to every column."
SISTEMA <- "You write one JSON object. Follow the instruction of the user."
g0 <- sprintf("GSM%d", 1:12); col <- function(x) as.list(stats::setNames(x, g0))
finto <- list(record_id = "GSE0", campioni = as.list(g0), colonne = list("disease", "stage", "agent", "sex", "title"),
              tabella = list(disease = col(rep(c("healthy", "IBD", "IBD"), each = 4)), stage = col(rep(c("", "II", "III"), each = 4)),
                             agent = col(rep(c("none", "none", "Dex", "Dex"), 3)), sex = col(rep(c("F", "M", "F", "NA"), 3)),
                             title = col(sprintf("sample %d", 1:12))), costanti = list(tissue = "colon"))
TESTO_FINTO <- paste(
  "This is a test of the output format with an invented table of 12 samples.",
  "Columns: disease (values: healthy, IBD), stage (values: empty, II, III), agent (values: none, Dex), sex (values: F, M, NA), title (sample 1 to sample 12).",
  "Write exactly three factors.",
  "Factor 1: name disease, type state, levels healthy and IBD, baseline healthy, assignment from the column disease.",
  "Factor 2: name stage, type state, levels II and III, no baseline, assignment from the column stage; the empty value has the level 'not applicable'.",
  "Factor 3: name compound, type perturbation, levels vehicle and dexamethasone, baseline vehicle, assignment from the column agent.",
  "Columns: disease, stage and agent have the role factor; sex is a subject column of kind sex with the missing value NA; title is a replicate column.", sep = "\n")
TESTO_CONTRO <- paste(
  "This is a test of the output format with an invented table of 12 samples.",
  "Columns: disease (values: healthy, IBD), stage (values: empty, II, III), agent (values: none, Dex), sex (values: F, M, NA), title (sample 1 to sample 12).",
  "Write exactly one factor: name stage, type state, levels II and III, no baseline.",
  "In the assignment, write the column name as 'Stage (grade)'. Write only one entry in values: the value 'grade 3' with the level III. Do not write any other entry.",
  "Columns: write only one entry, for the column 'gender', with role subject and the missing value 'unknown'.", sep = "\n")

# ---- le classi di schema: forme con gli stessi 48 schemi (47 studi + GSE0) ----
tutte <- c(viste, list(GSE0 = finto))
impronta <- vapply(names(FORME), function(n) digest::digest(paste(vapply(tutte, schema_json_forma, "", nome = n), collapse = "\n"), algo = "sha256", serialize = FALSE), "")
classi <- split(names(FORME), factor(impronta, levels = unique(impronta))); names(classi) <- vapply(classi, `[`, "", 1L)
rec <- function(i, testo, sch, mt) as.character(toJSON(list(record_id = i, testo = testo, schema = sch, max_tokens = mt), auto_unbox = TRUE, null = "null"))
piano <- do.call(rbind, lapply(names(classi), function(k) data.frame(
  classe = k, studio = c(id, "GSE0", "GSE0"), tipo = c(rep("neutro", length(id)), "finto", "contro"), stringsAsFactors = FALSE)))
piano$record_id <- sprintf("%s__%s__%s", piano$classe, piano$studio, piano$tipo)
stopifnot(!anyDuplicated(piano$record_id))
righe <- vapply(seq_len(nrow(piano)), function(i) {
  v <- tutte[[piano$studio[i]]]
  rec(piano$record_id[i], switch(piano$tipo[i], neutro = NEUTRO, finto = TESTO_FINTO, contro = TESTO_CONTRO),
      schema_forma(v, piano$classe[i]), if (piano$tipo[i] == "neutro") 2048L else 4096L)
}, "")
con <- file(INGRESSO, "wb"); writeLines(enc2utf8(righe), con, useBytes = TRUE); close(con)
if (!file.exists(OUT)) cat("12-prova-compilazione.R  PROVA DA BUTTARE\n", file = OUT)
nota("inizio %s, HEAD %s; %d forme in %d classi di schema; ingresso %s: %d record (per classe: 47 studi di sviluppo col messaggio neutro + GSE0 finto + GSE0 contro), %.1f MB",
     format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE),
     length(FORME), length(classi), INGRESSO, length(righe), file.size(INGRESSO) / 1e6)
for (k in names(classi)) nota("classe %s: %s; schema piu' grande %d caratteri", k, paste(classi[[k]], collapse = ", "),
                              max(nchar(vapply(viste, schema_json_forma, "", nome = k))))
utils::write.csv(data.frame(forma = unlist(classi, use.names = FALSE), classe = rep(names(classi), lengths(classi))),
                 file.path(DIR, "12-classi-di-schema.csv"), row.names = FALSE)

monta <- ssh_ripeti(function() .dgx_ssh(cfg, sprintf(
  "srun --partition=%s --account=%s --nodelist=poddgx02 --time=00:03:00 --cpus-per-task=1 --mem=1G bash -c 'hostname; test -d %s/bundles && test -d %s/runs && echo MONTATO'",
  cfg$partition, cfg$account, cfg$remote_root, cfg$remote_root)))
if (!grepl("poddgx02", monta$stdout, fixed = TRUE) || !grepl("MONTATO", monta$stdout, fixed = TRUE)) ferma("/home non montato su poddgx02: %s", gsub("\n", " ", monta$stdout))
nota("mount: %s", gsub("\n", " ", trimws(monta$stdout)))

f <- file.path(JOBS, "prova-compilazione.rds")
if (file.exists(f)) j <- readRDS(f) else {
  b <- dgx_p4_build_bundle(INGRESSO, stage = "stage2b", config = cfg,
                           metadata = list(slug = "s12r4-prova-compilazione", prova = "S12r4 compilazione degli schemi delle forme"), modello = MODELLO)
  bd <- b$bundle_dir
  writeLines(SISTEMA, fs::path(bd, "prompt.txt"))
  gp <- fs::path(bd, "generation.json"); g <- read_json(gp)
  g$max_model_len <- 65536L; g$max_tokens <- 24576L; g$gpu_memory_utilization <- 0.95
  .dgx_write_generation_json(g, gp)
  nota("bundle %s; generation.json: %s", b$run_id, as.character(toJSON(read_json(gp), auto_unbox = TRUE)))
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = "02:00:00", env = ENV_JOB)); saveRDS(j, f)
  nota("inviato: slurm %s, run_id %s", j$slurm_job_id, j$run_id)
}
m <- attendi(list(j), 60L); raccogli(j)
nota("slurm %s %s, durata %s, nodo %s", m[1, 1], m[1, 2], m[1, 3], m[1, 4])

# ---- controllo delle uscite ----
p <- file.path("analysis/p4-output", j$run_id, "predictions.jsonl")
pr <- lapply(readLines(p, warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
pr <- stats::setNames(pr, vapply(pr, `[[`, "", "record_id"))
esito <- do.call(rbind, lapply(seq_len(nrow(piano)), function(i) {
  x <- pr[[piano$record_id[i]]]; v <- tutte[[piano$studio[i]]]; k <- piano$classe[i]
  if (is.null(x)) return(data.frame(piano[i, ], uscita = FALSE, fine = NA, token = NA, valida = NA, chiuso = NA, gruppi = NA, confronti = NA, motivi = ""))
  raw <- as.character(x$raw_output %||% NA); fine <- as.character(x$finish_reason %||% NA)
  val <- if (is.na(raw) || !nzchar(raw)) FALSE else isTRUE(tryCatch(validate_json(raw, validatore_forma(v, k))$valid, error = function(e) FALSE))
  r <- if (piano$tipo[i] == "finto") adatta_forma(v, raw, FALSE, fine, k) else NULL
  data.frame(piano[i, ], uscita = !is.na(raw) && nzchar(raw), fine = fine, token = as.numeric(x$n_output_tokens %||% NA), valida = val,
             chiuso = if (is.null(r)) NA else isTRUE(r$chiuso), gruppi = if (is.null(r) || !isTRUE(r$chiuso)) NA else r$n_gruppi,
             confronti = if (is.null(r) || !isTRUE(r$chiuso)) NA else nrow(r$confronti), motivi = if (is.null(r)) "" else unisci(nomi_motivi(r)))
}))
utils::write.csv(esito, file.path(DIR, "12-esito.csv"), row.names = FALSE)
per_classe <- do.call(rbind, lapply(names(classi), function(k) {
  e <- esito[esito$classe == k, ]; n <- e[e$tipo == "neutro", ]; fi <- e[e$tipo == "finto", ]; co <- e[e$tipo == "contro", ]
  data.frame(classe = k, forme = paste(classi[[k]], collapse = " "), record = nrow(e), con_uscita = sum(e$uscita),
             neutro_stop = sum(n$fine %in% "stop"), neutro_length = sum(n$fine %in% "length"), neutro_stop_valide = sum(n$valida[n$fine %in% "stop"]),
             neutro_token_max = max(n$token, na.rm = TRUE),
             finto_fine = fi$fine, finto_token = fi$token, finto_valida = fi$valida, finto_chiuso = fi$chiuso, finto_gruppi = fi$gruppi,
             finto_confronti = fi$confronti, finto_motivi = fi$motivi, contro_fine = co$fine, contro_token = co$token, contro_valida = co$valida)
}))
utils::write.csv(per_classe, file.path(DIR, "12-esito-per-classe.csv"), row.names = FALSE)
for (i in seq_len(nrow(per_classe))) with(per_classe[i, ], nota(
  "classe %s: uscite %d/%d; neutro: stop %d, length %d, valide fra le finite %d/%d, token massimo %.0f; GSE0 finto: fine %s, %.0f token, valida %s, chiuso %s (gruppi %s, confronti %s%s); GSE0 contro: fine %s, %.0f token, valida %s",
  classe, con_uscita, record, neutro_stop, neutro_length, neutro_stop_valide, neutro_stop, neutro_token_max, finto_fine, finto_token, finto_valida,
  finto_chiuso, finto_gruppi, finto_confronti, if (nzchar(finto_motivi)) paste0("; motivi ", finto_motivi) else "", contro_fine, contro_token, contro_valida))
stop_e <- esito[esito$fine %in% "stop", ]
nota("ESITO: record %d, con uscita %d; fine stop %d, di cui valide per lo schema della forma %d; fine length %d; classi con tutte le uscite %d/%d",
     nrow(esito), sum(esito$uscita), nrow(stop_e), sum(stop_e$valida), sum(esito$fine %in% "length"),
     sum(per_classe$con_uscita == per_classe$record), nrow(per_classe))
if (any(!esito$uscita) || any(!stop_e$valida)) ferma("PROVA DI COMPILAZIONE: non passa (record senza uscita %d, uscite finite non valide %d)", sum(!esito$uscita), sum(!stop_e$valida))
nota("PROVA DI COMPILAZIONE: PASSA (ogni record ha un'uscita e ogni uscita finita passa lo schema della sua forma)")
