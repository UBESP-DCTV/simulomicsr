# Layer B — difetti noti chiusi e residui (revisione finale del ridisegno, 2026-08-06)

La revisione finale del ramo `review-scientific-consistency-2026-06-10` (28 commit del
ridisegno Layer B, `docs/superpowers/plans/2026-08-05-layer-b-redesign-plan.md`) ha
prodotto una lista di rilievi. Il ledger che li tracciava (`.superpowers/sdd/progress.md`)
e' gitignored: non sopravvive fuori dalla sessione che lo scrive. Questo file riporta
**il crash trovato dal revisore** (con la riproduzione minimale, ora chiuso) e **i limiti
noti che restano** dopo il giro di correzioni del 2026-08-06, cosi' che non vadano
riscoperti da zero alla prossima sessione.

## Il crash: heatmap placeholder, "figure margins too large"

**Sintomo.** `.build_heatmap()` (`R/layer-b-plot-heatmap.R`), quando un cluster non ha
nessun gene significativo a FDR sotto soglia, disegna un placeholder testuale al posto
della heatmap vera:

```r
png_path <- file.path(out_dir, "heatmap.png")
grDevices::png(png_path, width = 800, height = 400, res = config$dpi)
graphics::plot.new()
graphics::text(0.5, 0.5, sprintf("Heatmap N/A: no genes significant at FDR<%g", fdr_thr))
grDevices::dev.off()
```

`width`/`height` sono in pixel ma **senza `units = "in"`**: a `res = config$dpi` (default
300) un canvas di 800x400 px e' in realta' solo 2,67x1,33 pollici — troppo piccolo per i
margini di default di `plot.new()`. `graphics::plot.new()` fallisce con
`Error in plot.new() : figure margins too large`.

**Riproduzione minimale** (isolabile senza il resto della pipeline):

```r
png("/tmp/repro.png", width = 800, height = 400, res = 300)
plot.new()  # Error in plot.new() : figure margins too large
dev.off()
```

**Perche' contava piu' di un bug estetico.** `.build_heatmap()` e' chiamata dentro il
ciclo per-cluster di `build_layer_b_results()` (`R/layer-b-build.R`) **senza
`tryCatch`**. Un solo cluster della selezione con zero geni significativi (non un caso
raro: vedi ad es. il gruppo IL1A "DECLARED INCOHERENT" nella selezione v15, dove il
pooling ha fatto cadere gli studi giusti) faceva abortire **l'intero batch**, dopo aver
gia' scritto su disco le figure dei cluster processati prima in ordine di selezione.

**Fix (2026-08-06).** Allineato alla stessa forma gia' usata da `.build_ma_plot()` e
`.build_go_enrichment()` (che non avevano questo difetto):

```r
grDevices::png(png_path, width = 8, height = 4, units = "in", res = config$dpi)
```

Verificato con un test SENZA mock del rendering (prima il difetto era invisibile alla
suite: l'unico test che toccava questo ramo mockava `grDevices::png`/`graphics::plot.new`
per isolare il contenuto del valore di ritorno, non il PNG vero) — vedi
`tests/testthat/test-layer-b-heatmap-legenda.R`, test `".build_heatmap non crasha sul
ramo placeholder (rilievo I1, senza mock del rendering)"`.

Non risultano altre chiamate a `grDevices::png()` nel Layer B con lo stesso difetto: le
altre (heterogeneity, go_enrichment x3, heatmap principale) usano gia' `units = "in"`
esplicito o pixel scalati da `config$dpi` (`width = 8 * config$dpi`), entrambe forme
sicure. Verificato con `grep -rn "grDevices::png(" R/layer-b-*.R`.

## Limiti noti che restano dopo questo giro

1. **Nessun `tryCatch` per-cluster nel ciclo di build.** Il fix sopra chiude l'UNICO
   innesco oggi noto, ma `R/layer-b-build.R` continua a generare le otto figure di ogni
   cluster della selezione senza isolamento: un futuro difetto non ancora scoperto in
   una qualunque delle funzioni `.build_*()` fermerebbe di nuovo l'intero batch dopo aver
   gia' scritto le figure dei cluster precedenti. Non e' stato aggiunto in questo giro
   (fuori dal perimetro dei rilievi della revisione, che chiedeva "una riga" per il
   sintomo trovato) — resta un'architettura da rivedere se altri crash simili emergono.
2. **`bersagli_attesi_provider` e' un argomento del CHIAMANTE, non un default del
   pacchetto.** Il fix del rilievo C1 collega
   `analysis/p5-stage4-layer-b-build-v13.R` alla lista `ATTESI` di
   `analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R` (7 entita', 31
   bersagli). Uno script di build futuro (un ipotetico v16) che non ripete questo
   collegamento tornera' silenziosamente al comportamento "nessuna aspettativa
   dichiarata" — corretto per definizione (`build_layer_b_results()` non ha una tabella
   interna di bersagli, per design: vedi il docstring di `.narrativa_bozza()`), ma va
   ricordato ad ogni nuovo script di build.
3. **Il titolo YAML del report (`inst/templates/layer-b-report.qmd`) non puo' contenere
   il conteggio dinamico delle meta-analisi.** Quarto/knitr valutano il codice inline
   nell'ordine in cui compare nel documento: il titolo YAML precede il chunk `setup` che
   carica `lb <- load_layer_b(...)`, quindi un'espressione `` `r nrow(lb$selection_resolved)` ``
   nel titolo fallisce con `object 'lb' not found` (verificato con un rendering Quarto
   minimale di prova). Il fix del minor "nove meta-analisi cablato" ha rimosso il
   conteggio dal titolo YAML invece di renderlo dinamico (impossibile in quella
   posizione); l'intestazione H1 e la riga dell'appendice, che vengono DOPO il chunk
   `setup`, usano invece `` `r nrow(lb$selection_resolved)` `` e restano sempre esatte.
4. **`.LB_COLORI$neutro` resta usato per le linee di riferimento a zero** (`geom_vline`)
   nel pannello superiore del forest e nel volcano, oltre che per la legenda
   "non significativo" del volcano. E' un riuso deliberato (una linea tratteggiata di
   riferimento non ha una semantica "significativo/non significativo" propria) e non lo
   stesso difetto del rilievo I6 (che riguardava le STIME per-studio nel pannello
   inferiore del forest, ora `$per_studio`) — segnalato qui solo perche' un lettore
   veloce del diff potrebbe scambiarlo per un residuo del fix non applicato.

## Riferimento

Rilievi della revisione (C1, C2, I1, I2, I3, I4, I6, I7, I8 + 5 minori) chiusi in un solo
giro sul branch `review-scientific-consistency-2026-06-10`, commit successivi a
`44158b2`. Verifica sull'artefatto (rigenerazione del bundle TGF-β1 sui dati veri v15)
documentata nel messaggio di chiusura della sessione.
