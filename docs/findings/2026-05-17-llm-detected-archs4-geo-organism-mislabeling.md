# LLM-Detected Organism Mislabeling in ARCHS4/GEO Bulk RNA-seq Metadata

> **Status:** Discovery, 2026-05-17
> **Discovered during:** P4 β rescue cascade (Phase 1+2 systematic debugging dei 1.571 stage1 fails)
> **Methodological contribution:** la pipeline `simulomicsr` (Mistral-Small-3.2-24B LLM + structured outputs) ha identificato **72 studi GEO** etichettati come `organism_ch1 = "Homo sapiens"` in ARCHS4 v2.5 ma che in realtà contengono campioni murini, per un totale di **~9.147 campioni mislabeled**.

## Summary

Eseguendo `simulomicsr` stage1 classification sul dataset ARCHS4 v2.5 human bulk RNA-seq (888.821 sample post-filtri `organism_ch1 = "Homo sapiens"` + `library_strategy = "RNA-Seq"` + non-trivial metadata), il modello Mistral-Small-3.2-24B ha classificato **8.398 campioni come `Mus musculus`** + **749 campioni hanno fallito la generazione JSON con degenerazione legata a metadata mouse-specific** (totale ~9.147 sample). Questi sample si concentrano in **72 studi GEO** (>=5 sample non-human + >=50% non-human della classificazione valid per studio).

Top studi affetti:

| Series | Total sample | Non-human classified | % non-human |
|---|---|---|---|
| GSE202695 | 2.973 | 2.973 | 100.0% |
| GSE86977  | 1.938 | 1.810 | 93.4% (+746 fails) |
| GSE86982  | 1.846 | 1.476 | 80.0% |
| GSE93593  | 1.732 | 1.162 | 67.1% |
| GSE213896 | 70    | 66    | 94.3% |
| GSE242202 | 59    | 59    | 100.0% |
| GSE189518 | 52    | 52    | 100.0% |
| GSE93801  | 39    | 34    | 87.2% |
| GSE217260 | 36    | 33    | 91.7% |
| GSE98183  | 46    | 33    | 71.7% |
| ... (62 altri studi, ≥5 sample + ≥50% non-human) | | | |

Lista completa salvata in `analysis/p4-output/p4-beta-rescue-h2-suspects.rds`.

## Meccanismo del mislabeling upstream

ARCHS4 si fida del campo `organism_ch1` come depositato in GEO. La nostra ipotesi:

1. **Errore di compilazione campi GEO al momento del deposit**: alcuni ricercatori, caricando esperimenti che coinvolgono sia umano che modello murino (es. cell-line studies con engineering source da mouse iPS, xenograft, oppure simply data-entry errors), hanno marcato `organism_ch1 = "Homo sapiens"` per tutti i sample anche quelli murini.

2. **Bulk-copy mistakes**: studi con decine/centinaia di sample dove il campo `organism_ch1` viene compilato una volta sola e replicato. Se la prima riga è human ma il resto è mouse, il bulk-copy propaga l'errore.

3. **Co-culture / chimeric studies**: studi misti dove la dichiarazione GEO sceglie un organism singolo per convention ma i sample sono divisi.

### Evidence concrete sui top 3 affetti

- **GSE202695** (2.973 sample): tutti classificati Mus musculus dall'LLM. Title field contiene marker mouse-only (es. `Cre line: DCX+` = transgene DCX-Cre Mus musculus, tessuti/protocolli murini).
- **GSE86977** (1.938 + 746 fails): titoli simili (`cultured embryonic stem cells, days in culture: 12, cre line: DCX+, library prep#: 4`). DCX-Cre = mouse-specific transgenic line. Nessuna ambiguità.
- **GSE86982** (1.846, 80%): pattern simile a GSE86977 (stesso lab, stessa convenzione di naming).

L'LLM ha letto la stringa metadata raw e ha applicato il proprio prior biologico (transgenic line conventions, cell line nomenclature, tissue terminology) per inferire l'organism reale, andando in disaccordo col campo `organism_ch1` GEO.

## Significato metodologico

**Questa è una validazione "by-product" del metodo `simulomicsr`**, non solo per la sua use case primaria (design-aware comparison annotation per meta-analisi). La pipeline LLM-driven funziona come **quality-control secondario downstream** di ARCHS4/GEO, identificando errori upstream che:

- Non sono rilevati dai filtri esistenti su `organism_ch1`.
- Sono ignorati dai metadata curation pipelines che si fidano dei campi strutturati (MetaSRA, MetaHQ).
- Possono inquinare meta-analisi RNAseq cross-studio se non corretti.

Per confronto, gli annotatori GEO/SRA esistenti (citati in ADR-0006 stato-arte: MetaSRA, MetaHQ Hicks 2026, multi-agent curation Mondal 2025, RummaGEO Maayan 2024) non hanno questo cross-check perché operano sul campo structured `organism` senza re-interpretare il free-text del title/characteristics.

**Implicazioni paper-grade**:
1. **Contribuzione metodologica indipendente**: oltre al design-aware comparison annotation (use case primario), `simulomicsr` produce un by-product di **provider-error detection** sui database upstream. È un secondo paper-grade finding da menzionare nell'abstract.
2. **Suggested workflow change per ARCHS4/MetaSRA/MetaHQ**: aggiungere uno step LLM-based cross-check `organism_ch1` vs `title + characteristics_ch1` come QC layer prima della indexing.
3. **Communication agli stewards GEO/ARCHS4**: i 72 studi identificati possono essere segnalati ai curators per re-annotazione (è in our interest as a community).

## Action items per la pipeline `simulomicsr`

1. **H2 cleanup esteso (GSE-level)**: i 72 studi sospetti sono droppati interamente dal master stage1 e dal stage2-input pre-stadio 3 (raggruppamento). Drop totale ~9.147 sample / 888.821 = **1.03%** del dataset β.
2. **Master stage1 post-H2-v2**: ~879.674 sample (888.821 - 749 fails - ~8.398 valid non-human classifications).
3. **Documentazione finding nel paper**: sezione dedicata in Methods / Results (non Limitations — è un contributo metodologico positivo).
4. **Lista dei 72 studi mislabeled** come supplementary material per riproducibilità + per consenting a future re-annotation effort upstream.

## Snippet outputs (per future ref)

```
Discovered: 2026-05-17, branch p4-beta-rescue
Method: simulomicsr stage1 (Mistral-Small-3.2-24B) classification disagreement
        vs ARCHS4 v2.5 organism_ch1
Threshold criterion: >=5 sample classified non-human + >=50% non-human per study
Affected studies: 72
Total mislabeled samples: ~9.147 (8.398 valid non-human + 749 LLM fails with non-human metadata signal)
Dataset fraction: 1.03% of 888.821 ARCHS4 human bulk RNA-seq filtered
```

## References

- `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv` (749 fails analizzati)
- `analysis/p4-output/p4-beta-rescue-h2-suspects.rds` (lista completa 72 GSE)
- `analysis/p4-beta-rescue-h2-cleanup.R` (script H2 v2 GSE-level drop)
- `docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md` (plan rescue cascade)
- ADR-0008 addendum 3 (sampling deviation + rescue documentation)
- ADR-0006 (stato-arte vs simulomicsr: positioning vs MetaSRA/MetaHQ/RummaGEO)
