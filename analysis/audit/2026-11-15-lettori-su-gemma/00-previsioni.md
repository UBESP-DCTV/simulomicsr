# I lettori locali sugli studi curati da Gemma (UBC), parte aperta. Carta e previsioni

Depositato il 2026-11-15, **prima** di ogni corsa di un modello sugli studi di Gemma. Dopo i numeri questo file non
cambia. Quando scrivo, le viste e gli schemi degli studi di Gemma non esistono ancora (lo scarico dei testi GEO è
in corso): anche le previsioni sulla copertura (P1, P2) sono scritte prima di vederle.

## La domanda

Il PI ha ripreso il lavoro il 2026-11-15 e ha fissato come riferimento le curazioni umane di Gemma e di Expression
Atlas. Sui 21 studi di sviluppo curati da tutti e due, i curatori fra loro concordano quanto il lettore con uno di
loro (`docs/findings/2026-11-15-gemma-curatori-contro-curatori.md`). Ma 21 studi sono pochi e sono serviti a sei
prove. La domanda è: **su circa 2.000 studi mai visti, il lettore dello studio (Mistral-Small 3.2 nella forma `B0`)
dà i gruppi e i confronti dei curatori di Gemma in quanti studi?** In più: l'accordo fra due lettori locali segnala
gli studi dove il lettore non concorda con i curatori?

## L'oggetto

- Gli studi di Gemma con una tabella dell'adattatore depositato (`analysis/audit/2026-11-15-gemma-riferimento/`,
  regole 1-7 della sua carta, senza cambi): **3.015 studi GEO, 3.086 voci** (`21-divisione.csv`). Nessuno studio di
  giudizio e nessuno studio di sviluppo. Gli 82 studi di giudizio di Atlas restano chiusi.
- **La divisione** (`21-divisione.R`, regola per costruzione sul numero GEO): **parte aperta 2.024 studi** (2.075
  voci), **parte chiusa 991 studi** (1.011 voci). Sulla parte chiusa nessun modello gira e niente si misura fino a
  una decisione del PI. Questa carta vale per la parte aperta.
- **La vista** dello studio è la vista v0 dei 47 studi di sviluppo, con lo stesso programma (`20-vista-v0.R`): i
  testi GEO congelati il 2026-11-15 e i campioni dello studio che stanno nel bacino di ARCHS4.
- **Il lettore**: Mistral-Small 3.2, forma `B0` (prompt v2, schema delle uscite a elenco chiuso generato per ogni
  studio, `22-schemi-b0.R`), parametri della terza prova (S12r3): `temperature` 0, `repetition_penalty` 1,1,
  `max_model_len` 65536, `max_tokens` 24576, `VLLM_BATCH_INVARIANT=1`, vLLM 0.20.2, solo `poddgx02`
  (`40-lancia.R`, corse `M-rp11` e la replica `M-rp11r`).
- **Il secondo lettore**: il candidato locale che la regola di `analysis/audit/2026-11-15-secondo-lettore/00-previsioni.md`
  ammette, nella corsa che quella regola sceglie. Se la regola non ammette nessun candidato, le misure m7 e m8 non
  si fanno e lo dico.
- **Il riferimento** di una voce: i gruppi dei fattori di Gemma e i confronti che il costruttore del pacchetto forma
  dalla tabella di Gemma (`30-misura-contro-gemma.R`). L'universo di una voce sono i campioni di Gemma che stanno
  nella vista.

## Che cosa ho già visto

- Dei disegni di Gemma: i conti dell'adattatore su tutte le voci (fattori, gruppi, confronti), anche della parte
  chiusa. Non ho letto i disegni uno per uno, tranne quelli dei 21 studi di sviluppo.
- Il controllo positivo della misura (Gemma contro Gemma) su 3.107 voci: gruppi identici 3.107, confronti ritrovati
  10.681 su 10.681, non elencati 0 (`31-out-controllo-positivo.txt`).
- **La taratura sui 21 studi di sviluppo** (`31-out.txt`), riferimento Gemma: Mistral `B0` ha gruppi identici in
  14/21 (IC95 48-86%) e ritrova 26/52 confronti (IC95 23-86%); i curatori di Atlas letti contro Gemma: 12/21 (38-76%)
  e 30/52 (28-93%). Confronti del lettore non elencati da Gemma e giudicati errore: 19/41, di cui 16 in `GSE57945`.
- Nessuna uscita di un modello su uno studio di Gemma esiste.

## Cancelli

1. **K1, riproduzione e controllo positivo.** Mistral `B0` sui 47 studi di sviluppo ridà 45 chiusi, 36/47, 68/95
   contro Atlas. La misura Gemma contro Gemma passa su tutte le voci con una tabella.
2. **K2, oggetto.** Il programma della vista ridà le 47 viste di sviluppo uguali byte per byte. Il generatore dello
   schema ridà le 47 impronte del lancio del secondo lettore. L'ingresso ha l'impronta di `22-ingresso-sha256.txt`.
   Prompt, generatore, divisione e programma di lancio sono uguali ai file committati.
3. **K3, copertura.** Ognuno dei 2.024 studi aperti ha un esito: misurato, oppure un motivo con codice (senza vista,
   senza colonne non costanti, oltre il contesto, non chiuso). La somma degli esiti è 2.024. Niente si taglia.
4. **K4, ambiente.** Ogni job gira su `poddgx02`. Le variabili d'ambiente chieste si leggono nel contenitore.
   `generation.json` è quello atteso. Ogni worker dichiara lo schema per record. Le uscite si congelano con SHA-256.
5. **K5, parti chiuse.** Nell'ingresso e nelle uscite non c'è nessuno studio della parte chiusa di Gemma, nessuno
   studio di giudizio, nessuno studio di sviluppo.

## Misure (parte aperta; unità del ricampionamento: lo studio GEO; B = 10.000; seme 20261115)

- m1: studi aperti con una vista su 2.024; studi mandati al modello su quelli con una vista (escono: senza colonne
  non costanti, oltre il contesto).
- m2: studi chiusi dal lettore su quelli mandati al modello.
- m3: voci con gruppi identici a Gemma su voci misurate (le voci degli studi mandati al modello; uno studio non
  chiuso conta come non identico). Accanto le classi: più fine, più grossa, incrociata.
- m4: confronti di Gemma ritrovati (stessi due insiemi, stesso verso) sul totale. Accanto: in ogni verso.
- m5: confronti del lettore non elencati da Gemma e giudicati errore, su quelli giudicabili.
- m6: replica. Studi con l'uscita uguale al carattere fra `M-rp11` e `M-rp11r`; studi con gli stessi gruppi e gli
  stessi confronti.
- m7 (con un secondo lettore ammesso): studi tenuti = i due lettori danno gli stessi gruppi e gli stessi confronti,
  sul totale degli studi mandati al modello.
- m8 (con un secondo lettore ammesso): quota di voci con gruppi identici a Gemma fra gli studi tenuti meno la stessa
  quota fra gli studi non tenuti, con IC 95%.
- Accanto, senza previsione: m3 e m4 per classi di grandezza dello studio (fino a 12 campioni, 13-48, oltre 48) e
  per numero di fattori di Gemma (1, 2, 3 o più).

## Previsioni

Da dove vengono i margini: P3, P4 e P5 dalla variabilità misurata nella taratura (gli intervalli al 95% sui 21 studi
di sviluppo, del lettore e dei curatori di Atlas contro Gemma). P6 da una soglia del progetto (la pipeline è
deterministica). P1, P2, P7 e P8 sono un giudizio motivato: lo dico al PI.

| # | quantità | atteso | intervallo di rilevanza | motivo |
|---|---|---|---|---|
| P1 | m1, studi mandati al modello su 2.024 aperti | 96% | 90-100% | sui 47 di sviluppo 47 su 47; studi con una sola condizione e studi molto grandi esistono in Gemma |
| P2 | m2, chiusi su mandati al modello | 93% | 88-98% | 45/47 sui 47 di sviluppo, scelti su quegli studi; sotto 88% il lettore perde più di uno studio su otto |
| P3 | m3, gruppi identici a Gemma | 55% | 45-67% | taratura 14/21, ma su studi già usati; i curatori di Atlas contro Gemma 12/21. Sotto 45% il lettore sta sotto l'accordo fra curatori; sopra 67% sta sopra |
| P4 | m4, confronti di Gemma ritrovati | 40% | 28-58% | taratura 26/52; i curatori di Atlas 30/52 (58%) |
| P5 | m5, errori fra i non elencati giudicabili | 20% | 5-35% | taratura 19/41, ma 16 errori sono di un solo studio; senza quello 3/23 |
| P6 | m6, replica uguale al carattere | 100% | 99-100% | tre repliche uguali 47/47 con `VLLM_BATCH_INVARIANT=1`; oltre l'1% di studi diversi la pipeline non è ripetibile |
| P7 | m7, studi tenuti dall'accordo fra due lettori | 60% | 50-75% | la regola del secondo lettore chiede 30/47 (64%) sugli studi di sviluppo |
| P8 | m8, differenza fra tenuti e non tenuti | +25 punti | IC tutto sopra 0 | se l'intervallo tocca 0, l'accordo fra lettori non segnala il disaccordo con i curatori |
| P9 | classi di m3 | «più fine» più frequente di «più grossa» | differenza con IC sopra 0 | taratura 4 contro 2; il lettore tiene fattori che Gemma non cura (donatore, lotto) |

**Che cosa cambia.** P3 e P4 dentro l'intervallo: l'articolo può scrivere che il lettore concorda con un curatore
quanto due curatori fra loro, con un numero su circa 2.000 studi. P3 sotto 45%: il lettore è sotto i curatori e la
pipeline su tutto ARCHS4 non parte con un solo lettore. P8 confermata: l'accordo fra due lettori locali è il filtro
da portare su tutto ARCHS4, e m7 dice quanti studi restano. P8 non confermata: il filtro non ha una base. P6 smentita:
niente va su tutto ARCHS4 prima di una diagnosi.

## Limiti dichiarati prima

- Un disaccordo con Gemma non è un errore del lettore: può essere una scelta del curatore (un fattore in più, livelli
  uniti, un'altra base). Questa carta misura l'accordo. La lettura dei disaccordi è un passo dopo, con la sua carta.
- I confronti di Gemma sono quelli del nostro costruttore sulla sua tabella, non i contrasti del suo modello lineare.
  L'adattatore non dà una base ai fattori di tempo e di contesto: un confronto del lettore con una base di tempo è
  un «non elencato».
- Gli studi di Gemma non sono un campione a caso di ARCHS4: sono studi che un curatore ha scelto e chiuso. Il numero
  su tutto ARCHS4 può essere più basso.
- La forma `B0` e il modello sono stati scelti sui 47 studi di sviluppo. Qui non si sceglie niente: una sola forma,
  un solo primo lettore. Se dopo questi numeri qualcosa cambia, la conferma è la parte chiusa.
- L'accordo fra lettori toglie studi, non li corregge, e non vede gli errori che i due lettori fanno uguali.
- La vista contiene solo i campioni del bacino di ARCHS4. I campioni di Gemma fuori dalla vista si contano.
- La regola «nessun Claude nella pipeline» resta. Le letture dei modelli Claude sugli stessi studi sono un termine
  di misura, con una carta loro e dentro il limite di 99 dollari.
