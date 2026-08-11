# PASSO 1 (parte 1) — L'ID emesso dal modello NON entra nell'identità delle 214

**Data:** 2026-08-09 · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessun commit · nessun re-cluster · nessun re-pool**

Risponde alla prima delle due domande del PASSO 1 dell'handout
`2026-08-10-correttezza-passo-passo-HANDOUT.md`: *quanti degli ID sbagliati
arrivano nel deliverable?*

**Risposta, in due righe che vanno lette insieme:**

- **ID ontologico EMESSO dal modello nell'identità delle 214: 0 su 214.** Ogni ID
  esce da un dizionario. Il modo di fallire di §3.5 dell'handout (ID esistente ma
  sbagliato, accettato senza verifica) **non raggiunge il deliverable**.
- **Entità NOMINATA dal modello (nome → dizionario → ID): 7 su 214 (3,3%).** Per
  quelle sette l'identità c'è perché Mistral ha proposto un nome, e senza quel
  canale il ramo che le produce non poteva neppure accendersi.

⚠️ **Due revisori ostili hanno demolito la prima stesura di questo documento.** La
proposizione letterale regge; **la prova con cui la sostenevo era invalida** (§4.1)
e la conclusione implicita «nessun canale del modello determina l'identità» è
**falsa** (§4.2). Sotto, tutto ciò che è caduto, rimisurato in modo indipendente.

---

## 1. La catena, letta nel codice

L'entità che forma le 214 (`contrast_entity`) nasce in
`.ca_member_contrast()` (`R/stage3-contrast-anchor.R:704-721`) da **quattro rami
mutuamente esclusivi**, registrati in `contrast_entity_source`:

| ramo | da dove viene l'identità | l'ID del modello può entrare? |
|---|---|---|
| `anchor` | `anchor_id = tm$agent_id_resolved` (`R/stage3-build.R:619`) | **SÌ** — è l'unico canale |
| `onto` | `.ca_resolve_entity()` sui `factor_levels` e le etichette | NO — non riceve mai l'ID |
| `defrag` | token ripulito agganciato a un alias univoco >3 caratteri | NO |
| `STR` | ripiego testuale | NO |
| `COMBO` | parti risolte dal testo | NO |

Il ramo `anchor` è per di più condizionato: scatta solo se **tutti** i token
distintivi del nome canonico dell'anchor compaiono nei valori del braccio
trattato (`.cg_matches_all_words`).

### Perché il primo membro basta, e la misura è esatta e non approssimata

`ct_chr()` (`R/stage3-build.R:893-898`) porta al cluster il valore del **primo
membro soltanto**. Questo non degrada la misura, per un motivo strutturale:

> l'entità è **nella chiave del cluster** (`anchor_key = entità||verso||controllo`),
> quindi è identica per tutti i membri. Se il primo membro l'ha ottenuta da un
> ramo testuale (`onto`/`defrag`/`STR`/`COMBO`), quell'entità **è derivabile dal
> solo testo**, qualunque cosa abbiano fatto gli altri membri.

Resta da controllare unicamente il ramo `anchor`, e per quelle righe
`resolution_source` descrive **lo stesso membro**. La misura è quindi esatta.

## 2. Il secondo canale LLM: il recupero-nome

`recovery_source == "LLM_NAME_CLEANUP"` su **59/214 (27,6%)**; l'identità è
sostituita dal recupero su **79/214**. Verificato nel codice
(`R/stage3-name-cleanup-overlay.R:75`, `R/name-cleanup.R:400,451,460`):

```r
new_id = pol$new_id            # = resolution$resolved_id
res <- .resolve_canonical_to_id(out$canonical_name, ckind, env)
```

**Mistral emette un NOME (`canonical_name`) e un `kind`, mai un ID.** L'ID lo
produce sempre un dizionario, e solo con `match_strength == "STRONG"` e
`confidence != "low"`. Questo canale non può quindi trasportare il modo di
fallire di §3.5 (ID numerico esistente ma sbagliato, accettato senza verifica).

## 3. Lo strumento, e come è stato validato

> ⚠️ **Questa sezione è la SECONDA stesura.** La prima è stata sottoposta a un
> revisore ostile incaricato di falsificarla coi dati; ha trovato **sei difetti,
> tutti veri e tutti rimisurati qui in modo indipendente**. La conclusione di §4
> non è toccata; la classificazione con cui era argomentata sì. I difetti sono
> elencati con il loro numero in §8, non nascosti in una revisione silenziosa.

I **17** valori di `resolution_source` osservati nei 322.415 cluster (non 16: era
un errore di conteggio mio) sono classificati leggendo il **sito di emissione**
di ciascuno — non a memoria: il primo elenco, fatto con un `grep` sulle stringhe
letterali, era cieco sui valori costruiti via `src <- if (...) "A" else "B"` e ne
perdeva sei.

| classe | significato — **criterio: il NUMERO del modello entra nell'identità** | valori |
|---|---|---|
| **A** | sì, il numero emesso dal modello diventa l'identità (eventualmente tradotto in un altro spazio-ID) | `CHEBI_DIRECT`, `CHEBI_SECONDARY_REDIRECT`, `HGNC_DIRECT`, `HGNC_ENTREZ_MAPPED`, `WRONG_DB_to_HGNC`, `MESH_DIRECT` |
| **A′** | sì, **e senza alcun supporto di dizionario** | `MESH_NAKED_NOLOOKUP` |
| **B** | no: l'ID viene da un **testo** risolto sui dizionari | `STRING_ALIAS_CHEBI`, `STRING_ALIAS_HGNC`, `STRING_ALIAS_MESH` |
| **C** | no: nessun ID ontologico dal *resolver* (⚠️ vedi il limite qui sotto) | `NO_AGENT`, `STRING_NO_ALIAS_MATCH`, `HALLUCINATED_OR_FALLBACK`, `LLM_VEHICLE_LITERAL`, `DISEASE_NO_MESH_UI`, `MEDIATED_STR_NO_LOOKUP` |
| — | fuori dalle classi, dichiarato | `CHEMBL_NAKED_NOLOOKUP` (20 cluster, nessuno fra le 214) |

⚠️ **Il criterio NON è «l'ID esiste nel dizionario»**, come diceva la prima
stesura. È falso per **4.523 cluster su 67.478 di classe A/A′ (6,7%)**:
- `MESH_NAKED_NOLOOKUP` (389 cluster, 23 UI distinti): **0 su 23 esistono** nei
  30.956 descrittori MeSH. Sono accettati sulla sola **forma** `^D[0-9]{6}$`
  (`R/stage3-anchor-levels.R:91-92`, il commento lo dichiara). Il più frequente,
  `D015585`, entra in 119 cluster. Per questo ha una classe propria, più severa.
- `HGNC_ENTREZ_MAPPED` (3.388): il numero non è un HGNC valido, è un Entrez.
- `WRONG_DB_to_HGNC` (746/746): il modello dichiara un composto ChEBI e l'esito è
  un **gene umano**. Rimisurato: 746 su 746 cambiano tipo di entità.

### La validazione, e dove NON vale

Osservabile: il numero nudo di `agent_id_llm_original` coincide con quello di
`agent_id_resolved`?

| classe | n | coincide |
|---|---:|---:|
| A + A′ | 67.478 | **90,2%** |
| B | 38.326 | **0,0%** |
| C | 216.980 | 11,4% |

- **Caso positivo:** `CHEBI_DIRECT` 0/26.524 discordanti, `HGNC_DIRECT` 0/27.958.
- **Caso negativo (quello che pesa):** tutti e tre gli `STRING_ALIAS_*` → **0,0%**.
- Il 90,2% invece di 100% ha **tre** cause, non due: `CHEBI_SECONDARY_REDIRECT`
  3.021 + `HGNC_ENTREZ_MAPPED` 3.388 + **`WRONG_DB_to_HGNC` 151** (il ramo Entrez
  dentro `.try_hgnc_int`). La terza mancava nella prima stesura. Somma esatta:
  6.560 disallineamenti.

⚠️ **Tre limiti dell'osservabile, tutti rimisurati:**

1. **È tautologico su tutto il ramo MeSH.** `R/stage3-anchor-levels.R:85` assegna
   `agent_id <- paste0("MeSH:", mesh_raw)` **prima** del lookup e la riga 131
   assegna `agent_id_raw <- mesh_raw`: l'uguaglianza è per costruzione. Prova
   decisiva: `MESH_NAKED_NOLOOKUP`, che è *definito* dal **fallimento** del
   lookup, dà anch'esso **389/389 = 100,0%**. Un osservabile che vale 100% sia
   quando il lookup riesce sia quando fallisce non misura nulla lì.
2. **Il controllo negativo di classe B è vacuo dove il modello non ha emesso
   alcun numero** (confrontare una parola con un numero dà 0% per aritmetica).
   Righe in cui un ID numerico c'era davvero ed è stato **scartato**:
   `STRING_ALIAS_CHEBI` 3.565/20.611 (17,3%), `STRING_ALIAS_HGNC` 3.440/11.851
   (29,0%), `STRING_ALIAS_MESH` 279/5.864 (4,8%) → **7.284 su 38.326 = 19,0%**.
   Su quelle 7.284 il controllo è reale; sull'81% restante non dice niente.
   ⚠️ Ho sbagliato **due volte** questo metro prima di azzeccarlo: «qualunque
   cifra nella stringa» dava 48,6% (`IL-6` contava), e
   `^[A-Za-z]{0,10}:?[0-9]+$` dava 41,2% perché accetta `RIPK1`, `KEAP1`,
   `LINC00942` — i simboli genici sono lettere seguite da cifre. Il metro finale
   pretende i due punti (`^[0-9]+$` oppure `^[A-Za-z]+:[0-9]+$` oppure
   `D[0-9]{6}$`) ed è validato su 10 casi di accettazione, 4 positivi e 6
   negativi.
3. **Nella classe C un'uguaglianza non significa «ID accettato»** ma «il testo del
   modello conservato come `STR:`» (il confronto toglie il prefisso).

### ⚠️ Difetto più grave, e non è mio: `resolution_source` è STALE per il 40,1% dei cluster

Il recupero-nome sovrascrive `tm$agent_id_resolved` e `tm$canonical_name` **ma non
`tm$resolution_source`** (`R/stage3-anchor-levels.R:281-288`): l'etichetta resta
quella di una risoluzione poi scartata.

Rimisurato: **129.400 cluster (40,1%) hanno l'identità sostituita dal recupero**.
Prova che non ammette repliche: **12.788 cluster hanno `agent_id_resolved` con
prefisso `NCBITaxon:`**, che `resolve_agent_canonical()` non può emettere in
nessun ramo — e tutti e 12.788 portano un'etichetta di classe C. In totale
**101.776 cluster di classe C (46,9%) portano un ID ontologico forte.**

Conseguenza per la classificazione: la classe C va letta come «il **resolver** non
ha prodotto un ID», non «non c'è un ID». Non tocca §4 — lì il ramo `anchor` con
`NO_AGENT` è già attribuito al recupero-nome, e il recupero non trasporta ID del
modello (§2) — ma rende la tabella di questa sezione una classificazione **di
scopo**, non una descrizione dello stato finale dell'identità.

### Verifica esterna, che chiude la circolarità

Le due colonne confrontate sopra sono prodotte dallo stesso codice che sto
classificando. Il revisore ostile ha rifatto la verifica **dal JSONL grezzo dello
Stadio 1** (508.037 record, 531.380 righe-perturbazione), fuori dalla pipeline:
per `CHEBI_DIRECT` il 100,0% dei valori compare **verbatim** come stringa `id` nel
JSONL; per tutti e tre gli `STRING_ALIAS_*` lo 0,0% è conservato. Prova diretta
che il ramo B ignora l'ID: lo stesso `id` del modello `CHEB:27956` produce **9
identità distinte su 98 cluster** (idarubicina, zidovudina, ketoconazolo,
talidomide, mifepristone, lomustina, melfalan…).

## 4. Il risultato, e le due cose che sono cadute

| | n | su | |
|---|---:|---:|---|
| righe del deliverable con entità dal ramo `anchor` | 34 | 214 | 15,9% |
| di queste, con `resolution_source` in classe A/A′ | **0** | 34 | **0,0%** |
| **entità delle 214 prese da un ID EMESSO dal modello** | **0** | **214** | **0,0%** |
| **entità delle 214 NOMINATE dal modello** (overlay Mistral) | **7** | **214** | **3,3%** |

### 4.1 ⚠️ La prova era invalida: `resolution_source` non può testimoniare

`R/stage3-anchor-levels.R:276-287`: quando il recupero-nome adotta un'identità
sovrascrive `tm$agent_id_resolved` e `tm$canonical_name` **e lascia
`resolution_source` intatto**. La condizione di adozione scatta su `agent_id ==
"UNK"` o su `STR:` + ID forte — cioè **esattamente** sugli esiti che producono
`NO_AGENT` e `STRING_NO_ALIAS_MATCH`, i due valori che la prima stesura citava
come garanzia. Erano la firma della porta d'ingresso, non la prova che fosse chiusa.

Rimisurato: **17 delle 34 righe `anchor` (50,0%) hanno `agent_id_recovered == TRUE`**,
cioè l'ID che finisce in `contrast_entity` è stato scritto dal recupero **dopo**
che `resolution_source` era già fissato.

E il vincolo che rende la cosa strutturale: `NO_AGENT` impone
`canonical_name = NA` (`R/stage3-anchor-levels.R:102-103`) mentre il ramo `anchor`
richiede `!is.na(anchor_name)`. Verificato sui 174.016 cluster `NO_AGENT`: quelli
con un nome canonico sono **115.136, e tutti e 115.136 hanno
`agent_id_recovered == TRUE`** — nessuna eccezione. **Senza il recupero, su una
riga `NO_AGENT` il ramo `anchor` non può accendersi affatto.**

### 4.2 Sette meta-analisi la cui entità è quella che Mistral ha nominato

| cluster | entità | etichetta | k_eff | n_sig | verdetto |
|---|---|---|---:|---:|---|
| `cgroup_L5_b2affd22` | `MeSH:D011225` | Pre-Eclampsia | 6 | 2.461 | coherent |
| `cgroup_L5_8c9339f5` | `NCBITaxon:64320` | Zika virus | 5 | 3.133 | coherent |
| `cgroup_L5_3f0cc1fe` | `MeSH:D003093` | Colitis, Ulcerative | 4 | 555 | coherent |
| `cgroup_L5_387b0d1a` | `MeSH:D003922` | Diabetes Mellitus, Type 1 | 3 | 180 | coherent |
| `cgroup_L5_6b7b8076` | `MeSH:D000077273` | Thyroid Cancer, Papillary | 3 | 3.491 | coherent |
| `cgroup_L5_6ee86f02` | `MeSH:D013167` | Spondylitis, Ankylosing | 3 | 348 | coherent |
| `cgroup_L5_debadb13` | `NCBITaxon:10407` | hepatitis B virus | 3 | 23 | coherent |

**L'ID resta prodotto da un dizionario**, non emesso dal modello: verificato che su
53.892 righe `override` **zero** hanno un `new_canonical` o un
`llm_proposed_name` a forma di ID, e che su 3.403 triple uniche
`(new_canonical, new_kind, new_id)` **3.402 si riproducono esattamente**
rieseguendo `.resolve_canonical_to_id()`. L'unica non riproducibile (`HGF` →
`HGNC:4893` allora, `HGNC:6018` oggi: la collisione di alias già nota del
2026-07-25) **non è entità di nessuna delle 214**.

**Ampiezza del danno, misurata con un controfattuale** (ricalcolo di
`.ca_member_contrast(anchor_name = NA, anchor_id = NA)` sui 114 record veri dei 7
cluster): l'entità resta raggiungibile **dal solo testo** in tutti e sette. Cambia
la **composizione**: preeclampsia 24/24 membri, tiroide 11/11, colite 41/46,
epatite B 8/9, diabete 3/4, spondilite 2/3, e **Zika 7 su 17** — gli altri 10
cadrebbero su `STR:zika_virus_infection` / `STR:zika_virus` / `STR:zika`.
**Su Zika il modello non ha scelto l'identità, ma ha tenuto insieme il gruppo.**

### 4.3 Il resto del ramo `anchor`, e il corpus intero

Le 34 righe `anchor`: `NO_AGENT` 16 (tutte con identità dal recupero),
`STRING_ALIAS_CHEBI` 14, `STRING_NO_ALIAS_MATCH` 3, `LLM_VEHICLE_LITERAL` 1.
Nessuna in classe A/A′ — questo fatto resta esatto; è l'inferenza che ne traevo a
essere caduta.

Le **55** righe del deliverable il cui *anchor* è di classe A esistono, ma la loro
entità viene da un altro ramo: `onto` 50, `STR` 4, `COMBO` 1.

**Sull'intero corpus dei cgroup** il canale esiste ed è misurabile: 724 cluster su
11.536 hanno l'entità dal ramo `anchor`, e **4** di quei 724 hanno anche l'anchor
di classe A — `CHEBI:17234` glucosio, `CHEBI:29105` zinco(2+), `CHEBI:15361`
piruvato e un quarto, tutti con k ≤ 3 e **nessuno nel deliverable**. Nei quattro
casi, per giunta, l'ID del modello è quello **giusto**.

## 5. Che cosa questo NON dice

- **Non dice che le identità delle 214 siano corrette.** Dice che non sono
  corrotte *da quel meccanismo*. Restano aperti due modi di sbagliare diversi:
  (a) il modello propone un **nome** sbagliato e il dizionario lo risolve
  fedelmente; (b) il testo è ambiguo (`alcohol`) e il dizionario sbaglia da solo.
  §3.5 dell'handout dichiara già (b) come limite proprio.
- Non misura quante delle 214 abbiano un'entità sbagliata *per qualunque causa*:
  è la parte 2 del PASSO 1 e richiede il confronto con il testo dei membri.
- 47 righe su 214 (22,0%) hanno un'entità `STR:` — nessun ID ontologico affatto.
  Non è un errore di identità, è un'identità assente, e va dichiarata a parte.

## 6. Conseguenza per il PASSO 2

La correzione proposta nel PASSO 2 (far verificare al resolver la **coerenza**
dell'ID col testo, non solo l'esistenza) **non cambierebbe nessuna delle 214
entità per via diretta**: nessuna ne dipende.

Può però cambiarle **per via indiretta**, e l'ampiezza è delimitata e misurabile:
correggere l'ID cambia anche `canonical_name`, che è l'ingresso della guardia
`.cg_matches_all_words` del ramo `anchor`. Le 55 righe di classe A sono il
perimetro massimo dell'effetto. Va misurato prima di essere deciso.

L'handout definisce il PASSO 2 «il cambiamento più invasivo del programma».
Sui dati, **il suo perimetro è al più 55 righe su 214, per via indiretta, e zero
per via diretta.**

## 7. Previsioni depositate ed esito

Depositate in `scratchpad/previsione-passo1.md` prima di qualunque conteggio.

| previsione | attesa | misurata | |
|---|---|---|---|
| P1 `anchor` | 35–55% | **15,9%** | **falsificata** |
| P1 `onto` | 30–50% | **65,0%** | **falsificata** |
| P1 `STR` | 5–15% | 17,8% | **falsificata** |
| P1 `defrag` | 0–5% | 0,0% | centrata |
| P1 `COMBO` | 0–5% | 1,4% | centrata |
| P2 — % delle 214 con entità sbagliata alla radice | 3–10% | **non ancora decidibile** | vedi sotto |
| P3 — accordo coi dizionari dentro il ramo `anchor` | >80% | non applicabile: 0 righe di classe A | non decidibile |
| P4 — `CHEBI_DIRECT` >50% dei cluster con ID ChEBI | >50% | 39/96 = **40,6%** (primo membro, 214) | **falsificata** |

⚠️ **P2 NON è centrata né falsificata, ed è importante non dichiararla chiusa.**
Ciò che è misurato è che **0/214** prendono l'entità da un ID emesso dal modello.
Non è la stessa cosa di «l'entità è giusta»: quella richiede di leggere i **44
gruppi** che il censimento di §8 ha filtrato, e nessuno è stato letto. Chiamare
P2 «falsificata a 0%» sarebbe confrontare due grandezze diverse — la trappola
n.11 dell'handout.

**Quattro falsificate su otto, due non decidibili, due centrate.** Le falsificate
vanno tutte nella stessa direzione: avevo sottostimato quanto il deliverable
ri-risolva l'identità dal testo.

## 8. Il censimento «l'ID promette un nome: compare nei membri?»

Strumento: `analysis/audit/2026-08-09-passo1/40-id-vs-membri-v15.R`, port su v15 di
quello del 2026-07-28 (che su v13 diede 303 giusti / 1 sbagliato / 1 parziale),
cicatrice inclusa — un match su una **sigla** (≤4 caratteri) non prova l'identità,
perché è la forma delle collisioni note (`LTA` = sia il tripeptide Leu-Thr-Ala sia
l'acido lipoteicoico; `ml` → THPO; `cancer` → granchio).

⚠️ **Trappola disinnescata da un caso di accettazione.** In v13 il `record_id` era
`sid__comparison_id`; da v15 è `sid__comparison_id__n`. Il port ingenuo non
aggancia **nessun** membro e produrrebbe «senza membri risolti» su tutto — un
numero dall'aria plausibile, prodotto da uno strumento cieco. Lo script replica il
contatore `cmp_seen` della produzione e **si ferma** se la copertura è sotto il 98%.
Misurata: **5.786/5.786 = 100,00%**.

| esito | 351 candidati | 214 poolate |
|---|---:|---:|
| nome per esteso trovato nei membri | 290 | **170 (79,4%)** |
| solo una sigla | 52 | **38 (17,8%)** |
| nessun nome trovato | 9 | **6 (2,8%)** |

**Stratificato per ramo — la circolarità resa visibile invece che nascosta.** Il
controllo è parzialmente circolare sul ramo `onto` (lì l'entità è stata risolta da
quel testo), non lo è sul ramo `anchor` (identità importata):

| ramo | nome per esteso | solo sigla | nessun nome |
|---|---:|---:|---:|
| `anchor` (identità importata — **non circolare**) | **33** | **0** | 1 |
| `onto` (parzialmente circolare) | 110 | 24 | 5 |
| `STR` | 25 | 13 | 0 |
| `COMBO` | 2 | 1 | 0 |

I 38 «solo sigla» sono in maggioranza allarmi attesi, dove la sigla **è** l'entità:
LPS (k=50), DHT (34), H₂O₂ (20), THZ1 (18), IL-13 (15), IL-4 (14), EGF (12),
IL-6 (10), ATRA (9), PMA (8), TCDD (7), NASH (7). I 6 «nessun nome trovato» sono
5 patogeni (la tassonomia usa il binomio latino, gli studi scrivono `CMV`, `flu`,
`HIV`, `Mtb`) e `HGNC:5434` (IFNB1).

**44 gruppi del deliverable restano da leggere a mano** (360 studi-slot). Il
censimento **non è un verdetto: è un filtro.** Nessuno dei 44 è stato giudicato.

## 9. I difetti trovati dai revisori ostili — tutti veri, tutti rimisurati

Sei del primo revisore, uno del secondo. Nessuno è stato accettato sulla parola.

| # | difetto | rimisurato |
|---|---|---|
| 1 | `resolution_source` è **stale** rispetto a `agent_id_resolved`: il recupero riscrive il secondo e non il primo | **129.400 cluster (40,1%)**; 12.788 con `NCBITaxon:`, prefisso che il resolver non può emettere; **101.776 di classe C (46,9%) portano un ID forte** |
| 2 | La mia **prova** per il ramo `anchor` era invalida (§4.1) | 17/34; 7 dall'overlay Mistral; 115.136/115.136 |
| 3 | `MESH_NAKED_NOLOOKUP` in classe A, ma quell'ID non esiste da nessuna parte | **0 su 23** UI presenti nei 30.956 descrittori MeSH → classe A′ propria |
| 4 | Il 100% di `MESH_DIRECT` è **tautologico** (`agent_id` assegnato prima del lookup) | vale 100% anche dove il lookup **fallisce**: 389/389 |
| 5 | Il 90,2% ha **tre** cause, non due | 3.021 + 3.388 + **151** = 6.560 esatti |
| 6 | Il controllo negativo di classe B è vacuo dove non c'era un numero | reale su **7.284/38.326 = 19,0%** (e ho sbagliato il metro due volte: 48,6% e 41,2%) |
| 7 | Ho contato **16** valori invece di 17 | 17 |

**Rimedio proposto, una riga, non argomentativo** — `R/stage3-anchor-levels.R:282-286`:

```r
tm$resolution_source <- paste0("RECOVERY_", recovery$recovery_source)
```

così il campo smette di mentire. **Non applicato**: tocca la provenienza registrata
di 129.400 cluster ed è una decisione dell'utente.

## 10. Riproducibilità

Misure in `scratchpad/misura-01-rami.txt`, `-02-validazione.txt`, `-03-risposta.txt`.
Nessun numero di questo documento viene da un agente. Denominatori: 214 =
`deliverable-annotato.rds` (v15 `d29545c7`); 11.536 = cluster `mode=="cgroup"`;
322.415 = tutti i cluster (Stadio 3 v15 `7f986159`).
