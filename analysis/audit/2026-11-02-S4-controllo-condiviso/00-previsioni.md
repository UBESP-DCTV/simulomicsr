# Sessione S4, il controllo condiviso: cancelli e previsioni

**Scritto il 2026-11-02, prima del calcolo.** Deliverable A3 v16, 194 meta-analisi:
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`.
Il deliverable non si tocca. Nessun verdetto cambia.

## Che cosa ho già guardato prima di scrivere

- Ho rieseguito `C2-controllo-condiviso.R` e `B6-setaccio.R`: 121 entry, 56 chiavi, 41 gruppi,
  20 nei 113, 59 dei 113 con il dominante a più bracci, setaccio 194 → 128 → 116 → 113 → 37.
- Fattibilità dell'abbinamento: i bracci del parquet, presi in ordine dentro (gruppo, studio),
  coincidono con i bracci di `dispatch-A3.rds` per `n_t` e `n_c` in 1.903 casi su 1.903.
  Le coppie (gruppo, studio) sono 1.178, 393 con più bracci, per 1.118 bracci, massimo 28.
  `per_study_de.parquet` contiene anche 319 bracci di gruppi fuori dalle 194: si scartano.
  Nessun `logFC` o `SE` non finito. Nessun conflitto di ruolo nel `qc_report`.
- **Non ho guardato** quanti bracci condividono campioni, né nessuna stima corretta.

## I trattamenti

Notazione, dentro una coppia (gruppo, studio) e per un gene: il braccio `i` ha stima `d_i` ed
errore standard `S_i`, con trattati `T_i` e controlli `C_i`, contati in **librerie** (dopo il
collasso delle corsie). La correlazione fra due bracci viene dal disegno e non dal gene:

```
num = |T_i∩T_j|/(nt_i nt_j) + |C_i∩C_j|/(nc_i nc_j) - |T_i∩C_j|/(nt_i nc_j) - |C_i∩T_j|/(nc_i nt_j)
rho_ij = num / sqrt((1/nt_i + 1/nc_i)(1/nt_j + 1/nc_j))
```

- **T0, produzione.** `.collapse_arms_by_study` / `.collapse_arm_se_by_study`: varianza inversa come
  se i bracci fossero indipendenti.
- **T1, varianza corretta.** Stessa stima puntuale di T0. Cambia solo l'errore standard:
  `Var = sum_i sum_j rho_ij (1/S_i)(1/S_j) / (sum_i 1/S_i^2)^2`. È il trattamento primario,
  perché cambia una sola cosa (la regola 4 del protocollo). Non usa `.build_franchini_V_matrix`:
  quella funzione ha un `rho` fisso a 0,5 e un pool per contrasto, qui `rho_ij` è misurato.
- **T2, minimi quadrati generalizzati (GLS).** `V_ij = rho_ij S_i S_j`, stima e varianza cambiano.
  Solo sensibilità: può dare pesi negativi quando gli `S_i` sono molto diversi.
- **T3, fusione.** Dentro una coppia, due bracci sono legati se condividono un campione con lo
  **stesso ruolo** (`T_i∩T_j` o `C_i∩C_j`). Ogni componente connessa diventa un confronto solo:
  unione dei trattati contro unione dei controlli, nuovo fit con `.run_limma_voom_de`, stesse
  guardie di produzione (`.drop_role_conflicts`, `.collapse_technical_lanes`). I componenti di una
  coppia si combinano poi con la varianza inversa di T0. Un campione con ruoli opposti
  (`T_i∩C_j`) non fonde: conto questi casi e li dichiaro.

Per T1, T2 e T3 ricalcolo tutta la catena di produzione: REM per gene (`metafor::rma`, REML,
ripiego DL), FDR di Benjamini-Hochberg dentro il gruppo, geni con FDR < 0,05, poi
`compute_pooling_effectiveness()` su quei geni e su quei `tau2`. Il taglio è quello del
setaccio: i 113 con `quota_top1 <= 0,5`.

Calcolo anche **T1-pesi**: errori standard di T1, ma `tau2` e geni significativi del deliverable.
Serve solo a separare i due canali e non produce un numero M.

## Cancelli

Se un cancello fallisce, la sessione non vale.

1. Il manifesto SHA-256 del deliverable passa. **Già superato** il 2026-11-02 (26 file di stage4-v16).
2. **Riproduzione di T0.** Il mio percorso di calcolo con `rho = 0` riproduce, su 194 gruppi su
   194 e su tutte le righe, `logFC_pool`, `SE_pool`, `tau2`, `FDR_BH_within_cluster` di
   `cluster_pooled.parquet` (scarto massimo < 1e-6) e `quota_top1`, `k_kish` di
   `deliverable-annotato.rds` (scarto massimo < 1e-6). Il setaccio torna 113 → 37.
3. **Abbinamento bracci e campioni.** Il fit limma-voom ripetuto su tutti i 1.118 bracci degli
   studi multi-braccio riproduce `logFC` e `SE` del parquet (scarto massimo < 1e-6). Sbaglio
   l'abbinamento, e con lui ogni `rho`, se questo cancello non passa.
4. **Controllo positivo sul nullo.** Prendo gruppi di controllo veri con almeno 9 librerie e li
   divido a caso in due pseudo-trattati e uno pseudo-controllo, con proporzioni 1:1:1 (`rho` = 0,5)
   e 1:1:2 (`rho` = 1/3). Unità: l'insieme di controlli. Almeno 20 insiemi, seme 20261102.
   Passa se: (a) `|mediana(rho empirico - rho formula)| <= 0,05` in tutte e due le proporzioni;
   (b) la mediana di MAD² dello z corretto T1 sta in [0,85; 1,15]; (c) la mediana di MAD² dello z
   di T0 supera quella di T1 di almeno il 15%. La lettura è: lo strumento vede l'errore di T0 e
   non lo vede in T1. Margini: giudizio motivato, l'effetto atteso su T0 è 1 + `rho`, cioè
   +33% e +50%.
5. **Copertura.** 194 gruppi su 194 e 1.903 bracci su 1.903 entrano in ogni trattamento. Con
   `rho_ij` calcolato su un caso con la formula chiusa (m bracci uguali, stesso controllo,
   `Var = sigma^2 (1/(m n) + 1/n)`), lo scarto è < 1e-10.

## Previsioni

Unità di incertezza: la coppia (gruppo, studio) per P2, il gruppo per P3 e P5. Bootstrap con
B = 2.000 e seme 20261102. M, le uscite e le differenze fra trattamenti sono conteggi sull'intera
popolazione: non hanno intervallo di confidenza e si giudicano direttamente.

| # | quantità | attesa | intervallo di rilevanza | da dove viene il margine |
|---|---|---|---:|---|
| P1 | bracci che condividono almeno un campione con un altro braccio della coppia, su 1.118 | 750 (67%) | [560; 950], cioè 50%-85% | giudizio: sotto il 50% il fenomeno è di minoranza e l'handout va riscritto; sopra l'85% le corse a controlli separati sono trascurabili |
| P2 | rapporto mediano `SE_T1 / SE_T0` nelle coppie con `rho` non nullo | 1,20 | [1,10; 1,35] | giudizio: 1,10 sull'errore standard è −17% sul peso senza `tau2`. Sotto 1,10 regge la frase del codice «lievemente ottimistica» |
| P3 | Δ`quota_top1` mediano (T1 − T0), fra i 113, nei gruppi con il dominante a bracci che condividono campioni | −0,04 | [−0,08; −0,01] | soglia di progetto: −0,01 muove solo i quattro gruppi a 0,50-0,51; −0,08 muove anche i due a 0,57 e oltre |
| P4 | M: quanti dei 113 hanno `quota_top1 <= 0,5` con T1 | 44 | [39; 49] | variabilità misurata: nel test-retest 5 meta-analisi su 194 saltano fra corretta e difettosa. Il taglio si legge con questo margine |
| P5 | variazione relativa mediana di `n_sig` (T1 su T0) nei gruppi con `rho` non nullo | −8% | [−15%; −3%] | giudizio: sotto −3% il controllo condiviso non tocca le stime poolate in modo leggibile; oltre −15% tocca le frasi dell'articolo sul numero di geni |
| P6 | gruppi che escono dai 37 con T1 | 1 | [0; 3] | giudizio: un'uscita richiede un dominante a braccio singolo e un secondo studio che perde peso |
| P7 | `M(T3) − M(T1)` | +1 | [−3; +5] | stesso margine di P4. Con bracci omogenei T1 e T3 danno la stessa varianza, quindi una differenza grande viene dall'eterogeneità fra bracci |
| P8 | rapporto mediano `SE_T3 / SE_T1` sui geni dei componenti fusi | 1,10 | [1,00; 1,30] | giudizio: la fusione mette nel residuo le differenze vere fra bracci. Sopra 1,30 la fusione misura l'eterogeneità e non il controllo condiviso |
| P9 | `|M(T2) − M(T1)|` | 1 | [0; 3] | giudizio: T2 è una sensibilità. Oltre 3 la scelta dello stimatore pesa quanto il controllo condiviso |

## Che cosa non vede questa misura

- `rho_ij` viene dalla sovrapposizione dei campioni e assume la stessa varianza nei gruppi. Non
  vede la correlazione fra bracci con campioni diversi dello stesso laboratorio, per esempio il batch.
- Il collasso a effetti fissi ignora le differenze vere fra bracci (dose, tempo). T1 non le corregge.
- Il controllo positivo prova la formula su un nullo. Non prova che i veri bracci siano omogenei.

## Che cosa decide il PI, alla fine

Correggere (e allora il lavoro entra nell'applicazione delle correzioni, S13), oppure dichiarare il
limite nei Methods (S17). Questa sessione porta il numero, non la scelta.
