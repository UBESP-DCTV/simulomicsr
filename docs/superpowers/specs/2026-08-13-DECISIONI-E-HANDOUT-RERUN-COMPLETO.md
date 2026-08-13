# HANDOUT — Le sette decisioni prese, e come si esegue il re-run completo

**Scritto:** 2026-08-13 · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessun push · nessun run lanciato**

> **Autosufficiente.** Non serve la conversazione precedente. Va letto per intero.

---

## 0. Il mandato dell'utente

Tutti i fix in place, **poi si rifà tutta la pipeline, tutti gli stadi**, DGX
compresa (ora riproducibile con `VLLM_BATCH_INVARIANT=1`). Prima del lancio: un
**controllo approfondito di tutta la pipeline**. Dopo il run: **si ricontrollano
tutti i dati**.

---

## 1. LE SETTE DECISIONI (prese il 2026-08-13, dopo misura)

| # | decisione | effetto misurato |
|---|---|---|
| **D1** | **Sommare le corsie** di sequenziamento prima del DE | 6 confronti cadono (tutti GSE173902), 6 righe delle 214 perdono uno studio, *S. epidermidis* esce (k 3→2), deliverable **214 → 213**. Corregge anche l'SE di GSE115542 (×2,16), GSE116899 (×1,31), GSE178340 (×1,20) |
| **D2** | **Correggere il confine** del marcatore genetico | 3 confronti scartati in 2 gruppi. ATRA resta k=4 (lo studio ha altri 3 confronti puliti), **Nutlin-3a k=8 → 7**. Nessun gruppo esce |
| **D3** | **Accendere la mappa delle ENTITÀ** (5 fusioni su 8 candidate) | TNF **+6 studi (32→38)**, misurato. IL6 +1, IL15 +2 (non misurati, il lato assorbito non è poolato). Endotelina-1 non raggiunge il gate. Le 3 respinte restano fuori |
| **D4** | **Mappa dei CONTROLLI: solo ipossia + SARS-CoV-2** | ipossia **+8 studi (25→33)**, SARS-CoV-2 **+2 (34→36)**. Tutte le altre 10-11 fusioni **escluse** |
| **D5** | **Ipossia: fondere e dichiarare il difetto** | il donatore disallineato di GSE269699 (Hypoxia don. 1 e 3 contro Normoxia don. 2) **esisteva già nel gruppo vincente prima della fusione**: non lo porta la fusione. Va nei limiti |
| **D6** | **Infigratinib a k=3: accettare**, con `k_kish`/`dominato` a dichiararlo | unica meta-analisi nuova che nasce dalle fusioni scelte. KSHV, epatite C e Zika **non nascono più**: venivano da fusioni di controllo escluse in D4 |
| **D7** | **Registrare su disco il motivo di ogni scarto** | corsie sommate, genetica su un braccio, `n_min`, conflitto di ruolo. Il registro dei conflitti di ruolo esisteva ma **non arrivava su disco** (attributo perso da `write_parquet`): già spostato in `qc_report` |

**Chiuso senza modifiche:** il PASSO 2 (coerenza dell'ID col testo). Misurato: il
`canonical_name` sbagliato costa **9 cluster su 10.521, zero nel deliverable**, e
"aggiustarlo" ne perderebbe **26**. Il resolver **non si tocca**.

---

## 2. CHE COSA VA IMPLEMENTATO — tre cambi, con i casi di accettazione

### 2.1 D1 — le corsie (GIÀ FATTO, va solo acceso)

Codice pronto e testato: `R/stage4-technical-lanes.R` (23 casi / 41 asserzioni) +
`test-stage4-technical-lanes-integration.R` (4 casi / 10 asserzioni).
Agganciato in `.build_group_rem_dispatch_from_stage3()`, `.run_per_study_de_all()`,
`.drop_role_conflicts()`.

**Da fare: accendere l'interruttore.**
`stage4_default_config()$rem_group$collapse_technical_lanes` da `FALSE` a `TRUE`.

Accettazione già superata (rifarla dopo l'accensione):
- dispatch 2.152 → 2.146 entry, 6 cluster con `k` cambiato, **gli stessi 6**;
- con la corrispondenza spenta: byte-identico a oggi (verificato su 186.269
  `replicate_group`, zero con campioni ripetuti).

### 2.2 D2 — il confine del marcatore genetico (DA SCRIVERE)

`R/stage3-row-pairing.R`, `.RP_GENETIC_CS_RX` / `.RP_GENETIC_CI_RX`.

**Il difetto:** `\b` pretende un confine di parola **prima** del marcatore. In
`p63shRNA` prima di `sh` c'è una **cifra** → nessun match. Idem `\bko\b` contro
`KO2`.

**La correzione, con i suoi vincoli:**

```r
# confine allargato: inizio, separatore o CIFRA
"(^|[^A-Za-z])(sh|si|sg)[A-Z][A-Za-z0-9]{1,}"
"(^|[^A-Za-z])(KO|KD)[0-9]{0,2}([^A-Za-z]|$)"   # case-SENSITIVE
```

⚠️ **Tre trappole misurate, da chiudere nei test:**
1. `KO`/`KD` **devono essere case-sensitive**: in minuscolo prendono `Kd`
   (costante di dissociazione) e `kd of 5 nM`. Il pattern di produzione
   `\bkd\b` è case-insensitive e **ha già questo falso positivo**.
2. Il marcatore va applicato **ai VALORI, non a `chiave=valore`**: altrimenti
   `genetic_knockdown=no knockdown`, `TET1_knockdown=wild_type`,
   `overexpression=None` risultano genetici **per il nome del campo**. Questo
   errore ha gonfiato un conteggio da 3 a 23.
3. Serve la lista dei valori che **negano** la modifica: `none`, `no`,
   `wild-type`, `wt`, `control`, `scramble`, `parental`, `empty`, `-`.

**Casi di accettazione (positivi):** `p63shRNA`, `MCF10A_p63shRNA_Nutlin3A_5uM`,
`A549siEGFR`, `MCF7 RELA KO2`, `Engineered HeLa S3 cells (KO38)`, `shTP53`,
`siRNA against MYC`, `MYC overexpression`, `TP53 KO`.
**(negativi):** `Kd measurement`, `kd of 5 nM`, `KOH buffer`, `no knockdown`,
`wild_type`, `simvastatin`, `sirolimus`, `single cell`, `shear stress`,
`sitagliptin`, `silica`, `sigmoid colon`, `Tokyo`, `Kobe`, `washing`,
`MCF10A_DMSO`.

**Esito atteso sui dati veri:** esattamente **3 confronti**, in `cgroup_L5_37942548`
(ATRA) e `cgroup_L5_35d1be10` (Nutlin-3a) — **gli stessi due gruppi che i lettori
umani avevano giudicato il 5 agosto**. Se ne escono di più, lo strumento è
sbagliato: fermarsi e leggerli.

### 2.3 D3+D4+D5+D6 — le mappe (DA POPOLARE)

`stage4_default_config()$rem_group$entity_canonical` e `$control_canonical`, oggi
`NULL`. Il meccanismo di fusione esiste ed è testato (`R/stage4-qc.R`, commit
`ef0cf49`, 137 righe di test); **con NULL non cambia nulla, verificato sui dati
veri** (351 candidati, `cluster_id` identici, `k` invariato).

**`entity_canonical` — 5 voci** (da `analysis/audit/2026-08-08-deframmentazione/32-verdetti-8-fusioni.csv`):

| scrittura | codice canonico | prova |
|---|---|---|
| `CHEMBL:CHEMBL265582` | `HGNC:11892` (TNF) | 48/48 membri = proteina TNF-α esogena vs veicolo. **Zero trasfezioni, zero anticorpi** |
| `MeSH:D015850` | `HGNC:6018` (IL6) | 11/11 = IL-6 esogena vs non trattato/veicolo |
| `CHEMBL:CHEMBL4297989` | `HGNC:5977` (IL15) | 6/6 = IL-15 esogena |
| `CHEMBL:CHEMBL437472` | `CHEBI:80240` (endotelina-1) | entrambi = endotelina-1 esogena vs controllo/DMSO |
| `CHEMBL:CHEMBL1852688` | `CHEBI:63451` (infigratinib) | BGJ398 = infigratinib, stesso inibitore FGFR, farmaco vs DMSO |

**NON inserire** (respinte con la prova): IL-10, GM-CSF/CSF2 («5 membri su 13
misurano DIFFERENZIAZIONE non stimolazione»), «Compound 4» («**NON È LA STESSA
MOLECOLA**: il ponte è l'alias generico `compound4`»).

**`control_canonical` — 2 voci soltanto**:

| chiave | canonica | prova |
|---|---|---|
| `normoxia` | `vehicle_untreated` | 23/23 membri = ipossia contro il compagno normossico dello stesso studio, scritto `untreated`/`control`/`vehicle`. **+8 studi (25→33)** |
| `uninfected` (solo per `NCBITaxon:2697049`) | `vehicle_untreated` | 5/5 = "SARS-CoV-2 infected" vs "Uninfected", **dentro lo studio, stesso tipo cellulare**. Zero difetti trovati. **+2 (34→36)** |

⚠️ **`uninfected` NON va reso generale.** Da solo produce 10 fusioni, di cui: 2 con
**doppio conteggio** (ATRA e HSV-1: gli stessi campioni contati due volte contro
due controlli diversi dello stesso studio), 1 **minestrone** (RSV: aggiunge un
secondo studio clinico a un gruppo sperimentale), 2 incerte, 3 a guadagno nullo.
**Se il meccanismo non sa condizionare la fusione all'entità, si accende solo
`normoxia` e SARS-CoV-2 si rinuncia** — non si accende `uninfected` generale.

### 2.4 D7 — il registro degli scarti (PARZIALMENTE FATTO)

`qc_report$role_conflicts` e `qc_report$lane_collapses` già aggiunti (prima
vivevano come attributi di `per_study_de` e `arrow::write_parquet` **li perdeva**).
**Da aggiungere:** il motivo `n_min` per-confronto e quello della genetica.

---

## 3. IL CONTROLLO APPROFONDITO, PRIMA DEL LANCIO

Ordine consigliato. Ogni voce ha già il suo strumento.

1. **Stadio 1** — il guard `is_zero_timepoint` deve continuare a valere:
   sull'input v3 attuale è **2.882 accensioni, 0 in disaccordo con l'evidenza**.
   Ri-verificare sull'input nuovo. ⚠️ Leggere il JSONL con i valori **spacchettati**:
   sono array di un elemento e `isTRUE(list(FALSE))` è sempre FALSE (mi ha dato
   due numeri falsi).
2. **Stadio 2** — un record per studio (`.assert_stage2_one_record_per_series`).
3. **Stadio 3** — le cinque invarianti di `60-invarianti-v15.R`; le bandiera sopra
   il pavimento (SARS 38, LPS 50, enzalutamide 29, vemurafenib 20); **bumpare
   `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`** se si tocca il recupero-nome (v7 oggi),
   o la cache serve un output stale — già costato 8 ore.
4. **Stadio 4** — funnel `cgroup → 355 → 351 candidati → 214+137`, zero orfani;
   `k_eff` contro il deliverable (era 214/214 scarto 0).
5. **Le guardie che devono restare accese**: conflitto di ruolo, verdetti orfani
   (fermano l'annotazione a fine run, sta fuori dal `tryCatch` apposta).
6. **Suite intera**: oggi **0 fallimenti**. Rilanciarla **dopo** l'ultima modifica
   al codice, non prima: `devtools::load_all` fotografa il pacchetto all'avvio e
   due volte ho letto fallimenti di codice già corretto.

---

## 4. IL RUN

- Stadio 1 e 2 su DGX **con `VLLM_BATCH_INVARIANT=1`** (riproducibilità 100%
  verificata: Stadio 1 40,4%→100%, Stadio 2 62,0%→100%).
  ⚠️ `sinfo` che dice `idle` **non basta**: verificare il mount reale con un `srun`
  breve prima di sottomettere.
- Re-cluster Stadio 3 ~9 h, re-pool Stadio 4 ~31 h. `setsid` (verificare SID==PID),
  **mai** in background del tool. Aggiornamento **ogni ora**.
- La cache dei conteggi (27.940 voci, 9 GB) si riusa: un re-pool sugli stessi
  cluster non rilegge l'H5.

## 5. DOPO IL RUN

1. **Anti-stale**: leggere dai file, non dal log — `Methods` = solo `rem_group`,
   tutti i `cluster_id` col prefisso `cgroup_L5_`, confronto d'insieme coi cluster
   attesi.
2. **Controllo biologico** (`90-controllo-biologico-v15.R`): bersagli fissati dalla
   letteratura **prima** di guardare. Il controllo che vale doppio è DHT contro
   enzalutamide: 1.266 geni su 1.299 di segno opposto, Spearman −0,939.
3. **Le previsioni depositate PRIMA del run** (scriverle in un file):
   deliverable 214 → **213 − 1 (Nutlin resta) + 1 (infigratinib)**; TNF 32 → 38;
   ipossia 25 → 33; SARS-CoV-2 34 → 36; i 6 confronti di GSE173902 assenti; i 3
   confronti genetici assenti.
4. **Rifare Layer B** e rileggere le narrative (sono bozze).
5. **Correggere i sei documenti** col peso contaminato sbagliato: `0,0–15,9%` non
   `0,7–33,7%`, il peggiore è **LPS** non IL1B.

## 6. MATERIALE

- `docs/findings/2026-08-12-corsie-non-repliche.md` + `analysis/audit/2026-08-12-corsie/` (README con l'ordine degli script)
- `docs/findings/2026-08-13-passo2-il-nome-sbagliato-non-costa.md` + `analysis/audit/2026-08-13-passo2/`
- `docs/findings/2026-08-13-genetica-su-un-braccio-solo.md` + `analysis/audit/2026-08-13-genetica-su-un-braccio/`
- `docs/findings/2026-08-10-sensitivity-confronti-spuri.md`
- verdetti delle fusioni: `analysis/audit/2026-08-08-deframmentazione/32-verdetti-8-fusioni.csv`, `36-verdetti-4-fusioni-dedup.csv`, `38b-verdetti-10-fusioni-controllo.csv`
