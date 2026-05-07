# ADR-0007: DGX self-host vLLM mistral-small-3.2 per P4

- **Status:** Accepted (smoke E2E verde 2026-05-07, job 19723)
- **Date:** 2026-05-06 (decisione), 2026-05-07 (validazione end-to-end)
- **Deciders:** Luca Vedovelli
- **Supersedes:** —
- **Superseded by:** —

## Update 2026-05-07 (smoke verde)

Smoke 1-GPU end-to-end passato (job 19723 su poddgx03, 2:41 min totali):
modello caricato in 125s (44.7 GiB GPU), 1 prompt JSON-strict generato
in 1.44s con `parsed={'ack':'ok','n':42}`. Cambiamenti rispetto al
design originale del 2026-05-06:

- **Image base bumpata**: `vllm/vllm-openai:v0.6.4` → **`v0.10.0`**.
  v0.6.4 dava `KeyError 'mistral3'` perche' transformers 4.45 non
  conosce `Mistral3Config` (multimodale, introdotto in 4.49).
- **vLLM API mistral-specific**: `tokenizer_mode="mistral"` +
  `config_format="mistral"` + `load_format="mistral"` + `llm.chat()`
  (NO `apply_chat_template` perche' Tekken/`mistral_common`).
- **`GuidedDecodingParams(json=schema)`** sostituisce `guided_json=schema`
  (API v1 vLLM 0.10).
- **Path remoti**: `/home/u0044/...` NON `/mnt/home/u0044/...`. I compute
  node UniPD HPC (poddgx01/02/03) non montano `/mnt/home/`. Verificato
  col probe job 19720 su poddgx03.
- **Esecuzione singularity**: diretta (NO `srun singularity`), come
  scRNA_DGX/smoke_test.sh validato. Bind: `/home/u0044`, `bundles/`,
  `runs/`, `models/HF_HOME`, `runtime/python` (script Python rsync-ati
  a ogni submit, no rebuild SIF).
- **`runs/<run_id>/` mkdir prima del sbatch**: SLURM `--output`/`--error`
  puntano li' e fallisce con signal 53 senza log se la dir non c'e'.

## Context and Problem Statement

P3.5-D ha valutato 14+ modelli LLM su mini-gold v5 con il task di
classificazione `study_design` Stadio 2 (100 sample, 50 GSE). Vincitore
per rapporto accuracy/costo: `mistralai/Mistral-Small-3.2-24B-Instruct-2506`
(Apache 2.0, 96% accuracy, $0.0004/sample via OpenRouter).

P4 richiede di portare la pipeline a scala massiva: ~130k sample (alpha)
fino a ~700k sample (beta). Il costo OpenRouter su 700k sample a
$0.0004/sample sarebbe ~$280 -- fattibile, ma il budget disponibile
e' $0 perche' il laboratorio ha accesso al DGX UniPD HPC (nodo
`poddgx02`, 8x H100 80GB = 640 GB VRAM totali). Self-hosting elimina
la dipendenza da terze parti, i rate limit OpenRouter, e il rischio
di degrado qualita' per quantizzazione vendor-side (OpenRouter non
garantisce FP16 per modelli open).

La questione e': come integrare il self-hosting DGX nel controllo
dell'utente R senza dipendere da codice esterno non mantenuto
(`laimsdgxllm` del collega)?

## Decision Drivers

- **Costo zero**: HPC gia' disponibile, P4 non puo' costare $280+.
- **Qualita' FP16 garantita**: evitare il degrado per quantizzazione
  aggressiva (Q3-Q4) che OpenRouter potrebbe applicare vendor-side.
- **Idempotenza e resume**: run massivo su 700k sample deve essere
  riprendibile dopo crash/timeout SLURM senza re-elaborare record gia' pronti.
- **Ownership totale del codice**: niente fork di repo di colleghi
  (dipendenza non mantenuta, codice incompatibile con vLLM continous
  batching, backend `transformers` 10x piu' lento).
- **Workflow ergonomico da R**: l'utente non deve uscire da R per
  gestire il run.

## Considered Options

1. **Self-host vLLM su DGX (questa ADR)** -- container Apptainer +
   job SLURM batch + vLLM offline batch + control plane R `dgx_*`.
2. **Fork `laimsdgxllm`** -- adattare il pacchetto del collega
   (SSH/SLURM/registry gia' implementati).
3. **OpenRouter mistral-small-3.2** -- continuare a usare l'API
   cloud gia' funzionante da P3.5-D.
4. **vLLM server persistente (`vllm serve`)** -- servizio always-on
   che espone endpoint OpenAI-compatible, riusando `R/llm-client-openrouter.R`.

## Decision Outcome

Scelta: **Opzione 1 -- self-host vLLM su DGX tramite Apptainer + SLURM batch.**

Motivazione: e' l'unica opzione che combina costo zero, qualita' FP16
nativa, resume idempotente su run massivo, e ownership completa del
codice. Fork `laimsdgxllm` richiederebbe di riscrivere ~80% del codice
(modelli hardcoded, backend `transformers` senza continuous batching,
~10x piu' lento di vLLM). OpenRouter risolve costo e qualita' ma
introduce dipendenza da rete e $280 su run beta. `vllm serve` persistente
e' incompatibile con SLURM (non garantisce servizio always-on fuori
da un job batch).

### Consequences

- **Positive:**
  - Costo P4: $0 (solo elettricita').
  - Qualita' FP16 nativa: nessun degrado per quantizzazione vendor.
  - Resume idempotente: `predictions.worker_*.jsonl` append-only,
    ripartenza senza re-elaborare record gia' pronti.
  - Ownership totale: nessuna dipendenza da repo esterni non mantenuti.
  - Scalabilita': 4x H100 in data-parallel coprono 130k--700k sample
    in ~30 min (modello 24B entra largo in 80GB VRAM singola, no tensor
    parallel necessario).
- **Negative:**
  - Setup one-time piu' complesso: build Docker locale, push DockerHub,
    pull Singularity sul cluster, pre-download ~50 GB pesi modello.
  - Nuova dipendenza R: `processx` (subprocess SSH/rsync).
  - Nuovo asset committato nel repo: `inst/dgx/` (~230 LOC Python +
    1 SLURM template + Dockerfile + Makefile).
- **Neutral:**
  - ADR-0005 (server migration trigger) parzialmente assorbito: P4
    gira sulla DGX, ma `analysis/cache/` e altri artefatti restano
    sul laptop fino a migrazione completa.
  - `R/llm-client-openrouter.R` rimane nel repo come fallback per
    run esplorativi piccoli (P3.5-D, smoke test via API).

## Pros and Cons of the Options

### Opzione 1: self-host vLLM su DGX

- **Pro:** costo zero; FP16 nativo; resume idempotente; ownership; 4x H100 in ~30 min.
- **Contro:** setup one-time complesso (Docker + Singularity + HF download).

### Opzione 2: fork laimsdgxllm

- **Pro:** SSH/SLURM/registry gia' implementati dal collega.
- **Contro:** ~80% del codice da riscrivere (modelli hardcoded, backend
  `transformers` single-record-loop ~10x piu' lento di vLLM continuous
  batching); dipendenza da manutentore esterno.

### Opzione 3: OpenRouter mistral-small-3.2

- **Pro:** zero infra; gia' funzionante da P3.5-D; nessun setup.
- **Contro:** ~$280 su run beta (700k sample); dipendenza da
  network/uptime di terzi; rate limit; qualita' non garantita FP16.

### Opzione 4: vLLM server persistente

- **Pro:** riusa `R/llm-client-openrouter.R` invariato; endpoint
  OpenAI-compatible.
- **Contro:** cluster SLURM non garantisce servizio always-on fuori
  da job batch; richiede comunque un job batch wrapper.

## Implementation Notes

Architettura implementata:

1. **Container**: `inst/dgx/Dockerfile` (base `vllm/vllm-openai:latest`)
   + script Python `inst/dgx/python/run_p4_vllm.py` per vLLM offline
   batch con `guided_json=schema`. Build locale, push DockerHub
   `lucavd/simulomicsr-vllm:latest`, pull come SIF Singularity sul cluster.

2. **SLURM**: template `inst/dgx/slurm/run_p4.sh.template` (4x H100,
   data-parallel, no tensor parallel). Renderizzato da `dgx_p4_submit()`
   con parametri dinamici (n_gpus, time, input_path, output_dir).

3. **vLLM offline batch**: `LLM().generate()` con
   `SamplingParams(guided_json=schema)` garantisce output schema-valid.
   Worker scrivono `predictions.worker_<i>.jsonl` append-only.
   `dgx_p4_collect()` mergia e deduplica.

4. **Control plane R**: 5 funzioni esportate `dgx_*` in
   `R/dgx-control.R` (`dgx_config`, `dgx_p4_build_bundle`,
   `dgx_p4_submit`, `dgx_p4_status`, `dgx_p4_collect`).

5. **Workflow utente** (dopo setup one-time):
   ```r
   cfg    <- dgx_config()
   bundle <- dgx_p4_build_bundle(input_path, "stage1", cfg)
   job    <- dgx_p4_submit(bundle, time = "01:00:00", config = cfg)
   dgx_p4_status(job, watch = TRUE, interval = 30)
   result <- dgx_p4_collect(job)
   ```

## Links

- Spec P4 design: `docs/superpowers/specs/2026-05-06-p4-dgx-integration-design.md`
- Plan P4: `docs/superpowers/plans/2026-05-06-p4-dgx-integration-plan.md`
- P3.5-D risultati: CLAUDE.md sezione "Risultati conclusivi P3.5-D"
- ADR-0005 server migration: `docs/decisions/0005-server-migration-trigger.md`
- `laims-dgx-llm-batch-main` esempio collega (riferimento, non importato)
- `2026.scRNA_DGX` esempio interno (stesso cluster, pattern Singularity)
