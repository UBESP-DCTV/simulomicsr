#!/usr/bin/env Rscript
# S14, prima parte: i due passi col modello sull'intero corpus, da zero, in un solo run. Attese: 00-previsioni.md.
# Base: analysis/audit/2026-11-04-S8b-prova/50-notte.R. Ogni passo scrive stato/<passo>.done e si puo' riprendere.
# Uso: setsid nohup Rscript analysis/audit/2026-11-05-S14-re-run-modello/50-catena.R >> .../log/catena.out 2>&1 < /dev/null &
# Prova breve: SOLO_PROVA=1 Rscript analysis/audit/2026-11-05-S14-re-run-modello/50-catena.R
suppressPackageStartupMessages({ library(jsonlite); library(fs) })
suppressMessages(pkgload::load_all(".", quiet = TRUE))
DIR <- "analysis/audit/2026-11-05-S14-re-run-modello"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs"); ST <- file.path(DIR, "stato"); S8 <- "analysis/audit/2026-11-04-S8b-prova"
IN1 <- "analysis/input/archs4-human-stage1-input-v2.jsonl"; SHUF <- "analysis/input/S14-stage1-input-shuffled.jsonl"; OUTL <- "analysis/input/S14-stage1-outliers.jsonl"; CHUNKS <- "analysis/input/S14-chunks"
PRED1 <- "analysis/p4-output/S14-stage1-predictions-rescued.jsonl"; M1 <- "analysis/p4-output/S14-stage1-master.jsonl"; M2 <- "analysis/p4-output/S14-stage2-master.jsonl"
IN2 <- "analysis/input/S14-stage2-input.jsonl"; RES2 <- "analysis/input/S14-stage2-rescue.jsonl"; COLL2 <- "analysis/p4-output/S14-stage2-collect.rds"; COLLR2 <- "analysis/p4-output/S14-stage2-rescue-collect.rds"
# Solo riferimenti, nessun record entra nei master nuovi.
RIF1 <- "analysis/p4-output/S8b-stage1-master-innestato.jsonl"; OLD1 <- "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl"; OLD2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
A3S <- readLines("analysis/audit/2026-08-16-A3/A3-studi.txt"); NUOVI <- readLines(file.path(S8, "campione-nuovi.txt")); RIF_STUDI <- c(A3S, NUOVI)
if (anyDuplicated(RIF_STUDI) || length(RIF_STUDI) != 8566L) stop("riferimento: attesi 8.566 studi distinti")
N_PARTI <- 12L; SEME <- 20261105L; SOGLIA1 <- 0.999; SOGLIA2 <- 0.988
PROVA <- nzchar(Sys.getenv("SOLO_PROVA"))
cfg <- dgx_config(nodelist = "poddgx02")  # solo poddgx02: poddgx01 e' vietato dal PI
stopifnot(identical(cfg$nodelist, "poddgx02"))

temp <- function() { x <- tryCatch(system("sensors 2>/dev/null | grep Tctl", intern = TRUE), error = function(e) "?"); g <- tryCatch(system("nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader", intern = TRUE), error = function(e) "?"); paste0(sub("^.*\\+([0-9.]+).*$", "\\1", x[1]), "C RTX=", g[1]) }
scrivi <- function(...) { msg <- sprintf("[%s] T=%sC %s", format(Sys.time(), "%m-%d %H:%M:%S"), temp(), sprintf(...)); cat(msg, "\n", sep = ""); cat(msg, "\n", sep = "", file = file.path(LOG, "catena.log"), append = TRUE); flush.console() }
ferma <- function(...) { scrivi("FERMO: %s", sprintf(...)); stop(sprintf(...), call. = FALSE) }
passo <- function(nome, expr) {
  f <- file.path(ST, paste0(nome, ".done"))
  if (file.exists(f)) { scrivi("passo %s gia' fatto", nome); return(invisible(NULL)) }
  scrivi("INIZIO %s", nome); t0 <- Sys.time(); force(expr)
  writeLines(format(Sys.time()), f); scrivi("FINE %s (%.1f min)", nome, as.numeric(difftime(Sys.time(), t0, units = "mins")))
}
ssh_ripeti <- function(fun) { for (i in 1:30) { r <- tryCatch(fun(), error = function(e) e); if (!inherits(r, "error")) return(r); scrivi("ssh in errore (%d): %s", i, conditionMessage(r)); Sys.sleep(60) }; ferma("ssh non risponde da 30 minuti") }
id_job <- function(jobs) vapply(jobs, function(j) as.character(j$slurm_job_id), character(1), USE.NAMES = FALSE)
stati_sacct <- function(jobs) {
  ids <- id_job(jobs)
  for (i in 1:60) {
    r <- tryCatch(.dgx_ssh(cfg, sprintf("sacct -X -n -P -j %s -o JobID,State,Elapsed,NodeList", paste(ids, collapse = ","))), error = function(e) NULL)
    righe <- if (is.null(r)) character(0) else grep("[|]", strsplit(r$stdout, "\n")[[1]], value = TRUE)
    m <- do.call(rbind, strsplit(righe, "|", fixed = TRUE))
    if (!is.null(m) && ncol(m) == 4L && all(ids %in% m[, 1])) {
      m <- m[match(ids, m[, 1]), , drop = FALSE]
      partiti <- !grepl("^None", m[, 4]); if (any(m[partiti, 4] != "poddgx02")) { cancella(jobs); ferma("CANCELLO 3: job fuori da poddgx02: %s", paste(m[partiti & m[, 4] != "poddgx02", 1], collapse = " ")) }
      return(m)
    }
    scrivi("sacct senza risposta completa (%d), riprovo fra un minuto", i); Sys.sleep(60)
  }
  ferma("sacct non risponde da un'ora")
}
cancella <- function(jobs) { ssh_ripeti(function() .dgx_ssh(cfg, sprintf("scancel %s", paste(id_job(jobs), collapse = " ")))); scrivi("tolti dalla coda %d job", length(jobs)) }
FINE <- "^(COMPLETED|FAILED|CANCELLED|TIMEOUT|NODE_FAIL|OUT_OF_MEMORY|PREEMPTED|BOOT_FAIL|DEADLINE)"
attendi_n <- function(jobs, n, ogni = 120L) {
  repeat {
    m <- stati_sacct(jobs); st <- sub(" .*$", "", m[, 2]); male <- grepl(FINE, st) & st != "COMPLETED"
    if (any(male)) ferma("job non completati: %s (%s)", paste(m[male, 1], collapse = " "), paste(st[male], collapse = " "))
    if (sum(st == "COMPLETED") >= n) break
    scrivi("job: %s", paste(names(table(st)), table(st), collapse = ", ")); Sys.sleep(ogni)
  }
  for (i in which(st == "COMPLETED")) scrivi("slurm %s: %s %s %s", m[i, 1], m[i, 2], m[i, 3], m[i, 4])
  jobs[st == "COMPLETED"]
}
attendi <- function(jobs, ogni = 120L) invisible(attendi_n(jobs, length(jobs), ogni))
cfr_bundle <- function(b, rif, file = c("prompt.txt", "schema.json", "generation.json")) {
  dr <- as.character(fs::dir_ls("analysis/p4-bundles", glob = paste0("*-", rif, "-*"))); if (length(dr) < 1L) ferma("CANCELLO 3: bundle di riferimento %s assente", rif)
  dr <- dr[length(dr)]
  for (f in file) if (!identical(unname(tools::md5sum(fs::path(b$bundle_dir, f))), unname(tools::md5sum(fs::path(dr, f))))) ferma("CANCELLO 3: %s diverso dal bundle %s", f, rif)
}
invia <- function(p, stage, slug, time, tiered = NULL, gen_over = NULL, rif = NULL, rif_file = c("prompt.txt", "schema.json", "generation.json")) {
  f <- file.path(JOBS, paste0(slug, ".rds")); if (file.exists(f)) return(readRDS(f))
  args <- list(p, stage = stage, config = cfg, metadata = list(slug = slug)); if (!is.null(tiered)) args$tiered_max_tokens <- tiered
  b <- ssh_ripeti(function() do.call(dgx_p4_build_bundle, args))
  if (!is.null(gen_over)) { gp <- fs::path(b$bundle_dir, "generation.json"); g <- jsonlite::read_json(gp); for (n in names(gen_over)) g[[n]] <- gen_over[[n]]; jsonlite::write_json(g, gp, auto_unbox = TRUE, pretty = TRUE, null = "null") }
  if (!is.null(rif)) cfr_bundle(b, rif, rif_file)
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = time, env = c(VLLM_BATCH_INVARIANT = "1")))
  saveRDS(j, f); scrivi("inviato %s slurm=%s run_id=%s", slug, j$slurm_job_id, j$run_id); j
}
raccogli <- function(j) { d <- ssh_ripeti(function() dgx_p4_collect(j)); p <- file.path("analysis/p4-output", j$run_id, "container-env.txt"); if (!file.exists(p) || !any(grepl("^VLLM_BATCH_INVARIANT=1$", readLines(p)))) ferma("CANCELLO 3: flag assente in %s", j$run_id); scrivi("cancello 3: flag presente in %s", j$run_id); d }
rid_di <- function(x) sub('^.*"record_id": ?"([^"]+)".*$', "\\1", x)
sid_di <- function(x) sub('^.*?"series_id":"([^"]+)".*$', "\\1", x, perl = TRUE)
valid <- function(x) grepl('"valid_schema": *true', x)
raw_di <- function(l) vapply(l, function(x) { v <- fromJSON(x, simplifyVector = FALSE)$raw_output; if (is.null(v)) NA_character_ else v }, character(1), USE.NAMES = FALSE)
Rs <- function(script, env, log) { rc <- system2("Rscript", script, env = env, stdout = file.path(LOG, log), stderr = file.path(LOG, log)); if (rc != 0L) ferma("%s rc=%d, vedi log/%s", script, rc, log); invisible(rc) }
ci_txt <- function(x, n) { ci <- binom.test(x, n)$conf.int; sprintf("%d su %d = %.3f%% [%.3f; %.3f]", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
# Riferimenti, letti una volta sola.
MEMO <- new.env()
gsm_rif <- function() { if (is.null(MEMO$g)) { i <- readLines(IN1, warn = FALSE); MEMO$g <- sub('^.*"record_id":"([^"]+)".*$', "\\1", i)[sub('^.*"series_id":"([^"]+)".*$', "\\1", i) %in% RIF_STUDI] }; MEMO$g }
rif1 <- function() { if (is.null(MEMO$r1)) { m <- readLines(RIF1, warn = FALSE); MEMO$r1 <- list(l = m, id = rid_di(m)) }; MEMO$r1 }
rif2_raw <- function() { if (is.null(MEMO$r2)) { a <- readRDS("analysis/p4-output/A3-stage2-collect.rds")$predictions; b <- readRDS("analysis/p4-output/S8b-stage2-collect.rds")$predictions; a <- a[sub("#.*$", "", a$record_id) %in% A3S, c("record_id", "raw_output")]; b <- b[sub("#.*$", "", b$record_id) %in% NUOVI, c("record_id", "raw_output")]; MEMO$r2 <- rbind(as.data.frame(a), as.data.frame(b)) }; MEMO$r2 }
# Confronto dei record validi dello Stadio 1 con il riferimento: restituisce i booleani.
cfr1 <- function(rr) { rr <- rr[valid(rr)]; id <- rid_di(rr); g <- id %in% gsm_rif(); r <- rif1(); pos <- match(id[g], r$id); ug <- raw_di(rr[g]) == raw_di(r$l[pos]); ug[is.na(ug)] <- FALSE; ug }
# Confronto dello Stadio 2 con il riferimento, per studio: uno studio e' identico se lo sono tutti i suoi record con un riferimento.
cfr2 <- function(p) { s <- sub("#.*$", "", p$record_id); g <- s %in% RIF_STUDI & p$record_id %in% rif2_raw()$record_id; ii <- match(p$record_id[g], rif2_raw()$record_id); ug <- p$raw_output[g] == rif2_raw()$raw_output[ii]; ug[is.na(ug)] <- FALSE; tapply(ug, s[g], all) }

# ---- prova breve, solo se richiesta -----------------------------------------------------------------------
if (PROVA) {
  set.seed(SEME); out <- character(0)
  i1 <- readLines(IN1, warn = FALSE); id1 <- sub('^.*"record_id":"([^"]+)".*$', "\\1", i1); pool <- i1[id1 %in% gsm_rif()]; p1 <- "analysis/input/S14-prova-stage1.jsonl"; writeLines(sample(pool, 200L), p1); rm(i1, id1, pool)
  j1 <- invia(p1, "stage1", "s14-prova-s1", "01:00:00", rif = "s8b-s1-chunk-00"); attendi(list(j1), 30L); d1 <- raccogli(j1)
  l1 <- readLines(file.path(d1$run_dir, "predictions.jsonl"), warn = FALSE); u1 <- cfr1(l1); out <- c(out, sprintf("Stadio 1: %d righe, valide %d, identiche al riferimento %d su %d", length(l1), sum(valid(l1)), sum(u1), length(u1)))
  s2 <- readLines("analysis/input/A3-stage2-subset.jsonl", warn = FALSE); s2 <- s2[!grepl("#[0-9]+of", rid_di(s2)) & nchar(s2) < 6000L]; p2 <- "analysis/input/S14-prova-stage2.jsonl"; writeLines(sample(s2, 12L), p2)
  # Solo nella prova breve: 12 record piccoli sono tutti di tier S, quindi il max_tokens globale di generation.json vale 4096 e non 32768.
  # Il valore globale e' solo il ripiego: ogni record porta il suo. Nel run vero ogni parte ha record XL e il confronto resta su tutto il file.
  j2 <- invia(p2, "stage2", "s14-prova-s2", "01:00:00", tiered = TRUE, rif = "s8b-s2-parte1", rif_file = c("prompt.txt", "schema.json")); attendi(list(j2), 30L); d2 <- raccogli(j2)
  g2 <- read_json(file.path("analysis/p4-bundles", j2$run_id, "generation.json")); g0 <- read_json(file.path(as.character(fs::dir_ls("analysis/p4-bundles", glob = "*-s8b-s2-parte1-*")), "generation.json")); g2$max_tokens <- g0$max_tokens <- NULL; if (!identical(g2, g0)) ferma("CANCELLO 3: generation.json della prova breve diverso anche oltre max_tokens")
  u2 <- cfr2(d2$predictions); out <- c(out, sprintf("Stadio 2: %d record validi, errori %d, studi identici al riferimento %d su %d", nrow(d2$predictions), nrow(d2$errors), sum(u2), length(u2)))
  m <- stati_sacct(list(j1, j2)); out <- c(out, sprintf("slurm %s %s %s %s", m[, 1], m[, 2], m[, 3], m[, 4])); writeLines(out, file.path(DIR, "20-prova-breve.txt")); for (l in out) scrivi("%s", l)
  quit(save = "no")
}

# ---- 1. Stadio 1 -----------------------------------------------------------------------------------------
passo("s1-blocchi", {
  rc <- system2("bash", c("-c", shQuote(sprintf("shuf --random-source=<(yes 42) %s > %s", shQuote(IN1), shQuote(SHUF))))); if (rc != 0L) ferma("shuf rc=%d", rc)
  raw <- readLines(SHUF, warn = FALSE); df <- jsonlite::stream_in(file(SHUF), verbose = FALSE); idx <- which(nchar(df$string) > 3500L)
  fs::dir_create(CHUNKS); if (length(idx)) writeLines(raw[idx], OUTL); main <- if (length(idx)) raw[-idx] else raw
  n <- ceiling(length(main) / 10000L)
  for (i in seq_len(n)) writeLines(main[((i-1L)*10000L+1L):min(i*10000L, length(main))], fs::path(CHUNKS, sprintf("chunk-%02d.jsonl", i-1L)))
  rl <- unlist(lapply(fs::dir_ls(CHUNKS, glob = "*.jsonl"), readLines, warn = FALSE), use.names = FALSE); if (length(idx)) rl <- c(rl, raw[idx])
  if (length(raw) != 508037L || length(rl) != length(raw) || anyDuplicated(rl) || !setequal(rl, readLines(IN1, warn = FALSE))) ferma("CANCELLO 2: taglio dei blocchi non coerente")
  scrivi("cancello 2: record %d, outlier %d, blocchi %d, identici all'input", length(raw), length(idx), n)
  scrivi("mescolamento identico a quello di maggio: %s", identical(unname(tools::md5sum(SHUF)), unname(tools::md5sum("analysis/input/archs4-human-stage1-v2-shuffled.jsonl"))) || identical(unname(tools::md5sum(SHUF)), unname(tools::md5sum("analysis/input/archs4-human-stage1-input-v2-shuffled.jsonl"))))
})
if (nzchar(Sys.getenv("SOLO_BLOCCHI"))) quit(save = "no")
blocchi <- c(as.character(fs::dir_ls(CHUNKS, glob = "*.jsonl")), if (file.exists(OUTL)) OUTL)
jobs1 <- lapply(blocchi, function(p) invia(p, "stage1", paste0("s14-s1-", sub("[.]jsonl$", "", basename(p))), "72:00:00", rif = "s8b-s1-chunk-00"))
passo("s1-cancello5", {
  fatti <- attendi_n(jobs1, 2L, 60L); rr <- unlist(lapply(fatti[1:2], function(j) readLines(file.path(raccogli(j)$run_dir, "predictions.jsonl"), warn = FALSE)), use.names = FALSE)
  ug <- cfr1(rr); msg <- sprintf("cancello 5, Stadio 1, primi due blocchi, record identici al riferimento: %s", ci_txt(sum(ug), length(ug))); writeLines(msg, file.path(DIR, "30-cancello5-s1.txt")); scrivi("%s", msg)
  if (mean(ug) < SOGLIA1) { cancella(jobs1); ferma("CANCELLO 5 fallito sullo Stadio 1") }
})
passo("s1-attesa", attendi(jobs1, 300L))
passo("s1-raccolta", {
  rr <- unlist(lapply(jobs1, function(j) readLines(file.path(raccogli(j)$run_dir, "predictions.jsonl"), warn = FALSE)), use.names = FALSE)
  rid <- rid_di(rr); att <- sub('^.*"record_id":"([^"]+)".*$', "\\1", readLines(IN1, warn = FALSE))
  scrivi("raccolti %d, attesi %d, mancanti %d, estranei %d, duplicati %d, validi %d", length(rr), length(att), length(setdiff(att, rid)), length(setdiff(rid, att)), sum(duplicated(rid)), sum(valid(rr)))
  if (length(setdiff(rid, att)) || anyDuplicated(rid)) ferma("CANCELLO 2: raccolta Stadio 1 non coerente")
  writeLines(rr, "analysis/p4-output/S14-stage1-predictions.jsonl")
})
passo("s1-recupero", {
  rr <- readLines("analysis/p4-output/S14-stage1-predictions.jsonl", warn = FALSE); inp <- readLines(IN1, warn = FALSE); inp_id <- sub('^.*"record_id":"([^"]+)".*$', "\\1", inp)
  conf <- list(list(rep = 1.2, mt = 4096L, ml = 8192L), list(rep = 1.3, mt = 8192L, ml = 16384L), list(rep = 1.4, mt = 8192L, ml = 16384L))
  for (k in seq_along(conf)) {
    rid <- rid_di(rr); dafare <- union(rid[!valid(rr)], setdiff(inp_id, rid)); scrivi("recupero %d: %d da rifare", k, length(dafare)); if (!length(dafare)) break
    p <- sprintf("analysis/input/S14-stage1-rescue%d.jsonl", k); writeLines(inp[inp_id %in% dafare], p)
    j <- invia(p, "stage1", sprintf("s14-s1-rescue%d", k), "72:00:00", gen_over = list(max_tokens = conf[[k]]$mt, repetition_penalty = conf[[k]]$rep, max_model_len = conf[[k]]$ml), rif = sprintf("s8b-s1-rescue%d", k))
    attendi(list(j), 60L); d <- raccogli(j)
    nu <- readLines(file.path(d$run_dir, "predictions.jsonl"), warn = FALSE); nu <- nu[valid(nu)]; nid <- rid_di(nu)
    keep <- !(rid %in% nid); rr <- c(rr[keep], nu); scrivi("recupero %d: recuperati %d", k, length(nu))
  }
  rid <- rid_di(rr); res <- union(rid[!valid(rr)], setdiff(inp_id, rid)); scrivi("Q3: campioni senza record valido dopo il recupero: %d", length(res)); writeLines(res, file.path(DIR, "residui-stadio1.txt"))
  writeLines(rr, PRED1)
})
passo("s1-master", {
  rr <- readLines(PRED1, warn = FALSE); rid <- rid_di(rr); o <- rid_di(readLines(OLD1, warn = FALSE))
  if (anyDuplicated(rid) || length(setdiff(rid, o))) ferma("CANCELLO 2: master Stadio 1 con record duplicati o estranei")
  pos <- match(o, rid); assenti <- o[is.na(pos)]; writeLines(rr[pos[!is.na(pos)]], M1); scrivi("master Stadio 1: %d record, assenti %d, ordine del master di maggio", sum(!is.na(pos)), length(assenti))
})
passo("s1-confronto", {
  rr <- readLines(M1, warn = FALSE); rid <- rid_di(rr); g <- intersect(gsm_rif(), rid); r <- rif1(); o <- readLines(OLD1, warn = FALSE); o_id <- rid_di(o)
  rn <- raw_di(rr[match(g, rid)]); ra <- raw_di(r$l[match(g, r$id)]); ro <- raw_di(o[match(g, o_id)])
  ug <- rn == ra; ug[is.na(ug)] <- FALSE; ug0 <- ra == ro; ug0[is.na(ug0)] <- FALSE
  pl <- rn; pl[1] <- paste0(pl[1], "x"); vis <- sum(pl != rn, na.rm = TRUE)
  out <- c(sprintf("Q1 record identici al riferimento, tutti: %s", ci_txt(sum(ug), length(ug))), sprintf("record di riferimento attesi %d, con un record nel run nuovo %d", length(gsm_rif()), length(g)),
           sprintf("cancello 4 negativo: vecchio senza flag contro riferimento, identici %d su %d (deve essere meno di tutti)", sum(ug0), length(ug0)), sprintf("cancello 4 positivo: differenza piantata, viste %d", vis), sprintf("record diversi: %s", paste(head(g[!ug], 50), collapse = " ")))
  writeLines(out, file.path(DIR, "60-s1-confronto.txt")); for (l in out) scrivi("%s", l)
  if (sum(ug0) == length(ug0) || vis != 1L) ferma("CANCELLO 4 fallito sullo Stadio 1")
  if (mean(ug) < SOGLIA1) ferma("Q1 fuori dall'intervallo: mi fermo prima dello Stadio 2")
})

# ---- 2. Stadio 2 -----------------------------------------------------------------------------------------
passo("s2-input", {
  Rs("analysis/p4-fase-f4-stage2-build-input-v3.R", c(sprintf("STAGE1_PREDS_PATH=%s", M1), sprintf("OUT_JSONL=%s", IN2)), "build-s2.log")
  n <- readLines(IN2, warn = FALSE); sn <- sid_di(n); a <- readLines("analysis/input/A3-stage2-subset.jsonl", warn = FALSE); b <- readLines("analysis/input/S8b-stage2-subset.jsonl", warn = FALSE); b <- b[sid_di(b) %in% NUOVI]
  r <- c(a, b); sr <- sid_di(r); ln <- split(n, sn); lr <- split(r, sr); ug <- vapply(RIF_STUDI, function(s) identical(ln[[s]], lr[[s]]), logical(1))
  out <- c(sprintf("input Stadio 2: %d record, %d studi", length(n), length(unique(sn))), sprintf("studi di riferimento con input byte-identico: %s", ci_txt(sum(ug), length(ug))), sprintf("studi diversi: %s", paste(head(names(ug)[!ug], 50), collapse = " ")))
  writeLines(out, file.path(DIR, "61-s2-input.txt")); for (l in out) scrivi("%s", l)
  if (mean(ug) < SOGLIA1) ferma("input dello Stadio 2 diverso dal riferimento oltre lo 0,1%%: mi fermo")
})
PART2 <- sprintf("analysis/input/S14-stage2-parte%02d.jsonl", seq_len(N_PARTI))
passo("s2-parti", {
  n <- readLines(IN2, warn = FALSE); sn <- sid_di(n); nc <- tapply(nchar(n), sn, sum); set.seed(SEME); ordine <- sample(names(nc))
  bin <- numeric(N_PARTI); dove <- vector("list", N_PARTI); for (s in ordine) { b <- which.min(bin); bin[b] <- bin[b] + nc[[s]]; dove[[b]] <- c(dove[[b]], s) }
  for (k in seq_len(N_PARTI)) writeLines(n[sn %in% dove[[k]]], PART2[k]); scrivi("parti Stadio 2, milioni di caratteri: %s", paste(round(bin / 1e6, 1), collapse = " "))
  if (!setequal(sn, unlist(dove)) || anyDuplicated(unlist(dove))) ferma("CANCELLO 2: le parti non coprono l'input")
})
jobs2 <- lapply(seq_len(N_PARTI), function(k) invia(PART2[k], "stage2", sprintf("s14-s2-parte%02d", k), "72:00:00", tiered = TRUE, rif = "s8b-s2-parte1"))
passo("s2-cancello5", {
  fatti <- attendi_n(jobs2, 1L, 300L); d <- raccogli(fatti[[1]]); u <- cfr2(d$predictions); msg <- sprintf("cancello 5, Stadio 2, prima parte, studi identici al riferimento: %s", ci_txt(sum(u), length(u))); writeLines(msg, file.path(DIR, "31-cancello5-s2.txt")); scrivi("%s", msg)
  if (mean(u) < SOGLIA2) { cancella(jobs2); ferma("CANCELLO 5 fallito sullo Stadio 2") }
})
passo("s2-attesa", attendi(jobs2, 300L))
passo("s2-raccolta", {
  ds <- lapply(jobs2, raccogli); d <- list(predictions = dplyr::bind_rows(lapply(ds, `[[`, "predictions")), errors = dplyr::bind_rows(lapply(ds, `[[`, "errors")), run_dir = vapply(ds, function(x) as.character(x$run_dir), character(1)))
  if (anyDuplicated(d$predictions$record_id)) ferma("CANCELLO 2: record duplicati nella raccolta Stadio 2")
  saveRDS(d, COLL2); scrivi("Stadio 2: valide %d, errori %d", nrow(d$predictions), nrow(d$errors))
  m <- stati_sacct(jobs2); h <- sum(vapply(strsplit(m[, 3], ":"), function(x) { x <- as.numeric(x); sum(x * c(1, 1/60, 1/3600)) }, numeric(1))); scrivi("Q6: ore di job dello Stadio 2: %.2f", h)
})
passo("s2-recupero", {
  d <- readRDS(COLL2); inp <- readLines(IN2, warn = FALSE); iid <- sub('^.*?"record_id":"([^"]+)".*$', "\\1", inp, perl = TRUE); sid <- sid_di(inp)
  man <- setdiff(iid, d$predictions$record_id); aff <- unique(sid[iid %in% man]); scrivi("Q5: record mancanti %d, studi da recuperare %d", length(man), length(aff)); writeLines(aff, file.path(DIR, "studi-recupero-s2.txt"))
  if (!length(aff)) { file.create(RES2); saveRDS(list(predictions = data.frame()), COLLR2) } else {
    Rs(file.path(DIR, "45-rescue-build-s2.R"), c(sprintf("AFFECTED_FILE=%s/studi-recupero-s2.txt", DIR), sprintf("STAGE1_PREDS_PATH=%s", M1), sprintf("OUT_JSONL=%s", RES2), "MAX_TREATED=12"), "rescue-build-s2.log")
    membri <- function(l) tapply(l, sid_di(l), function(x) sort(unique(unlist(lapply(x, function(y) unlist(lapply(fromJSON(y, simplifyVector = FALSE)$samples, function(s) unlist(s$member_sample_ids))))))), simplify = FALSE)
    rl <- readLines(RES2, warn = FALSE); m1 <- membri(rl); m0 <- membri(inp[sid %in% aff]); if (!setequal(names(m1), aff) || !all(vapply(aff, function(s) identical(m1[[s]], m0[[s]]), logical(1)))) ferma("CANCELLO 2: i campioni del recupero non coincidono con l'input")
    rr_id <- sub('^.*?"record_id":"([^"]+)".*$', "\\1", rl, perl = TRUE); conf <- c(1.2, 1.3, 1.4); pred <- NULL
    for (k in seq_along(conf)) {
      dafare <- if (is.null(pred)) rr_id else setdiff(rr_id, pred$record_id); scrivi("recupero Stadio 2, giro %d: %d record", k, length(dafare)); if (!length(dafare)) break
      p <- sprintf("analysis/input/S14-stage2-rescue-giro%d.jsonl", k); writeLines(rl[rr_id %in% dafare], p)
      jr <- invia(p, "stage2", sprintf("s14-s2-rescue%d", k), "72:00:00", tiered = FALSE, gen_over = list(max_tokens = 32768L, repetition_penalty = conf[k]), rif = "s8b-s2-rescue", rif_file = if (k == 1L) c("prompt.txt", "schema.json", "generation.json") else c("prompt.txt", "schema.json"))
      attendi(list(jr), 120L); dr <- raccogli(jr); pred <- dplyr::bind_rows(pred, dr$predictions); scrivi("recupero Stadio 2, giro %d: valide %d", k, nrow(dr$predictions))
    }
    saveRDS(list(predictions = pred), COLLR2); res <- setdiff(rr_id, pred$record_id); writeLines(res, file.path(DIR, "residui-stadio2.txt"))
    if (length(res)) ferma("CANCELLO 2: %d record senza predizione dopo il recupero: l'assemblaggio toglierebbe blocchi in silenzio. Decidi prima di proseguire", length(res))
  }
})
passo("s2-assemblaggio", Rs("analysis/p4-fase-f4-stage2-collect-v3.R", c(sprintf("INPUT_V3=%s", IN2), sprintf("RESCUE_INPUT=%s", RES2), sprintf("FULLRUN_COLLECT=%s", COLL2), sprintf("RESCUE_COLLECT=%s", COLLR2), sprintf("OUT_MASTER=%s", M2)), "assemblaggio-s2.log"))
passo("s2-confronto", {
  n <- readLines(M2, warn = FALSE); sn <- sid_di(n); o <- readLines(OLD2, warn = FALSE); so <- sid_di(o); a <- readLines("analysis/p4-output/A3-stage2-master-parziale.jsonl", warn = FALSE); b <- readLines("analysis/p4-output/S8b-stage2-master-parziale.jsonl", warn = FALSE); b <- b[sid_di(b) %in% NUOVI]
  r <- c(a, b); sr <- sid_di(r); g <- intersect(RIF_STUDI, sn); ug <- n[match(g, sn)] == r[match(g, sr)]; ug0 <- o[match(g, so)] == r[match(g, sr)]
  pl <- n[match(g, sn)]; pl[1] <- paste0(pl[1], "x"); vis <- sum(pl != n[match(g, sn)]); u <- cfr2(readRDS(COLL2)$predictions); altri <- setdiff(sn, RIF_STUDI); ug1 <- n[match(altri, sn)] == o[match(altri, so)]; ug1[is.na(ug1)] <- FALSE
  smis <- setdiff(unique(sid_di(readLines(IN2, warn = FALSE))), sn); writeLines(smis, file.path(DIR, "studi-senza-record-s2.txt"))
  out <- c(sprintf("Q4 studi nel master: %d; rispetto ai master vecchi, persi %d, nuovi %d, stesso ordine %s", length(sn), length(setdiff(so, sn)), length(setdiff(sn, so)), identical(sn, so)), sprintf("studi di input senza record: %d", length(smis)),
           sprintf("Q2 studi con record assemblato identico al riferimento: %s", ci_txt(sum(ug), length(ug))), sprintf("studi con uscita grezza identica al riferimento, prima del recupero: %s", ci_txt(sum(u), length(u))),
           sprintf("cancello 4 negativo: vecchio senza flag contro riferimento, identici %d su %d", sum(ug0), length(ug0)), sprintf("cancello 4 positivo: differenza piantata, viste %d", vis),
           sprintf("descrittivo: studi fuori dal riferimento con record identico al master vecchio: %s", ci_txt(sum(ug1), length(ug1))), sprintf("studi diversi dal riferimento: %s", paste(head(g[!ug], 50), collapse = " ")))
  writeLines(out, file.path(DIR, "62-s2-confronto.txt")); for (l in out) scrivi("%s", l)
  if (sum(ug0) == length(ug0) || vis != 1L) ferma("CANCELLO 4 fallito sullo Stadio 2")
  if (length(sn) != length(unique(sn))) ferma("CANCELLO 2: master Stadio 2 con studi doppi")
})
scrivi("CATENA FINITA")
