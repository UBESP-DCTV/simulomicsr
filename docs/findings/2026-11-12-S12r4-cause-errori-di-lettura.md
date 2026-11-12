---
type: Finding
title: "Dove nasce ogni errore di lettura del lettore dello studio: 31 forme dell'uscita, un cambio per volta, Mistral-Small 3.2, gli stessi 47 studi"
description: "Con 31 forme dell'uscita provate un cambio per volta sugli stessi 47 studi, nessun cambio toglie un errore di lettura senza farne nascere altri: gli errori si spostano fra gli studi anche con una frase riscritta senza cambiare il senso, un solo errore dei 4 resta in tutte le 31 forme, e la regola depositata dà come forma finale la forma di partenza senza cambi."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-12T00:00:00+01:00}
sources:
- {id: carta, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/01-carta.md", title: "La carta: tutte le differenze fra le due forme dell'uscita, la variante di ognuna, le 31 forme, i limiti dichiarati prima (commit 41d0231)"}
- {id: previsioni, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/00-previsioni.md", title: "Cancelli 1-5, previsioni 1-12, regola di diagnosi, conto dell'errore nuovo e regola della forma finale, depositati prima di ogni corsa (commit 25062af)"}
- {id: strumento, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/11-out.txt", title: "Cancello dello strumento sulle uscite congelate (cancello 2) e il ponte fra i due lati"}
- {id: compila, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/12-out.txt", title: "Prova di compilazione delle 17 classi di schema su poddgx02"}
- {id: corse, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/23-out.txt", title: "Registro delle 32 corse su poddgx02"}
- {id: misura, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/24-out.txt", title: "Misura delle 31 forme, cancelli 1, 3, 4, 5, previsioni 1-5, 9, 10, 12"}
- {id: forme, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/24-forme.csv", title: "Una riga per corsa: chiusi, identici, ritrovati, firme diverse dalla base, stato dei 4 errori"}
- {id: perstudio, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/24-per-studio.csv", title: "Una riga per studio e corsa: stato, firma della tabella dei fattori, unità di disaccordo"}
- {id: letture, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/26-letture.csv", title: "La lettura di ogni scheda (studio, firma): causa, errore, descrizione (audit interno)"}
- {id: basi, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/26-errori-nelle-basi.csv", title: "Ogni errore di lettura etichettato, col suo stato nelle due basi, la descrizione e la colonna «costa»"}
- {id: diagnosi, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/27-diagnosi.csv", title: "I 58 errori di lettura: stato in ogni forma, prove, placebo, esito alla lettera e lettura severa"}
- {id: diagout, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/27-out.txt", title: "Uscita della diagnosi: conti delle letture, per forma, previsioni 6, 7, 8, 11, forma finale"}
- {id: performa, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/27-per-forma.csv", title: "Per forma: studi migliorati, peggiorati, con un errore nuovo, errori tolti"}
- {id: peggio, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/27-peggioramenti.csv", title: "I 156 peggioramenti, uno per riga, con la causa letta"}
- {id: presenti, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/29-errori-presenti-per-forma.csv", title: "Errori di lettura presenti in ogni forma, tutti e quelli che costano"}
- {id: finale, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/30-forma-finale.txt", title: "La forma finale secondo la regola"}
- {id: stabilita, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/31-out.txt", title: "Stabilità delle tabelle dei fattori sotto i placebo e fra le 31 forme (dichiarata dopo i numeri)"}
- {id: tabelle, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/32-tabelle.md", title: "Le tabelle di questo finding, generate dai CSV"}
- {id: nate, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/33-nati-per-etichetta.csv", title: "Per forma: etichette di errore tolte e nate rispetto alla base (conto per etichetta, dichiarato dopo i numeri), col conto depositato accanto"}
- {id: revisione, resource: "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/34-revisione-indipendente.md", title: "Il rapporto della revisione indipendente (subagente Claude, audit interno), con i suoi script in 34-revisione-script/"}
- {id: s12r3, resource: "docs/findings/2026-11-11-S12r3-terza-prova-lettore-studio.md", title: "La terza prova del lettore (S12r3): i 4 errori di lettura da diagnosticare"}
- {id: adr29, resource: "docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md", title: "ADR-0029 e aggiornamento del 2026-11-12"}
---

# In breve

## In breve: da dove viene ogni errore di lettura del lettore dello studio?

**A cosa serviva.** Il lettore dello studio è un solo passo del modello: legge uno studio e scrive la tabella dei suoi fattori. Nella prova precedente il lettore sbagliava la lettura in 4 studi su 47, e 3 di questi errori non c'erano con la forma dell'uscita di prima. La forma dell'uscita è fatta di due pezzi: lo schema della tabella e il testo delle istruzioni.

In questa sessione abbiamo cercato la causa di ogni errore. Abbiamo provato 31 forme dell'uscita sugli stessi 47 studi, con un solo cambio per volta fra la forma di prima e la forma di oggi. Il risultato serve a decidere se scriviamo il piano che mette il lettore nella pipeline, e con quale forma.

**Cosa abbiamo trovato.**

1. **Nessun cambio della forma toglie un errore di lettura senza farne nascere un altro.** In 24 forme su 29 il cambio toglie almeno un errore, e in tutte le 24 nasce almeno un errore nuovo in un altro studio. La forma di oggi ha 9 errori di lettura in 8 studi, e 4 di questi errori cambiano i gruppi o i confronti. Nessuna delle 13 forme a un solo cambio dalla forma di oggi ha meno di 9 errori.
2. **Il lettore cambia la tabella anche quando il cambio non dice niente.** Come controllo abbiamo riscritto una frase delle istruzioni senza cambiare il senso, in quattro corse. La tabella dei fattori cambia in 5-9 studi su 47. Due dei 4 errori spariscono con una frase riscritta, e in altri studi nascono errori nuovi: da 0 a 3 studi per corsa. Con le stesse parole, invece, due corse danno uscite uguali al carattere.
3. **Un solo errore dei 4 resta in tutte le 31 forme: le sigle dei 9 pazienti scritte come malattie (GSE46665).** Questo errore è del modello, con il testo dello studio che il modello riceve oggi. Gli altri tre errori si spostano con la forma. Il sesso scritto come fattore (GSE57945) è presente in 13 forme su 31. La colonna del trattamento non vista (GSE60340) è presente in 8 forme, il fattore doppio (GSE49155) in 14.
4. **Abbiamo letto 58 errori di lettura in 32 studi su 47. La regola scritta prima dà la causa nella forma per 14 errori e nel modello per 2. Per 42 errori non dà una causa.** Dei 14, uno solo indica un cambio che toglie un errore della forma di oggi: il sesso come fattore. Le due forme con quel cambio fanno nascere errori in 5 e in 8 studi. Negli altri 13 casi il pezzo della forma di oggi tiene lontano l'errore. Ho applicato anche una lettura più severa della regola, dichiarata dopo i numeri: i 14 scendono a 5, e nessuno dei 5 riguarda i 4 errori.
5. **La regola scritta prima dà come forma finale la forma di oggi, senza cambi.** Le due correzioni allo schema proposte nella prova precedente non entrano: una fa nascere errori in 14 studi, l'altra in 5. Due forme ritrovano più confronti dei curatori di Expression Atlas: 76 e 74 su 95, contro 68. Queste due forme fanno nascere errori in 5 e in 4 studi.

**Cosa devi decidere.**

1. **Con quale forma dell'uscita andiamo avanti? Raccomando la forma di oggi, senza cambi.** È l'esito della regola scritta prima delle corse. Le alternative:
   - La forma senza la frase che chiede di scegliere la colonna che dice il fattore per ogni campione. Questa forma chiude 47 studi su 47 e ritrova 74 confronti. Toglie 3 errori e ne fa nascere 5 in 4 studi. Conseguenza: scegliamo una forma per il numero dei confronti, e la regola scritta prima lo vieta.
   - La forma con i nomi riservati in un campo separato. Ritrova 76 confronti e fa nascere errori in 5 studi. La conseguenza è la stessa.
2. **Che cosa facciamo prima del piano? Raccomando una sessione breve che legge ogni studio più volte, con frasi riscritte senza cambiare il senso, e misura se la discordanza fra le letture segnala gli errori.** Il motivo: è la sola strada che usa la causa misurata, cioè la lettura che cambia con le parole. La regola sulla discordanza si scrive prima delle corse, e non fa il lavoro del modello. I limiti sono tre. Un calcolo fatto dopo i numeri dice che la discordanza segnala 12 studi su 47, e 7 di questi hanno gruppi giusti. Segnala 3 dei 4 studi con un errore che cambia i gruppi o i confronti, e non segnala GSE57945. Non porta a zero errori. Le alternative:
   - Scrivere il piano adesso, con la forma di oggi. Conseguenza: gli 82 studi mai aperti misurano il lettore, ma gli errori di lettura ci saranno e nessun rimedio ha un nome. Questa strada va contro la tua regola che nessun errore si accetta.
   - Una sessione che cambia il testo dello studio che il modello riceve, un cambio per volta. È il solo pezzo a monte che non abbiamo ancora cambiato. Conseguenza: su 47 studi un cambio utile si distingue male da una frase riscritta, che sposta già 5-9 studi. Sarebbe la quinta lettura degli stessi studi.
   - Un altro modello. Conseguenza: serve una tua decisione nuova. Hai scelto questo modello, e nella seconda prova il modello Mistral più grande ha fatto peggio.
   - Aprire una parte degli 82 studi solo per contare gli errori. Conseguenza: consumiamo una parte degli studi mai aperti, che servono una volta sola.
   - Dichiarare gli errori di lettura come limite. Conseguenza: va contro la tua regola. Per 44 errori su 58 la sessione non ha trovato una causa da correggere.
   - Fermare il lettore e tenere la pipeline di oggi. Conseguenza: restano 13 confronti ritrovati su 95, contro 68.

**Comunque.** Gli 82 studi mai aperti restano chiusi. Il deliverable e i master non cambiano. Il lettore non entra nella pipeline prima della tua decisione. Non scrivo il piano e non correggo le istruzioni per coprire uno studio.

Appena decidi questi 2 punti, la sessione è chiusa.

**Sui tempi di calcolo.** La stima è dell'agente. In questa sessione le 32 corse sono durate in tutto 222 minuti, cioè circa 7 minuti per corsa sui 47 studi, con 4 GPU. La sessione raccomandata chiede da 5 a 10 corse come queste, quindi circa un'ora di calcolo.

# 1. Che cosa è stato fatto

La sessione S12r4 cerca dove nasce ogni errore di lettura del lettore dello studio (ADR-0029[^adr29]). La terza
prova (S12r3[^s12r3]) aveva lasciato 13 unità di lettura del modello in 4 studi, e 3 di quei 4 errori non c'erano
con la forma dell'uscita precedente (S12r2). Le due forme differiscono per schema e per prompt.

- **Carta, prima di ogni corsa**[^carta]: 14 righe di differenze fra la forma A (S12r2: schema v1, prompt v1) e la
  forma B (S12r3: schema generato per ogni studio, prompt v2). Per ogni differenza una variante che cambia solo
  quella: `A1` ordine dei campi del fattore, `A2` una colonna per fattore, `A3` elenchi chiusi, `A4` tupla dei
  valori, `C` blocco delle colonne (`C3` la sua parte di solo schema), `P` quattro frasi del prompt (`Pa`-`Pd` una
  per volta), `P5` una frase, `R` la stesura di un paragrafo. Due correzioni di forma come varianti a sé: `F1` (via
  l'elenco `levels`), `F2` (nomi riservati in un campo a parte), `F12`. Quattro placebo: una frase del prompt
  riscritta senza cambiare il senso, due dal lato B (`B0pl1`, `B0pl2`) e due dal lato A (`A0pl1`, `A0pl2`).
- **Previsioni, regola di diagnosi, conto dell'errore nuovo e regola della forma finale** depositati prima di ogni
  corsa sui testi degli studi[^previsioni].
- **Prova di compilazione** degli schemi su `poddgx02` con un messaggio neutro: 17 classi di schema, 833 record su
  833 con un'uscita valida[^compila].
- **32 corse** su `poddgx02`: 31 forme sui 47 studi di sviluppo, più la seconda corsa della forma di partenza `B0`.
  Solo `mistralai/Mistral-Small-3.2-24B-Instruct-2506`, configurazione di produzione (`temperature` 0,
  `repetition_penalty` 1,1, `max_model_len` 65536, `max_tokens` 24576, vLLM 0.20.2, `VLLM_BATCH_INVARIANT=1`). La
  somma delle durate dei 32 job è 222 minuti[^corse]. La regola dà come forma finale `B0`: le due corse previste
  per la forma finale non servono (§6).
- **Misura** di ogni forma con le misure di S12r3 (riferimento a 95 confronti, misura su 97 accanto), più i
  predicati dei 4 errori, i due conti generici (fattori doppi, soggetto costante nei gruppi) e la firma della
  tabella dei fattori[^misura].
- **Lettura di tutti i disaccordi che cambiano**: 290 righe (studio, forma) da leggere, raccolte in 172 schede
  (studio, firma, unità, base), 156 distinte fra le due basi; lette 172, non lette 0. Due righe hanno una lettura per corsa
  (`GSE147507` in `RPc` e in `B0pl1`). Una lettura supplementare copre 28 coppie (studio, firma) senza unità di
  disaccordo, 71 celle in 13 studi, negli studi che hanno un errore etichettato[^diagout]. È audit interno: una
  sola lettura dell'agente della sessione, non cieca. La pipeline e la misura non usano Claude.
- **Diagnosi**: 58 errori di lettura etichettati in 32 studi, ognuno col suo stato in ogni forma e con l'esito
  della regola[^diagnosi].

Gli 82 studi di giudizio sono rimasti chiusi. Deliverable e master non sono stati toccati.

# 2. Cancelli

Tutti e cinque passano[^strumento][^misura].

| cancello | esito |
|---|---|
| 1. La condizione di partenza si riproduce | la prima corsa di `B0` è identica al carattere alle uscite congelate di S12r3 in 47 studi su 47; ridà 45 chiusi, 36 gruppi identici, 68 confronti su 95, le 40 unità di disaccordo e le 13 di lettura; la seconda corsa di `B0` è identica alla prima in 47 su 47. La forma finale è `B0`: le sue due corse identiche sono queste |
| 2. Lo strumento ridà i numeri congelati | con `A0` 34 chiusi, 31 identici, 50/95; con `B0` 45, 36, 68/95; 40 unità, 13 di lettura nei 4 studi (7, 1, 2, 3) |
| 3. Controllo positivo | i predicati vedono i 4 errori di lettura sulle uscite congelate e nella corsa nuova di `B0`; il conto dei soggetti costanti vede `source_name_ch1` in `GSE50760` e `GSE71595` |
| 4. Copertura | ogni corsa copre 47 studi di sviluppo su 47 e nessun altro (32 corse) |
| 5. Ambiente | 32 job su 32 `COMPLETED` su `poddgx02`, con `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` lette dal file dell'ambiente del container; modello, revisione e parametri della carta; il lavoratore usa lo schema del record in ogni record |

# 3. Le misure e le previsioni

## 3.1 Le 31 forme

Unità: lo studio. Ogni forma si confronta con la sua base (`B0` per il lato B, `A0` per il lato A). «Firme
diverse» conta gli studi in cui la tabella dei fattori (tipo, fonti, partizione e base di ogni fattore, più i
soggetti) è diversa da quella della base. «Errori presenti» conta gli errori di lettura etichettati presenti in
quella forma, e fra parentesi quelli che costano gruppi o confronti. Le ultime quattro colonne dicono se il
predicato vede l'errore di S12r3 in quello studio.

Due avvertenze sulle colonne. «Migliorati» e «peggiorati» vengono da `27-per-forma.csv`[^performa] e contano anche
gli studi che sono tutte e due le cose (da 1 a 5 per forma, in 16 forme); `24-forme.csv`[^forme] li toglie da
tutti e due i conti. «Studi con un errore nuovo» è il **conto depositato**: conta solo gli studi peggiorati la cui
scheda ha causa «lettura del modello». Il conto per etichetta, più largo, sta in §5.2.

| forma | cambi | base | chiusi | identici | ritrovati su 95 | firme diverse dalla base | migliorati | peggiorati | studi con un errore nuovo (stretto) | errori presenti (che costano) | GSE57945 | GSE60340 | GSE49155 | GSE46665 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `B0` | nessuno | B0 | 45 | 36 | 68 | - | - | - | - | 9 (4) | sì | sì | sì | sì |
| `RP` | P | B0 | 44 | 37 | 64 | 21 | 6 | 9 | 8 (8) | 20 (6) | no | no | sì | sì |
| `RPa` | Pa | B0 | 47 | 38 | 74 | 13 | 5 | 3 | 3 (3) | 11 (4) | no | no | sì | sì |
| `RPb` | Pb | B0 | 44 | 37 | 66 | 19 | 6 | 8 | 7 (7) | 16 (7) | sì | no | sì | sì |
| `RPc` | Pc | B0 | 42 | 36 | 66 | 16 | 6 | 6 | 2 (2) | 10 (5) | sì | sì | no | sì |
| `RPd` | Pd | B0 | 44 | 37 | 64 | 15 | 5 | 4 | 4 (4) | 15 (8) | sì | no | sì | sì |
| `RP5` | P5 | B0 | 44 | 36 | 68 | 11 | 4 | 3 | 2 (2) | 13 (7) | sì | no | sì | sì |
| `RC` | C | B0 | 45 | 37 | 70 | 16 | 6 | 4 | 2 (2) | 12 (6) | no | no | sì | sì |
| `RC3` | C3 | B0 | 45 | 36 | 68 | 0 | 0 | 0 | 0 (0) | 9 (4) | sì | sì | sì | sì |
| `RA1` | A1 | B0 | 44 | 36 | 71 | 21 | 9 | 6 | 2 (2) | 13 (5) | no | no | no | sì |
| `RA4` | A4 | B0 | 41 | 33 | 64 | 7 | 0 | 4 | 1 (0) | 12 (6) | sì | sì | sì | sì |
| `RA4A3` | A4+A3 | B0 | 40 | 32 | 59 | 8 | 0 | 5 | 0 (0) | 11 (5) | sì | sì | sì | sì |
| `RR` | R | B0 | 45 | 36 | 69 | 17 | 6 | 3 | 3 (3) | 10 (6) | no | sì | sì | sì |
| `RA1P` | A1+P | B0 | 45 | 38 | 71 | 21 | 7 | 5 | 4 (4) | 15 (3) | no | no | no | sì |
| `RA1PP5` | A1+P+P5 | B0 | 44 | 36 | 64 | 25 | 8 | 9 | 9 (9) | 21 (9) | no | no | no | sì |
| `RA1PP5C` | A1+P+P5+C | B0 | 45 | 37 | 66 | 22 | 7 | 5 | 4 (4) | 18 (6) | no | no | no | sì |
| `F1` | F1 | B0 | 38 | 32 | 59 | 23 | 7 | 14 | 11 (11) | 19 (11) | no | no | no | sì |
| `F2` | F2 | B0 | 45 | 35 | 76 | 15 | 6 | 4 | 3 (3) | 12 (7) | no | sì | sì | sì |
| `F12` | F1+F2 | B0 | 36 | 32 | 57 | 24 | 8 | 15 | 10 (10) | 21 (14) | no | no | no | sì |
| `B0pl1` | pl1 | B0 | 45 | 36 | 71 | 9 | 4 | 2 | 2 (1) | 10 (4) | sì | sì | no | sì |
| `B0pl2` | pl2 | B0 | 42 | 35 | 69 | 6 | 3 | 3 | 1 (1) | 8 (4) | sì | no | sì | sì |
| `A0` | nessuno | A0 | 34 | 31 | 50 | - | - | - | - | 11 (4) | no | no | no | sì |
| `A0C` | aC | A0 | 34 | 31 | 52 | 15 | 4 | 6 | 4 (3) | 14 (5) | sì | no | no | sì |
| `A0A1` | aA1 | A0 | 32 | 28 | 49 | 16 | 3 | 7 | 4 (4) | 15 (8) | sì | no | sì | sì |
| `A0A3` | aA3 | A0 | 35 | 32 | 51 | 3 | 1 | 0 | 0 (0) | 11 (4) | no | no | no | sì |
| `A0A2` | aA2 | A0 | 36 | 31 | 53 | 18 | 4 | 7 | 6 (5) | 18 (8) | no | no | no | sì |
| `A0A2A3` | aA2+aA3 | A0 | 39 | 34 | 57 | 20 | 6 | 6 | 6 (5) | 19 (7) | no | no | no | sì |
| `A0A2A3A4` | aA2+aA3+aA4 | A0 | 45 | 37 | 61 | 22 | 11 | 9 | 6 (5) | 19 (9) | no | no | no | sì |
| `A0A2A3A4R` | aA2+aA3+aA4+aR | A0 | 45 | 37 | 66 | 20 | 12 | 7 | 4 (3) | 18 (6) | no | no | no | sì |
| `A0pl1` | pl1 | A0 | 35 | 32 | 52 | 8 | 2 | 1 | 1 (1) | 12 (6) | sì | no | no | sì |
| `A0pl2` | pl2 | A0 | 36 | 32 | 54 | 5 | 2 | 1 | 0 (0) | 11 (4) | no | no | no | sì |

| forma | ritrovati su 97 | ritrovati meno la base (IC 95%) | uscite non finite | fattori doppi | studi con un soggetto costante nei gruppi |
|---|---|---|---|---|---|
| `B0` | 68 | 0 (0, 0) | 0 | 5 | 3 |
| `RP` | 64 | -4 (-15, 5) | 0 | 6 | 8 |
| `RPa` | 74 | 6 (0, 18) | 0 | 4 | 5 |
| `RPb` | 66 | -2 (-16, 8,025) | 0 | 3 | 7 |
| `RPc` | 66 | -2 (-16, 8) | 0 | 6 | 2 |
| `RPd` | 64 | -4 (-16,025, 3) | 0 | 6 | 2 |
| `RP5` | 68 | 0 (-3, 3) | 0 | 5 | 3 |
| `RC` | 70 | 2 (-13, 17) | 0 | 5 | 3 |
| `RC3` | 68 | 0 (0, 0) | 0 | 5 | 3 |
| `RA1` | 71 | 3 (-5, 12) | 0 | 5 | 4 |
| `RA4` | 64 | -4 (-10, 0) | 1 | 5 | 3 |
| `RA4A3` | 59 | -9 (-19, -1) | 0 | 5 | 3 |
| `RR` | 69 | 1 (-14, 16) | 0 | 5 | 1 |
| `RA1P` | 71 | 3 (-4, 11) | 0 | 6 | 5 |
| `RA1PP5` | 64 | -4 (-17, 7) | 0 | 7 | 7 |
| `RA1PP5C` | 66 | -2 (-15, 8) | 0 | 5 | 5 |
| `F1` | 59 | -9 (-23, 3) | 0 | 4 | 4 |
| `F2` | 76 | 8 (0, 21) | 0 | 5 | 3 |
| `F12` | 57 | -11 (-29, 3) | 0 | 4 | 4 |
| `B0pl1` | 71 | 3 (-1, 8) | 0 | 4 | 3 |
| `B0pl2` | 69 | 1 (0, 3) | 0 | 5 | 2 |
| `A0` | 50 | 0 (0, 0) | 0 | 3 | 3 |
| `A0C` | 52 | 2 (-2, 7) | 0 | 4 | 4 |
| `A0A1` | 49 | -1 (-7, 5) | 0 | 4 | 4 |
| `A0A3` | 51 | 1 (0, 3) | 1 | 3 | 3 |
| `A0A2` | 53 | 3 (-5, 12) | 0 | 6 | 5 |
| `A0A2A3` | 57 | 7 (-3, 18) | 1 | 6 | 5 |
| `A0A2A3A4` | 61 | 11 (-2, 26) | 0 | 8 | 5 |
| `A0A2A3A4R` | 66 | 16 (5, 30) | 0 | 5 | 5 |
| `A0pl1` | 52 | 2 (0, 6) | 0 | 4 | 3 |
| `A0pl2` | 54 | 4 (0, 12) | 0 | 3 | 4 |

Che cosa dice la tabella:

- **Nessuna forma a un cambio da `B0` ha meno errori di lettura presenti di `B0`** (9, di cui 4 che costano),
  tranne il placebo `B0pl2` (8, di cui 4 che costano). `RC3` ne ha 9: cambia solo lo schema di un blocco scritto
  dopo i fattori e ridà gli stessi fattori (previsione 2).
- **Due forme ritrovano più confronti di `B0`** con un intervallo che ha lo zero come estremo: `F2` 76 (+8; 0, +21),
  `RPa` 74 (+6; 0, +18). `RPa` chiude 47 studi su 47. Tutte e due hanno 3 studi con un errore nuovo di lettura
  col conto depositato; per etichetta `F2` ne ha 5 e `RPa` 4 (§5.2). Il
  placebo `B0pl1` ne ritrova 71 (+3; −1, +8). La regola depositata vieta di scegliere una forma per il numero dei
  confronti.
- **Dal lato A** la catena dei quattro cambi di schema (`aA2`, `aA3`, `aA4`, `aR`) porta gli studi chiusi da 34 a
  45 e i confronti da 50 a 66 (+16; +5, +30): la chiusura viene dalla tupla dei valori (`aA4`: da 39 a 45).
- **Il ponte**: `A0A2A3A4R` e `RA1PP5C`, costruite dai due lati con lo stesso prompt e lo stesso schema, danno
  uscite identiche al carattere in 47 studi su 47 (previsione 3). L'elenco delle differenze è completo.

## 3.2 Le previsioni con l'esito

Ricampionamento per studio, appaiato fra forma e base, B = 2.000, seme 20261112. Le previsioni sono 12; alcune
hanno più righe. Esiti delle 18 righe: 13 confermate, 4 smentite, 1 indeterminata.

| n. | quantità | atteso | intervallo | osservato | esito | accanto |
|---|---|---|---|---|---|---|
| 1 | A0 identica al carattere a M-corsa1.jsonl di S12r2 | 47/47 | 47 | 47/47 | confermata | diversi:  |
| 2 | RC3: blocco `factors` identico a quello di B0 (al carattere) | 47/47 | 47 | 47/47 | confermata | letto come JSON: 47/47; diversi:  |
| 3 | il ponte: A0A2A3A4R identica al carattere a RA1PP5C | 47/47 | 47 | 47/47 | confermata | diversi:  |
| 4 | B0pl1: studi con la firma diversa dalla base | 5/47 | 0-12 | 9/47 | confermata | ricampionamento sugli studi, IC 95%: 4-14; uscite uguali al carattere 15/47; firme non valutabili 0; migliorati 4, peggiorati 2 |
| 4 | B0pl2: studi con la firma diversa dalla base | 5/47 | 0-12 | 6/47 | confermata | ricampionamento sugli studi, IC 95%: 2-11; uscite uguali al carattere 23/47; firme non valutabili 0; migliorati 3, peggiorati 3 |
| 4 | A0pl1: studi con la firma diversa dalla base | 5/47 | 0-12 | 8/47 | confermata | ricampionamento sugli studi, IC 95%: 3.975-14; uscite uguali al carattere 19/47; firme non valutabili 0; migliorati 2, peggiorati 1 |
| 4 | A0pl2: studi con la firma diversa dalla base | 5/47 | 0-12 | 5/47 | confermata | ricampionamento sugli studi, IC 95%: 1-9; uscite uguali al carattere 19/47; firme non valutabili 0; migliorati 2, peggiorati 1 |
| 5 | i 4 errori di lettura sotto i due placebo di B0 (8 stati) | 8 presenti | 7-8 | 6 presenti, 2 assenti, 0 non valutabili | smentita | GSE49155 in B0pl1: assente; GSE60340 in B0pl2: assente |
| 6 | GSE46665: esito della regola | del modello | - | del modello | confermata |  |
| 7 | GSE60340: esito della regola | della forma (A1) | - | non deciso: instabile col placebo | smentita |  |
| 7 | GSE49155: esito della regola | della forma (A1) | - | non deciso: instabile col placebo | smentita |  |
| 8 | i 3 errori assenti con la forma A: quanti hanno esito «della forma» | 2 | 1-3 | 1 | confermata |  |
| 9a | F12: studi chiusi | 47 | 46-47 | 36 (IC 95% 30-41) | smentita | non chiusi: GSE103501 GSE44379 GSE52778 GSE56691 GSE57945 GSE58365 GSE63816 GSE65335 GSE67812 GSE69597 GSE83415 |
| 9b | F12: confronti ritrovati meno quelli di B0 | +3 (71/95) | 0 - +6 | -11 (57/95; IC 95% -29 3) | indeterminata |  |
| 10a | F1 chiude GSE50499 | si' | - | si' (identica) | confermata |  |
| 10b | F2 chiude GSE63816 | si' | - | si' (diversa) | confermata |  |
| 11 | studi con un errore nuovo per forma a un cambio da B0: mediana fra 13 forme | 2 | 0-5 | 3 | confermata | RP 8, RPa 3, RPb 7, RPc 2, RPd 4, RP5 2, RC 2, RC3 0, RA1 2, RA4 1, RR 3, F1 11, F2 3; col conto stretto mediana 3 |
| 12 | RA4 (senza la tupla dei valori): studi chiusi | 39 | 35-43 | 41 | confermata | ricampionamento sugli studi, IC 95%: 36-45; motivi dei non chiusi: base_assente 1, livello_assente 1, mappa_ambigua 2, non_coperta 3, non_valida 1, ruolo_incoerente 1, troncata 1 |

esiti: {'confermata': 13, 'smentita': 4, 'indeterminata': 1}

## 3.3 I dubbi aperti dalle previsioni, e come sono chiusi

1. **Previsione 5, smentita: spiegata, ed è un risultato.** Mi aspettavo i 4 errori presenti sotto tutti e due i
   placebo di `B0`. `GSE49155` è assente in `B0pl1` e `GSE60340` è assente in `B0pl2`. Una frase riscritta senza
   cambiare il senso basta a togliere 2 dei 4 errori (uno per placebo). §5 dà la misura intera.
2. **Previsione 7, smentita per i due studi: spiegata, stessa causa.** Avevo scritto «della forma (A1)» per
   `GSE60340` e `GSE49155`. La forma senza A1 (`RA1`) li toglie tutti e due, ma li toglie anche un placebo: la
   regola dà «non deciso: instabile col placebo». Il cambio dell'ordine dei campi non si distingue da un cambio di
   parole senza significato.
3. **Previsione 9a, smentita: spiegata con la lettura.** `F12` chiude 36 studi e non 47 (IC 95% 30-41). La
   previsione veniva dal calcolo fatto dopo i numeri in S12r3, che cambiava solo la regola di chiusura sulle uscite
   già scritte. Con lo schema senza l'elenco `levels` il modello scrive un'altra uscita: in 4 studi scrive come
   base il valore della colonna al posto del nome del livello (`GSE103501`, `GSE44379`, `GSE57945`, `GSE65335`:
   causa «forma»), e in `F1` nascono errori di lettura in 11 studi (§5.2). Il calcolo dopo i numeri di S12r3 non
   era una misura, come dichiarato allora.
4. **Previsione 9b, indeterminata: non tocca una conclusione.** `F12` ritrova 57 confronti su 95, 11 meno di `B0`
   (IC 95% −29, +3): l'intervallo sta a cavallo dell'estremo inferiore (0). La conclusione «le due correzioni di
   forma non entrano» non viene da questo numero: viene dalla regola della forma finale, che conta gli studi con
   un errore nuovo di lettura (`F1` 11, `F2` 3).
5. **Previsione 8, confermata alla lettera, fuori dall'intervallo con la lettura severa: dichiarato.** L'unico dei
   3 errori con esito «della forma» è `GSE57945` (il sesso come fattore). Con la lettura severa (§4.4) il conto è
   0, sotto l'intervallo 1-3. L'esito depositato resta «confermata», perché la regola si applica alla lettera; la
   conclusione del finding usa il numero severo («nessuno dei 4 errori ha una causa nella forma», §4.4).
6. **Previsione 11, confermata con tutti e due i conti, col conto per etichetta sull'estremo.** Col conto
   depositato la mediana è 3. Col conto per etichetta (§5.2, rilievo R1 della revisione) è 5, l'estremo superiore
   dell'intervallo 0-5.

# 4. La diagnosi

## 4.1 La regola e i conti

La regola depositata[^previsioni] chiede due prove per la stessa differenza D: la forma che toglie solo D da una
base cambia lo stato dell'errore, e la forma che mette solo D sull'altra base lo cambia nel verso opposto. In più
lo stato non deve cambiare sotto i due placebo della base in cui l'errore è presente. «Del modello»: l'errore è
presente in ogni forma valutabile e nelle due basi. Ogni altro caso è «non deciso», con una sotto-etichetta.

Gli errori di lettura etichettati sono 58, in 32 studi su 47; 35 costano gruppi o confronti (colonna «costa», §8).
Ci sono i 4 errori di S12r3, le letture del modello che in `B0` e `A0` non costano confronti, e ogni errore nuovo
nato in una forma.

| esito | alla lettera | lettura severa (dichiarata dopo i numeri) |
|---|---|---|
| della forma | 14 (6 che costano) | 5 (1 che costa) |
| del modello | 2 (1 che costa) | 2 (1 che costa) |
| non deciso: instabile col placebo | 9 | 11 |
| non deciso: più cambi, nessuna prova doppia | 20 | 27 |
| non deciso: una direzione sola | 6 | 6 |
| non deciso: nessuna coppia a un cambio lo sposta | 7 | 7 |
| totale | 58 | 58 |

| errore | costa | in B0 | in A0 | presente / assente / non valutabile (su 31 forme) | esito alla lettera | lettura severa | verso delle prove doppie |
|---|---|---|---|---|---|---|---|
| GSE57945:sesso come fattore | si | presente | assente | 13 / 18 / 0 | della forma (C, A1) | non deciso: instabile col placebo | appare con D A1; appare con D C |
| GSE60340:colonna del trattamento non vista | si | presente | assente | 8 / 23 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | appare con D A1 |
| GSE49155:fattore doppio | si | presente | assente | 14 / 17 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | appare con D A1 |
| GSE46665:sigle dei pazienti come malattie | si | presente | presente | 31 / 0 / 0 | del modello | del modello | - |
| GSE112057:NA di gender non dichiarato mancante | si | assente | presente | 12 / 19 / 0 | della forma (C) | della forma (C) | sparisce con D C |
| GSE112057:sottotipo JIA come secondo fattore | si | assente | assente | 8 / 23 / 0 | non deciso: più cambi, nessuna prova doppia (Pb, A1, A4, P5) | non deciso: più cambi, nessuna prova doppia (Pb, A1, A4, P5) | - |
| GSE147507:ceppo dei controlli scritto come non dichiarato | si | assente | assente | 4 / 24 / 3 | della forma (A1) | non deciso: più cambi, nessuna prova doppia (A1, C, P) | sparisce con D A1 |
| GSE147507:controlli senza livello (ruxolitinib, strain) | si | assente | assente | 2 / 26 / 3 | non deciso: più cambi, nessuna prova doppia (P, C, P5) | non deciso: più cambi, nessuna prova doppia (P, C, P5) | - |
| GSE41586:due dosi unite in un livello | si | assente | assente | 1 / 30 / 0 | non deciso: nessuna coppia a un cambio lo sposta | non deciso: nessuna coppia a un cambio lo sposta | - |
| GSE46665:tempo ripetuto come secondo fattore | no | presente | assente | 8 / 23 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | appare con D A1 |
| GSE47718:source_name_ch1 come donatore | no | assente | presente | 22 / 9 / 0 | della forma (A1) | non deciso: più cambi, nessuna prova doppia (P, Pa, Pb, P5, C, A1) | sparisce con D A1 |
| GSE49155:tessuto come fattore con un livello inventato | si | assente | assente | 2 / 29 / 0 | non deciso: più cambi, nessuna prova doppia (A2, A4) | non deciso: più cambi, nessuna prova doppia (A2, A4) | - |
| GSE49608:source_name_ch1 come donatore | no | assente | assente | 4 / 27 / 0 | non deciso: più cambi, nessuna prova doppia (P, Pa, Pb, C, P5) | non deciso: più cambi, nessuna prova doppia (P, Pa, Pb, C, P5) | - |
| GSE50499:lo stesso fattore scritto due volte | si | assente | assente | 4 / 27 / 0 | non deciso: più cambi, nessuna prova doppia (A2, R, C, P5) | non deciso: più cambi, nessuna prova doppia (A2, R, C, P5) | - |
| GSE50760:source_name_ch1 come donatore | no | presente | presente | 30 / 1 / 0 | non deciso: una direzione sola (R) | non deciso: una direzione sola (R) | - |
| GSE50760:tessuto come contesto senza base | si | assente | presente | 21 / 10 / 0 | della forma (A1) | non deciso: più cambi, nessuna prova doppia (P, Pc, Pd, P5, C, A1) | sparisce con D A1 |
| GSE52194:source_name_ch1 come donatore | no | assente | presente | 12 / 19 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | - |
| GSE52778:donatore come fattore di contesto | si | assente | assente | 3 / 28 / 0 | non deciso: più cambi, nessuna prova doppia (A4, R) | non deciso: più cambi, nessuna prova doppia (A4, R) | - |
| GSE53280:controllo mock senza livello | si | assente | assente | 4 / 27 / 0 | non deciso: più cambi, nessuna prova doppia (Pb, Pd, R) | non deciso: più cambi, nessuna prova doppia (Pb, Pd, R) | - |
| GSE56691:controllo non trattato senza livello | si | assente | assente | 6 / 25 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | - |
| GSE56691:tempo ripetuto come secondo fattore | no | assente | assente | 8 / 23 / 0 | della forma (P) | della forma (P) | sparisce con D P |
| GSE56787:fattore DUX4 inventato | no | assente | presente | 6 / 25 / 0 | non deciso: più cambi, nessuna prova doppia (C, A1, A4) | non deciso: più cambi, nessuna prova doppia (C, A1, A4) | - |
| GSE56787:tipo di campione non letto | si | assente | assente | 2 / 29 / 0 | non deciso: nessuna coppia a un cambio lo sposta | non deciso: nessuna coppia a un cambio lo sposta | - |
| GSE57116:tempo ripetuto come secondo fattore | no | assente | presente | 22 / 9 / 0 | della forma (A1) | non deciso: più cambi, nessuna prova doppia (P, Pc, Pd, A1, A4, R) | sparisce con D A1 |
| GSE57945:NA come livello di base | no | assente | assente | 2 / 29 / 0 | non deciso: più cambi, nessuna prova doppia (A2, A4) | non deciso: più cambi, nessuna prova doppia (A2, A4) | - |
| GSE57945:NA scritto come Not IBD | si | assente | assente | 1 / 30 / 0 | non deciso: nessuna coppia a un cambio lo sposta | non deciso: nessuna coppia a un cambio lo sposta | - |
| GSE57945:eta' come fattore di contesto | no | assente | assente | 2 / 29 / 0 | non deciso: più cambi, nessuna prova doppia (Pd, A1) | non deciso: più cambi, nessuna prova doppia (Pd, A1) | - |
| GSE57945:l2 type come secondo fattore di malattia | si | assente | assente | 10 / 21 / 0 | della forma (A1) | non deciso: più cambi, nessuna prova doppia (P, A1, A2) | sparisce con D A1 |
| GSE58365:base che non e' un livello | si | assente | assente | 2 / 29 / 0 | non deciso: nessuna coppia a un cambio lo sposta | non deciso: nessuna coppia a un cambio lo sposta | - |
| GSE58365:base non scritta | si | assente | assente | 1 / 30 / 0 | non deciso: una direzione sola (P5) | non deciso: una direzione sola (P5) | - |
| GSE60340:base non scritta | si | assente | assente | 3 / 28 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | - |
| GSE60340:immortali come non applicabile | no | assente | assente | 4 / 27 / 0 | della forma (P) | della forma (P) | sparisce con D P |
| GSE60340:nessun trattamento diviso in tre livelli | si | assente | assente | 2 / 29 / 0 | non deciso: più cambi, nessuna prova doppia (A4, R, C, P5) | non deciso: più cambi, nessuna prova doppia (A4, R, C, P5) | - |
| GSE60340:passaggio come fattore | si | assente | assente | 3 / 28 / 0 | non deciso: una direzione sola (R) | non deciso: una direzione sola (R) | - |
| GSE60585:tipo di RNA non letto | si | assente | assente | 1 / 30 / 0 | non deciso: più cambi, nessuna prova doppia (C, P5) | non deciso: più cambi, nessuna prova doppia (C, P5) | - |
| GSE63816:MDS scritta come non dichiarata | si | assente | presente | 7 / 24 / 0 | della forma (A1) | non deciso: più cambi, nessuna prova doppia (A1, A2, P) | sparisce con D A1 |
| GSE63816:genotipo ZRSR2 non letto | si | assente | assente | 9 / 22 / 0 | non deciso: più cambi, nessuna prova doppia (Pa, Pb, Pd, P5, C, A4) | non deciso: più cambi, nessuna prova doppia (Pa, Pb, Pd, P5, C, A4) | - |
| GSE63816:genotipo e shRNA in un fattore solo | no | assente | assente | 7 / 24 / 0 | della forma (P) | della forma (P) | sparisce con D P |
| GSE63816:shRNA letto da source_name_ch1 | si | assente | assente | 5 / 26 / 0 | non deciso: più cambi, nessuna prova doppia (Pa, Pd, P5, C, A4, A3) | non deciso: più cambi, nessuna prova doppia (Pa, Pd, P5, C, A4, A3) | - |
| GSE63816:shRNA non letto | si | assente | assente | 2 / 29 / 0 | non deciso: più cambi, nessuna prova doppia (A2, A3) | non deciso: più cambi, nessuna prova doppia (A2, A3) | - |
| GSE63816:source_name_ch1 come donatore | no | assente | assente | 5 / 26 / 0 | della forma (P) | della forma (P) | sparisce con D P |
| GSE65335:source_name_ch1 come donatore | si | assente | assente | 2 / 29 / 0 | non deciso: più cambi, nessuna prova doppia (P, Pb) | non deciso: più cambi, nessuna prova doppia (P, Pb) | - |
| GSE66207:classificazione di Montreal come fattore | si | assente | assente | 1 / 30 / 0 | non deciso: più cambi, nessuna prova doppia (C, P5) | non deciso: più cambi, nessuna prova doppia (C, P5) | - |
| GSE66573:source_name_ch1 come donatore | no | presente | assente | 21 / 10 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | - |
| GSE67812:controlli scritti come DM1 | no | assente | assente | 18 / 13 / 0 | della forma (A1) | non deciso: instabile col placebo | sparisce con D A1 |
| GSE68919:controllo PBS senza livello | si | assente | assente | 1 / 30 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | - |
| GSE69597:paese come fattore | si | assente | assente | 2 / 29 / 0 | non deciso: più cambi, nessuna prova doppia (Pd, R) | non deciso: più cambi, nessuna prova doppia (Pd, R) | - |
| GSE69597:source_name_ch1 come donatore | no | assente | assente | 3 / 28 / 0 | non deciso: più cambi, nessuna prova doppia (C, P) | non deciso: più cambi, nessuna prova doppia (C, P) | - |
| GSE69597:stadio che mescola storia e risposta | si | assente | assente | 3 / 28 / 0 | non deciso: più cambi, nessuna prova doppia (A2, A4) | non deciso: più cambi, nessuna prova doppia (A2, A4) | - |
| GSE71289:source_name_ch1 come donatore | no | assente | assente | 1 / 30 / 0 | non deciso: una direzione sola (P) | non deciso: una direzione sola (P) | - |
| GSE71595:source_name_ch1 come donatore | no | presente | presente | 30 / 1 / 0 | non deciso: una direzione sola (Pd) | non deciso: una direzione sola (Pd) | - |
| GSE75852:tempo che ripete il tipo cellulare | no | presente | presente | 31 / 0 / 0 | del modello | del modello | - |
| GSE83415:base che non e' un livello | si | assente | assente | 1 / 30 / 0 | non deciso: nessuna coppia a un cambio lo sposta | non deciso: nessuna coppia a un cambio lo sposta | - |
| GSE83415:base non scritta | si | assente | assente | 1 / 30 / 0 | non deciso: nessuna coppia a un cambio lo sposta | non deciso: nessuna coppia a un cambio lo sposta | - |
| GSE83687:ileo come non applicabile | no | assente | assente | 2 / 29 / 0 | non deciso: instabile col placebo | non deciso: instabile col placebo | - |
| GSE83687:sede del prelievo scritta come non dichiarata | no | assente | assente | 1 / 30 / 0 | della forma (A1) | non deciso: più cambi, nessuna prova doppia (A1, P) | sparisce con D A1 |
| GSE83687:source_name_ch1 come donatore | no | assente | assente | 1 / 30 / 0 | non deciso: una direzione sola (Pb) | non deciso: una direzione sola (Pb) | - |
| GSE93624:base della complicazione non scritta | no | assente | assente | 1 / 30 / 0 | non deciso: nessuna coppia a un cambio lo sposta | non deciso: nessuna coppia a un cambio lo sposta | - |

## 4.2 I 4 errori di S12r3, uno per uno

| errore | presente in | esito alla lettera | lettura severa | che cosa lo sposta |
|---|---|---|---|---|
| `GSE46665`: le sigle dei 9 pazienti scritte come malattie | 31 forme su 31 | **del modello** | del modello | niente |
| `GSE57945`: il sesso scritto come fattore | 13 su 31 | **della forma (C, A1)** | non deciso: instabile col placebo | lo tolgono da `B0` le forme senza `C`, `A1`, `P`, `Pa`, `R`, e le forme con `F1` e con `F2`; lo mettono su `A0` le forme con `C` e con `A1`; lo mette su `A0` anche il placebo `A0pl1` |
| `GSE60340`: la colonna del trattamento non vista | 8 su 31 | **non deciso: instabile col placebo** | lo stesso | lo tolgono da `B0` le forme senza `P`, `Pa`, `Pb`, `Pd`, `P5`, `C`, `A1`, la forma con `F1`, e il placebo `B0pl2` |
| `GSE49155`: il fattore doppio | 14 su 31 | **non deciso: instabile col placebo** | lo stesso | lo tolgono da `B0` le forme senza `Pc` e senza `A1`, la forma con `F1`, e il placebo `B0pl1`; lo mette su `A0` la forma con `A1` |

Le due unità di lettura di S12r2 (presenti con la forma A, sparite con la forma B):

- `GSE57116`, il tempo ripetuto come secondo fattore: presente in 22 forme su 31. Alla lettera «della forma (A1)»,
  con la lettura severa «non deciso: più cambi».
- `GSE75852`, il tempo che ripete il tipo cellulare: presente in 31 forme su 31, «del modello». Non costa
  confronti. Il predicato di S12r2 lo contava sparito con la forma B perché non costava più confronti: la lettura
  delle schede lo trova in tutte le forme.

## 4.3 Il verso delle prove doppie

Dei 14 esiti «della forma», **uno solo dice che togliere una differenza da `B0` toglie un errore**: `GSE57945`,
il sesso come fattore (appare con `C` e con `A1`). Negli altri 13 l'errore **sparisce** con la differenza: è
assente in `B0` e presente nella forma che toglie la differenza. Per questi 13 la differenza della forma B
protegge dall'errore, e toglierla lo fa comparire:

- `P` (4 errori: `GSE56691` tempo ripetuto, `GSE60340` immortali come non applicabile, `GSE63816` genotipo e shRNA
  in un fattore solo, `GSE63816` `source_name_ch1` come donatore);
- `C` (1 errore: `GSE112057`, il valore NA di `gender` non dichiarato mancante);
- `A1` (8 errori, per esempio `GSE47718` e `GSE57116`).

Quindi lo script nomina `C`, `A1` e `P` come differenze «candidate», ma solo per `C` e `A1` c'è un errore di `B0`
che il cambio toglie, ed è lo stesso errore (`GSE57945`). `P` non è una candidata da togliere: è una parte della
forma B che tiene lontani 4 errori.

## 4.4 Due limiti della regola depositata, e la lettura severa

La regola si applica alla lettera: è stata depositata prima dei numeri e non si cambia. Due sue proprietà rendono
l'esito «della forma» più largo di quello che la prova sostiene. Le dichiaro, e riporto accanto una lettura severa
decisa dopo i numeri (colonna `esito_severo`), che non sostituisce l'esito.

1. **Per `A1` la stessa coppia di forme conta due volte.** La coppia (`RA1`, `B0`) è la prova «toglie» dal lato B
   ed è anche l'ultimo passo della catena da `A0` a `B0`, che la regola ammette come prova «mette». Otto errori
   hanno esito «della forma (A1)» per questa sola coppia. La lettura severa chiede due coppie diverse.
2. **Il placebo si guarda solo nella base in cui l'errore è presente.** `GSE57945` è presente in `B0` e nei suoi
   due placebo, ma dal lato A basta il placebo `A0pl1` a farlo comparire: la prova «mette» di `A0C` e `A0A1` non si
   distingue da un cambio di parole senza significato. La lettura severa chiede lo stato stabile sotto tutti e
   quattro i placebo.

Con la lettura severa gli esiti «della forma» sono 5, tutti del tipo «la differenza protegge» (`C` per
`GSE112057`, `P` per 4 errori), e nessuno dei 4 errori di S12r3 ha una causa nella forma.

La revisione indipendente (§13, rilievo R4) ha trovato una terza scelta di lettura, che non avevo dichiarato:

3. **La regola è applicata anche agli errori assenti in tutte e due le basi.** Il testo depositato definisce le due
   prove «per un errore che c'è in `B0` e non in `A0`» e per il caso inverso. Il codice le applica a tutti i 58
   errori. Con il solo vincolo «presente in una base e assente nell'altra» gli esiti «della forma» sono 6 e non
   14. Insieme alla lettura severa ne resta 1 su 58: `GSE112057`, il valore NA di `gender` (`C` protegge).

Il testo depositato è anche ambiguo sul placebo: la definizione di «della forma» nomina «i due placebo della base
in cui E è presente», la sotto-etichetta di «non deciso» dice «lo stato cambia sotto un placebo» senza nominare la
base. Il codice usa la prima per l'esito e la seconda per la lettura severa.

Quindi il numero degli esiti «della forma» va da 14 a 1 secondo la lettura. Con ogni lettura la forma finale è
`B0` (§6), e l'errore di `GSE46665` è «del modello».

# 5. Gli errori nuovi, e quanto si sposta il lettore per un cambio che non dice niente

## 5.1 I placebo

| placebo | studi con la tabella dei fattori diversa dalla base | uscite uguali al carattere a quelle della base | studi migliorati | studi peggiorati | studi con un errore nuovo di lettura, conto depositato (stretto) | studi con un'etichetta di errore nata (§5.2) |
|---|---|---|---|---|---|---|
| `B0pl1` | 9 su 47 (IC 95% 4-14) | 15 su 47 | 4 | 2 | 2 (1) | 3 |
| `B0pl2` | 6 su 47 (2-11) | 23 su 47 | 3 | 3 | 1 (1) | 1 |
| `A0pl1` | 8 su 47 (4-14) | 19 su 47 | 2 | 1 | 1 (1) | 2 |
| `A0pl2` | 5 su 47 (1-9) | 19 su 47 | 2 | 1 | 0 (0) | 0 |

Una frase del prompt riscritta senza cambiare il senso («You receive one GEO series:» → «You are given one GEO
series:»; «Use an empty array if there are none.» → «If there are none, use an empty array.») cambia la tabella dei
fattori in 5-9 studi su 47, toglie 2 dei 4 errori di S12r3 (uno per placebo, §3.3) e fa nascere un errore di
lettura in 0-2 studi col conto depositato, in 0-3 col conto per etichetta. Con la stessa forma due corse sono identiche al carattere (cancello 1): il lettore è
ripetibile, e non è stabile rispetto alle parole.

## 5.2 Gli errori nuovi per forma

Un peggioramento è definito dai sei criteri depositati; ogni peggioramento è stato letto. I peggioramenti sono
156: causa «lettura del modello» 109 (errore nuovo), «forma» 33, «non errore» 14[^peggio]. Sette dei 109 sono un
effetto nuovo di un errore che la base ha già (per esempio `GSE46665` nelle forme del lato A): il conto «stretto»
li toglie e dà 102. Gli studi con almeno un errore nuovo in almeno una forma sono 27 su 47.

**Due conti.** Il conto depositato (§4 delle previsioni) vede solo gli studi peggiorati: un errore di lettura che
nasce in uno studio non peggiorato non si conta. Per esempio in `RC` i tre controlli di `GSE67812` vanno al
livello `dm1`, ma lo studio resta «identico» (i curatori hanno un gruppo solo) e il conto depositato non lo vede.
La revisione indipendente lo ha rilevato (§13, R1). Accanto riporto il **conto per etichetta**, dichiarato dopo i
numeri[^nate]: un'etichetta è «nata» se l'errore è presente nella forma e non nella base, «tolta» se è presente
nella base e assente nella forma. Il conto depositato resta quello che decide gli esiti; il conto per etichetta
non ne cambia nessuno.

| forma | base | etichette tolte | etichette nate (che costano) | studi con un'etichetta nata | studi con un errore nuovo, conto depositato (stretto) |
|---|---|---|---|---|---|
| `RP` | B0 | 3 | 14 (4) | 13 | 8 (8) |
| `RPa` | B0 | 3 | 5 (2) | 4 | 3 (3) |
| `RPb` | B0 | 2 | 9 (4) | 9 | 7 (7) |
| `RPc` | B0 | 3 | 4 (2) | 4 | 2 (2) |
| `RPd` | B0 | 2 | 8 (5) | 7 | 4 (4) |
| `RP5` | B0 | 2 | 6 (4) | 5 | 2 (2) |
| `RC` | B0 | 3 | 6 (4) | 5 | 2 (2) |
| `RC3` | B0 | 0 | 0 (0) | 0 | 0 (0) |
| `RA1` | B0 | 4 | 8 (4) | 8 | 2 (2) |
| `RA4` | B0 | 0 | 3 (2) | 2 | 1 (0) |
| `RA4A3` | B0 | 0 | 2 (1) | 2 | 0 (0) |
| `RR` | B0 | 4 | 5 (3) | 5 | 3 (3) |
| `RA1P` | B0 | 4 | 10 (2) | 9 | 4 (4) |
| `RA1PP5` | B0 | 4 | 16 (8) | 16 | 9 (9) |
| `RA1PP5C` | B0 | 4 | 13 (5) | 11 | 4 (4) |
| `F1` | B0 | 4 | 14 (10) | 14 | 11 (11) |
| `F2` | B0 | 2 | 5 (4) | 5 | 3 (3) |
| `F12` | B0 | 4 | 16 (13) | 13 | 10 (10) |
| `B0pl1` | B0 | 2 | 3 (1) | 3 | 2 (1) |
| `B0pl2` | B0 | 2 | 1 (1) | 1 | 1 (1) |
| `A0C` | A0 | 2 | 5 (1) | 5 | 4 (3) |
| `A0A1` | A0 | 1 | 5 (4) | 4 | 4 (4) |
| `A0A3` | A0 | 0 | 0 (0) | 0 | 0 (0) |
| `A0A2` | A0 | 1 | 8 (5) | 7 | 6 (5) |
| `A0A2A3` | A0 | 1 | 9 (4) | 8 | 6 (5) |
| `A0A2A3A4` | A0 | 2 | 10 (6) | 10 | 6 (5) |
| `A0A2A3A4R` | A0 | 2 | 9 (3) | 8 | 4 (3) |
| `A0pl1` | A0 | 1 | 2 (2) | 2 | 1 (1) |
| `A0pl2` | A0 | 0 | 0 (0) | 0 | 0 (0) |

- **Forme a un cambio da `B0`** (13 forme, previsione 11). Conto depositato: `RP` 8, `RPa` 3, `RPb` 7, `RPc` 2,
  `RPd` 4, `RP5` 2, `RC` 2, `RC3` 0, `RA1` 2, `RA4` 1 (0 col conto stretto), `RR` 3, `F1` 11, `F2` 3; mediana 3.
  Studi con un'etichetta nata: `RP` 13, `RPa` 4, `RPb` 9, `RPc` 4, `RPd` 7, `RP5` 5, `RC` 5, `RC3` 0, `RA1` 8,
  `RA4` 2, `RR` 5, `F1` 14, `F2` 5; mediana 5. `RC3` non cambia i fattori.
- **Contro i placebo.** Col conto depositato i placebo hanno 0-2 studi con un errore nuovo, e `RC`, `RC3`, `RA1`,
  `RA4`, `RPc`, `RP5` stanno dentro questo intervallo. Col conto per etichetta i placebo hanno 0-3 studi, e dentro
  l'intervallo restano solo `RC3` (0) e `RA4` (2): le altre 11 forme ne hanno 4 o più. La frase «per `RC` e `RA1`
  gli errori nuovi non si distinguono da quelli di un cambio di parole» vale solo col conto depositato.
- **Ogni forma che toglie almeno un errore della sua base ne fa nascere almeno uno, in un altro studio**: sono 24
  forme su 29 (17 dal lato B, 7 dal lato A), con tutti e due i conti. Le 5 forme che non tolgono errori sono
  `RC3`, `A0A3`, `A0pl2` (nessuna etichetta nata), `RA4` (3 nate in 2 studi) e `RA4A3` (2 nate in 2 studi). Una
  sola forma ha meno etichette nate che tolte: il placebo `B0pl2` (2 tolte, 1 nata).
- **Esempi, per etichetta.** `RA1` toglie 4 errori presenti in `B0` (i tre di S12r3 che si spostano e il tempo
  ripetuto di `GSE46665`) e ne fa nascere 8 in 8 studi, 4 che costano: sono gli 8 errori con esito «della forma
  (A1)». `RC` ne toglie 3 e ne fa nascere 6 in 5 studi. `RPa` ne toglie 3 e ne fa nascere 5 in 4 studi. `F2` ne
  toglie 2 e ne fa nascere 5 in 5 studi. I conti tornano con gli errori presenti del §3.1: per `RA1` 9 − 4 + 8 = 13.

# 6. La forma finale secondo la regola

La regola depositata: si parte da `B0`; si toglie una differenza D se almeno un errore ha esito «della forma (D)»
e la forma che toglie D non ha errori nuovi di lettura; si aggiunge `F1` o `F2` se chiude il suo studio senza
errori nuovi.

| candidata | perché è candidata | studi con un errore nuovo nella forma che la applica (conto depositato) | studi con un'etichetta nata (§5.2) | entra |
|---|---|---|---|---|
| togliere `C` (`RC`) | `GSE57945` «della forma (C, A1)» | 2 | 5 | no |
| togliere `A1` (`RA1`) | `GSE57945` «della forma (C, A1)» | 2 | 8 | no |
| togliere `P` (`RP`) | 4 errori «della forma (P)», tutti del tipo «la differenza protegge» (§4.3) | 8 | 13 | no |
| aggiungere `F1` | chiude `GSE50499` (previsione 10a) | 11 | 14 | no |
| aggiungere `F2` | chiude `GSE63816` (previsione 10b) | 3 | 5 | no |

**La forma finale è `B0`, senza cambi**[^finale]. Coincide con la forma di partenza: come scritto nella regola, non
servono altre corse. Il conto per etichetta va nello stesso verso e rafforza ogni «no».

Lo script mette fra le candidate ogni differenza con un esito «della forma», senza guardare il verso, e
`30-forma-finale.txt` chiamava «conflitto» anche `P`. `P` non è un conflitto: toglierla fa nascere 4 errori e non
ne toglie nessuno di `B0` (§4.3; rilievo R3 della revisione). I conflitti veri sono al più 4: `C`, `A1`, `F1`,
`F2`. Con la lettura severa sono 2 (`F1`, `F2`), perché l'unico errore che motiva `C` e `A1` è instabile col
placebo. Vanno al PI come risultato (§9). La forma del Piano 2 la decide il PI.

# 7. Calcolo fatto dopo i numeri: dove stanno gli errori rispetto agli studi instabili

Questo calcolo non era nelle previsioni e non entra in nessun esito[^stabilita].

- **`B0` e i suoi due placebo.** In 12 studi su 47 almeno una delle tre letture dà una tabella dei fattori
  diversa. Dei 9 errori presenti in `B0`, 5 stanno in questi 12 studi e 4 negli altri 35. Dei 4 errori che costano,
  3 stanno in studi dove le tre letture non concordano (`GSE60340`, `GSE49155`, `GSE46665`) e 1 in uno studio dove
  concordano (`GSE57945`, il sesso come fattore). In `GSE46665` le tre letture differiscono per un altro fattore:
  l'errore delle sigle è in tutte e tre. Dei 12 studi, 7 hanno in `B0` gruppi identici a quelli dei curatori.
- **`A0` e i suoi due placebo.** 9 studi su 47 con letture diverse; degli 11 errori presenti in `A0`, 4 stanno in
  questi 9 studi e 7 negli altri.
- **Le 31 forme.** In 9 studi su 47 tutte le 31 forme danno la stessa tabella dei fattori (12 studi nelle 21 forme
  del lato B). 32 studi su 47 hanno almeno un errore di lettura in almeno una forma, 21 un errore che costa; 15
  studi non hanno mai un errore.

Lettura: la concordanza fra più letture dello stesso studio segnala una parte degli errori, non tutti. Un errore
stabile (`GSE57945` in `B0`, `GSE46665` ovunque) non si vede dalla concordanza.

# 8. Decisioni tecniche dell'agente

Quelle prese prima delle corse stanno nella carta, §8[^carta]. Dopo:

1. **Criteri di lettura.** «Forma»: la lettura giusta si ricava dall'uscita, e la blocca il modo in cui è scritta
   (lo studio non chiude). «Lettura del modello»: il contenuto è sbagliato (un fattore che non c'è, un fattore non
   visto, un livello sbagliato, una base che non è un livello). «Non errore»: colonna equivalente, fattore
   annidato vero, scelta dei curatori.
2. **La colonna «costa»** (sì o no) dice se l'errore cambia gruppi o confronti in almeno una forma in cui lo
   studio chiude. I 4 errori di S12r3 costano. Serve a non mettere sullo stesso piano il donatore letto da
   `source_name_ch1` e un fattore sbagliato.
3. **Eredità per scheda e lettura per corsa.** Una scheda (studio, firma, unità) letta una volta vale per tutte le
   corse che la condividono, come depositato. Tre controlli meccanici verificano che le corse di una scheda siano
   davvero uguali in quello che la lettura afferma (`28-*`): 55 schede sono condivise da più corse, 14 con corse
   non uguali in qualche dettaglio; per `GSE147507` in `RPc` e `B0pl1` la lettura è per corsa.
4. **La sotto-etichetta «nessuna coppia a un cambio lo sposta»** (7 errori) non era nell'elenco depositato: è il
   caso di un errore presente solo in forme a più cambi (per esempio `F12`). Sta sotto «non deciso».
5. **Il conto stretto degli errori nuovi** (102 contro 109), **il conto per etichetta** (§5.2) e **la lettura
   severa** della diagnosi sono dichiarati dopo i numeri e stanno accanto ai conti alla lettera.
6. **La lettura supplementare** (28 coppie, 71 celle): le celle senza unità di disaccordo, negli studi con un
   errore etichettato, hanno una firma che la lettura dei disaccordi non copre. Senza leggerle lo stato
   dell'errore in quelle celle sarebbe «assente» per costruzione.
7. **Nessuna corsa per la forma finale**, perché coincide con `B0` (regola §6 delle previsioni).
8. **Le schede di lettura non sono nel repository**: `25-materiale.R` le rigenera dalle uscite congelate
   (`23-uscite-sha256/` porta gli SHA-256). `26-leggi.py` le cerca nella cartella `schede/` accanto allo script.
9. **Una lettura corretta dopo la revisione** (rilievo R5, §13). La scheda di `GSE69597` nelle forme `RA1P` e
   `RA1PP5` era «non errore»; l'uscita scrive `source_name_ch1` con ruolo di soggetto (donatore). L'ho corretta in
   «lettura del modello» con l'etichetta `GSE69597:source_name_ch1 come donatore`, e ho rigenerato diagnosi e
   tabelle. Che cosa è cambiato: peggioramenti di lettura da 107 a 109 («non errore» da 16 a 14), conto stretto da
   100 a 102; `RA1P` da 3 a 4 studi con un errore nuovo, `RA1PP5` da 8 a 9; l'esito di quell'errore da «una
   direzione sola» a «più cambi» (sotto-etichette 19 → 20 e 7 → 6). Non è cambiato nessun esito «della forma» o
   «del modello», nessuna previsione, nessuna delle 13 forme a un cambio, e la forma finale.
10. **Una scheda ha una causa sola** (rilievo R2). In `RA1` le schede di `GSE147507` e `GSE57116` hanno causa
    «forma», perché lo studio non chiude per il modo in cui l'uscita è scritta, ma la stessa uscita porta anche un
    errore di lettura (il ceppo dei controlli come non dichiarato; il tempo ripetuto). Il conto depositato dà a
    `RA1` 2 studi con un errore nuovo; con la causa doppia sarebbero 3 o 4. Il conto per etichetta (8) li vede.

# 9. Che cosa va al PI

La regola depositata dice: un esito «del modello» o «non deciso» non si corregge in questa sessione, va al PI col
conto e con tutte le opzioni.

**Il conto.**

- «Del modello»: 2 errori. `GSE46665` (sigle dei pazienti come malattie): 31 forme su 31, costa gruppi e
  confronti. `GSE75852` (tempo che ripete il tipo cellulare): 31 su 31, non costa.
- «Non deciso»: 42 errori alla lettera (28 che costano), 51 con la lettura severa. Fra questi 2 dei 4 errori di
  S12r3 (`GSE60340`, `GSE49155`).
- «Della forma»: 14 alla lettera, 5 con la lettura severa, 1 con la lettura più stretta (§4.4). Uno solo indica un
  cambio che toglie un errore di `B0` (`GSE57945`), e le due forme che lo applicano fanno nascere errori in 2
  studi ciascuna col conto depositato, in 5 (`RC`) e in 8 (`RA1`) col conto per etichetta.
- Nella forma finale `B0` restano 9 errori di lettura in 8 studi, 4 che costano in 4 studi (i 4 di S12r3).

**Che cosa dice la diagnosi.** Gli errori di lettura non nascono in un pezzo della forma dell'uscita che si possa
nominare e togliere. Nascono nella lettura del modello, che cambia con le parole del prompt e con la forma dello
schema anche quando il cambio non dice niente. Un errore (`GSE46665`) è stabile. La vista (il testo che il modello
riceve) non è stata variata in questa sessione, per disegno.

**Le opzioni per il passo seguente** (la scelta è del PI):

| opzione | che cosa si fa | conseguenza |
|---|---|---|
| A | Si scrive il Piano 2 con `B0` com'è; il cancello sugli 82 studi di giudizio misura il lettore | È la misura che manca: quanti errori su studi mai letti. Gli errori di lettura ci saranno e nessun rimedio ha un nome: sui 47 studi 4 studi su 47 hanno un errore che costa. Contrasta con la regola «nessun errore si accetta» finché non c'è una decisione su che cosa si fa di quegli errori. Gli 82 studi si aprono una volta sola |
| B | Prima del Piano 2, una sessione che misura più letture dello stesso studio (la stessa forma con frasi riscritte senza cambiare il senso) e una regola deterministica sulla concordanza, scritta prima | Attacca la causa misurata (la lettura cambia con le parole). Non sostituisce il modello e non copre uno studio. Il calcolo dopo i numeri dice che segnala 12 studi su 47, e fra questi 3 dei 4 studi con un errore che costa; non segnala `GSE57945`, e segnala `GSE46665` per un altro fattore, non per l'errore stabile. Non porta a zero errori. Costo: più corse per studio in produzione, e una parte degli studi segnalati ha gruppi giusti |
| C | Prima del Piano 2, una sessione che varia la vista (quali testi e quali colonne riceve il modello), un cambio per volta | È l'unico pezzo a monte non ancora variato. In `GSE46665` il modello legge le sigle da `source_name_ch1` con la forma B e da `description` con la forma A (finding di S12r3, §5): la vista porta le sigle in più campi. Limite: ogni cambio sposta 5-9 studi su 47 anche senza significato, quindi su 47 studi un cambio utile si distingue male dal rumore; sarebbe la quinta lettura degli stessi studi |
| D | Un altro modello | Il PI ha deciso Mistral-Small 3.2 (2026-11-10). Nella prova ripetuta il modello Mistral più grande ha fatto peggio e non era ripetibile. Serve una decisione nuova del PI |
| E | Si ferma il lettore dello studio e si tiene la pipeline di oggi | La pipeline di oggi ritrova 13 confronti su 95 contro 68, e forma gruppi identici ai curatori in 14 studi contro 36. Il giudice di confrontabilità resta senza rimedio |
| F | Si apre una parte degli 82 studi di giudizio solo per contare gli errori di lettura, senza cancello | Dà la frequenza su studi mai letti senza il Piano 2. Consuma una parte del solo materiale non visto, che si può usare una volta |
| G | Si dichiarano gli errori di lettura come limite nei Methods | Contrasta con la regola del PI «nessuna soglia di errore accettata: ogni causa si corregge». La sessione non ha trovato una causa da correggere per 44 errori su 58 |

Le opzioni B e C si possono fare insieme o in fila. Per la forma dell'uscita la regola indica `B0`; le alternative
`RPa` (74 confronti, 47 studi chiusi, 3 studi con un errore nuovo col conto depositato, 4 per etichetta) e `F2`
(76 confronti, 3 e 5 studi con un errore nuovo) non entrano per la regola, e sceglierle per il numero è vietato dalla regola depositata.

# 10. Le consegne ricevute dalla prova precedente, e che cosa passa al passo seguente

1. **Le letture del modello che non costano confronti sono contate.** Dei 58 errori etichettati, 23 non costano
   gruppi o confronti in nessuna forma. In `B0` sono 5 su 9: `source_name_ch1` letta come donatore in `GSE50760`,
   `GSE71595` e `GSE66573`, il tempo ripetuto in `GSE46665`, il tempo che ripete il tipo cellulare in `GSE75852`.
   `source_name_ch1` come donatore è presente in 30 forme su 31 in `GSE50760` e in `GSE71595`, e in 21 su 31 in
   `GSE66573`. I due conti generici per forma stanno nella tabella del §3.1: i fattori doppi vanno da 3 a 8 per
   forma (`B0` 5), gli studi con un soggetto costante nei gruppi da 1 a 8 (`B0` 3).
2. **L'errore si conta sui gruppi e sui fattori, non solo sui confronti.** I sei criteri del peggioramento
   guardano lo stato dello studio, i confronti ritrovati, gli errori fra i non elencati, i predicati dei 4 errori,
   i due conti generici e la firma della tabella dei fattori con le unità. In `GSE57945` il predicato vede il sesso
   come fattore anche quando i confronti risultano coerenti.
3. **Le due correzioni di forma sono misurate come corsa** (`F1`, `F2`, `F12`): non entrano (§6). La frase del
   finding precedente «le due correzioni entrano nel passo seguente, qualunque sia» non vale più.
4. **Il rischio di adattamento resta** (§11, punto 1).
5. **Passano al Piano 2 senza cambi**, perché questa sessione non li ha toccati: la regola del riferimento per i
   fattori di contesto (`growth condition`, `GSE65335`: per nomi di Atlas o per tipo del fattore, da decidere
   prima e per costruzione); `GSE147507` (10 confronti fuori dall'universo di Atlas, limite «variabile su più
   colonne»; in questa sessione non chiude in 15 forme su 31 e in 3 l'uscita non finisce); la misura dei
   confronti non elencati sugli 82 studi col suo intervallo.

# 11. Limiti

1. **Quarta lettura degli stessi 47 studi** (le tre prove, più questa): ogni etichetta è data da chi
   conosce gli studi. Solo gli 82 studi di giudizio misurano il lettore, e restano chiusi.
2. **La lettura delle schede è di un solo agente, non cieca, senza seconda lettura.** I controlli meccanici (§8.3)
   e la revisione indipendente (§13) la verificano in parte.
3. **Due placebo per base.** Il rumore di fondo è stimato da 4 corse: 5-9 studi su 47. Con più placebo altri
   errori «stabili» possono risultare instabili.
4. **La vista non è variata.** Un esito «del modello» vuol dire «presente con ogni forma dell'uscita provata, con
   questa vista».
5. **I limiti della carta** (§6): `A2` non si toglie da `B0`; `A3` e `A4` sono annidati; nelle reversioni di solo
   schema il testo resta; l'ordine dei passi della catena è una scelta; `RA1` cambia insieme ordine e posto del
   nome della colonna.
6. **La firma della tabella dei fattori è sensibile per costruzione**: una firma diversa non è un errore.
7. **I conti per esito dipendono dalla regola**: 14 «della forma» alla lettera, 5 con la lettura severa, 1 con la
   lettura più stretta (§4.4).
8. **Un errore uguale in tutte le forme e senza unità di disaccordo non è letto.** La lettura parte dai disaccordi
   che cambiano. Per esempio in `GSE69597` la colonna `country` ha ruolo di soggetto (donatore) in 30 uscite su 32
   (non in `RPd` e `RR`, dove è un fattore): non ha un'etichetta, perché non costa confronti e non cambia fra le
   forme. I 58 errori sono quelli che la lettura ha visto, non tutti quelli che ci sono.
9. **Il conto depositato degli errori nuovi è stretto** (§5.2): vede solo gli studi peggiorati, e una scheda ha
   una causa sola (§8.10).

# 12. Anomalie viste durante il lavoro

1. **Uscite non finite.** `GSE147507` non finisce (fine `length`, uscita in ciclo) in tre forme: `RA4`, `A0A3`,
   `A0A2A3`. In quelle forme i 2 errori etichettati di quello studio sono «non valutabili».
2. **`GSE50499` chiude in 25 forme su 31**, anche col placebo `B0pl1`. Non chiude in `B0`, `RP5`, `RC3`, `RA4`,
   `RA4A3`, `B0pl2`. Il «non chiuso» che `F1` doveva correggere è anch'esso instabile rispetto alle parole.
3. **`GSE63816` chiude in 4 forme** (`RPa`, `RPb`, `RA1`, `F2`), sempre con gruppi diversi da quelli dei curatori.
4. **Un comando dell'agente si è fermato** durante la copia dei file dei job (un processo R per file); l'ho
   interrotto e rifatto in un comando solo. Nessun file dei job o dei log committati contiene il token di Hugging
   Face (cercato in tutti).
5. **Un'etichetta larga.** In `RC`, `GSE50760` scrive `source_name_ch1` con ruolo di soggetto di tipo «coppia», non
   «donatore»: l'etichetta `GSE50760:source_name_ch1 come donatore` lo segna presente. È l'unica cella discorde
   su 341 nel controllo meccanico delle etichette «…come donatore» dopo la correzione di §8.9.
6. **Il predicato di `GSE46665` riconosce le sigle per prefisso.** In `F1` i livelli sono `DCM_T0`…, uno per
   campione: il predicato dice «presente» e la lettura conferma che l'errore c'è nella sostanza.

# 13. La revisione indipendente

Un subagente Claude ha rivisto la sessione in sola lettura: codice, CSV e uscite grezze, con script suoi[^revisione].
È audit interno. Il revisore ha lavorato sui file prima della correzione di §8.9; dopo la correzione ho rieseguito
i suoi due script di ricalcolo sui file corretti: 58 esiti su 58 uguali.

**Che cosa dice il revisore.** Nessun numero sbagliato nelle tabelle. Ricalcolati senza differenze: i 58 esiti da
`27-stati.csv`, le 29 righe di `27-per-forma.csv`, le 31 di `29-errori-presenti-per-forma.csv`, le 32 di
`24-forme.csv`, le previsioni 1, 2, 3, 4, 5, 9, 10, 12. La forma finale `B0` regge con ogni lettura della regola
che ha provato. Ha riletto dal grezzo i 4 errori di S12r3 nelle 31 forme: accordo in 124 celle su 124. Ha riletto 30 coppie (forma, studio) con un errore nuovo nelle forme `RP`, `RC`, `RA1`,
`F1`, `F2` e nei placebo: accordo sulla causa in tutte, tre di confine (`RC` `GSE112057`, `F1` `GSE83415`, `F2`
`GSE53280`); se le tre cambiano causa nessuna forma arriva a zero errori nuovi. Ha riletto l'etichetta
`GSE67812:controlli scritti come DM1` nelle 31 forme: accordo 31 su 31.

| rilievo | che cosa | esito |
|---|---|---|
| R1 | Il conto depositato degli errori nuovi vede solo gli studi peggiorati; una frase di §5.2 mescolava «tolti» per etichetta e «nati» per riga peggiorata (`RA1`: 4 e 2, ma gli errori presenti passano da 9 a 13) | **corretto**: conto per etichetta calcolato per le 29 forme e riportato accanto (§5.2, §5.1, §6, §9); la frase è riscritta; il conto depositato resta quello degli esiti |
| R2 | In `RA1` due schede con causa «forma» portano anche un errore di lettura | **dichiarato** (§8.10, §11.9); nessun esito cambia |
| R3 | La forma finale non guarda il verso: `P` è chiamata «conflitto» | **corretto** nel testo (§6) e con una nota in `30-forma-finale.txt`; l'esito `B0` è uguale |
| R4 | «Della forma»: 14 alla lettera, 5 con la lettura severa, 1 con una terza lettura non dichiarata; la previsione 8 con la lettura severa è fuori dall'intervallo; il testo depositato è ambiguo sul placebo | **dichiarato** (§3.3 punto 5, §4.4, §11.7); ho ricalcolato 6 e 1 |
| R5 | Due celle «assente» sbagliate per `GSE69597:source_name_ch1 come donatore` (`RA1P`, `RA1PP5`) | **corretto**: era un mio errore di lettura; scheda corretta, diagnosi e tabelle rigenerate (§8.9) |
| R6 | Minori: sotto-etichetta non depositata; due definizioni di «migliorati» e «peggiorati»; predicato di `GSE46665` per prefisso; `RA4` e il conto stretto | **dichiarati** (§8.4, §3.1, §12.6, §5.2) |

**Che cosa il revisore non ha controllato** (lo dichiara lui):

- le righe con un errore nuovo delle forme `RPa`, `RPb`, `RPc`, `RPd`, `RP5`, `RA4`, `RR`, `F12`, del lato A e della
  catena: non rilette dal grezzo;
- gli stati delle 54 etichette nelle 1.674 celle: riletti dal grezzo solo per le etichette «…come donatore» (341
  celle, in modo meccanico) e per `GSE67812` (31 celle);
- le righe con causa «forma» o «non errore» (49 su 156 prima della correzione): lette solo le due di R2;
- il costruttore dei confronti e le misure: letti, non ricalcolati da zero;
- gli intervalli da ricampionamento, i cancelli, il calcolo sulla stabilità (§7), le tabelle generate;
- questo finding, il riassunto e la tabella delle fonti: non riletti.

**Limite dell'indipendenza.** La rilettura non è cieca del tutto: il revisore ha visto le prime righe dei file
delle letture, e quindi le mie letture di 7 studi, prima del suo giudizio. Il conto per etichetta sui placebo e sul
lato A, la terza lettura della regola e i numeri dopo la correzione sono miei e nessuno li ha rivisti, a parte i 58
esiti ricalcolati con lo script del revisore.

# 14. Da dove vengono i numeri del riassunto

Gli errori nuovi del riassunto sono contati per etichetta (§5.2), il conto più largo; il conto depositato sta fra parentesi.

| Nel riassunto | Fonte | Valore letto |
|---|---|---|
| «4 studi su 47, e 3 di questi errori non c'erano con la forma di prima» | finding di S12r3, §5 | 13 unità di lettura in 4 studi; 3 dei 4 non c'erano con lo schema v1 |
| «31 forme … sugli stessi 47 studi» | `01-carta.md` §4; `24-out.txt` (cancello 4) | 31 forme; 47 su 47 in ogni corsa |
| «24 forme su 29 … in tutte le 24 nasce almeno un errore nuovo in un altro studio» | `33-nati-per-etichetta.csv`, colonne `etichette_tolte`, `nate`, `tolte`; `33-out.txt` | 24 righe con tolte ≥ 1, tutte con almeno un'etichetta nata in uno studio diverso da quelli delle tolte; 5 righe con tolte = 0 |
| «9 errori di lettura in 8 studi, 4 che cambiano gruppi o confronti» | `31-out.txt`; `29-errori-presenti-per-forma.csv`, riga `B0` | 9 errori, 8 studi, 4 che costano |
| «nessuna delle 13 forme a un solo cambio ha meno di 9 errori» | `29-errori-presenti-per-forma.csv` | `RP` 20, `RPa` 11, `RPb` 16, `RPc` 10, `RPd` 15, `RP5` 13, `RC` 12, `RC3` 9, `RA1` 13, `RA4` 12, `RR` 10, `F1` 19, `F2` 12 |
| «la tabella dei fattori cambia in 5-9 studi su 47» | `27-previsioni.csv`, previsione 4 | 9, 6, 8, 5 |
| «due dei 4 errori spariscono con una frase riscritta» | `24-stati-dei-4-errori.csv` | `GSE49155` assente in `B0pl1`; `GSE60340` assente in `B0pl2` |
| «errori nuovi: da 0 a 3 studi per corsa» | `33-nati-per-etichetta.csv`, colonna `studi_con_etichetta_nata`, righe dei quattro placebo | 3, 1, 2, 0 (conto depositato: 2, 1, 1, 0) |
| «due corse danno uscite uguali al carattere» | `24-out.txt`, cancello 1 | 47 su 47 |
| «GSE46665 in tutte le 31 forme» | `27-diagnosi.csv` | presente 31, assente 0; esito «del modello» |
| «GSE57945 in 13 forme, GSE60340 in 8, GSE49155 in 14» | `27-diagnosi.csv` | 13 / 18; 8 / 23; 14 / 17 |
| «58 errori di lettura in 32 studi» | `27-diagnosi.csv`; `31-out.txt` | 58 righe; 32 studi |
| «nella forma per 14, nel modello per 2, per 42 nessuna causa» | `27-diagnosi.csv`, colonna `esito` | 14, 2, 42 |
| «dei 14, uno solo indica un cambio che toglie un errore della forma di oggi» | `32-tabelle.md`, T2, colonna del verso | «appare con D» solo per `GSE57945:sesso come fattore`; 13 «sparisce con D» |
| «le due forme con quel cambio fanno nascere errori in 5 e in 8 studi» | `33-nati-per-etichetta.csv`, righe `RC` e `RA1` | 5 e 8 (conto depositato: 2 e 2) |
| «i 14 scendono a 5» | `27-diagnosi.csv`, colonna `esito_severo` | della forma 5 (`C` 1, `P` 4) |
| «forma finale la forma di oggi» | `30-forma-finale.txt` | `B0`, nessun cambio |
| «una fa nascere errori in 14 studi, l'altra in 5» | `33-nati-per-etichetta.csv`, righe `F1` e `F2` | 14 e 5 (conto depositato: 11 e 3) |
| «76 e 74 su 95, contro 68» | `24-forme.csv` | `F2` 76, `RPa` 74, `B0` 68 |
| «queste due forme fanno nascere errori in 5 e in 4 studi» | `33-nati-per-etichetta.csv`, righe `F2` e `RPa` | 5 e 4 (conto depositato: 3 e 3) |
| «chiude 47 studi su 47 … toglie 3 errori e ne fa nascere 5 in 4 studi» | `24-forme.csv`; `33-nati-per-etichetta.csv`, riga `RPa` | 47 chiusi; tolte 3; nate 5 in 4 studi |
| «segnala 12 studi su 47, e 7 hanno gruppi giusti; 3 dei 4 studi; non GSE57945» | `31-out.txt` | 12 studi; identica 7; `GSE60340`, `GSE49155`, `GSE46665` sì, `GSE57945` no |
| «5-9 studi» (alternativa sul testo dello studio) | `27-previsioni.csv`, previsione 4 | 9, 6, 8, 5 |
| «il modello Mistral più grande ha fatto peggio» | finding di S12r2 (`CLAUDE.md` §1) | 32/97 e 25/97 contro 50/97 |
| «44 errori su 58» | `27-diagnosi.csv` | del modello 2 + non deciso 42 |
| «13 confronti su 95, contro 68» | finding di S12r3, §3 | pipeline di oggi 13/95; lettore 68/95 |
| «222 minuti, circa 7 minuti per corsa» | `23-out.txt` | somma delle durate di 32 job: 222,0 minuti |
