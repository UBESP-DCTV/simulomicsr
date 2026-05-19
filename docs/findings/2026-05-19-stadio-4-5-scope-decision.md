# Scope decision per Stadio 4+5: focus su ~412 meta-analisi "publishable", non sulle 4.575 teoricamente fattibili

**Data:** 2026-05-19
**Branch / tag riferimento:** master @ `626faed` / `p5-stadio3-complete`
**Run β di riferimento:** `analysis/p4-output/20260519T055547Z-stage3-2153addc/`
  (267.056 cluster, run_id `2153addc`)
**Decisione presa da:** lucavd (sessione esplorativa)

## Contesto

L'output dello Stadio 3 (run β) genera tre famiglie di cluster cross-studio
utilizzabili come input per meta-analisi:

1. **REM (`metafor::rma`) su anchor-pair**: 345 cluster `usable_rem_relaxed`;
2. **MEGA (mixed-model raw counts) su anchor-group**: 4.163 cluster `usable_mega_relaxed`;
3. **MEGA-augmentation (pair-DE + shared baseline group)**: 67 cluster pair con
   controparte group sufficientemente popolosa per usare il baseline cross-studio.

Totale teorico: **~4.575 meta-analisi distinte** producibili dal singolo output Stadio 3.

Una proof-of-concept Stadio 4 (`/tmp/edger-prototype.R` + `/tmp/edger-power-gain.R`,
prototipi non committati nel repo) ha dimostrato che:
- Per-study edgeR QLF + metafor REM funziona end-to-end su cluster reale
  (interferon A549, k=3 studi qualificati);
- Il guadagno di potere reale dipende fortemente da τ² gene-specifico
  (vedi `2026-05-19-stage3-power-gain-quantificazione.md`).

Domanda strategica: **vale la pena computare TUTTE le 4.575?**

## Decisione

**No.** La pipeline produrra' come deliverable batch solo le **~412 meta-analisi
"publishable" core** (Layer A sotto). Le rimanenti ~4.163 sono disponibili on-demand
via pipeline re-run sul cluster di interesse, ma non come catalog precomputato.

### Tre layer di output, scope esplicito

| Layer | Conta | Quando si computa | Ruolo nel paper |
|---|---:|---|---|
| **A — Core publishable** | ~412 | UNA volta come batch (Stadio 5 production, ~1 h compute parallel 32-core) | Methods + figure agregate (Results tabella riassuntiva) |
| **B — Showcase case study** | 10-20 | Manuali con biological narrative | Results dedicato (1-2 figure per case) |
| **C — Catalog Stadio 3** | 267.056 cluster | Gia' prodotto (run β) | Supplementary table + GitHub release |

Layer A = unione di:
- 2 cluster REM gold (k≥5)
- 33 cluster REM proper (k=3-4)
- 312 cluster MEGA strict (k≥5, L0/L1, safety≥0.7)
- 67 cluster MEGA-augmentation

Layer A escludendo:
- 310 cluster REM FE-only (k=2): pooling FE su 2 studi e' statisticamente debole,
  scientificamente fragile; produce risultati ma con bassa interpretabilita';
- ~3.400 cluster MEGA-relaxed k=2-4: high heterogeneity attesa, signal-to-noise basso;
- ~430 cluster MEGA-relaxed k=5-9: scoping pragmatico, scartati per economia.

## Razionale

**1. Liability scientifica.** Pubblicare 4.575 meta-analisi implica una claim di
validita' per ognuna. Reviewer onesti rifiuterebbero risultati con I²>95%
(eterogeneita' massiva) ottenuti da k=2 studi senza giustificare la scelta.
Pubblicare solo i cluster dove il pooling e' statisticamente difendibile e' eticamente
piu' robusto.

**2. Diluizione del messaggio.** Un paper con "we ran 4.575 meta-analyses" suona
impressionante ma e' "data dump". Un paper con "we identified ~412 publishable
cross-studio meta-analyses + 15 case studies con interpretazione biologica"
trasmette piu' valore scientifico per lettore.

**3. Il vero deliverable e' la pipeline + il catalogo Stadio 3, non le MA**.
La cluster table di Stadio 3 (`clusters.rds`, 267k entries, 35 MB) **e' essa stessa
un database**: chiunque puo' usare `filter_clusters(usable_rem_strict)` o costruire
la propria query e poi consumare il flusso di Stadio 4+5 sul cluster di interesse.
Pre-computare 4.575 MA e' offrire un servizio che il paper non e' tenuto a erogare,
e che molti utenti non vorranno (filtreranno comunque per la propria domanda specifica).

**4. Compute economics non-vincolanti, ma la scope decision NON e' guidata dal
compute**. Le 4.575 MA si calcolano in ~5 ore wall-time (parallel 32 core) e
occupano ~15 GB. Tecnicamente fattibile. La decisione e' guidata dal valore
scientifico per MA, non dal costo CPU.

## Implicazioni per il design di Stadio 4 (DE per-studio) e Stadio 5 (meta-analisi)

### Stadio 4 production: scope

- Input: 33 REM cluster proper + 312 MEGA strict + 67 MEGA-augmentation = ~412 cluster
- Per ogni cluster REM: edgeR QLF per ogni studio (sum k = ~120-200 DE runs)
- Per ogni cluster MEGA: fetch raw counts + GLM-NB con study random effect
- Per MEGA-augmentation: DE pair-study + augmented baseline GLM
- Output unico parquet/rds: (cluster_id, gene, logFC_pool, SE_pool, τ², I², p, FDR_BH)

### Stadio 5 production: scope

- Solo per cluster REM proper (k≥3, ~35 cluster): `metafor::rma` su `(yi, vi)`
  per ogni gene per cluster
- Output: cluster-level meta-analytic statistics
- Per cluster MEGA strict/augmentation: il modello misto stesso ha logica
  Stage 5 built-in (no separate REML pooling step needed)

### QC sample-level

Threshold lib_size minimo da introdurre formalmente (vedi caveat nel finding
`2026-05-19-stage3-power-gain-quantificazione.md`). Proposta: lib_size >= 500k.
Esclusione di GSE206784 nel POC e' precedente concreto.

### Output catalog (Layer C)

Layer C resta come `analysis/p4-output/20260519T055547Z-stage3-2153addc/`
(gia' in master, gia' shared). Aggiungere README sintetico nel directory che
indica:
- Schema dei 5 file
- Esempi di query (filter_clusters, cluster_records)
- Pointer a docs/findings/2026-05-19-* per use cases

### Out-of-scope espliciti

Non producibili nel paper iniziale (lasciati a follow-up):
- Meta-analisi per cluster REM k=2 (310 cluster);
- Meta-analisi per cluster MEGA-relaxed bassi (k=2-4, ~3.400 cluster);
- Cross-cluster integration (es. combine REM IFN-A549 con REM IFN-HUVEC);
- Sample-level scoring (es. z-score di ogni sample contro shared baseline).

## Validazione della decisione

La decisione e' validata empiricamente dal finding di power gain:
- Solo geni con τ² basso traggono beneficio reale da REM pooling (gain 5-10x);
- Geni con τ² alto producono pooling con SE inflato (gain <1x);
- Il filtro a livello cluster (usable_rem_strict / safety>=0.7 / k>=5) e'
  l'analogo del filtro per-gene del power gain;
- Stratificare per quality e poi computare solo high-quality e' la strategia
  che massimizza signal-to-noise sull'output paper.

## Riferimenti

- `docs/findings/2026-05-19-stage3-esempi-metanalisi-abilitate.md`: 4 case study
- `docs/findings/2026-05-19-stage3-power-gain-quantificazione.md`: power gain
  empirico
- Prototipi (non in repo): `/tmp/edger-prototype.R`, `/tmp/edger-power-gain.R`
- Spec Stadio 3: `docs/superpowers/specs/2026-05-18-p4-stadio3-raggruppamento-design.md`
- ADR 0014 (Stadio 3): `docs/decisions/0014-stage3-tiered-anchor-dual-mode.md`
