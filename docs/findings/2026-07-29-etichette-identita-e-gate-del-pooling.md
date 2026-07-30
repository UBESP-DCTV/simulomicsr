# Etichette risolte dall'ID, identità verificata su tutti e 305, e quanti gruppi il pooling terrà davvero

**Data:** 2026-07-29 · **Branch:** `review-scientific-consistency-2026-06-10`
**Contesto:** lavoro a valle, eseguito mentre il re-pool v13 (~50 h) è in corso.
**Stato:** 🟡 **Nessun run pesante lanciato per questo lavoro. Il re-pool non è stato toccato.**

---

## 1. Che cosa è stato fatto

Il nome mostrato dei gruppi (`canonical_name`) è ereditato dall'anchor del vecchio cluster e su
decine di gruppi è sbagliato. Ora l'etichetta si risolve **dall'ID** (`contrast_entity`), in una
colonna **nuova** (`contrast_entity_label`), senza sovrascrivere `canonical_name`: la provenienza
del nome vecchio resta tracciabile.

Codice: `R/stage3-entity-label.R`, test `tests/testthat/test-stage3-entity-label.R`
(**34 PASS / 0 FAIL**, scritti prima dell'implementazione e visti fallire).

**Non tocca il pooling**: `canonical_name` non compare in nessun file `R/stage4-*` (verificato con
grep sull'intero sorgente, non solo assunto).

| fonte dell'etichetta | gruppi |
|---|---:|
| ChEBI | 158 |
| STR (nessun nome ontologico: resta la stringa) | 64 |
| MeSH | 32 |
| HGNC | 27 |
| NCBI Taxonomy (nome **normalizzato**, vedi §4) | 11 |
| ChEMBL | 10 |
| COMBO (parti unite) | 3 |

**305 su 305 risolte, zero non risolte. 161 (52,8%) hanno un nome diverso da quello mostrato oggi**,
per 1.181 studi-slot su 2.158. Tabella: `analysis/audit/2026-07-29-etichette-v13/etichette-v13.csv`;
versione leggibile riga per riga: `etichette-da-rileggere.txt`.

Esempi: `CHEBI:63637` mostrato "sodium aurothiomalate" è **vemurafenib**; `CHEBI:5931` "chloride" è
**insulina**; `CHEBI:16335` "glucose" è **adenosina**; `MeSH:D008180` "cancer" è il **lupus**;
`HGNC:5981` "SNORD13P3" è **IL17A**; `NCBITaxon:10359` "influenza virus" è il **citomegalovirus**.

## 2. RITRATTAZIONE: «gli ID sono tutti giusti» non è vero

Il finding del 2026-07-28 (§5) dice: «**Gli ID sono giusti**: sbagliata è l'etichetta ereditata
dall'anchor vecchio». Su 305 gruppi **almeno uno smentisce quella frase**:

> **`CHEBI:73572` è il tripeptide Leu-Thr-Ala. I suoi tre studi trattano con acido lipoteicoico
> (LTA)** — GSE140702 "Neurotypical LTA", GSE140788 "LTA-treated hPMNC", GSE223177 "CD34+ cells
> treated with LTA". La sigla LTA è stata risolta alla molecola sbagliata. **Qui era il nome vecchio
> a essere giusto.**

È la stessa classe di difetto già misurata il 2026-07-25 (`ml`→THPO, `cancer`→granchio): un alias
formalmente valido che collide col gergo di laboratorio. Il gruppo resta **internamente coerente**
(tutti e tre gli studi trattano con LTA), quindi la meta-analisi vale: sbagliata è l'**identità** che
le attribuiamo.

Un secondo caso, più lieve: **`HGNC:1653` "CD28"** raccoglie stimolazioni **anti-CD3/anti-CD28**.
L'ID cattura metà del trattamento e non dice che si tratta di anticorpi. Non è falso, è parziale.

## 3. Come sono stati verificati TUTTI e 305 (e come il primo metro ha sbagliato)

Per ogni gruppo si prendono **tutti** i nomi con cui l'ontologia conosce quell'ID (nome primario +
sinonimi, dai dump grezzi: 561.100 alias ChEBI, 60.530 HGNC, 234.729 MeSH, 128.937 ChEMBL, taxonomy)
e si cerca se almeno uno compare nelle etichette dei bracci dei membri.

⚠️ **Il primo metro dava per buono il caso da cui era nato.** `CHEBI:73572` risultava "trovato"
perché fra i sinonimi del tripeptide c'è la sigla `LTA`, che nei membri compare — ma lì significa
acido lipoteicoico. Un match su una **sigla** non prova l'identità. Il metro è stato corretto
**prima** di usarlo, separando il match su un nome per esteso (>4 caratteri) dal match su sola sigla.

| esito | gruppi | letti come |
|---|---:|---|
| nome per esteso trovato nei membri | 248 | identità confermata dal testo |
| **solo sigla** | 52 | **letti tutti e 52, uno per uno** |
| nessun nome trovato | 5 | **letti tutti sui membri** (sono i patogeni, §4) |

Dei 52 "solo sigla": **49 sono abbreviazioni standard e corrette** (lps→lipopolysaccharide,
dht→17β-hydroxy-5α-androstan-3-one, h2o2, pma→phorbol 13-acetate 12-myristate, tcdd, tsa→trichostatin
A, drb, mms, pfos, dmog, kcl, dapt, sr1→StemRegenin 1, her2→ERBB2, p53→TP53 …), **1 è l'ID sbagliato**
del §2 (LTA), **1 è parziale** (CD28), **1 è corretto ma illeggibile**: `CHEBI:138438` è il nome
sistematico di **SAG**, l'agonista di Smoothened (i tre studi sono medulloblastoma DAOY + SAG).

Le quattro sigle con più di un significato in letteratura (TSA, DRB, KCl, SAG) sono state
controllate sui membri una per una: **tutte e quattro corrette**.

**Bilancio: su 305 gruppi, 303 hanno un ID corretto, 1 è sbagliato, 1 è parziale.**

## 4. I patogeni non hanno un'etichetta pubblicabile

Per gli 11 gruppi `NCBITaxon:` il dizionario in cache conserva **solo il nome scientifico
normalizzato** — `severeacuterespiratorysyndromecoronavirus2`, `humanbetaherpesvirus5` — perché il
dump costruito il 2026-07-01 tiene `name_norm` e butta la forma originale. L'etichetta è corretta ma
non tipografica: **va riscritta a mano per il paper** (sono 11 righe), oppure va ricostruito il dump
dal taxdump conservando il nome originale.

Nessuno dei 5 patogeni che non matchavano è un errore: letti sui membri, sono tutti quello che l'ID
dice — CMV (12 studi, tutti HCMV/AD169/TB40), influenza (9), HIV-1 (6), HSV-1 (5), HBV (4).
Il gruppo influenza `NCBITaxon:11320` contiene un membro di **influenza B** (GSE197143), che ha un
taxid diverso: imprecisione minore, in un gruppo già dichiarato incoerente per altro motivo.

## 5. Un secondo caso del difetto «entità su entrambi i bracci»

Il limite dichiarato il 2026-07-28 (GSE233083: `TGF-β1 + 3C` contro `TGF-β1 + DMSO` misura 3C ma
finisce nel gruppo TGF-β1) **ha un gemello**, trovato leggendo i membri di `CHEBI:32588`:

> `GSE180240`: **`KCl_Harringtonin` contro `KCl_DMSO`** — il confronto misura l'**harringtonina**,
> non il KCl, ma sta nel gruppo del cloruro di potassio.

Non cambia la decisione presa (limite dichiarato, non si corregge), ma la misura «1 confronto su
4.954» va letta come **almeno 2**: la ricerca strutturale del 28/07 cercava il pattern `X + A` contro
`X + B` e non ha catturato la forma con l'underscore (`KCl_Harringtonin`).

## 6. Quanti gruppi il pooling terrà davvero: 191 su 305

Misura fatta **con la funzione di dispatch vera** (`.build_group_rem_dispatch_from_stage3`), la
stessa che il run sta usando, su tutti e 305 — non su un campione, non con una regola riscritta.

Il ramo `rem_group` scarta i gruppi in cui **meno di 3 studi distinti** portano un confronto
risolvibile con controllo interno (limite L7, misurato il 2026-07-09 e non recuperabile: prestare
controlli da altri studi recupera l'1-7% dei geni veri e porta I² a 99).

| | |
|---|---:|
| gruppi del deliverable | 305 |
| **poolati** | **191 (62,6%)** |
| scartati dal gate (k_eff = 0 / 1 / 2) | 114 (11 / 37 / 66) |
| studi-slot tenuti | 1.758 su 2.158 (81%) |
| coerenza attesa sul poolato | **185 / 191 = 96,9%** |

**«305» non è il numero da portare nel paper: le meta-analisi poolate saranno ~191.** Il censimento
resta valido — misurava i raggruppamenti, non il pooling — ma il numero di testa cambia. Verifica di
sanità: `k_eff` non è mai maggiore di `k` (mediana 0,75 del k censito), come previsto dal collasso
dei bracci intra-studio.

Dei 9 gruppi incoerenti, **3 cadono da soli** per il gate (Recurrence k_eff=1, CSF2 k_eff=1, PTSD
k_eff=2) e **6 restano** nel poolato.

Bandiera, k censito → k_eff atteso: TGFB1 65→**49** · LPS 50→**35** · SARS 38→**33** ·
enzalutamide 29→**19** · vemurafenib 20→**8**.

Tabella: `analysis/audit/2026-07-29-etichette-v13/keff-atteso.csv`.

## 7. I gruppi incoerenti si marcano, non si scartano

Decisione confermata dall'utente il 2026-07-29. Scartarli richiederebbe una **lista di
identificativi scritta a mano**: chi rifacesse la pipeline otterrebbe 191 gruppi e non troverebbe
nessuna regola che spieghi la differenza. Tenerli e marcarli lascia la selezione **visibile** e il
numero prodotto uguale a quello che la pipeline produce.

Codice: `R/stage4-coherence-annotation.R`, test
`tests/testthat/test-stage4-coherence-annotation.R` (**12 PASS / 0 FAIL**). Aggiunge
`coherence_verdict`, `coherence_reason` e `coherence_source` (il verdetto è una lettura umana: la
sua provenienza viaggia nel dato). **Un verdetto che non trova il suo gruppo ferma la marcatura**:
senza quel controllo, un gruppo incoerente resterebbe marcato "coerente" — un fallimento silenzioso
e per giunta a favore della conclusione che fa comodo. Provato sui dati veri: 9 verdetti su 9
attaccano.

Uno dei sei incoerenti che restano sarebbe chiudibile con una **regola vera**, non con una lista:
`HGNC:5991` mescola IL-1α e IL-1β, che sono due entità distinte con gruppi propri. Richiederebbe un
altro re-cluster (~9 h): è una decisione dell'utente, non una cosa da infilare in questo run.

## 8. Che cosa questo NON dimostra

- **Non è una validazione del pooling.** Il re-pool è in corso; I², τ² e geni significativi non
  esistono ancora. I 191 sono una **previsione** calcolata con la funzione vera, da confrontare col
  risultato quando esce.
- **La coerenza del 96,9% è quella misurata prima del pooling.** Se il pooling scarta membri per
  ragioni sue, va rimisurata sui dati poolati.
- **Le etichette nuove sono corrette, non necessariamente leggibili.** Decine sono nomi sistematici
  ChEBI (`17β-hydroxy-5α-androstan-3-one` è il DHT, `5,6-dichloro-1-β-D-ribofuranosyl-1H-benzimidazole`
  è il DRB): per il paper serve un passaggio umano che scelga il nome d'uso. La colonna nuova è il
  punto di partenza di quel passaggio, non il suo risultato.

## 9. Riproducibilità

`analysis/audit/2026-07-29-etichette-v13/`:
`10-etichette.R` → `etichette-v13.csv`, `etichette-da-rileggere.txt` ·
`20-sospetti.R` → `sospetti-membri.txt` (i casi letti sui membri) ·
`30-keff-atteso.R` → `keff-atteso.csv` ·
`40-id-vs-membri.R` → `id-vs-membri.csv` (il controllo su tutti e 305).
