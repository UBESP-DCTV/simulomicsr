# Deep research — database per nominare le small molecule (report Claude Code)

**Data:** 2026-06-28 · **Fonte:** skill `deep-research` (6 angoli, 26 fonti fetchate, 122 claim
estratti, **25 verificati avversarialmente → 22 confermati / 3 uccisi**). Versione "in-repo" per
confronto con la deep research da browser.

> Sintesi integrata col nostro contesto: oggi usiamo **ChEBI** (primario) + **ChEMBL 37** (2ª
> sorgente). Smoke Task 7: 63,4% recupero drug-name; residuo = sigle oscure + termini rumorosi.

## Raccomandazione (architettura a strati, precisione-decrescente)

Interrogare le sorgenti in **ordine di curazione decrescente**, accettando il PRIMO match ad alta
confidenza e scendendo a sorgenti più rumorose solo per i residui:

1. **ChEBI** (già primario, curato manualmente) →
2. **ChEMBL** (curato, ampiezza research+clinica — **promuoverlo a layer primario di copertura**;
   noi lo usiamo come 2ª, l'evidenza dice che è LA sorgente per i composti da ricerca) →
3. **DrugCentral** (NUOVO complemento consigliato: 20.617 sinonimi **+ research code**, proprio per
   le sigle GDC-/ABT-/KW-; CC BY-SA 4.0; dump PostgreSQL offline) →
4. **PubChem** solo via file **`CID-Synonym-filtered.gz`** (~918M, curato/structure-consistent — NON
   l'unfiltered rumoroso), come ultima rete **con gating esplicito** →
5. **Riconciliazione strutturale** di tutti gli ID via **UniChem** su **Standard InChIKey** (stesso
   InChIKey = stessa molecola), per collassare lo stesso composto trovato da fonti diverse su un
   unico parent canonico.

**Licenza del derivato:** ChEMBL (BY-SA 3.0) + DrugCentral (BY-SA 4.0) + ChEBI (BY 4.0) → la catena
share-alike obbliga a rilasciare il dizionario combinato come **CC BY-SA 4.0**. **DrugBank** è
**restrittivo** (CC BY-NC 4.0, accesso gated) → **escluderlo** da un derivato redistribuibile
(conferma la nostra scelta di sessione).

## Tabella sintetica (solo claim VERIFICATI)

| DB | Copertura research-compounds | Research-code come sinonimi | Licenza redistr. | Dump offline | Note |
|---|---|---|---|---|---|
| **ChEMBL** | ~2,4M composti; ~17,5k approvati+clinici; 11.544 USAN/INN | sì (pref_name+synonyms) | **CC BY-SA 3.0** ✅ | SQLite/SDF/… | layer primario copertura |
| **DrugCentral** | ~4.444 API (skew approvati) | **sì, 20.617 syn+research code** ✅ | **CC BY-SA 4.0** ✅ | PostgreSQL + MOL/SMILES/InChI | miglior fonte per le SIGLE |
| **PubChem** | enorme | sì ma rumoroso | (da verificare, ~public domain) | `CID-Synonym-filtered.gz` 918M | solo filtered + gating |
| **ChEBI** | curato (già usato) | parziale | CC BY 4.0 | flat | nostro primario |
| **UniChem** | hub ID↔ID (NON nomi) | n/a | **NON CC-0** (da verificare) | flat-file FTP (wholeSourceMapping) | de-dup via InChIKey |
| **DrugBank** | clinici | sì | **restrittivo (BY-NC)** ❌ | gated | escludere dal derivato |

*Non verificati indipendentemente (NON asserire numeri): RxNorm, Guide to Pharmacology (GtoPdb),
KEGG DRUG — vedi open questions.*

## Insight chiave per noi

- **La copertura "vera" viene dai DB di ricerca, non dagli approvati.** L'intero universo pubblico
  di farmaci testati clinicamente è ~11.700 API → i DB di approvati (DrugCentral/DrugBank) saturano
  presto. Per un residuo di composti da ricerca, il guadagno marginale è **ChEMBL/PubChem**;
  DrugCentral serve per i **research code** (alias), non per ampiezza.
- **De-frammentazione 2.0**: oggi de-frammentiamo via "pref_name ChEMBL → ri-lookup ChEBI". L'evidenza
  suggerisce il meccanismo robusto: **UniChem + InChIKey pieno** per l'identità; il match per
  connectivity-layer (collassa sali/dose/racemi) va usato **DELIBERATAMENTE**, non come chiave di
  default (rischio di fondere stereoisomeri/sali genuinamente diversi). Rischio collisione InChIKey a
  ~1M composti: **trascurabile** (collisione attesa solo verso ~6,1 miliardi di voci).
- **Il nostro approccio è quello giusto (validato).** Normalizzazione dizionario + gating di
  precisione + **stoplist** anti-generici ("acid"/"inhibitor"/"drug") è esattamente la best practice;
  i tool ML di chemical-NER sono **inaffidabili cross-corpus** (HunFlair2 ~54% F1, PubTator ~32%,
  dizionario puro plafona a ~0,87). **Implicazione per l'LLM-fallback finale (DECISIONE C)**: l'LLM va
  usato **precision-gated** (propone, ma valida contro ontologia), NON come normalizzatore fidato.
- Le **abbreviazioni** sono il rischio #1 (es. "MTT" → 800+ stringhe diverse): gating severo, meglio
  NO_RECOVERY che un merge a bassa confidenza (= il nostro principio precisione-prima).

## Correzioni (3 claim UCCISI dalla verifica — NON ripeterli)

1. ❌ "ChEMBL assegna ChEBI/InChIKey a TUTTI i composti" → falso (non assumere xref ChEBI ovunque).
2. ❌ "Il primo blocco dell'InChIKey codifica formula+connettività leggibili" → falso (è un **hash**
   della connettività, non leggibile come formula).
3. ❌ "UniChem è CC-0" → falso (licenza da verificare prima di redistribuire i suoi mapping).

## Domande aperte (per la decisione)
1. Copertura/licenza reale di **DrugBank** (e dell'eventuale subset Open Data) sui research-code.
2. Quale singola fonte ha l'hit-rate più alto sulle **sigle** GDC-/ABT-/AT-/KW- misurato sul NOSTRO
   residuo reale (ChEMBL named candidates vs DrugCentral research-code vs PubChem)? → si misura con
   uno smoke mirato, come Task 7.
3. RxNorm / GtoPdb / KEGG DRUG aggiungono copertura redistribuibile oltre ChEMBL+DrugCentral?
4. Licenza di redistribuzione di PubChem e UniChem (non verificate qui).

## Azione concreta proposta (eventuale "v6", DOPO v5 + biologici)
Aggiungere **DrugCentral** come 3ª sorgente (clone del pattern ChEMBL: dump PostgreSQL → tabella
nome→ID offline) per le sigle di ricerca, e valutare un layer **UniChem/InChIKey** per la
de-frammentazione cross-sorgente. Misurare il guadagno con uno smoke mirato sul residuo (come Task 7)
prima di committare un re-cluster. Non blocca il run v5 (ChEMBL).

## Fonti principali (verificate)
- ChEMBL 35 / 33: `PMC12516679`, `PMC10767899`, NAR `40/D1/D1100`.
- DrugCentral 2017: NAR `45/D1/D932`.
- PubChem downloads: NLM KB `KA-03558`, `PMC11181558`.
- UniChem: `chembl.gitbook.io/unichem`, `PMC3616875`, `PMC4158273`.
- InChIKey collisioni: J Cheminform `1758-2946-4-39`.
- Licenze: `reusabledata.org/drugbank.html`, `chembl.gitbook.io/.../general-questions`,
  RxNorm/KEGG/GtoPdb terms.
- NER tooling: `s13326-024-00314-1`, tmChem/ChemListem papers (PMC4331693/PMC4177665/…).
