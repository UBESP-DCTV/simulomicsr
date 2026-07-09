# Handout — v9 FASE D (run pesanti gated) — PROSSIMA SESSIONE

**Data:** 2026-07-09
**Branch:** `review-scientific-consistency-2026-06-10` — **HEAD `804c16a`** — master invariato, **NO push**
**Stato:** tutto il **codice v9 è completo e reviewato** (Tasks 3-10 + man/sync + final review opus + guard #2).
Restano solo i **run pesanti gated** della Fase D (Task 11-15). Questa sessione li ha lasciati al gate utente.

> Leggere PRIMA il ledger `.superpowers/sdd/progress.md` (sezione finale "FINAL whole-branch review" +
> "SESSIONE v9 CODICE COMPLETA"), la spec `docs/superpowers/specs/2026-07-09-stage3-v9-final-llm-name-recovery-design.md`
> e il plan `docs/superpowers/plans/2026-07-09-stage3-v9-final-llm-name-recovery-plan.md` (§FASE D).

---

## 0. Idea in una riga

Portare le correzioni-nome di Mistral (side-table, run T13) **dentro** la pipeline: overlay GSM→identità
sul `recovery_lookup` → il re-cluster Stadio 3 produce meta-analisi con il nome giusto **e** i frammenti
della stessa entità (splittati sotto nomi-spazzatura) **si fondono**. Provato end-to-end nello smoke del
Task 9 (26 GSM → 5 cluster materializzati con l'ID corretto; spariscono senza overlay).

## 1. Cosa è già fatto (codice, tutto review-clean)

- **Fix deterministici (Fase A):** `STR:` per target genetici mediati ignoti a HGNC; prefisso ChEMBL
  uniforme a `CHEMBL:` (era misto). Cache lookup bumpata **v5→v6** (Task 3).
- **Overlay (Fase B):** `R/stage3-name-cleanup-overlay.R` — `.side_table_to_recovery_overlay()`
  (side-table→GSM→identità, **solo `action=="override"`**) + `.overlay_recovery_lookup()` (LLM vince
  sul deterministico, in-place).
- **Triage (Fase C):** `R/stage3-suspect-triage.R` — `.build_suspect_triage()` (suspect/canary/skip su
  colonne clusters.rds, NO H5; canary-safety provata da round-trip col consumer non-modificato).
- **Script:**
  - `analysis/p4-fase-f7-stage3-v9-pre.R` — re-cluster v9-pre (deterministico, **NO overlay**).
  - `analysis/p4-fase-f7-stage3-v9-final.R` — re-cluster v9-final (**con overlay**; env `SIDE_TABLE`
    + `STAGE3_V9PRE_DIR`).
  - `analysis/p4-fase-f5-stage4-layer-a-rebuild-v9.R` — re-pool Stadio 4 v9 (env `STAGE3_DIR` =
    dir v9-final; out `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v9`).
  - `analysis/p5-name-cleanup-run.R` — parametrico (env `TRIAGE`/`STAGE3`/`STAGE2`); azioni
    `triage` (genera CSV v9 da `.build_suspect_triage`), `submit`, `eval`.
- **Final review (opus):** ✅ pronto per i run gated, nessun blocker. Data-flow, **canary safety** e
  **precision-gate** verificati coerenti end-to-end.

## 2. 🔴 PRE-FLIGHT OBBLIGATORIO (zero-compute) prima dei ~25h — dalla final review

L'overlay corregge **ID + nome** (provato). MA il `kind` proposto da Mistral entra nell'anchor in
vocabolario **grezzo** (`cytokine`, `gene_mutation`), non nell'enum canonico. Impatto misurato sul
side-table T13 (83 override): ~6% (4 citochine + 1 mutazione) → ID corretto ma kind disallineato →
**merge mancato** (NON corruzione). Rischio latente: `genetic_variant` grezzo potrebbe iniettare un
kind non-anchor.

**Al Task 13, dopo aver ottenuto il side-table v9** (Task 12): stampare
`table(side$new_kind[side$action=="override"])`. Il **branch (b)** di `.extract_anchor_segments`
(`R/stage3-anchor-levels.R`) sovrascrive `kind_effective` solo se `recovery$kind` inizia con
`genetic_` o è in `.biological_override_kinds` (`cytokine_stim`, `pathogen_or_aggregate_exposure`).
- Se **ogni** valore che farebbe scattare (b) è già in
  `{genetic_knockdown, genetic_knockout, genetic_overexpression, crispra_activation,
  crispri_repression, cytokine_stim, pathogen_or_aggregate_exposure}` → **procedere**.
- Se compaiono `cytokine`/`pathogen` **grezzi** o `genetic_variant`/`gene_mutation`/`gene_*` →
  applicare una **canonicalizzazione STRETTA** (~3 righe) in `.side_table_to_recovery_overlay`:
  `cytokine`→`cytokine_stim`, `pathogen`→`pathogen_or_aggregate_exposure`; **scartare** i valori
  genetic non-anchor (così (b) fa no-op invece di iniettare). ⚠️ **NON** usare
  `.canonicalize_resolver_kind` (mapperebbe genetic→`genetic_perturbation`, che NON è un kind-anchor →
  reintrodurrebbe il problema). TDD, poi ri-verifica suite `name-cleanup|anchor|stage3`.

## 3. Sequenza FASE D (ogni step è un GATE utente separato)

### Task 11 — Build v9-pre (~8h, `setsid`, LOOP DI MONITORAGGIO OGNI ORA)
Comando (detached, log su file):
```bash
cd /home/user/simulomicsr
SMOKE=0 setsid bash -c 'Rscript analysis/p4-fase-f7-stage3-v9-pre.R \
  > analysis/p4-fase-f7-stage3-v9-pre-fullrun.log 2>&1' < /dev/null &
```
Poi **verificare SID==PID** e monitorare via `pgrep -f 'p4-fase-f7-stage3-v9-pre'` (NON via PID; NON
usare `run_in_background` per il polling — le notifiche background non funzionano, memoria
`feedback_bash_background_notifications` + `feedback_setsid_for_long_detached_runs`).

**Loop di monitoraggio ogni ora** (il run `setsid` NON è tracciato dall'harness → serve un check
attivo): dopo il lancio, usare `ScheduleWakeup(delaySeconds=3600, reason="check build v9-pre")` e ad
ogni risveglio:
1. `pgrep -f 'p4-fase-f7-stage3-v9-pre'` → vivo? (assente = finito o crashato)
2. `tail -30 analysis/p4-fase-f7-stage3-v9-pre-fullrun.log` → avanzamento / errori / "FINE. Wall totale".
3. se ancora vivo → ri-schedulare `ScheduleWakeup(3600)`; se finito → verifica sotto e **stop del loop**.

**Verifica a completamento** (~400-475 min attesi, come v5/v7):
- dir `analysis/p4-output/<ts>-stage3-v9pre-<run_id>/` con `clusters.rds` + `assignments.parquet`.
- `run_metadata.json`: cache lookup **v6** materializzata, ontologie reali (is_fixture=false).
- sanity: `agent_id_resolved` ha `STR:` e `CHEMBL:` (maiusc), **0** `ChEMBL:` (misto).
- **STOP al gate** — annota la dir v9-pre e passa il controllo per il Task 12.

### Task 12 — Mistral sui sospetti v9 (DGX, ~minuti, GATE)
⚠️ **Prerequisito DGX**: un nodo che SCRIVA i log slurm. Il 2026-07-06 poddgx02 era rotto (0:53
zero-log, rete NFS/bond1 down — vedi memoria `dgx_storage_projects_not_home`). Verificare il nodo
PRIMA (provare poddgx01/03 o `dgx_config(nodelist=...)`).
```bash
# 1) genera il triage v9 dai cluster v9-pre (l'azione triage ha un guard anti-clobber: TRIAGE va settato)
STAGE3=<dir v9-pre> TRIAGE=analysis/audit/2026-07-09-stage4-popB-coherence-triage-v9.csv \
  Rscript analysis/p5-name-cleanup-run.R triage
# 2) submit + eval (dopo COMPLETED)
STAGE3=<dir v9-pre> TRIAGE=analysis/audit/2026-07-09-stage4-popB-coherence-triage-v9.csv \
  Rscript analysis/p5-name-cleanup-run.R submit
STAGE3=<dir v9-pre> TRIAGE=analysis/audit/2026-07-09-stage4-popB-coherence-triage-v9.csv \
  Rscript analysis/p5-name-cleanup-run.R eval   # -> side-table v9 (SIDE_RDS)
```

### Task 13 — Gate di validazione (validate-before-fullrun)
- **PRE-FLIGHT kind (§2 sopra) — obbligatorio.**
- Canary: sul side-table v9 i canary devono dare **0 `override`** (0 falsi allarmi).
- Fusioni: `.measure_fragmentation(side_v9, k_by_cluster)` → le entità note si fondono? k sale?
- **GO/NO-GO esplicito all'utente.** Se non netto → STOP + report.

### Task 14 — Re-cluster v9-final + re-pool Stadio 4 v9 (GATE, ~ore, `setsid` + loop orario)
```bash
SIDE_TABLE=<side-v9.rds> STAGE3_V9PRE_DIR=<dir v9-pre> SMOKE=0 setsid bash -c \
  'Rscript analysis/p4-fase-f7-stage3-v9-final.R > ...v9-final.log 2>&1' < /dev/null &
# poi (dir v9-final prodotta):
STAGE3_DIR=<dir v9-final> setsid bash -c \
  'Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v9.R > ...rebuild-v9.log 2>&1' < /dev/null &
```
Verifica anti-stale re-pool: `Methods` include `rem_group`, ~885 Layer A, entità note più potenti.
Riusa la cache counts (method-independent). Stesso pattern loop-orario del Task 11.

### Task 15 — Closeout
Re-gate omogeneità/frammentazione v9 vs v8; finding + ADR + CLAUDE.md + ledger + memorie. Layer B =
plan separato a valle.

## 4. Note operative (non negoziabili)

- **`setsid`** per i run multi-ora (verifica SID==PID); monitor via `pgrep` sul nome script, **loop
  orario via `ScheduleWakeup(3600)`**. NON `run_in_background` per il polling.
- **NON delegare i run pesanti ai subagent**: in Fase C i subagent hanno messo in background le run
  foreground 4 volte (le notifiche background non arrivano ai subagent) → guidarli dal coordinator.
- **R con renv** (no `--vanilla`) sul laptop.
- Dopo QUALSIASI modifica ad anchor/stage3 → suite **COMPLETA** `name-cleanup|anchor|stage3` (i filtri
  stretti hanno mancato regressioni cross-file). Baseline verde = `N PASS + 1 FAIL (perf-budget stale,
  pre-esistente, non-regressione) + 2 SKIP`.
- **Vietato** `git checkout <ref> --` / `git stash`. Commit a piccoli passi, **no push**, master invariato.
- Input presenti su disco: stage1 master `p4-fase-f2-stage1-master-predictions-rescued.jsonl`, stage2
  master v3 `p4-fase-f4-stage2-master-v3.jsonl`, H5 `human_gene_v2.5.h5`, dizionari ontologia (has_chembl/
  taxonomy/immport/uniprot/go = TRUE).

## 5. Riferimenti

- Ledger: `.superpowers/sdd/progress.md` (autoritativo; final review + findings + pre-flight).
- Spec/plan: `docs/superpowers/{specs,plans}/2026-07-09-stage3-v9-final-llm-name-recovery-*`.
- Macchinario name-cleanup T13: `R/name-cleanup.R`, `analysis/p5-name-cleanup-run.R`,
  finding `docs/findings/2026-07-07-name-cleanup-results.md`.
- Re-pool v8 (base del v9): ADR-0022, `docs/findings/2026-07-06-stage4-rem-group-results.md`.
- Memorie: `project_stage3_minestrone_rework`, `feedback_validate_before_fullrun`,
  `feedback_setsid_for_long_detached_runs`, `feedback_bash_background_notifications`,
  `feedback_bump_lookup_cache_version`, `feedback_no_fretta_paper_grade`,
  `dgx_storage_projects_not_home`.
