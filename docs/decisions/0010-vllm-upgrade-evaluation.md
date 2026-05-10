# ADR-0010: vLLM upgrade evaluation — gated decision verso v0.20.2

- **Status:** Proposed (validation pending)
- **Date:** 2026-05-10
- **Deciders:** Luca Vedovelli
- **Supersedes:** —
- **Superseded by:** —
- **Relates to:** ADR-0007 (DGX self-host), ADR-0008 (sampling defaults), ADR-0009 (safe-mode stage2), ADR-0011 (tier max_tokens)

## Context and Problem Statement

L'α P4 è chiusa il 2026-05-10 (tag `p4-dgx-complete` su `ab5e9ff`) con un'infrastruttura LLM funzionante ma carica di workaround. Il container in produzione è `vllm/vllm-openai:v0.10.0` (engine `0.10.1.dev1+gbcc0a3cbe`). Sopra a questa base abbiamo accumulato cinque mitigation:

1. **chunk_size=25** in `analysis/p4-stage2-build-input.R` (ADR-0009 Path C) — limita ogni record stage2 a ~14K token / ~50 KB per evitare la danger zone del bug scheduler.
2. **`max_num_seqs=1` + `microbatch=1`** safe-mode stage2 (ADR-0009) — elimina la concorrenza inter-request che triggera il deadlock. Costo: ~1.5–2× wall time per worker, sotto-utilizzo H100.
3. **`disable_guided_decoding=true`** (Task 22 investigation) — bypassa xgrammar che saturava `torch._dynamo cache_size_limit` in stage2 con shape variation. Output è free-JSON, schema validation post-hoc R-side.
4. **Markdown fence-strip + heuristic recovery** (`inst/dgx/python/run_p4_vllm.py::_strip_md_fences` + `_RX_MISSING_VALUE`) — pattern Mistral-3.2 che droppa `"value":` o wrappa output in fences.
5. **Tier-based max_tokens** (ADR-0011) — single-pass strategy con per-record budget S/M/L/XL.

Il risultato è schema validity 99.84% e binary accuracy mini-gold v5 93.3%, raggiunti con un pipeline 3-pass nel run α che la tier strategy ha poi compresso a single-pass. Funziona, ma il costo è strutturale: continuous batching disabilitato, schema validation post-hoc invece di parser-grade strict, complessità di mantenimento.

**Trigger condition.** Memory `project_vllm_upgrade_post_alpha.md` (2026-05-08) aveva differito ADR-0010 a post-α, con il vincolo "Issue #39734 non risolto upstream nemmeno in 0.19.x". Web research del 2026-05-10 ha aggiornato lo stato: **PR #40946 (fix per Issue #39734) è stato mergiato il 2026-04-27 ed è incluso in v0.20.0**. Latest stabile al 2026-05-10 = **v0.20.2** (release 2026-05-10 stesso). Questo è il momento per valutare l'upgrade da posizione informata: α chiusa, fix upstream disponibile, β massivo (700k sample ARCHS4) all'orizzonte.

**Tre potenziali wins concreti dell'upgrade:**

1. **W1 — `outlines` strict-schema backend funzionante.** vLLM 0.20 ha riorganizzato l'API guided decoding: il vecchio `guided_decoding_backend` request field è deprecato a favore di `--structured-outputs-config.backend` (default `auto` con xgrammar→outlines fallback). Se outlines funziona su Mistral-Small-3.2 senza saturare `torch._dynamo`, possiamo passare da 99.84% post-hoc a **100% parser-grade** schema validity, eliminando la heuristic recovery e il fence-strip post-processing.

2. **W2 — concurrency restored.** PR #40946 fixa la root cause del deadlock (mismatch tra startup KV cache pool sizing e runtime admission gating per Sliding Window Attention / Chunked Local Attention). Dopo upgrade, dovrebbe essere possibile alzare `max_num_seqs` da 1 a 4+ riportando in vita il continuous batching, con throughput stimato +200-300% su stage2 (4× sequenze parallele per worker × 4 worker = 16x teorico, in pratica saturazione HBM bandwidth → ~3-4× reale).

3. **W3 — perf bonus PagedAttention v2 / CUDA 13.0.** v0.20 introduce CUDA 13.0 come default + ottimizzazioni paged-attention. Throughput puro misurabile in smoke; non sappiamo l'entità ex-ante ma è la classica "free perf" cumulativa di 10 minor releases.

**Rischi dell'upgrade:**

- **API migration.** `guided_decoding_backend` request field rimosso in favore di `structured_outputs_config`. `inst/dgx/python/run_p4_vllm.py` deve cambiare. Anche `GuidedDecodingParams(json=schema)` può aver migration path.
- **Mistral-3.2 fragilità storica.** L'esperienza 0.6.4 → 0.10.0 ha richiesto fix multipli (`tokenizer_mode="mistral"` + `config_format="mistral"` + `load_format="mistral"` + `llm.chat()` invece di `apply_chat_template`). Anche jump 0.10.0 → 0.20.2 può rompere qualcosa, anche se il release v0.20.0 lista miglioramenti Mistral (PR #38150 Mistral Grammar factory, #39294 Mistral tool parser HF-tokenizer fix).
- **CUDA 13.0 default.** DGX UniPD H100 ha driver compatibili con CUDA 13.x ma il container deve essere validato (`nvidia-smi` dentro singularity).
- **Regression model output.** Stesso prompt + stesso seed + stesso modello, ma diverso engine vLLM, può produrre output leggermente diversi per cambi nel sampling/PagedAttention. Mini-gold v5 binary accuracy è il regression test.

## Decision Drivers

- **β massivo richiede pipeline efficiente.** ARCHS4 ~700k sample. Concurrency restored = ~3-4× throughput = settimane risparmiate di DGX time.
- **Schema validity 100% riduce pipeline complexity.** Heuristic recovery + fence-strip + post-hoc R-side validation diventano dead code. Manutenzione e onboarding ridotti.
- **Issue #39734 fix upstream.** Possiamo finalmente abbandonare safe-mode (ADR-0009) come strategia strutturale — passa a fallback contingency.
- **Regression su Mistral-3.2 è inaccettabile.** P3.5-D ha investito settimane per pickare questo modello (96% accuracy/costo); un'upgrade che lo rompe vale meno di zero.
- **Costo $0 (DGX self-host).** Throughput perf è apprezzabile ma non è la variabile dominante. La variabile dominante è "pipeline complexity" e "schema rigor".

## Considered Options

1. **A — Stay su `vllm/vllm-openai:v0.10.0`.** Status quo. Nessun rischio di regressione. Nessun guadagno. Pipeline resta caricata di 5 workaround in perpetuo.

2. **B — Upgrade pinned a `vllm/vllm-openai:v0.20.2`** (questa proposta). Latest stabile, include PR #40946, include miglioramenti Mistral, CUDA 13.0 default. Validation gated tramite smoke + mini-gold (vedi sotto).

3. **C — Multi-version A/B (es. v0.11 vs v0.15 vs v0.20.2).** Più rigoroso ma 3× costo build/SIF/smoke. Out of scope: il guadagno marginale di sapere "anche v0.15 funzionerebbe" non vale 6-10h aggiuntive di lavoro.

4. **D — Switch runtime (SGLang / TensorRT-LLM / llama.cpp).** ADR-0009 ha già scartato questa opzione come "1-3 giorni di lavoro con regression risk significativo". Out of scope per ADR-0010; merita ADR separato se mai riemerge.

## Decision Outcome (preliminary, gated)

Scelta **proposta**: **Opzione B — upgrade a `v0.20.2`**, condizionata al passaggio del gate validation sotto definito. Status `Proposed` finché smoke + mini-gold non sono completati. L'ADR sarà aggiornato a `Accepted` con outcome concreto (PASS → upgrade committato; FAIL → revert e stay 0.10.0) sullo stesso file, in stile gated già usato per ADR-0009 e ADR-0011.

Motivazione preliminare: la combinazione di (i) fix upstream Issue #39734, (ii) maturazione Mistral-3.2 support nel v0.20 line, (iii) latest stabile rilasciato oggi 2026-05-10, rende v0.20.2 il candidato ottimale per un single-target upgrade. Le opzioni A, C, D sono dominate.

### Validation Plan

Cinque fasi sequenziali. Ogni fase ha input concreto, comandi, metriche.

**Phase 0 — Changelog research (DONE 2026-05-10).**

Output baked in questo ADR: target `vllm/vllm-openai:v0.20.2`. Fonti citate in Links.

**Phase 1 — Build & deploy (~1h wall).**

- Edit `inst/dgx/Dockerfile`: `FROM vllm/vllm-openai:v0.20.2`.
- `docker build -t lucavd/simulomicsr-vllm:v0.20.2 . && docker push`.
- DGX: `singularity pull simulomicsr-vllm-v0.20.2.sif docker://lucavd/simulomicsr-vllm:v0.20.2`.
- API migration prep: aggiornare `inst/dgx/python/run_p4_vllm.py` per `structured_outputs_config` se `GuidedDecodingParams(json=schema)` è breaking.
- Smoke sanity 1-GPU: pattern `"ack":"ok","n":42` come job 19723 ADR-0007. PASS = modello carica + 1 generation OK.

**Phase 2 — Smoke 4-GPU mini500-cs25, 3 config A/B (~1.5h DGX + analysis).**

Input fisso: head 500 record di `data-raw/p4-alpha-stage2-cs25.jsonl` (uguale a T5h per comparabilità con baseline 0.10.0).

| Config | Descrizione | Cosa testa |
|---|---|---|
| 2a baseline | safe-mode `max_num_seqs=1` + microbatch=1 + free-gen + tier max_tokens (status quo 0.10.0 traslato su 0.20.2) | regression detection — l'upgrade da solo non deve peggiorare niente |
| 2b outlines | `structured_outputs_config.backend="outlines"` + safe-mode + tier max_tokens | win W1 — strict schema 100% |
| 2c concurrency | `max_num_seqs=4` + free-gen + tier max_tokens (NO `scheduler_reserve_full_isl=False` — PR #40946 fixa il bug a monte) | win W2 — deadlock-free concurrency post-fix |

Metriche per ogni config: `schema_validity_pct`, `wall_time_min`, `records_per_min_per_worker`, `stall_detected (Y/N)`, `worker_completion (4/4 vs <4)`.

**Phase 3 — Mini-gold v5 binary accuracy (~30 min DGX + analysis).**

Sulla config Phase 2 con highest schema validity senza regression deadlock: rerun `inst/extdata/p35c-minigold-reviewed-v5.csv` (100 sample, 16 GSE) → compute binary accuracy vs gold via `analysis/p4-stage2-eval.R` paths esistenti. Confronto vs baseline 93.3%.

**Phase 4 — Apply gate + update ADR (~15 min).**

Apply hierarchical gate (sotto). Update ADR: `Status: Accepted`, popolare `Decision Outcome` con numeri reali, popolare `Consequences` del ramo scelto. Se PASS → commit Dockerfile bump + tag `vllm-upgrade-v0.20.2`, poi procedere con Phase 5. Se FAIL → revert Dockerfile + documenta NOPE nell'ADR + memory update + STOP (Phase 5 non si applica).

**Phase 5 — Code simplification & cleanup (post-PASS, obbligatoria).**

Se il gate PASSA, l'upgrade NON è completato finché lo stack di workaround non è stato attivamente rimosso. I workaround sono debito tecnico che deve sparire, non zombie code. Ogni item è un commit atomico con test mini-gold v5 di non-regressione (≥ 93%).

Checklist (in ordine, ognuno è un commit separato con test):

1. **Safe-mode → standard concurrency** se W2 PASSA. `inst/extdata/p4-defaults.yml`: `max_num_seqs: 1 → 4`, rimuovere `microbatch: 1` (lasciare default vLLM). `R/dgx-bundle.R` propagation invariato. Test: smoke 4-GPU mini500-cs25 + mini-gold v5.
2. **`disable_guided_decoding` → outlines strict** se W1 PASSA. `inst/extdata/p4-defaults.yml`: `disable_guided_decoding: false` + `structured_outputs_config: {backend: outlines}`. `inst/dgx/python/run_p4_vllm.py`: ripristinare branch guided decoding usando `SamplingParams` con la nuova API. Test: smoke 4-GPU mini500-cs25 + verifica 100% schema validity.
3. **Rimuovi heuristic recovery Python** se W1 PASSA. `inst/dgx/python/run_p4_vllm.py`: rimuovere `_strip_md_fences()`, `_RX_MISSING_VALUE`, e tutto il path `_try_parse` con applied_patches (output sarà sempre parser-grade). Test: smoke + spot-check `applied_patches` field assente nelle predictions.
4. **Rimuovi heuristic recovery R-side** se W1 PASSA. `R/dgx-collect.R`: rimuovere `.try_recover_stage2_json()` + relative chiamate in `dgx_p4_collect()`. Test: `devtools::test()` (rimuovere/aggiornare i test che la coprono).
5. **Valutare `chunk_size=25 → 50`.** Path C era misura preventiva contro Issue #39734; a bug fixato non è strutturale. Cs50 dimezza il numero di chunks → ~50% wall time stage2 in meno + KV cache pressure ridotta perché continuous batching restored. Decisione: smoke comparativo cs25 vs cs50 (1 run mini500 ognuno), se cs50 schema validity ≥ 99% e nessun deadlock → bump default a 50. Aggiornare `analysis/p4-stage2-build-input.R::CHUNK_SIZE`.
6. **`scheduler_reserve_full_isl` flag**. Se v0.20.2 espone il kwarg pulito e il default upstream è ora safe (post #40946), rimuovere l'override esplicito da `inst/extdata/p4-defaults.yml`. Se il flag è stato deprecato in v0.20, rimuoverlo del tutto.
7. **ADR-0009 (`safe-mode`) update.** Aggiungere sezione `## Update YYYY-MM-DD (post ADR-0010)` con nota: "Mitigazione superata da PR #40946 in vLLM v0.20.2. Status: deprecata come strategia strutturale, ridotta a `fallback contingency` se safe-mode è ri-attivato manualmente per dataset patologici futuri." Status header invariato (`Accepted`) — l'ADR registra la decisione presa il 2026-05-08 con le info di allora.
8. **ADR-0011 (`tier strategy`) update.** Aggiungere sezione `## Update YYYY-MM-DD` con nota: "Tier strategy resta valida e attiva. Single-pass goal raggiunto. Compatibile con concurrency restored (W2). Tier S/M/L/XL boundaries invariati." Nessun cambiamento sostanziale — la tier strategy non era un workaround per #39734, era un'ottimizzazione single-pass indipendente.
9. **NEWS.md + DESCRIPTION version bump** (es. `0.0.0.9015`): "vLLM upgrade v0.10.0 → v0.20.2; rimossi 5 workaround stack (safe-mode, disable_guided_decoding, fence-strip, heuristic recovery Python+R); concurrency restored; schema validity 100% parser-grade."
10. **Final regression run α stage2-cs25 / cs50.** Re-run completo del dataset α (8546 record) con la pipeline pulita. Confronto con baseline α 99.84% / 93.3%. Atteso: schema validity = 100%, binary accuracy ≥ 93.3%, wall time ridotto del 50-70% vs baseline 3-pass. Risultato salvato come `analysis/p4-output/alpha-stage2-cs25-v0.20.2-clean.rds` per audit storico.

Tempo stimato Phase 5: 1-2 giornate operatore (cleanup commit per commit + test mini-gold ad ognuno) + 4-8h DGX time per smoke + final regression run. Non parallelizzabile con Phase 4 — serve gate PASS prima di iniziare.

### Gate Criteria (Hierarchical)

**HARD gate (3 condizioni, TUTTE devono passare — no regression).**

| H# | Condizione | Threshold | Source |
|---|---|---|---|
| H1 | Mini-gold v5 binary accuracy non regredisce | ≥ **93%** (baseline 93.3%, 0.3pp tolerance per stochastic n=100) | Phase 3 |
| H2 | Schema validity non regredisce | ≥ **98%** (baseline α full = 99.84%, 1.84pp tolerance) | Phase 2 config 2a |
| H3 | No deadlock baseline | 4/4 worker completano 500/500 senza stall | Phase 2 config 2a |

**SOFT gate (almeno 1 di 2 deve passare — almeno un win strutturale).**

| W# | Win | Threshold | Source |
|---|---|---|---|
| W1 | `outlines` strict-schema su Mistral-3.2 | schema_validity = **100%** sui 500 record (vs 99.84% post-hoc baseline) | Phase 2 config 2b |
| W2 | Concurrency restored post PR #40946 | (a) 4/4 worker completano 500/500 senza stall AND (b) throughput ≥ **+20%** vs config 2a wall time | Phase 2 config 2c |

**Decision matrix.**

| HARD | SOFT | Outcome | Rationale |
|---|---|---|---|
| ALL PASS | ANY PASS | **Upgrade SÌ → v0.20.2** | Win strutturale ottenuto, no regression, β beneficia |
| ALL PASS | NONE PASS | **Stay on v0.10.0** | No win concreto, upgrade è puro maintenance churn |
| ANY FAIL | — | **Stay on v0.10.0** | Regression inaccettabile; v0.20.2 non è candidato valido |

**Note sui threshold (giustificazioni).**

- H1 ≥ 93%: Mini-gold v5 ha n=100 → 95% CI binomiale ≈ ±5pp. Threshold 93% (0.3pp tolerance da baseline 93.3%) sotto la quale c'è vera regressione, sopra rumore stocastico.
- H2 ≥ 98%: Baseline α full = 99.84% (8.532/8.546 dopo canonical merge 3-pass + heuristic recovery). Threshold ≥ 98% (1.84pp tolerance) protegge il guadagno faticoso senza essere assolutista.
- W1 = 100%: se outlines strict-schema funziona davvero, **deve** dare letteralmente 100% (parser-grade) — qualunque deviazione indica che il backend fa silently free-gen e non è il win cercato.
- W2 throughput ≥ +20%: incrementi sotto 20% non giustificano il maintenance lifetime cost del version bump; β payoff diventa marginale.

**Cosa NON è nel gate (rationale).**

- **Stage1 NON viene re-testato.** Issue #39734 non lo affligge (record sample-level con prompt corti, validato 100% su 130k record in α). Re-smoke stage1 sarebbe spreco DGX time.
- **Costo $.** Irrilevante (DGX self-host, $0). Non variabile.
- **Cold load time.** Cumulativo trascurabile vs cost regression operative.

### Consequences (PASS path — upgrade SÌ + Phase 5 cleanup obbligatoria)

L'upgrade non è completato al merge del Dockerfile bump. È completato solo dopo che la Phase 5 (`Code simplification & cleanup`) ha rimosso lo stack di workaround. I workaround che diventano superflui devono sparire, non restare come zombie code: ogni workaround mantenuto inutilmente è debito tecnico che paghiamo con interest compounded sui run β successivi e sull'onboarding.

- **Positive (post Phase 5):**
  - β massivo accelera ~3-4× (concurrency restored, `max_num_seqs=4`).
  - Schema validity 100% parser-grade via outlines → ~80-100 righe Python+R rimosse (heuristic recovery `_RX_MISSING_VALUE` + `.try_recover_stage2_json()` + fence-strip).
  - Safe-mode (ADR-0009 `max_num_seqs=1, microbatch=1`) ELIMINATO dalla config default. Resta richiamabile manualmente come fallback contingency per dataset patologici futuri.
  - `disable_guided_decoding=true` ELIMINATO. `structured_outputs_config.backend=outlines` è il nuovo default.
  - `chunk_size=25 → 50` se smoke comparativo lo permette (dimezza numero chunks su β).
  - PagedAttention v2 / CUDA 13.0 perf gain bonus.
  - Pipeline complexity ridotta: 5 workaround → 0 (o 1 conservativo se cs50 fallisse).
  - NEWS.md `0.0.0.9015` documenta la transizione, paper Methods aggiornata.

- **Negative:**
  - Maintenance lifetime: container immagine bumpata, dipendenza CUDA 13.0 richiede driver moderni.
  - API migration `guided_decoding_backend` → `structured_outputs_config` cementata.
  - ADR-0009 "Safe-mode" e ADR-0011 "Tier strategy" richiedono sezione `## Update` con note di deprecation parziale (vedi Phase 5 step 7-8).
  - Phase 5 richiede 1-2 giornate operatore + 4-8h DGX. Non automatizzabile.

- **Neutral:**
  - Final regression run α stage2 con pipeline pulita produce `alpha-stage2-cs25-v0.20.2-clean.rds` come baseline-of-record.
  - ADR-0009 e spec investigation Task 22 restano nel repo come record storico interno; non vanno citati nel paper (audience bioinformatica, non CS).

### Consequences (FAIL path — stay 0.10.0)

- **Positive:**
  - Zero rischio. Pipeline α resta validata.

- **Negative:**
  - β massivo continua a girare in safe-mode = settimane di wall time aggiuntive.
  - Schema validity 99.84% post-hoc resta il ceiling.
  - Manutenzione 5 workaround in perpetuo.

- **Neutral:**
  - ADR-0010 chiuso `Accepted: Stay`. Ri-apertura possibile su trigger nuovo (es. v0.21+ con ulteriori fix Mistral).

## Pros and Cons of the Options

### A — Stay v0.10.0

- **Pro:** zero rischio; pipeline α validata invariata.
- **Contro:** 5 workaround in perpetuo; β paga ~3-4× wall time; schema validity 99.84% ceiling.

### B — Upgrade v0.20.2 (gated)

- **Pro:** Issue #39734 fixed upstream; outlines per strict schema; perf bonus; pipeline complexity ridotta.
- **Contro:** API migration richiesta; rischio regression Mistral-3.2; ~3-4h validation.

### C — Multi-version A/B

- **Pro:** rigore scientifico massimo.
- **Contro:** 3× build/SIF/smoke = 6-10h aggiuntive senza guadagno informativo proporzionato.

### D — Switch runtime

- **Pro:** elimina dipendenza vLLM.
- **Contro:** già scartata in ADR-0009; settimane di lavoro.

## Links

- vLLM Issue #39734: <https://github.com/vllm-project/vllm/issues/39734>
- vLLM PR #40946 (fix #39734, mergiato 2026-04-27 in v0.20.0): <https://github.com/vllm-project/vllm/pull/40946>
- vLLM v0.20.0 release: <https://github.com/vllm-project/vllm/releases/tag/v0.20.0>
- vLLM v0.20.2 release (2026-05-10, target): <https://github.com/vllm-project/vllm/releases/tag/v0.20.2>
- vLLM Structured Outputs docs (post-API-rework): <https://docs.vllm.ai/en/latest/features/structured_outputs/>
- ADR-0007 DGX self-host: `docs/decisions/0007-dgx-self-host-vllm.md`
- ADR-0008 sampling defaults: `docs/decisions/0008-vllm-sampling-defaults.md`
- ADR-0009 safe-mode stage2: `docs/decisions/0009-stage2-safe-mode-vllm-deadlock.md`
- ADR-0011 tier max_tokens: `docs/decisions/0011-tier-based-max-tokens.md`
- Spec investigation Task 22: `docs/superpowers/specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md`
- Memory `project_vllm_upgrade_post_alpha.md` (trigger condition, da aggiornare post-decision)
