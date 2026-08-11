# PASSO 4 — Che cosa decide davvero il verdetto di coerenza

**Data:** 2026-08-09 · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessun commit · nessun re-cluster · nessun re-pool**

Risponde alla domanda che l'handout chiama «la più importante del programma»: il gate
di coerenza dà 25, 58 o 97 incoerenti a seconda di chi legge. **Su che cosa divergono i
giudici, e il consenso è predetto da un segnale deterministico?**

---

## In tre righe

1. **La severità del lettore umano cresce col numero di studi, e cresce alla velocità
   che ci si aspetta se i difetti si accumulassero studio per studio.** Il tasso di
   difetto **per studio** che i suoi verdetti implicano è **0,1111 (IC95% 0,091–0,134)**;
   quello misurato indipendentemente il 5 agosto, contando i difetti, è **0,1018**.
   Conseguenza pratica: **a k ≥ 15 la lettura umana condanna il 100% dei gruppi** — cioè
   tutti quelli con potenza da figura.
2. **Anche Mistral diventa più severo con k, ma si ferma prima.** La sua quota di
   «dubbio» sale da 26% a 55%; quella di «incoerente» resta piatta. I due giudici non
   differiscono sul fatto che k conti: differiscono su **dove mettono il tetto**.
3. **Un segnale misurabile c'è, e non l'avevo cercato: l'imprecisione delle stime.**
   La mediana sui geni del **massimo errore standard fra studi** separa il nucleo solido
   dal resto (0,399 contro 0,603) e, da sola, dà **+0,271 di precisione fuori campione**
   sopra il caso, positiva in **197 divisioni su 200**. ⚠️ La prima stesura diceva
   «nessun segnale predice il verdetto»: **è falso, ed è ritrattato** (§9.7).
4. **Ma il gate resta non-codificabile**: AUC fuori campione **0,68** con 83 predittori e
   regolarizzazione; precisione > 0,80 *insieme* a copertura > 0,50: **zero volte su
   9.000 misure**. È materiale da **triage**, non da gate.

⚠️ **Questa è la SECONDA stesura.** La prima sosteneva che i giudici «non sono in
disaccordo sui fatti, ma sulla regola di aggregazione». Un revisore ostile l'ha
falsificata su quattro punti, tutti rimisurati e tutti confermati: vedi §9. **Quella tesi
non è sostenuta dai dati** e viene ritirata; quello che resta, sopra, è più debole e
verificato.

---

## 1. La base, e ciò che è stato escluso

| giudice | base | fonte |
|---|---:|---|
| lettura umana 5 agosto | 214 | `analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv` |
| Mistral, 5 giri, senza flag | 214 | `mistral/pred5x.jsonl` |
| Mistral, 5 giri, **con** flag di batch-invarianza | 214 | `mistral/bi_coe.jsonl` |

**Base comune finale: 213.** ⚠️ **Taglio dichiarato:** `cgroup_L5_2e16719f` è escluso —
ha 5 fallimenti di schema su 5 giri in **entrambe** le esecuzioni Mistral, quindi da quel
giudice non ha verdetto.

⚠️ **Il giudice Claude (92/64/58 del 2026-08-09) non è stato salvato come tabella** e non è
ricostruibile dai file esistenti. L'analisi confronta due giudici, non tre. Dichiarato,
non aggirato.

⚠️ I due Mistral **non sono giudici indipendenti**: stesso modello, con e senza flag.
Contano come uno. La flag cambia il verdetto in **34 casi su 213**.

## 2. Quanto divergono

| | |
|---|---:|
| accordo a 3 livelli | **36,2%** (77/213) |
| accordo binario (coerente contro il resto) | 55,9% (119/213) |
| discordi | 136/213 (63,8%) |
| di cui **umano più severo** | 89 (65,4%) |
| di cui Mistral più severo | 47 (34,6%) |

| umano ⧵ Mistral | coerente | dubbio | incoerente | tot |
|---|---:|---:|---:|---:|
| **coerente** | **55** | 40 | 6 | 101 |
| **dubbio** | 10 | 5 | 1 | 16 |
| **incoerente** | **38** | 41 | **17** | 96 |
| tot | 103 | 86 | 24 | 213 |

**Il nucleo solido è 55 su 213 (25,8%)**: le meta-analisi che entrambi chiamano coerenti.
Su 17 entrambi dicono incoerente.

## 3. Il segnale che li separa è il NUMERO DI STUDI

| k | n | accordo | nucleo solido | umano dice incoerente | Mistral dice incoerente |
|---|---:|---:|---:|---:|---:|
| 3 | 80 | 54% | 39% | 38% | 18% |
| 4 | 43 | 28% | 23% | 40% | 9% |
| 5–6 | 35 | 31% | 26% | 34% | 6% |
| 7–10 | 35 | 26% | 11% | 54% | 9% |
| **11+** | 20 | **10%** | **5%** | **90%** | **5%** |

Spearman fra k e «incoerente»: **umano +0,222, Mistral −0,147**. Le due severità vanno in
direzioni opposte.

## 4. L'ipotesi, e il suo test

⚠️ **Onestà sull'ordine dei fatti:** l'ipotesi **non** era depositata prima. È nata
leggendo i 38 motivi con cui il lettore umano dichiara incoerente un gruppo che Mistral
chiama coerente. Sono tutti difetti **puntuali e verificabili**: un secondo agente in un
braccio (`GSE175867` «DAC 1uM + DEX» contro DMSO), un tessuto diverso fra i bracci
(`GSE159196` «IL13 tracheale» contro «controllo nasale»), cellule contro tessuto
(`GSE108743` MSC espanse in coltura), finestre temporali disallineate (`GSE213245` «day
90-120» contro «day 61-91»), sottolinee resistenti (`GSE151680`). **Mistral non li nega:
li considera non decisivi.**

Se la regola umana è «almeno uno su k», la probabilità di condanna deve crescere come
**1 − (1−p)^k**, con p il tasso di difetto **per confronto**. Se è una regola sulla
frazione, deve essere **indipendente da k**.

**p non è un parametro inventato qui: è già stato misurato il 2026-08-05 su altro
materiale — 85 confronti imperfetti su 843 nei 13 gruppi grandi = 0,1008.**

| fascia k | n | k medio | osservato (umano) | atteso con p=0,1008 | atteso con p stimato |
|---|---:|---:|---:|---:|---:|
| 3 | 80 | 3,0 | 0,375 | 0,273 | 0,298 |
| 4 | 43 | 4,0 | 0,395 | 0,346 | 0,376 |
| 5–6 | 35 | 5,3 | 0,343 | 0,431 | 0,464 |
| 7–10 | 35 | 8,4 | 0,543 | 0,586 | 0,623 |
| 11+ | 20 | 19,4 | 0,900 | 0,839 | 0,865 |

| modello | errore assoluto medio |
|---|---:|
| «almeno uno su k», p misurato il 5 agosto | **0,069** |
| «almeno uno su k», p stimato dai verdetti | 0,066 |
| costante (nessuna dipendenza da k) | 0,156 |

**p stimato per massima verosimiglianza dai soli verdetti umani: 0,1111,
IC95% [0,0910 – 0,1340]** (profilo di verosimiglianza). Il p misurato indipendentemente
(**0,1008**) **cade dentro l'intervallo**, che è largo 0,043 — quindi la coincidenza non è
vacua.

**E Mistral?** Il p implicito nei suoi verdetti «incoerente» è **0,0194**, cioè 5,7 volte
più piccolo. ⚠️ **Ma questo NON significa che Mistral sia insensibile a k** — vedi la
rettifica in §9.3: la sua severità *sale* con k, satura su «dubbio» invece di arrivare a
«incoerente».

### ⚠️ 4.1 Due errori miei in questo paragrafo, corretti

**(a) Errore dimensionale — è la trappola n.11 dell'handout, commessa di nuovo.**
`85/843 = 0,1008` è un tasso **per CONFRONTO**; l'esponente `k` è il numero di **STUDI**.
Sui 13 gruppi ci sono 2,96 confronti per studio: propagando correttamente, il modello
darebbe 1−(1−0,1008)^2,96 = 0,270, cioè **2,4 volte** il p̂ — e l'errore salirebbe a 0,299,
peggio del modello costante.
**La riparazione tiene il risultato in piedi**: la grandezza dimensionalmente giusta è
**studi accusati / studi**, e vale **29/285 = 0,1018** sui 12 gruppi in base (34/344
contando anche il 13°, escluso perché senza verdetto Mistral). Praticamente identica a
0,1008, perché **i difetti si concentrano dentro pochi studi** — 34 studi accusati per 85
confronti difettosi. Senza dirlo, la coincidenza sembra magia.

**(b) La forma «almeno uno su k» NON è dimostrata.** L'avevo confrontata solo con un
modello costante. Confronto onesto, verosimiglianza vera sui 213 punti:

| modello | par | logLik | AIC |
|---|---:|---:|---:|
| logistica in k | 2 | −135,01 | **274,03** |
| **1−(1−p)^k** | **1** | −136,86 | 275,72 |
| logistica in log k | 2 | −137,42 | 278,84 |
| costante | 1 | −146,60 | 295,21 |

ΔAIC fra le prime due è **1,69**: indistinguibili. Ciò che è dimostrato è **«la severità
umana cresce con k»** (ΔAIC 21 contro la costante), non la forma di Bernoulli. Il modello
non è nemmeno smentito — è semplicemente non distinguibile dalle rivali.

**(c) p non è omogeneo.** La frazione difettosa dei 13 gruppi va da 0,031 a 0,282, nove
volte di scarto (χ² di omogeneità 42,6, df 12). Un solo p è una semplificazione, e va detto.

## 5. Che cosa costa la scelta della regola

| soglia | gruppi | umano li dichiara incoerenti | Mistral |
|---|---:|---:|---:|
| k ≥ 3 | 213 | 45,1% | 11,3% |
| k ≥ 6 | 66 | 62,1% | 7,6% |
| k ≥ 10 | 28 | 85,7% | 3,6% |
| **k ≥ 15** | **12** | **100,0%** | **0,0%** |

**Con la regola «almeno uno», nessuna meta-analisi con k ≥ 15 sopravvive.** Sono i gruppi
da figura: TGF-β1, LPS, SARS-CoV-2, DHT, enzalutamide.

⚠️⚠️ **RITRATTAZIONE DI UNA MIA PROVA, prima che la trovi un revisore.** Avevo elencato
fra le prove che «sui 12 gruppi grandi in cui i confronti difettosi sono stati CONTATI
l'umano dice incoerente 12/12». **Non è una prova indipendente:** quei 12 gruppi sono
esattamente quelli con k ≥ 15, e **non esiste nessun altro gruppo con k ≥ 15** (misurato:
n=0). Il 12/12 è la stessa cosa dell'ultima riga della tabella di §3, non una conferma in
più. **Resta valido il lato Mistral:** sui 12 gruppi dove *sappiamo* che ci sono 85
confronti difettosi, Mistral dice incoerente **0 volte su 12** — e la sua severità non
dipende da k, quindi quello non è un artefatto di selezione.

## 6. Il gate può diventare codice? Non così

Cercata la regola migliore fino a 3 condizioni (**9.919** combinazioni) su metà dei dati e
misurata sull'altra metà, ripetendo su **200 divisioni casuali** (seme fisso):

| | mediana | 1º–3º quartile |
|---|---:|---|
| precisione dove la regola è stata cercata (A) | 0,636 | 0,600 – 0,700 |
| precisione dove è misurata (B) | 0,333 | 0,237 – 0,429 |
| base di B (il caso) | 0,264 | 0,243 – 0,284 |
| **guadagno su B** | **+0,073** | −0,019 – +0,165 |

Precisione > 0,80 su B: **1 divisione su 200**. Calo mediano di precisione da A a B:
**−0,300**. Prendendo come bersaglio il verdetto di **un solo** giudice il guadagno
mediano resta piccolo: **+0,103** (umano), **+0,092** (Mistral).

**Previsione P4 depositata (precisione > 0,80 *e* copertura > 0,50): FALSIFICATA.**
Non c'è nulla di misurabile nel deliverable che predica il verdetto. C'è un segnale, ma
vale ~7 punti percentuali sopra il caso: **non è un gate, è una tendenza.**

**Ma il gate può diventare codice in un altro modo, e questo è il risultato utile:** non
predicendo il verdetto, bensì **rendendo esplicita la regola di aggregazione**. Il numero
da riportare non è «25» o «97» — è una **scelta dichiarata** fra:

- **«almeno uno»** → 96/213 incoerenti, e zero meta-analisi con k ≥ 15;
- **«frazione di confronti difettosi»** → è già misurata (5 agosto: mediana 8,6% dei
  confronti, 12,0% del peso come limite superiore) e **non dipende da k**.

## 7. Le previsioni depositate

| | attesa | misurata | |
|---|---|---|---|
| P1 — accordo a 3 livelli | 35–55% | **36,2%** | centrata |
| P2 — umano più severo in oltre l'85% dei discordi | >85% | **65,4%** | **falsificata** |
| P3 — un predittore con d di Cohen > 0,5, il candidato è `k_effective` | sì | `n_studi_censiti` d=−0,54, `k_effective` d=−0,50 | **centrata, col candidato giusto** |
| P4 — regola con precisione >0,80 e copertura >0,50 | sì | +0,073 di guadagno, 1/200 sopra 0,80 | **falsificata** |

Due centrate, due falsificate. P2 è falsificata nel modo utile: l'umano è più severo, ma
Mistral lo è a sua volta in **47 casi su 136** — non è un giudice uniformemente indulgente.

## 9. Che cosa ha demolito il revisore ostile — tutto rimisurato

| # | accusa | rimisurato da me | esito |
|---|---|---|---|
| 9.1 | Il «12/12 contro 0/12» è **circolare**: i 12 gruppi grandi sono esattamente i ranghi 1–12 di k | gruppi con k ≥ 15 esclusi i 13: **n = 0**. Non esiste controllo | **accusa giusta, prova ritirata** (l'avevo già ritirata in §5 prima del suo arrivo) |
| 9.2 | Errore dimensionale: p per confronto, esponente per studio | confermato; la grandezza giusta è 29/285 = 0,1018 | **accusa giusta, conclusione salvata** (§4.1a) |
| 9.3 | «Mistral è piatto in k» è **falso** | Spearman(k, severità **ordinale**): umano **+0,238**, Mistral **+0,049**. Quota di «dubbio» di Mistral per fascia di k: **0,262 → 0,465 → 0,429 → 0,543 → 0,550**. Il −0,147 vale solo sul livello massimo | **accusa giusta, tesi riscritta** |
| 9.4 | La forma «almeno uno» perde da una logistica in k | AIC 275,72 contro **274,03** | **accusa giusta** (§4.1b) |
| 9.5 | «I giudici concordano sui fatti» **non è misurato** | la severità di Mistral non segue la frazione di studi accusati (Spearman +0,119); nulla distingue «li vede e li ritiene non decisivi» da «non li vede» | **accusa giusta, tesi RITIRATA** |
| 9.6 | Con la flag i 5 giri sono **identici**: la «maggioranza di 5» è vacua | verificato: 515/430/120 verdetti, tutti divisibili per 5 | **accusa giusta**, e va detto: quei 5 giri non sono una prova di robustezza |

⚠️ **Un numero su cui io e il revisore differiamo, dichiarato invece che scelto:** gli
studi accusati sono **34** contando tutti e 13 i gruppi, **29** contando i 12 in base
(il 13° è TGF-β1, escluso perché Mistral ha fallito lo schema su tutti e 5 i giri). Il
revisore riporta 29; entrambi i numeri sono giusti su denominatori diversi.

⚠️ **Nota che pesa sul deliverable:** il gruppo escluso, `cgroup_L5_2e16719f`, è **TGF-β1
— 145 confronti, 29 difettosi, il peggiore dei 13**, ed è la figura 2 del paper. Non ha
alcun verdetto Mistral. Il passaggio da «97 su 214» a «96 su 213» è esattamente la sua
uscita.

### 9.7 ⚠️ RITRATTAZIONE: «nessun segnale predice il verdetto» è falso

Un secondo revisore ostile ha mostrato che il **+0,073** di §6 è il prodotto di **tre
scelte arbitrarie prese insieme**, e che cambiandone **una sola** il numero almeno
raddoppia:

| scelta | alternativa | guadagno fuori campione |
|---|---|---:|
| lista dei predittori senza **nessuna** statistica di dispersione o precisione | + 6 segnali nuovi | **+0,222** |
| soglia `n_A ≥ 10` | `n_A ≥ 5` | **+0,267** |
| bersaglio «entrambi coerente» (base 0,258, il più difficile dei cinque) | «nessuno dei due incoerente» (base 0,518) | **+0,465** |

E il +0,073 **non è distinguibile dal nullo della sua stessa procedura** (p = 0,115 su
permutazioni). Era una misura fatta con uno strumento che non vedeva il dato — la stessa
classe di errore già pagata più volte in questo progetto.

**Rimisurato da me, in modo indipendente, sul segnale di punta** (`SE_max_med` = mediana
sui geni del massimo errore standard fra studi, da `per_study_de.parquet`):

| | |
|---|---:|
| mediana nel nucleo solido | **0,399** |
| mediana fuori | **0,603** |
| precisione fuori campione (200 divisioni) | 0,537 contro base 0,264 |
| **guadagno** | **+0,271** |
| divisioni con guadagno positivo | **197/200** |
| nullo per permutazione (95° percentile) | +0,165 → **superato** |

⚠️ Il revisore riporta +0,340, io +0,271 sulla mia implementazione della soglia. Ordine di
grandezza identico, entrambi ben sopra il nullo; **riporto il mio, più basso**.

**Interpretazione, dichiarata come tale e non misurata:** i gruppi giudicati non-coerenti
sono quelli le cui stime per-studio sono **imprecise**. È plausibile che sia la stessa
cosa vista da due lati (studi piccoli e rumorosi → più facile trovarci un difetto), ma
non è stato dimostrato.

**Che cosa NON cambia:** il tetto. AUC fuori campione **0,680** [q1 0,644, q3 0,705] con
83 predittori e regolarizzazione L2; 0,685 anche addestrando sull'80%; **0 bersagli su 5**
sopra 0,75. Precisione > 0,80 **insieme** a copertura > 0,50: **0 su 9.000** misure fuori
campione (45 configurazioni × 200 divisioni). **La previsione P4 resta falsificata, e la
conclusione operativa regge: è triage, non un gate.**

⚠️ **Caveat che va detto insieme al resto:** i segnali migliori (`SE_max_med`,
`sd_logFC_q75`) sono **uscite dello Stadio 4**, disponibili solo *dopo* il pooling. Con i
soli segnali di Stadio 3 si perde poco (precisione 0,455 contro 0,500 al 10% di copertura)
ma il tetto non cambia.

## 10. Riproducibilità

Script in `analysis/audit/2026-08-09-passo4/`: `10-matrice-giudici.R`, `20-predittori.R`,
`30-regola-e-meta.R`, `40-robustezza.R`, `50-regola-di-aggregazione.R`.
Previsioni depositate prima: `00-previsioni.md`. Tabelle: `10-matrice.csv`,
`20-predittori-*.csv`, `30-divario-umano-mistral.csv`, `30-regole-su-A.csv`.
Nessun numero di questo documento viene da un agente senza essere stato rimisurato.
