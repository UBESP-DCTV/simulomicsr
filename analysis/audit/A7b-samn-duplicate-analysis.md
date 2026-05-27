# A7b — Analisi paper-grade dei duplicati cross-GSE per BioSample SAMN

> **Data**: 2026-05-27.
> **Scope**: RED ALERT FASE E0b. Estende A7 misurando QUANTO i GSM duplicati
> su stesso SAMN sono **simili** (metadata + counts) e QUANTI cluster
> Stadio 3 v3.1.1 sono potenzialmente colpiti, per decidere fra le tre
> opzioni E0b (drop / average / sotto-noise).
> **Branch**: `p5-llm-anchor-classification-audit`.
> **Output evidence**:
> - `A7b-samn-duplicate-metadata.tsv` (425 GSM × 16 colonne metadata).
> - `A7b-samn-duplicate-pairs.tsv` (176 SAMN × 17 diff flags).
> - `A7b-samn-counts-correlation.tsv` (subset 10 SAMN stratificato).
> - `A7b-samn-cluster-impact.tsv` (270 righe SAMN×cluster_id a rischio).

## 1. Universo (riconferma A7)

- 425 GSM cross-GSE, 176 SAMN duplicati.
- Distribuzione SAMN per `n_gsm`: 148 SAMN in 2 GSE (84.1%), 13 in 3, 7 in 4,
  1 in 5, 1 in 7, 4 in 8, 2 in 9.

## 2. Quanto sono SIMILI i duplicati cross-GSE — metadata

Per ogni SAMN duplicato, % SAMN con valore mixed (≥ 2 valori distinti
cross-GSE) per ciascun campo:

| campo                  | % mixed | n_mixed/n_tot |
|---|---:|---|
| `library_source`       | **0.00%**  | 0/176 |
| `molecule_ch1`         | **0.00%**  | 0/176 |
| `data_processing`      | **0.00%**  | 0/176 |
| `instrument_model`     | **45.45%** | 80/176 |
| `extract_protocol_ch1` | **95.45%** | 168/176 |

Lettura:

- I campi controlled-vocabulary GEO (`library_source`, `molecule_ch1`) sono
  **identici cross-GSE** per tutti i 176 SAMN. Stessa entità biologica,
  stessa categoria di RNA.
- `data_processing` (testo aligner upstream) è identico cross-GSE. Questo è
  sospetto: significa che il valore in H5 ARCHS4 è probabilmente la pipeline
  *di ARCHS4 stesso*, non quella del submitter GEO originale. Da verificare
  se serve usarlo come covariata batch in E3.
- `instrument_model` cambia nel **45%** dei SAMN duplicati → re-sequenziamento
  su strumenti diversi (es. HiSeq2500 in GSE-A, NovaSeq6000 in GSE-B).
- `extract_protocol_ch1` cambia nel **95%** → testo libero quasi sempre
  diverso, ma in molti casi diff cosmetica (whitespace, numerazione PCR
  cycles).

**`lib_size_ratio` max/min cross-GSE** (sample post-A3 filtri):

| quartile | ratio |
|---|---:|
| 25% | 1.50× |
| 50% (mediano) | **2.23×** |
| 75% | 3.32× |
| 90% | 4.83× |
| 95% | 5.80× |
| max | 17.18× |

Lettura: la profondità di sequenziamento varia in media **2.2×** cross-GSE
sullo stesso SAMN. NON sono re-upload identici della stessa FASTQ — sono
re-sequenziamenti / re-runs con depth diversa.

## 3. Quanto sono SIMILI i duplicati cross-GSE — counts

Subset stratificato 10 SAMN (5 `identical_meta` con metadata uniformi +
5 `instrument_mix`). Correlazione gene-wise cross-GSE su counts ARCHS4 v2.5:

| stratum | n | median Pearson(log1p) | min Pearson | median Spearman | median lib_ratio |
|---|---:|---:|---:|---:|---:|
| `identical_meta` | 5 | **0.753** | 0.414 | 0.720 | 2.06× |
| `instrument_mix` | 5 | **0.522** | 0.347 | 0.515 | 0.91× |

Lettura paper-grade:

- Anche con **metadata identico** (stesso instrument + stesso data_processing
  + stesso molecule), la correlazione Pearson cross-GSE è **0.75 mediana,
  0.41 minimo**. Questo è MOLTO lontano dal valore atteso per replicate
  tecnici puri (~0.98-0.99).
- Con instrument diverso, scende a **0.52 mediana**.
- Spearman rank conferma: i ranking dei geni cambiano sostanzialmente
  cross-GSE.
- I 10 SAMN testati NON sono replicate tecnici dello stesso campione
  preparato in modo identico. Sono "stesso BioSample biologico" ma con
  rumore tecnico/pipeline cross-GSE enorme.
- Caveat statistico: n=5 per stratum è piccolo per intervalli di confidenza
  formali, ma il segnale è netto (cor 0.5-0.75 su tutti, mai vicino a 1).

## 4. Quanti cluster Stadio 3 sono colpiti (upper bound)

Heuristic: per ogni SAMN duplicato (lista delle GSE in cui appare), conta
i cluster Stadio 3 v3.1.1 baseline (`2655ecb0`, 390532 cluster) il cui
`studies_in_cluster` contiene **≥ 2** delle GSE del SAMN. È un upper bound
(sovrastima): il SAMN potrebbe essere assignato a un sotto-cluster diverso
da quello dei suoi GSE peers per via di anchor / replicate_group split.

| metrica | valore |
|---|---:|
| SAMN con ≥1 cluster a rischio | **57 / 176 (32.4%)** |
| cluster_id unici a rischio | **128** |
| % del bacino cluster (128 / 390532) | **0.033%** |

Per `mode`:

| mode | n |
|---|---:|
| group | 270 (100%) |
| pair | 0 |

Per `level`:

| level | n |
|---|---:|
| 0 | 52 |
| 1 | 52 |
| 2 | 52 |
| 3 | 57 |
| 4 | 57 |

Top `kind_effective_resolved`:

| kind | n |
|---|---:|
| none | 190 |
| disease_vs_normal | 40 |
| differentiation | 20 |
| environmental | 20 |

Lettura:

- **0 pair cluster** a rischio direttamente. È atteso: un pair vive entro
  un singolo GSE, due GSE diversi danno pair cluster diversi.
- **128 group cluster** a rischio. Sono i bacini di augmentation MEGA-AUG
  + i pool MEGA puri group-mode. Coerente con la teoria: il duplicato
  cross-GSE entra nel pool come 2 sample, non come 1.
- L'impatto pair cluster non è zero indirettamente: MEGA-AUG augmenta un
  pair con il `group_baseline`, e se il group baseline contiene 2+ GSM dello
  stesso SAMN, MEGA-AUG li somma. L'heuristic A7b non lo cattura.
- 32.4% dei SAMN duplicati impattano cluster Stadio 3, NON è "diluito a
  0.048%" come potrebbe sembrare guardando solo il bacino. È concentrato.

## 5. Implicazione per la scelta E0b

Tabella decisione data-driven:

| opzione | giudizio A7b | razionale |
|---|---|---|
| **(a) drop** | ✅ **scelta** | safe statisticamente: tiene 1 sample biologico = 1 sample nel pool, no inflazione `k_effective` / `n_studies`. |
| **(b) average counts** | ❌ **scartata** | i 10 SAMN testati hanno cor 0.5-0.75 cross-GSE. Mediare counts NB con correlazione così bassa NON è statisticamente difendibile. Equivale a forzare additività su dati non-omologhi. Contraddice D8 (covariate batch instrument_model + aligner_class) dello stesso ADR-0019. |
| **(c) sotto-noise** | ❌ **scartata** | 57/176 SAMN (32.4%) impattano cluster: NON è diluito. 128 group cluster a rischio è solo l'upper bound diretto, MEGA-AUG amplifica indirettamente. Lasciare il bug aperto viola la convenzione "no acceptable v1 + TODO v2" + non passerebbe peer review. |

### 5.1 Sotto-decisione: quale GSM tenere quando si fa drop?

A7b mostra che i duplicati NON sono replicate tecnici (cor 0.5-0.75 anche
con metadata identico). Quindi la scelta del GSM da tenere NON è
indifferente. 3 opzioni discusse:

1. **Primo alfabetico GSM** (semplice, deterministico).
   - Pro: trivial implementation, no metadata dependency.
   - Contro: arbitrario, potrebbe favorire GSM più vecchi (HiSeq2500 sopra
     NovaSeq6000) per via dell'ordinamento accessioned.
2. **Max `lib_size`** (preserva profondità sequenziamento, tie-break alfabetico).
   - Pro: preferisce il GSM con più segnale per le DE; difendibile nel
     paper ("kept the deepest sequenced GSM per SAMN cross-study").
   - Costo: trivial — `lib_size` precalcolato in
     `analysis/audit/A3-libsize-scprob-bacino.tsv` per i 547k sample
     candidati post-Stage 0 v2.
3. **GSM più recente per accessioned date** (proxy: ordering naturale
   numerico di GSM).
   - Pro: favorisce sequenziamento più recente / instrument più recente.
   - Contro: GSM accessioned date != actual sequencing date.

**Decisione utente 2026-05-27**: ✅ **opzione 2 — max `lib_size`**.

## 6. Cosa A7b DECIDE

> **Strategia E0b** (decisione utente 2026-05-27 su evidence A7b):
> opzione **(a) drop deterministico**. Regola: per ogni SAMN cross-GSE,
> tieni il GSM con `lib_size` massimo; tie-break su GSM accessioned
> alfabetico.

Implementazione (proposta da scrivere come task FASE E0b):

- Nuovo helper `R/stage4-dedupe-biosample.R::.dedupe_gsm_by_samn(sample_ids,
  biosample_lookup, libsize_lookup)`.
- Applicato in 3 punti:
  - Record builders Stadio 3 (`.build_pair_records`, `.build_group_records`)
    al momento della costruzione di `treated_sample_ids` / `control_sample_ids`.
  - `R/stage4-mega-aug.R::build_baseline_rows` su `sids` augmentation pool.
  - Eventualmente in `R/stage4-mega-safe.R::.build_mega_metadata_safe` (da
    verificare se serve, dipende da come accumula gli sample MEGA).
- Tests TDD bite-sized.
- Logging: `qc_drops_sample` reason code `cross_gse_samn_dedupe`.

## 7. Cosa A7b NON decide

- Implementazione precisa: spec dedicato in apertura task E0b.
- Effetto su MEGA-AUG augmentation cross-cluster (pair vs baseline pool
  sharing SAMN). L'heuristic A7b non lo cattura, va misurato in E0b o
  difensivamente droppato dal pool augmented.
- Cluster impact "vero" (non upper bound): richiederebbe join completo
  stage2_master + assignments. Se l'upper bound 128 è già abbastanza
  basso da decidere, non serve. Se invece serve un numero esatto per il
  paper Results, A7c (deferred).

## 8. Riferimenti

- A7 sintesi: `analysis/audit/A7-synthesis-biosample-dedupe.md`
- ADR-0019 §D9 (dedupe BioSample SAMN scelta), §Consequences (E0b TODO)
- ADR-0016 (gene symbol paralogi, sub-finding dream silent fallback —
  contesto stage 4 affidabilità)
- RED_ALERT.md §FASE E0b
- Script analisi: `analysis/audit/A7b-samn-duplicate-analysis.R`
- Log run: `analysis/audit/A7b-samn-duplicate-analysis.log`
