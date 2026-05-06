# Architettura attuale

## Executive summary

`laimsdgxllm` è un package R che orchestra run batch LLM su un cluster DGX
raggiungibile via login node, SSH, SLURM e Apptainer/Singularity.

Il laptop dell'utente è il control plane. Il cluster esegue job one-shot. Non
ci sono servizi persistenti né endpoint pubblici.

## Flusso operativo

1. `dgx_config()` definisce host, utente, chiave SSH, root remoto, modalità
   runtime (default `managed`), mail di notifica e risorse di job.
2. `create_bundle()` crea il bundle locale con `manifest.json`, `run_meta.json`,
   `status.json`, `records.jsonl`, `schema.json`, `prompt.txt` e
   `chunk_plan.jsonl`.
3. `ensure_runtime()` risolve il runtime:
   - `managed`: bootstrap o riuso del runtime ufficiale del modello
   - `external`: validazione di un `.sif` remoto già esistente
4. `submit_job()` esegue staging remoto, renderizza `submit_slurm.sh` e lancia
   `sbatch`.
5. `job_status()`, `sync_job()`, `sync_jobs()`, `progress()` e
   `collect_results()` seguono il ciclo di vita del run.

## Runtime gestito: stato reale

Il package gestisce **esattamente due** runtime condivisi lato cluster:

- `20B` -> `<user_root>/runtime/official-20b/`
- `120B` -> `<user_root>/runtime/official-120b/`

Il bootstrap è concreto:

1. fingerprint degli asset locali in `inst/runtime/`
2. copia remota in `assets/<asset_hash>/`
3. esecuzione remota di `build-runtime.sh`
4. build o riuso di una `.sif` versionata in `versions/`
5. aggiornamento di `current.sif`
6. scrittura di `manifest.json`

Questa parte non è placeholder: è il percorso realmente usato da
`ensure_runtime()`.

## Stato verificato end-to-end

Il pipeline è stato testato su cluster reale (job 16661, H100 80GB, SLURM). Il
percorso completo funziona:

- bootstrap runtime via `ensure_runtime()` e `build-runtime.sh`
- staging bundle via SCP e submit via `sbatch`
- esecuzione batch dentro il container (`pytorch/pytorch:2.6.0-cuda12.6-cudnn9-runtime`)
- scrittura di `predictions.jsonl`, `errors.jsonl`, `run_summary.json`, `status.json`
- raccolta risultati via `collect_results()` con parse JSONL → `data.frame`

Il runtime usa:

- `pytorch/pytorch:2.6.0-cuda12.6-cudnn9-runtime` (richiesto per `torch.accelerator`)
- `transformers`: kwarg `dtype` (non `torch_dtype`, deprecato)
- `chmod -R a+rX /opt/laims/runtime/python` nel `%post` del `.def` per evitare
  EACCES sul runner Python
- `I()` attorno ai vettori di lunghezza 1 in `record_ids` e `required` nello
  schema JSON per preservare la forma array con `jsonlite::toJSON(auto_unbox=TRUE)`

## Artefatti remoti per run

Ogni run remoto usa una directory dedicata sotto `<user_root>/runs/<run_id>`.
I percorsi principali previsti dal package sono:

- `bundle/`
- `output/`
- `status.json`
- `slurm-%j.out`
- `slurm-%j.err`

Gli output applicativi attesi includono:

- `predictions.jsonl`
- `errors.jsonl`
- `run_summary.json`

Il job script monta anche la root del run remoto in modo che il runtime scriva
`status.json` dove il control plane R se lo aspetta per `sync_job()`.
Il launch segue ora il pattern cluster-native già noto sul DGX cluster:
carica `singularity/4.2.0` e `slurm/slurm/23.02.7`, dichiara `#SBATCH --nodes=1`
e `#SBATCH --ntasks=1`, e avvia il container con
`/cm/shared/apps/singularity/4.2.0/bin/singularity exec --nv ...` tramite `srun`.
Il package mantiene `nodelist = "poddgx02"`
come default di cluster, ma `nodelist` resta un input utente overrideabile.
Restano i bind essenziali per run, bundle, output e la cache Hugging Face persistente da
`<user_root>/runtime/cache/huggingface` a `/opt/laims/cache/huggingface`,
piu' una home scrivibile montata da `<user_root>/runtime/home` verso `/home/<login_user>`
con `--pwd` interno su quella home e l'export di `HF_HOME` e
`TRANSFORMERS_CACHE`. L'entrypoint del runtime batch viene invocato tramite
`/bin/sh /opt/laims/runtime/bin/run-batch`, evitando di dipendere dal path
Python interno del package nel container.

## Registry locale

Il client mantiene un registry SQLite locale persistente per:

- discovery dei run
- recovery dopo restart
- mapping `run_id -> job_id / remote_run_dir`
- sync di stato
- tracking di progress e raccolta risultati

## API pubblica corrente

Le funzioni principali attuali sono:

- `dgx_config()`
- `ensure_runtime()`
- `create_bundle()`
- `submit_job()`
- `extract_batch()`
- `jobs_list()`
- `recover_job()`
- `sync_job()`
- `sync_jobs()`
- `job_status()`
- `progress()`
- `collect_results()`

## Modelli supportati

L'interfaccia pubblica espone solo due scelte canoniche:

- `"20B"`
- `"120B"`

Il package risolve internamente il catalogo modello/runtime corrispondente.

## Vincoli intenzionali

- host login fisso: `logindgx.hpc.ict.unipd.it`
- nessun servizio persistente sul cluster
- nessun endpoint pubblico
- GPU count fissato a `1`
- hardware story fissata a `H100 80GB`

## Conclusione

L'architettura attuale è coerente con un package R async-first e file-based.
Il punto importante per questa iterazione è che il layer runtime non è più una
promessa vaga: il repo contiene un bootstrap esplicito e verificabile per i due
runtime gestiti `20B` e `120B`, più un primo percorso eseguibile di batch
inference dentro il container.
