# Validazione esterna: il disegno (S6)

**Scritto:** 2026-11-04. **Esegue:** la sessione S7. **Stato:** congelato il 2026-11-04, con le scelte del PI segnate con ⚑.
S7 lo esegue e non lo cambia. Se il disegno è sbagliato, S7 si ferma e si rifà S6.

I numeri stanno in `docs/findings/2026-11-04-S6-validazione-disegno.md` e in
`analysis/audit/2026-11-04-S6-validazione-disegno/`. Il seme è 20261104. L'unità è la meta-analisi.
`Rscript` si lancia senza `--vanilla`.

## 1. La domanda

Una meta-analisi dice di descrivere l'effetto di un composto. Il profilo combinato riconosce quel composto fra
migliaia di altri, in dati prodotti da altri, su un'altra piattaforma? Tutte le verifiche fatte finora guardano
dentro il corpus che ha prodotto le stime.

## 2. Gli oggetti

| oggetto | dove |
|---|---|
| Deliverable | `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`, `cluster_pooled.parquet` |
| Stime per studio dopo il collasso dei bracci | `/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/studio/<cluster_id>.rds` |
| Insieme principale e supplementare | `analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv`, `80-insieme-172.csv` (172 = 40 + 132) |
| Aggancio, classe e misurabilità di ogni meta-analisi | `analysis/audit/2026-11-04-S6-validazione-disegno/50-copertura-con-tahoe.csv`, `40-aggancio-con-elenco.csv` |
| Metadati LINCS | `/mnt/wwn-0x5000039d58caca35/lincs-meta/`, SHA-256 in `analysis/audit/2026-08-08-validazione-esterna/provenienza-file-scaricati.csv` |

⚑ **Il momento, scelta del PI.** S7 misura adesso il deliverable su disco, poi lo stesso codice si riesegue dopo
il calcolo che applica le correzioni. Il numero dell'articolo è il secondo. Il primo resta in supplementare. Le
correzioni già decise per gli errori noti non toccano l'insieme primario (§4): su quell'insieme agisce solo la varianza del
controllo condiviso. Il rilevatore di difetti può aggiungere altre correzioni: il secondo calcolo le include.

**Regola di separazione.** Nessuna correzione di S9-S13 può scegliere che cosa correggere guardando l'esito di S7 per
una meta-analisi. Una meta-analisi corretta per quel motivo si marca come `a_posteriori` ed esce dal calcolo primario.

## 3. Le fonti

⚑ **Scelta del PI:** le righe 1, 1b, 2 e 3, ognuna nel ruolo scritto.

| # | fonte | ruolo | copertura misurata (40 / 132 / altre 22) | circolarità | scarico |
|---|---|---|---|---|---|
| 1 | LINCS L1000, composti (`trt_cp`) | **verdetto** | 19 / 53 / 8 misurabili | 0 studi in comune | 35,5 GB |
| 1b | LINCS L1000, ligandi (`trt_lig`) | descrizione, senza verdetto | 5 / 9 / 2 misurabili | come sopra | 0,4 GB |
| 2 | Tahoe-100M (`pseudobulk_differential_expression`) | seconda fonte, prova sulla fonte | 8 / 24 / 2, tutte già misurabili in LINCS | fuori da GEO, licenza CC0 | 88,9 GB |
| 3 | TCGA, tumore contro normale appaiati | controllo positivo sul segno, descrizione | 0 / 5 / 1 | 0 studi che citano TCGA nei 6 gruppi | circa 6 GB |

Fonti scartate, con il motivo:

- **CREEDS, RummaGEO, Expression Atlas, Enrichr:** sono costruite da GEO. Non sono esterne.
- **PANACEA (`GSE186341`):** sta già dentro le 194. **sci-Plex (`GSE139944`):** sta nel bacino ARCHS4, e non offre i confronti già calcolati.
- **Genetica di malattia (Open Targets, GWAS):** non ha verso. Un gene di malattia può non cambiare espressione, quindi un disaccordo non è un fallimento.
- **Coorti ad accesso controllato (AMP-PD, PsychENCODE):** richiedono un accordo d'uso. Coprirebbero Parkinson e disturbo bipolare nelle 40, secondo quello che so. Non l'ho misurato.
- **`trt_sh`, `trt_xpr`, `trt_oe`:** le meta-analisi genetiche sono 2 su 194 e nessuna entra nell'insieme principale.

**Il soffitto.** La misura vale per 96 meta-analisi su 194 (49,5%): 24 su 40, 62 su 132. Le altre restano non validate:
45 malattie (6 tumori hanno soltanto la descrizione con TCGA), 8 patogeni, 5 ambientali, 5 biologici, 2 genetiche e
i composti senza firma misurabile. **Nelle 40 restano non validate 16:** 8 malattie, Zika, `bleomycin A2`, `dimethyloxalylglycine`,
`calcium atom`, `MIVEBRESIB`, `ykl 5 124`, `GSK126`, `IL13`. L'articolo lo dichiara in una colonna per ogni meta-analisi.

## 4. L'insieme primario

**Regola di misurabilità**, scritta sulla sola fonte e fissata prima di ogni confronto: il composto ha firme `exemplar`
con `tas >= 0,2` in almeno 3 linee cellulari. Il valore 0,2 è circa il quartile superiore di `tas` nei composti (0,193, misurato).
Una meta-analisi che passa questa regola non può più accusare la fonte di non vedere il suo composto.

- **Primario:** i 19 composti misurabili nelle 40.
- **Secondario, con verdetto proprio:** i 53 composti misurabili nelle 132.
- **Descrizione:** gli 8 composti misurabili fuori dai due insiemi, i 16 ligandi misurabili, i 6 tumori.

Le molecole doppie (`atra` e `all-trans-retinoic acid`, `nutlin 3a` e `Nutlin-3`, `1 25 oh 2d3` e `calcitriol`) restano
unità distinte. Una sensibilità le unisce. Se l'insieme cambia dopo le correzioni, la stessa regola lo rigenera.

**Difetti noti e insieme primario.** I tre bracci con i ruoli sbagliati stanno in `R1881`, Parkinson ed endometriosi. L'inversione
sta nel carcinoma epatocellulare. I quattro studi con un braccio sbagliato stanno in epatite B, `vtp50469`, LPS e Parkinson. Gli studi
doppi con effetto stanno in psoriasi, `bleomycin A2`, `sirna pool against igf2bp1` e `R1881`. Nessuno di questi gruppi è misurabile in LINCS.

## 5. La statistica

**Interrogazione.** Per la meta-analisi `e`, su ogni gene landmark presente: `q_e[g] = logFC_pool[g] / SE_pool[g]`. I landmark sono 978:
`feature_space == "landmark"` in `geneinfo_beta.txt`, `ensembl_id` contro `gene_id` senza versione. I geni inferiti non entrano.

**Firma di un composto.** File `level5_beta_trt_cp_n720216x12328.gctx`. Si prendono le firme con `is_exemplar_sig == 1` e `tas >= 0,2`.
Si fa la media delle `z` dentro la linea cellulare, poi la media fra le linee. `qc_pass` non filtra: una sensibilità lo applica.
Se l'entità ha più `pert_id`, le firme si uniscono.

**Fondo.** I 5.466 composti che passano la stessa regola di misurabilità, con la stessa firma, tolti i `pert_id` dell'entità.

**Rango.** `sim(e, c)` è la correlazione di Spearman fra `q_e` e la firma di `c` sui geni in comune. `P_e` è la quota dei composti del
fondo con `sim` minore di quella del composto giusto. **Un successo è `P_e >= 0,90`:** il composto giusto sta nel primo 10% del fondo.

**Statistica primaria.** `H` è la quota di successi. Intervallo esatto di Clopper-Pearson al 95%.
**Secondaria.** La mediana di `P_e`, bootstrap sulle meta-analisi con B = 2000.

```r
# definizione di riferimento per una meta-analisi e un composto
rango <- function(q, firme, giusto) {          # firme: matrice geni x composti, stesse righe di q
  s <- cor(q, firme, method = "spearman", use = "pairwise.complete.obs")[1, ]
  mean(s[setdiff(colnames(firme), giusto)] < mean(s[giusto]))
}
```

## 6. Il puro caso e le soglie

**Valore teorico.** Il 10% dei composti giusti cade nel primo 10% per puro caso: circa 2 su 19. La mediana di `P_e` vale 0,50, con intervallo
95% da 0,29 a 0,71 su 19 meta-analisi e da 0,37 a 0,63 su 53 (20.000 estrazioni, `60-out.txt`).

**Valore misurato.** Una risposta generica può alzare il caso: un composto forte può salire in cima a molte interrogazioni. S7 misura quindi `H_scambio`.
È la stessa statistica con un composto sbagliato preso fra gli 80 misurabili del deliverable, su tutte le coppie, tolte le coppie con un `moa` in comune.
`T_eff = max(T, H_scambio)`. Nessun altro aggiustamento è ammesso.

**Riferimenti dalla letteratura** (Lim e Pavlidis, Sci Rep 2021, 11:17624, stesso criterio del primo 10%): CMap 1 interroga CMap 2, 17% (99 su 588);
CMap 2 interroga se stesso, 83% (486 su 588). La loro interrogazione è una sola condizione. La nostra è una media di più studi contro una media di più linee.

⚑ **Scelta del PI: la riga B, T = 17%.** Passa se il limite inferiore esatto di `H` supera `T_eff`, e se il limite inferiore bootstrap di `H - H_scambio` supera 0.

| | T | serve nelle 19 | serve nelle 53 | che cosa vuol dire se passa | probabilità di passare nelle 19, se la quota vera è 25% / 35% / 50% / 70% |
|---|---:|---:|---:|---|---:|
| A | 10% | 6 | 11 | Le stime contengono l'identità del composto più del caso. Non dice quanto bene. | 33% / 70% / 97% / 100% |
| **B, scelta** | 17% | 8 | 16 | Le stime riconoscono il composto meglio di quanto due edizioni di CMap si riconoscono fra loro. | 8% / 33% / 82% / 100% |
| C | 30% | 11 | 24 | Più di metà dei composti sta nel primo 10%. Con 19 unità il test è severo anche con una quota vera buona. | 0% / 4% / 32% / 92% |

La soglia e il verdetto delle 53 sono indipendenti da quelli delle 19. Il verdetto principale è quello delle 19.

## 7. L'ordine di esecuzione in S7

**Passo A, solo fonti.** Non si legge nessuna stima del deliverable. Il risultato si committa prima del passo B.

1. Verificare il manifesto del deliverable. Scaricare i file nell'ordine di §3, in `/mnt/wwn-0x5000039d58caca35/lincs-meta/level5/` con `curl -C -`. Scrivere gli SHA-256.
2. Costruire le firme del fondo. Sono 36.204 firme su 5.466 composti. Il nome delle righe è l'Entrez `gene_id` di `geneinfo_beta.txt`.
3. **Controllo positivo su L1000.** Il primo composto interroga il secondo, sul fondo, per queste 5 coppie: `romidepsin` e `trichostatin A`, `romidepsin` e `vorinostat`, `trichostatin A` e `vorinostat`, `bortezomib` e `carfilzomib`, `thapsigargin` e `tunicamycin`.
4. **Soffitto della fonte (`H_metà`).** Per ogni composto degli 80, le linee si dividono a caso in due metà (20 divisioni). La metà 1 interroga le metà 2 di tutto il fondo. `H_metà` è la quota media di successi.
5. **Accordo fra le fonti (`H_fonti`).** Tahoe, per ogni farmaco: la concentrazione più alta, la media di `stat` fra le linee, sui landmark per `gene_name`. I 142 farmaci con una firma LINCS misurabile, per nome normalizzato, interrogano LINCS sul fondo.
6. **TCGA.** `limma-voom` con `~ paziente + tipo` sulle coppie tumore-normale dei 16 progetti con almeno 10 normali (711 normali, conte `STAR - Counts`).

**Passo B, deliverable.**

7. Calcolare `H`, `H_scambio`, `T_eff` e il verdetto per le 19 e le 53. Stampare ogni `P_e` nella tabella.
8. Eseguire la sensibilità: solo InChIKey completo (71 composti su 80), `qc_pass == 1`, molecole doppie unite, 978 landmark contro tutti i geni su Tahoe.
9. Descrivere ligandi (fondo: 164 ligandi misurabili) e tumori (fondo: 16 progetti).
10. Controllare i verdetti della rilettura: `H` fra le corrette (33) e fra difettose e incerte (20) nelle 53.
11. Se il verdetto delle 19 non passa, eseguire §9.

## 8. Cancelli e previsioni di S7

**Cancelli.** Se uno fallisce, S7 si ferma.

1. Il manifesto del deliverable passa all'inizio e alla fine. Gli SHA-256 dei metadati LINCS coincidono con la provenienza.
2. S7 riottiene le stesse conte del finding S6: 19, 53, 5.466 composti, 36.204 firme.
3. Ogni composto dell'insieme ha almeno 800 landmark e `H` copre 19 su 19 e 53 su 53.
4. **Controllo positivo L1000:** almeno 4 coppie su 5 hanno il secondo composto nel primo 10%. La query invertita di segno deve abbassare `P_e` in tutte le coppie.
5. **Controllo positivo sul segno:** nel carcinoma epatocellulare, `GSE144269` (inversione nota) ha correlazione negativa con TCGA-LIHC. La mediana degli altri studi del gruppo è positiva.

**Previsioni.** Sono giudizi miei, tranne dove è indicata la fonte. S7 le copia senza cambiarle nel proprio `00-previsioni.md`.

| quantità | attesa | intervallo di rilevanza | origine del margine |
|---|---:|---:|---|
| `H` nelle 19 | 40% | [17%; 70%] | 17% è il riferimento; sopra 70% il valore supera quanto mi aspetto dal soffitto e va cercato un errore |
| `H` nelle 53 | 30% | [17%; 70%] | stesso motivo; queste meta-analisi sono dominate o contengono difetti |
| `H_scambio` | 15% | [10%; 25%] | sopra 25% la risposta generica pesa più della differenza che vogliamo vedere |
| `H_metà` | 70% | [50%; 83%] | 83% è il soffitto di letteratura su una stessa condizione; sotto 50% la fonte non vede se stessa |
| `H_fonti` | 30% | [17%; 50%] | 17% è il riferimento fra piattaforme |
| mediana di `P_e` nelle 19 | 0,80 | [0,71; 0,95] | 0,71 è il limite del caso su 19 |

## 9. Se il verdetto non passa: la prova che distingue le spiegazioni

Una fonte o un'identità non si invocano: **si dimostrano con queste prove, nell'ordine.** Se nessuna è dimostrata, la spiegazione è il metodo.

**È la fonte**, se vale almeno una condizione:

- `H_metà < 50%`: la fonte non vede se stessa.
- `H_fonti <= T_eff`: due fonti indipendenti non raggiungono la soglia fra loro, quindi la soglia non è raggiungibile per noi.
- Sui composti in comune con Tahoe (8 nelle 19, 24 nelle 53), il limite inferiore di `H` contro Tahoe supera `T_eff`, mentre lo stesso `H` contro L1000 non lo supera.

**È l'identità**, se valgono entrambe le condizioni:

- nelle 72 meta-analisi, sui composti con verdetto corretta e InChIKey completo, il limite inferiore di `H` supera `T_eff`;
- `H` delle restanti è più basso, con differenza bootstrap tutta sotto 0.

I verdetti della rilettura esistono già e sono stati scritti senza LINCS. **Le 19 hanno tutte il verdetto corretta.** Se il fallimento resta nelle 19 con InChIKey completo,
l'identità è esclusa, salvo un errore nell'aggancio. Un errore nell'aggancio si dimostra mostrando struttura e nome dalle fonti, prima di ricalcolare.
La sessione sulle lettere greche (S9) non è ancora fatta, quindi un'etichetta con una lettera greca resta esposta: S7 riporta `H` con e senza i composti elencati in `65-out.txt`. I ligandi non entrano nel verdetto, anche per questo motivo.

**È il metodo**, in tutti gli altri casi. Due prove dicono dove:

- **Combinazione.** Per ogni meta-analisi `d_e = P_e - mediana(P_e per studio)`. Se l'intervallo bootstrap della media è tutto sotto 0, la combinazione peggiora i singoli studi.
- **Contesto.** Per gli studi che citano una linea con una firma attiva (11 su 19, 38 su 53, limite superiore), lo studio interroga la firma in quella linea. Se questi passano la soglia e la meta-analisi no, il problema sta nella miscela di contesti. Se non passano, sta a monte: confronti scelti o dati.

## 10. La via d'uscita

⚑ **Scelta del PI: l'opzione 1**, se S7 fallisce e la prova dice «è il metodo». Il PI conferma dopo aver letto il finding di S7. Nessuna correzione parte prima.

| | che cosa resta | conseguenza |
|---|---|---|
| **1, scelta** | L'articolo tiene la catena, il catalogo dei confronti, le verifiche e i limiti. Il fallimento è un risultato dichiarato. Le stime restano in supplementare come ipotesi, senza la parola «validate». | Si pubblica un risultato onesto. La promessa sulle stime cade. |
| 2 | Si corregge il metodo e si rifà tutto, poi una nuova validazione su una fonte non ancora vista. | Costa settimane. LINCS e Tahoe sono già visti: serve una terza fonte, e oggi non è individuata. |
| 3 | Si ferma l'articolo. | Si salva il lavoro futuro. Si perde il lavoro fatto. |

**Negli altri esiti.**

- **Passa:** l'articolo scrive il numero con il denominatore, «19 delle 40», e dichiara le altre 21 come non validate. Il valore non vale per la singola meta-analisi.
- **È la fonte:** l'articolo dichiara la validazione non conclusiva. Non scrive «validata».
- **È l'identità:** le correzioni si applicano con una regola scritta prima. Il calcolo si ripete con la stessa soglia. Il primo fallimento resta nel supplementare.
- **Le 19 passano e le 53 no:** la frase vale per le 19. Le altre 132 restano in supplementare con questo avviso.
- **Le 19 non passano e le 53 sì:** il verdetto principale è il fallimento. Si esegue comunque §9.

## 11. Il confronto con studi non collegati

Entra nell'articolo per scelta del PI (2026-11-04). È un controllo **interno**: non sostituisce la validazione esterna.

- **Quando:** dopo il calcolo delle correzioni, su tutti i gruppi. Riceve il rinvio la sezione S13 dell'handout.
- **Che cosa:** lo schema di `analysis/audit/2026-11-03-S5-gate-e-insiemi/74-nullo-appaiato.R`, senza il ricalcolo senza lo studio dominante, che non serviva. Ogni gruppo ha B estrazioni.
- **Regola per gruppo:** il valore empirico è (1 + estrazioni con almeno tanti geni significativi) / (B + 1). Si corregge con Benjamini-Hochberg sui gruppi. Il gruppo passa con FDR < 0,05 e rapporto mediano almeno 1,5.
- **Regola per insieme:** il limite inferiore del rapporto mediano supera 1,5, come in S5.
- **Limite dichiarato:** una risposta generica condivisa alza il nullo, quindi il controllo può non vedere un effetto vero.

⚑ **Scelta del PI: 99 estrazioni.** Il tempo misurato è 15,1 minuti per 137 gruppi. La testata dello script indica 32 processori, e il numero effettivo non è registrato. Su 193 gruppi diventa 21 minuti per estrazione al massimo.

| | B | tempo al massimo | valore empirico minimo | conseguenza |
|---|---:|---:|---:|---|
| **scelta** | 99 | 35 h | 0,01 | Il verdetto per gruppo regge la correzione per molti test. |
| | 19 | 7 h | 0,05 | Il verdetto per gruppo non regge la correzione: vale solo l'insieme. |

## 12. Che cosa questa validazione non dimostra

- Non dice nulla su circa metà del deliverable: tutte le malattie, i patogeni, gli ambientali (§3).
- Guarda 978 geni su 21.758 (4,5%). Non verifica la grandezza dell'effetto né la lista dei geni significativi.
- Confronta il profilo con linee cellulari tumorali, a dosi e tempi diversi. Un fallimento può nascere dal contesto, un successo può nascere da una risposta condivisa da quella classe di composti.
- Il verdetto vale per l'insieme, non per la singola meta-analisi.
- Un successo non assolve una meta-analisi dominata da uno studio: può descrivere bene quello studio.
- La ricerca di studi in comune legge i metadati dei campioni, non il riassunto della serie GEO. Può non vedere uno studio LINCS descritto solo lì.

## 13. Tempi di S7

Stima dell'agente, dai tempi misurati il 2026-11-04.

| passo | quanto | da dove viene |
|---|---:|---|
| Scarico LINCS, 35,9 GB | 2,1 h | 4,7 MB/s, 100 MB misurati |
| Scarico Tahoe, 88,9 GB | 0,7 h | 35,7 MB/s, 100 MB misurati |
| Scarico TCGA, circa 6 GB | ≤ 1 h | non misurato |
| Lettura delle firme e calcolo | ≤ 2 h | non misurato: la prima ora di S7 lo misura |
| **Totale** | **circa 6 h** | quasi tutta attesa di rete |

Il PI ha scelto tutte le fonti di §3 e ha approvato questo calcolo.

## 14. Fonti

- Lim N, Pavlidis P. Evaluation of connectivity map shows limited reproducibility in drug repositioning. Sci Rep 2021;11:17624. doi:10.1038/s41598-021-97005-z.
- LINCS2020: `https://s3.amazonaws.com/macchiato.clue.io/builds/LINCS2020/level5/`, build del 2020.
- Tahoe-100M: `https://huggingface.co/datasets/tahoebio/Tahoe-100M`, licenza CC0, preprint bioRxiv 10.1101/2025.02.20.639398. Indice in `analysis/audit/2026-11-04-S6-validazione-disegno/indici/`.
- GDC: `https://api.gdc.cancer.gov/files`, flusso `STAR - Counts`.
