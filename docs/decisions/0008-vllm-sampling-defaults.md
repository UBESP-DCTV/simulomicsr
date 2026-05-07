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
  - 211 record (0.16%) restano irrecuperabili anche con rep_pen 1.1 + temp 0.0-0.4 — irrecuperabili da CIASCUNO dei 5 setting testati. Questi vanno investigati separatamente (next session).
  - Marginale CPU/latency overhead di rep_pen tracking nel decoder vLLM (trascurabile a fronte del gain).
- **Neutral:**
  - I run α retry e ablation sono rimasti sul cluster per debugging (~250 MB total nei `runs/<run_id>/`). Cleanup quando si chiude P4.

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
