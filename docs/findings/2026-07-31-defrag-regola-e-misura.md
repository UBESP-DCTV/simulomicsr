# La regola di de-frammentazione: che cos'e', dove sta, e che cosa fa a tutto il corpus

**Data:** 2026-07-31 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** 🟡 regola scritta con i test prima e misurata su TUTTI gli 87.092 confronti del corpus.
**NON e' un risultato del re-run**: e' la misura che decide se il re-run si fa.

---

## 1. LA DOMANDA CHE POTEVA RIBALTARE LA DECISIONE, E LA RISPOSTA

Il programma chiedeva di misurare, prima di scrivere qualsiasi codice: **l'alias `tgfb`
aggancia solo TGFB1, o anche TGFB2/TGFB3?** Se non fosse univoco, la fusione principale
non si farebbe e il guadagno atteso su TGF-β1 — che e' la figura 2 del main paper —
sparirebbe.

Misurato su tutti gli alias di ChEBI, ChEMBL, HGNC, MeSH e tassonomia (4.709.134 alias
normalizzati, 3.184.787 entita' distinte):

| token | entita' agganciate | esito |
|---|---:|---|
| **`tgfb`** | **1** — `HGNC:11766` TGFB1 | si fonde |
| `tgf_b` (stessa chiave normalizzata) | 1 — `HGNC:11766` | si fonde |
| `ifna` | **2** — `HGNC:5417` IFNA1 + `HGNC:5423` IFNA2 | **NON si fonde** |
| `glioblastoma` | 1 — `MeSH:D005909` | si fonde |
| `il17` | 1 nello spazio della classe `drug` — `HGNC:5981` IL17A | si fonde |

**TGFB2 e TGFB3 portano come alias `tgfb2` e `tgfb3`, mai `tgfb` nudo.** La cifra e' parte
della chiave: senza, sarebbero la stessa entita'.

## 2. TRE COSE CHE LA MISURA HA CAMBIATO NEL DISEGNO DELLA REGOLA

1. **`tgfb` si risolve gia'.** `.normalize_cytokine_to_hgnc("tgfb")` restituisce
   `HGNC:11766` via ImmPort. A bloccarlo e' `.ca_acronym_ok`, che accetta un candidato di
   ≤4 caratteri **solo** se coincide col nome risolto: `tgfb` ≠ `tgfb1`. La frammentazione
   di TGF-β1 nasce li', ed e' una guardia di precisione, non un errore.
2. **`ifna` non si risolve affatto**, e in piu' e' gia' nella tabella delle collisioni
   accertate (`ifna|HGNC:5417`, `ifna|HGNC:5423`, audit 2026-07-25). Resta fuori per due
   motivi indipendenti.
3. **`glioblastoma` non passa dal resolver MeSH** — e' il limite noto «glioblastoma MeSH
   miss» (name-cleanup 2026-07-07) — ma nell'indice degli alias aggancia `MeSH:D005909` in
   modo univoco.

Il punto 3 **esclude la scorciatoia**: una regola che si limitasse ad allentare
`.ca_acronym_ok` prenderebbe TGF-β1 e perderebbe glioblastoma. La regola giusta e' quella
scritta nel programma — match sull'indice degli alias.

## 3. LA REGOLA

> Prima di ripiegare su `STR:`, il token si prova contro l'ontologia pretendendo un match
> **univoco** su un alias **per esteso** (>3 caratteri) fra le entita' che **la classe del
> contrasto interroga**. Ambiguo, corto o assente → si resta su `STR:`, e lo si dichiara.

**E' per-record, non dipende dal corpus**: la stessa etichetta produce lo stesso esito in
qualunque insieme di studi. Non e' una lista di casi.

**Le ontologie per classe rispecchiano `.ca_resolve_entity`**, non sono un insieme nuovo:
`drug` → ChEBI+ChEMBL+HGNC+tassonomia · `infection` → tassonomia · `disease` → MeSH ·
`genetic` → HGNC · ogni altra classe → **nessuna fusione**.

**Dove sta:** `R/stage3-defrag-alias.R`, innestata in `R/stage3-contrast-anchor.R` **dopo**
`res$id` e prima del ripiego `STR:`. Non puo' quindi cambiare un'entita' gia' risolta:
solo recuperarne una che si perderebbe. L'invariante e' verificata sui dati (§6), non
assunta.

**Perche' serve un indice proprio:** i dizionari in memoria sono ambienti hash
chiave→valore — una chiave, una entita'. **Non possono dire che `ifna` aggancia DUE geni**:
l'informazione e' persa nella costruzione. L'ambiguita' si vede solo nelle tabelle lunghe
degli alias, rilette una volta per sessione (165 s su un run di ~9 h) e memoizzate.

### Perche' «>3 caratteri»

E' il vincolo gia' pagato il 2026-07-29: un match su una **sigla** fece dare per buono
`CHEBI:73572` per tre studi che trattano con acido lipoteicoico (il tripeptide Leu-Thr-Ala
ha `LTA` fra i sinonimi). Misurato oggi: `lta` aggancia **2** entita', `dht` e `tnf` ne
agganciano 1 ciascuno — e **nessuno dei tre si fonde**, perche' la lunghezza viene prima
dell'univocita'.

## 4. DUE DIFETTI MIEI, TROVATI LEGGENDO IL CODICE A VALLE PRIMA DI LANCIARE

Per un membro fuso `raw` diventa l'**ID** (`HGNC:11766`) invece del **nome**. Due guardie
che per un membro `STR:` funzionavano si spegnevano in silenzio **proprio sui membri
nuovi**:

| guardia | con `STR:tgfb` | con `HGNC:11766`, prima del fix |
|---|---|---|
| `.ca_entity_tokens()` → rilevatore di riga | riceve `tgfb` | riceve `hgnc`, `11766`: il nome dell'entita' puo' essere scambiato per un identificativo di linea |
| sonda «entita' tenuta costante fra i bracci» | cerca `tgfb` nel controllo | cerca `hgnc 11766`: **non lo trova mai**, la guardia e' morta |

Corretti passando il token della fusione in entrambi i punti, con due test che li
difendono. **Non e' un difetto teorico**: la seconda guardia e' quella che scarta
`TGF-β1 + inibitore` contro `TGF-β1`, cioe' un membro che non misura l'entita' del gruppo.

## 5. UN RISCHIO CHE IL PROGRAMMA NON CITAVA

La classe `drug` interroga la **tassonomia**, come fa il resolver. Li' `cancer` aggancia
`NCBITaxon:6754` — **il genere del granchio**. A fermarlo e' solo `.is_unreliable_candidate`,
che e' una lista finita di parole funzionali. Con 3,3 milioni di nomi di tassonomia il
rischio di fusioni sbagliate e' reale, quindi **ogni fusione che finisce su un taxon si
legge una per una** (§7), non si somma.

## 6. LA MISURA SU TUTTI I MEMBRI

**Su 87.092 confronti** — l'intero corpus dello Stadio 2, non i 28.294 del censimento
2026-07-28 (quelli erano i soli membri gia' assegnati a un `cgroup`, e non avrebbero mostrato
i membri **ripescati**).

I due regimi si ottengono **nella stessa passata e sugli stessi input**, senza toccare il
codice di produzione e senza `git stash`: una copia dell'ambiente dei dizionari con la
memoizzazione dell'indice pre-seminata **vuota** fa trovare al ramo nuovo esattamente
nulla. Lo script **asserisce** che i due regimi siano quelli dichiarati prima di misurare
(`ON fonde tgfb, OFF no`), cosi' il file non puo' essere etichettato male.

**Lo strumento vede il dato per intero:** etichette max 238 caratteri (mediana 22),
`factor_levels` max 319, nessun tetto di troncamento — ci sono stringhe sopra ogni limite
sospetto (40/58/64/100/128/255). E' il controllo che il 2026-07-30 mancava, quando un
verdetto fu dato su mezza frase.

### 6bis. I NUMERI, e il fatto che NON tornano come previsto

Prima misura completa (codice con i due fix del §4, senza il terzo del §6quater):

| | previsto dal §2 della decisione | **misurato su 87.092 confronti** |
|---|---:|---:|
| membri che cambiano entita' | ~198 studi-slot | **2.203 (2,53%)** |
| coppie distinte `da → a` | ~5 | **670** |
| gruppi `k>=3` | — | 688 → **700** (+12: **55 nati, 43 spariti**) |
| gruppi la cui composizione cambia | «3 gruppi» | **1.483** |
| membri PERSI (tenuti prima, scartati ora) | — | **0** |

**E' ~11 volte piu' grande di quanto la decisione prevedeva**, e la ragione e' che le
due misure guardano cose diverse: il §2 contava le entita' dei `cgroup` **sopravvissuti al
gate** (7.756 entita' `STR` su 11.541 gruppi), questa conta **tutti** i confronti, compresi
quelli che il gate scarta e che la regola puo' ripescare.

**Invariante verificata sui dati: 0 membri cambiano partendo da un'entita' gia' risolta**
(tutti e 2.203 hanno `entity_source == "defrag"`). L'innesto e' nel posto giusto.
`STR:ifna`: **0 membri cambiano**, come previsto.

Le fusioni piu' grandi sono quelle che ci si aspetta da una de-frammentazione corretta:
`STR:hypoxia`→`MeSH:D000860` (94 membri), `STR:tgfb`→`HGNC:11766` (67), `STR:covid_19`
→`MeSH:D000086382` (61), `STR:schizophrenia` (57), `STR:glioblastoma` (40),
`STR:multiple_sclerosis` (31), `STR:ifnb`→`HGNC:5434` (30), `STR:cystic_fibrosis` (19).

**DECISIONE UTENTE 2026-07-31: si procede con la regola piena.** Restringerla ai cinque
casi previsti significherebbe tornare a una lista scritta a mano — l'errore che questo
progetto ha gia' pagato per mesi. Il prezzo e' che la rilettura fra i due run e' piu'
lunga di «3 gruppi»: vanno confrontati gli insiemi dei membri su tutti i gruppi e riletti
i cambiati.

### 6quater. TERZA ISTANZA DEL DIFETTO — e una MIA RITRATTAZIONE nel mezzo

**Il difetto e' reale**: le guardie basate sul NOME (`induttore`, `nome generico`,
`nome ombrello`, `candidato ombrello`) si spengono su un membro fuso, perche' l'entita'
diventa un ID e `res$name` e' NA. Corretto con un principio unico invece che caso per
caso: **il token della fusione E' il nome**, e vale ovunque il codice cerchi il nome.

**L'effetto misurato e' sui controlli OMBRELLO e GENERICO: 99 membri** (59
`nome_ombrello`, 40 `str_generico`) rientravano nel corpus perche' quelle due guardie sono
agganciate al prefisso `STR:`, che la fusione toglie.

> ⚠️ **RITRATTAZIONE.** La prima stesura di questa sezione diceva: «`STR:dtag13` →
> `CHEBI:234353`, 22 membri: oggi quei membri sono scartati, con la regola sarebbero
> rientrati». **E' FALSO.** Misurato: quei 22 membri erano **gia' tenuti prima** e restano
> tenuti dopo. Avevo dedotto lo scarto dal commento accanto al codice invece di contarlo —
> la stessa classe di errore di sempre, *credere all'etichetta invece di guardare il dato*.
> Il test che avevo scritto per «difendere» quella correzione asseriva la stessa cosa
> falsa, ed e' stato il suo fallimento a farmela scoprire.

**In compenso la ritrattazione ha fatto emergere un difetto VERO e PRE-ESISTENTE**, che
non c'entra con questa regola: `.CG_INDUCERS` contiene `"dtag"`, ma il confronto e' a
**confini di parola** e le cifre sono caratteri di parola, quindi `\bdtag\b` **non
aggancia `dtag13`**. Le etichette scritte `dTAG-13` vengono prese, quelle scritte `dTAG13`
sfuggono.

**Misura: 64 membri** (`STR:dtag13` 22, `STR:dtag7`, `STR:dtag47`) stanno oggi nel corpus
sotto il nome di un induttore di degron — dove l'entita' comune e' il reagente e la
proteina degradata cambia da studio a studio.

**NON e' chiuso qui, ed e' una scelta**: chiuderlo cambierebbe il corpus oltre a cio' che
e' stato misurato e autorizzato stasera. Va nell'elenco delle cose da decidere, con il suo
numero accanto. Un test lo fissa per iscritto perche' non si perda.

### 7. LE FUSIONI SU UN TAXON, LETTE UNA PER UNA

Come annunciato nel §5, non si sommano: si guardano. **7 coppie, 16 membri.**

| da | a | membri | giudizio |
|---|---|---:|---|
| `STR:zika_virus` | NCBITaxon:64320 Zika virus | 4 | corretto |
| `STR:senv` | NCBITaxon:136966 SEN virus | 4 | corretto |
| `STR:h1n1` | NCBITaxon:114727 | 3 | corretto |
| `STR:h3n2` | NCBITaxon:119210 | 2 | corretto |
| `STR:h5n1` | NCBITaxon:102793 | 1 | corretto |
| `STR:h7n9` | NCBITaxon:333278 | 1 | corretto |
| **`STR:mito`** | **NCBITaxon:262676 *Vasconcellea candicans*** | **1** | **SBAGLIATO: e' una PIANTA** |

**Sei su sette sono ceppi virali corretti; uno e' il granchio del §5, in miniatura.**
`Vasconcellea candicans` ha `mito` fra i sinonimi; negli studi «mito» e'
mitocondriale/mitomicina/mitotico. **DECISIONE UTENTE: aggiunto a `.ALIAS_COLLISIONS`**,
lo stesso meccanismo usato il 2026-07-25 per `ml`→THPO e `cancer`→granchio.

Senza la lettura una-per-una questo caso sarebbe passato: 1 confronto su 87.092 non si vede
in nessun aggregato.

## 6ter. UNA DIPENDENZA TROVATA PRIMA DEL LANCIO: i verdetti di coerenza sono chiavati per ENTITA'

`annotate_stage4_deliverable()` attacca i verdetti di coerenza con la chiave
`entita||verso||tipo-di-controllo`, non con `cluster_id` — quindi sopravvive a un
re-cluster. **Ma la de-frammentazione cambia proprio l'entita'.**

Dei 6 verdetti in `analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv`,
cinque sono gia' ID ontologici e non si muovono. **Uno no: `STR:adenoma`.** Misurato:
`adenoma` aggancia `MeSH:D000236` in modo univoco nello spazio della classe `disease`,
quindi quel gruppo cambia chiave e il verdetto resta **orfano**.

`.annotate_coherence()` **si ferma** su un verdetto orfano — ed e' la difesa giusta:
«un verdetto che non attacca lascerebbe un gruppo incoerente marcato coerente: fallimento
silenzioso, e per giunta a favore della conclusione che fa comodo».

⚠️ **CORRETTO 2026-08-02**: qui si scriveva «Se non si fa nulla, il re-pool gira 28 ore e
poi l'annotazione fallisce (in modo non fatale: i parquet restano, il deliverable
arricchito no)» — l'annotazione NON si fermava: il chiamante pre-filtrava gli orfani e la
difesa non scattava mai — provato, il gruppo `adenoma`, che ha un verdetto di INCOERENZA,
usciva marcato `coherent`. E anche dopo il fix del pre-filtro lo `stop()` restava dentro un
`tryCatch` che lo declassava a warning. Chiuso il 2026-08-02 portando il controllo in testa
allo script (Task 7). C'e' comunque una finestra naturale per aggiornare i verdetti: il
re-cluster finisce **prima** del re-pool. Quindi, **fra i due run**:

1. si confrontano gli insiemi dei membri gruppo per gruppo (procedura 2026-07-28) e si
   rileggono **solo** i gruppi che cambiano composizione;
2. i verdetti si aggiornano **su quelli**, con la chiave nuova;
3. solo allora parte il re-pool.

Il verdetto su adenoma **non si ri-chiavizza e basta**: il gruppo puo' aver assorbito altri
membri, quindi va riletto. Ri-chiavizzarlo senza leggerlo sarebbe la stessa scorciatoia —
spostare un'etichetta invece di guardare il dato.

Gli altri tre incoerenti noti che restano fuori dal deliverable poolato (`Recurrence`,
`PTSD`, `CSF2`) non sono toccati dalla de-frammentazione; ⚠️ **CORRETTO 2026-08-02**: qui si
scriveva che tutti e tre «hanno gia' un ID ontologico» — falso per `PTSD`, che resta
`STR:ptsd` (verificato: non e' in `.CA_DEFRAG_ACCEPT` ne' in `.CA_DEFRAG_REJECT`, un ID
MeSH candidato `MeSH:D013313` esiste nella tabella d'audit ma non e' mai stato applicato).
`Recurrence` e `CSF2` hanno gia' un ID ontologico. `IL3` non si fonde perche' `il3` ha 3
caratteri.

## 8. IL GUADAGNO POOLATO — e perche' NON posso certificare i quattro numeri

Misura finale (codice con tutti i fix + la collisione `mito`): **2.192 membri cambiano
entita'**, invariante **0**, `STR:ifna` **invariato**, fusioni su taxon **6, tutte ceppi
virali corretti** (`mito` chiuso). I «ripescati» crollano da **99 a 3** — la prova che le
guardie su ombrello e nome generico ora vedono il nome. **10 membri persi**
(9 `nome_generico`, 1 `candidato_ombrello`): membri che passavano perche' quelle guardie
non avevano niente da guardare. E' l'effetto voluto, e va riportato.

| | atteso dal programma | **simulato** |
|---|---|---|
| TGF-β1 poolati | 49 → 59 | **70 → 91** |
| Glioblastoma | 2 → 3 | **2 → 5** |
| IL17A | 7 → 8 | **9 → 13** |
| `STR:ifna` | invariato | **invariato** |

> ⚠️ **LA SIMULAZIONE NON RIPRODUCE IL DELIVERABLE, e i suoi valori assoluti non vanno
> usati.** La base di partenza di TGF-β1 e' **70** dove il deliverable vero dice **49**.
> Il motivo e' strutturale: la simulazione riderivà i gruppi dalle etichette con il ramo
> **anchor disattivato** (`anchor_name = NA`), mentre il build vero lo usa; e non applica
> il partizionamento del build ne' la dedup. Il **confronto fra i due regimi resta valido**
> — stesso metodo da entrambe le parti, e la differenza e' cio' che si voleva misurare —
> ma «49 → 59» **non e' confermato**: lo confermera' solo il run.
>
> Nota: la base di Glioblastoma coincide (2), quella di IL17A no (9 contro 7). Lo scarto
> non e' uniforme, il che conferma che dipende dai rami disattivati e non da un fattore
> di scala.

**Un dato scomodo che il programma non prevedeva.** Sommando su tutti i **1.454** gruppi
la cui composizione cambia, gli studi poolati fanno **−12**, non +11. Nascono **42**
meta-analisi e ne escono **34** (saldo +8). **La de-frammentazione RIDISTRIBUISCE piu' di
quanto aggiunga**: concentra studi in gruppi piu' grandi e correttamente nominati, e
alcuni gruppi piccoli di partenza, persi i membri, scendono sotto la soglia del dispatch.

Questo **non ribalta la decisione** — l'argomento che pesa di piu' non era la potenza ma
la coerenza interna del metodo (§5 della decisione: «`TGF-beta` e `TGFb` trattate come
entita' diverse» non si puo' scrivere nei Methods) — ma va scritto cosi', senza spacciare
per guadagno una redistribuzione. **Il numero vero lo dara' il run.**

## 8bis. IL DIFETTO DEL MIO DISEGNO, TROVATO LEGGENDO L'OUTPUT VERO (2026-08-01)

Rileggendo i gruppi cambiati del run v14, il **secondo** gruppo lo dice subito:
`STR:hypoxia||gain||normoxia` passa da **37 a 33** studi, con **19 membri tolti**. Quei
membri non sono spariti: sono in `MeSH:D000860||gain||normoxia`, gruppo **NUOVO** con k=10.

> **La stessa entita' biologica finisce in DUE gruppi.** Entrambi superano k>=3, quindi
> entrambi andrebbero nel deliverable come meta-analisi distinte della stessa cosa — e la
> dedup per entita' (ADR-0022) non li prende, perche' le entita' sono formalmente diverse.

**Causa, nel mio codice:** `.ca_defrag_ontologies()` interroga ontologie **diverse a
seconda della classe del contrasto** (`disease`→MeSH, `drug`→ChEBI/ChEMBL/HGNC/taxonomia,
le altre → nessuna). Lo stesso token si risolve o no a seconda di come lo Stadio 2 ha
classificato la chiave. **E' frammentazione creata dalla regola che doveva toglierla.**

**Ampiezza misurata: 6 entita'**, 189 membri migrati:

| entita' | membri migrati |
|---|---:|
| hypoxia | 94 |
| schizophrenia | 57 |
| sepsis | 18 |
| endometriosis | 9 |
| medulloblastoma | 8 |
| smoking | 3 |

**Il fix ovvio non funziona.** Misurato: rendere l'univocita' indipendente dalla classe
bloccherebbe **52 token su 664** (178 membri su 2.192), ma quasi tutti sono casi in cui le
due entita' agganciate sono **la stessa cosa in due ontologie** — `zika_virus`
(`MeSH:D000071244` + `NCBITaxon:64320`), `vegf` (`HGNC:12680` + `MeSH:D042461`), `il17`,
`il23`, `bdnf`, `cadasil`, `r5020`. Sarebbe l'errore opposto.

**Le opzioni vere, con il loro costo:**

- **(A) tenere v14 e dichiarare** i 6 gruppi doppi fra i limiti. Costo zero, ma
  reintroduce esattamente il problema che il rework doveva chiudere — «due meta-analisi
  della stessa entita'» e' la stessa frase indifendibile di «TGF-beta e TGFb entita'
  diverse», solo su 6 casi invece che su 3.
- **(B) dare a OGNI classe l'insieme completo delle ontologie**, usando la classe solo per
  l'ORDINE di priorita' invece che per restringere. Toglie lo split per costruzione, ma e'
  un allargamento di scopo **non misurato** (classi oggi escluse comincerebbero a fondere)
  → serve rimisurare (~1 h) e **rifare il re-cluster (~9 h)**.
- **(C) univocita' su tutte le ontologie**: misurata e **peggiore** (blocca 52 token
  legittimi).

**Nessuna e' gratis, ed e' una scelta scientifica, non tecnica.** La rilettura dei 46
gruppi (FASE D0ter) e' stata **sospesa**: se si rifa' il re-cluster va rifatta da capo, e
un'ora di lettura buttata e' un'ora di lettura buttata.

## 9. ERRORI OPERATIVI DI QUESTA SESSIONE, A VERBALE

1. **Ho modificato uno script mentre era in esecuzione.** Rscript legge il file a pezzi:
   il processo ha incassato un errore di sintassi a meta' corsa. Scoperto perche' il
   monitor ha segnalato un `Error` che nel log non compariva piu': invece di accettare la
   spiegazione comoda ho confrontato PID, orari di avvio e descrittori aperti. Il processo
   compromesso girava **anche** col codice anteriore ai fix del §4 ed e' stato terminato.
2. **Un test verde che non provava nulla.** Il caso `ugml` doveva esercitare la tabella
   delle collisioni e invece non aggancia nulla: passava per la ragione sbagliata.
   Sostituito con `activin`, che aggancia `HGNC:24029` in modo univoco e con 7 caratteri,
   e viene fermato **solo** da `.is_alias_collision`.
3. **La cache del recupero-nome NON e' stata bumpata**, e la ragione e' verificata e non
   assunta: l'unica cache su disco in questo percorso alimenta l'**anchor**, e la regola
   sta nel ripiego, a valle. Bumparla costerebbe un'ora di ricostruzione per nulla.

## 10. CHE COSA QUESTO NON DIMOSTRA

- **Non dimostra che i gruppi fusi siano coerenti.** Dimostra che l'identita' e' univoca
  nell'ontologia. La coerenza dei gruppi che cambiano composizione si rilegge **dopo** il
  re-cluster, membro per membro.
- **I 12 test end-to-end si saltano nella suite completa**, dove i dizionari sono fixture:
  valgono solo lanciati sui dizionari veri (`test_file`). E' il pattern gia' in uso qui,
  non una copertura piena.
- **La soglia «>3 caratteri» e' una scelta dichiarata**, non un risultato. Con >4 si
  perderebbe `tgfb`; con >2 si riaprirebbe la classe di errori delle sigle.
