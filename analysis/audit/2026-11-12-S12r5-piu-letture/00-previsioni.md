# S12r5 — cancelli, previsioni, regola sulla discordanza e regola di esito

Depositato il 2026-11-12, **prima di ogni corsa di S12r5**, e committato da solo (con la carta, i prompt e gli
script che le corse usano). Dopo le corse non cambia. Le letture, le frasi riscritte, il criterio «non cambia il
senso» e i limiti stanno in `01-carta.md`. Finora sono state lette solo le uscite congelate di S12r4
(`analysis/p4-output/S12r4-forme/`), sui 47 studi di sviluppo.

**Unità:** lo studio. **Ricampionamento:** per studio, B = 2.000, seme 20261112 (la data della sessione), intervallo
al 95% dai percentili. **Letture:** 9 per studio (`B0` e `L1`-`L8`). **Errori di riferimento:** i 9 errori di lettura
di `B0` del finding di S12r4, in 8 studi; 4 costano gruppi o confronti (`GSE46665` sigle dei pazienti come malattie,
`GSE57945`, `GSE60340`, `GSE49155`) e 5 no (`GSE46665` tempo ripetuto, `GSE50760`, `GSE66573`, `GSE71595`,
`GSE75852`). Gli altri 39 studi sono «senza un errore letto in `B0`», non «senza errore» (`01-carta.md` §6).

## 1. Cancelli (se uno fallisce, la sessione non vale)

1. **`B0` si riproduce.** La corsa nuova di `B0` è identica al carattere all'uscita congelata di S12r4
   (`analysis/p4-output/S12r4-forme/B0.jsonl`) in 47 studi su 47. Quindi ridà 45 studi chiusi, 36 con gruppi identici
   ai curatori, 68 confronti ritrovati su 95.
2. **Lo strumento ridà i numeri congelati** (prima delle corse: `13-out.txt`). Sulle uscite di S12r4 la misura ridà
   `24-per-studio.csv` per `B0`, `B0pl1`, `B0pl2`; i 9 predicati ridanno gli stati letti in S12r4 in 279 casi su 279;
   la discordanza sulla sola tabella dei fattori ridà i 12 studi dell'handout (7 con gruppi identici, 4 degli 8 studi
   con errore, 3 dei 4 che costano).
3. **Controllo positivo.** Nella corsa nuova di `B0` i 9 predicati vedono i 9 errori di lettura.
4. **Copertura.** Ogni corsa copre 47 studi di sviluppo su 47 e nessuno degli 82 studi di giudizio.
5. **Ambiente.** Ogni job gira su `poddgx02`; `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` sono lette dal file
   dell'ambiente del container (solo quelle due righe); modello, revisione, `temperature`, `repetition_penalty`,
   `max_model_len`, `max_tokens` sono quelli di `01-carta.md` §1; l'ingresso di ogni corsa ha lo SHA-256 dell'ingresso
   di `B0`; il prompt nel bundle è quello generato dal codice committato; il lavoratore usa lo schema del record in
   ogni record mandato al modello.

## 2. Previsioni

Origine del margine: (S) soglia del progetto, (M) variabilità misurata in S12r4, (G) giudizio motivato dell'agente.
**Le previsioni 1, 2, 5, 9, 10 e 12 hanno un margine di giudizio:** partono dal conto sui due placebo di S12r4, che è
una misura a 3 letture, e l'estensione a 9 letture è un giudizio.

| n. | quantità | atteso | intervallo di rilevanza | origine | se cade fuori |
|---|---|---|---|---|---|
| 1 | studi segnalati con 9 letture (su 47) | 20 | da 13 a 23 | G; M: 13 con 3 letture (`13-out.txt`) | sotto 13 non può andare (vedi sotto). Sopra 23: la regola segnala più di metà degli studi, e una segnalazione dice poco |
| 2 | studi con la chiave diversa da `B0`, per ogni lettura nuova: mediana fra le 8 | 8 | da 5 a 12 | G; M: 10 e 7 con i due placebo | sotto 5: le frasi estratte muovono il modello meno dei placebo; sopra 12 (un quarto degli studi): una frase riscritta sposta la lettura quanto un cambio di forma di S12r4 |
| 3 | studi con un errore che costa segnalati (su 4) | 3 | da 3 a 4 | M: 3 con 3 letture | 2 o meno: più letture non vedono nemmeno gli errori che costano; la condizione (b) della regola di esito è «no» |
| 4 | errori di `B0` in studi segnalati (su 9) | 6 | da 5 a 8 | M: 5 con 3 letture | 9: nessun errore stabile (contro S12r4); sotto 5 non può andare se `B0` e i placebo non sono un caso |
| 5 | studi con gruppi identici ai curatori in `B0` che sono segnalati (su 36) | 11 | da 7 a 15 | G; M: 7 con 3 letture | sopra 15: quasi metà degli studi giusti è segnalata, il costo di rileggerli è alto |
| 6 | esito della regola (§4) | **no**: la condizione (a) non vale, la (b) vale | — | G, dalla tabella di `01-carta.md` §6 punto 4 | «sì»: la discordanza separa gli studi con errore dagli altri più di quanto prevedo; si riporta con l'intervallo |
| 7 | errori che costano il cui stato cambia fra le 9 letture (su 4) | 2 (`GSE60340`, `GSE49155`) | da 2 a 3 | M: questi due cambiano sotto un placebo; `GSE57945` cambia in S12r4 solo con un cambio di forma | 4: anche l'errore in 31 forme su 31 si muove; 0 o 1: i placebo di S12r4 erano un caso |
| 8 | `GSE46665`, sigle dei pazienti come malattie: letture in cui è presente (su 9) | 9 | 9 | M: presente in 31 forme su 31 | sotto 9: l'errore «del modello» di S12r4 non è stabile |
| 9 | studi segnalati aggiunti in media passando da 5 a 9 letture | 3 | da 1 a 5 | G | sotto 1: dopo 5 letture altre letture non aggiungono; sopra 5: 9 letture non bastano a dire quanti studi sono instabili |
| 10 | confronti ritrovati su 95, in ognuna delle 8 letture nuove | da 64 a 74 | tutte e 8 fra 64 e 74 | M: 68, 71, 69 in `B0` e nei placebo; G per il margine | una lettura fuori: una frase riscritta «senza cambiare il senso» cambia la misura quanto un cambio di forma; quella riscrittura si rilegge |
| 11 | studi con un errore di lettura nuovo (§6: un'etichetta che `B0` non ha in quello studio), per ogni lettura nuova: mediana fra le 8 | 2 | da 0 a 4 | M: 4 e 1 con i due placebo, contati per etichetta dalle letture di S12r4 | sopra 4: ogni lettura in più porta errori suoi; l'insieme degli errori cresce col numero di letture |
| 12 | fra gli studi segnalati, quelli in cui la discordanza tocca un errore di lettura (§6) | 65% | da 50% a 85% | G; M: 9 su 13 con 3 letture (etichette di S12r4, 2 studi senza etichetta) | sotto 50%: più di metà delle segnalazioni viene dalla forma o da letture tutte e due difendibili; sopra 85%: quasi ogni segnalazione è un errore di lettura in almeno una lettura |

**Lettura di un esito.** I 47 studi sono tutti gli studi di sviluppo e le corse sono ripetibili: un conteggio non ha
errore di misura e si confronta direttamente con l'intervallo. L'incertezza sugli studi (ricampionamento) si riporta
accanto e riguarda la generalizzazione. La previsione 6 si giudica sull'esito della regola.

**Che cosa non può uscire.** Gli studi segnalati crescono o restano uguali quando si aggiunge una lettura: con 9
letture non possono essere meno di quelli che una sola lettura nuova distingue da `B0`.

**Non previsto, dichiarato:** quale lettura muove quale studio; i conti con le chiavi da sole; il conto a 11 letture.
Si misurano e si riportano come esplorativi.

## 3. La regola sulla discordanza

**Su che cosa si confrontano le letture.** Per ogni studio e ogni lettura si calcola una chiave di tre parti:

1. **la tabella dei fattori**: la firma di S12r4 (per ogni fattore il tipo, le colonne di fonte, la partizione dei
   campioni nei livelli e quale livello è la base; più le colonne coi soggetti). Non entrano i nomi dei fattori e dei
   livelli, le entità, le dosi, le prove citate e i ruoli delle altre colonne. Una lettura senza un'uscita valida ha
   la chiave «senza tabella»;
2. **i gruppi**: gli insiemi di campioni che il costruttore forma; uno studio non chiuso ha la chiave «non chiuso»;
3. **i confronti**: le coppie (campioni trattati, campioni di controllo) che il costruttore forma.

Due letture sono **concordi** se hanno le tre parti uguali. Il motivo delle tre parti sta in `01-carta.md` §7.

**Quando uno studio è segnalato.** Uno studio è **segnalato** se le 9 letture hanno due o più chiavi distinte. Non
c'è una soglia sul numero di letture discordi: ne basta una.

**Che cosa la regola non fa.** Segnala soltanto. Non sceglie una lettura, non vota, non corregge e non usa i
curatori. Che cosa fare di uno studio segnalato lo decide il PI.

**Come si conta «la discordanza segnala un errore».** Conto principale, per studio: un errore di `B0` è segnalato se
il suo studio è segnalato. Accanto, per errore: lo stato dell'errore (presente, assente, senza tabella; i 9 predicati
del cancello 2) non è uguale nelle 9 letture. Un errore con lo stato che cambia sta per costruzione in uno studio
segnalato; un errore in uno studio non segnalato è presente uguale in tutte le letture.

**Accanto, senza peso nell'esito:** la stessa regola con ogni parte della chiave da sola.

## 4. La regola di esito

«**La discordanza segnala gli errori di lettura: sì**» se valgono tutte e due:

- **(a)** la quota di studi segnalati fra gli 8 studi con un errore di `B0` è più alta della quota fra gli altri 39,
  e l'intervallo al 95% della differenza (ricampionamento degli studi, B = 2.000, seme 20261112) sta tutto sopra
  zero;
- **(b)** almeno 3 dei 4 studi con un errore che costa sono segnalati.

Altrimenti l'esito è «**no**». Insieme all'esito si riportano sempre: gli errori **non** segnalati, uno per uno; gli
studi segnalati con gruppi identici ai curatori; la forza della regola (`01-carta.md` §6 punto 4). L'esito «sì» non
vuol dire che la regola basta: un errore in uno studio non segnalato resta, e il PI ha stabilito che nessun errore si
accetta.

## 5. Conti accanto, dichiarati prima

- **Andamento col numero di letture.** Per k da 0 a 8 letture nuove aggiunte a `B0`: media, minimo e massimo, su
  tutti i sottoinsiemi di k letture, di studi segnalati, studi con errore segnalati (su 8), studi con un errore che
  costa segnalati (su 4), studi con gruppi identici in `B0` segnalati. In più l'ordine fisso `L1`…`L8`. Il numero
  della sessione è quello a 9 letture: non si sceglie un k.
- **11 letture:** le 9 più i due placebo di S12r4 (`01-carta.md` §4).
- **Per lettura:** studi chiusi, gruppi identici, confronti ritrovati, studi con la chiave diversa da `B0`.

## 6. La lettura dei disaccordi

**Che cosa si legge: tutto.** Ogni coppia (studio, lettura nuova) con la chiave diversa da `B0`. Le coppie con la
stessa chiave nello stesso studio fanno una scheda sola. Nessun campione.

**Che cosa riceve ogni scheda**, leggendo il testo dello studio, la tabella dei campioni, la lettura di `B0` e la
lettura nuova:

- **causa della differenza**, una fra:
  - *lettura del modello*: `B0` o la lettura nuova legge male il testo o la tabella (un fattore sbagliato, mancante o
    di troppo; un livello o una base sbagliati; un soggetto sbagliato);
  - *forma*: la lettura è la stessa, ma l'uscita è scritta in un modo che lo schema o il costruttore non legano;
  - *non errore*: le due letture sono diverse e tutte e due difendibili sul testo;
- **dove sta l'errore**: in `B0`, nella lettura nuova, in tutte e due, in nessuna;
- **le etichette degli errori di lettura presenti nella lettura nuova**: una delle 9 di `B0`, una già usata in S12r4,
  o una nuova (`GSE…:descrizione`). Un errore è **nuovo** se `B0` non ha quell'etichetta in quello studio (conto per
  etichetta).

Dove la stessa tabella dei fattori è già stata letta in S12r4, la scheda mostra l'etichetta di allora. È un punto di
partenza: la scheda si rilegge comunque.

**Classe di uno studio segnalato**, dalle sue schede e dagli stati dei 9 errori:

- *tocca un errore di lettura*: almeno una scheda ha causa «lettura del modello», oppure lo stato di un errore di
  `B0` cambia fra le letture;
- *forma*: nessuna scheda di lettura, almeno una di forma;
- *non errore*: tutte le schede sono «non errore».

**Chi legge.** L'agente legge tutte le schede. Poi un agente indipendente, che non vede le mie etichette, rilegge
tutte le schede dal materiale congelato fuori dal repository. I disaccordi fra i due si riportano uno per uno. È un
audit interno: nessuna etichetta entra nella pipeline.

## 7. Che cosa NON cambia dopo i numeri

Le 8 frasi e le riscritture; il numero di letture del conto principale (9); la chiave a tre parti; la definizione di
«segnalato»; i 9 errori e gli 8 studi; le condizioni (a) e (b); B e seme; il conto per etichetta; le classi della
lettura; gli intervalli delle previsioni. Un conto dichiarato dopo i numeri si scrive nel finding con queste parole:
«dichiarato dopo i numeri».

Se una corsa fallisce due volte, la sessione si ferma. Se un cancello fallisce, la sessione non vale e si dice.
