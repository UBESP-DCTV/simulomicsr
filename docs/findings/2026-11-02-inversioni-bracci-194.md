# Inversioni dei bracci sulle 194: una trovata, e che cosa costa

**Data:** 2026-11-02 · **Evidenza:** `analysis/audit/2026-11-02-inversioni-194/` ·
**Deliverable:** A3 v16, 194 meta-analisi
(`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`) ·
**Previsioni:** `00-previsioni.md`, committate prima del calcolo.

## 0. La risposta

> Fra i **1.174** studi misurabili la ricerca conferma **una sola inversione**, quella già
> trovata dalla lettura umana: `GSE144269` in `Carcinoma, Hepatocellular`. Ma costa quasi
> tutta la meta-analisi: **105 geni significativi nel deliverable, 6.590 col segno
> raddrizzato**. La ricerca ha portato alla luce anche **4 studi con un braccio
> sbagliato** che nessuna lettura del modello aveva accusato. **Non è la prova che non ci
> siano altre inversioni**: lo strumento ne avrebbe vista una solo nel **52%** degli studi.

**Nessun verdetto è cambiato e nessuna correzione è stata applicata.**

## 1. Il metodo

Per ogni studio, dopo il collasso dei bracci (formula identica a
`.collapse_arms_by_study`, verificata su `IFNA1`): Spearman fra il suo logFC e la mediana
degli altri studi del gruppo, su tutti i geni e sui 500 con |t| mediano più alto negli altri.
Il nullo è lo stesso studio contro 20 gruppi estratti a caso che non lo contengono (seme
20261102). **Candidato** = sotto il 1° percentile del nullo su almeno una misura. I 1.118 bracci
degli studi multi-braccio sono misurati a parte, col proprio nullo. I bracci ricostruiti sono
**1.903**, come i confronti poolati già noti. Ogni candidato è poi stato classificato leggendo
titoli, sorgente e caratteristiche dei campioni (`40-classificazione.csv`, `candidati/`).

| soglia del nullo | tutti i geni | top 500 |
|---|---:|---:|
| 1° percentile, studi | −0,215 | −0,386 |
| 0,1° percentile, studi | −0,362 | −0,634 |

## 2. I risultati

**14 studi candidati su 1.174 misurabili** (1,2%; 4 dei 1.178 non hanno abbastanza geni) e **12
bracci su 1.118**, per **23 studi distinti**. L'unione di due code all'1% ne attende fino al 2%:
**nel totale non c'è eccesso sul caso**. L'eccesso è nell'estremo: 4 studi oltre lo 0,1° percentile
contro 1,2 attesi (`GSE144269`, `GSE236205`, `GSE64741`, `GSE186054`).

| classe | studi | quali |
|---|---:|---|
| `inversione` | **1** | `GSE144269` |
| `braccio_sbagliato` | **4** | `GSE93153`, `GSE168468`, `GSE208347`, `GSE186709` |
| `nessuna_inversione` | **18** | il metadato concorda con l'etichetta |
| `non_decidibile` | 0 | |

### `GSE144269`: quanto costa un'inversione (`50-out.txt`)

Stessa catena di produzione, cambiando solo il segno di quello studio. Il deliverable si
riproduce esattamente prima di toccare il segno.

| `Carcinoma, Hepatocellular` | deliverable | segno raddrizzato |
|---|---:|---:|
| geni significativi (FDR < 0,05) | **105** | **6.590** |
| I² mediano | 79,8 | 63,3 |
| GPC3 | +2,07, FDR 0,80 | +2,94, FDR 0,0013 |
| TOP2A | +1,60, FDR 0,80 | +2,82, FDR 0,0008 |
| CYP3A4 | −2,69, FDR 0,80 | −4,45, FDR 0,0006 |
| ALB | −1,32, FDR 0,80 | −2,40, FDR 1e-19 |

Peso REM dello studio: 22,6%. Il segno dei logFC poolati era già giusto per quei marcatori:
l'inversione non capovolge il risultato, **lo spegne**. Questa è una misura, non il gruppo
corretto: la correzione passa dallo Stadio 2.

### I quattro bracci sbagliati

| studio | gruppo | etichetta | metadato | peso REM | nei 37 / nei 173 |
|---|---|---|---|---:|---|
| `GSE93153` | hepatitis B virus | *HBV D10 Donor2* | 2/2 `infection: Mock`, giorno 8 | 31,8% | no / sì |
| `GSE186709` | vtp50469 | *… VTP50469* contro *… Vehicle* | trattato MLL3 mutante, veicolo MLL3 WT | 33,5% | no / sì |
| `GSE168468` | lipopolysaccharide | *LPS (24h)* | 2 campioni su 3 sono macrofagi a 6 giorni, contro monociti a 24 h | 3,4% | no / sì |
| `GSE208347` | Parkinson Disease | *Healthy Controls* | 5/5 `parkinson status: PD` | 0,6% | no / sì |

**Nessuno di questi quattro studi, né `GSE144269`, è accusato in `difetti.csv` né nel retest
2.** `vtp50469` e `Parkinson Disease` hanno verdetto *corretta* e stanno fra i 128 «senza
difetti» dei 173. Nessuno dei cinque gruppi è nei 37.

### Discordanti senza errore nel metadato

I 18 `nessuna_inversione` restano non spiegati: per un trattamento diverso, un contesto
diverso, o un errore che il metadato non mostra. Non è un'assoluzione. Da guardare per primi
`GSE236205` (THZ1, −0,51), `GSE64741` (crizotinib, −0,48) e `GSE186054` (sepsis, −0,44), oltre lo
0,1° percentile. Quattro stanno in gruppi dei **37**: `GSE64741` (crizotinib), `GSE153739`
(endometriosis), `GSE247275` (tazemetostat), `GSE151464` (keloid).

## 3. Quanto vede lo strumento

Invertire uno studio cambia solo il segno di Spearman, quindi la sensibilità si calcola sui dati:
uno studio invertito sarebbe stato visto se il suo rho, cambiato di segno, finisse sotto soglia.

| k | studi che lo strumento avrebbe visto |
|---|---:|
| 3 | 96/243 = 39,5% |
| 4–5 | 90/216 = 41,7% |
| 6–10 | 134/315 = 42,5% |
| > 10 | 291/400 = 72,8% |
| **tutti** | **611/1.174 = 52,0%** |

Solo **28 gruppi su 194** sono coperti in tutti gli studi; **70** non hanno nessuno studio
coperto. Un'inversione su 611 coperti dà un tasso dello 0,16% (IC95 esatto 0,004–0,91%). Se
valesse anche per gli studi non coperti, che è un'assunzione, sui 1.174 sarebbero fino a **una
decina**. Inoltre: uno studio invertito fa da riferimento agli altri, gruppi interamente invertiti
non si vedono, e gli errori che non anticorrelano sfuggono (i casi `GSE138698`, `GSE221804` e
`GSE226115` della lettura umana non sono fra i candidati).

## 4. Le previsioni

| | esito |
|---|---|
| P1 `GSE144269` candidato su entrambe le misure | **vera** (−0,77 e −0,96) |
| P2 candidati fra il 2% e il 6% | **falsa**: 1,2% |
| P3 almeno il 70% dei candidati non è un'inversione | **vera**: 22 su 23 |
| P4 da 0 a 5 inversioni oltre `GSE144269` | **vera**: 0 |
| P5 la maggioranza in gruppi caso-controllo | **non valutabile**: nessuna oltre `GSE144269`, che è caso-controllo |

## 5. Che cosa ne segue

1. **`GSE144269` va corretto** con gli altri errori in S13 (gate S12): nel frattempo
   `Carcinoma, Hepatocellular` non è citabile, e sta nei 173.
2. **I 173 contengono errori che il setaccio non vede.** S5 deve decidere sapendolo: il metro
   sulle etichette non basta per chiamare «puliti» i 128.
3. **Il rilevatore di S10 deve confrontare le etichette con le stringhe grezze**: tutti e cinque
   gli errori qui, e quelli della lettura umana, sono leggibili lì e non nell'etichetta. La
   correlazione resta un controllo complementare a copertura parziale.
