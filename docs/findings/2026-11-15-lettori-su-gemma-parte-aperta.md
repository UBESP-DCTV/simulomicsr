---
type: Finding
title: "I lettori dello studio su 2.016 studi curati da Gemma (UBC) e mai visti: Mistral, Gemma-4-31B e i Claude come termine di misura"
description: "Sulla parte aperta degli studi di Gemma, Mistral-Small 3.2 (forma B0) ha i gruppi dei curatori nel 67,1% delle voci e ritrova il 46,7% dei loro confronti; i Claude stanno al 72-73% e al 51-57%. L'accordo fra due lettori locali tiene il 66,6% degli studi, con gruppi identici ai curatori nell'82,2% delle voci contro il 38,3% degli altri."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-15T22:00:00+01:00}
sources:
- {id: carta-locali, resource: "analysis/audit/2026-11-15-lettori-su-gemma/00-previsioni.md", title: "Carta dei lettori locali: cancelli K1-K5, misure m1-m8, previsioni P1-P9"}
- {id: misura-locali, resource: "analysis/audit/2026-11-15-lettori-su-gemma/41-out.txt", title: "La misura di Mistral B0 (corse M-rp11 e M-rp11r) e di Gemma-4-31B (GE-rp0) contro i curatori di Gemma"}
- {id: secondo, resource: "analysis/audit/2026-11-15-secondo-lettore/24-out.txt", title: "La regola di scelta del secondo lettore sui 47 studi di sviluppo"}
- {id: carta-claude, resource: "analysis/audit/2026-11-15-claude-su-gemma/00-previsioni.md", title: "Carta dei Claude: regola di spesa, cancelli KC1-KC5, misure c2-c8, previsioni PC1-PC11"}
- {id: misura-claude, resource: "analysis/audit/2026-11-15-claude-su-gemma/30-out.txt", title: "La misura delle quattro corse dei Claude, i confronti appaiati e l'accordo come filtro"}
- {id: corse-claude, resource: "analysis/audit/2026-11-15-claude-su-gemma/30-corse.csv", title: "Una riga per corsa: studi, esiti, token, dollari"}
- {id: lotti, resource: "analysis/audit/2026-11-15-claude-su-gemma/20-lotti.jsonl", title: "Il registro dei lotti mandati all'API"}
- {id: curatori, resource: "docs/findings/2026-11-15-gemma-curatori-contro-curatori.md", title: "Curatori contro curatori sui 21 studi di sviluppo"}
---

# In breve

## In breve: su duemila studi mai visti, il lettore dello studio forma i gruppi e i confronti dei curatori di Gemma?

**A cosa serviva.** I curatori di Gemma (UBC) hanno scritto a mano il disegno di circa 3.000 studi del nostro bacino. Abbiamo
tenuto chiuso un terzo di questi studi e abbiamo fatto leggere gli altri 2.016 ai nostri modelli, senza cambiare niente
del lettore. Serve a sapere se il lettore dà il disegno dei curatori su studi mai usati, e con quale regola portarlo su
tutto ARCHS4.

**Cosa abbiamo trovato.**

1. **Il modello locale forma gli stessi gruppi dei curatori in due voci su tre.** Mistral ha i gruppi dei curatori in 1.377
   voci su 2.052 (67%) e ritrova 3.198 dei loro 6.850 confronti (47%). Chiude 1.879 studi su 2.008 e due corse danno la
   stessa uscita in 2.016 studi su 2.016. Sui 21 studi curati due volte, due gruppi di curatori concordavano in 15 studi.
2. **I modelli Claude arrivano al 72-73% e nessuno va oltre.** Haiku ha gruppi identici ai curatori nel 72,5% delle voci,
   Sonnet nel 72,9%, Opus nel 71,6% dei 252 studi che ha letto. Sono circa 6 punti più di Mistral sugli stessi studi.
   Tre modelli di forza molto diversa si fermano allo stesso punto: la parte che resta non dipende dalla forza del modello.
3. **Quando due lettori locali concordano, i gruppi sono quelli dei curatori in più di quattro voci su cinque.** Mistral e
   il secondo modello locale danno gli stessi gruppi e gli stessi confronti in 1.337 studi su 2.008 (67%). In questi studi i
   gruppi sono quelli dei curatori nell'82% delle voci. Negli altri studi lo sono nel 38%.
4. **Un Claude al posto del secondo modello locale non filtra meglio.** Con Sonnet come secondo lettore i gruppi sono quelli
   dei curatori nell'83% delle voci tenute, con Haiku nell'84%, con il modello locale nell'82%. Il filtro può restare tutto
   locale.
5. **L'accordo con i curatori cala negli studi grandi.** Fino a 12 campioni Mistral ha i gruppi dei curatori nel 79% delle
   voci, oltre 48 campioni nel 39%. Sonnet passa dall'85% al 50%. Dove il lettore e i curatori non concordano, il lettore
   forma più spesso gruppi più fini (15% delle voci) che gruppi più grossi (8%).

**Cosa devi decidere.** Niente adesso. La scelta sul passaggio a tutto ARCHS4 arriva con la lettura dei disaccordi, che dice
quanti sono errori del lettore e quanti sono scelte dei curatori.

**Comunque.** Leggiamo i disaccordi fra il lettore e i curatori di Gemma, con le previsioni scritte prima. La parte chiusa
di Gemma (991 studi) resta chiusa. Le prove con i Claude sono costate 42,21 dollari su 99. Opus ha letto solo 252 studi,
perché la regola di spesa scritta prima lo ha fermato. Ho tolto la chiave dal disco: puoi cancellarla.

Non c'è nulla da decidere: se non hai dubbi, questa parte è chiusa e il lavoro continua con la lettura dei disaccordi.

---

# 1. Oggetto e metodo

Due carte depositate prima dei numeri: i lettori locali[^carta-locali] e i modelli Claude[^carta-claude]. Oggetto comune: i
2.024 studi della **parte aperta** degli studi di Gemma (divisione per costruzione sul numero GEO; la parte chiusa, 991
studi, non è stata toccata), la vista v0, l'ingresso congelato di 2.016 studi (8 studi aperti non hanno colonne non
costanti). Il riferimento di una voce sono i gruppi dei fattori di Gemma e i confronti che il costruttore del pacchetto
forma dalla tabella di Gemma. Unità del ricampionamento: lo studio GEO; B = 10.000; seme 20261115.

| lettore | forma | corse | studi letti |
|---|---|---|---|
| Mistral-Small 3.2 (locale) | `B0`: prompt v2, schema a elenco chiuso per studio, `repetition_penalty` 1,1 | `M-rp11`, replica `M-rp11r` | 2.008 (8 oltre il contesto) |
| Gemma-4-31B (locale, secondo lettore ammesso[^secondo]) | `B0`, senza `repetition_penalty` | `GE-rp0` | 2.016 |
| Claude Haiku 5.5 | V: prompt v1, schema v1 vincolato, `effort` high | due corse | 2.016 |
| Claude Sonnet 5.5 | V | una corsa | 2.016 |
| Claude Opus 5.5 | V | una corsa | 252 (pezzo 1 dell'ordine per costruzione) |

Le letture dei Claude sono un **termine di misura**: niente entra nella pipeline e la regola «nessun Claude nella pipeline
né nella validazione pubblicata» resta.

# 2. Cancelli

Tutti passano.[^misura-locali][^misura-claude]

| cancello | esito |
|---|---|
| K1 / KC1 riproduzione | Mistral `B0` sui 47 studi di sviluppo: 45 chiusi, 36/47, 68/95. Opus forma V corsa 1 sui 47 studi: 47 chiusi, 38/47, 72/95. La misura dei Claude ridà per Mistral 1.377/2.052 e 3.198/6.850. Controllo positivo Gemma contro Gemma passato |
| K2 / KC2 oggetto | impronte SHA-256 di ingresso, prompt, schema e di tutte le uscite congelate uguali |
| K3 / KC3 copertura | ogni studio ha un esito: 2.024 su 2.024 per i locali; 2.016 su 2.016 per Haiku e Sonnet, 252 su 252 per Opus; 0 saltati, 0 senza risposta |
| K4 ambiente / KC4 spesa | ogni job su `poddgx02`; spesa dei Claude 42,21 dollari, tetto 75 |
| K5 / KC5 parti chiuse e chiave | nessuno studio della parte chiusa, di giudizio o di sviluppo; nessuna chiave nei file tracciati o scritti dalla prova |

# 3. Mistral `B0` contro i curatori di Gemma

Esiti dei 2.024 studi aperti: misurato 1.879, non chiuso 129, senza colonne non costanti 8, oltre il contesto 8. Motivi dei
non chiusi (uno studio può averne più di uno): livello assente 71, ruolo incoerente 55, base assente 31, uscita non valida 2,
tabella dei fattori 2, base non ammessa 1, troncata 1.

| misura | valore | IC95 |
|---|---|---|
| studi chiusi su studi mandati al modello | 1.879/2.008 = 93,6% | 92,5-94,6 |
| voci con gruppi identici a Gemma | 1.377/2.052 = 67,1% | 65,1-69,2 |
| più fine / più grossa / incrociata / non chiusa | 307 (15,0%) / 156 (7,6%) / 82 (4,0%) / 130 | più fine meno più grossa +7,4 punti (+5,3, +9,4) |
| confronti di Gemma ritrovati (stesso verso) | 3.198/6.850 = 46,7% | 42,3-51,0 |
| confronti ritrovati in ogni verso | 3.324/6.850 = 48,5% | |
| non elencati giudicati errore | 544/1.895 = 28,7% | 23,2-35,0 |
| replica uguale al carattere | 2.016/2.016 | |

Per grandezza dello studio e per numero di fattori di Gemma (gruppi identici, confronti ritrovati):

| classe | Mistral `B0` | Sonnet | Haiku corsa 1 |
|---|---|---|---|
| fino a 12 campioni | 79,4%, 68,2% | 84,5%, 74,8% | 84,2%, 73,4% |
| 13-48 campioni | 58,3%, 51,1% | 64,1%, 61,1% | 64,2%, 57,2% |
| oltre 48 campioni | 38,8%, 21,5% | 50,0%, 37,7% | 46,8%, 26,8% |
| 1 fattore di Gemma | 73,8%, 54,3% | 78,7%, 60,6% | 79,4%, 58,4% |
| 2 fattori | 65,0%, 49,1% | 70,8%, 60,0% | 70,2%, 51,7% |
| 3 o più fattori | 44,9%, 33,9% | 54,8%, 46,4% | 50,4%, 43,2% |

I campioni di Gemma fuori dalla vista sono 1.518 in 295 voci. I campioni della vista fuori da Gemma sono 3.195 in 97 voci.

# 4. L'accordo fra i due lettori locali

Gemma-4-31B (`GE-rp0`) ha letto i 2.016 studi dell'ingresso. «Tenuto» vuol dire: i due lettori danno gli stessi gruppi e
gli stessi confronti. Il numero di studi che Gemma-4-31B chiude da solo non sta nei file della misura.

| misura | valore | IC95 |
|---|---|---|
| studi tenuti | 1.337/2.008 = 66,6% | 64,5-68,6 |
| gruppi identici a Gemma fra i tenuti | 1.107/1.347 = 82,2% | 80,1-84,2 |
| gruppi identici a Gemma fra i non tenuti | 270/705 = 38,3% | |
| differenza | +43,9 punti | +39,6, +48,1 |
| fra i tenuti: confronti ritrovati | 2.567/3.846 = 66,7% | 62,3-71,1 |
| fra i tenuti: non elencati giudicati errore | 208/822 = 25,3% | 18,8-32,3 |

L'accordo toglie studi, non li corregge. Fra i tenuti resta il 17,8% di voci con gruppi diversi da quelli dei curatori:
sono i casi dove i due lettori fanno la stessa scelta e i curatori un'altra.

# 5. I Claude come termine di misura

| corsa | studi | chiusi | gruppi identici | confronti ritrovati | non elencati errore | dollari |
|---|---|---|---|---|---|---|
| Haiku corsa 1 | 2.016 | 1.990 (98,7%) | 1.494/2.060 = 72,5% (70,6-74,5) | 3.676/7.190 = 51,1% (46,0-56,2) | 842/3.044 = 27,7% | 2,98 |
| Haiku corsa 2 | 2.016 | 1.984 (98,4%) | 1.484/2.060 = 72,0% (70,1-74,0) | 3.834/7.190 = 53,3% (48,1-58,3) | 578/2.782 = 20,8% | 2,97 |
| Sonnet | 2.016 | 2.011 (99,8%) | 1.502/2.060 = 72,9% (71,0-74,9) | 4.076/7.190 = 56,7% (51,4-61,7) | 675/3.131 = 21,6% | 29,25 |
| Opus | 252 | 251 (99,6%) | 184/257 = 71,6% (65,9-77,0) | 570/838 = 68,0% (58,4-76,5) | 30/253 = 11,9% | 7,00 |

Motivi dei non chiusi: Haiku «voce non coperta» 17, base assente 10-14, livello assente 10-14, una uscita troncata nella
corsa 2; Sonnet «voce non coperta» 5; Opus un rifiuto. Le classi dei gruppi non identici per Sonnet: più fine 393 (19,1%),
più grossa 101 (4,9%), incrociata 57 (2,8%).

**Differenze appaiate con Mistral, sulle voci degli studi che tutti e due hanno letto:**

| corsa meno Mistral | voci | gruppi identici | confronti ritrovati | non elencati errore |
|---|---|---|---|---|
| Haiku corsa 1 | 2.052 | +5,6 (+3,8, +7,3) | +6,6 (+4,0, +9,6) | −4,8 (−11,2, +1,8) |
| Haiku corsa 2 | 2.052 | +5,1 (+3,2, +6,8) | +6,7 (+3,9, +9,5) | −8,4 (−13,3, −3,7) |
| Sonnet | 2.052 | +6,0 (+4,4, +7,8) | +10,2 (+7,2, +13,5) | −9,8 (−14,7, −5,2) |
| Opus | 257 | +7,0 (+2,4, +11,6) | +7,4 (+0,7, +14,6) | −30,8 (−48,3, −13,9) |

Sui 252 studi di Opus, Mistral ritrova il 60,6% dei confronti (46,7% su tutti gli studi) e ha il 42,7% di non elencati
giudicati errore (28,7% su tutti): il pezzo 1 non somiglia all'insieme in queste due misure, che dipendono da pochi studi
grandi. Per Opus fa fede la differenza appaiata, non la quota.

**Fra i Claude, sugli stessi 252 studi:** Haiku corsa 1 meno Opus +2,7 punti nei gruppi identici (0,0, +5,5); Sonnet meno
Opus +2,7 (+0,4, +5,4). Opus non concorda con i curatori più di Haiku o di Sonnet.

**Stessi gruppi e stessi confronti fra due corse:** Haiku corsa 1 e corsa 2: 1.709/2.016 = 84,8% (83,2-86,3). Haiku e
Sonnet 78,4% e 80,3%. Opus e Sonnet 215/252 = 85,3%. Opus e Haiku 78,6% e 80,6%. Mistral con se stesso: 100%.

**L'accordo con Mistral come filtro**, con ogni secondo lettore:

| secondo lettore | studi tenuti | identici a Gemma fra i tenuti | fra i non tenuti | differenza |
|---|---|---|---|---|
| Gemma-4-31B (locale) | 1.337/2.008 = 66,6% | 1.107/1.347 = 82,2% | 38,3% | +43,9 (+39,6, +48,1) |
| Haiku corsa 1 | 1.221/2.008 = 60,8% | 1.027/1.225 = 83,8% | 42,3% | +41,5 (+37,5, +45,5) |
| Haiku corsa 2 | 1.239/2.008 = 61,7% | 1.039/1.243 = 83,6% | 41,8% | +41,8 (+37,8, +45,9) |
| Sonnet | 1.279/2.008 = 63,7% | 1.072/1.288 = 83,2% | 39,9% | +43,3 (+39,2, +47,5) |
| Opus (252 studi) | 159/252 = 63,1% | 128/161 = 79,5% | 39,6% | +39,9 (+28,2, +51,8) |
| Gemma-4-31B e Opus insieme (252 studi) | 140/252 = 55,6% | 117/140 = 83,6% | 41,9% | +41,7 (+30,7, +52,6) |

Il secondo lettore locale tiene più studi di ogni Claude e la quota di gruppi identici fra i tenuti è la stessa entro 2
punti. Il confronto fra le quote di Gemma-4-31B, Haiku e Sonnet è senza intervallo sulla differenza: la carta lo prevedeva
solo per Opus (PC10).

**Voci dove Mistral e Opus hanno gli stessi gruppi** (257 voci): 198. Di queste, 41 hanno gruppi diversi da Gemma: 33 più
fini, 6 più grosse, 2 incrociate. Nelle voci di Mistral più fini di Gemma, Opus ha gli stessi gruppi di Mistral in 33 su
43. Nelle voci più grosse in 6 su 25.

# 6. Previsioni

**Lettori locali.**[^misura-locali]

| # | quantità | atteso, rilevanza | stima (IC95) | giudizio |
|---|---|---|---|---|
| P1 | studi mandati al modello su 2.024 | 96%, 90-100 | 2.008/2.024 = 99,2% | confermata |
| P2 | chiusi su mandati | 93%, 88-98 | 93,6% (92,5-94,6) | confermata |
| P3 | gruppi identici a Gemma | 55%, 45-67 | 67,1% (65,1-69,2) | indeterminata, sopra l'atteso |
| P4 | confronti ritrovati | 40%, 28-58 | 46,7% (42,3-51,0) | confermata |
| P5 | non elencati giudicati errore | 20%, 5-35 | 28,7% (23,2-35,0) | confermata |
| P6 | replica uguale al carattere | 100%, 99-100 | 2.016/2.016 | confermata |
| P7 | studi tenuti dall'accordo | 60%, 50-75 | 66,6% (64,5-68,6) | confermata |
| P8 | tenuti meno non tenuti | +25, IC sopra 0 | +43,9 (+39,6, +48,1) | confermata |
| P9 | più fine più frequente di più grossa | IC sopra 0 | +7,4 (+5,3, +9,4) | confermata |

**Claude.**[^misura-claude]

| # | quantità | atteso, rilevanza | stima (IC95) | giudizio |
|---|---|---|---|---|
| PC1 | Opus, studi chiusi | 97%, 93-100 | 99,6% (98,8-100) | confermata |
| PC2 | Opus, gruppi identici | 72%, 62-80 | 71,6% (65,9-77,0) | confermata |
| PC3 | Opus meno Mistral, gruppi identici | +4, da −5 a +5 | +7,0 (+2,4, +11,6) | indeterminata |
| PC4 | Opus, confronti ritrovati | 52%, 40-62 | 68,0% (58,4-76,5) | indeterminata |
| PC5 | Opus, non elencati errore | 30%, 15-45 | 11,9% (6,1-18,8) | indeterminata |
| PC6 | Haiku corsa 1 meno Opus | −2, da −5 a +5 | +2,7 (0,0, +5,5) | indeterminata |
| PC7 | Sonnet meno Opus | 0, da −5 a +5 | +2,7 (+0,4, +5,4) | indeterminata |
| PC8 | Haiku, stessi fra le due corse | 80%, 70-90 | 84,8% (83,2-86,3) | confermata |
| PC9 | tenuti da Mistral = Opus | 65%, 55-78 | 63,1% (57,1-69,0) | confermata |
| PC10 | identici fra i tenuti, Opus meno Gemma-4-31B | +2, da −5 a +5 | −1,7 (−6,1, +2,7) | indeterminata |
| PC11 | tenuti meno non tenuti, Mistral = Opus | +40, IC sopra 0 | +39,9 (+28,2, +51,8) | confermata |

**Le indeterminate.** P3: il lettore concorda con i curatori più di quanto atteso; non tocca una conclusione in senso
sfavorevole. PC3: Opus ha letto 252 studi e l'intervallo è largo; Haiku e Sonnet su tutti gli studi danno +5,1, +5,6 e +6,0,
con intervalli a cavallo di +5. La frase che i numeri reggono: i Claude concordano con i curatori circa 6 punti più di
Mistral, e nessuno dei tre supera il 73%. PC4 e PC5: il pezzo 1 ha quote diverse dall'insieme (sezione 5). PC6 e PC7: Haiku
e Sonnet non stanno sotto Opus; l'intervallo esce dal lato a favore del modello che costa meno. PC10: l'intervallo esce dal
lato a favore del lettore locale; nessun numero dice che il filtro locale perde.

**Che cosa cambia, secondo le due carte.** P8 confermata: l'accordo fra due lettori locali è il filtro da portare su tutto
ARCHS4, e tiene due studi su tre. P6 confermata: la pipeline locale è ripetibile. PC3 non è tutta dentro l'intervallo: la
frase «un modello locale concorda con i curatori quanto il modello più forte» non si può scrivere; la differenza misurata è
circa 6 punti. PC6: una lettura di tutto ARCHS4 con Haiku come termine di misura costa, a questi prezzi e con studi di
questa grandezza, circa 36 dollari con i lotti (2,98 dollari per 2.016 studi, 24.393 studi): è una proiezione, non una misura.

# 7. Spesa, chiave e scostamenti dalla carta

- Spesa contata dal campo `usage`: Haiku 2,98 e 2,97 dollari, Opus pezzo 1 7,00, Sonnet 29,25, prove del percorso 0,001.
  **Totale 42,21 dollari** (tetto della prova 75, limite del PI per le prove nuove 99).[^corse-claude][^lotti]
- **La regola di spesa ha fermato Opus.** Dopo la prima onda la spesa era 16,47 dollari. Seconda onda: 16,47 + 7 × 7,00 ×
  1,25 = 77,72 > 75, quindi i pezzi 2-8 di Opus non sono partiti. Terza onda: 16,47 + 7 × 3,52 × 1,25 = 47,27 ≤ 75, quindi
  Sonnet ha letto tutti i pezzi. La carta prevedeva Opus su tutti gli studi e Sonnet su una parte: è successo il contrario,
  per la regola scritta prima. La proiezione di Opus (53 dollari) era giusta entro il 6%; è il margine di 1,25 che ha chiuso.
- Non ho esteso Opus ad altri pezzi fuori dalla regola: sui 252 studi Opus non concorda con i curatori più di Haiku o di
  Sonnet, che coprono tutti gli studi.
- La riga della chiave è stata tolta da `.Renviron.local` il 2026-11-15 dopo la misura. La chiave non sta in nessun file.
- Correzione al programma della misura dopo il primo lancio, fermo prima di ogni numero su Gemma: la cache delle letture
  stava nell'ordine del file e la misura chiedeva l'ordine dell'ingresso (riordino per nome, stessi studi).

# 8. Limiti

- Un disaccordo con Gemma non è un errore del lettore. Questo finding misura l'accordo. La lettura dei disaccordi ha la sua
  carta e il suo finding.
- I confronti di Gemma sono quelli del nostro costruttore sulla sua tabella. L'adattatore non dà una base ai fattori di
  tempo e di contesto.
- Gli studi di Gemma non sono un campione a caso di ARCHS4: un curatore li ha scelti e chiusi.
- Claude legge nella forma V e Mistral nella forma `B0`: la differenza fra i modelli e la differenza fra le forme non si
  separano qui.
- I Claude non ripetono la stessa uscita (Haiku: 84,8% degli studi uguali fra due corse). Opus e Sonnet hanno una corsa.
- Opus ha letto 252 studi su 2.016: ogni numero di Opus ha un intervallo largo.
- L'accordo fra lettori non vede gli errori che i due lettori fanno uguali.
- Chi ha scritto le previsioni e letto i risultati è un modello Claude. Le misure sono programmi deterministici.

# 9. Dubbi

| dubbio | stato |
|---|---|
| Che cosa sono le voci con gruppi diversi da Gemma (675 per Mistral: 307 più fini, 156 più grosse, 82 incrociate, 130 non chiuse) e i 544 confronti non elencati giudicati errore | rinviato alla lettura dei disaccordi, con la sua carta |
| PC3, PC4, PC5, PC10 indeterminate per i 252 studi di Opus | spiegato (sezione 6); non toccano una conclusione, perché Haiku e Sonnet coprono tutti gli studi |
| L'accordo cala negli studi grandi | rinviato alla lettura dei disaccordi: va separato per grandezza |

# 10. Da dove vengono i numeri del riassunto

| frase | file e riga | valore letto |
|---|---|---|
| gruppi dei curatori in 1.377 voci su 2.052 | `41-out.txt`, misura m3; `30-out.txt` KC1 | 1377/2052 = 67,1% |
| 3.198 dei 6.850 confronti | `41-out.txt`, m4; `30-out.txt` KC1 | 3198/6850 = 46,7% |
| chiude 1.879 studi su 2.008 | `41-out.txt`, esiti e m2 | 1879/2008 = 93,6% |
| stessa uscita in 2.016 studi su 2.016 | `41-out.txt`, m6 | 2016/2016 |
| due gruppi di curatori concordavano in 15 studi su 21 | `docs/findings/2026-11-15-gemma-curatori-contro-curatori.md` | 15/21 |
| Haiku 72,5%, Sonnet 72,9%, Opus 71,6% su 252 studi | `30-out.txt`, `a_gruppi_identici` di ogni corsa | 1494/2060, 1502/2060, 184/257 |
| circa 6 punti più di Mistral | `30-out.txt`, c6 | +5,6, +5,1, +6,0, +7,0 |
| 1.337 studi su 2.008 tenuti | `41-out.txt` m7; `30-out.txt` c8 | 1337/2008 = 66,6% |
| 82% fra i tenuti, 38% negli altri | `30-out.txt` c8, Mistral = Gemma-4-31B | 1107/1347 = 82,2%; 270/705 = 38,3% |
| Sonnet 83%, Haiku 84% fra i tenuti | `30-out.txt` c8 | 1072/1288 = 83,2%; 1027/1225 = 83,8% |
| fino a 12 campioni 79%, oltre 48 campioni 39% | `41-out.txt`, classi di grandezza | 810/1020 = 79,4%; 69/178 = 38,8% |
| Sonnet dall'85% al 50% | `30-out.txt`, sonnet-corsa1, classi di grandezza | 862/1020 = 84,5%; 93/186 = 50,0% |
| più fini 15%, più grossi 8% | `41-out.txt`, classi di m3 | 307/2052 = 15,0%; 156/2052 = 7,6% |
| 42,21 dollari | `30-out.txt`, KC4 | 42,21 |
| Opus ha letto solo 252 studi | `30-corse.csv`, riga opus-corsa1 | 252 |
| parte chiusa 991 studi | `analysis/audit/2026-11-15-lettori-su-gemma/00-previsioni.md` | 991 |

[^carta-locali]: `analysis/audit/2026-11-15-lettori-su-gemma/00-previsioni.md`.
[^misura-locali]: `analysis/audit/2026-11-15-lettori-su-gemma/41-out.txt`.
[^secondo]: `analysis/audit/2026-11-15-secondo-lettore/24-out.txt`.
[^carta-claude]: `analysis/audit/2026-11-15-claude-su-gemma/00-previsioni.md`.
[^misura-claude]: `analysis/audit/2026-11-15-claude-su-gemma/30-out.txt`.
[^corse-claude]: `analysis/audit/2026-11-15-claude-su-gemma/30-corse.csv`.
[^lotti]: `analysis/audit/2026-11-15-claude-su-gemma/20-lotti.jsonl`.
