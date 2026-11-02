# S3 — Il metro concorda con se stesso? Il test-retest della rilettura delle 194

**Data:** 2026-08-21/22 · **Sessione:** S3 dell'handout
`docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md` · **Evidenza:**
`analysis/audit/2026-08-21-S3-test-retest/` · **Deliverable:** A3 v16, 194
meta-analisi (`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`).

## 0. La domanda, e la risposta in una riga

Tutti i numeri dell'handout — 116/62/16, i 66 gruppi, i 97 difetti, i 128, i
173, i 37 — vengono da **una sola lettura** delle 194, fatta da un modello
(lettore + due critici + arbitro, `C1-workflow-rilettura.js`, 2026-08-19). La
domanda di S3: **rifacendola, esce la stessa cosa?**

> **Sì, entro un margine misurato.** Rifatta in ambiente congelato con lo stesso
> materiale, lo stesso modello e gli stessi prompt, la lettura concorda con se
> stessa sull'**88,1%** delle 194 [IC95 83,5; 92,8], **kappa 0,78** [0,70; 0,86];
> sul binario *difettosa / non* **93,3%**, kappa 0,84. Solo **5 gruppi su 194**
> passano da *corretta* a *difettosa* o viceversa; i 18 altri disaccordi hanno
> «incerta» da un lato. I tre casi di coda (`IL22`, `obese`, `sals`) sono
> confermati con lo stesso studio accusato. Secondo la soglia fissata prima del
> run, l'accordo è **alto**: i numeri dell'handout acquistano una barra d'errore
> (corrette 116→113, difettose 62→55, incerte 16→26; gruppi con ≥1 difetto
> 66→55, 52 comuni) e non vanno rifatti. Ma il primo retest, fatto senza
> congelare l'ambiente, era **contaminato** (§2): la lezione vale quanto il numero.
>
> **Aggiornamento 2026-11-02.** La lettura umana è fatta (§5): accordo col run
> originale **18/19** (94,7%, IC95 esatto 74,0–99,9). Ma la parte 2 delle schede
> mostra ciò che il metro non può vedere: in `Carcinoma, Hepatocellular` lo studio
> più pesante, `GSE144269`, ha i **bracci invertiti**, confermato sui dati.

## 1. Che cosa è stato verificato PRIMA di lanciare

Le quattro cose che l'handout chiedeva di risolvere, e come:

1. **I prompt sono verbatim.** `C1-workflow-rilettura.js` (recuperato il 21/08)
   ha SHA-256 **identico** allo script persistito del run originale
   `wf_40052108-a99` (`~/.claude/projects/…/ce316c82…/workflows/wf_40052108-a99.json`,
   campo `script`). Il retest misura l'originale, non una ricostruzione. Il
   risultato grezzo di quel run, che non era nel repo, è ora salvato:
   `2026-08-20-rilettura-194/risultato-workflow-wf_40052108-a99.json`.
2. **Il modello è lo stesso.** Il run originale girava con `claude-opus-5`
   (campo `defaultModel` e `"model"` in ogni transcript di agente); il retest lo
   fissa esplicitamente (`model: 'opus'`), verificato sui transcript dei nuovi
   agenti: `claude-opus-5`.
3. **Blocchi interi, non venti gruppi estratti.** Comporre un blocco nuovo
   cambia il metodo (i critici vedono i verdetti del lettore su tutto il blocco,
   l'arbitro rilegge il blocco intero). Si rifanno i blocchi già letti — e si
   rifanno **tutti e 15** (194 gruppi, ~40 minuti di macchina), il che toglie
   anche la scelta di *quale* blocco. `10-blocchi.R` non è stato toccato: i
   `blocco-XX.txt` sono quelli del 19/08 (`SHA256-blocchi-letti.txt`).
4. **Le previsioni sono scritte prima** (`00-previsioni.md`, 23:10; lancio 23:12):
   P1 accordo a tre classi 78–90% e kappa 0,55–0,80; P2 binario ≥ 85%; P3 meno
   di metà delle incerte resta incerta; P4 totali entro ±12; P5 coppie accusate
   ritrovate ≥ 60%; P6 più cambi verso il peggio che verso il meglio. Soglia di
   decisione fissata allora: **alto** = kappa ≥ 0,60 e binario ≥ 85%; **basso** =
   kappa < 0,40 o binario < 75%; in mezzo zona grigia.

Diff fra C1 e il workflow del retest (`C3`): il nome, i blocchi da `args`, il
modello esplicito, due righe di `log`. Prompt e schemi JSON byte-identici.

## 2. Il retest 1 era contaminato — e si è visto solo misurando

Il primo retest (`wf_62d20ef5-167`, 60 agenti, 0 errori, 43 min, 6,2 M token)
ha dato **accordo 80,4%, kappa 0,64 [0,54; 0,73], binario 88,1%** — tutte e sei
le previsioni vere, «accordo alto» secondo la soglia.

Ma leggendo i motivi degli arbitri: *«sono andato a vedere i nove campioni»*,
*«ho letto i 40 campioni di GSE217421»*, *«i titoli dei campioni sono …»*. Il
materiale del run originale erano le **etichette** dei blocchi; le stringhe
grezze per campione (`schede/`, `campioni-per-meta-analisi.csv`) sono state
scritte il **20/08 alle 11:36**, dodici ore *dopo* il run originale, nella
stessa cartella. Gli agenti hanno strumenti, e li hanno usati.

`25-cosa-hanno-letto.py` conta, per ruolo e per run, le fonti toccate oltre il
blocco assegnato:

| run | lettori | critici A | critici B | arbitri | **fonti contaminanti** |
|---|---|---|---|---|---|
| originale (19/08) | 0/15 | 4/15 (solo `tutte-le-etichette`, `dispatch-*.rds`) | 4/15 | 3/15 | **0/60** |
| retest 1 (21/08) | 0/15 | 8/15 | 5/15 | 10/15 | **11/60** |

«Contaminanti» = le stringhe grezze per campione (8 arbitri, 6 critici), **i
verdetti originali stessi** (`verdetti-194.csv`, `difetti.csv`, `INDICE-194.csv`:
5 arbitri, 1 critico), il finding del 20/08, e lookup esterni (ChEBI, ChEMBL
`compounds.tsv.gz`). Due conseguenze: il retest 1 **non è indipendente**
dall'originale, e ha letto **più informazione** (quella che la regola 2 del
prompt — «un difetto si dichiara solo se è leggibile nell'etichetta che citi» —
gli vietava di usare, e che ha usato lo stesso: `calcium atom` passa a difettosa
«con tutti e tre gli studi, leggibili nei metadati dei campioni»).

Quindi il retest 1 misura **un metodo diverso** (etichette + stringhe grezze +
verdetti precedenti), e il suo 80,4% non è il numero cercato. Si conserva con
il suffisso `-retest1-contaminato` e si riporta in §4 per quello che è.

**La lezione, che vale più del numero:** un test-retest di agenti con strumenti
richiede lo **stesso materiale raggiungibile**, non solo lo stesso prompt; e lo
si verifica *dopo*, sui transcript, non lo si assume. Il retest 2 gira in una
cartella **fuori dal repo** con solo i file che esistevano il 19/08 alle 23:32
(`C4-workflow-retest-congelato.js`, unica differenza da C3: il percorso).

## 3. Il retest 2, ambiente congelato: il test-retest vero

**Run** `wf_a0a37108-046` (`C4-workflow-retest-congelato.js`), 2026-08-21
23:52 → 00:25: 60 agenti, 0 errori, 33 min, 5,3 M token, 336 tool call
(originale 314, retest 1 511). **Fonti contaminanti: 0/60** (`25-out-tutti.txt`).
Oltre il blocco, gli agenti hanno letto solo ciò che stava nella cartella
congelata (`tutte-le-etichette.txt`, `00-materiale.R`, `10-blocchi.R`) e — cosa
che l'originale non faceva — lookup ontologici in cache (`chebi-lookup.rds`,
ChEMBL `compounds.tsv.gz` / `names.tsv.gz`: 4 arbitri, 3 critici). È informazione
sull'identità della molecola, non sui campioni: lo dichiaro, non lo conto come
contaminazione.

### I numeri (`30-out-retest2.txt`)

| | originale (19/08) | retest 2 (21/08) |
|---|---:|---:|
| corrette / difettose / incerte | 116 / 62 / 16 | **113 / 55 / 26** |
| gruppi con ≥1 difetto | 66 | **55** (52 comuni) |
| coppie gruppo-studio accusate | 94 | **80** (72 comuni, 76,6% ritrovate, Jaccard 0,71) |
| verdetti che l'etichetta non chiude | 32 | **40** (25 comuni) |

| misura | valore | IC95 (bootstrap, 2.000) |
|---|---:|---|
| accordo grezzo a tre classi | **88,1%** | 83,5 – 92,8 |
| kappa di Cohen a tre classi | **0,78** | 0,70 – 0,86 |
| accordo binario *difettosa / non* | **93,3%** | kappa 0,84 [0,75; 0,92] |
| accordo binario *corretta / non* | 92,3% | kappa 0,84 |

Matrice (righe originale, colonne retest 2):

| | corretta | difettosa | incerta |
|---|---:|---:|---:|
| **corretta** (116) | 107 | 2 | 7 |
| **difettosa** (62) | 3 | 52 | 7 |
| **incerta** (16) | 3 | 1 | 12 |

### Che cosa sono i 23 disaccordi

- **18 su 23 hanno «incerta» da un lato**: 10 fra *corretta* e *incerta*, 8 fra
  *difettosa* e *incerta*. È la classe che assorbe il rumore del metodo.
- **5 su 194 (2,6%) saltano fra *corretta* e *difettosa***: due verso il peggio
  (`cabozantinib`, `Carcinoma, Renal Cell`, entrambi k=3), tre verso il meglio
  (`nilotinib`, `Pre-Eclampsia`, `Carcinoma, Hepatocellular`). Sono i soli casi in
  cui le due letture si contraddicono sul fatto, non sul grado di certezza.
- Il verso non è quello previsto (P6): **13 verso il meglio, 10 verso il peggio**;
  il movimento più frequente è *difettosa → incerta* (7). La pressione verso la
  condanna misurata nel run originale (183 rilievi del critico «troppo poco»
  contro 69) non si traduce in una deriva sistematica fra i due run.
- **Per blocco**: cinque blocchi a 13/13, il peggiore è il 09 (8/13). Nel retest 1
  contaminato i peggiori erano il 03 (6/13) e il 10 (7/13): nel retest 2 stanno a
  12/13 e 13/13. L'instabilità di quei due blocchi era l'informazione in più,
  non il rumore del modello.
- **Per fascia di k**: accordo 85–90% in tutte (k=3 88,9%, kappa 0,76; k>10 85,0%,
  kappa 0,73). Il retest 1 mostrava fragilità a k=3 (kappa 0,49): sparita.
- I tre casi di coda: `IL22` (GSE149262), `obese` (GSE205668), `sals` (GSE138691)
  — **stesso verdetto, stesso studio accusato** nei due run.

### Le previsioni, valutate

| | esito |
|---|---|
| P1 accordo 78–90%, kappa 0,55–0,80 | **vera** (88,1%, 0,78) |
| P2 binario ≥ 85% | **vera** (93,3%) |
| P3 meno di metà delle incerte resta incerta | **falsa**: 12/16 restano incerte — la classe è più stabile del previsto |
| P4 totali entro ±12 | **vera** (−3, −7, +10) |
| P5 coppie accusate ritrovate ≥ 60% | **vera** (76,6%) |
| P6 più cambi verso il peggio | **falsa** (10 contro 13) |

**Decisione secondo la soglia fissata prima del run: accordo ALTO** (kappa
0,78 ≥ 0,60 con tutto l'intervallo sopra; binario 93,3% ≥ 85%).

### Che cosa ne segue per l'handout

- I numeri **non vanno rifatti**; vanno **scritti con la barra**: 116 corrette
  (113 al retest), 62 difettose (55), 16 incerte (26); 66 gruppi con difetto (55);
  94 coppie accusate (80). Dove un numero a valle dipende dal confine
  *difettosa/incerta* o *corretta/incerta* — il setaccio di S5, il denominatore
  di S10 — la sensibilità è dell'ordine di **±10 gruppi**, e va dichiarata lì.
- Dove dipende dal confine *corretta/difettosa* — i 173 «che restano togliendo i
  difetti», i 37 del nocciolo — la sensibilità è di **5 gruppi su 194**.
- **S5 e S10 possono procedere** sul metro esistente. Resta aperto il punto 2
  (l'umano, §5), che è l'unico a poter dire se il metro è *giusto* oltre che
  ripetibile.

## 4. Il retest 1 accanto, per confronto

| | retest 1 (contaminato) | retest 2 (congelato) |
|---|---|---|
| accordo a tre classi | 80,4% [74,7; 85,6] | **88,1% [83,5; 92,8]** |
| kappa | 0,64 [0,54; 0,73] | **0,78 [0,70; 0,86]** |
| binario (difettosa / non) | 88,1%, kappa 0,73 | **93,3%, kappa 0,84** |
| totali corrette / difettose / incerte | 110 / 65 / 19 | **113 / 55 / 26** |
| coppie accusate ritrovate | 75,5% (71/94), Jaccard 0,53 | **76,6% (72/94), Jaccard 0,71** |
| etichetta non chiude | 48 (orig 32) | **40 (orig 32)** |
| fonti contaminanti | 11/60 agenti | **0/60** |

Il retest contaminato concorda **meno** con l'originale (kappa 0,64 contro 0,78):
l'informazione in più ha spostato 38 verdetti invece di 23, ha raddoppiato le
coppie accusate (111 contro 94) e ha portato a 48 i verdetti «non chiusi». Nel
retest 1 i due blocchi peggiori erano il 03 (6/13) e il 10 (7/13); i disaccordi
con «incerta» da un lato erano 23 su 38; `obese` — uno dei tre casi
in cui il difetto sposta il risultato — passava a *corretta* perché l'arbitro
ha letto nelle stringhe grezze che le età in etichetta erano quelle del primo
campione del braccio. È un'informazione vera, ed è esattamente ciò che il metodo
originale non poteva vedere.

## 5. La lettura umana: 19 schede su 20

Modulo `umano/RISPOSTE.csv`, ricevuto il 2026-11-02; conteggio `40-out.txt`.
**`08-sals` è vuota di proposito**: il riepilogo del 22/08, l'handout e §0 di questo
finding dicono che è difettosa e quale studio è accusato, quindi non era più cieca.

### I numeri, su 19 gruppi

| confronto | tre classi | IC95 esatto | kappa | binario *difettosa / non* |
|---|---:|---|---:|---:|
| **umano, parte 1, contro originale** (primario) | **18/19 = 94,7%** | 74,0 – 99,9 | 0,91 | 18/19 |
| umano, parte 1, contro retest 2 | 15/19 = 78,9% | 54,4 – 93,9 | 0,63 | 17/19 |
| *paragone:* originale contro retest 2, stesse righe | 16/19 = 84,2% | 60,4 – 96,6 | 0,71 | 18/19 |
| umano, dopo parte 2, contro originale | 16/19 = 84,2% | 60,4 – 96,6 | 0,70 | 16/19 |

Il limite inferiore 74% esclude il precedente del progetto (36,2%), ma quello era
un altro esperimento: un altro metodo, sui 213 gruppi. **Per questo braccio nessuna
soglia era stata depositata**: quelle di `00-previsioni.md` riguardano il retest. L'unico
disaccordo col run originale sulla parte 1 è `16-tamoxifen` (umano *incerta*,
originale *difettosa*). Studi accusati sulla parte 1: 14 coppie gruppo-studio per
parte, 11 comuni.

### Che cosa aggiunge la parte 2: l'etichetta non è il dato

Con le stringhe grezze, che il modello non aveva, cambiano **4 verdetti su 19**:
`04-asthmatic` difettosa → corretta, `05-IL2` corretta → difettosa, `16-tamoxifen` e
`19-doxorubicin` incerta → difettosa. Otto delle affermazioni del modulo sono state
controllate sulle schede, e **reggono tutte**:

| studio | etichetta dello Stadio 2 | che cosa dicono i metadati |
|---|---|---|
| `GSE144269` (HCC) | *HCC patients* contro *Normal liver tissue* | **invertiti**: i 56 «trattati» sono tutti `non-tumor`, i 61 «controlli» tutti `tumor` |
| `GSE256235` (HCC) | *Hepatocellular carcinoma* | 4 dei 10 «trattati» sono `background liver` |
| `GSE138698` (IL2) | *no treatment* | il «controllo» è `H9T 24h`: un'altra forma ingegnerizzata di IL-2 (agonista parziale secondo la letteratura, non superagonista come nella nota: da confermare sulla fonte) |
| `GSE221563` (IL2) | *IL2* contro *Untreated* | giorno 13 contro giorno 0 |
| `GSE221804` (IFNA1) | *Wild-type, IFN alpha* | a 0 h e 72 h sono doppi KO IRF9/IRF1, come uno dei due bracci a 2 h e un campione su tre a 8 h; il «Wild-type» di controllo mescola WT, IRF1 KO, IRF9 KO e STAT2 KO |
| `GSE93153` (HBV) | *HBV D10 Donor2* | i 2 campioni sono `Mock`, giorno 8: niente HBV |
| `GSE152004` (asma) | *Asthmatic small molecule* | 8 asmatici con metadati uguali agli altri: la molecola non esiste nel metadato |
| `GSE226115` (doxorubicina) | *doxorubicin (total RNA)* | knockdown di STING + DOX contro siRNA di controllo + salina |

Le altre affermazioni del modulo (`GSE164359`, `GSE210765`, `GSE178374`, `GSE157104`,
`GSE141806`, `GSE123285`, `GSE144378`, `GSE152360`, `GSE196724`, `GSE202859`,
`GSE217421`, `GSE252576`) **non sono state controllate**.

### `GSE144269`: l'inversione si vede nei dati (`50-out.txt`)

Marcatori fissati dalla letteratura nello script prima di aprire il risultato (up nel
HCC: GPC3, AFP, MKI67, TOP2A, CDC20, CCNB1; down: CYP2E1, CYP3A4, ALB, APOA1, CRP, SAA1):

| studio | segno concorde coi marcatori | Spearman con `GSE144269`, tutti i geni |
|---|---:|---:|
| `GSE144269` | **0/12** | — |
| `GSE77509` | 12/12 | **−0,82** |
| `GSE159220` | 12/12 | **−0,68** |
| `GSE164359` | 11/12 | **−0,76** |
| `GSE256235` | 11/12 | −0,13 |
| `GSE120663` (PBMC) | 6/7 | +0,05 |

È anche lo studio **più pesante**, di poco: quota mediana di peso REM **22,6%**, contro
22,2% di `GSE77509` (`30-pesi-rem.R` della sessione `2026-11-02-inversioni-194`). Un
primo calcolo con 1/SE² senza tau² dava 34,8%: era sbagliato, ed è la stessa
approssimazione che il progetto aveva già ritirato il 2026-08-10. La meta-analisi ha 105
geni significativi. **Nessuna delle due letture del modello l'ha
visto**, né poteva: sull'etichetta il confronto è impeccabile (originale *difettosa*
per `GSE120663`, retest 2 *corretta*). **Da qui non discende una stima di quante
inversioni ci siano**: è un caso su 19 gruppi letti.

### Che cosa ne segue

Il metro è ripetibile e, sulle etichette, concorda con la lettura umana. Ma misura le
etichette: i suoi «corretta» non garantiscono i bracci. **Nessun verdetto è stato
cambiato e nessuna correzione è stata fatta.** Il controllo delle inversioni su tutte le
194 è stato fatto dopo: `docs/findings/2026-11-02-inversioni-bracci-194.md`.

## 6. Limiti

1. Il test-retest misura la **varianza di campionamento del modello** a
   temperatura non controllabile, sullo stesso materiale: non dice nulla sulla
   correttezza dei verdetti (quello è il punto 2).
2. Anche nel retest 2 gli agenti hanno strumenti: la cartella congelata riduce
   le fonti raggiungibili, non le azzera. Il conteggio di `25-cosa-hanno-letto.py`
   sul retest 2 è in §3 ed è parte del risultato.
3. I critici restano asimmetrici nell'esito (handout, finding del 20/08 §3):
   anche il retest misura un metodo la cui pressione è verso la condanna.
4. Nessun verdetto delle 194 è stato cambiato: i retest sono insiemi di
   verdetti *accanto*, non al posto.
5. Il confronto con l'umano è su **19 gruppi**, con intervallo largo (§5).

## 7. File

Vedi `analysis/audit/2026-08-21-S3-test-retest/README.md`.
