# P4 β Rescue Cascade — Session 2 Handoff

> **Per la prossima sessione Claude Code.** Leggi questo file PRIMA di agire. Lo stato consolidato + cosa fare è qui.

## Stato al session break (2026-05-17, fine sessione 1)

**Branch attivo**: `p4-beta-rescue` (8 commits ahead di master, NON pushed).

**Plan formale**: `docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md`

**Task completati (Session 1)**:
- ✅ Task 1: branch + plan
- ✅ Task 2: classify 1.571 stage1 fails (749 ETL leak / 660 Mode A whitespace / 147 Mode B trunc / 15 other)
- ✅ Task 3+3b: **H2 v2 GSE-level drop** di 72 studi mouse-mislabeled ARCHS4
  - Stage1: 888.821 → **879.167** (−9.654 sample)
  - Stage2-input: 39.205 → **38.963** (−242 record)
- ✅ Task 4: H1 rescue input (822 record, tutti human-classified, 0 overlap con suspect GSE)
- ✅ Task 5+6: **H1 smoke20 = 20/20 = 100% recovery** con `rep_pen=1.2 + max_tokens=4096 + max_model_len=8192` (slurm 21008 COMPLETED 1m39s)
- ✅ Discovery doc: `docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md` — finding paper-grade salvato in memory `project_llm_detected_archs4_mislabeling`

**Cosa devi fare (Session 2)**: Task 7 → 15 nel plan.

## Cold-start procedura

### Step 1: verifica state branch + working dir

```bash
git status                                          # expect clean
git log --oneline -10 | head                        # expect ba75bea..13c664d sequence
git branch --show-current                           # expect p4-beta-rescue
ls analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl   # expect 879167 lines
ls analysis/input/archs4-human-stage2-input-cleaned.jsonl               # expect 38963 lines
ls analysis/input/archs4-human-stage1-rescue.jsonl                      # expect 822 lines
```

Se qualcosa manca, rerunna lo script corrispondente (i nomi sono in `analysis/p4-beta-rescue-*.R`).

### Step 2: Task 7 — submit H1 full retry su 822 record

```bash
Rscript analysis/p4-beta-rescue-h1-stage1-full.R
```

(**NO `--vanilla`** su questa macchina — devtools è in renv lib, non system. Il file è già scritto e idempotente: se il job esiste già, fa resume + status check; se no, submitta nuovo job.)

Output atteso:
- Slurm job_id stampato
- `analysis/p4-output/<run_id>-beta-rescue-stage1-full-*-job.rds` creato
- ETA `~30-60 min wall` (822 record @ 12 rec/min steady, post-boot)

```bash
git add analysis/p4-beta-rescue-h1-stage1-full.R 2>/dev/null  # gia' committato
# Niente da committare se script gia' committato in session 1.
```

### Step 3: aspetta + collect H1 full + merge

Quando job COMPLETED (controlla con re-source di `p4-beta-rescue-h1-stage1-full.R` → printa stato):

```bash
Rscript analysis/p4-beta-rescue-h1-merge.R
git add analysis/p4-beta-rescue-h1-merge.R 2>/dev/null  # gia' committato
```

Atteso: master rescued = 879.167 record con `rescue_source = "h1_rep12_maxtok4096"` su ~820 sample + NA sui restanti. Schema validity finale ~99.97-99.98%.

### Step 4: Task 9 — H3 prep (re-split stage2 fails a cs25)

```bash
Rscript analysis/p4-beta-rescue-h3-build-input.R
git add analysis/p4-beta-rescue-h3-build-input.R 2>/dev/null  # gia' committato
```

Atteso: ~86-100 cs25 chunks da 43 stage2 fails originali. Output: `analysis/input/archs4-human-stage2-rescue-cs25.jsonl`.

### Step 5: Task 10+11 — H3 smoke5 + validate

```bash
Rscript analysis/p4-beta-rescue-h3-stage2-smoke.R   # submit
# aspetta ~10 min, poi:
Rscript analysis/p4-beta-rescue-h3-stage2-smoke-validate.R
```

Threshold GO: recovery >=60% sui 5 smoke chunks. Se NO-GO, investigare (vedi sotto note).

### Step 6: SESSION BREAK 2 (opzionale)

Se smoke H3 ha dato GO, puoi procedere subito a Task 12 (H3 full retry) nella stessa sessione — sono solo ~100 record, ~30 min DGX, totale sessione 2 sotto 2h. Oppure rispetta il pattern `feedback_validate_before_fullrun` e fai un altro break.

### Step 7: Task 12+13 — H3 full + merge

```bash
Rscript analysis/p4-beta-rescue-h3-stage2-full.R   # submit
# aspetta, poi:
Rscript analysis/p4-beta-rescue-h3-merge.R
```

Atteso: master stage2 collect rescued con stage2 validity 99.97%+.

### Step 8: Task 14 — Docs

Update:
- `docs/decisions/0008-vllm-sampling-defaults.md` (addendum 3 — il template è nel plan Task 14 step 1)
- `NEWS.md` (entry 0.0.0.9017)
- `CLAUDE.md` (sezione "Stato corrente" + DONE su decisione rinviata β retry)

### Step 9: Task 15 — Close

```bash
Rscript -e "devtools::test()"                              # expect 585 PASS
git checkout master
git merge --ff-only p4-beta-rescue
git tag -a p4-beta-rescue-complete -m "P4 β rescue cascade complete (~99.97% stage1+stage2)"
# Push remoto: NON fare. L'utente lo fa sempre lui (CLAUDE.md).
```

## Note operative critiche

1. **NO `--vanilla`** su questa macchina (renv intercetta libpath; devtools non è in system libs)
2. **NO `git push`** — l'utente push sempre lui
3. **`dgx_p4_status` ritorna "TERMINATED" per job COMPLETED OK** (bug minor mapping in R/dgx-utils — il job è davvero COMPLETED, verificare con `sacct -j <ID> --format=State,ExitCode -P` se in dubbio)
4. **DGX time = 72:00:00** per default (memoria `feedback_dgx_time_limit_default`)
5. **Memorie chiave da rispettare**:
   - `feedback_validate_before_fullrun` — smoke prima di full
   - `feedback_explain_then_decide` — opzioni con tradeoff prima di scelte non banali
   - `feedback_pipeline_config_uniformity` — H1 retry config è override puntuale, NO propagazione a p4-defaults.yml
   - `feedback_paper_audience_bioinformatics` — paper è per bio, non CS
6. **Discovery 72 mouse-mislabeled GSE** è il finding paper-grade più rilevante della sessione — vedi `docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md` e memoria `project_llm_detected_archs4_mislabeling`. Da includere in paper come Methods/Results section (NON Limitations — contributo positivo).

## File chiave / posizioni

- Plan: `docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md`
- Discovery: `docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md`
- Classified fails CSV: `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv`
- Suspect 72 GSE: `analysis/p4-output/p4-beta-rescue-h2-suspects.rds`
- Master stage1 cleaned: `analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl`
- Stage2-input cleaned: `analysis/input/archs4-human-stage2-input-cleaned.jsonl`
- Rescue input H1: `analysis/input/archs4-human-stage1-rescue.jsonl`
- Smoke H1 job: `analysis/p4-output/20260517T142150Z-beta-rescue-stage1-smoke20-1a92ff-job.rds`

## Numeri target finali post-cascade

| Metric | Pre-rescue | Post H2+H1+H3 atteso |
|---|---|---|
| Stage1 master records | 888.821 | 879.167 + 822 rescued ≈ **879.989** |
| Stage1 schema validity (sui kept) | 99.82% | **~99.98%** |
| Stage2 master records | 39.162 | 38.963 + ~35 rescued ≈ **38.998** |
| Stage2 schema validity (sui kept) | 99.89% | **~99.97%** |
| Mouse contamination | 9.147 sample latent | **0** (72 GSE dropped) |
