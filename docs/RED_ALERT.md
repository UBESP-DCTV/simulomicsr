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

#### ✅ A7 — Confronto qualità dedupe: `relation` (BioSample) vs `donor_id` (LLM)

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

#### ✅ B1 — ADR-0019 "ARCHS4 metadata exploitation v2"

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

#### ✅ B2 — Mini-spec parsing `data_processing`

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

#### ✅ B3 — Mini-spec parsing `extract_protocol_ch1` per single-cell

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

#### ✅ C1 — Estendere `read_archs4_metadata()`

**Cosa facciamo.** La funzione attualmente legge 7 campi. La estendiamo
a leggerne tutti quelli che servono: aggiungere `molecule_ch1`,
`library_source`, `extract_protocol_ch1`, `singlecellprobability`,
`instrument_model`, `data_processing`.

**Perché serve.** Tutto quello che viene dopo lavora sull'output di
questa funzione. Se i campi non ci sono, non si può fare niente.

**Come.** Aggiunta dei nomi alla lista `fields` nella funzione. Update
del test che verifica i campi letti.

#### ✅ C2 — Estendere `is_sample_classifiable()` con filtri SC nuovi

**Cosa facciamo.** Aggiungiamo al filtro Stadio 0:
- `library_source` non ∈ {"transcriptomic single cell", "genomic single cell"}
- `is_single_cell_protocol(extract_protocol_ch1) == FALSE`
- (eventuale) `singlecellprobability < soglia` (da A5)

**Perché serve.** È il cuore del fix single-cell. Skip log scrive
reason codes: `single_cell_library_source`,
`single_cell_protocol_match`, `single_cell_probability_high`.

**Come.** Update di `is_sample_classifiable()` + tests TDD (test
fixture con sample fake per ogni reason code).

#### ✅ C3 — Build ARCHS4 metadata RDS esteso

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

#### ✅ C4 — Update JSONL input Stadio 1 con `molecule_ch1`

**Cosa facciamo.** Lo JSONL che leggiamo per dare in pasto all'LLM
attualmente ha `{geo_accession, series_id, string, library_strategy,
organism}`. Aggiungiamo `molecule_ch1`.

**Perché serve.** L'LLM deve sapere se sta classificando un sample di
total RNA o di polyA (cambia che geni vede).

**Come.** Aggiunta del campo in `archs4_to_stage1_jsonl()` + update
test.

#### ✅ C5 — Tests TDD per C1-C4

**Cosa facciamo.** Aggiunta dei test che falliscono prima del codice e
passano dopo. Conferma che i nuovi reason code sono raggiungibili e
che il JSONL contiene il nuovo campo.

---

### FASE D — Codice LLM (Stadio 1)

> ⚠️ **GATE UTENTE**. L'utente ha esplicitamente chiesto di rivedere il
> prompt Stadio 1 prima di qualunque modifica. D1a estrae il prompt
> corrente verbatim + propone l'integrazione `molecule_ch1` + aspetta
> approvazione utente. Solo dopo OK, D1b applica.

#### ✅ D1a — Mostra prompt Stadio 1 attuale + proponi modifica (gate utente)

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

#### ✅ D1b — Applica modifica prompt approvata in D1a

**Cosa facciamo.** Modifica del prompt secondo la versione approvata in
D1a. Tests che verificano la presenza della riga "RNA selection
method:" (o equivalente approvata) nel prompt generato.

**Perché serve.** Inserisce in produzione la versione approvata.

**Come.** Edit di `R/llm-stage1.R` + tests TDD + commit dedicato che
cita D1a come gate utente nel messaggio.

#### ✅ D2 — Tests D1b

#### ✅ D3 — Traduzione prompt Stadio 2 IT -> EN (scope-extension sessione 5)

**Cosa abbiamo fatto.** Decisione utente sessione 5 2026-05-27: allineare
la lingua del prompt Stadio 2 a Stadio 1 (entrambi inglese). Estrazione
verbatim del prompt italiano corrente + proposta traduzione 1:1
semantica + gate utente approvato (Q1+Q2+Q3 OK, Q4 anti-IT regression
test escluso esplicitamente).

**Perche' fuori scope FASE D originale.** FASE D nella prima stesura
(2026-05-26 sessione 2) trattava solo Stadio 1. La decisione utente di
allineare entrambi gli stadi all'inglese e' arrivata in sessione 5
durante D1a. Aggiunta come scope-extension.

**Come.** Modifica chirurgica del solo `R/llm-stage2.R`:
- `.stage2_system_prompt()` ~85 righe IT -> EN (1:1)
- `.STAGE2_PRIMARY_ROLES` 5 glosse IT -> EN
- `.STAGE2_CONTROL_TYPES` 7 glosse IT -> EN
- Enum values, schema fields, termini scientifici (DMSO, PBS, scrambled,
  siRNA, WT, KO) preservati verbatim.

**Validazione.** Mini-gold v5 ri-misurata come parte di FASE F3 fullrun
Stadio 2 post-rebuild (validation deferred, documentata in BLOCCO 5 di
`analysis/audit/D3-prompt-stage2-translation.txt`).

#### ✅ D4 — Fix bug latente Python organism_hint (simmetria D1b)

**Cosa abbiamo fatto.** Durante D1b ho rilevato un bug pre-esistente
silenzioso: l'ETL R (`R/etl-archs4-h5.R:97`) emette il JSONL con chiave
`organism` verbatim ARCHS4, ma il Python DGX
(`inst/dgx/python/prompts.py:28` pre-D4) cercava la chiave
`organism_hint`. Quindi nel fullrun beta Stadio 1 (888.821 sample, ETA
~18h), per ogni sample, l'LLM Mistral ha visto user message SENZA la
riga `organism_hint: Homo sapiens`. Bug silent: nessun crash. R-side
`classify_sample_row` aveva lo stesso problema (non leggeva `row$organism`).

**Perche' fuori scope FASE D originale.** Bug discovered durante D1b
investigation. Su richiesta utente sessione 5 ("sistemalo ora poi
andiamo avanti") -> fix immediato come D4 invece di task posticipata.

**Impatto scientifico basso ma non zero.** Stage 0 v2 filtra a monte
`organism_ch1 == "Homo sapiens"`, quindi tutti i sample inviati all'LLM
sono human -> la riga organism_hint mancante e' info ridondante per
discriminare. Pero': (a) asimmetria con `molecule_hint` sistemata in
D1b crea stato confuso, (b) forward-looking se in futuro multi-organismo,
(c) paper-grade discoverability del codice.

**Come.** Fix simmetrico al pattern stabilito in D1b:
- R/llm-stage1.R::classify_sample_row legge `row$organism` con guard
  e lo passa come `organism_hint=` a classify_sample.
- inst/dgx/python/prompts.py::render_user_message_stage1 cambia
  `record.get("organism_hint")` -> `record.get("organism")`.
- 2 test_that nuovi (R-positivo + R-row-senza-colonna).
- Python sanity 4/4 PASS su shape JSONL beta-real.

---

### FASE E — Codice POST-LLM (Stadio 3 metadata + Stadio 4 DE)

#### ✅ E0 — Implementazione dedupe BioSample da A7 (sessione 6, `cc77faf`)

**Cosa abbiamo fatto.** Materializzato ADR-0019 D9 in `clusters.rds`:

1. Record builders `R/stage3-build.R::.build_pair_records` +
   `.build_group_records` ora portano `treated_sample_ids` +
   `control_sample_ids` (GSM list a livello record, era solo conteggio).
   Group-mode `control_sample_ids = character(0)` (no control side
   semantico).
2. Due nuovi helper in `R/stage3-metadata.R`:
   - `.build_biosample_lookup(archs4_metadata)` → named char vec
     `geo_accession → SAMN`. NULL su input incompatibile.
   - `.build_donor_lookup(stage1_master)` → named char vec
     `geo_accession → donor_id`. Accetta sia list che environment
     (post Phase 1.5 di `build_stage3_clusters`).
3. `.enrich_cluster_metadata()` esteso con parametri `biosample_lookup`
   + `donor_lookup`. Policy NA-non-collassante (sample senza SAMN/donor
   = identita' biologica distinta).
4. Nuova colonna `n_distinct_biosamples` in `clusters.rds`. Schema
   `empty_clusters` aggiornato.
5. **Fix paper-grade sotto-stima `n_distinct_donors`**: pre-E0 leggeva
   solo `stage1_facts$donor$donor_id` del primo sample del record
   (sotto-stima sistematica per cluster con replicate gruppi multi-donor).
   Post-E0 itera tutti i `treated_sample_ids` + `control_sample_ids`,
   lookup via `donor_lookup`. Fallback legacy preservato quando
   `donor_lookup = NULL` (retrocompat 2 test pre-E0 in
   `test-stage3-metadata.R`).
6. `R/stage3-config.R::stage3_default_config()$schema_versions` aggiunge
   `dedupe_strategy = "biosample_samn_unique"` (loggato una volta in
   `run_metadata.json`, non colonna ridondante per-cluster).
7. `R/stage3-archs4-meta.R::load_archs4_metadata` esteso per leggere
   `meta/samples/relation` da H5 e applicare `parse_biosample_id()`
   (gia' definita in C3). Tibble output ora ha colonna `biosample_id`.
   Cache key bumpata con `schema_version = "v2_biosample"` per
   invalidare automaticamente le cache pre-E0. Fallback graceful
   (tryCatch) se H5 non ha il dataset `relation` -> tutti NA.

**Out-of-scope esplicito (rimandato a E0b)**: collasso same-SAMN
cross-GSE in pooling Stadio 4. A7 ha identificato 425 GSM cross-GSE
duplicati veri (0.048%). E0 espone il numero, NON collassa nel pool.

**Test result E0**: 24 nuovi `test_that` in
`tests/testthat/test-stage3-e0-biosample-dedupe.R`. Test suite globale
post-E0 (escluso perf-budget): **1931 PASS / 0 FAIL / 3 SKIP** (vs
pre-E0 1883 PASS / 0 FAIL / 4 SKIP). +48 expect_*, 0 regressioni.

**Decisione architetturale registrata**: nuovo task **E0b** aperto per
collasso cross-GSE same-SAMN in pooling Stadio 4. 3 opzioni discusse
con utente:
- (a) Drop duplicate: tenere solo il primo GSM per SAMN nel pool.
- (b) Average counts: mediare counts cross-GSE per stesso SAMN.
- (c) Lasciare entrambi: dichiarare 0.048% sotto-noise in ADR-0019
  consequence "neutral".

Gate utente per scelta (a) / (b) / (c) prima del codice.

#### ✅ E0b — Collasso same-SAMN cross-GSE in pooling Stadio 4 (DONE sessione 7)

**Decisione utente 2026-05-27 (sessione 7, su evidence A7b)**: ✅
opzione **(a) drop deterministico** con criterio **max `lib_size`**
(tie-break GSM alfabetico). Evidence completa:
`analysis/audit/A7b-samn-duplicate-analysis.md`.

**Implementazione completata sessione 7** — 7 commit bite-sized TDD:
- `13d5342` T1: helper `.dedupe_gsm_by_samn` + `.lookup_chr/_num` (38 expect)
- `8fc6491` T2: integrazione MEGA pure `.build_mega_metadata_safe` (14 expect)
- `5f600e1` T3: integrazione MEGA-AUG `.assemble_mega_aug_metadata_bidir` +
  `exclude_samn` cross pair-baseline (20 expect)
- `b386144` T4: `.build_samn_dedupe_lookups` + propagazione down via
  `.pool_all_clusters` (18 expect)
- `88d916c` T5: `schema_versions$samn_dedupe_strategy =
  "max_libsize_alphabetic_tiebreak"` (2 expect)
- `6ed729d` T6: smoke integration end-to-end MEGA pure (8 expect)
- `9fee42c` T6b: fix paper-grade self-review — propaga
  `assembled$samn_dedupe_log` MEGA-AUG in `pooling_warnings`
  dell'orchestrator (era persa silenziosamente, asimmetria con MEGA pure)
  (5 expect)

Test suite E0b perimetro: **49 test_that, 202 expect_* PASS / 0 FAIL**.
Master invariato. Codex CLI tentato per review esterna ma auth ChatGPT
non supporta i modelli gpt-5.x-codex con quel tier -> self-review
paper-grade Opus 4.7 ha scoperto il finding T6b.

Razionale paper-grade (sintesi A7b):
- I 425 GSM cross-GSE NON sono replicate tecnici puri: Pearson(log1p)
  cor cross-GSE 0.41-0.75 anche con metadata identico, mediana 0.75
  (vs ~0.99 atteso per replicate tecnici); mediana `lib_size_ratio`
  cross-GSE 2.23×, max 17×.
- → opzione (b) average counts scientificamente indifendibile (mediare
  dati non-omologhi contraddice D8 covariate batch dello stesso ADR-0019).
- → opzione (c) sotto-noise scartata: upper bound 128 group cluster
  (32.4% dei 176 SAMN duplicati) impattati direttamente. NON e' rumore
  diluito su 0.048%.
- Criterio max `lib_size` preserva il GSM piu' profondo (difendibile nel
  paper: "kept the deepest sequenced GSM per SAMN cross-study").
  `lib_size_a3` gia' precalcolato in `analysis/audit/A3-libsize-scprob-bacino.tsv`.

**Cosa facciamo.**
- Nuovo helper `.dedupe_gsm_by_samn(sample_ids, biosample_lookup,
  libsize_lookup)` che: (1) raggruppa GSM per SAMN, (2) per SAMN con
  N>=2 GSM, tiene il GSM con `lib_size` massimo (tie-break alfabetico),
  (3) restituisce vector filtrato + lista GSM droppati per logging.
- Applicato nei record builders Stadio 3 (`.build_pair_records`,
  `.build_group_records`) prima dell'emissione di `treated_sample_ids` /
  `control_sample_ids`.
- Applicato in `R/stage4-mega-aug.R::build_baseline_rows` su `sids`
  augmentation pool (defense-in-depth contro MEGA-AUG cross-cluster
  duplicates, non catturato da heuristic A7b).
- Verifica se serve in `R/stage4-mega-safe.R::.build_mega_metadata_safe`
  (TBD durante implementazione: dipende da come accumula sample MEGA).
- Logging: nuovo reason code `cross_gse_samn_dedupe` in `qc_drops_sample`
  + counter in `qc_report`.
- Cache key Stage 3 bumpata (`v2_biosample` → `v3_samn_dedupe`) per
  invalidare automaticamente clusters pre-E0b.

**Decisione che dipende da E0b.** Piano implementazione dettagliato +
TDD bite-sized prima del codice. Gate utente sul piano prima di toccare
codice.

#### ✅ E1 — Gene axis a Ensembl ID (DONE sessione 7)

**Decisione utente 2026-05-27 (sessione 7)**: ✅ opzione **A breaking
pulito** — schema cluster_pooled.parquet + per_study_de.parquet: colonna
`gene` (HGNC make.unique pre-E1) rinominata `gene_id` (Ensembl, univoco
per costruzione: 67186 ID distinti in H5 v2.5 con 0 NA confermato) +
nuova colonna `gene_symbol` (HGNC, possibili duplicati cross-paralogi +
NA-aware). Layer B aggiornato per usare gene_symbol come label
leggibile nei plot (forest, heatmap, volcano, top-gene table, summary
card, GO via keyType='ENSEMBL'+readable=TRUE).

**Implementazione completata sessione 7** — 6 commit bite-sized TDD:
- `d9bcc00` T1: helper puro `.parse_gene_axis(ensembl, symbol)` in
  `R/stage4-gene-axis.R` con validazione early-fail (NA, "", duplicati);
  18 expect_*.
- `93b8b3e` T2: `.h5_gene_axis` refactor (Ensembl + symbol via
  `.parse_gene_axis`); `.attach_gene_annotation(counts, gene_axis)`
  setta rownames + attr('gene_symbol') named (lookup post-filterByExpr);
  `.fetch_counts_from_h5` rimosso `make.unique()` legacy. Cache key memo
  bumpata `genes::v2_ensembl::`. 10 expect_*.
- `13d88a1` T3: DE functions output schema `gene_id` + `gene_symbol`
  (`.run_limma_voom_de`, `.run_dream_mega`, `.empty_per_study_de`,
  `.empty_pooled_rem`, `.pool_rem_cluster`); defensive make.unique
  rimosso da .run_dream_mega + sostituito con guardia stop() esplicita.
  Test fixture rem-pooling + replication aggiornati. 10 expect_*.
- `3e486ec` T4: orchestrator riattacca attr('gene_symbol') dopo cbind
  cross-study (cbind + matrix subscripting perdono attr custom). Fix
  catturato durante self-review T4.
- `5ba0786` T5: Layer B compatibility (7 plot file + helper fixture +
  3 test): gene_id come chiave operativa, gene_symbol come label
  leggibile con fallback gene_id se symbol NA. GO enrichment switch
  keyType 'SYMBOL' -> 'ENSEMBL' + readable=TRUE.
- `934d156` T6: cache key disk `.cache_key_for_fetch` payload bumpato
  con prefisso 'v2_ensembl::' (invalida cache disk pre-E1
  automaticamente); schema_versions\$stage4_algorithm bumpato
  'v1' -> 'v2_ensembl_gene_axis'.

Test perimetro E1 + Layer B post-T6: **669 expect_*, 0 fail** su tutti
i file stage4 + layer-b (38 file). Zero regressioni. Self-review
paper-grade Opus 4.7 ha confermato l'integrita' algoritmica; nessun
finding bloccante. Codex CLI non utilizzabile per review esterna (auth
ChatGPT non supporta i modelli gpt-5.x-codex con quel tier, gia'
documentato in E0b).

**Effetto su ADR-0016 Decision 2** (sub-finding dream silent fallback):
risolto alla fonte. La patch make.unique() era un workaround per
simboli HGNC duplicati; ora Ensembl come axis rende il problema
inesistente per definizione (67186 unici, 0 NA). Defensive make.unique
sostituito da guardia stop() per qualunque fetch_fn alternativo che
producesse rownames duplicati.

#### ✅ E2 — Filtro `biotype == protein_coding` (DONE sessione 7 — 2026-05-28)

**Decisione utente 2026-05-28**: ✅ implementazione opzione standard
RED ALERT (default `gene_biotype_filter = "protein_coding"`, NULL
disabilita, vector multi-valore = union biotype). Riduce ~67k geni →
~23k (34%) - target ADR-0019 D7. Filter applicato alla SORGENTE
(`.fetch_counts_from_h5`) pre-cache: DE downstream + Layer B operano
su counts pre-filtrati senza ulteriore lavoro.

**Implementazione completata sessione 7** — 5 commit bite-sized TDD:
- `605ceb6` T1: `.parse_gene_axis` esteso a 3-comp (ensembl + symbol +
  biotype) con retrocompat default NULL biotype → NA. `.attach_gene_annotation`
  setta `attr(counts, 'gene_biotype')` named se presente in axis.
  7 nuovi test_that, 11 expect_*.
- `5f39215` T2: `.h5_gene_axis` legge anche `meta/genes/biotype` (cache
  memo key bumpata `genes::v3_with_biotype::`). `.fetch_counts_from_h5`
  parametro `gene_biotype_filter` default 'protein_coding'; helper puro
  `.apply_biotype_filter` (NA-strict, errore esplicito se 0 geni
  match). 5 nuovi test_that, 11 expect_*.
- `b7deb8e` T3: `.cache_key_for_fetch` payload include segmento
  `biotype::<sort_unique(filter)>::`; `.fetch_counts_cached` propaga
  filter. Permutazioni vector filter normalizzate (deterministic key).
  3 nuovi test_that, 6 expect_*.
- `3536dd4` T4: `build_stage4_results` parametro
  `gene_biotype_filter = 'protein_coding'`; closure default Step 4
  cattura filter e lo propaga a `.fetch_counts_cached`. 4 test_that
  con `with_mocked_bindings`, 6 expect_*.
- `84d0ccc` T5: `schema_versions$gene_biotype_filter_strategy =
  "v1_protein_coding_default"` + `run_metadata$gene_biotype_filter` =
  valore effettivo passato. `write_stage4_to_dir` lo include nel JSON
  pretty di `run_metadata.json` per tracciabilita' paper-grade.
  2 nuovi test_that, 3 expect_*.

Test perimetro E2: **18 test_that, 37 expect_* PASS** sui file E2 +
zero regressioni nei 705 expect_* del perimetro stage4+layer-b totale.

**Caveat documentato**: `fetch_fn` ESTERNO (override esplicito dal
chiamante) NON riceve il `gene_biotype_filter` automaticamente. Il
filter e' applicato SOLO al fetch_fn default cacheato. Se l'utente
passa un fetch_fn esterno, deve filtrare lato suo. Default
'protein_coding' attivo se nessun override.

Self-review paper-grade Opus 4.7: nessun finding bloccante. **Codex CLI
finalmente utilizzabile (sessione 7 fine pomeriggio 2026-05-28, auth
restored)** -> review eseguita e 5 finding paper-grade indirizzati in
**T7a + T7b** (commit `0f1dd59` + `054fb88`):

- **Fix 5** (T7a): `.h5_gene_axis` errore esplicito su H5 senza
  `meta/genes/biotype` (ARCHS4 legacy v1). Suggerisce
  `gene_biotype_filter = NULL` per H5 incompatibili. Test mock H5 in
  tempfile.
- **Fix 4** (T7a): `.apply_biotype_filter` warning con count quando
  gene_axis ha N>0 NA biotype + filter attivo. ARCHS4 v2.5 ha 0 NA
  (warning non scatta), forward-compat ARCHS4 future + axis alternativi.
- **Fix 3** (T7a): errori distinti per causa nel `.apply_biotype_filter`:
  axis senza gene_biotype | filter character(0) | filter typo
  (mostra biotypes presenti per debugging).
- **Fix 1** (T7a): `build_stage4_results` warning runtime quando
  fetch_fn esterno + filter non-NULL. Forza il chiamante a essere
  esplicito (no piu' "silent half-applied filter" che corromperebbe
  run_metadata).
- **Fix 2** (T7b): `run_metadata$gene_axis_summary` registra n_total,
  n_post_filter, n_biotype_na droppati, biotypes_kept. Trasparenza
  paper-grade: il revisore vede l'EFFETTO osservato del filter, non
  solo il valore richiesto. NULL se fetch_fn esterno (non
  introspettabile).

Test perimetro post-T7a+T7b: **744 expect_*, 0 fail** (era 705 pre-fix).
Convenzione utente paper-grade applicata: "pubblichiamo l'idea delle
meta-analisi, non la bellezza del codice — ma il codice deve essere
robusto".

#### ✅ E3 — Covariate batch `instrument_model` + `aligner_class` nel design (DONE sessione 7 — 2026-05-28)

**Decisione utente 2026-05-28**: ✅ implementazione opzione standard
ADR-0019 D8 (covariate batch nel design DE: `instrument_model` +
`aligner_class` di default; vector custom override; NULL disabilita).
Edge case `single-level` / `missing` / `NA partial` gestiti via helper
`.augment_de_design` (drop covariata + log) con livello `'unknown'`
per NA partial (preserva sample). Post-Codex review robusta:
**Fix C1 pre-fit rank check** (drop covariate se design singolare per
confound col treatment) + **Fix C2 helper join** con warning dedicato
per sample del cluster non in `metadata_extra`.

**Implementazione completata sessione 7** — 7 commit bite-sized TDD:
- `225b015` T1: helper `.augment_de_design(metadata, covariates,
  cluster_id)` con 4 edge case (multi-level kept | single-level drop |
  missing skip | NA partial -> 'unknown'). 26 expect_*.
- `e065db8` T2: `.run_limma_voom_de` integra `metadata_extra` +
  `covariates`; design `~ treatment + <terms>` via
  `stats::model.matrix`. 10 expect_*.
- `369b1b8` T3: `.run_dream_mega` integra `covariates`; formula
  `~ treatment + <terms> + (1|study)` dinamica. 4 expect_*.
- `4e9ee68` T4: `build_stage4_results` parametro `de_covariates`
  default `c("instrument_model", "aligner_class")` + orchestrator
  propaga ai 3 callsite DE (per-studio + mega + mega-aug). 5 expect_*.
- `3fed578` T5: `schema_versions$de_covariates_strategy` +
  `run_metadata$de_covariates_requested`. 4 expect_*.
- `02b848a` **T6a post-Codex Fix C1**: pre-fit rank check
  (`qr(model.matrix)$rank < ncol`) in `.augment_de_design`. Se design
  rank-deficient (covariata confounded col treatment), drop tutte le
  covariate kept + log `non_estimable_confounded_with_treatment`.
  Approccio conservativo: meglio fit treatment-only che modello
  singolare con coef NA silenziosi. 6 expect_*.
- `ff037ee` **T6b post-Codex Fix C2**: helper
  `.join_covariates_to_metadata` con warning DEDICATO per sample del
  cluster non in `metadata_extra` (`join_incomplete`), distinto dal
  warning `NA biologico` di `.augment_de_design`. Integrato in 3
  callsite DE. 11 expect_*.

Test perimetro E3: **66 expect_* test_that**, **0 fail** sui file
E3 + zero regressioni nei 810 expect_* del perimetro stage4+layer-b
totale.

Codex review eseguita post-T5 (auth ChatGPT restored 2026-05-28): 2
finding bloccanti paper-grade (C1+C2) indirizzati prima del closing.

**Effetto su rebuild FASE F5** (Stage 4 fullrun): le coefficient
`treatmenttreated` nel cluster_pooled.parquet saranno calcolati con
covariate batch attive cross-study (riduzione confondimento
instrument/aligner). Per-studio limma le covariate sono spesso
single-level e auto-droppate (warning logged in qc_report).

#### ✅ E4 — Integration test cascade E1-E3 (DONE sessione 7, 2026-05-28)

Commit `af8a80c`. Test integration end-to-end (`test-stage4-e4-cascade.R`)
con mock H5 sintetico (50% protein_coding + 30% lncRNA + 20% miRNA;
4 studi x 6 sample) che verifica:
- Ensembl axis univoco (E1)
- biotype filter protein_coding (E2)
- covariate batch instrument_model (E3)
- pre-fit rank check Fix C1 confound col treatment

5 test_that, 23 expect_* PASS. Edge case: H5 senza biotype, covariata
confunded, axis NA gestiti coerentemente.

#### ✅ E5 — Stage4 dashboard/Layer B compatibility (DONE sessione 7, 2026-05-28)

Commit pending. Verifica end-to-end che Layer B produce bundle
paper-grade con il nuovo schema E1-E3:

- `R/layer-b-build.R`: `schema_versions$stage4_algorithm` bumpato a
  `v2_ensembl_gene_axis` (era 'v1' stale). Tracciato in
  `run_metadata.json` post-write.
- `tests/testthat/test-stage4-e5-layer-b-schema.R`: 2 test_that,
  8 expect_*. Verifica schema_versions propagato + top_genes.csv
  contiene `gene_id` + `gene_symbol` (no 'gene' legacy).
- `analysis/audit/E5-smoke-plots.R` + output dir: script standalone
  che materializza i plot di 2 cluster sintetici (cl_mega_1 +
  cl_aug_1) per giudizio visuale. Output volcano/forest/heatmap/MA/
  top_genes/summary_card committato in `analysis/audit/E5-smoke-plots/`.

Test perimetro post-E4+E5: **840 expect_*, 0 fail** stage4+layer-b
totale.

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

#### ✅ F1 — ETL re-run (nuovo JSONL filtrato + esteso) — DONE sessione 8 (2026-05-28)

**Cosa abbiamo fatto.** Riscritto l'ETL come `analysis/p4-fase-f-etl-build.R`
(NON riusato lo script β, scoperto stale pre-FASE-C: 5 problemi — H2
assente, H2-su-series-raw, molecule droppato, D4 non applicato, H5_PATH
errato. Vedi piano `docs/superpowers/plans/2026-05-28-p5-fase-f1-etl-rebuild-plan.md`).

**Esito (GATE PASS).** Bacino produzione **508.037 sample** in
`analysis/input/archs4-human-stage1-input-v2.jsonl` (gitignored). Set
equality vs oracle audit A3 (508.038): `extra=0`, `missing={GSM3612196}`
(= drop pulito H2 opzione (i): GSE126753 78.6% murino, residuo H2 di β
rimosso). molecule_ch1 preservato (20/20 non-NA random). Provenance
`analysis/p4-output/p4-fase-f-source.json` (sha256 H5 verificato).
Decomposizione drop + riconciliazione in ADR-0019 §Decision Outcome esito
produzione F1 + commit F1.

**Sub-decisioni utente sessione 8.** A1 (H2 post-resolver, non dentro
`is_sample_classifiable`) + (i) drop pulito GSM3612196. Commit:
`P5 audit RED_ALERT F1: ETL re-run Stage 0 v2 input stage1` (+ T1+T2
helper TDD `.flag_mouse_mislabeled_h2` + `.build_libsize_vec`).

**Nota downstream (tracciata, NON in scope F1).** `build_archs4_metadata_v2`
(C3, usato da F5 Stadio 4) non fa resolver né H2 → il suo RDS include i
sample H2 sopravvissuti a D1-D4. Innocuo a F5 (lookup solo su GSM nei
cluster, post-H2). Da risolvere/documentare a F5.

#### ✅ F2 — Stadio 1 fullrun DGX (F2-smoke ✅ + fix ✅ + fullrun ✅ + rescue 100% ✅, sessione 10)

**Cosa facciamo.** Submit del fullrun Stadio 1 sul nuovo input JSONL.

**Perché serve.** Re-classifica tutti i sample con il nuovo prompt
(che include molecule_ch1 come hint).

**Come.** Stessa procedura del fullrun precedente: chunked
orchestrator + cron tick. Sample meno (~30% drop per single-cell) →
fullrun più breve in proporzione.

**✅ F2-smoke + root-cause + fix (2026-05-28/29, sessione 9 + autonomo).**
Il gate F2-smoke (100 sample) ha rilevato accuracy mini-gold 92.93% < soglia
93%. Indagine systematic-debugging (3 run DGX a variabile singola): causa =
**fragilità del prompt Stadio 1** — D1b `molecule_hint` + D4 `organism_hint`
destabilizzano `duration.is_zero_timepoint` (campo non correlato), che a valle
fa scattare la REGOLA 2 di Stadio 2 (time-zero=control). **NON** è il prompt
Stadio 2 (controprova IT identica) né drift infra (β-prompt oggi recupera 98%).

Fix: **guard deterministico** `R/stage1-normalize.R` (`is_zero_timepoint=TRUE`
solo con evidenza t=0; TDD 38 expect_*), agganciato nel build input Stadio 2.
Mini-gold 92.93% → **97.00%** senza toccare il prompt (molecule_hint intatto).
Commit `301bdc8`, `bc40793`, `03abb8b`.

**Benchmark design-aware scalato** (gold LLM-assisted 756 sample / 72 studi
reali del bacino v2, `design_role_v3`, calibrato 88.2% vs gold umano autore):
binary accuracy **94.14%** (full, conservativo) / **96.02%** (raffinato, −2
studi mal posti). Dei 68 disaccordi: 24 multi-asse difendibile + 26 coverage
gap (3.5%) + 15 gold mal posto + solo 5 plausibili errori pipeline. Dettaglio:
`docs/findings/2026-05-28-f2-stage1-prompt-fragility.md`. Gold:
`analysis/p4-output/f2-eval-gold.csv`.

**Gate pre-fullrun confermato PASS** (schema 100%, accuracy sopra soglia,
distribuzione design_kind sana).

**✅ F2-fullrun + rescue COMPLETO (sessione 10, 2026-05-29).** Fullrun Stadio 1
v2 sul bacino di produzione (508.037 sample), config invariata, prompt v2 (guard
`is_zero_timepoint` a valle). 51 chunk da 10k + 25 outlier (nchar>3500,
max_model_len=32768), wall ~11h40m, throughput ~13.8 min/chunk, 0 HALT.
Validità LLM-only post-fullrun **99.712%** (1.464 fail). **Rescue cascade β**
(H1 rep_pen=1.2 → 1.317; H1.2 rep_pen=1.3 → 124; H1.3 rep_pen=1.4 → 21; H1.4
manual 2) → master rescued **508.037 / 508.037 = 100.0000%**.

Diagnosi paper-grade (audit before patch): il fail rate 3x vs β NON è infra
(worker bilanciati) né lunghezza, ma **fragilità del prompt v2** — 81.6% dei
fail sono record che classificavano col prompt β e ora vanno in loop (overlap
GSM). 22/23 residui finali = un solo studio (GSE157354 chimera human-mouse).
Recuperabile, accuratezza già validata 94-96%. Dettaglio:
`docs/findings/2026-05-28-f2-stage1-prompt-fragility.md` §5.

Deliverable: `analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl`
(508.037 record, 100% validi, gitignored). Scaffolding/rescue script committati
(`bda18f8`..`6ecd7b1`). Master invariato.

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
- 2026-05-26/27 sessione 4: **FASE C completata (5/5)**.
  - ✅ C1 (`5e45671`) `read_archs4_metadata` 14 campi H5.
  - ✅ Fix regex audit underscore-aware (`3bca92c`, ultrathink): bug
    paper-grade title-bulk rescue + pattern Gruppo S (perl `_` word-char
    → no boundary). Rerun A2 + update A3 lib_size + A3c FPR curve.
    Drop Stage 0 v2 ricalcolato: **371.129 / 879.167 = 42.21%** (vs
    42.28% pre-fix). Bacino finale: **508.038 sample** (+578, corretto
    sessione 8 pre-flight F: era scritto a mano "507.838 / +378" in
    sessione 4, ricalcolato empiricamente). Pattern
    K (kit) invariati (chiusura strict avrebbe creato 3.568 FN su
    CelSeq2, FluidigmTM, FluidigmC1 — scartata).
  - ✅ C2 (`cb650e6`) `is_sample_classifiable` v2 firma B3 (10 args,
    return list(keep, reason)). 7 reason codes esposti per skip log
    paper-grade. Chiamante `archs4_to_stage1_jsonl` aggiornato.
  - ✅ C3 (`4aebe80`) `build_archs4_metadata_v2` + `parse_aligner_class`
    + `parse_biosample_id`. RDS schema 11 colonne (geo, series,
    library_source, molecule_ch1, instrument_model, data_processing,
    aligner_class factor, relation, biosample_id SAMN, lib_size,
    singlecellprobability). Deviazione spec B2 documentata: regex
    aligner senza chiusura `\b` (perl word-char block su STAR_2.7.10a /
    STARSOLO).
  - ✅ C4 (`6963198`) `molecule_ch1` aggiunto al JSONL Stage 1 input
    (D5 ADR-0019). Prompt LLM Stadio 1 NON toccato in C4 (gate D1a).
  - ✅ C5 (`8ed4b2c`) test e2e cascade Stage 0 v2 in
    `tests/testthat/test-stage0-v2-e2e.R` (5 test_that + 17 expect_*).
  Branch ahead di master di 12 commit. Test suite globale Stage 0 v2:
  194 PASS / 0 FAIL / 1 SKIP. Prossimo step: FASE D1a gate utente
  prompt LLM Stadio 1.
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
  ✅ **A7 chiusa**: SAMN coverage 99.98%, 425 GSM (0.048%) duplicati
  cross-GSE veri. donor_id LLM scartato per cross-studio (9.16%
  donor_id unique appaiono in >1 series con nomi generici tipo "patient 1"
  = falsi duplicati). Decisione: **`relation` BioSample SAMN come segnale
  primario unico, no fallback donor_id**. Sintesi `analysis/audit/A7-synthesis-biosample-dedupe.md`.
  **FASE A completata (7/7)**.
  ✅ **B1 chiusa**: ADR-0019 "ARCHS4 metadata exploitation v2" scritto
  in `docs/decisions/0019-archs4-metadata-exploitation-v2.md` (status
  Proposed, 307 righe). Raccoglie 9 sub-decisioni D1-D9 derivate
  dall'audit FASE A (4 filtri Stage 0 + LLM input + gene axis Ensembl +
  biotype filter + covariate batch + dedupe SAMN) + macro-decisione
  rebuild data-driven. Counter-fattuali documentati. Validation
  strategy + future work LLM quality check post-aggregazione registrati.
  ✅ **B2 + B3 chiuse**: mini-spec parsing scritte in
  `docs/superpowers/specs/2026-05-26-B2-parsing-data-processing.md`
  (aligner_class regex prioritizzate STAR>HISAT>Salmon>kallisto>RSEM>BWA>Bowtie>TopHat
  + fallback other/unknown + test fixture) e
  `docs/superpowers/specs/2026-05-26-B3-parsing-extract-protocol-sc.md`
  (`is_single_cell_protocol(extract, title, src)` con K+S pattern +
  title-bulk rescue + test fixture positive/negative + integrazione FASE C2).
  **FASE B completata (3/3). FASE A+B chiuse (10/10)**.
  Prossimo step in nuova sessione: FASE C (codice pre-LLM).

- 2026-05-27 sessione 5: **FASE D completata (4/4)** + scope-extension
  D3+D4 chiusi paper-grade. 4 commit incrementali:
  - ✅ D1a (file traccia `analysis/audit/D1a-prompt-stage1-current.txt`,
    gate utente approvato strada cauta + naming molecule_hint + valore
    verbatim).
  - ✅ D1b (`de440ce`) molecule_hint nel prompt Stadio 1 (R +
    inst/dgx/python/prompts.py + 9 test_that, ground rule #9 in system
    prompt: "molecule_hint indicates the RNA fraction profiled ... not a
    perturbation").
  - ✅ D2 (`40a75d8`) tests end-to-end: 2 cascade JSONL stream_in ->
    classify_sample_row + 1 bundle DGX verify prompt.txt contiene la
    ground rule 9.
  - ✅ D3 (`0e20495`) traduzione prompt Stadio 2 IT -> EN. Modifica al
    solo `R/llm-stage2.R`: system prompt + glosse PRIMARY_ROLES +
    glosse CONTROL_TYPES. Enum values, schema fields, termini
    scientifici verbatim. File traccia
    `analysis/audit/D3-prompt-stage2-translation.txt` (IT verbatim + EN
    proposed side-by-side).
  - ✅ D4 (`0409810`) fix bug latente organism_hint discovered durante
    D1b: Python DGX cercava chiave inesistente, mai emessa nel beta
    fullrun. Fix simmetrico al pattern D1b (Python legge `organism`
    verbatim ARCHS4, R legge `row$organism`). 2 test_that R + 4 sanity
    Python PASS.
  Branch `p5-llm-anchor-classification-audit` ahead di master di **17
  commit** (last `0409810`). Master invariato. Test suite globale
  (escluso perf-budget): **92 file, 614 test_that, 1883 expect_* PASS,
  0 FAIL, 4 SKIP**. Prossimo step nuova sessione: **FASE E (codice
  post-LLM Stadio 3 + Stadio 4)** — task E0-E5.

- 2026-05-27 sessione 6: **E0 chiusa paper-grade** + decisione design
  E0b registrata in attesa scelta utente. 1 commit incrementale + 1
  commit closing (questo doc + CLAUDE.md):
  - ✅ E0 (`cc77faf`) dedupe BioSample SAMN sample-level in Stadio 3
    materializza ADR-0019 D9 in `clusters.rds`. Architettura additive:
    record builders pair/group portano `treated_sample_ids` +
    `control_sample_ids` (era solo conteggio); 2 nuovi helper
    `.build_biosample_lookup` + `.build_donor_lookup` pre-built una
    volta in `.summarize_clusters` (lookup O(1) per cluster);
    `.enrich_cluster_metadata` esteso con i 2 lookup; nuova colonna
    `n_distinct_biosamples` nello schema cluster; `schema_versions.dedupe_strategy
    = "biosample_samn_unique"` loggato in `run_metadata.json` (non
    colonna ridondante); `load_archs4_metadata` esteso per leggere
    `meta/samples/relation` con cache key bumpata `v2_biosample`.
    **Fix paper-grade collaterale**: `n_distinct_donors` pre-E0 leggeva
    solo donor del primo sample per record (sotto-stima sistematica),
    post-E0 itera tutti i GSM via `donor_lookup`. Fallback legacy
    preservato per retrocompat 2 test pre-E0. Policy NA-non-collassante
    per sample senza SAMN/donor.
  - ⬜ E0b APERTO post-E0: collasso same-SAMN cross-GSE in pooling
    Stadio 4 (425 GSM cross-GSE veri dall'A7, 0.048%). 3 opzioni
    discusse con utente (drop / average counts / sotto-noise). Gate
    utente per scelta in next session.
  Branch ahead di master di **37 commit** (correzione: il claim "17"
  nei banner sessioni 4-5 era miscount cumulato; valore reale verificato
  con `git rev-list --count master..HEAD`). Master invariato. Test suite
  globale (escluso perf-budget): **93 file, 638 test_that, 1931 expect_*
  PASS, 0 FAIL, 3 SKIP**
  (+24 test_that E0 + 1 file nuovo
  `tests/testthat/test-stage3-e0-biosample-dedupe.R`).
  Prossimo step nuova sessione: **decidere E0b + procedere con E1
  (gene axis Ensembl)**.

- 2026-05-28 sessione 7: ✅ **FASE E completata (E0b+E1+E2+E3+E4+E5)**.
  E0b SAMN dedupe cross-GSE drop max-libsize; E1 gene axis Ensembl
  (supera ADR-0016 Decision 2); E2 biotype protein_coding default; E3
  covariate batch instrument_model+aligner_class; E4 integration test
  cascade; E5 Layer B compatibility. Codex review C1+C2 (E3) + 5 finding
  (E2) indirizzati. Test stage4+layer-b: 840 expect_* PASS. Dettaglio nei
  §E sopra (tutti ✅ DONE). FASE A+B+C+D+E chiuse (26/19 task).

- 2026-05-28 sessione 8: ✅ **pre-flight (5/5) + FASE F1 chiusi**.
  - **Fix math error bacino**: 507.838 → 508.038 (oracle audit), errore
    aritmetico sessione 4, verificato empiricamente su A3 TSV. Propagato
    ADR-0019 + A3 + RED_ALERT (commit `4434c03`).
  - **Pre-flight 2**: smoke `is_sample_classifiable` 7/7 reali + 7/7
    coverage TDD (`0a3024c`). H5 v2.5 pre-filtrato → 3 reason code
    defensive non triggerabili da reali (coperti da fixture unit).
  - **F1 ETL re-run**: nuovo `analysis/p4-fase-f-etl-build.R` (β stale
    pre-FASE-C, 5 problemi). Bacino produzione **508.037** (`fe8121a`).
    Helper TDD `.flag_mouse_mislabeled_h2` + `.build_libsize_vec`
    (`5e8295b`). Doc closing `8bf9c5f`.
  - **Pre-flight 3**: `build_archs4_metadata_v2` full H5 GATE PASS,
    n_kept 509.033 (= F1 pre-H2), schema F5-compatibile (`8d3d441`).
  - **Pre-flight 4**: config DGX live OK (.sif v0.20.2, partition
    infinite, Mistral cached). Finding time default → fix (`1ea1e15`,
    `938992c`).
  - **Igiene**: DESCRIPTION 9020→9026, man/*.Rd ×42 rigenerati
    (`6f6a148`, `f1edbac`), cache stage4-counts purgata −5 GB.
  - **Pre-flight 5**: cache purge eseguita.
  Branch ahead master ~84 commit. Master invariato. F1 DONE; F2-F6 TODO.

- 2026-05-28/29 sessione 9 (+ lavoro autonomo notturno): ✅ **F2-smoke +
  root-cause + fix `is_zero_timepoint` + benchmark design-aware scalato**.
  - F2-smoke: accuracy mini-gold 92.93% < 93% → STOP. Indagine
    systematic-debugging (3 run DGX): causa = fragilità prompt Stadio 1
    (D1b/D4 destabilizzano `is_zero_timepoint` → REGOLA 2 stage2). NON
    stage2 prompt, NON drift infra. Guard deterministico `R/stage1-normalize.R`
    (TDD 38 expect_*) → 97.00%. Commit `301bdc8`/`bc40793`/`03abb8b`.
  - Benchmark scalato: gold LLM-assisted 756 sample / 72 studi (calibrato
    88.2% vs gold umano). Accuracy **94.14%** (full) / **96.02%** (raffinato).
    Solo 5/717 plausibili errori pipeline; resto = multi-asse + coverage gap.
  - Finding `docs/findings/2026-05-28-f2-stage1-prompt-fragility.md`.
  - Gate pre-F2-fullrun PASS. Master invariato.

- 2026-05-29 sessione 10: ✅ **F2-fullrun Stadio 1 v2 (508.037) + rescue
  cascade → 100%**.
  - Fullrun: 51 chunk da 10k + 25 outlier, config invariata, prompt v2 + guard.
    Wall ~11h40m, ~13.8 min/chunk, 0 HALT. Validità LLM-only 99.712% (1.464 fail).
  - Diagnosi (audit before patch): fail rate 3x vs β = **fragilità prompt v2**
    (81.6% fail nuovi via overlap GSM; 22/23 residui = GSE157354 chimera). NON
    infra, NON dati. Finding §5.
  - Rescue: H1(1.317)/H1.2(124)/H1.3(21)/manual(2) → **508.037/508.037 = 100%**.
  - Deliverable: `p4-fase-f2-stage1-master-predictions-rescued.jsonl` (gitignored).
    Commit `bda18f8`..`6ecd7b1` + closeout doc. Master invariato.

### Handoff next session (sessione 11 = F3 Stadio 2 fullrun)

- **Deliverable F2 pronto**: `analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl`
  (**508.037 record, 100% validi**, gitignored). Colonna `rescue_source` su
  1.464 record (1.462 LLM rep_pen-escalation + 2 manual GSE157354).
- **Prossimo step: F3 — Stadio 2 fullrun DGX**. Sotto-task previsti:
  1. **Build input Stadio 2 v2** da `analysis/p4-beta-stage2-build-input.R`
     (choke point pipeline): NB qui è agganciato il guard `is_zero_timepoint`
     (`R/stage1-normalize.R`) — verificare che usi il master v2 rescued, non il β.
     Output: nuovo `archs4-human-stage2-input-v2.jsonl` (chunked cs50).
  2. **Validate-before-fullrun** (§10): smoke Stadio 2 + eval mini-gold v5 (prompt
     Stadio 2 ora EN, D3) → gate utente PRIMA del fullrun.
  3. **F3-fullrun**: chunked orchestrator stage2 (riusa pattern β; attenzione
     tier XL + ADR-0009/0013 safe-mode/cs25 fallback se stall #39734). Rescue H3
     (cs50→cs25) se fail.
- **Riuso macchina F2**: scaffolding chunked v2 in `scripts/p4-fase-f2-stage1-chunked-tick.sh`
  + `analysis/p4-fase-f2-stage1-chunk-build.R` (adattare a stage2). Tick β stage2
  esiste? verificare; il fullrun β stage2 NON era chunked-cron ma job unico 4-worker.
- **DGX pronto**: container v0.20.2, partition dgx12cluster infinite, Mistral cached,
  SSH BatchMode OK. Cron F2 già rimosso.
- **Nota downstream F5**: `build_archs4_metadata_v2` non applica H2 → RDS include
  996 sample H2-survived-D1-D4, inerti (lookup solo cluster GSM post-H2). Decidere
  a F5 se restringere al GSM set F1 o documentare.
- Branch `p5-llm-anchor-classification-audit`, master invariato. No push.
- Quando RED ALERT (Stadio 0) chiude (post-F6+G): aprire
  `docs/RED_ALERT-stage1.md` per audit Stadio 1.
