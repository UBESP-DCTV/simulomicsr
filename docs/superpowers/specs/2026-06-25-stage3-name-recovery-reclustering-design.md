# Spec — Recupero nome (malattia/composto) dai metadati + ri-clustering Stadio 3

- **Status:** Draft (in review utente)
- **Date:** 2026-06-25
- **Owner scientifico:** lucavd · **Owner esecutivo:** Claude Code
- **Contesto:** RED ALERT FASE F6 → durante la selezione del pilota è emerso un
  difetto a monte nel clustering Stadio 3. Questo rework lo sana.
- **Branch:** `review-scientific-consistency-2026-06-10` (master git invariato).

---

## 1. Problema

I cluster `disease_vs_normal` (e in parte `small_molecule`) raggruppano **biologie
diverse** perché l'anchor dello Stadio 3 non porta il nome di malattia/composto e
collassa sul solo tessuto.

### Evidenza misurata (sessione 17, 2026-06-25)

- Sui 177 cluster `disease_vs_normal` (dedup): **66 = 37%** mescolano ≥2 malattie
  diverse riconoscibili (minestrone **provato**, limite inferiore); 71 = 1 malattia;
  40 non etichettabili. Tra i 37 candidati robusti del pilota: **26 = 70%** minestroni.
- Esempio: cluster "sangue", 23 studi → 16 malattie diverse (seno, leucemia, HIV,
  Parkinson, lupus, …). Esempio "sangue" 6 studi → 15 tumori, **consistenza 0,91**.
- `small_molecule`: pattern diverso ma presente — (a) studi **degron/genetici**
  mal-etichettati `small_molecule` e raggruppati per linea cellulare (HCT116) su geni
  bersaglio diversi (ZC3H4, INTS11, XRN2, …); (b) composti diversi (bleomicina vs
  mitoxantrone) raggruppati per tema.
- **La consistenza (F6) NON distingue cluster coerente da minestrone**: alcuni
  minestroni hanno consistenza 0,91 · 0,98 · 1,00 (segnale generico aspecifico). Serve
  un controllo di **omogeneità biologica** distinto dalla consistenza.

### Radice nel codice

`R/stage3-anchor-levels.R:52` — il nome della malattia viene **solo** dal campo LLM
`stage1_facts$disease_state$mesh_id_candidate`. Se è `"unknown"` → riga 73
`agent_id = "UNK"`. Stesso schema per l'agente delle perturbazioni. **I metadati GEO
grezzi (dove il nome c'è: `characteristics_ch1`, `source_name_ch1`, `title`) non
vengono mai letti dall'anchor.**

---

## 2. Decisioni (gate utente, sessione 17)

| # | Decisione | Scelta |
|---|---|---|
| Sorgente | Da dove arriva il nome | **A**: deterministico dai metadati + ontologia. In parallelo **benchmark LLM** sugli stessi casi; se l'LLM è bravo → **C** (ibrido: deterministico primario, LLM fallback). |
| Scope | Su quali cluster | **S3**: tutti i cluster con `agent = UNK`, qualunque sia il tipo (non solo disease/small_molecule). Stessa causa → trattamento uniforme. |
| Granularità | Cosa è "stessa malattia/composto" | **G2**: livello-malattia (sottotipi dello stesso tumore insieme; malattie distinte separate). Composto esatto (bleomicina ≠ mitoxantrone). Dose/durata sono già segmenti separati. |
| Ignoti | Cluster senza nome anche dopo recupero | **U1**: niente pooling cross-studio (nessuna affermazione cross-studio senza identità comune); restano per-studio, fuori dal pilota; si riporta il conteggio. |
| Ontologia | Ruolo della mappatura | **Cuore del recupero**, non opzionale: senza, i sinonimi ("breast cancer" / "breast tumor") frammentano e G2 non si realizza. |

**Decisione rimandata (da ripresentare a fine rework):** correzione dei **tipi
sbagliati** (es. degron etichettato `small_molecule` → `genetic_*`). È un secondo asse,
distinto dal recupero-nome. Il recupero-nome da solo de-minestrona quei cluster
(separa per gene bersaglio) ma lascia il tipo errato.

---

## 3. Architettura

Flusso: **recupero nome (deterministico)** → **lookup precalcolato** → **innesto
nell'anchor** → **re-cluster Stadio 3** → **ri-pooling Stadio 4 (solo cluster
cambiati)** → **ri-calcolo F5/F6** → **gate di omogeneità**. In parallelo, fuori dalla
produzione: **benchmark LLM**.

### 3.1 Modulo di recupero — `R/stage3-name-recovery.R` (nuovo)

- **Input:** per i campioni *case/treated* di un record, i campi grezzi H5
  `characteristics_ch1`, `source_name_ch1`, `title`.
- **Estrazione per tipo:**
  - `disease_vs_normal` → **malattia**: valori delle chiavi `disease|disease state|
    diagnosis|condition|histology|tumor type|cancer type|subtype|group` +
    scansione del `title`.
  - `small_molecule`/`cytokine_stim`/`pathogen_*`/… → **agente**: valori delle chiavi
    `treatment|agent|compound|drug|chemical|stimulus|ligand|exposure` + `title`.
    Esclusi i controlli (`control|vehicle|dmso|pbs|untreated|none|mock|scramble|wt`).
- **Normalizzazione (ontologia):** mappa su **MeSH** (malattie) / **ChEBI** (composti)
  via i dizionari ontologici già caricati dalla pipeline (`.load_ontology_dicts`,
  `.mesh_lookup_*`, `resolve_agent_canonical`). Output per record:
  - `MeSH:Dxxxxxx` / `CHEBI:xxxxx` (+ nome leggibile + `recovery_source`), oppure
  - `STR:<nome normalizzato>` se nessun match ontologico (rischio frammentazione,
    tracciato), oppure
  - `NA` se non si estrae nulla.
- **TDD:** funzioni pure testate su fixture sintetiche (estrazione + normalizzazione +
  esclusione controlli + casi NA).

### 3.2 Lookup precalcolato

Una passata unica sull'H5 costruisce `campione (GSM) → identità recuperata`
(cacheabile, tracciabile, materializzabile come artefatto supplementare del paper),
sullo stile di `build_archs4_metadata_v2`. L'aggancio studio→campioni usa il match
per **token** su `series_id` (i super-series sono comma-joined — bug scoperto e da
gestire, vedi §6).

### 3.3 Innesto nell'anchor — `.extract_anchor_segments`

Nei punti dove oggi si assegna `UNK` (riga 73 e gemelle per le perturbazioni), si
consulta il lookup: se c'è un'identità recuperata, la si usa nel segmento `agent_id`;
altrimenti resta `UNK` e il record entra in regime **U1**. I valori LLM-original
restano in `tracking_meta` per audit (come già fa v3.1).

### 3.4 Benchmark LLM (valutazione, gated, fuori produzione)

Sugli stessi record UNK: estrazione LLM mirata di malattia/composto. Confronto
**LLM vs deterministico vs campione etichettato a mano** (verità di riferimento, ~50
record). Metriche: accuratezza di estrazione, copertura sui casi `NA` del
deterministico. **Decisione C** (LLM come fallback) presa solo se l'LLM supera una
soglia concordata. Non entra in produzione altrimenti.

### 3.5 Ri-esecuzione a cascata

Re-cluster Stadio 3 (nuovo anchor) → **ri-pooling Stadio 4 solo sui cluster con
membership cambiata** (i coerenti già-nominati restano) → ri-calcolo metrica
consistenza F5/F6 sui cluster nuovi. Costo: ore (Stadio 4 pieno era ~24h; lo scope
ai soli cluster toccati lo riduce).

### 3.6 Gate di accettazione — omogeneità

Si productionizza il **test di omogeneità sui metadati** (prototipo in scratchpad
sessione 17) come script tracciato, e lo si gira sui cluster **nuovi**. Criterio:
**~0 minestroni provati** (≥2 malattie/composti diversi) nel set poolabile. Se ne
restano → il recupero non basta, si itera prima di accettare.

---

## 4. Unità e interfacce

- `R/stage3-name-recovery.R` — estrazione + normalizzazione (puro, TDD). Non conosce
  l'H5: riceve testo, restituisce identità.
- builder del lookup — legge H5, applica il modulo, scrive `GSM → identità` (cache).
- patch `.extract_anchor_segments` — consuma il lookup, retrocompatibile (lookup NULL =
  comportamento attuale).
- script di benchmark LLM — standalone, non in `R/`.
- script gate omogeneità — standalone, riusa il modulo per etichettare i cluster nuovi.

---

## 5. Validazione

1. TDD sul modulo di recupero (estrazione/normalizzazione/NA/controlli).
2. Smoke su una manciata di record reali (seno, sangue, HCT116) prima del run pieno.
3. Gate omogeneità sui cluster nuovi (~0 minestroni poolabili) — **gate scientifico**.
4. Benchmark LLM vs deterministico vs gold a mano.
5. Sanity sul re-cluster: conteggi, copertura campioni, nessuna regressione sui cluster
   già coerenti.

---

## 6. Rischi / questioni aperte

- **Frammentazione G2**: i casi `STR:` (non mappati a ontologia) possono spezzare la
  stessa malattia in più cluster. Misurare quanti `STR:` restano; se troppi, rafforzare
  la normalizzazione (sinonimi) o accettare e dichiarare.
- **Povertà dei metadati**: i record `NA` (regime U1) vanno quantificati — numero da
  dichiarare nel paper.
- **Match `series_id` comma-joined** (super-series): usare match per token, non `==`
  (bug scoperto sessione 17; ha falsato le prime misure).
- **Tipi sbagliati** (degron→small_molecule): fuori scope qui, decisione a fine rework.
- **Relazione con F6**: la metrica di consistenza resta valida come metrica, ma **non**
  è il gate di coerenza; il gate è l'omogeneità (§3.6). La selezione del pilota (F6
  Fase B/C/D) riparte dai cluster nuovi.

---

## 7. Conseguenze

- I risultati DE attuali (`cluster_pooled.parquet` del run `4f7ea215`) per il braccio
  malattia/UNK **non sono affidabili** e vengono rigenerati.
- Il pilota Layer B si seleziona dai cluster nuovi, post-gate omogeneità.
- Secondo contributo metodologico per il paper: un layer di QC che recupera identità
  biologica dai metadati grezzi quando la classificazione automatica fallisce, con
  benchmark onesto LLM vs deterministico.
