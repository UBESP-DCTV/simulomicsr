# Prompt prossima sessione (sessione 10) — RED ALERT FASE F

> Preparato a fine sessione 9 (2026-05-28/29). Copia-incolla questo come
> apertura. Adatta lo scope (A o B) secondo la tua decisione.

---

Continua RED ALERT FASE F, sessione 10. Lavori passo passo, una task alla
volta, mai alla successiva senza che te lo dica io. Risposte concise, no claim
non guadagnati, no "ottimo/perfetto". Se non sai una cosa vai a guardare il
codice e cita file:linea — non ipotizzare. Parli a un bioinformatico.

⚠️ SCIENZA NON PRODOTTI. RIGORE NON VELOCITÀ. Tempo quanto ne vuoi. Niente
shortcut. Validation gate fra ogni step. Audit before patch: 2+ bug nella
stessa area = STOP, cerca il pattern. Codice robusto, non bello.

LETTURA OBBLIGATORIA prima di agire, in quest'ordine:
  1. CLAUDE.md (banner RED ALERT — stato fine sessione 9: F2-smoke + fix
     is_zero_timepoint + benchmark design-aware 94-96%).
  2. docs/RED_ALERT.md §FASE F (F2 🟡: smoke+fix DONE, fullrun TODO) +
     §"Come Claude si deve comportare" + §Handoff (sessione 10).
  3. docs/findings/2026-05-28-f2-stage1-prompt-fragility.md (root-cause +
     guard + benchmark scalato + completeness guard + raccomandazioni).
  4. NEWS.md entry 0.0.0.9027.
  5. Memorie: feedback_validate_before_fullrun, feedback_dgx_respect_plan_time,
     feedback_no_fretta_paper_grade, feedback_bash_background_notifications.

STATO POST-SESSIONE 9 (committato, branch ahead master 89 commit, master
invariato, no push):
- Fix guard `is_zero_timepoint` (`R/stage1-normalize.R`) attivo nel build
  input Stadio 2. Mini-gold 92.93% → 97.00%.
- Benchmark design-aware scalato: gold 756 sample / 72 studi
  (`analysis/p4-output/f2-eval-gold.csv`), accuracy 94.14% / 96.02%.
- Completeness guard Stadio 2 (`R/stage2-normalize.R`) implementato + testato +
  validato, MA non ancora wired nel path live (vedi sotto, opzione del wiring).
- Deliverable F1 pronto: `analysis/input/archs4-human-stage1-input-v2.jsonl`
  (508.037 record). DGX verificato sessione 8.

---

## SCOPO SESSIONE 10 — scegli tu A o B (o entrambe in ordine)

### Opzione A — F2-fullrun Stadio 1 (508k) — il deliverable principale

Submit del fullrun Stadio 1 sul bacino v2 (508.037 sample) con il prompt
corrente (D1b molecule_hint + D4 + guard is_zero_timepoint a valle). È un run
massivo (~12-15h DGX): VALIDATE-BEFORE-FULLRUN già fatto (F2-smoke PASS), quindi
qui si parte.

Procedura (come il fullrun β, memoria project_vllm_scheduler_deadlock +
scripts/p4-beta-stage1-chunked-tick.sh):
1. Shuffle + chunk del jsonl-v2 (508k) in chunk da ~10k (come β).
   ⚠️ Verifica il filtro outliers nchar>3500 (β li gestiva a parte con
   max_model_len=32768, Task 10b).
2. Chunked orchestrator + cron tick `*/3 * * * *` (cascade COMPLETED→submit).
3. Config INVARIATA (temp=0, rep_pen=1.1; uniformity). time esplicito 72h.
4. Monitoraggio: NON pollare con until-sleep in background; check al turno
   conversazionale (memoria feedback_bash_background_notifications).
5. A fine: master predictions Stadio 1 v2 + rescue cascade se servono fail
   (riusa la strategia H1/H2/H3 della β rescue se emergono LLM fail).

GATE: prima di submittare il fullrun, mostrami il piano chunking + la stima
wall + conferma config. Poi vai.

### Opzione B — Audit qualitativo Stadio 3 sui 72 studi del gold (preview F4)

I 72 studi del benchmark sono ora un set di cui conosco i design a fondo. Far
girare Stadio 3 (clustering cross-studio via comparability_anchor v3.1.1) sui
loro output stage1+stage2 e ispezionare i cluster è un audit qualitativo utile
di Stadio 3 — un assaggio di F4 + del futuro audit Stadio 3.

⚠️ CAVEAT (vedi mia risposta sul clustering, fine doc): il gold sono i
design_role (treated/control), NON gli anchor. Quindi:
- Validabile bene: il within-study (treated/control split corretto?) +
  l'anchor assegnato è sensato?
- NON validabile quantitativamente: il cross-study clustering (servirebbe
  anchor ground-truth non etichettato; 72 studi diversi → pochi cluster
  cross-study).
Quindi B è ESPLORATIVO/QUALITATIVO, non un benchmark. Output: report di
osservazioni su anchor + grouping, da usare per pianificare l'audit Stadio 3.

### Opzione C — wiring completeness guard Stadio 2 a F4

Se vuoi chiudere il completeness guard: wire `audit_stage2_coverage` nel path
live. Richiede prima far sì che `R/stage3-build.R::.load_stage2_master`
preservi `record_id` (oggi riduce a parsed_json), poi match chunk-aware
input/output per record_id. È un cambio di Stadio 3 → va con F4 (rebuild
gated), con TDD + validazione end-to-end. NON farlo isolato senza F4.

---

REGOLE CHIAVE: italiano in commenti/commit; prompt LLM invariati; commit
atomici "P5 audit RED_ALERT F2/F<n>: <azione>"; MAI git push; MAI --no-verify;
master invariato; una cosa alla volta; decisioni non banali = problema +
opzioni + preferenza + aspetta; notifica mobile quando aspetti input.

PRIMO STEP: leggi i file obbligatori, conferma stato, dimmi quale opzione
(A/B/C) e presentami il piano PRIMA di toccare codice di produzione.
