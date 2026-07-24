# HANDOUT — Anchor derivato-dal-contrasto: chiudere il residuo e ri-censire (sessione successiva)

**Data prep:** 2026-07-24 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** 🟡 design validato in simulazione all'**81% (tutti i cluster) / ~89% (deliverable)**.
**NON è finito. NON è "una soluzione". Nessun re-cluster è stato lanciato e non va lanciato finché il
gate non passa.**

---

## 0. LEGGI QUESTO PRIMA DI TOCCARE QUALSIASI COSA

Questo progetto ha un fallimento di processo che dura da MESI: si è ottimizzato un PROXY (i nomi dei
cluster; il conteggio dei cluster; l'I² del pooled) scambiandolo per l'OBIETTIVO (che gli studi
raggruppati misurino lo STESSO contrasto). Ogni volta che è stato dichiarato "publication-grade /
DELIVERABLE FINALE / done", era falso. Quando la coerenza è stata finalmente misurata: **157/184 (85%)
del deliverable erano MINESTRONI**; la vetrina Layer B **0/9**.

**E l'errore è stato rifatto DENTRO la sessione del 2026-07-24, due volte:**
1. Ho scritto "🟢 DESIGN VALIDATO / soluzione trovata" avendo misurato **k recuperato (287 poolabili)**
   e **farmaci 8/8 preservati** — **senza aver verificato che i nuovi cluster fossero coerenti**. Quando
   li ho verificati: **72%**, non 100%. Ritrattato.
2. Ho lasciato passare entità-spazzatura come **`STR:t`, `STR:d`, `STR:dox`** (letteralmente una lettera)
   come chiave di raggruppamento. Slop puro: non doveva nemmeno essere concepibile.

**Se in questa sessione scrivi "validato / risolto / paper-grade / finale" senza la prova di coerenza
PER-CLUSTER su TUTTI i cluster, stai mentendo. È già successo tre volte + due in una sola sessione.**

---

## 1. REGOLE HARD (non negoziabili)

1. **Il GATE è la COERENZA, MAI un conteggio.** "N cluster poolabili" NON è "N cluster coerenti". La
   consistenza (k, I²) è la FORZA da riportare accanto, non la barriera.
2. **La verifica va fatta su TUTTI i cluster, MAI su un campione** (decisione utente 2026-07-24). Un
   campione ha già prodotto una falsa vittoria in questa stessa sessione.
3. **Zero slop nel gate.** Un'entità di 1-3 caratteri, una parola generica (`none`, `high`, `positive`,
   `mutant`, `chemotherapy`), un veicolo (DMSO), un induttore (doxiciclina), una classe-ombrello
   (`MeSH:Neoplasms`, "organic cation", "steroid") **non sono entità**. Se una di queste passa, il gate
   è rotto: fermati e riparalo.
4. **La pipeline pubblicata è 100% DETERMINISTICA.** La coerenza nasce **per costruzione** dell'anchor,
   non da un giudice LLM a runtime. Nessun componente può richiedere Claude o un abbonamento. L'unico
   LLM nella pipeline è **Mistral self-hosted** (come Stadio 1/2). I subagent Claude sono SOLO uno
   strumento di audit interno, mai un metodo pubblicabile.
5. **VALIDA-PRIMA-DEL-FULLRUN.** Nessun re-cluster (~8h) o re-pool (~50h) prima che il censimento di
   coerenza su TUTTI i cluster passi + GO esplicito dell'utente.
6. **Fail onesto coi numeri.** Se resta il 19% incoerente, scrivi 19%.
7. **Non fidarti dei subagent/LLM senza controllo contro i dati veri.**

---

## 2. DOVE SIAMO (numeri misurati, non asseriti)

**Causa radice PROVATA:** l'anchor è **comparison-blind** — ancora sulla perturbazione del campione
TRATTATO, non su ciò che il CONTRASTO isola (il delta trattato↔controllo). Prova: SARS `b6a3eabd`
mescola infezione-vs-mock + farmaco-vs-DMSO (SARS held-constant) + KO genetico. A scala: dei 1.674
cluster k≥3 risolvibili, **59,8% mescola ≥2 classi-contrasto**, **76,8% ≥2 tipi-controllo**.

**Design misurati (simulazione sui contrasti già ricostruiti, nessun re-cluster):**

| design | poolabili k≥3 | coerenza verificata |
|---|---:|---|
| baseline (anchor v10) | 1.674 | 26/184 = **14%** sul deliverable |
| A — solo control_type | 945 | **11% (3/28)** → INSUFFICIENTE, scartato |
| B/C — entità-delta (proxy grezzo) | 126 | 80% (16/20) su campione |
| v4 hybrid (on/off-contrast) | 287 | **72% (29/40)** ← la mia "vittoria" prematura |
| v5 gate rigoroso | 219 | **74% (162/219)** — censito TUTTI, 15 batch |
| **v6 gate hardened** | **196** | **81% (159/196) su TUTTI** · **~89% sul deliverable** |

Il **~89%** esclude i 16 bucket `+COMBO` (le combo staccate dai mono, che ORA sono puliti:
enzalutamide/fulvestrant/palbociclib/osimertinib/DHT/estradiolo mono = tutti `one_contrast`). Il bucket
`+COMBO` è un artefatto del proxy: in produzione ogni combo si risolve nel suo ID specifico.

**Prova che il meccanismo funziona:** SARS ricomposto e pulito a **k=34** (era 3 frammenti k=7+4+4);
k≥5 da 26 (lower bound) a 70-118 a seconda del gate.

---

## 3. DECISIONI GIÀ PRESE DALL'UTENTE (non ri-litigare)

1. **Opzione B**: re-anchor a monte (anchor derivato-dal-contrasto: entità-delta canonica via resolver
   esistente + control_type). NON il filtro a valle.
2. **Trade-off accettato**: ~100 meta-analisi difendibili > 184 minestroni. Meno cluster, tutti veri.
3. **Soglia k≥3** globale (incluse le disease low-k; sotto k=3 si scarta).
4. **Degeneri e nuisance-only si SCARTANO.** Criterio degenere = `factor_levels` identici (NON la label:
   cattura i 246 nulli veri e NON i 18 mal-etichettati). Loggare la lista scartata.
5. **Combo = entità a sé** (non si spezza, non si scarta; se poi ha k<3 muore per soglia).
6. **Verifica su TUTTI i cluster**, mai campione.
7. **Pipeline + gate deterministici**, evaluator Mistral (non Claude).

### DECISIONE ANCORA APERTA (chiedere all'utente, NON decidere da solo)
- **Direzione opposta**: un cluster deve fondere **agonista e antagonista** dello stesso bersaglio
  (DHT-agonista + enzalutamide-antagonista; glucosio deprivazione + aggiunta; TNF inibitore + stimolo)?
  **Raccomandazione: NO** — misurano effetti opposti che si annullano; l'anchor deve separarli per
  verso/segno. **4 casi misurati** nel residuo + è un problema strutturale. L'utente NON ha ancora
  confermato: spiegato ma interrotto.

---

## 4. IL LAVORO DA FARE (il residuo: 15 falliti veri = 84 studi-slot su 965, ~9%)

Strategia già disegnata e QUANTIFICATA sui dati (2026-07-24). Tre mosse:

### (A) SPLIT — separare i due contrasti; di solito si recupera quasi tutto
| caso | k prima | dopo | recuperato |
|---|---:|---|---|
| vemurafenib (mono+combo) | 12 | mono k=12, combo k=1 | 12/12 |
| covid (malattia+vaccino) | 13 | malattia k=13, vaccino k=1 | 13/13 |
| HCC (tessuto+plasma) | 9 | tessuto k=8, plasma k=1 | 8/9 |
| artrite reum. (vs-sano + longitudinale) | 6 | vs-sano k=5, long. k=1 | 5/6 |
| bleomicina (mono+combo) | 5 | mono k=3, **combo k=3** | 6 (entrambi validi) |

Implementazione: nella chiave entrano (i) il **materiale del controllo** (tessuto/plasma/siero/cfRNA),
(ii) il **tipo di baseline** (sano vs proprio-baseline longitudinale), (iii) le **combo** come entità a
sé — **e il rilevatore combo va esteso a `/` e `and`** (così sono sfuggite bleomicina/TMZ/vemurafenib:
oggi cattura solo `+`).

### (B) RIPULITURA — scartare i pochi membri sbagliati, tenere il cluster
Membri con controllo incongruo (es. `heart_failure` vs "Baseline Kidney"; leucemia vs "Normal Lung") =
errori Stadio 2. Stessa logica del filtro degeneri: si droppa il MEMBRO, non il cluster.

### (C) SCARTO — non recuperabile, e va detto
- entità inventata da nome sbagliato (`HGNC:11795` = lariciresinolo+doxorubicina+grafene) → **bug
  ortogonale di name-recovery**, scarta qui e annota;
- aggregati vaghi (`environmental_or_behavioral`) → non sono entità;
- trattamento ignoto (`early/late_on_biopsy vs pre-treatment`: quale terapia? cambia per studio) → non
  verificabile, si scarta (NON si tiene come "unclear").

**Bilancio stimato:** ~50-60 slot recuperati, ~25-30 scartati. Quasi nessun cluster si perde intero.

---

## 5. SEQUENZA OPERATIVA DELLA PROSSIMA SESSIONE

1. **Chiedere all'utente la decisione sulla direzione opposta** (§3). NON procedere a naso.
2. Implementare (A)+(B)+(C) + la regola sulla direzione nel gate di simulazione
   (`analysis/audit/2026-07-24-anchor-coherence-sim/77-fase1-v6-hardened-gate.R` è il punto di partenza).
3. **RI-CENSIRE LA COERENZA SU TUTTI I CLUSTER** (non campione). Target onesto: ≥90-95%; ogni fallito
   residuo catalogato e spiegato. Se non ci si arriva, **scriverlo** e portare i numeri all'utente.
4. Solo con il censimento passato + GO utente → **Fase 2** (implementazione in produzione: `R/anchors.R`,
   `R/stage3-anchor-levels.R`, `R/stage3-build.R`, filtro degeneri a monte, gate deterministico, bump
   cache-version) con TDD.
5. Poi Fase 3 (re-cluster ~8h + re-pool ~50h, setsid, ANTI-STALE) e ri-verifica per-cluster sui dati REALI.

**Nota di realismo:** il proxy della simulazione risolve dai label GREZZI ed è più debole della pipeline
vera (che ha resolver + overlay). Quindi l'81/89% è un **pavimento**, non un tetto — ma questo NON
autorizza a dichiarare nulla: si misura sui dati veri in Fase 3.

---

## 6. ASSET (riusare, NON ripartire da zero)

- **Engine + gate + censimenti:** `analysis/audit/2026-07-24-anchor-coherence-sim/`
  - `contrast-sig-engine.R` (firma di contrasto: parse factor_levels, classe della chiave, delta)
  - `77-fase1-v6-hardened-gate.R` (gate rigoroso attuale: stoplist, blacklist ID, combo, material-aware)
  - `72-fase1-v4-hybrid.R` (entità hybrid on/off-contrast: il meccanismo che recupera k)
  - `v5-census-failures.txt`, `v6-census-failures.txt` (catalogo dei falliti per causa)
  - `FASE1-RESULT.md` (risultati + le mie ritrattazioni), `60-degenerate-measure.R`
- **Tool coerenza (produzione):** `R/stage3-coherence.R` + test.
- **Verifica 2026-07-23:** `analysis/audit/2026-07-23-coherence/` (`per-member-contrasts.parquet` =
  38.440 contrasti già ricostruiti; `cluster-verdicts.rds` = i 184 con verdetto LLM = ground truth).
- **Doc:** finding `docs/findings/2026-07-24-anchor-contrast-coherence-simulation.md`; spec di design
  `docs/superpowers/specs/2026-07-24-stage3-contrast-anchor-design.md`; plan
  `docs/superpowers/plans/2026-07-24-stage3-contrast-anchor-rework-plan.md`.
- **Dispatch/anchor produzione:** `R/stage4-dispatch.R`, `R/anchors.R`, `R/stage3-anchor-levels.R`.

## 7. COSA NON FARE
- NON lanciare re-cluster/re-pool senza il censimento passato + GO utente.
- NON verificare su un campione.
- NON dichiarare "validato/finale/paper-grade".
- NON tornare a ottimizzare i NOMI (sono ortogonali; alcuni sono ancora sbagliati — ethanol→TNF,
  anisole→calcitriolo — si correggono DOPO la coerenza).
- NON mettere Claude/subagent dentro la pipeline o dentro la validazione pubblicata.
