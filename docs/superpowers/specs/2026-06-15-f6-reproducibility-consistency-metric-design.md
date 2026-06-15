# Spec — Metrica di consistenza/riproducibilità cross-studio per i cluster Stadio 4 (F6, Fase A)

> RED ALERT FASE F6, 2026-06-15. Design della metrica che sostituisce il proxy
> Spearman-su-top-2000 (winner's curse) come asse di consistenza per la selezione
> Layer B. Fondamento bibliografico: deep research 2026-06-15
> (`analysis/audit/F5-concordance-metric.md` per il contesto del ribaltamento %DE).

## Problema

I 776 cluster Stadio 4 v3 (`20260613T051637Z-stage4-4f7ea215/`) vanno filtrati e
rankati per la selezione dei ~15 case study pilota che devono **dimostrare** la
validità della pipeline. La domanda scientifica non è "quanti geni DE" (la %DE non è
diagnostica — i cluster ad alta %DE sono per lo più concordi, vedi F5 sanity) ma
**"gli studi del cluster misurano lo stesso effetto?"** — cioè **replicabilità**
(NAS 2019: studi indipendenti, ognuno coi propri dati), non reproducibility.

Il proxy precedente (mediana delle correlazioni di Spearman dei logFC per-studio sui
top-2000 geni per min-p) è **selection-biased** (winner's curse / regression to the
mean indotti dal ranking per min-p; Li et al. 2011 critica esplicitamente lo Spearman
su liste rankate) e scarta la magnitudine. Va sostituito.

## Decisione di metrica (asse di consistenza)

Asse unico **consistenza ∈ [0,1]**, 1 = massima consistenza cross-studio, calcolato
per **tutti i 776 cluster**, sempre riassunto sui **geni FDR-significativi** del
pooled fit (FDR_BH_within_cluster < 0.05). Il razionale del gene set: ci interessa se
il **segnale DE** replica, non il rumore dei nulli; riassumere su tutti i geni sarebbe
dominato dalla nuvola dei nulli (eterogeneità rumorosa, non informativa).

Tre realizzazioni method-specific che convergono sullo stesso asse:

### mega (173, group-mode, k≥5) — VPC dell'effetto-studio random
Il modello pooled è `~ treatment + (1|study) + covariate`. Per gene, la **frazione di
varianza attribuibile a `(1|study)`** (variance partition coefficient = ICC) è
l'analogo di I² (I² = τ²/(τ²+σ²) è esso stesso un ICC). Si ricalcola con
`variancePartition::fitExtractVarPartModel` usando lo **stesso preprocessing** del
fullrun (filtro biotype protein_coding, TMM, covariate via `.augment_de_design`,
stessa formula). 
- componente nativa: `median_vpc_study` (mediana VPC_study sui geni sig) + IQR.
- **consistenza = 1 − median_vpc_study**.

### rem (28, k=3–8) — I² + prediction interval
I²/Q/τ² sono già in `cluster_pooled` (per-gene, solo rem).
- componente nativa: `median_I2` (mediana I² sui geni sig) + `tau2_median` (dispersione
  assoluta — I² è relativo e va accoppiato all'assoluto, Borenstein 2017).
- **consistenza = 1 − median_I2**.
- in più, **prediction interval 95%** ricalcolato con metafor (REML + correzione
  **HKSJ**, IntHout 2014/2016) per-gene → `pi_frac_excl0` = frazione di geni sig il cui
  PI 95% esclude lo 0 (= "replicabile in direzione in uno studio nuovo"). Riportato a
  fianco della consistenza, non fuso in essa.

### mega_aug (575, k=2) — sign-concordance dei 2 studi
A k=2 l'eterogeneità non è stimabile (Q ha 1 df, I²/τ²/PI inaffidabili). Dai
`per_study_de` dei 2 studi della coppia:
- **consistenza = sign_concordance** = frazione di geni sig su cui i 2 studi
  concordano nella direzione del logFC. Già su [0,1], 1 = pieno accordo.
- I²/τ²/PI = NA esplicito (non fabbricati).

### Caveat dichiarati (paper)
- I²/ICC sono **ratio relativi** (crescono con la precisione/sample size; Borenstein
  2017, Rücker 2008): la consistenza 1−I²/1−ICC va sempre accompagnata dalla
  dispersione assoluta (τ²/IQR) e, sui pilota finali, dal PI.
- L'equivalenza REM↔ICC è **strutturale, non numerica**: stessa *natura* (varianza
  between/total) ma stimata da modelli diversi → presentate come assi analoghi, non
  valori intercambiabili.
- k=2 domina (575/776): la consistenza interna lì è fragile (1 confronto di direzione)
  → per i mega_aug pesa di più la validazione esterna (Fase C: LOO/LINCS/pathway).

## Output / artefatti

Estensione di `cluster_reproducibility.rds` (per-cluster) con:
`cluster_id, method, k_studies, conc_confidence, n_sig_used, consistency_score,
median_vpc_study (mega), median_I2 + tau2_median + pi_frac_excl0 (rem),
sign_concordance (mega_aug)`, più i flag (es. `consistency_method`, NA dove non
applicabile).

Artefatti per-gene salvati per riuso (forest/heterogeneity plot dei pilota, evitare
ri-calcolo della parte costosa):
- `cluster_vpc_per_gene.parquet` (mega): cluster_id, gene_id, gene_symbol, vpc_study,
  vpc_treatment, vpc_residual.
- `cluster_pi_per_gene.parquet` (rem): cluster_id, gene_id, logFC_pool, pi_lower,
  pi_upper, tau2, I2.

Tutto gitignored (output di run), nella dir del run Stadio 4.

## Implementazione (pipeline superpowers — TDD)

**Helper puri in `R/` (TDD, input sintetici):**
- `.summarize_consistency_over_sig(values, fdr, threshold)` — mediana/IQR di una
  metrica per-gene sui soli geni sig (riusabile per VPC e I²).
- `.rem_prediction_interval(logFC, SE, level, knha)` — PI 95% per-gene via metafor
  REML+HKSJ; ritorna pi_lower/upper + flag excl0. Gestione k<2 (NA) e non-convergenza
  (fallback Paule-Mandel documentato, Veroniki 2016).
- `.sign_concordance(logFC_study_a, logFC_study_b, sig_mask)` — frazione direzione-
  concorde sui geni sig; gestione segni 0/NA.
- `.consistency_score(method, components)` — mappa method+componenti → [0,1] unico.

**Orchestrazione (script, NON unit-tested ma smoke-gated):**
`analysis/p4-fase-f6-consistency.R` — ricostruisce l'input per-cluster riusando gli
helper Stadio 4 già mappati (`.build_group_dispatch_from_stage3`,
`.build_mega_metadata_safe`, `fetch_fn` con cache calda, `.augment_de_design`; vedi
piano agente F6), ricalcola VPC (mega) / PI (rem) / sign-concordance (mega_aug),
scrive la tabella estesa + i parquet per-gene. **Gotcha** dal piano agente: prefiltro
sample H5, riattacco attr gene_symbol dopo cbind, biotype filter = protein_coding
(cache key), OPENBLAS/OMP=1, formula VPC = identica a dream via `.augment_de_design`.

**Smoke gate pre-run-pieno:** su ~6 cluster (2 mega + 2 rem + 2 mega_aug) verificare
che consistency_score sia in [0,1], che VPC_study sia sensato (>0, <1), che il PI rem
sia coerente con I², e wall/RSS per stimare il run pieno (~3–9h sui 173 mega).
Pattern del progetto (validate-before-fullrun).

## Cosa NON fa (YAGNI / scope)
- NON ricalcola i mega_aug LOO né la validazione esterna (Fase C, solo sui candidati).
- NON tocca il pooling già prodotto (`cluster_pooled.parquet` resta la verità del DE).
- NON fonde I²/PI in un singolo numero per i rem (PI riportato a fianco, non nello score).
- NON calcola consistenza interna per i mega_aug oltre la sign-concordance (k=2).

## Riferimenti
NAS 2019 (reproducibility vs replicability); Li et al. 2011 (IDR, critica Spearman);
Higgins & Thompson 2002 (I², soglie 25/50/75); Borenstein et al. 2017 ("I² is not an
absolute measure"); IntHout et al. 2014 (HKSJ), 2016 (prediction interval); Veroniki
et al. 2016 (stimatori τ²); Hoffman & Schadt 2016 (variancePartition); Nakagawa &
Schielzeth 2013 (ICC). Dettaglio in `analysis/audit/F5-concordance-metric.md` + deep
research 2026-06-15.
