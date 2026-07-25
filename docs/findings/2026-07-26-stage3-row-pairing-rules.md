# Righe mal appaiate dentro i gruppi coerenti: quattro regole, misurate e messe in produzione

**Data:** 2026-07-26 · **Branch:** `review-scientific-consistency-2026-06-10`
**Stato:** 🟡 **Regole implementate nel codice di pacchetto con TDD e misurate su TUTTI i gruppi.
Nessun re-cluster, nessun re-pool: niente e' materializzato.**

---

## 1. Il problema

Il gruppo dice **che cosa** si misura; la riga dice **come** e' stato confrontato. Un gruppo puo'
essere coerente — tutti gli studi misurano la stessa entita' — e contenere lo stesso confronti mal
appaiati: il trattato a 24 ore contro il controllo a 0 ore, il farmaco su una linea cellulare contro
il veicolo su un'altra, la modifica genetica presente su un braccio solo.

La verifica riga per riga dei 143 gruppi coerenti (2026-07-25) ne aveva contate **96 su 1.851 (5,2%)**.
**Decisione utente:** si scartano, accettando di perdere i gruppi che scendono sotto i 3 studi.

## 2. Le quattro regole (deterministiche, nessuna lista di righe)

| regola | quando scatta | esempio reale |
|---|---|---|
| `tempo_non_appaiato` | entrambi i bracci dichiarano un tempo, nessuno in comune (normalizzati in ore) | `H1650_osimertinib_1day` vs `H1650_DMSO_4hr` |
| `soggetto_diverso` | donatori dichiarati diversi, **oppure** codici di linea diversi anche nei numeri — **solo nei disegni di trattamento** | `Erlotinib MSN08` vs `DMSO MSN01` |
| `genetica_asimmetrica` | marcatore genetico esplicito su un braccio solo, e la genetica non e' l'entita' del gruppo | `+ shMfn2 + TNF` vs `+ DMSO` |
| `combinazione_non_vista` | ≥2 agenti risolti nel trattato assenti dal controllo, e il gruppo non e' gia' una combinazione | `TNF-α IL-1α` vs `Control` |

Vincoli espliciti, tutti derivati da falsi allarmi **misurati**:

- Nei **caso-controllo di malattia** i soggetti sono per forza persone diverse: la regola del
  soggetto non si applica (decisione utente). Vale anche per i caso-controllo clinici travestiti da
  trattamento (`HIV-positive Subject 14` vs `Subject 12 (HIV-negative)`).
- Codici il cui **insieme di numeri coincide** designano lo stesso soggetto in due condizioni
  (`LS4` lung-SARS / `LM4` lung-mock): appaiati, non difettosi.
- Identificatori di **archivio** (`GSM4711203`) e **anagrafici** (`39-year-old`) non sono linee.
- `wild-type` non e' un marcatore genetico: dice che una modifica **non** c'e'.

## 3. Cinque bug MIEI, trovati misurando

Il primo rilevatore segnalava 186 righe di cui 96 vere (precisione 52%). Le cause dello scarto non
erano ambiguita' dei dati ma difetti del mio codice:

1. **`_` e' carattere di parola** per le espressioni regolari: `\bsirna\b` non vedeva
   `Control_siRNA_1`, `10day` dentro `osimertinib_10day` non era un tempo, `MSR-A549_JQ1` era un
   codice diverso da `MSR-A549_DMSO`. (Stesso inciampo gia' pagato su `calcium_low`.)
2. **L'espressione regolare dei codici** pretendeva la cifra nel primo segmento: perdeva
   `CWR-22Rv1` — un difetto vero non visto.
3. **Un solo token condiviso annullava la segnalazione**: `Donor1 HBV D6` vs `Donor2 Mock D6`
   passava perche' `D6` era in comune. Le due categorie (soggetti, codici) vanno confrontate separate.
4. **La stoplist conteneva il candidato grezzo** del resolver — che spesso e' l'intera etichetta del
   trattato: disinnescava la regola in silenzio (`CaCO2` vs `HRT18` non veniva visto).
5. **Soglia sui token** che scartava `TNF-` e `IL-1` (3 caratteri alfanumerici): la combinazione
   `TNF-α IL-1α` non veniva riconosciuta.

Piu' due falsi allarmi da collisione di alias: `mitoxantrone (MIT)` contava due agenti (`MIT` risolve
a 3-iodo-L-tirosina) e `IAV (H1N1)` pure. Regola generale: una sigla che e' **prefisso di un'altra
parola della stessa etichetta** non e' un secondo agente; i sierotipi non sono agenti distinti.

## 4. Numeri (misurati, non stimati)

**Sulle 1.851 righe dei gruppi coerenti** — le stesse gia' verificate a mano:

| | valore |
|---|---:|
| righe segnalate dalle regole | **139 (7,5%)** |
| di cui giudicate a mano difetti veri | **139 / 139** |
| ripartizione | tempo 73 · soggetto/linea 49 · genetica 13 · combinazione 4 |
| segnalazioni del primo rilevatore | 186, di cui 96 vere (52%) |

Le 43 righe in piu' rispetto alle 96 della verifica precedente **non sono un allargamento del
criterio**: sono difetti che il primo rilevatore non poteva vedere (tempi dentro gli underscore in
`GSE165019` e `GSE229119`, linee diverse in `GSE186341`, `CWR-22Rv1` in `GSE97204`).

**Sul corpus intero** (38.440 membri): **2.713 membri scartati (7,1%)**, pari a **1.109 confronti
distinti** (studio, trattato, controllo).

**Sul deliverable:**

| | v9 | v10 (con le regole) |
|---|---:|---:|
| gruppi poolabili k≥3 | 145 | **144** |
| gruppi coerenti | 143 (98,6%) | **141 (97,9%)** |
| studi-slot nei coerenti | 890/896 | 866/875 |

Persi 2 gruppi scesi sotto i 3 studi (bosutinib `CHEBI:39112`, RSV `NCBITaxon:12814||uninfected`),
esattamente come previsto. Comparso 1 gruppo nuovo — la dedup per entita' ha promosso la variante
peggiore di RSV, che mescola infezione clinica e sperimentale: **giudicato incoerente**.

**Metodo del censimento:** i 108 gruppi con composizione identica a v9 conservano il verdetto
precedente; i **36 con composizione cambiata o nuovi sono stati riletti uno per uno**
(`v11-cambiati.txt`, contrasti tenuti e scartati affiancati). Nessun campione.

## 5. Codice di produzione

**Due moduli, entrambi scritti test-first.**

`R/stage3-contrast-gate.R` (nuovo) — le regole del gate che finora vivevano nello script d'analisi:
token generici, induttori, verso del delta, anatomia e sinonimi d'organo, materiale del braccio,
contrasto rotto, baseline propria, infezione clinica vs sperimentale, resistenza asimmetrica,
controlli non validi, delta multiclasse, nomi-ombrello, entita' on-contrast.
`tests/testthat/test-stage3-contrast-gate.R`: **102 PASS / 0 FAIL**.

**Equivalenza verificata sui dati veri** (`108-equivalenza-gate.R`, 19.863 etichette / 38.440
contrasti): 11 regole su 16 danno risposta identica allo script; le altre differiscono in **624
casi**, e in ogni caso la versione di pacchetto e' quella corretta — lo script non vedeva oltre un
underscore (`_doxycycline` non era un induttore, `Baseline_Control` non era una baseline,
`CON_1_input` non era un controllo di saggio, `Patient_081` non era un contesto clinico) — piu'
`pulmonary` aggiunto al vocabolario anatomico.

Il gate e' stato quindi **rimisurato col codice di produzione** (`109-fase1-v11-gate.R`): **stessi
144 gruppi, composizione identica, 0 gruppi da rileggere**. Le 624 differenze agiscono su cluster
fuori dal deliverable o su membri gia' scartati per altre ragioni. I numeri riportati sono quelli
del codice che verra' eseguito, non di uno script divergente.

`R/stage3-row-pairing.R` (nuovo) — `.rp_time_hours`, `.rp_identifiers`, `.rp_subject_mismatch`,
`.rp_has_genetic_marker`, `.rp_genetic_asymmetry`, `.rp_agents`, `.rp_uncaptured_combination`,
`.rp_row_defect`. Scritto **test-first**: `tests/testthat/test-stage3-row-pairing.R`, **67 PASS /
0 FAIL**, ogni caso e' una riga vera (scartata o tenuta), nessun esempio inventato.

**Bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` v6 → v7.** Le guardie del resolver erano entrate in
produzione il 2026-07-25 **senza bump**: il prossimo re-cluster avrebbe riusato il lookup vecchio,
l'errore che e' gia' costato 8 ore.

## 6. Limiti dichiarati

- **Nomi di linea senza cifre** (`VCaP`, `LNCaP`, `HeLa`) non sono identificatori per la regola:
  `LAPC4_ENZA` vs `VCaP_DMSO` resta dentro. Servirebbe un vocabolario di linee cellulari — cioe' una
  lista, non una regola.
- **Varianti resistenti** (`U251TR` vs `U251MG`) hanno gli stessi numeri e sono trattate come
  appaiate. Il gate ha una regola separata sulla resistenza, che pero' cerca la parola `resistan`.
- **Tempi senza numero** (`H1975_osimertinib_day`) e **scritti al contrario** (`D8` vs `D13`) non
  sono letti come tempi; i secondi vengono comunque scartati, ma sotto la regola del soggetto.
- La regola sulla combinazione vede solo agenti che **risolvono a un ID canonico**: `LPS 24h + BG 24h`
  (beta-glucano) resta dentro.
- Le regole vivono in `R/`, ma **non sono ancora innestate nel build dello Stadio 3**: quello richiede
  i record group derivati dal contrasto (opzione B della spec) ed e' il passo successivo.

## 7. Riproducibilita'

`analysis/audit/2026-07-24-anchor-coherence-sim/`:
`regole-riga.R` (prototipo) → `102-regole-riga-misura.R` (misura sulle 1.851 righe) →
`103-fase1-v10-gate.R` (gate con le regole) → `105-delta-v9-v10.R` (che cosa cambia) →
`106-bundle-cambiati.R` (i 36 da rileggere) → `107-census-v11-final.R`.
Tabelle: `regole-riga-esito.csv`, `regole-riga-segnalate.txt`, `v11-cambiati.txt`,
`v11-census-verdicts-FINAL.csv`.

---

## 8. Addendum — quanto varrebbe il ri-mappaggio delle sigle bloccate (misurato)

Domanda dell'utente: le guardie rifiutano senza ri-mappare (`5-FU` resta senza nome invece di
diventare `CHEBI:46345`). Quanto si recupererebbe ri-mappando?

Misura (`analysis/audit/2026-07-25-resolver-alias-audit/98-remap-impatto.R`), sui contrasti
ricostruiti, contando i membri il cui braccio trattato nomina la sigla a parola intera e che oggi non
hanno un'entita' canonica:

| alias | bersaglio giusto | membri | studi | il bersaglio e' gia' poolabile |
|---|---|---:|---:|---|
| `tpa` | CHEBI:37537 forbolo estere | 15 | 2 | no |
| `lap` | CHEBI:49603 lapatinib | 19 | 2 | **si'** |
| `hgf` | HGNC:4881 HGF | 6 | 2 | no |
| `5fu` | CHEBI:46345 5-fluorouracile | 4 | 1 | no |
| `shh` | HGNC:10848 SHH | 5 | 1 | no |
| `dha` | CHEBI:28125 acido docosaesaenoico | 1 | 1 | no |
| `mek`, `nmda`, `mit`, `tpo`, `5-fu` | — | 0 | 0 | — |

**Gruppi poolabili nuovi (k≥3): 0. Rafforzamenti: 1** (lapatinib, gia' poolabile). 50 membri in
totale. Le sigle bloccate piu' frequenti in assoluto — `cancer`→Neoplasms (354 campioni), `ifn`→IFNA1,
`ml`→THPO — **non sono ri-mappabili per principio**: sono termini-ombrello, nomi di famiglia e unita'
di misura, non entita'.

**Limite della misura:** e' fatta sui contrasti ricostruiti (38.440 membri), non sull'intero corpus.
I 1.990 campioni che perdono il nome fuori dai contrasti non producono comunque meta-analisi: il loro
effetto sarebbe solo su etichette di cluster k=1/k=2.

**DECISIONE UTENTE (2026-07-26): NO al ri-mappaggio (opzione A).** Le guardie continuano a
rifiutare senza proporre il nome giusto. Motivo: il guadagno misurato sul prodotto scientifico e'
nullo, e ri-mappare significherebbe asserire un'identita' per inferenza — l'errore d'origine. Si
potra' riaprire dopo il re-cluster, se le etichette delle figure lo richiederanno.

**Conseguenza:** il ri-mappaggio non cambia il deliverable. Se si fara', andra' fatto come tabella
curata e versionata coi dizionari (lo stesso trattamento delle 71 coppie di collisione), non come
inferenza automatica — ma non e' sulla strada critica. **Decisione dell'utente in attesa, con questi
numeri in mano.**
