# Validazione esterna, l'esecuzione (S7): cancelli e previsioni

Scritte il 2026-11-04, prima del calcolo. Non si cambiano dopo il risultato. Il disegno è
`docs/superpowers/specs/2026-11-04-validazione-esterna-design.md`, congelato. Cancelli e previsioni sono copiati da §8
senza cambiamenti.

**Che cosa ho già letto.** Il disegno, il finding S6 e i suoi script. Dal deliverable: i nomi delle colonne, `contrast_direction`,
`contrast_control_key` e `direction_applied` degli 80 composti misurabili (tutti `gain`, `vehicle_untreated`, `none`) e dei 6 tumori.
Da LINCS: i metadati. Da Tahoe: l'elenco dei file e il README.
**Che cosa non ho letto.** Nessun dato Level 5, nessun file di Tahoe con i confronti, nessun dato TCGA, nessun valore di
`logFC_pool` o `SE_pool`, nessuna stima per studio.

Unità: la meta-analisi. B = 2000 per ogni bootstrap. Seme: 20261104. `Rscript` senza `--vanilla`.

## Cancelli (da §8 del disegno). Se uno fallisce, S7 si ferma.

1. Il manifesto del deliverable passa all'inizio e alla fine. Gli SHA-256 dei metadati LINCS coincidono con la provenienza.
2. S7 riottiene le stesse conte del finding S6: 19, 53, 5.466 composti, 36.204 firme.
3. Ogni composto dell'insieme ha almeno 800 landmark e `H` copre 19 su 19 e 53 su 53.
4. **Controllo positivo L1000:** almeno 4 coppie su 5 hanno il secondo composto nel primo 10%. La query invertita di segno deve abbassare `P_e` in tutte le coppie.
5. **Controllo positivo sul segno:** nel carcinoma epatocellulare, `GSE144269` (inversione nota) ha correlazione negativa con TCGA-LIHC. La mediana degli altri studi del gruppo è positiva.

## Previsioni (da §8 del disegno)

Sono giudizi dell'agente della sessione sul disegno (S6), tranne dove è indicata la fonte.

| quantità | attesa | intervallo di rilevanza | origine del margine |
|---|---:|---:|---|
| `H` nelle 19 | 40% | [17%; 70%] | 17% è il riferimento; sopra 70% il valore supera quanto mi aspetto dal soffitto e va cercato un errore |
| `H` nelle 53 | 30% | [17%; 70%] | stesso motivo; queste meta-analisi sono dominate o contengono difetti |
| `H_scambio` | 15% | [10%; 25%] | sopra 25% la risposta generica pesa più della differenza che vogliamo vedere |
| `H_metà` | 70% | [50%; 83%] | 83% è il soffitto di letteratura su una stessa condizione; sotto 50% la fonte non vede se stessa |
| `H_fonti` | 30% | [17%; 50%] | 17% è il riferimento fra piattaforme |
| mediana di `P_e` nelle 19 | 0,80 | [0,71; 0,95] | 0,71 è il limite del caso su 19 |

## Scelte tecniche scritte prima del calcolo

Il disegno lascia aperti questi dettagli. Li fisso adesso, prima di vedere un dato. Nessuno cambia soglia, statistica o insiemi.

1. **Cartelle.** LINCS in `/mnt/wwn-0x5000039d58caca35/lincs-meta/level5/`, Tahoe in `level5/tahoe100m/`, TCGA in `level5/tcga/`. I ligandi stanno in
   `level5_beta_trt_misc_n8283x12328.gctx`. Gli scarichi partono nell'ordine di §3 e possono sovrapporsi: le fonti sono server diversi e l'ordine non tocca il risultato.
2. **Valori mancanti in LINCS.** In `compoundinfo_beta.txt` un campo vuoto è scritto come due virgolette, alla lettera. Vale come mancante.
3. **Firma con più firme nella stessa linea.** Media delle `z` dentro la linea, poi media fra le linee, come dice §5. Un'entità con più `pert_id` unisce tutte le firme attive dei suoi `pert_id`, e il fondo perde tutti quei `pert_id`.
4. **Nomi dei controlli positivi.** Il nome si cerca in `cmap_name` e in `compound_aliases`, senza maiuscole, con trattini e spazi trattati come uguali (`trichostatin-a`). Si uniscono i `pert_id` trovati con almeno una firma attiva. Dal fondo escono i `pert_id` del primo e del secondo composto.
5. **`H_scambio`.** Per ogni interrogazione `e` di un insieme e per ogni composto `c` degli 80, `P_{e,c}` è il rango della firma di `c` sul fondo senza i `pert_id` di `c` e di `e`. Tolgo la coppia se i due composti hanno un `moa` non vuoto in comune o un `pert_id` in comune (le molecole doppie). Si calcola per le 19 e per le 53, e ogni insieme usa il proprio valore in `T_eff`.
6. **Bootstrap di `H - H_scambio`.** `d_e` è il successo di `e` meno la media dei suoi successi sbagliati. Ricampiono le meta-analisi, B = 2000, percentile 2,5%.
7. **`H_metà`.** La metà 1 ha `floor(n/2)` linee, la metà 2 ha le altre. Ogni divisione rifà la scelta per tutti i composti del fondo. Il fondo perde i `pert_id` dell'entità. L'intervallo viene dal bootstrap sugli 80 composti, sulla loro media fra le 20 divisioni.
8. **Tahoe.** Per ogni farmaco prendo la concentrazione più alta del farmaco. Faccio la media di `stat` dentro la linea e poi fra le linee. Un `stat` mancante esce dalla media. Il fondo sono tutti i farmaci di Tahoe tranne il controllo, tolto il farmaco giusto. `H_fonti` ha l'intervallo esatto su 142 farmaci. L'aggancio per nome è quello di `50-tahoe.R` del disegno, e riottiene 142.
9. **TCGA.** Campioni `Primary Tumor` e `Solid Tissue Normal` della stessa persona. Con più file per lo stesso tipo prendo il primo per `file_id` in ordine alfabetico. Colonna `unstranded`, righe `ENSG` senza versione, senza `_PAR_Y`. `filterByExpr`, TMM, `voom`, `lmFit`, `eBayes`. Il profilo del progetto è la `t` di `tipo`, tumore contro normale.
10. **Cancello 5 e tumori.** La correlazione è di Spearman fra `logFC / SE` dello studio, dopo il collasso dei bracci, e la `t` di TCGA, su tutti i geni in comune. Stampo anche il valore sui soli landmark. Se i due valori danno esiti diversi, è un dubbio da spiegare. Il cancello si giudica su tutti i geni, perché TCGA non ha il limite dei geni inferiti. Anche la descrizione dei 6 tumori usa tutti i geni, con il rango fra i 16 progetti.
11. **Sensibilità `qc_pass == 1`.** Il filtro vale per firme ed entità, e la regola di misurabilità si riapplica. Un'entità senza alcuna firma resta fuori, e dichiaro il denominatore.
12. **Sensibilità sulle molecole doppie.** Una coppia conta una volta, nell'insieme principale se uno dei due vi sta, con `P` uguale alla media dei due valori.
13. **Riesecuzione.** Gli script del passo B leggono `POOL_DIR` e gli elenchi degli insiemi da variabili d'ambiente, così lo stesso codice si riesegue dopo le correzioni.

Un cancello, una regola o un margine di questo file non cambiano dopo il primo risultato. Se il disegno risulta sbagliato, S7 si ferma e si rifà S6.
