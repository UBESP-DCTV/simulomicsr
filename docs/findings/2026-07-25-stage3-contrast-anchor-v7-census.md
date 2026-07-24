# Anchor derivato-dal-contrasto v7 — censimento di coerenza su TUTTI i cluster

**Data:** 2026-07-25 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato · nessun push
**Stato:** 🟡 **92,7% di coerenza misurata su TUTTI i 150 cluster poolabili, uno per uno. NON e' un
deliverable, NON e' "validato": nessun re-cluster e' stato lanciato e il residuo dell'7,3% e' aperto e
catalogato.**

---

## 0. Cosa e' stato deciso all'inizio della sessione (decisioni utente)

1. **Direzione opposta = NO.** Un cluster non puo' fondere agonista e antagonista dello stesso bersaglio
   (DHT + enzalutamide; glucosio deprivazione + aggiunta; TNF stimolo + inibitore): il **verso** entra
   nella chiave dell'anchor.
2. **Verso non determinabile = SCARTO** del cluster (non "unclear tenuto da parte").

---

## 1. Il numero, senza sconti

| | v6 (sessione precedente) | **v7 (questa sessione)** |
|---|---:|---:|
| poolabili k≥3 | 196 | **150** |
| di cui k≥5 | 70 | **74** |
| coerenti (censiti TUTTI) | 159 = 81% | **139 = 92,7%** |
| incoerenti residui | 37 | **11 = 7,3%** |
| studi-slot nei cluster coerenti | — | **866 / 934** |

Coerenti per forza: k=3-4 → 68 · k=5-9 → 53 · k=10-19 → 12 · k≥20 → 6.
Coerenti per classe: farmaco 85 · malattia 50 · infezione 3 · altro 1.

⚠️ **Le due percentuali NON sono confrontabili fra loro**: il giudice e la rubrica sono diversi (qui piu'
severi — contano come incoerenti anche le combo non catturate, il misto clinico/sperimentale, i controlli
di tessuto sbagliati). Il confronto valido e' la **chiusura uno-per-uno dei falliti catalogati in v6**.

## 2. Chiusura dei falliti v6 — verificata sui dati (`87-v6-failures-closure.R`)

**19 casi su 20 chiusi, 1 aperto.**

| esito | casi |
|---|---|
| chiusi diventando **coerenti** | bleomicina (k=5), temozolomide (k=5), vemurafenib (k=15), glucosio-deprivazione (k=3), HCC tessuto (k=8), lung adeno (k=5), heart failure (k=5), covid (k=12), artrite reumatoide (k=4) |
| chiusi **sparendo** (scartati o spezzati sotto k≥3) | i 16 bucket `+COMBO`, androgeno CHEBI:50113, estrogeno-deprivazione, TNF CHEMBL:265582, liver_cancer-plasma, THPO da `ug/ml`, CD8A da label, heat-shock+tabacco, environmental_or_behavioral, early/late_on_biopsy |
| **ancora aperto** | HBV: stato HBV in tumori (clinico) + infezione di epatociti in vitro |

## 3. Le regole che hanno prodotto il risultato (tutte deterministiche)

Ognuna nasce dall'ispezione dei falliti veri, non da un'idea a priori.

| regola | cosa chiude |
|---|---|
| **R1** on-contrast a parola intera sui token **distintivi** (anatomia e generici esclusi) | "lung adenocarcinoma" inghiottiva "SSc **lung** fibroblasts"; "heat shock" inghiottiva "**heat**ed tobacco" |
| **R2** nome del cluster **canonicalizzato** nello stesso spazio-ID dei membri | `NAME:cisplatin` e `CHEBI:27899` erano due cluster della stessa cosa |
| **R3** **verso** (gain/loss/block) nella chiave; verso ambiguo → scarto | glucosio, androgeno, estrogeno, TNF, calcio high-vs-low |
| **R4** **combo = entita' a se'** con la sua composizione, rilevata anche dal **label** e non solo dal delta | bleomicina/ALA, vemurafenib_acalabrutinib, estradiolo+fulvestrant, palbociclib+indisulam |
| **R5** **materiale per braccio** (liquido vs solido); bracci discordi → membro droppato | HCC tessuto-vs-plasma, HNSCC-vs-piastrine, mieloma (resta, coerente, tutto plasma) |
| **R6** **baseline propria** (longitudinale) separata dal controllo trasversale | artrite reumatoide settimane-vs-baseline, heart failure "Baseline Kidney" |
| **R7** **contrasto rotto** = anatomia / materiale / tipo cellulare dei due bracci disgiunti → membro droppato | AML-vs-"Normal Lung", gastrico-vs-"Normal liver", colon-vs-lung, CML-vs-lung, osteoartrite condrociti-vs-MSC |
| **R8** infezione **clinica vs sperimentale** separata (vale per ogni entita' NCBITaxon) | influenza, HIV |
| **R9** firma delle **classi** che cambiano nel delta | "LSCC + tabagismo": il delta isolava il tumore, l'entita' era *Nicotiana tabacum* |

## 4. Tre bug **miei**, trovati misurando e corretti (non nascosti)

1. `anatomy_of()` faceva `gsub("[^a-z ]")` **prima** di `tolower()`: `"Acute Myeloid Leukemia (Blood)"`
   diventava `"cute yeloid eukemia lood"` → la regola sul contrasto rotto era mezza morta.
2. La mia sanitizzazione toglieva i numeri isolati e **spezzava `sars-cov-2` → `sars-cov`**, cioe' il
   SARS del 2003 (`NCBITaxon:694009`): 166 membri finivano sull'entita' sbagliata.
3. `\b` in regex considera `_` un carattere di parola → `calcium_low` non matchava `\blow\b` e il verso
   opposto sfuggiva.

## 5. Bug ORTOGONALE di produzione (nomi, non coerenza) — da decidere

`.normalize_cytokine_to_hgnc()` (codice di **produzione**, usato dal recupero-nome v9/v10) risolve
**qualunque etichetta contenente `ug/ml`** a **THPO (HGNC:11795)**: ImmPort ha `ML` come sinonimo di
*Thrombopoietin*, e l'estrazione dei candidati produce `/ml`. Misurato:
`.normalize_cytokine_to_hgnc("GO 1 ug/ml 28 days")` → `HGNC:11795`; idem `"Doxorubicin 0.5 ug/ml 24h"`.
Stessa famiglia di ethanol→TNF e anisole→calcitriolo. **Non toccato in questa sessione** (i nomi sono
ortogonali alla coerenza, per decisione presa); qui e' registrato perche' qualcuno deve deciderlo.

## 6. Il residuo: 11 cluster, tutti catalogati (`v7-census-verdicts.csv`)

| causa | n | esempi |
|---|---:|---|
| disegno misto | 3 | artrite+metotrexato vs sano (isola malattia **e** terapia); M1-vs-M0 sotto GM-CSF; PTSD (perturbazione dentro-malattia + caso-controllo) |
| clinico vs sperimentale | 2 | CMV (viremia in pazienti + MRC5 in vitro), HBV (stato HBV in HCC + epatociti infettati) |
| co-infezione | 2 | M.tb da solo + M.tb+CMV; RSV da solo + RSV+rhinovirus |
| combo non catturata | 2 | "T3 and LPS" (T3 = 2 caratteri, sotto la soglia del rilevatore); E2+OTX015 |
| controllo incongruo | 1 | 5-FU con controllo "total RNA" + linea resistente senza farmaco |
| entita' estranea | 1 | "Her/Lap" (trastuzumab/lapatinib) dentro il cluster TGFB1 |

## 7. Limite noto NUOVO: frammentazione (costa k, non coerenza)

Nove entita' biologiche sono spezzate in 20 cluster: LPS (27+3), SARS-CoV-2 (31+3), enzalutamide (22+4),
R1881 (18+3), TGFB1 (28+7), ipossia (9+9+6), decitabina (5+4), nutlin (4+3, **due ID ChEBI per lo stesso
farmaco**), asma (4+3). Cause: veicolo scritto diversamente (`ethanol`, `rpmi media`), sigla non risolta
(`STR:enza`, `STR:aza_cdr`), sinonimo (`asthma`/`asthmatic`), duplicato ontologico. **~10 cluster in
eccesso**: unirli non cambia la coerenza, aumenta il k.

## 8. Cosa questo NON e'

- **NON e' un deliverable.** Nessun re-cluster (~8h) e nessun re-pool (~50h) sono stati lanciati.
- **NON e' "validato".** E' una simulazione sui 38.440 contrasti gia' ricostruiti, con un resolver piu'
  debole di quello di produzione: l'92,7% e' un **pavimento** su questo proxy, non una promessa sul run vero.
- **Il giudice del censimento e' Claude** (audit interno). La pipeline pubblicata resta deterministica e
  l'evaluator dichiarabile resta Mistral self-hosted: nessun componente di questo censimento entra nella
  pipeline.

## 9. Riproducibilita'

`analysis/audit/2026-07-24-anchor-coherence-sim/`: `80-reresolve-hardened.R` (risoluzione blindata) →
`81-fase1-v7-gate.R` (gate v7) → `84-gen-census-v7.R` (bundle di censimento, TUTTI) →
`86-census-verdicts.R` (catalogo verdetti) → `87-v6-failures-closure.R` (chiusura falliti v6).
Diagnostiche: `78-inspect-failures.R`, `79-diag-entity-source.R`, `79b-probe-resolver.R`, `82-diag-v7.R`,
`85-debug-rules.R`. Tabelle: `v7-census-verdicts.csv`, `v7-census-bundles.txt`.
