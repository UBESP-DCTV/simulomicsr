# P4 β — ETL ARCHS4 human + classification stage1+stage2 (design spec)

**Stato:** draft 2026-05-11 — in attesa di review utente
**Branch target:** `p4-beta-archs4-human` (da creare partendo da `master` @ `p4-vllm-upgrade-v0.20.2-complete`)
**Predecessore:** P4 α stage2 cs50 (`alpha-stage2-cs50-final` 6649/6652 valid, mini-gold 96.7%)
**Successore previsto:** P4 γ — mouse + ortholog mapping (post P4 β validation)
**Decisioni rilevanti:** ADR-0006 (positioning vs RummaGEO), ADR-0008 (sampling defaults), ADR-0010 (vLLM v0.20.2-cu129), ADR-0011 (tier-based max_tokens), ADR-0013 (cs50 default)

## 1. Goal

Eseguire la pipeline classification stage1+stage2 sull'intero dump bulk RNA-seq **human** di ARCHS4 — ~500k sample / ~10k studies — producendo:

- `sample_facts.stage1.v3` per ogni sample classificabile
- `study_facts.stage2.v3` per ogni studio classificabile (design_role + replicate_groups + comparisons con `comparability_anchor` canonicalizzato)
- Tabella di copertura per studio (sample classificati / sample totali / motivo esclusione)

Questo è il prerequisito ETL per Stadio 3 (clustering cross-studio) e Stadio 4+5 (DE per-studio + meta-analisi REM) descritti in ADR-0006.

## 2. Posizionamento vs filtri di qualità a monte (Q1 della brainstorming)

**Decisione: nessun filtro `sample_count_per_study` ex-ante.**

Il filtraggio aggressivo che fanno altri tool (RummaGEO ≥ N sample) rinuncia esattamente al meccanismo che giustifica i 100h di DGX: il pooling REM in `metafor` è progettato per aggregare studies piccoli pesandoli per inverse-variance. Uno studio n=3 vs n=3 con CI larga contribuisce comunque a un pooled effect-size robusto quando 50 studies condividono lo stesso `comparability_anchor`.

Il filtro vero è **naturale e differito**:

1. **Stage2** produce zero comparisons per studies senza replicati validi → escluso da Stadio 3 senza spreco a valle.
2. **Stadio 3** cluster su `comparability_anchor`: snowflake studies non matchano nessun anchor popolato e cadono fuori dal pooling automaticamente.
3. **Stadio 4+5** lavora solo sui cluster con peso REM significativo.

Filtri legittimi pre-stage1:
- **Organismo**: human-only in P4 β (mouse in P4 γ separato).
- **Library strategy**: solo `RNA-Seq` bulk (escludere `scRNA-seq`, `miRNA-Seq`, `ATAC-seq` se presenti nel dump).
- **Stringa metadata non-empty**: se la stringa risultante dall'ETL (sezione 4.2) è < 20 char, il sample è non-classificabile → log + skip senza chiamata LLM.

## 3. Decisioni architetturali (riepilogo brainstorming)

| Decisione | Scelta | Rationale |
|---|---|---|
| Scope filtri | A: no filtro sample count | USP del progetto vs RummaGEO (sez. 2) |
| Organism | Human-only (P4 β) | Match diretto col benchmark RummaGEO + rischio scaling ridotto |
| Resume strategy | A per entrambi stadi: single long job + cache LLM idempotent + cron monitoring proattivo | Coerenza scientifica (no mixed config tra stadi) |
| Format stringa stage1 | B: `characteristics_ch1 + title + source_name_ch1` con pre-eval mini-gold gating | Più contesto LLM, ma format diverso dal gold-standard → re-eval obbligatoria |
| cs50 vs cs25 | cs50 confermato, scaling solo data-driven | ADR-0013 + nessuna evidence pre-empirica per cs45/cs40 |

## 4. Architettura

### 4.1 Pipeline complessiva

```
ARCHS4 human_gene_v2.5.h5  (45 GB)
    │
    ▼  [4.2 ETL H5 → JSONL]
analysis/input/archs4-human-stage1-input.jsonl  (~500k record)
    │
    ▼  [4.3 GATE #1 mini-gold format B re-eval (100 sample)]
analysis/p4-output/<TS>-p4-beta-minigold-formatB/  + metriche
    │
    ▼  [4.3-bis GATE #2 smoke test stratificato (1000 sample casuali)]
analysis/p4-output/<TS>-p4-beta-smoke1000/  + metriche
    │
    ▼  [4.4 Stage1 full run, single SLURM job, vLLM v0.20.2-cu129]
analysis/p4-output/<TS>-p4-beta-stage1/predictions.jsonl  (~500k record)
    │
    ▼  [4.5 Stage1 → stage2 aggregation per primary series_id, cs50 chunks]
analysis/input/archs4-human-stage2-input/  (chunked JSON files)
    │
    ▼  [4.6 Stage2 full run, single SLURM job, vLLM v0.20.2-cu129]
analysis/p4-output/<TS>-p4-beta-stage2/predictions.jsonl  (~10k studi × records)
    │
    ▼  [4.7 Aggregation + coverage report]
analysis/p4-output/p4-beta-coverage.rds  +  p4-beta-coverage.html
```

### 4.2 ETL HDF5 → JSONL transform

**Source.** ARCHS4 human gene-level dump dalla pagina download ufficiale (`https://maayanlab.cloud/archs4/download.html`):

- **File:** `human_gene_v2.5.h5`
- **Versione:** v2.5
- **Size:** 45 GB
- **Last update:** 2024-08-24
- **Razionale**: ultima versione gene-level stabile pubblicata da Maayan Lab al 2026-05-11. Le versioni più recenti pubbliche sono solo transcript-level (`human_transcript_v2.5.h5` 136 GB) e TPM (`human_tpm_v2.2.h5` 218 GB), non utili per noi: P4 β usa solo metadata, Stadio 4 (DE) richiede gene-level counts.

SHA256 calcolato al download e committato in `analysis/p4-output/p4-beta-archs4-source.json` come provenance record.

**Lettura.** Pacchetto R `rhdf5` (BioC) o `hdf5r`. Campi target da `/meta/samples/`:
- `geo_accession` (sample-level GSM ID)
- `series_id` (uno o più GSE separati da `,`)
- `characteristics_ch1` (formato `"key: value,key: value"`)
- `title` (titolo sample)
- `source_name_ch1` (es. "MCF7 cells, drug-treated")
- `library_strategy` (filtro su `RNA-Seq`)
- `organism_ch1` (sanity check `Homo sapiens`)

**String format B.** Per ogni sample:

```
string = paste(
  paste0("title: ", title),
  paste0("source: ", source_name_ch1),
  characteristics_ch1,
  sep = ","
)
```

Es:
```
title: RNA-seq of MCF7 treated with tamoxifen 24h,source: MCF7 cell line,cell line: MCF7,treatment: tamoxifen 1uM,timepoint: 24h
```

Campi vuoti/NA degradano gracefully (es. solo `source` + `characteristics` se `title` mancante). Se il risultato è < 20 char → skip.

**Output schema JSONL** (`archs4-human-stage1-input.jsonl`):

```json
{"geo_accession":"GSM...","series_id":"GSE...","string":"...","library_strategy":"RNA-Seq","organism":"Homo sapiens"}
```

Una riga per sample. Atteso ~500k righe / ~150-200 MB compresso.

**Filtri applicati in ETL:**
- `library_strategy == "RNA-Seq"` (drop scRNA, miRNA, ATAC, ChIP)
- `organism_ch1 == "Homo sapiens"` (sanity)
- `nchar(string) >= 20`
- `!is.na(characteristics_ch1) || !is.na(title)` (almeno uno dei due deve esistere)

**Provenance log** per ogni sample escluso: `analysis/p4-output/p4-beta-etl-skipped.tsv` con colonne `geo_accession, series_id, skip_reason`.

**Gestione `series_id` multipli.** In ARCHS4 il campo `series_id` può contenere più GSE separati da virgola (es. `"GSE145668,GSE145669"`), tipicamente per relazioni super-series ↔ sub-series in GEO, multi-paper publication, o resubmission. Stage2 lavora a livello di studio, quindi serve una policy.

**Decisione: Primary only (opzione A).** Aggrega per `series_id[0]` (il primo elemento della lista). Lo stesso `geo_accession` appartiene a un solo studio in stage2 e contribuisce a un solo cluster Stadio 3.

**Rationale:**
- Opzione "Replicate" (sample in ogni series_id) è matematicamente scorretta per REM in `metafor`: violerebbe l'indipendenza degli effect-size con double-counting.
- Opzione "Smart selection via GEO API" (chiama NCBI Entrez, scarta `SuperSeries` tieni `SubSeries`) è la più corretta ma sproporzionata per P4 β (~5k chiamate API extra, codice ad hoc).
- Primary è pragmatica: nella maggior parte dei casi `series_id[0]` è la sub-series specifica o il sole accession; se è una super-series multi-omics, perdiamo specificità ma non correttezza statistica.

**Tracking.** ETL log: per ogni sample con `series_id` multipli, salva `geo_accession, series_id_primary, series_id_secondary` in `analysis/p4-output/p4-beta-etl-multiseries.tsv`. Coverage report (sez. 4.7) mostra la distribuzione percentuale — se > 5%, considerare migrazione a opzione C in P4 γ.

### 4.3 Pre-flight: mini-gold re-eval format B (GATING)

**Necessario prima di qualunque full-run stage1.** Format B è off-distribution rispetto al gold P3.5-A su cui Mistral-Small-3.2 ha registrato 96.7% mini-gold.

**Procedura:**

1. Costruire `minigold-v5-format-B.csv`: stesse 100 sample di `p35c-minigold-reviewed-v5.csv`, ma colonna `string` ricostruita con format B usando `title + source_name + characteristics`. Per ottenere `title` e `source_name` originali, lookup via `geo_accession` su GEO (script ad-hoc, una tantum, cacheabile).
2. Sottomettere job DGX stage1+stage2 sul mini-gold format B con config **identica al full-run pianificato**: vLLM v0.20.2-cu129, structured outputs, temperature 0.0 / repetition 1.1, cs50, tier max_tokens, max_num_seqs=6, microbatch=50.
3. Calcolare metriche: schema valid rate (target ≥ 99.5%), mini-gold accuracy (target ≥ 96.7%, threshold blocco < 95%), n_overflow per tier (target = 0 per tier_XL).

**Gate decision:**
- PASS (≥ 96.7% acc, 0 overflow): procedi a smoke test 1000 sample (sez. 4.3-bis) prima del full-run.
- PASS borderline (95-96.7% acc): nuova sessione conversazionale per decidere se accettare il leggero drop o iterare prompt stage1 con esempi B.
- FAIL accuracy < 95%: investigare causa (off-distribution stage1 vs degradazione stage2). Format B potrebbe richiedere prompt tuning.
- FAIL overflow stage2 osservato: scaling cs50 → cs45 → cs40 in step, MAI cs25 senza altra evidence.

### 4.3-bis Smoke test 1000 sample casuali (pre-full-run sanity)

Secondo gate dopo mini-gold PASS, prima di sottomettere il job 35h+ di stage1 full. Validazione su volume reale (1000 sample) per catturare problemi di scale che mini-gold (100 sample) non vede.

**Procedura:**
1. Da `archs4-human-stage1-input.jsonl` (output ETL completo, ~500k record), sample casuale stratificato N=1000 con `set.seed(42)`: stratificazione per quantile di `nchar(string)` (Q1/Q2/Q3/Q4) per coprire la distribuzione di lunghezza input.
2. Sottomettere job DGX stage1+stage2 sul subset N=1000 con config **identica al full-run**: vLLM v0.20.2-cu129, structured outputs, temperature 0.0, repetition 1.1, max_num_seqs=6, microbatch=50, cs50, tier max_tokens. Stima wall ~1-1.5h.
3. Calcolare metriche:
   - Stage1 schema valid rate (target ≥ 99.5%)
   - Stage2 schema valid rate (target ≥ 99.5%, parity α cs50 99.96%)
   - n_overflow per tier S/M/L/XL (target = 0 per XL)
   - Throughput effettivo rec/min (per refinare la stima 35h+50-70h del full-run)
   - Distribuzione `design_role` plausibile (no anomalie ovvie, es. > 50% `unclassifiable`)
   - Distribuzione tier S/M/L/XL coerente con α (~70% S, ~25% M, ~4% L, ~1% XL)
4. Output dump in `analysis/p4-output/<TS>-p4-beta-smoke1000/` per audit.

**Gate decision:**
- PASS: lancia full-run stage1 con confidence calibrata.
- FAIL throughput < 50% stima: rivedi stima totale (potrebbe essere 200h+ wall invece di 100h), valuta se procedere.
- FAIL schema valid < 99%: investigare (probabile bug ETL o config drift), NON procedere a full-run.
- FAIL distribuzione anomala: investigare (potrebbe essere format B effetto su distribution dei `design_role` da gold P3.5-A).

### 4.4 Stage1 full-run

**Container:** `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` (stesso ADR-0010).
**Modello:** `mistralai/Mistral-Small-3.2-24B-Instruct-2506` FP16.
**Sampling:** `temperature=0.0, repetition_penalty=1.1` (ADR-0008).
**Concurrency:** `max_num_seqs=6, microbatch=50` (ADR-0010 restored post PR #40946).
**Schema validation:** `StructuredOutputsParams` (xgrammar→outlines fallback). Heuristic recovery NON applicata (Phase 5 cleanup ADR-0010).

**Job submission:**
- Bundle build via `dgx_p4_build_bundle()` (riuso `R/dgx-bundle.R`).
- SLURM time = `168:00:00` (7 gg, partition `dgx12cluster` è `infinite` quindi non serve limite stretto; 168h è un cap difensivo per evitare run permanenti su bug).
- Resume capability: se il job muore (node down, network glitch), re-submetto con cache LLM in `analysis/cache/` che salta i record già processati.

**Stima:** ~500k sample / ~250 rec/min (stage1 con concurrency=6) → ~35h wall.

### 4.5 Stage1 → Stage2 input aggregation

Riuso `analysis/p4-stage2-build-input.R` con `CHUNK_SIZE = 50` (cs50). Variante: input source è `analysis/p4-output/<TS>-p4-beta-stage1/predictions.jsonl` invece dell'alpha XLSX.

### 4.6 Stage2 full-run

**Configurazione identica a stage1** (sez. 4.4) tranne:
- Tier-based max_tokens per record S/M/L/XL → 4K/8K/16K/32K (ADR-0011).
- Aggregation chunks cs50.

**Stima:** ~10k studi aggregati × records con tier → ~50-70h wall (estrapolazione da α stage2 cs50: 6649 record / ~32h).

### 4.7 Coverage report

Pacchetto Quarto o report R: `analysis/p4-beta-coverage.html`. Sezioni:
- Sample classificati / sample totali / sample skippati (per motivo).
- Studi classificati / studi totali.
- Distribuzione `design_role` (treatment_vs_control, time_course, dose_response, case_control, ecc.).
- Distribuzione `comparability_anchor` (top-20 anchor + tail).
- Sample con `low_confidence` / `ambiguous` flag.
- Comparison vs P4 α (incremento numero studies disponibili per Stadio 3).

## 5. Resume & monitoring infrastructure

### 5.1 Resume strategy (decisione brainstorming)

Single long SLURM job per stadio + cache LLM idempotent. Re-submit manuale in caso di node failure / network glitch / time limit hit. Niente sharding, niente auto-resume signal-trap.

**Recovery procedure documentata in spec**:
1. Verificare via cron (sez. 5.2) lo stato job.
2. Se `FAILED` o `TIMEOUT`: ispezionare `analysis/p4-output/<TS>/slurm.out` + cache hit rate.
3. Re-submit identico (stesso bundle, stesso job_name +`-rN` suffix) — cache salta record completati.
4. Se 3 consecutive failures: aprire sessione conversazionale per investigazione (non risolvere in autopilot).

### 5.2 Cron monitoring (proattivo, NON background script)

L'utente monitora via app Claude (no Telegram bot, no notifiche push). Lo script di monitoring genera un log strutturato che l'utente legge a discrezione (o che Claude può ispezionare on-demand all'inizio di sessione successiva).

Cron sul laptop dell'utente:

```cron
# Ogni 2h, ssh DGX per snapshot stato job + tail logs ultimi 50 righe
0 */2 * * * /home/user/simulomicsr/scripts/p4-beta-monitor.sh >> /home/user/simulomicsr/analysis/p4-beta-monitor.log 2>&1
```

Lo script `scripts/p4-beta-monitor.sh` fa:
1. `ssh dgx 'squeue -u u0044 --format="%A %j %T %M %l"'` → lista job attivi con state + elapsed + time-limit.
2. Per ogni job RUNNING, `ssh dgx 'tail -50 ~/p4-beta/slurm-*.out'` → snapshot progress.
3. Conta record processati nel JSONL output corrente per stimare throughput live (es. `wc -l predictions.jsonl`).
4. Append a `analysis/p4-beta-monitor.log` con header chiaro per ogni snapshot: timestamp ISO, job_state, elapsed, n_records, n_overflow, n_cache_hit.
5. Se `0` job attivi E last logged state ≠ `COMPLETED`: scrive una riga `[ATTENTION]` a inizio log per renderla evidente quando l'utente apre il file.

**NON** background bash con `until ... ; do sleep ...` (memoria `feedback_bash_background_notifications.md`).

Setup cron + script è task del plan di implementazione, non di questa spec di design.

## 6. Output destinations & storage

| Output | Path | Gitignore? | Backup? |
|---|---|---|---|
| ARCHS4 H5 source | `analysis/input/archs4-human-gene-v2.X.h5` | YES (~50-100 GB) | DGX local solamente |
| Stage1 JSONL input | `analysis/input/archs4-human-stage1-input.jsonl` | YES | regenerabile da ETL |
| Stage1 predictions | `analysis/p4-output/<TS>-p4-beta-stage1/predictions.jsonl` | YES | DGX → rsync a laptop |
| Stage2 input chunks | `analysis/input/archs4-human-stage2-input/cs50_*.json` | YES | regenerabile |
| Stage2 predictions | `analysis/p4-output/<TS>-p4-beta-stage2/predictions.jsonl` | YES | DGX → rsync a laptop |
| Provenance source | `analysis/p4-output/p4-beta-archs4-source.json` | NO (committed) | git |
| Provenance ETL skipped | `analysis/p4-output/p4-beta-etl-skipped.tsv` | YES (può essere grande) | rsync |
| Coverage report | `analysis/p4-beta-coverage.html` + `.rds` | YES per HTML, NO per RDS sintetico | git per RDS sintetico se < 5 MB |
| Source code transform | `R/etl-archs4.R` + `analysis/p4-beta-*.R` | NO | git |

## 7. Cost/time projection

| Stadio | Wall time stimato | Costo monetario | Costo GPU-time |
|---|---|---|---|
| ARCHS4 H5 download (`human_gene_v2.5.h5` 45 GB) | 1-3 h (dipende da banda) | $0 | 0 |
| ETL H5 → JSONL | 1-2 h | $0 | 0 (CPU-only su DGX node) |
| Pre-eval mini-gold format B (gate #1) | ~1 h | $0 | 4 GPU × 1 h = 4 GPU-h |
| Smoke test 1000 sample (gate #2) | ~1.5 h | $0 | 4 GPU × 1.5 h = 6 GPU-h |
| Stage1 full run (500k sample) | ~35 h | $0 | 4 GPU × 35 h = 140 GPU-h |
| Aggregation stage1→stage2 | < 30 min | $0 | 0 (CPU) |
| Stage2 full run (~10k studi) | ~50-70 h | $0 | 4 GPU × 60 h = 240 GPU-h |
| Coverage report | < 30 min | $0 | 0 |
| **Totale** | **~92-115 h wall (~4-5 gg)** | **$0** | **~390 GPU-h** |

Costo monetario zero perché DGX self-hosted con vLLM (ADR-0007). GPU-time va contabilizzato per progetto UniPD HPC ma non finanziario.

## 8. Risks & mitigations

| Rischio | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Format B re-eval mini-gold scende < 95% | media | alto (blocca full run) | Pre-eval è gating step; investigazione separata in nuova sessione |
| Overflow tier_XL stage2 con format B | bassa | medio (richiede cs45/cs40 scaling) | Pre-eval mini-gold cattura il segnale; downscale data-driven |
| Node DGX failure mid-job 70h+ | bassa | medio | Cache LLM idempotent, re-submit recovery procedure |
| Network glitch I/O hang (rare edge) | bassa | basso | Cron monitor cattura entro 2h; kill+retry |
| ARCHS4 dump version cambia mid-run | molto bassa | basso | Provenance record fissa SHA256, dump committato |
| Sample con `series_id` multipli (es. GSEx,GSEy) | media | basso | Stage2 aggregation per `series_id` primario; secondary tracked ma non riprocessato |
| Library strategy mislabel (sample scRNA dichiarato `RNA-Seq`) | media | basso | Stage1/2 catturano via `ambiguity_flags`; coverage report mostra outlier |

## 9. Out of scope (deferred)

- **P4 γ — mouse + ortholog mapping.** Stesso pattern di P4 β su `mouse_gene_v2.X.h5`. Ortholog pooling mouse→human via HGNC homologene / MGI: ADR separato post P4 β.
- **Stadio 3 — clustering cross-studio.** P5 dopo P4 β chiusa.
- **Stadio 4+5 — DE + meta-analisi REM.** P5 / P6.
- **Rebrand pacchetto** (ADR-0003) — pre-publish.
- **Migrazione ellmer** — ADR separato post-α.

## 10. Open questions — risolte 2026-05-11

1. ~~Versione ARCHS4 H5~~ → **`human_gene_v2.5.h5` v2.5** (45 GB, 2024-08-24). Sez. 4.2.
2. ~~`series_id` multipli~~ → **Primary only (opzione A)**, con tracking dei secondary in log per coverage report. Sez. 4.2.
3. ~~Telegram bot~~ → **No notifiche push, monitoring via app Claude**. Cron genera log strutturato leggibile on-demand. Sez. 5.2.
4. ~~Smoke test 1000 sample~~ → **Aggiunto come gate #2 dopo mini-gold gate #1**. Sez. 4.3-bis.
