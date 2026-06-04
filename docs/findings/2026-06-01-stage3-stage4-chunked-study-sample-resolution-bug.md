# Chunked-study sample resolution bug — Stadio 3 + Stadio 4

> **Data**: 2026-06-01 (RED ALERT FASE F4, sessione 12).
> **Severità**: paper-grade, **bloccante**. Compromette la membership dei
> campioni nel pooling DE per gli studi chunked, sia nel rebuild F4 in arrivo
> sia nei risultati **già prodotti** (run Stadio 4 `96c43acb` + 15 case study
> Layer B `56b911e6`).
> **Scoperto**: durante il wiring del completeness guard (F4 Step 2), inseguendo
> un rilievo di code review sul gruppo sintetico `completeness_uncovered`.
> **Stato fix**: diagnosi chiusa, fix NON implementato (gate utente).

## TL;DR

Lo Stadio 2 LLM processa gli studi grandi in **chunk** (cs50, per il limite di
contesto del modello). Un studio splittato in N chunk compare nel master come N
record con la **stessa `series_id`**. Tutta la pipeline a valle assume invece
**un record per studio**: il `record_id` è `sprintf("%s__%s", series_id,
suffix)` e Stadio 4 indicizza il master per `series_id` con `assign` last-wins.
Risultato: di uno studio chunked **sopravvive solo l'ultimo chunk**; i campioni
di tutti gli altri chunk vengono **droppati o misrisolti** nel pooling.

Impatto misurato (campioni "a rischio" = fuori dall'ultimo chunk):

| Dataset | Studi chunked | Campioni a rischio | % campioni |
|---|---:|---:|---:|
| Master β (→ Stadio 4 `96c43acb` già prodotto) | 2.266 | **435.255 / 784.000** | **55,52%** |
| Master F3 v2 (input del rebuild F4) | 1.661 | **164.483 / 461.212** | **35,66%** |

## Root cause

Il chunking nasce come dettaglio infrastrutturale (throughput LLM), ma non viene
mai "annullato": nessuno step riassembla i chunk di uno stesso studio prima del
clustering. Due assunzioni incompatibili con il chunking sono cablate nel codice.

### 1. `record_id` non è chunk-unico (Stadio 3)

`R/stage3-build.R:429` (pair) e `:487` (group):

```r
record_id = sprintf("%s__%s", sid, cmp$comparison_id)   # pair
record_id = sprintf("%s__%s", sid, rg$group_id)         # group
```

`sid` è `series_id` nudo (es. `GSE48865`), **non** il record_id del chunk
(`GSE48865#1of6`). L'LLM rietichetta `comparison_id`/`group_id` in modo
indipendente per ogni chunk, quindi due chunk dello stesso studio possono
produrre lo stesso `record_id` downstream.

Conseguenza in `.summarize_clusters` (`R/stage3-build.R:582,586`): i lookup
`pair_lookup`/`group_lookup` sono env keyed per `record_id` con `assign`
last-wins → il record collidente precedente viene sovrascritto; `mget`
(`:621,623`) restituisce il sopravvissuto. I conteggi del cluster vengono
calcolati sull'ultimo chunk (eventualmente doppiati), le identità dei campioni
degli altri chunk vengono perse.

Sul master F3: **681 / 1.661 studi chunked** hanno group_id collidenti tra chunk
con campioni disgiunti (**13.017** collisioni di gruppo), **350** studi
collidono anche in pair-mode (`comparison_id`).

### 2. Indice stage2 per `series_id`, last-wins (Stadio 4)

`R/stage4-dispatch.R:40`:

```r
.index_stage2_master <- function(stage2_master) {
  env <- new.env(...)
  for (s in stage2_master) {
    if (is.null(s$series_id)) next
    assign(s$series_id, s, envir = env)   # last-wins: tiene solo l'ultimo chunk
  }
  env
}
```

I tre resolver di Stadio 4 — `.build_study_dispatch_from_stage3` (`:128`),
`.build_group_dispatch_from_stage3` (`:190`), `.enrich_group_baseline_sample_ids`
(`:258`) — risolvono `record_id → campioni` via `.split_record_id` (split sul
primo `__` → `series_id`) + lookup nell'indice per `series_id`. Per uno studio
chunked l'indice contiene solo l'ultimo chunk: un `record_id` che riferisce un
gruppo definito in un chunk precedente o (a) non trova il gruppo → record
`next` → **campioni droppati**, o (b) trova un omonimo nell'ultimo chunk
(collisione) → **campioni misrisolti** (quelli dell'ultimo chunk al posto dei
veri).

Questo difetto colpisce **tutti** gli studi chunked (non solo i 681 collidenti):
ogni campione fuori dall'ultimo chunk è corrotto, perché il chunking partiziona
i campioni in modo disgiunto tra chunk.

## Evidence (riproduzione deterministica)

`analysis/audit/F4-chunk-collision-repro.R` (gira in pochi secondi):

```
== Stadio 3, group_id collidente ==
record_id distinti nelle assignment del cluster L0: GSET__tumor
  -> 2 record fisici collassano su 1 record_id; last-wins, GSM1/GSM2 persi.
cluster_id L0 identico tra collisione e chunk-unique: TRUE

== Stadio 4, dispatch ==
chunked (bug): GSM3,GSM4
merged (fix) : GSM1,GSM2,GSM3,GSM4
```

- **Stadio 3**: due chunk con stesso `group_id` e campioni disgiunti collassano
  su un solo `record_id`.
- **Controprova**: con `group_id` chunk-unici i due record sopravvivono e
  l'anchor li **ri-fonde nello stesso cluster** (il `cluster_id` deriva
  dall'anchor, non dal record_id — `cluster_id` identico nei due scenari). Cioè
  il clustering per-anchor fa già il merge biologico corretto; manca solo che i
  record sopravvivano al lookup.
- **Stadio 4**: uno studio a 2 chunk **senza collisione** perde comunque i
  campioni del primo chunk (`GSM1,GSM2`) al dispatch; il riassemblaggio in un
  record/series li recupera tutti.

## Impatto scientifico

- **Risultati già prodotti** (`96c43acb` + Layer B `56b911e6`): la membership dei
  campioni nel `cluster_pooled.parquet` (13,7M righe) è corrotta per gli studi
  chunked — **>55% dei campioni referenziati**. I logFC/effect-size dei cluster
  che includono studi chunked sono calcolati su un sottoinsieme/insieme errato di
  campioni. I 15 case study Layer B vanno riverificati uno per uno.
- **Stadio 3 (cluster, assignment)**: la struttura dei cluster è corretta (tutti
  i chunk diventano record e vengono assegnati); il danno è (i) nei conteggi dei
  cluster collidenti (`.summarize_clusters`) e (ii) a valle in Stadio 4.
- **Completeness guard (F4 Step 2)**: il gruppo sintetico `completeness_uncovered`
  eredita la stessa collisione (group_id fisso → `series__completeness_uncovered`
  per ogni chunk). È un sintomo dello stesso difetto, non una causa separata.

## Fix implementato (2026-06-01)

**Riassemblaggio al caricamento**, `.reassemble_stage2_chunks()`
(`R/stage2-normalize.R`): fonde i record con la stessa `series_id` in un unico
study record, applicato in `build_stage3_clusters()` (Fase 1b) e
`build_stage4_results()` (prima dei dispatch builder). Ripristina l'invariante
"un record per studio" su cui contano i 5 consumatori, senza riscrivere lo schema
record_id. No-op per i master non chunked; idempotente.

**Strategia: namespacing-per-chunk, NON union-per-id.** La validazione empirica
sul master F3 ha mostrato che union-per-`group_id` non è sicura: **639** group_id
omonimi tra chunk hanno `primary_role` in conflitto e **831** comparison_id
riferiscono treated/control diversi (`factor_levels` invece mai). Quindi ogni
chunk mantiene i suoi gruppi/comparison con id resi unici (suffisso
`#chunk<k>`), e i riferimenti delle comparison vengono riscritti coerentemente
entro lo stesso chunk. Nessuna assunzione semantica: ogni campione resta col
ruolo che il suo chunk gli ha dato. Il **merge biologico** (due chunk dello
stesso gruppo) lo fa il clustering per-anchor a valle — verificato: due record
namespaced con stesso anchor finiscono nello stesso `cluster_id`
(`analysis/audit/F4-chunk-collision-repro.R`).

**Completeness guard (F4 Step 2)** ricalibrato per-studio post-riassemblaggio
(`.apply_stage2_completeness_by_series`, input unito per series).

Test: `tests/testthat/test-stage2-reassemble.R` (21) +
`test-stage3-completeness-guard.R` (16); regressione stage2/3/4 = 1161 PASS /
0 FAIL; layer-b + dedupe SAMN = 225 PASS / 0 FAIL.

### Verifica di non-propagazione

- Tutti i consumatori di produzione (`.build_*_dispatch_from_stage3`,
  `.enrich_group_baseline_sample_ids`, `.index_stage2_master`) sono raggiunti
  solo via `build_stage4_results`, che ora riassembla prima. Gli script di
  produzione (smoke, layer-b) passano da lì. Unico chiamante diretto:
  `analysis/audit/A4-cluster-pooled-contamination.R` (audit one-off FASE A4, non
  pipeline).
- `build_stage4_results`: il riassemblaggio (riga 151) precede tutti gli usi di
  `stage2_master` (153/156/164).

### Residui noti (non introdotti dal fix, da decidere a parte)

- **Eligibility per-record** (`R/stage3-eligibility.R:80,89`, soglia n≥2): un
  gruppo biologico splittato con **esattamente 1 campione in un chunk** vede quel
  record cadere per n<2 (con l'union sarebbe salvato unendosi al resto del
  gruppo). Artefatto pre-esistente del chunking, ortogonale a questo fix.
  Quantificazione e decisione (eventuale union role-safe) rimandate.
- **Rigenerazione**: il fix impone di rifare F4 (Stadio 3) e F5 (Stadio 4) — già
  in piano. Ma marca i risultati `96c43acb` + Layer B `56b911e6` come **non
  affidabili** come baseline di confronto.

## File / righe chiave

- `R/stage3-build.R:429,487` (record_id), `:582,586,621,623` (lookup last-wins).
- `R/stage4-dispatch.R:40` (`.index_stage2_master`), `:79` (`.split_record_id`),
  `:128,190,258` (3 resolver).
- Repro: `analysis/audit/F4-chunk-collision-repro.R`.
