# HANDOUT — Dalla riproducibilità alla CORRETTEZZA, una variabile alla volta

**Scritto:** 2026-08-09 a fine sessione · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessun push · nessun re-cluster e nessun re-pool eseguiti**

> **Questo file è autosufficiente.** Non serve leggere la conversazione precedente.
> Va letto **per intero** prima di toccare qualsiasi cosa.

---

## 0. Il mandato di questa sessione, in tre righe

Sappiamo **come rendere la pipeline riproducibile**. Non sappiamo se sia **corretta**.
Sono due cose diverse: un errore ripetibile resta un errore, e adesso lo sarà in
modo perfettamente riproducibile.

**Il compito è stabilire la correttezza, un pezzo alla volta, cambiando UNA
SINGOLA VARIABILE per volta e misurando che cosa succede.**

Non c'è un deliverable da consegnare. Non c'è una scadenza. Se un passo richiede
un giorno, richiede un giorno. **La lentezza qui è un requisito, non un costo.**

---

## 1. ⚠️ L'UNICA COSA ACQUISITA — e nient'altro

**`VLLM_BATCH_INVARIANT=1` rende la generazione riproducibile al 100%.**

Questo è l'unico risultato che la prossima sessione può dare per acquisito senza
rimisurarlo. Ecco la prova, perché anche un fatto acquisito va accompagnato dal
suo numero:

| | senza flag | con flag |
|---|---:|---:|
| **Stadio 1**, record completo identico su 5 giri | 40,4% (403/998) | **100,0%** (998/998) |
| Stadio 1, `perturbations[].agent_normalized.id` | 86,0% (858/998) | **100,0%** |
| Stadio 1, `perturbations[].duration.is_zero_timepoint` | 95,2% (950/998) | **100,0%** |
| Stadio 1, `cell_context` | 89,4% (892/998) | **100,0%** |
| **Stadio 2**, record completo identico su 5 giri | 62,0% (124/200) | **100,0%** (200/200) |
| Stadio 2, insieme dei confronti — **per identità dei campioni** | 92,0% (184/200) | **100,0%** |
| Stadio 2, insieme dei confronti — per etichetta `grp_000N` | 90,5% (181/200) | **100,0%** |
| Stadio 2, **`primary_role`** per gruppo | 93,0% (186/200) | **100,0%** |

⚠️ **Tre correzioni rispetto alla prima stesura, tutte trovate da revisori
ostili e verificate:**

1. **Il campo dei ruoli si chiama `primary_role`, non `design_role`** (schema
   `stage2.v2`; `design_role` è del vecchio `stage2.v1` e ha **zero occorrenze**
   nell'output). La prima stesura leggeva `design_role`, otteneva `NULL` ovunque,
   e misurava di fatto la stabilità dei soli `group_id` — che dà 95,0%. Il numero
   vero è **93,0%**. È la trappola n.5 di questo stesso handout, commessa da chi
   l'ha scritta.
2. **L'«insieme dei confronti» al 90,5% confrontava le etichette** `grp_000N`, non
   i confronti. Risolvendo i `group_id` negli insiemi di campioni: **92,0%**. Tre
   studi risultavano instabili solo perché il modello aveva rinumerato i gruppi
   producendo gli stessi identici confronti.
3. **I denominatori delle due colonne non coincidevano**: 998 record con 5 giri
   validi senza flag, **999** con flag. La tabella qui sopra è ricalcolata sulla
   base comune di 998.

Condizioni del test: stessi bundle di produzione, stessi record, stessi 5 giri,
**unica differenza una riga** nello script slurm (`--env "VLLM_BATCH_INVARIANT=1"`),
verificata con `filecmp` su input, prompt, schema e `generation.json`.

⚠️ **LIMITE PESANTE DEL TEST, da conoscere prima di citarlo:** in tutti i run,
**i cinque giri di ogni record sono stati serviti dallo stesso worker**
(verificato: worker distinti per record = 1, su 1000/1000 e 200/200). Il test
quindi **non ha mai variato la composizione del batch fra i giri** — che è
esattamente ciò che la batch-invarianza serve a garantire. Quello che è provato è:
*a parità di worker, di run e di composizione del batch, la flag elimina la
variazione residua*. **Non** è provato che la flag renda identici due run con
numero di record, microbatch o nodo diversi. Chi volesse quella garanzia deve
misurarla, e non l'ha fatto nessuno.

Costo misurato: Stadio 1 **+44%** (6m55s → 9m58s su 5.000 record), Stadio 2
**+153%** (32m → 1h21m su 1.000 record).

Container: `simulomicsr-vllm-v0.20.2.sif`, che espone già `VLLM_BATCH_INVARIANT`
e contiene il modulo `vllm.model_executor.layers.batch_invariant` (verificato).

### ⚠️ Tre avvertenze sulla flag, che NON vanno dimenticate

1. **La flag cambia i risultati.** Fra gli 89 record su cui la produzione era già
   stabile su 5 giri, **4 (4,5%) danno un risultato diverso con la flag**. Non è
   un interruttore che congela il comportamento attuale: produce una
   classificazione **diversa**, corretta e riproducibile, ma altra.
2. **Gli artefatti esistenti restano non riproducibili.** I **508.037** record
   dello Stadio 1 (`p4-fase-f2-stage1-master-predictions-rescued.jsonl`) e i
   **24.394** dello Stadio 2 (`p4-fase-f4-stage2-master-v3.jsonl`) sono stati
   prodotti senza la flag. Nessuna configurazione futura li rende riproducibili:
   solo rifarli.
   ⚠️ La prima stesura scriveva «879.000 e 24.972»: il primo è il master **β
   superato** (`p4-beta-…`, 879.167 righe) che non alimenta il deliverable v15,
   il secondo è il numero delle righe di **input**, non dell'artefatto. Conteggi
   verificati con `wc -l`.
3. **La flag non corregge niente.** Rende l'errore ripetibile. Vedi §3.

### Che cosa NON è acquisito (elenco esplicito)

- che le classificazioni siano **corrette**;
- che il verdetto di coerenza sia stabile (**non lo è**: vedi §3.4);
- che il deliverable v15 sia difendibile;
- qualunque numero della sessione del 2026-08-08 non ricontrollato in §3;
- **qualunque cosa scritta in questo handout che non abbia un numero accanto.**

---

## 2. IL METODO — non negoziabile

### 2.1 Una variabile alla volta

Questa regola nasce da un errore commesso il 2026-08-09: il primo test della
flag cambiava **tre** cose insieme (la flag, il campione da 1000 a 200 record, i
giri da 5 a 3) ed è stato presentato come confronto. Non lo era.

**Prima di ogni esperimento, scrivere:**
1. qual è la variabile che cambia — **una**;
2. che cosa resta identico, e **come lo si è verificato** (`filecmp`, `sha256`,
   `diff` dello script), non «l'ho copiato»;
3. la previsione numerica, **depositata su file prima di guardare l'esito**;
4. che cosa falsificherebbe l'ipotesi.

Il punto 3 non è formalità. Il 2026-08-09 sei previsioni erano state depositate
(`scratchpad/previsione-replica.md`) e l'esito è questo — elencato, perché un
conteggio senza l'elenco non è verificabile:

| previsione | attesa | misurata | |
|---|---|---|---|
| accordo a 3 livelli fra due esecuzioni | 60–78% | 79,3% | **falsificata** |
| accordo binario | 75–88% | 87,4% | centrata |
| «dubbio» stabile sotto il 60% | <60% | 63,9% | **falsificata** |
| totali stabili entro il 15% | <15% | 2–7% | centrata |
| copertura 214/214 | sì | 198/214 | **non decidibile**: il run è morto per limite di spesa, non per la previsione |
| rilevatore deterministico: 9 cluster | 9 | 9 | centrata |

Due falsificate, tre centrate, una non decidibile. ⚠️ Un revisore ostile ha
contato **tre** falsificate includendo la quinta: la differenza sta nel se un
fallimento d'infrastruttura falsifichi una previsione. Qui si è scelto di no, e
lo si dichiara — ma è una scelta, non un dato.

### 2.2 Lo strumento va validato prima del dato

**Ogni strumento di misura nuovo deve avere casi di accettazione, positivi E
negativi, verificati prima di usarlo.**

Il 2026-08-09 sono stati costruiti quattro rilevatori di repliche tecniche prima
di averne uno che funzionasse:

- **v1** cieco sul caso noto: in R `\b` non riconosce il confine su `_`
  (trappola già pagata due volte dal progetto), e in più 229 falsi positivi;
- **v2** passava i test ma trattava `_R1`/`_R2` come *read* Illumina, mentre in
  GEO sono repliche **biologiche**: segnalava `DU145_R1/R2/R3` a torto;
- **v3** contava le **occorrenze** dei campioni invece dei campioni **distinti**:
  un controllo riusato da due confronti sembrava una replica tecnica;
- **v4** passa 13 casi di accettazione (2 positivi, 11 negativi costruiti sui
  falsi allarmi delle versioni precedenti) e dà **9 cluster su 214**.

⚠️ **Precisazione onesta:** i numeri della v1 (229 bracci segnalati, 120 cluster
su 214) sono stati *mostrati* all'utente prima di essere smentiti — accompagnati
dalla riserva che andavano verificati, ma mostrati. Nessuno di essi è entrato in
una decisione, e questo è il solo motivo per cui il danno è stato nullo. **La
regola giusta non è "dichiarare la riserva": è non mostrare un numero prima che
lo strumento abbia superato i suoi casi di accettazione.**

⚠️ **E il controllo del caso noto NON basta, contro quanto affermava la prima
stesura.** Ha smascherato **una versione su tre**: la v1, che il caso noto non lo
trovava. La v2 e la v3 lo trovavano — e restavano rotte. A smascherare quelle è
stato il controllo **opposto**: guardare i FALSI ALLARMI (`DU145_R1/R2/R3` per la
v2, il conteggio occorrenze-contro-distinti per la v3).

**Servono entrambi i controlli, e quello che pesa di più è il negativo.** La v4 ha
2 casi positivi e **11 negativi**, e non è un caso: i falsi positivi sono la
direzione in cui uno strumento sbaglia senza dare segno.

### 2.3 Un numero estremo è un sospetto sullo strumento

Il 2026-08-09 un confronto dava **98,7% di ID sbagliati**. Il confronto *aveva*
un difetto reale: il modello emette formati misti (`HGNC:18412`, ma anche
`NOTCH1` e `CHEMBL1200786`) e la v1 li trattava come stringhe, quindi un simbolo
giusto risultava diverso dal numero giusto.

**Regola: quando un numero contraddice di ordini di grandezza una misura
precedente del progetto, il primo sospettato è lo strumento nuovo.** Va cercato
un **controllo negativo** (nel caso sopra: «esistono casi di accordo?» — sì, 17,
e questo ha provato che il confronto non era rotto).

⚠️ **Ma il seguito della storia conta quanto la regola.** Corretto il difetto, il
numero è passato da 98,7% a **96,8%**: 1,9 punti. Lo strumento era imperfetto e
il risultato reggeva lo stesso. **Sospettare lo strumento è obbligatorio;
aspettarsi che il sospetto assolva il dato non lo è.** Qui il dato è sopravvissuto
alla correzione, e questo lo rende più forte, non più debole.

### 2.4 Verificare se un difetto è già noto PRIMA di chiamarlo nuovo

Il 2026-08-08 e il 2026-08-09 sono stati riferiti come «difetti nuovi» cinque
casi, di cui **almeno due erano già documentati** e uno era già stato **esaminato
e assolto** il 5 agosto. Il controllo costava due minuti:

```bash
grep -n "GSExxxxx" analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv
```

**Prima di dire «nuovo», cercarlo negli audit esistenti.**

### 2.5 Le altre regole, brevi

- **Nessun numero prodotto da un agente entra in una decisione senza essere
  rimisurato in modo indipendente.**
- **Verifica sull'artefatto, non sul sorgente.** Le figure si aprono e si guardano.
- **Prima di giudicare, verifica che lo strumento veda il dato per intero**
  (contare quante stringhe toccano il limite di lunghezza).
- **Mai la parola «validato» senza la misura accanto.**
- **Nessun taglio silenzioso**: ogni omissione dichiarata.
- **Se un numero non torna: fermarsi e dirlo.** Non aggiustare.
- **Niente liste scritte a mano come meccanismo.**

---

## 3. LO STATO DEI FATTI — che cosa è misurato, e con quale forza

Ogni riga porta la sua provenienza. Dove manca, il fatto **non è misurato**.

### 3.1 Il funnel del deliverable — SOLIDO

11.536 cluster `cgroup` → 355 alla porta → **351 candidati** → **214 poolate +
137 scartate**, zero orfani. Riprodotto due volte in modo indipendente partendo
dai dati veri con `.identify_layer_a_clusters()`, non dai CSV di agenti.

I 137 scartati sono corroborati **dall'esterno**: i 13 con k=0 non hanno alcuna
riga in `per_study_de.parquet`, gli altri 124 ne hanno esattamente quante ne
dichiarano.

### 3.2 La calibrazione del k — ✅ REGGE (e una mia ritrattazione, ritrattata)

**Lo strumento `k_eff` è calibrato, e la sua calibrazione NON è tautologica.**

Verificato aprendo il file: `analysis/audit/2026-08-08-deframmentazione/00-funnel-e-calibrazione.R`
definisce lo scarto come `cmp$scarto <- cmp$k_eff_mio - cmp$k_effective` — cioè
contro **`k_effective`**, la colonna che nasce dal pooling — e il CSV risultante
(`02-calibrazione-214.csv`) ha **scarto 0 su tutte e 214 le righe**.

Lo strumento (`10-strumento-keff.R`) parte dai soli cluster dello Stadio 3:
costruisce `assignments` sintetici e chiama il dispatch **di produzione**
`.build_group_rem_dispatch_from_stage3()`. Non legge il pooling. E riproduce
`k_effective` esattamente, più i 137 scartati al k dichiarato nel loro motivo.

⚠️⚠️ **RITRATTAZIONE DI UNA RITRATTAZIONE.** Una versione precedente di questo
handout affermava che quel confronto fosse «tautologico, fatto contro la colonna
`k`», e che «partendo dallo Stadio 3 il k_effective non è calcolabile». **Erano
entrambe false.** Venivano da un agente che non le aveva verificate, e chi
scriveva l'handout non ha aperto né il file né il CSV — che stanno nella stessa
cartella e dicono il contrario. L'intestazione stessa dello strumento dichiara la
calibrazione riga per riga: **non era stata letta.**

È lo stesso errore che questo documento denuncia ovunque (fidarsi di un agente),
commesso nella direzione opposta: invece di gonfiare un risultato, ne ha demolito
uno corretto. **Distruggere una prova valida è un errore quanto costruirne una
falsa.**

**Limite vero dello strumento, dichiarato dallo strumento stesso:** non applica il
pre-filtro H5 del re-pool (campioni assenti dall'H5, `lib_size` sotto soglia),
quindi il `k_eff` è un **limite superiore**. Su v15 quel limite è stretto — scarto
zero su tutti e 214 — ma resta un limite superiore per costruzione, e su un corpus
diverso potrebbe non esserlo.

**Conseguenza per la prossima sessione:** il guadagno di una fusione si può
misurare in cinque secondi senza re-pool. Non serve un run da 31 ore per sapere
una cosa che è già calibrata 351 volte su 351.

### 3.3 La de-frammentazione — MISURATA, NON DECISA

Con entrambe le mappe accese (misura fatta col codice di produzione sui dati veri):

- **9 righe delle 214 sono toccate**: 8 cambiano `k` e 1 sparisce (il TNF
  `CHEMBL:CHEMBL265582`, assorbito). ⚠️ La prima stesura diceva «13 righe del
  deliverable, non 7»: il 13 vive sui **354 candidati**, non sulle 214 righe, ed
  era quindi confrontato con un numero di un'altra base — la trappola n.11 di
  questo stesso handout;
- **4 meta-analisi nuove nascono a k=3 esatti**: KSHV, epatite C, Zika ceppo
  MR766, infigratinib;
- guadagno sul `k` dello Stadio 3: **+35 studi** (NON confrontabile col «+21» in
  `k_eff` della sessione precedente: sono grandezze diverse).

Giudizi di contrasto. ⚠️ **Il numero di lettori NON e' uniforme**: 5 giudici
ciechi piu' 8 critici, ma i due critici simmetrici (accusa **e** difesa) hanno
coperto solo 3 blocchi su 5 — ipossia, le quattro nuove a k=3, e i virus. I
blocchi «obesi e resto» (dove sta `STR:symptomatic`) ed «entita-proteine» hanno
avuto **un solo critico, con lente di accusa e senza difesa**. Dove sotto si
legge «3 lettori su 3», vale solo per i tre blocchi con la coppia completa:

- **ipossia/normossia: stesso contrasto.** ⚠️ Ma **l'argomento riferito era
  falso**: fra i confronti CONTRIBUENTI, il gruppo vincente ha **36 controlli su
  37** che nominano la normossia nell'etichetta (**37/37** se si guarda i
  `factor_levels`), l'assorbito **1 su 10** — l'esatto contrario di quanto
  affermato. Definizione usata, perche' il numero sia rifacibile: l'etichetta di
  controllo contiene `normox` **oppure** `nrx` (l'abbreviazione standard di
  normoxia). Contando solo `normox` sono 35/37. La conclusione
  regge per un motivo diverso e verificato: **GSE120886 è un solo studio, un solo
  esperimento, due linee cellulari** — una col controllo scritto «normoxia»
  (finita nel vincente), l'altra «untreated» (finita nell'assorbito). Il confine
  è lessicale, non biologico. Prova indipendente: **GSE151610** ha un controllo
  che si chiama letteralmente «Vector Control + Normoxia» e sta nel gruppo
  «non-trattato», perché il campo strutturato dice `treatment=vector control`.
- **HSV-1: il caso che da solo dimostra la tesi.** Il gruppo «assorbito» non è
  uno studio nuovo: è lo **stesso GSE201012, con lo stesso braccio trattato**,
  spaccato in due gruppi solo perché i suoi due controlli si chiamano «Mock
  infected» e «Uninfected».
- **RSV (`NCBITaxon:12814`): contrasti diversi, 3 lettori su 3.** Polmone
  autoptico FFPE di bambini deceduti contro controlli di un'altra coorte.
- **`STR:symptomatic`: contrasti diversi.** Mette insieme SARS-CoV-2 e **malaria**.
- **Zika MR766: zero confronti contribuenti su cinque.** Il gruppo arriverebbe a
  k=3 senza produrre alcun dato. E MR766 è un **ceppo**, non una specie: identità
  di livello sbagliato.
- **Epatite C:** l'unico studio che la fusione aggiunge **non contribuisce**.
- **Un disaccordo aperto:** rinovirus — giudice e accusa dicono «incerto», la
  difesa «stesso contrasto». **Non risolto.**

### 3.4 Il gate di coerenza NON è riproducibile — e dipende dal giudice

Questo è il risultato più grande della sessione, e cambia il peso di un numero
che sta nei Results.

| chi giudica | base | coerenti | dubbi | **incoerenti** |
|---|---:|---:|---:|---:|
| lettura del 5 agosto | 214 | 101 | 16 | **97** |
| Claude, 2026-08-09 (prima esecuzione) | 214 | 92 | 64 | **58** |
| Mistral, maggioranza di 5 giri | 213 | 109 | 79 | **25** |

**Il numero di meta-analisi «non difendibili» va da 25 a 97 sulle stesse identiche
schede.** Quasi un fattore quattro, cambiando solo il lettore.

⚠️ **Le basi non sono identiche** (214, 214, 213: Mistral ha una meta-analisi in
meno per 5 fallimenti di schema su 1.070 richieste) e **i tre giudizi non sono
alla pari**: la lettura del 5 agosto vedeva solo le etichette dei gruppi, quelle
del 9 agosto anche i campioni e tre assi invece di uno. La differenza fra 97 e 58
contiene quindi sia rumore sia un cambio di metodo. Quella fra 58 e 25 no: stesso
materiale, stessi assi, solo un altro modello.

E la variabilità fra esecuzioni **dello stesso lettore**:

| | accordo fra esecuzioni |
|---|---|
| Claude, 2 esecuzioni, 3 livelli | 79,3% |
| Claude, binario coerente/non | 87,4% |
| Mistral, media su 10 coppie, 3 livelli | 92,2% |
| Mistral, verdetto identico su tutti e 5 i giri | 84,5% |

⚠️ **Quei numeri di Mistral sono SENZA la flag. Il run CON la flag è stato
eseguito** (job 34883, `20260809T050000Z-BI-coerenza-5x`, 12m53s, stesse 213
meta-analisi, unica riga di differenza) **ed è al 100% su tutto**:

| campo | senza flag | con flag |
|---|---:|---:|
| `verdetto_contrasto` | 84,5% | **100,0%** |
| `difetti_repliche` | 97,7% | **100,0%** |
| `difetti_indipendenza` | 96,2% | **100,0%** |
| testo dell'analisi | 52,6% | **100,0%** |
| risposta completa | 38,5% | **100,0%** |
| accordo medio a coppie | 92,2% | **100,0%** |

**La variabilità di Mistral era dunque tutta numerica**, non di giudizio.

⚠️⚠️ **MA IL VERDETTO CAMBIA IN 33 CASI SU 213 (15,5%), E 18 DI QUESTI ERANO
PERFETTAMENTE STABILI PRIMA.** Questo è il fatto più importante del paragrafo, e
la prima stesura di questo handout lo minimizzava.

Scomposizione dei 33:

| | quanti | su | |
|---|---:|---:|---|
| erano **instabili** senza flag (il modello oscillava) | 15 | 33 instabili | 45% |
| erano **stabili** senza flag (5 voti identici su 5) | **18** | 180 stabili | **10%** |

Esempi, tutti con 5 voti identici prima e 5 voti identici dopo:

```
cgroup_L5_10344dfd :  5/5 "coerente"    →  con flag  5/5 "dubbio"
cgroup_L5_479c6221 :  5/5 "dubbio"      →  con flag  5/5 "coerente"
cgroup_L5_523e64b9 :  5/5 "incoerente"  →  con flag  5/5 "dubbio"
```

**Tre conseguenze, in ordine di gravità:**

1. **La stabilità su N giri NON è un indicatore di affidabilità.** Il 10% delle
   risposte che sembravano solidissime cambia se si cambia il modo di sommare i
   numeri. La ripetibilità misura quanto un calcolo è rumoroso, non quanto una
   risposta è fondata. **Non usare «5/5 identici» come prova che un giudizio
   regga.**
2. Per quelle 33 meta-analisi esistono **due risposte diverse, entrambe
   perfettamente riproducibili**, e nel dato non c'è nulla che dica quale sia
   giusta. La differenza sta nell'ordine delle somme in virgola mobile, non nella
   biologia. **Per quel 15,5% il verdetto non è una proprietà del dato ma del
   calcolo.**
3. **Prendere la maggioranza di 5 giri senza flag non equivale a un giro con la
   flag.** I giudizi prodotti prima del 2026-08-09 non sono riutilizzabili come se
   fossero gli stessi.

⚠️ **Non è stato misurato PERCHÉ proprio quei 33**: servirebbero i logit, che
l'output non conserva. Non inventare una spiegazione.

Il numero di «incoerenti» resta comunque ~24 contro i 58 di Claude e i 97 del
5 agosto: **la dipendenza dal giudice non è toccata dalla flag**, ed è il PASSO 4.

Confronto fra giudici: **Mistral e Claude concordano sul 44,1%** delle 213
meta-analisi. Mistral è sistematicamente più indulgente (77 casi contro 42).

⚠️ **Limite dichiarato dell'impianto:** il contestatore è spinto alla severità dal
prompt. I disaccordi vanno **25 verso il peggio e 3 verso il meglio**. È lo stesso
difetto già documentato il 5 agosto e **non è stato corretto**: un impianto
migliore avrebbe due critici simmetrici anche lì.

### 3.5 La CORRETTEZZA degli ID — il problema più grave, e il meno esplorato

**Su 524 perturbazioni dove i dizionari sanno risolvere il testo, l'ID che il
modello assegna coincide con quello del dizionario 17 volte: 3,2%.**

Controllo negativo superato: esistono accordi veri (`ethanol` → CHEBI:16236,
`pparg` → HGNC:9236, `HuR` → HGNC:3312), quindi il confronto non è rotto.

**La stabilità non salva:** dei 41 testi per cui il modello dà **sempre lo stesso
ID**, **39 danno sempre lo stesso ID sbagliato**.

```
Alpelisib          → CHEBI:123456   (⚠️ NON inventato: e' un accession REALE,
                                    un'ammide furanica senza rapporto con
                                    l'alpelisib. E' proprio per questo che passa)
Adriamycin         → CHEB:27974     (prefisso malformato)
1-Bromopropane     → 75-26-3        (un numero CAS al posto di ChEBI)
alcohol            → CHEBI:17790    (metanolo, non etanolo)
Reserpine          → CHEBI:6846 / 6840 / 6830   (metsuximide, metossamina, inesistente)
```

**E il resolver non se ne accorge.** `resolve_agent_canonical()`
(`R/anchors.R:373`, ramo CHEBI) prende l'ID del modello come **primo** tentativo
e lo accetta se **esiste** in ChEBI — non se è **giusto**. `CHEBI:17790` esiste (è il
metanolo), quindi «alcohol» diventa metanolo senza che nessuna guardia protesti.
I fallback (nome preferito, alias) scattano solo quando l'ID non esiste.

Questo spiega un dato che il progetto aveva misurato nel maggio 2026 e mai
spiegato: l'accordo fra il `kind` dichiarato e i ruoli ChEBI era **0,7% per le
citochine e 2,4% per i patogeni**. Se l'identità di partenza è un ID esistente ma
sbagliato, tutto ciò che ne deriva è coerentemente sbagliato.

⚠️ **Limiti di questa misura, dichiarati:** il risolutore di confronto interroga i
dizionari in un ordine fisso (ChEBI → HGNC → MeSH → ChEMBL); su testi ambigui
come «alcohol» può sbagliare anche lui. Campione: 998 campioni di un blocco di
8.012, sul corpus di **508.037** dello Stadio 1 (non 888.000: quello e' il bacino
β superato), sistematico e non probabilistico. **Non è stato misurato
quanti di questi ID sbagliati arrivino fino al deliverable.**

### 3.6 Difetti nel deliverable ATTUALE — misurati, non corretti

- **9 meta-analisi su 214 contengono repliche da corsia di sequenziamento**
  contate come repliche biologiche. La peggiore è **GSE173902**, che tocca **sei**
  meta-analisi (IFNG k=20, IL13 k=12, IL4 k=10, IL22 k=6, *S. aureus* k=4,
  *S. epidermidis* k=3): in tutti e 12 i bracci **i 2 campioni sono un solo
  campione biologico su due corsie**. Quei confronti sono **1 contro 1** e hanno
  superato il filtro `n_min = 2`, che esiste per garantire le repliche. Il filtro
  conta i campioni, non i campioni *biologici*.
  Due delle nove sono a **k=3**, il minimo: se il confronto cade, escono dal
  deliverable.
- **1 confronto su 2.152 ha lo stesso campione in entrambi i bracci**: GSE158765
  nell'acido acetilsalicilico (k_effective 3, marcata **coerente**) — 94 trattati,
  61 controlli, **59 dei controlli sono anche trattati**. È uno studio
  longitudinale entro soggetto. Attenuante misurata: quel gruppo è dominato al
  91% da un altro studio (k_kish 1,19), quindi il peso è al più il 9%.
- **Il dedup SAMN NON serve** a questo ramo: stesso BioSample in due studi diversi
  dentro la stessa meta-analisi = **0 su 214**; stesso GSM in due GSE = **0**.
  Applicarlo sarebbe **dannoso**: GSE98984 ha quattro campioni distinti (2
  trattati, 2 controlli) con **un solo BioSample** per errore di deposito in GEO,
  e la regola «tieni la libreria più grande» ne cancellerebbe tre su quattro.
  **Va documentato come scelta consapevole, non corretto.**

### 3.7 Codice scritto e non committato

- `R/stage4-role-conflict.R` — guardia sui conflitti di ruolo. Il campione
  ambiguo esce da **entrambi** i bracci; se un braccio scende sotto `n_min` il
  confronto non entra; ogni scarto è registrato in un attributo.
- `tests/testthat/test-stage4-role-conflict.R` (37 asserzioni) e
  `-integration.R` (15): queste ultime verificano che la guardia sia **davvero
  chiamata**, perché il progetto ha tre casi documentati di codice scritto,
  testato e mai invocato.
- Modificati: `R/stage4-orchestrator.R` (la guardia sta nel punto attraversato
  dai tre rami **per-studio** — `rem`, `mega_aug`, `rem_group` — selezionati dal
  filtro a riga 39) e `R/stage4-build.R` (soglia dalla config).
  ⚠️ «Tre rami vivi» era scorretto: il **deliverable e' un ramo solo**
  (`deliverable_methods = "rem_group"`, `R/stage4-config.R:87`); gli altri due
  sono calcolati ma fuori dal deliverable per decisione utente. La guardia li
  copre comunque, ed e' un bene, ma non sono «vivi» nel senso del deliverable.
- **Suite `stage4`: 0 FAIL, 0 ERROR.**
- ⚠️ **Il ramo `mega` è morto e non va usato come modello** (indicazione
  dell'utente, 2026-08-09): la guardia gemella esiste lì, ma non è stata copiata.

---

## 4. IL PROGRAMMA — passo passo, in quest'ordine

Ogni passo: **una variabile, una previsione depositata prima, una misura, una
conclusione scritta.** Nessun passo comincia prima che il precedente sia chiuso.

### PASSO 0 — ✅ FATTO il 2026-08-09

Il run di coerenza con `VLLM_BATCH_INVARIANT=1` sulle 213 × 5 giri è stato
eseguito e misurato: **100% su ogni campo** (vedi la tabella in §3.4). La
variabilità di Mistral era tutta numerica.

Restano però due cose da tenere presenti, ed è il motivo per cui il passo è
documentato invece che cancellato:

1. il verdetto di maggioranza **cambia nel 15,5% dei casi** rispetto a prima
   della flag: i giudizi vecchi non sono riutilizzabili come se fossero gli stessi;
2. la **dipendenza dal giudice resta intatta** (24 incoerenti secondo Mistral, 58
   secondo Claude, 97 secondo la lettura del 5 agosto). È il PASSO 4.

### PASSO 1 — La correttezza degli ID, su scala (mezza giornata)

**Variabile:** nessuna. È una misura, non un esperimento.

Estendere la misura di §3.5 dal campione a un insieme grande, e soprattutto
rispondere alle due domande che mancano:

1. **Quanti degli ID sbagliati arrivano nel deliverable?** Serve tracciare
   `agent_normalized.id` → anchor → cluster → le 214. Non è stato fatto.
2. **Il resolver corregge o propaga?** `resolve_agent_canonical()` ha rami
   diversi (`CHEBI_DIRECT`, `CHEBI_FIELDSWAP`, `WRONG_DB_to_HGNC`…): misurare
   quanti record passano per ciascuno e quanti finiscono col codice sbagliato.
   La colonna `resolution_source` esiste già nell'output: **usarla**.

**Previsione da depositare prima:** quale percentuale delle 214 ha un'entità
sbagliata alla radice.

### PASSO 2 — La correzione minima al resolver (un giorno)

**Variabile:** una sola — far verificare al resolver la **coerenza** dell'ID col
testo, non solo la sua esistenza.

Oggi: `hit <- .try_chebi_int(id_clean); if (!is.null(hit)) return(...)`.
Domani: accettare l'ID **solo se** risolve alla stessa entità a cui risolve il
testo (`agent_raw`); altrimenti preferire il testo.

TDD, coi casi noti come test di accettazione: `alcohol` deve dare CHEBI:16236 e
non 17790; `Alpelisib` non deve dare CHEBI:123456.

**Misura:** quante entità cambiano su tutto il corpus, e in che direzione.
**Non materializzare**: misurare a freddo sull'output esistente.

**⚠️ Attenzione:** questo cambia l'identità di partenza, quindi le chiavi di
clustering, quindi la composizione dei gruppi. **È il cambiamento più invasivo
del programma.** Va misurato prima di essere deciso, e la decisione è dell'utente.

### PASSO 3 — Il filtro delle repliche biologiche (mezza giornata)

**Variabile:** una — `n_min` conta i campioni **biologici** invece dei campioni.

Il rilevatore v4 esiste ed è validato (13 casi di accettazione). Portarlo in
codice di pacchetto con TDD, agganciarlo dove si costruisce il dispatch, e
misurare quante delle 214 cambiano e quante escono.

**Previsione, corretta dopo essere stata falsificata dallo strumento stesso:**
solo i confronti di **GSE173902** cadono (2 campioni → 1 biologico, sotto
`n_min`), quindi **le sei meta-analisi che lo contengono perdono uno studio** e
*S. epidermidis* (k=3) esce. **La digossina NON esce**: il suo studio flaggato
(GSE115542) ha 12 campioni → **3** biologici per braccio, e 3 ≥ 2. Stessa cosa
per GSE178340 (12→3) e GSE116899 (10→5, 3→2): sopravvivono.
⚠️ La prima stesura prevedeva l'uscita della digossina. Era falsa, ed è stata
smentita con i dati che c'erano già.

### PASSO 4 — Che cosa cambia davvero il verdetto (un giorno)

**Variabile:** il giudice.

Il gate di coerenza dà 25, 58 o 97 incoerenti a seconda di chi legge (§3.4).
Prima di decidere quale numero mettere nell'articolo, capire **su che cosa** i
giudici divergono:

- i casi su cui **tutti e tre** concordano sono il nucleo solido: quanti sono?
- i casi su cui divergono hanno una **caratteristica comune misurabile** (k basso?
  dominanza alta? materiale misto?)
- esiste un **segnale deterministico** che predice il consenso? Se sì, il gate può
  diventare codice.

**Questa è la domanda scientifica più importante del programma.**

### PASSO 5 — Solo qui, e solo se i primi quattro sono chiusi

Le decisioni rimaste in sospeso dal 2026-08-08, che **non vanno riaperte prima**:
de-frammentazione sì/no, dove (Stadio 3 o 4), ampiezza del re-pool, KSHV a k=3.
Sono documentate in `docs/superpowers/specs/2026-08-09-deframmentazione-RICONTROLLO-HANDOUT.md`
e i loro numeri sono in §3.3 di questo file.

---

## 5. LE TRAPPOLE — tutte già pagate, tutte con la loro cicatrice

1. **`\b` in R non vede il confine su `_`.** Pagata tre volte: `calcium_low`,
   il rilevatore v1, e prima ancora nelle regole di riga del 2026-07-26.
2. **`_R1`/`_R2`/`_rep1` in GEO sono repliche BIOLOGICHE**, non read Illumina.
   Solo `_L001..L008` sono corsie.
3. **Contare le occorrenze invece delle entità distinte.** Un controllo riusato
   da due confronti non è un campione duplicato.
4. **Confrontare stringhe invece di identità.** `HGNC:18412`, `NOTCH1` e
   `CHEMBL1200786` sono formati diversi della stessa cosa: canonicalizzare prima.
5. **Un percorso di campo inesistente dà «0% varia», che sembra un risultato.**
   `duration` non è di primo livello: sta dentro `perturbations[]`. Verificare
   sempre che il campo esista prima di misurarne la stabilità.
6. **Un numero estremo è un sospetto sullo strumento** (§2.3).
7. **Un difetto «nuovo» va cercato negli audit prima di chiamarlo tale** (§2.4).
8. **Cambiare più di una variabile e chiamarlo confronto** (§2.1).
9. **Uno strumento che vede meno del dato.** Prima di giudicare, contare quante
   stringhe toccano il limite di lunghezza: se molte e diverse è troncamento.
10. **Una regola misurata su pochi casi non si applica a centinaia** senza
    rimisurare l'ampiezza.
11. **`k` dello Stadio 3 e `k_effective` del deliverable sono grandezze DIVERSE.**
    Il progetto le ha già confuse una volta («TGF-β1 ha 145 confronti, non 59»).
12. **Se tocchi il recupero-nome, bumpa `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`**,
    o il re-cluster riusa la cache e produce un output identico. Già costato 8 ore.
13. **Mai `head` in pipe su una suite di test**: chiude la pipe e la tronca.
14. **Un verdetto di coerenza orfano ferma l'annotazione a fine run.**
15. **Il ramo `mega` è morto**: non usarlo come modello per codice nuovo.
16. **`setsid` per i run lunghi**, mai in background del tool. E verificare che il
    poller legga davvero il dato: il 2026-08-09 un loop è uscito su una caduta di
    ssh scambiandola per «finito», e un altro espandeva la tilde in locale
    leggendo un percorso inesistente sul DGX e stampando 0.

---

## 6. IL MATERIALE

**Dati.** Stadio 3 v15: `analysis/p4-output/20260803T164558Z-stage3-v15-7f986159/`
(`clusters.rds` 322.415 cluster, `assignments.parquet`).
Deliverable v15:
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/`
(`deliverable-annotato.rds` 214 righe, `non_processable.rds` 137,
`per_study_de.parquet`, `cluster_pooled.parquet`).
Stadio 2: `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl` (24.394 studi).
Verdetti del 5 agosto: `analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv`.

**Run DGX del 2026-08-09** (in `~/simulomicsr-dgx/runs/`):

| run | che cos'è |
|---|---|
| `20260809T000000Z-coerenza5x-m5x001` | coerenza, 214×5, **senza** flag |
| `20260809T010000Z-repro-stage1-r5x001` | Stadio 1, 1000×5, **senza** flag |
| `20260809T010000Z-repro-stage2-r5x002` | Stadio 2, 200×5, **senza** flag |
| `20260809T020000Z-det-stage1-d3x001` | tentativo di determinismo a mano — **fallito**, 30× più lento |
| `20260809T040000Z-BI-stage1-5x` | Stadio 1, **con** flag → 100% |
| `20260809T040000Z-BI-stage2-5x` | Stadio 2, **con** flag → 100% |
| `20260809T050000Z-BI-coerenza-5x` | coerenza, **con** flag — **job 34883, da leggere** |

**Scratchpad della sessione** (non nel repo, copiare ciò che serve):
`/tmp/claude-1000/-home-user-simulomicsr/632a8932-.../scratchpad/`
— `dossier/` (campioni delle 214 fino al singolo GSM, segnali v4),
`blocchi/` (20 blocchi di materiale), `mistral/` (tutte le predizioni),
`rilevatore-v4.R` (il rilevatore validato), `previsione-replica.md`.

**Codice.** `R/anchors.R:373` (`resolve_agent_canonical`, ramo CHEBI: il punto
del PASSO 2), `R/stage4-qc.R` (fusione + gate),
`R/stage4-orchestrator.R:39` (il filtro che seleziona i tre rami vivi) e
`:57-72` (la guardia nuova, nel punto che tutti e tre attraversano),
`R/stage4-role-conflict.R` (la guardia),
`R/stage3-coherence.R` (`.normalize_control_type`, il vocabolario dei controlli),
`R/stage3-defrag-alias.R` (la regola generale e la storia dei suoi difetti).

---

## 7. VINCOLI OPERATIVI

- Branch `review-scientific-consistency-2026-06-10`. **master invariato, il push
  lo fa l'utente.**
- `Rscript` **senza** `--vanilla`. Reinstallare il pacchetto prima di ogni render
  Quarto.
- **Nessun re-cluster e nessun re-pool senza decisione esplicita dell'utente.**
- Run lunghi con `setsid` (verificare SID == PID), **mai** in background del tool.
- Durante un run multi-ora: **aggiornamento ogni ora**, fatto più stima del residuo.
- **DGX**: `ssh u0044@logindgx.hpc.ict.unipd.it`. `sinfo` che dice `idle` **non
  basta**: verificare il mount reale con un `srun` breve prima di sottomettere.
- **Attenzione al budget**: il 2026-08-09 il limite di spesa mensile è stato
  raggiunto a metà di un workflow, e 14 agenti su 38 sono falliti. I run su DGX
  costano zero; gli agenti no. **Preferire il calcolo self-hosted dove possibile.**

---

## 8. LA COSA DA NON DIMENTICARE

Questa sessione ha stabilito **come** rendere riproducibile la pipeline. Non ha
stabilito che sia corretta — e ha trovato indizi seri che in almeno un punto non
lo sia (§3.5: il 96,8% degli ID assegnati non corrisponde a quello che i
dizionari danno per lo stesso testo).

Rendere riproducibile un errore lo rende più facile da studiare, non meno grave.

**Il compito non è arrivare a un deliverable. È sapere che cosa è vero.**
