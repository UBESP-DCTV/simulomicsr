# Note del revisore indipendente — rilettura delle 38 schede

Data: 2026-11-12. Uscita: `uscita/26-letture-revisore.csv` (38 righe). Script di scrittura e controllo:
`uscita/scrivi-e-controlla.py` (38 righe, id uguali a `schede-da-leggere.csv`, regole causa/dove/etichette: nessun errore).

## Conti

| causa | schede |
|---|---|
| lettura del modello | 25 |
| non errore | 9 |
| forma | 4 |

| dove | schede |
|---|---|
| nella lettura nuova | 15 |
| in nessuna | 13 |
| in B0 | 5 |
| in tutte e due | 5 |

Schede con almeno un'etichetta: 21 su 38.

## Come ho deciso (regole che ho applicato a tutte le schede)

1. `dove` dice dove sta l'errore di lettura che causa la differenza. Le etichette elencano tutti gli errori di lettura
   presenti nella lettura nuova, anche quelli che non causano la differenza.
2. Un livello usato nelle voci e non dichiarato, un ruolo incoerente, il nome `not_applicable`: forma.
3. Una colonna equivalente (stessa partizione dei campioni) o il solo cambio di tipo del fattore: non errore.
4. Un controllo mandato a un livello con nome vuoto, con base vuota: lettura del modello.
5. Un fattore di troppo è un errore quando la stessa grandezza è scritta in due fattori (GSE57116 L3). Non è un errore
   quando la lettura aggiunge una colonna vera e distinta con la stessa partizione (GSE103501 L5, GSE71289).
6. Quando una scheda non è chiusa per un motivo di forma, ma B0 o la lettura nuova ha anche un errore di lettura, la
   causa è `lettura del modello` e il motivo di forma sta nella descrizione.
7. Un attributo del soggetto scritto come fattore (sesso, età, paese, passaggio) è un errore di lettura. Una colonna
   del soggetto con il ruolo sbagliato è un errore quando il ruolo esatto esiste (age → subject/donor, GSE63816 L6).

## Casi dubbi

| scheda | scelta | dubbio |
|---|---|---|
| `GSE103501\|3d36c1a7730a\|da51d3ac` (L5) | non errore | Il fattore «group» ripete la partizione del tempo e il costruttore conta un fattore doppio; la colonna è vera e gruppi e confronti non cambiano. |
| `GSE112057\|d62cd9d66170\|c25deea5` (L2 L4 L8) | lettura del modello, nella lettura nuova | NA di ancestry non dichiarato mancante, ma gruppi e confronti 5/5 sono uguali a B0: l'alternativa è «non errore». |
| `GSE147507\|176d2a969095\|0c9f8029` (L3) | lettura del modello, in tutte e due | La scheda non è chiusa anche per forma (ruolo incoerente di source_name_ch1); ho scelto la lettura perché ci sono un fattore inventato e i tempi sbagliati. |
| `GSE147507\|6e8f57fbd9a5\|2060fa8c` (L4) | lettura del modello, in tutte e due | Ruxolitinib ha 6 campioni dalla description, contro 3 da source_name_ch1 in L3: non posso verificare quale conto è giusto (voci troncate), quindi non ho messo un'etichetta. Lo stesso vale per L8. |
| `GSE147507\|b738508cf3df\|d937fe8f` (L2) | lettura del modello, in tutte e due | Dissento da S12r4 (nessun errore): affermo un errore di B0 che la scheda non elenca (vedi sotto). Se il PI non lo accetta, la scheda diventa «non errore». |
| `GSE57116\|c37409409645\|96ec7e0c` (L3) | lettura del modello, nella lettura nuova | Il tempo scritto due volte non cambia gruppi né confronti (2/2): l'alternativa è «non errore». |
| `GSE57945\|6c079af72d99\|0c9f8029` (L2) | lettura del modello, nella lettura nuova | La mancata chiusura nasce da ruoli incoerenti (forma), ma i due fattori dell'età sono una lettura sbagliata. |
| `GSE60340\|5ec302b13e8b\|75c46680` (L3) | lettura del modello, in tutte e due | La differenza è solo la base (immortal invece di young), difendibile da sola; il braccio misto è un effetto della colonna del trattamento non vista, che B0 ha già. Alternativa: «non errore». |
| `GSE60340\|f88c0bb58658\|0c9f8029` (L7) | lettura del modello, in B0 | S12r4 dice forma. La lettura di L7 è giusta e non è chiusa per forma; ma B0 non vede la colonna del trattamento. Alternativa: forma, in nessuna. |
| `GSE63816\|17660776ac46\|0c9f8029` (L6) | lettura del modello, nella lettura nuova | age con ruolo subject/donor invece di subject/age: senza effetto su gruppi e confronti. Alternativa: «non errore». |
| `GSE63816\|41564f163411\|0c9f8029` (L7) | non errore | S12r4 dice forma. Il motivo di forma (`not_applicable`) è uguale in B0 e non causa la differenza; la differenza è l'unione dei due shRNA in un livello, come fa Atlas. |
| `GSE65335\|69079952891b\|d1fc7ae6` (5 letture) | non errore | Alternativa: lettura del modello in B0 (contesto senza base, perde ALI contro submerged). I due bracci differiscono anche nel tempo (giorno 14 contro giorno 8), quindi tutte e due le letture sono difendibili. |
| `GSE69597\|9e2a6d6e69a7\|4db9efdf` (L8) | non errore | La leishmaniosi è un livello dello stadio invece di non applicabile; senza effetto. Ho dedotto dai conti la corrispondenza fra i codici di «subgroup» e gli stadi. |

## Dove dissento da S12r4

- **GSE147507, B0.** S12r4 non segna errori per B0. Nella scheda B0 legge il tempo solo da «time point» e scrive
  «time after treatment» uninformative: dichiara i livelli 4hrs, 6hrs e 12hrs senza campioni (24hrs 16, 9hrs 4,
  non applicabile 57) e confronta 6 campioni IFNB di tre tempi diversi con 7 mock. Le due colonne del tempo sono
  complementari. Conseguenza: L2, L3 e L4 hanno `in tutte e due`; L8 ha un'etichetta in più.
- **GSE112057, le due schede.** S12r4 lascia la causa vuota. Io vedo NA non dichiarato mancante in colonne del
  soggetto: in una scheda costa 5 confronti su 5, nell'altra non costa.
- **GSE60340 L7 e GSE63816 L7**: vedi la tabella dei dubbi.
- **GSE49608 L6, GSE60340 L6, GSE60585**: l'etichetta «forma» di S12r4 vale per le corse non chiuse con la stessa
  firma; queste corse sono chiuse e le ho giudicate sui loro fatti.

## Etichette nuove (non in `etichette-S12r4.txt`)

- `GSE112057:NA di ancestry non dichiarato mancante`
- `GSE147507:IFNB non applicabile sull'infezione`
- `GSE147507:fattore organism inventato da cell type`
- `GSE147507:tempi 4 e 6 ore scritti come non applicabile`
- `GSE147507:time after treatment non letta`
- `GSE147507:time point non letta`
- `GSE63816:age come donatore`

## Osservazioni senza etichetta

- `country` (GSE69597, B0 e L8) e `ancestry` (GSE112057, B0 e letture nuove) hanno ruolo subject/donor. Sono
  attributi del soggetto, non il donatore. Non conosco un ruolo migliore nello schema e non causano la differenza.
- GSE63816: il livello di malattia che contiene i 12 campioni MDS ha nome «mutant», e l'eritroleucemia va a
  `not_applicable`, in B0 e in tutte le letture nuove. La partizione è giusta.
- GSE147507 L4 e L8: ruxolitinib con 6 campioni dalla description (3 in L3 da source_name_ch1). Non verificabile.

## Limiti della mia lettura

- Le righe «voci» delle schede sono troncate a 14 voci da chi ha fatto le schede (per esempio 77 voci, 14 mostrate).
  Dove serviva ho usato «campioni per livello» e i conti dei valori distinti in testa al file.
- Anche i valori distinti in testa sono troncati («… altri N valori»).
- Ho giudicato solo sui file di questa cartella. Non ho letto il testo intero degli studi su GEO.
- Le righe di legenda `L1`-`L8` sono uguali in tutti i file: le ho lette per intero in `GSE103501.txt` e
  `GSE112057.txt` e le ho saltate negli altri.

## File letti (27, tutti in questa cartella)

- `ISTRUZIONI.md`
- `schede-da-leggere.csv`
- `etichette-S12r4.txt`
- `schede/GSE103501.txt`
- `schede/GSE112057.txt`
- `schede/GSE147507.txt`
- `schede/GSE46665.txt`
- `schede/GSE49155.txt`
- `schede/GSE49608.txt`
- `schede/GSE50499.txt`
- `schede/GSE50760.txt`
- `schede/GSE53280.txt`
- `schede/GSE56235.txt`
- `schede/GSE56691.txt`
- `schede/GSE56787.txt`
- `schede/GSE57116.txt`
- `schede/GSE57945.txt`
- `schede/GSE60340.txt`
- `schede/GSE60585.txt`
- `schede/GSE63816.txt`
- `schede/GSE65335.txt`
- `schede/GSE66573.txt`
- `schede/GSE67812.txt`
- `schede/GSE68919.txt`
- `schede/GSE69597.txt`
- `schede/GSE71289.txt`
- `schede/GSE83687.txt`

File scritti: `uscita/26-letture-revisore.csv`, `uscita/note-revisore.md`, `uscita/scrivi-e-controlla.py`.
Non ho letto niente fuori da questa cartella, non ho usato la rete, non ho lanciato altri agenti.
