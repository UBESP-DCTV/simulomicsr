# Dev set sampling — decisione operativa P2

**Data:** 2026-05-02 (Task 8 del plan P2).

## Strategia

Spec v5 §6.1 prescrive un eval set stratificato:
- 60% sample dove `trtctr_EP == trtctr` (baseline shallow d'accordo con gold manuale)
- 30% sample dove `trtctr_EP != trtctr`
- 10% sample con stringhe ambigue/corte (`nchar(string) <= 60`)

P2 implementa questo come **dev set di 100 sample** (60/30/10). Funzione:
`build_dev_set()` in `R/eval-sampling.R`, target `samples_dev_set` in
`analysis/_targets.R`.

## Riproducibilita'

- Seed default = 1812 (scelto dall'utente).
- Per ciascuno strato la funzione fa un `withr::with_seed(seed + offset)` con
  offset deterministico per strato (1/2/3) — così gli strati sono indipendenti
  e cambiare uno strato non muove gli altri.
- Il target `samples_dev_set` è invalidato automaticamente da `targets` se
  `samples_input` cambia, garantendo coerenza tra dev set e fonte.

## Espansione futura

- P3: passare a `n = 1000` per l'eval set vero (sempre 60/30/10, oppure
  ricalibrato sulle frequenze osservate).
- P3 mid-stage: introdurre il **gold design-aware** (spec §6.2), un secondo
  target `samples_gold_design_aware` che sostituisce/affianca questo dev set
  per la valutazione dello Stadio 2.
