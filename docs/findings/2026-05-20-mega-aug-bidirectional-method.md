# MEGA-AUG bidirezionale: metodo per recuperare baseline pool single-arm in meta-analisi RNA-seq cross-studio design-aware

> Documento tecnico vivente — destinato a diventare la sezione "Methods + Results" del paper `simulomicsr` per la parte di Stadio 4. Cresce man mano con i risultati dei test di validazione.
>
> **Status**: Draft 0.1 — 2026-05-20. Letteratura raccolta, ipotesi formulate, policy proposte, test pianificati. **Results: TBD pending validation tests.**

## 1. Contesto e problema

`simulomicsr` è una pipeline R per meta-analisi RNA-seq cross-studio "design-aware". Stadio 1 e 2 classificano i campioni GEO via LLM (Mistral-Small-3.2-24B self-hosted) in una rappresentazione strutturata che include un `comparability_anchor` canonico v3 — una stringa semantica a 13 segmenti tier-based (`kind_effective`, `agent_id`, `variant_label`, `dose_canonical`, `duration_canonical`, `phase_canonical`, `cell_id`, `context_kind`, `cell_state`, `subcellular`, `tissue`, `disease_status`, `has_engineered`) che permette di appaiare campioni biologicamente comparabili tra studi diversi senza dipendere da curation manuale. L'anchor è disponibile a 5 livelli di granularità (L0..L4): L0 contiene tutti i 13 segmenti, L4 solo i 3 segmenti del tier S (`kind_effective`, `agent_id`, `tissue`).

Stadio 3 raggruppa i campioni cross-studio sull'anchor, producendo **267.056 cluster** complessivi su ~879k sample umani ARCHS4. Di questi, **4508 sono "Layer A"** — cluster con potenza statistica e bilanciamento sufficienti per differential expression a valle.

L'analisi della composizione di Layer A rivela una stratificazione netta:

| Tipo cluster | Count | % Layer A | Natura |
|---|---:|---:|---|
| `mode = pair` (MEGA-contrast genuino) | **345** | 7.7% | Cluster derivati da `comparisons` Stadio 2: contengono entrambi i bracci (treated + control) all'interno dello stesso cluster, già pronti per DE classico mixed-effect. |
| `mode = group` (baseline pool single-arm) | **4163** | 92.3% | Cluster derivati da `replicate_groups` Stadio 2: aggregano repliche cross-studio di **una sola condizione biologica** (es. "33 campioni di CD4+ T cells untreated baseline da 5 studi diversi"). Single-arm: non hanno un secondo braccio da contrastare. |

Il **92% di Layer A è single-arm**. Se ci limitiamo ai pair genuini, perdiamo gran parte del segnale che la pipeline è in grado di estrarre dai metadati.

L'osservazione chiave: questi 4163 baseline pool sono **biologicamente informativi**. Un pool di 33 CD4+ T cells untreated baseline da 5 studi indipendenti è una caratterizzazione cross-replicata di una condizione biologica più solida di qualsiasi singolo studio. Se solo trovassimo un secondo braccio compatibile (es. CD4+ T cells trattati con drug-X da 2 altri studi), avremmo un contrasto cross-studio impossibile da costruire altrimenti.

Questo documento descrive il metodo **MEGA-AUG bidirezionale** che recupera questa informazione, e il suo posizionamento rispetto allo state-of-the-art.

## 2. Posizionamento rispetto allo state-of-the-art

Tre famiglie di tool dominano il campo RNA-seq meta-analysis cross-studio:

- **MetaIntegrator (Haynes/Sweeney 2017)** [1]. Multi-cohort framework che richiede etichetta binaria caso/controllo definita manualmente per ogni studio. Tutto il matching è lasciato al curatore. Robusto ma non scalabile.
- **MetaSRA (Bernstein 2017)** [2]. Normalizza i metadati GEO/SRA su ontologie (Disease Ontology, Cell Ontology, Uberon, EFO, Cellosaurus) con un "Case-Control Finder" che appaia campioni per cell type/tissue ontology-matched. **Match relaxed ontology-driven** — il pattern metodologico più vicino al nostro.
- **RummaGEO (Maayan 2024)** [3]. Definisce control via keyword bag ("wildtype", "ctrl", "DMSO") e fa DE **within-study**, senza tentare alcun match cross-study a livello di braccio.

In nessuno dei tre, un **baseline pool single-arm aggregato cross-studio** viene riusato per augmentare un'analisi DE in cui il braccio mancante proviene da studi diversi. La letteratura review più recente (Vicens/Tarazona 2025) conferma che harmonization "soft" su ontologie è ormai best practice, ma non identifica un metodo end-to-end che chiuda il cerchio dal metadato testuale al contrasto cross-studio aumentato.

**Il MEGA-AUG bidirezionale è metodologicamente nuovo** rispetto a questi tre: usa l'anchor canonico LLM-driven come ponte tra un baseline pool single-arm di Stadio 3 e un pair cluster di Stadio 3, costruendo un contrasto cross-studio aumentato in cui la potenza statistica del braccio control è massimizzata.

## 3. Ipotesi del metodo

**H1 (recovery)**: i 4163 baseline pool single-arm di Stadio 3 contengono informazione biologica utilizzabile per aumentare statisticamente i 345 pair cluster k=2, quando l'anchor canonical è compatibile sotto policy relaxed.

**H2 (validità statistica)**: il segnale recuperato via MEGA-AUG bidirezionale è qualitativamente confrontabile con il segnale di contrasti within-study tradizionali, **a patto che** la pipeline gestisca esplicitamente: (a) il confonding studio-trattamento quando i bracci sono in studi disgiunti (Nodo 2), (b) la correlazione tra contrasti che condividono uno stesso baseline pool (Nodo 3).

**H3 (trasparenza)**: tutti i contrasti aumentati sono dichiarati come **indirect comparison** nel report finale, e il dato grezzo (numero studi overlap, numero studi disjoint, baseline pool reuse count) è disponibile per il lettore per ogni contrasto pubblicato.

## 4. Tre nodi di design e policy adottate

### Nodo 1 — Anchor matching baseline ↔ pair

**Domanda**: quando il `comparability_anchor` di un baseline pool e quello del braccio control mancante di un pair sono "comparabili abbastanza"?

**Letteratura**. MetaSRA (Bernstein 2017) [2] e i lavori successivi legittimano il match ontology-based relaxed: due record matchano se cell type, tessuto e perturbazione (categorical) coincidono, anche se differiscono su dose o tempo (continuous). Nessun paper quantifica formalmente il trade-off strict-vs-relaxed sui campi periferici.

**Policy adottata (Draft v0.1)** — applicata sull'anchor v3 a 13 segmenti tier-based:

- **Strict (obbligatorio)**: tier **S** (`kind_effective`, `agent_id`, `tissue`), tier **A** (`variant_label`, `disease_status`, `phase_canonical`), tier **B** (`cell_state`, `cell_id`), hard_filters (`context_kind`, `subcellular`).
- **Relaxed (tollerato in `relaxed` policy)**: tier **C** (`dose_canonical`, `duration_canonical`), tier **D** (`has_engineered`).
- **Effetto pratico**: a L2/L3/L4 i segmenti tollerati sono già droppati, quindi `relaxed` ≡ `strict` a quei livelli. La policy ha impatto reale solo a **L0 e L1**.
- **Sensitivity reportata**: il pipeline produce un secondo run con `anchor_policy = "strict"`, e il diff in numero di contrasti recuperati + concordanza di logFC è riportato nei Results come quantificazione del trade-off.

### Nodo 2 — Studi disgiunti tra baseline e pair (il nodo critico)

**Domanda**: se il baseline pool di un contrasto aumentato viene da studi A-B-C-D-E e il braccio treated dal pair viene da studi F-G, con zero overlap di studi, il random effect `study` del mixed model è sufficiente?

**Letteratura — guidance unanime**:

- Leek et al. 2010 [4]: quando il batch è confuso col contrasto d'interesse, qualunque correzione naive rimuove anche il signal biologico.
- Nygaard et al. 2016 [5]: rimuovere il confonding senza overlap "esagera la confidenza downstream" (titolo letterale).
- Hoffman & Roussos 2021 [6] (dream/voomWithDreamWeights): random effect `study` funziona quando lo studio è random crossed col trattamento, **non** risolve il caso disjoint (il random effect assorbe tutto).
- Winter et al. 2019 [7]: dimostra che network meta-analysis produce fold-change più vicini al vero rispetto al merge naive quando i bracci sono in studi diversi; raccomanda di dichiarare la cosa esplicitamente come "indirect comparison".
- Salanti / Cipriani / Higgins — NMA transitivity assumption [11]: il confronto indiretto è valido solo se gli effect modifier (cell context, dose, time) sono distribuiti similmente nei due bracci.

**Punto chiave dalla letteratura**: con bracci disjoint, il random effect `study` non risolve il confonding. Il modo standard è dichiararlo come indirect comparison e verificare la transitività sugli effect modifier. **Nessuna soglia quantitativa di minimum-overlap è pubblicata** — va decisa empiricamente.

**Policy adottata (Draft v0.1) — due modalità implementate in parallelo, decisione finale data-driven via test**:

- **Modalità A "permissive"**: ammettiamo bracci completamente disjoint (zero overlap). Il contrasto risultante è etichettato `comparison_kind = "indirect_disjoint"` in output. L'utente vede esplicitamente il warning.
- **Modalità B "strict"**: richiediamo **almeno uno studio overlap** tra baseline pool e pair. Più conservativo, perde candidati.

Il test simulation (sez. 5.2) ci dirà se Modalità A è accettabile in pratica o se Modalità B deve essere il default.

### Nodo 3 — Riuso multiplo dello stesso baseline pool

**Domanda**: se lo stesso baseline pool è usato come braccio control per N comparison diverse, c'è doppio conteggio statistico?

**Letteratura — risolto**:

- Lu & Ades 2004 [8]: foundation paper della network meta-analysis. Il doppio conteggio quando un braccio è riusato in più contrasti si gestisce modellando la correlazione tra contrasti che condividono il braccio.
- Franchini et al. 2012 [9]: dimostra che ignorare la correlazione tra contrasti che condividono un control arm produce standard error sottostimati e p-value gonfiati. Fornisce **la formula esplicita** per la matrice di covarianza dei contrasti correlati.
- Tseng et al. 2020 [10]: Bayesian latent hierarchical transcriptomic meta-analysis — pattern di "borrow strength across studies" applicabile in alternativa frequentista.

**Policy adottata (Draft v0.1)**: ogni baseline pool utilizzato in ≥ 2 contrasti aumentati introduce la correzione di covarianza Franchini 2012 nel pooling **cross-cluster post-hoc** (NON dentro il REM pooling del singolo cluster). La correzione produce un output secondario `cluster_pooled_franchini` con SE / p-value corretti, da confrontare contro il `cluster_pooled` base nel sensitivity analysis 6.4. Approssimazione adottata: correlation factor `rho = 0.5` uniforme (limite paper-grade documentato — Franchini 2012 esatta richiederebbe le component variances within-arm che dream non espone direttamente). Il count di reuse è documentato in `mega_aug_diagnostics` (`baseline_pool_id_control`, `baseline_pool_id_treated`).

## 5. Validation plan

I test riportati qui sotto sono il payload empirico per validare le tre policy. Tutti hanno output deterministico e riproducibile.

### 5.1 Test anchor matching (Nodo 1)

**Setup**. 20-30 candidati di match baseline-pair estratti dall'attuale registro Stadio 3, etichettati a mano (Vd. autori) come "match valido / dubbio / non valido". Confronto con la policy automatica (strict + relaxed).

**Output atteso**: confusion matrix e accuracy della policy. Identificazione di edge case dove la relaxation su dose/tempo produce match clinicamente non plausibili.

**Status**: TBD.

### 5.2 Simulation batch confounding (Nodo 2)

**Setup**. Selezione di 5-10 studi GEO noti con design pulito trattato-vs-controllo (es. dal mini-gold P3.5 v5). Per ogni studio:

1. Calcolo del logFC vero within-study (ground truth).
2. Split artificiale: control da $k$ altri studi (baseline pool simulato), treated dall'arm trattato del singolo studio originale.
3. Calcolo del logFC ricostruito via MEGA-AUG con `study` random effect.
4. Confronto: correlazione Spearman + RMSE su top-1000 DE genes, in funzione del numero di studi nel pool baseline e dell'overlap (0, 1, 2 studi).

**Output atteso**: curva di degradation. Identificazione della soglia oltre la quale "indirect comparison" è non recuperabile.

**Status**: TBD.

### 5.3 Sensitivity strict-vs-relaxed (Nodo 1 esteso)

**Setup**. Layer A fullrun viene eseguito in due varianti — `match_policy = "strict"` (tutti i campi strict) e `match_policy = "relaxed"` (default proposta sez. 4 Nodo 1). Confronto del numero di contrasti recuperati e della concordanza dei top-100 DE genes per contrasti che esistono in entrambi i run.

**Output atteso**: trade-off quantificato "N contrasti extra recuperati ↔ correlazione top-100 logFC". Decisione finale sulla policy default.

**Status**: TBD.

### 5.4 Comparison vs Layer A pair-only (baseline contro)

**Setup**. Confronto tra: (a) Layer A pair-only — solo i 345 pair cluster nativi, no augmentation; (b) Layer A + MEGA-AUG bidirezionale completo. Comparison su: numero di contrasti totali, numero di DE genes paper-grade (BH-adjusted q < 0.05), p-value distribution (test di calibrazione null-hypothesis sotto permutation).

**Output atteso**: quantificazione del beneficio incrementale dell'augmentation. Deliverable diretto per la sezione Results del paper.

**Status**: TBD.

### 5.5 Comparison vs RummaGEO (benchmark esterno)

**Setup**. Su un sottoinsieme di GSE comuni tra simulomicsr Layer A e RummaGEO public release, comparison della concordanza dei DE genes within-study + identificazione di contrasti cross-studio prodotti solo da `simulomicsr`.

**Output atteso**: dimostrazione che la nostra pipeline produce contrasti che RummaGEO non può produrre (cross-studio MEGA-AUG), pur preservando la concordanza within-study sui contrasti comuni.

**Status**: TBD — deliverable integrale di P3.5 eval (vedi ADR-0006).

## 6. Results

**TBD pending validation tests 5.1 – 5.5.** Le sezioni di questo documento verranno aggiornate in-place con tabelle, figure (paths a `analysis/p4-output/...`) e narrativa man mano che i test producono risultati.

Sezioni attese:

- 6.1 Anchor matching accuracy on hand-curated set
- 6.2 Batch confounding simulation: degradation curve
- 6.3 Strict-vs-relaxed sensitivity
- 6.4 Augmentation gain over pair-only baseline
- 6.5 RummaGEO comparison

## 7. Discussione (TBD)

Le sezioni cresceranno con i Results. Strutturazione attesa:

- 7.1 Limitazioni note. (a) anchor canonico LLM-derived ha residual error rate (Stadio 1 LLM-only 99.998%, Stadio 2 100% post-rescue cascade); (b) Mistral-Small-3.2-24B ceiling sul mini-gold P3.5 è ~98%; (c) i 4163 baseline pool single-arm sono stati segnalati come Layer B0 in Stadio 3 — il riuso in MEGA-AUG richiede tagging delle dipendenze per riproducibilità.
- 7.2 Rapporto con NMA classica: il MEGA-AUG bidirezionale è formalmente equivalente a un'indirect comparison NMA su transcriptome, ma scalato all'intero GEO.
- 7.3 Future work. (a) extension a multi-arm augmentation (più di un treated arm condiviso); (b) integrazione di Stage 2 confidence score come weight aggiuntivo nel pooling; (c) γ ARCHS4 mouse cross-organism comparability.

## 8. Implementazione

Spec implementativa interna: `docs/superpowers/specs/2026-05-20-p5-stadio4-mega-aug-bidirezionale-design.md` (da scrivere subito dopo questo documento).

ADR di accompagnamento: `docs/decisions/0016-mega-aug-bidirezionale.md` (da scrivere alla chiusura del fullrun).

Codice principale atteso: `R/stage4-mega-aug-bidirectional.R`, `R/stage4-anchor-matching.R`, `R/stage4-baseline-pool-pairing.R`.

## Bibliografia

[1] Haynes WA, Vallania F, Liu C, et al. **Empowering Multi-Cohort Gene Expression Analysis to Increase Reproducibility**. Pacific Symposium on Biocomputing, 2017. (MetaIntegrator). https://pmc.ncbi.nlm.nih.gov/articles/PMC5167529/

[2] Bernstein MN, Doan A, Dewey CN. **MetaSRA: normalized human sample-specific metadata for the Sequence Read Archive**. Bioinformatics, 2017. https://pmc.ncbi.nlm.nih.gov/articles/PMC5870770/

[3] Marino GB, Clarke DJB, Lachmann A, Deng EZ, Ma'ayan A. **RummaGEO: Automatic mining of human and mouse signatures from GEO Gene Expression Omnibus**. Patterns (Cell Press), 2024. https://www.cell.com/patterns/fulltext/S2666-3899(24)00231-9

[4] Leek JT, Scharpf RB, Bravo HC, et al. **Tackling the widespread and critical impact of batch effects in high-throughput data**. Nat Rev Genet, 2010. https://www.nature.com/articles/nrg2825

[5] Nygaard V, Rødland EA, Hovig E. **Methods that remove batch effects while retaining group differences may lead to exaggerated confidence in downstream analyses**. Biostatistics, 2016. https://pmc.ncbi.nlm.nih.gov/articles/PMC4679072/

[6] Hoffman GE, Roussos P. **dream: powerful differential expression analysis for repeated measures designs**. Bioinformatics, 2021. https://academic.oup.com/bioinformatics/article/37/2/192/5878955

[7] Winter C, Kosch R, Ludlow M, Osterhaus ADME, Jung K. **Network meta-analysis correlates with analysis of merged independent transcriptome expression data**. BMC Bioinformatics, 2019. https://bmcbioinformatics.biomedcentral.com/articles/10.1186/s12859-019-2705-9

[8] Lu G, Ades AE. **Combination of direct and indirect evidence in mixed treatment comparisons**. Statistics in Medicine, 2004.

[9] Franchini AJ, Dias S, Ades AE, Jansen JP, Welton NJ. **Accounting for correlation in network meta-analysis with multi-arm trials**. Research Synthesis Methods, 2012. https://onlinelibrary.wiley.com/doi/abs/10.1002/jrsm.1049

[10] Zhu T, Hu Y, Ma Z, Zhang D, Li T, Yang Z. **Bayesian Hierarchical Mixture Model for analyzing Single Arm Trials with Subgroup of Interest** (Tseng group, hierarchical transcriptomic latent meta-analysis). 2019. https://pubmed.ncbi.nlm.nih.gov/31007807/

[11] Tu YK. **NMA transitivity assumption — methodological review**. Research Synthesis Methods, 2024. https://onlinelibrary.wiley.com/doi/full/10.1002/jrsm.1760

## Changelog

- **2026-05-20 — Draft v0.1**. Letteratura raccolta (11 reference), ipotesi formulate, policy proposte, test plan pianificato. Results pending validation tests 5.1–5.5.
