# HUMANE — Lettore dello studio e tabella dei fattori

Versione leggibile del plan `2026-11-09-lettore-studio-tabella-dei-fattori-plan.md`. Il disegno approvato è
`docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`.

## Cosa fa, in due righe

Il piano costruisce gli strumenti che misurano un lettore dello studio contro i curatori di Expression Atlas.
Poi misura la pipeline di oggi con gli stessi strumenti, e fa una prova piccola del lettore su 47 studi.

## Perché quattro piani e non uno

Il disegno ha dieci fasi. Le fasi dalla 1 alla 9 dipendono da numeri che oggi non abbiamo: quale vista
funziona, quanto è lunga l'uscita del modello, quale modello serve. Un piano dettagliato di quelle fasi,
scritto oggi, fisserebbe scelte prima della misura.

| piano | che cosa dà | quando si scrive |
|---|---|---|
| 1 · fondamenta e prova | la misura di oggi, la misura del lettore di prova, le cause dei disaccordi | scritto ora |
| 2 · il lettore nel pacchetto | i testi GEO di tutti gli studi, il lettore definitivo, il modello scelto, il cancello sui due insiemi di giudizio | dopo la tua decisione sul Piano 1 |
| 3 · corsa intera e deliverable nuovo | tutti i 24.393 studi, i nomi delle entità, le meta-analisi nuove | dopo il cancello |
| 4 · validazione del risultato | LINCS, Tahoe-100M, TCGA, meta-analisi contro singolo studio | dopo il deliverable nuovo |

## Le sei idee chiave del Piano 1

1. **La divisione degli studi e le previsioni vengono per prime.** I 129 studi di Atlas si dividono in 47 di
   sviluppo, 42 del primo giudizio e 40 del secondo. Degli 82 studi di giudizio nessuno legge fattori,
   confronti o uscite del modello fino all'apertura.
2. **La definizione di confronto diventa codice con i test.** Due gruppi sono un confronto se sono uguali in
   tutti i fattori tranne uno, e in quel fattore uno dei due è al livello di base. Ogni coppia non formata
   riceve un motivo scritto.
3. **Lo stesso codice lavora sui fattori dei curatori.** Per questo possiamo dire quali confronti di Atlas
   rispettano la definizione, e giudicare i nostri confronti che Atlas non elenca.
4. **Tre misure.** (a) I nostri gruppi sono uguali ai gruppi dei curatori? (b) Quanti confronti dei curatori
   ritroviamo? (c) Quanti nostri confronti in più mescolano due differenze secondo i fattori dei curatori?
5. **La pipeline di oggi si misura per prima.** È il termine di paragone, ed è un numero per l'articolo.
6. **La prova è da buttare.** Mistral-Small 3.2 legge i 47 studi di sviluppo con una vista e uno schema di
   prima versione. L'agente legge ogni disaccordo e ne scrive la causa. Poi decidi tu.

## Le scelte dell'agente che non stanno nel disegno

Il disegno le lascia a chi implementa. Sono qui perché tu le possa rifiutare.

1. **La regola della divisione.** I 12 studi già letti vanno nello sviluppo. Gli altri 117 si dividono per il
   resto della divisione per 3 del numero GEO. Il risultato è 47, 42 e 40, non «circa 51, 39 e 39».
2. **L'ordine.** Il costruttore dei confronti e le misure entrano nel pacchetto prima della prova. Il disegno
   metteva la prova prima di ogni codice. La prova usa quel codice, e quel codice non dipende dal suo esito.
3. **Le misure usano i campioni comuni.** Atlas esclude alcuni campioni e noi altri. Le misure lavorano sui
   campioni presenti nei due lati, e contano gli esclusi.
4. **Il numero principale dell'ordine** è la quota di studi con gruppi identici a quelli dei curatori.
5. **L'età.** Se ogni valore contiene un numero, due bracci sono confrontabili quando gli intervalli di età
   si sovrappongono. Con la regola degli insiemi, due bracci con età tutte diverse non sarebbero mai confrontabili.
6. **Sesso ed età in un confronto fra trattato e controllo** seguono la regola dei donatori. La tua decisione
   dell'8 novembre li nominava solo per il confronto fra malati e sani.
7. **Il contesto della prova** è di 65.536 token, con 16.384 per l'uscita. Uno studio più lungo si conta e non
   si taglia. Il contesto più grande chiede due GPU per processo e va nel Piano 2.
8. **La prova usa il meccanismo di lancio già esistente**, con prompt e schema sostituiti e controllati per
   impronta. Così nessun codice di prova entra nel pacchetto.
9. **I valori attesi delle previsioni sono giudizio motivato.** Non esiste una misura precedente contro un
   riferimento esterno.
10. **La pipeline di oggi si misura con almeno 2 campioni per braccio**, come il lettore. La misura senza
    questo limite si riporta come secondaria.

## Che cosa il Piano 1 non fa

- Non apre gli studi di giudizio.
- Non scrive il lettore definitivo e non sceglie il modello.
- Non tocca il deliverable, i master e gli stadi a valle.
- Non lancia la corsa su tutti gli studi.
