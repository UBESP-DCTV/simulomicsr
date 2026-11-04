# Sessione S8, decisione sul re-run completo: cancelli e previsioni

Scritto il 2026-11-04, prima del calcolo su studi fuori dal sottoinsieme A3. Dopo il risultato questo file non cambia.

**Già visto prima del deposito, quindi non è una previsione:** 1.123 → 993 studi, 271 usciti, 141 entrati, tutti e 141 dentro il
sottoinsieme A3; i tempi SLURM dei job (`sacct`); il costo della rilettura delle 194 (60 agenti, 33-43 minuti, 5,3-6,2 M token, finding S3).

**Oggetti.** Deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`.
Riferimento `.../archivio/20260815T193851Z-stage4-v16-3e31e59d`. Stadio 3 A3 `analysis/p4-output/20260818T110906Z-stage3-v16-7f986159`.
Stadio 3 riferimento `analysis/p4-output/20260814T025911Z-stage3-v16-7f986159`, lo stesso che definisce A3.

**Incertezza.** Unità: lo studio. Bootstrap degli studi di A3, B = 2000, seme 20261104.

## La domanda

Il conto dell'handout usa il netto di -130 studi come argomento contro il re-run. A3 ha però rigenerato solo studi già in gruppi con
almeno due studi, quindi gli altri studi non hanno avuto la possibilità di entrare. Il netto può dipendere dal disegno. Serve una stima di
quanti dei 21.828 studi entrerebbero e di quante meta-analisi cambierebbero.

## Lo stimatore, fissato prima

Una coppia è (studio, entità, verso, tipo di controllo) nei gruppi `cgroup` dello Stadio 3. Una coppia è singola se il suo gruppo ha un solo
studio. Il deliverable tiene una meta-analisi per entità, quindi un gruppo nuovo conta solo per un'entità che oggi non ha una meta-analisi.

Sugli studi di A3 misuro due tassi per coppia singola del riferimento:

- `r_stessa`: l'entità e il verso hanno una chiave nel deliverable. Il tasso conta le coppie per cui il run nuovo dà allo stesso studio una
  chiave del deliverable con stessa entità, stesso verso e altro tipo di controllo, che lo studio prima non aveva.
- `r_altra`: l'entità e il verso non hanno una chiave nel deliverable. Il tasso conta, per studio, le chiavi del deliverable nuove con un'altra
  entità, divise per queste coppie singole.
- `f_pool`: la frazione degli arrivi con lo studio davvero poolato in quel gruppo.

Applico i tassi alle coppie degli studi fuori da A3. Uno studio fuori entra con probabilità
`1 - (1 - r_stessa*f_pool)^n_stessa * (1 - r_altra*f_pool)^n_altra`. Gli arrivi per entità e verso vanno sulle chiavi del deliverable, in proporzione
ai loro studi. Una meta-analisi è toccata con probabilità `1 - exp(-a)`, dove `a` è il numero atteso di arrivi.

Per i gruppi con due studi di un'entità senza meta-analisi uso lo stesso tasso, calcolato sulle chiavi con almeno due studi (`r_stessa_k2`).

**Che cosa lo stimatore non vede.** I tassi vengono da studi con almeno un gruppo condiviso, che possono differire dagli altri. Non vede i
gruppi che nascono da due studi nuovi insieme, l'effetto delle fusioni e un eventuale movimento dei 2.566 studi già rigenerati. Non dice se gli
studi nuovi sono corretti. Il numero è una stima d'ordine di grandezza, non una misura sul corpus.

## Cancelli

1. Il manifesto SHA-256 del deliverable passa, all'inizio e alla fine.
2. Lo script riproduce: 2.566 su 24.394 studi, 86.898 su 508.037 record, 211 → 194, 38 uscite, 21 entrate, 173 comuni, 1.123 → 993 studi, 271 usciti,
   141 entrati, e i k invariati, in calo, in crescita 68, 76, 29.
3. Copertura: il calcolo classifica tutti gli studi fuori da A3 e tutte le 194 meta-analisi. Il denominatore è scritto nell'output.
4. Controllo positivo dello stimatore, in due parti. (a) Lo strumento delle coppie vede almeno 135 dei 141 studi entrati in una chiave del deliverable.
   (b) Validazione incrociata: divido gli studi di A3 a metà a caso (seme 20261104), stimo i tassi su una metà e prevedo gli arrivi nell'altra. Il rapporto
   previsto/osservato sta fra 0,7 e 1,3 nei due versi. Se fallisce, lo stimatore non vale e il riassunto non lo usa.
5. Ogni voce del costo del re-run ha una fonte misurata, oppure è marcata come stima con il suo calcolo.

## Previsioni

| # | quantità | atteso | intervallo di rilevanza | da dove viene l'intervallo |
|---|---|---:|---:|---|
| P1 | studi fuori da A3 con almeno una coppia `cgroup` | 55% | 40-70% | giudizio: la frase dell'handout «oggi tutti in gruppi da uno studio solo» vale solo per questi. Sotto il 40% la platea reale è meno di metà di quella dichiarata |
| P2 | studi fuori da A3 con entità e verso di una delle 194 | 10% | 5-20% | giudizio sul costo: sopra il 20% un re-run mirato perde gran parte del vantaggio di costo, sotto il 5% è un lavoro di poche ore |
| P3 | studi fuori da A3 che entrerebbero nel deliverable | 150 | 50-250 | 5-25% dei 993 studi poolati. Giudizio: sotto il 5% la potenza cambia poco, sopra il 25% il deliverable cambia in modo sostanziale |
| P4 | meta-analisi toccate fra le 194 | 60 | 49-146 | 25-75% delle 194. Giudizio: sotto il 25% la rilettura resta valida in gran parte, sopra il 75% scade quasi tutta |
| P5 | meta-analisi toccate fra le 41 attuali | 10 | 4-20 | 10-50%. Giudizio: sotto 4 l'insieme principale non cambia in pratica, sopra 20 cambia per metà |
| P6 | meta-analisi nuove da gruppi con due studi, per entità senza meta-analisi | 30 | 10-60 | variabilità misurata: A3 ne ha fatte entrare 21, e l'intervallo va da circa metà a circa tre volte |

**Margini.** P1-P5 usano un giudizio motivato, non una soglia del progetto. Lo dico al PI nel riassunto.

## La regola per la raccomandazione, fissata prima

- Se l'IC di P3 sta tutto sotto 50 e l'IC di P5 tutto sotto 4: raccomando **no**. Il limite nei Methods basta.
- Se l'IC di P3 sta tutto sopra 250, oppure l'IC di P6 tutto sopra 60: raccomando **sì**. Il deliverable è incompleto in modo sostanziale.
- Negli altri casi la scelta non viene dal numero. Porto al PI le opzioni con i costi misurati e dico quale preferisco e perché.
