# PROGRAMMA — fix del codice, poi re-run del fine settimana

**Scritto:** 2026-07-31 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Mandato utente (2026-07-31):** «da 1 a 5 fare tutto. Correggi le preesistenti (cancella pure se
serve). Il rerun lo facciamo nel week end partendo da stasera. Le narrative per ultime.»

> **Questo file è autosufficiente.** Se la sessione cambia, si riparte da qui: percorsi, comandi,
> criteri di accettazione e cancelli sono tutti dentro. Aggiornare la colonna «stato» man mano.

---

## 0. DOVE SIAMO ADESSO

| cosa | dove |
|---|---|
| deliverable poolato (191, arricchito) | `analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.{csv,rds}` |
| pooled v13 | `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296` |
| cluster v13 (Stadio 3) | `analysis/p4-output/20260728T151529Z-stage3-v13-364547a7` |
| master Stadio 2 | `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl` |
| bundle Layer B correnti (9) | `analysis/p4-output/20260730T220723Z-layer-b-828b020d` |
| selezione dei case study | `analysis/layer-b-selection-v13-finale.csv` |
| script di build Layer B | `analysis/p5-stage4-layer-b-build-v13.R` |
| script di re-pool | `analysis/p4-fase-f5-stage4-layer-a-rebuild-v13.R` |
| finding della sessione | `docs/findings/2026-07-31-layer-b-v13-case-study.md` |
| elenco dei difetti | `docs/superpowers/specs/2026-07-31-cose-da-sistemare.md` |

**Suite di partenza:** 3952 PASS / 3 FAIL / 3 ERROR / 37 SKIP.

**Regole non negoziabili** (valgono per ogni fase): TDD — il test si scrive prima e lo si vede
fallire · il gate è la coerenza, mai il numero · verifica su TUTTI, mai a campione · prima di
giudicare, verifica che lo strumento veda il dato per intero · nessun LLM nella pipeline · run
pesanti solo con `setsid` (SID==PID), mai `run_in_background` · `Rscript` **senza** `--vanilla` ·
fail onesto coi numeri · vietato scrivere «validato/finale» senza prova per-gruppo su tutti.

---

## FASE A — i bug che si vedono nelle figure

Obiettivo: i 9 bundle correnti contengono numeri sbagliati. Correggere e rigenerare.

### A1 · `k_effective` è per-gene, tre punti lo usano come se fosse del cluster ⬜

`k_effective` in `cluster_pooled.parquet` ha un valore **per gene**. Tre punti ne pescano uno a caso:

- `R/layer-b-summary-card.R:37` — `unique(cp_c$k_effective)[1L]`
- `R/layer-b-selection.R:110` — `dplyr::first(k_effective)`
- `R/layer-b-plot-forest.R:163-164` — `unique(top_genes$k_effective)[1L]`

Il valore giusto è `max(k_effective)` sul cluster intero: stesso criterio del deliverable
(`60-deliverable-annotato.R`) e del filtro di copertura.

**Test da scrivere prima** (`tests/testthat/test-layer-b-k-cluster.R`):
- una fixture con `k_effective` diverso per gene (es. 2, 5, 20) deve dare **20**, non il primo;
- il caso a un solo gene resta invariato (non-regressione);
- `NA` fra i valori non deve propagarsi né vincere;
- la didascalia del forest e la tabella di pre-validazione riportano lo stesso k della scheda.

**Criterio di accettazione:** rigenerati i bundle, il k di **tutte e 9** le schede coincide col
`k_effective` del deliverable. Verifica: lo snippet in §A4.

### A2 · La summary card non mostra l'efficacia del pooling ⬜

Le colonne nuove stanno nel deliverable ma non nella scheda accanto alla figura. Chi legge il case
study di Parkinson vede `k_effective: 10` e non che gli studi efficaci sono **1,8** e che il **73%**
del peso viene da un modello cellulare.

Aggiungere alla scheda: `k_kish`, `frazione_efficace`, `quota_top1`, `studio_dominante`,
`dominato`, `materiale_misto`, `dominato_da_modello`.

**Come alimentarla:** `.build_summary_card()` riceve già `stage3_metadata`. Si aggiunge un parametro
`pooling_effectiveness = NULL` (data.frame per cluster). **NULL deve restare retrocompatibile**: se
non arriva, la scheda esce come prima senza righe vuote.

**Test da scrivere prima:** con il data.frame → le righe compaiono coi numeri giusti; senza → la
scheda è identica a quella di oggi (non-regressione byte-a-byte sulle righe esistenti).

### A3 · Le etichette del volcano non deduplicano per simbolo ⬜

`R/layer-b-plot-volcano.R` non passa da `.rank_and_dedup_genes()`, a differenza di tabella e
heatmap. Lo stesso simbolo su più ID Ensembl può comparire due volte fra le 15 etichette.

**Test prima:** una fixture con `UBD` su tre ID Ensembl → una sola etichetta `UBD`.

### A4 · Rigenerare i 9 bundle e VERIFICARE ⬜

```
setsid nohup Rscript analysis/p5-stage4-layer-b-build-v13.R \
  > analysis/p5-stage4-layer-b-v13-fix.log 2>&1 < /dev/null &
# verificare SID==PID; wall atteso ~6 min
```

Verifica obbligatoria dopo il build (non basta che non crashi):

```r
d <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")
D <- "<nuova dir>"
for (f in list.files(D, "summary_card.md", recursive = TRUE, full.names = TRUE)) {
  cid <- basename(dirname(f)); txt <- readLines(f, warn = FALSE)
  k <- as.integer(sub(".*k_effective:\\*\\* ", "", grep("k_effective", txt, value = TRUE)[1]))
  stopifnot(k == d$k_effective[match(cid, d$cluster_id)])
}
```

**Criterio:** 9/9 schede col k giusto, 9/9 con le righe di efficacia, 0 etichette duplicate nei
volcano.

---

## FASE B — il codice nuovo deve stare nella pipeline

Obiettivo: **il re-run del fine settimana deve produrre il deliverable arricchito da solo.** Senza
questa fase il re-run rifarebbe un deliverable senza `k_kish`, e sarebbero 28 ore buttate.

### B1 · Velocizzare `compute_pooling_effectiveness()` ⬜

Oggi **612 secondi** su 32,4 M di righe (R base: `split`/`aggregate`/`vapply`). Riscrivere il cuore
con `dplyr` (già dipendenza) o `data.table`.

**Rete di sicurezza:** i 38 test esistenti devono restare verdi **senza modifiche**. In più:
verifica sui dati veri con `100-efficacia-pacchetto.R`, che confronta con la misura fatta a mano —
**deve restare scarto 0,0000000000 su `k_kish` e `quota_top1`, `k_studies` identico su tutti e 191.**

**Criterio:** stessi numeri, wall < 120 s.

### B2 · Innestare le due misure nella pipeline ⬜

`compute_pooling_effectiveness()` e `detect_mixed_material()` **non sono richiamate da nessun file**
di `R/` né dagli script di produzione (verificato con grep il 2026-07-31).

**Dove innestarle:** a valle, come è già stato fatto per la coerenza con
`R/stage4-coherence-annotation.R` — non dentro il pooling. Motivo: sono **annotazioni** del
deliverable, non parte del calcolo dell'effetto, e tenerle separate lascia il pooling invariato e
confrontabile con i run precedenti.

Nuovo file `R/stage4-deliverable-annotation.R` con una funzione unica che, dati `cluster_pooled`,
`per_study_de` e le etichette dei membri, restituisce il deliverable annotato con **tutte** le
colonne (etichetta, coerenza, efficacia, materiale). Gli script di audit
`60-deliverable-annotato.R` e `130-deliverable-arricchito.R` diventano suoi chiamanti.

**Test prima:** su fixture, la funzione produce tutte le colonne attese; un cluster presente nel
pooled ma assente nelle etichette **ferma** la funzione (stessa difesa del verdetto orfano in
`.annotate_coherence`); l'ordine delle righe è deterministico.

**Criterio:** rieseguita sui dati v13, produce un deliverable **identico** a quello attuale
(confronto colonna per colonna, non a occhio).

### B3 · Agganciare l'annotazione allo script di re-pool ⬜

`analysis/p4-fase-f5-stage4-layer-a-rebuild-v13.R` deve, a fine run, chiamare l'annotazione e
scrivere il deliverable arricchito accanto ai parquet. **Non fatale**: se l'annotazione fallisce, i
parquet restano (stesso trattamento del render quarto).

---

## FASE C — i test pre-esistenti

Mandato utente: «correggi le preesistenti (cancella pure se serve)».

### C1 · `test-smoke-e2e-stage1.R` e `test-smoke-e2e-stage2.R` ⬜

Chiamano l'API OpenAI. Senza `OPENAI_API_KEY` **falliscono invece di essere saltati**. Devono usare
`testthat::skip_if(!nzchar(Sys.getenv("OPENAI_API_KEY")), "OPENAI_API_KEY assente")` come prima
istruzione. Un test che fallisce per mancanza di una chiave è rumore che nasconde i fallimenti veri.

### C2 · `test-stage4-dashboard.R` ⬜

Richiede il binario `quarto`, assente su questa macchina — è lo stesso motivo per cui il render
della dashboard fallisce a ogni run pesante. Aggiungere
`skip_if_not(nzchar(Sys.which("quarto")), "quarto non installato")`.

### C3 · `test-stage4-gene-axis.R` — `E2 T2.4` ⬜

**Va letto prima di decidere.** Se il test è sbagliato si corregge; se coglie un difetto vero del
codice si corregge il codice; se non ha più senso (l'API è cambiata) si cancella **dichiarandolo**
nel commit. Non va silenziato.

**Criterio di fase:** suite completa con **0 FAIL e 0 ERROR**, e ogni SKIP con un motivo scritto.

---

## FASE D0bis — LA REGOLA DI DE-FRAMMENTAZIONE (da fare PRIMA del re-cluster)

Deciso il 2026-07-31 dopo aver rifatto l'analisi (vedi
`docs/superpowers/specs/2026-07-31-decisione-rerun.md`): **un re-pool da solo non cambia niente**
— nessuna riga del calcolo dell'effetto è cambiata dal run v13 — quindi l'unico re-run con
contenuto è re-cluster + re-pool con questa regola.

### La regola

> Prima di ripiegare su `STR:`, si prova a risolvere il token contro l'ontologia pretendendo un
> match **univoco** su un alias **per esteso** (>3 caratteri). Se l'alias aggancia più di una
> entità, **non si fonde** e si resta su `STR:`.

**È una regola per-record, non dipende dal corpus.** Così `ifna` resta `STR:` da solo (gli alias
`IFNA` agganciano IFNA1…IFNA21), mentre `tgfb` aggancia solo TGFB1 — **da verificare, è la prima
cosa da misurare.**

### Dove va, esattamente

`R/stage3-contrast-anchor.R`, nel ramo di ripiego intorno alla **riga 697-701**:

```r
} else if (!is.na(res$id) && !startsWith(res$id, "STR:")) {
  entity <- res$id; src <- "onto"
} else {
  tk <- .ca_clean_token(tval)
  if (nzchar(tk)) { entity <- paste0("STR:", gsub(" ", "_", tk)); src <- "STR" }
}
```

Il nuovo tentativo va **fra** i due: dopo `res$id`, prima del ripiego `STR:`.

### Trappole già pagate oggi, da non ripagare

1. **`contrast_entity_label_source` NON vale `"STR"`.** I valori veri sono
   `chebi`, `chembl`, `combo_parts`, `hgnc`, `mesh`, `override`, `str_literal`. Un filtro su
   `"STR"` seleziona **zero righe** e il rilevatore trova «nessuna frammentazione» — errore
   commesso e corretto il 2026-07-31.
2. **Solo alias per esteso (>3 caratteri).** Un match su una **sigla** non prova l'identità: è
   l'errore che il 2026-07-29 fece dare per buono `CHEBI:73572` (il tripeptide ha `LTA` fra i
   sinonimi).
3. **Il costruttore di alias esiste già**: `analysis/audit/2026-07-29-etichette-v13/40-id-vs-membri.R`
   righe 53-101, che legge i dump da `/home/user/.cache/R/simulomicsr/`. Non riscriverlo.
4. **Bumpare `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`** se si tocca il recupero-nome: senza, il
   re-cluster riusa il lookup su disco e produce un output identico (8 ore buttate, già successe).
   Se la regola sta solo in `stage3-contrast-anchor.R` il bump **non** serve — verificare.
5. **La simulazione del guadagno si fa con la funzione vera**:
   `analysis/audit/2026-07-31-layer-b-v13/180-guadagno-dopo-il-gate.R` mostra come — si uniscono gli
   assignment e si chiama `.build_group_rem_dispatch_from_stage3`.

### Criteri di accettazione

- Test scritti **prima** e visti fallire: `tgfb` → `HGNC:11766`; `ifna` → resta `STR:`; una sigla
  (≤3 caratteri) non fonde mai; un token che non aggancia nulla resta `STR:`.
- **Misura su TUTTI i membri prima del lancio** (modello: `2026-07-28`, che misurò su 28.294
  confronti): quante entità cambiano, quanti membri, quanti gruppi nascono o spariscono.
  **Se cambia più di quanto previsto dal §2 della decisione, ci si ferma e si guarda.**
- Attesi (misurati il 2026-07-31 sul deliverable): TGF-β1 poolati **49 → 59**, glioblastoma entra
  nel deliverable (k_eff 2 → 3), IL17A 7 → 8, `STR:ifna` **invariato**.

---

## FASE D — il re-run (fine settimana, parte stasera)

⚠️ **Non lanciare finché le Fasi A, B e C non sono chiuse**: il senso del re-run è produrre il
deliverable arricchito automaticamente.

### D0 · Decisione ✅ PRESA il 2026-07-31: re-cluster + re-pool

**«Solo re-pool» è ritrattata**: dal run v13 nessuna riga del calcolo dell'effetto è cambiata,
quindi riprodurrebbe un file identico. Vedi `specs/2026-07-31-decisione-rerun.md`.
Il re-run è **re-cluster (~9 h) + re-pool (~28 h)**, dopo la FASE D0bis.

<details><summary>Il ragionamento originale, superato</summary>

**Solo re-pool (~28 h) oppure re-cluster + re-pool (~37 h)?**

- **Solo re-pool** — rifà il pooling sui cluster v13 esistenti. Il deliverable esce arricchito. Il
  gruppo IL1A resta incoerente (mescola IL-1α e IL-1β).
- **Re-cluster + re-pool** — aggiunge la regola «entità con un gruppo proprio», che chiude IL1A.
  Costo: **~9 h in più**, e cambia la composizione dei gruppi, quindi **il censimento di coerenza va
  rifatto sui gruppi cambiati** (non su tutti: si confrontano gli insiemi dei membri e si rileggono
  solo i diversi, come il 28/07).

**Raccomandazione: solo re-pool.** ← **SBAGLIATA**: pesava il costo, che non è un argomento
scientifico, e il «riapre il censimento» era sovrastimato (cambiano **3 gruppi**, non 191).
</details>

### D1 · Pre-flight prima del lancio ⬜

```
DRY_RUN=1 Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v13.R
```
- input v13 presenti (Stadio 3 + master Stadio 2);
- `deliverable_methods = "rem_group"` (ADR-0026);
- spazio su `/mnt/wwn-0x5000039d58caca35/` (il run precedente ha scritto ~1,3 GB);
- la cache dei counts **si riusa** (chiave method-independent) — non va invalidata;
- ⚠️ **la cache del recupero-nome NON va bumpata**: è un re-pool, non un re-cluster.

### D2 · Lancio ⬜

```
setsid nohup Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v13.R \
  > analysis/p4-fase-f5-v14.log 2>&1 < /dev/null &
ps -o sid=,pid= -p $(pgrep -f p4-fase-f5-stage4-layer-a-rebuild-v13)   # SID deve == PID
```
Wall atteso **~28 h** (il run precedente: 28 h 17 m; il solo TGF-β1 ha preso 59 minuti).
**Aggiornamento ORARIO obbligatorio** durante il run: «fatto + ETA».

### D3 · Verifica ANTI-STALE dopo il run ⬜

Letta **dai file prodotti**, non dal log (modello: `50-antistale-v13.R`):

| controllo | atteso |
|---|---|
| `Methods` contiene solo `rem_group` | tutte le righe |
| prefisso `cgroup_L5_` sui `cluster_id` | 191 su 191 |
| i cluster poolati sono **esattamente** i previsti | `setequal`, non un conteggio |
| `k` per cluster identico al previsto | su tutti e 191 |
| I² e τ² non NA | su tutte le righe |
| **deliverable arricchito prodotto dal run** | tutte le colonne, senza passaggi a mano |

Poi il **controllo biologico** (§7bis del finding del 30/07): DHT su, enzalutamide giù sugli stessi
quattro bersagli; LPS, TGF-β1, SARS-CoV-2, IFN-γ coerenti con la letteratura.

### D4 · Ricostruire il Layer B sul nuovo pooled ⬜

Aggiornare `stage4_dir` in `analysis/p5-stage4-layer-b-build-v13.R`, rifare il pre-flight
(`20-preflight.R`) e ricostruire i 9 bundle (~6 min).

---

## FASE E — contenuto (per ultima, come da mandato)

### E1 · Le 9 narrative ⬜

`narrative.qmd` in ogni bundle: «Biological context / Findings / Discussion» sono segnaposto voluti.

### E2 · I Methods ⬜

Il materiale è già scritto nei finding, va raccolto: i 114 gruppi scartati dal gate e perché · i 6
incoerenti col motivo · TGF-β1 spezzato in tre · l'ID sbagliato dell'acido lipoteicoico · la
dominanza (**55% dei gruppi ha uno studio sopra il 50% del peso**) · il meccanismo per cui il gate
dei controlli interni **può concentrare l'errore invece di diluirlo** · la proprietà del REM per cui
l'ordinamento per FDR premia i geni consistenti e non quelli grandi · il filtro di copertura sulle
figure, dichiarato.

---

## STATO

| fase | | stato | esito misurato |
|---|---|---|---|
| A1 | k per-gene | ✅ | `.cluster_k_effective()` in tre punti; **9/9 schede col k giusto** (erano 4 sbagliate) |
| A2 | efficacia nella scheda | ✅ | 12 test; la scheda di Parkinson ora dice «1.8 of 10» e «GSE181029 73.2%» |
| A3 | dedup volcano | ✅ | `.volcano_labels()`, 8 test |
| A4 | rebuild + verifica | ✅ | `20260731T113513Z-layer-b-828b020d`, 9 bundle, 5,9 min |
| B1 | velocizzare | ✅ | **612 s → 91 s** (6,7×) con **scarto 0,0000000000** sui 191 |
| B2 | annotazione di pacchetto | ✅ | `annotate_stage4_deliverable()`, 18 test; **16 colonne su 16 IDENTICHE** al deliverable a mano |
| B3 | aggancio al re-pool | ✅ | il run scrive `deliverable-annotato.{csv,rds}` da solo, non-fatale |
| C1 | smoke E2E gated | ✅ | la chiave c'era ma dava 401 → serve `SIMULOMICSR_LLM_SMOKE=1` |
| C2 | dashboard quarto | ✅ | **il binario c'era**: il template usava `gene`, rinominata da FASE E1 a maggio |
| C3 | gene-axis E2 T2.4 | ✅ | attesa del test anteriore al fix T7a; codice corretto |
| D0 | decisione re-cluster | 🔶 **APERTA — serve prima del lancio** | |
| D1-D4 | re-run | ⬜ | |
| E1-E2 | narrative + Methods | ⬜ | |

**Suite:** da 3952 PASS / 3 FAIL / 3 ERROR a **3983+ PASS / 0 FAIL / 0 ERROR**.

### Due cose emerse strada facendo, che non erano nella lista

- **La dashboard non era rotta per il binario mancante.** Il template
  `inst/templates/stage4-dashboard.qmd` usava la colonna `gene`, che la FASE E1
  ha rinominato in `gene_id`/`gene_symbol` il 2026-05-28. L'errore veniva
  liquidato da due mesi come «quarto assente» (anche da me, nella prima stesura
  della lista). **Effetto collaterale utile: la dashboard tornerà a renderizzare
  nel re-run.**
- **`I2_med` nel deliverable attuale è approssimato.** Lo script vecchio
  calcolava la mediana **dentro Arrow**, che usa un t-digest; la funzione di
  pacchetto la calcola esatta in R. Differenza fino a **0,93** su 190 righe su
  191. I valori nuovi sono quelli giusti, e il re-run li produrrà.
