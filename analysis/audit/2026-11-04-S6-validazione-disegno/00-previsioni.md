# Validazione esterna, il disegno (S6): cancelli e previsioni

Scritte il 2026-11-04, prima del calcolo. Non si cambiano dopo il risultato.

**Che cosa ho già letto.** L'handout, i cinque script del 2026-08-07, le prime righe di
`copertura-lincs-per-entita.csv` (4 righe) e di `copertura-trtlig-entita-hgnc.csv` (20 righe, sulle 214), i nomi delle colonne di
`siginfo_beta.txt` e del deliverable, le dimensioni dei file Level 5 (richiesta HEAD).
**Che cosa non ho letto e non leggerò in questa sessione.** Nessun dato Level 5, nessun
confronto fra una stima del deliverable e una firma LINCS.

**Un dubbio, prima di contare.** Gli script del 2026-08-07 chiamano «111» i *candidati* con un
identificativo di composto (`CHEBI`/`CHEMBL`), non i composti agganciati: `50-tabella-finale.R`
stampa «i 111 candidati» e poi agganciate e non agganciate, e `40-trtlig-e-borderline.R` parla di
«21 non agganciati». L'handout scrive «111 entità già mappate» e ricava «al meglio il 47% del
deliverable» da 91/194. Se il dubbio è giusto, quel 47% è un soffitto sui candidati, non sui composti.

Unità: la meta-analisi. Queste sono conte su tutta la tabella, senza campionamento: non hanno
intervallo di confidenza, e la regola è «dentro» o «fuori» dall'intervallo di rilevanza.
Seme delle parti casuali: 20261104.

## Cancelli

1. **Dati.** Il manifesto SHA-256 del deliverable passa all'inizio e alla fine.
2. **Riproduzione.** Il metodo del 2026-08-07, riscritto senza `stopifnot(nrow(d)==214)`, ridà sul
   deliverable v15 lo stesso esito di `20-entita-con-firme.rds`: stesse 111 righe, stesso
   `metodo_match` e stesso `pert_id` per ciascuna.
3. **Copertura.** Ognuna delle 194 meta-analisi cade in una sola classe della tavola del soffitto
   e la somma fa 194. Le liste `80-insieme-40.csv` e `80-insieme-172.csv` si agganciano per
   `cluster_id` a 40 e 172 righe del deliverable.
4. **Controlli positivi.**
   (a) l'aggancio per struttura trova `bortezomib` (`CHEBI:52717`) ed `erlotinib` (`CHEBI:114785`), e
   rifiuta l'acido ascorbico (`CHEBI:29073`) già respinto a mano il 2026-08-07;
   (b) lo strumento della circolarità, a cui aggiungo un `GSE` che so essere nelle 194, lo vede;
   (c) la ricerca nel testo dei metadati trova la parola di controllo `CRISPR` in almeno uno studio delle 194.
5. **Cieco.** Nessun file `.gctx` su disco nella cartella di LINCS o nell'evidenza. Nessuno script di
   questa sessione legge insieme `cluster_pooled` e una firma LINCS.

## Previsioni

| # | quantità | attesa | intervallo di rilevanza | origine del margine |
|---|---|---:|---:|---|
| P1 | meta-analisi delle 194 con almeno una firma `trt_cp` | 72 | [60; 90] | giudizio: sotto 91 l'handout sbaglia il 47%, sotto 60 la fonte copre meno di un terzo |
| P2 | meta-analisi delle **40** con almeno una firma `trt_cp` | 16 | [12; 21] | giudizio: 21 è il valore dell'handout sui 37; sotto 12 l'insieme principale ha una potenza da rivedere |
| P3 | studi delle 194 fra le serie LINCS note, confronto esatto | 0 | [0; 0] | soglia di principio: uno solo apre il dubbio |
| P4 | studi delle 194 che citano LINCS, L1000 o CMap nel metadato | 3 | [0; 26] | soglia: 26 è l'1% di 2.566 studi, oltre serve l'esclusione caso per caso |
| P5 | composti della P1 misurabili dalla fonte (almeno 3 firme attive, in almeno 3 linee cellulari) | 70% | [50%; 90%] | giudizio: sotto 50% la fonte vede meno di metà di quel che aggancia |
| P6 | meta-analisi in più con una firma di ligando (`trt_lig`) | 12 | [8; 15] | 15 citochine dichiarate dall'handout, 8 è circa la metà |
| P7 | meta-analisi delle 194 senza alcuna fonte esterna disponibile | 35% | [25%; 50%] | giudizio: oltre metà, l'articolo non può dire «validato» senza una riga di limite molto forte |

I margini 1, 2, 5, 7 sono un giudizio mio: lo dico al PI nel riassunto.
