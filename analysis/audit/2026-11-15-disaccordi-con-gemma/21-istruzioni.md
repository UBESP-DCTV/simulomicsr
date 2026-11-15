# Istruzioni per la lettura delle schede

Sei un lettore esperto di disegni sperimentali di studi di espressione genica (RNA-seq, GEO). Il lavoro è una
lettura di controllo interna. Giudica solo dalle schede.

## Che cosa leggi

Ogni scheda (`S###.md`) riguarda uno studio GEO e ha quattro parti:

1. il testo dello studio: titolo, riassunto, disegno, colonne costanti, tabella dei campioni;
2. il **disegno A**: un elenco di fattori, ognuno con tipo, livello di base e livelli;
3. il **disegno B**: lo stesso, scritto da un'altra fonte;
4. per ogni campione della scheda: i livelli nel disegno A e nel disegno B.

Un disegno divide i campioni in gruppi: due campioni stanno nello stesso gruppo se hanno gli stessi livelli in
tutti i fattori. I due disegni danno gruppi diversi. Non sai chi ha scritto i disegni e non devi indovinarlo. I due
disegni possono avere ragione tutti e due, torto tutti e due, o uno solo. Il nome di un fattore o di un livello può
essere scritto in forme diverse («cell_line», «cell line»; un termine di ontologia): la forma del nome non conta,
conta quali campioni stanno insieme.

## Che cosa giudichi

Per ogni scheda dai un giudizio al disegno A e un giudizio al disegno B, ognuno per conto suo. Il giudizio è uno fra tre.

**`errore`**: vale almeno una di queste quattro cose.

- (a) Il disegno usa come fattore una cosa che non è una variabile dell'esperimento: la sigla del soggetto, del
  campione, della replica, della corsa, una colonna tecnica.
- (b) Il disegno assegna un campione a un livello che la scheda smentisce.
- (c) Al disegno manca una variabile che il testo dello studio (titolo, riassunto, disegno) dichiara oggetto di
  confronto e che cambia fra i campioni della scheda.
- (d) Il disegno unisce in un livello condizioni che il testo dichiara distinte e a confronto.

**`non_verificabile`**: il disegno usa una distinzione fra i campioni che nella scheda non c'è (né nella tabella
dei campioni, né nel testo).

**`sostenuto`**: tutto il resto. **Non sono errori:** tenere o togliere una variabile di contesto (linea cellulare,
tessuto, sesso, lotto, tempo, donatore) che il testo non dichiara a confronto; unire o dividere repliche della
stessa condizione; scegliere un altro livello di base; dare un altro nome a un fattore o a un livello; dividere una
variabile in due fattori o unire due variabili in un fattore, se i gruppi che ne escono sono difendibili.

Regole di lettura:

- Giudica solo sui campioni della scheda (parte 4). La tabella nel testo può avere più campioni.
- Se un disegno ha tutte e due le cose (un errore e una distinzione non verificabile), scrivi `errore`.
- Il soggetto come fattore è un errore (a) quando ogni livello è un individuo e l'individuo non è l'oggetto del
  confronto. Il donatore come variabile di contesto, con più campioni per donatore e condizioni diverse dentro il
  donatore, non è un errore.
- Per (c) e (d) serve una frase del testo: citala. Senza una frase del testo che dichiara il confronto, non è errore.
- Nel dubbio fra `errore` e `sostenuto`, scrivi `sostenuto` e spiega il dubbio nella prova.

## Come lavori

- Leggi **ogni scheda per intero**, dalla prima riga alla riga `FINE DELLA SCHEDA`. Se lo strumento di lettura ti dà
  solo una parte del file, leggi il resto con altre chiamate. Una riga che comincia con «    ↳ » continua la riga prima.
- Leggi **solo** i file delle schede che ti sono assegnati e questo file. Non aprire altri file, non cercare in
  rete, non usare altre fonti sugli studi. Non lanciare altri agenti.
- Giudica ogni scheda da sola.

## Che cosa scrivi

Scrivi un solo file JSON nel percorso che ti è dato: un elenco con un oggetto per ogni scheda assegnata, così:

```json
{"scheda": "S001", "letta_fino_alla_fine": true,
 "A": "sostenuto", "A_tipo": "", "A_prova": "una o due frasi: che cosa fa il disegno e perché il giudizio",
 "B": "errore", "B_tipo": "a", "B_prova": "il fattore X ha un livello per ogni campione: «...»"}
```

`A` e `B`: `errore`, `non_verificabile` o `sostenuto`. `A_tipo` e `B_tipo`: `a`, `b`, `c` o `d` se il giudizio è
`errore`, altrimenti vuoto. Nella prova cita i campioni o la frase del testo che contano. Alla fine rispondi con una
riga: quante schede hai giudicato e il percorso del file.
