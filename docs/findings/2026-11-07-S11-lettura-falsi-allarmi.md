---
type: Finding
title: "Gli allarmi del rilevatore sono quasi due volte su tre errori veri, e la lista degli errori sale da 129 a 193"
description: "La lettura uno per uno dei 56 allarmi del rilevatore sui fatti dei campioni, con i dati GEO, e la regola del PI sui controlli a tempo zero applicata a tutti i 1.903 confronti del deliverable. Con la decisione del PI sulle differenze tecniche, 37 allarmi sono errori veri, 18 errori del rilevatore, 1 incerto; la lista degli errori passa da 129 a 193 confronti e 15 meta-analisi cambiano verdetto."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-07T23:30:00+01:00'}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/00-previsioni.md", title: "Decisioni del PI, regole della lettura, cancelli e previsioni (commit c50228a)"}
- {id: schede, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/23-schede.txt", title: "Le 89 schede di lettura"}
- {id: note, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/30-note-lettura.tsv", title: "L'esito di ogni scheda, con la citazione"}
- {id: lettura, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/30-lettura.csv", title: "Le 116 righe lette, con insieme, regole e cause"}
- {id: misura, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/40-out.txt", title: "Cancelli, riferimento corretto, sensibilita', verdetti"}
- {id: registro, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/40-registro-cambi.csv", title: "Ogni confronto che cambia stato"}
- {id: rif, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", title: "Il riferimento corretto, 188 confronti"}
- {id: difetti, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/42-difetti-dopo-S11.csv", title: "La lista degli errori nel formato di agosto, con la fonte"}
- {id: verdetti, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/45-verdetti-che-cambiano.csv", title: "Le 29 meta-analisi con errori nuovi"}
- {id: nonvisti, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/46-out.txt", title: "Gli errori noti che il rilevatore non vede"}
- {id: tecnici, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/27-out.txt", title: "Il censimento delle differenze tecniche fra i bracci"}
- {id: lettecn, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/28-lettura-tecnica.csv", title: "La lettura degli 8 candidati tecnici"}
- {id: s10b, resource: "docs/findings/2026-11-07-S10b-rilevatore-metadati.md", title: "Il rilevatore sui fatti dei campioni e l'elenco dei 56"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi, non toccato"}
---

# In breve

## In breve: gli allarmi del rilevatore sono errori veri, o errori del rilevatore?

*Questo è il riassunto che il PI ha letto, con i numeri prima della sua decisione sulle differenze tecniche. I numeri finali sono in §12.*

**A cosa serviva.** Il rilevatore deve togliere dalle meta-analisi i confronti in cui trattati e controlli differiscono per più del solo trattamento. Nella sessione precedente ha segnalato 56 confronti che la rilettura di agosto giudicava buoni o non giudicava. Oggi li ho letti uno per uno, con il nome dei gruppi e con i dati GEO di ogni campione. Ho anche applicato la tua regola sui controlli raccolti a tempo zero a tutti i 1.903 confronti del deliverable.

**Cosa abbiamo trovato.**

1. **Dei 56 allarmi, 36 sono errori veri che la rilettura di agosto non aveva visto, 19 sono errori del rilevatore e 1 resta incerto.** 30 dei 36 errori si leggono solo nei dati GEO dei campioni, non nel nome dei gruppi. Per esempio il gruppo «HBV D10» contiene campioni non infettati, e il gruppo «radiation» riceve anche un farmaco.
2. **I controlli raccolti a tempo zero sono 50 confronti, in 17 studi e 18 meta-analisi.** Ad agosto ne erano accusati 6. Il rilevatore ne vede 31. In 12 confronti il tempo zero sta solo nel titolo GEO del campione, e il modello non lo scrive.
3. **La lista degli errori passa da 129 a 188 confronti, e 14 meta-analisi cambiano verdetto.** 12 passano da corretta a difettosa e 2 da incerta a difettosa. Sei sono fra le 40 dell'insieme principale dell'articolo: calcio, TNF, decitabina, EGF, IL2 e IL13. Senza tutti gli errori, 19 meta-analisi scendono sotto 3 studi, contro 12 con la lista di agosto.
4. **I 19 errori del rilevatore hanno sette cause, e ognuna si può correggere.** La più frequente è una modifica genetica o una condizione comune ai due bracci, che il modello scrive solo sul trattato (6 casi). Altre cause sono un tempo uguale scritto in due modi e un agente comune marcato come controllo solo nel controllo.
5. **Il rilevatore vede 80 dei 188 errori noti, e gli altri 108 restano nel deliverable.** Non vede soprattutto tempo (28), materiale (20), donatore (14) e secondo agente (12). Per molti di questi l'informazione sta nei dati GEO e non nei fatti scritti dal modello.

**Cosa devi decidere.**

1. **Una differenza solo tecnica fra trattati e controlli è un errore? Consiglio di sì.** In uno studio sull'irradiazione i trattati sono sequenziati paired-end e i controlli single-end. In uno studio sul Pladienolide B un campione trattato è RNA marcato con 4sU e i controlli sono RNA totale. Le cellule e il trattamento sono quelli giusti.
   - Se rispondi sì, i due confronti entrano nella lista degli errori, come il tempo zero. Il rilevatore dovrà guardare anche il metodo di preparazione e di sequenziamento. Lo consiglio perché segue la stessa regola del tempo zero: i bracci devono differire solo per il trattamento.
   - Se rispondi no, i due confronti restano buoni. La differenza tecnica diventa un limite scritto nei Methods.

**Comunque:**

- il deliverable, i master, il codice e i file di agosto non sono cambiati, e la lista corretta sta in file nuovi;
- la sessione che mette il rilevatore nella pipeline deve correggere le sette cause e vedere i 108 errori, spesso con i dati GEO;
- la scelta delle 40 meta-analisi decade già adesso, e la rifaremo una volta sola dopo il nuovo run completo, come avevi deciso;
- la rilettura dopo il nuovo run leggerà anche i dati GEO, perché il nome dei gruppi non basta;
- la tua proposta di confrontarci con meta-analisi pubblicate è scritta nell'handout come sessione nuova.

Appena decidi questo punto, la sessione è chiusa.

# 1. Che cosa è stato fatto

**Oggetto.** I 1.903 confronti poolati del deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d` (`analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds`, `tenuti`, tabella `analysis/audit/2026-11-07-S10b-metadati-campioni/20-confronti.csv`). L'elenco da leggere è quello scelto dal PI nella S10b: 56 righe, 40 puliti e 16 altri negativi segnalati dalla combinazione R1 + R2a + R2b + R6 + parte di V3[^s10b]. Riferimento di partenza: i 129 confronti difettosi della S10 (`30-riferimento.csv`).

**Decisioni del PI prese in apertura, prima del deposito**[^previsioni]:

1. un controllo raccolto a tempo zero, con il tempo zero leggibile nell'etichetta o nei metadati GEO e il trattato più lungo, è un errore, per tutti i confronti (risposta «1»);
2. un errore leggibile solo nei metadati GEO entra nel riferimento, con la fonte marcata;
3. nessuna soglia di errore: «La pipeline non deve sbagliare. Sono dati fissi». Ogni falso allarme è un errore della regola da correggere, ogni errore non visto va spiegato. La tabella delle soglie dell'handout non si calcola.

**Il materiale.** Per ogni confronto una scheda (`23-schede.py`, `23-schede.txt`[^schede]) con etichette dello Stadio 2, valori dello Stadio 1 che fanno scattare la regola, titolo, sorgente e caratteristiche GEO di ogni campione (H5 ARCHS4 v2.5, `21-metadati-geo.R`; 35.807 campioni su 35.808), e gli altri gruppi dello studio (master Stadio 2 A3, SHA-256 uguale a `run_metadata.json`, `20-studi-out.txt`).

**Le schede lette.** 89: le 56 righe (sezione A), 28 candidati a tempo zero fuori dall'elenco (B), 5 controlli (C). Più 27 candidati del censimento allargato (E, §4) e 3 del censimento tecnico (T, §12). Totale 119 confronti in `30-lettura.csv`[^lettura]. Ogni esito ha la citazione del testo in `30-note-lettura.tsv`[^note] e `25-lettura-allargata.py`.

**Il lettore** è uno solo, l'agente, e sa che ogni riga della sezione A è un allarme. La lettura non è alla cieca. Dichiarato nel deposito.

# 2. Cancelli e controlli

| cancello | esito |
|---|---|
| C1 manifesto a inizio e a fine sessione | `VERIFICA OK` due volte (`10-manifesto-inizio.txt`, `90-manifesto-fine.txt`) |
| C2(a) le 56 righe da `PROPOSTA` | 43 / 40 / 16, le 56 coincidono con l'elenco |
| C2(b) la combinazione col riferimento S10 | 43 su 129 |
| C2(c) studi distinti fra i confronti tenuti = `k_effective` | 194 su 194[^misura] |
| C3 copertura | 56 su 56 con esito e citazione; 54 candidati a tempo zero su 54; 27 allargati su 27; 8 candidati tecnici su 8 |
| C4 controlli | 5 controlli su 5 come attesi; censimento: `GSE126409` 11 su 11, `GSE221804` 10 su 10 |
| C5 file intatti | `git diff --stat R/` vuoto; SHA-256 di `difetti.csv`, `30-riferimento.csv`, `40-esiti.csv`, `40-falsi-allarmi.csv` uguali (`90-sha-riferimenti-fine.txt`) |

**Il controllo C su `GSE210984`** passa (`sbagliato`), ma i metadati GEO dicono «midollo osseo» per tutti e due i bracci, non «iPSC-derived». La differenza vera è «micromass chondrogenic differentiation for 21 days» contro MSC non differenziate (§9).

# 3. La lettura delle 56 righe

| insieme S10 | errore vero | errore della regola | incerto |
|---|---:|---:|---:|
| pulito (40) | 23 | 16 | 1 |
| altro negativo (16) | 14 | 2 | 0 |
| totale (56) | 37 | 18 | 1 |

I numeri includono la decisione del PI sulle differenze tecniche (§12): la riga 4 (`GSE105951`, paired-end contro single-end) passa da errore della regola a errore vero. Dei 37 errori veri, 31 si leggono solo nei metadati GEO e 6 anche nell'etichetta. Esempi:

- `GSE93153`, etichetta «HBV D10 Donor2»: i campioni del trattato sono «infection: Mock, time: D8». Il confronto è Mock contro Mock.
- `GSE222658`, «SAS wild-type + radiation»: GEO «treatment: Radiation+CB-839».
- `GSE247389`, «5-Aza-treated»: GEO «CPT + GTA + 5-Aza».
- `GSE209582`, «TE11 + Chloroquine»: GEO «Chloroquine + 5 Fluorouracil».
- `GSE229331`, «Dasatinib 30 min»: GEO «Dasatinib for 30 minutes, followed by treatment with Das-AI for 30 minutes».
- `GSE203395`, «Control, non-BCG»: 11 dei 53 controlli sono «CMV-infected» in una meta-analisi sul CMV.
- `GSE221804`: il controllo «Wild-type, unstimulated» contiene 4 campioni knockout su 6, e due trattati «Wild-type» sono doppi knockout IRF9/IRF1.

Quattro allarmi sono errori veri, ma scattano per un motivo diverso dall'errore: `GSE105951` (passaggio; l'errore è la differenza tecnica), `GSE191279` (passaggio; l'errore è un controllo con 6 campioni a 13 giorni su 24), `GSE203395` (tempo «D-7» letto in due modi; l'errore è il CMV nel controllo), `GSE93153` (tempo; l'errore è il Mock nel trattato).

Fuori dall'elenco (sezioni B, E e T) la lettura ha trovato altri 23 confronti difettosi e 3 incerti: quasi tutti per il tempo zero (§4), 4 per una differenza tecnica (§12), più `GSE57116` (DRB e 4sU solo nel trattato, tre tempi mescolati).

# 4. Il tempo zero (decisione 1 del PI)

**Il censimento** (`22-tempo-zero.py`) unisce Stadio 1, etichetta e metadati GEO: 54 candidati in 22 studi. Leggendo le schede ho visto che le forme dell'elenco depositato non trovano il tempo zero attaccato ad altre lettere («TGF0h», «_0HR_», «Day0», «D0»). **Aggiunta dopo il deposito, dichiarata qui:** `24-tempo-zero-allargato.py` cerca queste forme su tutti i controlli dei 1.903 confronti, fuori dai candidati già letti. Ha trovato 27 candidati in 12 studi. 13 sono errori, 13 sono buoni (per esempio «UNTREATED_0_24» è dose 0 a 24 ore, «D300» e «D0» sono dosi), 1 è incerto.

**Risultato** (`40-out.txt`): 50 confronti difettosi per il tempo zero, in 17 studi e 18 meta-analisi. 6 erano già nel riferimento di agosto. La combinazione ne segnala 31. In 12 il tempo zero si legge solo nei metadati GEO e lo Stadio 1 non lo scrive (`GSE221563`, `GSE139393`, `GSE135458`, `GSE184891`, `GSE198670`, `GSE65335`).

**Che cosa il censimento non vede.** Un controllo raccolto all'inizio dell'esperimento senza un tempo scritto («untreated», «control») non si distingue da un controllo raccolto alla fine. Dei 17 candidati trovati dal solo Stadio 1, 13 non hanno un tempo zero leggibile nei metadati: 6 buoni, 2 incerti per un altro motivo, 5 errori per un altro motivo. Lo Stadio 1 marca il tempo zero anche su controlli senza tempo («untreated», «time point: no»). La decisione 1 chiede un tempo zero leggibile, quindi su questi non si applica. In vivo, «Baseline» indica la visita prima del farmaco (`GSE102677`): il trattato non ha un tempo, e la decisione 1 non si applica.

# 5. Il riferimento corretto e la sensibilità

`40-registro-cambi.csv`[^registro] registra ogni confronto che cambia stato. Il riferimento corretto è in `41-riferimento-dopo-S11.csv`[^rif] (formato della S10, più `fonte` e `sessione`) e in `42-difetti-dopo-S11.csv`[^difetti] (formato di agosto). I file di agosto e della S10 non cambiano.

| | confronti |
|---|---:|
| difettosi nel riferimento S10 | 129 |
| nuovi, provati | 60 |
| nuovi, non provati (incerti) | 4 |
| difettosi nel riferimento corretto | 193 |
| di cui nuovi dai metadati GEO / dall'etichetta | 58 / 6 |
| altri negativi letti buoni, diventano puliti | 5 |
| categoria cambiata (`GSE163241`, da passaggio a tempo zero) | 1 |

Nuovi per famiglia (una riga può averne più di una): tempo zero 45, genotipo 10, differenza tecnica 7, secondo agente 6, tempo non appaiato 5, braccio misto 3, donatore o genotipo 4, entità nel controllo 1, entità assente dal trattato 1, formato di coltura 1.

**Sensibilità della combinazione** (bootstrap degli studi, B = 2000, seme 20261107):

| riferimento | presi | IC95 |
|---|---|---|
| S10 | 43 / 129 = 33,3% | [21,7; 45,5] |
| corretto | 81 / 193 = 42,0% | [29,8; 53,8] |
| corretto, solo provati | 80 / 189 = 42,3% | [29,7; 54,3] |

**La sensibilità corretta è ottimistica.** I metadati GEO sono letti solo sugli allarmi e sui candidati a tempo zero. Gli errori nei metadati degli altri 1.787 confronti non sono cercati.

**Falsi allarmi della combinazione:** 40 prima della lettura, 18 dopo.

# 6. Gli errori del rilevatore, per la sessione che lo porta in produzione

| parte | allarmi | errori veri | errori del rilevatore |
|---|---:|---:|---:|
| R1 secondo agente | 48 | 35 | 13 |
| R2a tempo diverso | 46 | 43 | 3 |
| R2b controllo a tempo zero | 31 | 31 | 0 |
| R6 passaggio | 5 | 3 | 2 |
| parte di V3 (greche, materiale nelle etichette) | 5 | 5 | 0 |

Le cause dei 18 errori del rilevatore (`30-lettura.csv`, colonna `classe_causa`):

| casi | causa | esempi |
|---:|---|---|
| 6 | una modifica genetica o una condizione comune ai due bracci è scritta dallo Stadio 1 solo sul trattato | shPSMD2 (`GSE123638`), p53mut (`GSE126775`), SMAD2/3 KO (`GSE178714`), ACP-coating, Monoculture, shYAP1 |
| 3 | un agente comune ai due bracci è marcato «controllo negativo» nel controllo, e la regola non lo conta | «Never smoked», «Medium», gRNA di controllo |
| 3 | lo stesso tempo è scritto in due modi | «21 days» come 504 e 1008 ore (`GSE168462`); 2 x 24 h come 48 h e 24 h |
| 2 | il campo del passaggio contiene altro | «senescent» contro «proliferating»; codice della trasfezione |
| 2 | il nome dell'entità non si riconosce nell'agente | «TB» contro l'entità «tb positive» |
| 1 | la mutazione del paziente è scritta come knockout e conta come agente | PARK2 nel Parkinson |
| 1 | una perturbazione vuota conta come agente | «unclear» nella SLA |

Per la decisione 3 del PI ognuna di queste cause va corretta prima della produzione. Rinvio scritto nel riquadro della S12.

# 7. Gli errori che il rilevatore non vede

`46-non-visti.py`[^nonvisti]: dei 193 errori la combinazione ne vede 81. I 112 non visti sono 86 della rilettura di agosto e 26 di questa lettura. Per famiglia: tempo 28, materiale 20, donatore e soggetto 14, altro 13, secondo agente 12, sede 6, entità non isolata 6, differenza tecnica 5, altre 8. Dei 26 nuovi non visti, 13 hanno il tempo zero solo nei metadati GEO e lo Stadio 1 non lo scrive. 6 hanno il tempo zero scritto dallo Stadio 1, ma la regola non scatta (`GSE163241`, `GSE186396`, `GSE207409`, `GSE223893`): il motivo va cercato nella S12. 4 sono differenze tecniche, 2 sono incerti per il genotipo dei donatori, 1 è il DRB con 4sU. Per la decisione 3 del PI questi errori non si accettano: rinvio scritto nel riquadro della S12.

# 8. Le meta-analisi che cambiano verdetto

32 meta-analisi hanno almeno un errore nuovo (`45-verdetti-che-cambiano.csv`[^verdetti]). Il verdetto cambia in 15:

| da corretta a difettosa (13) | da incerta a difettosa (2) |
|---|---|
| calcium atom, TNF, 5-aza-2'-deoxycytidine, EGF, IL2, IL13 (le sei nelle 40); 5-azacytidine, DRB, chloroquine, copd, neratinib, radiation, Pladienolide B | 5 aza, r5020 |

Le altre 17 erano già difettose (16) o restano incerte (poly(I:C)).

**La regola della S5** dice che la scelta delle 40 e delle 132 decade se più di 5 verdetti passano fra corretta e difettosa, o uno solo nelle 40. Ne passano 13, e 6 nelle 40: la scelta decade. La decisione del PI nella S8b la faceva già decadere alla fine del run completo, e nessuna sessione prima del run usa le 40. Si rifà una volta sola dopo il run.

**Studi per meta-analisi senza gli errori** (conteggio degli studi distinti fra i confronti tenuti, C2(c)): con la lista di agosto 12 meta-analisi scendono sotto 3 studi, con la lista corretta 20. Le 8 nuove sono IFNA1, IL2, chloroquine, 5 aza, neratinib, IL15, DRB e calcium atom (IL2 e calcium atom nelle 40).

# 9. Osservazioni fuori dalle famiglie

- **Differenze tecniche fra i bracci.** `GSE105951`: trattati paired-end, controlli single-end. `GSE132782`: un trattato è una libreria 4SU, i controlli sono RNA totale. Letti buoni in prima lettura, perché le famiglie della rilettura non hanno una voce tecnica. **Deciso dal PI: sono errori** (§12).
- **Differenze di clone o costrutto** in confronti già difettosi per il tempo zero: `GSE188958` («GCN2cr3» contro «LC9B» nei titoli), `GSE207409` («GFP» contro «CTERM»). Il verdetto non cambia.
- **Etichette dello Stadio 2 smentite dai metadati GEO** in almeno 9 studi (`GSE93153`, `GSE221804`, `GSE222658`, `GSE247389`, `GSE209582`, `GSE229331`, `GSE118566`, `GSE198670`, `GSE184891`). La rilettura di agosto leggeva solo le etichette: non poteva vederli. Rinvio alla rilettura dopo il run (S15).
- **Accuse di agosto non confermate dai metadati**, fra le 15 rilette: `GSE163241` (i passaggi sono appaiati; resta errore per il tempo zero, categoria cambiata), `GSE161860` («Pre» su tutti e due i bracci; l'accusa resta), `GSE210984` (non «iPSC-derived»; resta errore per il formato). Le altre 114 accuse di agosto non sono state rilette sui metadati. Rinvio alla S15.
- **Composizione per genotipo** (`GSE145382`, TREML4) e tempo sequenziale (`GSE213691`, 24 h più 4 h): incerti, nel riferimento come non provati.

# 10. Previsioni

| # | atteso | misurato | esito |
|---|---|---|---|
| P1 verdetti fra corretta e difettosa | 8; rilevante oltre 5 o uno nelle 40 | 13, 6 nelle 40 | **nella zona rilevante, come previsto**: la scelta delle 40 e delle 132 decade (§8). Censimento, senza intervallo |
| P2 righe lette buone (errori della regola) | 20; rilevante oltre 0 | 18 (19 prima della decisione tecnica) | **confermata**: la regola non va in produzione così com'è |
| P3 tempo zero solo nei metadati GEO | 3; rilevante oltre 0 | 12 | **nella zona rilevante, come previsto**, 4 volte l'atteso: lo Stadio 1 non legge il tempo zero nei titoli («D0», «Day0», «_0h», «T0») |

# 11. Dubbi e come si chiudono

| dubbio | chiusura |
|---|---|
| il censimento a tempo zero non vede forme attaccate ad altre lettere | **corretto**: censimento allargato (§4), dichiarato come aggiunta dopo il deposito |
| 18 errori del rilevatore, sette cause | **rinviato** alla S12 (decisione 3 del PI), scritto nel suo riquadro |
| 112 errori noti che il rilevatore non vede | **rinviato** alla S12, scritto nel suo riquadro con che cosa serve |
| la scelta delle 40 e delle 132 decade | **spiegato** (§8): decisione del PI nella S8b, si rifà dopo il run |
| etichette dello Stadio 2 smentite dai metadati; 114 accuse di agosto non rilette sui metadati | **rinviato** alla S15, scritto nel suo riquadro |
| differenze tecniche fra i bracci | **deciso** dal PI (§12): sono errori, applicato a tutti i confronti |
| lettore unico, non alla cieca; sensibilità corretta ottimistica | **spiegato**: dichiarati nel deposito e in §1, §5 |
| la proposta del PI di confrontarsi con meta-analisi pubblicate | **rinviato**: sessione nuova nell'handout |

# 12. Decisioni del PI

Il PI ha letto il riassunto e ha risposto il 2026-11-07: «si».

1. **Una differenza solo tecnica fra trattati e controlli è un errore**: metodo di sequenziamento, strumento, kit di
   preparazione, RNA marcato. Vale per tutti i confronti, come il tempo zero.

**Applicazione a tutti i 1.903 confronti.** `26-campi-tecnici.R` estrae dall'H5 strumento, selezione, fonte e strategia
della libreria, molecola, piattaforma e protocollo di estrazione. `27-differenze-tecniche.py` segnala un campo senza
valori in comune fra i bracci, e i marcatori 4sU, paired-end, single-end, total RNA e polyA presenti su un braccio e
non sull'altro. Una prima versione cercava i marcatori anche nel protocollo di estrazione, che è quasi sempre uguale
in tutto lo studio, e non vedeva `GSE132782`: corretta prima di leggere i candidati. Candidati: 8 in 7 studi, tutti
letti (`28-lettura-tecnica.py`):

| studio | esito |
|---|---|
| `GSE105951` (irradiazione) | errore nuovo: paired-end contro single-end (riga 4) |
| `GSE132782` (Pladienolide B) | errore nuovo: un trattato 4SU, controlli Total (riga 22) |
| `GSE122409`, due confronti (IL2) | errori nuovi: NovaSeq 6000 e kit Zymo contro HiSeq 2500 e kit QIAGEN; anche donatori diversi |
| `GSE150819` (SARS-CoV-2) | errore nuovo: NovaSeq 6000 con TruSeq contro NextSeq 500 con NEBNext |
| `GSE57116`, `GSE101216` | già errori; la differenza tecnica si aggiunge alla famiglia |
| `GSE207821` (Alzheimer) | buono: stesso strumento e stesso kit, cambia solo una frase del protocollo |

**Che cosa il censimento tecnico non vede.** Paired-end e single-end non sono un campo GEO: si vedono solo se gli
autori li scrivono nelle caratteristiche o nel titolo. Lo stesso vale per un kit diverso scritto in un protocollo
unico per tutto lo studio.

**I numeri finali**, dopo la decisione (`40-out.txt`, `46-out.txt`; quelli del riassunto sono nei file
`prima-della-decisione-tecnica-*`):

| | prima della decisione | dopo |
|---|---:|---:|
| righe dell'elenco: errori veri / errori della regola / incerti | 36 / 19 / 1 | 37 / 18 / 1 |
| errori nel riferimento corretto | 188 | 193 |
| visti dalla combinazione / non visti | 80 / 108 | 81 / 112 |
| meta-analisi che cambiano verdetto (da corretta a difettosa) | 14 (12) | 15 (13) |
| di cui nelle 40 | 6 | 6 |
| meta-analisi sotto 3 studi senza gli errori | 19 | 20 |

Con questa decisione nessun dubbio di §11 resta aperto: i rinvii stanno nei riquadri della S12 e della S15, e la
proposta del PI sulle meta-analisi pubblicate è la sessione S7b dell'handout. La sessione è chiusa.

# Da dove vengono i numeri del riassunto

| nel riassunto | fonte | valore letto |
|---|---|---|
| *tutte le righe sotto, salvo dove indicato* | file `prima-della-decisione-tecnica-*`, cioè lo stato letto dal PI | |
| «56 confronti», «1.903 confronti» | `40-out.txt`, C3; `20-confronti.csv` | 56; 1.903 |
| «36 errori veri», «19 errori del rilevatore», «1 incerto» | `40-out.txt`, «Previsione P2» | 36, 19, 1 |
| «30 dei 36 errori si leggono solo nei dati GEO» | `40-out.txt`, «righe A per fonte» | metadato 30, etichetta 6 |
| «HBV D10», «radiation» | `30-note-lettura.tsv`, righe 88 e 67 | Mock D8; Radiation+CB-839 |
| «50 confronti, in 17 studi e 18 meta-analisi», «6», «31», «12» | `40-out.txt`, «Tempo zero» e P3 | 50, 17, 18; 6; 31; 12 |
| «da 129 a 188» | `40-out.txt`, «Riferimento corretto» | 129, 188 |
| «14 meta-analisi», «12», «2», «Sei» e i sei nomi | `40-out.txt`, «P1 verdetti»; `45-verdetti-che-cambiano.csv` | 12 + 2; 6 nelle 40 |
| «19 meta-analisi», «12» sotto 3 studi | `40-out.txt`, ultima sezione | 19; 12 |
| «sette cause», «6 casi» | `40-out.txt`, «Cause dei falsi allarmi» | 7 classi; 6 |
| «80 dei 188», «108», «28», «20», «14», «12» | `46-out.txt` | 80; 108; 28, 20, 14, 12 |
| paired-end e single-end; 4sU | `30-note-lettura.tsv`, righe 4 e 22 | `GSE105951`; `GSE132782` |

[^previsioni]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/00-previsioni.md`, commit `c50228a`.
[^s10b]: `docs/findings/2026-11-07-S10b-rilevatore-metadati.md`, §4 e §10.
[^schede]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/23-schede.txt`.
[^lettura]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/30-lettura.csv`.
[^note]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/30-note-lettura.tsv`.
[^misura]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/40-out.txt`.
[^registro]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/40-registro-cambi.csv`.
[^rif]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv`.
[^difetti]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/42-difetti-dopo-S11.csv`.
[^verdetti]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/45-verdetti-che-cambiano.csv`.
[^nonvisti]: `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/46-out.txt`.
