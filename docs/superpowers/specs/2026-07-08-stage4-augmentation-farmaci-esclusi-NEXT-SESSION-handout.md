# Handout — Prossima sessione: recupero dei farmaci esclusi (augmentation "passo 3")

**Data:** 2026-07-08
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, no push)
**Prerequisito:** lo Stadio 4 v8 (`rem_group`) è chiuso e girato (finding
`docs/findings/2026-07-06-stage4-rem-group-results.md`, ADR-0022 Accepted). Il
name-cleanup (etichette + identità gene) è chiuso.

## In una frase (per lo scienziato)

Ci sono **279 gruppi di esperimenti** — soprattutto **farmaci** e alcune
malattie — che oggi **non producono nessuna meta-analisi**, perché sono soggetti
*trattati* **senza un gruppo di controllo nello stesso studio**. La pipeline
confronta trattato-vs-controllo *dentro* lo studio, quindi questi restano fuori.
L'obiettivo è **recuperarli** prendendo in prestito controlli da **altri studi
comparabili** (stessa linea cellulare / tessuto / piattaforma). È scienza nuova:
più meta-analisi, senza inventare nulla.

## Perché cadono (dettaglio tecnico)

Dal fullrun Stadio 4 v8 (`non_processable = 382`): **279
`rem_group_insufficient_in_study_controls`** + 103 `mega_rank_deficient` (questi
ultimi sono i mega senza ≥2 livelli, questione diversa, NON in scope).

I 279 si distribuiscono per numero di studi con controllo utilizzabile:
**131 a k=0, 93 a k=1, 55 a k=2** (la soglia per poolare è k≥3 studi distinti).
Sono gruppi per cui **non esiste una comparison Stadio 2 in cui quel gruppo è il
`treated_group`** → nessun lato-controllo in-studio → il pooling REM per-studio
non parte. Origine nel codice: `.build_group_rem_dispatch_from_stage3`
(`R/stage4-dispatch.R:313`) via `.lookup_cmp_by_treated_group` — se non trova la
comparison, il gruppo cade.

## Cosa esiste GIÀ da riusare (non partire da zero)

La pipeline ha già un meccanismo di **augmentation cross-studio del
lato-controllo**, usato dal ramo `mega_aug`:
- **baseline-pool pairing** `R/stage4-baseline-pool-pairing.R`: pesca controlli
  (baseline) comparabili da altri studi per augmentare un braccio.
- **correzione di Franchini** `R/stage4-franchini-correction.R`: quando più
  contrasti condividono lo **stesso** pool di controllo preso in prestito, le
  loro stime NON sono indipendenti → matrice di covarianza che modella la
  correlazione (`.build_franchini_V_matrix`, `rho`). **Da applicare anche qui**:
  se molti farmaci pescano lo stesso controllo, il REM va corretto.
- **de-dupe SAMN cross-GSE** `R/stage4-samn-dedupe.R`: evita di contare due volte
  lo stesso campione fisico ricomparso in più studi (già integrato).

"Passo 3" = **estendere l'augmentation baseline-pool al ramo `rem_group`**, che
oggi la usa solo per il lato-controllo in-studio.

## Domande di DESIGN aperte (→ brainstorming, NON decidere ora)

1. **Da dove pescare i controlli?** Vincoli di comparabilità: stessa linea
   cellulare / tessuto / piattaforma di sequenziamento; controlli "sani/vehicle"
   dallo stesso contesto. Quanto stringente? (troppo largo = confronti
   inquinati; troppo stretto = pochi recuperi).
2. **Ibrido o omogeneo?** Il ramo `rem_group` fa REM per-studio; qui il controllo
   è cross-studio → per uno stesso "studio" trattato-solo il controllo viene da
   fuori. Come definire l'unità di sintesi (k = studi distinti trattati? o
   coppie trattato-studio × controllo-prestato?). Evitare pseudo-replicazione
   (vedi `.collapse_arms_by_study`, opzione C già adottata in v8).
3. **Correlazione da controllo condiviso** → Franchini `rho`: quale valore, e
   quando attivarla.
4. **Soglie**: k minimo, dimensione minima del pool di controllo, cap.
5. **Batch/covariate**: il controllo cross-studio introduce batch → covariate
   già presenti (`instrument_model`, `aligner_class`, FASE E3); verificarne
   l'adeguatezza qui.
6. **Rischio scientifico principale**: comparabilità del controllo preso in
   prestito. Serve un **gate di validazione before-fullrun** (come sempre): uno
   smoke su un campione dei 279 con controllo dei confronti (bandiera: farmaci
   noti tipo enzalutamide/tamoxifene/olaparib che oggi cadono).

## Workflow proposto (convenzione utente)

1. **Brainstorming** (`superpowers:brainstorming`) → risolvere le 6 domande sopra
   con l'utente (gate). Poi **spec** + **plan** + **HUMANE** in
   `docs/superpowers/{specs,plans}/`.
2. **Implementazione subagent-driven TDD** sul ramo esistente (estendere il
   dispatch + baseline-pool al caso treated-only cross-studio). NON re-cluster
   Stadio 3 (v7 va bene); è un **re-pool Stadio 4** (come v8).
3. **Gate smoke** su un campione dei 279 (validate-before-fullrun) → misurare
   quanti dei 279 si recuperano davvero e la qualità dei confronti.
4. **Fullrun gated** (re-pool, ~ore, `setsid`; **riusare la cache counts**,
   method-independent — vedi lezione v8) → verifica anti-stale (Methods include
   il nuovo ramo, N recuperati) → closeout + ADR.

## File chiave

- `R/stage4-dispatch.R` (`.build_group_rem_dispatch_from_stage3`,
  `.lookup_cmp_by_treated_group`) — dove i 279 cadono.
- `R/stage4-baseline-pool-pairing.R` — augmentation controlli (da estendere).
- `R/stage4-franchini-correction.R` — correlazione baseline condiviso.
- `R/stage4-build.R:158` — orchestrazione dispatch.
- Input: stage3 v7 `analysis/p4-output/20260703T113045Z-stage3-v7-364547a7/`,
  stage2 master v3 `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`.
- Elenco dei 279: `non_processable.rds` nel run v8
  `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v8/20260706T112612Z-stage4-v8-a500d032/`
  (filtrare `reason == "rem_group_insufficient_in_study_controls"`).

## Riferimenti

- Finding v8: `docs/findings/2026-07-06-stage4-rem-group-results.md` (§4 i 279).
- ADR-0022: `docs/decisions/0022-stage4-rem-group-named-metaanalyses.md`.
- Spec/plan rem_group: `docs/superpowers/{specs,plans}/2026-07-05-stage4-rem-group-named-metaanalyses-*`.
- Ledger: `.superpowers/sdd/progress.md`.
- Memorie: `project_stage3_minestrone_rework`, `feedback_validate_before_fullrun`,
  `feedback_setsid_for_long_detached_runs`, `user_de_methods_benchmark`.

## Nota DGX

Il re-pool gira in locale (come v8, su `/mnt/wwn-…`), NON serve il DGX (quello
serve solo per Mistral). `setsid` per i run multi-ora (memoria
`feedback_setsid_for_long_detached_runs`), NON `run_in_background`.

---

## Prompt per aprire la prossima sessione (copiare come primo messaggio)

> Riprendiamo il recupero dei farmaci esclusi dallo Stadio 4 ("augmentation
> passo 3"): i ~279 gruppi `rem_group_insufficient_in_study_controls` (trattati
> senza controllo in-studio) che oggi non producono meta-analisi. Leggi
> l'handout `docs/superpowers/specs/2026-07-08-stage4-augmentation-farmaci-esclusi-NEXT-SESSION-handout.md`
> per intero, poi partiamo dal **brainstorming** sulle 6 domande di design
> (comparabilità dei controlli presi in prestito, unità di sintesi, Franchini,
> soglie) prima di scrivere spec/plan. Niente run finché non abbiamo spec, plan e
> uno smoke gate. Master invariato, no push.
