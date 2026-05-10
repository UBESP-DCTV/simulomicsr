# ADR-0009: Safe-mode stage2 (max_num_seqs=1, microbatch=1) per deadlock-proof vLLM

- **Status:** Accepted (parzialmente superato — vedi Update 2026-05-10)
- **Date:** 2026-05-08
- **Deciders:** Luca Vedovelli
- **Supersedes:** parte dell'investigation Task 22 (Path C cs25 come primary defense)
- **Superseded by:** ADR-0010 (vLLM upgrade v0.20.2 con PR #40946 fix upstream)

## Update 2026-05-10 (post ADR-0010 upgrade)

Il workaround safe-mode (`max_num_seqs=1, microbatch=1`) **NON è più il
default operativo** dal 2026-05-10. ADR-0010 ha validato l'upgrade a
vLLM v0.20.2-cu129 che include PR #40946 (fix upstream per Issue
#39734). Phase 5 cleanup ha sostituito il default con `max_num_seqs=6`
+ `microbatch=50` (vincitore Phase 2 config 2d, +267% throughput vs
safe-mode).

Questo ADR resta `Accepted` come **record storico della decisione del
2026-05-08**: la scelta era corretta per l'engine vLLM v0.10.0 e
permise di chiudere α stage2 con 99.84% schema validity senza intervento
manuale. Il problema strutturale identificato (Issue #39734) è stato
fixato upstream 14 giorni dopo (PR #40946 mergiata 2026-04-27, rilasciata
in v0.20.0 2026-04-27).

**Safe-mode resta richiamabile manualmente come fallback contingency**
per dataset patologici futuri o se un nuovo bug vLLM emerge: i flag
`max_num_seqs` e `microbatch` restano nel codice (`R/dgx-bundle.R`,
`inst/dgx/python/run_p4_vllm.py`), basta override yaml o gen-override
runtime per riattivarli. Path C (`chunk_size=25` in
`analysis/p4-stage2-build-input.R`) resta default conservativo.



## Context and Problem Statement

Durante l'esecuzione del run α stage2 cs25 (job 19948 resume, 2026-05-08), il **worker 1 si è stallato per 30+ min con zero microbatch processati**. Gli altri 3 worker (0, 2, 3) progredivano regolarmente (~3 rec/min/worker). Il pattern è identico al **vLLM Issue #39734** (scheduler v1 deadlock head-of-line) che credevamo bypassato dalla mitigazione **Path C** (chunk_size=25, vedi `docs/superpowers/specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md`).

Investigation post-stallo ha identificato il record tossico: `GSE186121#37of238`, primo record assegnato a worker 1 nel resume. GSE186121 è uno studio "mostro" con 5933 sample, splittato in 238 chunks cs25 da ~32.7 KB ciascuno (~8K token). Caratteristiche del record:
- Dimensione: 33 KB raw input, ~8367 token approx
- Ben dentro `max_model_len=32768`
- Ben sotto la soglia di sicurezza dichiarata Path C ("max ~14K token (50KB)")

**Il record da solo NON sarebbe dovuto deadlock-are.** Path C era stato validato T5g (4/4 worker complete 500/500) e T5h (485/500 schema valid). Ma il bug Issue #39734 è **strutturalmente non-deterministico**: il deadlock non dipende solo dalla dimensione del prompt, ma dallo **stato concorrente del KV cache** al momento dello scheduling. Quando un record borderline-grande viene assegnato come primo job di un worker su KV cache fresca, con altri 3 worker che stanno costruendo il proprio KV state, l'interazione può triggerare il break-without-pop loop dello scheduler.

Conseguenza pratica: la pipeline non è affidabile sotto pattern di carico realistici. Su 8546 record cs25, un singolo record tossico in posizione sfortunata blocca permanentemente 1/4 dei worker. Il problema riemergerà su qualsiasi dataset stage2 futuro con studi grandi.

## Decision Drivers

- **Affidabilità sopra velocità**: la pipeline deve completare run di qualsiasi dataset senza intervento umano. Stalli che richiedono diagnosi + intervento manuale sono inaccettabili strutturalmente, anche se rari.
- **Causa root non gestibile a livello applicativo**: Issue #39734 è un bug nello scheduler vLLM v1 (`vllm/v1/core/sched/scheduler.py`). Documentato presente fino a 0.19.x. Non possiamo risolverlo dal codice utente.
- **Concorrenza è la condizione necessaria del bug**: il deadlock richiede multiple richieste in flight contemporaneamente che si contendono la KV cache.
- **Self-host = no time pressure**: la pipeline gira su DGX dell'utente, costo $0, tempo disponibile (vedi conversazione 2026-05-08: "non ho problemi di tempo").
- **Stage1 NON e' affetto**: i record stage1 sono sample-level con prompt corti (~1-2K token). Mai vicino al cap KV. Validato 100% su 130k record (run α stage1 2026-05-07).

## Considered Options

1. **A — Safe-mode (max_num_seqs=1, microbatch=1)**: elimina la concorrenza inter-request su ogni worker. I 4 worker continuano a girare in parallelo su 4 GPU, ma ognuno processa una richiesta alla volta. Deadlock-proof per costruzione perchè il bug richiede concorrenza.

2. **B — Filtro a-priori per dimensione**: pre-split input in due bundle (chunks <THRESHOLD → fast batch mode; chunks >=THRESHOLD → safe single-stream). Threshold empirico (es. 28 KB).

3. **C — Watchdog runtime con quarantena**: monitoring real-time dei worker, detection del stall (no progress in N min), scancel + auto-resubmit con record problematici in quarantena single-stream.

4. **D — Cambio runtime**: SGLang, TensorRT-LLM, llama.cpp.

5. **E — Upgrade vLLM**: deferred a ADR futuro post-alpha; Issue #39734 documentato presente fino a 0.19.x.

6. **F — Ridurre `max_model_len` 32768 → 16384**: meno spazio prenotato per request, KV pressure diluita; rischio truncation per chunks borderline.

## Decision Outcome

Scelta: **Opzione A — Safe-mode**.

Motivazione: A è l'unica opzione **strutturalmente deadlock-proof per costruzione**, non probabilistica. Le altre sono workaround:
- B introduce una soglia empirica che dipende da dataset e va ricalibrata. Non garantisce: il record può essere borderline e cadere dalla parte sbagliata.
- C è la soluzione "pipeline si auto-cura" piu' completa, ma richiede sviluppo non triviale (heartbeat worker, IPC, scancel/resubmit logic). Rinviata come miglioria futura.
- D è un investimento di 1-3 giorni con regression risk su Mistral-3.2.
- E e' deferred: non sappiamo se Issue #39734 e' fixed nel branch corrente.
- F e' workaround tattico, non strutturale.

A costa ~1.5-2x slowdown per worker (perdiamo continuous batching), ma il parallelismo cross-GPU resta (4 GPU = 4x). Stima α stage2 cs25 con safe-mode: ~13h vs ~6h con seqs=4. Costo accettabile dato che non c'e' pressione di tempo (DGX self-host, $0).

### Consequences

- **Positive:**
  - Pipeline stage2 deadlock-proof per qualsiasi dataset futuro (qualsiasi dimensione di chunk fino a `max_model_len`).
  - Nessuna soglia empirica da mantenere o ricalibrare.
  - Nessun watchdog/IPC complexity.
  - Risultati riproducibili: `seqs=1` riduce lo spazio di non-determinismo del scheduler.

- **Negative:**
  - ~1.5-2x slowdown per worker. Stage2 α: ~6h → ~13h.
  - Sotto-utilizzo della GPU H100 (la sua design point e' il continuous batching). Spreco di compute "teorico" che pero' e' gratis (DGX self-host).
  - Il problema concettuale resta: vLLM e' inadatto al pattern di prompt eterogenei lunghi se vuoi continuous batching. Documentato per future revisione (post ADR vLLM upgrade).

- **Neutral:**
  - Stage1 invariato: i record sample-level non triggerano il bug.
  - L'opzione di tornare a continuous batching resta accessibile (basta cambiare il yaml). Se futuri vLLM versions fixano Issue #39734, potremo riconsiderare.

## Pros and Cons of the Options

### Opzione A — Safe-mode

- **Pro:** strutturalmente deadlock-proof; configurazione minima (2 valori yaml); reversibile (single yaml change); riproducibile.
- **Contro:** slowdown ~1.5-2x; spreco GPU "teorico".

### Opzione B — Filtro per dimensione

- **Pro:** mantiene velocità sui record tipici; solo i big paganu il prezzo.
- **Contro:** threshold empirico (sbagliato per qualche dataset); orchestrazione di due bundle paralleli; non garantisce (record borderline possono cadere dalla parte sbagliata).

### Opzione C — Watchdog runtime

- **Pro:** auto-difende contro pattern non previsti (anche bug futuri non solo Issue #39734); preserva velocita' sul caso comune.
- **Contro:** complessità implementativa significativa (heartbeat, IPC, scancel logic, quarantine state machine); rinviabile a quando il volume giustifica l'investimento.

### Opzione D — Cambio runtime

- **Pro:** elimina la causa root (se altro engine non ha lo stesso bug).
- **Contro:** rebuild Docker completo; smoke su Mistral-3.2; integration risk; 1-3 giorni di lavoro.

### Opzione E — Upgrade vLLM

- **Pro:** se fixed upstream, soluzione zero-effort.
- **Contro:** Issue #39734 documentato presente fino a 0.19.x; rischio regression Mistral-3.2.

### Opzione F — Riduzione max_model_len

- **Pro:** zero re-engineering, una riga config.
- **Contro:** rischio truncation; non strutturale; problema riemerge se prompt crescono.

## Links

- vLLM Issue #39734: https://github.com/vllm-project/vllm/issues/39734
- Spec investigation: `docs/superpowers/specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md`
- ADR-0007: `docs/decisions/0007-dgx-self-host-vllm.md` (decisione di restare su vLLM)
- ADR-0008: `docs/decisions/0008-vllm-sampling-defaults.md` (sampling temp/rep_pen)
- Memory: `project_vllm_scheduler_deadlock.md` (root cause)
- Memory: `feedback_explain_then_decide.md` (stile decision-making che ha portato a questa scelta)
