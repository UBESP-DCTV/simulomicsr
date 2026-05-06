# Container notes

`laimsdgxllm` is an **R-first control-plane package**. The cluster runtime is a
separate concern.

## Current state

The repo already includes a real managed-runtime bootstrap path through
`ensure_runtime()` plus the assets under `inst/runtime/`.

That bootstrap currently builds a minimal Apptainer image and maintains two
canonical remote runtime identities:

- `official-20b`
- `official-120b`

Those identities are resolved from the public model choices exposed to users:

- `"20B"`
- `"120B"`

## What this `container/` directory is for

This directory is design documentation only. It describes the likely longer-term
shape of the inference container once the project grows beyond the current
minimal managed image.

## Intended long-term split

- **R outside the cluster job** for config, staging, submit, sync, and results
- **Python inside the container** for GPU inference and structured-output logic

## What is not claimed yet

The package does **not** currently claim to ship a full model-serving runtime in
this directory. The real bootstrap/init path lives in `inst/runtime/`, while
`container/` remains a place for future runtime design notes.
