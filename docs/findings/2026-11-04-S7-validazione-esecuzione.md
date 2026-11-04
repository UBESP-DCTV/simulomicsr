---
type: Finding
title: "La validazione esterna: le stime riconoscono il composto, il test passa, ma il valore dipende dalla fonte e dai composti"
description: "Esecuzione del disegno congelato sul deliverable di oggi: 14 su 19 e 39 su 53 contro LINCS, 11 su 32 contro Tahoe-100M, controlli sul segno e sull'errore di calcolo. Il numero dell'articolo verrà dalla seconda esecuzione, dopo le correzioni."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-04T21:00:00+01:00'}
sources:
- {id: disegno, resource: "docs/superpowers/specs/2026-11-04-validazione-esterna-design.md", title: "Il disegno congelato"}
- {id: previsioni, resource: "analysis/audit/2026-11-04-S7-validazione-esecuzione/00-previsioni.md", title: "Cancelli, previsioni e scelte tecniche, commit 7125974"}
- {id: passoa, resource: "analysis/audit/2026-11-04-S7-validazione-esecuzione/15-esito-passo-a.md", title: "Esito del passo A, commit cbf8407, prima di ogni stima"}
- {id: errore, resource: "analysis/audit/2026-11-04-S7-validazione-esecuzione/72-ricerca-errore-previsioni.md", title: "Controlli della ricerca di un errore, commit 59f4a0b"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi"}
- {id: lim, resource: "https://doi.org/10.1038/s41598-021-97005-z", title: "Lim e Pavlidis, Sci Rep 2021;11:17624"}
---

# In breve

## In breve: le stime riconoscono il composto in dati che non vengono dal nostro corpus?

**A cosa serviva.** Tutte le verifiche fatte finora usavano gli stessi dati che hanno prodotto le stime. Questa sessione ha eseguito il controllo esterno con le regole che hai approvato. Ogni profilo combinato deve riconoscere il proprio composto fra 5.466 composti di LINCS, una raccolta pubblica di profili di farmaci su linee cellulari. Il riconoscimento riesce se il composto giusto sta nel primo 10%.

**Cosa abbiamo trovato.**

1. **Il test passa nei due insiemi.** Il composto giusto sta nel primo 10% in 14 casi su 19 nell'insieme principale e in 39 casi su 53 nelle altre 132 meta-analisi.
   - La regola chiedeva almeno 9 casi su 19 e 21 su 53. I numeri scritti erano 8 e 16, ma la regola alza la soglia se i composti sbagliati superano il 17%. I composti sbagliati arrivano a 24 e 26 volte su 100.
2. **Il valore di 74 su 100 non è un errore di calcolo, ma dipende dai composti che misuriamo.** La previsione chiedeva di cercare un errore sopra 70 su 100. La formula del disegno, applicata alla lettera, dà gli stessi valori. Con i geni rimescolati il valore scende a 9 su 100. Ho trovato tre cause che alzano il valore:
   - I nostri composti hanno una mediana di 14 linee cellulari, gli altri di LINCS ne hanno 5. Con 5 linee per tutti il valore scende a 64 e 59 su 100.
   - Il confronto con i soli 906 composti studiati in almeno 10 linee dà 63 e 57 su 100. I composti sbagliati scendono allora a 10 su 100, cioè al valore del caso.
   - Nel deliverable entrano composti forti e molto studiati. Anche fra Tahoe-100M e LINCS il riconoscimento vale 64 su 100 per questi composti e 31 su 100 per gli altri.
3. **Contro la seconda fonte indipendente il valore è molto più basso: 11 casi su 32.** Tahoe-100M è un atlante aperto di 379 farmaci, fuori da GEO. Sugli stessi 32 composti, LINCS dà 26 casi su 32. I composti sbagliati arrivano a 13 su 100 contro Tahoe-100M.
   - Tahoe-100M è difficile anche per LINCS, che la riconosce in 18 casi su 32. Le nostre stime restano comunque sotto LINCS.
4. **Il test non separa gli insiemi e non separa i verdetti.** Il valore è 74 su 100 sia per i composti dell'insieme principale sia per quelli delle altre 132. Nelle altre 132 le meta-analisi corrette arrivano a 24 su 33, quelle difettose o incerte a 15 su 20.
   - Il test riconosce l'identità del composto. Non dice se la combinazione funziona meglio dei singoli studi, perché il disegno misura questo solo dopo un fallimento.
   - Quindi questo esito non conferma né smentisce la scelta delle 40 come insieme principale.
5. **Il controllo sul segno vede l'inversione già nota, e i sei tumori trovano il progetto TCGA giusto.** Lo studio invertito nel carcinoma epatocellulare ha correlazione -0,75 con TCGA, e la mediana degli altri studi è +0,67. Tutti i sei tumori mettono al primo posto il proprio progetto fra 16.
   - Due altri studi del carcinoma epatocellulare hanno correlazione vicina a 0, e non conosco la causa. Questo dato non prova un errore.
   - I ligandi, che hanno solo una descrizione, stanno nel primo 10% in 5 casi su 16.

**Cosa devi decidere.**

1. **Come scriviamo il risultato nell'articolo? Consiglio di scrivere insieme il numero di LINCS e quello di Tahoe-100M.** Il numero di LINCS da solo sovrastima quello che le stime sanno fare, perché i nostri composti sono forti e molto studiati. Il testo direbbe: 14 delle 19 meta-analisi misurabili contro LINCS, da 63 a 74 su 100 secondo il trattamento delle linee, e 11 di 32 contro Tahoe-100M. Le altre 21 delle 40 restano dichiarate come non validate.
   - In alternativa scriviamo solo 14 su 19, come dice il disegno, e mettiamo Tahoe-100M in supplementare. Il testo è più semplice, ma un revisore che rifà il confronto con Tahoe-100M trova un valore molto più basso.
   - In alternativa usiamo Tahoe-100M come numero principale. Il valore è il più prudente, ma copre solo 32 composti e il disegno non le assegna un verdetto. Questa scelta nascerebbe dopo aver visto i dati.

**Comunque:**

- rieseguiremo lo stesso codice dopo le correzioni, e il numero dell'articolo sarà il secondo;
- misureremo in quella occasione anche se la combinazione riconosce il composto meglio dei singoli studi, solo come descrizione;
- nessuna correzione guarderà l'esito di una singola meta-analisi: per esempio la metformina sta nell'ultimo 1% dei composti, e non la correggeremo per questo motivo;
- i Methods diranno che il test guarda 978 geni su 21.758, su linee tumorali, e che riconosce soprattutto i composti con una risposta forte in LINCS;
- non cambiamo nessun verdetto e non tocchiamo il risultato depositato.

Appena decidi questo punto, la sessione è chiusa.

# 1. I cancelli

Testo in `00-previsioni.md`[^previsioni]. Il disegno è stato controllato prima del calcolo: è scritto sulle 194 (`40-copertura.R` con `nrow(d) == 194L`, 194 righe in `50-copertura-con-tahoe.csv`), non sulle 214 di v15.

| # | cancello | esito | fonte |
|---|---|---|---|
| 1 | manifesto, inizio e fine; metadati LINCS con la provenienza | **passa**, due volte | `12-cancello-1-inizio.txt`, `12-cancello-1-fine.txt` |
| 2 | 19, 53, 5.466 composti, 36.204 firme | **passa** | `20-firme-out.txt` |
| 3 | almeno 800 landmark, 19 su 19, 53 su 53 | **passa**: minimo 937 | `70-out.txt` |
| 4 | almeno 4 coppie su 5 nel primo 10%; invertita più bassa in tutte | **passa**: 5 su 5, 5 su 5 | `30-out.txt` |
| 5 | `GSE144269` negativa, mediana degli altri positiva | **passa**: -0,753 (landmark -0,808); +0,675 (landmark +0,735) | `69-out.txt` |

Integrità degli scarichi: ETag di S3 per i due `.gctx`, oid LFS per i 1.026 file di Tahoe, md5 di GDC per i 1.386 file di TCGA (`10-scarica-log-lincs.txt`, `12-cancello-1-scarichi.txt`). La copia in `/mnt/micron/simulomicsr-salvataggio` passa il manifesto. Il passo A è stato committato (`cbf8407`) prima di leggere una stima.

# 2. Il verdetto

Regola del disegno, §6: passa se il limite inferiore esatto di `H` supera `T_eff` e il limite inferiore bootstrap di `H - H_scambio` supera 0. Unità la meta-analisi, B = 2000, seme 20261104.

| insieme | successi | `H` | IC95 esatto | `H_scambio` | IC95 | `T_eff` | successi minimi | `H - H_scambio` | IC95 | mediana `P_e` | esito |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 19, nelle 40 | 14 | 73,7% | [48,8; 90,9] | 23,9% | [19,2; 28,4] | 23,9% | 9 | 49,8 | [28,0; 69,1] | 0,993 | **passa** |
| 53, nelle 132 | 39 | 73,6% | [59,7; 84,7] | 26,4% | [23,7; 29,1] | 26,4% | 21 | 47,2 | [34,3; 59,0] | 0,985 | **passa** |

Il disegno §6 scrive 8 e 16 successi con T = 17%. Il valore misurato dei composti sbagliati supera il 17%, quindi `T_eff` sale come prevede il disegno. Il ricalcolo indipendente dai file `70-P-per-metanalisi.csv` e `70-coppie-scambio.csv` dà gli stessi 14, 39, 0,2388, 0,2639. Le coppie sbagliate sono 6.320, e 108 escono per un `moa` o un `pert_id` in comune. Ogni `P_e` sta in `70-P-per-metanalisi.csv`.

Le prove discriminanti di §9 non sono state eseguite, perché il verdetto delle 19 passa.

**Sensibilità (§7, punto 8).**

| sensibilità | 19 | `H` | 53 | `H` |
|---|---:|---:|---:|---:|
| primaria | 14 su 19 | 73,7% | 39 su 53 | 73,6% |
| solo InChIKey completo | 13 su 17 | 76,5% | 35 su 46 | 76,1% |
| senza `17β-estradiol`, l'unica lettera greca | 14 su 18 | 77,8% | 39 su 53 | 73,6% |
| `qc_pass == 1` | 13 su 18 | 72,2% | 36 su 52 | 69,2% |
| molecole doppie unite | 14 su 19 | 73,7% | 37 su 50 | 74,0% |

**Verdetti della rilettura (§7, punto 10).** Nelle 53: corrette 24 su 33 (72,7%, [54,5; 86,7]), difettose o incerte 15 su 20 (75,0%, [50,9; 91,3]). Le 19 hanno tutte il verdetto corretta. Il test non separa i due gruppi. Con 20 e 33 unità non può vedere una differenza piccola.

# 3. Le previsioni

| quantità | attesa | intervallo | valore | esito |
|---|---:|---:|---:|---|
| `H` nelle 19 | 40% | [17%; 70%] | 73,7% [48,8; 90,9] | **indeterminata**, a cavallo di 70%, tocca una conclusione: §4 |
| `H` nelle 53 | 30% | [17%; 70%] | 73,6% [59,7; 84,7] | **indeterminata**, a cavallo di 70%, tocca una conclusione: §4 |
| `H_scambio` | 15% | [10%; 25%] | 23,9% [19,2; 28,4] e 26,4% [23,7; 29,1] | **indeterminata**, a cavallo di 25% |
| `H_metà` | 70% | [50%; 83%] | 82,5% [75,2; 88,9] | indeterminata, a cavallo di 83%; non tocca una conclusione |
| `H_fonti` | 30% | [17%; 50%] | 37,3% [29,4; 45,8], 53 su 142 | confermata |
| mediana di `P_e` nelle 19 | 0,80 | [0,71; 0,95] | 0,993 [0,9497; 0,9996] | **indeterminata**, quasi tutta sopra 0,95: §4 |

**`H_scambio` (spiegato).** Il margine diceva: sopra 25% la risposta generica pesa più della differenza che vogliamo vedere. La differenza misurata vale 47-50 punti, quindi il timore non si è avverato. Il valore alto alza `T_eff`, e il verdetto non cambia. §4 ne spiega la causa.

**`H_metà` (spiegato).** La condizione sulla fonte scatta sotto 50%. Il riferimento di 83% viene da una stessa condizione, invece qui si confronta una media di linee. Il valore riguarda 80 composti scelti dal deliverable.

# 4. La ricerca di un errore

Il margine delle previsioni chiede di cercare un errore se `H` supera 70%. I controlli sono stati depositati prima del calcolo[^errore]. Non cambiano il verdetto.

**Non ho trovato errori di calcolo.**

| # | controllo | atteso | valore | esito |
|---|---|---:|---:|---|
| E1 | `rango()` del disegno alla lettera sui 72 | differenza < 1e-9 | 0 | passa |
| E2 | firma dell'entità contro colonna del fondo, 70 entità | uguali | differenza 0 | passa |
| E3 | 99 rimescolamenti dei geni sui 72 | 10% in [7%; 13%] | 8,7% (da 2,8% a 15,3%), mediana `P` 0,496 | passa |

**Ho trovato tre cause che alzano il valore: sono limiti, non errori.** Le stime vengono da `73-riassunto.csv`, bootstrap sulle meta-analisi.

| # | controllo | `H`, 19 | `H`, 53 | `H_scambio`, 19 | `H_scambio`, 53 | differenza, 19 | differenza, 53 |
|---|---|---:|---:|---:|---:|---:|---:|
| | primaria | 73,7 | 73,6 | 23,9 | 26,4 | 49,8 | 47,2 |
| E4 | firme su 5 linee a caso, 20 estrazioni | 63,9 [42,9; 84,0] | 59,3 [47,5; 70,6] | 15,8 [13,6; 18,1] | 17,7 [16,5; 18,9] | 48,2 | 41,6 |
| E5 | fondo con almeno 10 linee, 906 composti | 63,2 [42,1; 84,2] | 56,6 [43,4; 69,8] | 9,4 [7,3; 11,6] | 10,1 [9,3; 10,9] | 53,8 | 46,5 |
| E6 | senza la prima componente del fondo (22,4% della varianza) | 89,5 [73,7; 100] | 69,8 [56,6; 81,1] | 19,0 [16,2; 22,0] | 21,1 [19,3; 22,8] | 70,5 | 48,7 |
| non depositato | fondo dei farmaci di Tahoe, 185 `pert_id` | 63,2 [42,1; 84,2] | 62,3 [49,1; 75,5] | 14,9 [12,5; 17,1] | 14,5 [13,3; 15,7] | 48,3 | 47,8 |

Nessun controllo scende sotto la condizione di limite depositata, cioè `H` sotto 17% o sotto `H_scambio`. Rispetto agli intervalli depositati, `H` di E4 ed E5 è a cavallo di 74%, `H_scambio` di E4 ed E6 è confermato, `H` delle 19 in E6 è a cavallo di 74%.

1. **Numero di linee.** La mediana è 14 linee per le entità e 5 nel fondo (`72-out.txt`). Una firma con più linee ha meno rumore, quindi sale di rango per qualunque interrogazione strutturata. Fra i composti sbagliati la quota di successi cresce con le linee: Spearman 0,419 [0,224; 0,602]. Il controllo `T_eff` copre questo effetto.
2. **Selezione.** E7: fra Tahoe e LINCS, `H_fonti` è 64,3% (18 su 28) sui composti del deliverable e 30,7% (35 su 114) sugli altri. Il deposito scriveva 34 e 108: dei 34 composti agganciati a Tahoe, 28 stanno fra i 142 per nome normalizzato, gli altri 6 hanno in Tahoe un nome diverso da LINCS (per esempio `Rapamycin`). Questo spiega quasi tutto il divario fra il 74% delle stime e il 37% complessivo.
3. **Forza del composto.** E8: `P_e` cresce con il `tas` mediano, Spearman 0,515 [0,301; 0,682], a cavallo della soglia di 0,5. Con le linee vale 0,197 [-0,038; 0,417]. Il test riconosce soprattutto i composti con una risposta forte in LINCS.

**La risposta generica non produce i successi.** Togliere la prima componente del fondo alza `H` nelle 19 da 73,7% a 89,5%, e abbassa `H_scambio`. Le coppie di E5 scendono a 9,4 e 10,1: con un fondo ben misurato un composto sbagliato torna al valore del caso, mentre quello giusto resta sopra il 56%.

# 5. La seconda fonte

Tahoe non ha un verdetto nel disegno: serve per la prova sulla fonte. La riporto perché il divario apre un dubbio. Sugli stessi composti (`74-out.txt`):

| confronto, stessi composti | n | successi | `H` | IC95 esatto | mediana `P` |
|---|---:|---:|---:|---:|---:|
| stime contro L1000 | 32 | 26 | 81,2% | [63,6; 92,8] | 0,991 |
| stime contro L1000, fondo dei farmaci di Tahoe | 32 | 22 | 68,8% | [50,0; 83,9] | 0,967 |
| Tahoe contro L1000 | 26 | 16 | 61,5% | [40,6; 79,8] | 0,968 |
| L1000 contro Tahoe | 32 | 18 | 56,2% | [37,7; 73,6] | 0,915 |
| stime contro Tahoe | 32 | 11 | 34,4% | [18,6; 53,2] | 0,729 |

Stime contro Tahoe, per insieme: 3 su 8 e 8 su 24, uguali sui landmark e su tutti i geni (`71-out.txt`). `H_scambio` contro Tahoe vale 12,8% (13,8% e 12,4% per insieme, `74-out.txt`). L'accordo fra i due ranghi è 0,403.

**Il dubbio è spiegato in parte.** Il fondo non basta a spiegare il divario, perché con lo stesso fondo L1000 dà 22 su 32. Tahoe come bersaglio è più difficile anche per L1000 (18 su 32). Le stime stanno comunque sotto L1000 nel riconoscere Tahoe: differenza 21,9 punti [6,2; 37,5] (`75-out.txt`). La causa di questo scarto non è misurata. Una spiegazione possibile è il contesto: L1000 e Tahoe usano linee tumorali, le stime mescolano contesti diversi. **Resta come limite dichiarato**, e il PI decide come scriverlo.

# 6. Le descrizioni

**Tumori (§7, punto 9).** TCGA ha 711 normali nei 16 progetti, e 693 hanno il tumore della stessa persona. `TCGA-READ` ha 9 coppie (`60-tcga-out.txt`). Tutti i 6 tumori mettono al primo posto il proprio progetto fra 16, su tutti i geni e sui landmark. Le correlazioni con il progetto giusto vanno da 0,415 a 0,716 (`71-tumori.csv`). Il carcinoma epatocellulare contiene ancora lo studio invertito.

**Ligandi.** 5 su 16 nel primo 10%, mediana 0,788, fondo 164 (`71-ligandi.csv`). `IFNB1` sta a 0,043, con 7 studi.

# 7. I dubbi, e come sono chiusi

- **Due studi del carcinoma epatocellulare con correlazione vicina a 0** (`GSE256235` -0,009, `GSE120663` +0,032, `69-out.txt`). Rinviato alla sessione che applica le correzioni (S13), con la regola di separazione: questo esito non può scegliere una correzione.
- **Valori molto bassi.** `metformin` 0,009 con 9 studi, `nicotinamide` 0,099, `17β-estradiol` 0,291 con 9 studi, `enzalutamide` 0,569 con 18 studi. Nessuna correzione può nascere da qui (disegno §2). Una causa possibile per gli ormoni è la scarsità in LINCS di linee con una risposta forte, che non ho misurato.
- **La combinazione contro i singoli studi.** Il disegno la misura solo dopo un fallimento. Un successo può descrivere bene uno studio dominante (disegno §12). Rinviato alla seconda esecuzione, come descrizione.
- **Il test non separa le 40 dalle altre 132.** Il confronto con studi non collegati le separa (3,04 e 1,19 volte, S5). I due controlli misurano cose diverse. La scelta del PI non decade: le sue condizioni riguardano i verdetti.

# 8. Le decisioni tecniche e le correzioni di strumento

- **Scarico a pezzi.** Durante lo scarico di Tahoe una connessione da S3 andava a circa 100 KB/s. Lo script scarica a pezzi da 64 MiB con 24 connessioni, poi controlla l'ETag.
- **Lettura del `.gctx`.** Una selezione su 978 righe non contigue per molte colonne si bloccava. Lo script legge colonne intere e poi i landmark: 23 secondi.
- **Nome `trichostatin A`.** In LINCS sta in `compound_aliases`, con `cmap_name` uguale al `pert_id`. La scelta 4 di `00-previsioni.md` lo copre, e l'aggancio unisce `BRD-K68202742` e `BRD-A19037878`.
- **Fondo dei ligandi.** Il disegno conta 164 nomi esatti, con `TGFA` e `TGFa` distinti. Un primo calcolo li univa e ha dato 163: il cancello ha fermato lo script.
- **Tre errori di script, trovati e corretti prima del finding.**
  - In `72-ricerca-errore.R` il parametro `k` dell'aiutante coincideva con la colonna `k`: E5 ed E6 avevano n = 0. `73-ricerca-parte-2.R` li rifà. Le righe E5 ed E6 di `72-out.txt` non valgono.
  - In `71-tahoe-e-descrizioni.R` `cluster_id[i]` dentro `g[...]` era la colonna di `g`: tutti i 16 ligandi usavano la stessa interrogazione. Il valore sbagliato era 3 su 16. Lo script ora verifica che le interrogazioni siano distinte.
  - In `74-triangolo-fonti.R` `drug[i]` dentro `hf[...]` era la colonna di `hf`: ha dato 32 su 32, un valore che E7 smentiva. Ho cercato lo stesso schema negli altri script di questa sessione e non l'ho trovato. Il verdetto è confermato da E1 e dal ricalcolo indipendente.
- **Tempi.** Il calcolo è durato meno delle 6 ore stimate. Scarichi: 41 minuti. Firme di Tahoe: 1,07 ore, in parte in parallelo.

# 9. Che cosa questa misura non dimostra

Vale §12 del disegno: nessuna informazione su circa metà del deliverable, 978 geni su 21.758, linee tumorali, verdetto per l'insieme e non per la meta-analisi, nessuna assoluzione per le meta-analisi dominate. In più: il test riconosce soprattutto i composti forti e molto studiati, e questa è la prima esecuzione. Il numero dell'articolo verrà dalla seconda.

# Da dove vengono i numeri del riassunto

Cartella: `analysis/audit/2026-11-04-S7-validazione-esecuzione/`.

| frase | file | valore |
|---|---|---|
| 5.466 composti | `20-firme-out.txt` | «composti del fondo: 5466» |
| 14 su 19, 39 su 53 | `70-verdetto.csv`, `70-out.txt` | `successi` |
| almeno 9 e 21; 8 e 16 | `75-out.txt` | «successi minimi 9», «21»; «con T = 17%: 8», «16» |
| 24 e 26 su 100 | `70-verdetto.csv` | `H_scambio` 0,239 e 0,264 |
| 74 su 100 | `70-verdetto.csv` | `H` 0,737 e 0,736 |
| 9 su 100 con i geni rimescolati | `72-out.txt` | «E3: media 0.087» |
| 14 e 5 linee | `72-out.txt` | «mediana 5 ; entita', mediana 14» |
| 64 e 59 su 100 con 5 linee | `73-riassunto.csv`, riga E4 | 0,639 e 0,593 |
| 906 composti; 63 e 57 su 100; 10 su 100 | `73-out.txt`, `73-riassunto.csv`, riga E5 | 906; 0,632 e 0,566; 0,094 e 0,101 |
| 64 e 31 su 100 | `72-e7.csv` | 18 su 28, 35 su 114 |
| 379 farmaci; 11 su 32; 26 su 32; 18 su 32 | `50-tahoe-firme-out.txt`, `74-triangolo.csv` | 379; 11; 26; 18 |
| 13 su 100 contro Tahoe | `74-out.txt` | «tutti e due gli insiemi: 0.128» |
| 24 su 33, 15 su 20 | `70-verdetti-rilettura.csv` | righe 132 |
| -0,75, +0,67 | `69-out.txt` | «r = -0.753», «0.675» |
| correlazione vicina a 0 | `69-cancello-5.csv` | -0,009 e +0,032 |
| 6 tumori, 16 progetti | `71-tumori.csv` | `P_16` = 1 in tutte le righe |
| 5 su 16 | `75-out.txt` | «ligandi nel primo 10%: 5 su 16» |
| da 63 a 74 su 100 | `73-riassunto.csv`, righe delle 19 | 0,632 (E5) e 0,737 (primaria), senza E6 |
| altre 21 delle 40 | disegno §10 | 40 - 19 |
| metformina, ultimo 1% | `70-P-per-metanalisi.csv` | 0,009 |
| 978 geni su 21.758 | disegno §12 | |

[^previsioni]: `analysis/audit/2026-11-04-S7-validazione-esecuzione/00-previsioni.md`, commit `7125974`.
[^errore]: `analysis/audit/2026-11-04-S7-validazione-esecuzione/72-ricerca-errore-previsioni.md`, commit `59f4a0b`.
