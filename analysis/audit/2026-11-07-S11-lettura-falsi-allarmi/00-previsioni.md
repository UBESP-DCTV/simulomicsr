# S11, la lettura dei falsi allarmi: decisioni, regole della lettura, cancelli e previsioni

Depositato il 2026-11-07, prima di leggere una sola delle 56 righe e prima del censimento dei controlli a tempo
zero sui metadati GEO. Dopo il risultato questo file non cambia.

## Oggetto

- Deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`
  (194 meta-analisi), non toccato. Manifesto verificato a inizio sessione (`10-manifesto-inizio.txt`).
- I 1.903 confronti poolati: `analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds`, elemento `tenuti`.
- Il riferimento della S10: `analysis/audit/2026-11-07-S10-rilevatore/30-riferimento.csv` (129 confronti difettosi,
  1.704 puliti, 70 altri negativi). La rilettura di agosto: `analysis/audit/2026-08-20-rilettura-194/difetti.csv`.
  Tutti e due restano intatti: SHA-256 in `10-sha-riferimenti-inizio.txt`, da ricontrollare a fine sessione.
- L'elenco da leggere: `analysis/audit/2026-11-07-S10b-metadati-campioni/40-falsi-allarmi.csv`, 56 righe (40 puliti,
  16 altri negativi), segnalate dalla combinazione scelta dal PI nella S10b (R1 + R2a + R2b + R6 + la parte di V3
  senza la soglia a un agente). Riprodotte da `40-esiti.csv` (colonna `PROPOSTA`): 43 difettosi, 40 puliti,
  16 altri negativi, e le 56 coincidono con l'elenco.

## Decisioni del PI, prese in questa sessione prima del deposito

1. **Controllo a tempo zero** (risposta «1»): un confronto è difettoso quando il controllo è raccolto a tempo zero,
   il tempo zero si legge nell'etichetta o nei metadati GEO, e il trattato resta in coltura più a lungo. Vale per
   tutti i confronti con un controllo a tempo zero, non solo per le 56 righe.
2. **Difetti leggibili solo nei metadati GEO** («Sì, con la fonte marcata»): entrano nel riferimento corretto, con
   una colonna `fonte` = `metadato`. Il file di agosto resta intatto.
3. **Nessuna soglia di errore.** Il PI: «La pipeline non deve sbagliare. Sono dati fissi, non ci sono dati nuovi.
   È un database fisso.» La risposta precedente al criterio («Tutta la combinazione») è superata: non si sceglie
   quanti falsi allarmi accettare. Ogni falso allarme confermato dalla lettura è un errore della regola, con una
   causa da correggere prima della produzione (S12). Ogni difetto che la regola non vede è un errore da spiegare.
   **Quindi la tabella delle soglie chiesta dall'handout non si calcola**: non c'è una soglia da scegliere.

## Il materiale di ogni riga

Per ogni confronto letto, una scheda con:

- meta-analisi (entità e nome), studio, etichette del trattato e del controllo (Stadio 2);
- i valori dello Stadio 1 che fanno scattare la regola (colonne `det_*`);
- per ogni campione del trattato e del controllo: titolo, sorgente e caratteristiche GEO (H5 ARCHS4 v2.5,
  `meta/samples/`), e il tempo e gli agenti scritti dallo Stadio 1;
- gli altri gruppi dello studio (Stadio 2, master `analysis/p4-output/A3-stage2-master-innestato.jsonl`) con le loro
  etichette, per vedere il disegno (per esempio se esiste un controllo raccolto allo stesso tempo).

## Le regole del giudizio

Sono le regole 1-6 della rilettura di agosto (`analysis/audit/2026-08-20-rilettura-194/C1-workflow-rilettura.js`,
costante `REGOLE`), con le decisioni 1 e 2 del PI. In breve: un confronto è giusto se i due bracci differiscono
solo per l'entità della meta-analisi, nel verso dichiarato, contro un controllo del tipo dichiarato. Le differenze
fra studi diversi sono normali. Nei caso-controllo di malattia i soggetti diversi sono il disegno. Nel dubbio si
sceglie la lettura che non sovrastima la qualità del dato, e la scelta si dichiara.

**Esito di ogni riga** (`30-lettura.csv`), una riga per confronto, con la citazione del testo su cui si basa:

| esito | significato |
|---|---|
| `sbagliato` | i bracci non sono appaiati; `fonte` = `etichetta` se si legge nell'etichetta dello Stadio 2, `metadato` se si legge solo nei metadati GEO |
| `giusto` | i bracci sono appaiati: la regola ha sbagliato. Si scrive la causa (il valore dello Stadio 1 sbagliato o irrilevante, oppure la logica della regola) |
| `incerto` | etichetta e metadati non bastano. Entra nel riferimento corretto come `non_provato`, come le tre righe «sospetto» della S10 |

La famiglia del difetto usa le famiglie della S10 (`analysis/audit/2026-11-07-S10-rilevatore/40-esiti.csv`).

## Il censimento dei controlli a tempo zero (decisione 1)

Candidati, sui 1.903 confronti, tre fonti unite:

1. Stadio 1: tutti i controlli con un tempo hanno `value_hours` 0 o `is_zero_timepoint`, e almeno un trattato ha
   un tempo maggiore di 0 (prima stima in apertura: 51 confronti, 20 studi, 19 meta-analisi);
2. etichetta del controllo con un tempo zero (`time zero`, `0 h`, `0 min`, `day 0`, `t0`, `baseline`,
   `pre-treatment`) e etichetta del trattato senza;
3. metadati GEO (titolo, sorgente, caratteristiche) di tutti i controlli con un tempo zero, con lo stesso elenco di
   forme, e trattati senza.

Ogni candidato si legge: la decisione 1 si applica se il tempo zero e il tempo del trattato si leggono nell'etichetta o
nei metadati GEO. Un tempo zero scritto solo dallo Stadio 1 (dedotto dal modello) non basta.

## Che cosa si misura dopo la lettura

- il registro di ogni confronto che cambia stato rispetto al riferimento della S10 (`40-registro-cambi.csv`);
- il riferimento corretto al livello del confronto (`41-riferimento-dopo-S11.csv`, formato della S10 più `fonte`) e
  nel formato di agosto (`42-difetti-dopo-S11.csv`, coppie gruppo-studio più `fonte`);
- la sensibilità della combinazione sul riferimento della S10 e su quello corretto, tutte e due dichiarate.
  **La sensibilità corretta è ottimistica**: i metadati GEO si leggono solo sugli allarmi e sui candidati a tempo zero;
- per ogni falso allarme confermato, la causa, raggruppata, per la sessione che porta la regola in produzione (S12);
- i verdetti delle 194 meta-analisi che cambiano: un nuovo difetto provato porta `corretta` o `incerta` a
  `difettosa`; un nuovo `non_provato` porta `corretta` a `incerta`. Si confronta con la regola della S5;
- descrittivo: quante delle 194 meta-analisi scendono sotto 3 studi se si tolgono tutti i confronti del
  riferimento corretto (conteggio degli studi distinti fra i confronti tenuti; cancello C2(c)).

Incertezza: unità = studio. Bootstrap degli studi, B = 2000, seme 20261107, percentili 2,5 e 97,5, per la sensibilità.
I conteggi sui censimenti (verdetti, falsi allarmi letti) non hanno intervallo di campionamento.

## Controlli

| controllo | atteso |
|---|---|
| il censimento a tempo zero trova i confronti noti | 11 su 11 di `GSE126409`, 10 su 10 di `GSE221804` |
| la scheda porta l'informazione dei difetti noti (letti come controlli, non alla cieca) | `sbagliato` per `GSE139963` «Hypoxia + TGF-β1» contro «PBS (Vehicle Control)», `GSE97744` «Circulating macrophage + IFN-γ and LPS» contro «untreated», `GSE210984` «MSC iPSC-derived TGF-β 21 days» |
| la scheda porta l'informazione dei confronti puliti noti | `giusto` per `GSE139963` «TGF-β1» contro «PBS (Vehicle Control)» e `GSE114686` «Lapatinib 1 µM 24h» contro «DMSO 0.001 µM 24h» |

**Limite dichiarato prima.** Il lettore è uno solo (l'agente) e sa che ogni riga è un allarme della regola. La lettura
non è alla cieca. La rilettura di agosto ha un accordo test-retest kappa 0,78: un solo lettore ha un errore dello
stesso ordine.

## Cancelli

| # | cancello | passa se |
|---|---|---|
| C1 | manifesto SHA-256 del deliverable, a inizio e a fine sessione | `VERIFICA OK` tutte e due le volte |
| C2 | riproduzione | (a) le 56 righe coincidono con `PROPOSTA` di `40-esiti.csv` (fatto in apertura: sì); (b) la combinazione prende 43 su 129 col riferimento della S10; (c) il conteggio degli studi distinti fra i confronti tenuti riproduce `k_effective` del deliverable in 194 meta-analisi su 194 |
| C3 | copertura | 56 righe su 56 e tutti i candidati a tempo zero con un esito e una citazione |
| C4 | controlli | tutti i controlli della tabella sopra come attesi |
| C5 | file intatti | `git diff --stat R/` vuoto; SHA-256 di `difetti.csv`, `30-riferimento.csv`, `40-esiti.csv`, `40-falsi-allarmi.csv` uguali a inizio sessione |

## Previsioni

| # | quantità | atteso | intervallo di rilevanza e motivo |
|---|---|---|---|
| P1 | meta-analisi il cui verdetto passa fra `corretta` e `difettosa` dopo la lettura e il censimento a tempo zero | 8 | **più di 5, oppure almeno una nelle 40** (soglia della S5): la scelta delle 40 e delle 132 decade |
| P2 | fra le 56 righe, confronti `giusto` (errori della regola) | 20 | **più di 0**: la regola non va in produzione così com'è, e la S12 deve correggere ogni causa (decisione 3) |
| P3 | confronti con un controllo a tempo zero leggibile nei metadati GEO ma senza tempo zero nello Stadio 1 | 3 | **più di 0**: lo Stadio 1 non scrive il tempo zero in tutti i casi, e la regola non può vederli dai soli fatti dello Stadio 1 |

## Che cosa non si fa

- Non si cambia la regola mentre si legge. Le cause dei falsi allarmi vanno alla S12.
- Non si modificano `difetti.csv` di agosto, il riferimento della S10, il deliverable, i master e `R/`. I file
  corretti sono nuovi, in questa cartella.
- I verdetti delle meta-analisi che cambiano sono una conseguenza delle decisioni 1 e 2 del PI. Si registrano, e il PI
  li legge nel riassunto.
- Non si usa la validazione esterna.
- La validazione con le meta-analisi pubblicate, proposta dal PI in questa sessione, non si fa qui: va nell'handout come
  sessione nuova.
