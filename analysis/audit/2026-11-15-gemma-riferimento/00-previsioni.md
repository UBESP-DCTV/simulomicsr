# Il riferimento di Gemma (UBC): curatori contro curatori. Carta e previsioni

Scritto il 2026-11-15, **prima** di formare un gruppo o un confronto dai disegni di Gemma. Fino a qui ho letto dei
disegni di Gemma solo la struttura (le chiavi dei JSON di `GSE46665` e il censimento `20-censimento.csv`, che conta
campioni, fattori, analisi e livelli di base). Non ho confrontato nessun disegno di Gemma con Atlas né con un lettore.

## La domanda

Due gruppi di curatori umani (Gemma e Expression Atlas) hanno curato lo stesso studio. **Quanto concordano fra loro
sui gruppi e sui confronti?** La risposta dice quanto può valere al massimo un lettore misurato contro uno solo dei
due: se due curatori concordano in 6 studi su 10, un lettore a 8 su 10 contro Atlas non è «sotto» i curatori.
Serve anche a decidere se il riferimento di Gemma si può usare sui circa 3.100 studi che Atlas non copre.

## L'oggetto

- I disegni di Gemma scaricati il 2026-11-15 (`12-scarica-disegni.py`, 3.170 voci, 0 errori) in
  `analysis/p4-output/gemma-disegni-2026-11-15/`. Gli studi di giudizio (17 + 16 nell'elenco) **non sono scaricati**.
- La misura di questa carta: i **21 studi di sviluppo** che hanno un disegno di Gemma (`11-da-scaricare.csv`,
  `parte == sviluppo`). Il riferimento di Atlas è quello della terza prova (S12r3): 95 confronti sui 47 studi, senza
  il tempo zero come controllo e senza i confronti di solo contesto.
- Termine di paragone sugli stessi 21 studi: Mistral-Small 3.2 nella forma `B0`
  (`analysis/p4-output/S12r5-letture/B0.jsonl`, corsa congelata).

## L'adattatore: dai disegni di Gemma alla tabella dei fattori (regole fissate qui)

1. **Campioni**: i GSM dei campioni di Gemma. Un campione senza GSM ferma lo studio.
2. **Fattori**: i fattori sperimentali di Gemma scritti sui campioni (`fvbasicVOs`). Escono, con una nota:
   i fattori di blocco tecnico (categoria `block`: Gemma li ricava dalle testate dei FASTQ, non sono disegno) e i
   fattori continui (`experimentalFactorType == continuous`: non formano gruppi).
3. **Livelli**: il testo `summary` del valore del fattore. Due valori diversi con lo stesso testo nello stesso
   fattore prendono l'identificativo di Gemma in coda. Un campione senza valore per un fattore ha `non scritto`.
4. **Base**: il `baselineGroup` che Gemma dichiara per quel fattore nelle sue analisi differenziali (insiemi di
   risultati a un solo fattore). Se le analisi su sottoinsiemi dichiarano basi diverse per lo stesso fattore, il
   fattore resta senza base e lo studio porta la nota `basi_diverse`. Un fattore senza analisi resta senza base.
5. **Tipo**, per costruzione dalle due decisioni del PI sul riferimento di Atlas, non da un elenco nuovo:
   categoria in `TF_FATTORI_CONTESTO_ATLAS` (`cell type`, `cell line`, `organism part`) → `contesto`, senza base;
   categoria `timepoint` → `tempo`, senza base; ogni altro fattore con una base → `perturbazione`; senza base →
   `contesto`. Gemma non ha colonne di soggetto, quindi `perturbazione` e `stato` danno gli stessi confronti.
6. **Confronti**: li forma il costruttore del pacchetto (`tf_confronti()`, `n_min = 2`) dalla tabella. Non sono i
   contrasti del modello lineare di Gemma (effetto principale su tutti i campioni): sono le coppie di gruppi uguali
   in tutti i fattori tranne uno, con uno dei due alla base. È la stessa definizione che vale per il lettore.
7. Una voce di Gemma che è una parte di uno studio GEO (`GSE52778.2`) si misura sui suoi campioni: l'universo è
   l'intersezione con l'universo di Atlas. Si dichiara quanti campioni dell'universo di Atlas restano fuori.

## Cancelli

- **K1 riproduzione.** Mistral `B0` sui 47 studi: 45 chiusi, 36 gruppi identici, 68/95 confronti ritrovati.
- **K2 controllo positivo.** Uno studio finto nel formato di Gemma (2 fattori, un blocco, una base) dà la tabella
  attesa: gruppi, base, confronti. Un secondo studio finto con basi diverse fra sottoinsiemi dà la nota.
- **K3 copertura.** Ognuna delle 3.170 voci ha un esito dell'adattatore: tabella, oppure un motivo con codice.
  I 21 studi di sviluppo: 21 esiti.
- **K4 solo sviluppo.** Nessun file di uno studio di giudizio nella cartella dei disegni; la misura contro Atlas
  legge solo studi con `parte == sviluppo`.
- **K5 oggetto.** La misura usa le stesse funzioni e lo stesso riferimento della terza prova (`misura_r3`).

## Misure (sui 21 studi; unità: lo studio; B = 10.000; seme 20261115)

- m1: studi con una tabella di Gemma che forma gruppi (chiusi) su 21.
- m2: studi con gruppi identici ad Atlas su 21 (Gemma), accanto a Mistral `B0` sugli stessi 21.
- m3: confronti di Atlas ritrovati su quelli dei 21 studi (Gemma), accanto a Mistral `B0`; differenza appaiata
  Gemma meno Mistral con IC 95%.
- m4: studi dove Gemma e Mistral `B0` danno gli stessi gruppi; di questi, quanti identici ad Atlas.
- m5: i 4 studi con un errore di lettura di Mistral che costa e che stanno nei 21 (`GSE46665`, `GSE49155`,
  `GSE57945`, `GSE60340`): Gemma dà i gruppi di Atlas, quelli di Mistral, o altri.

## Previsioni

Margini: giudizio motivato (non c'è una soglia del progetto né una variabilità misurata per due curatori).

| | quantità | atteso | intervallo di rilevanza | motivo |
|---|---|---|---|---|
| P1 | m1, chiusi su 21 | 20 | 18-21 | le analisi mancano in 174/3.170 voci, ma i gruppi non chiedono la base |
| P2 | m2, Gemma identici ad Atlas su 21 | 11 | 7-15 | i curatori scelgono fattori diversi (contesto, tempo, donatore) |
| P3 | m2, Mistral `B0` identici su 21 | 16 | 13-19 | 36/47 sui 47, e i 21 contengono 4 dei 5 studi con errore |
| P4 | m3, Gemma ritrovati sul totale | 45% | 25-65% | la base di Gemma è una scelta del modello lineare, non sempre il controllo di Atlas |
| P5 | m3, differenza Gemma meno Mistral | −15 punti | IC tutto sotto 0 | se smentita: il lettore non supera due curatori fra loro, o li eguaglia |
| P6 | m5, Gemma con i gruppi di Atlas nei 4 studi | 2 | 1-3 | sono studi difficili anche per chi cura |

**Che cosa cambia.** Se P2 e P4 sono confermate (due curatori concordano in circa metà degli studi), l'articolo non
può presentare Atlas come verità: presenta l'accordo fra curatori come tetto e mette il lettore accanto. Se Gemma
concorda con Atlas più di Mistral (P5 smentita verso l'alto), i curatori sono un riferimento più stretto del
lettore e il riferimento di Gemma sui 3.100 studi è una misura severa e utile.

## Limiti dichiarati prima

- 21 studi, già usati sei volte per sviluppare il lettore: Mistral `B0` è scelto su questi studi, Gemma no.
- I confronti di Gemma qui sono quelli del nostro costruttore sulla sua tabella, non i suoi contrasti.
- La base di Gemma è scelta da regole automatiche e da curatori insieme: l'API non distingue i due casi.
- Il riferimento di Atlas ha due esclusioni decise dal PI (tempo zero, solo contesto) che Gemma non ha deciso.
- Un disaccordo fra curatori non dice chi dei due ha ragione. Leggo tutti i disaccordi dei 21 studi, non un campione.
