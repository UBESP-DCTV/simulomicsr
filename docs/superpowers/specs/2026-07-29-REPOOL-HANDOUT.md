# HANDOUT — sessione del RE-POOL v13 + correzione delle etichette (preparato 2026-07-28)

**Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** 🟢 **Il deliverable esiste, è censito e i limiti sono dichiarati. Manca poolarlo.**
**Il lavoro di questa sessione: UN RUN PESANTE (~50 h) + un lavoro a valle in parallelo.**

---

## 0. REGOLE (non negoziabili)

1. Il gate è la **COERENZA**, mai il numero di gruppi.
2. Verifica su **TUTTI**, mai a campione. Se un insieme è identico a uno già verificato, dirlo e
   provarlo (confronto di insiemi), non assumerlo.
3. Nessun LLM nella pipeline.
4. **Aggiornamento ogni ora** durante il run: fatto X, manca Y, ETA Z.
5. Fail onesto coi numeri. Se resta il 3%, si scrive 3%.
6. **VIETATO** dichiarare "validato / finale / paper-grade" senza prova per-gruppo su TUTTI.
7. Se una misura contraddice una conclusione precedente, si ritratta subito e per iscritto.

## 1. DA DOVE SI PARTE

Re-cluster **v13** completato: `analysis/p4-output/20260728T151529Z-stage3-v13-364547a7`.

| | |
|---|---:|
| gruppi del deliverable (`rem_group` sui `cgroup`) | **305** |
| coerenti, letti uno per uno | **296 (97,0%)** |
| incoerenti dichiarati | 9 |
| studi-slot | 2.158 |
| bandiera | SARS 38 · TGFB1 65 · LPS 50 · enzalutamide 29 · vemurafenib 20 |

Finding: `docs/findings/2026-07-28-censimento-v13.md`.

**Decisioni già prese, non ri-litigare:**

| cosa | decisione |
|---|---|
| `mega`, `mega_aug`, `rem` | **fuori dal deliverable** (ADR-0026 + utente 2026-07-27). Già implementato: `stage4_default_config()$deliverable_methods = "rem_group"` |
| soglia k | **k≥3** |
| cache recupero-nome | **v7**, non bumpare (`recover_identity()` non è cambiato) |
| i 9 incoerenti | **restano**, dichiarati nei Methods |
| TGF-β1 (frammentazione + GSE233083) | **limite dichiarato**, non si corregge (utente 2026-07-28) |
| etichette sbagliate | **si correggono in questa sessione**, a valle, mentre il re-pool gira |

## 2. IL RUN — re-pool Stadio 4 (~50 h)

Base: `analysis/p4-fase-f5-stage4-layer-a-rebuild-v10.R` (o l'ultimo `-rebuild-v*`). Da cambiare:
`stage3_dir` → la dir v13, `out_dir` → token v13 su `/mnt/wwn-0x5000039d58caca35/`.

```bash
# DRY_RUN prima, sempre
DRY_RUN=1 Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v13.R 2>&1 | tail -30

# poi il full, DETACHED (run_in_background uccide i run lunghi)
setsid nohup Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v13.R \
  > analysis/audit/v13-repool-full.log 2>&1 < /dev/null &
ps -eo pid,sid,args | grep "[r]ebuild-v13"   # SID deve essere == PID
```

**Attesi nel DRY_RUN**: Layer A = **305 cluster**, tutti `method = "rem_group"`, nessun `mega`,
`mega_aug`, `rem`. Se compaiono, la selezione non sta leggendo `deliverable_methods`: **fermarsi**.

**VERIFICA ANTI-STALE a fine run** (non saltarla — è già costata un run intero in passato):

- `Methods` in `cluster_pooled.parquet` contiene **solo** `rem_group`;
- i `cluster_id` iniziano tutti con `cgroup_L5_`;
- ~305 cluster poolati;
- confronto k con `deliverable-v13.rds`: il `k_effective` poolato può essere **minore** di `k`
  (collasso dei bracci intra-studio, ADR-0022) ma non maggiore.

**Cache**: riusare `stage4-counts/` (chiave method-independent, nessun rischio di stale). Non
esiste cache del pooled: il ramo viene sempre ricalcolato.

## 3. IN PARALLELO — correzione delle etichette (~poche ore, nessun run pesante)

**Il problema.** Il nome mostrato di un gruppo (`canonical_name`) è ereditato dall'anchor del
vecchio cluster e su decine di gruppi è sbagliato, mentre **l'ID è giusto**:

| ID (corretto) | nome mostrato | cos'è davvero |
|---|---|---|
| CHEBI:63637 | sodium aurothiomalate | vemurafenib |
| CHEBI:85993 | PI(18:0/18:3(6Z,9Z,12Z)) | palbociclib |
| CHEBI:5931 | chloride | insulina |
| CHEBI:16335 | glucose | adenosina |
| CHEBI:16796 | hydron | melatonina |
| MeSH:D008180 | cancer | lupus eritematoso sistemico |

**Verificato**: `canonical_name` non compare in nessun file di pooling/build/dispatch dello
Stadio 4 — correggerlo non tocca il risultato del re-pool e si può fare in qualsiasi momento.

**Che cosa fare**: una funzione che risolve `contrast_entity` (l'ID) al nome canonico usando i
dizionari già caricati (`.load_ontology_dicts()`), con TDD, e una colonna nuova
(es. `contrast_entity_label`) — **senza sovrascrivere `canonical_name`**, così la provenienza
resta tracciabile. Poi una tabella delle 305 etichette da rileggere: gli ID sono giusti, ma i nomi
vanno guardati, non solo generati.

Attenzione: per le entità `STR:` non esiste un nome ontologico — lì l'etichetta resta la stringa,
e va dichiarato.

## 4. DOPO (non in questa sessione, salvo GO)

- **Ri-censimento sui dati poolati**: la coerenza è stata misurata *prima* del pooling. Se il
  re-pool scarta membri per ragioni sue, va rimisurata.
- **Layer B** sui case study, con le etichette corrette.
- I nove incoerenti e i limiti TGF vanno nei **Methods**, non nascosti.

## 5. TRAPPOLE GIÀ PAGATE

- **`setsid`**, mai `run_in_background`: uccide i run lunghi. Verificare SID==PID.
- **Mai `git stash` prima di un comando che può scadere**: lo stash sopravvive al timeout e il
  codice sparisce dal working tree (successo il 2026-07-28, recuperato).
- **`Rscript` senza `--vanilla`** per gli script che caricano il pacchetto (renv).
- **Nella suite completa i dizionari sono fixture**: 31 test vengono saltati. Girare anche i file
  singoli (`test-stage3-contrast-gate`, `-v13`, `-row-pairing`, `-contrast-anchor`).
- **`test-stage3-perf-budget` è in ERRORE da prima**: non è una regressione.
- **Un metro sbagliato accusa il codice innocente**: prima di correggere, controllare lo strumento.
  Nel censimento v12 due rilevatori su tre erano ciechi al caso da cui erano partiti.

## 6. ASSET

| cosa | dove |
|---|---|
| deliverable v13 (305 gruppi + stato) | `analysis/audit/2026-07-28-censimento-v13/deliverable-v13.rds` |
| i 9 incoerenti col motivo | `.../verdetti-v13.csv` |
| bundle dei 63 riletti | `.../bundle-v13-compatto.txt` |
| finding v13 | `docs/findings/2026-07-28-censimento-v13.md` |
| finding v12 (metodo del censimento) | `docs/findings/2026-07-28-censimento-v12-dati-veri.md` |
| regole del gate | `R/stage3-contrast-gate.R`, `R/stage3-coherence.R`, `R/stage3-contrast-anchor.R` |
| test delle sei regole | `tests/testthat/test-stage3-contrast-gate-v13.R` (71 PASS) |
| ADR | 0025 (anchor dal-contrasto), 0026 (mega fuori) |
