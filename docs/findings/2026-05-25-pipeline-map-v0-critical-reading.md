# Critical reading — pipeline-map v0 (2026-05-25)

> **Cosa è questo file.** Lettura GAN-of-self del documento gemello
> `2026-05-25-pipeline-map-v0.md` (output sub-agent Explore). Verifica
> indipendente di alcuni numeri chiave + lista di problemi/bias/lacune
> trovati durante la rilettura. Regola 3 dell'audit.
>
> **Non è un fix.** Le anomalie sotto sono FINDINGS da annotare (regola 2):
> nessuna modifica al codice o agli artefatti viene fatta in questa
> sessione. Le si valuterà nel passo 2 (fix uno alla volta) dopo che
> l'audit per-stadio è chiuso.

## Verifiche indipendenti eseguite (2026-05-25)

Comandi bash diretti, non subordinati alla parola del sub-agent.

| Claim della map v0 | Verifica | Esito |
|---|---|---|
| `p4-beta-stage1-master-predictions-rescued.jsonl` ha 879,167 record | `wc -l` | ✅ 879,167 |
| Dir `20260519T055547Z-stage3-2153addc/` esiste con clusters.rds, assignments.parquet, run_metadata.json | `ls -la` | ✅ presenti, size match (8.5 MB / 21 MB / 1.6 KB) |
| Dir `20260523T032601Z-stage4-96c43acb/` esiste con `cluster_pooled.parquet` 375 MB + `per_study_de.parquet` 384 MB | `ls -la` | ✅ size match (393 MB / 402 MB — agente arrotonda) |
| Dir `20260524T192649Z-layer-b-56b911e6/` esiste con 15 sotto-dir + layer_b_report.html + run_metadata | `ls -la` | ✅ 15 case-study dir + html 33 MB |
| Audit branch modifica solo Stage 3 R code + ontology, NON tocca Stage 4 / Layer B R code | `git diff master..HEAD --name-only -- 'R/stage4*' 'R/layer-b*'` | ✅ output vuoto: 0 modifiche |
| Audit branch modifica `R/anchors.R`, `R/ontology-lookup.R`, `R/stage3-*.R` (5 file R) + CLAUDE.md + analysis/p5-* + nuovi test | `git diff master..HEAD --name-only` | ✅ esattamente 38 file: 5 R-lib + 1 doc + 12 audit-scripts + 4 plan/spec/finding + 3 fixture rds + 13 test files |

**Conclusione verifiche**: I numeri/percorsi/scope claim chiave dell'Explore
agent reggono al sample-check indipendente. Nessuna prova di
fabbricazione. Le verifiche non-fatte (es: contare le righe dei parquet
13.691.756 e 12.009.646) restano in coda come check da fare nel ramo
dell'audit Stage 4.

## Errori e bias trovati nella mappa v0

### E1 — Etichettatura "Stage 5" usata per Layer B (errore semantico, paper-grade)

**Cosa dice la map v0**: sezione `## Stage 5 — Layer B case study`.

**Cosa dice il codice e CLAUDE.md**: Layer B è il **Layer B di Stadio 4**
(case study showcase post-pooling), NON lo Stadio 5. CLAUDE.md §
"Visione del progetto" elenca esplicitamente:

> 5. **Stadio 4 DE per-studio + Stadio 5 meta-analisi** (`DESeq2`/`limma` + `metafor` REM)

Lo Stadio 5 meta-analisi **non è stato ancora costruito** ("spec design
da scrivere"). Layer B è una parte ortogonale di Stadio 4: case-study
showcase paper-grade, non meta-analisi.

**Perché conta**: usare "Stage 5" per Layer B confonde il lettore e
nasconde un gap reale (Stadio 5 meta-analisi non esiste). Per un audit
Nature-grade, l'etichettatura corretta è la prima onestà.

**Conseguenza per l'audit**: la mappa-pipeline finale (Tappa D, versione
semplice) deve usare "Stadio 4 — Layer A (pooling)" e "Stadio 4 — Layer
B (case study)" come due sezioni di Stadio 4; "Stadio 5" va etichettato
come **non-built** con stato esplicito.

### E2 — Bias del sub-agent: rationalization di "code unchanged on audit branch"

**Cosa dice la map v0** (sezione Stage 4 Code-drift-since-artifact):

> **Minor upstream dependencies**:
> - Stage 4 calls `load_stage3()` which now has v3.1.1 resolver
>   integration (on audit branch). However, Layer A fullrun artifact
>   (96c43acb) was built with master Stage 3 code (v3.0). This is
>   benign: Stage 4 reads Stage 3 parquet/RDS, doesn't re-execute Stage
>   3 build.

**Perché è una rationalization sospetta**: il sub-agent dichiara "this
is benign" senza aver verificato il comportamento di `load_stage3()`
nelle versioni master vs branch. È possibile (non escluso) che la
versione branch faccia introspezione/trasformazione del payload basata
su `schema_versions.anchor`. Anche solo un side-effect (es: warning
emesso, fallback path attivato, override silente di colonne)
inquinerebbe Layer B se Layer B venisse ri-eseguito sul branch.

**Conseguenza per l'audit**: quando si arriva a Stage 4 audit, includere
una verifica esplicita:
1. `git diff master..HEAD -- R/stage3-load.R` (o equivalente loader)
2. Smoke-test che `load_stage3(<v3 baseline path>)` dia output bit-equivalente su master vs branch
3. Documentare il risultato come parte del trust report Stage 4

### E3 — Test count è una stima ad occhio, non grep esatto

**Cosa dice la map v0**: "Total: ~70 test functions" (Stage 1), "~65"
(Stage 2), "~92" (Stage 3), "~105" (Stage 4), "~42" (Layer B).

**Perché conta**: questi numeri sono usati per dedurre "test coverage
gaps" (Layer B 42 vs Stage 4 105 — agente segnala come finding). Se i
numeri sono stime ad occhio, il finding è debole.

**Conseguenza per l'audit**: durante il trust report per-stadio, fare
`grep -c "^test_that\|^expect_" tests/testthat/test-<stadio>*.R`
puntuale e citare il numero esatto, non la stima.

### E4 — Manca audit della versione di catena (chain-of-custody)

**Cosa dice la map v0**: dice "no drift" tra master HEAD e i tag che
hanno prodotto gli artefatti (`p5-stadio4-complete`, `p5-stadio4-layer-b-complete`).

**Cosa non verifica**: che `dplyr`, `metafor`, `variancePartition`,
`limma`, `clusterProfiler`, `ComplexHeatmap` e altre **dipendenze
Bioconductor/CRAN** siano alla stessa versione di quando furono
prodotti gli artefatti (es. `cluster_pooled.parquet`, Layer B PNGs).
Se renv.lock è cambiato tra fullrun e oggi, il "no code drift" non
basta a garantire riproducibilità bit-equivalente.

**Conseguenza per l'audit**: verificare `renv.lock` SHA1 al tempo dei
tag vs oggi. Se diverso → finding.

### E5 — Layer B legge `analysis/layer-b-selection.csv` USER-CURATED

**Cosa dice la map v0**: "Selection CSV (user-curated) | 15 rows".

**Perché conta**: la selection è prodotto umano, non output algoritmico.
Una catena audit-grade deve sapere COME è stata costruita: a partire
da `analysis/p5-stage4-layer-b-shortlist.R` (31 candidates) → curation
manuale → 15. Il CSV stesso è un artifact di processo umano da
documentare nel paper Methods, non un output deterministico.

**Conseguenza per l'audit**: verificare che `analysis/layer-b-selection.csv`
sia (a) committato sul branch, (b) provvisto di criteri di selezione
tracciabili nel commit message, (c) collegato al log del run-id
shortlist (output di `p5-stage4-layer-b-shortlist.R`). Audit Layer B
deve esplicitamente notare quale parte è algoritmica e quale è curated.

### E6 — Manca scrutinio sui caching layer (regola anti-falsi-positivi)

**Cosa dice la map v0**: 4 livelli di cache documentati (Stage 1/2 LLM
hash(messages), Stage 4 xxhash32 counts, Stage 3 anchor precompute,
Entrez GSE cache).

**Cosa non scrutina**: chi garantisce che la cache non sia stata
inquinata. Esempio scenario peggiore: cache Stage 4 counts contiene
risultati di un run precedente con bug paralog HLA non risolto; cache
viene riutilizzata in run 96c43acb post-fix; output cluster_pooled
contiene MIX di gene-symbol-deduplicated (cache miss) + gene-symbol-non-deduplicated
(cache hit). Questo invaliderebbe TUTTO l'output.

**Conseguenza per l'audit**: il trust report Stage 4 DEVE verificare che
(a) la cache Stage 4 è stata svuotata/regenerata DOPO il fix
`make.unique()` paralog HLA, oppure (b) la cache è chiavata in modo
da non poter contenere risultati pre-fix. Se nessuno dei due è vero
→ rebuild Stage 4 obbligatorio anche se code-drift è zero.

### E7 — Map non distingue artefatti "scientifici" da artefatti "infrastrutturali"

**Cosa dice la map v0**: elenca file `qc_report.rds`, `non_processable.rds`,
`dashboard_data.rds`, `run_metadata.json`, `selection_resolved.csv` allo
stesso livello dei parquet DE.

**Perché conta**: in audit Nature-grade, gli artefatti scientifici (DE
risultati, p-value, logFC) hanno requirement diversi dagli artefatti
operativi (logs, dashboard, metadata). I primi devono essere
bit-equivalent-reproducible o documented-stochastic; i secondi solo
loggable.

**Conseguenza per l'audit**: nel report Stage 4 trust, classificare ogni
artefatto come `SCIENTIFIC_OUTPUT` (audit obbligatorio) vs
`OPERATIONAL_LOG` (audit best-effort).

## Lacune note del Tappa B (cosa NON è stato fatto)

1. **Non sono state contate le righe dei parquet** (cluster_pooled
   13.691.756 e per_study_de 12.009.646). Solo size-on-disk match. La
   conta righe richiede `arrow::open_dataset() |> dplyr::count()` (1
   chiamata R). Riservato a quando si entra in Stage 4 audit.
2. **Non sono stati ispezionati i `run_metadata.json`** dei 3 run-id
   (Stage 3 2153addc, Stage 4 96c43acb, Layer B 56b911e6). Confronto
   degli schema_versions interni vs codice attuale potrebbe rivelare
   inconsistencies.
3. **Non è stato verificato che il prompt Stage 1** in `R/llm-stage1.R`
   sia coerente con il `inst/schemas/sample_facts.stage1.v3.json`.
   Un prompt che chiede campi non in schema o uno schema che vincola
   campi non chiesti = bug paper-grade. Riservato a Stage 1 audit.
4. **Non sono stati eseguiti i test**. Sub-agent ha contato i file di
   test, non ha mai eseguito `devtools::test()`. La copertura
   testthat-eseguita potrebbe essere diversa dalla copertura
   testthat-presente (es. test skipped).
5. **Non è stato verificato che la cache LLM `analysis/cache/`** sia
   immutabile o regenerable. Audit Stage 1/2 deve coprire questo.

## Raccomandazione per la Tappa successiva

L'audit ha ora un anchor scritto (map v0) + una lista esplicita di
errori e bias (questo file). Le tappe avanti come da piano:

- **Tappa C** (codex review): inviare la map v0 a `codex:rescue` per
  lettura indipendente. **Attenzione**: codex è un LLM separato ma con
  bias correlati. Va usato come oracolo di **lettura strutturale del
  codice** (vede gli stessi file ma con architettura diversa), non come
  validazione scientifica.
- **Tappa D** (versione semplice per carta): la map v0 deve essere
  collassata in una pagina con (i) box per ogni stadio (input → funzione
  → output), (ii) Layer A/B come sotto-livelli di Stadio 4, (iii) un
  flag "non ancora costruito" per Stadio 5 meta-analisi, (iv) anchor a
  file/funzioni reali (non box vaghi tipo "LLM").
- **Tappa E** (Stage 1 audit): iniziare percorrendo il primo stadio
  end-to-end con record concreti (regola 6). Spec del workflow trust
  report per-stadio da scrivere PRIMA di iniziare.

## Stato findings

Findings da questo file (E1-E7) + lacune (L1-L5) raccolti per future
fix sessions (passo 2). Numerati per riferimento incrociato.

| ID | Severity | Stadio impattato | Stato |
|---|---|---|---|
| E1 | low (semantica) | Layer B / Stage 5 doc | open |
| E2 | medium (verifica mancante) | Stage 4 | open, da verificare in Stage 4 audit |
| E3 | low (debt) | tutti | open, fix in trust reports |
| E4 | medium (riproducibilità) | tutti | open, da verificare prima del paper |
| E5 | low (documentazione) | Layer B | open |
| E6 | **HIGH (potenziale invalidazione output)** | Stage 4 | **open, blocking finding finché non verificato** |
| E7 | low (struttura audit) | tutti | open, definire classificazione in Stage 1 trust report |
| L1 | n/a | Stage 4 | da fare in Stage 4 audit |
| L2 | n/a | Stage 3, 4, Layer B | da fare in Stage 3/4/LB audit |
| L3 | n/a | Stage 1 | da fare in Stage 1 audit |
| L4 | n/a | tutti | da fare per ogni stadio |
| L5 | n/a | Stage 1, 2 | da fare in Stage 1/2 audit |

---

**Document version**: v0 critical reading (2026-05-25)
**Generated by**: Claude main session post-Explore-dispatch, regola 3 GAN-of-self
**Scope**: trovare bias / errori / lacune nella map v0; NIENTE FIX.
