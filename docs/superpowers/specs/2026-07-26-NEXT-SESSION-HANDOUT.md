# HANDOUT — dopo la notte del 2026-07-25: coerenza 98,6% + fix del resolver in produzione

**Branch:** `review-scientific-consistency-2026-06-10` · master invariato · nessun push
**Stato:** 🟡 **145 cluster poolabili, 143 coerenti (98,6%) censiti uno per uno. Il resolver ha una
guardia di precisione in produzione, testata e misurata. NIENTE e' ancora materializzato: nessun
re-cluster, nessun re-pool.**

---

## 0. REGOLE (invariate)

1. Il gate e' la **COERENZA**, mai il numero di cluster.
2. Verifica su **TUTTI** i cluster, mai su un campione.
3. Zero slop nel gate: sigle, parole generiche, veicoli, induttori, classi-ombrello non sono entita'.
4. Pipeline pubblicata **deterministica**: nessun LLM a runtime (evaluator = Mistral self-hosted).
5. Nessun run pesante senza **GO esplicito** dell'utente.
6. Fail onesto coi numeri.
7. **VIETATO** dichiarare "validato/finale/paper-grade" senza prova per-cluster su TUTTI.

## 1. DOVE SIAMO

**Coerenza** (`docs/findings/2026-07-25-stage3-contrast-anchor-v7-census.md`, addendum v10):
143/145 = **98,6%**, 890/896 studi-slot. Residui: 2 cluster k=3 (CSF2 polarizzazione M1/M0, PTSD
perturbazione dentro-malattia). Piu' forti: SARS-CoV-2 k=29 · LPS k=28 · TGFB1 k=27 · JQ1 k=24 ·
enzalutamide k=21 · DHT k=20 · cisplatino k=19 · R1881 k=19 · doxorubicina k=17 · TNF k=15.

**Resolver** (`docs/findings/2026-07-25-resolver-alias-collisions.md`): il bug THPO non era isolato —
e' una **classe** (unita' di misura, parole del discorso, sinonimi storici, sigle di famiglia,
omonimie chimiche). Misurato sulla produzione: **952 identita' sbagliate su 26.936 (3,53%)**, rimosse;
**zero perdite** sulle entita' vere. Fix in `R/resolver-guards.R` + TDD (57 PASS).

## 2. COSA MANCA PRIMA DI MATERIALIZZARE (ordine consigliato)

1. **Portare le regole del gate dalla simulazione alla produzione.** Oggi vivono in
   `analysis/audit/2026-07-24-anchor-coherence-sim/92-fase1-v9-gate.R` (script d'analisi). Vanno
   riscritte come codice di pacchetto con TDD: `R/anchors.R`, `R/stage3-anchor-levels.R`,
   `R/stage3-build.R` + filtro degeneri a monte + **bump della cache-version**
   (`.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`: senza il bump il re-cluster riusa il lookup stale —
   e' gia' costato 8 ore in passato).
2. **Decidere sul ri-mappaggio.** Le guardie oggi RIFIUTANO (5-FU non diventa CHEBI:46345, resta senza
   nome). Vale la pena una tabella curata di ri-mappaggio per i casi ad alto impatto? E' un'asserzione
   di identita': va decisa dall'utente, non da me.
3. **Coda dell'audit alias**: 244 alias non adjudicati (698 campioni, tutti n≤6).
4. Solo dopo: **GO utente** → re-cluster (~8h) + re-pool (~50h), `setsid`, ANTI-STALE, e
   **ri-verifica della coerenza sui dati VERI** (il proxy e' piu' debole del resolver di produzione).

## 3. COSE DA NON RIFARE (errori gia' pagati questa notte)

- L'indicizzazione di 4,4 M di alias con `assign()` in un ciclo R non finisce (22 min, 8,8 GB): usare
  join vettoriali.
- Nel confronto prima/dopo del recupero-nome, **escludere i percorsi K2/K3**: riscrivono il `kind`,
  e rialimentandolo come input il ramo non riparte — sembra una regressione e non lo e'.
- `gsub("[^a-z ]")` **prima** di `tolower` cancella le maiuscole (bug gia' fatto in `anatomy_of`).
- Togliere i numeri isolati spezza `sars-cov-2` → `sars-cov` (= SARS del 2003, taxon diverso).
- `\b` non vede `calcium_low`: `_` e' un carattere di parola.

## 4. ASSET

- Gate: `analysis/audit/2026-07-24-anchor-coherence-sim/92-fase1-v9-gate.R` (v10 = v9 + guardie).
  Catena: `80-reresolve-hardened.R` → `92-...` → `84c-gen-census-v9.R` → `97-census-verdicts-final.R`.
  Gli `.rds` intermedi sono gitignored: se mancano, si ricostruiscono con `70-fase1-canonical-sim.R`
  (~8 min) e `80-...` (~4 min).
- Verdetti finali: `v10-census-verdicts-FINAL.csv` · bundle: `v9-census-bundles.txt`.
- Audit resolver: `analysis/audit/2026-07-25-resolver-alias-audit/` (script 90 → 96).
- Codice di produzione toccato: `R/resolver-guards.R` (nuovo), `R/stage3-name-recovery.R` (4 innesti).
