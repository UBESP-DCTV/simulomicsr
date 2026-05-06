#!/bin/sh
set -eu

ASSET_HASH="${LAIMS_RUNTIME_ASSET_HASH:?}"
ASSET_DIR="${LAIMS_RUNTIME_ASSET_DIR:?}"
VERSIONED_SIF="${LAIMS_RUNTIME_VERSIONED_SIF:?}"
CURRENT_SIF="${LAIMS_RUNTIME_CURRENT_SIF:?}"
MANIFEST_PATH="${LAIMS_RUNTIME_MANIFEST_PATH:?}"
BUILD_PREFERRED_BIN="${LAIMS_RUNTIME_BUILD_PREFERRED_BIN:-apptainer}"
BUILD_PREFERRED_ARGS="${LAIMS_RUNTIME_BUILD_PREFERRED_ARGS:-build --force}"
DEFAULT_BUILD_FALLBACK_BIN="/cm/shared/apps/singularity/4.2.0/bin/singularity"
BUILD_FALLBACK_BIN="${LAIMS_RUNTIME_BUILD_FALLBACK_BIN:-$DEFAULT_BUILD_FALLBACK_BIN}"
BUILD_FALLBACK_ARGS="${LAIMS_RUNTIME_BUILD_FALLBACK_ARGS:-build --force --fakeroot}"
PACKAGE_VERSION="${LAIMS_RUNTIME_PACKAGE_VERSION:-unknown}"
RUNTIME_NAME="${LAIMS_RUNTIME_NAME:-laims-runtime}"
MODEL="${LAIMS_RUNTIME_MODEL:-unknown}"
MODEL_ID="${LAIMS_RUNTIME_MODEL_ID:-unknown}"
RUNTIME_ROOT="${LAIMS_RUNTIME_ROOT:-}"
MANAGED_ID="${LAIMS_RUNTIME_MANAGED_ID:-unknown}"
ENTRYPOINT="python /opt/laims/runtime/python/laims_runtime/run_batch.py"

mkdir -p "$(dirname "$VERSIONED_SIF")" "$(dirname "$CURRENT_SIF")" "$(dirname "$MANIFEST_PATH")"

cd "$ASSET_DIR"

run_build() {
  build_bin="$1"
  build_args="$2"

  if [ -z "$build_bin" ]; then
    return 127
  fi

  if [ "${build_bin#*/}" != "$build_bin" ]; then
    [ -x "$build_bin" ] || return 127
  else
    command -v "$build_bin" >/dev/null 2>&1 || return 127
  fi

  # shellcheck disable=SC2086
  "$build_bin" $build_args "$VERSIONED_SIF" runtime.def
}

if [ ! -s "$VERSIONED_SIF" ]; then
  if ! run_build "$BUILD_PREFERRED_BIN" "$BUILD_PREFERRED_ARGS"; then
    if ! run_build "$BUILD_FALLBACK_BIN" "$BUILD_FALLBACK_ARGS"; then
      if ! run_build "singularity" "build --force --fakeroot"; then
        echo "No usable container builder found for managed runtime bootstrap." >&2
        exit 1
      fi
    fi
  fi
fi

ln -sfn "$VERSIONED_SIF" "$CURRENT_SIF"

cat >"$MANIFEST_PATH" <<EOF
{
  "runtime_name": "$RUNTIME_NAME",
  "managed_id": "$MANAGED_ID",
  "runtime_root": "$RUNTIME_ROOT",
  "model": "$MODEL",
  "model_id": "$MODEL_ID",
  "asset_hash": "$ASSET_HASH",
  "package_version": "$PACKAGE_VERSION",
  "current_sif_path": "$CURRENT_SIF",
  "versioned_sif_path": "$VERSIONED_SIF",
  "entrypoint": "$ENTRYPOINT",
  "runtime_contract_version": "0.1",
  "built_at_note": "manifest rewritten on bootstrap; first model load may still trigger Hugging Face downloads"
}
EOF
