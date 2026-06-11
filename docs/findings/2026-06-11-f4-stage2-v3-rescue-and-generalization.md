# F4 Stadio 2 v3 — rescue dei troncamenti + il rescue come procedura data-adaptive

> **Status:** Consolidato 2026-06-11, branch `p5-llm-anchor-classification-audit`
> **Purpose:** Documentare (a) il rescue dei 19 fail-schema del fullrun Stadio 2 v3
> (opzione C, ADR-0020) e (b) l'osservazione metodologica — valida per il paper —
> che la cascata di rescue non è un set di iperparametri universali ma una
> **procedura diagnostica data-adaptive**. Da includere in Methods/Discussion.

## Contesto

Il fullrun Stadio 2 v3 (input a condizioni deduplicate per `design_signature`,
opzione C) ha processato **24.972 record / 24.394 studi** su Mistral-Small-3.2-24B
(vLLM, 4×H100 DGX, config invariata: temp 0, rep_pen 1.1, tiered max_tokens,
microbatch 50). Esito single-pass: **24.953 valide / 19 fail-schema (99,924%)**,
slurm 24022, wall 15h20m.

## Audit dei 19 fail — tre meccanismi, non uno

I 19 fail (10 studi distinti) erano tutti `json_parse_error` (output troncato), ma
l'audit (`analysis/p4-output/p4-f4-stage2-fullrun-v3-collect.rds`, ispezione dei
`raw_output`) ha mostrato che **non erano lo stesso problema**:

| meccanismo | diagnosi | studi |
|---|---|---|
| esplosione confronti | disegni multi-fattoriali generano ~4–6 confronti per condizione trattata → output oltre i 32768 token del tier XL | GSE249377 (~200 cmp/chunk), GSE162694 (174 cmp da 45 condizioni, 608 char/cmp) |
| esplosione rep_groups | chunk con centinaia di condizioni (broadcast spento, partizione per char budget) → centinaia di `replicate_group`, troncato prima dei confronti | GSE193677 (315 rep_groups/chunk) |
| degenerazione / flood | il decoder entra in loop ripetitivo (es. GSE186121 bloccato a ripetere `"1"` nell'array `levels`; GSE235391/GSE246587 whitespace-flood) | GSE186121, GSE235391, GSE246587 |

Più un caso a sé: GSE134595 (`multi_arm`, sole 9 condizioni ma 20 confronti
combinatori) troncato perché il tier basato sull'**input** gli aveva assegnato
4096 token, insufficienti per quell'**output**.

Lezione operativa (coerente con `feedback_audit_before_patch_cycle`): un fix
uniforme "abbassa il budget e re-splitta" avrebbe richiuso solo l'esplosione
rep_groups, lasciando aperti l'esplosione confronti, la degenerazione e il caso
multi_arm. Riconoscere i tre meccanismi PRIMA di lanciare ha evitato un
whack-a-mole di re-submit.

## Config di rescue (una sola, chiude tutti e tre)

Deviazione di **config** (non di prompt; tracciata come nel rescue β):

1. **`max_treated_per_chunk = 12`** — nuovo parametro di `.chunk_conditions`
   (commit del tetto condizioni/chunk). Il budget caratteri limita l'**input**;
   questo tetto limita il numero di condizioni *trattate* per chunk, che è ciò che
   guida l'**output** (confronti). È broadcast-safe (i controlli non contano contro
   il tetto, restano in ogni chunk). Porta il peggiore (GSE162694) a ~72 confronti
   ≈ 16k token, con margine sotto 32768.
2. **`max_tokens` piatto 32768** (`tiered_max_tokens=FALSE`) — headroom per
   l'esplosione confronti residua e per GSE134595 (che intero non sfora più i 4096).
3. **`repetition_penalty = 1.2`** (era 1.1) — cura la degenerazione/flood. Valore
   del rescue β (H1).

Esito: **506 record di rescue, 506/506 validi, 0 residui** (slurm 24222, wall
26 min). Master Stadio 2 v3 finale: **24.394 studi, 1 record/studio** (guard
fail-loud `.assert_stage2_one_record_per_series` PASS), gli studi re-chunkati
ricomposti per series (es. GSE249377: 268 chunk → 1 record, 3146 replicate_groups,
123 confronti). Riproducibile: `analysis/p4-fase-f4-stage2-rescue-build-v3.R` +
`-rescue-submit-v3.R` + `-collect-v3.R`.

## Il rescue è una procedura data-adaptive (paper-relevant)

Confrontando i quattro rescue prodotti finora:

| run | leve usate (valori) |
|---|---|
| β stage1 | rep_pen cascade 1.2→1.3→1.4 → cura manuale 1 record |
| β stage2 | resplit cs50→cs25 + tiered max_tokens |
| F3 stage2 | resplit cs25 + rep_pen cascade |
| F4 v3 | re-chunk a tetto condizioni + max_tokens 32768 piatto + rep_pen 1.2 |

Sotto, **la stessa cassetta degli attrezzi a tre leve**: (1) ridurre la dimensione
della richiesta (resplit/tetto), (2) alzare il budget di output (max_tokens),
(3) alzare `repetition_penalty` contro le degenerazioni. Ciò che cambia tra i run
non sono gli attrezzi ma i **valori** e **quale leva** si tira.

Conseguenza metodologica da dichiarare nel paper: **cambiando il corpus di input,
la coda dei fallimenti LLM (quanti, di che tipo, su quali studi limite) cambia, e
il rescue va ri-derivato.** Non perché serva codice nuovo — le tre leve coprono i
modi di fallimento osservati — ma perché la coda è una proprietà dei dati. Il
rescue non è un set di iperparametri universali: è un **loop diagnostico**
(audita i fail → classificali per meccanismo → scegli la leva → ri-tenta) che
porta la validità di schema a ~100% in modo riproducibile ma **richiede una
taratura per-corpus guidata dall'audit**, non automatica.

L'unica parte che generalizza ed è ora codice validato (con TDD) è il tetto
`max_treated_per_chunk`. I valori (12 / 32768 / 1.2) restano specifici di questo
run e vanno documentati come tali.
