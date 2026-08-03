# Che cosa deve produrre v15 — scritto PRIMA del lancio

**Data:** 2026-08-03 · **Task:** 13 (il cancello, provato sui file) del piano
`docs/superpowers/plans/2026-08-02-pipeline-impeccabile-pre-v15.md` (companion
`.superpowers/sdd/2026-08-02-pipeline-impeccabile-pre-v15/task-13-brief.md`).

Questo file esiste per un solo motivo: dopo il re-cluster pieno (~9-10h) e il re-pool
(~28h) qualcuno confronterà un numero con un'attesa. Se l'attesa fosse scritta DOPO aver
visto il risultato, ogni sorpresa diventerebbe "spiegabile a posteriori". Scritta PRIMA,
un numero diverso è un segnale, non una narrazione.

---

## 1. Provenienza — il `run_id`

- Il `run_id` è deterministico da input + config (`digest::digest(..., algo="xxhash32")`,
  `R/stage3-build.R:990`). `schema_versions$contrast_defrag = "v2"` (Task 2) entra
  nell'hash apposta: senza, v13/v14/v15 sarebbero indistinguibili (tutti `364547a7`).
- **Predetto per il run PIENO**: `7f986159` (calcolato nel piano, Task 2, sullo stesso
  meccanismo di hash con `contrast_defrag="v2"` sull'insieme pieno degli input).
- **Osservato per lo SMOKE** (subset di 250 studi, stesso codice, girato **due volte** in
  sessioni separate — vedi §5): `run_id = 7418a9a0` **entrambe le volte**, in
  `analysis/p4-output/20260802T221130Z-stage3-v15smoke-7418a9a0/run_metadata.json` (run
  esplorativo precedente) e `analysis/p4-output/20260803T000942Z-stage3-v15smoke-7418a9a0/`
  (run ufficiale del Task 13, log `analysis/audit/2026-08-02-fix/03-smoke-v15-task13.log`).
  **Diverso sia da `364547a7` sia da `7f986159`**, com'è corretto: lo smoke ha un
  INSIEME DI INPUT diverso dal run pieno (250 studi contro 24.394), quindi l'hash diverge
  anche a parità di codice. Che le DUE esecuzioni indipendenti (timestamp diversi, stesso
  codice committato) abbiano prodotto lo STESSO `run_id` è una conferma empirica, non solo
  teorica, che l'hash è deterministico da input+config e non dall'orologio. Questo
  **conferma l'invariante che conta**: i metadati DISTINGUONO i run, non solo per il token
  nel nome della directory ma nel campo stesso che uno script a valle può leggere e
  confrontare.
- **Invariante per il run pieno**: il `run_id` osservato **non deve essere `364547a7`**
  (altrimenti la cache/gli input non sono cambiati com'era il difetto pagato con
  `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` non bumpata, 2026-07-19). Che sia esattamente
  `7f986159` è un dettaglio di conferma piacevole ma non il gate — il gate è "diverso da
  364547a7", perché `7f986159` è stato calcolato a mano fuori da un run reale e potrebbe
  divergere per un dettaglio non modellato nel calcolo a mano.

---

## 2. Effetto 1 — la de-frammentazione (`tgfb`, `il17`): due entità, non un aggregato

Numeri di partenza, letti dal deliverable v13 esistente
(`analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.csv`, 191 righe,
verificato riga per riga in questa sessione):

| entità | riga oggi (v13) | k censito (Stadio 3) | k poolato (deliverable) |
|---|---|---:|---:|
| TGFB1 `HGNC:11766` | `cgroup_L5_2e16719f` | 65 → **78** | 49 → **59** |
| `STR:tgfb` (letteralmente "tgfb", non risolto) | `cgroup_L5_33673560`, k_effective **9** | si fonde in TGFB1 | la riga **scompare** (assorbita) |
| IL17A `HGNC:5981` | `cgroup_L5_b32ab7f6` | 8 → **12** | 7 → **8** |
| glioblastoma `MeSH:D005909` | — | **invariato** | **invariato** |

**glioblastoma è un'invariante attesa, non un guadagno**: la fusione è stata tolta da
`.CA_DEFRAG_ACCEPT` il 2026-08-02 (misurato: comprava un solo membro candidato su 40, e
non chiudeva lo split che doveva chiudere — `STR:glioblastoma` k=6 restava comunque
accanto a `MeSH:D005909` k=3). **Se il k di glioblastoma cambia nel run v15, è una
regressione da fermare**, non un effetto atteso.

**Solo il fronte del deliverable** (righe del CSV finale poolato, non il censimento
Stadio 3): oggi 191 righe. `STR:tgfb` (k_effective 9) confluisce nella riga TGFB1
esistente → **191 → 190 righe**, isolando SOLO l'effetto della de-frammentazione. Se
compare anche una riga `STR:il17` separata nel deliverable v13 e sparisce allo stesso
modo, il conto scenderebbe a 189 — verificato in questa sessione: **non esiste** una riga
`STR:il17` fra le 191 (l'unico hit su `HGNC:5981` è la riga IL17A stessa, k=7); quindi
l'effetto isolato della de-frammentazione sul conteggio righe è **esattamente −1**.

**Nell'impatto misurato sui MEMBRI del corpus (non sulle righe del deliverable)**:
**MISURATO** (non più solo atteso — `analysis/audit/2026-08-02-fix/10-impatto-v8.R`, run
completo sugli 87.092 confronti del corpus, log `10-impatto-v8.log`, dump
`impatto-membri-v8.rds`): **97 membri** cambiano entità, per intero coerente con la
previsione **86 da `tgfb` + 11 da `il17`**, e leggibile nel dettaglio delle quattro
scritture:

| da | a | membri |
|---|---|---:|
| `STR:tgfb`  | `HGNC:11766` (TGFB1) | 69 |
| `STR:tgf_b` | `HGNC:11766` (TGFB1) | 17 |
| `STR:il17`  | `HGNC:5981` (IL17A)  | 8 |
| `STR:il_17` | `HGNC:5981` (IL17A)  | 3 |

69+17 = **86** (tgfb), 8+3 = **11** (il17), totale **97** — esattamente l'atteso, alla
cifra. ⚠️ **97, non 137**: 137 era il numero prodotto dalla misura precedente (v7,
`impatto-membri-v7.rds`, script in scratchpad) quando la regola fondeva ancora **tre**
entità (`tgfb`, `glioblastoma`, `il17`); il differenziale (137−97 = 40) è esattamente il
numero di membri candidati di `glioblastoma` misurato nel Task 1, coerente con la
decisione di toglierla. Questo file non deve mai più riportare "137" o "tre entità" come
numero corrente.

Tutte e cinque le invarianti sono **verificate a zero/nessuna** sul dump
(`10-impatto-v8.log`, righe 67-72): 0 membri partiti da un'entità già risolta, 0 persi,
0 `control_key` divergenti, 0 direzioni divergenti, nessuna destinazione inattesa (solo
`HGNC:11766` e `HGNC:5981`).

---

## 3. Effetto 2 — la dedup corretta (Task 5): SEPARATO dall'Effetto 1

Questo è un effetto **indipendente**, già misurato sui dati v13 (Task 5, Passo 5,
`analysis/audit/2026-08-02-fix/10-dedup-effetto.R`), che **non ha nulla a che fare** con
`tgfb`/`il17`: la chiave di dedup del deliverable era ancorata su
`kind_effective_resolved || agent_id_resolved || direction` (l'anchor del **primo
membro**), che per i `cgroup` diverge da `contrast_entity` (il vero contrasto) in 188
cluster su 358. Risultato pre-fix: **53 gruppi scartati**, 49 dei quali **orfani**
(l'entità non ricompare altrove) — fra le vittime tamoxifene `CHEBI:41774` k=7,
testosterone `CHEBI:17347` k=6, un cluster su `NCBITaxon:1773`.

- **Selezione (candidati pre-pooling, `.identify_layer_a_clusters` su v13
  `clusters.rds`)**: da **305 a 354** cluster tenuti, **4 scartati** (duplicati veri,
  invece di 53). Misurato col gate di produzione vero (nessuna riscrittura locale del
  filtro), solo la funzione di dedup mockata per isolare "prima"/"dopo".
  **Numero atteso da verificare dopo il run: Δ = +49 gruppi candidati** (354 − 305),
  che coincide alla cifra coi 49 orfani misurati pre-fix (sopra) — non sono gruppi mai
  visti: sono i 49 che **rientrano** nella selezione perché il fix ancora la dedup su
  `contrast_entity`, il vero contrasto, invece che sull'anchor del primo membro.
- **Deliverable poolato (stima, NON un run reale)**: applicando ai 354 candidati lo
  stesso tasso di sopravvivenza al gate di pooling osservato in v13 (191 poolate / 305
  candidate ≈ 62,6%), la proiezione è **~215-225 righe**. È una STIMA basata su un
  rapporto storico, non il risultato del re-pool (~28h, non eseguito in questo task): il
  numero vero si misura solo dopo il re-pool.

**I due effetti si sommano ma vanno riportati separati**: l'Effetto 1 (de-frag) da solo
porta il deliverable **191 → 190** (un'entità in meno, per fusione); l'Effetto 2 (dedup)
da solo porterebbe la SELEZIONE **305 → 354** candidati e, per proiezione, il deliverable
poolato a **~215-225**. Il numero finale dopo v15 + re-pool sarà l'effetto combinato
(atteso nell'ordine di ~214-224, cioè "quello che la dedup guadagna" meno "la riga che la
de-frag consuma"), **non 191 → 190 da solo**: leggere un conteggio finale diverso da 191
come regressione, senza scomporlo nei due effetti, sarebbe un errore di lettura.

---

## 3bis. Effetto 3 — la chiave `record_id` (fix F1/F2 della revisione finale, 2026-08-03):
sette gruppi cambiano composizione, uno correggeva un braccio sbagliato

Terzo effetto, **indipendente** dai primi due (non tocca `tgfb`/`il17` né la chiave di
dedup): dallo Stadio 3 v15 lo stesso `comparison_id` può comparire più volte nello stesso
studio su bracci DIVERSI (`R/stage3-build.R:592-595`, misurato: 291 studi, 746 coppie su
754), e il `record_id` porta un terzo segmento con l'indice 1-based dell'occorrenza per
distinguerle. Il re-pool `analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R` aveva DUE copie
locali della risoluzione `record_id → campioni` (in `collect_sids()` e nel blocco di
annotazione) che non conoscevano questo terzo segmento e restituivano sempre vuoto/nessun
aggancio — fix in questa stessa sessione (F1: da 0 a 587 sample id sullo smoke §5; F2: da
0/102 a 102/102 `rid` agganciati sullo smoke §5), sostituendo le copie con
`.split_record_id()`/`.lookup_cmp()` di `R/stage4-dispatch.R`, già corrette per l'indice.

**Perché è un effetto sul deliverable e non solo un fix di script**: PRIMA del fix, quando
un `comparison_id` ricorreva più volte nello stesso studio, la risoluzione (ovunque nella
pipeline, non solo nel re-pool) restituiva sempre i campioni della PRIMA occorrenza — le
occorrenze successive risolvevano lo stesso braccio, quindi uno studio con `comparison_id`
duplicato o perdeva un membro (il braccio vero non veniva mai raggiunto) o ne poolava uno
sbagliato (stessi campioni contati due volte sotto due `record_id` diversi). Misurato
(revisione finale, prima del re-pool pieno): **sette gruppi del deliverable cambiano k**:

| gruppo | k prima | k dopo |
|---|---:|---:|
| vemurafenib | 8 | **9** |
| gefitinib | 7 | **8** |
| ciclosporina A | 3 | **4** |
| IFN-γ | 19 | **20** |
| IL1B | 17 | **18** |
| gemcitabina | 4 | **5** |
| JQ1 | 24 | **25** (due dei membri sono case study del Layer B) |

più una correzione di **composizione senza cambio di k**: il gruppo del **17β-estradiolo**
poolava 14 righe su 44 di un **altro composto** (il braccio sbagliato della comparison
duplicata) — corrette dal fix, non aggiunte.

**Numeri attesi da verificare dopo il re-pool pieno**: i sette k sopra (colonna "k dopo"),
e nel gruppo 17β-estradiolo 0 righe residue del composto estraneo (14/44 corrette). Questi
sette k **non sono spiegati né dall'Effetto 1 né dall'Effetto 2** (nessuno dei sette è
TGFB1/IL17A, nessuno era fra gli orfani della dedup): se dopo il run compaiono senza che
questa sezione venga letta, sembreranno inspiegati — è esattamente il motivo per cui questo
file esiste.

---

## 4. Cluster con entità dalla de-frammentazione

- `cluster con contrast_entity_source == "defrag"` (o equivalente tracciato nel
  cluster): atteso **> 0**. **Osservato due volte** nello smoke (§5), stesso numero
  entrambe le volte: **5** cluster (su un subset di 250 studi — non confrontabile 1:1
  col run pieno, ma prova che il meccanismo si esercita fuori dai test unitari, dentro
  la pipeline reale `build_stage3_clusters()`).

---

## 5. Smoke del re-cluster — osservato in questa sessione (Task 13, run ufficiale)

`Rscript analysis/p4-fase-f12-stage3-v15-defrag.R` (SMOKE, default, subset 250 studi),
girato con lo stesso codice ora committato (verificato: i commit successivi allo smoke
toccano solo testo/commenti in `R/stage3-defrag-alias.R`, "Nessuna modifica di
comportamento: solo testo" — commit `a63b0ac`). Log ufficiale del Task 13:
`analysis/audit/2026-08-02-fix/03-smoke-v15-task13.log`
(output `analysis/p4-output/20260803T000942Z-stage3-v15smoke-7418a9a0/`):

```
ℹ [v15] +38 serie che esercitano la de-frammentazione
✔ FINE. Wall totale: 10.7 min.
run_id=7418a9a0
cluster con entita' dalla de-frammentazione: 5
cgroup poolabili k>=3: 7 | k>=5: 1 | k max: 14
TGFB1 (HGNC:11766): k=14 (pavimento 61, non confrontabile: smoke e' un SUBSET)
```

PASS (N=5 > 0). I "pavimenti bandiera" nello smoke NON sono confrontabili con quelli del
run pieno (il subset non contiene tutti gli studi bandiera) — sono lì per verificare che
il meccanismo giri, non per predire i numeri finali.

---

## 6. Verdetti di coerenza

- **6 incoerenti**, come in v13 (`analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv`,
  verificato in questa sessione: 6 righe, nessuna con `ckey` che inizi per `HGNC:11766` o
  `HGNC:5981` — quindi nessuno dei 6 tocca le due entità de-frammentate, ed è per questo
  che l'atteso è "invariato" e non "da rileggere").
- **Se il file dei verdetti letto dopo v15 riporta 0 incoerenti, è un difetto dello
  strumento (i verdetti non sono stati letti/joinati), non un miglioramento reale**: la
  de-frammentazione non tocca nessuno dei 6 gruppi oggi incoerenti (CSF2, PTSD,
  Recurrence, HIV-1/influenza clinico-vs-sperimentale, IFN-α/R5020, IL1A/IL-1β) — nessuno
  di questi ckey coinvolge TGFB1 o IL17A.

---

## 6bis. Le cinque invarianti misurate a monte NON sono un sostituto della verifica sul run pieno — vanno ripetute sull'OUTPUT VERO

Le cinque invarianti del §2 (0 membri partiti da un'entità già risolta, 0 persi, 0
`control_key` divergenti, 0 direzioni divergenti, nessuna destinazione inattesa) sono
state misurate da `10-impatto-v8.R` chiamando `.ca_member_contrast()` **isolatamente,
etichetta per etichetta**, fuori dalla pipeline — è un DUMP del comportamento della
regola sulle etichette grezze dello Stadio 2, non un'esecuzione di
`build_stage3_clusters()`. Per costruzione **non vede il ramo `anchor`**
(`R/stage3-contrast-anchor.R:700-702`), che precede la de-frammentazione nella pipeline
reale e può risolvere un'entità (anche a `STR:`) prima che il ripiego di
`.ca_defrag_entity()` venga mai interrogato — è esattamente il meccanismo per cui
`glioblastoma` è stata tolta dalla lista (§2): il dump isolato l'avrebbe dichiarata
"si fonde e basta", mentre sull'output vero lo split restava aperto.

**Le stesse cinque invarianti vanno quindi ri-misurate sull'OUTPUT del re-cluster pieno**
(non sul dump, e non solo sullo smoke — lo smoke è un subset di 250 studi, non tutti gli
studi che toccano `tgfb`/`il17` sono garantiti dentro), leggendo `clusters.rds` vero:

1. **0 membri che cambiano entità partendo da un'entità già risolta** — sull'output vero:
   nessun cluster con `contrast_entity_source == "defrag"` deve avere membri il cui
   `contrast_entity` proveniva da un ramo diverso da `STR:` prima della de-frammentazione.
2. **0 membri persi** — il conteggio totale di membri sui cluster `cgroup` che toccano
   `tgfb`/`il17` non deve calare rispetto a v13 a parità di altri fattori.
3. **0 `control_key` divergenti** — nessun membro deve cambiare `contrast_control_key`
   per effetto della sola fusione dell'entità.
4. **0 direzioni divergenti** — stesso per `contrast_direction`.
5. **nessuna destinazione inattesa** — ogni cluster con `contrast_entity_source ==
   "defrag"` deve avere `contrast_entity` in `{HGNC:11766, HGNC:5981}`, mai altro, e MAI
   `MeSH:D005909` (glioblastoma: se compare, la sua esclusione da `.CA_DEFRAG_ACCEPT` non
   ha impedito la fusione da qualche altro percorso — fermarsi e indagare).

Se una di queste cinque, ri-misurata sull'output vero, non torna a zero/nessuna, **è un
difetto nuovo introdotto dal ramo `anchor` che il dump non poteva vedere**, non un
fallimento della regola stessa (che sul dump ha già passato il cancello alla cifra).

---

## 7. Come si legge questo file dopo il run

1. Confrontare il `run_id` osservato: deve essere diverso da `364547a7`.
2. Leggere `contrast_entity_source`/tracking sui cluster: cercare TGFB1 e IL17A, misurare
   k censito, confrontare con §2.
3. Confrontare `STR:tgfb` (e verificare che NON esista più come cluster poolabile
   separato, o se esiste che sia sotto la soglia k≥3 residua da fusione parziale).
4. Contare il deliverable poolato SOLO dopo il re-pool (non prima): confrontare col
   range combinato di §3, scomponendo i due effetti prima di dichiarare
   regressione/progresso. Verificare in particolare che i candidati pre-pooling tornino
   da 305 a 354 (**Δ = +49**, §3): un Δ diverso vuol dire che il fix della dedup non si è
   comportato come misurato su v13.
5. Rileggere i 6 verdetti di coerenza uno per uno sulla nuova composizione (FASE D0ter,
   §7 dell'handout) — "invariato" qui è una previsione sulle DUE entità fuse, non
   un'esenzione dal rileggerli.
6. Ri-misurare le cinque invarianti del §2/§6bis **sull'output vero** (`clusters.rds` del
   run pieno), non fidarsi del dump di §2: è la verifica che il dump, per costruzione, non
   può fare da solo (non vede il ramo `anchor`).
7. Controllare i sette k dell'Effetto 3 (§3bis: vemurafenib, gefitinib, ciclosporina A,
   IFN-γ, IL1B, gemcitabina, JQ1) e la composizione del gruppo 17β-estradiolo — un
   cambiamento su questi sette senza spiegazione nell'Effetto 1 o 2 è ATTESO, non un
   difetto nuovo da indagare.
