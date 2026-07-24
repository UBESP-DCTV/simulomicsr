# Finding — Rework anchoring Stadio 3: causa radice provata + simulazione di coerenza dei design candidati

**Data:** 2026-07-24
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, nessun re-cluster)
**Handout:** `docs/superpowers/specs/2026-07-24-stage3-anchor-coherence-rework-HANDOUT.md`
**Spec di design (opzioni + decisione):** `docs/superpowers/specs/2026-07-24-stage3-contrast-anchor-design.md`
**Predecessore:** `docs/findings/2026-07-23-stage3-cluster-coherence.md` (26/184 difendibili)
**Codice/evidenza:** `analysis/audit/2026-07-24-anchor-coherence-sim/`

---

## 0. In una riga

La causa radice del minestrone è **provata e quantificata**: l'anchor è **comparison-blind** — ancora
sull'entità del **campione trattato**, non su ciò che il **contrasto isola** (il delta trattato↔controllo).
Simulando i design candidati sui contrasti già ricostruiti (nessun re-cluster), con verifica LLM sui
dati reali: **il fix del solo controllo (Design A) è INSUFFICIENTE (rescue 11%)**; un anchor **derivato
dal contrasto (delta-entity, Design B/C)** è **coerente all'80-89%** e trasforma i minestroni noti in
meta-analisi pulite (SARS→"SARS-CoV-2 vs mock", enzalutamide, fulvestrant, osimertinib, HCC…). **Costo:
k crolla** (mediana 8→3-4; le malattie collassano). Numeri sotto. **Nessun re-cluster lanciato: la
decisione di design è dell'utente.**

> ⚠️ Nessuna dichiarazione "finale/paper-grade": questo è un design **validato sulla coerenza su
> campione**, non un deliverable. Il re-cluster (~8h) + re-pool (~50h) restano gated dietro la scelta
> dell'utente.

---

## 1. Causa radice PROVATA — l'anchor è comparison-blind

L'anchor v3.1 codifica 13 segmenti che descrivono **solo il lato trattato** (kind, agent, cell context,
tissue, disease). L'entità (`agent_id`) è scelta dalla **perturbazione primaria del campione trattato**
(Stadio 1, sample-level) — **indipendentemente dal confronto**. Il controllo non entra mai nell'anchor
(tranne i pair, 5%). Conseguenza: se una perturbazione è **costante** tra trattato e controllo, diventa
comunque l'anchor, e il cluster raccoglie contrasti diversi.

**Prova sui `factor_levels` reali (SARS `group_L4_b6a3eabd`):**

| studio | trattato (factor_levels) | controllo | DELTA (cosa cambia) |
|---|---|---|---|
| GSE147507 | `treatment=Ruxolitinib; virus=SARS-CoV-2` | `virus=SARS-CoV-2` | **+Ruxolitinib** (SARS costante) |
| GSE151513 | `infection_status=infected` | `infection_status=control` | **infezione** |
| GSE154613 | `infection_status=infected; treatment=RS504393` | `infection_status=infected; treatment=DMSO` | **+RS504393** (infezione costante) |
| GSE167131 | `viral_infection=SARS-CoV-2` | `viral_infection=mock` | **infezione** |

Sotto l'anchor "SARS-CoV-2" convivono un contrasto **infezione**, uno **farmaco (ruxolitinib)**, uno
**farmaco (RS504393)**, KO genetici… — perché SARS è la perturbazione più saliente del campione, non
ciò che ogni confronto isola. **Nei bracci farmaco/genetici SARS è HELD-CONSTANT** (presente in entrambi
i lati): l'anchor ha ancorato su una costante.

**Quantificazione a scala** (7.886 cluster k≥2 con ≥1 contrasto ricostruibile; `40-mechanisms.R`):
tra i **1.674 cluster con k≥3 studi risolti**,
- **59,8%** mescola **≥2 classi-contrasto** distinte (drug/infection/genetic/disease),
- **28,4%** ne mescola **≥3**,
- **76,8%** mescola **≥2 tipi-controllo** distinti.

I minestroni del deliverable (finding 2026-07-23) hanno **mediana 3 classi-contrasto** e **5 tipi-controllo**;
i coerenti 1,5 e 3. **Due meccanismi, entrambi misurati:** (1) contrasti diversi sotto lo stesso anchor
(controllo libero / anchor su costante); (2) entità trattata troppo grezza (malattie diverse fuse). I
184 per classe dominante × verdetto:

| classe | coherent | minestrone |
|---|---:|---:|
| drug | 12 | 93 |
| disease | 9 | 50 |
| infection | 2 | 5 |
| genetic | 0 | 4 |

Sia **drug** sia **disease** (i due kind più numerosi) sono dominati dal minestrone → il fix deve
toccare **l'entità trattata E il controllo**, non uno solo.

---

## 2. Metodo di simulazione (validate-before-fullrun, nessun re-cluster)

Per misurare un design **senza** il re-cluster (~8h), si riparte dai **contrasti già ricostruiti** per
ogni membro (`per-member-contrasts.parquet`, 38.440 membri risolti, 7.886 cluster; via il dispatch reale
Stadio 4). Per ogni membro si calcola una **firma di contrasto** (`contrast-sig-engine.R`):
- `ct` = classe del controllo (`.normalize_control_type`, esistente);
- `dominant` = **classe semantica della dimensione che cambia** nel delta dei `factor_levels`
  (drug/infection/genetic/disease/environment/time), robusta perché usa le CHIAVI (più canoniche dei valori);
- `entity` = valore trattato normalizzato della dimensione che cambia (per la granularità).

Poi si **ri-partiziona ogni cluster esistente** per chiave-design e si misura la coerenza dei
sotto-cluster risultanti: (a) deterministica per costruzione; (b) **verifica LLM** su un campione con la
**rubrica identica al deep-dive 2026-07-23** ("un contrasto o molti?", i subagent vedono solo i contrasti
reali, nessun verdetto atteso).

**Design misurati** (chiave di ri-partizione entro-cluster):
- **DA — contrast-anchor**: `(cluster, control_type)` — aggiunge SOLO il controllo (estende ai group la
  logica pair `treated__VS__control`).
- **DB — +classe-contrasto**: `(cluster, control_type, classe)` — separa drug/infection/genetic/disease.
- **DC — +delta-entity (fine)**: `(cluster, control_type, classe, entità)` — coerente per costruzione
  (un controllo, una classe, un'entità). **Proxy dell'anchor derivato-dal-contrasto.**

**Limite dichiarato:** la ri-partizione **entro-cluster** è un **LOWER BOUND**: cattura gli SPLIT (che
alzano la coerenza) ma NON i MERGE cross-cluster (i frammenti ruxolitinib-in-SARS non si fondono con un
cluster ruxolitinib altrove). Il k reale di un anchor derivato-dal-contrasto è **≥** quello simulato.

---

## 3. Risultati misurati

### 3.1 Conteggi a scala (tutti i 7.886 cluster risolvibili)

| design | sotto-cluster | poolabili k≥3 | k≥5 | coerenza LLM (campione) |
|---|---:|---:|---:|---|
| Baseline (anchor v10) | 7.886 | 1.674 | 586 | ~14% (26/184 sul deliverable) |
| **DA** control-type | 13.966 | 945 | 321 | **3/28 = 11%** |
| **DB** +classe | 15.582 | 815 | 243 | — |
| **DC** +delta-entity | 24.329 | **126** (107 classificati) | 26 | **16/20 = 80%** (89% escl. `<none>`) |

### 3.2 Design A (solo controllo) è INSUFFICIENTE — 11% (3/28)

Split per `control_type` su 28 sotto-cluster k≥3 dei 184 (verifica LLM): **25/28 restano minestrone**.
Il normalizzatore collassa mock/DMSO/untreated/PBS/healthy in `vehicle_untreated`, così il TRATTATO
resta eterogeneo. Esempio `group_L4_a54e9090||vehicle_untreated` (k=64): dopo lo split contiene ancora
RA + NaCl osmotico + vaccino + melanoma anti-PD-1 + trapianto + ACS. I 3 rescue sono cluster il cui
anchor era **già** un'entità specifica (R1881, fulvestrant, AML) → DA aiuta solo dove il problema non
c'era. **Il controllo da solo non basta: va toccata l'entità trattata.**

### 3.3 Design B/C (delta-entity) — 80-89% coerente, i minestroni noti si sciolgono

Su 20 sotto-cluster DC k≥3 (verifica LLM): **16/20 = 80% `one_contrast`** (89% escludendo la classe
`<none>`). Prove reali:
- **SARS `b6a3eabd`** → il sotto-cluster delta-entity `…||drug||sars cov` è **"SARS-CoV-2 infection vs
  mock/uninfected"** = `one_contrast`. Il minestrone si è sciolto nel contrasto infezione pulito.
- `one_contrast` verificati: **enzalutamide, R1881, fulvestrant, osimertinib, vemurafenib, palbociclib,
  HCC-vs-normale** — ciascuno un'entità vs il suo veicolo/normale, su linee/tessuti diversi (covariata).
- I **4 falliti**: 2 sono classe **`<none>`** (delta non classificabile / normale-vs-normale degenere →
  vanno **scartati**, non poolati); 2 sono confondimenti **sottili sul controllo** (estradiolo-solo vs
  estradiolo+fulvestrant; tamoxifene puro vs resistenza+tamoxifene) — difficili anche per il design fine.

### 3.4 Il trade-off k↔coerenza, misurato

- **k crolla**: mediana dei poolabili 8 (baseline) → 3-4 (DC). k≥5 da 586 → 22.
- **Le malattie collassano di più**: DC produce 91 poolabili **drug** (k_med 3, k_max 18) ma solo **13
  disease** (k_med 3, k_max 6) — perché ogni malattia specifica ha pochi studi. La granularità disease
  (meccanismo 2) è **intrinsecamente low-k**.
- **Stima difendibili (lower bound within-cluster):** ~**95-107** meta-analisi difendibili k≥3 (107
  poolabili classificati × ~89% coerenza). Il valore reale è più alto grazie ai merge cross-cluster non
  simulati (vedi §3.5: la sola SARS recupera k=7→15 con l'entità canonica).
  **Confronto onesto sui denominatori:** i **26** di oggi sono i difendibili DENTRO il deliverable di 184
  `rem_group`; i **~95-107** sono su TUTTI i 7.886 cluster risolvibili. Non è 26→107 sullo stesso insieme:
  è "il deliverable passa da 184 cluster (14% difendibili) a ~100+ cluster **tutti** difendibili".
  L'obiettivo del paper non è massimizzare il conteggio ma rendere **ogni** cluster difendibile
  (clustering irreprensibile); il conteggio ~100+ è la conseguenza, non il gate.

### 3.5 Caveat CRUCIALE — l'entità grezza-da-label sovra-frammenta

Il DC usa l'entità estratta dai **label grezzi** ("TNF (10 ng/ml)" vs "3998MEL TNF" → stringhe diverse).
Questo **spezza anche i 26 cluster oggi coerenti**: solo **8/26** mantengono un sotto-cluster k≥3
(mediana maxk=2). Cioè la sovra-frammentazione del DC è in gran parte **artefatto di rumore delle label**,
non granularità reale.

**Esempio concreto (SARS `b6a3eabd`):** lo stesso contrasto "SARS-CoV-2 infezione vs mock" viene spezzato
dal proxy in **3 sotto-cluster** — `…||drug||sars cov` (k=7), `…||infection||infected` (k=4),
`…||infection||sars cov` (k=4) — solo per inconsistenza della classe (chiave `perturbation`/`exposure`
finisce in "drug" invece di "infection") e della normalizzazione ("infected" vs "sars cov"). Con l'entità
**canonica** (SARS-CoV-2 → `NCBITaxon:2697049`) e una classe stabile, i 3 diventano **un k=15** coerente.
È la prova diretta che il proxy sotto-stima il k e che il resolver canonico (Opzione B) lo recupera. **Conseguenza per il design vero:** l'entità del delta va **canonicalizzata col
resolver esistente** (HGNC/ChEBI/MeSH/ChEMBL, già maturo dopo v5-v10), NON presa dai label. Con l'entità
canonica: (a) i sinonimi non frammentano → k recuperato; (b) i 26 coerenti restano interi. Questo è
esattamente il **lavoro di build** del re-cluster — motivo per cui la misura si ferma qui e la decisione
è dell'utente.

---

## 4. Cosa dice tutto questo per il design (dettaglio nella spec)

1. **Il controllo da solo (Design A) NON basta** (11% misurato). Chi propone "aggiungi il control-type e
   basta" è smentito dai dati.
2. **L'anchor va derivato dal CONTRASTO**: entità = perturbazione **presente nel trattato e assente nel
   controllo** (il delta), canonicalizzata col resolver; + tipo-di-controllo per disease/none. Questo
   riusa TUTTA la macchina dei nomi — le dà solo l'entità GIUSTA (il delta, non il campione).
3. **Scartare** i contrasti a delta `<none>`/solo-nuisance e i degeneri (non sono contrasti).
4. **Trade-off da decidere con l'utente**: coerenza forza k basso; le malattie collassano. Meglio ~100
   meta-analisi difendibili (molte k=3-4, forza da riportare via consistenza ADR-0021) che 184 minestroni.

---

## 5. Deliverable / riproducibilità (`analysis/audit/2026-07-24-anchor-coherence-sim/`)

- `contrast-sig-engine.R` — firma di contrasto (parse factor_levels, classificatore chiave→classe, delta).
- `10-simulate-designs.R` (scala) · `20-simulate-184.R` (deliverable) · `40-mechanisms.R` (meccanismi).
- `30-gen-verification-bundles.R` — bundle per la verifica LLM (formato deep-dive).
- `llm-verdicts-sample.jsonl` — 48 verdetti LLM (28 DA + 20 DC) con motivazione citante le label reali.
- `design-comparison.csv`, `dc-poolable-by-class.csv` — tabelle di sintesi.
- Input riusati: `analysis/audit/2026-07-23-coherence/{per-member-contrasts.parquet,cluster-verdicts.rds}`.

## 5bis. Nota sui contrasti degeneri (errore di etichettatura Stadio 2) — provenienza onesta

Il drop dei **degeneri** (`treated_label == control_label`) fa parte del design (decisione utente). Per il
record: **NON era un difetto pre-misurato/validato sullo Stadio 2.** La validazione Stadio 2 (F3/F4,
smoke gate, accuracy ~94% su `design_role`) misurava se i ruoli-campione erano classificati bene, **non**
se ogni comparison ricostruita avesse trattato≠controllo. Il degenere è **emerso come sottoprodotto della
verifica di coerenza 2026-07-23** (ricostruendo i contrasti col dispatch Stadio 4 si vede che alcune
comparison hanno label identiche). Anche la misura fu raffinata in corsa: il 1° rilevatore (via
`factor_levels`) dava falsi positivi → fix a uguaglianza del `label_human` (54→13 sui 184).

**Magnitudine reale (misurata 2026-07-24, `degen.R`):** **264/38.440 membri risolti = 0,69%** degeneri;
**183 cluster** hanno ≥1 membro degenere; **49 cluster interamente degeneri** — ma **0 di questi raggiunge
k≥3** (la soglia k≥3 elimina da sola i cluster interamente degeneri; restano da droppare i **membri**
degeneri sparsi dentro cluster altrimenti validi). **Giustificazione del drop:** una comparison con
trattato==controllo non ha alcun contrasto da stimare (confronta una cosa con sé stessa) → input invalido
per definizione, a prescindere dalla statistica. **Caveat:** rilevamento label-based → conservativo (una
coppia "degenere" potrebbe essere un contrasto reale mal-etichettato, es. dose/timepoint collassati nella
label); magnitudine comunque minima (0,69%). È un problema di **qualità Stadio 2 ortogonale**, piccolo,
non il cuore del minestrone.

## 6. Limiti (dichiarati)

- **Lower bound**: ri-partizione entro-cluster, no merge cross-cluster → k e conteggio difendibili
  sotto-stimati per l'anchor derivato-dal-contrasto.
- **Entità grezza-da-label** sovra-frammenta (§3.5); il design vero usa il resolver → misurabile solo
  costruendolo.
- **Verifica LLM su campione** (28+20), non censimento; rubrica conservativa. I 4 falliti DC sono
  diagnosticati (`<none>` + confondimenti controllo).
- **Copertura ricostruzione**: solo i membri con contrasto ricostruibile (~69% dei poolati); i treated-only
  non entrano (ma non erano poolati, L7).
