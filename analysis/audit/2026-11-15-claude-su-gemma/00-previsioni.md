# I modelli Claude sugli studi curati da Gemma (UBC), parte aperta. Carta e previsioni

Depositato il 2026-11-15, **prima** di ogni chiamata all'API con il testo di uno studio di Gemma. Dopo i numeri
questo file non cambia. È la carta che `analysis/audit/2026-11-15-lettori-su-gemma/00-previsioni.md` annuncia
nell'ultimo limite: le letture dei modelli Claude sono un **termine di misura**, dentro il limite di spesa del PI.
**Niente di questa prova entra nella pipeline.** La regola «nessun Claude nella pipeline né nella validazione
pubblicata» resta scritta.

## La domanda

Mistral-Small 3.2 (forma `B0`) dà i gruppi dei curatori di Gemma nel 67,1% delle voci della parte aperta e ritrova
il 46,7% dei loro confronti (`../2026-11-15-lettori-su-gemma/41-out.txt`). Tre domande:

1. **Il modello più forte che abbiamo (Claude Opus 5.5) concorda con i curatori più di Mistral?** Se no, la distanza
   dai curatori non dipende dalla capacità del modello. Se sì, la differenza è lo spazio che un modello locale
   migliore può recuperare.
2. **Il Claude che costa meno (Haiku 5.5) concorda con i curatori quanto Opus?** È la domanda del PI sul costo.
3. **L'accordo fra Mistral e un Claude segnala i disaccordi con i curatori quanto l'accordo fra i due lettori
   locali?** Serve a sapere se il secondo lettore locale (Gemma-4-31B) perde qualcosa rispetto a un modello forte.

## L'oggetto

- **Gli studi:** i 2.016 studi della parte aperta nell'ingresso congelato
  `analysis/input/gemma-b0-ingresso-aperta.jsonl` (impronta in `../2026-11-15-lettori-su-gemma/22-ingresso-sha256.txt`).
  Del record si usa **solo il campo `testo`** (la vista v0). La parte chiusa (991 studi), gli 82 studi di giudizio di
  Atlas e i 47 studi di sviluppo non entrano in nessuna richiesta.
- **La forma:** la forma V della prova del 2026-11-14 (S12r6), senza cambi. Sistema: il prompt v1
  (`analysis/audit/2026-11-10-S12r2-prova-ripetuta/21-prompt-v1.md`). Utente: il testo dello studio. L'API vincola
  l'uscita allo schema v1 (`20-schema-v1.json`). Impostazioni: `output_config.effort` = "high", ragionamento di
  default, nessuna `temperature`, `max_tokens` 64000. L'adattatore è `A0` (S12r4). Motivo della forma: sui 47 studi
  di sviluppo è la forma dove Opus sbaglia meno, e l'API non accetta lo schema `B0` come vincolo. **Una sola forma
  per tutti i modelli Claude.**
- **I modelli e le corse:**
  - Haiku 5.5 (`claude-haiku-5-5`): tutti i 2.016 studi, **due corse** (la seconda misura la ripetibilità);
  - Opus 5.5 (`claude-opus-5-5`): tutti i 2.016 studi, una corsa;
  - Sonnet 5.5 (`claude-sonnet-5-5`): i primi N pezzi dell'ordine qui sotto, una corsa, con N secondo la regola di
    spesa. Fable 5.1 non si corre: costa 2,5 volte Opus e sui 47 studi ha rifiuti.
- **L'ordine per costruzione:** gli studi in ordine crescente dello SHA-256 del numero GEO, in **8 pezzi da 252**.
  I primi cinque: `GSE144208`, `GSE195877`, `GSE57871`, `GSE141756`, `GSE197959`.
- **Il riferimento e la misura:** quelli della carta dei lettori locali (`30-misura-contro-gemma.R`), senza cambi.
  Mistral `B0` è la corsa congelata `M-rp11`, Gemma-4-31B la corsa `GE-rp0`.

## La regola di spesa

- **Tetto di questa prova: 75 dollari.** Il limite del PI per tutte le prove nuove è 99 dollari. I 24 che restano
  coprono una coda di uscite lunghe che la proiezione non vede, e le prove che seguono.
- La spesa si conta dal campo `usage` di ogni risposta, al prezzo di listino per milione di token (ingresso,
  uscita): Haiku 0,10 e 0,50 (0,50 e 2,50 se l'ingresso supera 100.000 token), Sonnet 2 e 10, Opus 4 e 20. Le
  richieste a lotti (Batch API) costano la metà.
- **Strada:** richieste a lotti, un lotto per pezzo e per corsa. Se la chiave non ammette i lotti: richieste in
  tempo reale con il flusso, come il 2026-11-14; allora Opus legge solo i primi pezzi che stanno nel tetto e Sonnet
  non si corre.
- **Ordine dei lanci.** Prima onda: Haiku corsa 1 e corsa 2 (tutti i pezzi), Opus pezzo 1, Sonnet pezzo 1. Seconda
  onda: i pezzi 2-8 di Opus, solo se spesa + 7 × costo del pezzo 1 di Opus × 1,25 ≤ 75. Terza onda: i pezzi di
  Sonnet dal 2 in su, il numero più grande di pezzi interi per cui spesa + proiezione (costo del pezzo 1 × 1,25 per
  pezzo) ≤ 75. Un pezzo lanciato si misura sempre, anche se costa più della proiezione.
- Proiezione scritta prima (dai token misurati sui 47 studi di sviluppo; ingresso stimato 13,6 milioni di token
  per corsa): Haiku circa 3 dollari per corsa, Opus circa 53, Sonnet circa 27 per tutti gli studi, con i lotti.
- **Tempo:** la chiave scade il 2026-11-16 verso le 20 (ora italiana). Un lotto non finito alle 18 del 2026-11-16
  si annulla, e le sue risposte arrivate si tengono. Uno studio senza risposta ha l'esito `senza_risposta`.
- Uno studio con una risposta intera non si chiama una seconda volta nella stessa corsa. Un errore della richiesta
  (400) è l'esito `saltato`. Una richiesta scaduta o fallita per il servizio si rimanda una volta sola.
- La chiave sta solo in `.Renviron.local` (non tracciato). Non entra in nessun file, registro o messaggio. A prova
  finita la riga si toglie.

## Che cosa ho già visto

- Le misure di Mistral `B0` e di Gemma-4-31B sugli stessi 2.016 studi contro i curatori di Gemma (`41-out.txt`):
  numeri d'insieme, per grandezza e per numero di fattori. Non ho letto i disaccordi uno per uno.
- Le uscite dei modelli Claude sui 47 studi di sviluppo (S12r6), con i loro errori di lettura.
- **La taratura** (`10-out.txt`, nessuna chiamata): le uscite congelate dei Claude nella forma V sui 21 studi di
  sviluppo con un disegno di Gemma, contro Gemma. Gruppi identici: Opus 16/21 nelle due corse, Sonnet 16 e 17,
  Haiku 16 e 16; Mistral `B0` 14/21. Confronti ritrovati su 52: Opus 29 e 29, Sonnet 27 e 27, Haiku 29 e 25;
  Mistral 26. Non elencati giudicati errore: Opus 15/38 e 15/35. Stessi gruppi e stessi confronti fra due corse
  (47 studi): Haiku 39, Opus 45, Sonnet 46. Mistral `B0` uguale a Opus: 34 e 33 su 47.
- Nessuna uscita di un modello Claude su uno studio di Gemma esiste.

## Cancelli

1. **KC1, riproduzione.** Il codice della misura per la forma V ridà i numeri del 2026-11-14 contro Atlas sulle
   corse congelate (Opus corsa 1: 47 chiusi, 38/47, 72/95). La misura di Mistral `M-rp11` contro Gemma ridà 1.377
   voci identiche su 2.052 e 3.198 confronti su 6.850.
2. **KC2, oggetto.** Ingresso, prompt v1 e schema v1 hanno le impronte SHA-256 congelate. Ogni richiesta porta
   solo il prompt v1, il testo dello studio e lo schema v1.
3. **KC3, copertura.** In ogni corsa intera ognuno dei 2.016 studi ha un esito: misurato, non chiuso (con il
   motivo), saltato, senza risposta. Niente si taglia. Le uscite si congelano con SHA-256.
4. **KC4, spesa.** La spesa contata da `usage` è al massimo 75 dollari.
5. **KC5, parti chiuse e chiave.** Nelle richieste e nelle uscite non c'è nessuno studio della parte chiusa di
   Gemma, di giudizio o di sviluppo. La chiave non sta in nessun file tracciato o scritto dalla prova.

## Misure (unità del ricampionamento: lo studio GEO; B = 10.000; seme 20261115)

Per ogni corsa, le misure m2-m5 della carta dei lettori locali, sugli studi mandati al modello:

- c2: studi chiusi sul totale degli studi con una risposta richiesta;
- c3: voci con gruppi identici a Gemma (uno studio non chiuso, saltato o senza risposta conta come non identico),
  con le classi più fine, più grossa, incrociata;
- c4: confronti di Gemma ritrovati; c5: confronti non elencati giudicati errore, su quelli giudicabili;
- c6: differenza appaiata con Mistral `B0` in c3 e in c4, sulle voci degli studi che tutti e due hanno ricevuto;
- c7: fra due corse o due modelli Claude, studi con gli stessi gruppi e gli stessi confronti;
- c8: studi tenuti dall'accordo fra Mistral `B0` e un Claude (stessi gruppi e stessi confronti), e quota di voci con
  gruppi identici a Gemma fra i tenuti e fra i non tenuti; lo stesso per l'accordo a tre (Mistral, Gemma-4-31B, Opus);
- accanto, senza previsione: c3 e c4 per grandezza dello studio e per numero di fattori di Gemma; le voci dove
  Mistral e Opus hanno gli stessi gruppi e Gemma no (servono alla lettura dei disaccordi, che ha la sua carta);
  token, spesa, motivi di fine, rifiuti.

## Previsioni

Da dove vengono i margini. **±5 punti per «lo stesso livello»:** è la variabilità misurata fra due corse dello
stesso modello Claude sui 47 studi di sviluppo (i gruppi identici ad Atlas cambiano di 0-2 studi su 47, cioè fino a
4,3 punti). PC1, PC2, PC4, PC5, PC8, PC9 sono un giudizio motivato dalla taratura: lo dico al PI.

| # | quantità | atteso | intervallo di rilevanza | motivo |
|---|---|---|---|---|
| PC1 | c2, Opus: studi chiusi | 97% | 93-100% | sviluppo 47/47 due volte; lo schema v1 non è generato per studio e gli studi grandi di Gemma (fino a 632 campioni) non sono mai stati provati; sotto 93% Opus chiude meno di Mistral (93,6%) |
| PC2 | c3, Opus: gruppi identici a Gemma | 72% | 62-80% | taratura 16/21 contro 14/21 di Mistral, che qui ha 67,1% |
| PC3 | c6, Opus meno Mistral nei gruppi identici | +4 punti | da −5 a +5 | IC tutto dentro: stesso livello, la distanza dai curatori non è del modello. IC tutto sopra +5: Opus legge meglio |
| PC4 | c4, Opus: confronti ritrovati | 52% | 40-62% | taratura 29/52 contro 26/52; Mistral qui 46,7% |
| PC5 | c5, Opus: non elencati giudicati errore | 30% | 15-45% | taratura 15/38, in gran parte un solo studio; Mistral qui 28,7% |
| PC6 | c3, Haiku corsa 1 meno Opus, appaiata | −2 punti | da −5 a +5 | taratura 16/21 tutti e due. IC tutto dentro: il modello che costa un quarantesimo legge come Opus |
| PC7 | c3, Sonnet meno Opus, appaiata sugli studi di Sonnet | 0 punti | da −5 a +5 | taratura 16-17/21 contro 16/21 |
| PC8 | c7, Haiku: stessi gruppi e confronti fra le due corse | 80% | 70-90% | sviluppo 39/47 (83%); gli studi di Gemma sono in media più grandi nella coda |
| PC9 | c8, studi tenuti dall'accordo Mistral = Opus | 65% | 55-78% | sviluppo 33-34/47 (71%); Mistral = Gemma-4-31B qui tiene il 66,6% |
| PC10 | c8, gruppi identici a Gemma fra i tenuti da Mistral = Opus, meno la stessa quota fra i tenuti da Mistral = Gemma-4-31B (82,2%) | +2 punti | da −5 a +5 | IC tutto dentro: il secondo lettore locale filtra come un modello forte. IC tutto sopra +5: il filtro locale perde |
| PC11 | c8, tenuti meno non tenuti, accordo Mistral = Opus | +40 punti | IC tutto sopra 0 | con Gemma-4-31B +43,9 |

**Che cosa cambia.** PC3 dentro l'intervallo: l'articolo può dire che un modello locale da 24 miliardi di parametri
concorda con i curatori quanto il modello più forte provato, e la parte che resta è dei curatori o del compito. PC3
sopra +5: la differenza va scritta come limite del modello locale, e la ricerca di un lettore locale migliore ha
uno spazio misurato. PC6 dentro: una lettura di tutto ARCHS4 con Haiku come termine di misura costa poche decine di
dollari. PC10 dentro: il filtro per tutto ARCHS4 resta l'accordo fra i due lettori locali.

## Limiti dichiarati prima

- Claude legge nella forma V (prompt v1, schema v1 vincolato) e Mistral nella forma `B0` (prompt v2, schema a elenco
  chiuso per studio). Ogni modello sta nella forma dove ha fatto meglio sui 47 studi di sviluppo. La differenza fra
  i modelli e la differenza fra le forme non si separano qui.
- I modelli Claude non ripetono la stessa uscita. Opus e Sonnet hanno una corsa sola: il numero porta anche la
  variabilità fra corse, che per Haiku si misura.
- Le richieste a lotti e le richieste in tempo reale usano lo stesso modello, ma non l'ho verificato con una misura.
- Un disaccordo con Gemma non è un errore del lettore. Vale per Claude come per Mistral.
- Gli 8 studi che Mistral non riceve perché oltre il suo contesto arrivano ai Claude: stanno nei numeri dei Claude
  e fuori dai confronti appaiati.
- Sonnet legge una parte degli studi: i suoi numeri hanno un intervallo più largo e valgono per quei pezzi.
- Chi scrive le previsioni e legge i risultati è un modello Claude. La misura è un programma deterministico.
