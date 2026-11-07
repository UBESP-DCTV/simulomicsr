# FATTI grezzi su `simulomicsr` (misurati stanotte o letti dai finding; nessun verdetto)

Progetto: pipeline R. ARCHS4 (RNA-seq umano bulk, 508.037 campioni GEO) → Stadio 1: LLM locale
(Mistral-Small-3.2-24B, vLLM, temperatura 0, batch-invariant) legge i metadati di OGNI campione →
Stadio 2: LLM interpreta il disegno di ogni studio (gruppi di repliche, ruolo trattato/controllo,
confronti) → Stadio 3: regole deterministiche raggruppano i confronti di studi diversi con la stessa
chiave «entità ‖ verso ‖ tipo di controllo» (entità risolta via ChEBI/HGNC/MeSH/ChEMBL) → Stadio 4:
limma-voom per studio + meta-analisi random-effects per gene (metafor), gate ≥3 studi, ≥2 repliche
per braccio. Obiettivo dell'articolo assunto: «catena end-to-end LLM→meta-analisi con resa ed errore
misurati» (non «atlante delle perturbazioni»).

## Imbuto (deliverable A3 v16, 2026-08-19)
- 508.037 campioni → 24.393 studi → 18.746 studi con ≥1 confronto (86.212 confronti) → 323 gruppi
  candidati con ≥3 studi → **194 meta-analisi** (993 studi, 1.903 confronti). 122 candidati cadono
  perché dopo il gate «≥2 repliche per braccio» restano <3 studi (88 a k_eff=2, 27 a 1, 7 a 0).
- Soffitto misurato stanotte (Stadio 3 corrente, unione di tutti i cluster di una entità, ignorando
  tipo di controllo e verso): **455 entità con ≥3 studi distinti**, 194 con ≥5, 62 con ≥10.
  Deliverable/soffitto = 194/455 = 43%. Perdita 455→323 = frammentazione per tipo di controllo e
  chiave; 323→194 = bracci con una sola replica (dato, non pipeline).
- Tipi: 107 small_molecule, 42 disease_vs_normal, 15 citochine, 11 ambientali, 9 patogeni, 9 genetici,
  1 differenziamento (colonna `kind` nota per sbagliare il tipo).

## Qualità misurata
- Lettura di tutte le 194 (agenti Claude, 2026-08-20): 116 corrette / 62 difettose / 16 incerte.
  Test-retest in ambiente congelato (S3): kappa 0,78 [0,70; 0,86]; lettura umana del PI su 19:
  accordo 18/19, kappa 0,91.
- Confronti difettosi nel riferimento dopo S11: **193/1.903 (10,1%)**, in 82 gruppi e 115 studi.
  Il riferimento NON è un campione neutro: 64 vengono da allarmi di una regola che ne vede 81/193.
- Attribuzione dei 193 per origine (regex sulle categorie, stanotte):
  - 125 (65%) bracci non appaiati: tempo zero (48), tempo/durata, materiale, linea, donatore,
    genotipo, sesso, differenza tecnica, controllo condiviso → lettura del disegno (Stadi 1/2) o
    ingresso. 50 di questi 125 sono leggibili SOLO nei metadati GEO (non nelle etichette).
  - 45 (23%) seconda perturbazione persa (es. «Hypoxia + TGF-β1» poolato sotto TGF-β1): lo Stadio 1
    scrive quasi sempre UNA perturbazione per campione (15.024/15.559).
  - 15 (8%) entità/contrasto sbagliato (chiave Stadio 3: metabolita per il padre, omonimia, IL-1β
    sotto IL1A).
  - 8 (4%) indecidibili dall'etichetta.
- Ingresso del modello: Stadio 1 vede `title`, `source_name_ch1`, `characteristics_ch1` del
  campione (`R/etl-archs4-utils.R:8`). Stadio 2 vede i fatti dello Stadio 1 per condizione (non il
  testo grezzo). **I «metadati GEO» letti in S11 sono questi stessi tre campi** (script
  `21-metadati-geo.R`): quindi i 50 difetti «leggibili solo nei metadati» erano nel testo che il
  modello ha ricevuto, e non sono arrivati al confronto (Stadio 1 non li ha scritti, o Stadio 2 li ha
  persi nell'etichetta). L'H5 ha anche `extract_protocol_ch1`, `data_processing`, `instrument_model`,
  `library_selection` (non usati dal modello); non ha `overall_design` né `summary` della serie.
- Inversioni di braccio: 1 confermata (`GSE144269` in HCC, 105 geni significativi di cui 6.590 col
  segno raddrizzato) + 4 studi con un braccio sbagliato, su 194, con uno strumento che vede il 52%.
- Nomi: 61/194 `canonical_name` sono ID ChEBI sbagliati o NA (es. «D-cycloserine(1+)» = JQ1,
  «calcium atom», «hydron», «4-maleylacetoacetate» = DHT). L'etichetta di contrasto è giusta in quasi
  tutti; la colonna del nome no. Il modello scrive il nome giusto con l'ID sbagliato e il codice si
  fida dell'ID (S9). Da maggio a luglio 2026 il lavoro è stato soprattutto sui nomi (v5→v10).
- Dominanza: 116/194 (60%) dominate da un solo studio (>50% del peso); 67 (35%) valgono meno di
  2 studi efficaci. Solo **40/194** passano tutti i controlli (nessun difetto, nessuna dominanza);
  nelle 40 i geni significativi veri sono 3,0× quelli con studi non collegati, nelle 96 dominate 1,2×.
  La scelta delle 40 è DECADUTA in S11 (6 delle 40 hanno cambiato verdetto).
- Controllo biologico (bersagli fissati ad agosto dalla letteratura, rieseguito stanotte sul
  deliverable): **30/31 geni col segno atteso e significativi** (DHT, enzalutamide, TGF-β1,
  SARS-CoV-2, IFN-γ, LPS, IL-17A); DHT contro enzalutamide: 667/690 geni di segno opposto (96,7%),
  Spearman −0,944.
- Validazione esterna (S7, senza nullo per estrazioni casuali): 14/19 contro LINCS, 11/32 contro
  Tahoe-100M; non separa le 40 dalle 132. Tumori: 6/6 trovano il proprio progetto TCGA su 16.
- Gold Stadio 1: 756 campioni / 72 studi, accuratezza binaria trattato/controllo 94,1–96,0%;
  mini-gold 100 campioni; 21 modelli confrontati su 100 campioni in P3.5 (2026-04/05).
- Riproducibilità: Stadio 1+2 rifatti da zero (S14, 33 h su 8 H100): 211.484/211.484 record e
  8.565/8.566 studi identici al riferimento; 24.393 studi.

## Convergenza
- Verdetti sulle 194 cambiati per giro di misura: S9 (greche) 7/194; S11 (tempo zero + tecnica) 15/194,
  di cui 6 nelle 40. Classi di difetto nuove scoperte in S9, S10, S11: sinonimi/ID, aggancio tabelle
  dei nomi, tempo zero, differenze tecniche, studi doppi (13 gruppi).
- Tre dichiarazioni di «deliverable finale / publication-grade» ritrattate (lug 2026): riguardavano
  il livello dei nomi, poi sostituito dal record di gruppo «dal contrasto» (ADR-0025).
- Handout 2026-08-21: 13 voci → 17 (11 chiuse). Sessioni in programma prima dell'articolo: S12, S12b,
  S12c, S12d (regole e chiave), S13 (ri-calcolo), S14 (raggruppamento sui master nuovi), S15
  (rilettura), S16 (figure), S17 (Methods). Le stime di durata dell'handout (3-6 h) sono state
  superate in quasi tutte le sessioni.

## Costi noti (solo in avanti)
- Stadio 1+2 da zero: 33 h su 8 H100 (misurato). Stadio 3: 2,5 h (32 worker). Stadio 4: 75 min a pezzi.
- Riprodurre tutte le chiavi dello Stadio 3 per misurare una correzione: 35 min.
- Lettura di 194 meta-analisi con agenti: una sessione (60 agenti); lettura umana: 19 schede = 1 sessione.
- Esistono: ETL verificato, master S14 riproducibili, gold, 194 verdetti, test-retest, strumenti di audit
  (65k righe di script), 25k righe di pacchetto R con 28k di test (4.317 asserzioni, 0 fallimenti).
