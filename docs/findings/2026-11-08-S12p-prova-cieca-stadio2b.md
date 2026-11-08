---
type: Finding
title: "La prova cieca dello Stadio 2b: nessun modello passa, al riferimento mancano 280 difetti, e metà dei difetti nasce nella scelta del confronto"
description: "S12p: Mistral-Small-3.2, Magistral-Small-2509 e Gemma-4-31B compilano la lista di controllo dello Stadio 2b sui 1.903 confronti del deliverable; la regola fissa decide; il conto cieco contro i 193 difettosi e i 1.710 puliti dice che nessun modello passa il cancello di ADR-0028 (almeno 130 presi, al massimo 40 falsi allarmi). La diagnosi dice che metà dei 473 difetti nasce quando lo Stadio 2 sceglie il confronto, e tre su dieci nello Stadio 1."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-08T19:20:00+01:00'}
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
- {id: prevl, resource: "analysis/audit/2026-11-08-S12p-prova/00-previsioni-lettura.md", title: "Lettura dei falsi allarmi: cancelli L1-L3 e previsioni R1-R5 (commit a65d6b1)"}
- {id: lett, resource: "analysis/audit/2026-11-08-S12p-prova/70-out.txt", title: "Lettura raccolta: L1, L2, classi, R1-R5"}
- {id: l3, resource: "analysis/audit/2026-11-08-S12p-prova/71-out.txt", title: "Che cosa hanno aperto i lettori (L3)"}
- {id: diag, resource: "analysis/audit/2026-11-08-S12p-prova/00-previsioni-diagnosi.md", title: "Diagnosi di dove nascono i 473 difetti: regole, cancelli G0-G5, previsioni D1-D9 (commit a5897aa, correzione 9c4513b)"}
- {id: diagout, resource: "analysis/audit/2026-11-08-S12p-prova/132-out.txt", title: "Dove nasce il difetto, tabella finale (con 130-out.txt, 131-out.txt, 133-out.txt)"}
---

# In breve

## In breve: un modello sa trovare i confronti difettosi, e dove nascono i difetti?

**A cosa serviva.** Il nuovo passo della pipeline fa leggere a un modello il testo dei campioni dei due bracci. Una regola fissa decide se il confronto entra nella meta-analisi. La prova ha misurato tre modelli su tutti i 1.903 confronti del deliverable. Poi, su tua richiesta, abbiamo cercato in quale passo della pipeline nasce ogni confronto difettoso, per correggere l'errore dove nasce e non dopo. Il modello lavora in due passi: il primo scrive i fatti di ogni campione, il secondo riceve solo questi fatti e sceglie i confronti.

**Cosa abbiamo trovato.**

1. **Nessun modello passa la prova, e non bastano né un prompt nuovo né il codice da solo.** Mistral accusa metà dei confronti puliti anche con il prompt nuovo, 713 su 1.430, e la soglia è 40. Gemma ne accusa 138. Il confronto fatto solo dal codice prende metà dei difetti e accusa un confronto pulito su quattro.
2. **Il riferimento dei 193 difetti è incompleto: altri 280 confronti non sono confrontabili.** Due letture indipendenti concordano quasi sempre su questi 280 confronti, e le tue regole sui donatori sono applicate. Quindi un confronto su quattro del deliverable non è confrontabile, e non uno su dieci.
3. **In metà dei difetti il secondo passo aveva la differenza fra i bracci, e ha costruito il confronto lo stesso.** Il suo prompt chiede condizioni identiche dentro un gruppo, e il modello lo rispetta quasi sempre. Unisce condizioni diverse solo in 12 difetti su 473 e in 45 confronti puliti su 1.430. Per un confronto il prompt chiede solo un controllo riconoscibile, e permette il tempo zero come controllo. Le differenze più nette sono quasi assenti nei confronti puliti. I tempi diversi compaiono in 53 difetti e in 5 puliti, il controllo a tempo zero in 31 difetti e in nessun pulito, il secondo agente solo nel trattato in 30 difetti e in 6 puliti.
4. **In tre difetti su dieci il primo passo ha letto la differenza, soprattutto nel titolo, e non l'ha scritta.** Senza la differenza nei fatti, il codice mette campioni diversi nella stessa condizione, e il secondo passo non li può separare. Il resto è piccolo: 36 difetti stanno in donatore, età, sesso o passaggio, che il codice ignora per costruzione. Altri 35 stanno solo nella descrizione o nei protocolli, che nessun passo legge, e 21 sono nomi di entità sbagliati.
5. **Il ricalcolo finale riporterebbe tutti i 473 difetti.** Il nuovo calcolo dei due passi, fatto da zero a novembre, dà gruppi e confronti identici in tutti i 993 studi. Una correzione deve cambiare la catena, perché ripetere il calcolo non toglie niente.

**Cosa devi decidere.**

1. **Mettiamo i 280 difetti nel riferimento? Raccomando di sì, marcati come trovati da due letture automatiche concordi.** Il riferimento decide ogni misura futura, e oggi gli manca più di metà dei difetti noti.
   - Se rispondi sì, il riferimento passa da 193 a 473 difetti, e ogni prova futura usa quello.
   - Se rispondi no, ogni prova futura conta come falsi allarmi questi 280 difetti veri.
2. **Dove correggiamo per primo? Raccomando il secondo passo: chiedere confronti con i bracci uguali in tutto tranne il trattamento, senza il tempo zero come controllo.** Lì nasce metà dei difetti, e il modello ha già l'informazione. Il modello rispetta già una regola dello stesso tipo per i gruppi. Il rischio: i fatti del primo passo differiscono anche in un confronto pulito su tre, per donatore, malattia o tessuto. Per questo la misura deve contare i difetti tolti e i confronti puliti persi.
   - Se scegli il primo passo, la correzione tocca tre difetti su dieci, ma cambia i fatti di 508.037 campioni e tutto il calcolo a valle.
   - Se scegli il secondo passo e poi il primo, la correzione tocca circa otto difetti su dieci. Servono due cicli di calcolo e di misura.
   - Se tieni il passo che giudica dopo, resta il risultato di oggi: nessun modello passa, e le istruzioni non lo vincolano.

**Comunque.** Il passo che giudica dopo non entra nella pipeline, e il ricalcolo finale non parte. La decisione di novembre sul nuovo passo resta una proposta. Ogni correzione va misurata prima del ricalcolo, su tutti i confronti, e la misura conta i difetti tolti e i confronti puliti persi.

Appena decidi questi 2 punti, la sessione è chiusa.

**Sui tempi di calcolo.** Sul DGX i tre modelli hanno lavorato 30 minuti (Mistral), 29 minuti (Magistral) e 53 minuti (Gemma), con 4 GPU H100 per modello. Il recupero delle risposte non valide ha richiesto 33 minuti, la ripetizione di Gemma altri 53, il prompt nuovo di Mistral 27. Le tre letture automatiche hanno usato 59 agenti, ognuno con circa 150.000 token, per circa mezz'ora in tutto. La diagnosi non ha usato il DGX: ha letto i master su questo computer.

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
| lettura dei falsi allarmi del modello migliore (handout, punto 5) | **deciso** dal PI il 2026-11-08: letti i falsi allarmi di Gemma e di Mistral (§11) |
| il riferimento manca 318 difetti secondo i lettori (§11) | **spiegato** con una seconda lettura indipendente (§12): 280 confermati con le regole del PI; se entrano nel riferimento e' **decisione del PI** (riassunto, punto 1) |
| la scheda della prima lettura non diceva che i soggetti parziali sono avvisi | **corretto** nella lettura mirata (§12): 30 confronti tornano avvisi |
| prompt nuovo e codice da solo (richiesta del PI, §13) | **spiegato**: nessuno dei due basta (A1, A2, B1, B3, B4 smentite) |
| dove nascono i 473 difetti (richiesta del PI, §14) | **spiegato**: metà nella scelta del confronto dello Stadio 2, tre su dieci nello Stadio 1; D1 e D5 smentite e spiegate (§14.4); D8 smentita: i bracci di più condizioni sono rari; G5 al limite, spiegato (§14.2) |
| il ricalcolo finale sui master S14 riporta i 473 difetti (D9) | **spiegato** (§14.4): gruppi e confronti identici in 993 studi su 993; si chiude con la correzione scelta dal PI |
| quale via dopo il cancello fallito e dopo la diagnosi | **decisione del PI** (riassunto, punto 2) |

# 10. Che cosa la prova vede e che cosa non vede

- Il riferimento non e' un campione neutro: 64 dei 193 vengono da allarmi di una regola che ne vede 81 (valutazione
  autonoma). Un falso allarme del modello puo' essere un difetto che il riferimento non ha.
- La prova e' cieca sugli esempi, non sulle categorie (spec §8): le voci della lista vengono dalle categorie dei 193.
- La prova misura una versione di prompt, schema, regola e tabella degli esiti. Ogni modifica decisa sui numeri di
  §5 andrebbe misurata su confronti che nessuno ha usato per scriverla: i 1.903 del deliverable non sono piu' ciechi
  per una versione 2.

# 11. La lettura dei falsi allarmi (decisione del PI, 2026-11-08)

**Disegno**[^prevl]. 1.236 pacchetti ciechi: 988 falsi allarmi di Mistral o di Gemma con affermazioni (338 di tutti e
due), 188 difetti presi (controllo positivo), 60 puliti non accusati da nessun modello (campione). Identificativo
opaco, ordine mescolato, fonti anonime. 42 agenti di revisione interna (Claude, stesso modello della sessione), un lotto
da 29-30 pacchetti ciascuno, con la scheda `61-scheda-lettura.md` (regole del progetto: §5 della spec e decisioni del
PI). Pacchetti fuori dal repository, impronte in `61-manifesto-pacchetti.sha256`, chiave fuori dalla cartella dei
lettori fino alla fine (`62-chiave.json`, stessa impronta). I lettori hanno lavorato circa 15 minuti in tutto, venti
alla volta; circa 155.000 token ciascuno.

**Cancelli**[^lett][^l3]

| # | cancello | esito |
|---|---|---|
| L1 | 1.236 letture valide | **passa**: 1.236 su 1.236, nessuna difforme |
| L2 | i lettori riconoscono almeno l'80% dei difetti noti (esclusi i «non provati») | **passa**: 149 su 177 = 84,2% [78,1; 88,8]; 3 incerti. Dei 11 «non provati», 7 giudicati non confrontabili |
| L3 | ogni lettore apre solo scheda, lotto, pacchetti; scrive solo il suo file | **passa**: 1.236 pacchetti aperti su 1.236; una chiamata fuori dalla scheda (lotto 34: `ls` della cartella delle risposte, solo i nomi dei file, nessun contenuto) |

Quattro lettori hanno scritto il file di risposta in modo diverso dalla scheda (in due volte, o con `cat >>`): il
contenuto e' valido (L1).

**Previsioni**

| # | quantita' | atteso | rilevanza | risultato [IC 95%] | giudizio |
|---|---|---|---|---|---|
| R1 | falsi allarmi di Gemma giudicati non confrontabili | 20% | 10%-100% | **238 su 360 = 66,1%** [61,1; 70,8] | confermata (molto sopra l'atteso) |
| R2 | falsi allarmi di Mistral giudicati non confrontabili | 12% | 10%-100% | **299 su 962 = 31,1%** [28,2; 34,1] | confermata |
| R3 | `CONDIZIONE_CON_AGENTE` di Mistral giudicata falsa | 85% | 70%-100% | **301 su 315 = 95,6%** [93,0; 97,8] | confermata |
| R4 | `ALTRA_DIFFERENZA` di Mistral vera ma non un difetto | 50% | 40%-100% | **334 su 606 = 55,1%** [51,2; 58,9]; falsa 135, vera e difetto 119 | confermata |
| R5 | puliti non accusati giudicati non confrontabili (campione di 60) | 5% | 0%-10% | 5 su 60 = 8,3% [3,6; 18,1]; 1 incerto | indeterminata |

R5 e' indeterminata e non tocca una conclusione: anche con l'estremo superiore (18%) i falsi allarmi giudicati difettosi
(66% e 31%) restano molto sopra la base; e R5 va nella stessa direzione di R1 e R2 (il riferimento manca difetti anche
dove nessun modello accusa).

**Le classi dei falsi allarmi**

| classe | Gemma (360) | Mistral (962) |
|---|---|---|
| riferimento (il lettore trova un difetto) | 238 (66,1%) | 299 (31,1%) |
| modello (affermazione falsa, confronto confrontabile) | 70 (19,4%) | 462 (48,0%) |
| regola (fatti veri che non sono difetti) | 48 (13,3%) | 186 (19,3%) |
| incerto | 4 (1,1%) | 15 (1,6%) |

**318 confronti** che il riferimento da' per puliti sono non confrontabili per i lettori (unione dei due modelli), in
197 studi (`70-difetti-non-nel-riferimento.csv`). Primo tipo di difetto: materiale, linea o sede 87; soggetti 61; altro
28; coltura 24; genotipo 23; tempo diverso 21; entita' 17; braccio misto 15; tecnica 14; tempo zero 14; agente nel
controllo 9; secondo agente 5. Una lettura mia di 8 casi a caso (seme 20261108) trova difetti plausibili, quasi tutti
di composizione: un braccio mescola campioni (frazioni, genotipi TP53+/+ e TP53-/-, terreni, linea parentale e cloni)
che l'altro braccio non ha. Il riferimento di S11 e' stato costruito leggendo soprattutto le etichette (135 su 193) e non
vede questo tipo di difetto.

**Che cosa dice e che cosa non dice.**

- Se i lettori hanno ragione, almeno 511 confronti su 1.903 (193 + 318 = 26,9%) non sono confrontabili, non 193 (10,1%).
  Il numero vero e' piu' alto: i confronti che nessun modello accusa sono stati letti solo a campione (R5), e quelli
  accusati solo da Magistral non sono stati letti.
- Anche con questi difetti nessun modello passa: restano 122 accuse sbagliate per Gemma (360 − 238 riferimento − 4
  incerti, piu' 4 confronti scartati senza lista) e 651 per Mistral (962 − 299 − 15, piu' 3). La soglia e' 40.
- Gli errori di Mistral sono concentrati: la malattia del donatore scritta come agente (301 affermazioni false) e la
  voce aperta (135 false, 334 vere ma non difetti). `DIVERSO_DONATORE` di Mistral e' vera ma non un difetto in 160 casi
  su 182: nei confronti malati contro sani, quando la malattia e' scritta come agente, la regola non riconosce il
  disegno caso-controllo e accusa i donatori diversi. Gli errori di Gemma sono sparsi: eta' o stadio (35 falsi),
  entita' diversa (36 falsi), tempo (7 falsi e 14 non verificabili), nessuna differenza (9 falsi).
- **Limite**: i lettori sono agenti automatici, non verificati da una persona su questa lettura; vedono le affermazioni
  delle fonti, e questo puo' orientarli (pero' giudicano false 301 affermazioni su 315 in R3, quindi non le accettano
  in blocco). Ogni nuovo conto contro un riferimento allargato da questa lettura favorisce i due modelli letti, perche'
  i nuovi difetti sono stati cercati fra le loro accuse.

# 12. La verifica dei 318 difetti, senza il PI

Il PI non legge a mano (2026-11-08). La conferma l'ha fatta una seconda lettura indipendente, senza le affermazioni dei
modelli (`00-previsioni-verifica.md`, commit `25e2443`; scheda `81-scheda-verifica.md`; 15 agenti nuovi).

| # | cancello o previsione | atteso | rilevanza | risultato [IC 95%] | giudizio |
|---|---|---|---|---|---|
| V1 | letture valide | 438 | — | **438 su 438** | passa |
| V2 | difetti noti riconosciuti | ≥ 80% | — | **49 su 60 = 81,7%** [70,1; 89,4] | passa |
| V3 | lettori dentro la scheda | — | — | 438 pacchetti aperti su 438, nessuna chiamata fuori | passa |
| Q1 | i 318 ritrovati senza affermazioni | 75% | 70%-100% | **310 su 318 = 97,5%** [95,1; 98,7] | confermata |
| Q2 | confrontabili per la prima lettura, difettosi per la seconda | 15% | 0%-25% | **0 su 60** [0,0; 6,0] | confermata |
| Q3 | accordo fra le due letture (438) | kappa 0,6 | 0,6-1 | **kappa 0,94** [0,89; 0,98]; 430 concordi su 438 | confermata |

Fra i 310 ritrovati, il primo tipo di difetto e' lo stesso nelle due letture in 283 casi. Per tipo, i ritrovati sono
86 su 87 (materiale, linea o sede), 60 su 61 (soggetti), 24 su 28 (altro), tutti gli altri tipi da 8 su 9 a 24 su 24.

**I soggetti e le decisioni del PI.** La scheda non diceva che una sovrapposizione parziale di donatori, sesso o eta' e'
un avviso (decisione 3 del PI in S12); un lettore lo ha segnalato. Dei 310, 45 avevano come unico difetto i soggetti in
tutte e due le letture. Una lettura mirata (2 agenti, aggiunta depositata prima, `93-scheda-soggetti.md`) li ha
classificati: 36 confronti di trattamento (donatori disgiunti 6, parziali 30) e 9 malati contro sani (eta' o sesso
disgiunti in tutti e 9). Con le regole del PI restano difetti 15 e diventano avvisi 30. I due controlli scelti prima
(GSE219065, un paziente per braccio; GSE185051, eta' senza valori in comune) risultano difetti[^sogg].

**Risultato: 280 confronti** che il riferimento da' per puliti sono non confrontabili per due letture indipendenti e per
le regole del PI, in 171 studi (`94-difetti-finali.csv`). Con questi il riferimento passerebbe da 193 a 473 difetti su
1.903 (24,9%).

**Conto descrittivo contro il riferimento allargato** (favorisce Gemma e Mistral, perche' i 280 sono stati cercati fra le
loro accuse; Magistral non e' stato letto):

| modello | presi su 473 | puliti accusati su 1.430 |
|---|---|---|
| Mistral | 451 (95,3%) | 700 (49,0%) |
| Magistral | 425 (89,9%) | 639 (44,7%) |
| Gemma | 381 (80,5%) | 138 (9,7%) |

Dei 700 falsi allarmi di Mistral, 587 hanno fra i motivi `CONDIZIONE_CON_AGENTE` o `ALTRA_DIFFERENZA`; 113 nessuno dei due.

**Che cosa la verifica non dice.** Le due letture sono agenti Claude con la stessa scheda: l'accordo (kappa 0,94) misura
che il giudizio si ripete, non che coincide con quello di una persona. Il riferimento di S11 ha la stessa natura (lettura
di agenti, con un controllo del PI su 19 meta-analisi in S3). Il progetto non usa Claude nella pipeline ne' nella
validazione pubblicata: i 280 servono alle misure interne e alla scelta della strada; se una decisione della pipeline
dovra' toglierli dal deliverable, la dovra' prendere un passo deterministico o il modello del progetto.

# 13. A monte: il codice da solo, e un prompt nuovo (richiesta del PI, 2026-11-08)

Il PI: «Mistral sbaglia anche se glielo diciamo... bisogna trovare un modo per non farlo sbagliare a monte»; poi «misura,
dimmi esattamente cosa dice il prompt, forse basta cambiare quello, prova anche quest'ultima soluzione». Previsioni in
`00-previsioni-monte.md` (commit `16a48ed`, correzione prima del calcolo `2d644f1`). Riferimento allargato (473 difetti,
1.430 puliti); **nessuno di questi numeri è una prova cieca**.

**A. Il codice da solo** (`100-senza-modello.R`, `100-out.txt`): le coppie «chiave: valore» di `characteristics_ch1` e
`source_name_ch1` di ogni campione, confrontate per codice fra i bracci, esclusi identificativi, chiavi di replica e la
chiave dell'entità.

| # | quantità | atteso | rilevanza | risultato [IC 95%] | giudizio |
|---|---|---|---|---|---|
| A1 | difetti presi | 55% | 70%-100% | 242 su 473 = 51,2% [46,7; 55,6] | **smentita** |
| A2 | puliti accusati | 20% | 0%-10% | 339 su 1.430 = 23,7% [21,6; 26,0] | **smentita** |
| A3 | difetti con un braccio mescolato | 60% | — | 186 su 473 = 39,3% | — |
| A4 | puliti con un braccio mescolato | 25% | — | 283 su 1.430 = 19,8% | — |
| A5 | confronti con almeno 2 chiavi strutturate | 70% | — | 1.903 su 1.903 | — |

Il codice non sa che cosa vuol dire una chiave: accusa per misure di qualità dell'RNA (RIN, concentrazione, volume),
numeri di campione, dosi, e per l'età nei confronti malati contro sani. Il braccio mescolato è due volte più frequente
fra i difetti (39%) che fra i puliti (20%), ma da solo non li separa. 212 confronti non hanno una chiave riconosciuta come
entità.

**B. Il prompt v2** (`inst/prompts/stage2b-v2.md`, SHA-256 `d1bbaad2…`): cambiano solo gli agenti (due domande prima di
scrivere un agente: applicato dagli sperimentatori? non una condizione del donatore?) e le altre differenze (quattro
condizioni). Schema, regola, configurazione invariati; Mistral, job 470101 (26 min 53 s), nessuna lista da recuperare,
token contati = vLLM 1.900 su 1.900; uscite in `analysis/p4-output/S12p-uscite-v2/` (impronte `110-uscite-v2-sha256.txt`,
copia su micron). Il prompt v2 è arrivato al modello (verificato sul bundle nel DGX); 62 uscite su 1.903 identiche a v1.

| # | quantità | v1 | atteso v2 | rilevanza | v2 [IC 95%] | giudizio |
|---|---|---|---|---|---|---|
| B1 | puliti accusati, su 1.430 | 700 | 300 | 0-40 | **713** (49,9% [47,3; 52,4]) | **smentita** |
| B2 | difetti presi, su 473 | 451 | 420 | 317-473 | 438 (92,6% [89,9; 94,6]) | confermata |
| B3 | confronti con `CONDIZIONE_CON_AGENTE` | 347 | 50 | 0-35 | **198** | **smentita** |
| B4 | confronti con `ALTRA_DIFFERENZA` | 707 | 300 | 0-70 | **731** | **smentita** |

Il verdetto cambia in 182 confronti (puliti: 75 non più accusati, 88 accusati di nuovo; difetti: 16 persi, 3 nuovi). Fra i
713 puliti accusati, 439 hanno un solo segnale: `ALTRA_DIFFERENZA` da solo 273, `CONDIZIONE_CON_AGENTE` da solo 45. Il
prompt ha ridotto la malattia scritta come agente del 43%, non l'ha tolta; le quattro condizioni sulla voce aperta non
hanno avuto effetto (707 → 731). **Cambiare il prompt non basta**: le istruzioni non vincolano il modello su questi due
punti.

# 14. Dove nascono i 473 difetti (diagnosi, richiesta del PI, 2026-11-08)

Il PI: «fai la diagnosi». Domanda: per ogni confronto difettoso, qual è l'ultimo passo della pipeline che **aveva**
l'informazione che rende i bracci non confrontabili. Previsioni, regole e cancelli in `00-previsioni-diagnosi.md`
(commit `a5897aa`; correzione dello strumento dopo G3, prima delle classi, `9c4513b`)[^diag]. Script `130-diagnosi.R`
(uscita `130-out.txt`, tabella `130-diagnosi.csv`), poi tre analisi descrittive dopo il calcolo, non nelle previsioni:
`131-dove-sta-la-prova.R`, `132-sintesi.R`, `133-s14-uguale.py`. Nessun file della pipeline è cambiato.

**14.1 La catena, letta nel codice.** Lo Stadio 1 legge per ogni campione `title`, `source` e `characteristics`
(non la descrizione, non i protocolli, non i campi tecnici) e scrive i fatti. Il codice corregge il flag del tempo zero
(`normalize_stage1_facts_zt()`), poi mette nella stessa **condizione** i campioni con la stessa firma di disegno; la
firma esclude donatore, età, sesso, ascendenza, passaggio, trattamenti tecnici. Il modello dello Stadio 2 riceve
**solo** i fatti di un campione rappresentante per condizione (con `n_replicates`); `study_summary` è vuoto in 2.728
ingressi su 2.728. Scrive gruppi (unioni di condizioni) e confronti (coppie di gruppi). Lo Stadio 3 fa un record per
confronto. Il prompt dello Stadio 2 (`R/llm-stage2.R::.stage2_system_prompt()`) dice, per i gruppi: «Group into the SAME
replicate_group ONLY samples with IDENTICAL conditions (same treatment, dose, time, cell line, genotype)»; per i
confronti dice solo: «Create comparisons only where a control_group is clearly identifiable», e «RULE 2 (time-zero =
control): in time_course designs, samples with time=0 [...] are primary_role='control'». **Il prompt non chiede che i
due bracci di un confronto differiscano solo per il trattamento.**

**14.2 Cancelli.** G0 manifesto del deliverable e dei master: OK. G1 bracci del dispatch uguali ai gruppi del master A3:
1.903 su 1.903. G2 fatti e condizioni per ogni campione, bracci fatti di condizioni intere: 1.903 su 1.903. G3 firma
uguale dentro la condizione: prima 3.407 su 3.423; le 16 differenze erano solo `is_zero_timepoint`, perché il master
conserva i fatti prima della correzione del tempo zero; con i fatti corretti 3.423 su 3.423 (correzione dichiarata nelle
previsioni prima di vedere le classi). G4 cinque confronti finti, uno per classe: OK. G5 difetti dei 193 visibili nelle
etichette dello Stadio 2 in classe A: 104 su 129 = 80,6% [73,0; 86,5], **al limite** della soglia dell'80%. I 25 mancati
sono soprattutto secondi agenti scritti dallo Stadio 1 come un solo agente («T3 and LPS») e controlli condivisi fra bracci
a tempi o donatori diversi: la regola conta gli agenti, non le parole. Lo strumento vede quindi meno di quanto lo Stadio 2
vedeva.

**14.3 Previsioni.** Unità: il confronto; Wilson al 95%; differenze con bootstrap per studio, B = 2000, seme 20261108.

| # | quantità | atteso | rilevanza | risultato [IC 95%] | giudizio |
|---|---|---|---|---|---|
| D1 | classe A per tipo («lo Stadio 2 l'ha vista») | 55% | 50%-100% | 199 su 473 = 42,1% [37,7; 46,6] | **smentita**; spiegata in 14.4: con le etichette 240 su 473 = 50,7% [46,2; 55,2] |
| D2 | A-unione (un braccio unisce condizioni diverse) | 15% | 20%-100% | 1 su 473 = 0,2% [0,0; 1,2] | fuori dall'intervallo: **non è una causa** |
| D3 | classe B (la firma nasconde) | 8% | 15%-100% | 37 su 473 = 7,8% [5,7; 10,6] | fuori: non è una causa grande |
| D4 | classe C (lo Stadio 1 legge una chiave e non scrive) | 15% | 25%-100% | 37 su 473 = 7,8% [5,7; 10,6] | fuori; ma vedi 14.4: con il titolo sono 139 |
| D5 | classe D (nessun passo la legge) | 15% | 25%-100% | 179 su 473 = 37,8% [33,6; 42,3] | **smentita**; spiegata in 14.4: la prova sta quasi sempre nel titolo o in `characteristics` |
| D6 | classe E (nome dell'entità) | 8% | — | 21 su 473 = 4,4% | — |
| D7 | classe A con tutte le famiglie, difettosi meno puliti | +20 punti | +10 / +100 | 59,6% contro 34,9%: **+24,7 [+13,6; +34,7]** | confermata: la classe A distingue i difetti |
| D8 | braccio di 2+ condizioni, difettosi meno puliti | +10 punti | +5 / +100 | 2,5% contro 3,1%: **−0,6 [−3,1; +2,5]** | **smentita**: i bracci di più condizioni sono rari e non distinguono i difetti |
| D9 | stessi bracci nel master S14 dello Stadio 2 | 85% | 80%-100% | 473 su 473 (puliti 1.430 su 1.430) | confermata; spiegata: gruppi e confronti di S14 sono identici ad A3 in 993 studi su 993 (`133-out.txt`) |

**14.4 Dove nasce il difetto** (`132-out.txt`). Unione dichiarata nello script prima del calcolo: classe A dello
strumento; fra i 193, i difetti che il lettore di S11 ha visto nelle **etichette** (le scrive lo Stadio 2, che legge solo
i fatti) contano come «lo Stadio 2 aveva l'informazione»; per i 280, ogni citazione del lettore si cerca nei campi GEO
dei campioni dei due bracci (`131-out.txt`).

| dove nasce | difetti su 473 [IC 95%] |
|---|---|
| lo Stadio 2 aveva l'informazione nei fatti, e ha costruito il confronto | 199 (42,1%) |
| lo Stadio 2 aveva l'informazione e l'ha scritta nell'etichetta | 41 (8,7%) |
| **totale: lo Stadio 2 aveva l'informazione** | **240 = 50,7% [46,2; 55,2]** |
| lo Stadio 1 l'ha letta (titolo, `characteristics`, `source`) e non l'ha scritta | **139 = 29,4% [25,5; 33,6]** |
| lo Stadio 1 l'ha scritta in un campo che la firma esclude (donatore, età, sesso, passaggio) | 36 = 7,6% [5,5; 10,4] |
| nessun passo legge il campo (descrizione, protocolli, campi tecnici) | 35 = 7,4% [5,4; 10,1] |
| nome dell'entità (chiave dello Stadio 3) | 21 = 4,4% [2,9; 6,7] |
| non attribuito (citazione non trovata) | 2 |

- **Il braccio misto non nasce nello Stadio 2.** In 461 difetti su 473 ogni braccio è una sola condizione; i bracci
  fatti di più condizioni sono 12 su 473 fra i difettosi e 45 su 1.430 fra i puliti, e solo in 1 difetto le condizioni
  unite differiscono nella famiglia del difetto. Il modello rispetta la regola dei
  gruppi. Quando un braccio contiene campioni diversi, il codice li aveva già messi nella stessa condizione, perché i
  fatti dello Stadio 1 erano uguali o differivano solo nei campi esclusi dalla firma.
- **La prova sta nei campi che lo Stadio 1 legge.** Fra i 280, la citazione del lettore sta in un campo letto dallo
  Stadio 1 in 233 casi, solo in campi non letti in 45, non si trova in 2. Fra i 121 della classe D, i campi più citati
  sono il titolo (54) e `characteristics` (33); la descrizione 28, i protocolli 22 (un difetto può citare più campi).
- **Segnali quasi esclusivi dei difetti**, fra i bracci, nei fatti che lo Stadio 2 ha ricevuto (`130-out.txt`): durate
  diverse 53 difettosi contro 5 puliti; controllo a tempo zero 31 contro 0; due o più agenti solo nel trattato 30 contro 6.
  Altri campi differiscono spesso anche fra i puliti: donatore 45 contro 66, stato di malattia 45 contro 111, tessuto 32
  contro 83, linea o tipo cellulare 37 contro 109. Per questo la classe A con tutte le famiglie copre anche il 34,9% dei
  puliti.
- **Il tempo zero.** Nessuno dei 1.903 confronti ha `control_type = time_zero` (il master A3 ne ha 4.451 in tutto). I 62
  difetti di tipo tempo zero hanno il controllo dichiarato `untreated` (47), `vehicle` (13), `genetic_negative` (2): lo
  Stadio 2 ha usato un gruppo a tempo zero come controllo, come la RULE 2 permette, e lo ha dichiarato come non trattato.
- **Il ricalcolo finale li riporta tutti.** Gruppi e confronti del master S14 sono identici a quelli di A3 in 993 studi su
  993: senza un cambio nella catena, il ricalcolo sui master S14 porta gli stessi 473 difetti.

**14.5 Che cosa la diagnosi non vede.** La classe dice dove l'informazione **c'era**, non che il passo dopo l'avrebbe
usata bene. Le famiglie sono regole sui nomi dei campi, e G5 è al limite: la quota «lo Stadio 2 aveva l'informazione» è
più probabilmente sotto la verità che sopra. La posizione della prova vale solo per i 280 (i lettori dei 193 non hanno
scritto citazioni). L'unione 14.4 è descrittiva, scritta dopo il calcolo dello strumento.

# Da dove vengono i numeri del riassunto

| frase del riassunto | file | valore letto |
|---|---|---|
| 1.903 confronti del deliverable | `40-out.txt`, riga «riferimento» | «193 difettosi, 1710 puliti, su 1903 confronti» |
| 713 su 1.430, soglia 40 | `120-out.txt`, Mistral v2; `00-previsioni.md` di S12, P5 | «713 su 1430»; «≤ 40» |
| Gemma 138 | §12, conto descrittivo | «138» |
| il codice prende metà dei difetti e accusa un pulito su quattro | `100-out.txt`, A1 e A2 | «242 su 473 = 51.2%»; «339 su 1430 = 23.7%» |
| altri 280 confronti | `94-out.txt`, ultima riga | «280 (tolti 30 avvisi), in 171 studi» |
| concordano quasi sempre | `90-out.txt`, Q3 | «kappa 0.94» |
| tue regole sui donatori applicate | `94-out.txt`; §12 | 15 difetti, 30 avvisi |
| uno su quattro, non uno su dieci | 473 / 1.903; 193 / 1.903 | 24,9%; 10,1% |
| il secondo passo riceve solo i fatti | §14.1; `prompts.py::render_user_message_stage2`; ingresso | «study_summary» vuoto in 2.728 su 2.728 |
| metà dei difetti: il secondo passo aveva la differenza | `132-out.txt`, «totale» | «240 su 473 = 50.7%» |
| unisce condizioni diverse in 12 difetti su 473 e in 45 puliti su 1.430 | `130-out.txt`, «braccio di 2+ condizioni» | «12 su 473 = 2.5%»; «45 su 1430 = 3.1%» |
| il prompt chiede solo un controllo riconoscibile e permette il tempo zero | `R/llm-stage2.R`, righe 137 e 171 | «Create comparisons only where a control_group is clearly identifiable»; «RULE 2 (time-zero = control)» |
| 53 e 5; 31 e nessuno; 30 e 6 | `130-out.txt`, campi fra i bracci | `tempo:dur` 53/5; `tempo:is_zero_timepoint` 31/0; `agente:agenti_solo_trattato` 30/6 |
| tre su dieci: il primo passo ha letto e non ha scritto | `132-out.txt` | «139 su 473 = 29.4%» |
| soprattutto nel titolo | `131-out.txt`, campi della classe D | title 54, characteristics_ch1 33, description 28 |
| 36, 35, 21 | `132-out.txt` | «36 su 473», «35 su 473», «21 su 473» |
| identici in tutti i 993 studi; tutti i 473 | `133-out.txt`; `130-out.txt`, D9 | «gruppi e confronti identici: 993»; «473 su 473» |
| più di metà dei difetti noti | 280 / 473 | 59% |
| un confronto pulito su tre | `130-out.txt`, classe A con tutte le famiglie | «puliti 499 su 1430 = 34.9%» |
| donatore, malattia o tessuto | `130-out.txt`, campi fra i bracci nei puliti | donor_id 66, ds_status 111, tissue 83, cell_type_or_line_raw 109 |
| 508.037 campioni | `CLAUDE.md` §2, Stadio 0 | «bacino 508.037 campioni» |
| circa otto su dieci | (240 + 139) / 473, `132-out.txt` | 80,1% |
| 30, 29, 53 minuti; 4 GPU H100 | `30-sacct-pieno.txt`; `inst/dgx/slurm/run_p4.sh` | 00:30:30, 00:29:10, 00:52:37 |
| 33 minuti di recupero; 53 della ripetizione; 27 del prompt nuovo | `log/catena.log`; §13 | 4,3 + 4,3 + 24,8 min; 00:52:49; 26 min 53 s |
| 59 agenti, circa 150.000 token, circa mezz'ora | 42 + 15 + 2 agenti; rapporti degli agenti; date dei file di risposta (18:40-18:54, 19:39-19:49) | da 117.114 a 183.389 token per agente |

[^rip]: `analysis/audit/2026-11-08-S12p-prova/50-gemma-ripetizione-out.txt`
[^prevl]: `analysis/audit/2026-11-08-S12p-prova/00-previsioni-lettura.md`
[^lett]: `analysis/audit/2026-11-08-S12p-prova/70-out.txt`
[^l3]: `analysis/audit/2026-11-08-S12p-prova/71-out.txt`
[^sogg]: `analysis/audit/2026-11-08-S12p-prova/94-out.txt`, `94-soggetti.csv`
[^diag]: `analysis/audit/2026-11-08-S12p-prova/00-previsioni-diagnosi.md`, `130-out.txt`, `131-out.txt`, `132-out.txt`, `133-out.txt`
