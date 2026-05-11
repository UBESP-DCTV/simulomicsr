# ADR-0013: chunk_size default cs25 → cs50 post H1 evidence

- **Status:** Accepted
- **Date:** 2026-05-11
- **Deciders:** Luca Vedovelli
- **Supersedes:** Path C default cs25 (introdotto in spec Task 22 2026-05-08, parte di ADR-0009 mitigation stack)
- **Relates to:** ADR-0010 (vLLM upgrade), ADR-0011 (tier max_tokens)

## Context

Path C cs25 (chunk_size=25 in `analysis/p4-stage2-build-input.R::CHUNK_SIZE`) era stato introdotto 2026-05-08 come **mitigazione probabilistica** di vLLM Issue #39734 (scheduler deadlock head-of-line). Records cs25 stanno tutti sotto ~50 KB / ~14K token → evitano la danger zone del bug.

Con ADR-0010 (vLLM v0.20.2 + PR #40946 fix upstream), il deadlock non e' piu' load-bearing. La domanda re-emerge: cs25 e' ancora il default giusto?

## Evidence (full alpha 2026-05-11)

Full alpha cs50 (data-raw/p4-alpha-stage2.jsonl, 6652 record, jobs 20087+20088 continuation):

| Metric | cs25 baseline (v0.10.0 + workaround) | cs50 v0.20.2 clean stack | Δ |
|---|---|---|---|
| Schema validity | 99.84% (3-pass + heuristic) | **99.96%** (single-pass) | +0.12pp |
| Mini-gold v5 binary accuracy | 93.3% | **96.7%** | **+3.4pp** |
| Wall α full | 25.5h (3-pass safe-mode) | 7:16:13 (continuation) | -71% |
| Variance throughput | bassa (record uniformi) | media-alta (XL record possono prendere 70min/microbatch) | — |

Per tier mini-gold: easy 100% (vs cs25 ~97%), hard 93.3% (invariato).

## Decision Drivers

- **Accuracy gain +3.4pp** e' scientificamente rilevante per il paper (target meta-analisi RNAseq design-aware).
- **Variance operativa** e' inconvenienza, non blocker — resume idempotent + time=72h+ la copre.
- **Token budget** verificato: cs50 lascia ~17% headroom su max_model_len=65536. cs75/cs100 saturerebbero (TIMEOUT certo o KV pressure forza max_num_seqs=1 = perdiamo W2 di ADR-0010).
- **Fallback simplicity**: cs25 resta opzione recovery con single-line change CHUNK_SIZE 50L → 25L.

## Options Considered

1. **cs25 status quo** — variance bassa, accuracy 93.3%, ma rinuncia a +3.4pp dimostrato.
2. **cs50 (questa scelta)** — accuracy 96.7%, variance media gestibile, sweet spot del budget token.
3. **cs75** — al limite max_model_len, 5-10% truncation rischio, gain marginale (~+0.5-1pp stimato).
4. **cs100** — richiede bump max_model_len → forza max_num_seqs=1 → throughput crolla. No.
5. **Adaptive chunking** — chunk_size dinamico basato su output complexity. Over-engineering per ora.

## Decision

**cs50 default**.

`analysis/p4-stage2-build-input.R::CHUNK_SIZE <- 50L`. `OUT_JSONL <- "data-raw/p4-alpha-stage2.jsonl"` (no suffix, cs50 implicito).

Per il paper Methods: cs50 e' la configurazione di reference, con accuracy 96.7% su mini-gold v5 e schema validity 99.96% single-pass.

### Consequences

- **Positive:**
  - +3.4pp accuracy direttamente nel pipeline output.
  - Eliminate ~1900 record extra di chunking aggressivo (8546 → 6652) → meno DGX time totale.
  - Coerenza con vLLM v0.20.2 post-upgrade (deadlock fixato upstream, chunk_size piccolo non piu' necessario).

- **Negative:**
  - Variance wall time per-microbatch piu' alta (record XL possono saturare 70min). Richiede SLURM time=72h+ generoso.
  - max_model_len bumpato a 65536 (era 32768 in cs25 era) gia' fatto in Phase 5 cleanup p4-defaults.yml.

- **Neutral:**
  - cs25 fallback: cambiare CHUNK_SIZE indietro e' triviale se un dataset futuro mostra TIMEOUT cronico.

## Links

- ADR-0010 vLLM upgrade evaluation (gate + Phase 5 cleanup + cs50 addendum).
- ADR-0011 tier-based max_tokens (compatibile, invariata).
- `analysis/p4-output/phase3-h1-eval-20088.rds` (H1 96.7% eval result).
- Spec investigation Task 22 (RESOLVED, superseded da ADR-0010 + questo ADR).
