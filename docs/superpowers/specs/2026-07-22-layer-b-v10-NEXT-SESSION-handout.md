# Handout — Layer B v10 (sessione NOTTURNA AUTONOMA, senza gate)

**Data prep:** 2026-07-22
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Modalità:** run notturno **autonomo** — NIENTE domande, NIENTE `AskUserQuestion`,
NIENTE gate utente. **Dritti fino alla fine.** L'utente lancia il prompt e va a dormire.

---

## 0. Stato: tutto pronto e validato (2026-07-22)

La pipeline v10 è END-TO-END completa (re-cluster + re-pool Stadio 4 v10, ADR-0024).
Il deliverable finale è il **Layer B** (case-study publication-grade) sulle **184
meta-analisi cross-studio nominate (rem_group)** di v10. **La macchina Layer B v10 è già
scritta, repointata e VALIDATA fino al build** — la sessione notturna deve solo *eseguire
il build*, verificare, documentare e committare.

- Re-pool v10: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032`
- Stage 3 v10: `analysis/p4-output/20260720T180625Z-stage3-v10-364547a7`
- **Selection VALIDATA**: `analysis/layer-b-selection-v10.csv` — **18 case study rem_group**
  (10 flagship + 8 extra), tutti `exists_in_stage4=TRUE` (già verificato). 7 malattie
  (RCC/lung/gastric/hepatocell/colorectal/breast/prostate), 5 farmaci (bleomicina/
  physostigmine/tamoxifen/enzalutamide/fulvestrant), 5 patogeni (RSV/influenza/LPS/
  SARS/M.tuberc), 1 citochina (TGFB1).
- Script build: `analysis/p5-stage4-layer-b-build-v10.R` (parse OK, render Quarto reso
  NON-FATALE).

---

## 1. Piano autonomo (esegui in ordine, senza fermarti)

### Passo 1 — Build Layer B v10 (~15-30 min, setsid + poller orario/più stretto)

```bash
cd /home/user/simulomicsr
rm -f analysis/p5-stage4-layer-b-build-v10.log
setsid bash -c 'Rscript analysis/p5-stage4-layer-b-build-v10.R \
  > analysis/p5-stage4-layer-b-build-v10.log 2>&1' < /dev/null &
```
Monitora via `pgrep -f "bin/exec/R.*build-v10"` + tail del log (NON `run_in_background`
per il job vero — usa setsid, vedi memoria `feedback_setsid_for_long_detached_runs`).
Aggiorna con "fatto + ETA" a intervalli (memoria `feedback_hourly_updates_during_long_runs`;
per un run breve ~15-30 min basta un paio di check).

Output atteso: una dir `analysis/p4-output/<UTC>-layer-b-<run_id>/` con:
- 18 sottodir bundle (una per case study) con PNG@300 + SVG + summary_card + narrative.qmd stub;
- `layer_b_report.html` (aggregate, SE quarto regge — se no, NON-FATALE, i bundle bastano);
- `run_metadata.json` + `selection_resolved.csv`.

### Passo 2 — Verifica (criteri di successo, oggettivi)

```bash
# trova la dir prodotta
LB=$(ls -dt analysis/p4-output/*-layer-b-*/ | head -1)
echo "$LB"
ls "$LB" | wc -l                       # ~18 bundle + file aggregati
find "$LB" -name "*.png" | wc -l        # plot generati (atteso decine)
grep -E "batch OK|n_plots|report_html" analysis/p5-stage4-layer-b-build-v10.log | tail
```
**Successo** = build "batch OK", ~18 bundle dir create, PNG presenti. Il report HTML è un
plus (non-fatale). Se **alcuni plot** falliscono per un singolo cluster (es. forest solo
per REM, heatmap su single-sample batch) è ATTESO e graceful — non è un fallimento del run.

### Passo 3 — Finding + closeout (scrivi, non chiedere)

- **Finding**: `docs/findings/2026-07-23-layer-b-v10-case-studies.md` — riassumi: 18 case
  study rem_group generati, tabella (label, agent_id, k_eff, n_sig_strong, kind, tissue)
  presa da `selection_resolved.csv`/`layer-b-selection-v10.csv`; nota le flagship validate
  (opzione C = re-gate v10); n_plots generati/skippati; report_html sì/no.
- **ADR-0017 Addendum** (in coda a `docs/decisions/0017-layer-b-case-study-generator.md`):
  una riga "Layer B v10 = 18 case study rem_group-focused (deliverable v10)".
- **CLAUDE.md**: aggiungi un blocco "Stato 2026-07-23 (Layer B v10)" in cima (mirando lo
  stile dei blocchi esistenti): 18 case study rem_group, dir output, prossimo = compilare
  le `narrative.qmd` (Biological context/Findings/Discussion) per il paper.
- **Ledger** `.superpowers/sdd/progress.md`: appendi una riga Layer B v10.
- **Memoria** `project_stage3_minestrone_rework`: appendi "Layer B v10 fatto".

### Passo 4 — Commit (a piccoli passi, NO push, master invariato)

```bash
git add docs/findings/2026-07-23-layer-b-v10-case-studies.md \
        docs/decisions/0017-layer-b-case-study-generator.md CLAUDE.md
git commit -m "P5 Layer B v10: 18 case study rem_group generati + finding + closeout ..."
```
(bundle output in `analysis/p4-output/` = gitignored, NON committare i binari).

---

## 2. Regole per l'autonomia (IMPORTANTI)

- **NIENTE `AskUserQuestion`, NIENTE gate.** Ogni scelta è già presa in questo handout.
  Se emerge un bivio non previsto, scegli l'opzione più conservativa/paper-grade,
  DOCUMENTALA nel finding, e prosegui. Non fermarti.
- **Render Quarto**: già reso non-fatale nel build-v10. Se casca, i bundle sono il
  deliverable — prosegui.
- **Se il build fallisce del tutto** (errore fatale prima dei bundle): leggi il log,
  applica il fix minimo ovvio (es. un path, un pacchetto), ri-lancia UNA volta. Se
  fallisce di nuovo per la stessa causa, scrivi un finding "Layer B v10 BLOCCATO: <causa
  + repro + fix proposto>" e committa quello (fail onesto, non loop).
- **R con renv, NO `--vanilla`** (R 4.6.0 nel project). `setsid` per il run. Push = utente.
- Non toccare i run v9/v10 esistenti; non ri-eseguire re-cluster/re-pool.

## 3. Riferimenti

- Finding v10: `docs/findings/2026-07-22-stage4-v10-fallback-materialization.md`, ADR-0024.
- Layer B design: ADR-0017, spec `docs/superpowers/specs/2026-05-24-p5-stadio4-layer-b-design.md`.
- Selection builder (già eseguito): `analysis/p5-stage4-layer-b-select-v10.R` (rigenera
  `layer-b-selection-v10.csv` dai 119 rem_group gate-passing se serve).
- Precedenti Layer B: v7 (`p5-stage4-layer-b-build-v7.R`), batch pre-rework 56b911e6.
