# Scheda di lettura (simulomicsr, prova S12p, 2026-11-08)

Sei un lettore di revisione interna. Leggi **solo** questa scheda e i pacchetti del tuo lotto, nella cartella
`/home/user/S12p-lettura-20261108/pacchetti/`. Non aprire altri file, non cercare nel disco o nel repository, non
usare la rete. Il giudizio si basa solo sul testo del pacchetto.

## Che cosa contiene un pacchetto

1. Le etichette che la pipeline ha dato ai due bracci e l'**entità proposta**: il trattamento o la condizione che,
   secondo la pipeline, distingue il braccio trattato dal controllo. Possono essere sbagliate.
2. Il testo grezzo dei metadati GEO di tutti i campioni dei due bracci: i campi uguali in tutti i campioni sono
   scritti una volta in alto; i campi uguali dentro un braccio, una volta per braccio; gli altri per campione, con
   le sigle T1, T2, … (trattato) e C1, C2, … (controllo). «(not available: sample deleted from GEO)» vuol dire che
   GEO non ha più quel testo.
3. Le **affermazioni da verificare** («[claim N]»), raggruppate per fonte («Source 1», «Source 2»). Le fonti sono
   letture automatiche dello stesso testo e possono sbagliare. Alcuni pacchetti non hanno affermazioni.

## Domanda 1: il confronto è confrontabile?

Un confronto è **confrontabile** se i due bracci differiscono in **una sola cosa**: l'entità proposta. Di solito è un
trattamento applicato al braccio trattato, contro un controllo con il veicolo o senza trattamento. Nei confronti
malati contro sani è la malattia o la condizione dei campioni.

Rispondi **"no"** se il testo mostra almeno uno di questi difetti. Le regole valgono sempre (decisioni del PI):

| tipo | difetto |
|---|---|
| `tempo_zero` | il controllo è raccolto al tempo zero (basale, pre-trattamento, «0 h», «day 0») e il trattato no |
| `tempo_diverso` | i due bracci sono raccolti a tempi diversi dall'inizio della perturbazione |
| `secondo_agente` | il trattato riceve, oltre all'entità proposta, un secondo agente (non un veicolo) che il controllo non riceve |
| `agente_nel_controllo` | il controllo riceve un agente (non un veicolo) che il trattato non riceve |
| `braccio_misto` | un braccio mescola campioni con e senza un agente |
| `entita_diversa` | ciò che distingue i bracci non è l'entità proposta (anche: l'entità è in tutti e due i bracci, o solo nel controllo) |
| `tecnica` | una differenza tecnica fra i bracci: preparazione o kit della libreria, poly(A) contro RNA totale, paired-end contro single-end, strumento, marcatura metabolica (per esempio 4sU). Vale anche se riguarda un solo campione |
| `materiale_o_sede` | materiale biologico, linea cellulare, popolazione o frazione profilata, sede anatomica diversi fra i bracci |
| `genotipo` | genotipo o modifica genetica di fondo diversi fra i bracci (oltre all'entità proposta) |
| `coltura` | condizioni di coltura diverse: terreno, siero, passaggio, formato 2D o 3D, co-coltura (non l'entità) |
| `soggetti` | in un confronto di trattamento: donatori, sesso o etnia diversi fra i bracci. In un confronto malati contro sani: sesso o età **senza nessun valore in comune** fra i bracci |
| `altro` | un'altra differenza sistematica fra i bracci che impedisce di attribuire la differenza alla sola entità proposta |

**Non sono difetti:**

- un dato non scritto: «non detto» non vuol dire «diverso»;
- nei confronti malati contro sani, donatori diversi (è il disegno), e sesso o età in parte diversi fra i due gruppi
  di donatori;
- differenze fra repliche presenti allo stesso modo in tutti e due i bracci; numeri di campione, di lane, di corsa,
  nomi di file;
- il veicolo presente solo nel controllo, o in tutti e due i bracci;
- la stessa dose o lo stesso tempo scritti in modo diverso nei due bracci.

Rispondi **"incerto"** solo se il testo non permette di decidere un punto che cambierebbe la risposta, e scrivi quale.
Per ogni difetto riporta il tipo e una citazione **esatta** dal testo del pacchetto (copia, non parafrasi).

## Domanda 2: le affermazioni

Per ogni `[claim N]`:

- `fatto`: **"vero"** se il testo conferma l'affermazione della prima riga (con i valori che la fonte riporta sotto);
  **"falso"** se il testo la contraddice o se la fonte ha frainteso il testo (per esempio una malattia o una
  condizione del donatore scritta come un agente applicato dagli sperimentatori, un valore che il testo non contiene,
  una differenza che in realtà vale per tutti e due i bracci); **"non_verificabile"** se il testo non basta.
- `conta`: **"si"** se l'affermazione è vera e rende il confronto non confrontabile secondo le regole di questa
  scheda; **"no"** se è vera ma non è un difetto secondo queste regole; **"na"** se il fatto è falso o non verificabile.

Le affermazioni «computed by code from structured GEO fields» non vengono da un lettore: il fatto è vero per
costruzione se i valori riportati sono diversi; giudica solo se la differenza è tecnica (`conta`).

## Che cosa scrivi

Un oggetto JSON per pacchetto, una riga per oggetto, nel file `/home/user/S12p-lettura-20261108/risposte/lotto-XX.jsonl`
(XX = il tuo lotto). Forma esatta:

```
{"id": "L0007", "confrontabile": "no", "difetti": [{"tipo": "secondo_agente", "citazione": "..."}], "affermazioni": [{"claim": 1, "fatto": "vero", "conta": "si"}, {"claim": 2, "fatto": "falso", "conta": "na"}], "nota": "al massimo 30 parole"}
```

- `confrontabile`: "si", "no" o "incerto". Se è "si", `difetti` è una lista vuota.
- `affermazioni`: una voce per ogni `[claim N]` del pacchetto, nell'ordine; lista vuota se il pacchetto non ne ha.
- Usa solo i tipi della tabella. Scrivi le citazioni con le virgolette interne precedute da `\`.

Leggi i pacchetti uno alla volta, nell'ordine del lotto. Aggiorna il file almeno ogni 5 pacchetti (con lo strumento
Write, riscrivendo il file intero). Alla fine controlla che il file abbia una riga valida per ogni pacchetto del lotto.
