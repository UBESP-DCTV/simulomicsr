# Roadmap

## Già in posto

- control plane R locale con registry SQLite persistente
- bundle locale riproducibile
- submit remoto via SSH + `sbatch`
- sync di stato da `status.json` e scheduler (`squeue` / `sacct`)
- progress / recovery locale
- runtime resolution con due profili pubblici: `20B` e `120B`
- bootstrap reale dei runtime gestiti:
  - `<user_root>/runtime/official-20b/`
  - `<user_root>/runtime/official-120b/`
- motore batch Python funzionante dentro il container
  - lettura bundle, caricamento modello, processing per chunk
  - scrittura `predictions.jsonl`, `errors.jsonl`, `run_summary.json`, `status.json`
- **pipeline verificata end-to-end su cluster reale** (job 16661, 1/1 record, ExitCode 0:0)
- raccolta risultati con parse JSONL → `data.frame`
- documentazione completa: README, schema guide, esempi end-to-end, roxygen @examples

## Prossimo hardening utile

### 1. Hardening del runtime di inferenza nel container

Il layer Python/GPU funziona ma resta da irrobustire per scenari più grandi:

- tuning del backend per `20B` / `120B` (quantizzazione, batch size, timeout)
- strategia cache/download più stabile (pre-warming della cache HuggingFace)
- verifica delle risorse necessarie per `120B` su 1x H100 80GB

### 2. Validazione e retry

- validazione schema record-level con errore utile
- logging più netto tra errori di runtime e parsing
- retry di record/chunk falliti (attualmente vanno in `errors.jsonl`)

### 3. Test su dataset reali più grandi

- smoke test con N > 100 record
- verifica chunking e gestione errori parziali
- tuning di tempi e risorse per `20B` / `120B`

## Fuori scope per ora

- servizio persistente sul cluster
- endpoint pubblico
- dipendenza strutturale da un server OpenAI-compatible
