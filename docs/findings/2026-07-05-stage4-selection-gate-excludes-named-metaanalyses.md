# Finding — lo Stadio 4 esclude tutte le meta-analisi nominate (gate di selezione)

**Data:** 2026-07-05
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Sessione:** audit RED_ALERT — verifica del deliverable finale (post rebuild v7)
**Artefatti:** `analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv` (197 entità),
`analysis/audit/2026-07-05-stage4-popB-{coherence-check,nametail}.R`.

## In una frase

Il pooling dello Stadio 4 (Layer A) processa **433 cluster su 317.304**, e la porta di
selezione — per come è scritta — **ammette solo anchor grossolani quasi-omogenei** e scarta
*tutte* le meta-analisi cross-studio specifiche e nominate (SARS-CoV-2 25 studi, enzalutamide 25,
Breast Neoplasms 88, …). Il deliverable finale è vuoto delle cose che il progetto promette, **non
perché non esistano ma perché la selezione le respinge**. Il difetto è a valle: la clusterizzazione
(Stadio 3) è sana e omogenea.

## 1. La causa radice (dimostrata)

La lista di ammissione Layer A è `.identify_layer_a_clusters` (`R/stage4-qc.R:11-40`). Tre porte:

| method | requisito (dal codice) |
|---|---|
| `rem` | `mode=pair` + `usable_rem_strict` + k∈[3,9] |
| `mega` | `mode=group` + `usable_mega_strict` + n_studies≥5 |
| `mega_aug` | `mode=pair` + **k==2** + `usable_rem_relaxed` |

E `usable_mega_strict` (`R/stage3-usability.R:44-48`, soglie `R/stage3-config.R`) richiede:

```
mode=group  AND  level ∈ {0,1}  AND  n_studies≥5  AND  n_total≥30  AND  safety_min ≥ 0.7
```

Due requisiti che, combinati, sono **auto-contraddittori** rispetto a dove vivono le meta-analisi vere:

- **`level ∈ {0,1}`** = anchor *grossolano* (tessuto). Il **nome** del composto/malattia vive a
  **L2–L4** (enzalutamide = L4). → nominato ⇒ escluso.
- **`safety_min ≥ 0.7`** = studi *quasi identici*. `safety_min` è l'omogeneità del disegno (frazione
  di campioni che condivide il valore più comune per l'aspetto meno omogeneo). Una meta-analisi
  cross-studio reale ha `safety_min` basso (enzalutamide 0.33, SARS 0.20, Breast 0.14) **per design**:
  25 laboratori con linee cellulari/dosi/tempi diversi. → cross-studio reale ⇒ escluso.

**`usable_mega_relaxed`** (nessun vincolo di livello, `safety_min ≥ 0.5`) *è calcolato nello Stadio 3
ma non consumato da nessuna parte dello Stadio 4* (le uniche occorrenze sono uno script di audit e un
`.md`). Idem per i `pair` k≥3 (il ramo `rem` usa solo `usable_rem_strict`).

**Errore concettuale sotto:** la soglia 0.7 ha senso solo per il **MEGA** (pooling congiunto in un
unico modello, che richiede omogeneità). Ma queste sono target da **REM** (random-effects: modella
l'eterogeneità I²/τ², non la filtra). Lo Stadio 4 applica la mentalità MEGA a tutto e respinge il REM.

## 2. La prova (numeri v7)

- Stadio 3 v7: `analysis/p4-output/20260703T113045Z-stage3-v7-364547a7/` (317.304 cluster).
- Stadio 4 v7: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v7/20260703T230632Z-stage4-v7-4f7ea215/`
  → **433 processati**: 353 `mega_aug` (pair k=2), 72 `mega` (group), 8 `rem`.
- **Dei 72 MEGA processati: 71 sono senza nome** (28 `none`, 21 `environmental`, 9 `vehicle_only`,
  9 malattia coarse, 4 pathogen generico). L'unico nominato è "Neoplasms" (l'etichetta più generica).
- Le meta-analisi nominate multi-studio esistono nello Stadio 3 ma sono `poolable`/processabili = FALSE:
  enzalutamide k=25, SARS-CoV-2 k=25, Breast Neoplasms k=88, Prostatic 17, Alzheimer 14, fulvestrant/
  estradiol 12, vemurafenib 10, tamoxifen 9 — tutte L2–L4, `safety_min` 0.14–0.39.

## 3. I cluster nominati NON sono minestrone (coerenza verificata)

Verifica al livello del **campione membro** (1526 GSM dei 9 bandiera + triage automatico su 650):
confronto anchor vs metadati GEO grezzi.

- **9 bandiera: ~100% coerenti** (SARS 183/183 GSM parlano di SARS/infezione; enzalutamide 123/123;
  Breast 614/614; **0 controlli infiltrati** nei gruppi trattati dei farmaci).
- **Su tutti i 650 (197 entità distinte): 187/197 (95%) internamente omogenei**; solo **6 (3%)**
  sospetti-eterogenei (tutti k=3–4, borderline). Il `safety_min` basso = diversità legittima di
  linea/dose/tempo, **non** biologie mescolate.

**Coda-nome separata:** ~50–70 cluster sono omogenei ma **mal etichettati** (LPS→"carnitine"/"hexanoate",
NSCLC→"Netherlands Antilles", AML→"Antistreptolysin", HCC→"Pemphigoid Gestationis", GBM→"Genes, Viral").
È un problema di **etichetta**, non di clustering: il pooling DE resta valido (raggruppa per struttura
dell'anchor, non per il nome). Si sistema con la pulizia-nomi (handout dedicato). Costo scientifico
della coda: frammenta la stessa biologia sotto nomi diversi (LPS in 2+ cluster) → k reale sottostimato.

## 4. Struttura dei ruoli — scope del fix (650 cluster Pop B)

Il MEGA richiede **≥2 livelli treatment** (`.check_mega_rank`, `R/stage4-orchestrator.R:205`), cioè
treated+control nel cluster. Composizione ruoli (da `primary_role` Stadio 2):

| struttura | n | dominanti |
|---|--:|---|
| **both_roles** (MEGA diretto una volta ammessi) | **208** | disease_vs_normal 107, small_molecule 48 |
| **treated_only** (serve lato-controllo) | **295** | small_molecule 175, cytokine 46, pathogen 30 |
| altro (perlopiù vehicle_only da escludere) | 147 | vehicle_only 118 |

Cioè: **le malattie** (Breast, Prostata, Alzheimer) hanno già caso+normale → poolano subito; **i
farmaci** (enzalutamide, fulvestrant, tamoxifen, estradiol, vemurafenib) sono treated-only → il gruppo
trattato pooled va appaiato a un pool di controllo (augmentation stile `mega_aug`) o portato a REM
per-studio. Vedi handout fix per le opzioni.

## 5. Cosa NON è

- NON è la dedup gerarchica (ipotesi iniziale scartata: i processati coprono L0–L4).
- NON è omogeneità/minestrone della clusterizzazione (95% omogeneo).
- NON è colpa del recupero-nome (i database hanno funzionato; i bandiera sono nominati giusti).
- È **solo** la porta di selezione Stadio 4 tarata MEGA-strict, applicata dove serviva REM/relaxed.
