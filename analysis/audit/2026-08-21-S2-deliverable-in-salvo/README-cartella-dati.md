# simulomicsr-stage4-v16 — QUALE delle quattro cartelle è il deliverable

Scritto il 2026-08-21 (sessione S2 dell'handout
`docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md`). Questo file è
versionato nel repository `simulomicsr` (branch `review-scientific-consistency-2026-06-10`)
in `analysis/audit/2026-08-21-S2-deliverable-in-salvo/README-cartella-dati.md`,
insieme al manifesto `SHA256SUMS.txt` di ogni file citato qui e allo script che
lo verifica (`10-manifesto-e-copia.sh verifica [DEST]`).

## Il deliverable è `20260819T185517Z-stage4-v16-3e31e59d` — 194 meta-analisi (A3 v16)

Le quattro cartelle hanno lo stesso suffisso (`stage4-v16-3e31e59d`: versione
del codice e run_id dello Stadio 4) e la stessa forma. Si distinguono **solo
dal timestamp**. Ecco che cosa sono:

| cartella | che cos'è | meta-analisi | Stadio 3 da cui viene (`analysis/p4-output/`) | master Stadio 1 / Stadio 2 |
|---|---|---:|---|---|
| **`20260819T185517Z`** | **DELIVERABLE CORRENTE — A3 v16.** Re-pool (16 pezzi ricomposti, 11 verdetti applicabili meno 2 orfani = `verdetti-A3.csv`) sullo Stadio 3 A3; Stadi 1 e 2 rigenerati su un sottoinsieme congelato di 2.566 studi con `VLLM_BATCH_INVARIANT=1`, innestati nei master vecchi. Annotato (`deliverable-annotato.*`). | **194** | `20260818T110906Z-stage3-v16-7f986159` — `clusters.rds` sha256 `43f3c6fe…8826d750` | `A3-stage1-master-innestato.jsonl` (508.037 record, sha256 `53f7f49a…c513eab`) · `A3-stage2-master-innestato.jsonl` (24.394 studi, sha256 `b9947746…fc05dd3`) |
| `20260819T184204Z` | **Duplicato senza annotazione** dello stesso re-pool: la ricomposizione dei 16 pezzi scritta 13 minuti prima. I suoi 5 file sono **byte-identici** ai 5 omologhi del deliverable (stesso `run_metadata.json`, timestamp interno `2026-08-19T18:40:05Z`); mancano solo `deliverable-annotato.csv/.rds`. Non contiene nulla che il deliverable non abbia. | — (non annotato) | idem | idem |
| `20260815T193851Z` | **RIFERIMENTO v16b** (master LLM vecchi): il deliverable precedente, oggi usato come termine di confronto per A3 (`10-blocchi.R`, `90-confronto-v16b.R`, rilettura delle 194). Corsie di sequenziamento collassate (18 collassi registrati). | 211 | `20260814T025911Z-stage3-v16-7f986159` — `clusters.rds` sha256 `b55e5ff2…cfc94e1f`. ⚠️ `CLAUDE.md` e alcuni script indicano `20260815T231154Z-stage3-v16-7f986159`: è **la stessa cosa**, byte-identica file per file (re-cluster parallelo a 8 worker, prova E3), differisce solo il timestamp dentro `run_metadata.json`. Il `run_metadata.json` dello Stadio 4 dice `20260814T025911Z`. | `p4-fase-f2-stage1-master-predictions-rescued.jsonl` · `p4-fase-f4-stage2-master-v3.jsonl` — il `run_metadata.json` dello Stadio 3 vecchio registra solo i conteggi (508.037 / 24.394), non percorso né sha |
| `20260815T121010Z` | **v16, superata**: primo re-pool sullo stesso Stadio 3 del riferimento, in cui il collasso delle corsie **non si accendeva** (`collapse_technical_lanes = TRUE` nel config ma `lane_collapses` 0 righe; 18 in v16b) e non esiste il registro `covariate_drops`. Usata dalle prove E1/E2/V16c di `analysis/audit/2026-08-13-rerun-prep/`. | 212 | `20260814T025911Z…` (idem riferimento) | idem riferimento |

**Dove sta scritto che cosa.** Il `run_metadata.json` dello **Stadio 4** registra
lo Stadio 3 (`stage3$dir`, `stage3$clusters_sha256` = sha256 del file
`clusters.rds`). I **master Stadio 1 e 2** sono registrati nel `run_metadata.json`
dello **Stadio 3** (`input_files$stage1_master`, `input_files$stage2_master`,
con percorso, conteggio e sha256 — ma solo dallo Stadio 3 A3 in poi; quello del
riferimento ha i soli conteggi).

**Che cosa serve per ricostruire il deliverable** (tutto nel manifesto e nella copia):

- re-pool soltanto: lo Stadio 3 `20260818T110906Z-stage3-v16-7f986159` (36 MB) +
  l'H5 ARCHS4 `human_gene_v2.5.h5` (47,86 GB, pubblico, MD5 `d61ae9b5…` in
  `analysis/p4-output/p4-beta-archs4-source.json`) + `verdetti-A3.csv` (in git);
  ~75 min in 16 pezzi (`docs/superpowers/specs/2026-08-16-HANDOUT-PROSSIMA-SESSIONE.md` §6);
- re-cluster + re-pool: in più i due master innestati (1,9 GB + 85 MB) e i
  dizionari ontologici di `~/.cache/R/simulomicsr/` con le release registrate
  nel `run_metadata.json` dello Stadio 3; ~2 h 30 m + 75 min;
- rifare anche gli stadi LLM: 40-60 ore di DGX, e **non** tornerebbe identico
  (`VLLM_BATCH_INVARIANT=1` rende riproducibile un run, non due run diversi).

**Copia di sicurezza.** Su un altro dispositivo fisico, con lo stesso manifesto:
vedi `docs/findings/2026-08-21-S2-deliverable-in-salvo.md` per il percorso.
Verifica: `10-manifesto-e-copia.sh verifica <DEST>`.

**Nessuna delle quattro cartelle è stata cancellata o spostata** (decisione che
spetta all'utente). Se si archiviano, la prima candidata è `20260819T184204Z`
(duplicato byte-identico), poi `20260815T121010Z` (superata, ma citata da tre
script di prova).
