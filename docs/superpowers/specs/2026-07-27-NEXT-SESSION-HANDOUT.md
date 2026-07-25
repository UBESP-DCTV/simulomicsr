# HANDOUT — prossima sessione (preparato 2026-07-26)

**Branch:** `review-scientific-consistency-2026-06-10` · master invariato · nessun push
**Stato:** 🟡 **Le regole di riga e le regole del gate sono CODICE DI PACCHETTO con TDD, verificate
equivalenti allo script sui dati veri e rimisurate col codice di produzione. Ma la pipeline NON le
chiama ancora: i 141 gruppi coerenti vivono in una simulazione. Nessun re-cluster, nessun re-pool.**

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

- **Regole di riga** in `R/stage3-row-pairing.R` (67 test): tempo non appaiato · soggetto/linea
  diversa (**solo nei disegni di trattamento**) · genetica su un braccio solo · combinazione non
  catturata.
- **Regole del gate** in `R/stage3-contrast-gate.R` (102 test): token generici, induttori, verso del
  delta, anatomia + sinonimi d'organo, materiale, contrasto rotto, baseline propria, infezione
  clinica vs sperimentale, resistenza, controlli non validi, delta multiclasse, nomi-ombrello,
  entita' on-contrast.
- **Equivalenza verificata** su 19.863 etichette / 38.440 contrasti (`108-equivalenza-gate.R`):
  le regole di riga sono identiche allo script; il gate differisce in 624 casi, **tutti a favore del
  pacchetto** (lo script non vedeva oltre un underscore). Rimisurato col codice di produzione
  (`109-fase1-v11-gate.R`): **stessi 144 gruppi, composizione identica**.
- **Cache lookup a v7** (le guardie del resolver erano entrate senza bump).
- Finding: `docs/findings/2026-07-26-stage3-row-pairing-rules.md`.

## 2. NUMERI (misurati col codice di produzione, su TUTTI i gruppi)

| | v9 | v10 (regole di riga) | v11 (= codice di pacchetto) |
|---|---:|---:|---:|
| gruppi poolabili k≥3 | 145 | 144 | **144** |
| gruppi coerenti | 143 | 141 | **141 (97,9%)** |
| studi-slot nei coerenti | 890/896 | 866/875 | **866/875** |

Righe mal appaiate scartate: **2.722 membri su 38.440 (7,1%)** = **1.110 confronti distinti**
(soggetto/linea 1.162 · genetica 870 · tempo 630 · combinazione 60).
Incoerenti residui: CSF2 (polarizzazione M1/M0), PTSD (perturbazione dentro-malattia), RSV
(clinico + sperimentale). Forza: k=3-4 → 75 · k=5-9 → 47 · k=10-19 → 14 · k≥20 → 5.
Piu' forti: SARS k=28 · TGFB1 k=27 · LPS k=26 · JQ1 k=24 · enzalutamide k=21.

⚠️ **Questi numeri vengono da una SIMULAZIONE** sui contrasti ricostruiti (`fase1-pm2.rds`), non
dalla pipeline. Sono un pavimento, non una promessa: il resolver di produzione e' piu' forte del
proxy, quindi il k reale puo' salire — ma va **rimisurato sui dati veri** dopo il re-cluster.

## 3. DECISIONI DELL'UTENTE (non ri-litigare)

- Opzione **B** (re-anchor a monte) · soglia **k≥3** · direzione opposta separata · verso non
  determinabile → scarta · combo = entita' a se' · degeneri e nuisance si scartano · verifica su
  TUTTI · pipeline e gate **deterministici** · le 96 righe mal appaiate si scartano.
- **2026-07-26 — RI-MAPPAGGIO DEL RESOLVER: NO (opzione A).** Le guardie continuano a rifiutare
  senza proporre il nome giusto: `5-FU` resta senza nome invece di diventare `CHEBI:46345`.
  Motivo, misurato: il ri-mappaggio darebbe **0 gruppi poolabili nuovi**, 1 rafforzamento
  (lapatinib, gia' presente), 50 membri; le sigle che pesano (`cancer` 354 campioni, `ifn`, `ml`)
  non sono ri-mappabili per principio. Si potra' riaprire DOPO il re-cluster, se le etichette delle
  figure lo richiederanno. Non e' sulla strada critica.

## 4. IL LAVORO DELLA PROSSIMA SESSIONE — l'innesto nel build

**Il problema, in una riga:** le regole esistono ma la pipeline non le chiama. Finche' non si tocca
il build, i 141 gruppi restano una simulazione e il deliverable resta quello vecchio (184 rem_group,
85% minestroni).

**La causa radice, nel codice:** `.build_group_records()` (`R/stage3-build.R:473`) costruisce **un
record per replicate_group**, prendendo l'anchor del PRIMO campione del gruppo
(`.extract_anchor_segments`, `R/stage3-anchor-levels.R:60`). Il controllo non entra mai nella chiave:
resta libero per studio → studi che misurano contrasti diversi finiscono sotto lo stesso anchor.
`.build_pair_records()` (`R/stage3-build.R:412`) invece ha gia' tutto quello che serve:
`treated_anchor_segments`, `control_anchor_segments`, `control_type`, piu' le liste di GSM.

**La direzione (opzione B, spec `docs/superpowers/specs/2026-07-24-stage3-contrast-anchor-design.md`):**
l'anchor del gruppo deve nascere dal CONTRASTO — entita' del delta trattato↔controllo,
canonicalizzata col resolver — non dalla perturbazione del campione.

**Ordine di lavoro suggerito:**
1. **Spec/ADR prima del codice** (convenzione del progetto): come si costruisce il record group
   derivato dal contrasto, cosa succede ai gruppi senza comparison Stadio 2 (oggi 279 = limite L7),
   come si mantiene la retrocompatibilita' del ramo pair.
2. **TDD sul builder**: un nuovo `.build_contrast_group_records()` che, per ogni comparison, produce
   entita'-delta canonica + verso + control_type (+ materiale, baseline, contesto d'infezione) e
   chiama `.cg_*` e `.rp_row_defect` gia' esistenti e testati.
3. **Filtro degeneri a monte** (`treated_label == control_label`, delta solo-nuisance).
4. **Smoke**: girare il build su un sottoinsieme e verificare che ricompaiano i gruppi bandiera
   (SARS, LPS, TGFB1, enzalutamide, R1881, cisplatino) con k ≥ quello della simulazione.
5. **Se `recover_identity` cambia** → bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` a v8.
6. **GATE UTENTE** → re-cluster (~8h, `setsid`) → re-pool (~50h) → ANTI-STALE → **ri-censimento
   della coerenza sui dati VERI, su TUTTI i gruppi**.

## 5. TRAPPOLE GIA' PAGATE (non ripeterle)

- **`_` e' carattere di parola** per le espressioni regolari: `\bsirna\b` non vede `Control_siRNA_1`,
  `10day` dentro `osimertinib_10day` non e' un tempo. Normalizzare i separatori PRIMA di tutto.
- Non bumpare la cache-version quando cambia `recover_identity`: il re-cluster riusa il lookup
  vecchio (gia' costato 8 ore).
- Mettere il **candidato grezzo** del resolver in una stoplist: spesso e' l'intera etichetta del
  trattato e disinnesca la regola in silenzio.
- Giudicare una collisione alias→ID senza leggere il testo sorgente: 5 volte su 78 il nome era giusto.
- `gsub("[^a-z ]")` **prima** di `tolower` cancella le maiuscole.
- Indicizzare 4,4 M di alias con `assign()` in un ciclo R non finisce: join vettoriali.
- I test end-to-end sui dizionari vanno saltati quando l'ambiente ontologico e' una fixture caricata
  da un altro file di test (`skip_if(isTRUE(oe$is_fixture))`).
- `run_in_background` uccide i run lunghi: usare `setsid` e verificare SID==PID.

## 6. ASSET

- Catena della simulazione: `70-fase1-canonical-sim.R` (~8 min) → `80-reresolve-hardened.R` (~4 min)
  → `109-fase1-v11-gate.R` (~25 min) → `110-delta-v10-v11.R` → `111-bundle-cambiati-v11.R` →
  `112-census-v12-final.R`. Gli `.rds` intermedi sono gitignored.
- Verdetti: `v12-census-verdicts-FINAL.csv` · righe: `regole-riga-esito.csv` ·
  equivalenza: `108-equivalenza-gate.R` + `108.log`.
- Codice di produzione: `R/stage3-row-pairing.R`, `R/stage3-contrast-gate.R`, `R/resolver-guards.R`,
  `R/stage3-name-recovery-lookup.R` (cache v7).
- Suite: 6 fallimenti pre-esistenti (4 chiamano OpenAI con chiave scaduta — la pipeline non usa
  OpenAI; 1 richiede il CLI quarto; 1 e' il noto gene-axis E2). Zero dai lavori di questa sessione.
