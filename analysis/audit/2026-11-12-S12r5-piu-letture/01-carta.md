# S12r5 — la carta: più letture dello stesso studio

Scritta il 2026-11-12, **prima di ogni corsa di S12r5**, e committata con `00-previsioni.md`. Dopo le corse non
cambia. Domanda della sessione: se il lettore dello studio legge lo stesso studio più volte, ogni volta con una
frase del prompt riscritta senza cambiare il senso, **la discordanza fra le letture segnala gli errori di lettura?**

Che cosa è stato letto finora: solo le uscite congelate di S12r4 (`analysis/p4-output/S12r4-forme/`), sui 47 studi
di sviluppo. Gli 82 studi di giudizio restano chiusi.

## 1. Che cosa resta fermo

- **Studi:** i 47 studi di sviluppo. **Vista:** v0, non variata. **Modello:** `mistralai/Mistral-Small-3.2-24B-Instruct-2506`,
  revisione `95a6d26c4bfb886c58daf9d3f7332c857cb27b43`, `temperature` 0, `repetition_penalty` 1,1,
  `max_model_len` 65536, `max_tokens` 24576, `VLLM_BATCH_INVARIANT=1`, `HF_HUB_OFFLINE=1`, solo `poddgx02`.
- **Forma dell'uscita:** `B0` senza cambi (decisione del PI del 2026-11-12): schema generato per ogni studio a elenco
  chiuso (`schema_studio()` di S12r3), adattatore di `B0`, prompt v2
  (`analysis/audit/2026-11-11-S12r3-elenco-chiuso/21-prompt-v2.md`).
- **Ingresso:** testi e schemi di ogni corsa sono quelli di `B0` (uno SHA-256 solo, controllato dal lanciatore).
  Fra una lettura e l'altra cambia **solo una frase del prompt di sistema**.
- **Misura di una lettura:** quella di S12r4 (`misura_forma()`), riferimento a 95 confronti, senza cambi.

## 2. Le letture

**Nove letture per studio:** `B0` (una corsa nuova, che deve essere identica al carattere a quella congelata) e otto
letture nuove `L1`-`L8`. Ogni lettura nuova è `B0` con **una** frase del prompt riscritta.

**Perché otto.** Il prompt v2 ha 7 sezioni (l'apertura e 6 sezioni col titolo). Otto letture sono una frase per
sezione, più una seconda frase dalla sezione con più frasi candidate. L'handout chiede da 5 a 10 corse: con `B0` sono
9. Il numero è fissato qui, prima dei numeri, e il conto principale usa **tutte e 9** le letture. Non si sceglie il
numero di letture che dà il conto migliore: l'andamento col numero di letture si riporta per intero (§5 delle
previsioni).

**Quali frasi.** Le sceglie un programma (`10-frasi.R`, seme 20261112), non l'agente e non guardando gli studi:

- una frase finisce con un punto seguito da uno spazio o con la fine della riga; il prompt ha 63 frasi;
- è candidata una frase con almeno 10 parole, che compare una volta sola nel prompt e che non è una delle due frasi
  dei placebo di S12r4: 40 candidate;
- si estrae una candidata per sezione e una seconda dalla sezione con più candidate (`10-frasi.csv`, con l'ordine
  di riserva per ogni sezione).

**Le riscritture** (`11-riscritture.csv`: frase originale, frase riscritta, operazione). Sono generali: nessuna
nomina uno studio, una colonna o un caso. Le operazioni ammesse sono quattro, tutte di sola sintassi:

| operazione | letture |
|---|---|
| ordine dei complementi | `L3`, `L5`, `L6`, `L8` |
| ordine di principale e subordinata | `L4`, `L7` |
| da attiva a passiva | `L2` |
| relativa equivalente | `L1` |

Vincoli controllati dal programma (`10-letture.R`, autocontrolli che fermano): la frase originale compare una volta
nel prompt; il resto del prompt è identico al byte; i nomi dei campi fra apici inversi sono gli stessi, nello stesso
numero; la lunghezza cambia di 10 caratteri al massimo; nessun prompt è uguale a `B0` o a un placebo di S12r4; lo
schema delle uscite non cambia. Nessuna parola di contenuto è aggiunta, tolta o sostituita con un sinonimo.

## 3. Il criterio «non cambia il senso»

Una riscrittura passa se un lettore attento segue **esattamente la stessa istruzione in ogni caso**: stesse
condizioni, eccezioni, quantificatori, forza del modale, ambito ed esempi; niente aggiunto e niente tolto; nessuna
ambiguità che l'originale non ha.

**Come è stato controllato** (audit interno, prima delle corse). Due agenti indipendenti hanno ricevuto il prompt
intero e 11 coppie in ordine casuale: le 8 riscritture e 3 esche, cioè frasi in cui il senso cambia apposta
(`12-esche.csv`). Non sapevano quante coppie fossero esche. Regola scritta prima: una riscrittura entra solo se
tutti e due la giudicano uguale; altrimenti si prende la frase di riserva della stessa sezione.

**Esito** (`12-giudizio-esito-giro1.csv`): le 8 riscritture sono giudicate uguali da tutti e due (fiducia 5 su 5
per sei, 4 su 5 per `L3` e `L7`); le 3 esche sono giudicate diverse da tutti e due. Nessuna frase di riserva è
servita.

**Limite.** Il criterio è un giudizio di due agenti, non una prova. Un modello può reagire a una riscrittura che per
un lettore umano è uguale: è proprio quello che la sessione misura. Se una riscrittura cambiasse il senso, gli studi
segnalati sarebbero di più; il conto per lettura (quanti studi cambiano con ognuna delle 8) lo fa vedere.

## 4. I due placebo di S12r4

In S12r4 due corse (`B0pl1`, `B0pl2`) avevano già una frase riscritta senza cambiare il senso. **Non entrano nel
conto principale.** Motivo: il conto dell'handout (12 studi con letture diverse, 3 dei 4 errori che costano) è nato
su quelle due corse, dopo i numeri. Usarle ancora vorrebbe dire confermare una regola sui dati che l'hanno
suggerita. Le loro due frasi sono escluse dall'estrazione.

Entrano in un **conto accanto, a 11 letture** (le 9 più i due placebo), dichiarato qui: dice se le due corse già
viste aggiungono studi segnalati. Non entra nella regola di esito.

## 5. Rischio di adattamento, dichiarato

È la quinta volta che gli stessi 47 studi si leggono. Che cosa limita il rischio:

- frasi estratte da un programma, riscritte e giudicate prima delle corse, senza guardare gli studi;
- regola sulla discordanza, regola di esito e previsioni depositate prima;
- numero di letture fissato prima.

Che cosa resta: i 9 errori di `B0` sono stati trovati su questi stessi studi; le previsioni conoscono il conto fatto
sui due placebo. Un risultato sui 47 studi non dice quanto vale la regola su studi nuovi. Gli 82 studi di giudizio
servono a questo e restano chiusi.

## 6. Che cosa la sessione non può dare, detto prima

1. **Non porta a zero errori.** La discordanza può segnalare uno studio, non dice quale lettura è giusta, e la regola
   non sceglie, non vota e non corregge.
2. **Non vede un errore stabile.** Un errore che il modello fa in tutte le letture dà letture uguali: lo studio non
   è segnalato. Nel conto sui placebo di S12r4 `GSE57945` (il sesso come fattore) era in questo caso.
3. **Segnala anche studi giusti.** Nel conto sui placebo 7 dei 12 studi segnalati avevano i gruppi dei curatori.
4. **La regola di esito ha poca forza.** Gli studi con un errore di `B0` sono 8 e gli altri 39. La tabella degli
   esiti possibili (`14-potenza.R`, `14-out.txt`, calcolata senza nessuna uscita del modello) dice quando la
   condizione sull'intervallo può valere:

   | studi con errore segnalati (su 8) | la condizione vale se gli studi senza errore segnalati (su 39) sono al massimo | non vale se sono almeno |
   |---|---|---|
   | da 0 a 3 | mai | 0 |
   | 4 | 3 | 6 |
   | 5 | 7 | 10 |
   | 6 | 13 | 16 |
   | 7 | 20 | 23 |
   | 8 | 35 | 36 |

   Con i valori che prevedo (5 su 8 e circa 15 su 39) l'esito è «no». Un «no» di questa regola vuol dire: su 47
   studi la discordanza non separa gli studi con errore dagli altri oltre il caso. Non vuol dire che non li separa.
5. **I 39 studi «senza errore» non sono provati senza errore.** Sono gli studi in cui la lettura di S12r4 (un agente
   solo, con una revisione indipendente) non ha trovato un errore di lettura in `B0`. Limite noto: `country` in
   `GSE69597` non è stato letto.
6. **La vista non è variata.** Un errore che nasce dalla vista non si muove con il prompt.
7. **`B0` non chiude `GSE50499` e `GSE63816`.** Sono errori di forma, non di lettura: non stanno fra i 9.

## 7. Scelte tecniche dell'agente (da riportare nel finding)

- **La chiave della regola ha tre parti** (tabella dei fattori, gruppi, confronti), non la sola tabella dei fattori
  dell'handout. Motivo, trovato sulle uscite già viste di S12r4 e prima di ogni corsa nuova (`13-out.txt`): in 3
  coppie di letture (`GSE50499`, `GSE83687`) la tabella dei fattori ha la stessa firma, ma una lettura chiude lo
  studio e l'altra no, perché la firma non vede il nome di un livello scritto in una forma che lo schema non lega.
  Con la chiave a tre parti gli studi segnalati sui placebo sono 13 (i 12 dell'handout più `GSE50499`). La sola
  firma si riporta accanto, come le altre due chiavi da sole.
- **Il file di S12r4 che definisce le forme non si carica più così com'è**: una sua riga legge come elenco di cambi
  un file che dopo la chiusura di S12r4 porta il testo dell'esito. I file di S12r4 non si toccano: `10-letture.R` li
  carica senza quella riga. Il cancello dello strumento prova che la misura ridà i numeri congelati.
- **Il conto degli errori nuovi è per etichetta** (l'errore è nuovo se `B0` non ha quell'errore in quello studio),
  non il conto depositato in S12r4, che dipendeva dalla forma di base. Lo dico prima, come chiede l'handout.
- **Due processi in parallelo** su `poddgx02`, con il lanciatore di S12r4 adattato (`23-lancia.R`). In S12r4 una
  corsa è durata da 3 a 7 minuti di calcolo: per 9 corse l'attesa è sotto un'ora.
