# Layer B v3 — il documento diventa pubblicabile

**Data:** 2026-08-06 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato, no push
**Artefatto:** `analysis/p4-output/20260806T143047Z-layer-b-81f379d3` (9 bundle, 37 PNG, HTML 14,9 MB)
**Commit:** `8876ade`

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

Suite `layer-b`: **527 PASS / 0 FAIL / 1 SKIP** (lo skip è il test dell'apertura, marcato
superato perché l'apertura non esiste più).

---

## 5. Limiti dichiarati

1. **Il layout non è stato verificato in un browser.** Il fix della tabella che sforava è
   verificato in modo statico (ogni tabella è dentro un contenitore `overflow-x: auto`,
   nessuna larghezza forzata inline), non aprendo la pagina: in questo ambiente il browser
   non raggiunge il server locale e non c'è un Chromium headless. **Va guardata a occhio.**
2. **Le narrative sono da firmare.** Sono verificate nei numeri e nei riferimenti, ma sono
   testo scientifico che l'autore deve leggere e fare proprio.
3. **Quindici disaccordi restano aperti** (§6): sono questioni che i fatti disponibili non
   chiudono, e sono state lasciate aperte invece di essere decise d'arbitrio.
4. Il peso dei confronti difettosi resta un **limite superiore** (attribuisce a un difetto
   l'intero peso dello studio).

---

## 6. I disaccordi da decidere

**Sui conteggi** (dieci, dall'arbitrato dei tre gruppi nuovi):

- **Crohn / GSE261086** (quattro confronti): l'etichetta dice `Inflamed colon mucosa` contro
  `Normal colon mucosa`, ma non nomina il Crohn, e lo studio tiene bracci `Crohn's disease X`
  e `Inflamed X` come distinti. È la coorte Crohn descritta con un'altra parola, oppure
  infiammazione di altra eziologia? L'etichetta non decide.
- **Crohn / GSE164871**: `Crohn's Disease CD4` — «CD4» è una popolazione cellulare isolata
  (materiale incompatibile col tessuto colico del controllo) o il codice di un paziente?
- **Crohn / GSE139179**: i bracci malati (retto, colon ascendente, discendente) sono
  confrontati con controlli di **sigmoideo**. Contato come difetto (18 confronti). È
  giusto, o in studi colici un unico sito di controllo è pratica accettabile?
- **Parkinson**: l'**età** del donatore va contata come il sesso? (GSE106608: 88 contro 66
  anni). E `Non-demented control` è un controllo valido per il Parkinson?

**Sulle narrative** (cinque questioni ricorrenti):

- se con I² di 95-99 si possa affermare che «gli studi concordano sul segno» (servirebbe il
  conteggio dei segni per studio, che non è nel materiale);
- se la testa dell'ordinamento per FDR a k basso sia segnale o artefatto della stima di τ²;
- se in IFN-γ vadano **esclusi** (non solo dichiarati) il confronto con co-infezione da
  *C. trachomatis* e quello su cellule IRF1-knockout;
- se in JQ1 si possa citare HEXIM1 come conferma, dato che per quel gruppo nessun bersaglio
  era stato fissato prima del run (osservazione a posteriori);
- se il gruppo Parkinson, che somma tre regioni cerebrali, neuroni da staminali e sette
  studi a tessuto non dichiarato, debba continuare a essere riportato come **un solo**
  contrasto caso-controllo.

Evidenza completa: `analysis/audit/2026-08-06-layer-b-v3/` (fatti per case study, conteggio
dei tre gruppi, pesi ricalcolati) e i journal dei due workflow.
