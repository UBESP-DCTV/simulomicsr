# ADR-0030: Chiusura del progetto — «non si può fare»

- **Status:** Accepted (decisione del PI del 2026-11-13)
- **Date:** 2026-11-13
- **Deciders:** Luca Vedovelli (PI). La decisione è del PI e non era fra le opzioni raccomandate dall'agente
- **Supersedes:** ADR-0029 (il lettore dello studio: fermato prima del cancello); il piano di
  `docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md` da S12s in poi
- **Superseded by:** —

## Il problema

Il progetto voleva una pipeline che parte dai metadati GEO, forma da sola i confronti trattato contro controllo
dentro ogni studio e li unisce in meta-analisi fra studi. La regola del PI (2026-11-07) è che la pipeline non deve
sbagliare: il database è fisso e nessuna soglia di errore si accetta. Dopo la sessione con più letture dello stesso
studio (S12r5, 2026-11-12) restavano due decisioni aperte, e l'agente raccomandava un'altra sessione sugli stessi 47
studi di sviluppo.

Che cosa è stato misurato (numeri ricopiati dal quadro di `CLAUDE.md` §1 e dai finding citati, non ricalcolati qui):

| passo | che cosa è stato misurato | finding |
|---|---|---|
| Deliverable A3 v16, 194 meta-analisi | lette tutte, due volte: 116 corrette, 62 difettose, 16 incerte | `2026-08-20-rilettura-194-correttezza`, `2026-08-21-S3-il-metro-concorda` |
| Confronti dentro gli studi | 193 difettosi su 1.903 nel riferimento; dopo la prova cieca altri 280 «puliti» non confrontabili: 473 su 1.903 (24,9%) | `2026-11-07-S11-lettura-falsi-allarmi`, `2026-11-08-S12p-prova-cieca-stadio2b` |
| Rimedio 1: regole dopo il modello | il rilevatore vede 81 difetti su 193 | `2026-11-07-S10-rilevatore`, `-S10b-rilevatore-metadati` |
| Rimedio 2: un giudice di confrontabilità (Stadio 2b, ADR-0028) | nessun modello passa il cancello (≥130/193 presi, ≤40/1.710 puliti accusati): 186/965, 177/887, 155/364 | `2026-11-08-S12p-prova-cieca-stadio2b` |
| Rimedio 3: il lettore dello studio (ADR-0029), cinque prove sugli stessi 47 studi | confronti dei curatori ritrovati: 10/93, poi 50/97, poi 68/95 (metodo di oggi 13/95); la regola di esito ha dato «no» in ogni prova | `2026-11-09-S12r-prova-lettore-studio`, `2026-11-10-S12r2-prova-ripetuta-lettore-studio`, `2026-11-11-S12r3-terza-prova-lettore-studio` |
| Gli errori di lettura del lettore | 9 errori noti in 8 studi su 47 nella forma decisa, più uno trovato dalla revisione; una frase del prompt riscritta con lo stesso senso cambia la tabella dei fattori in 5-9 studi; 24 cambi di forma su 24 che tolgono un errore ne fanno nascere un altro | `2026-11-12-S12r4-cause-errori-di-lettura` |
| Più letture dello stesso studio | la discordanza segnala 24 studi su 47 e non separa gli studi con errore dagli altri (6/8 contro 18/39); 5 errori noti su 9 sono uguali in tutte le letture; le 8 letture nuove portano 22 errori loro | `2026-11-12-S12r5-piu-letture-dello-stesso-studio` |
| Modelli più grandi | Mistral-Small-4-119B fa peggio e non è ripetibile; Qwen3.5-122B non parte | `2026-11-10-S12r2-prova-ripetuta-lettore-studio` |

Per gli errori di lettura del lettore oggi non c'è una correzione da applicare, e gli 82 studi di giudizio non sono
mai stati aperti: il cancello di ADR-0029 non è stato eseguito.

## Le forze

- Nessun errore si accetta, e un errore del modello non si chiude col prompt né con regole che fanno il lavoro del
  modello (regole del PI).
- Ogni rimedio provato ha spostato gli errori senza toglierli.
- La proposta seguente dell'agente aveva come bersaglio 6 errori su 47 studi già letti cinque volte.

## Le opzioni

Portate dall'agente dopo S12r5 (finding §8): non usare la discordanza come filtro, togliere gli studi segnalati,
tenerli con una nota; e per il passo seguente: una sessione che varia il testo dello studio che il modello riceve
(raccomandata dall'agente), il Piano 2 adesso con una lettura, il Piano 2 con più letture, un altro modello, aprire
una parte degli 82 studi di giudizio, fermare il lettore e tenere il metodo di oggi, dichiarare gli errori come limite.

Opzione del PI, non portata dall'agente: **chiudere tutto il progetto**.

## La decisione

Il PI (2026-11-13): «direi che non siamo pronti per fare uno studio del genere. Stai già ricominciando a fare proposte
che o non hanno senso o hanno un effect size microscopico. Direi che chiudiamo tutto con un non si può fare». Alla
domanda su che cosa comprende «tutto» il PI ha scelto «Tutto il progetto»: niente ricalcolo dei risultati, niente
articolo, i risultati su disco restano come sono. Poi: «poi pusha».

**Il progetto `simulomicsr` è chiuso il 2026-11-13 con l'esito «non si può fare».**

Che cosa sostengono le misure, detto con precisione: con gli strumenti provati (Mistral-Small 3.2 sul DGX, regole
deterministiche, un giudice a valle, un lettore dello studio) non è stata ottenuta una pipeline che forma i confronti
dai metadati GEO senza errori. Le misure non provano che la cosa è impossibile con altri strumenti.

## Le conseguenze

- **Nessuna sessione si apre.** Non si fanno S12s (il Piano 2 non si scrive), S12b, S12c, S12d, S13, S15, S7c, S7b,
  S16, S17. Non c'è un deliverable v17 e non c'è l'articolo.
- **La sessione S12r5 è chiusa.** Le sue due decisioni sono superate: la discordanza fra le letture non si usa, e il
  lettore dello studio non entra nel pacchetto.
- **Il deliverable A3 v16 resta su disco così com'è** e non è un risultato finale: 62 meta-analisi su 194 sono
  difettose, 473 confronti su 1.903 non sono confrontabili, l'inversione di `GSE144269` non è corretta. Chi lo usa
  deve leggere questo ADR.
- **Niente è cancellato:** dati, master, uscite delle prove, copia su `/mnt/micron/`, finding ed evidenza restano
  dove sono. Gli 82 studi di giudizio restano chiusi e non sono mai stati letti.
- **ADR-0029** passa a «Superseded by ADR-0030». ADR-0028 era già superato.
- **Git:** il branch `p6-tabella-dei-fattori` va su `origin` per ordine del PI; `master` resta invariato, senza merge
  e senza tag.
- Le decisioni rinviate e i limiti per i Methods (`CLAUDE.md` §11) restano scritti ma non hanno più una sessione che
  li riceve.

## Link

- Finding dell'ultima sessione: `docs/findings/2026-11-12-S12r5-piu-letture-dello-stesso-studio.md`
- Valutazione del progetto: `docs/findings/2026-11-07-valutazione-autonoma-del-progetto.md`
- ADR-0028 (Stadio 2b), ADR-0029 (il lettore dello studio)
- Handout: `docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md`
- Storia: `docs/STORIA.md`, `docs/RED_ALERT.md`
