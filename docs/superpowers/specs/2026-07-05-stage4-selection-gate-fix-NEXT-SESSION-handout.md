# Handout — Prossima sessione: FIX gate di selezione Stadio 4

**Data:** 2026-07-05
**Per:** sessione dedicata al fix (brainstorming → spec → plan → run gated)
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Finding base (LEGGERE PRIMA):** `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`

> **Ordine deciso con l'utente:** (1) questa sessione = fix Stadio 4; (2) sessione dopo = pulizia-nomi
> con Mistral (handout separato `2026-07-06-name-cleanup-mistral-SESSION-AFTER-handout.md`). Il fix
> Stadio 4 va PRIMA: sblocca ~187 meta-analisi omogenee subito, mal-nominate o no.

## In una frase

Lo Stadio 4 processa 433/317.304 cluster e la porta di selezione respinge *tutte* le meta-analisi
nominate (SARS-CoV-2, enzalutamide, Breast Neoplasms…): tiene solo 72 MEGA grossolani, di cui **71
senza nome**. Va ridisegnata la porta di ammissione + gestito il lato-controllo dei cluster treated-only.
**NON partire a codare: è una decisione architetturale → brainstorming skill + gate utente.**

## Il difetto in 3 righe

- `.identify_layer_a_clusters` (`R/stage4-qc.R:11-40`) ammette MEGA solo con `usable_mega_strict`, che
  richiede `level∈{0,1}` **e** `safety_min≥0.7`. I cluster nominati vivono a L2–L4 con safety 0.14–0.39.
- `usable_mega_relaxed` (no vincolo livello, safety≥0.5) è calcolato ma **mai consumato**. Idem pair k≥3.
- Concetto: soglia 0.7 è logica MEGA (pooling congiunto, serve omogeneità). Questi sono target **REM**
  (modella l'eterogeneità). Si sta scartando l'eterogeneità invece di modellarla.

## Scope reale del fix — due sotto-popolazioni (dai dati, §4 del finding)

Il MEGA richiede treated+control nel cluster (`.check_mega_rank`, `R/stage4-orchestrator.R:205`). Dei 650
cluster candidati (Pop B = group nominati k≥3 che falliscono relaxed):

- **208 both_roles** (malattie soprattutto: Breast/Prostata/Alzheimer): hanno già caso+normale →
  **poolano in MEGA appena ammessi**. Parte economica del fix (basta la porta).
- **295 treated_only** (farmaci soprattutto: enzalutamide/fulvestrant/tamoxifen/estradiol/vemurafenib):
  gruppo trattato senza controllo → serve un **lato-controllo**. Parte architetturale.
- 118 vehicle_only → **escludere** (non perturbazioni).

## Decisioni da prendere (BRAINSTORMING, gate utente) — NON pre-decise

1. **Nuova porta di ammissione.** Sostituire il gate `level∈{0,1} + safety≥0.7`. Candidati:
   consumare `usable_mega_relaxed`/`usable_rem_relaxed` k≥3; oppure una porta nuova basata sulla
   **coerenza** (support entità via sinonimi ontologici + non-vehicle/broad) al posto di `safety_min`
   — vedi anche il gate di omogeneità già esistente (`analysis/audit/stage3-homogeneity-check.R`) e la
   metrica di consistenza F6 (`R/stage4-consistency.R`, ADR-0021).
2. **Lato-controllo per i 295 treated_only.** Opzioni:
   - **(A) group-MEGA-augmented**: estendere l'augmentation baseline-pool (oggi solo `mega_aug`/pair
     k==2, `R/stage4-mega-aug.R` + `.assemble_mega_aug_metadata_bidir`) ai gruppi trattati multi-studio.
     Riusa macchinario esistente; resta pooling congiunto.
   - **(B) group-REM**: per ogni studio, contrasto trattato-vs-controllo *dello stesso studio* (il
     controllo vive in un cluster/record fratello) → effect size per-studio → REM su k studi
     (`.pool_rem_cluster`, `R/stage4-rem-pooling.R`, `metafor`). Statisticamente il più corretto per
     eterogeneità alta; richiede linkare treated-group ai controlli per-studio (oggi non fatto per group).
   - **(C) ibrido per struttura**: both_roles→MEGA, treated_only con controllo per-studio→REM,
     treated_only senza→augmented o scartato.
   - Preferenza da discutere: il goal è "meta-analisi robuste, meglio poche che minestrone" — REM è
     l'onesto per l'eterogeneità cross-studio, ma verificare la fattibilità del linking per-studio.
3. **Soglie minime** (k min, n_control min per studio: SARS ha 68 treated + solo 2 control → attenzione
   al bilanciamento) e cosa fare dei borderline.
4. **Dedup gerarchica L2/L3/L4**: 650 cluster = 197 entità (stessa entità a più livelli). Decidere se
   poolare a un livello per entità (quale?) o tutti — evitare di ri-processare lo stesso effetto 3 volte.

## Workflow suggerito

1. `superpowers:brainstorming` sulle 4 decisioni sopra → spec design + HUMANE + ADR (Proposed).
2. `superpowers:writing-plans` → plan task-by-task (TDD).
3. Implementazione (subagent-driven o TDD diretto), suite verde.
4. **Smoke gate** su un sottoinsieme (validate-before-fullrun): verificare che enzalutamide/SARS/Breast
   entrino e poolino con effect size sensati + I²/τ² ragionevoli.
5. **RUN GATED** re-pool Stadio 4 (~11h su `/sda`, gate utente): riusare/adattare lo script v7
   (`analysis/p4-fase-f5-stage4-layer-a-rebuild-v7.R` — nota: NON richiede re-cluster Stadio 3, il v7 va
   bene). Output nuovo `-stage4-v8` su `/sda`.
6. Re-gate + finding + CLAUDE.md + ledger + memoria.

## Stato verificato (fine sessione 2026-07-05)

- Input pronti: Stadio 3 v7 (`…20260703T113045Z-stage3-v7-364547a7/`), Stadio 2 master v3
  (`analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`), H5 (`analysis/input/human_gene_v2.5.h5`).
- Il fix **NON richiede un nuovo re-cluster Stadio 3**: i cluster v7 sono omogenei; si cambia solo la
  selezione + il pooling a valle. Basta un re-pool Stadio 4.
- Evidenza coerenza persistita: `analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv` (197 entità
  con homog/tema/nome-ok) + script `-coherence-check.R`/`-nametail.R`.
- Nessun codice del fix scritto. Nessun run lanciato. Master invariato, no push.

## Note operative

- **Dischi**: Stadio 4 output su `/sda` (NVMe `/` non basta). Stage3 v7 su `analysis/p4-output/`.
- **Run detached**: usare `setsid` per i multi-ora (memoria `feedback_setsid_for_long_detached_runs`),
  NON `run_in_background`. Monitorare via `pgrep` sul nome script.
- **DGX**: alternativa al laptop per il re-pool (2TB RAM, memoria `user_dgx_backup_2tb`) se serve.
- **Ledger**: `.superpowers/sdd/progress.md`. Memorie: `[[project_stage3_minestrone_rework]]`,
  `[[feedback_validate_before_fullrun]]`, `[[feedback_explain_then_decide]]`.
