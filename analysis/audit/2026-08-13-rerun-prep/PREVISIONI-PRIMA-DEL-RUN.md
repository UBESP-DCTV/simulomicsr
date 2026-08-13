# Le previsioni, depositate PRIMA del run

**Scritte:** 2026-08-13, dopo l'implementazione dei tre cambi e prima di
qualunque re-cluster o re-pool. **Nessun run lanciato.**

Sono calcolate col codice di produzione sui dati veri di v15
(`analysis/audit/2026-08-13-rerun-prep/`, script `D1-`, `D2b-`, `D3D4-`, `P5-`).

---

## ⚠️ La condizione sotto cui valgono

**Valgono a parità di Stadio 1 e Stadio 2.** Se il re-run rifà anche gli stadi
LLM — ed è il mandato — non valgono più, e il perché è misurato: senza
`VLLM_BATCH_INVARIANT=1` due esecuzioni identiche dello Stadio 1 davano lo stesso
record completo solo nel **40,4%** dei casi (Stadio 2: 62,0%). La flag rende
riproducibile il run **nuovo**; non fa coincidere il nuovo col vecchio. I campi
che contano cambiavano fra due giri nel **14,0%** (`agent_normalized.id`),
**10,6%** (`cell_context`), **8,0%** (confronti dello Stadio 2 per identità dei
campioni), **7,0%** (`primary_role`).

Chi confronta il deliverable nuovo con questi numeri sta misurando **due cose
insieme**: i tre cambi e il rifacimento degli stadi LLM.

---

## 1. Il deliverable

| | v15 | previsto |
|---|---:|---:|
| candidati (gate `k>=3` Stadio 3) | 351 | **351** |
| righe del deliverable (`k_eff>=3`) | 214 | **212** |
| non processabili | 137 | **139** |

Scomposizione delle due righe perse:

1. **−1** `cgroup_L5_4f4d9051` «Tumor Necrosis Factor-alpha» (k_eff 6): non è
   persa, è **assorbita** dalla fusione nel TNF `cgroup_L5_d9e23e09`, che passa
   da 32 a 38 studi (32 + 6, insiemi disgiunti).
2. **−1** `cgroup_L5_034592d9` *Staphylococcus epidermidis*: k_eff 3 → 2 per il
   collasso delle corsie (GSE173902).
3. **+0** infigratinib `cgroup_L5_889ae73b`: entra fra i candidati (k Stadio 3
   2 → 3 per la fusione) ma **non nasce come meta-analisi**, k_eff 1 → 2 < 3.

## 2. I k_eff attesi, gruppo per gruppo

| gruppo | entità | v15 | previsto | causa |
|---|---|---:|---:|---|
| TNF | `HGNC:11892` | 32 | **38** | fusione col registro CHEMBL |
| ipossia | `STR:hypoxia` | 25 | **33** | fusione `normoxia` → `vehicle_untreated` |
| SARS-CoV-2 | `NCBITaxon:2697049` | 34 | **36** | fusione `uninfected`, solo per questa entità |
| IL-6 | `HGNC:6018` | 10 | **11** | fusione col registro MeSH |
| IL-15 | `HGNC:5977` | 3 | **5** | fusione col registro CHEMBL |
| IFN-γ | `HGNC:5438` | 20 | **19** | corsie |
| IL-4 | `HGNC:6014` | 10 | **9** | corsie |
| IL5RA | `HGNC:5973` | 12 | **11** | corsie |
| IMPDH2 | `HGNC:14900` | 6 | **5** | corsie |
| *S. aureus* | `NCBITaxon:1280` | 4 | **3** | corsie |
| *S. epidermidis* | `NCBITaxon:1282` | 3 | **2** | corsie → **esce** |
| endotelina-1 | `CHEBI:80240` | 1 | 2 | fusione; resta fuori |
| infigratinib | `CHEBI:63451` | 1 | 2 | fusione; resta fuori |

## 3. Il dispatch

- entry: **2.152 → 2.146**. I sei che cadono sono tutti di **GSE173902**.
- nessun altro studio perde entry.

## 4. Gli scarti del gate di riga (Stadio 3)

- **5 confronti** con la genetica su un braccio solo dentro i 351 candidati
  (v15: 0), in 3 gruppi: ATRA `cgroup_L5_37942548` (1), Nutlin-3a
  `cgroup_L5_35d1be10` (2), bleomicina `cgroup_L5_79ce3bd1` (2).
- **Nessuno dei 5 era poolato** (un braccio sotto `n_min`): l'effetto sul
  `k_eff` è **zero**. Cambia un solo `k` di Stadio 3: bleomicina 10 → 9.
- Sul corpus intero: **+271** confronti acquistano la segnalazione, **−77** la
  perdono, in 132 studi.

## 5. Che cosa falsificherebbe queste previsioni

- una riga in più o in meno oltre le due dichiarate;
- infigratinib che compare fra le meta-analisi (vorrebbe dire che il gate finale
  non è sul `k_eff` come misurato qui);
- un k_eff diverso da quelli della tabella su uno qualsiasi degli 11 gruppi;
- entry del dispatch diverse da 2.146;
- confronti scartati per genetica diversi da 5, o in gruppi diversi dai 3.

**Limite dello strumento, dichiarato:** il `k_eff` calcolato dal dispatch non
applica il pre-filtro H5 del re-pool (campioni assenti dall'H5, `lib_size` sotto
500k) ed è quindi un **limite superiore**. Su v15 lo scarto misurato con
`k_effective` era 0 su tutti e 214.
