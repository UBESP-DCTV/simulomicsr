# Censimento v13: 296 gruppi coerenti su 305 (97,0%), dopo le sei regole

**Data:** 2026-07-28 · **Branch:** `review-scientific-consistency-2026-06-10`
**Sorgente:** `analysis/p4-output/20260728T151529Z-stage3-v13-364547a7` (re-cluster, 8h43m)
**Stato:** 🟡 **Secondo censimento su output di pipeline vero. Nessun re-pool: i gruppi non
sono poolati, I² e τ² non esistono ancora.**

---

## 1. Esito

| | v12 | **v13** |
|---|---:|---:|
| gruppi del deliverable | 312 | **305** |
| **coerenti** | 297 (95,2%) | **296 (97,0%)** |
| incoerenti | 15 | **9** |
| studi-slot (somma k) | 2.076 | **2.158** |
| k≥10 | — | 53 |

**Meno gruppi, più studi dentro**: è quello che devono fare le fusioni dei controlli sinonimi.
La coerenza sale di 1,8 punti e gli incoerenti scendono da 15 a 9.

**Bandiera, tutte cresciute o stabili**: SARS 38 (=) · TGFB1 61→**65** · LPS 41→**50** ·
enzalutamide 29 (=) · vemurafenib 19→**20**. Erano stati previsti esattamente così dalla misura
fatta prima del run (TGFB1 65, LPS 50, vemurafenib 20): la stima pre-run era fedele sulle
bandiera, **sbagliata sul conteggio** (aveva detto 360 gruppi perche' applicava una dedup diversa
da quella dello Stadio 4).

## 2. Come e' stato verificato: identita', non campionamento

Dei 305 gruppi, **242 hanno l'insieme dei membri identico a v12** — stessi record, quindi stesso
verdetto. Non e' un'assunzione: e' un confronto di insiemi, gruppo per gruppo. Sono stati riletti
i **63 restanti** (51 con composizione cambiata + 12 nuovi), uno per uno.

## 3. Che cosa hanno chiuso le sei regole

Delle 15 incoerenze di v12 ne restano 4 (Recurrence, adenoma, CSF2, PTSD: nessuna regola scritta
per loro, per scelta). Chiuse:

| | esito |
|---|---|
| cytokine_stimulation, U0126, `2_gram`, IAA, dTAGv-1, auxina, `affected` | **spariti** |
| **HIV-1** | **chiuso**: k=6 tutti sperimentali, i 2 studi clinici separati sotto soglia |
| **TP53** | **chiuso e ricomposto**: il gruppo `gain` che mescolava knockout e sovraespressione e' sparito; ne e' nato uno **`block` k=3 pulito** (TP53 KO, TP53(-/-), TP53 Knockdown) |
| influenza | migliorato: da 2 clinici su 10 a **1 su 9** |

Il caso TP53 e' il più istruttivo: la regola sulla notazione `-/-` non ha solo tolto un membro
sbagliato, ha **fatto nascere una meta-analisi corretta** che prima non esisteva.

## 4. I nove incoerenti

Dettaglio in `analysis/audit/2026-07-28-censimento-v13/verdetti-v13.csv`.

**Quattro invariati** (nessuna regola scritta): Recurrence, adenoma (ipofisario + colon), CSF2
(polarizzazione M1/M0), PTSD (perturbazione dentro-malattia).

**Uno migliorato ma non chiuso**: influenza — GSE113210 indica le visite cliniche con le sigle
`AV`/`CV`; nessuna regola generale puo' dedurlo e una scritta su questo caso sarebbe una lista.

**Quattro nuovi o resi visibili dalla crescita** — e vanno detti, perche' sono il prezzo delle
fusioni:

- **HGNC:5417 (IFN-α)**: GSE126517 misura R5020, non interferone. Lo stesso studio compare
  identico nel gruppo `STR:r5020`: e' un membro attribuito due volte a entita' diverse.
- **HGNC:5991 (IL1A)**: mescola IL-1α e IL-1β. GSE155141 e GSE205853 sono IL-1β, che ha un gruppo
  proprio con k=26. Errore di risoluzione preesistente, diventato visibile ora che il gruppo e'
  passato da k=3 a k=6.
- **HGNC:6011 (IL3)**: invariato — `iL3` sono larve di nematode.
- **CHEBI:59132 (DCVC)**: tre contrasti diversi sotto una sola entita'.

## 5. Le etichette restano sbagliate (gli ID no)

Il problema dichiarato il 2026-07-28 non e' stato toccato ed e' ancora li': `CHEBI:63637` mostrato
come "sodium aurothiomalate" e' vemurafenib, `CHEBI:5931` "chloride" e' insulina, `CHEBI:16335`
"glucose" e' adenosina, `CHEBI:16796` "hydron" e' melatonina. **Gli ID sono giusti**: sbagliata e'
l'etichetta ereditata dall'anchor vecchio. Va risolta da `contrast_entity` prima del paper.

## 6. Frammentazione: ridotta, non chiusa

Le fusioni hanno riunito i controlli sinonimi (DHT 27+3→34, LPS 41+3→50, IFN-γ 30+3→35,
TGFB1 61+3→65, R1881 4→26). Resta la frammentazione da **scritture diverse della stessa entita'**,
che era fuori dallo scope deciso: ATRA vs acido retinoico, `STR:ifna` vs `HGNC:5417`,
`STR:il17` vs `HGNC:5981`, nutlin su due ID ChEBI.

## 7. Che cosa questo NON dimostra

- **Non e' una validazione del pooling**: i gruppi non sono poolati, non esistono I², τ², geni
  significativi. Il re-pool (~50 h) e' dietro un GO dell'utente.
- **I verdetti sono giudizi di lettura**, ripetibili da un umano sugli stessi bundle, non l'output
  di una regola.
- **Il 97,0% e' la coerenza dei raggruppamenti prima del pooling.** Se il re-pool scartasse membri
  per ragioni sue, andrebbe rimisurata.

## 8. Riproducibilita'

`analysis/audit/2026-07-28-censimento-v13/`: `10-bundle-v13.R` → `bundle-v13-compatto.txt`
(i 63 riletti) · `verdetti-v13.csv` · `deliverable-v13.rds` (305 gruppi con lo stato
invariato/cambiato/nuovo). Regole: `R/stage3-contrast-gate.R`, `R/stage3-coherence.R`,
`R/stage3-contrast-anchor.R`; test `tests/testthat/test-stage3-contrast-gate-v13.R` (71 PASS).
Misura pre-run: `analysis/audit/2026-07-28-censimento-v12/40-impatto-regole.R`.
