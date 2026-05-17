# LLM-Detected Organism Mislabeling in ARCHS4/GEO Bulk RNA-seq Metadata

> **Status:** Discovery, 2026-05-17
> **Discovered during:** P4 β rescue cascade (Phase 1+2 systematic debugging dei 1.571 stage1 fails)
> **Methodological contribution:** la pipeline `simulomicsr` (Mistral-Small-3.2-24B LLM + structured outputs) ha identificato **72 studi GEO** etichettati come `organism_ch1 = "Homo sapiens"` in ARCHS4 v2.5 ma che in realtà contengono campioni murini. Cleanup GSE-level: **9.654 sample droppati** (1.09% del dataset β di 888.821), oltre a **749 sample con LLM JSON failure** concentrati negli stessi GSE (signal indiretto del mislabeling).

## Numeri canonici (paper-grade — riportare in Methods/Results)

Dataset di partenza: **888.821 sample** ARCHS4 v2.5 human bulk RNA-seq filtered (`organism_ch1 = "Homo sapiens"` + `library_strategy = "RNA-Seq"` + non-trivial metadata).

| Categoria | N sample | Fonte |
|---|---|---|
| **Sample classificati non-human dall'LLM (Mistral-Small-3.2-24B)** — discovery diretta | **8.398** | `suspects$nonhuman` su 72 GSE |
| Sample classificati human dall'LLM ma in GSE mixed — drop collaterale GSE-level conservativo | 1.256 | `suspects$total − suspects$nonhuman` |
| **Subtotale drop GSE-level effettivo (Stage1: 888.821 → 879.167)** | **9.654** | `sum(suspects$total)` |
| Sample con LLM JSON failure su metadata mouse-specific (signal indiretto, tutti nei 72 GSE flagged) | 749 | `fails$fail_mode == "ETL_LEAK_NONHUMAN"` |
| Di cui solo in GSE86977 | 746 | Concentrazione 99.6% |
| **Totale segnale mouse-mislabel raccolto dalla pipeline** | **10.403** | 9.654 + 749 |

Stage2-input cleanup correlato: 39.205 → **38.963 record** (−242 stage2 record GSE-level droppati).

**Criterio threshold per flagging studio**: ≥5 sample classificati non-human dall'LLM + ≥50% non-human del totale classificato per studio. 72 studi soddisfano il criterio.

Top studi affetti:

| Series | Sample classificati validi | Non-human classificati | % non-human | LLM JSON fails extra |
|---|---|---|---|---|
| GSE202695 | 2.973 | 2.973 | 100.0% | 0 |
| GSE86977  | 1.938 | 1.810 | 93.4% | **746** (degenerazione mouse-specific) |
| GSE86982  | 1.846 | 1.476 | 80.0% | 0 |
| GSE93593  | 1.732 | 1.162 | 67.1% | 1 |
| GSE213896 | 70    | 66    | 94.3% | 0 |
| GSE242202 | 59    | 59    | 100.0% | 0 |
| GSE189518 | 52    | 52    | 100.0% | 0 |
| GSE93801  | 39    | 34    | 87.2% | 1 |
| GSE217260 | 36    | 33    | 91.7% | 0 |
| GSE98183  | 46    | 33    | 71.7% | 0 |
| GSE126753 | (vario) | (vario) | (≥50%) | 1 |
| ... (62 altri studi, ≥5 sample + ≥50% non-human) | | | | |

Lista completa salvata in `analysis/p4-output/p4-beta-rescue-h2-suspects.rds` (72 righe × 4 colonne: `series_id`, `total`, `nonhuman`, `pct_nonhuman`).

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

1. **H2 cleanup esteso (GSE-level)**: i 72 studi sospetti sono droppati interamente dal master stage1 e dal stage2-input pre-stadio 3 (raggruppamento). Drop GSE-level: **9.654 sample / 888.821 = 1.09%** del dataset β (+ 749 LLM JSON failures concentrati negli stessi GSE come signal indiretto).
2. **Master stage1 post-H2-v2**: **879.167 sample** (888.821 − 9.654).
3. **Documentazione finding nel paper**: sezione dedicata in Methods / Results (non Limitations — è un contributo metodologico positivo).
4. **Lista dei 72 studi mislabeled** come supplementary material per riproducibilità + per consenting a future re-annotation effort upstream.

## Snippet outputs (per future ref)

```
Discovered: 2026-05-17, branch p4-beta-rescue
Method: simulomicsr stage1 (Mistral-Small-3.2-24B) classification disagreement
        vs ARCHS4 v2.5 organism_ch1
Threshold criterion: >=5 sample classified non-human + >=50% non-human per study
Affected studies: 72
Drop GSE-level effettivo: 9.654 sample (8.398 LLM-non-human + 1.256 human-classified collaterali)
Signal indiretto aggiuntivo: 749 LLM JSON failures su metadata mouse-specific (tutti nei 72 GSE, soprattutto GSE86977: 746)
Totale signal mouse-mislabel raccolto: 10.403 sample
Stage1 master post-cleanup: 888.821 -> 879.167 (1.09% drop)
Stage2-input post-cleanup: 39.205 -> 38.963 record (-242 record GSE-level)
```

## References

- `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv` (749 fails analizzati)
- `analysis/p4-output/p4-beta-rescue-h2-suspects.rds` (lista completa 72 GSE)
- `analysis/p4-beta-rescue-h2-cleanup.R` (script H2 v2 GSE-level drop)
- `docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md` (plan rescue cascade)
- ADR-0008 addendum 3 (sampling deviation + rescue documentation)
- ADR-0006 (stato-arte vs simulomicsr: positioning vs MetaSRA/MetaHQ/RummaGEO)
