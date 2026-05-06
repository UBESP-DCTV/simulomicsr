# Runtime management --------------------------------------------------------

.trim_scalar <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return("")
  }

  value <- trimws(as.character(x)[1])
  if (is.na(value)) {
    return("")
  }

  value
}

.normalize_remote_path <- function(x) {
  value <- .trim_scalar(x)
  if (identical(value, "")) {
    return(NA_character_)
  }

  sub("/+$", "", value)
}

.dirname_remote <- function(path) {
  path <- .normalize_remote_path(path)
  if (is.na(path)) {
    return(NA_character_)
  }

  parent <- fs::path_dir(path)
  if (identical(parent, ".") || identical(parent, "")) {
    return(NA_character_)
  }

  parent
}

.normalize_runtime_mode <- function(x, sif_path = NA_character_) {
  value <- tolower(.trim_scalar(x))

  if (identical(value, "")) {
    if (!is.na(.normalize_sif_path(sif_path))) {
      return("external")
    }

    return("managed")
  }

  if (!value %in% c("managed", "external")) {
    cli::cli_abort("`runtime_mode` must be either 'managed' or 'external'.")
  }

  value
}

.default_user_root <- function(login_user = "") {
  login_user <- .trim_scalar(login_user)
  base_root <- "/mnt/projects/dctv/dgx"

  if (identical(login_user, "")) {
    return(base_root)
  }

  paste(base_root, login_user, sep = "/")
}

.derive_runtime_config <- function(
    login_user = "",
    user_root = NA_character_,
    remote_base_dir = NA_character_,
    runtime_mode = "",
    runtime_name = "laims-runtime",
    sif_path = NA_character_) {
  explicit_base <- .normalize_remote_path(remote_base_dir)
  explicit_root <- .normalize_remote_path(user_root)
  normalized_sif <- .normalize_sif_path(sif_path)
  mode <- .normalize_runtime_mode(runtime_mode, sif_path = normalized_sif)

  if (is.na(explicit_root)) {
    explicit_root <- .dirname_remote(explicit_base)
  }

  if (is.na(explicit_root)) {
    explicit_root <- .default_user_root(login_user = login_user)
  }

  if (is.na(explicit_base)) {
    explicit_base <- paste(explicit_root, "runs", sep = "/")
  }

  runtime_name <- .trim_scalar(runtime_name)
  if (identical(runtime_name, "")) {
    runtime_name <- "laims-runtime"
  }

  runtime_root <- paste(explicit_root, "runtime", sep = "/")

  list(
    user_root = explicit_root,
    remote_base_dir = explicit_base,
    runtime = list(
      mode = mode,
      root = runtime_root,
      base_name = runtime_name,
      local_assets_dir = .package_file("runtime")
    )
  )
}

.managed_runtime_ref <- function(config, model = NULL, model_profile = NULL) {
  spec <- .model_spec(model = model, model_profile = model_profile)
  runtime <- spec$runtime %||% list()

  # The package manages exactly two canonical runtime identities:
  # - 20B   -> <runtime root>/official-20b/
  # - 120B  -> <runtime root>/official-120b/
  # These paths are the real bootstrap targets used by `ensure_runtime()`.
  managed_id <- runtime$managed_id %||% tolower(gsub("[^A-Za-z0-9]+", "-", spec$model))
  runtime_root <- paste(config$runtime$root, managed_id, sep = "/")
  versions_dir <- paste(runtime_root, "versions", sep = "/")
  assets_dir <- paste(runtime_root, "assets", sep = "/")
  manifest_path <- paste(runtime_root, "manifest.json", sep = "/")
  current_sif_path <- paste(runtime_root, "current.sif", sep = "/")
  runtime_name <- runtime$image_name %||% paste(config$runtime$base_name, tolower(spec$model), sep = "-")

  list(
    model = spec$model,
    model_id = spec$model_id %||% NA_character_,
    managed_id = managed_id,
    runtime_name = runtime_name,
    root = runtime_root,
    assets_dir = assets_dir,
    versions_dir = versions_dir,
    manifest_path = manifest_path,
    current_sif_path = current_sif_path
  )
}

.runtime_asset_files <- function(assets_dir) {
  files <- fs::dir_ls(assets_dir, recurse = TRUE, type = "file", all = TRUE)
  files <- files[!grepl("/__pycache__/", files, fixed = TRUE)]
  files <- files[!grepl("\\.pyc$", files, ignore.case = TRUE)]
  files[order(files)]
}

.runtime_assets_hash <- function(assets_dir) {
  files <- .runtime_asset_files(assets_dir)

  if (length(files) < 1L) {
    cli::cli_abort("Managed runtime assets are missing from `inst/runtime`.")
  }

  rel <- fs::path_rel(files, start = assets_dir)
  md5 <- unname(tools::md5sum(files))
  payload <- paste(rel, md5, sep = "  ")
  scratch <- tempfile("laims-runtime-assets-", fileext = ".txt")
  on.exit(unlink(scratch, force = TRUE), add = TRUE)
  writeLines(payload, scratch, useBytes = TRUE)
  unname(tools::md5sum(scratch))
}

.local_runtime_spec <- function(config, model = "20B", model_profile = NULL) {
  spec <- .model_spec(model = model, model_profile = model_profile)
  ref <- .managed_runtime_ref(config, model = spec$model)
  assets_dir <- config$runtime$local_assets_dir
  asset_hash <- .runtime_assets_hash(assets_dir)
  versioned_sif_path <- paste(
    ref$versions_dir,
    paste0(ref$runtime_name, "-", asset_hash, ".sif"),
    sep = "/"
  )

  list(
    model = spec$model,
    model_id = spec$model_id %||% NA_character_,
    runtime_name = ref$runtime_name,
    managed_id = ref$managed_id,
    package_version = as.character(utils::packageVersion("laimsdgxllm")),
    assets_dir = assets_dir,
    asset_hash = asset_hash,
    versioned_sif_path = versioned_sif_path,
    current_sif_path = ref$current_sif_path,
    manifest_path = ref$manifest_path,
    runtime_root = ref$root,
    remote_assets_dir = ref$assets_dir,
    remote_versions_dir = ref$versions_dir
  )
}

.runtime_ssh_capture <- function(config, command) {
  fun <- getOption("laimsdgxllm.runtime_ssh_capture", default = .ssh_capture)
  fun(config, command)
}

.runtime_copy_dir <- function(config, local_dir, remote_dir) {
  fun <- getOption("laimsdgxllm.runtime_copy_dir", default = NULL)
  if (is.function(fun)) {
    return(fun(config, local_dir, remote_dir))
  }

  destination <- .ssh_destination(config)
  result <- tryCatch(
    processx::run(
      command = config$scp_bin,
      args = c(
        .ssh_cli_args(config),
        "-r",
        paste0(fs::path_abs(local_dir), "/."),
        paste0(destination, ":", remote_dir, "/")
      ),
      error_on_status = FALSE,
      echo = FALSE
    ),
    error = function(e) {
      list(status = 1L, stdout = "", stderr = conditionMessage(e))
    }
  )

  list(
    ok = identical(result$status, 0L),
    status = result$status,
    stdout = trimws(result$stdout %||% ""),
    stderr = trimws(result$stderr %||% "")
  )
}

.runtime_inspect_remote <- function(config, spec) {
  exists_cmd <- paste(
    "if [ -f", shQuote(spec$manifest_path), "]; then echo manifest=1; else echo manifest=0; fi;",
    "if [ -e", shQuote(spec$current_sif_path), "]; then echo current=1; else echo current=0; fi"
  )
  exists_result <- .runtime_ssh_capture(config, exists_cmd)

  manifest_exists <- FALSE
  current_exists <- FALSE
  if (isTRUE(exists_result$ok) && !identical(exists_result$stdout, "")) {
    lines <- strsplit(exists_result$stdout, "\n", fixed = TRUE)[[1]]
    manifest_exists <- any(trimws(lines) == "manifest=1")
    current_exists <- any(trimws(lines) == "current=1")
  }

  manifest <- NULL
  if (manifest_exists) {
    manifest_result <- .runtime_ssh_capture(config, paste("cat", shQuote(spec$manifest_path)))
    if (isTRUE(manifest_result$ok) && !identical(manifest_result$stdout, "")) {
      manifest <- tryCatch(
        jsonlite::fromJSON(manifest_result$stdout, simplifyVector = FALSE),
        error = function(e) NULL
      )
    }
  }

  stale <- !manifest_exists ||
    !current_exists ||
    is.null(manifest) ||
    !identical(.deep_get(manifest, "asset_hash", default = NA_character_), spec$asset_hash) ||
    !identical(.deep_get(manifest, "current_sif_path", default = NA_character_), spec$current_sif_path) ||
    !identical(.deep_get(manifest, "model", default = NA_character_), spec$model)

  list(
    manifest_exists = manifest_exists,
    current_exists = current_exists,
    manifest = manifest,
    stale = stale
  )
}

.runtime_build_command <- function(config, spec) {
  asset_dir <- paste(spec$remote_assets_dir, spec$asset_hash, sep = "/")
  script_path <- paste(asset_dir, "build-runtime.sh", sep = "/")
  build_env <- .runtime_build_env(config)
  vars <- c(
    sprintf("LAIMS_RUNTIME_ASSET_HASH=%s", shQuote(spec$asset_hash)),
    sprintf("LAIMS_RUNTIME_ASSET_DIR=%s", shQuote(asset_dir)),
    sprintf("LAIMS_RUNTIME_VERSIONED_SIF=%s", shQuote(spec$versioned_sif_path)),
    sprintf("LAIMS_RUNTIME_CURRENT_SIF=%s", shQuote(spec$current_sif_path)),
    sprintf("LAIMS_RUNTIME_MANIFEST_PATH=%s", shQuote(spec$manifest_path)),
    sprintf("LAIMS_RUNTIME_ROOT=%s", shQuote(spec$runtime_root)),
    sprintf("LAIMS_RUNTIME_MANAGED_ID=%s", shQuote(spec$managed_id)),
    sprintf("LAIMS_RUNTIME_BUILD_PREFERRED_BIN=%s", shQuote(build_env$preferred_bin)),
    sprintf("LAIMS_RUNTIME_BUILD_PREFERRED_ARGS=%s", shQuote(build_env$preferred_args)),
    sprintf("LAIMS_RUNTIME_BUILD_FALLBACK_BIN=%s", shQuote(build_env$fallback_bin)),
    sprintf("LAIMS_RUNTIME_BUILD_FALLBACK_ARGS=%s", shQuote(build_env$fallback_args)),
    sprintf("LAIMS_RUNTIME_PACKAGE_VERSION=%s", shQuote(spec$package_version)),
    sprintf("LAIMS_RUNTIME_NAME=%s", shQuote(spec$runtime_name)),
    sprintf("LAIMS_RUNTIME_MODEL=%s", shQuote(spec$model)),
    sprintf("LAIMS_RUNTIME_MODEL_ID=%s", shQuote(spec$model_id))
  )

  paste(
    "mkdir -p",
    shQuote(spec$runtime_root),
    shQuote(spec$remote_assets_dir),
    shQuote(spec$remote_versions_dir),
    "&&",
    paste(vars, collapse = " "),
    "sh",
    shQuote(script_path)
  )
}

.runtime_build_env <- function(config) {
  fallback_bin <- .trim_scalar(config$apptainer_bin %||% "/cm/shared/apps/singularity/4.2.0/bin/singularity")
  if (identical(fallback_bin, "")) {
    fallback_bin <- "/cm/shared/apps/singularity/4.2.0/bin/singularity"
  }

  fallback_leaf <- tolower(basename(fallback_bin))
  fallback_args <- if (identical(fallback_leaf, "singularity")) {
    "build --force --fakeroot"
  } else {
    "build --force"
  }

  list(
    preferred_bin = "apptainer",
    preferred_args = "build --force",
    fallback_bin = fallback_bin,
    fallback_args = fallback_args
  )
}

.runtime_bootstrap_managed <- function(config, spec) {
  asset_dir <- paste(spec$remote_assets_dir, spec$asset_hash, sep = "/")
  mkdir_result <- .runtime_ssh_capture(
    config,
    paste(
      "mkdir -p",
      shQuote(spec$runtime_root),
      shQuote(spec$remote_assets_dir),
      shQuote(spec$remote_versions_dir),
      shQuote(asset_dir)
    )
  )

  if (!isTRUE(mkdir_result$ok)) {
    cli::cli_abort(c(
      "Managed runtime bootstrap failed while preparing remote directories.",
      "x" = mkdir_result$stderr %||% mkdir_result$stdout
    ))
  }

  copy_result <- .runtime_copy_dir(config, spec$assets_dir, asset_dir)
  if (!isTRUE(copy_result$ok)) {
    cli::cli_abort(c(
      "Managed runtime bootstrap failed while copying package runtime assets.",
      "x" = copy_result$stderr %||% copy_result$stdout
    ))
  }

  build_result <- .runtime_ssh_capture(config, .runtime_build_command(config, spec))
  if (!isTRUE(build_result$ok)) {
    cli::cli_abort(c(
      "Managed runtime bootstrap failed while building or refreshing the remote SIF.",
      "x" = build_result$stderr %||% build_result$stdout
    ))
  }

  list(
    mkdir = mkdir_result,
    copy = copy_result,
    build = build_result
  )
}

.validate_external_runtime <- function(config, sif_path) {
  sif_path <- .normalize_sif_path(sif_path)
  if (is.na(sif_path)) {
    cli::cli_abort(c(
      "External runtime mode requires a remote `sif_path`.",
      "i" = "Set `dgx_config(sif_path = ...)` or pass `ensure_runtime(sif_path = ...)`."
    ))
  }

  runtime_bin <- config$apptainer_bin %||% "/cm/shared/apps/singularity/4.2.0/bin/singularity"
  runtime_bin_check <- if (grepl("/", runtime_bin, fixed = TRUE)) {
    paste("[ -x", shQuote(runtime_bin), "]")
  } else {
    paste("command -v", shQuote(runtime_bin), ">/dev/null 2>&1")
  }

  command <- paste(
    "if [ -s", shQuote(sif_path), " ] &&", runtime_bin_check, "; then",
    shQuote(runtime_bin),
    "exec", shQuote(sif_path), "true >/dev/null 2>&1;",
    "else exit 1; fi"
  )
  result <- .runtime_ssh_capture(config, command)
  list(
    ready = isTRUE(result$ok),
    result = result
  )
}

.as_runtime <- function(x) {
  structure(x, class = "laims_dgx_runtime")
}

#' Ensure the remote runtime image is available
#'
#' Resolve the container runtime used for remote SLURM jobs. In `managed`
#' mode, `ensure_runtime()` fingerprints the package-managed assets under
#' `inst/runtime`, chooses one of the two canonical managed runtime identities
#' for the selected `model` (`official-20b` or `official-120b`), checks the
#' remote manifest/current `.sif`, and refreshes it when missing or stale.
#' The concrete bootstrap targets are `<user_root>/runtime/official-20b/` and
#' `<user_root>/runtime/official-120b/`. In `external` mode, it validates an
#' existing remote `.sif` path without attempting a build.
#'
#' @param model Canonical model size to ensure: `"20B"` or `"120B"`.
#' @param sif_path Optional explicit remote `.sif` path. When supplied, this
#'   bypasses managed mode and validates the path as an external runtime.
#' @param dry_run Logical; if `TRUE`, inspect and report what would happen
#'   without building or mutating the remote runtime.
#' @param force Logical; if `TRUE`, treat the managed runtime as stale and
#'   rebuild/refresh it unless `dry_run = TRUE`.
#' @param config A `laims_dgx_config` object. If `NULL`, uses [dgx_config()].
#' @param model_profile Deprecated alias for `model`. Still accepted for
#'   backward compatibility.
#'
#' @return An object of class `laims_dgx_runtime`.
#'
#' @examples
#' \dontrun{
#' cfg <- dgx_config(login_user = "u0043", mail_user = "you@example.org")
#'
#' # Inspect what would happen without touching the remote (dry run)
#' runtime <- ensure_runtime("20B", dry_run = TRUE, config = cfg)
#' print(runtime)
#'
#' # Bootstrap or verify the 20B runtime (builds .sif if missing or stale)
#' runtime <- ensure_runtime("20B", config = cfg)
#'
#' # Force a full rebuild regardless of the cached manifest
#' runtime <- ensure_runtime("20B", force = TRUE, config = cfg)
#'
#' # Use a pre-existing .sif instead of the managed runtime
#' runtime <- ensure_runtime(
#'   "20B",
#'   sif_path = "/mnt/projects/dctv/dgx/u0043/runtime/my-custom.sif",
#'   config   = cfg
#' )
#' }
#' @export
ensure_runtime <- function(model = "20B",
                           sif_path = NULL,
                           dry_run = FALSE,
                           force = FALSE,
                           config = NULL,
                           model_profile = NULL) {
  config <- .resolve_config(config)
  model_key <- .resolve_model_key(model = model, model_profile = model_profile)
  has_destination <- !identical(.ssh_destination(config), "")
  has_key <- .ssh_key_exists(config$ssh_key_path)

  explicit_sif <- .normalize_sif_path(sif_path)
  if (!is.na(explicit_sif)) {
    if (!has_destination && !isTRUE(dry_run)) {
      cli::cli_abort("Cannot validate an external runtime without a DGX login destination in `dgx_config()`.")
    }
    if (!has_key && !isTRUE(dry_run)) {
      .assert_ssh_ready(config, action = "validate the external runtime")
    }

    validation <- if (isTRUE(dry_run)) {
      list(ready = FALSE, result = list(ok = FALSE, status = NA_integer_, stdout = "", stderr = "dry_run"))
    } else {
      .validate_external_runtime(config, explicit_sif)
    }

    return(.as_runtime(list(
      mode = "external",
      source = "explicit",
      model = model_key,
      ready = isTRUE(validation$ready),
      stale = FALSE,
      ensured = !isTRUE(dry_run) && isTRUE(validation$ready),
      action = if (isTRUE(dry_run)) "validate_pending" else "validated",
      sif_path = explicit_sif,
      current_sif_path = explicit_sif,
      manifest_path = NA_character_,
      asset_hash = NA_character_,
      details = validation$result,
      config = config
    )))
  }

  if (identical(config$runtime$mode, "external")) {
    if (!has_destination && !isTRUE(dry_run)) {
      cli::cli_abort("Cannot validate an external runtime without a DGX login destination in `dgx_config()`.")
    }
    if (!has_key && !isTRUE(dry_run)) {
      .assert_ssh_ready(config, action = "validate the external runtime")
    }

    validation <- if (isTRUE(dry_run)) {
      list(ready = FALSE, result = list(ok = FALSE, status = NA_integer_, stdout = "", stderr = "dry_run"))
    } else {
      .validate_external_runtime(config, config$sif_path)
    }

    return(.as_runtime(list(
      mode = "external",
      source = "config",
      model = model_key,
      ready = isTRUE(validation$ready),
      stale = FALSE,
      ensured = !isTRUE(dry_run) && isTRUE(validation$ready),
      action = if (isTRUE(dry_run)) "validate_pending" else "validated",
      sif_path = .normalize_sif_path(config$sif_path) %||% "",
      current_sif_path = .normalize_sif_path(config$sif_path) %||% "",
      manifest_path = NA_character_,
      asset_hash = NA_character_,
      details = validation$result,
      config = config
    )))
  }

  spec <- .local_runtime_spec(config, model = model_key)
  if (!has_destination || !has_key) {
    if (!has_destination && !isTRUE(dry_run)) {
      cli::cli_abort("Cannot ensure a managed runtime without a DGX login destination in `dgx_config()`.")
    }
    if (!has_key && !isTRUE(dry_run)) {
      .assert_ssh_ready(config, action = "ensure the managed runtime")
    }

    return(.as_runtime(list(
      mode = "managed",
      source = "managed",
      model = model_key,
      ready = FALSE,
      stale = TRUE,
      ensured = FALSE,
      action = "connection_required",
      sif_path = spec$current_sif_path,
      current_sif_path = spec$current_sif_path,
      manifest_path = spec$manifest_path,
      asset_hash = spec$asset_hash,
      details = list(reason = if (!has_destination) "login destination is not configured" else "ssh key file was not found"),
      config = config
    )))
  }

  inspected <- .runtime_inspect_remote(config, spec)
  stale <- isTRUE(force) || isTRUE(inspected$stale)
  ready <- !stale
  action <- if (ready) "reuse" else if (isTRUE(dry_run)) "ensure_required" else "build"
  details <- inspected

  if (stale && !isTRUE(dry_run)) {
    details <- utils::modifyList(details, .runtime_bootstrap_managed(config, spec))
    ready <- TRUE
    stale <- FALSE
    action <- "built"
  }

  .as_runtime(list(
    mode = "managed",
    source = "managed",
    model = model_key,
    ready = ready,
    stale = stale,
    ensured = ready && !isTRUE(dry_run),
    action = action,
    sif_path = spec$current_sif_path,
    current_sif_path = spec$current_sif_path,
    manifest_path = spec$manifest_path,
    asset_hash = spec$asset_hash,
    details = details,
    config = config
  ))
}

#' @export
print.laims_dgx_runtime <- function(x, ...) {
  cat("<laims_dgx_runtime>\n", sep = "")
  cat("  model      : ", x$model %||% "<unknown>", "\n", sep = "")
  cat("  mode       : ", x$mode, "\n", sep = "")
  cat("  action     : ", x$action, "\n", sep = "")
  cat("  ready      : ", x$ready, "\n", sep = "")
  cat("  stale      : ", x$stale, "\n", sep = "")
  cat("  sif_path   : ", x$sif_path %||% "<unset>", "\n", sep = "")
  cat("  manifest   : ", x$manifest_path %||% "<unset>", "\n", sep = "")
  invisible(x)
}
