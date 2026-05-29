# F2 — Fragilità del prompt Stadio 1 + guard `is_zero_timepoint` + benchmark design-aware scalato

> **Data**: 2026-05-28 (RED ALERT FASE F, sessione 9 + lavoro autonomo notturno).
> **Branch**: `p5-llm-anchor-classification-audit`. **Stato**: investigazione chiusa,
> fix committato e validato; benchmark scalato in §3.
> **Tipo**: finding paper-grade (Methods/Results + Supplementary).

## 0. Sintesi

Il gate F2-smoke (100 sample) ha rivelato un calo di accuracy della
classificazione design-aware (mini-gold) da 98% (β, 2026-05-12) a 92.93%,
sotto la soglia di STOP del 93%. L'indagine sistematica (3 esperimenti DGX a
variabile singola) ha isolato la causa radice in **una fragilità del prompt
Stadio 1**: l'aggiunta di contenuti necessari ma logicamente non correlati
(D1b `molecule_hint`, D4 `organism_hint`) ha **destabilizzato campi non
correlati** dell'output LLM, in particolare `duration.is_zero_timepoint`. Il
fix è un **guard deterministico** che riallinea quel campo all'evidenza,
indipendente dal modello. Accuracy recuperata a 97% senza toccare il prompt.

## 1. Scoperta (gate F2-smoke)

F2-smoke ha girato due track end-to-end (stage1→stage2) a config invariata
(temp=0, rep_pen=1.1, microbatch=50):

| Track | Schema s1/s2 | Accuracy | Note |
|---|---|---|---|
| mini-gold (100, accuracy gate) | 100% / 100% | **92.93%** (92/99) | < soglia STOP 93% |
| bacino v2 (100 random, schema gate) | 100% / 100% | n/a (no gold) | design_kind sano |

Le 5 regressioni vs β GATE #1 erano **unidirezionali** (gold=treated →
pred=control) e concentrate in **2 studi** multi-arm (GSE183194 ×4, GSE201084
×1). Pattern sistematico, non rumore.

## 2. Indagine root-cause (systematic-debugging)

Catena del prompt verificata sull'artefatto reale: il prompt Stadio 2 arriva
al DGX via `R/llm-stage2.R::.stage2_system_prompt()` → `dgx-bundle.R:106-111`
→ `prompt.txt` → rsync. (Due conclusioni intermedie corrette guardando il
bundle reale, non un solo file.)

| Esperimento | Variabile cambiata | Risultato | Conclusione |
|---|---|---|---|
| F2-smoke | baseline | 92.93% | — |
| Controprova IT | stage2 prompt EN→IT | 92.86% | **stage2 NON è la causa** |
| Isolamento β-prompt | stage1 prompt → β-era | **97.96%**, is_zero_timepoint 12→7, 5/5 corretti | **trigger = prompt Stadio 1 (D1b/D4)** |

**Meccanismo** (tracciato all'indietro): lo Stadio 1, sotto il prompt D1b/D4,
marca `duration.is_zero_timepoint=TRUE` su sample con `duration=null` (β:
FALSE). A valle, la REGOLA 2 di Stadio 2 ("time-zero = control") declassa
correttamente quei sample a `control/time_zero`. Lo Stadio 2 è corretto; il
difetto è lo Stadio 1 che produce un flag semanticamente invalido (non esiste
"tempo zero" senza tempo). Magnitudine: `is_zero_timepoint=TRUE` 6 (β) → 12
(F2-smoke) sui 100 mini-gold. Né `molecule_hint` né `organism_hint` hanno
relazione logica con il timepoint → è **condizionamento diffuso** di un edit
di prompt su campi non correlati (prompt fragile).

Il 5° caso (GSM6050371, multi-arm) non è un bug: lo Stadio 2 lo usa come
braccio di riferimento (`secondary_arm`) — `control` in senso relazionale vs
`treated` in senso assoluto del gold binario (limitazione L1 nota del binario
su multi-arm).

## 3. Fix: guard deterministico `is_zero_timepoint`

`R/stage1-normalize.R` (TDD, 38 expect_*): `is_zero_timepoint` può essere TRUE
solo con evidenza reale di tempo zero (`value_hours==0` o `value_raw` che
matcha pattern t0/baseline/0h); altrimenti forzato FALSE. Applicato alla
sorgente nel build dell'input Stadio 2 (`analysis/p4-beta-stage2-build-input.R`,
choke point della pipeline F2). Robusto, model-independent: un campo con
vincolo semantico non è più lasciato al capriccio del modello (difesa in
profondità).

**Validazione (DGX)**: stage1 D1b/D4 + guard + stage2 EN → mini-gold accuracy
**92.93% → 97.00%**, GSE183194 4/4 → treated, 7 flag spuri corretti. D1b/D4 e
`molecule_hint` restano intatti per il fullrun F2. Le differenze residue vs
gold = 2 errori pre-esistenti di β + GSM6050371 (multi-arm L1). Qualità
tornata al livello β.

Il guard NON ripara la fragilità del prompt in sé (il modello resta sensibile
a edit non correlati); la neutralizza dove conta. La fragilità è un finding
metodologico per il paper: piccole modifiche di prompt necessarie possono
perturbare output non correlati di un LLM a temp=0.

## 4. Benchmark design-aware scalato (gold 756 sample)

<!-- DA COMPLETARE dopo il run benchmark scalato -->

### 4.1 Costruzione del gold

Gold design-aware LLM-assisted (Claude) su **756 sample reali da 72 studi**
del bacino v2 di produzione (508k), intersezione col gold umano dell'autore
(`relevant_sample_classified.xlsx`, `trtctr_EP`) usato come prior e raffinato
a `design_role_v3` leggendo i metadati. Studi completi (Stadio 2 vede il
design intero). Etichettatura: `analysis/p4-output/f2-eval-gold.csv`.

- Calibrazione vs prior umano `trtctr_EP`: **88.2% agreement** (620/703);
  l'11.8% di disaccordo sono correzioni design-aware verificate (genetic/
  vehicle/NT-siRNA controls marcati "treated" da EP; alcuni errori EP veri,
  es. estradiolo marcato control in GSE151392).
- Distribuzione: 437 treated / 306 control / 13 unclear (NA).
- Caveat: gold LLM-assisted, non human-expert. Forte ma da dichiarare; l'autore
  resta l'autorità finale.

### 4.2 Risultati

Pipeline corrente (stage1 D1b/D4 + guard `is_zero_timepoint` + stage2 EN),
schema s1=99.7% / s2=100%.

| Gold | Accuracy | n_eval | sens | spec | f1 |
|---|---:|---:|---:|---:|---:|
| Originale (full, conservativo) | **94.14%** | 717 | 96.9% | 90.2% | 0.951 |
| Raffinato (−2 studi mal posti) | **96.02%** | 678 | 96.7% | 95.0% | 0.966 |

Confusion (gold originale): control 266 ok / 29→treated / 11→NA; treated
409 ok / 13→control / 15→NA.

**Tassonomia dei 68 disaccordi** (analisi manuale di ogni errore):

| Categoria | n | Natura |
|---|---:|---|
| Multi-asse difendibile | 24 | Studi genetico×drug / culture×genetico (GSE103242, GSE106858, GSE117608, GSE149280, GSE158386, GSE186543): la pipeline sceglie un asse, il gold un altro; **nessuno dei due è errato** |
| Non-predetti (coverage gap) | 26 | Stadio 2 non assegna un `primary_role` a ogni sample (viola la sua REGOLA 4 "DO NOT OMIT"). 3.5% degli evaluable |
| Studi mal posti (gold) | 15 | GSE162187 (coorte resistant/sensitive, tutti chemo) + GSE162711 (tutti Akti): nessun braccio di riferimento untreated/vehicle → il binario treated/control è ill-posed |
| Potenziali errori pipeline | **5** | GSE53665 ERG-WT a "Wk0" (REGOLA 2 time-zero, difendibile), GSE157764 VitD (1), GSE166448 "serum starvation-stimulation" 4H/18H (3, frasing ambigua) |

**Refinement round-3 (principled, even-handed)**: criterio "uno studio senza
braccio di riferimento untreated/vehicle/genetic-negative non può definire
controlli design-aware → `unclear`". Applicato a GSE162187 + GSE162711 (39
sample → unclear). Riportiamo **entrambi** i numeri (no cherry-picking):
94.14% conservativo, 96.02% raffinato.

**Conclusione**: dopo il guard `is_zero_timepoint`, la classificazione
design-aware è sostanzialmente corretta su scala (717-678 sample, 5x il
mini-gold). I disaccordi residui sono **ambiguità multi-asse intrinseca** (il
binario treated/control è una proiezione lossy del design factoriale — L1
nota) + **gap di copertura 3.5%**, NON bug sistematici. Solo ~5/717 sono
plausibili errori veri della pipeline, e per lo più difendibili.

### 4.3 Completeness guard Stadio 2 (implementato + validato)

**Implementato** (`R/stage2-normalize.R`, TDD 19 expect_*): il coverage gap
del 3.5% (Stadio 2 omette sample, viola la sua REGOLA 4) è ora gestito da un
guard deterministico che raccoglie ogni sample di input non coperto da
`replicate_groups` in un gruppo sintetico `primary_role='unclear'`
(schema-valido v2). Chunk-aware: confronta con i sample EFFETTIVAMENTE in input
a ciascun record (`input_by_record` keyed per record_id), non l'intera series.

- `complete_stage2_coverage(parsed_json, input_sample_ids)` — pure, per-record.
- `audit_stage2_coverage(stage2_records, input_by_record)` — driver + report.

**Validazione sui dati reali del benchmark**: recupera **24 sample non coperti
su 14 record** (= il coverage gap osservato). Non cambia l'accuracy (unclear →
NA nel binario) ma rende il gap esplicito e auditabile invece di un drop
silenzioso a monte di Stadio 3.

**Wiring nel pipeline (deferred a F4, gated)**: l'integrazione nel path live
richiede che `.load_stage2_master` preservi `record_id` (oggi riduce a
`parsed_json`), così il match input/output è chunk-aware per record_id (per
studi chunked il match per `series_id` fonderebbe i chunk → bug). Quel cambio
appartiene al rebuild Stadio 3 (F4), dove sarà validato end-to-end. La funzione
è pronta e testata; serve solo agganciarla a F4.

### 4.4 Raccomandazione residua

**Gold design-aware esteso human-reviewed**: il gold da 756 è LLM-assisted
(Claude). Per il paper, una review umana dell'autore (almeno sugli studi
multi-asse e mal posti) lo eleverebbe a human-expert.

## 5. Conferma su scala — fullrun 508k (sessione 10, 2026-05-29)

Il fullrun Stadio 1 v2 sul bacino di produzione (508.037 sample, config
invariata temp=0/rep_pen=1.1, prompt v2 con guard `is_zero_timepoint` a valle)
ha **confermato e quantificato** la fragilità del prompt come previsto da §2-3.

**Wall**: ~11h40m (07:12→18:50 UTC), 51 chunk da 10k + 25 outlier (nchar>3500,
max_model_len=32768), throughput ~13.8 min/chunk stabile, 0 stall/HALT.

### 5.1 Tasso di fallimento: 3x rispetto al β, attribuito al prompt

Validità LLM-only post-fullrun: **506.573 / 508.037 = 99.712%** → **1.464 fail**
(`parsed_json` null). Tasso 0.288% **contro lo 0.0925% del β** (822 fail genuini
/ 888.795, escludendo i 749 ETL-leak). ~3.1x.

Indagine (audit before patch — i fail NON sono stati patchati prima di capire la
causa):

| Test | Esito | Conclusione |
|---|---|---|
| Distribuzione per worker | 360 / 371 / 366 / 367 (uniforme) + spalmati su tutto il run | **NON è infra/worker** |
| Correlazione input nchar | rate 0.23%→0.84% da <200 a 400-800 char | lieve, non spiega il 3x |
| `molecule_ch1` | total RNA 0.285%, polyA 0.266%, **nuclear RNA 3.30%** (36 fail) | enrichment nuclear, ma solo 2.5% dei fail |
| **Overlap GSM vs β** (stesso campione, prompt diverso) | **1.195/1.464 (81.6%) sono fail NUOVI** (successo nel prompt β, loop ora); 269 (18.4%) erano già β-fail; 328 β-fail ora recuperati | **causa = prompt v2 (D1b/D4)** |

L'81.6% di fail "nuovi" è la prova diretta: sono record che con il prompt β
(senza `molecule_hint`/`organism_hint`) classificavano e ora vanno in loop
whitespace (Mode A 77.3%). Stesso meccanismo di §2 (un edit di prompt necessario
perturba comportamento non correlato dell'LLM a temp=0), qui sul **decoder**
invece che su `is_zero_timepoint`. C'è churn bidirezionale (+1.195 / −328).

### 5.2 Caso estremo: GSE157354 (chimera neurale human-mouse)

I fail più ostinati (resistenti fino a rep_pen=1.4) sono **22/23 dei residui
finali da un solo studio**, GSE157354 ("Co-cultured human and mouse pluripotent
stem cell-derived neural cells", metadati `mixing percent human`, titoli
`Hsap_Mmul_Chimera`). Input corto (~380 char) ma output di flood whitespace
176k-339k char. Sample human validi (passano H2). Il linguaggio chimera/mixing
destabilizza il decoder su un sottoinsieme dello studio.

### 5.3 Rescue cascade → 100% (riuso strategie β, ADR-0008 addendum)

| Step | config | retry | recuperati |
|---|---|---:|---:|
| H1 | rep_pen=1.2, max_tokens=4096, mml=8192 | 1.464 | 1.317 (89.96%) |
| H1.2 | rep_pen=1.3, max_tokens=8192, mml=16384 | 147 | 124 (84.4%) |
| H1.3 | rep_pen=1.4, max_tokens=8192, mml=16384 | 23 | 21 (91.3%) |
| H1.4 manual | mirror gemello GSM4763009, schema-validato | 2 | 2 |

Master rescued: **508.037 / 508.037 = 100.0000%** (1.462 LLM + 2 manual), tag
`rescue_source`. La curation manuale rispecchia il `parsed_json` di un gemello
GSE157354 recuperato (stesso studio), cambiando solo `geo_accession` + `duration`
(growth-time days), validato contro `sample_facts.stage1.v3`.

### 5.4 Implicazione (onesta, senza minimizzare)

La fragilità del prompt v2 è **reale e quantificata** (3x fail rate, 81.6%
prompt-indotti). **Non** intacca:
- la **validità finale** del master (recuperata al 100% dalla cascade, ogni
  sample classificato e schema-valido, recuperi tracciati via `rescue_source`);
- l'**accuratezza** del contenuto (il benchmark design-aware 94-96% di §4 era già
  misurato sul prompt v2).

Si manifesta come fallimento **rumoroso** (loop → JSON invalido, recuperabile),
non come drift silenzioso. È un limite metodologico da dichiarare nel paper
(estende L2 ceiling Mistral): edit di prompt necessari su un LLM a temp=0 possono
perturbare comportamento non correlato — sia campi specifici (§2-3) sia la
stabilità del decoder (§5) — e vanno verificati su scala, non solo su mini-gold.

## 6. Riferimenti

- Script audit F2: `analysis/p4-fase-f2-smoke.R`, `*-counterproof-IT.R`,
  `*-isolate-stage1prompt.R`, `*-validate-guard.R`,
  `*-eval-build-pool.R`, `*-eval-sample-studies.R`, `*-eval-merge-build.R`,
  `*-eval-run.R`.
- Fix: `R/stage1-normalize.R` + `tests/testthat/test-stage1-normalize.R`.
- Gate sintesi: `analysis/audit/F2-smoke-eval.md`.
- Fullrun F2 (sessione 10): scaffolding `analysis/p4-fase-f2-stage1-chunk-build.R`
  + `scripts/p4-fase-f2-stage1-chunked-tick.sh`; merge
  `analysis/p4-fase-f2-stage1-merge.R`; rescue
  `analysis/p4-fase-f2-rescue-{classify-fails,build-input,h1,h12,h13,h14-manual,
  merge-master}.R`. Master: `p4-fase-f2-stage1-master-predictions-rescued.jsonl`.
