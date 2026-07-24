# Fase 1 — Validazione in simulazione dell'anchor derivato-dal-contrasto con ENTITÀ CANONICA

**Data:** 2026-07-24 · nessun re-cluster (simulazione sui 38.440 contrasti già ricostruiti).
**Scopo:** gate go/no-go PRIMA delle 8h di re-cluster. Provare che canonicalizzare l'entità-delta
(via resolver esistente) recupera k senza spezzare i cluster già coerenti.

## Verdetto: 🟡 DIREZIONE VALIDATA, MA NON PRONTO AL RE-CLUSTER

Il meccanismo centrale funziona (l'entità canonica **recupera k** e de-mescola i minestroni), ma tre
crepe nelle funzioni di supporto spezzerebbero i cluster oggi coerenti se re-clusterassimo ora. Sono
tutte fixabili prima del re-cluster (è esattamente ciò che il gate deve catturare).

## 1. Il meccanismo funziona (k recuperato)

- **SARS** `NCBITaxon:2697049`: i frammenti raw (k=7+4+4 nel lower bound) si **fondono in k=23** sotto
  l'entità canonica. Prova diretta che la canonicalizzazione recupera k cross-cluster.
- **Poolabili k≥3**: 132 (lower bound raw-label 126). **k≥5: 71 (lower bound 26)** — grosso guadagno di
  potenza dove conta.
- Per costruzione, ogni cluster-contrasto ha **una** entità canonica + **un** control_type (coerenza
  deterministica by-construction).

## 2. Le tre crepe (perché NON è pronto)

### Crepa A — control_type normalizer troppo stretto (FIXABILE, ben delimitato)
`.normalize_control_type` non collassa controlli equivalenti: "uninfected donor", "macrophage not
infected", "sirna against non targeting" restano distinti da `vehicle_untreated` → spezzano cluster
coerenti. **7/26 coerenti frammentati per control_type** (vemurafenib k=7→2 pezzi; carnitine, anisole,
INTS11, TGFB1, 4-maleylacetoacetate). Fix: estendere il vocabolario del normalizzatore.

### Crepa B — copertura del resolver sull'entità-delta (il collo di bottiglia)
**56% dei membri (21.702) → entità NA** (resolver non canonicalizza): soprattutto disease (MeSH manca
"Prostatic Neoplasms", "Crohn"…) e classi senza resolver (environment/radiation/immunization). **9/26
coerenti spariscono** (0 membri eleggibili: Hypoxia, X-ray, Immunization, obesity, endometriosis,
Sjogren, Rhinovirus, ZFX, training). Parte è il limite noto del name-recovery (disease), parte è la
crudezza del proxy Fase 1 (risolvo il treated_label grezzo; il build vero risolve la perturbazione con
più contesto) e il mio filtro che esclude la classe `environment` (Hypoxia è un contrasto legittimo).

### Crepa C — resolver inconsistente sull'entità (minore)
**4/26 coerenti frammentati per entità** (>1 ID canonico dentro un cluster davvero unico): RCC (3 ID),
rsv, ethanol, Staph. Sinonimi che risolvono a ID diversi ("renal cell carcinoma" vs "kidney cancer").

## 3. Bilancio sui 26 coerenti (il controllo di non-regressione)

| esito sotto anchor canonico | n | causa |
|---|---:|---|
| preservati puliti (ckey=1, k≥3 dove c'era) | 6 | — |
| frammentati per control_type | 7 | Crepa A (fixabile) |
| frammentati per entità | 4 | Crepa C |
| spariti (entità non risolta) | 9 | Crepa B + proxy Fase 1 |

Solo **6/26 puliti** → **NON si re-clusterizza ora** (regressione inaccettabile sui buoni).

## 4. Prossimo passo (prima di ri-valutare il gate)

1. **Estendere `.normalize_control_type`** (Crepa A) — vocabolario controlli (uninfected/not-infected/
   scramble/non-targeting → classe baseline appropriata). Ben delimitato, alto ritorno.
2. **Alzare la copertura entità** (Crepa B) — nel build vero risolvere la perturbazione (non il label
   grezzo); includere classi environment; misurare quanto del 56% NA è proxy-crudezza vs gap-resolver reale.
3. **Consolidare sinonimi entità** (Crepa C) — il resolver ha già la de-frammentazione; verificare perché
   non collassa RCC/rsv.
4. **Ri-eseguire Fase 1** con A+B+C → target: ≥24/26 coerenti preservati + k≥3 ≫ 132 + SARS k≥23.
   Solo allora GATE → utente → re-cluster.

## Dati
`70-fase1-canonical-sim.R` (engine) · `71-fase1-diagnosis.R` (diagnosi) ·
`fase1-pm.rds`/`fase1-results.rds` (scratchpad, gitignored). Resolver validato: enzalutamide→CHEBI:68534,
SARS→NCBITaxon:2697049, TNF→HGNC:11892, HCC→MeSH:D006528 (drug/cytokine ottimi; disease/infection con buchi).
