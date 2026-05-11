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
| `series_id` multipli | **D (revised) — SRP-driven hybrid + lower-accession fallback** | Pattern strutturale Entrez: GSE con SRP linked = sub-method (la vera data); GSE senza SRP = parent aggregator. Empiricamente verificato su gold (Exp A+C+D+D2): 99.3% sample ambiguous risolti via SRP signal, 0 sample persi. |
| cs50 vs cs25 | cs50 confermato, scaling solo data-driven | ADR-0013 + nessuna evidence pre-empirica per cs45/cs40 |

## 4. Architettura

### 4.1 Pipeline complessiva

```
ARCHS4 human_gene_v2.5.h5  (45 GB)
    │
    ▼  [4.2a ETL H5 → JSONL raw]
analysis/input/archs4-human-stage1-input-raw.jsonl  (~500k record con series_id multipli)
    │
    ▼  [4.2b GATE #0 series-id-resolver (GEO Entrez API + cache, 3 test sub-gate)]
analysis/input/archs4-human-stage1-input.jsonl  (~500k record con series_id_resolved)
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

**Gestione `series_id` multipli.** In ARCHS4 il campo `series_id` può contenere più GSE separati da virgola (es. `"GSE145668,GSE145669"`), tipicamente per relazioni super-series ↔ sub-series in GEO, multi-paper publication, o resubmission.

**Quanto pesa il fenomeno (misurato sul gold-standard 130k, Exp A 2026-05-11):**
- 27.33% sample hanno multi-series (35.748 / 130.784)
- Dopo Entrez SuperSeries detection (regex `"^This SuperSeries is composed of"` sul summary): **90.6% clean** (1 SuperSeries scartata + 1 NotSuper preservata)
- **9.4% ambiguous**: entrambi i GSE classificati come NotSuper (3.353 sample). **Iper-concentrati in 23 pair distinti** (top 1 = 80% volume, top 3 = 90%).
- 0 sample con tutti SuperSeries (caso patologico).

**Esplorazione resolver-informed (Exp C+D)**: testati Claude Sonnet 4.6 e GPT-5.5 sui 30 ambiguous sample con prompt arricchito (SRP, pdat, Jaccard, accession order). Entrambi convergono al 96.7% sulla rule deterministica `min(accession_numerico)`. Il LLM aggiunge zero info marginale.

**Insight strutturale (Exp D2)**: il pattern Entrez ESummary rivela un signal causale forte. Higher-accession GSE = parent aggregator (no SRP linkato, no method bracket nel title come `[scRNAseq]`, `[RNA-Seq]`); lower-accession GSE = sub-method specifico (SRP linkato a SRA project). Sono **SuperSeries non riconosciute dal pattern regex** perché il summary del parent è generic.

**Decisione: D (revised) — SRP-driven hybrid + lower-accession fallback.**

```
Per ogni pair ambiguous (entrambi classificati NotSuper):
  1. Solo GSE_a ha SRP linked → scegli GSE_a (è il sub-method, parent scartato)
  2. Solo GSE_b ha SRP linked → scegli GSE_b
  3. Entrambi hanno SRP → "truly ambiguous" (2 sub-methods distinti):
     fallback → scegli min(accession_numerico), log in ambiguous-tiebreak.tsv
  4. Nessuno ha SRP → pattern anomalo:
     fallback → scegli min(accession_numerico), log in no-srp-fallback.tsv
```

**Esito su gold (Exp D2, 23 pair, 3353 sample)**:
- 21 pair (3329 sample, **99.3% del volume**) risolti via signal SRP causale
- 1 pair (18 sample, 0.5%) truly ambiguous → tiebreak lower-acc
- 1 pair (6 sample, 0.2%) no-SRP pattern anomalo → tiebreak lower-acc
- **0 sample persi**, 0% drop

**Quanto contribuisce Op D vs pure-rule lower-accession**: agreement 82.6% su 23 pair. I 4 pair di disagreement sono casi dove la rule pura sceglierebbe il PARENT (no SRP) invece del sub-method (SRP linkato) → 27 sample (0.8% degli ambiguous, 0.02% del totale ARCHS4) sarebbero stati mis-classificati con la rule pura. Op D è strettamente migliore.

**Implementazione (modulo dedicato `R/etl-series-resolver.R`):**

1. **Step 1 — Inventory.** Estrai l'unione di tutti i GSE che appaiono in qualunque `series_id` (sia primary che secondary). Atteso ~6.3k GSE unici.
2. **Step 2 — GEO Entrez lookup.** Per ogni GSE, chiamata `esummary` a NCBI Entrez sul database `gds`:
   ```
   https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=gds&id=<GSE_uid>
   ```
   Estrai 2 campi chiave per ogni GSE:
   - `summary`: pattern detection SuperSeries via regex `"^This SuperSeries is composed of"`.
   - `extrelations` filtered by `relationtype == "SRA"`: estrai `targetobject` come **SRP ID**. Presence indica GSE = sub-method specifico; absence indica GSE = parent aggregator.

   **Rate-limit + API key:** Entrez senza API key permette 3 req/s; con API key 10 req/s. **`NCBI_API_KEY` in `.Renviron`** (utente lo fornisce). Stima tempo: ~10 min con key per 6.3k GSE (rate effettivo osservato ~80/min in Exp A 2026-05-11).

3. **Step 3 — Cache on-disk.** `tools::R_user_dir("simulomicsr", "cache")/geo-series-resolver-cache.rds`. Format: `list(gse_a = list(uid, srp, is_super_series, summary, pdat, n_samples, title), ...)`. Riusabile cross-session.

4. **Step 4 — Resolver function.** `resolve_series_id(series_id_multipli)` — output sempre un singolo GSE valido (no drop).
   - **Caso 1 GSE in input**: tienilo invariato.
   - **Caso >1 GSE**:
     - Fase A — scarta GSE flagati `is_super_series == TRUE` (pattern regex).
     - Fase B — sui residui, applica decision tree:
       1. Rimane 1 GSE → usalo (caso clean post-SuperSeries scarto, ~90% volume).
       2. Rimangono ≥2 GSE con `srp_a == NA, srp_b != NA` (o viceversa) → scegli quello con SRP (è il sub-method).
       3. Rimangono ≥2 GSE entrambi con SRP linked (truly-ambiguous: 2 sub-methods distinti dello stesso experiment) → fallback `min(accession_numerico)`, log in `series-id-resolver-tiebreak.tsv`.
       4. Rimangono ≥2 GSE entrambi senza SRP (pattern anomalo) → fallback `min(accession_numerico)`, log in `series-id-resolver-fallback.tsv`.

**Razionale (validato empiricamente, Exp D2 2026-05-11):**

| Branch | Cosa esprime | Frequenza misurata gold | Sample affetti |
|---|---|---|---|
| Fase A: SuperSeries detected via regex | Pattern GEO esplicito | ~90% multi-series | 32.391 / 35.748 |
| Fase B.1: 1 residuo NotSuper | Caso atteso post-scarto | 90.6% | 32.391 sample |
| Fase B.2: SRP-driven | Parent aggregator senza SRP scartato | 99.3% degli ambiguous | 3.329 sample |
| Fase B.3: 2 SRP tiebreak | 2 sub-methods veri | 0.5% degli ambiguous | 18 sample |
| Fase B.4: 0 SRP fallback | Anomalia (entrambi parent-like) | 0.2% degli ambiguous | 6 sample |

**0 sample persi** per design. I 24 sample in tiebreak/fallback (0.7% degli ambiguous, 0.02% del totale ARCHS4) hanno assegnazione documentata in log file, riproducibile, e ammettono review post-hoc se serve.

**Test obbligatori prima del deploy (gate pre-ETL):**

1. **Unit tests** in `tests/testthat/test-etl-series-resolver.R`:
   - Caso 1 GSE → input echoed.
   - Caso 1 SuperSeries (regex match) + 1 NotSuper → NotSuper scelto.
   - Caso 2 NotSuper: SRP_a presente, SRP_b assente → GSE_a scelto (SRP-driven).
   - Caso 2 NotSuper: SRP_a assente, SRP_b presente → GSE_b scelto (SRP-driven, override lower-accession).
   - Caso 2 NotSuper: entrambi SRP → lower-acc tiebreak, logged in `tiebreak.tsv`.
   - Caso 2 NotSuper: entrambi senza SRP → lower-acc fallback, logged in `fallback.tsv`.
   - Caso 3 GSE = 2 SuperSeries + 1 NotSuper → NotSuper scelto.
   - Cache hit / cache miss correct behavior.
   - Rate-limit respect (mock).
   - API key presence detected → 10 req/s; assente → 3 req/s.

2. **Replication test su gold-standard (Exp D2 reference)**: esegui resolver sui 35.748 multi-series del gold (`relevant_sample_classified.xlsx`). Verifica match esatto con i risultati pre-computati in `analysis/scratch/exp-d2-23pair-classification.csv`:
   - 23 pair ambiguous esatti
   - 21 risolti SRP-driven (3329 sample)
   - 1 truly-ambiguous tiebreak (18 sample) — pair GSE131620|GSE149886
   - 1 no-SRP fallback (6 sample) — pair GSE202833|GSE203247
   - 4 pair dove SRP override la lower-accession (GSE109440 family + GSE121668 family)

3. **Smoke run** sull'output ETL ARCHS4 v2.5 raw (~500k sample, ~12.8k ambiguous estrapolati):
   - % sample risolti via SRP-driven (atteso > 99%)
   - % truly-ambiguous tiebreak (atteso < 1%)
   - % no-SRP fallback (atteso < 0.5%)
   - Numero studi recuperati post-resolver (atteso ~400 ± 100 nuovi GSE sub-method)

**Gate decision** (questi 3 test passano prima di lanciare il full ETL):
- 100% unit test pass
- 100% replication esatta su gold (deterministic resolver, no model variance)
- < 2% non-SRP-resolved (tiebreak + fallback) nello smoke

Se il gate FAIL sul `< 2%`: escalation a sessione conversazionale. Numeri reali ARCHS4 potrebbero divergere dal gold per pattern di submission più recenti.

Tracking: ETL log per ogni multi-series sample salva `geo_accession, series_id_input, series_id_resolved, resolver_path (clean/ambiguous/fallback)` in `analysis/p4-output/p4-beta-etl-multiseries.tsv` per audit completo nel coverage report.

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
| ETL H5 → JSONL raw | 1-2 h | $0 | 0 (CPU-only su DGX node) |
| **Series-id-resolver dev + test** (gate #0) | ~3-4 h dev + 1h test | $0 | 0 |
| Series-id-resolver execution (Entrez API ~6.3k GSE) | ~10-35 min (key vs no-key) | $0 | 0 |
| Pre-eval mini-gold format B (gate #1) | ~1 h | $0 | 4 GPU × 1 h = 4 GPU-h |
| Smoke test 1000 sample (gate #2) | ~1.5 h | $0 | 4 GPU × 1.5 h = 6 GPU-h |
| Stage1 full run (500k sample) | ~35 h | $0 | 4 GPU × 35 h = 140 GPU-h |
| Aggregation stage1→stage2 | < 30 min | $0 | 0 (CPU) |
| Stage2 full run (~10k studi recovered con resolver) | ~55-75 h | $0 | 4 GPU × 65 h = 260 GPU-h |
| Coverage report | < 30 min | $0 | 0 |
| **Totale** | **~98-125 h wall (~4-5.5 gg) + 4-5h dev resolver** | **$0** | **~410 GPU-h** |

Nota: stage2 wall time aumentato leggermente (~+5h) perché ~793 studi recuperati con resolver = +20% studies da classificare in stage2 vs A.

Costo monetario zero perché DGX self-hosted con vLLM (ADR-0007). GPU-time va contabilizzato per progetto UniPD HPC ma non finanziario.

## 8. Risks & mitigations

| Rischio | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Format B re-eval mini-gold scende < 95% | media | alto (blocca full run) | Pre-eval è gating step; investigazione separata in nuova sessione |
| Overflow tier_XL stage2 con format B | bassa | medio (richiede cs45/cs40 scaling) | Pre-eval mini-gold cattura il segnale; downscale data-driven |
| Node DGX failure mid-job 70h+ | bassa | medio | Cache LLM idempotent, re-submit recovery procedure |
| Network glitch I/O hang (rare edge) | bassa | basso | Cron monitor cattura entro 2h; kill+retry |
| ARCHS4 dump version cambia mid-run | molto bassa | basso | Provenance record fissa SHA256, dump committato |
| Series-id-resolver fallisce su Entrez API down | bassa | medio | Cache on-disk persistente. Se Entrez down mid-resolution, retry exponential backoff. Worst-case: usa cache parziale + tag missing come `unresolved` per ETL log. |
| Series-id-resolver classifica male sub vs super | bassa | medio | Gate #0 validation 20 sample manual + smoke 35.748 sample. Se accuracy < 95% su validation, halt e investiga. |
| Library strategy mislabel (sample scRNA dichiarato `RNA-Seq`) | media | basso | Stage1/2 catturano via `ambiguity_flags`; coverage report mostra outlier |

## 9. Out of scope (deferred)

- **P4 γ — mouse + ortholog mapping.** Stesso pattern di P4 β su `mouse_gene_v2.X.h5`. Ortholog pooling mouse→human via HGNC homologene / MGI: ADR separato post P4 β.
- **Stadio 3 — clustering cross-studio.** P5 dopo P4 β chiusa.
- **Stadio 4+5 — DE + meta-analisi REM.** P5 / P6.
- **Rebrand pacchetto** (ADR-0003) — pre-publish.
- **Migrazione ellmer** — ADR separato post-α.

## 10. Open questions — risolte 2026-05-11

1. ~~Versione ARCHS4 H5~~ → **`human_gene_v2.5.h5` v2.5** (45 GB, 2024-08-24). Sez. 4.2.
2. ~~`series_id` multipli~~ → **Opzione D (revised): SRP-driven hybrid + lower-accession fallback**. Empiricamente validata su gold (Exp A+C+D+D2 2026-05-11): 99.3% sample ambiguous risolti via signal causale SRP (sub-method vs parent aggregator), 0 sample persi. Op2-rule pura (lower-accession) sbaglierebbe 27 sample (0.8% degli ambiguous). LLM commerciali (Claude Sonnet 4.6, GPT-5.5) testati ma convergono entrambi sulla rule deterministica → 0 valore marginale. Implementazione + 3 sub-test gating in sez. 4.2.
3. ~~Telegram bot~~ → **No notifiche push, monitoring via app Claude**. Cron genera log strutturato leggibile on-demand. Sez. 5.2.
4. ~~Smoke test 1000 sample~~ → **Aggiunto come gate #2 dopo mini-gold gate #1**. Sez. 4.3-bis.
