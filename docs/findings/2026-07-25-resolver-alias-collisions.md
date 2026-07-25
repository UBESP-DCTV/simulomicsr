# Collisioni di alias nei vocabolari di riferimento: una modalita' di errore
# sistematica del recupero-nome ontologico

**Data:** 2026-07-25 (sessione notturna autonoma) · **Branch:** `review-scientific-consistency-2026-06-10`
**Stato:** ✅ **Meccanismo isolato, impatto misurato sulla produzione, fix implementato con TDD e
verificato prima/dopo. Nessun re-cluster lanciato.**

---

## 1. Il punto di partenza

Durante il rework dell'anchor era emerso un caso singolo: `.normalize_cytokine_to_hgnc()` assegnava
**THPO (trombopoietina)** a qualunque etichetta contenente `ug/ml`. Domanda dell'utente: *"secondo me
non e' il solo bug di quel tipo. Va indagato."* Aveva ragione.

## 2. Il meccanismo

I vocabolari di riferimento contengono **sinonimi formalmente corretti** che, nel linguaggio dei
metadati trascrittomici, indicano quasi sempre un'altra cosa. Il resolver accetta il primo candidato
che matcha e assegna l'identita' **in silenzio**.

| stringa nei metadati | candidato estratto | entita' assegnata | perche' e' un sinonimo "valido" |
|---|---|---|---|
| `GO 1 ug/ml 28 days` | `ml` | **THPO** | ImmPort elenca `ML` fra i sinonimi di trombopoietina |
| `Her/Lap` (lapatinib) | `lap` | **TGFB1** | `LAP` = *Latency Associated Peptide* di TGF-β1 |
| `mitoxantrone (MIT)` | `mit` | **3-iodo-L-tirosina** | `MIT` = monoiodotirosina |
| `... in ...` | `in` | **CD44** | `IN` e' un sinonimo registrato del gene |
| `cancer` | `cancer` | **granchio** (*Cancer*, NCBI Taxonomy) | genere di crostacei |
| `5-FU` | `5fu` | **5-formiluracile** | invece di 5-fluorouracile (CHEBI:46345) |
| `DHA` | `dha` | **diidrossiacetone** | invece di acido docosaesaenoico |
| `TPA` | `tpa` | **acido tereftalico** | invece del forbolo estere |
| `SHH` | `shh` | **vorinostat** | invece di Sonic hedgehog |
| `MEK` | `mek` | **butan-2-one** | invece della chinasi MAP2K |
| `NMDA` | `nmda` | **ketamina** | l'antagonista al posto dell'agonista |
| `HGF`/`TPO`/`HGI` | — | **IL6** | sinonimi storici ImmPort ("hybridoma growth factor") |

Sono cinque famiglie: **unita' di misura**, **parole del discorso**, **sinonimi storici**,
**abbreviazioni di famiglia promosse a un membro** (IFN→IFNA1, IL1→IL1A, CSF→CSF2), **omonimie
chimiche**.

## 3. Misura sulla produzione (non sul proxy)

Sorgente: cache di produzione del recupero-nome (187.625 campioni) + testo sorgente vero dall'H5
ARCHS4 (`source_name_ch1`, `characteristics_ch1`, `title`) — gli stessi campi che legge
`build_name_recovery_lookup`.

- **28.556 campioni** hanno ricevuto un ID ontologico (CHEBI 18.349 · MeSH 4.060 · HGNC 3.474 ·
  ChEMBL 1.649 · NCBITaxon 1.024).
- Per **20.311** e' stato identificato l'alias che ha innescato il match (71%).
- **414 alias sospetti** allo screening, **4.649 campioni** coinvolti (22,9%).
- **Adjudicazione una per una** dei 170 alias piu' impattanti: **78 collisioni confermate**,
  92 risoluzioni corrette.

⚠️ **Una prima classificazione automatica dava il 51% e non era affidabile**: contava come collisione
anche `cisplatin` presente in ChEBI *e* ChEMBL, cioe' la stessa sostanza in due dizionari. Corretta:
l'ambiguita' va misurata sui **nomi**, non sui dizionari. Il numero pubblicabile e' quello adjudicato.

## 4. Una regola generale? Misurata e SCARTATA

Ipotesi elegante: *una sigla vale solo se l'entita' e' anche nominata per esteso nel corpus*
("LPS" e' credibile perche' compare "lipopolysaccharide"; "ML"→THPO no perche' "thrombopoietin" non
compare). Valutata contro le 170 coppie adjudicate:

| | valore |
|---|---:|
| precisione del rifiuto | 61,0% |
| copertura delle collisioni | 46,2% |
| **danno (risoluzioni corrette rifiutate)** | **25,0%** |

Avrebbe scartato PFOS (116 campioni), DNCB, DHEA, MEHP, lamivudina. **Regola rifiutata**: si sarebbe
pagato un quarto dei nomi corretti per intercettare meno di meta' degli errori. Resta la combinazione
di guardie strutturali + tabella adjudicata, che e' anche cio' che fanno i resolver biomedici
consolidati (stop-list curate).

## 5. Il fix (`R/resolver-guards.R`, TDD)

Tre guardie, applicate ai quattro punti d'ingresso (`.resolve_one_compound`,
`.normalize_cytokine_to_hgnc`, `.normalize_pathogen_to_taxid`, `.normalize_disease_to_mesh`):

1. **Unita' di misura e parametri** (`ml`, `mg`, `ph`, `moi`…): non identificano mai un'entita'.
2. **Parole funzionali e di laboratorio** (`in`, `on`, `lead`, `donor`, `cancer`, `tumor`, `cell`…).
3. **76 coppie (alias, ID) di collisione accertata**, ognuna con l'impatto misurato in commento.

Si scarta **il candidato**, non il termine: la catena prosegue col candidato successivo.
**Non si ri-mappa** al bersaglio giusto (5-FU → CHEBI:46345): ri-mappare significherebbe asserire
un'identita' per inferenza, che e' esattamente l'errore d'origine. Meglio nessun nome che uno sbagliato.

Test: `tests/testthat/test-resolver-guards.R` — **57 PASS, 0 FAIL**, inclusa la non-regressione su
LPS/DHT/vemurafenib/TNF/SARS-CoV-2.

## 6. Effetto misurato prima/dopo, sulla produzione

Ri-eseguito `recover_identity` (la funzione vera) sugli stessi campioni e testi.
Esclusi i percorsi K2/K3, che **riscrivono il `kind`**: rialimentandolo come input il ramo non riparte,
e la differenza sarebbe un artefatto della misura, non un effetto del fix (verificato: con il `kind`
originale, `siMETTL3` continua a risolvere a METTL3 anche con le guardie attive).

| | valore |
|---|---:|
| campioni su percorsi kind-invarianti | 26.936 |
| identita' invariate | 25.984 (**96,5%**) |
| **identita' sbagliate rimosse** | **952 (3,53%)** |

Collisioni accertate: **THPO 105→0 · CD44 96→0 · piombo 52→0 · 5-formiluracile 18→0 ·
diidrossiacetone 24→0 · acido tereftalico 19→0 · L-serina 23→0 · Neoplasms 354→0 · IFNA1 168→27 ·
IL6 86→42**.

Non-regressione (campioni con l'entita' corretta, prima → dopo): **LPS 401→401 · DHT 126→126 ·
vemurafenib 54→54 · enzalutamide 89→89 · SARS-CoV-2 308→308 · epatocarcinoma 162→162 · prostata
125→125**; **TNF 275→281** (+6: un candidato sbagliato non oscura piu' quello giusto).

Suite di regressione `name-recovery|anchor|ontology|stage3`: **0 fallimenti**.

## 7. Ricaduta sulla coerenza dei cluster

Il fix ha chiuso da solo un cluster incoerente del rework anchor: **TGFB1** conteneva i bracci
`Her/Lap` (trastuzumab/lapatinib) proprio per la collisione `lap`→TGFB1. Rimossa la collisione, il
cluster e' **k=27, tutto TGF-β1** — coerente. Vedi
`docs/findings/2026-07-25-stage3-contrast-anchor-v7-census.md` §Addendum.

## 7bis. Quanto ne e' toccato il deliverable v10

Sui 310.738 cluster dello Stadio 3 v10, **200.279 hanno un ID ontologico**; **6.389 (3,19%)** portano
un ID che e' bersaglio di una collisione accertata — i piu' frequenti: `MeSH:D009369` (*Neoplasms*,
nominato "cancer") 4.107, `TGFB1` 555, `IL6` 171, acido indolacetico 154, `THPO` 142, `IFNA1` 112,
`CSF2` 107, vorinostat 91, `CD44` 86, piombo 43. Nel **deliverable dei 184 rem_group** verificati il
2026-07-23 sono **5** i cluster con un nome di questo tipo (2× "cancer", acido indolacetico, CD44,
TGFB1).

⚠️ **E' un limite SUPERIORE, non un tasso di errore**: lo stesso ID puo' essere raggiunto anche per
via legittima (TGFB1 da "TGF-beta1" e' corretto; solo la via `lap` e' sbagliata). Il numero preciso e'
quello misurato per-campione al §6: **952 identita' sbagliate su 26.936 (3,53%)**, ognuna con l'alias
d'innesco identificato.

## 8. Limiti dichiarati

- L'adjudicazione copre i **170 alias piu' impattanti** (85% dei campioni sospetti). I 244 alias della
  coda (698 campioni, tutti n≤6) non sono stati giudicati uno per uno.
- La tabella delle collisioni e' **curata**: e' un dato, non un algoritmo. Va versionata insieme ai
  dizionari e ri-verificata quando cambia una release ontologica.
- Il giudice dell'adjudicazione e' interno (Claude). La pipeline pubblicata resta deterministica: le
  guardie sono codice + tabella, nessun LLM a runtime.
- Le identita' rimosse **non vengono sostituite**: 952 campioni perdono il nome e tornano a `STR:`.
  Recuperarli con un ri-mappaggio curato e' lavoro futuro, esplicitamente non fatto qui.

## 9. Riproducibilita'

`analysis/audit/2026-07-25-resolver-alias-audit/`:
`90-alias-danger-catalog.R` (catalogo alias + frequenze del corpus) →
`91b-production-impact-fast.R` (quale alias innesca ogni risoluzione di produzione) →
`93-suspects-refined.R` (screening rifatto) → `96-coattestazione.R` (valutazione della regola generale,
scartata) → `94-before-after.R` (effetto del fix). Tabelle: `sospetti-da-giudicare.csv`,
`alias-innesco-produzione.csv`, `identita-rimosse.csv`.
