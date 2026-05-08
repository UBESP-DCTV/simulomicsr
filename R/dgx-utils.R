#' Genera un run_id univoco per un run P4
#'
#' Formato: `<UTC-timestamp>-<slug-sanitizzato>-<6-hex>`. Esempio:
#' `20260507T093012Z-alpha-xlsx-stage1-a3f9c1`.
#'
#' @param slug breve descrizione user-defined.
#' @return character(1).
#' @keywords internal
.dgx_run_id <- function(slug) {
  stopifnot(is.character(slug), length(slug) == 1L, nzchar(slug))
  ts <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  slug_clean <- gsub("[^A-Za-z0-9]+", "-", slug)
  slug_clean <- gsub("^-+|-+$", "", slug_clean)
  slug_clean <- tolower(slug_clean)
  rand_hex <- substring(digest::digest(paste0(ts, slug_clean, stats::runif(1)), algo = "md5"), 1, 6)
  paste(ts, slug_clean, rand_hex, sep = "-")
}

#' Estrae lo slug user-defined da un run_id pieno
#'
#' @param run_id stringa formato `<ts>-<slug>-<hex>`.
#' @return slug come character(1).
#' @keywords internal
.dgx_run_id_short <- function(run_id) {
  parts <- strsplit(run_id, "-", fixed = TRUE)[[1]]
  if (length(parts) < 3L) return(run_id)
  paste(parts[2:(length(parts) - 1L)], collapse = "-")
}

#' Sostituisce placeholder `__VAR__` in un template
#'
#' Tutti i placeholder devono essere risolti; se ne resta qualcuno, errore.
#'
#' @param tmpl character(1) testo template.
#' @param ... named character(1) sostituzioni (e.g. `run_id = "..."`).
#' @return character(1).
#' @keywords internal
.dgx_render_slurm_template <- function(tmpl, ...) {
  vars <- list(...)
  for (nm in names(vars)) {
    placeholder <- paste0("__", toupper(nm), "__")
    tmpl <- gsub(placeholder, vars[[nm]], tmpl, fixed = TRUE)
  }
  remaining <- regmatches(tmpl, gregexpr("__[A-Z_]+__", tmpl))[[1]]
  if (length(remaining) > 0) {
    cli::cli_abort(
      "Placeholder non risolti nel template: {.val {unique(remaining)}}",
      class = "simulomicsr_dgx_template_unresolved"
    )
  }
  tmpl
}

#' Esegue un comando SSH sul login node via processx
#'
#' @param cfg `simulomicsr_dgx_config`.
#' @param cmd character(1) comando shell remoto.
#' @param env named character (default empty) di env vars da esportare prima del comando.
#' @return list con `stdout`, `stderr`, `status`.
#' @keywords internal
.dgx_ssh <- function(cfg, cmd, env = character()) {
  ssh_args <- c("-o", "BatchMode=yes",
                "-o", "ConnectTimeout=15")
  if (!is.null(cfg$ssh_key_path))
    ssh_args <- c(ssh_args, "-i", cfg$ssh_key_path)
  ssh_args <- c(ssh_args, paste0(cfg$login_user, "@", cfg$login_host))

  if (length(env) > 0) {
    env_prefix <- paste(paste0(names(env), "=", shQuote(env)), collapse = " ")
    cmd <- paste(env_prefix, cmd)
  }
  # Force login shell sul remoto: ssh non-interattivo NON sourca
  # /etc/profile.d/* per default, quindi `module`, PATH SLURM e
  # SLURM_CONF non sono settati. Senza login shell `sbatch`/`squeue`
  # falliscono con "command not found" o "Could not establish a
  # configuration source". Validato sul cluster UniPD HPC il 2026-05-07.
  remote_cmd <- paste0("bash -lc ", shQuote(cmd))
  ssh_args <- c(ssh_args, remote_cmd)

  res <- processx::run("ssh", ssh_args, error_on_status = FALSE)
  list(stdout = res$stdout, stderr = res$stderr, status = res$status)
}

#' Esegue rsync locale -> remoto via processx
#'
#' @param cfg `simulomicsr_dgx_config`.
#' @param local_path path locale (file o directory con trailing slash).
#' @param remote_path path remoto sul login node.
#' @param direction `"push"` (default, locale -> remoto) o `"pull"` (remoto -> locale).
#' @param flags character vector di flag rsync. Default `c("-az")`.
#' @return invisible(list(stdout, stderr, status))
#' @keywords internal
.dgx_rsync <- function(cfg, local_path, remote_path,
                       direction = c("push", "pull"),
                       flags = c("-az")) {
  direction <- match.arg(direction)
  remote_spec <- paste0(cfg$login_user, "@", cfg$login_host, ":", remote_path)
  ssh_cmd <- "ssh -o BatchMode=yes -o ConnectTimeout=15"
  if (!is.null(cfg$ssh_key_path))
    ssh_cmd <- paste(ssh_cmd, "-i", shQuote(cfg$ssh_key_path))

  args <- c(flags, "-e", ssh_cmd)
  args <- if (direction == "push") c(args, local_path, remote_spec) else c(args, remote_spec, local_path)

  res <- processx::run("rsync", args, error_on_status = FALSE, echo_cmd = FALSE)
  if (res$status != 0L)
    cli::cli_abort(
      c("rsync {direction} fallito (status={res$status})",
        "x" = "{res$stderr}"),
      class = "simulomicsr_dgx_rsync_failed"
    )
  invisible(list(stdout = res$stdout, stderr = res$stderr, status = res$status))
}

#' Live progress di un run P4 (mid-run reale)
#'
#' Conta via SSH le righe dei file `predictions.worker_*.jsonl` nella run
#' dir remota e restituisce il progress aggregato + per-worker. Usato come
#' fallback affidabile quando `status.json` e' fermo a `state="starting"`
#' (run_p4_vllm.py aggiorna status.json solo a inizio/fine, non per
#' microbatch). Se nessun file `predictions.worker_*.jsonl` esiste ancora
#' (fase boot pre-prima-microbatch), ritorna NULL.
#'
#' @param cfg `simulomicsr_dgx_config`.
#' @param run_id stringa run id.
#' @return list con `records_done` (intero), `per_worker` (data.frame
#'   con colonne worker_id, n_records), `last_modified` (POSIXct UTC,
#'   timestamp dell'ultimo file modificato) o NULL.
#' @keywords internal
.dgx_live_progress <- function(cfg, run_id) {
  run_dir <- paste0(cfg$remote_root, "/runs/", run_id)
  # `wc -l` su glob inesistente fa 'No such file': sopprimo via 2>/dev/null,
  # `stat -c '%Y %n'` per mtime epoch + path. Stampa una riga per file.
  cmd <- paste0(
    "cd ", shQuote(run_dir), " 2>/dev/null && ",
    "for f in predictions.worker_*.jsonl; do ",
    "  [ -f \"$f\" ] || continue; ",
    "  printf '%s\\t%s\\t%s\\n' \"$(stat -c '%Y' \"$f\")\" \"$(wc -l < \"$f\")\" \"$f\"; ",
    "done"
  )
  res <- .dgx_ssh(cfg, cmd)
  if (res$status != 0L || !nzchar(trimws(res$stdout))) return(NULL)

  raw <- strsplit(trimws(res$stdout), "\n", fixed = TRUE)[[1]]
  parts <- strsplit(raw, "\t", fixed = TRUE)
  ok <- vapply(parts, function(p) length(p) == 3L, logical(1))
  if (!any(ok)) return(NULL)
  parts <- parts[ok]

  mtimes <- as.numeric(vapply(parts, `[`, character(1), 1))
  counts <- as.integer(vapply(parts, `[`, character(1), 2))
  fnames <- vapply(parts, `[`, character(1), 3)
  worker_ids <- as.integer(sub(".*predictions\\.worker_(\\d+)\\.jsonl$",
                               "\\1", fnames))

  list(
    records_done  = sum(counts),
    per_worker    = data.frame(
      worker_id = worker_ids,
      n_records = counts,
      stringsAsFactors = FALSE
    )[order(worker_ids), , drop = FALSE],
    last_modified = as.POSIXct(max(mtimes), origin = "1970-01-01", tz = "UTC")
  )
}
