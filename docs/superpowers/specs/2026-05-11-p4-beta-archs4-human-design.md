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
ARCHS4 human_gene_v2.X.h5  (~50-100 GB)
    │
    ▼  [4.2 ETL H5 → JSONL]
analysis/input/archs4-human-stage1-input.jsonl  (~500k record)
    │
    ▼  [4.4 Stage1 classification, single SLURM job, vLLM v0.20.2-cu129]
analysis/p4-output/<TS>-p4-beta-stage1/predictions.jsonl  (~500k record)
    │
    ▼  [4.5 Stage1 → stage2 aggregation per series_id, cs50 chunks]
analysis/input/archs4-human-stage2-input/  (chunked JSON files)
    │
    ▼  [4.6 Stage2 classification, single SLURM job, vLLM v0.20.2-cu129]
analysis/p4-output/<TS>-p4-beta-stage2/predictions.jsonl  (~10k studi × records)
    │
    ▼  [4.7 Aggregation + coverage report]
analysis/p4-output/p4-beta-coverage.rds  +  p4-beta-coverage.html
```

### 4.2 ETL HDF5 → JSONL transform

**Source.** ARCHS4 human dump dalla pagina download ufficiale (`https://maayanlab.cloud/archs4/download.html`). Versione: ultima stabile al momento del download (probabile `v2.6` o successiva). Versione esatta + SHA256 → committati in `analysis/p4-output/p4-beta-archs4-source.json` come provenance record.

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

### 4.3 Pre-flight: mini-gold re-eval format B (GATING)

**Necessario prima di qualunque full-run stage1.** Format B è off-distribution rispetto al gold P3.5-A su cui Mistral-Small-3.2 ha registrato 96.7% mini-gold.

**Procedura:**

1. Costruire `minigold-v5-format-B.csv`: stesse 100 sample di `p35c-minigold-reviewed-v5.csv`, ma colonna `string` ricostruita con format B usando `title + source_name + characteristics`. Per ottenere `title` e `source_name` originali, lookup via `geo_accession` su GEO (script ad-hoc, una tantum, cacheabile).
2. Sottomettere job DGX stage1+stage2 sul mini-gold format B con config **identica al full-run pianificato**: vLLM v0.20.2-cu129, structured outputs, temperature 0.0 / repetition 1.1, cs50, tier max_tokens, max_num_seqs=6, microbatch=50.
3. Calcolare metriche: schema valid rate (target ≥ 99.5%), mini-gold accuracy (target ≥ 96.7%, threshold blocco < 95%), n_overflow per tier (target = 0 per tier_XL).

**Gate decision:**
- PASS (≥ 96.7% acc, 0 overflow): full-run stage1 partito.
- PASS borderline (95-96.7% acc): nuova sessione conversazionale per decidere se accettare il leggero drop o iterare prompt stage1 con esempi B.
- FAIL accuracy < 95%: investigare causa (off-distribution stage1 vs degradazione stage2). Format B potrebbe richiedere prompt tuning.
- FAIL overflow stage2 osservato: scaling cs50 → cs45 → cs40 in step, MAI cs25 senza altra evidence.

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

Da setupare sul laptop dell'utente con `crontab -e`:

```cron
# Ogni 2h, ssh DGX per check job + tail logs
0 */2 * * * /home/user/simulomicsr/scripts/p4-beta-monitor.sh >> /home/user/simulomicsr/analysis/p4-beta-monitor.log 2>&1
```

Lo script `scripts/p4-beta-monitor.sh` fa:
1. `ssh dgx 'squeue -u u0044'` → lista job attivi.
2. Per ogni job attivo, `ssh dgx 'tail -50 ~/p4-beta/slurm-*.out'`.
3. Se `0` job attivi e last job NON è `COMPLETED`: invia notifica (Telegram via bot configurato? email locale? `notify-send`?).
4. Append timestamp + status sintetico a log.

**NON** background bash con `until ... ; do sleep ...` (memoria utente `feedback_bash_background_notifications.md`).

Setup cron è task del plan di implementazione, non di questa spec.

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
| ETL H5 → JSONL | 1-2 h | $0 | 0 (CPU-only su DGX node) |
| Pre-eval mini-gold format B | ~1 h | $0 | 4 GPU × 1 h = 4 GPU-h |
| Stage1 full run (500k sample) | ~35 h | $0 | 4 GPU × 35 h = 140 GPU-h |
| Aggregation stage1→stage2 | < 30 min | $0 | 0 (CPU) |
| Stage2 full run (~10k studi) | ~50-70 h | $0 | 4 GPU × 60 h = 240 GPU-h |
| Coverage report | < 30 min | $0 | 0 |
| **Totale** | **~90-110 h wall (~4-5 gg)** | **$0** | **~385 GPU-h** |

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
- **Smoke test su 1000 sample casuali** — può essere utile come ultimo sanity check pre-full-run dopo che mini-gold passa il gate. Decisione: lo includo nel plan di implementazione, non in questa spec di design (decisione tattica, non architetturale).
- **Rebrand pacchetto** (ADR-0003) — pre-publish.
- **Migrazione ellmer** — ADR separato post-α.

## 10. Open questions per la review

1. Versione ARCHS4 H5 specifica: ultima stabile al momento del download, oppure versione precisa congelata in advance? (Default: ultima al download, registrata in provenance.)
2. `series_id` multipli (es. `GSE145668,GSE145669`): aggregare per primario (primo elemento), oppure replicare il sample in stage2 una volta per series_id? (Default proposta: primario per evitare duplicati nel pooling Stadio 3.)
3. Telegram bot per notifiche cron: utente vuole usare il bot configurato (vedo skill `telegram:configure` disponibile) o sufficiente log + check manuale? (Default proposta: log only, controllo manuale ogni 2-4h è già il flow utente.)
4. Smoke test su 1000 sample casuali pre-full-run: utile o eccessivo dato che mini-gold format B copre già il gating? (Default proposta: skip, mini-gold sufficient.)
