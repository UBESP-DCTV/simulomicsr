---
type: Finding
title: "La regola sulle etichette corretta trova 10 confronti mal appaiati su 129, e le tabelle dei nomi cadono su altri campioni"
description: "La regola di riga corretta come chiede l'handout, misurata su tutti i 1.903 confronti del deliverable contro un riferimento di 129 confronti difettosi: 10 presi, 51 falsi allarmi su 1.704. I difetti sono quasi tutti asimmetrici e la regola sulle etichette non li vede. Le tabelle dei nomi, agganciate per record_id, cadono su altri campioni negli studi rigenerati."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-07T21:30:00+01:00'}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-07-S10-rilevatore/00-previsioni.md", title: "Cancelli, previsioni e decisioni del PI, depositati prima della misura"}
- {id: regola, resource: "analysis/audit/2026-11-07-S10-rilevatore/10-regola-v2.R", title: "Le quattro varianti della regola, congelate"}
- {id: c2, resource: "analysis/audit/2026-11-07-S10-rilevatore/20-cancello-C2.txt", title: "Cancello di riproduzione"}
- {id: c4, resource: "analysis/audit/2026-11-07-S10-rilevatore/20-cancello-C4.csv", title: "Controlli positivi e negativi"}
- {id: conto, resource: "analysis/audit/2026-11-07-S10-rilevatore/30-conto.txt", title: "Il conto del riferimento, committato prima della misura"}
- {id: riferimento, resource: "analysis/audit/2026-11-07-S10-rilevatore/30-riferimento.csv", title: "I 129 confronti difettosi"}
- {id: amano, resource: "analysis/audit/2026-11-07-S10-rilevatore/30-a-mano.csv", title: "Le 23 attribuzioni a mano, con il motivo"}
- {id: misura, resource: "analysis/audit/2026-11-07-S10-rilevatore/40-out.txt", title: "La misura delle quattro varianti"}
- {id: falsi, resource: "analysis/audit/2026-11-07-S10-rilevatore/40-falsi-allarmi.csv", title: "I 54 allarmi da leggere"}
- {id: nonvisti, resource: "analysis/audit/2026-11-07-S10-rilevatore/40-difetti-non-visti.csv", title: "I 119 difetti non visti"}
- {id: diagnosi, resource: "analysis/audit/2026-11-07-S10-rilevatore/45-out.txt", title: "Che cosa la regola puo' vedere, per famiglia"}
- {id: tabelle, resource: "analysis/audit/2026-11-07-S10-rilevatore/50-out.txt", title: "Tabelle dei nomi: record agganciati per stato"}
- {id: campioni, resource: "analysis/audit/2026-11-07-S10-rilevatore/51-out.txt", title: "Tabelle dei nomi: il nome finale di ogni campione"}
- {id: meccanismo, resource: "analysis/audit/2026-11-07-S10-rilevatore/52-out.txt", title: "Tabelle dei nomi: il numero d'ordine del gruppo"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi, non toccato"}
---

# In breve

## In breve: una regola sulle etichette può trovare i confronti mal appaiati?

**A cosa serviva.** Secondo la rilettura di agosto, 129 confronti del deliverable sono mal appaiati: per esempio il trattato riceve due agenti e il controllo nessuno. Il codice ha già una regola che scarta questi confronti, ma nel deliverable non ne scarta nessuno. Abbiamo corretto la regola come chiedeva l'handout, fuori dal pacchetto, e l'abbiamo misurata su tutti i 1.903 confronti. Abbiamo anche controllato se le tabelle che correggono i nomi dei gruppi cadono sui campioni giusti.

**Cosa abbiamo trovato.**

1. **La regola corretta prende 10 confronti mal appaiati su 129, cioè l'8%.** Avevo previsto il 30%. Tre dei 10 li prende per caso: in uno studio sulla distrofia miotonica la sigla DM1 è anche il nome di un farmaco nei dizionari.
2. **La regola fa 51 falsi allarmi su 1.704 confronti puliti, sotto la soglia di 85 che hai fissato.** Tutti i 51 vengono dalla nuova soglia a un agente. 32 stanno nelle meta-analisi su TNF e sul calcitriolo, e vengono da due difetti del nome dell'entità che le correzioni già decise cambieranno.
3. **I difetti sono quasi tutti asimmetrici, e una regola sulle etichette non li vede.** In 12 difetti di tempo su 19 il tempo è scritto su un braccio solo. Il secondo agente è quasi sempre un codice di ricerca, una sigla di due lettere o la parola «Compound», che i dizionari non conoscono. L'etnia e il sesso non sono codici di soggetto.
4. **I confronti da trovare sono 129, non 97.** Molte righe della rilettura nominano più confronti. Ho agganciato tutte le 97 righe: 81 senza intervento, 16 con 23 confronti attribuiti a mano.
5. **Negli studi rigenerati le tabelle dei nomi cadono su altri campioni.** Le tabelle si agganciano quasi sempre al numero d'ordine del gruppo, e un modello rigenerato numera i gruppi in un altro modo. In 283 confronti del deliverable su 1.903, il primo campione trattato riceve dalle tabelle un nome diverso da quello che la correzione aveva deciso, oppure nessun nome. Nel re-run da zero il 70% dei gruppi e dei confronti a cui le tabelle si agganciano ha altri campioni o non esiste più. Non sappiamo ancora quante meta-analisi cambiano, perché il nome del campione decide l'entità solo in alcuni casi.

**Cosa devi decidere.**

1. **Che cosa facciamo del rilevatore? Consiglio una sessione nuova che costruisca la regola sui metadati di ogni campione, con lo stesso riferimento e la stessa soglia di 85.** Per ogni campione il modello ha già scritto gli agenti uno per uno, la durata in ore, il donatore, il sesso, l'etnia e il tipo di materiale. Sono le informazioni che le etichette scrivono su un braccio solo. La lettura dei falsi allarmi aspetta il risultato della sessione nuova.
   - In alternativa apriamo subito la lettura dei 54 allarmi, come prevede la soglia. La lettura richiede una sessione, ma 32 allarmi cambieranno con le correzioni del nome dell'entità. In produzione la regola toglierebbe circa 10 difetti su 129.
   - In alternativa fermiamo qui il rilevatore e scriviamo nei Methods che le regole sulle etichette vedono meno di un difetto su dieci. Gli studi doppi si tolgono comunque nel calcolo che applica le correzioni.
2. **Correggiamo l'aggancio delle tabelle dei nomi in una sessione nuova, prima del calcolo che applica le correzioni? Consiglio di sì.** La correzione aggancia ogni nome ai campioni che la tabella ha davvero visto, letti nel master del run vecchio, e non richiede il modello. La stessa sessione misura con gli script della sessione sulle greche quante meta-analisi cambiano.
   - In alternativa misuro adesso quante meta-analisi cambiano, con circa un'ora di calcolo, e decidiamo dopo.
   - In alternativa rigeneriamo le tabelle con il modello sui gruppi nuovi. Il costo non è misurato, e dopo il re-run da zero va pagato di nuovo.
   - In ogni caso il raggruppamento sul re-run da zero non può usare le tabelle come sono oggi.

**Comunque:**

- il deliverable, i master, la copia di salvataggio e il codice del pacchetto non sono cambiati;
- la traduzione delle lettere greche e la regola sul materiale prendono 5 difetti senza falsi allarmi, e il passaggio in produzione terrà conto di questa differenza;
- l'elenco dei 54 allarmi è pronto, e nessuno l'ha ancora letto.

Appena decidi questi 2 punti, la sessione è chiusa.

**Sui tempi di calcolo.** Le stime sono mie. L'ora per la misura sulle meta-analisi viene dai tempi della sessione sulle greche. Lì la raccolta degli ingressi ha richiesto 20 minuti con un processore, e le chiavi 15 minuti con 16 processori. In questa sessione la cattura degli ingressi della regola ha richiesto 12 minuti con un processore, quasi tutti per caricare i dizionari.

# 1. Che cosa è stato fatto

**Oggetto.** I 1.903 confronti poolati del deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d` (`analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds`, elemento `tenuti`), 194 meta-analisi, 993 studi. Il riferimento è `analysis/audit/2026-08-20-rilettura-194/difetti.csv` (97 righe, 94 coppie gruppo-studio). Manifesto SHA-256 verificato a inizio e a fine sessione[^c1].

**Decisioni del PI prima della misura** (2026-11-07, `00-previsioni.md`[^previsioni]): N = 85 falsi allarmi su 1.704, oltre i quali la regola non è recuperabile; lettura dei falsi allarmi a blocchi di al massimo 150.

**La regola** (`10-regola-v2.R`[^regola], congelata nel commit `e55e315`, prima di leggere le righe del riferimento oltre le quattro citate nell'handout). Quattro varianti cumulative, ognuna cambia una cosa:

| variante | che cosa cambia |
|---|---|
| V0 | `.rp_row_defect()` di produzione, con gli ingressi veri |
| V1 | + lettere greche tradotte (insieme G e traduzione della S9) nelle etichette e nei token dell'entità |
| V2 | + soglia: almeno un agente in più nel trattato dopo aver tolto l'entità; l'entità si toglie per ID, per token e per l'ID che i resolver danno ai token dell'entità |
| V3 | + regola nuova `materiale_diverso`: i due bracci nominano sistemi biologici (staminali, tridimensionale, linea, primaria, tessuto, xenotrapianto) senza uno in comune |

`R/stage3-row-pairing.R` e tutto `R/` non sono cambiati (`git diff --stat R/` vuoto).

**Gli ingressi veri** (`20-ingressi-regola.R`). Lo script di agosto chiamava la regola con la classe ricavata da `kind_effective_resolved`, che sbaglia il tipo (finding S6), e senza i token dell'entità. Qui `.ca_member_contrast()` gira sugli ingressi della chiave raccolti dalla S9, e `trace()` cattura gli argomenti che la produzione passa a `.rp_row_defect()` e a `.ca_entity_tokens()`.

# 2. Il riferimento al livello del confronto

`difetti.csv` è indicizzato per coppia (gruppo, studio). `30-riferimento.py` aggancia ogni riga ai confronti che nomina come colpevoli[^conto]:

| stato della riga | righe | confronti |
|---|---:|---:|
| la coppia ha un solo confronto | 40 | 40 |
| il parser chiude la prima citazione dopo TRATTATO (quattro formati, greche tradotte) | 41 | |
| il parser chiude la prima citazione, e la riga nomina altri confronti attribuiti a mano | 16 | 23 a mano |
| non agganciate | 0 | |

- Nelle 40 righe a confronto unico la prima citazione coincide con il confronto in 40 casi su 40.
- Se più confronti hanno le stesse due etichette, la riga non li distingue: il parser li prende tutti (per esempio i cinque confronti identici di `GSE123285`).
- Le 23 attribuzioni a mano hanno il motivo in `30-a-mano.csv`[^amano]. Regola dichiarata: se la riga nomina più trattati contro lo stesso controllo e non dice quale è appaiato («tutti e due», «entrambi»), li prendo tutti. Vale per `GSE218860`, `GSE99875`, `GSE169140`, `GSE217421`, `GSE158305`, `GSE249721`.
- Il testo dopo «a fronte di», «accanto», «nello stesso studio» nomina un confronto di paragone e non entra.

**Risultato:** 129 confronti difettosi distinti (122 senza le tre righe «non provato / sospetto»). Le 94 coppie accusate hanno 199 confronti: 129 difettosi e 70 **altri negativi**. I **puliti** sono 1.704. Il conto è stato committato (`3de5109`) prima della misura.

# 3. Riproduzione e controlli

| cancello | esito |
|---|---|
| C1 manifesto a inizio e a fine sessione | `VERIFICA OK` due volte |
| C2(a) i 1.903 arrivano alla regola una volta, con esito "" in produzione e in V0 | 1.903 su 1.903, tre volte[^c2] |
| C2(b) con gli ingressi di agosto la produzione segnala 2 | 2 |
| C3 copertura | 97 righe su 97 con uno stato; 1.903 su 1.903 con un esito per V0-V3 |
| C4 controlli | V3 segnala `GSE97744` «Circulating macrophage + IFN-γ and LPS» e `GSE210984` «MSC iPSC-derived TGF-β 21 days»; tace su `GSE139963` «TGF-β1» e su `GSE210984` «MSC Primary Culture TGF-β 14 days»[^c4] |
| C5 codice di produzione intatto | `git diff --stat R/` vuoto |

**C2(a) spiega il «2 su 1.903» dell'handout.** La regola di produzione scarta già nello Stadio 3 i confronti che segnala: i 1.903 sono i sopravvissuti, e con gli ingressi veri la regola tace su tutti. I 2 dello script di agosto venivano dagli ingressi ricostruiti.

**Nove membri hanno un'entità diversa da quella del gruppo**: cinque di TNF (`CHEMBL:CHEMBL265582` nel membro, `HGNC:11892` nel gruppo), tre di IL-15 (`CHEMBL:CHEMBL4297989`, `HGNC:5977`), uno di IL-6 (`MeSH:D015850`, `HGNC:6018`). Entrano nel gruppo per fusione. La regola usa l'entità del membro, come la produzione.

# 4. La misura

| variante | segnalati | difettosi presi (su 129) | IC95 | falsi allarmi (su 1.704) | IC95 del conteggio | altri negativi (su 70) | sui 199 |
|---|---:|---:|---|---:|---|---:|---:|
| V0 | 0 | 0 | | 0 | | 0 | 0 |
| V1 | 3 | 3 (2,3%) | [0,0; 6,3] | 0 | | 0 | 3 |
| V2 | 62 | 8 (6,2%) | [1,1; 12,8] | 51 (3,0%) | [28; 78] | 3 | 11 |
| V3 | 64 | 10 (7,8%) | [2,3; 14,4] | 51 (3,0%) | [28; 78] | 3 | 13 |

Bootstrap degli studi, B = 2000, seme 20261107[^misura]. Senza le righe non provate V3 prende 10 su 122 (8,2%).

**Che cosa porta ogni correzione.** La traduzione delle greche (V1) prende 3 difetti senza falsi allarmi: `GSE205853` (IFN-γ con IL-1β, due confronti) e `GSE97744`. La soglia a un agente (V2) prende 5 difetti e porta tutti i 51 falsi allarmi. La regola sul materiale (V3) prende 2 difetti (`GSE210984`, `GSE205787`) senza falsi allarmi.

**Tre dei 10 sono presi per caso.** In `GSE86356` (distrofia miotonica, sede anatomica diversa) la sigla «DM1» risolve a `CHEBI:82755` (mertansina, sinonimo «dm1»): la regola segnala tutti i confronti DM1 del gruppo, anche i puliti. In `GSE152004` «Asthmatic small molecule» la parola «molecule» risolve al termine generico `CHEBI:25367`: il difetto riguarda proprio l'esposizione a un farmaco, ma il motivo è debole.

**Per famiglia** (le famiglie di `30-consolida.py`):

| famiglia | difettosi | presi |
|---|---:|---:|
| secondo agente solo nel trattato | 41 | 3 |
| materiale / tipo cellulare diverso | 22 | 2 |
| tempo non appaiato | 19 | 0 |
| altro | 15 | 1 |
| donatore / soggetto / sesso / etnia | 14 | 0 |
| sede anatomica diversa | 6 | 3 (per caso) |
| entità non isolata dal confronto | 6 | 0 |
| passaggio, dose, controllo, genotipo | 6 | 1 |

# 5. Perché la regola vede l'8%

`45-perche-non-visti.R` misura, per ogni difetto, se la sotto-regola della sua famiglia ha gli ingressi che le servono[^diagnosi]:

- **Tempo** (19): solo 1 difetto dichiara un tempo su entrambi i bracci; 12 lo dichiarano su un braccio solo. La regola confronta i tempi solo se ci sono su entrambi: i controlli «time zero», «PC9_DMSO», «vehicle control» non hanno un tempo leggibile.
- **Donatore, sesso, etnia** (14): in 0 difetti la regola trova un codice di soggetto su entrambi i bracci. «Chinese, M» contro «Malay, M» non contiene codici.
- **Materiale** (22): solo 2 difetti nominano un sistema biologico su entrambi i bracci, e la regola li prende tutti e 2. Gli altri scrivono il sistema su un braccio solo («Asthma Airway Tissue» contro «Healthy Airway Epithelial Cells») o non lo scrivono.
- **Secondo agente** (41): 37 difetti hanno parole in più nel trattato, ma in 23 nessuna parola in più è riconosciuta dai resolver. Quando una parola è riconosciuta, spesso è l'entità scritta in un'altra forma. Il secondo agente è un codice di ricerca (`SHP1705`, `X15695`, `BI-3802`), una sigla di due lettere (AR, T3, CP, PW), un nome che i dizionari non hanno (Torin, ruxo, EPS, MtbLysate) o la parola «Compound». L'ipossia non è un agente per i resolver: `GSE139963` «Hypoxia + TGF-β1» resta invisibile, come previsto (P4).

Il quadro è uno: **i difetti del riferimento sono asimmetrici**. L'informazione che rompe il confronto sta su un braccio solo, e una regola che confronta i due bracci sulle etichette non ha niente da confrontare. Lo Stadio 1 scrive per ogni campione `perturbations` (agenti uno per uno, con `duration.value_hours` e `is_zero_timepoint`), `patient_metadata` (`donor_id`, `sex`, `ancestry_or_population`, `age`) e `cell_context` (`context_kind`, `tissue`, `cell_line_cellosaurus_candidate`, `passage_or_state`). Sono i campi dove l'asimmetria si legge, sui campioni dei due bracci.

# 6. I falsi allarmi, senza leggerli

54 allarmi: 51 sui puliti, 3 sugli altri negativi, in `40-falsi-allarmi.csv`[^falsi]. Non li ho letti uno per uno. Distribuzione per meta-analisi (sui puliti):

| meta-analisi (entità) | confronti | studi |
|---|---:|---:|
| TNF (`HGNC:11892`) | 25 | 14 |
| calcitriolo (`STR:1_25_oh_2d3`) | 7 | 2 |
| SARS-CoV-2 | 6 | 2 |
| altre otto, da 1 a 2 confronti ciascuna | 13 | 9 |

- **TNF.** «TNF-α» tradotto diventa «TNF-alpha», e il resolver porta questa forma a `CHEMBL:CHEMBL265582` invece che a `HGNC:11892`. I token dell'entità non contengono «tnf-alpha», quindi l'agente resta in più. È il difetto del finding S9 §3, assegnato alla correzione della chiave (S12b, citochine in lettere latine). Con la soglia a due agenti non scattava.
- **Calcitriolo.** È l'entità con più nomi assegnata alla S12c (verifica sotto).
- I 3 sugli altri negativi stanno in `GSE86356` (DM1, sopra).

54 è sotto 150: la lettura richiede una sessione sola, se il PI la apre.

- **Calcitriolo, verificato.** Le etichette dei 7 confronti dicono «Calcitriol». L'entità è `STR:1_25_oh_2d3` e i suoi token sono «anisole» e «methylcanadine», gli ID sbagliati che il modello scrive per il calcitriolo (finding S9 §12). «calcitriol» non è fra i token dell'entità e conta come agente in più.

# 7. Le tabelle dei nomi (dubbio ricevuto dalla prova del re-run)

**Il meccanismo.** Le tabelle `name-cleanup-side-table-v1.rds` e `name-cleanup-fallback-side-table.rds` correggono il nome di un gruppo dei run v9. La produzione le applica così (`R/stage3-name-cleanup-overlay.R:66`): gruppo del run v9 → `record_id` del run v9 → campioni trattati di quel `record_id` **nel master corrente**. Molti `record_id` contengono il numero d'ordine di un gruppo (`GSE101353__grp_0004`, `GSE102556__mg29`, `…__grp_0023_vs_grp_0022`): uno Stadio 2 rigenerato numera i gruppi in un altro modo, e il nome cade su altri campioni. Misurato (`52-out.txt`[^meccanismo]): dei 5.416 record distinti che nel master A3 hanno campioni diversi, 5.104 hanno un identificativo numerico, e 4.583 di questi non hanno più nessun campione in comune con il run vecchio.

**Il master del run v9.** Il 99,3% dei `record_id` dei run v9 sta nel master vecchio `p4-fase-f4-stage2-master-v3.jsonl` (P5a confermata)[^tabelle].

**Per record agganciato** (115.352, censimento di tutte le righe override):

| stato rispetto al master vecchio | master del deliverable (A3) | master rifatto da zero (S14) |
|---|---:|---:|
| stessi campioni | 91.255 | 34.450 |
| campioni diversi | 15.841 | 50.635 |
| `record_id` assente nel master nuovo | 7.426 | 29.437 |
| assente anche nel master vecchio | 830 | 830 |

Nel deliverable tutti i 15.841 cambi stanno nei 2.566 studi rigenerati: lì solo 6.671 record su 29.938 tengono gli stessi campioni. Negli altri studi i record sono 84.584 uguali e 0 diversi. Nel master da zero il 69,9% dei record agganciati ha campioni diversi o non esiste più.

**Per campione** (`51-nomi-per-campione.R`[^campioni]): il nome finale che ogni campione riceve in produzione, contro il nome agganciato ai campioni del run vecchio, con le stesse regole di precedenza.

| campioni | A3 | S14 |
|---|---:|---:|
| stesso nome | 85.914 | 54.114 |
| nome diverso | 2.774 | 7.708 |
| nome perso (la correzione lo dava, la produzione no) | 10.343 | 37.209 |
| nome non deciso (la produzione lo dà, la correzione no) | 4.686 | 13.105 |

**Nel deliverable**, sul primo campione trattato dei 1.903 confronti: 1.336 non ricevono nomi dalle tabelle, 284 ricevono il nome giusto, **283** no (33 nome diverso, 169 nome perso, 81 nome non deciso), in 105 meta-analisi. Esempio: `GSE186341`, «HCC1143 cells treated with Lapatinib», riceve `CHEBI:49375` invece di `CHEBI:49603`. Il confronto resta nella meta-analisi sul lapatinib, perché la chiave d'entità si calcola anche dalle etichette: il nome dell'anchor decide solo nel ramo «on-contrast». **Quante meta-analisi cambiano non è misurato.** Serve il ricalcolo delle chiavi su tutto lo Stadio 3 con l'aggancio corretto, con gli script della S9.

# 8. Previsioni

| # | atteso | misurato | esito |
|---|---|---|---|
| P1 falsi allarmi V3 | 45, ≤ 85 | 51, IC95 [28; 78] | **confermata**: la regola è recuperabile per la soglia del PI |
| P2 sensibilità V3 | 30%, [20%; 50%] | 7,8%, IC95 [2,3; 14,4] | **smentita**: spiegata in §5 |
| P3 guadagno per correzione | V1 ≤ 3; V2 più di V1 e di V3 | V1 3, V2 5, V3 2 | **confermata**; V2 porta anche tutti i 51 falsi allarmi |
| P4 casi invisibili | Hypoxia + TGF-β1, TGFB+AR | entrambi taciuti | **confermata** |
| P5a record v9 nel master vecchio | ≥ 99% | 99,3% | **confermata** |
| P5b record con campioni diversi, A3 | 3%, [0%; 1%] | 13,8% | **smentita**: spiegata in §7 |
| P5c confronti del deliverable toccati | 5 | 189 con un campione trattato toccato; 283 con un nome diverso sul primo | **smentita**: spiegata in §7 |
| P5d record diversi o assenti, S14 | 30%, [0%; 1%] | 69,9% | **smentita**: spiegata in §7 |

I conteggi di P5 sono censimenti di tutte le righe: non hanno intervallo di campionamento.

# 9. Dubbi e come si chiudono

| dubbio | chiusura |
|---|---|
| P2 smentita | spiegata (§5): i difetti sono asimmetrici |
| tre difetti presi per caso | spiegato (§4): «DM1» → mertansina |
| falsi allarmi concentrati | spiegato (§6): 32 su 51 da difetti della chiave già assegnati a S12b e S12c |
| nove entità diverse fra membro e gruppo | spiegato (§3): fusioni |
| P5b-P5d smentite | meccanismo spiegato (§7); effetto sulle meta-analisi **deciso** dal PI: si misura in S12d |
| che cosa fare del rilevatore | **deciso** dal PI: S10b |

# 10. Decisioni del PI

Il PI ha letto il riassunto e ha risposto il 2026-11-07: «si alle tue proposte».

1. **Il rilevatore si rifà sui metadati dei campioni**, in una sessione nuova (S10b), con lo stesso riferimento di 129 confronti
   difettosi e la stessa soglia N = 85. La lettura dei falsi allarmi (S11) aspetta S10b e legge gli allarmi della regola che S10b
   sceglie.
2. **L'aggancio delle tabelle dei nomi si corregge** in una sessione nuova (S12d), prima del calcolo che applica le correzioni
   (S13) e prima del raggruppamento sul re-run (S14): ogni nome si aggancia ai campioni del master su cui la tabella è stata
   scritta, senza il modello. La stessa sessione misura quante meta-analisi cambiano.

Con queste due decisioni nessun dubbio di §9 resta aperto: la sessione è chiusa.

# Da dove vengono i numeri del riassunto

| nel riassunto | fonte | valore letto |
|---|---|---|
| «129 confronti mal appaiati» | `30-conto.txt`, riga «confronti difettosi distinti (D)» | 129 |
| «1.903 confronti» | `40-out.txt`, cancello C3 | 1903 |
| «10 su 129, cioè l'8%» | `40-out.txt`, scala, riga V3 | 10/129 (7.8%) |
| «Avevo previsto il 30%» | `00-previsioni.md`, P2 | 30% |
| «Tre dei 10 per caso», «DM1» | `40-esiti.csv`, `GSE86356` tre righe; dizionario ChEBI, `dm1` → 82755 | 3 |
| «51 falsi allarmi su 1.704» | `40-out.txt`, scala, riga V3 | 51/1704 |
| «soglia di 85» | `00-previsioni.md`, decisione 1 | 85 |
| «Tutti i 51 dalla nuova soglia» | `40-out.txt`, P3, falsi allarmi aggiunti 0, 51, 0 | 51 |
| «32 su TNF e calcitriolo» | `40-falsi-allarmi.csv`, conteggio per entità | 25 + 7 |
| «12 difetti di tempo su 19» | `45-out.txt`, riga tempo, `tempo_in_uno_solo` | 12 su 19 |
| «81 senza intervento, 16 con 23 a mano» | `30-conto.txt` | 81, 16, 23 |
| «97 righe» | `30-conto.txt`, totale | 97 |
| «quasi sempre al numero d'ordine» | `52-out.txt`, record distinti diversi con identificativo numerico | 5.104 su 5.416 |
| «283 confronti su 1.903» | `51-out.txt`, ultima riga | 283 |
| «il 70%» | `50-out.txt`, `stato_S14`: (50.635 + 29.437) / 114.522 | 69,9% |
| «5 difetti senza falsi allarmi» | `40-out.txt`, P3: V1-V0 3, V3-V2 2, falsi allarmi 0 e 0 | 5 |
| «54 allarmi» | `40-falsi-allarmi.csv`, righe | 54 |
| «20 minuti», «15 minuti», «16 processori» | finding S9, «Sui tempi di calcolo» | 20, 7 + 8, 16 |
| «12 minuti» | `log/20.log`, ultima riga | 11,6 min |

[^c1]: `analysis/audit/2026-11-07-S10-rilevatore/10-manifesto-inizio.txt`, `90-manifesto-fine.txt`.
[^previsioni]: `analysis/audit/2026-11-07-S10-rilevatore/00-previsioni.md`, commit `e55e315`.
[^regola]: `analysis/audit/2026-11-07-S10-rilevatore/10-regola-v2.R`.
[^conto]: `analysis/audit/2026-11-07-S10-rilevatore/30-conto.txt`, commit `3de5109`.
[^amano]: `analysis/audit/2026-11-07-S10-rilevatore/30-a-mano.csv`.
[^c2]: `analysis/audit/2026-11-07-S10-rilevatore/20-cancello-C2.txt`.
[^c4]: `analysis/audit/2026-11-07-S10-rilevatore/20-cancello-C4.csv`.
[^misura]: `analysis/audit/2026-11-07-S10-rilevatore/40-out.txt`.
[^diagnosi]: `analysis/audit/2026-11-07-S10-rilevatore/45-out.txt`, `45-perche-non-visti.csv`.
[^falsi]: `analysis/audit/2026-11-07-S10-rilevatore/40-falsi-allarmi.csv`.
[^tabelle]: `analysis/audit/2026-11-07-S10-rilevatore/50-out.txt`, `log/50.log`.
[^campioni]: `analysis/audit/2026-11-07-S10-rilevatore/51-out.txt`, `51-deliverable-nome-diverso.csv`.
[^meccanismo]: `analysis/audit/2026-11-07-S10-rilevatore/52-out.txt`.
