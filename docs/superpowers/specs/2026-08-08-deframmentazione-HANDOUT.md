# HANDOUT — La deframmentazione: la stessa cosa contata due volte

**Scritto:** 2026-08-08 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Sequenza dei problemi scientifici aperti (decisione utente 2026-08-08):**
**1) deframmentazione ← questa sessione · 2) validazione esterna · 3) confronto con RummaGEO**

> **Questo file è autosufficiente.** Non serve leggere le conversazioni precedenti.

---

## 0. Il problema, in una frase

Nel deliverable la stessa entità biologica compare più volte sotto scritture diverse, e ogni
copia si porta via una parte degli studi: invece di una meta-analisi forte ne abbiamo due
deboli. Non è un errore di contrasto — i gruppi sono internamente puliti — è **potenza
buttata**.

L'esempio più netto, contato oggi sul deliverable v15: `radiation` con 7 studi e `irradiation`
con altri 7. Sono la stessa cosa. Al loro posto ci sarebbe una meta-analisi da 14.

---

## 1. Che cosa è già stato fatto, e perché non basta

| quando | che cosa è stato chiuso | esito |
|---|---|---|
| v13 (2026-07-28) | i **tipi di controllo** tenuti separati pur essendo lo stesso controllo (`vehicle_untreated` / `no treatment` / `unstimulated` / `RPMI media`). Causa vera: `.normalize_control_type` cercava sinonimi di due parole in una lista confrontata **per token** — non potevano matchare mai | gruppi 312→305 ma studi-slot 2.076→**2.158**: meno gruppi, più studi dentro |
| v15 (2026-08-05) | le fusioni esplicite delle scritture di TGF-β1 e IL-17A | **TGFB1 k 65→78**, IL17A 8→12, verificate prima del run e tornate alla cifra |

**Quello che resta è il residuo**: le entità la cui scrittura non risolve a nessun codice
ontologico, e quelle che risolvono a codici *diversi* pur essendo la stessa molecola.
Nessuno lo ha mai misurato per intero.

---

## 2. Il materiale

**Il deliverable** (`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/`):
`deliverable-annotato.rds` (214 righe, colonne `contrast_entity`, `contrast_direction`,
`contrast_control_key`, `k_effective`, `n_sig`, `studies_in_cluster`),
`cluster_pooled.parquet`, `per_study_de.parquet`, `non_processable.rds` (137 gruppi scartati).

**L'output dello Stadio 3** (`analysis/p4-output/20260803T164558Z-stage3-v15-7f986159/`):
`clusters.rds` — **322.415 cluster**, con `contrast_entity` / `contrast_direction` /
`contrast_control_key` su ognuno — e `assignments.parquet`. **È qui che sta il premio vero**
(vedi §4), non nelle 214.

**I dizionari in cache** (`~/.cache/R/simulomicsr/`): ChEBI, ChEMBL, MeSH, HGNC, ImmPort,
tassonomia NCBI, UniProt. Il codice che li legge: `R/ontology-lookup.R`. Il recupero-nome:
`R/stage3-name-recovery.R`, `R/stage3-name-recovery-lookup.R`, `R/resolver-guards.R`.

---

## 3. Quello che si vede già a occhio — **contato, ma solo sulle 214**

Le 214 hanno **47 entità senza codice ontologico** (prefisso `STR:`) e 167 con codice.
Scorrendo le etichette risolte, i doppioni evidenti sono questi (k fra parentesi):

| doppione | oggi | fusi |
|---|---|---:|
| `SARS-CoV-2` (34) + `covid 19` (7) | due gruppi | **41** |
| `TNF` (32) + `TNF-ALPHA` (6) | due gruppi | **38** |
| `nutlin 3a` (8) + `Nutlin` (5) + `Nutlin-3` (3) | **tre** gruppi, due ID ChEBI per la stessa molecola | **16** |
| `radiation` (7) + `irradiation` (7) | due gruppi | **14** |
| `hydrogen peroxide` (8) + `hydrogen + peroxide` (3) | il secondo è una combinazione *rotta dal parser* | **11** |
| `atra` (5) + `all-trans-retinoic acid` (4) | due gruppi | **9** |
| `asthma` (4) + `asthmatic` (4) | due gruppi | **8** |
| `mycobacteriumtuberculosis` (4) + `tb positive` (3) | due gruppi | **7** |
| `IFNB1` (3) + `ifnb` (3) | due gruppi | **6** |
| `IFNA1` (3) + `ifna` (3) | due gruppi | **6** |

⚠️ **Questa tabella è un'ispezione a occhio, non una misura.** Serve a far vedere che il
problema esiste e che tipo di forma ha. **Non usarla come elenco di lavoro**: una lista scritta
a mano è l'errore che questo progetto ha già pagato più volte. Le fusioni devono nascere da una
**regola generale** — risolvere l'etichetta al codice — non da un elenco di casi.

**Cose che NON vanno fuse, e che a occhio sembrano doppioni:**
`5-azacytidine` e `5-aza-2'-deoxycytidine` sono due farmaci diversi (azacitidina e decitabina);
`testosterone` e `DHT` sono due molecole diverse; `tamoxifen` e `afimoxifene` sono il farmaco e
il suo metabolita attivo; `JQ1` / `birabresib` / `MIVEBRESIB` / `ABBV-744` sono quattro
inibitori BET distinti; `PMA` da solo e `ionomycin + pma` sono contrasti diversi per disegno.
E **la direzione non si fonde mai**: `gain` e `loss` restano separati (decisione utente
2026-07-25).

Ci sono anche entità che non sono entità: `antigen (classe-ombrello)` (3), `calcium atom` (3),
`obese` (7), `steatotic` (3). Quelle non si fondono: semmai si scartano, ed è una decisione a sé.

---

## 4. Il premio vero non si vede nelle 214

Nel deliverable la stessa entità **non può** comparire due volte con la stessa direzione: la
deduplica (`.dedup_rem_group_by_entity`, `R/stage4-qc.R`) tiene un solo gruppo per chiave
`contrast_entity || contrast_direction`, e lo fa **prima** del gate su k. Quindi i doppioni
visibili nelle 214 sono solo quelli con **codice diverso**.

Il guadagno grosso è altrove, e va cercato nei 322.415 cluster dello Stadio 3:

1. **gruppi che oggi stanno sotto la soglia k≥3 e che fusi la superano** → meta-analisi
   **nuove**, che oggi non esistono;
2. **i 137 gruppi scartati** (`non_processable.rds`): 42 hanno un solo studio buono, 82 ne hanno
   due — **206 studi-slot con controllo interno valido**, fermi sotto soglia. Se una fusione ne
   porta due sopra il tre, quegli studi entrano nel deliverable;
3. **studi-slot in più** dentro le meta-analisi che già esistono.

**Il primo compito della sessione è misurare questi tre numeri, in questo ordine.**

---

## 5. La strada, e il gate

**Non si lancia niente prima di aver misurato.** Questo progetto ha già la procedura giusta,
usata per v13 e per v15: **si simula la fusione sull'output dello Stadio 3 che c'è già**, si
depositano le previsioni per iscritto **prima** del run, e poi si verifica che il run le
riproduca alla cifra. In v15 ha funzionato: le previsioni depositate (TGFB1 78, IL17A 12,
351 candidati, perfino il `run_id`) sono tornate tutte.

Sequenza:

1. **misurare il residuo** (nessun run pesante): quante entità sono spezzate, quanti studi-slot
   si recupererebbero, **quante meta-analisi nuove nascerebbero**;
2. **portarmi il numero** e decidere se vale il costo: **re-cluster ~9 h + re-pool ~31 h ≈ 40 h**;
3. solo dopo, e solo con un GO esplicito, scrivere le regole in TDD e lanciare.

**Il criterio di riuscita di questa sessione non è "il deliverable è deframmentato".** È: un
numero misurato del guadagno, una regola generale scritta (non una lista), e una decisione presa
sapendo quanto costa.

---

## 6. Le trappole di questo progetto (tutte già pagate almeno una volta)

1. **Le etichette sono sbagliate, gli ID no.** `canonical_name` dissente dal nome vero su **49
   righe su 111** delle piccole molecole: JQ1 vi compare come "D-cycloserine", il DHT come
   "4-maleylacetoacetate". **Risolvi dai codici, mai dalle etichette.**
2. **Bumpa `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`.** Se cambi il recupero-nome senza bumparla, il
   re-cluster riusa il lookup su disco e produce un output **identico al precedente**. È già
   costato 8 ore buttate. Verifica che la cache sia stata bustata: il build del lookup deve
   durare ~1 minuto, non 0,1.
3. **Lo strumento deve vedere il dato per intero.** Tre misure cieche in due giorni, nel luglio
   scorso: alias corti (`ml`→trombopoietina), lettere greche cancellate (`IL-1β`), testo troncato
   a 40/58 caratteri. Prima di giudicare, controlla **quante stringhe toccano il limite**.
4. **Non fondere ciò che è diverso.** TGF-β**2** non è TGF-β1. Vedi la lista in §3.
5. **Verifica sull'artefatto, non sul sorgente.** E se c'è una figura, si apre e si guarda.
6. **Niente liste scritte a mano.** Una regola che chiude tre casi su trecento è una lista
   travestita.

---

## 7. I vincoli operativi

- Branch `review-scientific-consistency-2026-06-10`, **master invariato, il push lo fa l'utente**.
- `Rscript` **senza** `--vanilla` (il progetto usa renv). Reinstallare il pacchetto prima di ogni
  render Quarto.
- **Nessun run pesante senza una decisione esplicita dell'utente.**
- I run lunghi si lanciano con `setsid` (verificare SID==PID), **non** in background del tool:
  i processi lunghi in background sono già stati uccisi a metà corsa.
- Durante un run multi-ora: **aggiornamento ogni ora**, con fatto + stima del residuo.
- **Mai la parola "validato" senza la misura accanto.** Questo progetto ha già ritrattato due
  dichiarazioni di vittoria premature (`docs/RED_ALERT.md`).
- Nessun taglio silenzioso: ogni omissione dichiarata.

---

## 8. Che cosa viene dopo — e che cosa è già stato fatto per il dopo

**Problema 2, validazione esterna.** Il lavoro di ricognizione è **già stato fatto il 2026-08-08**
e i numeri sono contati, non stimati. Non va rifatto:

- **90 delle 111 piccole molecole del deliverable esistono in LINCS L1000** (81 agganciate per
  struttura chimica, InChIKey completo), più **19 delle 20 entità citochina/gene** presenti come
  perturbazioni ligando — **incluso il TGF-β1**. Copertura totale ≈ **109 entità su 214**.
- **Circolarità zero**: le serie GEO in cui LINCS è depositato non compaiono nelle 214 e non
  compaiono nemmeno nell'intero corpus ARCHS4 (28.505 studi). Le piattaforme del deliverable sono
  12, tutte Illumina RNA-seq; le piattaforme Luminex di L1000 sono assenti.
- **Asse dei geni**: tutti e **978** i geni misurati direttamente da L1000 sono nel nostro asse.
- **Limite già noto**: metà delle molecole agganciate sta a k=3-4, solo 14 hanno k≥10.
- Artefatti: `analysis/audit/2026-08-08-validazione-esterna/copertura-lincs-per-entita.csv`
  (111 righe), `copertura-trtlig-entita-hgnc.csv`, `gse-del-deliverable.csv`;
  metadati LINCS in `/mnt/wwn-0x5000039d58caca35/lincs-meta/` con SHA256 in
  `provenienza-file-scaricati.csv`.
- **Criterio di successo già fissato, prima di guardare qualunque risultato**: non basta che la
  nostra stima assomigli alla firma esterna giusta — due firme qualunque si somigliano un po'.
  Si confronta la nostra stima con la firma giusta **e con tutte le altre**, e si guarda dove si
  piazza quella giusta. Conferma se batte in media il 90% delle altre; smentita se sta sotto il
  60%. Il confronto è su **direzione e ordine** dei geni, mai sulla grandezza (piattaforme
  diverse, scale diverse).
- **Direzione già scartata con i numeri**: i 137 gruppi esclusi dal gate non servono a validare le
  214. Hanno **137 entità distinte**, sovrapposizione con le 214 **zero** a entità+direzione
  (verificato in modo indipendente): la deduplica lo rende impossibile per costruzione.

**Nota utile:** la deframmentazione dovrebbe **aumentare** la copertura LINCS, perché parte delle
47 entità senza codice sono esattamente quelle da risolvere (`atra` è la tretinoina, che in LINCS
c'è). I due lavori condividono lo stesso pezzo: risolvere le etichette ai codici.

**Problema 3, RummaGEO.** Confronto competitivo con un altro metodo end-to-end. Deliverable
integrale del paper (ADR-0006), lavoro a sé, dopo la validazione.

---

## 9. Riferimenti

- Stato del progetto e lezioni: `CLAUDE.md`, `docs/RED_ALERT.md`
- Le regole di fusione già scritte: `analysis/p4-fase-f10-stage3-v13-regole.R`, `R/stage3-contrast-anchor.R`, `R/stage3-contrast-gate.R`
- Il censimento che ha misurato la frammentazione (v12): `docs/findings/2026-07-28-censimento-v12-dati-veri.md`, tabella `analysis/audit/2026-07-28-censimento-v12/frammentazione.csv`
- Il censimento v13: `docs/findings/2026-07-28-censimento-v13.md`
- Lo script del re-cluster v15: `analysis/p4-fase-f10-stage3-v13-regole.R` (v15 ne è la discendenza)
- Handout della validazione esterna (superato da questo per l'ordine, valido per il contenuto): `docs/superpowers/specs/2026-08-08-validazione-esterna-HANDOUT.md`
