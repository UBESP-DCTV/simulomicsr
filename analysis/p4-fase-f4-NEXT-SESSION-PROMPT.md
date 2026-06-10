# Prompt prossima sessione (sessione 14) — RED ALERT F4 opzione C: collect fullrun → master v3 → F4/F5

Continua RED ALERT FASE F, sessione 14. Lo Stadio 2 v3 (opzione C: condizioni di
design deduplicate, niente chunking per-campione) è stato implementato e validato
allo smoke gate nella sessione 13; il **fullrun sul DGX è stato lanciato a fine
sessione 13**. Questa sessione: raccogliere il fullrun → assemblare il master
Stadio 2 v3 → poi F4 (Stadio 3) e F5 (Stadio 4). Passo passo, una cosa alla volta,
mai alla successiva senza che te lo dica io. Risposte concise, niente claim non
guadagnati, niente "ottimo/perfetto". Parli a un bioinformatico in modo UMANO e
discorsivo, NON per sigle (cito file:linea solo per indicare un punto). Se non sai
una cosa, vai a guardare il codice e cita file:linea — non ipotizzare.

⚠️  SCIENZA NON PRODOTTI. RIGORE NON VELOCITÀ. Tempo quanto serve. Niente shortcut.
Validation gate fra ogni step. Audit before patch (2+ bug stessa area = STOP, cerca
il pattern). Codice robusto, non bello. Spec/ADR prima del codice; cambi al prompt
LLM SEMPRE sotto gate esplicito (estrazione verbatim + diff + mio OK). Italiano in
commenti/commit. Commit atomici "P5 audit RED_ALERT F4 (opzione C): ". MAI git
push, MAI --no-verify, master git invariato. Notifica mobile quando aspetti input.

LETTURA OBBLIGATORIA prima di agire, in quest'ordine:
1. CLAUDE.md (banner — stato fine sessione 13: opzione C fino a smoke gate PASS).
2. docs/RED_ALERT.md §F4 (🟢 sessione 13) + §"Come Claude si deve comportare" +
   §"Handoff sessione 14".
3. analysis/audit/F4-stage2-smoke-v3-eval.md (smoke gate: 94,04% = baseline F3, PASS).
4. docs/decisions/0020-stage2-design-signature-dedup.md (decisioni D1-D4 + namespacing,
   tutte DECISE) + spec/HUMANE 2026-06-02-stage2-design-signature-dedup-*.
5. Memorie: project_singlecell_escapees_stage0, project_pipeline_trust_audit_session1,
   feedback_no_fretta_paper_grade, feedback_validate_before_fullrun,
   feedback_audit_before_patch_cycle, feedback_explain_then_decide,
   feedback_bash_background_notifications, feedback_pipeline_config_uniformity,
   feedback_dgx_respect_plan_time.

STATO (fine sessione 13, branch p5-llm-anchor-classification-audit, master git
invariato, no push):
- **Fullrun Stadio 2 v3 SUBMITTATO** sul DGX a fine sessione 13 (2026-06-10), stato
  RUNNING. **slurm 24022**, run_id `20260610T120031Z-f4-stage2-fullrun-v3-5f166e`,
  job RDS `analysis/p4-output/20260610T120031Z-f4-stage2-fullrun-v3-5f166e-job.rds`.
  Input:
  `analysis/input/archs4-human-stage2-input-v3.jsonl` (24.972 record, gitignored).
  Config invariata (tiered_max_tokens, temp=0, rep_pen=1.1, 4-worker, time 72h).
  Atteso più veloce di F3 (meno tier XL: lo smoke aveva S=66/M=4/L=1/XL=1 su 72).
  Re-submit/stato: `Rscript analysis/p4-fase-f4-stage2-fullrun-v3.R` (resume-safe).
- Tutta la logica opzione C è committata + testata (179 expect_*):
  `design_signature` + `.build_study_conditions` + `.chunk_conditions`/
  `.is_control_condition` + `.expand_study_design`/`.merge_chunked_designs`/
  `.assemble_stage2_study` + guard `.assert_stage2_one_record_per_series`.
- Smoke script `analysis/p4-fase-f4-stage2-smoke-v3.R` contiene `assemble_master()`
  (orchestrazione collect→master) + `eval_v3()`, validati. Da PROMUOVERE/riusare
  per il collect del fullrun.
- Master F2 Stadio 1 invariato. Il master F3 chunked NON va usato.

SCOPO SESSIONE 14 — gated, una cosa alla volta:
1. **Stato fullrun**: controlla il job (`dgx_p4_status`). Se ancora in corso,
   stima e aspetta (monitoraggio non reattivo, come F3). Se COMPLETED → collect.
2. **Collect**: `dgx_p4_collect` → predictions.jsonl. Misura schema validity +
   eventuali fail (come F3 ~99,87%).
3. **Rescue cascade** (se fail, come F3): cs25 resplit / cascade rep_pen — ma
   attenzione: in v3 i record sono per-studio, il resplit va ripensato (un record
   = uno studio; il rescue è su record interi, non chunk cs50). Valuta con me la
   strategia rescue prima di applicarla (audit-before-patch).
4. **Assembly → master v3**: promuovi `assemble_master()` dello smoke script a uno
   script collect→master committato (`p4-fase-f4-stage2-collect-v3.R`): legge input
   v3 + predictions → `.assemble_stage2_study` per series → **master Stadio 2 v3
   (1 record/studio)**, schema stage2.v2. Sanity: 1 record/series (il guard
   fail-loud lo verifica a valle), copertura campioni. Deliverable gitignored.
5. **STOP gate** prima di F4.
6. **F4 (Stadio 3 rebuild)** sul master v3 + anchor v3.1.1. PRIMA: adattare il
   completeness guard a `member_sample_ids` (TODO tracciato: oggi
   `.build_stage2_input_lookup` legge geo_accession = rappresentante in v3; per il
   guard servono i GSM reali). Poi rebuild Stadio 3.
7. **F5 (Stadio 4)** sul nuovo Stadio 3.

GATE: prima di ogni run mostrami cosa cambia + perché. Decisioni non banali =
problema + opzioni + preferenza + aspetta. TODO tracciati da non perdere:
completeness guard member_sample_ids (F4); indagine single-cell Stadio 0
(~313 studi degeneri, memoria project_singlecell_escapees_stage0).
PRIMO STEP: leggi i file obbligatori, controlla lo stato del fullrun, riportami
dove siamo.
