# Tutto ARCHS4, passi 1 e 2: i testi GEO, l'ingresso del lettore e la prova piccola. Carta e previsioni

Depositato il 2026-11-16, **prima** dello scarico dei testi GEO e prima di ogni corsa di un modello su uno studio
nuovo. Dopo i numeri questo file non cambia. Quando scrivo esiste solo l'elenco degli studi (`10-elenco.csv`, fatto
dai numeri GEO e dalle parti già depositate): nessun testo nuovo, nessuna vista nuova, nessuna uscita nuova.

## La domanda

Il PI ha deciso (2026-11-16): i due lettori locali leggono tutto ARCHS4 con la regola dell'accordo, e la parte chiusa
di Gemma si apre dopo, come prova finale. Questa sessione fa i primi due passi e poi si ferma:

1. congela i testi GEO degli studi del bacino che non li hanno ancora;
2. prepara l'ingresso del lettore per tutti gli studi e fa una **prova piccola** su `poddgx02` con i due lettori.

La domanda della prova piccola è: **sugli studi mai curati la catena di ieri funziona senza cambi, e quanto rende?**
Cioè: quanti studi arrivano al modello, quanti il lettore chiude, quanti la regola dell'accordo tiene, quanto dura la
corsa grande, e se le uscite di ieri si possono unire a quelle della corsa grande. La corsa grande è una sessione
nuova e chiede il via del PI per le GPU.

## L'oggetto

- **Il bacino**: 24.393 studi, 508.037 campioni (`analysis/input/archs4-human-stage1-input-v2.jsonl`), lo stesso dei
  master S14.
- **Le classi** (`10-elenco.py`, per costruzione): `nuovo` 21.249, `gemma_aperta` 2.024, `gemma_chiusa` 991,
  `sviluppo` 47, `giudizio` 82.
- **I testi GEO**: per i 21.249 studi nuovi si scaricano adesso (`11-scarica-geo.py`, stessa richiesta di ieri: SOFT,
  vista «brief», un file per la serie e uno per i campioni, manifesto con SHA-256). Per gli altri **si riusano i testi
  già congelati** (47 del 2026-11-09, 3.015 del 2026-11-15): le date sono diverse e stanno nei manifesti.
- **La vista** v0 e **lo schema** `B0`: i programmi di ieri, senza cambi nel codice che forma la vista e lo schema.
- **I lettori**: Mistral-Small 3.2 nella forma `B0` con `repetition_penalty` 1,1 (corsa `M-rp11`) e Gemma-4-31B senza
  `repetition_penalty` (corsa `GE-rp0`), con i parametri di ieri (`temperature` 0, `max_model_len` 65536, `max_tokens`
  24576, `VLLM_BATCH_INVARIANT=1`, vLLM 0.20.2, solo `poddgx02`).
- **Il campione della prova piccola** (seme 20261116, `10-elenco.py`): 500 studi nuovi a caso (`casuale`), i 40 studi
  nuovi con più campioni fuori dai 500 (`grandi`, da 554 a 5.323 campioni), 50 studi a caso fra i 2.016 che ieri sono
  entrati nell'ingresso (`controllo`). Due ingressi e due job per lettore: il pezzo `casuale` (500 studi) e il pezzo
  `coda` (`grandi` più `controllo`, 90 studi).
- **La regola dell'accordo**: uno studio è «tenuto» quando i due lettori chiudono lo studio e danno gli stessi gruppi
  e gli stessi confronti (la chiave di `41-misura.R` di ieri, senza cambi).

## Le parti chiuse

- **Gli 82 studi di giudizio di Atlas**: in questa sessione niente testi, niente vista, niente ingresso, niente
  modello. Se entrano nella corsa grande è una decisione del PI: lo porto nel riassunto.
- **I 991 studi chiusi di Gemma**: la vista e lo schema si generano (non contengono il disegno di Gemma). Non entrano
  in nessun ingresso e nessun modello li legge. Niente si misura contro Gemma in questa sessione.
- **I 47 studi di sviluppo** e **i 2.024 studi aperti di Gemma** hanno già le uscite dei due lettori: non entrano
  nell'ingresso della corsa grande. Solo i 50 del `controllo` si rileggono nella prova.

## Che cosa ho già visto

- I numeri di ieri sulla parte aperta di Gemma: 2.016 studi nell'ingresso, 2.008 letti (8 oltre il contesto),
  Mistral ne chiude 1.879 (93,6%), i due lettori tengono 1.337 studi su 2.008 (66,6%); replica di Mistral uguale al
  carattere 2.016/2.016 (stesso ingresso, stessa divisione fra i lavoratori); durata 51 minuti per Mistral (4 GPU) e
  113 minuti di generazione per Gemma-4-31B (4 GPU, due lavoratori da 2 GPU).
- Dello studio nuovo solo il numero dei campioni nel bacino: mediana 8, 95% a 62, massimo 5.323; 818 studi hanno un
  campione solo, 2.239 ne hanno due.

## Cancelli

1. **K1, controllo positivo della catena.** Il programma della vista di questa sessione ridà, riga per riga, le 47
   viste di sviluppo (`60-viste-v0.jsonl`) e le 3.014 viste di Gemma (`gemma-viste-v0.jsonl`). I record dei 50 studi
   di `controllo` nell'ingresso della prova sono uguali byte per byte alle righe dell'ingresso di ieri.
2. **K2, testi congelati.** Ogni file dei testi GEO usato ha lo SHA-256 del suo manifesto (i tre manifesti). Lo
   scarico chiude con zero file che non tornano col manifesto.
3. **K3, copertura.** Ognuno dei 24.393 studi ha un esito con un codice: di giudizio (chiuso), senza testi (con il
   motivo), senza vista (con il motivo), senza colonne non costanti, nell'ingresso. La somma è 24.393. Nella prova
   ogni studio mandato ha un esito (letto e chiuso, letto e non chiuso, oltre il contesto). Niente si taglia.
4. **K4, ambiente.** Ogni job gira su `poddgx02`. Le variabili d'ambiente chieste si leggono nel contenitore.
   `generation.json` è quello atteso. Ogni lavoratore dichiara lo schema per record. Prompt, generatore, elenco e
   programma di lancio sono uguali ai file committati. Le uscite si congelano con SHA-256.
5. **K5, parti chiuse.** Nessuno studio di giudizio ha un testo, una vista o un record scritti in questa sessione.
   Negli ingressi e nelle uscite della prova non c'è nessuno studio di giudizio, nessuno studio chiuso di Gemma e
   nessuno studio di sviluppo.

## Misure

Unità: lo studio GEO. Intervalli al 95% col ricampionamento degli studi, B = 10.000, seme 20261116.

- a1: studi nuovi con i due file dei testi congelati, su 21.249.
- a2: studi nuovi nell'ingresso (una vista e almeno una colonna non costante), su 21.249.
- a3 (pezzo `casuale`): studi oltre il contesto, su quelli nell'ingresso.
- a4 (pezzo `casuale`): studi chiusi da Mistral, su quelli letti; lo stesso per Gemma-4-31B.
- a5 (pezzo `casuale`): studi tenuti dalla regola dell'accordo, su quelli letti da Mistral.
- a6 (`controllo`): studi con l'uscita di Mistral uguale al carattere a quella di ieri; studi con gli stessi gruppi e
  confronti di ieri, per ognuno dei due lettori.
- a7: secondi di generazione per studio letto nel pezzo `casuale` (il lavoratore più lento, diviso gli studi letti),
  per lettore; da qui la durata stimata della corsa grande su 4 GPU per lettore.
- Accanto, senza previsione: fra gli studi tenuti, quanti hanno almeno un confronto e quanti confronti; a4 e a5 per
  classi di grandezza (fino a 3 campioni, 4-12, 13-48, oltre 48); gli esiti dei 40 studi `grandi`; la stessa quota di
  studi tenuti con almeno un confronto sugli studi aperti di Gemma di ieri, come termine di paragone.

## Previsioni

Da dove vengono i margini. PA4, PA5 e PA7: i numeri misurati ieri sugli studi di Gemma, con un margine largo perché
gli studi nuovi non sono studi scelti da un curatore. PA6: una soglia del progetto (la pipeline è ripetibile).
PA1, PA2, PA3: un giudizio motivato, lo dico al PI.

| # | quantità | atteso | intervallo di rilevanza | motivo |
|---|---|---|---|---|
| PA1 | a1, studi nuovi con i testi | 99,7% | 99-100% | ieri 3.015 su 3.015, ma erano studi curati; ARCHS4 v2.5 è del 2024 e qualche serie può essere stata ritirata. Sotto il 99% la copertura è una frase dell'articolo |
| PA2 | a2, studi nuovi nell'ingresso | 95,5% | 93-98% | 818 studi nuovi su 21.249 (3,8%) hanno un campione solo e non hanno colonne non costanti; ieri 2.016 su 2.024 |
| PA3 | a3, oltre il contesto | 0,5% | 0-2% | ieri 8 su 2.016 (0,4%); 51 studi nuovi su 21.249 hanno più di 500 campioni |
| PA4 | a4, chiusi da Mistral | 93% | 88-98% | ieri 93,6%; sotto 88% il lettore perde più di uno studio su otto |
| PA4b | a4, chiusi da Gemma-4-31B | 97% | 92-100% | ieri 38 voci non chiuse su 2.052 |
| PA5 | a5, studi tenuti | 65% | 50-80% | ieri 66,6%; gli studi nuovi sono più piccoli (più accordo) e non scelti da un curatore (meno accordo). Sotto 50% la regola tiene meno di circa 10.000 studi e serve un altro secondo lettore; il piano conta su circa due studi su tre |
| PA6 | a6, Mistral uguale al carattere a ieri | 50 su 50 | 50 su 50 | `VLLM_BATCH_INVARIANT=1`; ieri la replica aveva la stessa composizione dei lotti, qui no. Una sola uscita diversa nei gruppi o nei confronti vuol dire che le uscite di ieri non si uniscono alla corsa grande |
| PA6b | a6, Gemma-4-31B con gli stessi gruppi e confronti di ieri | 49 su 50 | 45-50 | la replica sui 47 studi di sviluppo dava 47 su 47 nei gruppi e nei confronti, ma il modello non è ripetibile al carattere. Sotto 45 la regola dell'accordo dipende dalla corsa |
| PA7 | a7, durata stimata della corsa grande | Mistral 9 ore, Gemma-4-31B 20 ore | 5-14 ore, 11-30 ore | ieri 1,5 e 3,4 secondi per studio; fuori dall'intervallo cambia il piano della sessione seguente |

**Che cosa cambia.** Tutte dentro l'intervallo: la sessione seguente lancia la corsa grande con questo ingresso, senza
cambi, col via del PI. PA5 sotto 50%: porto al PI la scelta fra la corsa grande così com'è e la ricerca di un altro
secondo lettore prima. PA6 smentita nei gruppi o nei confronti: la corsa grande rilegge anche gli studi di ieri in una
corsa sola, e prima serve una diagnosi. PA6b sotto 45: la regola dell'accordo non è stabile e la corsa grande non
parte prima di una diagnosi. PA3 sopra il 2% o un job che si blocca su uno studio grande: prima della corsa grande
serve una regola scritta per gli studi oltre il contesto. PA1 o PA2 fuori: si dichiara la copertura e la causa.

## Decisioni tecniche prese prima

- Lo scarico usa due processi in parallelo sulla stessa lista (pausa 0,4 secondi per processo, circa 1,5 richieste al
  secondo, sotto il limite di 3 che NCBI chiede). Il campione della prova si scarica per primo.
- Uno studio senza testi esce con il motivo e con l'inizio dell'ultima risposta di GEO: dopo 5 tentativi se l'errore
  è di rete, dopo 3 se GEO risponde senza il testo dello studio. Non si ritenta a mano uno per uno: una seconda
  passata sola, su tutti i falliti, a scarico finito.
- Controllo positivo dello scarico, fatto prima di depositare questa carta (in una cartella provvisoria, fuori dal
  repository): il programma riscarica uno studio aperto di Gemma congelato ieri (`GSE51217`) e ridà i due file con
  lo stesso SHA-256 del manifesto di ieri; un numero GEO che non esiste esce fra i falliti.
- I testi già congelati non si riscaricano. Le date diverse (9, 15 e 16-17 novembre) sono un limite dichiarato.
- La vista non si taglia mai. Uno studio oltre il contesto lo salta il lavoratore sul DGX con i token contati, come
  ieri.
- I 540 studi nuovi della prova restano nell'ingresso della corsa grande: la corsa grande li rilegge, e il confronto
  fra le due letture è una replica in più.
- Nessuna misura contro Gemma o contro Atlas in questa sessione.

## Limiti dichiarati prima

- La prova piccola misura la resa e la tenuta della catena, non la correttezza: sugli studi nuovi non c'è un
  riferimento curato. La correttezza negli studi tenuti si misura sulla parte chiusa di Gemma, dopo.
- Uno studio «tenuto» può non avere nessun confronto (due lettori d'accordo su un solo gruppo). Per questo conto
  accanto gli studi tenuti con almeno un confronto.
- 500 studi danno un intervallo di circa ±4 punti su a5.
- L'accordo fra lettori toglie studi, non li corregge, e non vede gli errori che i due lettori fanno uguali: ieri
  l'errore di lettura stimato negli studi tenuti era 1,8% delle voci.
- I testi GEO di oggi possono essere diversi da quelli che ARCHS4 ha letto nel 2024: la vista usa i campioni del
  bacino e conta i campioni cancellati da GEO.
