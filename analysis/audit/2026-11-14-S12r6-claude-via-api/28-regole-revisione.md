# Revisione indipendente delle schede (audit interno)

Sei il revisore indipendente di una lettura. Lavori da solo. Non leggere nessun altro file oltre a quelli elencati
qui: in particolare NON leggere niente in `analysis/audit/2026-11-14-S12r6-claude-via-api/` del repository e niente
altro nella cartella scratchpad (li' sta la lettura di un altro lettore: guardarla annulla la revisione).

## Il contesto in breve

Un modello («il lettore») legge il testo di uno studio GEO e la tabella dei campioni e scrive una «tabella dei
fattori»: per ogni colonna un ruolo (factor, subject, replicate, uninformative), i fattori con tipo (perturbation,
state, context, time, technical), i livelli, il livello di base, e l'assegnazione di ogni valore a un livello.
Un programma deterministico forma poi i confronti: due gruppi uguali in tutti i fattori tranne uno, con uno dei due
al livello di base di quel fattore. Regole del programma che servono:
- un fattore senza base (base «») non forma confronti; il prompt dice che solo perturbation e state hanno una base,
  e che context, time e technical non la hanno mai;
- due gruppi che differiscono in piu' di un fattore non formano un confronto (`piu_di_un_fattore`);
- una colonna con ruolo subject/donor: se i due bracci di un fattore di perturbazione hanno donatori disgiunti il
  confronto NON si forma (`soggetti_disgiunti`); per un fattore di stato da' solo un avviso;
- una colonna subject senza il tipo di soggetto, un livello usato ma non dichiarato, o un'uscita che non rispetta lo
  schema: lo studio «non chiude» (nessun gruppo, nessun confronto).
Il riferimento e' la curazione di Expression Atlas (gruppi e confronti). Le regole che il lettore doveva seguire
stanno in `/home/user/simulomicsr/analysis/audit/2026-11-11-S12r3-elenco-chiuso/21-prompt-v2.md` (leggilo).

## Il materiale

Un file per studio nella tua cartella. In testa: il testo dello studio che il modello riceve, le colonne della
vista con i valori, i fattori, i gruppi e i confronti di Atlas. Poi «BASE»: la scheda di un altro modello
(Mistral-Small 3.2), come punto di partenza, non come esito. Poi una «SCHEDA <impronta>» per ogni lettura distinta:
fattori, livelli, campioni per livello, voci di assegnazione, altre colonne, «NON CAPITO» (quello che il lettore
dichiara di non avere capito), gruppi Atlas × lettore, confronti del lettore, esito dei confronti di Atlas, e le
UNITA' di disaccordo con Atlas. La forma T o V dice solo quale schema aveva l'uscita. Le schede non dicono quale
modello le ha scritte. Alcuni valori lunghi sono tagliati («…[tagliati N caratteri]»): se un taglio ti impedisce
di giudicare, scrivilo.

## Che cosa devi fare

Per OGNI scheda (non la BASE) di OGNI file della tua cartella dai una classe, leggendo la scheda intera (tutte le
voci di assegnazione, non solo le unita'):

- `non errore`: la lettura e' corretta rispetto al testo e alla tabella; il disaccordo con Atlas viene da una
  scelta dei curatori di Atlas (o da un loro errore), oppure non c'e' disaccordo e non c'e' errore;
- `forma`: lo studio non chiude o perde confronti per lo schema o la validazione dell'uscita (livello non
  dichiarato, soggetto senza tipo, uscita non valida), non per la lettura;
- `vista`: l'informazione che serve non sta in quello che il modello riceve;
- `lettura del modello`: il modello ha letto male lo studio (fattore mancante, fattore di troppo, fattore doppio
  dalla stessa colonna, valore assegnato al livello sbagliato, base sbagliata o non scritta dove lo studio la ha,
  una colonna con un valore per campione letta come donatore, e cosi' via);
- `rifiuto`: l'uscita e' vuota perche' l'API ha fermato la risposta (stop_reason refusal);
- `fermato dal limite di spesa`: nessuna risposta per un errore 400 sul limite di spesa (niente da giudicare).

Poi due colonne si/no:
- `costa`: si quando, per la causa che hai scritto, i gruppi del lettore sono sbagliati oppure confronti del
  lettore sono persi o sbagliati (anche se la misura contro Atlas non cambia). Per `non errore` scrivi no.
- `costa_su_atlas`: si quando quella causa cambia la misura contro Atlas (gruppi non identici ad Atlas o un
  confronto di Atlas non ritrovato PER quella causa). Per `non errore` lascia vuoto.
Un errore di lettura senza effetto su gruppi e confronti e' `lettura del modello`, costa no.
Se una scheda ha piu' cause, la classe e' quella della causa piu' grave (lettura del modello che costa > forma >
lettura senza costo > non errore) e le altre vanno nella descrizione.

Giudica con il testo dello studio e la tabella, non con Atlas: Atlas puo' sbagliare e puo' non usare un fattore
vero. Non dare ragione al lettore perche' dichiara un limite in «NON CAPITO»: giudica se l'informazione c'era.
Verifica i conteggi («campioni per livello») contro le colonne della vista quando un'assegnazione ti sembra dubbia.

## Che cosa consegni

Un file CSV (UTF-8, intestazione `scheda,studio,classe,costa,costa_su_atlas,descrizione`, una riga per scheda,
descrizione in italiano di una-tre frasi con i fatti che reggono la classe: colonne, livelli, numeri). Il percorso
del file te lo da' il messaggio. Nella risposta finale scrivi solo: quante schede hai classificato, il conteggio per
classe, e l'elenco delle schede su cui hai un dubbio vero con il motivo in una riga.
