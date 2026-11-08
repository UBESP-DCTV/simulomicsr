---
type: Finding
title: "La prova cieca dello Stadio 2b: tre modelli prendono quasi tutti i difetti e accusano troppi confronti puliti"
description: "S12p: Mistral-Small-3.2, Magistral-Small-2509 e Gemma-4-31B compilano la lista di controllo dello Stadio 2b sui 1.903 confronti del deliverable; la regola fissa decide; il conto cieco contro i 193 difettosi e i 1.710 puliti dice che nessun modello passa il cancello di ADR-0028 (almeno 130 presi, al massimo 40 falsi allarmi)."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-08T18:30:00+01:00'}
sources:
- {id: prev, resource: "analysis/audit/2026-11-08-S12p-prova/00-previsioni.md", title: "Cancelli K1-K5 e previsioni P11-P14 (commit 56accde), con P4-P6 di S12 (commit f8228f5)"}
- {id: spec, resource: "docs/superpowers/specs/2026-11-07-stadio-2b-design.md", title: "Spec dello Stadio 2b"}
- {id: adr, resource: "docs/decisions/0028-stadio-2b-giudice-di-confrontabilita.md", title: "ADR-0028"}
- {id: token, resource: "analysis/audit/2026-11-08-S12p-prova/25-token-1903.tsv", title: "Token del prompt dei 1.903 confronti per modello, contati su CPU"}
- {id: smoke, resource: "analysis/audit/2026-11-08-S12p-prova/20-smoke-out.txt", title: "Smoke, 21 confronti per modello"}
- {id: gtok, resource: "analysis/audit/2026-11-08-S12p-prova/21-gemma-token-out.txt", title: "Il token in piu' di Gemma"}
- {id: canc, resource: "analysis/audit/2026-11-08-S12p-prova/30-cancelli.txt", title: "Cancelli K3-K4 ed esiti senza riferimento"}
- {id: sha, resource: "analysis/audit/2026-11-08-S12p-prova/40-uscite-sha256.txt", title: "Impronte delle uscite, committate prima del conto (5d8814f)"}
- {id: conto, resource: "analysis/audit/2026-11-08-S12p-prova/40-out.txt", title: "Il conto cieco (script 40-conto.R, commit 126a282)"}
- {id: rip, resource: "analysis/audit/2026-11-08-S12p-prova/50-gemma-ripetizione-out.txt", title: "Gemma, seconda esecuzione sui 1.903"}
- {id: rif, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", title: "Il riferimento dei 193 confronti difettosi"}
---

# In breve

## In breve: un modello che legge il testo dei campioni sa dire quali confronti sono difettosi?

**A cosa serviva.** Il nuovo passo della pipeline fa leggere a un modello linguistico il testo grezzo dei campioni dei due bracci di ogni confronto. Il modello compila una lista di controllo, e una regola fissa decide se il confronto entra nella meta-analisi. Questa prova ha misurato il passo con tre modelli su tutti i 1.903 confronti del deliverable, contro i 193 confronti difettosi già noti. Il piano chiedeva almeno 130 difetti presi e al massimo 40 confronti puliti accusati, prima di mettere il passo nella pipeline.

**Cosa abbiamo trovato.**

1. **Nessuno dei tre modelli passa, perché tutti accusano troppi confronti puliti.** Mistral, il modello di produzione, prende 186 difetti su 193 e accusa 965 confronti puliti su 1.710. Magistral prende 177 difetti e accusa 887 confronti puliti. Gemma prende 155 difetti e accusa 364 confronti puliti.
2. **I modelli vedono bene i difetti scritti nel testo dei campioni.** Mistral e Magistral prendono tutti i 48 difetti di tempo zero. Prendono anche tutti i 58 difetti che la lettura precedente aveva trovato nei metadati e non nelle etichette. Gemma prende 44 e 52 di questi difetti.
3. **Due motivi compaiono nella maggior parte dei falsi allarmi di Mistral.** Mistral scrive la malattia del donatore come un trattamento, contro le istruzioni. Questo motivo compare in 315 dei confronti puliti accusati. La voce aperta «altre differenze», che hai deciso di trattare come errore, compare in 606. Un confronto può avere più di un motivo.
4. **Una parte dei falsi allarmi può essere fatta di difetti veri che il riferimento non contiene.** Il riferimento non è un campione neutro, perché 64 dei 193 difetti vengono dagli allarmi di una regola che vedeva 81 difetti su 193. Gemma passerebbe solo se almeno 324 dei suoi 364 falsi allarmi fossero difetti veri.
5. **Il conto è ripetibile.** Mistral e Magistral ridanno lo stesso testo nei 21 confronti rifatti. Gemma, rifatto da capo, cambia il testo nel 2% dei confronti, ma dà lo stesso verdetto in tutti i 1.903.

**Cosa devi decidere.**

1. **Leggiamo adesso tutti i 364 falsi allarmi di Gemma? Raccomando di sì, con i 155 difetti presi da Gemma mescolati, senza dire ai lettori quali sono quali.** Gemma è il modello che accusa meno confronti puliti. Per ogni falso allarme la lettura dice chi sbaglia: il modello, la regola o il riferimento. Questo dato serve a scegliere la strada, ma non cambia l'esito della prova. I lettori sono agenti di revisione interna con una scheda scritta prima. I 155 difetti presi servono a verificare che i lettori riconoscano un difetto vero. La lettura costa alcune ore e alcuni milioni di token.
   - In alternativa leggiamo solo i 323 confronti puliti che tutti e tre i modelli accusano. Costa meno, ma non separa gli errori propri di Gemma.
   - In alternativa rinviamo la lettura alla sessione in cui sceglierai la strada. Allora sceglierai senza sapere quanti falsi allarmi sono difetti veri.
2. **Quale strada prendiamo al posto di questa? Raccomando di scegliere dopo la lettura.** Il piano prevede tre strade, e ognuna ha una conseguenza:
   - regole scritte a mano, come in agosto: il rilevatore di allora prendeva 81 difetti su 193;
   - un modello addestrato sui dati già letti del progetto: serve tenere da parte confronti che il modello non vede mai durante l'addestramento;
   - un prompt e una regola nuovi: la tabella dei falsi allarmi dice dove intervenire.

   In ogni caso questi 1.903 confronti non sono più ciechi. Una versione nuova va misurata su confronti che nessuno ha usato per scriverla.

**Comunque.** Il nuovo passo non entra nella pipeline, e il ricalcolo finale non parte. Il prompt, lo schema e la regola restano come sono, e la decisione di novembre sul nuovo passo torna allo stato di proposta. Le risposte dei tre modelli sono congelate con un'impronta, e una copia verificata sta sull'altro disco.

Se scegli di leggere adesso, la sessione si chiude dopo la lettura. Se scegli un'alternativa, appena decidi questi 2 punti la sessione è chiusa.

**Sui tempi di calcolo.** La mia stima era da 2 a 6 ore per i tre modelli. Il tempo misurato è stato di 30 minuti per Mistral, 29 per Magistral e 53 per Gemma, con 4 GPU H100 per modello. A questi si aggiungono 33 minuti di recupero delle risposte non valide. Il costo della lettura è una mia stima: circa 500 confronti, ognuno con qualche migliaio di token di testo.

---

# 1. Che cosa c'è su disco

| oggetto | dove |
|---|---|
| uscite finali per modello (una riga per confronto, dopo la cascata) | `analysis/p4-output/S12p-uscite/{mistral,magistral,gemma}.jsonl` (fuori da git); copia verificata in `/mnt/micron/simulomicsr-salvataggio/S12p-uscite-20261108/` (9 file su 9) |
| tutti i giri (base e recupero) | `analysis/p4-output/S12p-uscite/<modello>-tutti-i-giri.rds` |
| esiti della regola, calcolati prima del riferimento | `analysis/p4-output/S12p-uscite/<modello>-esiti.tsv` |
| impronte, committate prima del conto | `analysis/audit/2026-11-08-S12p-prova/40-uscite-sha256.txt` (commit `5d8814f`) |
| conto, tabelle per categoria e per segnale | `40-out.txt`, `40-tabella.csv`, `40-per-categoria.csv`, `40-segnali.csv` |
| codice | `R/dgx-bundle.R` (`stage = "stage2b"`, argomento `modello`), `inst/dgx/python/run_p4_vllm.py` (ramo `stage2b`, token contati prima, `tensor_parallel_size`), `inst/extdata/p4-defaults.yml` (`stage2b`), test `tests/testthat/test-dgx-bundle-stage2b.R` (19 asserzioni), `inst/dgx/python/test_prompts.py` (7 test) |
| modelli nella cache del DGX | Magistral `a31cc96…` (52 GB, formato Mistral), Gemma `842da37…` (67 GB); Mistral `95a6d26…` gia' presente |

Job su `poddgx02`, tutti `COMPLETED` salvo dove detto: smoke 470086, 470087, 470089 (470083-470085 cancellati,
470088 fallito: §7); mini-job 470090; lancio pieno 470091 (Mistral, 30 min 30 s), 470092 (Magistral, 29 min
10 s), 470093 (Gemma, 52 min 37 s); recupero 470094-470098; ripetizione di Gemma 470099.

# 2. Cancelli

| # | cancello | esito | fonte |
|---|---|---|---|
| K1 | impronte dell'ingresso all'inizio e alla fine; prompt, schema e testo di ogni bundle identici agli oggetti congelati | **passa**: `91-sha256.txt` 8 su 8 all'inizio (e alla fine, §9); «prompt, schema e N testi identici» per ognuno dei 17 bundle | `log/catena.log` |
| K2 | `VLLM_BATCH_INVARIANT=1` (e `HF_HUB_OFFLINE=1`) nel `container-env.txt` di ogni run; ogni job su `poddgx02`; `generation.json` uguale fra i modelli a meno dei campi del modello | **passa** | `log/catena.log`, `20-smoke-out.txt`, `30-sacct-pieno.txt` |
| K3 | 1.903 confronti su 1.903 con un esito, per modello | **passa** per i tre modelli | `30-cancelli.txt` |
| K4 | le uscite dello smoke rifatte nel run pieno sono identiche; token contati prima = token di vLLM | **passa per Mistral e Magistral** (21 su 21; 1.900 su 1.900). **Fallisce per Gemma**: 15 uscite su 21 identiche; i token di vLLM sono quelli del template piu' 1 in 1.900 su 1.900 (§6, §7) | `30-cancelli.txt` |
| K5 | impronte committate prima dello script del conto; controllo positivo e negativo dello script | **passa**: `5d8814f` (impronte) prima di `126a282` (conto); 193/0 e 0/0 | `git log`, `40-out.txt` |

Il riferimento e' stato aperto la prima volta dopo il commit `5d8814f`, per scrivere lo script del conto.

# 3. Previsioni

Unita': il confronto. Intervallo di Wilson al 95% sulle frazioni; per P6 e P13 (quote di assi e di citazioni,
raggruppate nei confronti) bootstrap sui confronti, B = 2.000, seme 20261108. Per P4 e P5 l'intervallo di
rilevanza e' in conteggi: l'intervallo di Wilson si riporta in conteggi moltiplicando per 193 o 1.710.

| # | quantita' | modello | atteso | rilevanza | risultato [IC 95%] | giudizio |
|---|---|---|---|---|---|---|
| P4 | difetti presi su 193 | Mistral | ≥ 130 | [130, 193] | **186** (96,4% [92,7; 98,2] = 179-190) | confermata |
| | | Magistral | | | **177** (91,7% [87,0; 94,8] = 168-183) | confermata |
| | | Gemma | | | **155** (80,3% [74,1; 85,3] = 143-165) | confermata |
| P5 | puliti accusati su 1.710 | Mistral | ≤ 40 | [0, 40] | **965** (56,4% [54,1; 58,8] = 925-1.006) | **smentita** |
| | | Magistral | | | **887** (51,9% [49,5; 54,2] = 846-927) | **smentita** |
| | | Gemma | | | **364** (21,3% [19,4; 23,3] = 332-398) | **smentita** |
| P6 | assi `not_stated` (liste valide) | Mistral | < 30% | [0%, 30%] | 29,57% [29,03; 30,12] | indeterminata |
| | | Magistral | | | 29,20% [28,72; 29,68] | confermata |
| | | Gemma | | | 29,44% [28,89; 30,01] | indeterminata |
| P11 | confronti oltre il limite | tutti | 1 (Gemma 0-2) | [0, 19] | **3** per ogni modello (conteggio su tutta la popolazione) | confermata (fuori dall'atteso, dentro la rilevanza: §7) |
| P12 | liste non valide dopo la cascata | Mistral / Magistral / Gemma | 0-5 | [0, 19] | 0 / 0 / 1 | confermata |
| P13 | citazioni trovate per intero nel testo | Mistral | ≥ 90% | [80%, 100%] | 83,2% [82,5; 83,9] | confermata (sotto l'atteso) |
| | | Magistral | | | 80,3% [79,6; 80,9] | indeterminata |
| | | Gemma | | | 90,6% [90,0; 91,1] | confermata |
| P14 | durata per modello, 4 GPU | Mistral / Magistral / Gemma | 1-4 h | sopra 24 h | 30 min 30 s / 29 min 10 s / 52 min 37 s (piu' 4, 4 e 25 min di recupero) | confermata |

**Il cancello di ADR-0028** (P4 e P5 confermate per almeno un modello) **non passa**: P5 e' smentita per tutti e
tre, con l'intervallo intero molto sopra 40.

**Le due indeterminate.** P6 tocca il 30% per Mistral e Gemma (estremo superiore 30,12% e 30,01%): un asse su tre
resta non detto, e la regola lo passa con avviso. La conseguenza scritta in P6 riguarda i Methods di uno Stadio 2b
in produzione; nessun modello va in produzione, quindi non tocca una conclusione di questa sessione. Il dato va
nel disegno della via successiva (§10). P13 tocca l'80% per Magistral: una citazione su cinque non si trova per
intero nel testo; e' una diagnostica, non cambia il conto, e Magistral non passa comunque.

# 4. Il conto

| modello | presi su 193 | puliti accusati su 1.710 | passano su 1.903 | liste non valide | oltre il limite |
|---|---|---|---|---|---|
| Mistral-Small-3.2 (produzione) | 186 | 965 | 752 | 0 | 3 |
| Magistral-Small-2509 | 177 | 887 | 839 | 0 | 3 |
| Gemma-4-31B | 155 | 364 | 1.384 | 1 | 3 |

**Per famiglia dei 193.** Le famiglie vengono da una regola su parole chiave della categoria scritta nello
script del conto (non depositata: serve a leggere il conto per gruppi; il conto per ciascuna delle 85 categorie
e' in `40-per-categoria.csv`).

| famiglia | n | Mistral | Magistral | Gemma |
|---|---|---|---|---|
| tempo zero | 48 | 48 | 48 | 44 |
| seconda perturbazione | 42 | 41 | 39 | 40 |
| asse dei campioni non appaiato (materiale, linea, donatore, genotipo, sesso, sede…) | 42 | 37 | 34 | 28 |
| tempo o durata non appaiati | 21 | 21 | 18 | 14 |
| altro | 15 | 15 | 14 | 12 |
| entita' o contrasto | 14 | 13 | 13 | 10 |
| non provato o indecidibile | 6 | 6 | 6 | 2 |
| differenza tecnica | 5 | 5 | 5 | 5 |

I 58 difetti che il riferimento ha letto nei metadati (non nelle etichette): Mistral 58, Magistral 58, Gemma 52.
I 135 letti nelle etichette: 128, 119, 103. Quattro difetti non li prende nessun modello (due «donatore diverso
fra i bracci», uno di vescicole contro cellule, uno di materiale a granularita' diversa).

**Accordo fra i modelli.** 149 difetti e 323 puliti sono accusati da tutti e tre; 4 difetti e 666 puliti da nessuno.

**I due confronti con il controllo cancellato da GEO** (studio GSE226005, dubbio ricevuto e): sono puliti nel
riferimento, e passano con tutti e tre i modelli.

# 5. Che cosa accusa i confronti puliti

Segnali con esito «errore» che compaiono nei motivi dei confronti accusati (un confronto ne puo' avere piu' di
uno; tabella intera in `40-segnali.csv`):

| segnale | falsi allarmi Mistral | Magistral | Gemma | presi Mistral | Magistral | Gemma |
|---|---|---|---|---|---|---|
| `ALTRA_DIFFERENZA` (voce aperta, errore per decisione del PI) | 606 | 465 | 70 | 101 | 78 | 25 |
| `CONDIZIONE_CON_AGENTE` | 315 | 284 | 1 | 32 | 30 | 2 |
| `DIVERSO_DONATORE` | 182 | 125 | 33 | 12 | 13 | 9 |
| `TEMPO_DIVERSO` | 116 | 182 | 46 | 81 | 83 | 68 |
| `ENTITA_DIVERSA` | 79 | 48 | 55 | 40 | 15 | 63 |
| `PARZIALE_LINEA` | 75 | 71 | 39 | 7 | 7 | 7 |
| `DIVERSO_ETA_STADIO` | 69 | 46 | 60 | 7 | 4 | 7 |
| `DIVERSO_GENOTIPO` | 39 | 39 | 35 | 16 | 14 | 12 |
| `TEMPO_ZERO` | 28 | 59 | 14 | 51 | 56 | 47 |
| `SECONDO_AGENTE` | 23 | 35 | 8 | 44 | 44 | 42 |

- **Segnali calcolati dal codice** (`TECNICA_H5_*`, dubbio ricevuto c): da soli accusano 0 puliti con Mistral e
  Magistral, 2 con Gemma; prendono 3 difetti per modello (sempre insieme ad altri segnali).
- **Liste non valide e ingressi oltre il limite**: da soli accusano 3 puliti (Mistral, Magistral) e 4 (Gemma),
  nessun difetto.
- **Mistral e Magistral scrivono la malattia del donatore come agente** nei confronti malati contro sani, contro il
  prompt («Conditions of the donors before sampling ... are NOT agents»): la regola vede allora un agente e una
  condizione diversa insieme (`CONDIZIONE_CON_AGENTE`). Gemma lo fa una volta.
- **La voce aperta «altre differenze»** e' la prima causa dei falsi allarmi di Mistral e Magistral.

Questa tabella descrive; non e' una proposta di regola. Ogni modifica a prompt, schema, regola o tabella degli
esiti decisa guardando questi numeri non sarebbe piu' cieca su questi 1.903 confronti (§10).

# 6. Gemma non ripete le sue uscite (cancello K4)

**Il conto di Gemma non dipende da questa variabilita'.** Una seconda esecuzione sui 1.903 (job 470099, stesso
bundle) contro la prima (470093), entrambe prima della cascata[^rip]:

| misura | valore |
|---|---|
| uscite grezze identiche | 1.855 su 1.900 generate (97,6%) |
| liste valide | 1.890 e 1.890 |
| verdetto della regola uguale | 1.903 su 1.903 |
| motivi uguali | 1.902 su 1.903 |
| presi / falsi allarmi | 155 / 367 in tutte e due (364 dopo la cascata) |

Il cancello K4 e' fallito come scritto per Gemma; il dubbio e' **spiegato con il calcolo**: il testo cambia nel 2,4%
delle uscite, il verdetto in nessun confronto. Gemma non puo' andare in produzione cosi', perche' la pipeline
chiede uscite ripetibili (`CLAUDE.md` §6); per la prova il suo conto vale.

Nello smoke e nel run pieno, 6 delle 19 uscite generate di Gemma sono diverse: valori scritti in modo diverso
(«RPMI + 1% FBS» contro «1640 RPMI containing 1% dialyzed fetal bovine serum»), una relazione diversa (`same`
contro `partial` sulla tecnica), citazioni diverse. Il verdetto della regola e' uguale in 6 casi su 6; i motivi
cambiano in 1 (`PARZIALE_TECNICA` in piu'). Mistral e Magistral ripetono 21 uscite su 21.

Che cosa distingue Gemma: (1) le teste d'attenzione hanno due dimensioni (256 e 512), e vLLM forza il backend
`TRITON_ATTN` («Forcing TRITON_ATTN backend to prevent mixed-backend numerical divergence»), mentre Mistral usa
FlashAttention 3; (2) il modello e' diviso su 2 GPU, e l'all-reduce di FlashInfer non si inizializza
(«Failed to initialize FlashInfer All Reduce workspace»). Il codice della modalita' batch invariant tratta sia
Triton (kernel 2D forzato) sia NCCL (impostazioni deterministiche). La causa precisa non e' isolata.

# 7. Scostamenti dal piano e correzioni in corsa

1. **Il primo smoke si e' fermato** (job 470083 e 470084, 30 minuti): il worker con il confronto da 57.745 token
   e' rimasto in attesa dentro `LLM._preprocess_chat_one`, senza errore, con la GPU allo 0%. Il confronto da 28.038
   token (sotto `max_model_len`) e' passato dalla stessa funzione. Correzione: il runner conta con
   `tokenizer.apply_chat_template()`; il conteggio coincide con vLLM in 1.900 confronti su 1.900 per Mistral e
   Magistral. Job cancellati, riferimenti in `jobs/fermati/`.
2. **Il limite di lunghezza con il conteggio vero** (dubbio ricevuto b): 3 confronti su 1.903 per ogni modello
   (Mistral e Magistral: 28.038, 27.824, 57.745 token; Gemma: 27.588, 27.375, 59.050). La stima di 3 caratteri per
   token dava 1: nei due confronti di GSE146096 (farmaci, 104-105 campioni) il testo fa 2,4 caratteri per token. La
   mediana e' 4,16 caratteri per token. I tre confronti sono puliti nel riferimento e contano come falsi allarmi.
3. **Lo smoke ha 21 confronti, non 20**: il confronto «piu' lungo entro il limite stimato» era oltre il limite
   vero, e ho aggiunto il piu' lungo entro il limite vero (25.140 token, Alzheimer contro sani) per provare la
   memoria. Scelta fatta prima del lancio pieno, senza riferimento.
4. **Gemma-4-31B su 2 GPU per worker** (job 470088 fallito): la cache per 32.768 token chiede 15,8 GiB e su una
   H100 ne restano 3,6. `tensor_parallel_size = 2`, 2 worker per job; i parametri di campionamento non cambiano.
5. **vLLM aggiunge a Gemma uno spazio** (token 236743) in fondo al messaggio di sistema, in posizione 2.023, in
   1.900 confronti su 1.900 (mini-job 470090). Nessuna decisione sul limite cambia: il prompt di Gemma piu' vicino
   al limite ha 25.440 token.
6. **Magistral risponde senza la fase di ragionamento**: l'uscita strutturata parte dal primo token e il prompt
   di sistema e' quello del progetto. Dichiarato nelle previsioni.
7. **La documentazione del parametro `modello`** mancava nel primo commit del bundle: corretta (`75c18c9`).

# 8. Dubbi ricevuti (riquadro della S12p nell'handout)

| dubbio | come si chiude |
|---|---|
| (a) ingresso `28-…`, impronte `91-sha256.txt` | **chiuso**: verificate all'inizio e alla fine (K1) |
| (b) il limite con il conteggio vero | **spiegato** (§7.2): 3 confronti oltre il limite per modello, non 1; il confronto da 117 campioni resta oltre (57.745 token) |
| (c) segnali del codice separati da quelli del modello; quota di citazioni | **fatto** (§5, P13) |
| (d) descrizione e protocolli GEO; falsi allarmi come possibili errori del riferimento | **aperto**: dipende dalla lettura dei falsi allarmi (§9) |
| (e) i due confronti di GSE226005 | **fatto** (§4): puliti, passano con tutti e tre |

# 9. Dubbi aperti

| dubbio | come si chiude |
|---|---|
| P5 smentita per i tre modelli: il cancello di ADR-0028 non passa | **deciso** dall'handout: STOP, ADR-0028 torna `Proposed`, non si va al ricalcolo finale (S13); la via la sceglie il PI (§10) |
| K4 fallito per Gemma | **spiegato** (§6): seconda esecuzione, verdetto uguale in 1.903 confronti su 1.903; la causa del testo che cambia (backend Triton, 2 GPU) non e' isolata, e serve solo se Gemma andasse in produzione |
| P6 indeterminata (Mistral, Gemma), P13 indeterminata (Magistral) | **spiegato** (§3): non toccano una conclusione di questa sessione |
| lettura dei falsi allarmi del modello migliore (handout, punto 5): quanti sono errori del modello, della regola o del riferimento | **decisione del PI** (riassunto, punto 1) |
| quale via dopo il cancello fallito (regole, addestramento, prompt nuovo) | **decisione del PI** (riassunto, punto 2) |

# 10. Che cosa la prova vede e che cosa non vede

- Il riferimento non e' un campione neutro: 64 dei 193 vengono da allarmi di una regola che ne vede 81 (valutazione
  autonoma). Un falso allarme del modello puo' essere un difetto che il riferimento non ha.
- La prova e' cieca sugli esempi, non sulle categorie (spec §8): le voci della lista vengono dalle categorie dei 193.
- La prova misura una versione di prompt, schema, regola e tabella degli esiti. Ogni modifica decisa sui numeri di
  §5 andrebbe misurata su confronti che nessuno ha usato per scriverla: i 1.903 del deliverable non sono piu' ciechi
  per una versione 2.

# Da dove vengono i numeri del riassunto

| frase del riassunto | file | valore letto |
|---|---|---|
| 1.903 confronti, 193 difettosi, 1.710 puliti | `40-out.txt`, riga «riferimento» | «193 difettosi, 1710 puliti, su 1903 confronti» |
| almeno 130 presi, al massimo 40 accusati | `00-previsioni.md` di S12, P4 e P5 | «≥ 130», «≤ 40» |
| Mistral 186 su 193, 965 su 1.710 | `40-out.txt`, «== mistral ==», P4 e P5 | «186 su 193», «965 su 1710» |
| Magistral 177, 887 | `40-out.txt`, «== magistral ==» | «177 su 193», «887 su 1710» |
| Gemma 155, 364 | `40-out.txt`, «== gemma ==» | «155 su 193», «364 su 1710» |
| tutti i 48 difetti di tempo zero; Gemma 44 | `40-out.txt`, «presi per famiglia», riga «tempo zero» | 48 / 48 / 44 su 48 |
| tutti i 58 difetti trovati nei metadati; Gemma 52 | `40-out.txt`, riga «fonte = metadato» | «58 su 58», «58 su 58», «52 su 58» |
| 315 e 606 | `40-segnali.csv`, righe `CONDIZIONE_CON_AGENTE` e `ALTRA_DIFFERENZA`, colonna `falsi`, modello mistral | 315; 606 |
| 64 dei 193 dagli allarmi di una regola che vedeva 81 su 193 | `docs/findings/2026-11-07-valutazione-autonoma-del-progetto.md`, «Qualita' misurata» | «64 vengono da allarmi di una regola che ne vede 81/193» |
| almeno 324 dei 364 | 364 − 40 | 324 |
| 21 confronti rifatti con lo stesso testo | `30-cancelli.txt`, righe K4 | «21 su 21» (Mistral, Magistral) |
| Gemma cambia il testo nel 2%, stesso verdetto nei 1.903 | `50-gemma-ripetizione-out.txt` | «1855 su 1900» (45 diversi, 2,4%); «1903 su 1903» |
| 155 difetti presi da Gemma; 364 falsi allarmi | `40-out.txt` | come sopra |
| 323 puliti accusati da tutti e tre | `40-out.txt`, ultima riga | «falsi allarmi 323» |
| il rilevatore di agosto prendeva 81 su 193 | `CLAUDE.md` §1, «Rilevatore a regole» | «vede 81/193» |
| 30, 29 e 53 minuti; 4 GPU per modello | `30-sacct-pieno.txt`; `R/dgx-config`, template `run_p4.sh` (`--gres=gpu:4`) | 00:30:30, 00:29:10, 00:52:37 |
| 33 minuti di recupero | `log/catena.log`, righe «FINE recupero-…» | 4,3 + 4,3 + 24,8 min |
| circa 500 confronti da leggere | 364 + 155 | 519 |

[^rip]: `analysis/audit/2026-11-08-S12p-prova/50-gemma-ripetizione-out.txt`
