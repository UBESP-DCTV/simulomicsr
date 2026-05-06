# Managed runtime assets

This directory contains the local assets used by `ensure_runtime()` when
default `dgx_config()` (or explicitly `dgx_config(runtime_mode = "managed")`).

## What is real today

The package manages exactly two remote runtime identities:

- `20B` -> `<user_root>/runtime/official-20b/`
- `120B` -> `<user_root>/runtime/official-120b/`

For each identity, `ensure_runtime()` performs a real bootstrap flow:

1. fingerprint the local assets in `inst/runtime/`
2. create the remote runtime directories
3. copy the assets to `.../assets/<asset_hash>/`
4. run `build-runtime.sh` remotely
5. build or reuse `.../versions/<runtime-name>-<asset_hash>.sif`
6. refresh `current.sif`
7. write `manifest.json`

## Runtime payload

- `runtime.def` - practical Apptainer definition based on a CUDA-enabled PyTorch
  image, with Python dependencies installed into the container
- `build-runtime.sh` - remote bootstrap script executed by `ensure_runtime()`
- `requirements.txt` - Python dependencies for the first-pass engine
- `bin/run-batch` - compatibility wrapper kept in the image with explicit `0755` permissions
  for manual/debug use; the SLURM template and container runscript invoke the Python
  entrypoint directly to avoid shell-open permission issues in Apptainer/Singularity
  runscript
- `python/laims_runtime/run_batch.py` - batch runner that reads the staged
  bundle, loads the requested official model, processes chunked records, updates
  `status.json`, and writes `predictions.jsonl`, `errors.jsonl`, and
  `run_summary.json`
- `python/laims_runtime/backend.py` - backend abstraction with:
  - `transformers` as the real first-pass execution path
  - `mock` as a local test/dry execution path for contract tests

## Important scope note

This is now more than a placeholder: the managed runtime contains a concrete
batch runner and a plausible Python inference stack for the two supported
official models.

What remains provisional:

- first model load may trigger container/base-image downloads and model-weight
  downloads from Hugging Face
- the `transformers` backend is a practical first pass, not a tuned production
  serving stack
- successful execution still depends on cluster-side Apptainer GPU support,
  outbound access or preseeded caches, and valid Hugging Face access for the
  official model repositories
- JSON/schema conformance is still best-effort; constrained decoding and retry
  logic are not implemented yet
