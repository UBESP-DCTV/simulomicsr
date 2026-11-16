---
type: Finding
title: "Tutto ARCHS4, passi 1 e 2: i testi GEO congelati, l'ingresso del lettore per gli studi nuovi e la prova piccola dei due lettori locali"
description: "I testi GEO sono congelati per 21.244 studi nuovi su 21.249, l'ingresso della corsa grande ha 20.426 studi, e nella prova piccola i due lettori locali concordano in 338 studi su 482; tutte le previsioni sono confermate."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-16T20:30:00+01:00}
sources:
- {id: carta, resource: "analysis/audit/2026-11-16-archs4-intero/00-previsioni.md", title: "Carta: cancelli K1-K5, misure a1-a7, previsioni PA1-PA7"}
- {id: elenco, resource: "analysis/audit/2026-11-16-archs4-intero/10-out.txt", title: "L'elenco dei 24.393 studi, le classi e il campione della prova"}
- {id: testi, resource: "analysis/audit/2026-11-16-archs4-intero/12-out.txt", title: "La verifica dei testi GEO congelati contro i manifesti (K2, a1)"}
- {id: vista, resource: "analysis/audit/2026-11-16-archs4-intero/20-out-nuovo.txt", title: "La vista v0 degli studi nuovi"}
- {id: vista-controllo, resource: "analysis/audit/2026-11-16-archs4-intero/20-out-controllo.txt", title: "Il controllo positivo della vista (K1)"}
- {id: ingresso, resource: "analysis/audit/2026-11-16-archs4-intero/21-out-nuovo.txt", title: "L'ingresso della corsa grande e la copertura dei 24.393 studi (K3, a2)"}
- {id: ingresso-prova, resource: "analysis/audit/2026-11-16-archs4-intero/21-out-prova.txt", title: "L'ingresso della prova piccola"}
- {id: oltre, resource: "analysis/audit/2026-11-16-archs4-intero/23-out.txt", title: "Conto accanto nato dopo i numeri: studi e campioni oltre il contesto secondo la stima"}
- {id: chiusa, resource: "analysis/audit/2026-11-16-archs4-intero/22-out.txt", title: "Lo schema dei 991 studi chiusi di Gemma, generato e contato"}
- {id: lancio, resource: "analysis/audit/2026-11-16-archs4-intero/40-out.txt", title: "Il lancio delle quattro corse della prova su poddgx02"}
- {id: misura, resource: "analysis/audit/2026-11-16-archs4-intero/41-out-prova.txt", title: "La misura della prova piccola (K3-K5, a3-a7, conti accanto)"}
- {id: resa, resource: "analysis/audit/2026-11-16-archs4-intero/42-resa-out.txt", title: "Conto accanto nato dopo i numeri: la resa attesa sugli studi nuovi"}
- {id: ieri, resource: "docs/findings/2026-11-15-lettori-su-gemma-parte-aperta.md", title: "I lettori sulla parte aperta degli studi di Gemma"}
- {id: disaccordi, resource: "docs/findings/2026-11-15-disaccordi-con-i-curatori-di-gemma.md", title: "I disaccordi con i curatori di Gemma"}
---

# In breve

## In breve: siamo pronti a far leggere tutto ARCHS4 ai due modelli locali?

**A cosa serviva.** Hai deciso che i due modelli locali leggono tutti i 24.393 studi di ARCHS4 e che teniamo solo gli
studi dove i due modelli concordano. I due modelli sono Mistral e Gemma-4-31B di Google, che qui chiamo «il secondo
modello locale» per non confonderlo con i curatori di Gemma. Prima della corsa grande servivano i testi di GEO degli studi
mai letti e una prova piccola sul nodo di calcolo. La prova dice se la catena regge su studi che nessun curatore ha
scelto, quanto rende e quanto dura.

**Cosa abbiamo trovato.**

1. **I testi di GEO ci sono per 21.244 studi nuovi su 21.249.** Cinque studi non hanno i testi, perché GEO risponde con un
   errore anche al secondo tentativo. Questi cinque studi hanno 142 campioni in tutto.
2. **L'ingresso della corsa grande ha 20.426 studi.** Altri 818 studi hanno un solo campione e non possono dare un
   confronto. Poi 51 studi molto grandi superano il testo che il modello può leggere. Sono lo 0,25% degli studi, ma portano
   il 13% dei campioni, e restano senza lettura.
3. **Nella prova i due modelli concordano in 338 studi su 482, cioè nel 70%.** Gli studi sono estratti a caso fra quelli
   nuovi. Sugli studi curati di ieri i due modelli concordavano nel 67%. Mistral chiude il 95% degli studi e il secondo
   modello locale il 98%. Nessuna corsa si è bloccata.
4. **Circa quattro studi nuovi su dieci danno almeno un confronto.** Dei 338 studi tenuti, 206 hanno almeno un confronto e
   132 non ne hanno. Di questi 132, 73 hanno meno di 4 campioni e negli altri i gruppi non formano un confronto. Su tutti
   gli studi nuovi la stima è circa 8.750 studi con almeno un confronto e circa 20.570 confronti. La prova non dice quanti
   confronti sono giusti: questo lo misura la parte chiusa di Gemma, dopo.
5. **Le letture di ieri restano valide e tutte e nove le previsioni sono confermate.** Su 50 studi già letti ieri Mistral
   ridà la stessa uscita in 50 studi. Il secondo modello locale dà gli stessi gruppi e confronti in 49 studi, e la regola
   dell'accordo dà lo stesso esito in 50. Quindi non rileggiamo gli studi già letti. Per tre previsioni l'intervallo era un
   mio giudizio motivato, non una soglia del progetto.

**Cosa devi decidere.**

1. **Lancio la corsa grande sulle 8 GPU del nodo? Raccomando sì.** I due modelli girano insieme, con 4 GPU l'uno. Mistral
   finisce in circa 7 ore e il secondo modello locale fra 10 e 25 ore. La corsa parte in una sessione nuova, con questo
   ingresso e senza cambi. L'alternativa è fermarsi qui: i testi e l'ingresso restano pronti, e non c'è nessun risultato su
   tutto ARCHS4.
2. **Gli 82 studi di giudizio di Expression Atlas entrano nella corsa grande? Raccomando no, non adesso.** Li leggiamo alla
   fine, insieme ai 991 studi chiusi di Gemma, con le previsioni scritte prima. Così restano una seconda prova pulita, e
   la loro lettura dura pochi minuti. Se entrano adesso, le uscite del modello esistono prima della prova e non
   guadagniamo tempo. Se non li leggiamo mai, al risultato finale mancano 82 studi.

**Comunque.** Dopo la corsa grande applichiamo la regola dell'accordo a tutti gli studi. Poi apriamo la parte chiusa di
Gemma una volta sola, con le previsioni scritte prima, per misurare quanti gruppi sono giusti negli studi tenuti. I 51
studi troppo grandi e i 5 studi senza testi restano senza lettura: li dichiaro come limite. Oggi non ho speso niente per
le API, e le GPU del nodo sono libere.

Appena decidi questi 2 punti, la sessione è chiusa.

**Sui tempi di calcolo.** Ho fatto la stima dai tempi misurati oggi nella prova: 482 studi su 4 GPU per modello. Con il
processo più lento Mistral legge uno studio ogni 1,2 secondi. Per il secondo modello locale i due processi hanno impiegato
839 e 2.120 secondi. Il processo più lento ha letto uno studio dove il modello ha scritto fino al limite senza chiudere.
Per questo la durata del secondo modello locale sta fra 10 e 25 ore.

---

# 1. Oggetto e metodo

La carta è stata depositata prima dello scarico e prima di ogni corsa di un modello su uno studio nuovo.[^carta] Il PI ha
deciso il 2026-11-16: i due lettori locali leggono tutto ARCHS4 con la regola dell'accordo, poi la parte chiusa di Gemma si
apre come prova finale. Questa sessione fa i primi due passi e si ferma.

- **Il bacino**: 24.393 studi e 508.037 campioni, lo stesso dei master S14. Le classi, per costruzione: `nuovo` 21.249,
  `gemma_aperta` 2.024, `gemma_chiusa` 991, `sviluppo` 47, `giudizio` 82.[^elenco]
- **Passo 1, i testi GEO**: per i 21.249 studi nuovi due file per studio (la serie e i campioni, formato SOFT, vista
  «brief»), con la stessa richiesta dei testi già congelati. Due processi in parallelo, un manifesto con SHA-256 per
  processo, una seconda passata sola sui falliti.
- **Passo 2, l'ingresso**: la vista v0 e lo schema delle uscite `B0` (schema generato per ogni studio a elenco chiuso,
  prompt v2), con i programmi di ieri senza cambi nel codice che forma la vista e lo schema.
- **La prova piccola** su `poddgx02`: 500 studi nuovi estratti a caso (`casuale`), i 40 studi nuovi con più campioni
  (`grandi`, 554-5.323 campioni), 50 studi a caso fra i 2.016 letti ieri (`controllo`). Due lettori: Mistral-Small 3.2 con
  `repetition_penalty` 1,1 (corsa `M-rp11`, 4 lavoratori da 1 GPU) e Gemma-4-31B senza `repetition_penalty` (corsa `GE-rp0`,
  2 lavoratori da 2 GPU). Parametri di ieri: `temperature` 0, `max_model_len` 65536, `max_tokens` 24576,
  `VLLM_BATCH_INVARIANT=1`, vLLM 0.20.2.[^lancio]
- **La regola dell'accordo**: uno studio è «tenuto» quando i due lettori chiudono lo studio e danno gli stessi gruppi e
  gli stessi confronti. Il costruttore forma un confronto solo con almeno 2 campioni per braccio.
- Unità: lo studio GEO. Intervalli al 95% col ricampionamento degli studi, B = 10.000, seme 20261116.

**Che cosa la prova non misura.** Sugli studi nuovi non c'è una curazione di riferimento: la prova misura la resa e la
tenuta della catena, non la correttezza. La correttezza negli studi tenuti si misura sulla parte chiusa di Gemma, dopo.

# 2. Cancelli

Tutti e cinque passano.

| cancello | esito |
|---|---|
| K1 controllo positivo della catena | il programma della vista ridà byte per byte 3.061 viste congelate su 3.061 (47 di sviluppo, 3.014 di Gemma) e lo stesso studio escluso di ieri (`GSE224952`);[^vista-controllo] i 50 record di `controllo` rigenerati sono uguali byte per byte alle righe dell'ingresso di ieri; 47 schemi di sviluppo su 47 con l'impronta nota;[^ingresso-prova] la regola dell'accordo ridà 1.337 studi tenuti su 2.008 sulle corse di ieri |
| K2 testi congelati | 42.490 file su 42.490 con i byte e lo SHA-256 del manifesto; nessun file nella cartella fuori dai manifesti; nessun file di uno studio che non è nuovo[^testi] |
| K3 copertura | un esito per ognuno dei 24.393 studi (tabella nella sezione 3)[^ingresso]; nella prova un record per ogni studio mandato (482/482, 482/482, 90/90, 90/90) e un esito per lettore per 572 studi[^misura] |
| K4 ambiente | quattro job su `poddgx02`, tutti `COMPLETED`; `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` letti nel contenitore; schema per record 482/482 e 90/90; prompt e ingresso uguali ai file committati; 42 file di uscita congelati con SHA-256[^lancio] |
| K5 parti chiuse | nessuno studio di giudizio ha un testo, una vista o un record; negli ingressi e nelle uscite della prova nessuno studio di giudizio, di sviluppo o chiuso di Gemma[^misura][^elenco] |

# 3. I testi GEO e l'ingresso della corsa grande

**Passo 1, i testi.** Lo scarico è durato dalle 11:00 alle 18:42 UTC con due processi. I manifesti hanno 42.490 file.
**a1: 21.244 studi nuovi su 21.249 hanno i due file (99,98%).**[^testi] Cinque studi non hanno i testi, anche dopo la
seconda passata:

| studio | campioni nel bacino | file che manca | motivo |
|---|---|---|---|
| `GSE118725` | 13 | campioni | HTTP 502 a ogni tentativo |
| `GSE158435` | 2 | campioni | HTTP 502 a ogni tentativo |
| `GSE212793` | 26 | serie | GEO risponde con una pagina HTML al posto del testo SOFT |
| `GSE243983` | 8 | serie | GEO risponde con una pagina HTML al posto del testo SOFT |
| `GSE252644` | 93 | serie | GEO risponde con una pagina HTML al posto del testo SOFT |

Nessuno dei cinque sta nel campione della prova. La causa dal lato di GEO non è nota.

**La vista.** 21.244 viste su 21.244 studi con i testi, 429.219 campioni. 11 campioni del bacino in 4 studi non stanno più
in GEO e sono marcati. Nessuno studio senza riassunto.[^vista]

**L'ingresso della corsa grande. a2: 20.426 studi nuovi su 21.249 (96,1%).**[^ingresso] 818 studi non hanno colonne non
costanti: hanno tutti un solo campione nel bacino. Il file dell'ingresso pesa 370,5 MB e la sua impronta SHA-256 sta
accanto. I token stimati per studio: mediana 3.670, 99% degli studi sotto 15.172, massimo 901.032.

**Gli studi oltre il contesto secondo la stima sono 51** (0,25% dei 20.426). Sono studi grandi: da 29 a 5.323 campioni,
mediana 804, in tutto 54.538 campioni, cioè il 12,7% dei campioni degli studi nuovi con la vista.[^oltre] Restano nell'ingresso:
il lavoratore conta i token veri, li salta e scrive l'esito. Nella prova il lavoratore ne ha contati più della stima (36 e
37 contro 32 fra i 40 studi più grandi).

**La copertura dei 24.393 studi** (K3):[^ingresso]

| esito | studi |
|---|---|
| nell'ingresso della corsa grande | 20.426 |
| nuovo, senza colonne non costanti (un solo campione) | 818 |
| nuovo, senza testi | 5 |
| aperto di Gemma, già letto ieri dai due lettori | 2.024 |
| di sviluppo, già letto | 47 |
| chiuso di Gemma | 991 |
| di giudizio di Atlas, chiuso | 82 |
| somma | 24.393 |

I 540 studi nuovi della prova restano nell'ingresso della corsa grande, come dice la carta: la rilettura è una replica in
più.

**I 991 studi chiusi di Gemma.** La carta chiede che la vista e lo schema si generino, senza ingresso e senza modello. La
vista è quella di ieri (rigenerata oggi uguale byte per byte, K1). Lo schema è stato generato e contato, e sta solo come
impronta: 990 studi con la vista (manca `GSE224952`, senza campioni nella vista), 985 con uno schema, 5 senza colonne non
costanti, 3 oltre il contesto secondo la stima. Controllo positivo: sugli studi aperti lo stesso programma ridà lo schema
di ieri in 2.024 studi su 2.024. Nessun ingresso scritto, nessun modello, nessuna misura contro Gemma.[^chiusa]

# 4. La prova piccola: la catena sugli studi mai curati

Quattro corse, 41 minuti in tutto dal lancio alla fine (12:40-13:21 UTC).[^lancio] Misure sul pezzo `casuale`: 482 studi
nell'ingresso su 500 estratti (18 non hanno colonne non costanti).[^misura]

| misura | Mistral-Small 3.2 | Gemma-4-31B |
|---|---|---|
| a3, studi oltre il contesto | 0/482 | 0/482 |
| a4, studi chiusi su letti | 457/482 = 94,8% (IC95 92,7-96,7) | 471/482 = 97,7% (96,3-99,0) |
| uscite fermate dal limite dei token | 0 | 1 (`GSE66744`, 24.576 token) |

**a5, studi tenuti dalla regola dell'accordo: 338/482 = 70,1% (IC95 66,0-74,1).** Ieri, sugli studi aperti di Gemma:
1.337/2.008 = 66,6%.[^ieri]

**a6, i 50 studi di `controllo` contro le corse di ieri.** Mistral dà la stessa uscita al carattere in 50 studi su 50, con
una composizione dei lotti diversa da ieri. Gemma-4-31B dà gli stessi gruppi e confronti in 49 studi su 50 e la stessa
uscita al carattere in 42 su 50. Lo studio diverso è `GSE235357` (30 campioni), non tenuto ieri e non tenuto oggi. L'esito
della regola dell'accordo è uguale a ieri in 50 studi su 50 (35 tenuti). Quindi le uscite di ieri (47 studi di sviluppo e
2.016 studi aperti di Gemma) si uniscono a quelle della corsa grande senza rileggere.

**Per grandezza dello studio** (pezzo `casuale`; fra parentesi gli studi aperti di Gemma di ieri):

| campioni | letti da Mistral | chiusi da Mistral | chiusi da Gemma-4-31B | tenuti | tenuti con almeno un confronto |
|---|---|---|---|---|---|
| fino a 3 | 83 | 79 | 83 | 73 (88%; ieri 13/15) | 0 |
| 4-12 | 241 | 231 | 237 | 182 (76%; ieri 75%) | 141 |
| 13-48 | 127 | 118 | 122 | 69 (54%; ieri 60%) | 57 |
| oltre 48 | 31 | 29 | 29 | 14 (45%; ieri 44%) | 8 |

La quota di studi tenuti cala con la grandezza come ieri. Gli studi nuovi sono più piccoli degli studi curati: 83 studi
su 482 hanno fino a 3 campioni, ieri 15 su 2.008.

**I 40 studi `grandi`** (554-5.323 campioni): 37 sono oltre il contesto per Mistral e 36 per Gemma-4-31B (contati dal
lavoratore, token veri; `GSE103401` sta sopra il limite per Mistral e sotto per Gemma-4-31B). Dei letti da tutti e due,
uno è tenuto (`GSE152004`, 675 campioni, 2 gruppi, 1 confronto); `GSE144775` ha 137 gruppi e nessun confronto;
`GSE186507` ha 22 gruppi e 60 confronti e non è tenuto. Nessun job si è bloccato su un prompt oltre il contesto: il
prompt più lungo misurato è di 943.713 token.[^lancio]

# 5. Quanto rende

Conti accanto, senza previsione.[^misura]

| | studi nuovi, pezzo `casuale` | studi aperti di Gemma, ieri |
|---|---|---|
| studi tenuti | 338 | 1.337 |
| tenuti con almeno un confronto | 206 (60,9% dei tenuti; 42,7% dei letti da Mistral) | 1.055 (78,9%; 52,5%) |
| confronti negli studi tenuti | 484 (mediana 2 per studio con confronti) | 3.505 (mediana 2) |

**Perché 132 studi tenuti non hanno confronti.** 73 hanno fino a 3 campioni: il costruttore chiede 2 campioni per
braccio, quindi servono almeno 4 campioni. Degli altri 59, 41 hanno 4-12 campioni, 12 ne hanno 13-48 e 6 più di 48. Per
gruppi: in 40 studi i due lettori concordano su un gruppo solo; in 92 concordano su due o più gruppi che non formano un
confronto (un campione per gruppo, nessun livello di base, o gruppi diversi in più di un fattore).[^resa]

**La resa attesa sui 21.249 studi nuovi** (conto nato dopo i numeri; unità lo studio estratto, uno studio senza colonne
non costanti conta zero):[^resa]

| quantità | su 500 estratti | sui 21.249 studi nuovi |
|---|---|---|
| studi tenuti | 338 = 67,6% (IC95 63,6-71,6) | circa 14.360 (13.510-15.210) |
| studi tenuti con almeno un confronto | 206 = 41,2% (37,0-45,6) | circa 8.750 (7.860-9.690) |
| confronti negli studi tenuti | 484 = 0,97 per studio (0,81-1,15) | circa 20.570 (17.130-24.480) |

La stima non conta gli studi oltre il contesto (nessuno fra i 500 estratti) e non dice quanti confronti sono giusti.

# 6. I tempi e la corsa grande

a7 usa il lavoratore più lento del pezzo `casuale`, diviso gli studi letti, per 20.426 studi nell'ingresso della corsa
grande.[^misura]

| lettore | secondi per studio (lavoratore più lento) | corsa grande su 4 GPU | intervallo della carta |
|---|---|---|---|
| Mistral-Small 3.2 | 1,20 | 6,8 ore | 5-14 ore |
| Gemma-4-31B | 4,40 | 25,0 ore | 11-30 ore |

**La stima di Gemma-4-31B è un massimo probabile.** I due lavoratori hanno letto 241 studi l'uno: 839 secondi il primo,
2.120 secondi il secondo.[^lancio] Il secondo aveva `GSE66744`, lo studio dove il modello ha scritto 24.576 token (il
massimo) senza chiudere. Il conto con il tempo del lavoratore veloce dà 1,74 secondi per studio, cioè circa 10 ore. La
corsa grande avrà altre uscite così (1 su 482 qui): la durata attesa sta fra 10 e 25 ore. Che quella uscita sia la causa
della differenza fra i due lavoratori è la lettura più semplice dei log, non una misura separata. Per Mistral i quattro
lavoratori vanno da 293 a 579 secondi: con il più veloce il conto dà circa 3,5 ore.

I due lettori girano insieme sulle 8 GPU di `poddgx02` (4 per lettore): la corsa grande dura quanto Gemma-4-31B.

# 7. Previsioni

| # | quantità | atteso, rilevanza | stima (IC95) | giudizio |
|---|---|---|---|---|
| PA1 | a1, studi nuovi con i testi | 99,7%, 99-100 | 21.244/21.249 = 99,98% | confermata |
| PA2 | a2, studi nuovi nell'ingresso | 95,5%, 93-98 | 20.426/21.249 = 96,1% | confermata |
| PA3 | a3, oltre il contesto (pezzo `casuale`) | 0,5%, 0-2 | 0/482 per tutti e due i lettori | confermata |
| PA4 | a4, chiusi da Mistral | 93%, 88-98 | 94,8% (92,7-96,7) | confermata |
| PA4b | a4, chiusi da Gemma-4-31B | 97%, 92-100 | 97,7% (96,3-99,0) | confermata |
| PA5 | a5, studi tenuti | 65%, 50-80 | 70,1% (66,0-74,1) | confermata |
| PA6 | a6, Mistral uguale al carattere a ieri | 50 su 50 | 50 su 50 | confermata |
| PA6b | a6, Gemma-4-31B con gli stessi gruppi e confronti | 49 su 50, 45-50 | 49 su 50 | confermata |
| PA7 | a7, durata della corsa grande | 9 ore (5-14), 20 ore (11-30) | 6,8 ore, 25,0 ore | confermata |

Tutte e nove le previsioni sono confermate. PA1 e PA2 sono conti su tutti gli studi nuovi, senza intervallo di confidenza.
Per PA1, PA2 e PA3 l'intervallo di rilevanza era un giudizio motivato (carta). La carta dice che cosa segue: con tutte le
previsioni dentro, la sessione seguente lancia la corsa grande con questo ingresso, senza cambi, con il via del PI.

# 8. Scostamenti dalla carta e decisioni tecniche

- **Il nome del programma di verifica.** Il programma dello scarico nomina `12-unisci-manifesti.py`. Il programma vero è
  `12-verifica-testi.py`: legge i due manifesti senza unirli in un file e rifà la verifica di ogni riga.
- **I codici di esito di K3.** La carta elenca cinque esiti. Il programma dà un codice fisso alle classi che la corsa
  grande non rilegge: `sviluppo_gia_letto` (47), `gemma_aperta_gia_letta` (2.024), `gemma_chiusa` (991),
  `giudizio_chiuso` (82). La somma resta 24.393.
- **a3 per lettore.** I due lettori contano i token con il loro programma: a3 è riportata per ognuno (0/482 e 0/482).
- **Lo schema dei 991 studi chiusi di Gemma** è generato e contato, e non è scritto su disco: restano le impronte e i
  conti per studio. Nessun ingresso, come dice la carta.
- **Prova a secco a scarico in corso.** Alle 16:14 UTC i programmi della vista e dell'ingresso hanno girato sui 14.367
  studi già scaricati, per provare i programmi prima della fine dello scarico. Nessun modello. La corsa finale ha
  riscritto tutte le uscite; i log della prova a secco restano in `log/`.
- **Conti nati dopo i numeri.** La resa attesa sui 21.249 studi nuovi (`42-resa.R`) e i campioni degli studi oltre il
  contesto (`23-oltre-contesto.py`) non hanno una previsione. Sono scritti come conti accanto.
- **a7 calcolata due volte.** La prima misura usava una stima degli studi nell'ingresso (20.484). La misura finale usa il
  numero vero. Gli altri numeri della misura non cambiano fra le due. La durata
  non cambia alla prima cifra decimale (6,8 e 25,0 ore).
- **La seconda passata.** A scarico finito (18:42 UTC) lo stesso programma è ripartito una volta con lo stesso lanciatore:
  salta i file già nel manifesto e richiede solo i 5 falliti. Tutti e 5 falliscono ancora con lo stesso motivo (18:50
  UTC).
- **Nessun ritento a mano**, nessuna correzione del prompt, nessuna regola nuova per gli studi oltre il contesto: la carta
  la chiede solo se a3 supera il 2% o se un job si blocca, e nessuna delle due cose è successa.

# 9. Limiti

- La prova misura la resa, non la correttezza. Ieri, sugli studi aperti di Gemma, l'errore di lettura stimato negli studi
  tenuti era l'1,8% delle voci (IC95 0,6-3,1).[^disaccordi] Sugli studi nuovi non è misurato.
- L'accordo fra i due lettori toglie studi, non li corregge, e non vede gli errori che i due lettori fanno uguali.
- Uno studio tenuto può non avere confronti: 132 su 338 nel pezzo `casuale`.
- Gli studi nuovi non sono come gli studi curati: sono più piccoli e nessun curatore li ha scelti. La resa in confronti è
  più bassa (42,7% degli studi letti contro 52,5%).
- Gli studi oltre il contesto non hanno una lettura: 51 secondo la stima, lo 0,25% degli studi nell'ingresso e il 12,7%
  dei campioni. Il conto vero lo fa il lavoratore nella corsa grande.
- Gemma-4-31B non ripete l'uscita al carattere (42 studi su 50); nei gruppi e nei confronti 49 su 50. Un solo campione di
  50 studi misura la tenuta della regola dell'accordo fra due corse.
- I testi GEO sono del 16 novembre 2026; ARCHS4 v2.5 ha letto GEO nel 2024. La vista usa i campioni del bacino e conta i
  campioni cancellati da GEO. I testi delle altre classi sono del 9 e del 15 novembre.
- 500 studi danno circa ±4 punti sulla quota di studi tenuti.
- Chi ha scritto le previsioni e letto i risultati è un modello Claude. Le misure sono programmi deterministici.

# 10. Dubbi e come sono chiusi

| dubbio | stato |
|---|---|
| `GSE66744` (8 campioni): Gemma-4-31B scrive 24.576 token senza chiudere | spiegato: lo studio conta come non chiuso e non è tenuto; il costo è il tempo del lotto (sezione 6). Nella corsa grande questi studi escono dalla regola dell'accordo |
| `GSE235357`: Gemma-4-31B dà gruppi o confronti diversi da ieri | spiegato: lo studio non è tenuto né ieri né oggi; l'esito della regola dell'accordo è uguale in 50 studi su 50 (PA6b prevedeva 49 su 50) |
| 132 studi tenuti su 338 senza confronti | spiegato (sezione 5): 73 hanno fino a 3 campioni; negli altri i gruppi concordi non formano un confronto. È la definizione del costruttore, non un errore della catena |
| Gli studi oltre il contesto: nessuna lettura | spiegato e dichiarato fra i limiti: il lavoratore li salta e la copertura li conta; la carta chiede una regola solo sopra il 2% |
| La durata di Gemma-4-31B nella corsa grande sta fra 10 e 25 ore | deciso dal PI il 2026-11-16: sì alla corsa grande sulle 8 GPU di `poddgx02`, in una sessione nuova, con questo ingresso e senza cambi |
| Se gli 82 studi di giudizio di Atlas entrano nella corsa grande | deciso dal PI il 2026-11-16: no, non adesso; si leggono alla fine insieme ai 991 studi chiusi di Gemma, con le previsioni scritte prima |

**Decisioni del PI (2026-11-16), come raccomandato.** (1) La corsa grande parte sulle 8 GPU di `poddgx02`, in una sessione
nuova. (2) Gli 82 studi di giudizio di Atlas non entrano nella corsa grande: si leggono alla fine, con i 991 studi chiusi
di Gemma. La sessione è chiusa.

# 11. Da dove vengono i numeri del riassunto

| frase del riassunto | file e riga | valore letto |
|---|---|---|
| testi per 21.244 studi nuovi su 21.249 | `12-out.txt`, riga «a1» | 21244 su 21249 (99.98%) |
| cinque studi senza testi, 142 campioni | `12-senza-testi.csv` (5 righe); `10-elenco.csv`, campioni dei 5 studi | 13 + 2 + 26 + 8 + 93 = 142 |
| l'ingresso ha 20.426 studi; 818 con un solo campione | `21-out-nuovo.txt`, riga «nuovo:»; `23-out.txt`, ultima riga | 20426; 818, minimo 1 massimo 1 |
| 51 studi oltre il testo che il modello legge, 0,25% degli studi, 13% dei campioni | `23-out.txt`, righe 4-5 | 51 (0.25%); 54538 campioni (12.7%) |
| i due modelli concordano in 338 studi su 482 (70%) | `41-out-prova.txt`, a5 | 338/482 = 70,1% |
| ieri 67% | `docs/findings/2026-11-15-lettori-su-gemma-parte-aperta.md`, riassunto punto 3 | 1337/2008 = 66,6% |
| Mistral chiude il 95%, il secondo modello il 98% | `41-out-prova.txt`, a4 | 457/482 = 94,8%; 471/482 = 97,7% |
| 206 studi tenuti con almeno un confronto, 132 senza, 73 con meno di 4 campioni | `42-resa-out.txt`; `41-out-prova.txt`, tabella per grandezza | 206; 132; 73 |
| circa quattro studi su dieci; circa 8.750 studi e circa 20.570 confronti | `42-resa-out.txt` | 206/500 = 41,2%; 8750; 20570 |
| 50 su 50, 49 su 50, esito uguale in 50 | `41-out-prova.txt`, a6 | 50/50; 49/50; 50/50 |
| nove previsioni confermate | `41-out-prova.txt` (PA3-PA7); `21-out-nuovo.txt` (a1, a2) | sezione 7 |
| Mistral circa 7 ore, secondo modello fra 10 e 25 ore | `41-out-prova.txt`, a7; `40-out.txt`, righe 35-36 | 6.8 ore; 25.0 ore; 839,3 s e 2119,8 s (2 × 839,3 / 482 × 20.426 = 9,9 ore) |
| uno studio ogni 1,2 secondi | `41-out-prova.txt`, a7 | 579 s / 482 = 1.20 |
| la lettura degli 82 studi dura pochi minuti | conto: 82 × 4,40 s (a7) | 6 minuti |
| 991 studi chiusi di Gemma, 82 di giudizio | `10-out.txt`, classi | 991; 82 |

[^carta]: `analysis/audit/2026-11-16-archs4-intero/00-previsioni.md`.
[^elenco]: `analysis/audit/2026-11-16-archs4-intero/10-out.txt`.
[^testi]: `analysis/audit/2026-11-16-archs4-intero/12-out.txt`.
[^vista]: `analysis/audit/2026-11-16-archs4-intero/20-out-nuovo.txt`.
[^vista-controllo]: `analysis/audit/2026-11-16-archs4-intero/20-out-controllo.txt`.
[^ingresso]: `analysis/audit/2026-11-16-archs4-intero/21-out-nuovo.txt`.
[^ingresso-prova]: `analysis/audit/2026-11-16-archs4-intero/21-out-prova.txt`.
[^oltre]: `analysis/audit/2026-11-16-archs4-intero/23-out.txt`.
[^chiusa]: `analysis/audit/2026-11-16-archs4-intero/22-out.txt`.
[^lancio]: `analysis/audit/2026-11-16-archs4-intero/40-out.txt`.
[^misura]: `analysis/audit/2026-11-16-archs4-intero/41-out-prova.txt`.
[^resa]: `analysis/audit/2026-11-16-archs4-intero/42-resa-out.txt`.
[^ieri]: `docs/findings/2026-11-15-lettori-su-gemma-parte-aperta.md`.
[^disaccordi]: `docs/findings/2026-11-15-disaccordi-con-i-curatori-di-gemma.md`.
