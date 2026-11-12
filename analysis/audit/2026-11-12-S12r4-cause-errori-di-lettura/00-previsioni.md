# S12r4 — cancelli, previsioni e regola di diagnosi

Depositato il 2026-11-12, **prima di ogni corsa di S12r4**, e committato da solo. Dopo le corse non cambia.
Le differenze fra le due forme dell'uscita, le varianti e i limiti stanno in `01-carta.md`. Finora sono state lette
solo le uscite congelate di S12r2 (`analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl`) e di S12r3
(`analysis/p4-output/S12r3-lettore-v2/M-corsa1.jsonl`), sui 47 studi di sviluppo.

**Unità:** lo studio. **Ricampionamento:** per studio, appaiato fra forma e base, B = 2.000, seme 20261112 (la data
della sessione), intervallo al 95% dai percentili. **Basi:** `B0` (prima corsa) per le forme del lato B, `A0` (la
corsa di S12r4) per le forme del lato A. **Misura principale:** riferimento a 95 confronti; la misura su 97 si
riporta accanto.

## 1. Cancelli (se uno fallisce, la sessione non vale)

1. **La condizione di partenza si riproduce.** La prima corsa di `B0` è identica al carattere alle uscite congelate
   di S12r3 in 47 studi su 47. Quindi ridà 45 chiusi su 47, 36 gruppi identici su 47, 68 confronti su 95 e le 13
   unità di lettura del modello. La seconda corsa di `B0` è identica alla prima. Le due corse della forma finale
   sono identiche fra loro.
2. **Lo strumento ridà i numeri congelati** (prima delle corse, sulle uscite congelate: `11-out.txt`): con `A0` i
   numeri di S12r2 (34 chiusi, 31 identici, 50/95, 50/97), con `B0` quelli di S12r3 (45, 36, 68/95), le 40 unità di
   disaccordo e, fra quelle, le 13 di lettura nei 4 studi (7, 1, 2, 3).
3. **Controllo positivo.** I predicati vedono i 4 errori di lettura nella condizione di partenza (`GSE57945`,
   `GSE60340`, `GSE49155`, `GSE46665`), sulle uscite congelate e sulla corsa nuova di `B0`. Il conto dei soggetti
   costanti nei gruppi vede `source_name_ch1` in `GSE50760` e `GSE71595`.
4. **Copertura.** Ogni corsa copre 47 studi di sviluppo su 47 e nessuno degli 82 studi di giudizio.
5. **Ambiente.** Ogni job gira su `poddgx02`; `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` sono lette dal file
   dell'ambiente del container (solo quelle due righe); modello, revisione, `temperature` 0, `repetition_penalty`
   1,1, `max_model_len` 65536, `max_tokens` 24576 sono quelli di `01-carta.md` §1; prompt e schema nel bundle sono
   quelli generati dal codice committato; il lavoratore usa lo schema del record in 47 record su 47.

## 2. Previsioni

L'origine del margine è scritta per ogni previsione: (S) soglia del progetto, (M) variabilità misurata,
(G) giudizio motivato dell'agente. **Le previsioni 4-9 sono giudizi: non c'è una misura precedente.**

| n. | quantità | atteso | intervallo di rilevanza | origine | se cade fuori |
|---|---|---|---|---|---|
| 1 | `A0` identica al carattere a `M-corsa1.jsonl` di S12r2 | 47/47 | 47 | M: due corse identiche al carattere 47/47 in S12r2 e in S12r3 | il canale dello schema (bundle o record) o l'ambiente è una differenza in più; si riporta, e la base del lato A resta la corsa nuova |
| 2 | `RC3`: blocco `factors` dell'uscita identico a quello di `B0` | 47/47 | 47 | G: `01-carta.md` §5 | lo schema di un blocco agisce anche sui blocchi scritti prima: l'argomento dell'ordine non vale, e una differenza di schema non si lega al campo che cambia |
| 3 | il ponte: `A0A2A3A4R` identica al carattere a `RA1PP5C` | 47/47 | 47 | G: stesso prompt byte per byte, stesso vincolo | descrizioni, titolo o `$id` dello schema non sono inerti: l'elenco delle differenze non è completo |
| 4 | studi con la tabella dei fattori (firma) diversa dalla base sotto un placebo, per ognuno dei 4 placebo | 5/47 | da 0 a 12 | G | oltre 12 (un quarto degli studi): un cambio di parole senza senso sposta le letture quanto un cambio vero; la prova «un cambio per volta» localizza poco, e si dice al PI |
| 5 | i 4 errori di lettura sotto i due placebo di `B0` (8 stati) | 8 presenti | da 7 a 8 | G | un errore che un placebo toglie è instabile: esito «non deciso», e conta come lettura instabile del modello |
| 6 | `GSE46665` (sigle dei pazienti come malattie): esito della regola | «del modello» | — | M: presente con tutte e due le forme (`11-out.txt`) | se un cambio lo toglie e il cambio opposto lo rimette, l'errore è della forma |
| 7 | `GSE60340` e `GSE49155`: esito della regola | «della forma», cambio **A1** (i livelli scritti prima della colonna) per tutti e due | — | G: nelle uscite di S12r3 i livelli sono scritti prima di leggere i valori della colonna (`GSE49155`: tre livelli dichiarati, la cella vuota prende il secondo; `GSE60340`: otto livelli con i trattamenti dentro, poi una colonna sola) | altre candidate nominate dall'handout: la tupla dei valori (A4) per `GSE49155`, una colonna per fattore (A2) per `GSE60340` |
| 8 | i 3 errori che con la forma A non c'erano (`GSE57945`, `GSE60340`, `GSE49155`): quanti hanno esito «della forma» | 2 | da 1 a 3 | G; per `GSE57945` non prevedo il cambio | 0: la prova non localizza nessun errore; il messaggio al PI è che la causa non si trova con un cambio per volta |
| 9 | `F12` (le due correzioni di forma insieme): studi chiusi; confronti ritrovati meno quelli di `B0` | 47 chiusi; +3 (71/95) | chiusi da 46 a 47; differenza da 0 a +6 | G, dal calcolo fatto dopo i numeri in S12r3 (47/47 e 71/95, che non è una misura) | sotto 46 chiusi o differenza negativa: la correzione di forma costa più di quello che rende; si legge perché |
| 10 | `F1` chiude `GSE50499`; `F2` chiude `GSE63816` | sì e sì | — | G | la correzione non fa quello per cui è scritta |
| 11 | studi con un errore nuovo (§4) per ogni forma a un cambio da `B0` (`RP`, `RPa`-`RPd`, `RP5`, `RC`, `RC3`, `RA1`, `RA4`, `RR`, `F1`, `F2`): mediana fra le forme | 2 | da 0 a 5 | G | oltre 5: ogni cambio sposta errori in altri studi, e nessuna forma si sceglie senza una misura su studi nuovi |
| 12 | `RA4` (senza la tupla dei valori): studi chiusi | 39 | da 35 a 43 | G: in S12r2 8 studi non chiudevano per un valore senza voce | sopra 43: la tupla non è quello che chiude gli studi |

**Lettura di un esito.** Una previsione su un conteggio esatto (1, 2, 3, 5, 6, 7, 10) si giudica sul conteggio.
Per 4, 8, 11 e 12 il conteggio osservato si confronta con l'intervallo: i 47 studi sono tutti gli studi di
sviluppo e le corse sono ripetibili, quindi il conteggio non ha errore di misura; l'incertezza sugli studi
(ricampionamento) si riporta accanto e riguarda la generalizzazione. Per 9 vale la regola della skill: intervallo
al 95% tutto dentro = confermata, tutto fuori = smentita, a cavallo = indeterminata.

**Non previsto, dichiarato:** i numeri di ogni forma intermedia (chiusi, identici, ritrovati) e il cambio che fa
sparire le 5 unità di lettura di S12r2 (`GSE57116`, `GSE75852`). Si misurano e si riportano come esplorativi.

## 3. La regola di diagnosi

**Stato di un errore in una forma.** Per ogni errore di lettura E (un predicato su uno studio, oppure, per un
errore nuovo, le unità di disaccordo e la firma di quello studio lette e descritte in §5) e per ogni forma X:
*presente*, *assente* o *non valutabile* (uscita non valida, oltre il contesto, o forma non compilata).

**Le due prove per una differenza D** (le sigle sono quelle di `01-carta.md`), per un errore che c'è in `B0` e non
in `A0`:

- **toglie(D):** E è presente in `B0` e assente nella forma che toglie solo D da `B0` (`RP`, `RPa`-`RPd`, `RP5`,
  `RC`, `RC3`, `RA1`, `RA4`, `RR`; per A3: assente in `RA4A3` e presente in `RA4`).
- **mette(D):** E è assente prima di D e presente dopo D, in una di queste coppie: `A0` e la forma che aggiunge
  solo D ad `A0` (`A0C`, `A0A1`, `A0A3`, `A0A2`), oppure due forme vicine della catena da `A0` a `B0`
  (`01-carta.md` §4).

Per un errore che c'è in `A0` e non in `B0` (le unità di S12r2) le due prove si scambiano i lati.

**Esiti.**

- **«Della forma (D)»:** toglie(D) e mette(D) valgono per la stessa differenza D, e lo stato di E non cambia sotto i
  due placebo della base in cui E è presente. Se le due prove valgono per più differenze, l'esito le nomina tutte.
- **«Del modello»:** E è presente in ogni forma in cui è valutabile, e almeno nelle due basi. Il finding riporta il
  conto delle forme (presente, assente, non valutabile).
- **«Non deciso»:** ogni altro caso, con la sotto-etichetta:
  - *instabile col placebo*: lo stato di E cambia sotto un placebo;
  - *una direzione sola*: per una differenza vale toglie(D) senza mette(D), o il contrario (comprende A2, che da
    `B0` non si toglie);
  - *più cambi, nessuna prova doppia*: più differenze lo spostano, e per nessuna valgono le due prove;
  - *non valutabile*: le forme che servono non sono valutabili.

Un esito «non deciso» o «del modello» non si corregge in questa sessione: va al PI col conto e con tutte le
opzioni. L'agente non sceglie.

## 4. Come si conta un errore nuovo

Uno studio ha un **peggioramento** in una forma, rispetto alla base di quella forma, se vale almeno una di queste:

1. lo stato scende: da gruppi identici a gruppi diversi o a non chiuso, da chiuso a non chiuso;
2. i confronti di Atlas ritrovati sono di meno;
3. i confronti del lettore giudicati errore (più fattori, braccio misto) sono di più;
4. un predicato dei 4 errori passa da assente a presente;
5. un conto generico sale (`fattori_doppi`, `soggetto_costante_nei_gruppi`);
6. la tabella dei fattori (firma) è diversa e lo studio ha almeno una unità di disaccordo che la base non ha.

Ogni peggioramento **si legge** (§5) e prende una causa: *lettura del modello*, *forma* (lo studio non chiude per
come è scritta l'uscita), *non errore* (colonna equivalente, scelta dei curatori di Atlas). Un **errore nuovo** è
un peggioramento con causa «lettura del modello». Conta **contro la variante**, anche se nasce in uno studio
diverso da quello per cui la variante era pensata, e gli si applica la regola di diagnosi di §3. Per ogni forma il
finding riporta: studi migliorati, studi peggiorati, errori nuovi di lettura, errori di lettura tolti.

## 5. Che cosa si legge

Si leggono **tutti** i disaccordi che cambiano, non solo quelli dei 4 studi: ogni coppia (studio, firma della
tabella dei fattori), in ogni corsa, che ha almeno una unità di disaccordo e in cui le unità o la firma sono
diverse dalla base. Una coppia (studio, firma) già letta in un'altra forma eredita la causa. Le 40 unità di `B0`
hanno già la causa di S12r3 (`26-disaccordi-M-righe.csv`) e non si rileggono.

**Le 8 unità che oggi non costano confronti** si contano in ogni forma con i due conti generici e, per `GSE63816`
(il livello «mutant» per tutti i 12 campioni di mielodisplasia), con la lettura dello studio nelle forme in cui
chiude. Per `GSE60340` le 2 unità hanno la causa del fattore non visto e seguono il suo predicato.

## 6. La forma finale

La forma finale si compone **con la regola, non col numero dei confronti ritrovati**:

1. parte da `B0`;
2. toglie una differenza D se almeno un errore di lettura ha esito «della forma (D)» e la forma che toglie D non
   ha errori nuovi di lettura (§4). Se togliere D toglie un errore e ne fa nascere un altro, D **non** entra: il
   conflitto va al PI come risultato;
3. aggiunge `F1` e `F2`, ognuna se chiude il suo studio (previsione 10) e non ha errori nuovi di lettura;
4. non aggiunge nient'altro.

La forma finale si scrive in `30-forma-finale.txt` prima delle sue due corse. Se coincide con `B0`, non servono
altre corse. È la forma che la regola indica: la forma del Piano 2 la decide il PI.

## 7. Che cosa NON cambia dopo i numeri

Questo file, `01-carta.md`, gli schemi e i prompt di `10-forme.R`, i predicati, la regola di diagnosi, la
definizione di errore nuovo, la regola della forma finale. Una sensibilità pensata dopo si riporta come
«dichiarata dopo i numeri» e non entra in nessun esito.
