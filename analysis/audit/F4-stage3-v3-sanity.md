# F4 Stadio 3 v3 — sanity check pre-F5

> RED ALERT FASE F4, sessione 14 (2026-06-11). Gate prima di F5 (Stadio 4).
> Run `20260611T171555Z-stage3-v3-364547a7` (anchor v3.1.1, resolver v1.1.0,
> stage1 F2 508.037, stage2 master v3 24.394, completeness guard attivo).

## Esito — PASS

| check | esito |
|---|---|
| distribuzione cluster | OK — coda lunga attesa |
| eligibility DE (set candidato F5) | OK — 4.785 usable |
| `n_control=NA` sui group | OK — per-design (mega_aug per-studio) |
| regressione chunk-collision | **PASS** — 0 suffissi chunk, studi de-chunkati coerenti |
| completeness guard | OK — 18.004 → `unclear` (3,5%, = REGOLA 4) |

## Dettaglio

**Distribuzione (292.518 cluster).** Per mode×level: group 257.480 / pair 35.038.
Quasi tutti singoli studio (k mediana 1, media 1,19). Coda multi-studio poolabile:
k≥2 = 14.174, k≥3 = 5.858, k≥5 = 2.738, k≥10 = 1.068. n_total mediana 2, max 9.253.

**Set DE-usable (candidati F5) = 4.785**: 4.074 group (`usable_mega_relaxed`) +
711 pair (`usable_rem_relaxed`); gold-strict: 291 mega + 28 rem. k mediana 2, max 55.

**`n_control=NA` chiarito (era il sospetto principale).** 100% dei cluster group
hanno `n_control=NA` (257.480/257.480), 0% dei pair. È per-design: in group mode il
confronto è per-studio coi controlli augmentati dal pool baseline (mega_aug
bidirezionale, ADR-0016) → a livello cluster `n_treated` è il pooled trattati,
`n_control` è NA. Il pair mode ha entrambi popolati con split sensati (es. 778
trattati / 976 controlli). Non è un bug.

**Regressione chunk-collision (raison d'être di opzione C) — PASS.** Negli
assignment (546.905 righe, record_id = `series__series__comparison_id`):
- 0 record_id con suffisso chunk `#NofM` (atteso 0).
- 0 series_id contenenti `#` (i 27 record_id con `#` sono label biologiche:
  `Donor_#32`, `Patient#1`).
- GSE249377 (re-chunkato in 268 parti nel rescue) risolve coerentemente: 2
  record_id (`__mg1`, `__mg21`), 10 assignment, tutti su GSE249377, niente ID
  chimerici. Lo Stadio 2 v3 a 1-record/studio + il guard fail-loud eliminano
  strutturalmente la collisione del finding 2026-06-01.

**Completeness guard.** 18.004 sample non assegnati ai replicate_groups → gruppo
sintetico `unclear` su 1.452 studi (~3,5% di 508k = coverage gap REGOLA 4 atteso),
contati sui GSM reali (`member_sample_ids`, commit `c6b9d51`).

## Nota onesta (non bloccante, limite noto)

Molti cluster `disease_vs_normal` hanno `canonical_name=NA`: è la limitazione di
classificazione anchor dell'LLM (audit 2026-05-24, limite paper L2). I cluster
raggruppano comunque in modo deterministico per anchor key; manca solo
l'etichetta leggibile. Impatta l'interpretazione/label, non il pooling.

## Non verificato (basso rischio)

Non ho ispezionato direttamente che i sample `unclear` non entrino come
trattato/controllo nei confronti: per costruzione il completeness guard li mette
in un gruppo `primary_role='unclear'` separato, che non forma confronti. Da
ri-controllare a campione se a F5 emergono anomalie.
