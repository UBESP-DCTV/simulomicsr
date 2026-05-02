# ADR-0005: Trigger e procedura di migrazione su server con più spazio

- **Status:** Accepted
- **Date:** 2026-05-02
- **Deciders:** Luca Vedovelli
- **Supersedes:** —

## Context

Lo sviluppo P1+P2 di simulomicsr gira sul Mac locale dell'autore (R 4.5.2,
arm64). Le risorse locali bastano per:
- xlsx classificato 130k righe (~10 MB, in `data-raw/`, committato);
- dev set 100 sample + cache LLM JSONL+SQLite (~100 KB);
- pipeline `targets` con stato in `analysis/_targets/` (~1 MB).

Diventerà invece insostenibile localmente:
- il dump HDF5 di ARCHS4 (~5-10 GB) con i 700k+ sample dello Stadio upstream;
- il run massivo Stadio 1 in Batch API (700k+ chiamate, ~$300-700, output JSON
  cumulativo ~5 GB);
- le matrici di espressione raw richieste da Stadio 4 (DESeq2 per-studio).

L'utente ha un server con più spazio dove eseguire il run massivo. La
domanda è **quando spostarsi** e **come farlo senza perdere stato che vive
fuori dal repo** (memoria operativa, cache LLM, ambiente R).

## Decision

**Trigger:** spostarsi sul server al termine di P3, **prima di P4 (run massivo
ARCHS4)**. P3 — Stadio 2 (study_design, comparability_anchor, fetch metadati
GEO) — può girare comodamente in locale: ~150 MB di metadati GEO totali stimati
per ~50k GSE (each ~3 KB di summary).

**Strategia:** rendere il repo l'**unica fonte di verità** per tutto ciò che
mi serve riprendere il lavoro. Tutto il resto è ricostruibile o trasferibile
con un singolo `rsync`.

### Cosa vive nel repo (versionato)

- Codice (`R/`, `tests/`, `inst/`, `analysis/_targets.R`, `analysis/eval/`).
- Spec, plan, ADR, NEWS, README (`docs/`, `NEWS.md`).
- `data-raw/relevant_sample_classified.xlsx` (~10 MB, gold standard manuale).
- `data-raw/build-sample-fixtures-mini.R` (script idempotente).
- `inst/extdata/` (fixture mini stabile, dump HGNC mini).
- `renv.lock` (versione esatta delle dipendenze).
- **`CLAUDE.md` di root** — contesto persistente del progetto, sostituisce la
  memoria locale di Claude Code che vive in `~/.claude/projects/<path>/memory/`
  (path machine-specific, non portabile).

### Cosa NON vive nel repo (.gitignored, da rigenerare/trasferire)

| Item | Locale path | Azione sul server |
|---|---|---|
| `.Renviron.local` (OPENAI_API_KEY) | repo root | **Utente la ricrea manualmente.** 1 riga: `OPENAI_API_KEY="sk-..."`. |
| renv library | `~/Library/Caches/.../renv/...` | `renv::restore()` (legge `renv.lock` committato). |
| dump HGNC completo | `tools::R_user_dir("simulomicsr")` | Download manuale da `https://www.genenames.org/download/archive/` o script futuro. P2 funziona con la fixture mini bundled in `inst/extdata/hgnc-fixture-mini.tsv`; il dump completo serve solo da P3 in poi. |
| `analysis/cache/` (LLM cache JSONL+SQLite) | repo (gitignored) | `rsync -avz analysis/cache/ user@server:repo/analysis/cache/` — facoltativo. Senza, il server rifà le chiamate (costo ~$3 per i 100 sample del dev set, ~$300-700 per il batch P4). |
| `analysis/_targets/` store | repo (gitignored) | `rsync` se vuoi continuità degli stati intermedi. Senza, `tar_make` ricalcola da zero (tempo, non costo). |
| `analysis/input/` (ARCHS4 H5, ecc.) | non esiste su locale | Download diretto sul server (più veloce di passarlo via locale). |

### Procedura di migrazione (server-side, post-P3)

1. **Sul Mac locale**: `git push` di tutto il lavoro committato.
2. **Sul server**: `git clone <repo> simulomicsr && cd simulomicsr`.
3. **Sul server**: creare `.Renviron.local` con la API key (utente, manuale).
4. **Sul server** (R): `renv::restore()` per ripristinare l'ambiente.
5. **Sul server (opzionale)**: `rsync -avz user@mac:.../analysis/cache/ analysis/cache/` per portarsi dietro la cache LLM. Vale la pena se il run dev set è recente.
6. **Sul server (opzionale)**: `rsync -avz user@mac:.../analysis/_targets/ analysis/_targets/` per portarsi dietro lo stato della pipeline. Vale la pena se vuoi vedere `tar_meta()` con la storia di tutti i target.
7. **Sul server**: aprire Claude Code nella directory del repo. Il `CLAUDE.md` viene caricato automaticamente come contesto root: la sessione riprende con piena consapevolezza dello stato del progetto.
8. **Verifica**: `Rscript --vanilla -e 'devtools::test()'` deve ritornare 0 FAIL (i 2 smoke E2E richiedono la API key — se è in `.Renviron.local` passano, altrimenti SKIP).

### Consequences

- **Positive:**
  - Il repo è autosufficiente: chiunque cloni più API key può riprendere.
  - Le memorie Claude non sono più machine-specific; vivono in `CLAUDE.md` versionato e auditabile.
  - Tutti gli artefatti pesanti restano gitignored e gestiti via `rsync` quando serve.
- **Negative:**
  - `CLAUDE.md` introduce duplicazione: la stessa info può vivere lì e nelle memorie locali. Per evitare drift, consideriamo `CLAUDE.md` la fonte canonica e svuotiamo la memoria locale di tutto ciò che è già lì.
  - Costo `~$3` di re-run del dev set sul server se non si fa il rsync della cache. Trascurabile.
- **Neutral:**
  - Il server aggiunge un'autenticazione SSH al workflow. Standard.
  - HGNC dump da scaricare separatamente; in P3 valuteremo se automatizzarlo come parte di un setup script.

## Links

- [docs/superpowers/specs/2026-04-29-classificatore-llm-design.md §9 #2](../superpowers/specs/2026-04-29-classificatore-llm-design.md) — sorgente sample finale = tutto ARCHS4 (~700k+).
- [docs/superpowers/plans/2026-05-02-p2-stadio1-sample-facts-plan.md](../superpowers/plans/2026-05-02-p2-stadio1-sample-facts-plan.md) — plan P2 chiuso, dev set 100 sample.
- [CLAUDE.md](../../CLAUDE.md) — contesto persistente del progetto.
