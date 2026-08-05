# I 13 verdetti tolti dal file passato all'annotazione, e la prova

**Data:** 2026-08-05 · **Pool:** `20260805T004943Z-stage4-v15-d29545c7`

Dei 24 verdetti di incoerenza della FASE D0ter, **11 agganciano un gruppo del
deliverable e 13 no**. I 13 non sono stati rinominati ne' fusi: i loro gruppi
**non superano il gate del pooling** (controlli interni), come i 137 candidati
su 351 che non arrivano al deliverable. Erano stati letti sul CENSIMENTO dello
Stadio 3, dove esistono; nel poolato non ci sono.

Perche' toglierli e' sicuro, e perche' NON e' il pre-filtro corretto il 2026-08-01:
quel difetto riguardava un gruppo **presente nel poolato** con chiave diversa
(`adenoma`), che tolto il verdetto usciva marcato `coherent`. Qui nessuna delle
13 entita' compare fra le 214 meta-analisi: non c'e' nessun gruppo da marcare.
**La guardia nel codice NON e' stata toccata** e resta fatale.

| entita | k censito | nel poolato? | l'entita compare fra le 214? |
|---|---:|---|---|
| `CHEMBL:CHEMBL2108494` | 5 | non poolato | entita assente dalle 214 |
| `NCBITaxon:12814` | 4 | non poolato | entita assente dalle 214 |
| `STR:pathogen_or_aggregate_exposure` | 4 | non poolato | entita assente dalle 214 |
| `MeSH:D008113` | 3 | non poolato | entita assente dalle 214 |
| `MeSH:D016889` | 3 | non poolato | entita assente dalle 214 |
| `NCBITaxon:32644` | 3 | non poolato | entita assente dalle 214 |
| `STR:diseased` | 3 | non poolato | entita assente dalle 214 |
| `STR:fshd1` | 3 | non poolato | entita assente dalle 214 |
| `STR:myotonic_dystrophy_type_1` | 3 | non poolato | entita assente dalle 214 |
| `STR:osteogenic_differentiation` | 3 | non poolato | entita assente dalle 214 |
| `STR:ovarian_tumor` | 3 | non poolato | entita assente dalle 214 |
| `STR:rhinovirus` | 3 | non poolato | entita assente dalle 214 |
| `STR:tuberculosis` | 3 | non poolato | entita assente dalle 214 |

Verdetti passati all'annotazione: **11** (file `verdetti-poolato-v15-applicabili.csv`).
