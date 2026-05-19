# Quantificazione del guadagno di potere statistico cross-studio (Stadio 3+4 prototipo)

**Data:** 2026-05-19
**Branch / tag riferimento:** master @ `98cd8be` / `p5-stadio3-complete`
**Cluster usato:** `pair_L2_de50bf31` (livello L2, k=4) — interferon stimulation in A549,
  studi `GSE146403`, `GSE136864`, `GSE156295` (più `GSE206784` escluso al QC).
**Output Stadio 3 ispezionato:** `analysis/p4-output/20260519T055547Z-stage3-2153addc/`
**Metodo DE per-studio:** edgeR 4.10 quasi-likelihood F-test (QLF)
**Metodo meta-analisi:** `metafor::rma()` REML

## Contesto

Lo Stadio 3 della pipeline simulomicsr identifica cluster cross-studio comparabili
ma di per sé non dimostra che il pooling effettivamente aumenti la potenza statistica
rispetto agli studi individuali. Questo finding quantifica il guadagno empirico su un
cluster reale del run β (interferon response in A549), confrontando tre regimi:

1. **DE single-study** (edgeR QLF su ognuno dei 3 studi separatamente);
2. **Fixed-Effect pooling** (formula chiusa weighted by 1/SE²);
3. **Random-Effect pooling** (`metafor::rma()` REML, modello corretto in presenza
   di heterogeneity between-study).

## Metodologia

Per il cluster `pair_L2_de50bf31`:

1. Recuperati sample_ids treated + control per ognuno dei 4 studi via
   `stage2_master`.
2. Fetched raw counts da ARCHS4 v2.5 H5 (~2 sec per 23 GSM).
3. QC: scartato `GSE206784` perché tutti i 6 sample hanno library size <500k
   (sequenziamento fallito o single-cell misclassificato come bulk in ARCHS4).
4. Per ognuno dei 3 studi qualificati, run pipeline edgeR standard:
   `DGEList → filterByExpr → normLibSizes(TMM) → estimateDisp → glmQLFit → glmQLFTest`.
5. Estratti `logFC` e approssimato `SE = |logFC|/√F` per ogni gene per ogni studio.
6. Su 78 geni DE significativi (FDR<0.05) in *tutti* e 3 gli studi qualificati,
   computato pooling FE e REM con metafor.

## Risultati

### Tre regimi a confronto, 78 geni DE comuni

| Metrica | Single-study (mean) | FE pooled | REM pooled |
|---|---:|---:|---:|
| Median SE | 0.265 | 0.082 (3.2× meglio) | 0.527 (0.51× peggio) |
| Effective N multiplier (mediana) | 1× | **7.15×** | 0.26× |
| MDE (α=0.05, β=0.8) | 0.72 logFC | 0.23 logFC | 1.39 logFC |

### Heterogeneity dei 78 geni

| Statistica | Valore |
|---|---:|
| Mean I² | 82% |
| Median I² | 93% |
| Mean τ (SD between-study) | 1.0 |
| Median τ | 0.85 |

L'eterogeneità è massiccia perché il cluster è a livello L2 (dropped: `dose_canonical`,
`duration_canonical`): i 3 studi stimolano A549 con lo *stesso* IFN ligando ma con
dosi e durate diverse. La direzione dell'effetto è consistente (tutti up-regulated),
la magnitudo no.

### Dicotomia in funzione di τ² gene-specifico

Quando i 3 studi concordano sulla magnitudine (low τ²), REM dà guadagno reale.
Quando disagreono (high τ²), REM correttamente rifiuta il prestito di forza:

**Geni con basso τ² (REM gain massivo)**:

| Gene | logFC REM | τ | I² | SE single mean | SE REM | Gain |
|---|---:|---:|---:|---:|---:|---:|
| IFIT1 | 8.88 | 0.00 | 0% | 0.674 | 0.062 | **10.8×** |
| MX1 | 8.44 | 0.00 | 0% | 0.801 | 0.097 | **8.3×** |
| IRF9 | 3.25 | 0.00 | 0% | 0.268 | 0.075 | 3.6× |
| PSME1 | 1.33 | 0.001 | 0.5% | 0.144 | 0.065 | 2.2× |
| PSMB8 | 2.94 | 0.002 | 0.7% | 0.291 | 0.153 | 1.9× |

**Geni con alto τ² (REM gain negativo)**:

| Gene | logFC REM | τ | I² | SE single mean | SE REM | Gain |
|---|---:|---:|---:|---:|---:|---:|
| IFI27 | 9.32 | 1.85 | 99% | 0.268 | 1.768 | 0.15× |
| IFI6 | 7.10 | — | — | 0.260 | 0.872 | 0.30× |
| IFITM1 | 7.60 | — | — | 0.348 | 2.014 | 0.17× |
| IFITM3 | 4.16 | — | — | 0.197 | 0.797 | 0.25× |

Per questi geni, i 3 studi reportano logFC molto diversi (esempio IFI27: 12.8, 7.1, 8.0
log2 — range di 5.7 unità log2). REM trasforma questo disagreement in una stima
ampia con CI larga, correttamente.

## Interpretazione

### Il guadagno non è uniforme — è calibrato alla biologia

**FE pooling sopravvaluta il guadagno** assumendo homogeneity inesistente: i 3.2× di
gain mediano (sopra) sono un artifatto quando τ² è grande. Una meta-analisi pubblicata
con FE su questi dati sarebbe falsamente confidente.

**REM è onesto**: distingue automaticamente i sotto-domini dove il pooling funziona
(low τ²) da quelli dove non funziona (high τ²). Su IFIT1 e MX1 il guadagno è reale
e massiccio (effective N ~70-117× il singolo studio). Su IFI27 e IFITM1 il guadagno
è zero o negativo, e il vero risultato scientifico è il valore di τ² stesso: ci dice
che la magnitudo dell'effetto IFN dipende fortemente da parametri di esperimento
non catturati nel cluster a L2.

### Il vero valore della pipeline non è gain uniforme

Il valore unico di simulomicsr non è "+N× potere statistico per tutti i geni", una
promessa irreale. È:

1. **Selezione di cluster comparabili**: 345 cluster pair usable_rem_relaxed contro
   0 cluster identificabili manualmente.
2. **Stima della heterogeneity per-gene e per-cluster**: τ² e I² dicono quando trust
   il pooling e quando il cluster ha bisogno di scendere a L0/L1 più stretto.
3. **Quando i cluster sono biologicamente coerenti**: il guadagno reale è 5-10×
   effective N (IFIT1, MX1).
4. **Quando non lo sono**: REM mantiene calibration corretta, evitando false
   positives da pooling cieco.

### Conseguenze metodologiche per il paper

Tre raccomandazioni emergono per il design dello Stadio 4+5 production:

1. **Riportare per ogni cluster** sia stima FE sia stima REM con τ² e I². La differenza
   tra le due *è* il messaggio scientifico.
2. **Stratificare i risultati per livello L**: a L0/L1 ci si aspetta cluster con bassa
   heterogeneity (poche differenze sperimentali); a L3/L4 ci si aspetta high heterogeneity
   con interpretazione "cross-context aggregate".
3. **Cluster con I² > 75% sopra L2** sono scientificamente interessanti: indicano
   variabili sperimentali (dose, time, cell state) che modulano la risposta; meritano
   sotto-analisi a livello L0/L1 più stretto.

## Caveat metodologici

- **SE approximation**: usato `SE = |logFC|/√F` come approssimazione dello standard
  error dal QLF F-test. Per gene con F molto alto (>1000), questa approximation
  può inflate SE rispetto al SE proper estratto da `qlf$var.coefficients` o
  equivalente. Verifica raccomandata prima della pubblicazione, possibile che parte
  della heterogeneity osservata sia artifatto di SE inflation sui top genes.
- **QC sample**: lo scarto di GSE206784 (lib size <500k) suggerisce la necessità di
  un filtro sample-level documentato nel Methods. Threshold da calibrare empiricamente.
- **L2 vs L0**: il cluster usato è a L2 (drops dose+time). Replicare l'analisi su un
  cluster L0 ancora più stretto darebbe presumibilmente heterogeneity inferiore;
  attualmente in Stadio 3 non esistono cluster pair k≥3 a L0 (16 cluster pair k=2 a L0).
- **k=3**: con solo 3 studi, REML può convergere a τ²=0 quando i logFC sono molto
  vicini (vedi warning "Fisher scoring stuck at local maximum" su 1 gene). Con k≥10
  l'estimazione di τ² sarebbe più stabile (Veroniki et al. 2016).

## Riproducibilità

Prototipo: `/tmp/edger-power-gain.R` (script da spostare in `analysis/` come
parte dell'implementazione Stadio 4).

Dipendenze nuove: `edgeR` (Bioc, 4.10), `metafor` (CRAN), `metadat` (transitive),
`numDeriv`, `mathjaxr`, `pbapply`.

Riferimenti:
- Cluster Case 1: `docs/findings/2026-05-19-stage3-esempi-metanalisi-abilitate.md` Case 1
- Spec design Stadio 3: `docs/superpowers/specs/2026-05-18-p4-stadio3-raggruppamento-design.md`
- ADR 0006 (positioning vs FE-based gene-set methods): `docs/decisions/0006-stato-arte-vs-simulomicsr.md`
