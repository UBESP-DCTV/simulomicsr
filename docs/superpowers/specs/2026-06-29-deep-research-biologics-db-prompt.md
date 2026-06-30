# Deep research — quale database per nominare i BIOLOGICI (citochine + patogeni) (Stadio 3)

Prompt pronto da incollare in un tool di deep research. Contesto incluso così la ricerca
è mirata al nostro caso d'uso reale.

> Gemello del prompt farmaci (`2026-06-28-deep-research-small-molecule-db-prompt.md`), ma sui
> **biologici** (citochine proteiche + patogeni/esposizioni + PAMP/TLR-agonisti), che NON hanno
> un dizionario nome→ID come ChEBI/ChEMBL. Questo è il **Passo 0** dell'handout biologici
> (`2026-06-29-stage3-biologics-NEXT-SESSION-handout.md`).

---

## Prompt

> Sto costruendo una pipeline bioinformatica riproducibile (deliverable di un paper) che fa
> meta-analisi RNA-seq cross-studio. Per raggruppare studi confrontabili devo **dare un ID
> canonico** a menzioni testuali rumorose di **perturbazioni biologiche** estratte dai metadati
> GEO (campi `characteristics_ch1`/`source_name_ch1`/`title`). Ho già risolto le **small
> molecule / farmaci** con **ChEBI** (primario) + **ChEMBL 37** (dump SQLite offline, alias→ID),
> e le **malattie** con **MeSH**. Restano due famiglie biologiche per cui NON ho ancora un
> dizionario nome→ID, ed è questo l'oggetto della ricerca:
>
> 1. **Citochine e fattori immunitari proteici** — menzioni del tipo `"IFN-beta"`, `"interferon
>    beta"`, `"IFNB1"`, `"IL-6"`, `"interleukin 6"`, `"TNF-alpha"`, `"TNFa 600nm"`, `"TGF-beta"`,
>    `"IL4"`, `"GM-CSF"`. Stessa proteina scritta in decine di modi (simbolo gene, nome esteso,
>    alias greco α/β, sinonimi storici).
> 2. **Patogeni / esposizioni aggregate** — menzioni del tipo `"LPS"`, `"lipopolysaccharide"`,
>    `"intravenous LPS"`, `"SARS-CoV-2"`, `"influenza A"`, `"Mycobacterium tuberculosis"`,
>    `"poly(I:C)"`, `"R848"`, `"Resiquimod"`, `"PAM3CSK4"`. Mescolano **organismi** (virus,
>    batteri, ceppi) e **PAMP/adiuvanti/TLR-agonisti** che sono molecole ma con ruolo di
>    esposizione immunitaria.
>
> Voglio capire, con evidenza, **quale/quali database** dovrei usare per massimizzare la
> copertura nome→ID SENZA sacrificare la precisione, per OGNUNA delle due famiglie.
>
> Vincoli del mio caso d'uso (rispondi tenendoli presenti):
> - **Dizionario OFFLINE nome→ID**: la pipeline fa ~1 milione di lookup deterministici contro
>   hash-table locali; NON posso usare API live (lente, rate-limited, non riproducibili). Mi
>   serve un **dump scaricabile in bulk** (tabelle nome/sinonimi→ID), non un servizio.
> - **Riproducibilità paper**: devo poter **redistribuire il dizionario derivato** come
>   supplementary. La **licenza** conta (preferisco fonti aperte/redistribuibili; UniProt è
>   CC BY 4.0, NCBI Taxonomy è public-domain-like — verificalo).
> - **Precisione prima della copertura**: in meta-analisi unire due perturbazioni diverse è
>   peggio che lasciarne una "ignota". Mi interessa anche **come** fare matching robusto-ma-preciso
>   di nomi rumorosi (normalizzazione, gestione di α/β/greco, alias ambigui), evitando match su
>   parole-classe generiche (es. "cytokine", "interferon" da solo, "virus", "bacteria",
>   "infection") che causerebbero merge spuri.
> - **Granularità giusta per la canonicalizzazione**: per le citochine voglio l'identità della
>   **proteina/ligando specifico** (IFN-β ≠ IFN-γ ≠ IL-6). Per i patogeni voglio almeno il
>   **livello specie** (a volte ceppo): SARS-CoV-2 ≠ influenza ≠ M. tuberculosis.
>
> ### Parte A — Citochine / fattori immunitari proteici
> Confronta in modo fattuale (con numeri di copertura/dimensione dove disponibili, e con le
> fonti) almeno questi, e segnalane altri rilevanti che mi sfuggono:
> - **HGNC** (ho già il dump completo: gene symbol + alias + previous symbols). Le citochine sono
>   geni → posso normalizzare una citochina al suo **simbolo HGNC**? Copertura alias/greco?
> - **UniProt** (proteine + nomi/sinonimi alternativi; mapping a gene). Dump bulk
>   (`uniprot_sprot` / `idmapping`) e licenza per redistribuire una tabella nome→accession.
> - **Vocabolari immunologici dedicati**: **ImmPort cytokine registry**, **Gene Ontology** (termini
>   "cytokine activity"/"...receptor binding"), **Cell Ontology**, **Protein Ontology (PRO)**,
>   **InterPro/Pfam** (famiglie). Sono utili come dizionario nome→ID o solo come classificazione?
> - **Cytokine-specific resources**: esiste un registro canonico di nomi/sinonimi di citochine
>   (es. ImmPort, IUIS, "Cytokine nomenclature") redistribuibile e utile come alias-table?
> Per ciascuno: copertura nome→ID, qualità/quantità sinonimi (incl. greco α/β/γ e nomi storici),
> licenza redistribuibile, formato dump bulk, cross-reference verso HGNC/UniProt, stabilità ID.
>
> ### Parte B — Patogeni / esposizioni
> Confronta in modo fattuale:
> - **NCBI Taxonomy** (organismi: virus/batteri/ceppi → taxid). Dump bulk (`taxdump`), licenza,
>   copertura sinonimi/nomi comuni ("flu" → Influenza), granularità specie vs ceppo.
> - **Disease Ontology / MeSH / NCBI Taxonomy**: confine tra "il patogeno" (organismo) e "la
>   malattia infettiva" (es. tuberculosis MeSH vs M. tuberculosis taxid). Per la mia pipeline,
>   un'esposizione a patogeno è un'esposizione sperimentale, NON una malattia del soggetto — quale
>   asse uso?
> - **PAMP / adiuvanti / TLR-agonisti** (LPS, poly(I:C), R848/Resiquimod, PAM3CSK4, CpG ODN, Flagellin):
>   stanno meglio in **ChEBI** (hanno il ruolo, es. CHEBI per LPS/poly(I:C)) o in una fonte dedicata?
>   **Dove tracciamo il confine `small_molecule` ↔ `pathogen_exposure`** in modo deterministico e
>   difendibile? (es. una stoplist/whitelist di adiuvanti che vanno trattati come esposizione.)
>
> ### Output richiesto
> Per ciascun DB, in una **tabella comparativa**: copertura nome→ID, sinonimi (quantità/qualità,
> incluso greco e nomi storici), licenza redistribuzione, formato/dimensione dump bulk,
> cross-reference, stabilità ID, cadenza aggiornamento.
>
> Poi dammi:
> - una **raccomandazione separata per citochine e per patogeni**: sorgente primaria + eventuali
>   complementari, in che ordine interrogarle, con il ragionamento;
> - una **proposta operativa per il confine PAMP/adiuvanti** (quali restano small_molecule ChEBI e
>   quali vanno marcati come esposizione, con criterio deterministico);
> - **best practice e tool** noti per la **named-entity normalization di nomi di citochine e
>   patogeni da testo libero biomedico** verso ID canonici (gestione α/β/greco, alias storici,
>   sinonimi ambigui, gating di precisione; valuta se risorse come PubTator/GNormPlus/SPECIES-ORGANISMS
>   tagger/`taxonerd` sono rilevanti per un dizionario OFFLINE);
> - eventuali **insidie** (es. "interferon" generico, ambiguità simbolo gene vs proteina, ceppo vs
>   specie, lo stesso LPS come ChEBI vs come esposizione, sinonimi che collidono tra famiglie).
>
> Cita le fonti (pagine di documentazione/licenza/download dei DB, paper di benchmark di
> normalizzazione). Privilegia evidenza verificabile su affermazioni generiche.

---

## Note per quando arrivano i risultati
- Decisione attesa: scegliere la/le fonte/i per citochine (probabile **HGNC** che ho già, +/-
  **UniProt** per alias) e per patogeni (**NCBI Taxonomy**), + criterio per il confine PAMP/ChEBI.
- Collegare con il **gate di omogeneità v5** (cytokine_stim 61,2%, pathogen 33,0%) e stimare il
  guadagno con uno **smoke sul residuo reale** (come Task 7 farmaci): prendere i cytokine_stim/
  pathogen `UNK`/`STR` e vedere quanti si recuperano con la fonte scelta.
- Tenere distinto il **fix-tipo K3** (ri-tipizzare LPS/TNF/IL4 oggi etichettati `small_molecule`):
  è in parte ortogonale al dizionario (regola di correzione `kind`, analoga al K2 degron→genetic).
- Propedeutico a un eventuale **Stadio 3 v6**. Non blocca il v5 (già chiuso).
