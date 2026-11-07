---
type: Finding
title: "Sui fatti dei campioni il rilevatore trova un terzo dei confronti mal appaiati, con 40 falsi allarmi"
description: "La regola che confronta i fatti dello Stadio 1 dei campioni trattati e di controllo, misurata su tutti i 1.903 confronti del deliverable contro i 129 confronti difettosi della S10. Intera prende 56 difettosi con 184 falsi allarmi; la combinazione scelta col criterio depositato prende 43 difettosi con 40 falsi allarmi."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-07T20:30:00+01:00'}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/00-previsioni.md", title: "Cancelli, previsioni e criterio di scelta, depositati prima della misura (commit 3defd61)"}
- {id: regola, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/10-regola.py", title: "La regola, congelata"}
- {id: estrai, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/20-estrai-out.txt", title: "I fatti dei 15.559 campioni e lo SHA-256 del master"}
- {id: misura, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/40-out.txt", title: "La misura: cancelli, sotto-regole, scelta, previsioni"}
- {id: esiti, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/40-esiti.csv", title: "Gli esiti sui 1.903 confronti"}
- {id: falsi, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/40-falsi-allarmi.csv", title: "I 56 allarmi da leggere della combinazione proposta"}
- {id: nonvisti, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/40-difetti-non-visti.csv", title: "Gli 86 difetti che la combinazione proposta non vede"}
- {id: diagnosi, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/45-out.txt", title: "Perche' la regola intera non vede 52 difetti"}
- {id: opzioni, resource: "analysis/audit/2026-11-07-S10b-metadati-campioni/46-out.txt", title: "Le opzioni per la lettura"}
- {id: s10, resource: "docs/findings/2026-11-07-S10-rilevatore.md", title: "La regola sulle etichette e il riferimento dei 129"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi, non toccato"}
---

# In breve

## In breve: i fatti scritti per ogni campione trovano i confronti mal appaiati che le etichette non vedono?

**A cosa serviva.** Secondo la rilettura di agosto, 129 confronti del deliverable sono mal appaiati. La regola sulle etichette ne trova 10, perché l'informazione che rompe il confronto sta di solito su un braccio solo. Per ogni campione il modello ha scritto gli agenti, la durata, il donatore, il sesso, l'etnia, il materiale, la sede e il passaggio. Abbiamo scritto una regola che confronta questi fatti fra i campioni trattati e i campioni di controllo. L'abbiamo misurata su tutti i 1.903 confronti, con la stessa soglia di 85 falsi allarmi.

**Cosa abbiamo trovato.**

1. **La regola intera trova 56 confronti mal appaiati su 129, ma fa 184 falsi allarmi su 1.704 confronti puliti.** È più del doppio della soglia di 85, quindi la regola intera non va alla lettura.
2. **Il criterio che avevo depositato tiene quattro parti della regola, e la combinazione trova 43 difetti su 129 con 40 falsi allarmi.** Le quattro parti guardano il secondo agente, il tempo in due modi e il passaggio di coltura. A queste si aggiunge la parte della regola sulle etichette che non fa falsi allarmi. La sensibilità è un po' ottimistica, perché la scelta usa lo stesso riferimento della misura.
3. **I fatti dei campioni vedono soprattutto il secondo agente e il tempo.** La combinazione trova 29 dei 41 secondi agenti e 10 dei 19 tempi non appaiati, mentre la regola sulle etichette ne trovava 3 e 0. Non vede quasi nessuna differenza di materiale, donatore, sesso o etnia. In quei campi il modello scrive bracci misti, oppure lo stesso tipo di materiale per due linee cellulari diverse.
4. **La parte sul materiale è rimasta fuori per due falsi allarmi.** Con il materiale la combinazione trova 50 difetti con 87 falsi allarmi. In 27 dei suoi 48 falsi allarmi un braccio è «coltura primaria» e l'altro è «tessuto», e in almeno uno studio il modello usa i due valori per campioni dello stesso disegno.
5. **Nel riferimento i controlli a tempo zero sono giudicati in modo diverso nello stesso studio.** In uno studio la rilettura accusa 5 confronti su 11 con lo stesso controllo a tempo zero. Questo pesa sul conto dei falsi allarmi, e la lettura dei falsi allarmi lo deve chiarire.

**Cosa devi decidere.**

1. **Quale regola va alla lettura dei falsi allarmi? Consiglio la combinazione scelta dal criterio: 56 righe da leggere in una sessione.** Le righe sono i 40 falsi allarmi e 16 confronti degli studi accusati che la rilettura non nomina. Il criterio era scritto prima della misura, e la combinazione rispetta la soglia che hai fissato.
   - In alternativa aggiungi il materiale. La regola trova 7 difetti in più, ma fa 87 falsi allarmi, cioè 2 oltre la soglia, e le righe da leggere salgono a 106.
   - In alternativa leggiamo i 54 allarmi della regola sulle etichette. Quella regola trova solo 10 difetti su 129.
   - In alternativa fermiamo qui il rilevatore e scriviamo il limite nei Methods. Nessun difetto si toglierebbe in automatico.

**Comunque:**

- il deliverable, i master, la copia di salvataggio e il codice del pacchetto non sono cambiati;
- la lettura dei falsi allarmi legge anche quei 16 confronti, e 13 di loro hanno un controllo a tempo zero;
- in produzione la regola dovrà leggere i fatti dei campioni nel passo che appaia i bracci, mentre oggi quel passo legge solo le etichette;
- le idee per migliorare la regola sono scritte per la sessione che la porta in produzione, e non le ho applicate.

Appena decidi questo punto, la sessione è chiusa.

**Sui tempi di calcolo.** I tempi sono misurati in questa sessione con un processore. L'estrazione dei fatti dal master ha richiesto 4 secondi, la regola meno di un secondo, la misura con 2.000 ricampionamenti 19 secondi.

# 1. Che cosa è stato fatto

**Oggetto.** I 1.903 confronti poolati del deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d` (`analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds`, elemento `tenuti`, colonne `gsm_t` e `gsm_c`). I fatti dello Stadio 1 vengono dal master `analysis/p4-output/A3-stage1-master-innestato.jsonl`, quello scritto in `run_metadata.json` dello Stadio 3 del deliverable. Il riferimento è quello della S10, senza cambi: 129 confronti difettosi, 1.704 puliti, 70 altri negativi[^s10].

**Il deposito.** Regola, misura, controlli e criterio di scelta sono nel commit `3defd61`, prima di applicare la regola a un solo confronto vero[^previsioni]. Prima del deposito ho guardato la distribuzione dei campi dello Stadio 1 sui 15.559 campioni, senza il riferimento, e i fatti dei casi di controllo, per dichiararne la visibilità come chiede l'handout.

**La regola** (`10-regola.py`[^regola]). Dodici sotto-regole, ognuna su un campo dello Stadio 1:

| sigla | nome | famiglia della rilettura | che cosa confronta |
|---|---|---|---|
| R1 | agente_in_piu | secondo agente | agenti del trattato (in più della metà dei campioni) assenti da ogni controllo; soglia 2 per farmaci, ambiente e infezioni, 1 per le malattie dopo aver tolto i termini di malattia e l'entità |
| R1c | agente_solo_ctrl | secondo agente | un agente non veicolo nella maggioranza dei controlli e in nessun trattato |
| R2a | tempo_diverso | tempo | `value_hours` dei due bracci senza valori in comune |
| R2b | ctrl_tempo_zero | tempo | controllo tutto a tempo zero (guard di `R/stage1-normalize.R`), trattato no |
| R3a | sesso | soggetto | M/F senza valori in comune |
| R3b | etnia | soggetto | `ancestry_or_population` senza valori in comune |
| R3c | donatore | soggetto | `donor_id` senza valori in comune; non nelle malattie e nelle infezioni |
| R4a | materiale_tipo | materiale | `context_kind` senza valori in comune |
| R4b | linea | materiale | `cell_line_cellosaurus_candidate` senza valori in comune |
| R5 | sede | sede | parole della sede (almeno 4 lettere, non generiche) senza parole in comune |
| R6 | passaggio | passaggio | `passage_or_state` senza valori in comune |
| R7 | genotipo | genotipo | una modifica ingegnerizzata nella maggioranza di un braccio e assente dall'altro |

**M** è l'unione delle 12. **R1x** (soglia a un agente tolta l'entità, la logica di V2 della S10) è una variante di confronto, fuori da M e dalla scelta. Le regole di aggregazione sono una sola: un campo vuoto su un braccio fa tacere la sotto-regola, perché un campo vuoto non prova un'assenza.

`R/` non è cambiato (`git diff --stat R/` vuoto).

# 2. Riproduzione e controlli

| cancello | esito |
|---|---|
| C1 manifesto a inizio e a fine sessione | `VERIFICA OK` due volte[^c1] |
| C2(a) SHA-256 del master letto uguale a `run_metadata.json` | `53f7f49a…`, uguale[^estrai] |
| C2(b) campioni trovati | 15.559 su 15.559, tutti con `parsed_json` e `valid_schema` TRUE |
| C2(c) insiemi e V3 della S10 | 129 / 1.704 / 70, uguali alla S10; V3 10 difettosi e 51 falsi allarmi; V1 più materiale 5 e 0[^misura] |
| C3 copertura | 1.903 su 1.903 con un esito per ogni sotto-regola |
| C4 controlli | R1 segnala `GSE139963` «Hypoxia + TGF-β1»; R2a o R2b segnala 11 su 11 confronti di `GSE126409` con controllo a tempo zero; R3b segnala `GSE97358` `grp_0002_vs_grp_0003`; M tace su `GSE139963` «TGF-β1» e su `GSE114686` «Lapatinib 1 µM 24h» |
| C5 codice di produzione intatto | `git diff --stat R/` vuoto |

**Visibilità dichiarata prima.** Negli altri quattro confronti di `GSE97358` lo Stadio 1 scrive bracci misti: il trattato «Chinese» contiene anche campioni «Indian», e il controllo «Malay» contiene un campione «Indian». L'etnia è scritta, ma non come differenza fra i bracci. Li ho dichiarati invisibili nel deposito.

# 3. La misura

**Ogni sotto-regola da sola** (bootstrap degli studi, B = 2000, seme 20261107[^misura]):

| sotto-regola | segnalati | difettosi (su 129) | IC95 | falsi allarmi (su 1.704) | IC95 | altri negativi (su 70) |
|---|---:|---:|---|---:|---|---:|
| R1 agente_in_piu | 48 | 30 (23,3%) | [14,3; 33,8] | 16 | [9; 25] | 2 |
| R1c agente_solo_ctrl | 26 | 1 | | 24 | [14; 37] | 1 |
| R2a tempo_diverso | 46 | 11 (8,5%) | [0,8; 19,0] | 21 | [10; 35] | 14 |
| R2b ctrl_tempo_zero | 31 | 5 | | 13 | [4; 25] | 13 |
| R3a sesso | 2 | 0 | | 2 | | 0 |
| R3b etnia | 2 | 1 | | 1 | | 0 |
| R3c donatore | 15 | 0 | | 15 | [4; 30] | 0 |
| R4a materiale_tipo | 62 | 11 (8,5%) | [3,9; 13,7] | 48 | [30; 69] | 3 |
| R4b linea | 3 | 0 | | 3 | | 0 |
| R5 sede | 39 | 6 | | 33 | [20; 47] | 0 |
| R6 passaggio | 5 | 1 | | 4 | | 0 |
| R7 genotipo | 43 | 3 | | 38 | [23; 58] | 2 |
| R1x (confronto) | 669 | 53 (41,1%) | [30,3; 53,1] | 589 | [515; 671] | 27 |

**Le regole intere:**

| regola | difettosi | IC95 | falsi allarmi | IC95 | altri negativi | sui 199 |
|---|---:|---|---:|---|---:|---:|
| M (12 sotto-regole) | 56 (43,4%) | [31,8; 55,8] | 184 | [148; 223] | 21 | 77 |
| M + V3 della S10 | 60 (46,5%) | [34,4; 59,1] | 228 | [188; 273] | 24 | 84 |
| V3 della S10 | 10 (7,8%) | [2,3; 14,4] | 51 | [28; 78] | 3 | 13 |

**Tabella a due entrate, M:** segnala 56 difettosi, 184 puliti, 21 altri negativi; tace su 73 difettosi, 1.520 puliti, 49 altri negativi.

**R1x conferma la S10.** Con la soglia a un agente e l'entità tolta per nome, la regola prende 53 difettosi ma segnala 589 puliti su 1.704: il nome che il modello scrive per l'agente non coincide quasi mai con i token dell'entità. Contare gli agenti in più, senza confrontare i nomi con l'entità, evita questo problema.

**Contributo marginale in M** (che cosa si perde togliendo la sotto-regola): R1 27 difettosi e 12 falsi allarmi; R4a 5 e 38; R2a 5 e 6; R7 3 e 30; R5 2 e 26; R1c 1 e 18; R6 1 e 4; R3c 0 e 12; R2b 0 e 0 (R2a vede tutti i suoi casi, perché il controllo a tempo zero ha `value_hours` 0).

**Per famiglia, i difettosi presi da M sono quasi tutti presi dalla sotto-regola della loro famiglia:** 47 su 56. Cinque stanno in famiglie senza sotto-regola («altro», «dose»), quattro sono presi da una sotto-regola di un'altra famiglia (`GSE225751`, `GSE141236`, `GSE134737`, `GSE269699`).

# 4. La scelta per la lettura

Applicato il criterio depositato[^previsioni] (`40-out.txt`, sezione «Scelta»):

1. tolte R3a, R3c, R4b: da sole prendono 0 difettosi con almeno un falso allarme;
2. unione delle rimaste: 212 falsi allarmi; tolta R3b (marginale 0 difettosi, 1 falso allarme);
3. 211: tolta R1c (1 e 18);
4. 193: tolta R5 (2 e 29);
5. 164: tolta R7 (2 e 27);
6. 137: tolta V3 della S10 (5 e 50);
7. 87: tolta R4a (7 e 47);
8. 40: fine.

**Combinazione proposta: R1 + R2a + R2b + R6 + la parte di V3 senza la soglia a un agente** (greche tradotte e regola sul materiale delle etichette).

| opzione | difettosi | IC95 | falsi allarmi | IC95 | altri negativi | da leggere | meta-analisi con falsi allarmi |
|---|---:|---|---:|---|---:|---:|---:|
| a. proposta dal criterio | 43 (33,3%) | [21,6; 46,2] | 40 | [26; 55] | 16 | 56 | 28 |
| b. proposta + materiale (R4a) | 50 (38,8%) | [26,8; 50,9] | 87 | [65; 112] | 19 | 106 | 47 |
| c. M intera | 56 (43,4%) | [31,8; 55,8] | 184 | [148; 223] | 21 | 205 | 80 |
| d. M + V3 | 60 (46,5%) | [34,4; 59,1] | 228 | [188; 273] | 24 | 252 | 86 |
| e. V3 della S10 | 10 (7,8%) | [2,3; 14,4] | 51 | [28; 78] | 3 | 54 | 11 |

(`46-out.txt`[^opzioni]). **La sensibilità di (a) e (b) è ottimistica**: la scelta delle sotto-regole usa lo stesso riferimento della misura. La sensibilità di M non ha scelta.

Dei 43 difettosi della proposta, 41 sono presi dalla sotto-regola della loro famiglia e 2 stanno nella famiglia «altro». Per famiglia la proposta prende: secondo agente 29 su 41, tempo 10 su 19, materiale 2 su 22, altro 2 su 15, soggetto 0 su 14, sede 0 su 6, entità non isolata 0 su 6. Le 86 righe non viste sono in `40-difetti-non-visti.csv`[^nonvisti].

# 5. Che cosa i fatti dei campioni non vedono

`45-perche-non-visti.py` descrive, per ognuno dei 52 difetti che M non vede nelle famiglie con una sotto-regola, che cosa scrive lo Stadio 1[^diagnosi]:

| famiglia | non visti da M | causa |
|---|---:|---|
| secondo agente | 11 | un solo agente in più: il secondo non è scritto come perturbazione separata (`erlotinib` per «PC9_erlotinib_24h» contro «PC9_DMSO»; «XRT plus Metformin» in una sola stringa; «Wild-type T. gondii + IFN-β» con il solo IFN-β) |
| materiale | 14 | lo stesso `context_kind` sui due bracci: due linee diverse sono entrambe `cell_line_in_vitro` (U251TR e U251MG, HSTS e KRJ1, MR42F e MR42D) e la linea Cellosaurus è vuota; PBMC e sangue intero sono entrambi `primary_tissue` |
| soggetto | 8 | bracci misti: un valore in comune (le etnie di `GSE97358`, il sesso negli studi sull'artrosi) |
| soggetto | 4 | nessun campo del soggetto su entrambi i bracci |
| tempo | 4 | nessun tempo su nessun braccio |
| tempo | 3 | tempo su un braccio solo |
| tempo | 2 | tempi con un valore in comune |
| sede | 4 | una parola della sede in comune |
| sede | 2 | sede su un braccio solo o generica |

Lo Stadio 1 scrive quasi sempre una sola perturbazione per campione: 15.024 campioni su 15.559 ne hanno una, 257 due, 6 tre. Quando un campione riceve due agenti, il secondo sta spesso nella stessa stringa del primo, e la regola lo divide solo sui separatori dichiarati (`+`, ` and `, `, `, ` with `, `&`, `;`).

# 6. Da dove vengono i falsi allarmi (P5 smentita)

Avevo previsto che sede e donatore portassero più della metà dei falsi allarmi di M: ne portano il 26,1%. I falsi allarmi stanno in campi che dovevano essere precisi. Valori che fanno scattare, sui puliti (`40-esiti.csv`, colonne `det_*`[^esiti]):

- **R4a materiale (48 in 34 studi).** 27 sono «coltura primaria» contro «tessuto primario» (21 in un verso, 6 nell'altro). Il modello usa i due valori in modo incoerente fra campioni dello stesso studio: in `GSE97358` campioni dello stesso disegno sono `primary_culture` o `primary_tissue`.
- **R7 genotipo (38 in 26 studi).** Etichette delle modifiche scritte in modo diverso nello stesso studio («ACE receptor» contro «ACE», 6) e modifiche che la rilettura non conta come difetto (CFTR, immortalizzazione, TP53 sul controllo).
- **R5 sede (33 in 27 studi).** Sinonimi: «stomach» contro «gastric», «colon» contro «colorectal», «blood» contro «plasma».
- **R1c agente solo nel controllo (24 in 19 studi).** Condizioni di controllo scritte come agenti: «normoxia» (10), «normal pregnancy» (3).
- **R2a tempo (21 in 13 studi).** Soprattutto controlli a tempo zero (4 h contro 0 h, 24 h contro 0 h): vedi §7.
- **R1 secondo agente (16 in 16 studi).** Alcuni sembrano secondi agenti veri che la rilettura non ha accusato (bortezomib con shPSMD2, 5-fluorouracile con clorochina, CB-839 con radiazione). Altri sono lo stesso agente con due nomi (dasatinib) o un mezzo di coltura. La lettura dei falsi allarmi lo dirà.
- **R3c donatore (15 in 8 studi).** Disegni con donatori diversi nei due bracci che la rilettura non accusa.

La proposta tiene R1, R2a, R2b e R6: i suoi 40 falsi allarmi sono 15 di R1, 8 di R2a, 12 di R2a con R2b, 4 di R6 e 1 di R1 con R2a e R2b, in 28 meta-analisi e 32 studi.

# 7. Un'anomalia del riferimento: i controlli a tempo zero

In `GSE126409` gli 11 confronti hanno lo stesso controllo, «Healthy IEIL cells vehicle control (time zero)». La rilettura ne accusa 5: tutti e 3 i confronti di IL-21, 1 su 4 di IL-15, 1 su 4 di IFN-β. Gli altri 6 sono altri negativi. In `GSE221804` R2a e R2b segnalano 7 altri negativi e 3 puliti con controllo «unstimulated» a 0 h. Lo stesso disegno riceve giudizi diversi. Questo fa contare come falsi allarmi o come incerti dei confronti che hanno lo stesso difetto di confronti accusati. **Rinviato alla lettura dei falsi allarmi (S11)**, che ha il mandato di dire se ha sbagliato la rilettura e di registrare ogni riga che cambia: 13 dei 16 altri negativi della proposta hanno un controllo a tempo zero.

# 8. Previsioni

| # | atteso | misurato | esito |
|---|---|---|---|
| P1 falsi allarmi di M | 150 (intervallo depositato: ≤ 85) | 184, IC95 [148; 223] | **tutta fuori da ≤ 85, come atteso**: M intera non va alla lettura e si applica il criterio. La previsione era scritta male: il valore atteso stava fuori dall'intervallo di rilevanza. Il valore atteso cade nell'IC95 |
| P2 sensibilità di M | 35%, [20%; 50%] | 43,4%, IC95 [31,8; 55,8] | **indeterminata** (a cavallo del 50%). Non tocca una conclusione: M non va alla lettura; la proposta ha IC95 [21,6; 46,2], tutto dentro |
| P3 difettosi presi da M e non da V3 | 30, rilevante sotto 10 | 50 | **confermata**: i fatti dei campioni cambiano la frase dei Methods |
| P4 guadagno su V3 nelle quattro famiglie grandi | almeno uno in più in ognuna | secondo agente 30 contro 3; materiale 8 contro 2; tempo 10 contro 0; soggetto 2 contro 0 | **confermata** |
| P5 quota dei falsi allarmi da sede o donatore | più della metà | 26,1% | **smentita**: spiegata in §6 |

# 9. Dubbi e come si chiudono

| dubbio | chiusura |
|---|---|
| P1 scritta con il valore atteso fuori dall'intervallo | spiegato (§8): la conclusione (M sopra la soglia) è quella attesa |
| P2 indeterminata | spiegato (§8): non tocca la regola che va alla lettura |
| P5 smentita | spiegato (§6) |
| il materiale escluso per 2 falsi allarmi oltre la soglia | **decisione del PI** (§10) |
| controlli a tempo zero giudicati in modo diverso nello stesso studio | **rinviato** alla lettura dei falsi allarmi (S11), scritto nel suo riquadro dell'handout |
| sensibilità della proposta ottimistica | dichiarato (§4); la lettura dei falsi allarmi ricalcola la sensibilità sul riferimento corretto |
| idee per migliorare la regola (separatore «plus», materiale incoerente, linea vuota, condizioni di controllo come agenti, sinonimi della sede) | **rinviato** al passaggio in produzione (S12), scritto nel suo riquadro dell'handout; non applicate qui |

# 10. Decisioni del PI

In attesa.

# Da dove vengono i numeri del riassunto

| nel riassunto | fonte | valore letto |
|---|---|---|
| «129 sono mal appaiati», «1.903 confronti», «1.704 confronti puliti» | `40-out.txt`, cancello C2(c) | 129, 1.704; C3 1903 |
| «La regola sulle etichette ne trova 10» | `40-out.txt`, C2(c), S10 V3 | 10 |
| «soglia di 85» | `00-previsioni.md`, decisioni del PI | 85 |
| «56 ... su 129», «184 falsi allarmi» | `40-out.txt`, «Regola completa M» | 56/129, 184/1704 |
| «43 difetti su 129 con 40 falsi allarmi» | `46-out.txt`, opzione a | 43/129, 40 |
| «29 dei 41 secondi agenti e 10 dei 19 tempi» | `40-esiti.csv`, `PROPOSTA` per famiglia | 29 su 41, 10 su 19 |
| «ne trovava 3 e 0» | `40-out.txt`, P4, colonna V3 | 3, 0 |
| «50 difetti con 87 falsi allarmi», «7 difetti in più», «106» | `46-out.txt`, opzione b | 50, 87, 106 |
| «In 27 dei suoi 48 falsi allarmi» | `40-esiti.csv`, `det_R4a` sui puliti | 21 + 6 su 48 |
| «5 confronti su 11» | `40-esiti.csv`, `GSE126409` | 5 difettosi, 6 altri negativi |
| «56 righe», «40 falsi allarmi e 16 confronti», «13 di loro hanno un controllo a tempo zero» | `46-out.txt` opzione a; `40-esiti.csv`, `PROPOSTA` e `R2a`+`R2b` sugli altri negativi | 16, 56, 13 |
| «54 allarmi ... 10 difetti su 129» | `46-out.txt`, opzione e | 54, 10/129 |
| «4 secondi», «meno di un secondo», «19 secondi» | `time` dell'estrazione; `/usr/bin/time` sulla regola e sulla misura, rieseguite con esiti identici | 3,9 s; 0,65 s; 19,3 s |

[^previsioni]: `analysis/audit/2026-11-07-S10b-metadati-campioni/00-previsioni.md`, commit `3defd61`.
[^regola]: `analysis/audit/2026-11-07-S10b-metadati-campioni/10-regola.py`.
[^estrai]: `analysis/audit/2026-11-07-S10b-metadati-campioni/20-estrai-out.txt`.
[^c1]: `analysis/audit/2026-11-07-S10b-metadati-campioni/10-manifesto-inizio.txt`, `90-manifesto-fine.txt`.
[^misura]: `analysis/audit/2026-11-07-S10b-metadati-campioni/40-out.txt`.
[^esiti]: `analysis/audit/2026-11-07-S10b-metadati-campioni/40-esiti.csv`.
[^opzioni]: `analysis/audit/2026-11-07-S10b-metadati-campioni/46-out.txt`.
[^nonvisti]: `analysis/audit/2026-11-07-S10b-metadati-campioni/40-difetti-non-visti.csv`.
[^diagnosi]: `analysis/audit/2026-11-07-S10b-metadati-campioni/45-out.txt`, `45-perche-non-visti.csv`.
[^s10]: `docs/findings/2026-11-07-S10-rilevatore.md`, §2.
