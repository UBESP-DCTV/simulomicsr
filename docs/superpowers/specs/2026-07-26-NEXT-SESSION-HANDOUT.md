# HANDOUT — prossima sessione (preparato 2026-07-25, notte)

**Branch:** `review-scientific-consistency-2026-06-10` · master invariato · nessun push
**Stato:** 🟡 **145 gruppi poolabili, 143 coerenti (98,6%) verificati riga per riga. Il resolver ha
una guardia di precisione in produzione, testata e misurata. NIENTE e' materializzato: nessun
re-cluster, nessun re-pool.**

---

## 0. REGOLE (non negoziabili)

1. Il gate e' la **COERENZA**, mai il numero di gruppi.
2. Verifica su **TUTTI**, mai su un campione.
3. Zero slop: sigle, parole generiche, veicoli, induttori, classi-ombrello non sono entita'.
4. Pipeline pubblicata **deterministica**: nessun LLM a runtime (evaluator = Mistral self-hosted).
5. Nessun run pesante senza **GO esplicito** dell'utente.
6. Fail onesto coi numeri.
7. **VIETATO** dichiarare "validato/finale/paper-grade" senza prova per-gruppo su TUTTI.

## 1. DOVE SIAMO (misurato)

- **Coerenza**: 143/145 = 98,6% (890/896 studi-slot). I 2 scartati sono k=3 (GM-CSF: polarizzazione
  M1/M0; PTSD: perturbazione dentro-malattia). Piu' forti: SARS k=29 · LPS k=28 · TGFB1 k=27 ·
  JQ1 k=24 · enzalutamide k=21 · DHT k=20 · cisplatino k=19 · R1881 k=19.
- **Verifica riga per riga** (1.851 righe): **96 righe mal appaiate (5,2%)** — tempo non appaiato 42,
  controllo di linea/donatore diverso 29, combinazione non vista 13, genetica su un braccio solo 12.
  90 altre segnalazioni erano falsi allarmi del rilevatore (nei disegni malato-vs-sano i soggetti sono
  per forza diversi). Nessun verdetto di gruppo cambia.
- **Resolver**: il bug "ug/ml → THPO" era una classe. 949 identita' sbagliate rimosse su 26.936
  (3,52%), zero perdite sulle entita' vere. `R/resolver-guards.R` + TDD (59 PASS).
  Finding: `docs/findings/2026-07-25-resolver-alias-collisions.md`.

## 2. DECISIONE PRESA DALL'UTENTE (2026-07-25)

**Le 96 righe mal appaiate si SCARTANO.** Costo accettato: 2 gruppi scendono sotto i 3 studi
(bosutinib `CHEBI:39112`, RSV `NCBITaxon:12814||uninfected`) → **143 → 141 gruppi coerenti**.

## 3. COSA FARE, IN ORDINE

1. **Implementare lo scarto delle righe** dentro il gate, come regole (non come lista di righe):
   - tempo non appaiato: i due bracci hanno tempi espliciti e diversi (es. trattato 24h vs controllo 0h)
   - controllo di linea/donatore diverso, **solo nei disegni di trattamento** (nei caso-controllo di
     malattia i soggetti diversi sono obbligatori: NON e' un difetto)
   - combinazione non vista: ≥2 agenti nel trattato assenti dal controllo
   - modifica genetica presente su un solo braccio
   Riferimento: `analysis/audit/2026-07-24-anchor-coherence-sim/100-difetti-riga.R` (rilevatore gia'
   scritto e validato a mano) + `difetti-riga.csv`. Poi **ri-censire tutti** e riportare il numero.
2. **Portare le regole del gate in produzione con TDD**: oggi vivono in
   `analysis/audit/2026-07-24-anchor-coherence-sim/92-fase1-v9-gate.R` (script d'analisi). Vanno in
   `R/anchors.R`, `R/stage3-anchor-levels.R`, `R/stage3-build.R` + filtro degeneri a monte +
   **bump della cache-version** (`.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`: senza il bump il re-cluster
   riusa il lookup vecchio — e' gia' costato 8 ore).
3. **Decisione aperta**: le guardie del resolver oggi RIFIUTANO senza ri-mappare (5-FU resta senza
   nome invece di diventare CHEBI:46345). Ri-mappare significa asserire un'identita': serve l'ok
   dell'utente.
4. Solo dopo, con **GO esplicito**: re-cluster (~8h) + re-pool (~50h), `setsid`, ANTI-STALE, e
   **ri-verifica della coerenza sui dati VERI** (il proxy e' piu' debole del resolver di produzione:
   il 98,6% e' un pavimento, non una promessa).

## 4. TRAPPOLE GIA' PAGATE (non ripeterle)

- Indicizzare 4,4 M di alias con `assign()` in un ciclo R non finisce (22 min, 8,8 GB): join vettoriali.
- Nel confronto prima/dopo del recupero-nome, **escludere i percorsi K2/K3**: riscrivono il `kind`,
  rialimentarlo come input spegne il ramo e sembra una regressione.
- `gsub("[^a-z ]")` **prima** di `tolower` cancella le maiuscole.
- Togliere i numeri isolati spezza `sars-cov-2` → `sars-cov` (= SARS del 2003, taxon diverso).
- `\b` non vede `calcium_low`: `_` e' carattere di parola.
- Giudicare una collisione alias→ID **senza leggere il testo sorgente**: cinque volte su 78 il nome
  era giusto (`lead` era davvero piombo, `ser` serina, `mc` 3-metilcolantrene).
- I test end-to-end sui dizionari falliscono nella suite completa se non saltano quando l'ambiente
  ontologico e' una fixture caricata da un altro file di test.

## 5. ASSET

- Catena della simulazione: `80-reresolve-hardened.R` → `92-fase1-v9-gate.R` → `84c-gen-census-v9.R`
  → `97-census-verdicts-final.R` → `99-verifica-riga-per-riga.R` → `100-difetti-riga.R`.
  Gli `.rds` intermedi sono gitignored: se mancano, ricostruire con `70-fase1-canonical-sim.R` (~8 min)
  e `80-...` (~4 min).
- Verdetti: `v10-census-verdicts-FINAL.csv` · righe: `difetti-riga.csv`, `difetti-per-gruppo.csv`.
- Codice di produzione toccato: `R/resolver-guards.R` (nuovo), `R/stage3-name-recovery.R` (4 innesti),
  `tests/testthat/test-resolver-guards.R`.
- Suite: 6 fallimenti pre-esistenti (4 chiamano OpenAI con chiave scaduta — la pipeline non usa
  OpenAI; 1 richiede il CLI quarto; 1 e' il noto gene-axis E2). Zero dai lavori di questa sessione.
