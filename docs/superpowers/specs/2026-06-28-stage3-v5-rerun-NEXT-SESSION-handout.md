# Handout — Sessione 21: run gated v5 (re-cluster Stadio 3 → re-pool Stadio 4 → re-gate)

**Data:** 2026-06-28
**Per:** prossima sessione (sessione pulita)
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)

> Scritto in prosa semplice. Leggere tutto prima di lanciare i run pesanti.
> Questo handout copre **solo i 3 run gated** (Task 8-10 del Plan B). Il codice è già
> pronto, testato e revisionato. Non serve scrivere nuovo codice (salvo 2 micro-edit
> agli script di run, vedi sotto).

---

## In una frase

Il codice per dare un nome ai **farmaci** (ChEMBL) è pronto e validato sui dati reali
(smoke: 63% di recupero, 0 falsi). Il dizionario ChEMBL reale è già costruito. Resta da
**ri-girare la pipeline su v5**: re-cluster Stadio 3 (~6h) → re-pool Stadio 4 (~11h) →
re-gate omogeneità, per verificare che `small_molecule` scenda nettamente dal 49%.

## Dove siamo (stato di partenza, verificato)

- **Fase 1 codice Plan B COMPLETA** (Task 1-5 + final review opus "Ready to merge"),
  suite Stadio3/ontologia/anchor **1015 PASS / 0 FAIL / 0 ERROR**. Commit `cd9b213`..`f3c58b8`.
- **Dizionario ChEMBL reale GIÀ COSTRUITO**: `cache/chembl/chembl-lookup.rds`
  (49.099 molecole, 128.937 alias). `.load_ontology_dicts(refresh=TRUE)$has_chembl == TRUE`.
  Provenienza+SHA256 in `analysis/p4-output/chembl-source-provenance.json`. Tarball su
  `/sda` (`/mnt/wwn-0x5000039d58caca35/chembl_download/`); il `.db` da 30G è stato scartato.
- **Cache lookup**: schema version bumpata a `v2` + asse `has_chembl` nella chiave → il
  lookup v4 è invalidato automaticamente, si ricostruisce con la logica ChEMBL.
- **Pipeline ancora end-to-end su v4**; il codice per v5 è pronto.
- **Smoke copertura (Task 7) già fatto**: 63,4% recupero drug-name; il driver dominante è
  l'ESTRAZIONE (strip dose/tempo sblocca farmaci già in ChEBI), ChEMBL complementa i composti
  da ricerca; combo ok; **stoplist** anti-merge-spurio attiva (match generici 7→0).

## Cosa fare (sequenza, tutti GATE UTENTE)

### Pre-flight (sempre, prima di ogni run)
1. `Rscript -e 'devtools::load_all(quiet=TRUE); cat(isTRUE(.load_ontology_dicts(refresh=TRUE)$has_chembl))'`
   → deve stampare `TRUE`. Se `FALSE`: il dict ChEMBL manca → ri-costruirlo (vedi "Se serve
   ricostruire il dict").
2. Input Stadio 3 presenti (gli stessi del run v4 — già su disco).

### Task 8 — re-cluster Stadio 3 → v5 (~6h)
Script: `analysis/p4-fase-f6-stage3-reclustering.R` (lo stesso del v4: chiama già
`recover_identity` → eredita ChEMBL automaticamente).
- **2 micro-edit allo script PRIMA del run** (vedi plan Task 8):
  1. **Assert fail-loud** all'inizio: `stopifnot("ChEMBL dict mancante" = isTRUE(.load_ontology_dicts()$has_chembl))`
     — così non si produce mai v5 in qualità-v4 per errore (il loader è graceful: senza
     questo assert girerebbe senza ChEMBL silenziosamente).
  2. **Token output `v5`** nel nome della dir di output (il run è deterministico → run_id =
     v4 `364547a7`; disambigua la dir col token `v5`, come fu fatto per `v4`).
- Smoke prima del full: `SMOKE=1 Rscript analysis/p4-fase-f6-stage3-reclustering.R` (~2-3 min,
  sanity scomposizione: deve mostrare agent_id CHEMBL:/CHEBI: nuovi + small_molecule|UNK sciolto).
- Full: `SMOKE=0 Rscript analysis/p4-fase-f6-stage3-reclustering.R` **detached**
  (`setsid nohup ... &`), log gitignored. Wall atteso ~6h (Phase 6 summarize domina, come v4).
  Output `analysis/p4-output/…-stage3-v5-<id>/`.
- Verifica nel `run_metadata.json`: `ontology_releases` include `chembl`; `has_chembl=TRUE`;
  cache lookup `v2`. Sanity: `agent_id_resolved` con CHEMBL:/CHEBI: nuovi.

### Task 9 — re-pool Stadio 4 Layer A → v5 (~11h)
- Crea `analysis/p4-fase-f5-stage4-layer-a-rebuild-v5.R` = **copia** del `-v4` con il solo
  cambio: `stage3_dir` → dir v5 (Task 8) + token output `v5`. **Output su `/sda`** (NVMe ha
  poco margine).
- Il **fix df-residui + tryCatch è GIÀ committato** (`0c41848`) → Stadio 4 v5 non ri-crasha
  sullo studio degenere 1+1.
- Smoke gate pre-fullrun (pattern F5: poche cluster, gene axis Ensembl). Poi full **detached**
  (~11h). Backup protettivo su `/sda`.

### Task 10 — re-gate omogeneità v5 + closeout
- `Rscript analysis/audit/stage3-homogeneity-check.R <dir-v5> <h5> Inf Inf <stage2-master-v3>`
  → confronto apples-to-apples v4→v5 (riusa gli output `-v4-full-out` già in `analysis/audit/`).
- **Criterio**: `small_molecule` scende nettamente sotto il 49% v4; gli altri kind perturbativi
  non peggiorano. Riporta la tabella v4→v5.
- Closeout: aggiorna `CLAUDE.md` + `docs/RED_ALERT.md` + `.superpowers/sdd/progress.md` +
  memoria `[[project_stage3_minestrone_rework]]`.

## Note operative critiche

- **Run pesanti detached** (`setsid nohup`), monitoraggio orario session-only. La fase
  per-studio dello Stadio 4 è **muta** ~30-90 min (NON è un blocco).
- **Disco**: output pesanti su `/sda` (4TB liberi), NON su NVMe `/`. Osservazione non
  confermata: durante la scrittura Stadio 4 il FS NVMe ha dato ENOENT transitori sotto I/O
  pesante (FS sano, dati integri) — se ricapita, verificare con I/O calmo prima di concludere.
- `kind_by_gsm` nello script di re-cluster va costruito come **environment** (non named list)
  per evitare O(n²) al full run (già così nel v4 — confermare).
- Master invariato, no `--no-verify`. (Push: vedi sotto — da questa sessione in poi il push lo
  fa l'utente, come da convenzione, salvo richiesta esplicita.)

## Se serve ricostruire il dict ChEMBL
Il `.db` da 30G è stato scartato ma il **tarball** è su `/sda`:
`/mnt/wwn-0x5000039d58caca35/chembl_download/chembl_37_sqlite.tar.gz` (SHA256 in provenance).
Estrai il `.db`, poi `CHEMBL_SQLITE=<path-al-.db> Rscript analysis/p5-audit-chembl-build-dict.R`.

## End-state pianificato (NON questa sessione)

1. **TODO biologici (citochine/patogeni + fix-tipo K3)** — small_molecule mal-etichettati
   (LPS/TNF/IL → pathogen/cytokine) + un vocabolario/fonte per i biologici. È dove
   `cytokine_stim` resta ~64%. Sessione futura, **brainstorming dedicato**.
2. **🔑 LLM-fallback FINALE (DECISIONE C, generale)** — vedi sezione dedicata sotto.
3. **Scelta DB small-molecule** — è in corso una **deep research** (prompt dedicato, vedi
   `2026-06-28-deep-research-small-molecule-db-prompt.md`) per validare/estendere ChEMBL.

## 🔑 LLM-fallback finale (promemoria utente, da NON dimenticare)

Dopo TUTTO il recupero **deterministico** (MeSH per le malattie, ChEMBL/ChEBI per i farmaci,
ed eventuale vocabolario biologici), le occorrenze **ancora non-deterministiche** — cioè i
residui `STR:`/`UNK` di **disease + small molecule + farmaci** (oggi ~36% dei drug-name,
~53-70% in altri kind) — si tentano di recuperare **con un LLM**, come passo FINALE,
**precision-gated** (l'LLM propone, ma la decisione resta validata contro ontologia/regole per
non re-introdurre allucinazioni). Infrastruttura già esistente: `analysis/audit/name-recovery-llm-benchmark.R`
(Task 12, eval fuori produzione, GATED su gold + endpoint). Questa è la "DECISIONE C" del rework,
qui generalizzata a **tutti e tre** i tipi di entità, da fare **alla fine** dell'intera catena
deterministica. È un passo separato, da brainstorming dedicato, NON in questa sessione v5.

## Riferimenti
- Spec/plan/HUMANE: `docs/superpowers/{specs,plans}/2026-06-28-stage3-perturbative-name-recovery-B-*`.
- Ledger esecuzione: `.superpowers/sdd/progress.md` (sezione PLAN B, Task 1-7 + stoplist + closeout sessione 20).
- Memoria: `[[project_stage3_minestrone_rework]]`.
- Deep research DB small-molecule: `docs/superpowers/specs/2026-06-28-deep-research-small-molecule-db-prompt.md`.
