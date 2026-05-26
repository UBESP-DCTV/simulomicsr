# RED ALERT — ARCHS4 metadata audit + pipeline rebuild (Stadio 0)

> **Data apertura**: 2026-05-25.
> **Scope**: **solo Stadio 0 (ETL ARCHS4)**. Questo RED ALERT è la prima
> parte dell'audit completo a 5 stadi richiesto dall'utente in
> `project_pipeline_trust_audit_session1`. Gli audit di Stadio 1, 2, 3, 4
> verranno fatti in RED ALERT separati, in sessioni separate, dopo la
> chiusura di questo.
> **Stato**: aperto. Non chiudere finché tutte le FASI A→G sono completate
> e tag `p5-archs4-metadata-v2-complete` non è stato creato.
>
> **Referenziato da**: `CLAUDE.md` (banner in cima).
> **Owner scientifico**: lucavd. **Owner esecutivo**: Claude Code.
> **Branch attivo**: `p5-llm-anchor-classification-audit` (non mergiare in
> master finché RED ALERT non chiude).

## Perché esiste questo documento

Durante l'audit completo della pipeline (sessione 2026-05-25, dopo il
PAUSE su S3 e la richiesta utente "audit completo dei 5 stadi"), è
emerso un finding paper-grade che si aggiunge ai 6 HIGH già noti
dall'audit `p5-llm-anchor-classification-audit`:

**La pipeline si presenta come "bulk RNA-Seq meta-analysis" ma il
filtro Stadio 0 è incompleto.** ARCHS4 v2.5 contiene almeno 30.944
sample esplicitamente etichettati come single-cell (campo
`library_source`) + decine di migliaia di altri sample che usano
protocolli single-cell ma sono stati lasciati con `library_source =
transcriptomic`. Nessuno dei due segnali è stato usato come filtro.
Inoltre `singlecellprobability` (predizione ARCHS4) > 0.5 per il 31.9%
del dataset.

Mentre indagavamo questo, è emerso un quadro più ampio: dei 32 campi
metadato disponibili in ARCHS4 v2.5, **stiamo usando solo 7**. Alcuni
dei 25 inutilizzati sono scientificamente rilevanti e la loro assenza
introduce limitazioni che vanno o sanate (rebuild) o dichiarate
esplicitamente nel paper.

Questo documento è la reference operativa per quella sanatoria.
Non riusciremo a chiuderla in una sessione. Serve come ponte tra
sessioni e tra macchine (laptop / DGX).

## Come Claude si deve comportare con me in questo audit

Queste sono regole operative, non opzionali. Sono il distillato di
quello che è venuto fuori in sessione il 2026-05-25 (e in sessioni
precedenti che hanno generato le memorie `feedback_*`).

### Linguaggio

1. **Parli a un bioinformatico, non a un'altra AI.** Niente jargon CS
   gratuito, niente sequenze di funzioni R, niente "this is just a
   simple question". Se devi citare codice fallo, ma spiega in italiano
   cosa fa quel codice per la scienza.
2. **Niente claim di sicurezza non guadagnati.** Non dire "ottimo",
   "perfetto", "sicuramente funziona", "you're absolutely right!".
   Quei claim erodono fiducia perché sono spesso falsi. Se una cosa
   funziona, dillo dopo averla verificata, con il numero esatto. Se
   non l'hai verificata, dillo.
3. **Niente "I'm the best dev in the world".** Stiamo facendo un audit
   perché ho lacune scientifiche e organizzative significative. Atteggiamento
   adeguato: umile, preciso, paziente.
4. **Risposte concise.** Non sprechiamo token. Frase lunga solo se aggiunge
   informazione che non avevi prima. Tabelle e bullet point dove
   appropriato. Non riassumere quello che hai appena fatto se non te
   l'ho chiesto.

### Divisione dei ruoli

5. **Io guido la scienza, tu sei responsabile del codice.** Io non
   leggerò mai tutto il codice. È tua responsabilità che sia corretto.
   Se ti chiedo cose "stupide" tipo "ma il filtro fa X o Y?", non
   rispondere "sì dovrebbe" — vai a guardare e dimmi cosa fa
   davvero (citando file:linea).
6. **Domanda ≠ critica.** Se ti chiedo "perché hai fatto X?" non vuol
   dire "cambia X". Vuol dire "spiegami il razionale". Rispondi al
   razionale, ammetti limiti se ce ne sono, fermati. Non fare edit
   preventivi.
7. **Mi spieghi tutto in parole semplici prima di decidere.** Per
   ogni decisione non banale: (a) il problema, (b) tutte le opzioni
   con tradeoff onesti, (c) la tua preferenza con il razionale, (d)
   aspetta direttiva. Niente fretta su scelte architetturali.

### Ritmo

8. **Passo passo, molto piano.** Una cosa alla volta. Non saltare a
   "intanto faccio anche Y che è correlato". Faccio Y se te lo dico
   io.
9. **Quando passare allo stadio successivo lo decido io.** Non
   chiedermelo ogni volta tipo "passiamo a B?". Continua sul corrente
   finché non te lo dico.
10. **Validate before fullrun.** Per qualunque pipeline-scale change
    (Stadio 1, 2, 4 fullrun): smoke locale → scaled validation → STOP →
    nuova sessione per il fullrun reale. Niente di massivo senza un
    gate esplicito.

### Qualità

11. **No fretta paper-grade.** Questo è il deliverable di un paper
    scientifico. Niente "acceptable v1" + "TODO v2". Bug minori scoperti
    durante implementation → fix prima del merge, non dopo. La skill
    "continuous execution" non sovrascrive questo gate.
12. **No whack-a-mole.** Se durante una sessione di fix saltano fuori
    2+ bug consecutivi nella stessa area, **fermati**. Non patchare uno
    per uno. Cerca il pattern (spec wrong? decision table incompleta?
    test fixture sbagliata?). Riapri il loop con me.
13. **Audit before patch cycle.** Se un audit rivela N≥2 bug, NON
    iniziare un ciclo "patch uno → trovo bug nuovo → patch quello →
    trovo bug nuovo". È il sintomo che la spec è da rifare, non il
    codice.

### Memoria tra sessioni

14. **Aggiornare questo file alla fine di ogni sessione** con stato
    delle task (✅ DONE / 🟡 IN PROGRESS / ⬜ TODO) e handoff per next
    session in fondo.
15. **CLAUDE.md punta qui** finché RED ALERT è aperto. Non chiudere
    RED ALERT senza prima aggiornare CLAUDE.md.

---

## Il problema scientifico (in parole)

ARCHS4 v2.5 è il dump HDF5 prodotto dal Maayan Lab che contiene
~2 milioni di sample GEO con espressione + metadati. Lo Stadio 0 della
nostra pipeline legge questo dump, applica un filtro, e produce gli
~879k sample che poi vengono classificati dall'LLM.

Il filtro attuale è:

```
organism_ch1 == "Homo sapiens"  AND  library_strategy == "RNA-Seq"  AND  string ≥ 20 char
```

Questo filtro è **insufficiente**. ARCHS4 ha 29 campi metadato a livello
sample + 3 a livello gene, e la maggior parte dei segnali utili per
distinguere bulk da single-cell, per controllare i batch tecnici, e per
indicizzare correttamente i geni, sono in campi che ignoriamo.

### Campi ignorati che contano per la scienza

| Campo | Cosa ci dice | Conseguenza dell'averlo ignorato |
|---|---|---|
| `library_source` | "transcriptomic single cell" esplicito | 30.944 sample single-cell dichiarati sono passati come bulk |
| `extract_protocol_ch1` | Nome del kit (10x, SmartSeq2, Fluidigm…) | Migliaia di single-cell mascherati col nome del kit nella descrizione |
| `singlecellprobability` | Predizione ARCHS4 (0-1) | 283k sample (32%) hanno prob > 0.5; non li abbiamo mai guardati |
| `molecule_ch1` | total RNA / polyA / nuclear | L'LLM non sa se sta classificando un polyA o un total RNA (cambia che geni vede) |
| `instrument_model` | HiSeq2500 vs NovaSeq vs ecc. | Covariata batch tecnica mai inclusa nei modelli DE |
| `data_processing` | Aligner upstream (STAR / Salmon / HISAT…) | Variazione pipeline upstream mai controllata |
| `/meta/genes/ensembl_gene` | Ensembl ID univoco per gene | Non usato; abbiamo usato `symbol` che ha 4.638 duplicati → bug paralogi HLA/KIR (ADR-0016) |
| `/meta/genes/biotype` | protein_coding vs lncRNA vs miRNA… | DE girata su tutti i 67k geni invece dei ~20k protein_coding |

### Cosa significa concretamente

- I 13.7M risultati di DE in `cluster_pooled.parquet` sono calcolati su
  un dataset che mescola bulk e single-cell. Le distribuzioni count
  sono incompatibili, i modelli (limma-voom, dream) assumono bulk.
  Quanto è inquinato l'output corrente è la domanda della FASE A.
- Le DE non controllano per instrument_model né per aligner. Quindi
  effetti tecnici di Illumina HiSeq2500 vs NovaSeq6000 + STAR vs Salmon
  sono confusi con effetti biologici.
- I 4.638 simboli gene duplicati sono stati gestiti a valle con
  `make.unique()` (ADR-0016 Decision 2). È funzionante ma maldestro:
  l'Ensembl ID era già pronto in HDF5 da usare come index univoco.

### Decisione utente 2026-05-25

L'utente ha autorizzato:

- **LLM input**: aggiungere `molecule_ch1` (questo richiede re-run completo
  Stadio 1).
- **Filtro pre-LLM single-cell**: `library_source` + parsing
  `extract_protocol_ch1`. Per `singlecellprobability`, **cauto**:
  vedere distribuzione dopo gli altri filtri + `lib_size_min = 500k`,
  e decidere soglia empiricamente (forse non usarla, forse soglia alta).
- **Post-LLM (analisi)**: includere `instrument_model` + `data_processing`
  (parsed in classe aligner) come covariate; usare `ensembl_gene` come
  index e `biotype == protein_coding` come filtro default.
- **`relation` (BioSample)**: AGGIUNTO. Va valutato contro `donor_id`
  LLM-estratto (che già esiste in Stadio 1 + Stadio 3
  `n_distinct_donors`). FASE A7 confronta i due segnali su un campione
  reale del dataset, e decide se: (a) usare `relation` come primario
  + `donor_id` come fallback, (b) usare `donor_id` come primario, (c)
  combinare entrambi (union dei due segnali). FASE E0 implementa la
  scelta. La decisione finale viene circostanziata nell'ADR-0019.

---

## Lista cose da fare

Le fasi vanno in ordine. Le task entro una fase possono parzialmente
sovrapporsi.

Legenda stato: ⬜ TODO · 🟡 IN PROGRESS · ✅ DONE.

### FASE A — Scoping (prima di toccare codice)

Obiettivo: capire la magnitudine del problema single-cell + fissare la
soglia `singlecellprobability` empiricamente. Niente codice
produttivo, solo conta + plot.

#### ✅ A1 — Conta sample che cadono col filtro `library_source`

**Cosa facciamo.** Andiamo a vedere quanti dei nostri 879.167 sample
sono etichettati esplicitamente da ARCHS4 come single-cell tramite il
campo `library_source`. Questo è il filtro più "duro" e meno
discutibile, perché è un'etichetta che ARCHS4 importa da GEO senza
inventarsela.

**Perché serve.** Sono i sample che single-cell lo sono **per
dichiarazione esplicita** del submitter GEO. Toglierli non è
un'opinione: è coerente con quello che diciamo nel paper ("bulk
RNA-Seq meta-analysis"). Sappiamo già da una pre-conta che sono
~30.944 sample, ma vogliamo il numero esatto dopo i filtri attuali
(umano + RNA-Seq + lunghezza stringa).

**Come.**
1. Leggiamo dall'HDF5 ARCHS4 il campo `library_source` per i 879.167
   sample del dataset rescued.
2. Contiamo quanti hanno valore `"transcriptomic single cell"` o
   `"genomic single cell"`.
3. Salviamo la lista dei GSM rimossi in un file di log (ci serve poi
   per il count cumulato e per le supplementary del paper).

**Cosa ci aspettiamo di vedere.** Un numero, plausibilmente tra 25k e
35k. Distribuzione per studio: 1 sample o tutti i sample dello studio?
Se uno studio ha 50 sample di cui 5 marcati single-cell, è un
mixed-study e dobbiamo gestirlo con attenzione (può essere errore di
submission, o uno studio con sotto-parti diverse).

**Decisione che dipende da A1.** Se i numeri sono in linea con la
stima (~30k), procediamo dritti al filtro. Se sono enormemente diversi
(es. 200k), ci fermiamo a capire perché prima di accettare la
rimozione.

#### ✅ A2 — Conta sample aggiuntivi che cadono col parsing di `extract_protocol_ch1`

**Cosa facciamo.** Andiamo a vedere quanti sample, che ARCHS4 non ha
marcato esplicitamente come single-cell in `library_source`, in realtà
lo sono perché il loro `extract_protocol_ch1` cita protocolli
single-cell noti. Esempi reali nel nostro dataset: "Fluidigm C1 800
chip", "SmartSeq2 (21X-23X PCR cycles)", "ICELL8 single cell", "Single
nuclear capture".

**Perché serve.** Il submitter GEO a volte sbaglia il campo
`library_source` (lo lascia su "transcriptomic" anche per single-cell),
ma poi nella descrizione del protocollo è onesto su che kit ha usato.
Quindi `extract_protocol_ch1` ci dà una **seconda rete di sicurezza**
per intercettare i single-cell che sono sfuggiti al primo filtro. È un
controllo testuale (regex), quindi meno deterministico di A1, ma molto
pulito perché i nomi dei kit sono univoci.

**Come.**
1. Su tutti i sample che hanno **superato** il filtro A1 (cioè non già
   flaggati come single-cell), leggiamo `extract_protocol_ch1`.
2. Definiamo una lista di pattern univoci che indicano single-cell.
   Lista approvata 2026-05-26 (estesa rispetto alla bozza iniziale dopo
   evidence emerse da A1c `library_source=other`). Divisa in due gruppi:

   **Gruppo K — kit/platform specifici** (alta confidenza, no false
   positive attesi):
   - `10x Genomics` / `10X Genomics` / `Chromium` / `10x chip`
     (richiede contesto Genomics/Chromium/chip per evitare match con
     "10x SDS buffer", "10x SSC", "10x diluted")
   - `SmartSeq` / `Smart-Seq` / `Smart Seq` / `SmartSeq2` / `SmartSeq3`
     (esclude esplicitamente `Smart-3SEQ`, che è bulk 3'-tag RNA-seq
     Foley 2019, NON single-cell)
   - `Fluidigm` / `C1 chip` / `C1 IFC`
   - `ICELL8`
   - `Drop-seq` / `inDrop`
   - `CEL-seq` / `MARS-seq`
   - `Seq-Well`
   - `BD Rhapsody`
   - `Digital microfluidics` (visto in GSE240579 come SC custom)
   - `CellPlex` / `3' CellPlex` (10x multiplexing kit)
   - `CellTag` (lineage barcoding SC, visto in GSE239651)
   - `Multi-seq` (multiplexing SC)
   - `snDrop`

   **Gruppo S — single-cell semantica** (espressioni generiche, da
   gestire con cura per false positive):
   - `single cell` / `single-cell` (catch-all letterale)
   - `single nuclear` / `single nuclei`
   - `snRNA` / `snRNA-seq` / `snRNAseq` / `Nuc-seq` (snRNA-seq)
   - `scRNA` / `scRNA-seq` / `scRNAseq`

3. Per ogni sample, marchiamo `is_single_cell_protocol_K = TRUE` se
   matcha almeno un pattern del gruppo K, e `is_single_cell_protocol_S
   = TRUE` se matcha gruppo S. La distinzione serve per stimare il
   tasso di false positive: il gruppo K è praticamente safe, il gruppo S
   richiede validazione manuale (es. "compared to a single cell line"
   NON è single-cell ma matcha "single cell"). Salviamo la lista dei
   GSM colpiti + il pattern che ha matchato.
4. **Title-based rescue post-validazione FPR 2026-05-26**: sample che
   matchano regex SC ma il cui `title` contiene esplicitamente `bulk`
   (regex `(?i)\bbulk\b|\bbulkRNA`) vengono **esclusi dal drop**.
   Razionale: validazione cluster-based FPR (A2b) sui pattern volumetrici
   SmartSeq (171k catch, FPR 0.70% [0.34-1.45% Wilson 95% CI]) e
   single_cell_literal (158k catch, FPR 1.00% [0.55-1.83%]) ha
   identificato che ~70-80% dei FP sono **sample bulk-low-input in
   studi multi-modality** dove il submitter ha messo nello stesso GSE
   sia bulk che SC, e l'`extract_protocol_ch1` cita entrambi. Il title
   del sample chiarisce il caso specifico (es. `iPS2.D49.3 (bulk)`,
   `Sample-106 (Total Bulk RNA-seq)`, `Bulk_RNA-Seq_NSCLC_11_NTIL`,
   `bulkRNA HGR0000429_T1`). Rescue verificato su 20 random: 0/20 false
   rescue. Lista rescued salvata in
   `analysis/audit/A2-rescued-by-title-bulk.tsv`.
5. Confronto con A1: quanti sample sono NUOVI catch (non già marcati
   da A1)? Breakdown per gruppo K / gruppo S.

**Cosa ci aspettiamo di vedere.** Una stima a occhio: tra 10k e 50k
sample aggiuntivi. Il "veramente importante" sarà guardare gli esempi:
ti farei vedere 20 stringhe `extract_protocol_ch1` matchate a caso,
così verifichi che il regex non sta tirando dentro falsi positivi (es.
uno studio bulk che cita "single cell" solo per dire "non abbiamo
fatto single-cell"). Se trovo falsi positivi, irrigidisco i pattern.

**Decisione che dipende da A2.** Se i pattern catturano molti casi
puliti, il filtro entra in produzione. Se trovo molti falsi positivi
(catturo studi che NON sono single-cell), togliamo il pattern
problematico dalla lista o lo rendiamo più specifico. La lista finale
dei pattern viene committata nel codice + nell'ADR-0019, così è
tracciabile.

#### ✅ A3 — Distribuzione `singlecellprobability` sui sopravvissuti

**Cosa facciamo.** Sui sample che hanno superato A1+A2, applichiamo
anche il filtro lib_size_min = 500k (lo stesso filtro che usa Stadio 4
per QC). Sui sample che superano TUTTI questi filtri, guardiamo la
distribuzione di `singlecellprobability` (la predizione di ARCHS4,
continua tra 0 e 1).

**Perché serve.** `singlecellprobability` è un modello statistico
fatto da ARCHS4 che indovina se un sample è single-cell guardando il
pattern di espressione. Non è "verità": è una stima. Se dopo A1+A2 e
lib_size la distribuzione di singlecellprobability è schiacciata vicino
a zero (i.e. quasi tutti sotto 0.1), vuol dire che A1+A2 hanno già
fatto il loro lavoro e singlecellprobability non aggiunge informazione.
Se invece c'è ancora una coda destra alta (es. il 5% dei sopravvissuti
ha prob > 0.5), allora vale la pena usarla con una soglia alta tipo 0.9
per pescare gli ultimi single-cell mascherati.

**Come.**
1. Carichiamo i sample che passano A1 + A2.
2. Per ognuno calcoliamo `lib_size = sum(counts)` dall'HDF5
   `/data/expression`. Teniamo solo lib_size ≥ 500.000 (uguale al
   filtro QC Stadio 4).
3. Sui sopravvissuti, leggiamo `singlecellprobability` e facciamo:
   istogramma, summary (min/Q1/median/mean/Q3/max), conta sopra 0.3 /
   0.5 / 0.7 / 0.9.
4. Salviamo il plot in `analysis/audit/A3-scprob-distribution.png`.

**Cosa ci aspettiamo di vedere.** Due scenari:
- **Scenario "filtri puliti"**: distribuzione concentrata sotto 0.3,
  pochissimi sample sopra 0.5. Conclusione: non usiamo
  singlecellprobability, dichiariamo nel paper.
- **Scenario "coda residua"**: 5-15% dei sopravvissuti ha prob > 0.5.
  Conclusione: aggiungiamo filtro `singlecellprobability < 0.9` (o
  soglia da decidere guardando il plot).

**Decisione che dipende da A3.** Sceglie la soglia
`singlecellprobability` finale (o l'assenza di soglia, dichiarata).

#### ✅ A4 — Quanti single-cell sono ATTUALMENTE in `cluster_pooled.parquet`

**Cosa facciamo.** Ribaltiamo l'analisi sul prodotto finale che già
abbiamo (run 96c43acb). Sui ~13.7M risultati DE in `cluster_pooled.parquet`,
quanti cluster contengono sample che sarebbero stati esclusi da A1+A2+A3?

**Perché serve.** Misura quantitativa dell'inquinamento dell'output
corrente. Determina se possiamo "salvare" il run 96c43acb con un
filtro post-hoc sui cluster, oppure se il rebuild totale è obbligatorio
(cosa che già sospettiamo, ma vogliamo il numero).

**Come.**
1. Da `clusters.rds` (Stadio 3 baseline) prendiamo il mapping cluster_id
   → sample_id usati.
2. Marchiamo ogni sample come "single-cell se A1 OR A2 OR A3 lo
   eliminerebbe".
3. Per ogni cluster contiamo `frac_sc = n_sample_sc / n_sample_totali`.
4. Tabella: quanti cluster con frac_sc = 0% / 1-10% / 10-50% / >50% /
   100%.

**Cosa ci aspettiamo di vedere.** Una distribuzione bimodale: cluster
puliti (frac_sc = 0) + cluster sporcati. La quota dei sporcati e quanto
sono sporcati determina la decisione su A5.

**Decisione che dipende da A4.** Conferma o nega che il rebuild totale è
obbligatorio. Se inquinamento basso (<5% cluster con frac_sc > 0),
potrebbe essere sufficiente filtro post-hoc. Se alto, rebuild.

#### ✅ A5 — Soglia `singlecellprobability` finale (decision point)

**Cosa facciamo.** Sulla base di A3 + A4, fissiamo la soglia
`singlecellprobability` per il filtro produttivo (o la non-soglia,
dichiarata).

**Perché serve.** È un parametro libero. Va deciso una volta, registrato
in ADR-0019 (FASE B), e non più toccato.

**Come.** Discussione con te su istogramma A3 + impatto A4. Una
decisione scritta nel commit log + ADR.

**Cosa ci aspettiamo di vedere.** Una riga: "soglia
singlecellprobability = X" oppure "soglia non usata, motivazione: Y".

**Decisione che dipende da A5.** Determina il codice di C2 (filtro
Stadio 0 esteso) e l'ADR B1.

#### ✅ A6 — Decisione binaria rebuild vs filtro post-hoc

**Cosa facciamo.** Sulla base dei numeri A1-A5, decidiamo:
(a) rebuild totale FASE F (default), oppure
(b) "salvataggio" del run 96c43acb con filtro post-hoc.

**Perché serve.** Anche se la nostra preferenza è già rebuild, vogliamo
che la decisione sia data-driven, non assunzione. Se A4 mostra che
solo lo 0.5% dei cluster è contaminato, magari un filtro post-hoc + un
asterisco nel paper è razionale.

**Decisione che dipende da A6.** Stop o avanti con FASI B-G.

#### ⬜ A7 — Confronto qualità dedupe: `relation` (BioSample) vs `donor_id` (LLM)

**Cosa facciamo.** Andiamo a vedere su un campione reale del nostro
dataset quale dei due segnali è più affidabile per dire "questi due
GSM in studi diversi sono lo stesso campione biologico".

**Perché serve.** I due segnali sono complementari ma diversi:

- **`relation`** è un campo che ARCHS4 importa da GEO. Tipicamente
  contiene `"Reanalyzed by: GSE<numero>, BioSample: https://…/SAMN<id>"`.
  Il BioSample SAMN è la chiave canonica NCBI per "stesso campione".
  Pro: deterministico, controllato da NCBI. Contro: presente solo se
  il submitter ha linkato il BioSample (alcuni studi non lo fanno).
- **`donor_id`** è un campo che l'LLM estrae da testo libero dei
  characteristics ("patient P5", "donor 2", "subject_001"). Pro:
  funziona anche senza BioSample link. Contro: euristica, può non
  legare "subject 1" in GSE-A e "patient 001" in GSE-B per lo stesso
  individuo.

Se uno dei due è dominante (es. `relation` copre il 95% dei casi e
`donor_id` aggiunge solo lo 0.5%), usiamo quello principale e
l'altro come fallback. Se sono complementari (`relation` copre 60%,
`donor_id` un altro 30%), li combiniamo.

**Come.**
1. Sui ~879k sample con `relation` non-vuoto: parsing per estrarre il
   SAMN BioSample ID. Conta quanti sample hanno un SAMN associato.
2. Cross-check con `donor_id`: tabella di contingenza
   (BioSample SAMN unico × donor_id unico). Servono casi dove lo
   stesso SAMN appare in più GSE diversi → quello è il vero
   duplicato cross-studio che cerchiamo.
3. Per i sample senza SAMN, vedere se `donor_id` LLM-estratto cattura
   qualche duplicato che `relation` perderebbe.
4. Random sample di 30 casi controversi (es. due GSM con stesso SAMN
   ma `donor_id` diversi; o stesso `donor_id` ma SAMN diversi) → review
   manuale con te per capire chi ha ragione.

**Cosa ci aspettiamo di vedere.** Una tabella con:
- numero sample con SAMN parsable da `relation`
- numero sample con `donor_id` non-NA
- numero overlapping (entrambi presenti)
- numero esclusivi a `relation` (no donor_id)
- numero esclusivi a `donor_id` (no SAMN)
- numero duplicati cross-GSE catturati da ciascuno dei due segnali

**Decisione che dipende da A7.** Sceglie strategia dedupe:
(a) `relation` primario + `donor_id` fallback, (b) `donor_id` primario,
(c) union. La decisione entra in ADR-0019 con i numeri di supporto.

---

### FASE B — Spec + ADR

Obiettivo: scrivere a libro le decisioni prima di toccare codice.

#### ⬜ B1 — ADR-0019 "ARCHS4 metadata exploitation v2"

**Cosa facciamo.** Scriviamo l'Architectural Decision Record che fissa
tutte le decisioni di questo RED ALERT in un unico documento durevole.

**Perché serve.** Convenzione del progetto: ogni decisione architetturale
documentata in ADR prima del codice che la riflette (CLAUDE.md §
"Tracciabilità").

**Come.** Sezioni:
- Context: i 32 campi ARCHS4, gli 7 usati, il finding single-cell.
- Decision: lista delle scelte (pre-LLM filtri, LLM input molecule_ch1,
  post-LLM covariate, gene axis Ensembl, biotype filter, soglia
  singlecellprobability da A5, strategia dedupe BioSample da A7).
- Consequences: re-run obbligatori, breaking change per Layer B
  selection.csv, mitigazioni.
- Alternatives considered: filtro post-hoc cluster_pooled, soglie
  diverse, dedupe solo via donor_id (escluso se A7 mostra che relation
  porta valore), dedupe solo via relation (escluso se A7 mostra
  copertura insufficiente).

#### ⬜ B2 — Mini-spec parsing `data_processing`

**Cosa facciamo.** Definiamo come trasformare il testo libero di
`data_processing` (es. "STAR mapping, HTSeq-count 0.7+ gene counting,
Stampy virus mapping") in una classe aligner enumerata.

**Perché serve.** Per usarlo come covariata batch in limma-voom + dream
ci serve un fattore (categorico), non testo libero.

**Come.** Regex prioritizzate con fallback "unknown":
- STAR → "STAR" (case-insensitive, word-bounded)
- Salmon → "[Ss]almon"
- HISAT → "HISAT|hisat"
- kallisto → "[Kk]allisto"
- RSEM → "RSEM"
- BWA → "BWA|bwa"
- Bowtie → "[Bb]owtie"
- TopHat → "[Tt]op[Hh]at"
- "other" se >0 match ma nessuno noto
- "unknown" se 0 match o stringa vuota
Quale prevale se ne matchano più di uno (è comune: "STAR + RSEM")?
Proposta: ordine di priorità STAR > HISAT > Salmon > kallisto > RSEM
> BWA > Bowtie > TopHat. Da discutere.

#### ⬜ B3 — Mini-spec parsing `extract_protocol_ch1` per single-cell

**Cosa facciamo.** Formalizziamo il regex single-cell di A2 in una
funzione riusabile.

**Perché serve.** Stessa logica di B2: ci serve un test deterministico
ripetibile, non un one-off.

**Come.** Funzione `is_single_cell_protocol(text) -> logical`. La lista
dei pattern di A2 (post-revisione utente) finisce qui. Tests con
fixture sia positive (10 stringhe SC reali del dataset) che negative
(10 stringhe bulk che NON devono matchare).

---

### FASE C — Codice PRE-LLM (Stadio 0)

#### ⬜ C1 — Estendere `read_archs4_metadata()`

**Cosa facciamo.** La funzione attualmente legge 7 campi. La estendiamo
a leggerne tutti quelli che servono: aggiungere `molecule_ch1`,
`library_source`, `extract_protocol_ch1`, `singlecellprobability`,
`instrument_model`, `data_processing`.

**Perché serve.** Tutto quello che viene dopo lavora sull'output di
questa funzione. Se i campi non ci sono, non si può fare niente.

**Come.** Aggiunta dei nomi alla lista `fields` nella funzione. Update
del test che verifica i campi letti.

#### ⬜ C2 — Estendere `is_sample_classifiable()` con filtri SC nuovi

**Cosa facciamo.** Aggiungiamo al filtro Stadio 0:
- `library_source` non ∈ {"transcriptomic single cell", "genomic single cell"}
- `is_single_cell_protocol(extract_protocol_ch1) == FALSE`
- (eventuale) `singlecellprobability < soglia` (da A5)

**Perché serve.** È il cuore del fix single-cell. Skip log scrive
reason codes: `single_cell_library_source`,
`single_cell_protocol_match`, `single_cell_probability_high`.

**Come.** Update di `is_sample_classifiable()` + tests TDD (test
fixture con sample fake per ogni reason code).

#### ⬜ C3 — Build ARCHS4 metadata RDS esteso

**Cosa facciamo.** Costruiamo
`analysis/p4-output/p4-beta-archs4-metadata-v2.rds` che contiene tutti
i campi tecnici (instrument_model, data_processing parsed in
aligner_class, gpl, library_source ecc.) per ogni sample sopravvissuto
al filtro Stadio 0.

**Perché serve.** Stadio 4 (modelli DE) ha bisogno di queste covariate
ma non vogliamo ri-leggere l'HDF5 ogni volta. Un singolo RDS leggibile
è meglio.

**Come.** Funzione `build_archs4_metadata_v2()` che:
1. legge i campi tecnici da H5
2. parsa data_processing → aligner_class via funzione di B2
3. salva come RDS

#### ⬜ C4 — Update JSONL input Stadio 1 con `molecule_ch1`

**Cosa facciamo.** Lo JSONL che leggiamo per dare in pasto all'LLM
attualmente ha `{geo_accession, series_id, string, library_strategy,
organism}`. Aggiungiamo `molecule_ch1`.

**Perché serve.** L'LLM deve sapere se sta classificando un sample di
total RNA o di polyA (cambia che geni vede).

**Come.** Aggiunta del campo in `archs4_to_stage1_jsonl()` + update
test.

#### ⬜ C5 — Tests TDD per C1-C4

**Cosa facciamo.** Aggiunta dei test che falliscono prima del codice e
passano dopo. Conferma che i nuovi reason code sono raggiungibili e
che il JSONL contiene il nuovo campo.

---

### FASE D — Codice LLM (Stadio 1)

> ⚠️ **GATE UTENTE**. L'utente ha esplicitamente chiesto di rivedere il
> prompt Stadio 1 prima di qualunque modifica. D1a estrae il prompt
> corrente verbatim + propone l'integrazione `molecule_ch1` + aspetta
> approvazione utente. Solo dopo OK, D1b applica.

#### ⬜ D1a — Mostra prompt Stadio 1 attuale + proponi modifica (gate utente)

**Cosa facciamo.** Andiamo a leggere `R/llm-stage1.R::build_prompt_stage1()`
+ `R/llm-stage1.R::.stage1_system_prompt()` e estraiamo verbatim il
testo del system prompt + del user prompt template che vengono
spediti all'LLM per OGNI sample. Lo presentiamo all'utente per
review. Insieme presentiamo la proposta di integrazione `molecule_ch1`
(esattamente la riga che vogliamo aggiungere, esattamente dove).

**Perché serve.** Il prompt Stadio 1 è la spec semantica della
classificazione. Un cambio anche minimo può spostare la distribuzione
delle decisioni LLM. L'utente vuole controllarlo a vista prima di
autorizzare il rerun.

**Come.**
1. Leggere il file `R/llm-stage1.R` e estrarre i due blocchi (system +
   user prompt template) come testo verbatim.
2. Salvarli in `analysis/audit/D1a-prompt-stage1-current.txt` per
   tracciabilità.
3. Scrivere accanto la proposta D1b: la riga esatta da aggiungere +
   la posizione esatta (dopo quale riga del prompt).
4. Mostrare entrambi all'utente. Aspettare OK / modifiche.

**Cosa ci aspettiamo di vedere.** Output: due blocchi di testo (current
+ proposed diff) + decisione utente.

**Decisione che dipende da D1a.** Approvazione esatta del nuovo prompt,
o richiesta di modifica.

#### ⬜ D1b — Applica modifica prompt approvata in D1a

**Cosa facciamo.** Modifica del prompt secondo la versione approvata in
D1a. Tests che verificano la presenza della riga "RNA selection
method:" (o equivalente approvata) nel prompt generato.

**Perché serve.** Inserisce in produzione la versione approvata.

**Come.** Edit di `R/llm-stage1.R` + tests TDD + commit dedicato che
cita D1a come gate utente nel messaggio.

#### ⬜ D2 — Tests D1b

---

### FASE E — Codice POST-LLM (Stadio 3 metadata + Stadio 4 DE)

#### ⬜ E0 — Implementazione dedupe BioSample da A7

**Cosa facciamo.** Implementiamo nel codice la strategia dedupe scelta
in A7 (relation primario / donor_id primario / union). Nuova
funzione `R/etl-archs4-utils.R::parse_biosample_id(relation)` per
estrarre SAMN ID da `relation`. Stadio 3 `R/stage3-metadata.R`
modificato per consumare sia `donor_id` (già esistente) sia il nuovo
`biosample_id`, e calcolare `n_distinct_biosamples` per cluster.

**Perché serve.** È la materializzazione di A7 nel codice produttivo.
Senza questa, A7 resta una nota e non cambia niente nella pipeline.

**Come.**
1. Funzione `parse_biosample_id(relation_text) -> character (SAMN ID o NA)`
   con tests fixture.
2. `build_archs4_metadata_v2()` (C3) carica anche il SAMN ID parsato.
3. `R/stage3-metadata.R::.enrich_cluster_metadata()` aggiunge il calcolo
   di `n_distinct_biosamples` + `dedupe_strategy` come colonna logged
   nel cluster summary.
4. Tests TDD.

#### ⬜ E1 — Gene axis a Ensembl ID

**Cosa facciamo.** `.h5_gene_axis()` oggi torna `symbol` con
`make.unique()`. Cambiamo: torna `ensembl_gene` come rownames
(univoco), e `symbol` come colonna di annotazione separata.

**Perché serve.** Risolve il bug paralogi (ADR-0016 Decision 2) in modo
pulito invece che con la patch make.unique che genera "KIR3DL2.1
KIR3DL2.2 …" come rownames sintetici. Ensembl ID univoco per design,
nessuna ambiguità.

**Come.** Modifica `R/stage4-counts-cache.R::.h5_gene_axis()` per
leggere `/meta/genes/ensembl_gene`. Tabella di mapping ensembl↔symbol
diventa output separato che entra in `cluster_pooled.parquet` come
colonna `gene_symbol`. `make.unique` rimosso.

#### ⬜ E2 — Filtro `biotype == protein_coding`

**Cosa facciamo.** Aggiungiamo a `build_stage4_results()` un parametro
`gene_biotype_filter = "protein_coding"` (default). Solo i geni con
quel biotype vengono mantenuti per le DE.

**Perché serve.** Riduce ~67k geni → ~20k geni. Meno multiple testing,
segnale più forte. lncRNA e pseudogeni rimangono fuori dal volcano di
default (riducendo falsi positivi tipo "il top hit è un lncRNA poco
caratterizzato").

**Come.** Modifica del config Stadio 4 + opzione di disabilitazione
(`gene_biotype_filter = NULL` mantiene tutti).

#### ⬜ E3 — Covariate batch `instrument_model` + `aligner_class` nel design

**Cosa facciamo.** Modifichiamo la formula di limma-voom per-studio e di
dream-mega aggiungendo `instrument_model` e `aligner_class` come
covariate fisse (`~ treatment + instrument_model + aligner_class +
(1|study)` per dream).

**Perché serve.** Controllo per batch tecnici (sequenziatore + aligner
upstream). Riduce confondimento.

**Come.** Modifica delle funzioni `.run_limma_voom_de()` e
`.run_dream_mega()`. Edge case: cluster con un solo livello unico di
covariata → drop di quella covariata per quel cluster (warning logged
in qc_report). Tests per entrambi i casi.

#### ⬜ E4 — Tests E1-E3

#### ⬜ E5 — Stage4 dashboard/Layer B compatibility

**Cosa facciamo.** Verifichiamo che `cluster_pooled.parquet` con il
nuovo schema (ensembl_gene + symbol + biotype + covariate logged in
metadata) sia compatibile con Layer B plots (forest, MA, volcano,
heatmap).

**Perché serve.** Se la colonna chiave gene cambia da `symbol` a
`ensembl_gene`, tutti i plot di Layer B che mostrano gene name devono
mostrare symbol (più leggibile per il bio reader), non Ensembl ID.

**Come.** Smoke 3-cluster Layer B dopo che E1-E3 sono pronti.
Verificare visivamente che symbols vengono ancora labellati nei plot.

---

### FASE F — Re-run pipeline (ATTENZIONE: gate prima di partire)

**⚠️ Gate.** Prima di partire con F1, sessione separata. CLAUDE.md
aggiornato. Quando tutte F1-F6 sono andate, RED ALERT chiude **per
Stadio 0**. L'audit completo della pipeline NON è finito: vanno
ancora trattati Stadio 1, Stadio 2, Stadio 3, Stadio 4 (vedere
`project_pipeline_trust_audit_session1` + i 6 finding HIGH paper-grade
in `2026-05-25-pipeline-map-v0-critical-reading.md` /
`2026-05-25-pipeline-map-v0-codex-review.md`).

#### ⬜ F1 — ETL re-run (nuovo JSONL filtrato + esteso)

**Cosa facciamo.** Rigirare `analysis/p4-beta-etl-build.R` con il nuovo
filtro Stadio 0 + il nuovo campo `molecule_ch1`. Output: nuovo
`archs4-human-stage1-input.jsonl`.

**Perché serve.** Punto di partenza pulito per Stadio 1 rerun.

#### ⬜ F2 — Stadio 1 fullrun DGX

**Cosa facciamo.** Submit del fullrun Stadio 1 sul nuovo input JSONL.

**Perché serve.** Re-classifica tutti i sample con il nuovo prompt
(che include molecule_ch1 come hint).

**Come.** Stessa procedura del fullrun precedente: chunked
orchestrator + cron tick. Sample meno (~30% drop per single-cell) →
fullrun più breve in proporzione.

#### ⬜ F3 — Stadio 2 fullrun DGX

**Cosa facciamo.** Build nuovo Stadio 2 input + submit fullrun.

**Perché serve.** Stage 2 input cambia perché Stadio 1 output cambia.

#### ⬜ F4 — Stadio 3 rebuild

**Cosa facciamo.** Rebuild `build_stage3_clusters()` con anchor v3.1.1
(che già abbiamo dall'audit ontology) + i nuovi Stadio 1+2.

**Perché serve.** Cluster cross-studio cambiano perché input cambia.

#### ⬜ F5 — Stadio 4 Layer A rebuild

**Cosa facciamo.** Rebuild `build_stage4_results()` con (a) il nuovo
Stadio 3, (b) ensembl gene axis, (c) biotype filter, (d) covariate
instrument_model + aligner_class.

**Perché serve.** Nuovo `cluster_pooled.parquet` clean.

#### ⬜ F6 — Layer B re-selection + rebuild

**Cosa facciamo.** La selection.csv attuale (15 case study, sha256
56b911e6) è obsoleta perché i cluster_id sono cambiati. Ri-girare lo
shortlist script e ri-curare la selection con te.

**Perché serve.** Senza una nuova selection ri-curata non possiamo
produrre il report Layer B finale.

---

### FASE G — Doc + commit + tag

#### ⬜ G1 — Update NEWS.md

#### ⬜ G2 — Finding paper-grade

**Cosa facciamo.** Scriviamo
`docs/findings/2026-05-25-archs4-metadata-completeness-audit.md` che
documenta l'intera vicenda single-cell + covariate + ensembl axis per
le supplementary del paper.

**Perché serve.** Trasparenza scientifica + materiale Methods/Results.

#### ⬜ G3 — Update CLAUDE.md status post-fix

#### ⬜ G4 — Tag `p5-archs4-metadata-v2-complete`

**Cosa facciamo.** Tag che marca la chiusura **di questo** RED ALERT
(Stadio 0). ff-merge della branch in master locale. Aprire next RED
ALERT per Stadio 1 audit nella sessione successiva.

---

## Riferimenti

- **Audit completo pipeline (parent context)**:
  `docs/findings/2026-05-25-pipeline-map-v0.md` (mappa descrittiva)
  + `docs/findings/2026-05-25-pipeline-map-v0-critical-reading.md`
  (errori/bias) + `docs/findings/2026-05-25-pipeline-map-v0-codex-review.md`
  (review Codex, 6 finding HIGH paper-grade).
- **Audit LLM anchor classification (parent)**:
  `docs/findings/2026-05-24-llm-anchor-classification-audit.md`.
- **ADR-0016** "Stage 4 MEGA-AUG crash fixes + baseline pool cap"
  (gene-symbol paralogi paragrafo Decision 2 → da risolvere con E1).
- **ADR-0018** "LLM anchor ontology override" (Proposed, sospesa fino a
  RED ALERT chiuso).
- **CLAUDE.md** "Convenzioni operative dell'utente" — italiano,
  tracciabilità, git workflow, etc.

---

## Stato + handoff (aggiornare alla fine di ogni sessione)

### Stato corrente

- 2026-05-25 sessione 1: RED ALERT aperto, scope Stadio 0. Tutte le
  task ⬜ TODO. Mappa pipeline + critical reading + codex review già
  prodotti in sessione precedente
  (`docs/findings/2026-05-25-pipeline-map-v0*.md`).
- 2026-05-26 sessione 2: RED ALERT revisionato con utente. Aggiunto
  `relation` in scope (A7 + E0), splittato D1 in D1a/D1b come gate
  prompt, chiarito che scope è solo Stadio 0 dell'audit completo a
  5 stadi. CLAUDE.md banner aggiornato. Sessione chiusa qui.
- 2026-05-26 sessione 3: ✅ A1 chiusa (commit `bdbe879`). Decisione
  whitelist `library_source == "transcriptomic"` con drop 28.942/879.167
  = 3.29% motivato puntualmente per 4 valori esclusi (sintesi in
  `analysis/audit/A1-synthesis-libsrc-whitelist.md`). Lista pattern A2
  estesa con 8 kit nuovi + separazione gruppo K (kit-specific) / S
  (semantica). ✅ A2 + A2b FPR validation + title-bulk rescue: drop
  302.694/850.225 = 35.60%. Aggregato A1+A2 = 330.709/879.167 = **37.62%**.
  FPR osservato 0.70% SmartSeq + 1.00% single_cell_literal.
  ✅ **A3 chiusa**: soglia singlecellprobability=0.9 al plateau curva
  FPR proxy + manuale (150 sample classified, 0.5: 36% FPR, 0.7-0.8:
  14%, ≥0.9: 8% Wilson 95% CI [3-19%]). Drop A3 addizionale 1.225 /
  508.685 = 0.24% del bacino post-lib_size + 38.846 drop lib_size <500k
  (QC condiviso Stadio 4). Aggregato Stage 0 totale: 371.707 / 879.167
  = **42.28%** drop. Bacino finale candidati bulk: **507.460 sample**.
  Sintesi `analysis/audit/A3-synthesis-singlecellprobability.md` con
  prospettiva futura "LLM-based quality check post-aggregazione" come
  task deferred post-FASE F.
  ✅ **A4 + A5 + A6 chiuse**: cluster contamination Layer A baseline
  (run 96c43acb, 487 cluster). **30.8% cluster contaminati** (150/487,
  6x sopra soglia 5%); 15.09% sample SC nei pool aggregati; 9.45%
  cluster con ≥50% SC; 3.9% cluster 100% SC. Pattern: group_mega
  contaminato 69%, pair_mega_aug 8%. **A6 decisione data-driven:
  REBUILD TOTALE OBBLIGATORIO** (filtro post-hoc respinto).
  Run 96c43acb (Layer A) + 56b911e6 (Layer B 15 case study)
  **obsoleti**. Sintesi `analysis/audit/A4-synthesis-cluster-contamination.md`.
  Prossimo step: A7 (dedupe BioSample vs donor_id) → B1 ADR-0019.

### Handoff next session

- Sessione successiva: parte da FASE A1.
- Branch attivo: `p5-llm-anchor-classification-audit`.
- Master invariato.
- Niente da fare prima di A1, solo rilettura di questo doc.
- Quando RED ALERT (Stadio 0) chiude: aprire nuovo doc
  `docs/RED_ALERT-stage1.md` per audit Stadio 1.
