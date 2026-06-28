# Spec — Recupero nome farmaci/composti con ChEMBL + ri-clustering Stadio 3 v5 (Opzione B)

**Data:** 2026-06-28
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, no push)
**Template:** clone di `2026-06-25-stage3-name-recovery-reclustering-design.md` (rework malattie/MeSH),
sostituendo "MeSH/malattia" con "ChEMBL/farmaco". Vedi handoff
`2026-06-28-stage3-perturbative-name-recovery-B-handoff.md`.

> Regola d'oro (handoff): **riusa la stessa struttura del rework malattie**, cambia
> solo il database (ChEMBL al posto di MeSH). L'unico pezzo davvero nuovo è
> l'estrazione del nome-farmaco dal rumore (dose/tempo/combo), resa necessaria dai dati.

---

## 1. Problema

Il rework malattie (v4) ha portato il minestrone `disease_vs_normal` dal 63,7% al 7,7%.
Restano sporchi i cluster **perturbativi**: `small_molecule` 49,0%, `cytokine_stim` 63,6%,
`pathogen` 38,2% (gate omogeneità v4, Task 16). La causa misurata è la **copertura del
naming**: i composti fuori da ChEBI restano `UNK`/`STR:<slug>`, l'anchor collassa sul
tessuto, e composti diversi finiscono nello stesso cluster.

### Evidenza misurata (sessione 20, 2026-06-28)

Sondaggio a freddo sul gate v4 (`scratchpad/survey-*.R`):

- Token ID nei cluster perturbativi: **STR 1591 · CHEBI 863 · HGNC 6** → ~65% degli
  ID distinti sono fuori-ontologia (STR).
- I 648 slug STR distinti sono **bimodali**:
  - **~265 nomi-farmaco reali** (inibitori di chinasi da ricerca + farmaci clinici,
    spesso con sigla-codice: cobimetinib=GDC-0973, ABT-751, KW-2449). **Un DB farmaci li
    nomina.**
  - **~147 codici citochina/patogeno** (LPS, TNF, IFN, IL, TGF, poly(I:C), SARS-CoV-2).
    **Nessun DB di small-molecule li nomina** — sono biologici/esposizioni.
- Il mislabeling del tipo è reale ma piccolo: solo **104/1695 (6,1%)** dei cluster
  `small_molecule` contengono codici citochina/patogeno; le citochine mal-nominate stanno
  per lo più già sotto `cytokine_stim` (tipate giuste, senza nome ontologico).
- **Il clone minimale non basta**: solo **~14%** dei candidati-farmaco matcherebbe ChEMBL
  "a stringa intera"; l'**86%** è rumoroso (`osimertinib_2_um_9d`,
  `treated_for_48_hours_with_10_um_ag1478`) o combo. Il valore sta nell'**estrazione del
  nome dal rumore**.
- Misura a freddo precedente (sessione 19): la **normalizzazione della grafia non aiuta**
  (−0,1pp). Non si tratta di grafia, ma di copertura del naming. Confermato.

### Radice nel codice

`recover_identity` (`R/stage3-name-recovery.R`, passo 3) per i kind perturbativi chiama
`.extract_agent_term` → `.normalize_compound_to_chebi`, che fa **un solo lookup esatto su
stringa intera** contro ChEBI (`.chebi_lookup_alias`). Se manca → `STR:<slug>`. Mancano:
(a) una seconda sorgente di nomi (ChEMBL); (b) l'estrazione tollerante del nome dal termine
rumoroso.

## 2. Decisioni (gate utente, sessione 20)

| # | Decisione | Scelta |
|---|---|---|
| Scope | quali entità in questa sessione | **Solo farmaci/small-molecule.** Biologici citochina/patogeno + fix-tipo K3 → **sessione futura, brainstorming dedicato** (TODO). |
| DB | quale database esterno | **ChEMBL** (dump SQLite, licenza aperta CC BY-SA, copertura ottima sui composti da ricerca + sigle-codice; meglio di DrugBank su copertura e licenza). |
| Canonicalizzazione | che ID emettere | **ChEBI-preferred**: ChEBI resta primario; se risolve solo ChEMBL, si ri-mappa il `pref_name` canonico ChEMBL contro ChEBI (de-frammentazione); altrimenti `CHEMBL:<id>` nativo. |
| Gate precisione | match esatto vs fuzzy | **Esatto su alias controllato, NO fuzzy** (lezione C1). Un candidato emette un ID solo se matcha esattamente un alias ChEBI/ChEMBL. |
| Estrazione | come agganciare nomi rumorosi | Estrazione deterministica conservativa: stringa intera → spoglia rumore dose/tempo → split su congiunzioni. Pezzo nuovo, data-driven. |
| Combo | 2+ farmaci distinti | **ID-combo deterministico ordinato** (`CHEBI:a+CHEBI:b`): combo identiche cross-studio si raggruppano tra loro, separate dai singoli. |

## 3. Architettura

Clone 1:1 del rework malattie. Le modifiche toccano gli stessi file, con la stessa forma.

### 3.1 Acquisizione ChEMBL — `analysis/p5-audit-chembl-build-dict.R` (nuovo)

Clone di `analysis/p5-audit-chebi-build-dict.R`. Input: dump SQLite ChEMBL 37
(`chembl_37_sqlite.tar.gz`, 5.4G → ~25G estratto su `/sda`). Lettura via **DBI/RSQLite**
(già presenti sotto renv, nessuna nuova dipendenza). Output:
`cache/chembl/chembl-lookup.rds`, **stessa forma di ChEBI**:

- `$by_id`   tibble (`chembl_id`, `pref_name`, `pref_name_lower`) — da `molecule_dictionary`.
- `$aliases` tibble (`alias_lower`, `chembl_id`, `type`) — da `molecule_synonyms`
  (sinonimi, research codes, trade names) ∪ `pref_name`.
- `$meta`    list (release, n_molecules, n_synonyms) per `ontology_releases` nel run_metadata.

Tabelle ChEMBL rilevanti: `molecule_dictionary` (molregno, chembl_id, pref_name),
`molecule_synonyms` (molregno, synonyms, syn_type). Join su `molregno`. Lo script estrae
solo queste, scrive un RDS piccolo (~MB), **scarta il `.db`** da 25G dopo il build.
(Verificare in fase di build se `molecule_dictionary` espone un xref ChEBI diretto; se sì
lo si registra, ma la de-frammentazione §3.3 **non ne dipende**.)

Provenienza/SHA256 del dump registrati come per gli altri dump (riproducibilità paper-grade).

### 3.2 Loader + accessor — `R/ontology-lookup.R` (clone esatto)

- `.load_ontology_dicts` carica anche `chembl` (4° dizionario) accanto a chebi/hgnc/mesh.
  Mini-fixture `chembl-mini.rds` in `inst/extdata/ontology-fixtures-mini/` per i test.
- `.build_chembl_index(chembl_raw)` — costruisce hash-env `by_id` + `aliases`, identico per
  forma a `.build_chebi_index`.
- Accessor `.chembl_lookup_alias(synonym, env)` (sinonimo→`{chembl_id, type}`) e
  `.chembl_lookup_id(chembl_id, env)` (`chembl_id`→`{chembl_id, pref_name}`), stessa firma/
  stile/difensività (`.normalize_key_chr`, NULL su miss) degli accessor esistenti.
- `.ontology_release_meta` include `chembl`.
- **Retrocompat (graceful, rivisto in esecuzione 2026-06-28):** ChEMBL è caricato **se
  presente**; se il dict reale manca, `env$chembl <- NULL` + flag `has_chembl=FALSE` (gli
  accessor tornano NULL → comportamento v4), **senza `stop()`**. Il fail-loud "ChEMBL
  obbligatorio" NON sta nel loader (romperebbe ogni percorso anchor) ma è spostato come
  **assert a runtime** negli script di re-cluster/re-pool v5 (§3.6): asseriscono
  `.load_ontology_dicts()$has_chembl` prima di girare. ChEBI/HGNC/MeSH restano obbligatori.
  (Motivo: lo `stop()` nel loader rompeva `test-anchor-parse.R` e ogni build di anchor —
  vedi ledger Task 4.)

### 3.3 Risoluzione composto — `R/stage3-name-recovery.R`

`.normalize_compound_to_chebi` → estesa **in place** (nome invariato per diff minimo: è
`@keywords internal`, unico chiamante `recover_identity`; ora emette anche ID ChEMBL/combo
oltre a ChEBI/STR). Firma invariata `(term, ontology_env)`. Catena **precisione-prima**
applicata a ogni candidato prodotto da `.extract_compound_candidates` (§3.4), nell'ordine:

1. `.chebi_lookup_alias(cand)` → `CHEBI:<id>`, source `CHEBI_ALIAS` (invariato).
2. altrimenti `.chembl_lookup_alias(cand)` → preso `pref_name` via `.chembl_lookup_id`:
   - `.chebi_lookup_alias(pref_name)` → `CHEBI:<id>`, source `CHEMBL_VIA_CHEBI`
     (**de-frammentazione**: `gdc_0973`→ChEMBL→"cobimetinib"→`CHEBI:90217`).
   - altrimenti `CHEMBL:<chembl_id>`, source `CHEMBL_ALIAS`.
3. altrimenti il candidato non risolve.

Esito sui candidati:
- **0 risolti** → `STR:<slug(term)>`, source `STR_FALLBACK` (invariato, U1).
- **1 distinto risolto** → quell'ID.
- **≥2 ID distinti risolti** (combo) → ID-combo ordinato `paste(sort(unique(ids)), collapse="+")`,
  source `COMPOUND_COMBO`. (Sigle nome+codice dello stesso farmaco collassano a 1 ID, quindi
  non sono combo.)

`recover_identity` (passo 3): invariato nello scheletro; consuma il nuovo ritorno. I 5
valori di `recovery_source` perturbativi diventano: `CHEBI_ALIAS`, `CHEMBL_VIA_CHEBI`,
`CHEMBL_ALIAS`, `COMPOUND_COMBO`, `STR_FALLBACK`, `NO_RECOVERY`.

### 3.4 Estrazione tollerante — `.extract_compound_candidates(term)` (nuovo)

Funzione **pura, deterministica, conservativa**. Da un termine (es.
`"10 um enzalutamide and 30 nm onvansertib"`) produce un **vettore ordinato di candidati**
da provare contro la catena §3.3:

1. **stringa intera** normalizzata (lowercase, trim) — prima, così nomi con underscore
   interni (`kj_pyr_9`, `5_aza_cdr`) si provano interi e non si frantumano.
2. **versione spogliata dal rumore dose/tempo**: rimuovi token `\\d+(\\.\\d+)?\\s*(um|µm|nm|mm|ng|mg|ug|iu|u|m)\\b`,
   `for\\s+\\d+\\s*(h|hr|hours|d|days|min)`, `\\b\\d+\\s*(h|hr|d|days|min)\\b`, `treated|exposed|stimulated|condition|induction`.
3. **split su congiunzioni** `\\b(and|plus|with|\\+|&)\\b` → ogni sotto-stringa (ri-spogliata)
   è un candidato a sé.

**Gate di precisione (C1-safe)**: un candidato conta solo se, dopo lo strip, ha
**lunghezza ≥ 3 e non è puramente numerico**, e matcha **esattamente** un alias controllato.
Token come `1`, `s`, `so` non sono alias → non matchano mai (`10_nm_1`→STR, sicuro). Niente
fuzzy, niente prefisso/substring matching.

Output usato da §3.3: l'insieme degli ID risolti dai candidati determina singolo/combo/STR.

### 3.5 Lookup precalcolato — invariato

`build_name_recovery_lookup` (`R/stage3-name-recovery-lookup.R`): **logica invariata** (usa
già `recover_identity` nel ramo composto → eredita ChEMBL). Unica modifica: **bump della
cache version** (la cache disco è version-aware) per invalidare il lookup v4 e forzarne la
ricostruzione con la nuova logica ChEMBL.

### 3.6 Ri-esecuzione a cascata (RUN GATED)

- **Re-cluster Stadio 3 → v5**: `analysis/p4-fase-f6-stage3-reclustering.R` invariato nella
  logica (chiama già `recover_identity`); produce dir `…-stage3-v5-<id>/`. Token `v5`.
  ~6h (Phase 6 summarize domina, come v4).
- **Re-pool Stadio 4 → v5**: copia `analysis/p4-fase-f5-stage4-layer-a-rebuild-v5.R` del
  `-v4`, cambio solo `stage3_dir`→v5 + token output `v5`. ~11h. **Output su `/sda`**.
  ⚠️ Il fix df-residui + tryCatch (commit `0c41848`) è **già committato** → Stadio 4 v5 non
  ri-crasha sullo studio degenere.
- **Re-gate omogeneità su v5**: `analysis/audit/stage3-homogeneity-check.R` sulla dir v5,
  confronto apples-to-apples v4→v5.

## 4. Unità e interfacce

| Unità | File | Cosa fa | Dipende da |
|---|---|---|---|
| `p5-audit-chembl-build-dict.R` | analysis/ | dump SQLite → `chembl-lookup.rds` | DBI/RSQLite, dump ChEMBL |
| `.build_chembl_index` | R/ontology-lookup.R | raw → hash-env | — |
| `.chembl_lookup_alias` / `_id` | R/ontology-lookup.R | O(1) accessor | `.load_ontology_dicts` |
| `.extract_compound_candidates` | R/stage3-name-recovery.R | termine rumoroso → candidati | — (pura) |
| `.normalize_compound` (est.) | R/stage3-name-recovery.R | candidati → ID (ChEBI/ChEMBL/combo/STR) | accessor sopra |
| `recover_identity` | R/stage3-name-recovery.R | orchestratore (invariato) | sopra |

Ogni unità è testabile in isolamento con le mini-fixture (incluso `chembl-mini.rds`).

## 5. Validazione

- **TDD task-by-task** (clone del rework malattie): RED→GREEN→commit per ogni unità.
  Mini-fixture ChEMBL con casi reali del residuo (icotinib, cobimetinib/gdc_0973,
  enzalutamide combo, kj_pyr_9, osimertinib_2_um_9d).
- **Canary di precisione** (C1-style): termini che NON devono risolvere (`10_nm_1`,
  `10um_of_1_so`, numeri puri, token <3 char) → STR, mai un ID spurio. Composti già
  ChEBI-risolvibili → invariati (nessuna regressione).
- **Smoke di copertura PRE-fullrun** ([[feedback_validate_before_fullrun]]): campiona gli
  STR perturbativi del gate v4, gira la nuova `recover_identity`, misura il tasso di
  recupero ChEMBL **prima** del re-cluster da 6h. Gate: recupero atteso ≫ 0 sui ~265
  nomi-farmaco, 0 falsi sui canary.
- **Gate omogeneità v5** (criterio): `small_molecule` scende nettamente sotto il 49% v4;
  invariati o migliori gli altri kind perturbativi non-target (non devono peggiorare).
- Suite intera Stadio 3 verde (retrocompat byte-identica sui rami malattia/genetico).

## 6. Rischi / questioni aperte

- **R1 — copertura ChEMBL reale ignota finché non si scarica.** Mitigazione: smoke di
  copertura §5 prima del fullrun; se il recupero è deludente, si rivede l'estrazione prima
  di spendere 6h.
- **R2 — estrazione troppo aggressiva → falso positivo.** Mitigazione: gate esatto su alias
  controllato + min-length + no-numeric + canary. La precisione viene prima della copertura.
- **R3 — ID-combo ortogonale all'anchor a valle.** Verificare che `paste(...,"+")` non rompa
  il parsing dell'anchor key downstream (`.summarize_clusters`, Stadio 4 matching). Test
  dedicato; se collide col separatore anchor, scegliere un separatore sicuro.
- **R4 — dump da 25G + I/O su NVMe/sda.** Build su `/sda`; osservazione ENOENT transitori
  NVMe sotto I/O pesante (vedi handoff): tenere il dump e l'estrazione su `/sda`.
- **R5 — disallineamento renv** (`out-of-sync`): preesistente, non introdotto qui;
  RSQLite/DBI già disponibili, nessuna nuova dipendenza.

## 7. Conseguenze

- ChEMBL diventa il 4° dizionario ontologico della pipeline; `ontology_releases` lo registra.
- I cluster perturbativi `small_molecule` si de-minestronano per nome farmaco; i biologici
  restano (TODO sessione futura).
- Output v5 (Stadio 3 + Stadio 4) sostituiscono v4 come baseline end-to-end; v4 conservato.

## 8. TODO registrato (sessione futura, brainstorming dedicato)

1. **Biologici citochina/patogeno** (LPS/TNF/IFN/IL/TGF/poly(I:C)/…) + **fix-tipo K3**
   (small_molecule mal-etichettati → pathogen/cytokine). Copertura ontologica debole: serve una
   fonte/vocabolario curato di biologici. È dove `cytokine_stim` resta fermo a ~64%. Dopo i drugs (v5).
2. **🔑 LLM-fallback FINALE (DECISIONE C, generalizzata).** Dopo TUTTO il recupero
   **deterministico** (MeSH malattie + ChEMBL/ChEBI farmaci + vocabolario biologici), le occorrenze
   **ancora non-deterministiche** — i residui `STR:`/`UNK` di **disease + small molecule + farmaci**
   — si tentano di recuperare con un **LLM**, come passo FINALE, **precision-gated** (LLM propone,
   decisione validata contro ontologia/regole per non re-introdurre allucinazioni). Infrastruttura
   eval pronta: `analysis/audit/name-recovery-llm-benchmark.R` (Task 12). Da fare alla fine della
   catena deterministica, brainstorming dedicato.
3. **Scelta DB small-molecule** (deep research in corso): vedi
   `docs/superpowers/specs/2026-06-28-deep-research-small-molecule-db-prompt.md`. Eventuale fonte
   complementare a ChEMBL (es. DrugCentral/GtoPdb per i research compounds, UniChem per i cross-ref).
