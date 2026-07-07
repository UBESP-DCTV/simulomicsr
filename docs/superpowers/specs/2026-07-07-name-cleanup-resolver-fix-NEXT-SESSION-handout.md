# Handout — Prossima sessione: fix resolver citochine → re-smoke → full run name-cleanup

**Data:** 2026-07-07
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, no push — 8 commit avanti da origin)
**Contesto:** name-cleanup Mistral (path batch DGX). Codice T1–T13 COMPLETO; smoke girato end-to-end sul DGX.

## In una frase

La pipeline batch DGX del name-cleanup **funziona end-to-end** (submit→Mistral→predictions→collect→
side-table→metriche) e **Mistral è semanticamente perfetto (13/13 mislabel)**. Lo smoke ha però
intercettato **una lacuna del resolver deterministico sulle citochine** (nome esteso non mappa sul
symbol HGNC). **Task unico prossima sessione: migliorare `.resolve_canonical_to_id` per le citochine +
la variante estradiol → re-smoke → se passa, full run T13 → closeout.**

## Stato attuale (tutto fatto e verificato)

- **Codice T1–T13 completo** (23+ commit sul branch): 9 moduli TDD (`R/name-cleanup.R` +
  `R/llm-client-vllm.R`) + fix Critical HGNC + 2 Important final-review + stage `name_cleanup` nel
  bundle/runner DGX (T10) + builder/assembler batch (T11) + gold+smoke (T12) + script run pieno (T13).
- **DGX sbloccato**: il blocco `0:53`/zero-log era una **regressione di rete su poddgx02** (reboot
  2026-07-06 17:22 → bond1 LACP morto → `/home` NFS non montata). **Ora RIPARATO** (ping NFS OK, `/home`
  montata+scrivibile). Diagnosi completa in `CLAUDE.md` §Note DGX + memoria `dgx_storage_projects_not_home`.
  (NB: NON era autofs — mia diagnosi iniziale sbagliata; NON era il codice/quota.)
- **Smoke girato (2026-07-07)**: job 29665 COMPLETED (4:56), 17/17 predictions valid_schema.
  Side-table + metriche prodotte. Deliverable: `analysis/audit/name-cleanup-smoke-sidetable.{rds,csv}`.

## Il problema da fixare (il resolver, NON Mistral)

Metriche smoke: **Recall 69,2% (9/13), Precision 81,8%, canary false-alarm 25% (1/4)** → gate DA RIVEDERE.
**Mistral ha identificato l'entità giusta in TUTTI i 13 casi.** I 4 "sbagliati" sono del resolver:

| record | Mistral ha proposto | risolto a | atteso | problema |
|---|---|---|---|---|
| gold_il6 | interleukin-6 | `<NA>` (keep) | HGNC:IL6 | full-name non trova il symbol HGNC `IL6` |
| gold_ifnb | interferon beta | MeSH:D016899 (override) | HGNC:IFNB1 | risolve a MeSH invece di HGNC:IFNB1 |
| gold_tnf | TNF-alpha | MeSH:D014409 (override) | HGNC:TNF | risolve a MeSH invece di HGNC:TNF |
| gold_estradiol | 17-beta-estradiol | `<NA>` (keep) | CHEBI:16469 | variante hyphen non risolve su ChEBI |
| canary_tnf | TNF-alpha | (id≠"TNF") → flag_review | (noop) | "TNF" vs "TNF-alpha" → id diverso → canary flaggato |

**Causa**: `.resolve_canonical_to_id` (`R/name-cleanup.R`, Task 6) per `cytokine_stim` fa
`try_hgnc` (=`.hgnc_lookup_symbol`, lookup per **symbol** es. `IL6`/`TNF`) poi `try_chebi`. I nomi
estesi ("interleukin-6", "TNF-alpha", "interferon beta") NON sono symbol HGNC → miss; e in alcuni casi
il `kind` che Mistral restituisce dispatcha su MeSH. **Da verificare come PRIMO passo**: leggere il
`kind` che Mistral ha dato a queste righe in `predictions.jsonl` del run (`/home/u0044/simulomicsr-dgx/
runs/20260707T091223Z-name-cleanup-dd0718/predictions.jsonl`, via `dgx_p4_collect` o rsync) — se Mistral
etichetta "interferon beta" con kind≠cytokine_stim, il dispatch va altrove (spiega il MeSH).

## Task prossima sessione (TDD, subagent-driven come il resto)

1. **Investigare** (1 passo): il `kind` per gold_ifnb/gold_tnf/gold_il6 nelle predictions (spiega MeSH-vs-HGNC).
2. **Migliorare `.resolve_canonical_to_id`** per le citochine (aggiunta piccola e precision-gated, con
   test TDD in `tests/testthat/test-name-cleanup-resolve.R`):
   - normalizzazione nome citochina prima del lookup HGNC: es. `interleukin-N`→`ILN`, `interferon
     alpha/beta/gamma`→`IFNA1/IFNB1/IFNG`, `tumor necrosis factor`/`TNF-alpha`/`TNF-α`→`TNF`. Un piccolo
     dizionario sinonimo→symbol HGNC curato (alta precisione) è l'opzione più pulita; oppure sfruttare
     il campo `name` di HGNC (non solo `symbol`) + normalizzazione hyphen/spazio/greche.
   - preferenza HGNC per `cytokine_stim`: se HGNC hit, NON scendere a MeSH.
   - variante estradiol: `17-beta-estradiol`/`17β-estradiol`→ deve risolvere `estradiol` (CHEBI:16469)
     via strip prefisso/normalizzazione (`.strip_name_markup` già gestisce β; serve gestire il prefisso `17-beta-`).
   - **Precision-gated**: non introdurre falsi positivi. Canary attesi 0 override spuri.
3. **Re-smoke**: `Rscript analysis/audit/2026-07-06-name-cleanup-smoke-submit.R` → poll job (ATTIVO,
   vedi note) → `Rscript analysis/audit/2026-07-06-name-cleanup-smoke-eval.R`. Gate atteso: recall ≥70%,
   canary false-alarm 0. (Il gold è già pronto: `analysis/audit/name-cleanup-gold.csv`.)
4. **Se PASS → full run T13**: `Rscript analysis/p5-name-cleanup-run.R submit` (125 candidati veri:
   costruisce input da stage3 v7 + master v3 + stream Stadio 1) → poll → `Rscript
   analysis/p5-name-cleanup-run.R eval` (collect → assemble → misura-B).
5. **Closeout**: finding `docs/findings/2026-07-07-name-cleanup-results.md` (n override/flag/keep + misura-B:
   quante entità frammentano, k_merged → GO/NO-GO scope B) + CLAUDE.md header + memoria
   `project_stage3_minestrone_rework` + ledger.

## Note operative DGX (IMPORTANTI)

- Accesso: `ssh -o BatchMode=yes u0044@logindgx.hpc.ict.unipd.it` (chiave OK). Login node = podhead1.
- **NON aspettare le notifiche background — POLLA ATTIVAMENTE** (l'utente l'ha ribadito; memoria
  `feedback_bash_background_notifications`). Poll job: loop `sacct -j <JID> --format=State -n -X` finché
  terminale, con `sleep 25`.
- **EVITA le parentesi tonde `(` `)` negli `echo` dentro `ssh 'bash -lc "..."'`** — rompono il parsing
  (ci ho perso tempo ripetutamente). Usa underscore.
- Ispezionare un compute node: `srun -p dgx12cluster -A dctv_dgx -w poddgxNN --gres=gpu:1 -t2
  --chdir=/tmp /usr/bin/bash -c "..."` (I/O forwarding; l'SSH login→compute è negato). NON usare
  `--export=NONE` nella srun di probe (svuota PATH).
- **Nodi**: poddgx02 (ora OK, riparato), **poddgx01 = VIETATO dall'utente**, poddgx03 assente da sinfo.
  `dgx_config()$nodelist="poddgx02"` va bene ora. Se poddgx02 si ri-guasta (bond1/reboot): il fix è
  cluster-side (admin), non codice — vedi memoria.
- Lo smoke gira in ~5 min (17 record). Il full run 125 sarà più lungo ma dello stesso ordine (batch,
  non per-cluster). Model già cachato (HF_HOME 101G). `/home` quota liberata (380G).

## Stato git

- Branch `review-scientific-consistency-2026-06-10`, master invariato, **8 commit non pushati**
  (T10-T13 code + gold/smoke + doc DGX + smoke side-table). Push a discrezione utente.
- Ledger completo: `.superpowers/sdd/progress.md` (sezioni 2026-07-06/07).
- Memorie: `project_stage3_minestrone_rework`, `dgx_storage_projects_not_home`,
  `feedback_no_whackamole_systematic_debug`, `feedback_bash_background_notifications`.
- Spec/plan feature: `docs/superpowers/{specs,plans}/2026-07-06-name-cleanup-mistral-*`.
