---
type: Finding
title: "Il re-run completo: il conto dell'handout rivisto, e perché non sappiamo ancora quanti studi entrerebbero"
description: "Riproduce il conto dell'handout, corregge tre sue frasi, misura il costo dai tempi SLURM. La stima degli ingressi fallisce il proprio controllo. Propone una prova di circa 8 ore prima del sì o no."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-04T21:30:00+01:00'}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-04-S8-re-run/00-previsioni.md", title: "Cancelli, previsioni, stimatore, commit 665f102"}
- {id: conto, resource: "analysis/audit/2026-11-04-S8-re-run/10-out.txt", title: "Il conto, le previsioni, i controlli"}
- {id: diagnosi, resource: "analysis/audit/2026-11-04-S8-re-run/30-out.txt", title: "Perché il cancello 4(b) fallisce"}
- {id: costo, resource: "analysis/audit/2026-11-04-S8-re-run/20-costo-out.txt", title: "Costo dai tempi SLURM"}
- {id: a3, resource: "analysis/audit/2026-08-16-A3/PREVISIONI-A3-PRIMA-DEL-RUN.md", title: "Definizione di A3 e suoi limiti dichiarati"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi"}
---

# In breve

## In breve: conviene rifare con il modello la classificazione di tutti gli studi?

**A cosa serviva.** Il run parziale di agosto ha rigenerato 2.566 studi su 24.394, cioè il 10,5%, e tutte le 194 meta-analisi vengono da quegli studi. Gli altri 21.828 studi conservano la classificazione del run vecchio. Questa sessione mette sul tavolo il conto completo, perché il re-run completo cambierebbe l'insieme di studi dell'articolo e costerebbe giorni di calcolo.

**Cosa abbiamo trovato.**

1. **Il controllo della mia stima degli ingressi è fallito, quindi non so dire quanti studi entrerebbero.** Ho stimato gli ingressi su metà degli studi rigenerati e li ho previsti sull'altra metà. Il rapporto fra previsto e osservato è 4,4 in un verso e 0,22 nell'altro, e la regola depositata chiedeva da 0,7 a 1,3.
   - La stima non è distorta in media, perché il rapporto mediano su 500 divisioni è 1,02. Gli eventi sono però troppo pochi: 40 arrivi in 19 studi, e 20 arrivi in un solo studio con molti composti.
   - Per la regola depositata, questo riassunto non usa quella stima.
2. **Il saldo di 130 studi persi non è un argomento contro il re-run completo, perché dipende dal disegno del run parziale.** Ogni studio poolato poteva uscire, ma uno studio non rigenerato non aveva quasi modo di entrare. Sono usciti 271 studi e ne sono entrati 141, tutti fra i rigenerati. Dai 21.828 non è entrato nessuno.
   - Bastano 130 ingressi per annullare il saldo, cioè lo 0,6% dei 21.828.
   - Le 17 meta-analisi perse sono un saldo: 38 uscite e 21 nuove. Di queste, 31 e 18 stavano a tre studi.
3. **Gli studi mai rigenerati stanno più lontani dalle meta-analisi di quanto diceva l'handout.** Solo 4.994 su 21.828 hanno un gruppo, non tutti come era scritto. Altri 11.175 hanno confronti che le regole fermano prima di formare un gruppo, e 5.659 non hanno confronti.
   - Solo 140 studi condividono entità e verso con una delle 194. Quindi un re-run limitato a questi studi copre 171 confronti su 8.647 e non vale la pena.
   - Fra i 1.443 studi rigenerati e prima fuori dalle meta-analisi, 10 sono entrati con un confronto di tipo nuovo per loro, cioè lo 0,7%. Quegli studi avevano già un gruppo condiviso, quindi il tasso non vale per gli altri senza una misura.
4. **Il re-run completo costa più dell'handout: da 38 a 70 ore di macchina, con valore centrale 63.** L'handout diceva da 40 a 60 ore. L'opzione che rende ripetibile il modello costa circa 3 volte sul passo che interpreta il disegno degli studi. Sul passo che classifica i campioni costa 1,43 volte.
   - La rilettura costa invece poco: tutte le 194 richiedono circa 40 minuti di macchina e 6 milioni di token.
   - Il costo vero è un altro. La tua scelta dell'insieme principale decade, e la lettura umana a campione resta valida solo per i gruppi che non cambiano.
5. **Non sappiamo se il passo che interpreta il disegno è ripetibile.** L'abbiamo provato solo sul passo che classifica i campioni, con 997 record identici su 997. Se vale anche qui, i 2.566 studi restano uguali e un secondo run può solo aggiungere studi. Se non vale, un secondo run sposta di nuovo i gruppi.

**Cosa devi decidere.**

1. **Rifacciamo tutto, sì o no? Consiglio una prova di circa 8 ore prima di rispondere.** La prova rigenera 2.000 studi scelti a caso fra i 21.828 e 300 studi già rigenerati, nello stesso job. Misura quanti studi entrano e se il passo sul disegno è ripetibile. Il numero serve anche se poi rispondi no, perché i Methods dichiarano un limite misurato.
   - La regola sarebbe questa: sotto 50 studi stimati rispondiamo no, sopra 250 rispondiamo sì, in mezzo decidi tu. Le due soglie sono un mio giudizio, e valgono il 5% e il 25% dei 993 studi poolati.
   - **In alternativa rispondi no subito.** Non costa calcolo e il paragrafo dei Methods è già pronto. Il limite resta però senza una misura: l'articolo può solo dire che studi isolati potrebbero formare gruppi nuovi.
   - **In alternativa rispondi sì subito.** Il risultato viene da un solo run e il run stesso misura la ripetibilità. Spendi da 38 a 70 ore di macchina senza sapere se entrano molti studi, e rifai la scelta dell'insieme principale.
2. **La sessione vale con il controllo fallito? Consiglio di sì, perché ho spiegato la causa e nessuna conclusione usa quella stima.** In alternativa ripetiamo la stima con un altro metodo. Gli eventi restano 40, quindi il risultato non migliora.

**Comunque:**

- le correzioni già decise girano prima in un calcolo separato, così il loro effetto resta distinto da quello del re-run;
- il numero della validazione esterna nell'articolo viene dall'ultimo deliverable: dopo le correzioni se la risposta è no, dopo il re-run se la risposta è sì;
- non tocchiamo il risultato depositato e non cambiamo nessun verdetto.

Appena decidi questi 2 punti, la sessione è chiusa.

**Sui tempi di calcolo.** Le stime sono mie e vengono dai tempi registrati dei job di agosto e di giugno, su 4 GPU H100. Il passo sul disegno ha richiesto 15,3 ore sul corpus senza l'opzione e 7,8 ore con l'opzione sugli studi che generano il 16,4% del testo. Il passo sui campioni ha richiesto 83 minuti per 86.898 record, con due blocchi insieme. La ricostruzione dei gruppi ha richiesto 2,2 ore con 8 processi. La prova somma 5,4 ore di modello e 2,2 ore locali.

# Decisioni del PI (2026-11-04)

Il PI ha risposto «va bene prova parziale in notturna di 8 ore. Il resto ok». Il testo qui sopra resta com'era quando il PI l'ha letto.

1. **Il re-run completo non è deciso: prima la prova.** La prova rigenera 2.000 studi a caso fra i 21.828 e 300 studi già rigenerati, di notte, per circa 8 ore. Le attese sono in `analysis/audit/2026-11-04-S8b-prova/00-previsioni.md`.
2. **La regola resta quella del riassunto:** sotto 50 studi stimati la risposta è no, sopra 250 è sì, in mezzo decide il PI con i numeri.
3. **La sessione vale con il cancello 4(b) fallito e spiegato.** P3-P6 restano non giudicate e non si citano.
4. **Il dubbio ricevuto dalla validazione esterna è chiuso:** la seconda esecuzione del test va sull'ultimo deliverable, dopo la risposta sul re-run.

# 1. I cancelli

Testo in `00-previsioni.md`[^previsioni], commit `665f102`.

| # | cancello | esito | fonte |
|---|---|---|---|
| 1 | manifesto SHA-256, inizio e fine | **passa**, due volte | `10-manifesto-e-copia.sh verifica` |
| 2 | 2.566, 24.394, 86.898 su 508.037, 211 → 194, 38, 21, 173, 1.123 → 993, 271, 141, 68/76/29 | **passa** | `10-out.txt:11-16` |
| 3 | tutti gli studi fuori da A3, tutte le 194 | **passa**: 21.828 classificati, 194 su 194 | `10-out.txt:20-21`, `:39` |
| 4a | lo strumento vede almeno 135 dei 141 entrati | **passa**: 140 su 141 | `10-out.txt:41` |
| 4b | previsto/osservato fra 0,7 e 1,3 nei due versi | **fallisce**: 4,43 e 0,22 | `10-out.txt:50-51` |
| 5 | ogni voce del costo ha una fonte o è marcata come stima | **passa** | §5 |

**Il fallimento di 4b, spiegato (`30-out.txt`).** I 40 arrivi cadono in 19 studi su 2.566. `GSE199800`, uno screening di piccole molecole su LNCaP con 288 confronti, ne porta 20. Con 500 divisioni casuali il rapporto ha mediana 1,02 e va da 0,18 a 5,41 (2,5-97,5%). Solo 1 divisione su 500 porta i due rapporti dentro l'intervallo. Senza i 3 studi con più arrivi la mediana resta 1,00 e le divisioni che passano sono 174 su 500: `r_altra` scende da 0,0188 a 0,0074. Lo stimatore non è distorto, è impreciso. L'IC del bootstrap dipende da quello studio e non dice quanti studi simili esistono fra i 21.828. Il cancello non è cambiato e lo stimatore non è stato ritoccato.

**Effetto.** Per la regola depositata P3-P6 non si giudicano e il riassunto non le usa. La decisione del PI sulla validità della sessione è chiesta nel riassunto.

# 2. Le previsioni

| # | quantità | atteso | intervallo | misurato | esito |
|---|---|---:|---:|---:|---|
| P1 | studi fuori da A3 con una coppia `cgroup` | 55% | 40-70% | **22,9%** (4.994 su 21.828), censimento | **smentita** |
| P2 | studi fuori con entità e verso di una delle 194 | 10% | 5-20% | **0,64%** (140), censimento | **smentita** |
| P3 | studi fuori che entrerebbero | 150 | 50-250 | 70,1 [27,9; 113,9] | non giudicata, cancello 4b |
| P4 | meta-analisi toccate fra le 194 | 60 | 49-146 | 53,2 [24,6; 76,2] | non giudicata |
| P5 | meta-analisi toccate fra le 41 | 10 | 4-20 | 12,1 [5,5; 17,4] | non giudicata |
| P6 | meta-analisi nuove da gruppi con due studi | 30 | 10-60 | 9,7 [1,7; 18,4] | non giudicata |

Questi quattro valori sono non validati: non vanno citati. Nelle aggiunte non depositate, togliendo gli studi in cui si è mosso un gruppo condiviso, P3 scende a 52,9 e P6 a 2,1.

**P1 smentita, spiegata (`10-out.txt:66-85`).** La frase dell'handout «21.828 studi, oggi tutti in gruppi da uno studio solo» è sbagliata. 16.834 non hanno un gruppo: 11.175 hanno confronti nello Stadio 2 e 5.659 non ne hanno. Per i 11.175 i motivi, con sovrapposizione, sono `tier_s_incomplete` in 9.132 studi, `contrast_gate` in 6.538, `rem_eligibility_n1` in 1.662, `direction_ambiguous` in 681. Questi studi sono una riserva che nessuna misura vede: lo stimatore conta solo chi ha già una coppia.

**P2 smentita, spiegata.** Il sottoinsieme A3 ha preso ogni studio che condivide una chiave intera con un altro, quindi fuori resta solo chi differisce almeno per il tipo di controllo. Le coppie con entità e verso di una delle 194 sono 171 su 8.647. Un re-run mirato su questi studi non ha oggetto. **Ho scartato quella opzione per questo motivo.**

# 3. Il conto dell'handout, riga per riga

| frase dell'handout | misura | correzione |
|---|---|---|
| «141 studi sono entrati venendo da fuori: il meccanismo funziona» | 141 entrati, tutti dentro i 2.566 (`10-out.txt:53`); 131 avevano già quella chiave, 10 solo chiavi nuove (`:42`) | «da fuori» vuol dire fuori dal vecchio deliverable, non fuori da A3. Non prova il meccanismo per i 21.828 |
| «271 usciti, netto −130» | riprodotto. Tasso di uscita 24,1% su 1.123; tasso di entrata 9,8% su 1.443; 0 su 21.828 | Il netto dipende dal disegno. Dichiarato in A3 §1 come punto cieco. Fuori da A3 uno studio entra solo se altri due arrivano sulla sua chiave: 17 studi a k=2, 0 a k≥3 |
| «perdere 17 meta-analisi su 211» | 38 uscite (31 a k=3, 6 a 4, 1 a 5), 21 nuove (18 a k=3, 2 a 4, 1 a 6) | È un saldo. Oscillazione attorno al gate. Nessuna delle 38 sopravvive sotto altra chiave, nessuna delle 21 c'era sotto altra chiave (`10-out.txt:97`) |
| «40-60 ore» | da 38 a 70, centrale 63 (§5) | Vedi §5 |
| «manda in scadenza la rilettura» | 194 gruppi: 33-43 minuti, 5,3-6,2 M token (finding S3) | Il costo di lettura non è il vincolo (§6) |

Tutti i 993 studi del deliverable stanno in A3 (`10-out.txt:18`), quindi tutti i record usati vengono dal run con `VLLM_BATCH_INVARIANT=1`. Il corpus resta misto, come dichiara A3 §1. Il criterio di ingresso nel sottoinsieme dipende dall'esito del run vecchio.

# 4. Che cosa non sappiamo

1. **Quanti ingressi.** Lo stimatore non regge. Restano fatti senza proiezione: 10 su 1.443 con sole chiavi nuove (0,69%, IC esatto 0,33-1,27). Quei 1.443 studi hanno tutti un gruppo con almeno due studi, quindi il tasso non si trasferisce. 393 gruppi con due studi stanno in 387 entità senza meta-analisi (`10-out.txt:57`).
2. **La ripetibilità dello Stadio 2 con il flag.** Misurata solo sullo Stadio 1 (997 su 997). Il finding del 2026-08-16 lo dichiara. Se tiene, il movimento di A3 è stato il passaggio una tantum dal run senza flag al run con flag. Se non tiene, un secondo run ripete un movimento dello stesso ordine.
3. **Il nodo.** La prova è sempre stata su `poddgx02`.
4. **La correttezza dei nuovi ingressi.** Nessuna di queste misure la vede.

# 5. Il costo, dai tempi registrati

Fonte: `20-sacct.txt`, `21-out.txt`, `20-costo-out.txt`. I due job dello Stadio 2 differiscono solo per il flag (diff di `run_p4.rendered.sh`).

| voce | basso | centrale | alto | base |
|---|---:|---:|---:|---|
| prova di ripetibilità dello Stadio 2 | 2,0 | 2,0 | 2,0 | **stima** |
| Stadio 1 | 8,0 | 8,0 | 14,9 | 9 blocchi A3 in 82,6 min con due blocchi insieme; alto: un blocco alla volta, 17,6 min |
| recupero Stadio 1 | 1,4 | 1,4 | 1,4 | 14,4 min per 86.898 record, in scala |
| Stadio 2 | 22,0 | 47,2 | 47,2 | basso: 15,34 h × 1,43. Centrale: 7,76 h / 0,1645, la quota di caratteri di A3 |
| recupero Stadio 2 | 1,0 | 1,0 | 1,0 | 10,25 min / 0,1645 |
| re-cluster | 2,2 | 2,2 | 2,2 | 133,6 min, 8 processi |
| re-pool e ricomposizione | 1,6 | 1,6 | 1,6 | 71 + 23 min, 16 pezzi |
| **totale, ore di macchina** | **38** | **63** | **70** | |

**L'anomalia del flag.** Il fattore è 1,43 sullo Stadio 1 e 3,08, implicito, sullo Stadio 2. La causa non è misurata: lo Stadio 1 manda lo shard intero, lo Stadio 2 usa `microbatch = 50`, e la scala sui caratteri è un'ipotesi. **Rinviata alla prova**, che misura il tempo. Se il PI risponde no, la domanda non serve.

**La prova:** 38.587 record per 2.000 studi; Stadio 1 0,61 h, recupero 0,11 h; Stadio 2 3,61 h per gli studi fuori, 0,91 h per i 300 già rigenerati, recupero 0,17 h; totale modello 5,4 h; con il re-cluster 7,6 h. Il pooling non serve: l'arrivo si legge sulle chiavi del deliverable. Le chiavi si fermano allo Stadio 3, quindi l'errore dei ruoli (finding S4) non entra.

**Che cosa la prova non vede.** Gruppi che nascono da due studi nuovi insieme, perché il campione è il 9,2% dei 21.828. Effetto delle fusioni a pieno regime. Con 2.000 studi e un tasso vero di 0,3-0,7% si attendono da 6 a 14 arrivi: l'ordine di grandezza c'è, la precisione no.

# 6. Che cosa scade con un sì

| che cosa | con il sì | costo |
|---|---|---|
| rilettura delle 194 | si rileggono le meta-analisi nuove o cambiate | ≤ 43 minuti, ≤ 6,2 M token anche se fossero tutte |
| asimmetria dei critici (69 contro 183) | va corretta prima | già scritta nell'handout, S15 |
| test-retest | 20 gruppi non cambiati | meno di 10 minuti in proporzione, **stima** |
| misure d'influenza, setaccio, inversioni | si rifanno | script esistenti, durata non registrata |
| lettura umana su 19 schede | vale per i gruppi invariati | il PI decide se ripeterla |
| scelta delle 40 e delle 132 | **decade**, finding S5 | una sessione, circa 2 h, **stima** |
| seconda esecuzione della validazione esterna | va dopo il re-run | nessun costo in più: è comunque da fare una volta |
| figure, Methods | si scrivono dopo | nessun costo in più se aspettano |

**Dubbio ricevuto dalla validazione esterna (S7), chiuso.** La seconda esecuzione del test va sull'ultimo deliverable: dopo S13 se la risposta è no, dopo S14 se è sì. Con la prova, S13 può girare prima, perché la correzione resta utile nei due casi. Il test aspetta la risposta.

**Ordine, se è sì.** S13 prima di S14: isola l'effetto delle correzioni da quello del re-run, e la correzione dell'assegnazione dei ruoli è comunque un prerequisito di S14.

# 7. Il paragrafo dei Methods, se la risposta è no

I numeri vanno riletti dopo il calcolo che applica le correzioni.

> **Scope of the model re-run.** The two model-based stages were re-run with batch-invariant inference on a subset frozen before the run: the 2,566 of 24,394 studies (10.5%) that, in the preceding run, either belonged to a contrast group with at least two studies or had been pooled. All 993 studies in the final meta-analyses belong to this subset. The other 21,828 studies kept the labels of the preceding run, which did not use batch-invariant inference. Of these, 4,994 had at least one contrast group, 17 of them in a group of two studies and none in a larger group; 11,175 had comparisons that our rules excluded before grouping; 5,659 had no comparison. None entered a meta-analysis. The corpus is therefore not the output of a single run, and selection into the subset depended on the preceding run: pooled studies could leave, while the remaining studies could hardly enter. After a complete re-run, studies that are isolated today could join existing groups or form new ones. We did not measure how many.

Se la prova viene fatta, l'ultima frase diventa il numero misurato.

# 8. Note tecniche

- Il primo giro di `10-conto.R` si è fermato per un errore di tipo in `data.table`, dopo le stime (`10-out-primo-giro-interrotto.txt`). Il secondo giro usa `mclapply` su 60 processi, con il permesso del PI di salire al 90%. Il seme è 20261104, ma il flusso casuale è diverso. Le stime puntuali coincidono, gli IC cambiano poco: P3 [29,1; 118,4] contro [27,9; 113,9]. Il finding usa il secondo giro.
- Le aggiunte non depositate sono marcate in `10-out.txt` da «AGGIUNTE NON DEPOSITATE».
- Temperatura letta durante il calcolo (`Tctl`): massimo 73,4 °C. Il carico era dovuto soprattutto ad altri processi.

# 9. Da dove vengono i numeri del riassunto

| frase | file e riga | valore letto |
|---|---|---|
| 2.566 su 24.394, 10,5% | `10-out.txt:12`, `:20`; `21-out.txt:1` | 2566; 24394; 0.1052 |
| 21.828 | `10-out.txt:20` | 21828 |
| rapporto 4,4 e 0,22 | `10-out.txt:50-51` | 4.4295; 0.2246 |
| mediana 1,02 su 500 | `30-out.txt:56` | 1.02 |
| 40 arrivi, 19 studi, 20 in uno | `30-out.txt:34` | 40; 19; 20 |
| 271 usciti, 141 entrati, nessuno dai 21.828 | `10-out.txt:53` | 271; 141; 0 |
| 130 ingressi, 0,6% | `10-out.txt:54` | 130; 0.60% |
| 38 uscite, 21 nuove; 31 e 18 a tre studi | `10-out.txt:13`, `:89-96` | 38; 21; 31; 18 |
| 4.994 | `10-out.txt:21` | 4994 |
| 11.175; 5.659 | `10-out.txt:66` | 11175; 5659 |
| 140 studi; 171 su 8.647 | `10-out.txt:26` | 140; 171; 8647 |
| 1.443; 10; 0,7% | `30-out.txt:65` | 1443; 10; 0.69% |
| 38-70, centrale 63 | `20-costo-out.txt:6` | 38; 63; 70 |
| 40-60 ore | handout, §S8 | 40-60 |
| 3 volte, 1,43 | `20-costo-out.txt:3` | 3.08; 1.43 |
| 40 minuti, 6 M token | finding S3, righe 49, 64, 105 | 33-43 min; 5,3-6,2 M |
| 997 su 997 | finding 2026-08-16 | 997/997 |
| 2.000 e 300 studi, circa 8 ore | `20-costo-out.txt:8` | 7.6 h |
| 5% e 25% di 993 | `10-out.txt:14`, `00-previsioni.md` P3 | 993; 50; 250 |
| 15,3 h; 7,8 h; 16,4% | `20-costo-out.txt:2` | 15.34; 7.76; 0.1645 |
| 83 minuti per 86.898 | `20-costo-out.txt:1` | 82.6 |
| 2,2 h con 8 processi | `20-costo-out.txt:5`; `log/recluster-a3.log:103`; finding A3 §5 | 2.2 h; 133.6 min; 8 |
| 5,4 h e 2,2 h | `20-costo-out.txt:8` | 5.4; 7.6 |

[^previsioni]: `analysis/audit/2026-11-04-S8-re-run/00-previsioni.md`.
