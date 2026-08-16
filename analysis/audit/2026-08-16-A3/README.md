# A3 — il metro del movimento, e la prova che lo rende leggibile

Ordine degli script. Nulla qui dentro tocca il DGX senza che sia detto.

| | script | cosa fa | gira su |
|---|---|---|---|
| 1 | `00-definisci-sottoinsieme.R` | definisce e **congela** il sottoinsieme (2.566 studi) con 4 casi di accettazione | locale, minuti |
| 2 | `10-costruisci-input-stadio1.R` | estrae le 86.898 righe di input, byte-identiche | locale, minuti |
| — | `PREVISIONI-A3-PRIMA-DEL-RUN.md` | **si scrive prima e non si tocca dopo** | — |
| 3 | `20-invarianza-build-e-submit.R` | prova della batch-invarianza a shard diverso — **SOTTOMETTE 4 job** | DGX, ~1h |
| 4 | `21-invarianza-confronta.R` | confronto coi tre casi di accettazione, il negativo per primo | locale |
| 5 | *(gated)* Stadio 1 su `analysis/input/A3-stage1-input.jsonl` | | DGX, ~3h |
| 6 | `30-innesta-master-stadio1.R` | innesta le predizioni nuove nel master, lascia il resto intatto | locale |
| 7 | *(gated)* rebuild input Stadio 2 + Stadio 2 sugli studi A3 | | DGX, ~6h |
| 8 | *(gated)* re-cluster intero + re-pool intero | | locale, ~4h |
| 9 | confronto con v16b + controllo biologico | | locale, minuti |

## Perché la prova della batch-invarianza viene prima

Il runtime divide i record fra i worker con `shard_round_robin` (record *i* →
worker *i* mod *n*) e per lo Stadio 1 usa `MICROBATCH = None`, cioè **una sola
chiamata con l'intero shard**. Lo shard dipende quindi da quanti record ha il
job. A3 ne rigenera 86.898; il re-run completo ne fa 508.037 in blocchi da
10.000. Sono job di dimensione diversa.

La misura del 2026-08-09 ha provato che la flag elimina la variazione **a parità
di shard** — lo dichiara lei stessa. Se non tiene anche quando lo shard cambia,
il movimento misurato da A3 mescola il rumore del modello con l'effetto della
dimensione del job, e A3 non misura più quello che dice di misurare.

Il disegno: gli stessi 1.000 record, una volta da soli e una volta mescolati in
5.000. Misurato sul disegno vero: **il 75,8% dei record condivisi finisce su un
worker diverso**.

⚠️ Il primo disegno interlacciava in modo uniforme e lasciava **ogni** record
sullo stesso worker (passo 5, 4 worker: 5 mod 4 = 1, come nel job da solo). La
guardia l'ha bocciato prima di sottomettere. Era lo stesso difetto che il test va
a cercare nella misura del 9 agosto.

## Codice di produzione toccato per rendere tutto questo possibile

| file | perché |
|---|---|
| `R/dgx-utils.R` | `.dgx_format_env_lines()` — `VLLM_BATCH_INVARIANT` **non esisteva nel repo**: `grep -r` dava zero occorrenze in `.R`, `.sh`, `.py` |
| `R/dgx-submit.R` | `dgx_p4_submit(env=)` |
| `inst/dgx/slurm/run_p4.sh` | segnaposto `__EXTRA_ENV__` **e** scrittura di `runs/<run_id>/container-env.txt`: la flag si verifica sull'artefatto, non nello script |
| `analysis/p4-fase-f4-stage2-build-input-v3.R` | `series_id` dall'**input**, non dall'output del modello; registro delle divergenze; guardia fatale sugli studi fantasma |
| `analysis/p4-fase-f13-stage3-v16-tre-cambi.R` | i 4 percorsi di input erano scritti nel codice: con master nuovi altrove il re-cluster sarebbe girato sui vecchi **senza fallire** |

Test: `tests/testthat/test-dgx-extra-env.R` (23 asserzioni, 8 negative).
