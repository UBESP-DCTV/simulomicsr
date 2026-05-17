# ADR-0008: vLLM SamplingParams default per stage1/stage2 P4

- **Status:** Accepted
- **Date:** 2026-05-07
- **Deciders:** Luca Vedovelli
- **Supersedes:** —
- **Superseded by:** —

## Context and Problem Statement

Il run α stage1 P4 (job 19730, 130,784 record) con `temperature=0.0` (greedy) e nessun altro parametro di sampling oltre `GuidedDecodingParams(json=schema)` ha prodotto **5,805 errori (4.44%)**, con 99.95% di questi che NON sono violazioni di contenuto ma **degenerate generation pathology**: il modello produce JSON parziale corretto fino al boundary di un campo `["string","null"]`, poi entra in loop generando un fiume di tab/null padding (whitespace flood) fino a saturare `max_tokens`.

L'investigation 2026-05-07 ha confermato:

1. **Il problema non e' contenutistico**: 0/5,805 errori parsano come JSON validi off-schema. Sono tutti truncation per token budget esaurito da padding.
2. **Pattern strutturale**: 53.3% degli errori cluster in 73 series con >50% fail rate (GSE180954 da sola = 1320 errori, 36% del totale). Tutti i fail troncano nello stesso punto dello schema (`cell_line_cellosaurus_candidate` post `cell_type_or_line_raw`).
3. **63.2% dei FAIL hanno duplicato OK byte-identical** in altre repliche dello stesso studio → conferma forte di **non-determinismo fp16/bf16 nel continuous batching di vLLM**: stesso prompt produce output diverso a seconda di cosa c'e' in batch insieme (fp non-associativity, KV cache state).

Serve scegliere il default di `SamplingParams` per i prossimi run α stage1 + stage2 + run β massivi su ARCHS4. Vincoli:

- **Riproducibilita' bit-perfect** desiderabile (dataset scientifico).
- **Recovery >95%** desiderabile (target plan).
- **Zero drift contenutistico** non-negoziabile per task di extraction strict.

## Decision Drivers

- **Riproducibilita' scientifica**: il pacchetto produce dati per pubblicazione; ogni elemento di stocasticita' e' un costo metodologico.
- **Schema strict + content extraction**: il task non richiede creativity. Un sampling temp non-zero introduce variabilita' su valori (es. `perturbations[0].kind`, `disease_state.status`, dosi numeriche) che sono usati downstream per gruppi treatment/control nella meta-analisi.
- **Repliche biologiche**: in RNAseq i replicati sono identificati da metadati identici. Perdere repliche per non-determinismo distrugge potenza statistica.
- **Cost zero**: ogni iterazione su 130k record e' ~1h 18min su 4 H100 = compute interno gratis. Possiamo provare matrici larghe.

## Considered Options

1. **Status quo `temperature=0.0` greedy**: deterministico ma soffre il loop whitespace.
2. **`temperature=0.1` greedy-rotto**: 0.1 spezza i tie ma resta vicino al greedy. Recovery testato sui 5805 fail = 37%, insufficiente.
3. **`temperature=0.0 + repetition_penalty=1.1`**: greedy puro + penalty contro sequenze ripetute. Recovery testato sui 1343 hard cases = 84.3%, full determinismo.
4. **`temperature=0.2-0.4 + repetition_penalty=1.1`**: hybrid sampling + penalty. Recovery 85-86%, ma concordance contenutistica vs greedy puro crolla a 92-87% per campi critici.
5. **Modificare lo schema** (rimuovere `null` da campi `["string","null"]` e usare sentinel "unknown"): fix invasivo, downstream-breaking, non testato.
6. **Custom `stop_token_ids` su pattern di whitespace**: difficilmente preciso senza interrompere JSON validi con whitespace legittimo.

## Decision Outcome

Scelta: **Opzione 3 — `temperature=0.0 + repetition_penalty=1.1`**.

Motivazione: rep_pen 1.1 e' IL fix definitivo dimostrato dall'ablation 2026-05-07: 0% → 84.3% recovery a parita' di temperatura. La temperatura ha contributo MARGINALE (+1.8 pp da 0.0 a 0.4) ma porta drift contenutistico inaccettabile per il task (concordance pert.kind 87% a temp 0.4 = 13% dei record recuperati avrebbe perturbation classification diversa). Il greedy puro + rep_pen e' il punto ottimo: zero drift dal default originale, recovery sostanziale, riproducibilita' bit-perfect modulo non-determinismo bf16 inerente di vLLM.

### Consequences

- **Positive:**
  - Recovery dei "facili" hard cases (84% degli unique-fail) senza alcun drift contenutistico.
  - Riproducibilita' del pacchetto migliorata (greedy resta greedy, ma piu' robusto al collasso whitespace).
  - Default sicuro per run β massivi su ARCHS4 (700k sample) — non vogliamo scoprire drift dopo aver bruciato 10h di compute.
  - Soluzione applicata anche a stage2 by symmetry (stage2 ha schemi piu' complessi, anche piu' a rischio di degenerate).
- **Negative:**
  - 211 record (0.16%) restano irrecuperabili con rep_pen 1.1 alone — investigation successiva ha rivelato due failure mode separabili (vedi addendum sotto).
  - Marginale CPU/latency overhead di rep_pen tracking nel decoder vLLM (trascurabile a fronte del gain).
- **Neutral:**
  - I run α retry e ablation sono rimasti sul cluster per debugging (~250 MB total nei `runs/<run_id>/`). Cleanup quando si chiude P4.

## Addendum 2026-05-07 P.M. — Investigation 211 residual fails

Phase 1 ha caratterizzato i 211 residual fails (post temp 0.0 + rep_pen 1.1)
in due failure mode binariamente separabili:

- **Mode B (205, 97%)** — *legitimate truncation*. `raw_output` median 3231 char
  vs 1748 char per OK con stesso config (zero distribution overlap). Input
  cluster su 43 series con multi-perturbazione (es. "BMP4, VEGF, SCF,
  ACTIVIN A, FGF2, CHIR99012") che producono JSON ~1000 token, oltre
  `max_tokens=1024`. NON e' una pathology — il modello sta scrivendo JSON
  corretto e finisce semplicemente il budget.
- **Mode A (6, 3%)** — *decoder loop*. Tutti 6 raw_output stallano
  *esattamente* dopo `"label": "..."` dentro il primo
  `engineered_modifications[].`. Schema definisce `variant: ["object","null"]`
  con required nested `{label, description, is_wildtype}` se non null.
  Guided decoder collassa al field-boundary scegliendo tra `null`/`{`/`}`,
  in tab flood. rep_pen 1.1 insufficiente.

### Single-variable hypothesis tests (5 min DGX totale)

- **Job 19748**: `max_tokens 1024 → 2048` (single change vs default) sui 211 →
  **205/205 Mode B recuperati (100%)**, 6 Mode A residui invariati.
- **Job 19749**: `repetition_penalty 1.1 → 1.2` (single change) sui 6 Mode A →
  **6/6 recuperati (100%)** con content quality verificata
  (`engineered_modifications` corretti, perturbazioni coerenti, confidence
  0.8-0.9, zero garbage).

### Default policy aggiornata

- `inst/extdata/p4-defaults.yml`: stage1 `max_tokens 1024 → 2048` (nuovo
  default). Costo trascurabile: median raw_output OK ~500 token vs cap 2048.
  Fix architettonico per multi-perturbazione (downstream-critical: studi
  con cocktail terapeutici/fattori di differenziazione sono comuni).
- `repetition_penalty: 1.1` resta default. **`1.2` documentato nel commento
  yaml come escape hatch** per casi residual su altri schema con boundary
  loop simili — NON default per rischio drift contenutistico sui 130k
  normali (non testato a tappeto, solo sui 6 specifici dove ha funzionato).
- Stage2 `max_tokens=4096` rimane invariato (gia' generoso per output
  multi-comparison study-level).

### Risultato finale α stage1

**130,784 / 130,784 = 100.00000% valid**, 0 residui irrecuperabili. Tracking
provenienza in colonna `rescue_source`: `replicate_<GSM>` (2308 propagati) /
`uniqfail_temp00_rep11` (1132 rep_pen 1.1) / `rep11_maxtok2048` (205 Mode B
fix) / `rep12_maxtok2048` (6 Mode A fix) / NA (124,979 originali).

## Addendum 2026-05-17 — β rescue cascade (H1+H3 retry strategies)

Il fullrun β stage1 (888.821 sample ARCHS4 v2.5 human) e stage2 (39.205
record cs50) ha prodotto **1.571 stage1 fails** (0.18%) + **43 stage2
fails** (0.11%). Phase 1 systematic classification dei fails per failure
mode ha rivelato tre famiglie distinguibili (analoghe a α post-investigation
Mode A/B + nuovo modo C):

- **Mode A whitespace** (660 fails) — decoder loop su field-boundary,
  rep_pen 1.1 insufficiente. Analogo Mode A α.
- **Mode B legit truncation** (147 fails) — JSON parziale corretto, max_tokens
  2048 stage1 esaurito. Analogo Mode B α (ma su record stage1 con metadata
  più ricchi della distribuzione α).
- **OTHER degeneration** (15 fails) — pattern misti (es. tag formatting,
  rare token loops).
- **ETL_LEAK_NONHUMAN** (749 fails) — degenerazione metadata mouse-specific
  che causa stallo decoder; tutti concentrati nei 72 GSE
  mouse-mislabeled-as-human in ARCHS4/GEO upstream (signal indiretto della
  discovery H2, drop GSE-level cleanup — vedi
  `docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md`).

Per i 43 stage2 fails: tutti cs50 stalls residuati post-pipeline
(ADR-0009 safe-mode disabilitato a favore di max_num_seqs=6, microbatch=50
post-PR #40946) concentrati su tier XL (max_tokens=32768).

### Strategia rescue H1 — stage1 LLM-failure cascade

Per i 822 fails non-ETL (Mode A + Mode B + OTHER), single-shot rescue config:

- `repetition_penalty = 1.2` (vs default 1.1)
- `max_tokens = 4096` (vs default stage1 2048)
- `max_model_len = 8192` (vs default 4096)

**Razionale**: la combinazione triplo-override estende sia il budget token
(Mode B fix) sia il rep_pen (Mode A fix) sia il context per record verbose,
senza richiedere multi-round retry. Smoke20 → **20/20 = 100% recovery**.
Full retry 822 → **802/822 = 97.6% recovery** (20 residual irrecuperabili,
0.0023% del master cleaned).

**Decisione**: H1 config NON propagato come default `p4-defaults.yml`
(memoria `feedback_pipeline_config_uniformity` → uniformità config su tutti
gli stadi). È override puntuale come per α Mode A/B rescue rounds.

### Strategia rescue H3 — stage2 stall via cs25 re-split

Per i 43 stage2 cs50 fails (tutti cs50 tier XL stuck):

- Re-split cs50 → **cs25** (chunk_size 50→25, 85 cs25 chunks da 43 cs50)
- `tiered_max_tokens = TRUE` con tier XL = **32768** (default vLLM v0.20.2)
- Sampling invariato (`temperature=0.0, repetition_penalty=1.1`)
- max_model_len invariato (32k default tier XL)

**Razionale**: dimezzamento chunk_size riduce KV cache pressure per
request, evitando scheduler HoL su request grandi (Issue #39734 residual
edge case). Smoke5 → **5/5 = 100% recovery**. Full retry 85 cs25 →
**85/85 chunks valid → 43/43 original keys fully rescued, 0 residual,
stage2 validity 100.000%**.

### Risultato finale β post-rescue cascade

- **Stage1 LLM-only validity**: 99.998% (878.398 / 878.418 LLM_attempted,
  escludendo 749 ETL leak ridroppati nei 72 GSE H2 cleanup — vedi
  `feedback_etl_leak_not_llm_failure.md` per formula corretta).
- **Stage2 schema validity**: **100.000%** (39.247 valid, 0 residual).
- `rescue_source` annotation: `h1_rep12_maxtok4096` (802 record stage1),
  `h3_cs25_resplit` (85 cs25 chunks stage2), NA per gli originali.

## Pros and Cons of the Options

### Opzione 3 (vincente)
- **Pro:** elimina la pathology al 84%, zero drift, riproducibilita' massima.
- **Contro:** 16% di hard cases ancora fail (ma su 1343 = 211 / 130,784 = 0.16%, accettabile).

### Opzione 4 (temp > 0 + rep_pen)
- **Pro:** recovery marginalmente piu' alto (86.1% a temp 0.4 vs 84.3% a temp 0.0).
- **Contro:** drift contenutistico significativo: concordance pert.kind 87.4%, disease.status 91.2%. Su 130k sample farebbe variabilita' su ~5% del dataset, distorcendo le fasce di confidence dei downstream gruppi.

### Opzione 5 (schema modification)
- **Pro:** fix definitivo lato schema (nessuna pathologia possibile).
- **Contro:** invasiva, breaking per il post-processing R-side che si aspetta `null` per missing data, deve coordinare con `parse_stage1_response()`. Non testata.

## Links

- CLAUDE.md sezione "Ablation P4 stage1 sampling params (2026-05-07, jobs 19737-19740)" — matrice ablation completa.
- CLAUDE.md sezione "Propagation rescue strategy" — strategia rescue per repliche biologiche.
- CLAUDE.md sezione "Riassunto recovery completo α stage1" — tabella finale 99.84% valid.
- `inst/extdata/p4-defaults.yml` — default applicato.
- `inst/dgx/python/run_p4_vllm.py::worker_main()` — supporto opzionale `repetition_penalty`/`top_p`/`min_p`.
- `R/dgx-bundle.R::dgx_p4_build_bundle()` — propagazione yaml → generation.json.
- ADR-0007 (DGX self-host vLLM) — contesto P4 self-hosting.
- Output finale: `analysis/p4-output/alpha-stage1-final.rds`.
