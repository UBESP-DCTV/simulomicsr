# HANDOUT — prossima sessione (preparato 2026-07-26)

**Branch:** `review-scientific-consistency-2026-06-10` · master invariato · nessun push
**Stato:** 🟡 **Le regole di riga e le regole del gate sono CODICE DI PACCHETTO con TDD, verificate
equivalenti allo script sui dati veri e rimisurate col codice di produzione. Niente e'
materializzato: nessun re-cluster, nessun re-pool.**

---

## 0. REGOLE (non negoziabili)

1. Il gate e' la **COERENZA**, mai il numero di gruppi.
2. Verifica su **TUTTI**, mai su un campione.
3. Zero slop: sigle, parole generiche, veicoli, induttori, classi-ombrello non sono entita'.
4. Pipeline pubblicata **deterministica**: nessun LLM a runtime (evaluator = Mistral self-hosted).
5. Nessun run pesante senza **GO esplicito** dell'utente.
6. Fail onesto coi numeri.
7. **VIETATO** dichiarare "validato/finale/paper-grade" senza prova per-gruppo su TUTTI.

## 1. DOVE SIAMO

- **Regole di riga in produzione**: `R/stage3-row-pairing.R` + `tests/testthat/test-stage3-row-pairing.R`
  (67 PASS). Tempo non appaiato, soggetto/linea diversa (solo nei disegni di trattamento),
  genetica su un braccio solo, combinazione non catturata.
- **Regole del gate in produzione**: `R/stage3-contrast-gate.R` +
  `tests/testthat/test-stage3-contrast-gate.R` (102 PASS). Token generici, induttori, verso,
  anatomia, materiale, contrasto rotto, baseline propria, infezione clinica vs sperimentale,
  resistenza, controlli non validi, delta multiclasse, nomi-ombrello, entita' on-contrast.
- **Equivalenza verificata** (`108-equivalenza-gate.R`) su 19.863 etichette / 38.440 contrasti:
  le regole di riga sono identiche allo script; le regole del gate differiscono in quattro punti
  dove lo SCRIPT non vedeva oltre un underscore (`_doxycycline`, `Baseline_Control`, `CON_1_input`,
  `Patient_081`) piu' `pulmonary` aggiunto all'anatomia. Il gate e' stato **rimisurato col codice di
  pacchetto** (`109-fase1-v11-gate.R`): i numeri riportati sono quelli del codice che verra' eseguito.
- **Bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` v6 → v7** (le guardie del resolver erano entrate
  senza bump).
- Finding: `docs/findings/2026-07-26-stage3-row-pairing-rules.md`.

## 2. NUMERI (misurati col codice di produzione)

| | v9 | v10 (regole di riga) | v11 (= codice di pacchetto) |
|---|---:|---:|---:|
| gruppi poolabili k≥3 | 145 | 144 | **144** |
| gruppi coerenti | 143 | 141 | **141 (97,9%)** |
| studi-slot nei coerenti | 890/896 | 866/875 | **866/875** |

Righe mal appaiate scartate: **2.722 membri su 38.440 (7,1%)** = **1.110 confronti distinti**
(soggetto/linea 1.162 · genetica 870 · tempo 630 · combinazione 60).
Incoerenti residui: CSF2 (polarizzazione M1/M0), PTSD (perturbazione dentro-malattia), RSV
(infezione clinica e sperimentale mescolate). Forza: k=3-4 → 75 gruppi, k=5-9 → 47, k=10-19 → 14,
k≥20 → 5. Piu' forti: SARS k=28 · TGFB1 k=27 · LPS k=26 · JQ1 k=24 · enzalutamide k=21.

## 3. COSA MANCA (in ordine)

1. **L'innesto nel build dello Stadio 3.** Le regole vivono in `R/` ma non sono ancora chiamate dalla
   pipeline: serve il passo architetturale dell'opzione B (spec
   `docs/superpowers/specs/2026-07-24-stage3-contrast-anchor-design.md`) — i record **group** devono
   nascere dal CONTRASTO, non dal campione. Oggi `.build_group_records` (`R/stage3-build.R:473`)
   costruisce un record per replicate_group, col controllo libero per studio: e' la causa radice del
   minestrone. I record **pair** (`.build_pair_records`, :412) hanno gia' treated+control+control_type:
   sono il punto da cui derivare l'anchor del gruppo.
2. **Decisione utente aperta: ri-mappaggio del resolver.** Misurato (finding §8): recupererebbe
   **0 gruppi poolabili nuovi**, 1 rafforzamento, 50 membri. Le sigle piu' frequenti (`cancer`,
   `ifn`, `ml`) non sono ri-mappabili per principio. L'utente ha chiesto i numeri prima di decidere:
   ora ci sono.
3. Solo dopo, con **GO esplicito**: re-cluster (~8h) + re-pool (~50h), `setsid`, ANTI-STALE, e
   ri-verifica della coerenza sui dati VERI (il proxy e' piu' debole del resolver di produzione).

## 4. TRAPPOLE GIA' PAGATE (non ripeterle)

- **`_` e' carattere di parola** per le espressioni regolari: `\bsirna\b` non vede `Control_siRNA_1`,
  `10day` dentro `osimertinib_10day` non e' un tempo. Normalizzare i separatori PRIMA di tutto.
- Non bumpare `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` quando cambia `recover_identity`: il re-cluster
  riusa il lookup vecchio (gia' costato 8 ore).
- Mettere il **candidato grezzo** del resolver in una stoplist: spesso e' l'intera etichetta del
  trattato e disinnesca la regola in silenzio.
- Giudicare una collisione alias→ID senza leggere il testo sorgente: 5 volte su 78 il nome era giusto.
- Indicizzare 4,4 M di alias con `assign()` in un ciclo R non finisce: join vettoriali.
- `gsub("[^a-z ]")` **prima** di `tolower` cancella le maiuscole.
- I test end-to-end sui dizionari vanno saltati quando l'ambiente ontologico e' una fixture caricata
  da un altro file di test (`skip_if(isTRUE(oe$is_fixture))`).

## 5. ASSET

- Catena: `80-reresolve-hardened.R` → `109-fase1-v11-gate.R` → `110-delta-v10-v11.R` →
  `111-bundle-cambiati-v11.R` → `112-census-v12-final.R`. Gli `.rds` intermedi sono gitignored:
  se mancano, ricostruire con `70-fase1-canonical-sim.R` (~8 min) e `80-...` (~4 min).
- Verdetti: `v12-census-verdicts-FINAL.csv`. Righe: `regole-riga-esito.csv`, `v12-cambiati.txt`.
- Codice di produzione: `R/stage3-row-pairing.R`, `R/stage3-contrast-gate.R`,
  `R/resolver-guards.R`, `R/stage3-name-recovery-lookup.R` (cache v7).
- Suite: 6 fallimenti pre-esistenti (4 chiamano OpenAI con chiave scaduta — la pipeline non usa
  OpenAI; 1 richiede il CLI quarto; 1 e' il noto gene-axis E2). Zero dai lavori di questa sessione.
