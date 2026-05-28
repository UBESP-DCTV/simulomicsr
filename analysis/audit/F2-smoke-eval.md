# F2-smoke eval --- 100-sample gate (RED ALERT FASE F2, sessione 9)

> Data: 20260528T222542Z. Branch p5-llm-anchor-classification-audit.
> Config invariata (temp=0, rep_pen=1.1, microbatch=50, s2 tiered_max_tokens).
> Prompt: D1b molecule_hint (Stadio 1) + D3 EN (Stadio 2). load_all branch.

## Track 1 --- mini-gold (accuracy gate)
- Schema validity: s1 100.00%, s2 100.00%
- Accuracy binaria: **92.93%** (92/99 evaluable)
- Sensitivity 91.8% / Specificity 94.7%
- Baseline alpha cs50 = 96.7%. Soglia STOP = 93%.
- run_id s1=20260528T202554Z-f2-smoke-minigold-s1-80bedb s2=20260528T202817Z-f2-smoke-minigold-s2-0c2407
- Limite: mini-gold NON ha molecule_ch1 -> accuracy non testa molecule_hint.

## Track 2 --- bacino v2 (schema/distribution gate)
- 100 random stratificati nchar dal jsonl-v2 (508.037), seed=42
- molecule_ch1 non-NA: 100 / 100
- Schema validity: s1 100.00%, s2 100.00%
- run_id s1=20260528T203039Z-f2-smoke-bacinov2-s1-072da9 s2=20260528T203300Z-f2-smoke-bacinov2-s2-173604
- design_kind distribution:
  - multi_arm_treatment: 24
  - treatment_vs_vehicle: 24
  - case_control_disease: 23
  - treatment_vs_untreated: 9
  - unclear: 9
  - differentiation_course: 5
  - knockdown_panel: 4

## Verdetto gate
- STOP: accuracy 92.93% < 93% -> revisione prompt D1b necessaria.

Gate pre-F2-fullrun: questo risultato + decisione utente esplicita.
