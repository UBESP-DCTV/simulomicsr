# La lettura dei disaccordi con i curatori di Gemma: carta e previsioni

Depositata il 2026-11-15 prima di ogni calcolo di questa cartella. Dopo i numeri non cambia.
Mandato: PI, 2026-11-15, «fai tutto» (punto 2: la lettura dei disaccordi con i curatori di Gemma, con le previsioni
scritte prima). Niente di questa cartella entra nella pipeline. Nessuna spesa via API: i modelli non leggono studi nuovi.

## La domanda

Mistral-Small 3.2 nella forma `B0` (corsa `M-rp11`) ha gli stessi gruppi dei curatori di Gemma in 1.377 voci su 2.052
(67,1%) della parte aperta (`../2026-11-15-lettori-su-gemma/41-out.txt`). Restano 675 voci: gruppi più fini 307, più
grossi 156, incrociati 82, studio non chiuso 130. **Che cosa sono queste 675 voci: errori di lettura del lettore,
scelte diverse dei curatori, o limiti della vista e dell'adattatore?** La risposta decide quale numero si scrive come
errore del lettore: il 33% di oggi è un tetto, non una misura.

## Oggetto

- Le 2.052 voci misurate di Gemma della parte aperta; la corsa `M-rp11`; il riferimento è la tabella dell'adattatore
  di Gemma (`../2026-11-15-gemma-riferimento/30-adattatore-gemma.R`, regole 1-7), senza cambi.
- Gli altri lettori, già congelati: Gemma-4-31B (`GE-rp0`), Haiku 5.5 corsa 1, Sonnet 5.5 (tutti sui 2.016 studi
  dell'ingresso); Haiku corsa 2 e Opus 5.5 (252 studi) si riportano accanto.
- **La parte chiusa (991 studi), gli 82 studi di giudizio di Atlas: niente.** I 21 studi di sviluppo curati da Gemma
  entrano solo nel controllo positivo.
- Universo di ogni voce: i campioni di Gemma che stanno nella vista, come nella misura.

## Parte 1. Il censimento (un programma, tutte le 675 voci)

Scritture: P(T, S) è la partizione dei campioni dell'universo data dai livelli dei fattori S della tabella T;
«raffina» = ogni blocco della prima sta dentro un blocco della seconda. R è la tabella del lettore, G quella di Gemma.

1. **Voci non chiuse (130):** il motivo scritto dall'adattatore del lettore. Non entrano nelle classi qui sotto né
   nella lettura: la causa è la forma dell'uscita, già misurata (S12r4).
2. **Fattore in più del lettore:** un fattore h di R tale che P(G, tutti) non raffina P(R, {h}).
   **Fattore perso:** un fattore f di G tale che P(R, tutti) non raffina P(G, {f}).
   R' = R senza i fattori in più; G' = G senza i fattori persi.
3. **Classe del censimento** di ogni voce chiusa con gruppi diversi (545), una sola:
   - `fattore_in_piu`: nessun fattore perso e P(R') = P(G);
   - `fattore_in_meno`: nessun fattore in più e P(R) = P(G');
   - `fattori_in_piu_e_in_meno`: tutti e due gli insiemi non vuoti e P(R') = P(G');
   - `livelli_piu_fini`: non le prime tre, e un fattore in più del lettore raffina un fattore di Gemma (e non l'inverso);
   - `livelli_piu_grossi`: non le prime tre, e un fattore perso di Gemma raffina un fattore del lettore (e non l'inverso);
   - `altro`: il resto.
4. **Accanto, per ogni voce:** per ogni fattore in più: tipo scritto dal lettore, colonna di origine, se la sua
   partizione è uguale a quella di un fattore di Gemma tolto dall'adattatore (blocco o continuo); per ogni fattore
   perso: categoria di Gemma, e se esiste una **colonna della vista** (non costante, diversa da `title` e
   `description`, con meno valori distinti dei campioni) che lo raffina; campioni e numero di fattori di Gemma.
5. **Gli altri lettori sulla stessa voce:** per Gemma-4-31B, Haiku corsa 1 e Sonnet: se hanno i gruppi di Gemma
   (classe `identica`) e se hanno i gruppi di Mistral sull'universo. Haiku corsa 2 e Opus accanto.
6. **I 544 confronti non elencati giudicati errore:** per classe dei gruppi della voce e per motivo (più fattori di
   Gemma cambiano, braccio misto).

Che cosa il censimento vede: quanti e quali fattori separano le due tabelle. Che cosa non vede: chi ha ragione.

## Parte 2. La lettura (audit interno, a campione dichiarato)

- **Campione:** 120 voci fra le 545 chiuse con gruppi diversi: 50 più fini, 40 più grosse, 30 incrociate, estratte
  con `set.seed(20261115)` dalle voci ordinate per nome dentro ogni classe. **È un campione**: la lettura stima una
  quota con il suo intervallo; il censimento copre tutte le voci. Le quote si pesano per classe.
- **Scheda:** il testo intero dello studio nella vista (nessun taglio; si misura la scheda più lunga), i due disegni
  come «disegno A» e «disegno B» in ordine estratto a caso (chiave fuori dalla cartella delle schede), per ogni
  disegno i fattori con tipo, base e livelli e il gruppo di ogni campione. La scheda non dice chi ha scritto i disegni
  e non porta gli esiti degli altri lettori né la classe del censimento. Il cieco è parziale: i nomi dei livelli di
  Gemma sono termini di ontologia e si riconoscono.
- **Giudizio di ogni disegno**, uno fra tre:
  - `errore`: (a) usa come fattore una cosa che non è una variabile dell'esperimento (sigla del soggetto, del
    campione, della replica, della corsa, una colonna tecnica); (b) assegna un campione a un livello che la scheda
    smentisce; (c) non ha una variabile che il testo dello studio (titolo, riassunto, disegno) dichiara oggetto di
    confronto e che cambia fra i campioni; (d) unisce condizioni che il testo dichiara distinte e a confronto;
  - `non_verificabile`: usa una distinzione che nella scheda non c'è;
  - `sostenuto`: il resto. Tenere o togliere una variabile di contesto (linea, tessuto, sesso, lotto, tempo,
    donatore) che il testo non dichiara a confronto, unire o dividere repliche della stessa condizione, scegliere
    un'altra base: non sono errori.
- **Causa della voce** (dalla chiave, dopo i giudizi): `errore_del_lettore` (lettore `errore` o `non_verificabile`,
  Gemma no: il lettore ha solo la vista); `errore_del_curatore` (Gemma `errore`, lettore `sostenuto`); `errore_di_tutti_e_due`;
  `scelte_diverse` (tutti e due `sostenuto`); `fuori_vista` (Gemma `non_verificabile`, lettore `sostenuto`).
- **Due letture indipendenti** di tutte le 120 schede e delle esche, da agenti diversi con lo stesso testo di
  istruzioni; nessun agente vede i giudizi dell'altro. Dove le due cause sono diverse decido io sulla scheda, senza
  aprire la chiave. Gli agenti sono modelli Claude: è un audit interno, non una validazione pubblicabile.
- **Esche:** 4 schede dai 21 studi di sviluppo con la causa già letta (`../2026-11-15-gemma-riferimento/33-disaccordi-letti.csv`):
  `GSE46665` e `GSE60340` (errore di lettura di Mistral), `GSE51261` e `GSE71289` (Gemma unisce livelli: scelta).

## Cancelli

- **KD1** le uscite `M-rp11` e `GE-rp0`, l'ingresso e le uscite dei Claude hanno le impronte congelate
  (`40-uscite-sha256.txt`, `22-ingresso-sha256.txt`, `../2026-11-15-claude-su-gemma/20-uscite-sha256.txt`).
- **KD2** il censimento riforma la classe dei gruppi di ogni voce dalle due tabelle e ridà `41-per-voce-M-rp11.csv`
  riga per riga: 1.377 identiche, 307, 156, 82, 130 su 2.052; la partizione riformata dai livelli è uguale a quella
  scritta in ogni voce chiusa.
- **KD3** copertura: 545 voci su 545 hanno una classe del censimento, 130 su 130 un motivo; 120 schede su 120 e 4
  esche, tutte lette due volte, nessuna tagliata.
- **KD4** nessuno studio della parte chiusa, di giudizio o di sviluppo nel censimento e nel campione.
- **KD5** controllo positivo: (i) su uno studio finto il censimento dà le sei classi attese; (ii) sui due studi di
  sviluppo noti dà `GSE60340` = `fattore_in_meno` con una colonna nella vista e `GSE46665` = `livelli_piu_fini`;
  (iii) tutte e due le letture danno `errore` al disegno del lettore nelle esche `GSE46665` e `GSE60340`.

## Previsioni

Unità: la voce per le quote del censimento e della lettura; l'intervallo al 95% viene dal ricampionamento degli studi
GEO (B = 10.000, seme 20261115), dentro le classi per il campione. Gli intervalli di rilevanza sono un mio giudizio
motivato, salvo PD10 (variabilità misurata: kappa 0,78 in S3, 0,94 in S12p).

| | quantità | atteso | intervallo di rilevanza | perché |
|---|---|---|---|---|
| PD1 | voci chiuse con gruppi diversi dove almeno uno fra Gemma-4-31B, Haiku corsa 1 e Sonnet ha i gruppi di Gemma | 35% | 20-50% | sotto 20% un lettore migliore non cambia il numero; sopra 50% il disaccordo è soprattutto di Mistral |
| PD2 | voci chiuse con gruppi diversi dove almeno due dei tre altri lettori hanno i gruppi di Mistral | 40% | 25-55% | misura il disaccordo che tutti i lettori hanno con i curatori |
| PD3 | voci nelle tre classi a fattori interi | 65% | 50-80% | sotto 50% il disaccordo sta nei livelli, non nei fattori |
| PD4 | fra le voci `fattore_in_piu`: tutti i fattori in più sono di contesto o di tempo | 60% | 40-80% | è la scelta dei curatori vista sui 21 studi (linea, tempo) |
| PD5 | fra le voci con un fattore perso (`fattore_in_meno`, `fattori_in_piu_e_in_meno`): il fattore ha una colonna nella vista | 50% | 30-70% | sotto 30% il fattore perso sta nel testo o fuori dalla vista |
| PD6 | i 544 errori fra i non elencati che stanno in voci con gruppi diversi | 90% | ≥ 75% | sotto 75% l'errore nasce nei confronti, non nei gruppi |
| PD7 | lettura: `errore_del_lettore` più `errore_di_tutti_e_due` | 35% | 20-50% | con le 545 voci su 2.052 è un errore del lettore nel 5-13% delle voci |
| PD8 | lettura: `scelte_diverse` | 40% | 25-55% | sui 7 studi di sviluppo diversi da Gemma: 4 |
| PD9 | lettura: `errore_del_curatore` più `fuori_vista` | 15% | 5-30% | sopra 30% il riferimento va corretto prima di usarlo come misura |
| PD10 | kappa fra le due letture sulla causa | 0,70 | ≥ 0,60 | sotto 0,60 la lettura non regge una quota |
| PD11 | campione: quota con almeno un altro lettore identico a Gemma, `errore_del_lettore` meno `scelte_diverse` | +30 punti | > +10 | se vale, l'accordo fra lettori distingue l'errore dalla scelta |

## Che cosa si riporta alla fine

La quota di voci con un errore di lettura del lettore sulle 2.052 = (voci chiuse con gruppi diversi × quota di PD7)
/ 2.052, con l'intervallo, e accanto le 130 voci non chiuse. Nessuna soglia: la lettura descrive, non decide.
Ogni scostamento dalla carta si scrive nel finding come scostamento.
