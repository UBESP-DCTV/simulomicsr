# HANDOUT — Anchor derivato-dal-contrasto: dopo il censimento v7 (92,7%)

**Data prep:** 2026-07-25 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** 🟡 **150 poolabili k≥3, coerenza 92,7% (139/150) misurata su TUTTI, uno per uno.
NON validato, NON finale. Nessun re-cluster lanciato.**

---

## 0. LE REGOLE, INVARIATE

1. Il gate e' la **COERENZA**, mai il numero di cluster. "N poolabili" ≠ "N coerenti".
2. Verifica su **TUTTI** i cluster, mai su un campione.
3. Zero slop: entita' di 1-3 caratteri, parole generiche, veicoli, induttori, classi-ombrello **non sono
   entita'**. Se una passa, il gate e' rotto: fermati e riparalo.
4. Pipeline pubblicata **deterministica**: la coerenza nasce per costruzione dell'anchor. Nessun Claude
   nella pipeline ne' nella validazione pubblicata (evaluator = Mistral self-hosted).
5. **Nessun re-cluster (~8h) o re-pool (~50h)** senza GO esplicito dell'utente.
6. Fail onesto coi numeri. Se resta il 7,3%, si scrive 7,3%.
7. **VIETATO** scrivere "validato / risolto / finale / paper-grade" senza prova per-cluster su TUTTI.

## 1. DECISIONI PRESE (non ri-litigare)

- Opzione B (re-anchor a monte); ~100-150 meta-analisi vere > 184 minestroni; soglia k≥3.
- Degeneri e nuisance si scartano, con lista loggata. Combo = entita' a se'.
- **2026-07-25**: la **direzione opposta NON si fonde** (il verso entra nella chiave); quando il verso
  non e' determinabile, il cluster **si scarta**.

## 2. DOVE SIAMO (misurato, `docs/findings/2026-07-25-stage3-contrast-anchor-v7-census.md`)

- 150 poolabili k≥3 (74 con k≥5); **139 coerenti = 92,7%**; 866/934 studi-slot nei coerenti.
- Dei 20 casi falliti catalogati in v6: **19 chiusi, 1 aperto** (HBV) — verificato con
  `87-v6-failures-closure.R`, non a memoria.
- Bandiera: SARS k=31, LPS k=27, enzalutamide k=22, JQ1 k=26, TGFB1 k=28, vemurafenib k=15, R1881 k=18.

## 3. IL RESIDUO (11 cluster) — cosa serve per chiuderlo

| causa | n | fix candidato |
|---|---:|---|
| disegno misto (malattia+terapia, M1/M0, perturbazione-dentro-malattia) | 3 | il membro deve essere scartato quando il delta contiene sia la malattia sia la terapia e il controllo e' un sano; serve una regola sul **braccio di controllo appaiato** |
| clinico vs sperimentale (CMV, HBV) | 2 | l'asse R8 usa marcatori nel controllo; qui i controlli sono ambigui ("control 3 months", "no treatment"). Serve un segnale sul **trattato** (viremia/stato-portatore = clinico) |
| co-infezione (M.tb+CMV, RSV+rhinovirus) | 2 | estendere il rilevatore combo alle **infezioni multiple** nominate nel label |
| combo non catturata (T3+LPS, E2+OTX015) | 2 | la soglia a 3 caratteri esclude `T3`/`E2`: ammettere token di 2 caratteri **solo** se risolvono a un ID canonico |
| controllo incongruo (5-FU "total RNA") | 1 | controllo che non e' un controllo: stoplist di label-controllo non validi |
| entita' estranea (Her/Lap in TGFB1) | 1 | capire da dove viene l'ID (probabile eredita' NAME o mis-risoluzione): **diagnosticare prima di patchare** |

## 4. LIMITE NUOVO: frammentazione (~10 cluster in eccesso)

Stessa entita' spezzata: LPS 27+3, SARS 31+3, enzalutamide 22+4, R1881 18+3, TGFB1 28+7, ipossia 9+9+6,
decitabina 5+4, nutlin 4+3 (due ID ChEBI per lo stesso farmaco), asma 4+3. Cause: veicolo scritto
diversamente (`ethanol`, `rpmi media`), sigla non risolta (`STR:enza`), sinonimo (`asthma`/`asthmatic`),
duplicato ontologico. **Non tocca la coerenza, aumenta il k**: da fare prima del re-cluster, perche'
cambia la chiave.

## 5. SEQUENZA PROPOSTA PER LA PROSSIMA SESSIONE

1. Chiudere il residuo (§3) + la frammentazione (§4), **ri-censire TUTTI** e riportare il numero onesto.
2. Se ≥95%: chiedere il GO e passare alla **Fase 2** = implementazione in produzione con TDD
   (`R/anchors.R`, `R/stage3-anchor-levels.R`, `R/stage3-build.R`, filtro degeneri a monte, bump della
   cache-version) — il proxy della simulazione **non e'** la pipeline.
3. Solo dopo: Fase 3 = re-cluster (~8h) + re-pool (~50h) con `setsid`, ANTI-STALE, e **ri-verifica della
   coerenza sui dati VERI** (il proxy e' piu' debole del resolver di produzione: l'92,7% e' un pavimento).

## 6. DA DECIDERE CON L'UTENTE

- **Bug di produzione dei nomi** (§5 del finding): `.normalize_cytokine_to_hgnc` risolve ogni etichetta
  con `ug/ml` a THPO (ImmPort ha `ML` come sinonimo di *Thrombopoietin*). E' un bug **di nomi**, non di
  coerenza: si corregge ora (TDD, tocca la pipeline) o si lascia al giro sui nomi?
- **Soglia di accettazione**: il gate passa a ≥95% o si accetta 92,7% documentando gli 11?

## 7. ASSET

- Pipeline della simulazione: `analysis/audit/2026-07-24-anchor-coherence-sim/`
  `80-reresolve-hardened.R` → `81-fase1-v7-gate.R` → `84-gen-census-v7.R` → `86-census-verdicts.R`
  → `87-v6-failures-closure.R`. Intermedi rigenerabili: `fase1-pm.rds` (script 70, ~8 min),
  `fase1-pm2.rds` (script 80, ~4 min) — **sono gitignored: se mancano, vanno ricostruiti prima di tutto.**
- Verdetti: `v7-census-verdicts.csv` · bundle: `v7-census-bundles.txt` · finding:
  `docs/findings/2026-07-25-stage3-contrast-anchor-v7-census.md`.
- Ground truth precedente: `analysis/audit/2026-07-23-coherence/` (`per-member-contrasts.parquet`,
  `cluster-verdicts.rds`).
