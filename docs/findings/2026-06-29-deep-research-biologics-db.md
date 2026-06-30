# Deep research — database per nominare i BIOLOGICI (citochine + patogeni)

**Data:** 2026-06-29 · **Gemello** del report farmaci `2026-06-28-deep-research-small-molecule-db.md`.

## Provenienza (due fonti, merge)
- **Corpo del report = deep research da BROWSER (utente)** — la fonte ricca e completa (TL;DR, 7 Key
  Findings, tabelle comparative, raccomandazioni, insidie). È il documento di riferimento qui sotto.
- **Verifica indipendente = skill `deep-research` (Claude Code)** — il workflow è partito ma la fase di
  **sintesi è fallita per rate-limiting dell'API** (8 fetch + ~50 voti di verifica + `synthesize`
  falliti con "Server is temporarily limiting requests"). Ha comunque completato il **3-vote su 7
  claim**, che **confermano indipendentemente** i punti portanti del report browser (HGNC + NCBI
  Taxonomy). Vedi §"Verifica indipendente" in fondo.
- **Esito del merge:** le due fonti **concordano** sulla spina dorsale (HGNC per citochine, NCBI
  Taxonomy per patogeni, ChEBI per i PAMP). I punti che **nessuna** delle due ha potuto verificare con
  voto formale (licenze UniProt/NCBI, numeri ImmPort, ChEBI role per i PAMP) restano "forti da fonte
  singola, **da confermare al momento del build**" — marcati ⚠️ nelle domande aperte.

---

## TL;DR (dal report browser)
- **Citochine:** dizionario primariamente da **HGNC** (CC0 public domain; gene symbol + alias +
  previous symbols → `HGNC:n` stabile, poi cross-walk a UniProt accession e NCBI Gene ID) + sinonimi da
  **UniProt** (CC BY 4.0). Usare l'**ImmPort Cytokine Registry** (~300 entry, ~3.800 sinonimi che
  collassano grafie greco/storiche/simbolo-gene su un'unica entità) come **seed/whitelist** ad alta
  precisione: delimita il dizionario alle vere citochine e pre-risolve l'aliasing greco. **NON** usare
  GO/PRO/InterPro come dizionari nome→ID (sono strati di classificazione).
- **Patogeni:** **NCBI Taxonomy taxdump** (`names.dmp`/`nodes.dmp`; funzionalmente public domain, "no
  restrictions on use or distribution") come fonte primaria unica, ristretta a rank **specie/strain** e
  alle classi scientific-name/synonym/common-name. Patogeno sull'**asse organismo (taxid)**, separato
  dall'asse malattia (MeSH): un'esposizione è perturbazione sperimentale, non diagnosi del soggetto.
- **PAMP/adiuvanti** (LPS, poly(I:C), R848/resiquimod, PAM3CSK4, CpG ODN, flagellin) sono small molecule
  vere con ID ChEBI e role-annotation → **restano in ChEBI** come identità canonica, ma taggati
  `pathogen_exposure` via **whitelist curata** corta, così sono analizzati insieme agli organismi.
  Precision-gate ovunque: mai matchare class-word nude ("cytokine", "interferon", "virus", "infection").

## Key Findings (dal report browser)

**1. HGNC è l'anchor primario corretto per le citochine, e ce l'abbiamo già.** HGNC assegna un
`HGNC:n` stabile a ogni gene umano e pubblica `hgnc_complete_set` (TSV e JSON) su un bucket GCS pubblico,
aggiornato martedì e venerdì, con colonne esplicite per approved symbol/name, **alias symbols/names,
previous symbols/names**, + cross-ref a NCBI Gene, Ensembl, UniProt, MGI, IUPHAR. Dataset sotto **CC0**
(la licenza più permissiva per redistribuire un dizionario derivato). ID stabili anche se cambia il
simbolo. Esempio: IFNB1 (HGNC:5434) ha previous symbol IFNB e alias IFB/IFF/IFN-beta, mappa a UniProt
P01574 e NCBI Gene 3456. ✅ *(confermato dalla verifica indipendente, 3-0)*

**2. UniProt aggiunge il layer di sinonimi proteina sotto CC BY 4.0.** UniProtKB applica esplicitamente
**CC BY 4.0** a tutte le parti copyrightable (uniprot.org/help/license; embedded in ogni entry Swiss-Prot).
Nota per l'audit licenze: alcune pagine vecchie citano "Attribution-NoDerivs" — **testo obsoleto**, oggi
è CC BY 4.0 (permette di redistribuire una tabella nome→accession derivata). Dump: `uniprot_sprot.dat.gz`
(flat file, `DE` RecName/AltName + `GN` gene names/synonyms), `HUMAN_9606_idmapping.dat.gz` (3-col
accession→db→ID, per-organismo), `idmapping_selected.tab`. ⚠️ *(licenza non passata al 3-vote)*

**3. ImmPort Cytokine Registry è il seed di precisione che ci manca.** Master list curata di citochine,
chemochine e recettori che integra/mappa sinonimi su **MeSH, Protein Ontology, EntrezGene, HGNC, MGI,
UniProt** (JACI 2022 *Publicly available cytokine data*, S0091-6749(22)01054-5; cita Bhattacharya et al.,
Sci Data 2018;5:180015 — `immport.org/resources/cytokineRegistry`). ~**300 entry / ~3.800 sinonimi**
(inferiti da copia derivata di terzi, NON conteggio ufficiale). Collassa già greco/trattino/simbolo-gene/
storici/trade su un'entità (es. "INTERFERON BETA"/"BETA-INTERFERON"/"IFNB1"/"AVONEX" → 1 ID; "TNF
ALPHA"/"TNFA"/"CACHECTIN" → 1 ID). Valore: (a) whitelist che delimita alle vere citochine (esclude
~19.000 altri geni coding), (b) tabella di normalizzazione greco/alias pronta. **Licenza:** ImmPort User
Agreement §2.4 "unrestricted right to use and distribute" sotto termini commensurati + citazione — è un
data-use agreement, NON CC. ⚠️ **URL/formato bulk non verificati** (sito JS; endpoint legacy richiedeva
conversione CSV). *(non passato al 3-vote)*

**4. GO, PRO, InterPro/Pfam sono strati di classificazione, NON dizionari nome→ID.** GO "cytokine
activity" (GO:0005125) è un termine di funzione (annoti i geni *a* esso, non normalizzi un nome *a* esso;
non distingue IFN-β da IFN-γ). PRO (CC BY 4.0, OBO, `pro.obo`) = forme/complessi proteici fine-grained
(~35k termini), overkill e bassa copertura su free-text rumoroso; utile solo per distinzioni a livello
proteoforma. InterPro/Pfam = famiglia/dominio, granularità sbagliata (raggruppano intera "interferon
alpha/beta family"). Usarli a valle per il grouping, non per la normalizzazione.

**5. NCBI Taxonomy taxdump è il primario inequivocabile per i patogeni.** `taxdump.tar.gz` (FTP
ftp.ncbi.nlm.nih.gov/pub/taxonomy/) contiene `names.dmp` (taxid→name + colonna name-class: scientific
name, synonym, common name, genbank common name, equivalent name…) e `nodes.dmp` (taxid→parent + rank).
Tab-pipe (`\t|\t` / `\t|\n`), aggiornato giornalmente + archivi mensili, con `merged.dmp`/`delnodes.dmp`
per taxid mergiati/cancellati. **Licenza:** NCBI "no restrictions on the use or distribution"
(funzionalmente public domain). SARS-CoV-2 = taxid 2697049. Vernacolo ("flu"→Influenza) incompleto →
serve supplemento curato. ✅ *(confermato dalla verifica indipendente, 3-0 su più claim)*

**6. Il confine PAMP/adiuvante è reale, e ChEBI lo modella già.** ChEBI (CC BY 4.0; OBO) contiene
LPS/lipopolysaccharide, poly(I:C), resiquimod (R-848), PAM3CSK4, CpG ODN, flagellin come entità molecolari
con **role** annotation (modella "adjuvant"/"agonist"/immunomodulator via la role hierarchy). Download:
`chebi.obo`/`.owl`/JSON (FULL/CORE/LITE), SDF, dump PostgreSQL (ChEBI 2.0 su ftp.ebi.ac.uk/pub/databases/
chebi). Le molecole vivono legittimamente in ChEBI — la domanda è l'**asse analitico**, non l'identità.
⚠️ *(role/ID specifici non passati al 3-vote)*

**7. Per il tooling NER/normalizzazione, i tagger a dizionario calzano meglio coi vincoli offline+
precisione.** GNormPlus (open; il gene normalizer dietro PubTator) ~"86,7% F1 su BioCreative II GN, 50,1%
su BioCreative III GN" (Wei et al., BioMed Res Int 2015, 918710). JensenLab **SPECIES/ORGANISMS** (Pafilis
2013, PLoS ONE e65390; CC BY) = tagger a dizionario su NCBI Taxonomy (scientific/common/synonym +
abbreviazioni auto), "ordine di grandezza più veloce/efficiente di LINNAEUS" a pari precision/recall.
Caveat duro: "entrambi i metodi taggano i **virus** molto peggio degli organismi cellulari; batteri/funghi
i più facili". PubTator 3.0 (Wei 2024, NAR W540): >1 mld annotazioni, dump FTP
ftp.ncbi.nlm.nih.gov/pub/lu/PubTator3 — utile per **harvest di alias offline**, ma normalizza la
letteratura, non le nostre stringhe GEO. TaxoNERD = recognizer DNN, NON dizionario drop-in.

## Tabelle comparative (dal report browser)

### PARTE A — Citochine / fattori immunitari proteici
| Fonte | name→ID | Sinonimi (greco/storici) | Licenza | Dump bulk | Cross-ref | Stabilità ID | Cadenza |
|---|---|---|---|---|---|---|---|
| **HGNC** | tutti i gene symbol umani (~43k; ~19k coding); citochine ben coperte; `HGNC:n` | buono: alias + previous symbols/names; greco come alias ("IFN-beta") ma non esaustivo | **CC0** | `hgnc_complete_set` TSV+JSON (GCS); OWL | NCBI Gene, Ensembl, UniProt, MGI, OMIM, IUPHAR | molto alta | mar+ven |
| **UniProt** | tutte le proteine reviewed; accession | eccellenti RecName/AltName; GN synonyms; greco scritto+simbolico | **CC BY 4.0** | `uniprot_sprot.dat.gz`; `HUMAN_9606_idmapping.dat.gz`; `idmapping_selected.tab` | HGNC, NCBI Gene, Ensembl, PRO, ChEBI | alta | ~8 sett |
| **ImmPort Cytokine Registry** | ~300 entry (curato, bounded) | eccellenti per dominio: ~3.800 sinonimi; collassa greco/trattino/gene/trade/storici | ImmPort UA §2.4 (use+distribute + cite); non CC | URL/formato non verificati; legacy→CSV; JSON/TSV via API | MeSH, PRO, EntrezGene, HGNC, MGI, UniProt | ID interni + xref | irregolare |
| GO (cytokine activity) | NO (classificazione funzione) | n/a | CC BY 4.0 | `go.obo`+GAF | geni annotati | obsoleti non cancellati | frequente |
| Protein Ontology (PRO) | proteoform fine-grained; bassa copertura free-text | sì (overkill) | CC BY 4.0 (OBO) | `pro.obo`, OWL, `PAF.txt` | UniProt, PSI-MOD, Reactome, GO | alta | regolare |
| InterPro/Pfam | famiglia/dominio (granularità sbagliata) | nomi famiglia | aperta (InterPro CC0) | XML/TSV | UniProt | alta | per release |

### PARTE B — Patogeni / esposizioni
| Fonte | name→ID | Sinonimi/common | Licenza | Dump bulk | Cross-ref | Stabilità | Cadenza |
|---|---|---|---|---|---|---|---|
| **NCBI Taxonomy** | organismi→taxid; specie+strain | scientific+synonym+common+genbank-common+equivalent; auto-abbrev; vernacolo parziale | "no restrictions" (≈PD) | `taxdump.tar.gz` → `names.dmp`/`nodes.dmp`/`merged.dmp`/`delnodes.dmp` | UniProt, GenBank, BioSample | alta; merged/delnodes tracciano | giornaliera+archivio mensile |
| **ChEBI (PAMP/adiuvanti)** | LPS, poly(I:C), resiquimod, PAM3CSK4, CpG, flagellin + role | IUPAC/INN/synonyms (FULL) | CC BY 4.0 | `chebi.obo`/`.owl`/JSON, SDF, PostgreSQL | UniProt(Rhea), KEGG, PubChem, ChEMBL | stabile | nightly+mensile |
| MeSH (asse malattia, NON esposizione) | termini malattia (Tuberculosis D014376) | entry terms/synonyms | NLM public domain | XML/RDF | — | alta | annuale |

### Asse patogeno-vs-malattia (regola operativa)
Esposizione = **perturbazione del campione** ("cells stimulated with M. tuberculosis"), non diagnosi →
asse canonico = **NCBI Taxonomy (organismo→taxid)**, NON MeSH. "M. tuberculosis" → taxid 1773; riservare
MeSH "Tuberculosis" (D014376) solo se il record descrive lo stato di malattia del soggetto. Namespace
separati (come PubTator separa Species/Disease).

## Raccomandazioni (dal report browser)

### Citochine — build a strati
1. **Seed con ImmPort Cytokine Registry** (delimita l'universo + importa synonym→entity, pre-risolve
   greco/storici; registra l'acknowledgment ImmPort per la redistribuzione).
2. **Ancora ogni entry a un HGNC ID** (dump già in cache) via cross-ref → pull alias/previous symbols+names
   (HGNC CC0 → derivato redistribuibile).
3. **Espandi sinonimi da UniProt** (RecName/AltName + GN synonyms) per l'accession mappato (CC BY 4.0).
4. **Ordine a runtime:** match normalizzato esatto vs (a) ImmPort+HGNC approved symbol → (b) HGNC
   previous/alias → (c) UniProt protein-name synonyms → (d) reject. **ID canonico = HGNC** (più stabile),
   UniProt accession come chiave secondaria.
- **Soglia per cambiare approccio:** se la precisione su un set GEO hand-labeled scende sotto ~95% per
  collisioni di alias, restringere rimuovendo alias corti/ambigui (vedi Insidie), NON aggiungere fuzzy.

### Patogeni — build a strati
1. **Primario: NCBI Taxonomy taxdump.** Parse `names.dmp`; tieni name-class ∈ {scientific, synonym,
   equivalent, genbank-common, common}. Restringi nodi (via `nodes.dmp` rank) a **specie e sotto**
   (strain/subspecies/serotype); genere solo con whitelist esplicita.
2. **Tabella vernacolare/abbreviazioni curata** ("flu"→Influenza A/B, "TB"/"Mtb"→M. tuberculosis,
   "SARS-CoV-2"→2697049, "LPS from E. coli"→split organismo+adiuvante): common-name di taxdump incompleto,
   virus più difficili (benchmark SPECIES).
3. **Ordine:** scientific name → strain/synonym → vernacolo curato → reject. **taxid canonico**; usa
   `merged.dmp` per redirigere i taxid deprecati.

### Confine PAMP/adiuvante — criterio DETERMINISTICO
- **Regola:** una menzione è `pathogen_exposure` (analizzata con gli organismi) ma **mantiene l'ID ChEBI
  come identità canonica** se e solo se è in una **whitelist curata** (LPS/lipopolysaccharide, poly(I:C),
  R848/resiquimod, imiquimod/R837, PAM3CSK4, PAM2CSK4, FSL-1, CpG ODN/ODN 1826, flagellin, MPLA, MDP,
  zymosan, β-glucan). Membership decisa via **ChEBI role ancestry** (ruolo discendente di "adjuvant"/
  "immunomodulator"/TLR-agonist) **∩** whitelist (difendibilità). Tutto il resto resta small-molecule
  ChEBI puro. "LPS from Salmonella" → DUE record: ChEBI exposure + taxid organismo (mai mergiati).

### NER/normalizzazione — best practice (offline, precision-first)
- **Pipeline:** lowercase; Unicode NFKC; mappa lettere greche bidirezionale (α↔alpha↔"a", β↔beta, γ↔gamma)
  e collassa varianti trattino/spazio/parentesi ("IFN-β"="IFN beta"="IFNB"="IFN-beta"); strip dose/conc in
  coda ("TNFa 600nm"→"TNFa"); risolvi abbreviazioni (Ab3P-style).
- **Greco:** genera le permutazioni di alias UNA VOLTA al build (ImmPort le codifica già in gran parte).
- **Precision gating (obbligatorio):** **stoplist** di class-word che NON matchano mai da sole — "cytokine",
  "interferon", "interleukin", "chemokine", "growth factor", "virus", "bacteria", "bacterium", "infection",
  "pathogen", "TLR agonist". Richiedi un token discriminante (numero, lettera greca, epiteto di specie).
- **Tooling:** hash-table su chiavi normalizzate = giusto/più veloce per ~1M lookup. Riusare i *dizionari*
  (non i servizi) di SPECIES/ORGANISMS (NCBI-Tax-derived, CC BY) e GNormPlus (open). Opzionale: harvest di
  alias dai dump bulk **PubTator3** (`gene2pubtator3`, `species2pubtator3`), poi congelati per riproducibilità.

## Insidie / pitfall (dal report browser)
- **Gene-symbol vs proteina:** stessa stringa = gene (HGNC) o prodotto proteico → un'unica identità (la
  citochina) ma tieni sia HGNC ID sia UniProt accession (RNA-seq è gene-level).
- **Collisioni di alias:** alias corti pericolosi — "IFN" da solo = classe; "IL-1" senza α/β ambiguo
  (IL1A vs IL1B); alcuni alias collidono con geni diversi (esempio HGNC: alias "GluD1" vs approved GLUD1
  HGNC:4335). **Droppa alias <~3 char** e ogni alias che è approved symbol di un gene diverso.
- **Generici → UNKNOWN** ("interferon"/"cytokine"/"virus") mai forzati (precisione prima della copertura).
- **Strain vs specie:** "influenza A H1N1 PR8" vs "Influenza A virus" = taxid diversi; default rollup a
  **specie** salvo strain esplicito, documentato. Verificare a mano il sottoinsieme virus.
- **LPS doppia identità:** ChEBI molecola + derivato da batterio → mai mergiare "LPS" (adiuvante) con
  "Escherichia coli" (organismo); record distinti.
- **ImmPort non verificato:** URL/formato/conteggio/schema non confermati da fonte primaria (sito JS);
  ~300/~3.800 inferiti da copia di terzi → verificare al build.
- **Igiene licenze del derivato combinato:** CC0 (HGNC, NCBI≈PD) + CC BY 4.0 (UniProt, ChEBI, PRO, GO) +
  ImmPort data-use agreement → attribuzioni per-sorgente + clausola "commensurate terms" ImmPort. **UniProt
  è CC BY 4.0**, non la vecchia (obsoleta) "NoDerivs".
- **Drift cadenza update:** pinnare/archiviare le release usate (taxdump date, UniProt release, HGNC dump
  date, ChEBI release) e citarle nel paper.

---

## Verifica indipendente (skill `deep-research` Claude Code — 3-vote completato su 7 claim)
> La sintesi automatica del workflow è fallita per rate-limit; questi 7 claim sono gli unici col voto
> formale. **Tutti CONFERMANO** la spina dorsale del report browser (HGNC + NCBI Taxonomy):
1. ✅ (3-0) **HGNC** offre download bulk TSV+JSON (gene set completi, withdrawn, subset) → adatto a dizionario offline. `genenames.org/download`
2. ✅ (3-0) **NCBI Taxonomy** offre `new_taxdump` (archivio compresso) da FTP → dizionario offline senza API live. `NBK53758`
3. ✅ (3-0) Ogni nodo NCBI Taxonomy ha un **TaxId stabile e unico** → ID canonico version-stable per i patogeni. `NBK53758`
4. ✅ (3-0) Ogni record taxonomy ha nome scientifico corrente + uno o più **secondary names** (synonym/common). `NBK53758`
5. ✅ (3-0) `new_taxdump.tar.gz` aggiunge 6 file extra incl. **`host.dmp`** (relazioni ospite). `ncbiinsights 2018-02-22`
6. ✅ (2-0) NCBI Taxonomy mantiene per organismo nome corrente + sinonimi/varianti (hetero/homotypic, basionym, common, informal). `datasets/.../taxonomy-processing`
7. ✅ (2-0) NCBI Taxonomy distribuito come `new_taxdump` (incl. `nodes.dmp`) da FTP → lookup offline. `datasets/.../taxonomy-processing`

> **NON passati al 3-vote** (rate-limit) → da confermare al build: licenza UniProt CC BY 4.0; licenza
> public-domain NCBI; ChEBI:16412 LPS + role PAMP; numeri ImmPort (~300/~3.800, da copia di terzi);
> GNormPlus F1; SPECIES tagger; PubTator3.

## Domande aperte (per la decisione, da chiudere prima/durante il build)
1. ⚠️ **ImmPort Cytokine Registry**: URL/formato/licenza/conteggio reali (sito JS) — esiste un dump bulk
   pulito o va estratto via API/conversione CSV? Quanto copre davvero? *(unverified da entrambe le fonti)*
2. Copertura reale degli **alias greco in HGNC** (IFN-beta esaustivo?) — misurare sul residuo.
3. **Confine PAMP**: la whitelist corta basta? quanti dei NOSTRI pathogen residui sono PAMP (→ChEBI) vs
   organismi (→taxid)? Distribuzione da misurare.
4. **Guadagno atteso**: smoke sul residuo reale `cytokine_stim`/`pathogen` `UNK`/`STR` (come Task 7
   farmaci) — quanti si recuperano con HGNC+ImmPort (cito) e taxdump (patogeni)?

## Azione concreta proposta (eventuale Stadio 3 **v6** biologici, DOPO brainstorming/decisione)
- **Citochine**: clone del pattern dizionario — anchor HGNC (già in cache) + seed ImmPort + sinonimi UniProt.
- **Patogeni**: `taxdump` → tabella nome→taxid offline (rank-filtered) + whitelist vernacolare.
- **PAMP**: whitelist ChEBI + tag `pathogen_exposure` (role-ancestry ∩ whitelist).
- **Fix-tipo K3**: ri-tipizzare LPS/TNF/IL4 oggi `small_molecule` → `pathogen`/`cytokine` (regola analoga al K2).
- **Misurare con smoke** sul residuo PRIMA del re-cluster (validate-before-fullrun).

## Fonti principali
- HGNC download: `genenames.org/download`. NCBI Taxonomy: `NBK53758`, `ncbiinsights 2018-02-22`,
  `ncbi.nlm.nih.gov/datasets/docs/v2/.../taxonomy-processing`; SARS-CoV-2 taxid 2697049.
- UniProt licenza/dump: `uniprot.org/help/license`, `uniprot_sprot.dat.gz`, `HUMAN_9606_idmapping.dat.gz`.
- ImmPort Cytokine Registry: JACI 2022 `S0091-6749(22)01054-5`, Bhattacharya et al. Sci Data 2018;5:180015.
- ChEBI: `chebi.obo`/SDF/PostgreSQL, CC BY 4.0, OBO Foundry.
- NER: GNormPlus (Wei 2015, BioMed Res Int 918710), SPECIES/ORGANISMS (Pafilis 2013, PLoS ONE e65390),
  PubTator3 (Wei 2024, NAR W540), TaxoNERD.
