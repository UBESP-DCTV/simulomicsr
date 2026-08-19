# Le 194 meta-analisi, lette tutte: quante sono giuste

**Data:** 2026-08-20 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Deliverable letto:** `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`
**Riferimento per il confronto:** `.../20260815T193851Z-stage4-v16-3e31e59d`
**Evidenza:** `analysis/audit/2026-08-20-rilettura-194/`

---

## 0. La domanda, e la risposta in una riga

La domanda non era quante meta-analisi cambiano rifacendo gli stadi LLM — quella
e' una statistica sull'instabilita'. Era se le meta-analisi che il metodo produce
siano **giuste**.

Sono state lette tutte e 194, una per una, nessuna esclusa. **116 sono corrette
(59,8%), 62 hanno almeno un confronto difettoso (32,0%), 16 non sono decidibili
dall'etichetta (8,2%).**

E il difetto non e' distribuito a caso: **cresce con la dimensione del gruppo.**
Fra le 114 meta-analisi a k=3-4 e' difettoso il 22,8%; fra le 14 con k≥15 e'
difettoso il **78,6%**. Delle quattordici piu' grandi, **una sola e' pulita**
(TNF, k=36).

---

## 1. Che cosa e' stato letto, e perche' e' la cosa giusta

Il materiale non e' l'elenco degli studi assegnati dallo Stadio 3: sono i
**confronti effettivamente poolati**, cioe' le entry del dispatch di produzione
che hanno superato il gate `n_min` biologico (dopo il collasso delle corsie) e la
dedup `serie||braccio-trattato`.

La distinzione non e' formale. Il 2026-08-05 il materiale elencava i confronti di
uno studio non appena lo *studio* compariva nel poolato: **47 accuse su 85
riguardavano confronti che nel deliverable non c'erano.**

La ricostruzione passa **quattro prove di accettazione**, due per esecuzione:

| prova | A3 | riferimento |
|---|---|---|
| A — registro degli scarti identico a `qc_report$dispatch_drops` | **3.319 = 3.319** | **3.345 = 3.345** |
| B — coppie (cluster, studio) identiche a `per_study_de.parquet` | **1.178 = 1.178** | **1.343 = 1.343** |

Le prove hanno lavorato: la prima versione della replica **falliva la prova A**
(2.466 scarti contro 3.319). Tre cose mancavano, e ognuna era un passo che la
produzione fa prima del dispatch:

1. **il pre-filtro del master Stadio 2 contro l'asse dei campioni dell'H5** (15
   campioni su 491.071 non esistono in ARCHS4 v2.5, e vanno tolti dai bracci
   prima di misurarne la dimensione);
2. **lo spostamento dei record dei cluster assorbiti dalle fusioni** sul cluster
   vincente (6 cluster in A3, 7 nel riferimento);
3. **le corsie costruite su tutti i campioni del Layer A** (316 cluster
   candidati), non sui soli 194 sopravvissuti.

Con i tre passi al posto giusto, la replica riproduce la produzione alla riga.

**Numeri del deliverable A3, misurati:** 194 meta-analisi, **1.178** coppie
gruppo-studio, **1.903** confronti poolati, 993 studi distinti.

> ⚠️ **Il handout dava 1.381 coppie gruppo-studio. Il numero non torna con
> nulla.** 1.178 e' confermato tre volte in modo indipendente: da
> `per_study_de.parquet`, dalla replica del dispatch, e dalla colonna
> `k_effective` del deliverable stesso (la cui somma e' 1.178). 1.903 sono i
> confronti, che e' un'altra cosa.

---

## 2. Le etichette sono intere: verificato, non assunto

Il progetto ha gia' dato tre verdetti su mezza frase. Il controllo qui non e' una
formula ma un'ispezione.

La distribuzione delle lunghezze e' **liscia**, senza il picco isolato che
segnala un taglio a monte (39 car. → 41 etichette, 40 → 41, 41 → 31, 42 → 42).
Le due soglie segnalate dallo strumento sono state **aperte e lette una per una**:
tutte e 41 le etichette da 40 caratteri e tutte e 8 quelle da 58 sono **frasi
complete**. Zero etichette terminano con puntini di sospensione. La piu' lunga e'
di 110 caratteri e arriva in fondo.

La prova diretta e' il caso che era stato pagato: `GSE126517` compare ora come
**`T47D breast cancer cells treated with R5020 for 6 hours and IFN-alpha for 18
hours`** — il pezzo che nel 2026 era stato tagliato (`and IFN-alpha for 18
hours`) c'e'.

---

## 3. Come sono stati dati i verdetti

Per blocchi di 13 gruppi: un **lettore**, **due critici simmetrici** (uno
sostiene che ha accusato troppo, l'altro troppo poco — stessa struttura di
prompt, stessa istruzione a non gonfiare), un **arbitro** che decide
sull'etichetta e non sull'autorevolezza. 15 blocchi, 60 agenti, zero errori.

**Che i critici servano, si vede dai numeri: l'arbitro ha accolto 87 rilievi e ne
ha respinti 167.** Due terzi delle contestazioni non hanno retto alla lettura
dell'etichetta.

### La simmetria era nel disegno, non nel risultato — e va detto

| | rilievi prodotti | direzione proposta |
|---|---:|---|
| critico A (*ha accusato troppo*) | 69 | 37 assoluzioni, 17 condanne, 15 incerte |
| critico B (*ha accusato troppo poco*) | 183 | 1 assoluzione, 94 condanne, 88 incerte |

Il rapporto e' **0,38**: il critico severo ha trovato 2,7 volte piu' cose da dire
di quello indulgente. E' meglio del 2026-08-05, dove il critico unico produsse
**24 verdetti cambiati tutti verso il peggio e zero assoluzioni** (qui le
assoluzioni proposte sono 37, e alcune sono state accolte). Ma **non e'
simmetria**: chi legge questi verdetti deve sapere che la pressione sul materiale
e' stata piu' forte in direzione della condanna.

### Le citazioni sono state verificate contro il materiale

Regola: un difetto vale solo se e' leggibile nell'etichetta citata. Le
**272 citazioni** degli arbitri sono state ricercate nel testo dei blocchi:
**268 ritrovate (98,5%)**. I quattro mancanti sono stati aperti uno per uno e
**nessuno e' un'etichetta inventata**:

- `GSE97744` — l'etichetta vera e' `Circulating macrophage + IFN-γ and LPS` con
  la lettera greca; l'arbitro l'ha traslitterata in `IFN-gamma`. Il difetto (due
  agenti nel solo braccio trattato) e' reale. *E' il mio strumento che vedeva
  meno del dato, non l'arbitro.*
- `GSE154311`, `GSE205668` — differenze tipografiche (freccia ASCII contro
  freccia tipografica, frammento di prosa fra apici). Le etichette ci sono.
- `GSE255958` — l'arbitro cita un gruppo (`grp_PC9_Osimertinib`) che **non e' nel
  materiale** perche' scartato prima del pooling. **Verificato contro il registro
  degli scarti di produzione: esiste, ed e' caduto per `n_min` con un solo
  campione trattato.** Il ragionamento era esatto.

---

## 4. La tassonomia dei difetti — la parte che serve al metodo

97 segnalazioni, su **85 studi distinti**, in 66 gruppi. Contate **per studio**,
non per destinazione (uno studio che compare in trenta gruppi vale uno).

| difetto | studi | quota |
|---|---:|---:|
| **secondo agente presente solo nel braccio trattato** | 28 | **32,9%** |
| **materiale / tipo cellulare diverso fra i bracci** | 19 | **22,4%** |
| tempo non appaiato | 10 | 11,8% |
| donatore / soggetto / sesso / etnia diversi | 6 | 7,1% |
| sede anatomica diversa | 4 | 4,7% |
| passaggio di coltura non appaiato | 2 | 2,4% |
| entita' del gruppo non isolata dal confronto | 2 | 2,4% |
| genotipo su un braccio solo · controllo non valido · dose | 3 | 3,5% |
| altro (13 categorie, tutte elencate in `tassonomia.csv`) | 11 | 12,9% |

**Piu' della meta' dei difetti (55,3%) sono due cose sole**, ed entrambe sono
correggibili a monte con una regola, non con una lista:

1. **Il secondo agente nel solo trattato.** Esempio dal gruppo TGF-β1:
   `Hypoxia + TGF-β1` contro `PBS (Vehicle Control)`, mentre **lo stesso studio**
   ha il confronto pulito `TGF-β1` contro lo stesso controllo. Il confronto
   misura ipossia e TGF-β1 insieme, e il pooling lo attribuisce al TGF-β1. La
   regola esiste gia' in forma parziale (`.rp_row_defect`); qui si vede quanto
   pesa non averla piena.
2. **Il materiale diverso fra i bracci.** Esempio: `MSC iPSC-derived TGF-β 21
   days` contro `MSC Primary Culture Vehicle Only`, quando lo stesso studio ha la
   coppia primaria-contro-primaria.

**Concentrazione.** 43 delle 62 difettose hanno **un solo studio accusato**; la
mediana degli studi accusati e' il **20%** del gruppo. Il difetto e' quasi sempre
localizzato: non e' un gruppo sbagliato, e' un membro sbagliato in un gruppo
altrimenti buono.

---

## 5. Il giudizio comparativo: quale delle due esecuzioni ha ragione

1.034 giudizi, su **859 studi** che divergono fra le due esecuzioni. Contati per
studio:

| | studi | quota |
|---|---:|---:|
| **A** — il run NUOVO sbaglia dove il vecchio azzeccava | 228 | **26,5%** |
| **B** — il run NUOVO azzecca dove il vecchio sbagliava | 188 | **21,9%** |
| **C** — entrambe difendibili, l'etichetta sorgente e' ambigua | 443 | **51,6%** |

Tre letture, tutte necessarie:

- **In meta' dei casi l'etichetta sorgente non decide.** Non e' un difetto della
  pipeline: e' che il metadato GEO non dice abbastanza. Il metodo deve
  **dichiararlo**, non scegliere in silenzio.
- **Fra i casi in cui l'etichetta decide, il nuovo run sbaglia leggermente piu'
  spesso di quanto azzecchi** (228 contro 188). La differenza c'e' ma e' piccola:
  nessuna delle due esecuzioni domina l'altra.
- **Il deliverable corrente conteneva errori che nessuno aveva visto**: 188 studi
  stavano in un posto sbagliato e ora stanno in uno giusto.

### Quanto e' davvero cambiato, misurato sui campioni e non sul testo

Il conteggio grezzo delle divergenze non informa, perche' mette insieme cose
diverse. Confrontando gli **insiemi di campioni** dei bracci (se i campioni sono
identici, il dato poolato e' identico, qualunque cosa dica l'etichetta):

| | studi | quota |
|---|---:|---:|
| identici nei due run | 233 | 18,4% |
| solo l'etichetta riscritta, **stessi campioni** (cosmetico) | 95 | 7,5% |
| cambiano i campioni poolati | 500 | 39,6% |
| cambiano gruppo | 436 | 34,5% |

**192 dei 194 gruppi hanno almeno una divergenza vera.** Solo 233 studi su 1.264
(18,4%) escono identici. Nessun artefatto: **tutti** e 1.264 gli studi in gioco
appartengono al sottoinsieme rigenerato da A3, quindi il confronto e' pulito.

---

## 6. Dov'e' la leva, misurata sui dati

«Lo studio entra o esce dal pooling» e' il meccanismo dominante nei giudizi
comparativi (71% dei casi A, 69% dei B), ma descrive l'effetto, non la causa. La
causa si legge sulla **chiave di contrasto** (`entita || verso || tipo di
controllo`). Presi i **271 studi che escono dal deliverable** e guardati nello
Stadio 3, dove ci sono tutti i cluster e non solo quelli poolabili:

| dove finiscono | studi | quota |
|---|---:|---:|
| **stessa identica chiave: escono per il GATE (k≥3 o `n_min`)** | **169** | **62,4%** |
| spariscono dai cluster del contrasto | 48 | 17,7% |
| stessa entita', **cambia il tipo di controllo** | 37 | 13,7% |
| cambia l'entita' | 17 | 6,3% |

> **L'aspettativa del handout era che la leva fosse la normalizzazione del tipo
> di controllo** (`vehicle_untreated` → `unknown`, `ctrl`, `nt`, `nc`,
> `sicontrol`, `undiff`, `pre treatment`). **Il meccanismo esiste — e i cambi
> osservati sono esattamente quelli previsti** (`vehicle_untreated → ctrl / ut /
> nt / nc / undiff`, piu' `atopic`, `non sarcopenic`, `non stimulated`) — **ma
> vale il 13,7%, non la maggioranza.**

**La leva vera e' il gate.** Quasi due terzi degli studi che escono avevano la
chiave *identica*: sono usciti perche' il loro gruppo non ha raggiunto k=3, o
perche' un braccio e' sceso sotto `n_min`. La variabilita' degli stadi LLM non
sposta gli studi da un contrasto all'altro: li fa oscillare **intorno a una
soglia**, e la soglia amplifica un rumore piccolo in un'uscita netta. Chi vuole
un deliverable stabile deve intervenire li', non sulla normalizzazione delle
etichette.

---

## 7. Quello che l'etichetta non ha chiuso, dichiarato

**32 verdetti su 194 (16,5%) non sono decisi dall'etichetta** e restano una
scelta dichiarata: 16 «incerta», 13 «difettosa», 3 «corretta». Su questi si e'
applicata la regola gia' fissata — nel dubbio si sceglie la lettura che **non
sovrastima** la qualita' del dato — e la regola e' stata applicata **in entrambi
i versi**: dove l'etichetta decide che il confronto e' pulito, il gruppo resta
corretto.

I casi tipici sono etichette che non dicono cosa distingue i due bracci (sigle
mute, identificatori di braccio incommensurabili) e controlli che non dichiarano
il tempo mentre il trattato lo dichiara: li' **non si puo' sapere** se il
disallineamento c'e'.

---

## 8. Il verdetto contro quello che il deliverable dichiarava

| dichiarato dal deliverable | letta corretta | letta difettosa | letta incerta |
|---|---:|---:|---:|
| `coherent` (190) | 116 | 58 | 16 |
| `incoherent` (4) | 0 | 4 | 0 |

I quattro gia' dichiarati incoerenti sono confermati. Ma **74 gruppi dichiarati
`coherent` non lo sono**: `coherent` nel deliverable e' l'assenza di un verdetto,
non un verdetto — e questa e' la prima volta che tutti e 194 vengono letti.

---

## 9. Limiti, dichiarati

1. **I critici non sono stati simmetrici nell'esito** (69 contro 183 rilievi,
   §3). Il disegno lo era; la pressione sul materiale no.
2. **Il giudizio e' sulle etichette, non sui dati grezzi.** Un difetto invisibile
   all'etichetta (per esempio due bracci che differiscono per qualcosa che il
   sottomittente non ha scritto) non e' rilevabile con questo metodo, e il 16,5%
   di verdetti non chiusi e' un limite inferiore di quel buco.
3. **I giudizi vengono da un modello**, con verifica meccanica delle citazioni
   (98,5%) ma senza una lettura umana indipendente dei 194. Le tre lezioni
   precedenti dicono che la lettura umana cambia dei verdetti.
4. **«Corretta» non vuol dire «forte».** Il verdetto e' sull'appaiamento, non
   sulla potenza: un gruppo puo' essere corretto e valere meno di due studi
   efficaci. I due assi (correttezza e dominanza) restano indipendenti e vanno
   riportati insieme.
5. Il caso C (51,6%) e' una **misura dell'ambiguita' della sorgente**, non una
   assoluzione: dice che l'etichetta non basta, non che i due pooling siano
   equivalenti.

---

## 10. Che cosa si corregge a monte, in ordine di resa

1. **Il gate** (62,4% delle uscite). Un k=3 rigido trasforma un rumore LLM
   piccolo in un'uscita netta dal deliverable. Va deciso se dichiarare i gruppi a
   k=2, o se stabilizzare l'appartenenza prima della soglia.
2. **Il secondo agente nel solo trattato** (32,9% dei difetti). Regola generale,
   gia' esistente in forma parziale.
3. **Il materiale diverso fra i bracci** (22,4%). Stessa forma: quando lo stesso
   studio offre la coppia appaiata, va preferita.
4. **La normalizzazione del tipo di controllo** (13,7% delle uscite). Reale, ma
   vale meno di quanto ci si aspettasse.

---

## 11. File

| file | contenuto |
|---|---|
| `verdetti-194.csv` | **un verdetto per ciascuna delle 194**, col motivo e l'etichetta |
| `quadro-194.csv` | i verdetti incrociati con k, Kish, dominanza, I² |
| `difetti.csv` | 97 segnalazioni con studio, categoria, etichetta citata |
| `tassonomia.csv` | le famiglie di difetto, contate per studio |
| `comparativo.csv` | 1.034 giudizi A/B/C con il motivo |
| `meccanismi-divergenza.csv` | i meccanismi della divergenza, per studio |
| `leva-chiave-contrasto.csv` · `usciti-dove-finiscono.csv` · `usciti-controllo.csv` | dove va ogni studio che si muove |
| `divergenze-per-studio.csv` | divergenze vere contro cosmetiche, sui campioni |
| `blocco-01..15.txt` | il materiale letto, con le etichette intere |
| `00-materiale.R` … `80-usciti.R` | gli script, in ordine |
