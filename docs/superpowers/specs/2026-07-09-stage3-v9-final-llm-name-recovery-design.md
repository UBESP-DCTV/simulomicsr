# Spec design — Ultimo run (v9): recupero-nome LLM nativo della pipeline + rifusione dei frammenti

**Data:** 2026-07-09
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Obiettivo:** l'**ultimo full run prima della pubblicazione** (v9), in cui i nomi delle meta-analisi
escono **corretti dalla pipeline** (non ritoccati post-hoc) e le entità spezzate sotto nomi-spazzatura
vengono **ricongiunte** (meta-analisi più potenti).
**Stato:** design approvato in dialogo (brainstorming 2026-07-09), pronto per il plan.

---

## 0. Perché questo run e cosa NON è

Il name-cleanup con Mistral (run T13, 2026-07-07) ha dimostrato che i nomi corretti delle meta-analisi
li trova **l'LLM**, non il resolver deterministico (es. "2-decenal"→Enzalutamide, "Abomaso"→Alzheimer,
"1-lauroyl-…"→Olaparib; **tutte** le 83 correzioni hanno `name_recovery_source = mistral_fallback`).
Ma quel passaggio è girato **post-hoc** sul v7 e **non è nella pipeline**. Requisito scientifico
(decisione utente 2026-07-09): i casi-studio devono **uscire dalla pipeline** con il nome giusto —
un revisore deve poter rilanciare la pipeline e ottenere quei risultati, etichette incluse. Un
rattoppo sui soli casi selezionati romperebbe la riproducibilità.

**Livello di ambizione scelto: (iii)** — non solo etichette corrette su tutte le meta-analisi, ma
anche **rifusione della frammentazione**: le entità spezzate sotto nomi diversi tornano un solo
cluster. Valore misurato (T13): **31 entità su ≥2 cluster, fino a k=91 se ricongiunte** → 31
meta-analisi più potenti. È l'unico livello che migliora *la scienza*, non solo le etichette.

Questo è inteso come **l'ultimo full run prima della pubblicazione**: per questo vi si fa entrare
*tutto* ciò che richiede un ri-calcolo (recupero-nome LLM + i fix deterministici pronti), così non ne
serva un altro.

## 1. Il flusso (due passaggi, per necessità)

Uovo-e-gallina: servono i cluster per dare a Mistral l'evidenza dei campioni; servono le correzioni
per rifondere i frammenti (il nome è parte dell'anchor → cambiare nome cambia il raggruppamento).
Quindi **due passaggi**:

1. **Build v9-pre** — Stadio 3 col resolver attuale (già migliorato: identità-gene, recupero-nome
   deterministico v7) + i fix del Blocco 3. Wall ~8h. Cache identità (H5→GSM) riusabile.
2. **Triage** dei cluster con nome sospetto (§2).
3. **Recupero-nome LLM** — Mistral legge l'evidenza dei campioni membri di ogni sospetto e propone
   l'identità vera. Riusa il macchinario T13 (`run_name_cleanup`, `.build_cluster_member_metadata`,
   `.apply_name_cleanup_policy`, precision-gate + canary). Costo trascurabile (T13: 193 cluster in
   **1m31s** sulla DGX).
4. **Applica** solo le correzioni ad alta confidenza **agli anchor** dei record dei cluster corretti.
   Le incerte (`flag_review`) → si tiene l'anchor originale + si dichiara.
5. **Ri-cluster** con gli anchor corretti → i frammenti si fondono. Implementato come
   **ri-raggruppamento** riusando gli anchor già calcolati nel passo 1 (non un secondo build da 8h);
   fallback = build completo se il ri-raggruppamento leggero non è praticabile. → v9-final.
6. **Re-pool Stadio 4** (come v8, ramo rem_group incluso). Wall ~17h. Riusa la cache counts
   (method-independent). → v9.
7. **Curazione Layer B** dal v9 pulito (i nomi escono dalla pipeline).

**Ogni passaggio pesante è gated** (gate utente separati; `setsid` per i detached multi-ora).

## 2. Portata dei sospetti (generosa, ma precision-gated)

Poiché l'LLM è di fatto gratuito, la portata è **generosa** per massimizzare la rifusione: si mandano
a Mistral **tutti** i cluster con nome sospetto che sono (a) poolabili, **oppure** (b) plausibili
frammenti di un'entità poolata (cluster piccoli con nome-spazzatura nello stesso tessuto/tipo di
un'entità reale). "Sospetto" = nome-spazzatura ChEBI/MeSH (composti improbabili come perturbazione),
`STR:`, `UNK`, `kind_chebi_zero_roles`, bassa `kind_confidence`, o triage `MAL_nominato`/`ETEROGENEO`.

**Qualità protetta da tre reti** (già nel macchinario T13):
- **Gate di precisione**: si applica solo `override` con match `STRONG` + confidenza alta; tutto il
  resto → `flag_review` (non applicato).
- **Canary**: un set di cluster noti-buoni (`OMOGENEO+ben_nominato`) che **non devono** cambiare; se
  cambiano → allarme, si ferma.
- **Incerte lasciate stare**: nessun cambio speculativo.

## 3. Fix deterministici da agganciare prima del run

- **Identità-gene** (ID gene canonico `HGNC:<numero>` + fusione geni doppi): già committato
  (`bb802ae`, `8dcd91e`, cache v5), si materializza al re-cluster. Nessun lavoro.
- **Sigla `STR:` per bersagli genetici ignoti** (`R/stage3-anchor-levels.R:~154`,
  `MEDIATED_HGNC_NO_LOOKUP`): oggi fabbrica `HGNC:<sigla grezza>` per target che HGNC non conosce (es.
  `HGNC:DTMYC`, 5 sigle in v7) → cambiare in `STR:<sigla>`. Stessa classe del fix I2. TDD.
- **Micro-fix casing `ChEMBL:`/`CHEMBL:`** (~20 cluster): uniformare il prefisso. TDD.

## 4. Cancello di validazione prima del calcolo pesante

Convenzione utente (validate-before-fullrun). Prima di impegnare le ~26-34h:
- **Smoke** del recupero-nome LLM su un campione dei sospetti v9-pre **+ tutto il set canary** → deve
  reggere come T13 (recupero alto; **0** falsi allarmi sui canary). Riusa lo smoke T13.
- **Misura delle fusioni attese** sulle 31 entità spezzate note (`.measure_fragmentation`): si fondono
  davvero? La frammentazione scende? k delle entità note sale?
- **Cache**: bump della versione della cache del recupero-nome/lookup se cambia il resolver (lezione
  `feedback_bump_lookup_cache_version` — un cambio senza bump riuserebbe il lookup stale).
- Solo se passa **in modo netto** → re-cluster + re-pool. Altrimenti STOP + report.

## 5. Cosa resta limite dichiarato

- **Buchi del resolver** irrisolvibili con confidenza da Mistral: glioblastoma (MeSH miss), anticorpi
  (Infliximab), varianti genetiche, siRNA → si tengono + si dichiarano.
- **Residuo "minestrone" biologici** (citochine/piccole-molecole ~36% ai livelli L3/L4, ~8% al livello
  granulare L0/L1 ≈ disease) → in gran parte pooling-per-classe *by-design*, documentato.
- **Combinazioni di farmaci** (es. estradiolo+R5020) non modellate.
- **Casi-limite genotipo-vs-sovraespressione** (APOE e4, questione K2).
- **I 279 trattati-soli** già chiusi (limite L7, `docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`).

## 6. Rischi principali e mitigazioni

- **Over-correction** (Mistral cambia un nome giusto): mitigata da precision-gate + canary + solo
  `STRONG`/alta confidenza + revisione a mano dei `flag_review` e degli `override` sui cluster che
  finiranno in vetrina.
- **Frammenti non catturati** (fragment tiny fuori portata): mitigata dalla portata generosa (b); il
  residuo si misura e si dichiara.
- **Re-cluster costoso**: mitigato dal ri-raggruppamento leggero (riuso anchor pass-1); fallback build
  completo se necessario.
- **Cache stale**: bump versione lookup (Blocco 4).
- **Circolarità** (nome↔clustering): risolta dai due passaggi espliciti; una singola iterazione
  (build→LLM→re-cluster), il residuo dopo un giro si dichiara (niente loop infinito).

## 7. Architettura / unità (isolate e testabili)

- **Selezione sospetti** `.select_suspect_clusters(clusters, triage)` — nuova; input clusters v9-pre +
  euristiche §2 → tibble candidates+canary (estende `.load_name_cleanup_candidates`).
- **Recupero-nome LLM** — riuso invariato di `run_name_cleanup` + helper T13 (`R/name-cleanup.R`).
- **Applicazione correzioni agli anchor** `.apply_name_corrections_to_records(assignments, side_table)`
  — nuova; mappa le correzioni (chiave = record/anchor originale + contesto) → anchor corretti, gated
  su `action == "override"`. Gestione over-correction via chiave contestuale.
- **Ri-raggruppamento** — riuso della fase di clustering dello Stadio 3 sugli anchor corretti (o build
  completo di fallback).
- **Fix deterministici** — patch mirate in `R/stage3-anchor-levels.R` (STR:) + casing ChEMBL.
- **Orchestrazione run** — script `analysis/p4-fase-f7-stage3-v9-*.R` (build pre → triage → LLM →
  apply → re-cluster) + re-pool `-stage4-...-v9.R` (copia -v8).

## 8. Testing e validazione

TDD bite-sized (`feedback_no_fretta_paper_grade`):
- `.select_suspect_clusters`: sospetti veri selezionati, canary etichettati, buoni esclusi.
- `.apply_name_corrections_to_records`: override applicato all'anchor giusto; `flag_review` non
  applicato; chiave contestuale evita over-correction (fixture con nome-spazzatura legittimo altrove).
- ri-raggruppamento: due frammenti con anchor corretto identico → un solo cluster (fusione); byte-compat
  sui cluster non toccati.
- Fix `STR:` / casing: TDD mirati.
- **Smoke gate** (§4) + **canary** su dati veri, prima del fullrun.
- Retrocompat: i cluster non-sospetti restano invariati (non-regressione).

## 9. Alternative scartate

- **Ritocco post-hoc dei soli casi selezionati** — scartata: i risultati devono uscire dalla pipeline,
  non essere derivati a mano (riproducibilità; decisione utente 2026-07-09).
- **Strada 1: cucire le 83 correzioni T13 come lookup deterministico** — scartata come *soluzione
  principale*: le correzioni sono evidence-based per-cluster (over-correction se globali) e coprono
  solo il v7; non catturano i nuovi frammenti del v9. (Può restare come warm-start del passo LLM.)
- **Livello (i) solo vetrine / (ii) solo etichette** — scartati: (iii) è l'unico che migliora la
  scienza (rifusione frammenti).
- **Passaggio singolo integrato** (LLM inline nel primo build) — scartato: l'LLM ha bisogno
  dell'evidenza aggregata del cluster; deduplicare i sospetti per anchor prima dell'LLM equivale a
  clusterizzare → i due passaggi sono inevitabili.
- **LLM per-record su tutti i record** — scartato: milioni di chiamate; il gating post-cluster sui
  sospetti è di ordini di grandezza più economico.

## 10. Riferimenti

- Finding name-cleanup T13: `docs/findings/2026-07-07-name-cleanup-results.md`; macchinario
  `R/name-cleanup.R`, script `analysis/p5-name-cleanup-run.R`, triage
  `analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv`.
- Identità-gene: commit `bb802ae`, `8dcd91e`. Re-pool v8: ADR-0022, finding 2026-07-06.
- Limite L7 (279 esclusi): `docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`.
- Memorie: `project_stage3_minestrone_rework`, `feedback_validate_before_fullrun`,
  `feedback_bump_lookup_cache_version`, `feedback_setsid_for_long_detached_runs`,
  `feedback_no_fretta_paper_grade`, `feedback_pipeline_config_uniformity`.
