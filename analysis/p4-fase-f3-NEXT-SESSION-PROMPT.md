Continua RED ALERT FASE F, sessione 12. Lavori passo passo, una task alla volta, mai alla successiva senza che te lo dica io. Risposte concise, no claim non guadagnati, no "ottimo/perfetto". Parli a un bioinformatico in modo UMANO e discorsivo, NON per nomi di variabili e sigle (cito file:linea solo per indicarti un punto preciso). Se non sai una cosa vai a guardare il codice e cita file:linea — non ipotizzare.

⚠️ SCIENZA NON PRODOTTI. RIGORE NON VELOCITÀ. Tempo quanto ne vuoi. Niente shortcut. Validation gate fra ogni step. Audit before patch: 2+ bug nella stessa area = STOP, cerca il pattern. Codice robusto, non bello.

LETTURA OBBLIGATORIA prima di agire, in quest'ordine:
  1. CLAUDE.md (banner RED ALERT — stato fine sessione 11: F3 Stadio 2 fullrun v2 + rescue 100%).
  2. docs/RED_ALERT.md §FASE F (F1 ✅, F2 ✅, F3 ✅, F4 ⬜) + §"Come Claude si deve comportare" + §Handoff sessione 12 = F4.
  3. NEWS.md entry 0.0.0.9029 (F3).
  4. docs/decisions/0018-llm-anchor-ontology-override.md + 0019-archs4-metadata-exploitation-v2.md (anchor v3.1.1, dedupe SAMN, covariate — già implementati in FASE E + S1bis/S2bis).
  5. Memorie: feedback_parla_umano_non_sigle, feedback_validate_before_fullrun, feedback_no_fretta_paper_grade, feedback_bash_background_notifications, project_llm_anchor_classification_audit, project_pipeline_trust_audit_session1.

STATO POST-SESSIONE 11 (committato, branch ahead master, master git invariato, no push):
- Master Stadio 1 v2 (F2): analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl (508.037 record, 100% validi, gitignored).
- Master Stadio 2 v2 (F3): analysis/p4-output/p4-fase-f3-stage2-master-rescued.jsonl (28.567 record, 100% schema-validi, 24.394 studi, gitignored). Colonna rescue_source su 59 record.

SCOPO SESSIONE 12 — F4 Stadio 3 rebuild. Rebuild build_stage3_clusters() con:
  (a) anchor v3.1.1 + resolver v1.1.0 (già implementati: R/anchors.R, R/ontology-lookup.R, ADR-0018/0019 — verificare che siano agganciati);
  (b) i nuovi Stadio 1 (F2) + Stadio 2 (F3) come input al posto dei master β;
  (c) dedupe BioSample SAMN (E0/E0b) + covariate metadata C3 (per F5).
Output: nuovo clusters.rds cross-studio clean.

### Step 1 — Audit input loader Stadio 3 (PRIMA di lanciare)
Lo Stadio 3 oggi legge i master β: verifica e ripunta ai master v2 F2/F3. ⚠️ ATTENZIONE FORMATO: F3 è un JSONL (28.567 record), il β stage2 era un collect.rds (data.frame). Va adattato .load_stage2_master al JSONL o convertito. Cita file:linea dei punti che cambi. NIENTE run a questo step — mostrami cosa va cambiato e perché.

### Step 2 — Completeness guard Stadio 2 (deferred da F2 §4.3)
Valuta se agganciare complete_stage2_coverage/audit_stage2_coverage nel path Stadio 3 quando .load_stage2_master preserva record_id (chunk-aware). Vedi docs/findings/2026-05-28-f2-stage1-prompt-fragility.md §4.3. Proponi, non implementare senza ok.

### Step 3 — Rebuild Stadio 3 (gate utente)
Solo dopo OK sugli step 1-2: rebuild clusters.rds. Stadio 3 è locale/CPU (no DGX). Confronta i conteggi cluster col baseline v3.1.1 (390.532 cluster da run 2655ecb0) e spiega le differenze attese (input cambiato: meno studi, single-cell rimossi a monte). Validation gate prima di considerarlo chiuso.

GATE: prima di ogni run mostrami cosa cambia + perché. Una cosa alla volta. Decisioni non banali = problema + opzioni + preferenza + aspetta.

REGOLE CHIAVE: italiano nei commenti/commit; prompt LLM invariati; commit atomici "P5 audit RED_ALERT F4: <azione>"; MAI git push; MAI --no-verify; master git invariato; parla umano; notifica mobile quando aspetti input.

PRIMO STEP: leggi i file obbligatori, conferma stato, e presentami il piano F4 (audit input loader → completeness guard → rebuild) PRIMA di toccare codice di produzione.
