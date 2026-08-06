# HANDOUT — Layer B v3: il documento diventa pubblicabile

**Scritto:** 2026-08-06 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato, no push
**Stato di partenza:** report v2 in `analysis/p4-output/20260806T022106Z-layer-b-81f379d3`
(9 bundle, 37 PNG, HTML 14,1 MB) — struttura e figure rifatte, **contenuto testuale da rifare**.

> **Questo file è autosufficiente.** Non serve leggere la conversazione precedente.

---

## 0. Il giudizio dell'utente, per intero

> «Non hai fatto un lavoro preciso, non sono soddisfatto, hai fatto di fretta. Non hai
> controllato bene. Non mi fido quindi di quello che hai scritto.»

È fondato, e il §3 lo documenta con i numeri. Le narrative sono state **generate da un
template** a partire dalle colonne del deliverable: nessuna ricerca bibliografica, nessuna
verifica indipendente dei numeri, nessuna rilettura dell'output prima della consegna. Un
documento con quei difetti non va in un articolo.

**Il mandato della prossima sessione:** rifare il contenuto testuale con ricerca vera e
verifica indipendente, e rendere il documento neutro e pubblicabile.

---

## 1. Le otto richieste, alla lettera

| # | richiesta | dove intervenire |
|---|---|---|
| 1 | **Via l'apertura** «dalla pipeline vera» e ogni nota di processo. Documento **neutro e scientifico**. Niente corpus in apertura. **Mai la parola «sporco»** | `inst/templates/layer-b-report.qmd`, `R/layer-b-summary-card.R` |
| 2 | **Tutto in inglese** | ovunque: titoli, schede, narrative, didascalie, assi |
| 3 | **«Numeri verificabili» → titolo professionale**; la tabella **sfora nell'indice di destra e si sovrappone** | template + CSS |
| 4 | **Numerare i case study** (Case study 1, 2, …) | template |
| 5 | **Eliminare l'elenco delle figure** | `R/layer-b-summary-card.R`, `.write_narrative_template()` |
| 6 | **IL1A: «? confronti imperfetti su ?»** — spiegare e risolvere | vedi §3, è il punto più grave |
| 7 | **Riscrivere le narrative** con ricerca vera + verifica dei numeri + contestazione | workflow, vedi §4 |
| 8 | **Dopo i case study**, la descrizione del **corpus totale delle 214** con tabelle e grafici aggregati | template + funzione nuova |

---

## 2. Che cosa è già a posto e non va toccato

Il ridisegno strutturale di v2 regge e ha alle spalle undici revisioni indipendenti:

- **forest** a due pannelli, selezione per FDR, filtro di copertura, gene rappresentativo a k
  pieno (per TGF-β1: bersagli canonici sopra, PMEPA1 su 59 studi sotto);
- **volcano** con asse compresso **dichiarato** ed etichette sui geni ben misurati;
- **heatmap** senza la legenda dei 47 codici GSE;
- il **collegamento** scheda/narrativa al build, con ripiego dichiarato;
- il **tema grafico unico** (`R/layer-b-theme.R`).

Non rifarli. La spec di v2 è `docs/superpowers/specs/2026-08-05-layer-b-redesign-design.md`.

---

## 3. Il punto 6, misurato: due difetti sovrapposti

### 3.1 I punti di domanda

`analysis/p5-stage4-layer-b-build-v13.R:290-300`: `confronti_imperfetti_provider` restituisce

```r
n   = if (!is.null(grande)) length(grande$confronti_difettosi) else NA_integer_,
tot  = if (!is.null(grande)) grande$n_confronti_totali        else NA_integer_,
peso = riga$peso_citati[1L]
```

`grande` viene da `13-grandi-conteggio.json`, che copre **solo i 13 gruppi con k≥15**. Per gli
altri il conteggio confronto-per-confronto **non è mai stato fatto**, quindi `n` e `tot` sono
`NA` e la frase stampa `?`.

Gruppi con `?` nel report v2: **IL1A, Parkinson, Crohn** (i tre della vetrina fuori dai 13).

### 3.2 Il difetto grave: il peso viene da una misura dichiarata inaffidabile

`peso` viene da `peso_citati` di `analysis/audit/2026-08-05-rilettura-214/verdetti-con-peso.csv`.
Quella colonna è la stima ottenuta **estraendo con un'espressione regolare gli identificativi
GSE citati nelle motivazioni** — e in
`docs/findings/2026-08-05-confronti-imperfetti.md` §5.4 è scritto che **è stata scartata perché
cieca**: mediana **87%**, perché la regex prende anche gli studi che le motivazioni citano
come *puliti*, e nei gruppi da 3-6 studi citarne due copre tutto.

Nel report v2 quel numero è stampato come «% del peso stimato della meta-analisi»:
**IL1A 100,0%**, **Parkinson 60,1%**, Crohn 10,1%. Sono numeri di una misura che il progetto
stesso ha dichiarato di non usare.

**Da fare:** o si misura davvero il conteggio per i gruppi mancanti (stesso metodo dei 13:
un agente che conta i confronti difettosi leggendo le etichette intere), oppure la riga si
omette **dichiarando** che per quel gruppo la misura non è stata fatta. **Non si pubblica il
numero della regex.**

---

## 4. Il punto 7: come rifare le narrative (workflow obbligatorio)

L'utente ha chiesto esplicitamente un workflow con questa struttura, **un giro per ciascuno
dei nove case study**:

1. **Ricercatore** — un agente per case study, che fa una **ricerca vera su internet**
   (WebSearch/WebFetch) sulla biologia del trattamento o della malattia, e scrive la
   narrativa: contesto biologico, che cosa ci si attende dalla letteratura **con i
   riferimenti**, che cosa i dati mostrano, che cosa significa.
2. **Verificatore dei numeri** — un secondo agente per case study, con un compito solo:
   **ogni numero della narrativa deve essere esatto**, verificato contro il deliverable e il
   parquet. Non giudica la prosa, controlla le cifre.
3. **Contestatore (GAN)** — un agente finale che attacca i risultati dei primi due, **e loro
   devono difendersi**. Non un contestatore per blocco: uno che riceve narrativa + verifica e
   prova a smontarle.
4. **Se ricercatore e contestatore restano in disaccordo, il disaccordo va riportato al
   coordinatore, che decide.** Non deve essere il contestatore ad avere l'ultima parola
   d'ufficio: nella sessione precedente il suo prompt lo spingeva alla severità e i 24
   verdetti cambiati andavano **tutti** verso il peggio, zero assoluzioni. Questa volta i due
   critici vanno resi **simmetrici**, o il disaccordo va escalato.

**Fonti dei numeri per il verificatore:**
- deliverable annotato: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/deliverable-annotato.rds`
- per-gene: `cluster_pooled.parquet` nella stessa directory
- per-studio: `per_study_de.parquet`
- confronti imperfetti: `analysis/audit/2026-08-05-rilettura-214/13-grandi-conteggio.json`
- bersagli attesi dalla letteratura, fissati prima del run: `analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R`

**I nove case study** (cluster_id → etichetta), da `analysis/layer-b-selection-v15.csv`:
`cgroup_L5_930c8dcf` DHT · `cgroup_L5_c0d1d837` enzalutamide · `cgroup_L5_2e16719f` TGF-β1 ·
`cgroup_L5_871ae09e` SARS-CoV-2 · `cgroup_L5_87c40ebb` IFN-γ · `cgroup_L5_b71a25a2` JQ1 ·
`cgroup_L5_c3ae78cd` Crohn · `cgroup_L5_85083e38` Parkinson · `cgroup_L5_3973fe03` IL1A.

---

## 5. Il punto 8: la sezione sul corpus, DOPO i case study

Non in apertura (richiesta 1), ma come sezione conclusiva: **le 214 meta-analisi** con tabelle
e grafici aggregati. I dati sono tutti nel deliverable annotato:

- distribuzione di `k_effective`, `k_kish`, `I2_med`, `n_sig`;
- quante sono dominate da un solo studio (`dominato`) e quante valgono meno di due studi
  efficaci (`k_kish < 2`) — **122 e 78 su 214**, misurati;
- composizione per tipo di entità (farmaco, citochina, patogeno, malattia);
- le 11 marcate incoerenti;
- una tabella delle prime N per potenza, con k, studi efficaci, geni significativi, I².

**Attenzione:** `analysis/audit/2026-08-05-rilettura-214/verdetti-con-peso.csv` contiene la
colonna `peso_citati` **inutilizzabile** (§3.2). Le altre colonne di quel file vanno bene.

---

## 6. Le trappole di questo lavoro, dalla sessione precedente

1. **Il render Quarto gira in un sottoprocesso che carica il pacchetto INSTALLATO**, non
   quello in sviluppo: dopo ogni modifica alle funzioni chiamate dal template serve
   `Rscript -e 'devtools::install(quick = TRUE, upgrade = FALSE)'`. È documentato nel roxygen
   di `render_layer_b_report()`.
2. **Tre volte in un ramo è stato scritto codice che nessuno chiamava** (la scheda nuova, il
   fornitore dei confronti imperfetti, quello dei bersagli attesi). Ogni volta il difetto era
   nel **piano**, non nell'esecuzione. Quando si aggiunge una funzione, il task che la scrive
   deve **anche collegarla**, e la verifica va fatta **sull'artefatto**.
3. **I criteri automatici sono misure, non garanzie**: nella sessione precedente erano tutti
   verdi mentre il forest mostrava i geni sbagliati. **Aprire i PNG e guardarli** deve restare
   uno step esplicito.
4. **Niente Monitor e niente background negli agenti implementatori**: due sessioni si sono
   bloccate ad aspettare notifiche che non dovevano arrivare.
5. **Mai un taglio silenzioso**: ogni filtro, omissione o ripiego che cambia ciò che il lettore
   ricava da una figura va dichiarato in didascalia. Vale anche in inglese.

---

## 7. Stato del repository

- Branch `review-scientific-consistency-2026-06-10`, **39 commit** di ridisegno, albero pulito.
- Suite: `[ FAIL 0 | PASS 545 ]` sul perimetro `layer-b`.
- Difetti noti residui: `docs/findings/2026-08-06-layer-b-difetti-noti.md`.
- Confronti imperfetti (metodo e numeri): `docs/findings/2026-08-05-confronti-imperfetti.md`.
- Deliverable: 214 meta-analisi, controllo biologico 29/31, DHT contro enzalutamide 1.408/1.441
  di segno opposto, Spearman −0,938.
