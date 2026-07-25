# Censimento di coerenza sui gruppi del builder: 141 coerenti su 145, letti uno per uno

**Data:** 2026-07-27 · **Branch:** `review-scientific-consistency-2026-06-10`
**Stato:** 🟡 **Censimento fatto su TUTTI i gruppi, mai a campione. Nessun re-cluster, nessun
re-pool: niente e' materializzato. Questi numeri vanno RIFATTI sui dati veri dopo il re-cluster.**

---

## 1. Perche' rifare il censimento

La sessione precedente aveva letto 144 gruppi e ne aveva giudicati coerenti 141 (97,9%). Quel numero
**non si trasferisce**: i gruppi qui sono prodotti dal codice di pacchetto, la loro composizione e'
cambiata, e due sono nuovi. Riportare il 97,9% senza rileggere sarebbe stato esattamente l'errore che
questo progetto ha gia' fatto per mesi.

**Criterio** (definizione dell'utente, 2026-07-24): un gruppo e' coerente se genera una meta-analisi
difendibile, cioe' se **tutti** i confronti che contiene misurano lo **stesso** contrasto. La forza
(k, I²) si riporta accanto: non e' il gate.

**Metodo:** un bundle per gruppo con l'identita' del contrasto, tutti i confronti tenuti
(studio, trattato ⇒ controllo) e i confronti scartati della stessa entita'. Letti tutti, uno per uno
(`bundle-gruppi.txt`, 2.679 righe).

## 2. Esito

| | |
|---|---:|
| gruppi poolabili k≥3 | **145** |
| **coerenti** | **141 (97,2%)** |
| incoerenti | 4 |
| studi-slot nei coerenti | **866 / 878** |

Forza dei coerenti: k=3-4 → 75 · k=5-9 → 47 · k=10-19 → 14 · k≥20 → 5.

**Rispetto al gate misurato:** zero gruppi persi, **k identico su tutti e 144**, uno nuovo
(`MeSH:D012008`, giudicato incoerente).

## 3. I quattro incoerenti

| gruppo | k | perche' |
|---|---:|---|
| `HGNC:2434` (CSF2) | 3 | due studi stimolano con GM-CSF contro mock; il terzo confronta macrofagi **M1** (GM-CSF **+ IFN-γ**) contro **M0**. La polarizzazione non e' la stimolazione: cambia anche l'IFN-γ e il controllo e' uno stato di differenziamento, non un veicolo. |
| `STR:ptsd` | 3 | due studi sono caso-controllo (PTSD contro sano); il terzo confronta una perturbazione **dentro** i malati (`Current PTSD, perturbation` contro `Current, no perturbation`). |
| `NCBITaxon:12814` (RSV) | 3 | mescola sorveglianza **clinica** (pazienti positivi contro controlli) e infezione **sperimentale** (H292 e epitelio polmonare contro mock). |
| `MeSH:D012008` (Recurrence) — **nuovo** | 3 | recidiva contro diagnosi nelle leucemie, ma un membro confronta `Untreated` contro `Diagnosis` (non una recidiva) e due membri appaiano **pazienti diversi**. L'entita' e' uno stato clinico, non una perturbazione. |

I primi tre sono **gli stessi tre** del censimento del 2026-07-25: il codice di pacchetto non ha
introdotto incoerenze nuove, e non ha risolto quelle note.

**Perche' le regole non li prendono:** per RSV la regola clinico-vs-sperimentale esiste ma non scatta,
perche' il controllo clinico di quello studio (`Control CV`) non usa nessuna delle parole del
vocabolario. Per CSF2 e PTSD servirebbe capire che il **controllo** e' uno stato (M0, malato non
perturbato) e non un veicolo. Sono tre casi su 145: **non ho inventato una regola per prenderli**,
perche' una regola scritta su tre casi e' una lista travestita.

## 4. Un dodicesimo bug, trovato leggendo

Il gruppo **`STR:fetal||gain||adult`** (k=3: cellule B timiche, epitelio alveolare, parotide) era nato
da un delta di sola **classe tempo**. Il gate misurato escludeva quella classe dall'universo
poolabile; il mio codice non filtrava per classe. Uno stadio di sviluppo e' una dimensione
identitaria, non una perturbazione (ADR-0025 §4, decisione dell'utente 2026-07-24). Corretto: 229
membri ora scartati con ragione `classe_non_contrastiva`, il gruppo sparisce, **nessun altro gruppo
cambia**.

## 5. Frammentazione: la stessa entita' in due gruppi

Il censimento ha reso visibile un problema che i conteggi non mostrano.

| entita' | ID ontologico | sigla non risolta | k separati |
|---|---|---|---:|
| enzalutamide | `CHEBI:68534` | `STR:enza` | 21 + 4 |
| TGF-β1 | `HGNC:11766` | `STR:tgfb` | 27 + 7 |
| ipossia | `NAME:hypoxia` | `STR:hypoxia` | 9 + 9 |
| SARS-CoV-2 | `NCBITaxon:2697049` | `NAME:sars-cov-2` | 28 + 3 |

**Due di questi quattro sono artefatti della misura, non del build.** `NAME:` non esiste nel codice:
lo produce il *proxy* che uso per l'equivalenza quando il nome del cluster non canonicalizza. Nel
build l'anchor porta un ID vero, quindi ipossia e SARS si fondono da sole.

**Gli altri due sono reali e restano:** `ENZA` e `TGFb` sono scritture che il resolver non riconosce,
e producono un secondo gruppo separato dallo stesso oggetto biologico. Non e' un difetto del gate di
coerenza — entrambi i gruppi sono internamente coerenti — ma e' **potenza buttata**: enzalutamide
sarebbe k=25 invece di 21+4, TGFB1 k=34 invece di 27+7.

**Questo riapre una decisione.** Il 2026-07-26 l'utente ha deciso di non ri-mappare le sigle bloccate
dal resolver (opzione A), sulla base di una misura che dava **0 gruppi poolabili nuovi**. Quella
misura era giusta e resta giusta: qui infatti **non nascono gruppi nuovi**, si fondono gruppi
esistenti. Ma il guadagno di potenza non era stato quantificato cosi', e ora lo e'. **Non decido io:
lo porto al tavolo con i numeri.**

## 6. Che cosa questo NON dimostra

- **Non e' una misura sui dati veri della pipeline.** Gira sui contrasti gia' ricostruiti
  (`fase1-v11-results.rds`), non sull'output di un re-cluster. Il 97,2% e' un **pavimento da
  riverificare**, non un risultato.
- **Il ramo on-contrast usa un proxy** del nome dell'anchor. Nel build quell'ID viene dal record: e'
  la stessa fonte, ma la coincidenza va riverificata.
- **I verdetti sono giudizi di lettura**, non l'output di una regola. Sono ripetibili da un umano che
  legge gli stessi bundle; non sono deterministici nel senso della pipeline.
- Il campo `nome` nei bundle e' inaffidabile (prende il nome del *vecchio* cluster: `STR:keloid`
  compare come "Atopic Dermatitis"). Non tocca i verdetti, che si leggono dai confronti.

## 7. Riproducibilita'

`analysis/audit/2026-07-27-contrast-builder/`: `10-equivalenza-builder.R` →
`40-bundle-gruppi.R` (`bundle-gruppi.txt`, `gruppi-indice.csv`) → `50-smoke-bandiera.R`
(`smoke-bandiera.csv`) → `60-verdetti-censimento.R` (**`censimento-verdetti.csv`**, una riga per
gruppo con verdetto e motivo).
