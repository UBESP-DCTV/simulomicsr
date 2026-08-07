# Layer B v3 — il documento diventa pubblicabile

**Data:** 2026-08-06 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato, no push
**Artefatto:** `analysis/p4-output/20260807T103637Z-layer-b-81f379d3` (9 bundle, 37 PNG, HTML 14,9 MB)
**Commit:** `8876ade`, `38cdeff`, `6fa7743` · **Aggiornato:** 2026-08-07 (§6 e §7)

---

## 1. Il difetto peggiore: un numero inaffidabile pubblicato

Il report v2 stampava, per i tre case study fuori dai tredici gruppi grandi:

> «? confronti imperfetti su ? (100,0% del peso stimato della meta-analisi)»

Il conteggio non c'era (i punti di domanda), ma **il peso veniva stampato lo stesso**, e
veniva da `peso_citati`: la quota degli studi *citati nelle motivazioni* della rilettura,
estratti con un'espressione regolare. È la misura che il progetto stesso dichiara cieca —
`docs/findings/2026-08-05-confronti-imperfetti.md` §5.4, mediana 87%, perché raccoglie
anche gli studi citati come **puliti**, e in un gruppo da quattro studi citarne due copre
quasi tutto.

**Che cosa è stato fatto.** I tre gruppi mancanti hanno ora un conteggio vero, con lo
stesso metodo dei tredici (un contatore che legge le etichette intere), ma con **due
critici simmetrici** invece di uno spinto alla severità: uno sostiene che il contatore ha
accusato troppo, l'altro che ha accusato troppo poco, e un arbitro decide sull'etichetta
dichiarando i disaccordi che l'etichetta non chiude. Poi il peso è stato **ricalcolato per
tutti e sedici i gruppi** dagli studi che il *conteggio* identifica (mediana `1/SE²` per
studio, normalizzata dentro il gruppo), non da quelli citati nelle motivazioni.

| gruppo | conteggio | peso pubblicato in v2 | peso con la regola unica |
|---|---:|---:|---:|
| **IL1A** | 3 di 7 | **100,0%** | **10,1%** |
| **Parkinson** | 3 di 29 | 60,1% | 12,6% |
| **Crohn** | 18 di 42 | 10,1% | 4,9% |
| palbociclib | 11 di 39 | 32,1% | 16,1% |
| cisplatino | 5 di 49 | 15,2% | 4,7% |
| LPS-like `d9e23e09` | 4 di 71 | 8,6% | **13,8%** (in su) |
| gli altri dieci | invariati | — | — |

**Regola nuova, in codice:** `.lb_confronti_imperfetti_txt()` pubblica il peso **solo
insieme al conteggio**. Senza conteggio dichiara *"not measured for this group"*, e il peso
non compare. Fonte unica: `analysis/audit/2026-08-06-layer-b-v3/confronti-imperfetti-conteggio.json`,
prodotta da `10-conteggio-e-peso.R`.

⚠️ **Conseguenza da riportare nei Methods:** la tabella §3.2 del finding del 2026-08-05
contiene tre numeri (palbociclib, cisplatino, `d9e23e09`) calcolati sugli studi *citati*
invece che su quelli *contati*. Con la regola unica cambiano come sopra.

---

## 2. Le narrative: da testo generato a testo firmato

`.narrativa_bozza()` componeva la narrativa dalle colonne del deliverable. Il risultato
erano nove testi formalmente corretti, con la stessa forma di frase ripetuta nove volte, e
senza contenuto scientifico. **La funzione è stata rimossa**, insieme al suo file di test.

Al suo posto `build_layer_b_results(narrative_provider = ...)`, che legge il testo da
`analysis/layer-b-narratives/<cluster_id>.md`. Un gruppo senza file non riceve un testo
generico: il documento dichiara che la narrativa non è disponibile e `run_metadata` lo
registra (`input_files$narrative$cluster_id_senza_narrativa`).

**Come sono state prodotte** (workflow, quattro agenti per case study, 36 in tutto):

1. un **ricercatore** che fa ricerca bibliografica vera (WebSearch/WebFetch) e scrive la
   narrativa coi riferimenti, prendendo ogni cifra dal file dei fatti;
2. un **verificatore dei numeri**, con un compito solo: ogni cifra contro deliverable e
   parquet;
3. un **contestatore** che attacca su quattro fronti (esistenza e pertinenza dei
   riferimenti, affermazioni non supportate, limiti taciuti, stile);
4. la **difesa**: il ricercatore replica, accetta ciò che regge, respinge ciò che non
   regge *con l'argomento*, ed escala ciò che i fatti non chiudono.

**Bilancio: 112 rilievi accettati, 21 respinti con argomento, 15 escalati.** Nella sessione
precedente lo stesso impianto, con un solo critico spinto alla severità, aveva prodotto 24
verdetti cambiati **tutti** verso il peggio e zero assoluzioni. Qui i verdetti vanno in
entrambe le direzioni.

I nove testi: 682-871 parole, 5-10 riferimenti ciascuno con PMID, **67 PMID** nel
documento.

**Un errore trovato dal contestatore, per dare la misura:** la narrativa di DHT affermava
che «le stime più significative sono piccoli scarti riproducibili misurati in tutti e 23
gli studi». È falso in cima all'ordinamento: il primo è AFP (−2,000, k=5), il secondo
COL22A1 (+4,412, k=2). Riscritto, con AFP nominato e i k bassi dichiarati.

**Un errore mio, non degli agenti:** il file dei fatti riportava come «geni testati» il
numero *deduplicato per simbolo* (17.733 per DHT invece di 19.186 identificativi Ensembl,
che sono l'unità del test). Una narrativa su nove ci è cascata; corretta la fonte e il
testo.

---

## 3. Le altre sei richieste

| # | richiesta | esito |
|---|---|---|
| 1 | via l'apertura sull'impianto e le note di processo, niente corpus in apertura, mai «sporco» | il documento apre su una *Introduction* neutra; «Comparisons with a design defect» al posto di «Quanto è sporco» |
| 2 | tutto in inglese | schede, narrative, didascalie, **titoli delle figure** (`.lb_titolo()` diceva «59 studi») |
| 3 | «Numeri verificabili» → titolo professionale, tabella che sfora sull'indice | «Top-ranked genes», in un contenitore `overflow-x: auto; max-width: 100%`, otto colonne invece di nove |
| 4 | numerare i case study | «Case study 1 — …» |
| 5 | eliminare l'elenco delle figure | rimosso da `.write_narrative_template()`, insieme ai tre test che lo fissavano |
| 8 | dopo i case study, la descrizione delle 214 | sezione conclusiva con figura + quattro tabelle **calcolate** da `.corpus_tabelle()`, mai numeri cablati |

---

## 4. Verifica sull'artefatto

Sul file HTML prodotto, non sul sorgente: 9 case study numerati · 37 immagini incorporate ·
0 riferimenti esterni · 0 occorrenze di elenco-figure, «BOZZA», «sporco»/«dirty»,
«? confronti», «for cluster», titoli in italiano · 67 PMID · 13 tabelle, tutte dentro il
proprio contenitore, nessuna larghezza forzata.

**Le figure sono state aperte e guardate**, non solo contate: la figura del corpus, il
forest di TGF-β1 (i bersagli canonici sopra, PMEPA1 su tutti e 59 gli studi sotto), la
heatmap di IFN-γ (firma canonica, separazione netta), il volcano di enzalutamide, il forest
di IL1A.

Suite `layer-b`: **537 PASS / 0 FAIL / 1 SKIP** (lo skip è il test dell'apertura, marcato
superato perché l'apertura non esiste più).

---

## 5. Limiti dichiarati

1. ~~Il layout non è stato verificato in un browser.~~ **Verificato dall'utente il
   2026-08-07**: la formattazione regge, la tabella non sfora più sull'indice. Il fix è il
   contenitore `overflow-x: auto` con `max-width: 100%` attorno a ciascuna tabella e
   nessuna larghezza forzata inline; qui restava verificabile solo in modo statico, perché
   in questo ambiente il browser non raggiunge il server locale e non c'è un Chromium
   headless.
2. **Le narrative sono da firmare.** Sono verificate nei numeri e nei riferimenti, ma sono
   testo scientifico che l'autore deve leggere e fare proprio.
3. ~~Quindici disaccordi restano aperti.~~ **Decisi il 2026-08-07** (§6): uno era una
   misura mai fatta ed è stato misurato; gli altri seguono la regola prudente dichiarata
   nel documento.
4. Il peso dei confronti difettosi resta un **limite superiore** (attribuisce a un difetto
   l'intero peso dello studio).

---

## 6. I quindici disaccordi: decisi (2026-08-07)

Decisione dell'utente: non si rimandano, si decidono sui dati, e **nel dubbio si
sceglie la lettura prudente**.

### 6.1 Una domanda non era un'opinione: era una misura mai fatta

Cinque narrative si erano fermate sulla stessa obiezione — con I² fra 87 e 96, si puo'
dire che gli studi concordano sul *segno*? Il contestatore aveva ragione sul metodo (l'I²
misura la varianza delle magnitudini, non la direzione) e torto sul fatto: i segni per
studio stanno in `per_study_de.parquet`. Misurati
(`analysis/audit/2026-08-06-layer-b-v3/20-concordanza-di-segno.R`), sui bersagli fissati
prima del run:

| gruppo | stime per-studio concordi col segno poolato | I² mediano |
|---|---:|---:|
| IFN-γ | **91 / 91 (100%)** | 90,5 |
| TGF-β1 | 320 / 353 (90,7%) | 93,5 |
| DHT | 71 / 79 (89,9%) | 85,1 |
| SARS-CoV-2 | 114 / 135 (84,4%) | 95,6 |
| enzalutamide | 58 / 71 (81,7%) | 87,9 |

Eterogeneita' altissima nelle *ampiezze* e concordanza alta nella *direzione* convivono, ed
e' esattamente la lettura che il progetto sosteneva senza averla misurata. Le cinque
narrative ora riportano la cifra invece della cautela.

### 6.2 I dieci confronti che l'etichetta non decideva

Regola applicata, dichiarata nel documento: **quando l'etichetta ammette due letture, il
confronto si conta come difettoso**. E' coerente con una misura gia' dichiarata limite
superiore. La regola non e' "conta tutto": due confronti contestati **non** sono stati
contati, perche' l'etichetta li decide (un genotipo knockout identico sui due bracci isola
correttamente il trattamento — e' il caso GSE178714 gia' ritrattato dal progetto; e un
difetto di composizione gia' contato una volta nel verdetto di coerenza).

| gruppo | prima | dopo | peso |
|---|---:|---:|---:|
| Crohn | 18 / 42 | **25 / 42** | 4,9% → 11,7% |
| Parkinson | 3 / 29 | **9 / 29** | 12,6% → **81,1%** |
| IL1A | 3 / 7 | 3 / 7 | 10,1% |

L'81,1% di Parkinson e' voluto e va letto con la definizione accanto: lo studio che porta
il 73% del peso e' fra quelli con un confronto difettoso, e il limite superiore attribuisce
al difetto l'intero peso dello studio. In un gruppo gia' dichiarato dominato da un solo
studio e a materiale misto, e' l'informazione corretta.

Dettaglio per singolo confronto, con la motivazione:
`analysis/audit/2026-08-06-layer-b-v3/decisioni-conservative.json`.

### 6.3 Le cinque questioni sulle narrative

- **concordanza di segno** → misurata (§6.1);
- **testa dell'ordinamento a k basso** → descritta senza attribuirle una causa: a due o tre
  studi la varianza fra studi non e' stimabile e collassa a zero, il che comprime l'FDR;
  il documento lo dice, e il filtro di copertura tiene quei geni fuori dagli ordinamenti;
- **IFN-γ, i due confronti contestati** → non esclusi dal pooling (escluderli sarebbe una
  lista scritta a mano, l'errore gia' pagato) ma **dichiarati** nella narrativa: uno porta
  una co-infezione che induce parte dello stesso programma, l'altro stima IRF1 includendo
  cellule IRF1-deficienti;
- **JQ1 / HEXIM1** → mantenuto, con la dichiarazione che per quel gruppo nessun bersaglio
  era stato fissato prima del run e che i geni sono riportati come osservati;
- **Parkinson come contrasto unico** → il verdetto non e' stato ritrattato (i verdetti sono
  lettura umana, e ritrattarne uno a mano e' l'errore gia' pagato), ma la narrativa ora
  riporta il conteggio dei confronti mal appaiati accanto alla dominanza e al materiale
  misto.

---

## 7. Correzioni al testo pubblicato (2026-08-07)

Tre cose che finivano nel documento e non dovevano:

1. **Le motivazioni delle undici incoerenti** erano il verbale della lettura umana: in
   italiano, lungo, e in un caso con dentro la data e l'autore della decisione. Ora vengono
   da una traduzione editoriale breve (`inst/extdata/coherence-reason-en.csv`); un gruppo
   senza traduzione **non** ricade sull'italiano, dichiara che manca.
2. **Una etichetta di entita' era in italiano** (`antigen (classe-ombrello)`). Corretta
   nell'override canonico, che ora viene **riapplicato al momento della pubblicazione**:
   una correzione di testo non richiede un re-pool di 214 meta-analisi.
3. **La tabella della selezione in appendice** stampava la colonna `notes`, cioe' appunti
   di lavoro col gergo interno e i numeri di un run precedente scritti a mano. Ora mostra
   solo le colonne pubblicabili; le note restano nel CSV accanto al documento.
