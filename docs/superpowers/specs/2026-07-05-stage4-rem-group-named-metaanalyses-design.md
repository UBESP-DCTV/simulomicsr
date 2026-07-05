# Spec design — ramo `rem_group`: ammettere le meta-analisi nominate allo Stadio 4

**Data:** 2026-07-05
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Finding base:** `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`
**Handout base:** `docs/superpowers/specs/2026-07-05-stage4-selection-gate-fix-NEXT-SESSION-handout.md`
**ADR correlato (da creare, Proposed):** `docs/decisions/0022-stage4-rem-group-named-metaanalyses.md`
**Stato:** design approvato dall'utente (brainstorming 2026-07-05); pronto per il plan.

---

## 1. Problema (dal finding)

Il pooling dello Stadio 4 (Layer A) processa **433 cluster su 317.304** (Stadio 3 v7) e la porta di
selezione respinge *tutte* le meta-analisi cross-studio nominate. Dei 72 MEGA processati, **71 sono
senza nome**. Le meta-analisi vere esistono nello Stadio 3 v7 (sano, 95% omogeneo verificato al livello
del campione membro) ma sono `poolable=FALSE`: enzalutamide k=25, SARS-CoV-2 k=25, Breast Neoplasms
k=88, Prostatic 17, Alzheimer 14, fulvestrant/estradiol 12, vemurafenib 10, tamoxifen 9 — tutte a
livello **L2–L4** con `safety_min` **0.14–0.39**.

**Causa radice.** `.identify_layer_a_clusters` (`R/stage4-qc.R:11-40`) ammette i cluster `mode=group`
solo con `usable_mega_strict`, che richiede `level ∈ {0,1}` **e** `safety_min ≥ 0.7`
(`R/stage3-usability.R:44-48`, soglie `R/stage3-config.R`). Due requisiti auto-contraddittori con dove
vivono le meta-analisi vere: il **nome** vive a L2–L4, e una vera meta-analisi cross-studio ha
`safety_min` basso **per design** (25 laboratori con linee/dosi/tempi diversi). `usable_mega_relaxed`
(`safety_min ≥ 0.5`) è calcolato ma mai consumato — e comunque **non basterebbe**: i nominati hanno
`safety_min` sotto anche il relaxed 0.5.

**Errore concettuale.** La soglia `safety_min ≥ 0.7` è logica **MEGA** (pooling congiunto in un unico
modello → richiede omogeneità). Ma questi sono target **REM** (random-effects: modella l'eterogeneità
I²/τ², non la filtra). Lo Stadio 4 applica la mentalità MEGA a tutto e respinge il REM.

## 2. Scope del fix (Pop B: 650 cluster candidati = 197 entità distinte)

Composizione dei ruoli (`primary_role` Stadio 2), dal finding §4:

| struttura | n | dominanti | trattamento nel fix |
|---|--:|---|---|
| **both_roles** | 208 | disease_vs_normal 107, small_molecule 48 | REM per-studio (control nel cluster, via comparison) |
| **treated_only** | 295 | small_molecule 175, cytokine 46, pathogen 30 | REM per-studio (control da record fratello, via comparison) |
| altro (perlopiù vehicle_only) | 147 | vehicle_only 118 | **escluso** (non perturbazione) |

197 entità distinte perché la stessa entità compare a più livelli L2/L3/L4.

## 3. Decisioni prese (brainstorming 2026-07-05)

1. **Metodo statistico = REM per-studio uniforme.** Un solo macchinario per both_roles E treated_only:
   per ogni studio, effect-size limma-voom trattato-vs-controllo (controllo dello **stesso studio**) →
   `metafor::rma` REM su k studi. Modella esplicitamente I²/τ². Coerente col benchmark DE dell'utente
   (limma-voom migliore per n piccoli, memoria `user_de_methods_benchmark`). Riusa ~90% del macchinario
   esistente (`.run_per_study_de_all` → `.run_limma_voom_de` → `.pool_rem_cluster`).
   - *Scartato:* MEGA per both_roles + REM per treated_only (due metodi → confounder metodologico tra
     cluster, viola `feedback_pipeline_config_uniformity`). *Scartato:* mega_aug esteso ai group
     (astrazione hard-coded sul pair `__VS__`, più lavoro architetturale, non modella I²).
2. **Gate di ammissione = porta strutturale + I² a valle.** Nessun gate di omogeneità a monte (v7 già
   verificato 95% omogeneo); `safety_min` **rimosso** dal ramo REM (penalizzerebbe l'eterogeneità che il
   REM deve modellare). Il gate di **qualità** è l'I²/τ² prodotto dal REM, applicato a valle nella
   selezione Layer B.
3. **Studi treated_only senza controllo in-study = ibrido documentato.** REM puro adesso: contribuiscono
   solo gli studi con contrasto in-study valido; i cluster che scendono sotto `k_eff` minimo →
   `non_processable` con reason esplicita (NON augmentati). L'augmentation cross-studio resta un
   eventuale **passo 2 data-driven**, deciso dopo lo smoke gate se troppi nominati cadono.
4. **Soglie = conservativo.** `k_eff ≥ 3` (studi contribuenti dopo linking), `n_min = 2` per braccio
   per-studio (treated ≥2 E control ≥2, limma-voom richiede replica), cap superiore `k ≤ 9` **rimosso**.
5. **Dedup gerarchica = una meta-analisi per entità, al livello a k massimo.** Deliverable = ~197
   meta-analisi (una per entità `(kind_effective, agent_id)`), al livello che massimizza k (spesso L4).
   L'eterogeneità di contesto biologico residua è catturata/dichiarata dall'I²/τ². La selezione Layer B a
   valle può scendere di livello per un'entità con I² troppo alto (i livelli scartati sono tracciati).

## 4. Architettura

Nuovo percorso di pooling `rem_group`. I tre rami esistenti (`rem` pair, `mega` coarse, `mega_aug`)
restano **invariati** — nessuna regressione sui 433 cluster già processati.

Tre pezzi nuovi, isolati e testabili:

### 4.1 Porta di ammissione `rem_group` (`.identify_layer_a_clusters`, `R/stage4-qc.R`)

Ammette un cluster se **tutte**:
- `mode == "group"`;
- `kind_effective` non-degenere: esclude `vehicle_only`, `none`/vuoto, e i generici broad già coperti
  dal ramo `mega` coarse;
- entità nominata specifica: `agent_id` risolto e non generico;
- **nessun** vincolo `safety_min`, **nessun** vincolo di livello `{0,1}`.

L'ammissione qui è **provvisoria** su `k` grezzo: il taglio definitivo `k_eff ≥ 3` avviene a valle nel
dispatch-builder (§4.2), perché `k_eff` si conosce solo dopo il linking dei controlli. Coerente con come
lo Stadio 4 già rimanda decisioni "a counts veri" (`.qc_filter_samples_and_studies`,
`R/stage4-qc.R:104-119`).

**Mutua esclusività col ramo `mega`.** In pratica i coarse (L0/L1, safety alto) e i nominati (L2–L4) non
si sovrappongono; per sicurezza si mette una **precedenza esplicita**: se un cluster soddisfa entrambe le
porte, vince `mega` (già validato). Documentato.

**Dedup a un livello per entità** (dopo l'ammissione provvisoria, prima del dispatch):
- entità = `(kind_effective, agent_id)` (segmenti tier S, invarianti tra livelli);
- per ogni entità si tiene **un** cluster: k più alto, tie-break deterministico `k` desc → `n_total`
  desc → `level` desc → `cluster_id` alfabetico;
- le rappresentazioni scartate sono registrate (`dedup_dropped_for_entity`) per tracciabilità.

### 4.2 Dispatch-builder group-aware (`.build_group_rem_dispatch_from_stage3`, nuovo in `R/stage4-dispatch.R`)

Cuore del fix. Accanto a `.build_study_dispatch_from_stage3` (`R/stage4-dispatch.R:107`, oggi filtrato a
`mode=="pair"`). Per ogni cluster group ammesso:

1. dai suoi `assignments` ricava i `record_id` membri → coppie `(series_id, group_id)` via
   `.split_record_id` (`R/stage4-dispatch.R:79`);
2. per ogni `(series_id, group_id)` treated, cerca in `stage2_master$comparisons` la comparison dove
   `treated_group == group_id` → prende il `control_group` → risolve i `sample_ids` di entrambi i
   replicate_group **dello stesso studio** (via `.lookup_cmp`/`.lookup_rg`, `R/stage4-dispatch.R:64,54`);
3. emette una entry `{study_id = series_id, treated = <sample_ids>, control = <sample_ids>}` per studio;
4. **filtro `n_min = 2`:** scarta le entry con `<2 treated` o `<2 control`;
5. le entry sopravvissute entrano nel `study_dispatch`; il resto del flusso è quello REM esistente.

**Uniformità both_roles / treated_only:** la relazione treated→control vive sempre nelle `comparisons` di
stage2, non nel cluster. Per un both_roles il `control_group` è anch'esso nel cluster, per un treated_only
vive in un record fratello fuori dal cluster — **stesso identico lookup**. Un solo codice.

**`k_eff`** = numero di studi con entry valida. Materializza il caveat SARS: studi treated_only senza
`control_group` ricostruibile (o con `<2` controlli) non producono entry → non contribuiscono.

### 4.3 Dispatch nell'orchestratore (`R/stage4-orchestrator.R`)

`method == "rem_group"` viene instradato nel percorso per-studio DE già esistente
(`.run_per_study_de_all` → `.pool_rem_cluster`), che resta **invariato**. Attenzione: il filtro
`method %in% c("rem","mega_aug")` (`R/stage4-orchestrator.R:33,181`) va esteso per includere
`rem_group`.

## 5. Soglie, ibrido, tracciabilità

- `k_eff ≥ 3`, `n_min = 2` per braccio, cap `k ≤ 9` **rimosso** per `rem_group`.
- Studi senza controllo in-study valido: contati e loggati per cluster (`n_studies_no_control`).
- Cluster con `k_eff < 3` dopo il linking → `non_processable`, reason
  `rem_group_insufficient_in_study_controls` (con `k_grezzo`, `k_eff`, `n_studies_no_control`). **Non**
  augmentati.
- Parametri (`k_eff_min=3`, `n_min=2`, kind esclusi) in `stage4_default_config()`, non hard-coded.

## 6. Output / schema

- I risultati `rem_group` fluiscono nello stesso `cluster_pooled.parquet` con `method = "rem_group"`
  (nuovo valore) + colonne REM standard (`estimate`, `se`, `I2`, `tau2`, `k_used`, prediction interval).
- `run_metadata.json`: nuova config `rem_group_config` + soglie.
- `schema_versions` bump per il ramo (evita output stale da cache, memoria
  `feedback_bump_lookup_cache_version`).

## 7. Testing e validazione

**TDD bite-sized** (`feedback_no_fretta_paper_grade`):
- `.build_group_rem_dispatch_from_stage3`: fixture stage2_master sintetico — both_roles (control nel
  cluster), treated_only (control in record fratello), studio senza control → escluso, `<2` control →
  escluso, `k_eff` corretto.
- porta `rem_group`: nominato L4 ammesso, vehicle_only escluso, coarse L0/L1 → `mega` (mutua
  esclusività), dedup per entità tiene il k massimo.
- integrazione: cluster group fittizio → dispatch → `.run_per_study_de_all` → `.pool_rem_cluster` con
  `method="rem_group"`, colonne REM corrette.
- retrocompat: rem/mega/mega_aug invariati (non-regressione).

**Smoke gate (validate-before-fullrun, `feedback_validate_before_fullrun`):** su un sottoinsieme dei
nominati veri (SARS, enzalutamide, Breast, Prostatic, Alzheimer, fulvestrant, tamoxifen, vemurafenib):
(a) entrano nella porta, (b) il dispatch recupera i controlli in-study, (c) `k_eff` sensato, (d) il REM
produce estimate/I²/τ² ragionevoli. **Più il report dei cadenti** (quante/quali entità sopravvivono a
`k_eff≥3`, quante cadono). Gate esplicito prima del fullrun; se cadono troppe → decisione data-driven su
passo-2 augmentation (fuori scope).

**Run gated (gate utente separato):** re-pool Stadio 4 completo su `/sda`, adattando lo script v7
(`analysis/p4-fase-f5-stage4-layer-a-rebuild-v7.R`) → output `-stage4-v8`. **Non** richiede re-cluster
Stadio 3 (cluster v7 già omogenei). `setsid` per il detached multi-ora
(`feedback_setsid_for_long_detached_runs`), monitor via `pgrep`. Alternativa DGX (2TB RAM,
`user_dgx_backup_2tb`) se serve.

**Chiusura:** re-gate coerenza + finding + CLAUDE.md + ledger `.superpowers/sdd/progress.md` + memoria.
Master invariato, no push.

## 8. Cosa NON fa (limiti espliciti)

- **Non** implementa augmentation cross-studio (ibrido documentato: eventuale passo 2 data-driven).
- **Non** tocca il pooling MEGA/mega_aug/rem esistente (nessuna regressione).
- **Non** ripara la coda mal-nominata (LPS→"carnitine", ecc.): è la **pulizia-nomi con Mistral**, handout
  separato `2026-07-06-name-cleanup-mistral-SESSION-AFTER-handout.md`, da fare dopo.
- **Non** richiede un nuovo re-cluster Stadio 3.

## 9. Riferimenti

- Finding: `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`
- Triage evidenza coerenza: `analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv` (+ script
  `-coherence-check.R`/`-nametail.R`)
- ADR correlati: 0019 (metadata v2), 0021 (metrica consistenza F6); nuovo **0022** (questo fix).
- Memorie: `project_stage3_minestrone_rework`, `feedback_validate_before_fullrun`,
  `feedback_explain_then_decide`, `feedback_no_fretta_paper_grade`, `feedback_pipeline_config_uniformity`,
  `feedback_setsid_for_long_detached_runs`, `feedback_bump_lookup_cache_version`,
  `user_de_methods_benchmark`.
