# Decisione — database per nominare le small molecule (nota fusa: Claude Code + browser)

**Data:** 2026-06-28
**Fonti:** deep research Claude Code (`2026-06-28-deep-research-small-molecule-db.md`, 26 fonti,
25 claim verificati avversarialmente) + deep research browser (incollata dall'utente). Questa nota
**fonde** le due e segnala dove concordano, dove il browser aggiunge, e dove divergono.

> Contesto: oggi ChEBI (primario) + ChEMBL 37 (2ª). Smoke Task 7: 63,4% recupero drug-name,
> residuo = sigle GDC-/ABT-/KW- + termini rumorosi. Questa decisione riguarda un eventuale **v6**
> (più copertura), DOPO il v5 (ChEMBL) e il TODO biologici. NON blocca il run v5.

## Decisione operativa (consolidata)

**Dizionario core, tutto redistribuibile (Stage 1) — ordine precisione-decrescente:**

1. **ChEMBL** (primario di copertura; CC BY-SA 3.0). **Tenere `syn_type`** e fidarsi
   preferenzialmente di `RESEARCH_CODE`/`USAN`/`INN`/`BAN`/`JAN`/`TRADE_NAME`; **demotare/saltare i
   sinonimi non-tipati** (riduce i falsi). È il layer per le sigle (cobimetinib→GDC-0973/XL-518/RG-7420).
2. **DrugCentral** (CC BY-SA 4.0, dump PostgreSQL, no registrazione): ~4.927 farmaci (2023),
   **>20.617 sinonimi + research code** → secondo layer per le sigle cliniche.
3. **🆕 GtoPdb / Guide to Pharmacology** (dal browser; CC BY-SA 4.0 + ODbL): 13.721 ligandi, e
   soprattutto un **`ligand_id_mapping.csv` già pronto** che cross-referenzia PubChem/ChEMBL/ChEBI/
   CAS/INN/DrugBank/DrugCentral — utilissimo per la de-duplicazione.
4. **ChEBI** (già usato; CC BY 4.0).
5. **🆕 DrugBank Open Data "Vocabulary"** (dal browser; **CC0**, ~5MB): sottoinsieme redistribuibile
   (DrugBank ID, common name, CAS, UNII, synonyms, InChIKey). **NB**: il DrugBank *pieno* resta
   **escluso** (CC BY-NC, download sospesi) — si usa SOLO la vocabulary CC0.

**De-duplicazione:** canonicalizzare ogni voce a un ID interno via **UniChem** (whole-source-mapping,
chiave **Standard InChIKey**). `src_id`: ChEMBL=1, DrugBank=2, GtoPdb=4, ChEBI=7, PubChem=22,
DrugCentral=34, KEGG~6. **InChIKey pieno** per l'identità; il match per **primo blocco/connettività**
solo DELIBERATAMENTE per collassare sali/dose/racemi. **Unità canonica = composto parent**
(osimertinib = osimertinib mesilato).

**Stage 2 (recall gated):** solo per i residui ancora UNKNOWN, `CID-Synonym-filtered.gz` di PubChem,
con (a) match esatto normalizzato, (b) **blocklist generici** (vedi sotto), (c) rifiuto se il sinonimo
mappa a >1 CID con primo-blocco InChIKey diverso, (d) flag "PubChem-only, bassa confidenza".

**Stage 3 (opzionale, human-reviewed):** `text2term` (MIT, offline) fuzzy contro label locali
ChEBI/ChEMBL, soglia alta, **revisione manuale** di ogni nuovo mapping. Mai auto-accettare fuzzy.

**Licenza del derivato combinato = CC BY-SA 4.0** (catena share-alike ChEMBL BY-SA 3.0 + DrugCentral/
GtoPdb BY-SA 4.0 + ChEBI BY 4.0; DrugBank-CC0/PubChem-PD compatibili). **Escludere**: DrugBank pieno
(BY-NC), **KEGG** (sottoscrizione accademica a pagamento), **RxNorm** (licenza UMLS + solo farmaci
US, niente research code).

## Dove le due ricerche CONCORDANO (alta confidenza)
- **ChEMBL = sorgente giusta** per i research compound, con research code tipati; CC BY-SA 3.0; dump
  SQLite (il nostro approccio attuale). La nostra scelta è validata; entrambe dicono di tenerlo centrale.
- **DrugCentral** complemento per le sigle (CC BY-SA 4.0, Postgres offline).
- **DrugBank pieno = escludere** (restrittivo BY-NC).
- **PubChem** = ultima rete, solo file **filtered**, con gating.
- **UniChem + InChIKey** = meccanismo di de-dup; collisione InChIKey **trascurabile** a ~1M (50% solo
  a ~6,1×10⁹). Il rischio vero è il **falso NON-match** (stesso farmaco, sale/stereo diverso).
- **Precisione-prima**: normalizza (case-fold, NFKC, Greco α→alpha, strip dose/tempo "2 um 9d"),
  **match esatto** (no fuzzy come primario), **blocklist di parole-classe generiche**
  ("acid","inhibitor","drug","vehicle","control","DMSO","agonist","antagonist","compound"), soglia
  ≥3 alfanumerici + ≥1 lettera, e **lasciare UNKNOWN** invece di un merge sbagliato.
  → **Conferma in pieno la nostra `.GENERIC_COMPOUND_STOPLIST` e il gate del Task 7.**
- I tool **ML di chemical-NER sono inaffidabili cross-corpus** → **l'LLM-fallback finale (DECISIONE C)
  va precision-gated** (propone, valida contro ontologia), mai normalizzatore fidato.

## Cosa AGGIUNGE il browser (non era nel mio, prezioso)
- **GtoPdb** verificato (il mio l'aveva lasciato "non verificato"): 13.721 ligandi + **mapping file
  cross-DB pronto**. → da includere.
- **DrugBank Open Data Vocabulary CC0**: il mio diceva "escludi DrugBank" tout-court; il browser
  raffina — **escludi il pieno, USA la vocabulary CC0**. → adottare il raffinamento.
- **RxNorm/KEGG** chiariti come **non adatti** al nostro residuo (US-only/no-codici; pagamento).
- **Tooling offline**: `pubchempy` = solo online (no, per ~1M lookup); NER tagger (tmChem/ChemListem/
  ChemSpot/PubTator) = *trovano* le menzioni, ma noi le abbiamo già segmentate (servono a noi? no);
  **LeadMine** = grammar+dizionario offline ma **proprietario**; **`text2term` (MIT)** = il bolt-on
  fuzzy offline; **OnSIDES** = adverse events, escludere.

## Dove DIVERGONO (da risolvere prima di fidarsi)
1. **Licenza UniChem**: il browser asserisce **CC0** (due volte); la **mia verifica avversariale ha
   UCCISO (0-3)** il claim "UniChem è CC-0". → **CONFERMARE la licenza dei whole-source-mapping di
   UniChem** prima di redistribuirli (potenziale blocco per il supplementary).
2. **Conteggio DrugCentral**: 4.927 (2023, browser) vs 4.444 (2017, mio) — snapshot di release diversi.
   → usare la release più recente e **pinnare la versione**.
3. **Claim uccisi dalla mia verifica** (NON ripeterli a prescindere dalla fonte): ChEMBL **non** ha
   ChEBI/InChIKey per *tutti* i composti; il **primo blocco InChIKey non è formula leggibile** (è un
   hash troncato SHA-256, 65 bit); UniChem **non** è confermato CC0 (vedi sopra).

## Insidie (entrambe le ricerche, consolidate)
- **Parole-classe generiche come entità** ("acid"/"inhibitor" in ChEBI) = il rischio #1 di merge
  spurio → blocklist (già fatto). **Abbreviazioni** = catastrofiche ("MTT" → 800+ stringhe).
- **Sali/parent**: ChEMBL separa sale/parent (molregno hierarchy); DrugCentral riduce al parent.
  Decidere parent come unità canonica.
- **Racemi/stereo**: stesso primo-blocco, secondo-blocco diverso → collassare al parent salvo studi
  che contrastano stereoisomeri.
- **Numeri = snapshot di versione**: ri-scaricare e **pinnare la data del dump** nel supplementary.

## Azione concreta per "v6" (DOPO v5 + biologici)
1. **Smoke mirato** sul NOSTRO residuo reale (come Task 7): misurare l'hit-rate incrementale di
   DrugCentral vs GtoPdb vs DrugBank-CC0 sulle sigle GDC-/ABT-/KW- → decidere quali aggiungere.
2. Aggiungere le sorgenti scelte come dump offline (clone del pattern ChEMBL: nome→ID locale).
3. Valutare un layer **UniChem/InChIKey** per la de-frammentazione cross-sorgente (prima confermare
   la licenza UniChem).
4. Gating invariato (stoplist + esatto + min-length); residuo finale → **LLM precision-gated**.

## Verdetto del confronto Claude Code vs browser
- **Browser**: retrieval più ampio e ricco (GtoPdb, DrugBank-CC0, RxNorm, KEGG, tool) — vince sulla
  copertura del panorama, come previsto per una domanda di conoscenza pubblica.
- **Claude Code**: verifica avversariale che ha intercettato 3 claim falsi (incluso UniChem-CC0 che il
  browser dà per buono) + aggancio ai nostri numeri/codice + documento già nel repo.
- **Insieme** danno la decisione sopra. Nessuna delle due da sola era completa: il browser più completo
  sui fatti, il mio più severo sulla verifica.
