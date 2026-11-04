#!/usr/bin/env Rscript
# S8b: catena notturna della prova. Attese: 00-previsioni.md. Ogni passo scrive stato/<passo>.done e si puo' riprendere.
# Uso: setsid nohup Rscript analysis/audit/2026-11-04-S8b-prova/50-notte.R >> .../log/notte.out 2>&1 < /dev/null &
suppressPackageStartupMessages({ library(jsonlite); library(fs) })
suppressMessages(pkgload::load_all(".", quiet = TRUE))
DIR <- "analysis/audit/2026-11-04-S8b-prova"; LOG <- file.path(DIR, "log"); JOBS <- file.path(DIR, "jobs"); ST <- file.path(DIR, "stato")
NUOVI <- readLines(file.path(DIR, "campione-nuovi.txt")); GIA <- readLines(file.path(DIR, "campione-300-gia-rigenerati.txt"))
IN1 <- "analysis/input/S8b-stage1-input.jsonl"; SHUF <- "analysis/input/S8b-stage1-input-shuffled.jsonl"; OUTL <- "analysis/input/S8b-stage1-outliers.jsonl"; CHUNKS <- "analysis/input/S8b-chunks"
PRED1 <- "analysis/p4-output/S8b-stage1-predictions-rescued.jsonl"
M1A3 <- "analysis/p4-output/A3-stage1-master-innestato.jsonl"; M2A3 <- "analysis/p4-output/A3-stage2-master-innestato.jsonl"
M1 <- "analysis/p4-output/S8b-stage1-master-innestato.jsonl"; M2 <- "analysis/p4-output/S8b-stage2-master-innestato.jsonl"
IN2 <- "analysis/input/S8b-stage2-input.jsonl"; SUB2 <- "analysis/input/S8b-stage2-subset.jsonl"; RES2 <- "analysis/input/S8b-stage2-rescue.jsonl"
COLL2 <- "analysis/p4-output/S8b-stage2-collect.rds"; COLLR2 <- "analysis/p4-output/S8b-stage2-rescue-collect.rds"; PARZ <- "analysis/p4-output/S8b-stage2-master-parziale.jsonl"
SMOKE <- nzchar(Sys.getenv("SOLO_SMOKE"))
cfg <- dgx_config()
cfg01 <- dgx_config(nodelist = "poddgx01"); cfg02 <- dgx_config(nodelist = "poddgx02")

temp <- function() { x <- tryCatch(system("sensors 2>/dev/null | grep Tctl", intern = TRUE), error = function(e) "?"); g <- tryCatch(system("nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader", intern = TRUE), error = function(e) "?"); paste0(sub("^.*\\+([0-9.]+).*$", "\\1", x[1]), "C RTX=", g[1]) }
scrivi <- function(...) { msg <- sprintf("[%s] T=%sC %s", format(Sys.time(), "%m-%d %H:%M:%S"), temp(), sprintf(...)); cat(msg, "\n", sep = ""); cat(msg, "\n", sep = "", file = file.path(DIR, "log/notte.log"), append = TRUE); flush.console() }
ferma <- function(...) { scrivi("FERMO: %s", sprintf(...)); stop(sprintf(...), call. = FALSE) }
passo <- function(nome, expr) {
  f <- file.path(ST, paste0(nome, ".done"))
  if (file.exists(f)) { scrivi("passo %s gia' fatto", nome); return(invisible(NULL)) }
  scrivi("INIZIO %s", nome); t0 <- Sys.time(); force(expr)
  writeLines(format(Sys.time()), f); scrivi("FINE %s (%.1f min)", nome, as.numeric(difftime(Sys.time(), t0, units = "mins")))
}
ssh_ripeti <- function(fun) { for (i in 1:30) { r <- tryCatch(fun(), error = function(e) e); if (!inherits(r, "error")) return(r); scrivi("ssh in errore (%d): %s", i, conditionMessage(r)); Sys.sleep(60) }; ferma("ssh non risponde da 30 minuti") }
attendi <- function(jobs, ogni = 120L) {
  repeat {
    st <- vapply(jobs, function(j) ssh_ripeti(function() dgx_p4_status(j, fetch_status_json = FALSE, fetch_live = FALSE))$slurm_state, character(1))
    if (all(st == "TERMINATED")) break
    scrivi("job: %s", paste(names(table(st)), table(st), collapse = ", ")); Sys.sleep(ogni)
  }
  for (j in jobs) {
    s <- ssh_ripeti(function() .dgx_ssh(cfg, sprintf("sacct -X -n -P -j %s -o State,Elapsed", j$slurm_job_id)))$stdout
    scrivi("slurm %s: %s", j$slurm_job_id, trimws(s))
    if (!grepl("^COMPLETED", trimws(s))) ferma("job %s non completato: %s", j$slurm_job_id, s)
  }
}
invia <- function(p, stage, slug, time, tiered = NULL, gen_over = NULL, conf = cfg02) {
  f <- file.path(JOBS, paste0(slug, ".rds")); if (file.exists(f)) return(readRDS(f))
  args <- list(p, stage = stage, config = conf, metadata = list(slug = slug)); if (!is.null(tiered)) args$tiered_max_tokens <- tiered
  b <- ssh_ripeti(function() do.call(dgx_p4_build_bundle, args))
  if (!is.null(gen_over)) { gp <- fs::path(b$bundle_dir, "generation.json"); g <- jsonlite::read_json(gp); for (n in names(gen_over)) g[[n]] <- gen_over[[n]]; jsonlite::write_json(g, gp, auto_unbox = TRUE, pretty = TRUE, null = "null") }
  j <- ssh_ripeti(function() dgx_p4_submit(b, time = time, env = c(VLLM_BATCH_INVARIANT = "1")))
  saveRDS(j, f); scrivi("inviato %s slurm=%s run_id=%s", slug, j$slurm_job_id, j$run_id); j
}
flag_ok <- function(j) { p <- file.path("analysis/p4-output", j$run_id, "container-env.txt"); if (!file.exists(p) || !any(grepl("^VLLM_BATCH_INVARIANT=1$", readLines(p)))) ferma("CANCELLO 3: flag assente in %s", j$run_id); scrivi("cancello 3: flag presente in %s", j$run_id) }
rid_di <- function(x) sub('^.*"record_id": ?"([^"]+)".*$', "\\1", x)
valid <- function(x) grepl('"valid_schema": *true', x)
Rs <- function(script, env, log) { rc <- system2("Rscript", script, env = env, stdout = file.path(LOG, log), stderr = file.path(LOG, log)); if (rc != 0L) ferma("%s rc=%d, vedi log/%s", script, rc, log); invisible(rc) }

# ---- prova breve, solo se richiesta ----------------------------------------------------------------------
if (SMOKE) {
  p <- "analysis/input/S8b-smoke.jsonl"; if (!file.exists(p)) writeLines(readLines(IN1, n = 20L), p)
  sl <- Sys.getenv("SOLO_SMOKE"); j <- invia(p, "stage1", sl, "00:30:00", conf = dgx_config(nodelist = Sys.getenv("SMOKE_NODO", "poddgx02"))); attendi(list(j), 30L)
  d <- ssh_ripeti(function() dgx_p4_collect(j)); flag_ok(j)
  l <- readLines(file.path(d$run_dir, "predictions.jsonl")); scrivi("smoke: %d righe, valide %d", length(l), sum(valid(l)))
  ai <- rid_di(l); m <- readLines(M1A3); m_id <- rid_di(m); pos <- match(ai, m_id)
  ug <- vapply(seq_along(l), function(i) identical(fromJSON(l[i])$raw_output, fromJSON(m[pos[i]])$raw_output), logical(1))
  scrivi("smoke: rispetto al master di agosto, identici %d su %d (conta solo per gli studi rigenerati)", sum(ug & ai %in% rid_di(readLines(file.path("analysis/input/A3-stage1-input.jsonl")))), sum(ai %in% rid_di(readLines("analysis/input/A3-stage1-input.jsonl"))))
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
  if (length(rl) != length(raw) || anyDuplicated(rl) || !all(rl %in% raw)) ferma("taglio dei blocchi non coerente")
  scrivi("record %d, outlier %d, blocchi %d", length(raw), length(idx), n)
})
blocchi <- c(as.character(fs::dir_ls(CHUNKS, glob = "*.jsonl")), if (file.exists(OUTL)) OUTL)
# poddgx01 e' caduto alle 21:51 del 2026-11-04 (NODE_FAIL): tutto su poddgx02, il nodo di agosto, due job da 4 GPU alla volta.
nodi1 <- rep_len(list(cfg02), length(blocchi))
jobs1 <- Map(function(p, cc) invia(p, "stage1", paste0("s8b-s1-", sub("[.]jsonl$", "", basename(p))), "12:00:00", conf = cc), blocchi, nodi1)
passo("s1-attesa", attendi(jobs1))
passo("s1-raccolta", {
  rr <- character(0); nn <- character(0)
  for (j in jobs1) { d <- ssh_ripeti(function() dgx_p4_collect(j)); flag_ok(j); l <- readLines(file.path(d$run_dir, "predictions.jsonl"), warn = FALSE); rr <- c(rr, l); nn <- c(nn, rep(j$config$nodelist, length(l))) }
  writeLines(paste(rid_di(rr), nn, sep = "\t"), file.path(DIR, "record-nodo-s1.tsv"))
  rid <- rid_di(rr); att <- sub('^.*"record_id":"([^"]+)".*$', "\\1", readLines(IN1, warn = FALSE))
  scrivi("raccolti %d, attesi %d, mancanti %d, estranei %d, duplicati %d, validi %d", length(rr), length(att), length(setdiff(att, rid)), length(setdiff(rid, att)), sum(duplicated(rid)), sum(valid(rr)))
  if (length(setdiff(rid, att)) || anyDuplicated(rid)) ferma("raccolta Stadio 1 non coerente")
  writeLines(rr, "analysis/p4-output/S8b-stage1-predictions.jsonl")
})
passo("s1-recupero", {
  rr <- readLines("analysis/p4-output/S8b-stage1-predictions.jsonl", warn = FALSE); inp <- readLines(IN1, warn = FALSE); inp_id <- sub('^.*"record_id":"([^"]+)".*$', "\\1", inp)
  conf <- list(list(rep = 1.2, mt = 4096L, ml = 8192L), list(rep = 1.3, mt = 8192L, ml = 16384L), list(rep = 1.4, mt = 8192L, ml = 16384L))
  for (k in seq_along(conf)) {
    rid <- rid_di(rr); dafare <- union(rid[!valid(rr)], setdiff(inp_id, rid)); scrivi("recupero %d: %d da rifare", k, length(dafare)); if (!length(dafare)) break
    p <- sprintf("analysis/input/S8b-stage1-rescue%d.jsonl", k); writeLines(inp[inp_id %in% dafare], p)
    j <- invia(p, "stage1", sprintf("s8b-s1-rescue%d", k), "04:00:00", gen_over = list(max_tokens = conf[[k]]$mt, repetition_penalty = conf[[k]]$rep, max_model_len = conf[[k]]$ml))
    attendi(list(j), 60L); d <- ssh_ripeti(function() dgx_p4_collect(j)); flag_ok(j)
    nu <- readLines(file.path(d$run_dir, "predictions.jsonl"), warn = FALSE); nu <- nu[valid(nu)]; nid <- rid_di(nu)
    keep <- !(rid %in% nid); rr <- c(rr[keep], nu); scrivi("recupero %d: recuperati %d", k, length(nu))
  }
  rid <- rid_di(rr); res <- union(rid[!valid(rr)], setdiff(inp_id, rid)); scrivi("residui dopo il recupero: %d", length(res)); writeLines(res, file.path(DIR, "residui-stadio1.txt"))
  writeLines(rr, PRED1)
})
passo("s1-confronto", {
  rr <- readLines(PRED1, warn = FALSE); rid <- rid_di(rr); inp <- readLines(IN1, warn = FALSE)
  sid <- sub('^.*"series_id":"([^"]+)".*$', "\\1", inp); iid <- sub('^.*"record_id":"([^"]+)".*$', "\\1", inp); gsm_gia <- iid[sid %in% GIA]
  m <- readLines(M1A3, warn = FALSE); m_id <- rid_di(m); old <- readLines("analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl", warn = FALSE); o_id <- rid_di(old)
  raw <- function(l) vapply(l, function(x) { v <- fromJSON(x)$raw_output; if (is.null(v)) NA_character_ else v }, character(1), USE.NAMES = FALSE)
  g <- intersect(gsm_gia, rid); rn <- raw(rr[match(g, rid)]); ra <- raw(m[match(g, m_id)]); ro <- raw(old[match(g, o_id)])
  ug <- rn == ra; ug[is.na(ug)] <- FALSE; ug0 <- ra == ro; ug0[is.na(ug0)] <- FALSE
  # I record recuperati hanno girato su poddgx02 anche se il blocco stava su poddgx01
  nt <- read.delim(file.path(DIR, "record-nodo-s1.tsv"), header = FALSE, col.names = c("r", "n")); nodo_g <- nt$n[match(g, nt$r)]
  res_id <- unlist(lapply(fs::dir_ls("analysis/input", glob = "*S8b-stage1-rescue*.jsonl"), function(p) sub('^.*"record_id":"([^"]+)".*$', "\\1", readLines(p, warn = FALSE))), use.names = FALSE); nodo_g[g %in% res_id] <- "poddgx02"
  cn <- function(k) { x <- ug[nodo_g == k]; if (!length(x)) return(sprintf("%s: nessun record", k)); ic <- binom.test(sum(x), length(x))$conf.int; sprintf("%s: %d su %d = %.3f%% [%.3f; %.3f]", k, sum(x), length(x), 100*mean(x), 100*ic[1], 100*ic[2]) }
  pl <- rn; pl[1] <- paste0(pl[1], "x"); vis <- sum(pl != rn, na.rm = TRUE)
  ci <- binom.test(sum(ug), length(ug))$conf.int
  out <- c(sprintf("Q1 record identici ad agosto, tutti: %d su %d = %.3f%% [%.3f; %.3f]", sum(ug), length(ug), 100*mean(ug), 100*ci[1], 100*ci[2]),
           paste("Q1 per nodo,", cn("poddgx02")), paste("Q7 per nodo,", cn("poddgx01")),
           sprintf("cancello 4 negativo: vecchio senza flag contro agosto, identici %d su %d (deve essere meno di tutti)", sum(ug0), length(ug0)),
           sprintf("cancello 4 positivo: differenza piantata, viste %d", vis))
  writeLines(out, file.path(DIR, "60-s1-confronto.txt")); for (l in out) scrivi("%s", l)
  if (sum(ug0) == length(ug0) || vis != 1L) ferma("CANCELLO 4 fallito sullo Stadio 1")
  sid_n <- sid %in% NUOVI; idn <- iid[sid_n]; writeLines(rr[rid %in% idn], "analysis/p4-output/S8b-stage1-predictions-nuovi.jsonl")
})
passo("s1-innesto", {
  if (file.exists(M1)) file.remove(M1)
  Rs("analysis/audit/2026-08-16-A3/30-innesta-master-stadio1.R", c(sprintf("MASTER=%s", M1A3), "NUOVE=analysis/p4-output/S8b-stage1-predictions-nuovi.jsonl", sprintf("A3_LIST=%s/campione-nuovi.txt", DIR), sprintf("OUT=%s", M1)), "innesto-s1.log")
  if (!file.exists(M1)) ferma("master Stadio 1 non scritto")
})

# ---- 2. Stadio 2 -----------------------------------------------------------------------------------------
passo("s2-input", {
  Rs("analysis/p4-fase-f4-stage2-build-input-v3.R", c(sprintf("STAGE1_PREDS_PATH=%s", M1), sprintf("OUT_JSONL=%s", IN2)), "build-s2.log")
  n <- readLines(IN2, warn = FALSE); a <- readLines("analysis/input/A3-stage2-input.jsonl", warn = FALSE)
  sn <- sub('^.*?"series_id":"([^"]+)".*$', "\\1", n, perl = TRUE); sa <- sub('^.*?"series_id":"([^"]+)".*$', "\\1", a, perl = TRUE)
  uguali <- identical(sort(n[!sn %in% NUOVI]), sort(a[!sa %in% NUOVI]))
  msg <- sprintf("cancello 5: input fuori dal campione byte-identico ad agosto: %s (%d righe contro %d)", uguali, sum(!sn %in% NUOVI), sum(!sa %in% NUOVI)); scrivi("%s", msg); writeLines(msg, file.path(DIR, "61-cancello-5.txt"))
  if (!uguali) ferma("CANCELLO 5 fallito")
  sel <- n[sn %in% c(NUOVI, GIA)]; writeLines(sel, SUB2); scrivi("subset Stadio 2: %d record, %d studi", length(sel), length(unique(sn[sn %in% c(NUOVI, GIA)])))
})
# Due job da 4 GPU su poddgx02, le 8 GPU del nodo. I 300 studi gia' rigenerati stanno nel primo, mescolati ai nuovi.
PART2 <- sprintf("analysis/input/S8b-stage2-parte%d.jsonl", 1:2)
passo("s2-parti", {
  n <- readLines(SUB2, warn = FALSE); sn <- sub('^.*?"series_id":"([^"]+)".*$', "\\1", n, perl = TRUE); nc <- tapply(nchar(n), sn, sum)
  bin <- c(sum(nc[GIA]), 0); dove <- list(GIA, character(0))
  for (s in NUOVI[NUOVI %in% names(nc)]) { b <- which.min(bin); bin[b] <- bin[b] + nc[[s]]; dove[[b]] <- c(dove[[b]], s) }
  for (k in 1:2) writeLines(n[sn %in% dove[[k]]], PART2[k]); scrivi("parti Stadio 2, caratteri: %s", paste(round(bin/1e6, 1), collapse = " "))
  if (!setequal(sn, unlist(dove))) ferma("le parti non coprono il subset")
})
jobs2 <- Map(function(p, k) invia(p, "stage2", sprintf("s8b-s2-parte%d", k), "24:00:00", tiered = TRUE, conf = cfg02), PART2, 1:2)
passo("s2-attesa", attendi(jobs2, 300L))
passo("s2-raccolta", {
  ds <- lapply(jobs2, function(j) { d <- ssh_ripeti(function() dgx_p4_collect(j)); flag_ok(j); d })
  d <- list(predictions = dplyr::bind_rows(lapply(ds, `[[`, "predictions")), errors = dplyr::bind_rows(lapply(ds, `[[`, "errors")), run_dir = vapply(ds, function(x) as.character(x$run_dir), character(1)))
  if (anyDuplicated(d$predictions$record_id)) ferma("record duplicati nella raccolta Stadio 2")
  saveRDS(d, COLL2); scrivi("Stadio 2: valide %d, errori %d", nrow(d$predictions), nrow(d$errors))
})
passo("s2-recupero", {
  d <- readRDS(COLL2); inp <- readLines(SUB2, warn = FALSE); iid <- sub('^.*?"record_id":"([^"]+)".*$', "\\1", inp, perl = TRUE); sid <- sub('^.*?"series_id":"([^"]+)".*$', "\\1", inp, perl = TRUE)
  man <- setdiff(iid, d$predictions$record_id); aff <- unique(sid[iid %in% man]); scrivi("Stadio 2: record mancanti %d, studi da recuperare %d", length(man), length(aff))
  writeLines(aff, file.path(DIR, "studi-recupero-s2.txt"))
  if (!length(aff)) { file.create(RES2); saveRDS(list(predictions = data.frame()), COLLR2) } else {
    Rs(file.path(DIR, "45-rescue-build-s2.R"), c(sprintf("AFFECTED_FILE=%s/studi-recupero-s2.txt", DIR), sprintf("STAGE1_PREDS_PATH=%s", M1), sprintf("OUT_JSONL=%s", RES2), "MAX_TREATED=12"), "rescue-build-s2.log")
    jr <- invia(RES2, "stage2", "s8b-s2-rescue", "24:00:00", tiered = FALSE, gen_over = list(max_tokens = 32768L, repetition_penalty = 1.2))
    attendi(list(jr), 120L); dr <- ssh_ripeti(function() dgx_p4_collect(jr)); flag_ok(jr); saveRDS(dr, COLLR2); scrivi("recupero Stadio 2: valide %d su %d", nrow(dr$predictions), length(readLines(RES2)))
  }
})
passo("s2-assemblaggio", Rs("analysis/p4-fase-f4-stage2-collect-v3.R", c(sprintf("INPUT_V3=%s", SUB2), sprintf("RESCUE_INPUT=%s", RES2), sprintf("FULLRUN_COLLECT=%s", COLL2), sprintf("RESCUE_COLLECT=%s", COLLR2), sprintf("OUT_MASTER=%s", PARZ)), "assemblaggio-s2.log"))
passo("s2-confronto", {
  sid <- function(x) sub('^.*?"series_id":"([^"]+)".*$', "\\1", x, perl = TRUE)
  n <- readLines(PARZ, warn = FALSE); a <- readLines("analysis/p4-output/A3-stage2-master-parziale.jsonl", warn = FALSE); o <- readLines("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl", warn = FALSE)
  sn <- sid(n); sa <- sid(a); so <- sid(o); g <- intersect(GIA, sn)
  ug <- n[match(g, sn)] == a[match(g, sa)]; ug0 <- o[match(g, so)] == a[match(g, sa)]
  pl <- n[match(g, sn)]; pl[1] <- paste0(pl[1], "x"); vis <- sum(pl != n[match(g, sn)])
  # il confronto sull'uscita grezza non dipende dall'assemblaggio, che e' codice e puo' essere cambiato da agosto
  dn <- readRDS(COLL2)$predictions; da <- readRDS("analysis/p4-output/A3-stage2-collect.rds")$predictions
  ds <- sub("#.*$", "", dn$record_id); dn <- dn[ds %in% g, ]; ii <- match(dn$record_id, da$record_id); rawug <- dn$raw_output == da$raw_output[ii]; rawug[is.na(rawug)] <- FALSE
  stud_raw <- tapply(rawug, sub("#.*$", "", dn$record_id), all); ci <- binom.test(sum(stud_raw), length(stud_raw))$conf.int; ci2 <- binom.test(sum(ug), length(ug))$conf.int
  out <- c(sprintf("Q2 poddgx02, studi con uscita grezza identica ad agosto: %d su %d = %.1f%% [%.1f; %.1f]", sum(stud_raw), length(stud_raw), 100*mean(stud_raw), 100*ci[1], 100*ci[2]),
           sprintf("studi con record assemblato identico: %d su %d = %.1f%% [%.1f; %.1f]", sum(ug), length(ug), 100*mean(ug), 100*ci2[1], 100*ci2[2]),
           sprintf("cancello 4 negativo: vecchio senza flag contro agosto, identici %d su %d (riferimento 18,4%%)", sum(ug0), length(ug0)), sprintf("cancello 4 positivo: differenza piantata, viste %d", vis),
           sprintf("studi diversi: %s", paste(head(g[!ug], 30), collapse = " ")))
  writeLines(out, file.path(DIR, "62-s2-confronto.txt")); for (l in out) scrivi("%s", l)
  if (sum(ug0) == length(ug0) || vis != 1L) ferma("CANCELLO 4 fallito sullo Stadio 2")
})
passo("s2-innesto", {
  sid <- function(x) sub('^.*?"series_id":"([^"]+)".*$', "\\1", x, perl = TRUE); n <- readLines(PARZ, warn = FALSE); sn <- sid(n); a <- readLines(M2A3, warn = FALSE); sa <- sid(a)
  man <- setdiff(NUOVI, sn); scrivi("studi nuovi senza record assemblato, tenuti col record vecchio: %d", length(man)); writeLines(man, file.path(DIR, "studi-senza-record-s2.txt"))
  writeLines(c(n[sn %in% NUOVI], a[sa %in% man]), "analysis/p4-output/S8b-stage2-parziale-nuovi.jsonl"); if (file.exists(M2)) file.remove(M2)
  Rs("analysis/audit/2026-08-16-A3/70-innesta-master-stadio2.R", c(sprintf("MASTER=%s", M2A3), "NUOVO=analysis/p4-output/S8b-stage2-parziale-nuovi.jsonl", sprintf("A3_LIST=%s/campione-nuovi.txt", DIR), sprintf("OUT=%s", M2)), "innesto-s2.log")
  if (!file.exists(M2)) ferma("master Stadio 2 non scritto")
})

# ---- 3. Re-cluster e misura -----------------------------------------------------------------------------
passo("s3-recluster", {
  ing <- c("analysis/input/archs4-human-stage2-input-v3.jsonl", "analysis/input/archs4-human-stage2-rescue-v3.jsonl", "analysis/input/A3-stage2-subset.jsonl", "analysis/input/A3-stage2-rescue.jsonl", SUB2, if (file.info(RES2)$size > 0) RES2)
  scrivi("re-cluster: 8 processi, come in agosto: oltre, la memoria finisce (16,7 GB per processo)")
  Rs("analysis/p4-fase-f13-stage3-v16-tre-cambi.R", c("SMOKE=0", sprintf("STAGE1_MASTER=%s", M1), sprintf("STAGE2_MASTER=%s", M2), sprintf("STAGE2_INPUTS=%s", paste(ing, collapse = ",")), "SUMMARIZE_WORKERS=8"), "recluster.log")
  dirs <- sort(fs::dir_ls("analysis/p4-output", glob = "*-stage3-v16-*")); d <- as.character(dirs[length(dirs)])
  rm <- jsonlite::read_json(file.path(d, "run_metadata.json")); writeLines(d, file.path(DIR, "stadio3-prova.txt")); scrivi("Stadio 3 della prova: %s", d)
})
passo("misura", Rs(file.path(DIR, "70-misura.R"), character(0), "misura.log"))
scrivi("CATENA FINITA")
