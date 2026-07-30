# HANDOUT — sessione LAYER B sui 191 gruppi poolati (preparato 2026-07-30)

**Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** 🟢 **Il deliverable è poolato (191 meta-analisi), annotato e validato biologicamente.
Manca il materiale guardabile: i case study.**
**Nessun run pesante previsto**: il Layer B è costato 11,7 minuti l'ultima volta (18 bundle).

---

## 0. REGOLE (non negoziabili)

1. Il gate è la **COERENZA**, mai il numero.
2. Verifica su **TUTTI**, mai a campione. Se un insieme è identico a uno già verificato, **provalo**
   confrontando gli insiemi.
3. **Prima di giudicare, verifica che lo strumento veda il dato per intero.** In due giorni tre
   rilevatori sono stati ciechi (alias corti, lettere greche cancellate, testo troncato a 58
   caratteri) e uno di essi ha prodotto un verdetto sbagliato. Accanto a ogni misura su testo:
   *quante stringhe toccano il limite?*
4. Nessun LLM nella pipeline.
5. Fail onesto coi numeri. Se resta il 3%, si scrive 3%.
6. **VIETATO** dichiarare "validato / finale / paper-grade" senza prova per-gruppo su TUTTI.
7. Se una misura contraddice una conclusione precedente, si ritratta **subito e per iscritto**.

## 1. DA DOVE SI PARTE

| | |
|---|---:|
| meta-analisi poolate | **191** |
| coerenti (marcate) | 185 (96,9%) |
| incoerenti dichiarate | 6 |
| geni significativi (FDR<0,05) | 315.037 |
| I² mediano | 73,2 |

- **Pooled**: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296`
  (`cluster_pooled.parquet`, `per_study_de.parquet`, `run_metadata.json`).
- **Deliverable annotato** (una riga per meta-analisi, con etichetta leggibile, verdetto di coerenza
  col motivo, k, geni significativi, I², studi persi):
  `analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.csv` (e `.rds`).
- **Finding**: `docs/findings/2026-07-30-repool-v13-risultati.md` (run, anti-stale, controllo
  biologico, ritrattazioni) e `docs/findings/2026-07-29-etichette-identita-e-gate-del-pooling.md`
  (etichette, identità verificata su tutti e 305, gate k_eff).

## 2. IL LAVORO: costruire i case study

**Macchina già esistente** (ADR-0017): `analysis/p5-stage4-layer-b-build-v10.R` genera per ogni
cluster volcano, forest, MA, heatmap, pannello di eterogeneità, arricchimento GO, tabella dei top
geni, summary card, più un report HTML unico. Input: un CSV di selezione con i `cluster_id`.

⚠️ **Verificare prima di lanciare**: quello script è scritto per l'output v10. Vanno controllati i
percorsi (dir dello Stadio 4 v13) e che il dispatch `rem_group` sia ancora gestito — il bug del
2026-07-23 era esattamente questo, e il fix c'è ma va riverificato sul nuovo output.

**Selezione decisa dall'utente il 2026-07-30:**

| dove | quanti | quali |
|---|---:|---|
| **main paper** | **2 figure, 3 gruppi** | (a) **DHT** (`CHEBI:16330`, k=23) **contro enzalutamide** (`CHEBI:68534`, k=19) nella stessa figura: agonista e antagonista del recettore androgenico, segni opposti sugli stessi bersagli (KLK3, TMPRSS2, FKBP5, NKX3-1) — controllo positivo e negativo insieme; (b) **un solo** caso ad alto k, TGF-β1 (`HGNC:11766`, k=49) **oppure** LPS (`CHEBI:16412`, k=35), con forest e I² |
| **supplementari** | **5-6** | copertura di tipo: SARS-CoV-2 (`NCBITaxon:2697049`, k=33) · IFN-γ (`HGNC:5438`, k=19) · una malattia (Parkinson `MeSH:D010300` k=10 o carcinoma epatocellulare `MeSH:D006528` k=10) · JQ1 (`CHEBI:137113`, k=24, 9.501 geni sig) · **almeno uno dei 6 incoerenti**, mostrato come esempio di ciò che il metodo dichiara invece di nascondere |

**Che cosa guardare nei bundle** (è il motivo per cui si fa il Layer B, non l'estetica):

- il **forest plot** dice se un gruppo da 49 studi è in realtà dominato da due;
- la **heatmap** dice se i campioni si separano per studio invece che per trattamento (batch);
- l'**arricchimento GO** dice se le vie sono quelle attese o generiche;
- il **pannello di eterogeneità** mostra dove l'I² alto viene da uno studio fuori scala.

Se una di queste cose salta fuori, **è un finding**, non un problema di grafica.

## 3. DOPO (non in questa sessione, salvo GO)

- **Methods**: il materiale è già scritto nei finding, va raccolto — i 114 gruppi scartati dal gate
  e perché, i 6 incoerenti col motivo, TGF-β1 spezzato in tre, l'ID sbagliato dell'acido
  lipoteicoico, gli I² alti, e il meccanismo per cui **il gate dei controlli interni può concentrare
  un errore invece di diluirlo**.
- **Regola «entità con un gruppo proprio»** (IL-1α/IL-1β): chiuderebbe 1 gruppo su 191, costa ~9 h di
  re-cluster + ~28 h di re-pool. Decisione dell'utente, meglio **dopo** il Layer B: se i case study
  fanno emergere altri casi della stessa famiglia, lo stesso costo ne chiude molti invece di uno.

## 4. TRAPPOLE GIÀ PAGATE

- **`setsid`**, mai `run_in_background`, per qualunque run lungo (verificare SID==PID).
- **`Rscript` senza `--vanilla`** per gli script che caricano il pacchetto (renv).
- **Mai giudicare su testo troncato** (§0.3): il bundle del censimento tagliava a 58/40 caratteri.
- **`canonical_name` non si sovrascrive**: l'etichetta nuova sta in `contrast_entity_label`, la
  provenienza del nome vecchio resta tracciabile.
- **Le etichette curate a mano stanno nei dati**, non nel codice:
  `inst/extdata/entity-label-overrides.csv`.
- **`test-stage3-perf-budget` è in ERRORE da prima**: non è una regressione.
- **Nella suite completa i dizionari sono fixture**: alcuni test vengono saltati; girare anche i
  file singoli.

## 5. ASSET

| cosa | dove |
|---|---|
| deliverable annotato (191 righe) | `analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.csv` |
| pooled v13 | `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296` |
| verdetti dei 6 incoerenti (motivi riletti sui poolati) | `.../verdetti-poolato-v13.csv` |
| bundle di lettura senza troncamenti (99 gruppi) | `.../bundle-intero-99.txt` |
| appaiamenti con numero diverso | `.../appaiamenti-numero-diverso.csv` |
| etichette curate | `inst/extdata/entity-label-overrides.csv` |
| codice nuovo | `R/stage3-entity-label.R`, `R/stage4-coherence-annotation.R` |
| macchina Layer B | `analysis/p5-stage4-layer-b-build-v10.R`, ADR-0017 |
| ADR | 0025 (anchor dal-contrasto), 0026 (mega fuori dal deliverable) |
