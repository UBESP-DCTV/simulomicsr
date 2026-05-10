# Status index — specs & plans

Stato di tutti i documenti in `specs/` e `plans/` aggiornato al
**2026-05-10** (chiusura α stage2 + cleanup post-alpha).

`[archived]` = fase completata, lavoro chiuso (corrispondente tag git
indicato). I file restano on-disk per riferimento storico ma non sono
più "live": non aspettarsi update, prendili come fotografia del momento.

`[live]` = piano/spec attiva o riferimento canonico ancora in uso.

## Plans (`docs/superpowers/plans/`)

| File                                            | Status                       | Note                                    |
|-------------------------------------------------|------------------------------|-----------------------------------------|
| 2026-04-29-p1-infrastruttura-llm-plan.md        | `[archived]` `p1-infra-llm-complete` | + companion HUMANE              |
| 2026-05-02-p2-stadio1-sample-facts-plan.md      | `[archived]` `p2-stage1-complete`    | + companion HUMANE              |
| 2026-05-02-p3-stadio2-study-design-plan.md      | `[archived]` `p3-stage2-complete`    | + companion HUMANE              |
| 2026-05-02-p3.5b-eval-benchmark-plan.md         | `[archived]` `p3.5b-eval-complete`   | + companion HUMANE              |
| 2026-05-02-p3.5a-scaled-benchmark-plan.md       | `[archived]` `p3.5a-eval-complete`   | + companion HUMANE              |
| 2026-05-04-p3.5c-confidence-aware-plan.md       | `[archived]` `p3.5c-confidence-complete` | no HUMANE                   |
| 2026-05-06-p4-dgx-integration-plan.md           | `[archived]` `p4-dgx-complete`       | α completata (Task 1-22). β ETL ARCHS4 -> nuovo plan dedicato. |

## Specs (`docs/superpowers/specs/`)

| File                                                       | Status                       | Note                                       |
|------------------------------------------------------------|------------------------------|--------------------------------------------|
| 2026-04-29-classificatore-llm-design.md                    | `[live]` reference canonico  | v5 spec del classificatore design-aware. Riferimento permanente per il vocabolario. |
| 2026-04-29-classificatore-llm-design.dry-run.md            | `[archived]` storico         | Dry-run iter 1 (2026-04-29).               |
| 2026-04-29-classificatore-llm-design.dry-run-2.md          | `[archived]` storico         | Dry-run iter 2.                            |
| 2026-04-29-classificatore-llm-design.dry-run-3.md          | `[archived]` storico         | Dry-run iter 3.                            |
| 2026-04-29-classificatore-llm-design.dry-run-4.md          | `[archived]` storico         | Dry-run iter 4 (final).                    |
| 2026-05-02-p3.5-eval-benchmark-design.md                   | `[archived]` `p3.5b-eval-complete` | Design P3.5-B prototipo.             |
| 2026-05-02-p3.5a-scaled-benchmark-design.md                | `[archived]` `p3.5a-eval-complete` | Design P3.5-A scaled.                |
| 2026-05-04-p3.5c-confidence-aware-design.md                | `[archived]` `p3.5c-confidence-complete` | Design P3.5-C v5 multi-provider. |
| 2026-05-06-p4-dgx-integration-design.md                    | `[archived]` `p4-dgx-complete` | Design P4 originale (alcune scelte hanno divagato durante l'implementazione - vedi git log e ADR-0007/0008/0009/0011/0012). |
| 2026-05-08-task22-stage2-vllm-stalls-investigation.md      | `[archived]` RESOLVED        | Investigation root cause vLLM Issue #39734 + fix Path C/safe-mode. Soluzione applicata e documentata in ADR-0009. |

## Convenzione

Quando si apre un nuovo plan/spec:

1. Crea `<date>-<slug>-{plan,design}.md` (+ HUMANE se plan).
2. Aggiungi una riga in questo file con status `[live]`.
3. A chiusura fase: aggiorna lo status a `[archived] <tag>`.
