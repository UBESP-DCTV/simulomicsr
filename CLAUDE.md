# CLAUDE.md — contesto persistente per Claude Code su `simulomicsr`

> Fonte canonica del contesto del progetto per ogni sessione Claude Code,
> indipendentemente dalla macchina (laptop o server). Sostituisce la
> memoria locale di Claude Code (`~/.claude/projects/<path>/memory/`)
> che è machine-specific e non portabile.
>
> **Quando una sessione inizia in questa directory, leggi questo file
> per intero prima di agire.**

---

> 🔴🔴 **RED ALERT — FALLIMENTO DI PROCESSO RICONOSCIUTO (2026-07-24).** Per MESI l'audit v5→v10 ha
> ottimizzato i **NOMI** dei cluster (recupero deterministico, de-frammentazione, LLM-fallback) e ha
> dichiarato "vittoria" / "DELIVERABLE FINALE" / "publication-grade" **senza mai verificare la
> COERENZA DI CONTRASTO** — cioè l'obiettivo stesso dello studio: che gli studi raggruppati misurino
> lo STESSO contrasto così che la meta-analisi guadagni segnale vero. Quando è stata finalmente
> verificata (2026-07-23, finding `docs/findings/2026-07-23-stage3-cluster-coherence.md`): **157/184
> (85%) del deliverable sono MINESTRONI, la vetrina Layer B è 0/9.**
>
> **⚠️ RITRATTAZIONE ESPLICITA:** tutti i blocchi 🟢 qui sotto che dicono "DELIVERABLE FINALE" (v10
> fallback 2026-07-22) e "publication-grade / 18 case study" (Layer B v10 2026-07-23) sono
> **PREMATURI e RITRATTATI**: descrivono lavoro sui nomi corretto, ma NON il prodotto scientifico
> (meta-analisi coerenti), che in larga parte non esiste. "Nome recuperato" ≠ "cluster omogeneo" ≠
> "stesso contrasto". NON ri-dichiarare nulla "finale/publication-grade" senza il gate di coerenza.
>
> **DECISIONE UTENTE (2026-07-24): opzione 2 = REWORK DELL'ANCORAGGIO A MONTE (Stadio 3).** La causa
> radice è che l'anchor entità+tessuto è troppo grezzo (L3/L4) e, in group-mode, lascia il CONTROLLO
> libero per studio → pool­a contrasti diversi. Un filtro a valle è un cerotto; il fix vero è nel modo
> in cui si costruisce l'anchor/cluster. **Handout prossima sessione (DURO):**
> `docs/superpowers/specs/2026-07-24-stage3-anchor-coherence-rework-HANDOUT.md`.
>
> Reference operativa: ledger **`.superpowers/sdd/progress.md`** + finding coerenza + tool
> `R/stage3-coherence.R` + tabelle `analysis/audit/2026-07-23-coherence/`. Master invariato. Branch
> `review-scientific-consistency-2026-06-10`. Regole comportamentali: RED_ALERT §"Come Claude si deve
> comportare con me in questo audit" (+ la regola NUOVA sotto: la coerenza è il gate, non i nomi).
>
> **Stato 2026-08-13b (I TRE CAMBI DEL RE-RUN: IMPLEMENTATI E MISURATI — nessun run lanciato)**:
> 🟢 **D1, D2, D3+D4, D7 in codice di pacchetto con TDD, ognuno validato SUI DATI VERI. Suite intera
> 4.317 asserzioni, 0 fallimenti. Finding `docs/findings/2026-08-13-tre-cambi-implementati.md`,
> evidenza `analysis/audit/2026-08-13-rerun-prep/`, previsioni depositate in
> `PREVISIONI-PRIMA-DEL-RUN.md`. Commit `d92f505`, `18f83ea`. Master invariato, no push.**
>
> 1. **D1 corsie ACCESO**: dispatch 2.152 → 2.146, gli **stessi 6** cluster col k cambiato,
>    deliverable 214 → 213. Con l'interruttore spento il dispatch resta byte-identico.
> 2. **D2 confine del marcatore**: `\b` non vede il confine dopo una CIFRA (`p63shRNA`). Corretto,
>    con KO/KD solo maiuscoli, il marcatore sui VALORI e non sul nome del campo, e le negazioni.
>    **Sui dati veri: 5 confronti segnalati, NESSUNO poolato → effetto sul deliverable ZERO.**
>    L'attesa dell'handout («Nutlin 8 → 7») **non regge**: quel k=8 è il k_eff e i confronti
>    segnalati erano già fuori per `n_min`. Cambia un solo k di Stadio 3 (bleomicina 10 → 9).
> 3. **D3+D4 mappe**: 7 fusioni. **TNF 32 → 38, ipossia 25 → 33, SARS-CoV-2 34 → 36** (i tre numeri
>    della decisione tornano alla cifra), IL-6 10 → 11, IL-15 3 → 5. **La voce `normoxia` GENERALE
>    portava dentro un'ottava fusione non voluta** — ATRA, guadagno zero, stessi campioni contro due
>    controlli: è uno dei casi che D4 escludeva. Ora anche `normoxia` è condizionata all'entità
>    (`STR:hypoxia||normoxia`); il condizionamento è codice nuovo, senza il quale D4 non era
>    esprimibile.
> 4. **INFIGRATINIB NON NASCE**: la fusione porta il k di Stadio 3 da 2 a 3 (entra fra i 351
>    candidati) ma il **k_eff va da 1 a 2**, sotto il gate del pooling. D6 lo dava per «unica
>    meta-analisi nuova»: l'audit dell'8 agosto aveva scritto «gate ignoto», ora è misurato.
> 5. **PREVISIONE: deliverable 214 → 212** (−1 *S. epidermidis* per le corsie, −1 la riga TNF
>    assorbita dalla fusione, +0 infigratinib). Candidati 351, non processabili 137 → 139.
> 6. **⚠️ LE PREVISIONI VALGONO A PARITÀ DI STADIO 1 E 2.** `VLLM_BATCH_INVARIANT=1` rende
>    riproducibile il run NUOVO, non fa coincidere il nuovo col vecchio: senza flag due esecuzioni
>    identiche dello Stadio 1 davano lo stesso record nel **40,4%** dei casi (Stadio 2 62,0%;
>    `agent_normalized.id` 86,0%; confronti per identità dei campioni 92,0%). Rifacendo gli stadi
>    LLM, il deliverable cambia anche per motivi indipendenti dai tre fix. **DECISIONE APERTA
>    (utente): re-run a due tempi (prima Stadio 3+4 sul master attuale = verifica esatta dei tre
>    cambi, poi il re-run completo) oppure tutto insieme.**
> 7. **CONTROLLO PIPELINE §3 fatto**: Stadio 1 guard 12.967 flag corretti (2.882 accesi nell'input
>    v3, **0 senza evidenza**); Stadio 2 un record per studio PASS (24.394 studi); Stadio 3 le
>    cinque invarianti tornano tutte; Stadio 4 funnel 322.415 → 11.536 cgroup → 351 → 214+137, zero
>    orfani; guardie tutte invocate; cache recupero-nome **resta v7** (nessun cambio la tocca).
> 8. **DUE DIFETTI DEI MIEI STRUMENTI, corretti prima dell'uso**: (a) il riconoscimento di
>    `chiave=valore` tagliava tutto prima del primo `=` e mutilava **115 etichette**
>    (`LNCaP-abl shKDM3B1 t=7` → `7`); (b) i «36 flag senza evidenza» dello Stadio 1 **non esistono**:
>    nell'input v3 `value_hours` è un array di un elemento, `is.numeric(list(0))` è FALSE — la
>    trappola degli scalari-come-array, commessa dopo averla letta.
>
> **Stato 2026-08-13 (PASSO 2 — IL NOME SBAGLIATO NON COSTA POTENZA: chiuso SENZA modifiche)**:
> 🟢 **L'intervento più invasivo del programma di correttezza è stato tolto dal tavolo da una misura.
> Finding: `docs/findings/2026-08-13-passo2-il-nome-sbagliato-non-costa.md`. Evidenza
> `analysis/audit/2026-08-13-passo2/`. Nessuna modifica al codice di produzione.**
>
> 1. **L'IPOTESI**: il ramo `anchor` adotta l'ID dell'anchor **solo se** tutti i token del suo
>    `canonical_name` compaiono nel delta trattato; il nome è sbagliato su 111 righe su 214, quindi
>    dovrebbe **spegnere il ramo** → errore di **omissione** (potenza persa).
> 2. **CADE, misurata su 10.521 cluster `cgroup` non-COMBO**: il nome del modello spegne il ramo dove
>    quello vero lo accenderebbe in **9 cluster (0,09%), ZERO nel deliverable**. Il caso **opposto** —
>    il nome del modello **accende** il ramo e quello ontologico no — è **26**. Esito identico coi due
>    nomi nel **99,7%**; dove differiscono è **grafia o sinonimo** (`PLX4720`/`PLX-4720`,
>    `Monosomy X`/`Turner Syndrome`), non identità.
> 3. **SE SI "AGGIUSTASSE"**: dei 9, tre si fonderebbero con una chiave esistente e **una sola tocca
>    il deliverable** (`CHEBI:15698` k=1 → `cgroup_L5_a32e5eaa` k=31). Guadagno: **un membro in una
>    meta-analisi su 214**, e per giunta è de-frammentazione (due schede ChEBI della decitabina).
>    Costo: 26 cluster perdono l'anchor. **Netto negativo**, prima delle ~9 h di re-cluster e ~31 di
>    re-pool.
> 4. **DUE DIFETTI DELLO STRUMENTO, corretti prima di pubblicare**: (a) la prima versione girava su
>    tutti i `factor_levels` invece che su `d$treated_values` — un **sovrainsieme**, e 173 cluster
>    passavano senza avere `src=="anchor"`; rifatta con `.ca_delta` di produzione, **accordo
>    10.521/10.521 = 100,000%**; (b) il risolutore copre solo HGNC/ChEBI/MeSH, e per il 34,7% dei
>    cluster il nome vero è NA: contarli avrebbe dato **486 "guadagni" invece di 26**.
> 5. **PROGRAMMA**: passi 0-1-2-3-4 chiusi. Resta il **PASSO 5** (de-frammentazione, ampiezza del
>    re-pool, KSHV a k=3) e le due decisioni del PASSO 3.
>
> **Stato 2026-08-12 (PASSO 3 — LE CORSIE DI SEQUENZIAMENTO NON SONO REPLICHE)**:
> 🟢 **Meccanismo in codice di pacchetto, SPENTO di default. Nessun re-cluster, nessun re-pool.
> Finding: `docs/findings/2026-08-12-corsie-non-repliche.md`. Evidenza
> `analysis/audit/2026-08-12-corsie/` (README con l'ordine degli script). Suite `stage4` verde.**
>
> 1. **IL DIFETTO**: `n_min` ammette un braccio con **due campioni**; in quattro studi quei due
>    campioni sono la **stessa libreria letta su due corsie**. Il caso grave è **GSE173902** (36 GSM =
>    18 campioni × 2 corsie, **un solo campione biologico per condizione**): SE mediano **0,19–0,39
>    volte** quello dei pari e **76% del peso** in *S. aureus* e *S. epidermidis*.
> 2. **PRIMA DI MISURARE, L'UNITÀ ERA SBAGLIATA**: il rilevatore del 2026-08-09 raggruppava per
>    (cluster, studio, braccio); `n_min` agisce per **entry del dispatch**. Rifatto, con accettazione:
>    la replica riproduce il dispatch di produzione **entry per entry** (2.152 entry, 1.338 coppie
>    cluster-studio = lo stesso numero del 10 agosto).
> 3. **TRE CRITERI AUTOREVOLI PROVATI E SCARTATI**: il **BioSample** (copertura 100% ma quattro corsie
>    = quattro SAMN, e l'unico SAMN condiviso sta sui **due bracci opposti**); la **profondità** (le
>    corsie di GSE173902 hanno 19,9 M di reads, sopra la mediana); il **profilo di espressione**
>    (AUC 0,985 ma a soglia 0,990 ritrova **15%** delle corsie prendendo 3.444 coppie biologiche —
>    genera candidati, non verdetti).
> 4. **IL FALSO POSITIVO CHE HA CAMBIATO IL DISEGNO**: la regola del solo titolo unisce i **pozzetti
>    di una piastra** (`well: L1` contro `well: L10`, con `moi: 0` contro `moi: 0.1` = un controllo e
>    un trattato). Corpus intero: **solo il 45,3%** delle 4.360 librerie collassanti ha
>    `characteristics_ch1` identici. Tre guardie → 1.717 librerie, 50 studi. Una quarta guardia
>    proposta è stata **scartata perché vera per costruzione** (non misurava nulla).
> 5. **ESITO**: 9 confronti su 2.152 toccati, **6 cadono**, 6 righe delle 214 perdono uno studio,
>    **una esce** (*S. epidermidis*, k 3→2) → deliverable **214 → 213**. La previsione depositata
>    prima è confermata alla lettera.
> 6. **QUANTO CONTA**: *S. aureus* perde il **78,9%** dei geni significativi con Spearman **−0,02**,
>    *S. epidermidis* il 68,6% con 0,10. **Anche senza che nessuno studio esca**, la sola somma delle
>    corsie costa dal 12% al 18% (digossina, ATRA, artrite reumatoide).
> 7. **IL NULLO APPAIATO (55 pooling)**: in **tre gruppi su sei** GSE173902 **non** è la rimozione più
>    influente. Lì il motivo per toglierlo non è che sposta il risultato — è che **quel confronto non
>    ha repliche biologiche**. Nei due stafilococchi le due cose coincidono.
> 8. **PREVISIONE FALSIFICATA, con la spiegazione misurata**: avevo previsto SE ×√4 = 2 per gli studi
>    a quattro corsie; misurato **2,16 e 1,20**. Scomponendo `SE = sd·√(1/n₁+1/n₂)`: in GSE178340 la
>    **sd scende a 0,58** perché la dispersione fra le corsie era parte della varianza fra i 12.
> 9. **LIMITE PRINCIPALE**: i falsi negativi **non sono esclusi e non esiste uno strumento** per
>    farlo (7.185 coppie non dichiarate su 313.047 correlano almeno quanto una corsia confermata).
>    Il numero è un **limite inferiore**.
> 10. **DUE DIFETTI PRE-ESISTENTI CHIUSI DI PASSAGGIO**: il registro dei conflitti di ruolo viveva
>    come attributo di `per_study_de` e `write_parquet` gli attributi li perde — **non è mai arrivato
>    su disco**; ora sta in `qc_report` con quello dei collassi. E `NAMESPACE`/`man` non erano stati
>    rigenerati dopo il 10 agosto.
> 11. **DECISIONE APERTA (utente)**: **solo il gate** oppure **il collasso**. Il collasso *contiene*
>    il gate e in più corregge l'SE dei tre studi che restano; il gate da solo lascia metà del difetto
>    in piedi. Accendere richiede un re-pool. **PROSSIMO**: PASSO 2 ridotto alla sola misura (quante
>    volte il ramo `anchor` non scatta per un `canonical_name` sbagliato), poi PASSO 5.
>
> **Stato 2026-08-10 (I CONFRONTI SPURI: MISURATI INVECE CHE GIUDICATI — decisione utente: opzione A)**:
> 🟢 **Il verdetto di coerenza è sostituito da una misura di influenza. Nessun gruppo escluso,
> nessun re-cluster, nessun re-pool. Finding: `docs/findings/2026-08-10-sensitivity-confronti-spuri.md`
> (+ `-2026-08-10-passo1-accusati-dentro-il-pooling.md`). Evidenza `analysis/audit/2026-08-10-sensitivity/`.**
>
> 1. **PERCHÉ**: il verdetto non è riproducibile (stessi 213 gruppi: Mistral 24 incoerenti, lettura
>    umana 96, accordo 36,2%) e il criterio severo **azzera tutte le meta-analisi con k≥15**.
> 2. **IL CENSITO NON È IL POOLATO.** Il materiale della rilettura elencava i confronti di uno studio
>    non appena lo *studio* compariva nel poolato, senza `n_min` né dedup. **47 confronti accusati su
>    85 non sono nel deliverable**, tutti con un lato a n=1. Tasso vero **38/533 = 7,1%**, non 10,1%.
>    Definizione di braccio fissata (entry del dispatch di produzione) e verificata con **tre casi di
>    accettazione**: dispatch riprodotto su 214 cluster, bracci coincidenti col `per_study_de` su
>    **1.338** coppie, denominatore **843 riprodotto esattamente**.
> 3. **`n_min` FILTRA ANCHE LA QUALITÀ DELL'APPAIAMENTO** (scoperta nuova): difetti **7,1% dentro
>    contro 15,2% fuori**, Fisher **p = 0,00032**. Lette le 9 coppie accusate a vuoto: **9 su 9** il
>    confronto rimasto è la versione correttamente appaiata (`LAPC4_ENZA vs VCaP_DMSO` fuori,
>    `R1AD1_ENZA vs R1AD1_DMSO` dentro). Associazione, non meccanismo dimostrato.
> 4. **STRUMENTO in codice di pacchetto** (`R/stage4-loo-influence.R`, 28 test): il ri-pooling
>    riproduce `cluster_pooled.parquet` con **scarto 0 su tutte e otto le quantità**, anche su TGF-β1
>    (k=59, 532.109 coppie studio-gene a bracci multipli). **Nessun re-pool serve.** 521 pooling, 6,3 h.
> 5. **RISULTATO**: togliere tutti gli studi accusati costa **mediana 10,1% dei geni significativi**
>    (max 20,6%), Spearman mediana **0,902**. Gli accusati stanno al **79° percentile** delle rimozioni
>    pulite appaiate sui bracci (n=17, **p = 0,109**), e **6 su 17** superano il 90° percentile contro
>    1,7 attesi. **I dati sono coerenti con accusati un po' più influenti, ma non lo stabiliscono.**
> 6. **UN DIFETTO DEL MIO DISEGNO, DICHIARATO**: il nullo di blocco pareggia i *bracci* ma toglie
>    **1,35× più studi** (2,3× su TGF-β1), quindi è conservativo nella direzione sbagliata — il suo
>    p = 0,765 non prova indistinguibilità.
> 7. **DUE PREVISIONI SU CINQUE FALSIFICATE**, nella stessa direzione: avevo sottostimato quanto una
>    rimozione sposti il risultato (P1 prevedeva Spearman ≥0,95 in 9/11: sono 2).
> 8. **LIMITE PRINCIPALE, scritto prima di misurare**: una LOO vede solo gli studi **discordanti**;
>    un bias **concorde** le è invisibile (concordanza accusati 0,652 vs puliti 0,683, p = 0,168).
>    «Influenza piccola» **non assolve i difetti**.
> 9. **PROSSIMO**: Methods e Results (testo pronto nel finding §7). Branch invariato, master
>    invariato, no push, nessun commit.
>
> **Stato 2026-08-06 (LAYER B RIDISEGNATO — la vetrina era «indecente», ora regge)**:
> 🟢 **39 commit, 11 task in TDD con revisione indipendente ciascuno + revisione finale dell'intero
> ramo. Report: `analysis/p4-output/20260806T022106Z-layer-b-81f379d3` (9 bundle, 37 PNG, HTML 14,1 MB).
> Spec `docs/superpowers/specs/2026-08-05-layer-b-redesign-design.md`, piano
> `docs/superpowers/plans/2026-08-05-layer-b-redesign-plan.md`, difetti residui
> `docs/findings/2026-08-06-layer-b-difetti-noti.md`.**
>
> 1. **IL DIFETTO PEGGIORE ERA IL FOREST**: per TGF-β1 (59 studi) mostrava **CD300C e PROK2** —
>    misurati su **5 e 2 studi** — perché ordinava per grandezza dell'effetto senza guardare la
>    copertura. Il filtro giusto esisteva già ed era usato da tabella e heatmap: il forest non lo
>    chiamava. Ora: due pannelli, i bersagli canonici sopra, **PMEPA1 su tutti e 59 gli studi** sotto.
> 2. **TRE CASI DI CODICE SCRITTO E MAI CHIAMATO**, tutti trovati dalle revisioni: la scheda nuova
>    (il build usava ancora la vecchia), il fornitore dei confronti imperfetti, e — trovato solo dalla
>    revisione finale — `bersagli_attesi_provider`, per cui **ogni scheda dichiarava «nessun bersaglio
>    noto ritrovato» mentre nei dati c'erano tutti al k pieno**. Due erano buchi del PIANO, non
>    dell'esecuzione: nessun task si intestava il collegamento.
> 3. **QUELLO CHE I CRITERI AUTOMATICI NON HANNO VISTO**: i sette criteri erano tutti PASS quando il
>    forest ancora mostrava i geni sbagliati e il pannello studio-per-studio spariva **sempre**
>    (i geni a effetto massimo hanno k 43-52, mai 59). Trovato aprendo il PNG. **I criteri sono
>    misure, non garanzie** — ed è per questo che l'ispezione visiva era uno step del piano.
> 4. **VOLCANO**: un punto a p≈1e-310 schiacciava tutto; ora l'asse è compresso **in modo dichiarato**
>    e le etichette sono i bersagli veri (SKIL, PMEPA1, SERPINE1, TGFBI) invece di cornulina e granzima.
>    **HEATMAP**: via la legenda dei 47 codici GSE (un terzo della figura), la biologia era già giusta.
> 5. **TAGLI SILENZIOSI CHIUSI**: la heatmap non dichiarava di aver tolto l'annotazione per-studio;
>    la tabella dei «numeri verificabili» non diceva che 839 geni erano esclusi dall'ordinamento; la
>    narrativa taceva sulla dominanza quando il dato mancava, contraddicendo la scheda accanto.
> 6. **UN BUG PRE-ESISTENTE**: il ramo «0 geni significativi» della heatmap crashava e avrebbe abortito
>    l'intero batch. Mai esercitato da un test prima; il primo test lo isolava con un mock **che lo
>    nascondeva**. Ora il test lo esercita davvero.
> 7. **LE NARRATIVE SONO BOZZE**, marcate come tali: testo scientifico da rileggere e firmare.
>    **PROSSIMO**: rileggerle, poi i Methods.
>
> **Stato 2026-08-05b (I CONFRONTI IMPERFETTI: RILETTI TUTTI E 214, MISURATI, NON USATI COME GATE)**:
> 🟢 **Tutte e 214 le meta-analisi rilette sulla composizione POOLATA vera, con un contestatore per
> blocco. I difetti trovati sono QUANTIFICATI: 85 confronti su 843 nei 13 gruppi grandi (10,1%).
> DECISIONE UTENTE: non sono un gate, sono un finding dell'articolo.**
> Finding completo (metodo + numeri + limiti): `docs/findings/2026-08-05-confronti-imperfetti.md`.
>
> 1. **METODO, in tre passate** (`analysis/audit/2026-08-05-rilettura-214/`): materiale con le
>    etichette **INTERE** dei confronti POOLATI (non censiti) → 22 lettori da 10 gruppi → 22
>    contestatori («il tuo compito non è confermarlo: è provare che ha sbagliato») → 13 contatori sui
>    gruppi grandi, con un compito solo: **contare**, non rigiudicare.
> 2. **Il controllo del troncamento è dentro lo script**: misura la distribuzione delle lunghezze e
>    segnala i picchi. Ne ha trovati due (69 etichette a 40 caratteri, 11 a 58) → ispezionati: frasi
>    **complete**, non tronconi. La più lunga è 129 caratteri e arriva in fondo.
> 3. **ESITO sui 214**: 101 senza difetti, **97 con almeno un confronto imperfetto**, 16 incerti. Il
>    tasso **cresce con la dimensione**: k 3-4 → 47 su 115; **k≥15 → 13 su 13**. È il motivo per cui
>    NON può essere un gate: escluderebbe tutti i gruppi con potenza da figura.
> 4. **QUANTIFICAZIONE — ⚠️ RIFATTA IL 2026-08-10, i numeri qui sotto erano sbagliati due volte.**
>    ~~85 confronti imperfetti su 843 = 10,1%; peso mediano 12,0%; estremi SARS 0,7% / IL1B 33,7%;
>    TGF-β1 il 6,7% del peso perché «la pesatura per varianza inversa declassa da sola gli studi
>    rumorosi».~~ Il censito **non è** il poolato (il materiale ignorava `n_min`) e la regola del peso
>    pesava i **bracci** senza collasso né τ². **Veri: 38 confronti difettosi su 533 poolati = 7,1%;
>    peso contaminato mediano 8,8%, estremi 0,0%–15,9%; TNF ed enzalutamide 0,0%; il peggiore è LPS
>    (15,9%), non IL1B (13,3%); TGF-β1 9,1%.** Nessun declassamento automatico: rapporto
>    peso-accusati/equipeso **1,07**. Vedi
>    `docs/findings/2026-08-10-sensitivity-confronti-spuri.md`.
> 5. **TASSONOMIA**: secondo agente nel solo trattato 22% · materiale diverso 21% · passaggio di
>    coltura 16% · linea cellulare 15% · sede anatomica 12% · donatore/sesso/etnia 9%. **I difetti si
>    concentrano**: 8 studi danno 51 degli 85, e in 10 casi coprono l'INTERO contributo di uno studio
>    (GSE161176, GSE210984, GSE78801, GSE169241…) → una lista di studi da escludere è molto più corta
>    di una lista di confronti.
> 6. **UN DIFETTO NON IMPLICA UN RISULTATO SBAGLIATO**: DHT ed enzalutamide hanno 12,0% e 12,1% di peso
>    contaminato e danno insieme **1.266 geni su 1.299 di segno opposto, Spearman −0,939** (⚠️ CORRETTO 2026-08-10: prima «1.408 su 1.441», merge su `gene_symbol` con simboli ARCHS4 duplicati = prodotto cartesiano; l’asse del pooling è `gene_id`. La direzione regge, il conteggio era gonfiato del 10,9%).
> 7. **LIMITI DICHIARATI**: (a) il contestatore era **spinto alla severità** dal prompt — i 24 verdetti
>    cambiati vanno TUTTI verso il peggio, zero assoluzioni: un impianto migliore avrebbe due critici
>    simmetrici; (b) il peso è un limite superiore; (c) **tre accuse non hanno retto**, e una era MIA
>    (**RITRATTATA**): GSE178714 in TGF-β1 non è un difetto — il genotipo `SMAD2/SMAD3 KO` è IDENTICO
>    sui due bracci, era un argomento di plausibilità biologica, non di appaiamento; (d) una misura del
>    peso via regex **scartata perché cieca** (mediana 87%: prendeva anche gli studi citati come
>    *puliti*); (e) **TGF-β1 ha 145 CONFRONTI, non 59** — 59 sono gli STUDI, i due numeri erano stati
>    usati come sinonimi.
> 8. **Gli 11 verdetti umani precedenti: 11 su 11 riconfermati**, zero assoluzioni. E i difetti già
>    documentati nel progetto sono stati **ritrovati indipendentemente** dalle sole etichette (GSE78801
>    pons/brain, GSE210984 MSC da iPSC, GSE130247 «DHT and ENZ»).
> 9. **PROSSIMO**: le narrative dei 9 bundle e i Methods, con la tabella dei confronti imperfetti
>    accanto a ogni figura. Branch invariato, master invariato, no push.
>
> **Stato 2026-08-05 (v15 ESEGUITO — 214 META-ANALISI, IL CONTROLLO BIOLOGICO PASSA, LAYER B COSTRUITO)**:
> 🟢 **Il re-cluster v15 è stato l'ULTIMO, come da mandato. Re-cluster 8h43m + re-pool 31h, deliverable
> annotato, validazione biologica, 9 case study. Tutte le previsioni depositate PRIMA del run tornano
> alla cifra.**
>
> 1. **RE-CLUSTER v15** `analysis/p4-output/20260803T164558Z-stage3-v15-7f986159` (8h43m).
>    **`run_id` = `7f986159`, cioè il valore calcolato a mano nell'atteso prima del run.** Gate interni
>    tutti passati da soli: TGFB1 k=65→**78**, IL17A 8→**12** (attesi 78 e 12), **zero residui** delle
>    scritture fuse, glioblastoma **invariato a k=3** (tolto dalle fusioni il 2026-08-02), bandiera
>    tutte sopra il pavimento (SARS 38, LPS 50, enzalutamide 29, vemurafenib 20).
> 2. **LE CINQUE INVARIANTI, ri-misurate sull'OUTPUT VERO** (`60-invarianti-v15.R`, non sul dump che non
>    vede il ramo `anchor`): **tutte tornano**. Candidati pre-pooling **351**, cioè il numero depositato
>    nello script PRIMA di vedere l'output (305 pre-fix dedup → 354 post-fix → −3 assorbiti).
>    ⚠️ **Difetto del mio strumento, corretto misurando**: la prima versione confrontava solo i membri
>    dei cluster marcati `defrag` — **7 su 26.638**. Rifatta su tutti: **70 membri cambiano**, 49 sono
>    le fusioni volute (32+9 TGFB1, 5+3 IL17A) e **21 sono ricadute dell'Effetto 3**, provate:
>    `GSE131705__…__celiac_vs_control` in v13 compariva **dodici volte con lo stesso record_id**.
>    Nessuno di quei cluster tocca il deliverable (k≤2); il gruppo del 17β-estradiolo resta k=16.
>    Le chiavi di controllo anomale (`d+vehicle_untreated`) sono **8 in v13 e 8 in v15**: pre-esistenti.
> 3. **RE-POOL v15** `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7`
>    (31h, 351/351 cluster, run_id `d29545c7`). **Si è fermato sulla guardia dei verdetti**, che sta
>    fuori dal `tryCatch` apposta e ha funzionato. Annotazione rifatta **A FREDDO** dai parquet già
>    scritti (`80-annotazione-a-freddo-v15.R`, minuti invece di altre 31 h; guardia fatale inclusa).
> 4. **I 13 VERDETTI ORFANI NON sono il pre-filtro corretto il 2026-08-01.** Quel difetto riguardava un
>    gruppo **presente** nel poolato con chiave diversa (`adenoma`), che tolto il verdetto usciva
>    `coherent`. Qui **nessuna delle 13 entità compare fra le 214** e nessuno dei 13 cluster è poolato:
>    cadono al gate dei controlli interni come 137 candidati su 351. Prova in
>    `analysis/audit/2026-08-02-fix/81-verdetti-tolti-e-perche.md`. **La guardia non è stata toccata.**
> 5. **DELIVERABLE: 214 meta-analisi** (v13: 191), scomposizione **191 − 1 + 24** verificata: la riga
>    persa è **esattamente** `STR:tgfb||gain||vehicle_untreated`; i 24 nuovi vengono dalla dedup
>    corretta e sono **tutti già letti nella D0ter** — **zero gruppi entrano senza lettura umana**.
>    344.996 geni significativi, I² mediano 72,1, **11 incoerenti dichiarate, 0 NA**.
> 6. **LE PREVISIONI DEPOSITATE PRIMA DEL RUN, tutte verificate**: TGF-β1 **49→59** studi poolati;
>    **JQ1 24→25, IFN-γ 19→20, IL1B 17→18** (Effetto 3, `record_id` univoco); candidati 351; run_id.
>    Il fix F2 sui `record_id` a tre segmenti aggancia **4.726/4.726** (prima: zero).
> 7. **CONTROLLO BIOLOGICO — PASSA** (`90-controllo-biologico-v15.R`, bersagli fissati dalla letteratura
>    PRIMA di guardare i risultati): **29/31** col segno giusto e significativi. Il controllo che vale
>    doppio — **DHT agonista contro enzalutamide antagonista**, due gruppi costruiti separatamente —
>    dà **1.299 geni significativi in entrambi, 1.266 (97,5%) di SEGNO OPPOSTO, Spearman −0,939** (⚠️ CORRETTO 2026-08-10, prima 1.441/1.408: merge su `gene_symbol`).
>    KLK3 +2,27/−1,60 · TMPRSS2 +1,78/−0,92 · FKBP5 +2,32/−1,22 · NKX3-1 +1,37/−1,24. TGF-β1 tutti e 6
>    i bersagli (FDR fino a 1e−24), IFN-γ CXCL9 **+11,3**, LPS IL6 +4,70.
>    **Le due mancate sono entrambe su IL17A**, l'altro gruppo de-frammentato: segno giusto ma non
>    significative, e il gruppo lo spiega da sé — **k=9 con 3 soli studi efficaci**. La fusione ha
>    aggiunto studi, il gruppo resta debole: **non è materiale da figura**, e va detto.
> 8. **LAYER B v15** `analysis/p4-output/20260805T055939Z-layer-b-bb08afbd` (5,3 min, 9 bundle, 54 PNG
>    + 45 SVG, report HTML 18,8 MB con **54 immagini incorporate e 0 riferimenti esterni**). Selezione
>    **rigenerata dal deliverable nuovo** (`70-selection-v15.R`): il CSV di v13 portava **181 numeri di
>    v13 scritti a mano** nelle note, l'unico canale che nessuna guardia intercetta perché è testo
>    libero. Verificato sull'artefatto: la scheda di TGF-β1 dice **k=59**, non 49. I primi geni sono
>    SKIL, PMEPA1, BHLHE40, FSTL3 — bersagli canonici, misurati **tutti a k=59**.
> 9. **LE NOVE SCELTE DI ADR-0027 REGGONO**, tre si rafforzano. Verificato che **nessuno dei 24 gruppi
>    nuovi le batta**: il migliore è `irradiation` con 5,6 studi efficaci contro k 10-59 della vetrina.
>    **Il guadagno della dedup è in NUMERO di meta-analisi, non in potenza** (i nuovi sono tutti k=3-8).
> 10. **DUE LIMITI DA METTERE NEI METHODS**: (a) **122 su 214 (57%)** hanno uno studio che pesa più
>    della metà e **78 (37%)** valgono meno di due studi efficaci — non è un errore (la pesatura per
>    varianza inversa deve fare così) ma per un terzo del deliverable il pooling non aggiunge molto;
>    (b) il guadagno della dedup è in numero, non in potenza. **PROSSIMO**: le narrative dei 9 bundle e
>    i Methods. Branch invariato, master invariato, no push.
>
> **Stato 2026-07-31c (FASI A-C CHIUSE — la suite e' verde e il re-run produrra' il deliverable da solo)**:
> 🟢 **Cinque difetti del codice corretti con TDD, i tre test rotti risolti (due non erano quello che
> sembravano), suite da 3952 PASS / 3 FAIL / 3 ERROR a 0 FAIL / 0 ERROR. Il re-run e' pronto: manca
> solo la decisione D0.**
>
> 1. **A1 — `k_effective` e' PER-GENE e tre punti lo usavano come se fosse del cluster**
>    (`layer-b-summary-card.R:37`, `layer-b-selection.R:110`, `layer-b-plot-forest.R:164`).
>    **Quattro schede di case study su nove riportavano un k sbagliato** (IL1A 3 invece di 4,
>    Parkinson 9/10, SARS 32/33, JQ1 22/24). Fix: `.cluster_k_effective()` (10 test). Bundle
>    rigenerati: **9/9 col k giusto**.
> 2. **A2 — le schede dicono quanto il pooling e' efficace** (12 test, parametro opzionale
>    retrocompatibile). Parkinson ora dice «1.8 of 10», «GSE181029 73.2%», «the heaviest study is an
>    in vitro model». **A3** — il volcano deduplica le etichette come gia' facevano tabella e heatmap.
> 3. **B1 — `compute_pooling_effectiveness()` da 612 a 91 secondi** (6,7x) con **scarto
>    0,0000000000** sui 191. Il grosso non e' il cambio di libreria ma **lo spostamento del filtro a
>    monte del collasso dei bracci**.
> 4. **B2/B3 — `annotate_stage4_deliverable()` e' codice di pacchetto** (24 test) e **lo script di
>    re-pool la chiama a fine run**. Prima le misure erano cucite a mano in script di audit: un
>    re-pool avrebbe rifatto un deliverable **senza `k_kish`**. Validata sui dati veri: **tutte e 20
>    le colonne identiche** al deliverable costruito a mano, nessuna mancante.
> 5. **Due difetti trovati dal confronto B2**: (a) il materiale andava misurato sui soli studi
>    **poolati** e uno script usava tutti gli **assegnati** (1.758 contro 1.234 studi-slot) — ora la
>    funzione filtra da sola; (b) **`I2_med` era APPROSSIMATO**: lo script vecchio calcolava la
>    mediana **dentro Arrow** (t-digest), scarti fino a **0,93 su 190 righe su 191**. Deliverable
>    canonico rigenerato con la mediana esatta.
> 6. **C — i tre test rotti non erano quello che sembravano.** (a) Gli smoke E2E: la chiave OpenAI
>    **c'e' ma risponde 401**, e la guardia su `nzchar()` li lasciava passare → ora serve
>    `SIMULOMICSR_LLM_SMOKE=1`. (b) **La dashboard: il binario quarto NON e' assente** (c'e' in
>    `/usr/local/bin`), come si credeva da due mesi e come avevo scritto anch'io: il template usava
>    la colonna **`gene`**, rinominata da FASE E1 in `gene_id`/`gene_symbol` il 2026-05-28.
>    **La dashboard tornera' a renderizzare nel re-run.** (c) `gene-axis E2 T2.4`: l'attesa del test
>    era anteriore al fix T7a che ha reso il messaggio diagnostico.
> 7. **RE-RUN PRONTO, D0 APERTA.** DRY_RUN **PASS**: 305 cluster tutti `rem_group`/`cgroup_L5_`,
>    24.502 campioni, 3,1 TB liberi, cache counts riusata. **Decisione da prendere prima del lancio:
>    solo re-pool (~28 h) oppure re-cluster + re-pool (~37 h, chiude il gruppo IL1A ma riapre il
>    censimento di coerenza sui gruppi cambiati). Raccomandazione scritta: solo re-pool.**
>    Programma completo e autosufficiente: `docs/superpowers/plans/2026-07-31-programma-fix-e-rerun.md`.
>    Branch invariato, master invariato, no push.
>
> **Stato 2026-07-31b (LAYER B FINALE — 9 CASE STUDY, IL DELIVERABLE DICE QUANTO IL POOLING È EFFICACE)**:
> 🟡 **La critica dell'utente («non mostriamo dove il pooling sia davvero efficace») è accolta e
> chiusa: due assi nuovi, misurati su TUTTI e 191, in codice di pacchetto con TDD, dentro il
> deliverable. Le figure sono corrette e la correzione è verificata sull'artefatto. NON è "validato":
> vedi §10 del finding.**
>
> 1. **BUILD FINALE** `analysis/p4-output/20260730T220723Z-layer-b-828b020d` (9 bundle = 3 main + 6
>    supplementari, 54 figure, 5,7 min, report HTML 19 MB con 57 immagini incorporate).
>    Selezione: `analysis/layer-b-selection-v13-finale.csv`, generata dal deliverable.
> 2. **DECISE LE DUE SCELTE APERTE, sui numeri**: figura 2 = **TGF-β1** (49 studi contro 35 di LPS,
>    45,1 efficaci contro 31,8, i 6 bersagli attesi tutti al k pieno); malattia = **CROHN** (k=10,
>    **6,9 studi efficaci**, nessuno sopra il 21%, 3.515 geni sig, tutti i membri tessuto di paziente)
>    al posto di Parkinson (1,8 efficaci) e dell'epatocellulare (72 geni sig in tutto).
> 3. **IL DELIVERABLE ORA QUANTIFICA L'EFFICACIA.**
>    `analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.csv` ha 12 colonne nuove:
>    `k_kish` (numero efficace di studi, Kish), `frazione_efficace`, `quota_top1`, `dominato`,
>    `studio_dominante`, `materiale_misto`, `n_studi_model/primary/unknown`,
>    `classe_studio_dominante`, `dominato_da_modello`. Codice: **`R/stage4-pooling-effectiveness.R`
>    (38 test)** e **`R/stage3-material-class.R` (49 test)**, scritti test-first.
>    **Riproduzione ESATTA della misura a mano: scarto 0,0000000000 su k_kish e quota_top1,
>    k_studies identico su tutti e 191.**
> 4. **I NUMERI, su tutti e 191**: dominati da un solo studio (≥50%) **105 (55,0%)** · meno di 2 studi
>    efficaci **66 (34,6%)** · frazione efficace mediana **0,65** · materiale misto 49 (25,7%) ·
>    **dominati da un modello in vitro 8 (4,2%)**. Tutto concentrato sui k bassi: k=3-4 → **80%
>    dominati**, k≥11 → **zero**. Estremo: «Lung Neoplasms» k=3, **1,0 efficaci, 98,8% su uno**.
>    **Coerenza e dominanza sono assi INDIPENDENTI: 100 dei 105 dominati sono marcati "coerenti".**
>    Non è un errore (l'inverso della varianza deve pesare così) ma per un terzo dei gruppi il pooling
>    non aggiunge nulla, e prima nulla lo diceva. Va nei Methods.
> 5. **FIGURE CORRETTE E VERIFICATE**: `layer_b_default_config()$top_genes_min_k_frac = 0.5` (31 test)
>    — un gene entra in tabella/heatmap solo se misurato in almeno metà degli studi. Il filtro è
>    **dichiarato in caption** (mai tagli silenziosi), **non svuota mai una figura** (fallback
>    dichiarato) e **non tocca le stime**. Verifica sull'artefatto: geni sotto metà del k **106 → 0**;
>    k mediano dei mostrati SARS 6,0→**33,0**, IFN-γ 4,0→**19,0**; geni quasi-tutti-zero IFN-γ
>    **16/30 → 0/30**. La tabella di IFN-γ prima aveva geni GIMAP a k=2 con l'85-92% di zeri, **ora ha
>    STAT1, GBP1, CXCL9, TAP1**. **E la varianza si sposta dove deve**: rimisurato sui geni
>    effettivamente mostrati, su IFN-γ l'R² del TRATTAMENTO va da **0,01 a 0,81** e quello dello
>    studio da 0,82 a 0,04 — la heatmap era una mappa degli studi, ora separa in due blocchi per
>    trattamento e mostra la firma canonica dell'interferone γ (STAT1/STAT2/IRF1/GBP1/IDO1/TAP1-2,
>    immunoproteasoma, CXCL9/11). Geni quasi-tutti-zero: **0/30 su tutti e quattro** i cluster
>    rimisurati.
> 6. **LA FIGURA 1 È PIÙ FORTE DEL PREVISTO.** Non sono i quattro bersagli scelti prima: su **1.299
>    geni significativi in ENTRAMBI i gruppi, il 97,5% ha segno opposto, Spearman −0,939**; e dei 15
>    geni condivisi fra i primi trenta di ciascuno, **15 su 15** sono opposti (PGC +4,63/−3,04,
>    SLC38A4 +4,15/−4,23, UGT2B28, CHRNA2, KLK2…), tutti **scoperti, non scelti**. Caveat col numero:
>    i 2 studi condivisi fra i gruppi pesano **8,6%** e **10,2%**, quindi ~90% di ciascuna stima viene
>    da studi esclusivi. I bersagli noti non sono in cima all'FDR perché hanno **I² 99,7-99,9**:
>    l'ordinamento per FDR premia i consistenti, non i grandi — proprietà del REM, da dichiarare.
> 7. **PROPOSTA DI RITRATTAZIONE DI IERI SERA, RITIRATA.** Avevo proposto di ritrattare il verdetto di
>    coerenza del solo Parkinson. Leggendo **tutti e 20** i gruppi di malattia, la forma «paziente
>    contro modello in vitro» è in **almeno 6** (Parkinson 73%, spondilite 80%, Huntington 57%,
>    colorettale 47%, renale 31%, diabete gestazionale). Ritrattarne uno sarebbe stata **una lista
>    scritta a mano** — l'errore già pagato. Al suo posto: l'asse è misurato su tutti e 191 e sta nel
>    deliverable; **i verdetti non sono stati toccati**. Il rilevatore è un'euristica **dichiarata**,
>    accordo col giudizio umano **19/20**, e l'unico disaccordo è un caso in cui ha ragione lui.
> 8. **RITRATTATO ANCHE §8 DI IERI**: «i simboli duplicati costano 0-5 posti su 30» è **falso** —
>    `.rank_and_dedup_genes()` deduplica già, **zero duplicati in tutte e 12 le tabelle prodotte**.
>    Avevo misurato sul parquet grezzo invece che sull'artefatto. Stessa classe di errore di sempre:
>    **misurare l'oggetto sbagliato**.
> 9. **TRE ERRORI DI MISURA MIEI, tutti corretti prima dell'uso**: (a) confronto con un `k_effective`
>    che è **per-gene**; (b) peso calcolato sui **bracci** invece che sugli studi (83 per 49 in
>    TGF-β1) → rifatto col collasso e **validato, 0 disallineamenti su 40.251**; (c)
>    `dominato_da_modello` si accendeva dove il "dominante" pesa il 2,5% → mancava la congiunzione con
>    `dominato` (17 gruppi → **8**).
> 10. **SUITE**: stage4 **844 PASS / 0 FAIL** (+2 ERROR pre-esistenti), stage3 **1283 PASS / 0 FAIL**,
>    layer-b **202 PASS / 0 FAIL**. **PROSSIMO**: le narrative dei 9 bundle e i Methods (il materiale
>    c'è: i 114 scartati dal gate, i 6 incoerenti, TGF-β1 spezzato in tre, l'ID sbagliato dell'LTA,
>    la dominanza, il gate che può concentrare l'errore). Finding
>    `docs/findings/2026-07-31-layer-b-v13-case-study.md`; evidenza
>    `analysis/audit/2026-07-31-layer-b-v13/`. Branch invariato, master invariato, no push.
>
> **Stato 2026-07-31 (LAYER B v13 COSTRUITO — LE STIME REGGONO, DUE FIGURE NO, UN VERDETTO DA RIVEDERE)**:
> 🟡 **12 case study, 72 figure, report HTML, wall 10 min. La biologia passa (32 bersagli attesi su
> 32). Ma guardare i bundle ha trovato tre cose che i numeri aggregati non dicevano. NON è
> "validato": vedi §9 del finding.**
>
> 1. **BUILD** `analysis/p5-stage4-layer-b-build-v13.R` → `analysis/p4-output/20260730T160606Z-layer-b-c279e308`
>    (12 bundle, 75 immagini incorporate, 0 riferimenti esterni). Selezione ADR-0027 + **entrambi** i
>    doppioni aperti (TGF-β1/LPS e Parkinson/HCC), perché costruirli tutti e due costava due minuti.
> 2. **DUE DIFETTI DELLA MACCHINA trovati PRIMA del lancio**, entrambi perché il Layer B è anteriore
>    ad ADR-0025: (a) `anchor_key` dei `cgroup` ha **3** segmenti, non 13 → `extract_anchor_summary()`
>    non crasha ma dà **NA su tutto** (ogni card avrebbe scritto `Anchor: ? x ?`); (b) `canonical_name`
>    del DHT dice «4-maleylacetoacetate» — l'etichetta viene dal CSV di selezione, ora **generato dal
>    deliverable**. Il fix `rem_group` del 23/07 c'era già. Pre-flight 5/5 su 12 cluster.
> 3. **LA BIOLOGIA REGGE**: 32 bersagli attesi su 32, segno corretto, tutti nel 5% più significativo.
>    GO indipendente: IFN-γ dà «response to type II interferon», enzalutamide biogenesi ribosomiale,
>    DHT biosintesi del colesterolo (programma lipogenico di AR).
> 4. **FINDING 1 — la tabella dei top geni e la heatmap non mostrano l'effetto.** Catena verificata:
>    k basso → τ² stimato **0** → SE collassa → FDR minuscolo → il gene entra nei top 30 → ma è
>    **zero nella maggior parte dei campioni** → ComBat lo salta esplicitamente → la riga resta
>    segnale di studio. SARS: k mediano dei primi 20 = **6,5 su 33**, 20/20 sotto metà del k pieno;
>    SE mediano 0,554 a k=2 contro 0,088 a k≥21; τ²=0 nel 56,6% dei geni a k=2. Geni dei top 30
>    quasi tutti a zero: DHT 8/30, **IFN-γ 16/30**. ⚠️ **Una mia conclusione corretta prima di
>    scriverla**: misurato sul grezzo sembrava batch ovunque, ma la heatmap applica VST+ComBat →
>    rifatto sulla catena vera, R² studio **0,82→0,02** (DHT), 0,55→0,03 (TGF-β1); **fallisce solo
>    IFN-γ, 0,84→0,82**. Le stime poolate NON sono toccate: il difetto è in quali 30 geni si mostrano.
> 5. **FINDING 2 — 105 delle 191 (55,0%) sono dominate da un solo studio** (≥50% del peso), 66
>    (34,6%) valgono **meno di 2 studi efficaci**. Misurato su TUTTI e 191 col numero di Kish
>    `(Σw)²/Σw²`, w=1/(SE²+τ²). Tutto concentrato sui k bassi: k=3-4 → **80% dominati**; k≥11 → **0**.
>    I sette di punta stanno bene (TGF-β1 49→45,1 efficaci, studio più pesante 2,6%). Estremo:
>    «Lung Neoplasms» k=3, **1,0 efficaci, 98,8% su uno**. **Non è un errore** (l'inverso della
>    varianza deve pesare così) ma per un terzo dei gruppi **il pooling non aggiunge nulla**, e
>    **tutti e 105 sono marcati "coerenti"**: coerenza e dominanza sono assi indipendenti. Va nei
>    Methods; `k_kish` andrebbe accanto a `k_effective`. ⚠️ **Secondo mio errore corretto**: la prima
>    versione pesava i **bracci** (`per_study_de` ha una riga per braccio: 83 per 49 studi in TGF-β1);
>    rifatta col collasso e **validata — 0 disallineamenti su 40.251**.
> 6. **FINDING 3 — il case study di MALATTIA non regge, in nessuna delle due versioni.** Parkinson:
>    **1,8 studi efficaci su 10, 73,2% del peso su GSE181029**, che leggendo il testo intero **non è
>    cervello di paziente** ma progenitori/neuroni **da iPSC** con mutazione PARK2 — la stessa forma
>    «clinico contro sperimentale» che ha reso **incoerenti influenza e HIV-1**. → **PROPOSTA DI
>    RITRATTAZIONE del verdetto `coherent`, non applicata** (la marcatura è lettura umana, decide
>    l'utente). HCC: 67,4% del peso su due studi problematici (PBMC invece di fegato; un solo
>    controllo per pazienti diversi) e **solo 72 geni significativi**. **Alternativa misurata:
>    Crohn Disease k=10, 6,9 efficaci, max 20,3%, 3.515 geni sig** — poi Alzheimer (k=6, 3,8, 6.231).
>    Non costruiti: sono due minuti.
> 7. **I DIFETTI GIÀ NOTI ORA HANNO UN PESO**: nei sette gruppi di punta valgono **4,7–9,4%** (non
>    guidano nulla); nei due di malattia **67–74%**. Tre difetti **nuovi**: `GSE210984` in TGF-β1
>    (trattato = MSC da iPSC, controllo = MSC primarie), `GSE78801` in JQ1 (pons contro brain),
>    `GSE130247` in DHT (`DHT and ENZ`: l'antagonista dentro il gruppo dell'agonista).
> 8. **Difetto minore misurato**: asse dei geni pulito (**0 righe duplicate per `(cluster_id,gene_id)`
>    su 3.178.307**), ma le tabelle usano `gene_symbol` e nella regione MHC lo stesso simbolo ha più
>    ID Ensembl (`UBD` sei volte in SARS). Costo: **0-5 posti su 30** per tabella.
> 9. **PROSSIMO = decisioni utente**: (a) quale alto-k e quale malattia (Crohn?); (b) filtro per k
>    ed espressione su top-geni e heatmap (`layer_b_default_config()`, **non fatto**); (c) verdetto
>    Parkinson; (d) `k_kish` nel deliverable. Poi le narrative e i Methods. Finding
>    `docs/findings/2026-07-31-layer-b-v13-case-study.md`; evidenza
>    `analysis/audit/2026-07-31-layer-b-v13/`. Branch invariato, master invariato, no push.
>
> **Stato 2026-07-30 (RE-POOL v13 FATTO — 191 META-ANALISI POOLATE, I² ESISTE, I GENI SONO GIUSTI)**:
> 🟢 **Il deliverable è poolato, annotato e per la prima volta VALIDATO BIOLOGICAMENTE. Non è
> "finale": mancano il Layer B, i Methods e le decisioni sui limiti.**
>
> 1. **RUN** `analysis/p4-fase-f5-stage4-layer-a-rebuild-v13.R`, 28h17m, output
>    `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296`
>    (run_id `ac125296`). Solo ramo `rem_group` (ADR-0026). Un errore non fatale: dashboard quarto.
> 2. **ANTI-STALE PASS**, letta dai file non dal log: `Methods` = solo `rem_group` su 3.178.307
>    righe; tutti i `cluster_id` con prefisso `cgroup_L5_`; **191 poolati = ESATTAMENTE i 191
>    previsti** (confronto di insiemi); **k per cluster identico al previsto su tutti e 191**.
>    114 scartati con un solo motivo (`rem_group_insufficient_in_study_controls`, limite L7).
> 3. **IL NUMERO È 191, NON 305.** Il gate dei controlli interni scarta 114 gruppi (studi-slot
>    1.758 su 2.158). «305» è il censimento dei raggruppamenti, non il deliverable poolato.
> 4. **I² e τ² esistono su TUTTE le righe** (I² mediano 73,2) — è ciò che il ramo `mega`, uscito
>    con ADR-0026, non poteva fare. 315.037 geni significativi (FDR<0,05).
> 5. **CONTROLLO BIOLOGICO, MAI FATTO PRIMA — PASSA.** DHT (agonista AR): KLK3 **+2,27**,
>    TMPRSS2 +1,78, FKBP5 +2,32; **enzalutamide (antagonista): −1,60, −0,92, −1,22 SUGLI STESSI
>    GENI**. LPS, TGF-β1, SARS-CoV-2, IFN-γ tutti coerenti con la letteratura. Gli I² di quei geni
>    stanno fra 94 e 100: gli studi concordano sul **segno**, non sulla magnitudine.
> 6. **IL POOLING CAMBIA LA COMPOSIZIONE DI 3 GRUPPI SU 4**: solo 45 su 191 hanno lo stesso insieme
>    di studi censito, 524 studi persi. Per i coerenti il verdetto regge per **chiusura per
>    sottoinsiemi** (argomento, non misura); i **6 incoerenti sono stati riletti sui membri veri**:
>    nessuno assolto, e in tre casi il pooling ha fatto cadere gli studi giusti lasciando l'intruso.
>    **Il gate seleziona per controllo interno, non per correttezza biologica: può CONCENTRARE
>    l'errore.** Va nei Methods.
> 7. **DUE RITRATTAZIONI, per iscritto**: (a) «gli ID sono tutti giusti» (censimento 28/07) è
>    **falso** — `CHEBI:73572` è il tripeptide Leu-Thr-Ala mentre i suoi 3 studi trattano con acido
>    lipoteicoico; verifica estesa a TUTTI e 305: **303 corretti, 1 sbagliato, 1 parziale**
>    (`HGNC:1653` CD28 = anti-CD3/CD28). (b) **Il bundle del censimento TRONCAVA le etichette** a
>    58/40 caratteri e un mio verdetto è stato dato su mezza frase (GSE126517: il pezzo tagliato era
>    `and IFN-alpha for 18 hours`). Ampiezza: **8,6% dei confronti, 52% dei gruppi poolati**.
>    Riletti tutti i 99 col testo intero: **zero verdetti ribaltati**, un motivo corretto.
> 8. **LEZIONE DI METODO (dall'utente, e confermata dai fatti)**: tre strumenti di misura ciechi in
>    due giorni — alias corti (`LTA`), lettere greche cancellate (`IL-1β`), testo troncato — sempre
>    perché **lo strumento vedeva meno del dato**. Principio scrivibile PRIMA: *prima di giudicare,
>    verifica che lo strumento veda il dato per intero*, con accanto il controllo «quante stringhe
>    toccano il limite?».
> 9. **CODICE NUOVO** (TDD, 59 PASS/0 FAIL): `R/stage3-entity-label.R` (etichetta risolta dall'ID +
>    `.display_entity_label()` con le scelte umane in `inst/extdata/entity-label-overrides.csv`) e
>    `R/stage4-coherence-annotation.R` (marca i 6 incoerenti invece di scartarli — scartarli sarebbe
>    una lista; un verdetto orfano FERMA la marcatura). **`canonical_name` non è mai sovrascritto.**
> 10. **REGOLE DI RIGA: limite misurato.** `.rp_row_defect` non segnala nessuno dei difetti visti
>    (linea diversa, `visit`, passaggio, etnia, sede). Misura esatta: 38 confronti su 4.452 con un
>    numero diverso, di cui **16 non sono difetti** (caso-controllo di malattia) → **~22 veri (0,5%)
>    in 4 gruppi**. Etnia/sede/tipo cellulare **non misurati** (servirebbe un vocabolario).
> 11. **SELEZIONE DEI CASE STUDY DECISA — ADR-0027 Accepted** (utente 2026-07-30): **main paper 2
>    figure / 3 gruppi** — DHT (`CHEBI:16330`, k=23) **contro** enzalutamide (`CHEBI:68534`, k=19)
>    nella STESSA figura (segni opposti sugli stessi bersagli = controllo positivo e negativo
>    insieme), piu' UN SOLO caso ad alto k (TGF-β1 k=49 o LPS k=35) con forest e I². **Supplementari
>    5-6 per copertura di tipo**: SARS-CoV-2, IFN-γ, una malattia, JQ1, e **almeno uno dei 6
>    incoerenti** (un paper che mostra solo successi e' meno credibile). Le due vetrine precedenti
>    (15 case study 2026-05-24, 18 del 2026-07-23) sono **superate**: erano costruite su cluster poi
>    risultati incoerenti.
> 12. **PROSSIMO = LAYER B in sessione dedicata**: handout
>    `docs/superpowers/specs/2026-07-31-layer-b-NEXT-SESSION-HANDOUT.md`. Poi Methods, poi
>    (decisione utente) l'eventuale regola «entità con un gruppo proprio» (~9h + ~28h).
>    Deliverable annotato: `analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.csv`.
>    Finding `docs/findings/2026-07-30-repool-v13-risultati.md` e
>    `-2026-07-29-etichette-identita-e-gate-del-pooling.md`. Branch invariato, master invariato.
>
> **Stato 2026-07-28b (RE-CLUSTER v13 CON LE SEI REGOLE: 296 COERENTI SU 305 = 97,0%)**:
> 🟡 **Secondo re-cluster (8h43m, `20260728T151529Z-stage3-v13-364547a7`). NESSUN RE-POOL: i gruppi
> non sono poolati, I² e τ² non esistono. Il re-pool (~50 h) è dietro un GO dell'utente.**
>
> 1. **SEI REGOLE in TDD** (30 asserzioni viste fallire prima del codice), ognuna da una causa
>    trovata nel codice, non da un elenco di casi: (a) `.normalize_control_type` cercava i sinonimi
>    a DUE parole (`"no treatment"`) in una lista confrontata per TOKEN — non potevano matchare mai,
>    ed è il motivo per cui TGFB1/LPS/IFN-γ/DHT stavano in due gruppi ciascuno; (b) `.CG_BLOCK_RX`
>    non conosceva la notazione genetica `-/-`; (c) `.CG_UMBRELLA_RX` era ancorato `^…$` e nessuno
>    controllava il CANDIDATO del resolver (`"MEK inhibitor"` → U0126); (d) `.cg_is_inducer` riceveva
>    `"CHEBI:16411"` invece del nome; (e) mancavano i segnali clinici sul trattato (soggetto,
>    donatore, età, visita); (f) nessun controllo "solo numeri + unità".
> 2. **MISURA PRIMA DEL RUN** su tutti i 28.294 confronti (le regole nuove non passano dall'anchor):
>    89 membri scartati dalle due porte nuove, 7 versi `gain→block`, 1.031 chiavi di controllo
>    cambiate (~650 fusioni, ~168 separazioni cliniche). **Le bandiera previste erano esatte**
>    (TGFB1 65, LPS 50, vemurafenib 20); il conteggio dei gruppi no (stimati 360, veri 305: la mia
>    dedup non era quella dello Stadio 4).
> 3. **DELIVERABLE: 312 → 305 gruppi, ma studi-slot 2.076 → 2.158.** Meno gruppi, più studi dentro:
>    è quello che devono fare le fusioni. Bandiera: SARS 38 (=), TGFB1 61→**65**, LPS 41→**50**,
>    enzalutamide 29 (=), vemurafenib 19→**20**.
> 4. **CENSIMENTO: 296 coerenti (97,0%), 9 incoerenti** (v12: 297/312 = 95,2%). Verifica per
>    IDENTITÀ, non a campione: **242 gruppi hanno l'insieme dei membri identico a v12** (confronto
>    di insiemi, gruppo per gruppo) → stesso verdetto; **riletti i 63 restanti** (51 cambiati + 12
>    nuovi), uno per uno.
> 5. **CHIUSI**: cytokine_stimulation, U0126, `2_gram`, IAA, dTAGv-1, auxina, `affected` (spariti);
>    **HIV-1** (k=6 tutti sperimentali, i 2 clinici separati sotto soglia); **TP53** — il caso più
>    istruttivo: il gruppo `gain` che mescolava knockout e sovraespressione è sparito e ne è nato uno
>    **`block` k=3 pulito**. La regola non ha solo tolto un membro: ha fatto nascere una meta-analisi
>    corretta che prima non esisteva.
> 6. **I NOVE INCOERENTI, detti senza sconti**: 4 invariati (Recurrence, adenoma, CSF2, PTSD —
>    nessuna regola scritta per loro, per scelta); influenza migliorata (da 2 clinici su 10 a 1 su 9,
>    GSE113210 usa le sigle `AV`/`CV` per le visite e nessuna regola generale può dedurlo); **4 nuovi
>    o resi visibili dalla crescita** — IFN-α (GSE126517 misura R5020, e compare identico anche nel
>    gruppo R5020), IL1A (mescola IL-1β, che ha un gruppo proprio k=26), IL3 (larve di nematode),
>    DCVC (tre contrasti sotto un'entità). **È il prezzo delle fusioni e va riportato.**
> 7. **RESTANO APERTI**: le etichette sbagliate con ID giusti (`CHEBI:5931` "chloride" è insulina,
>    `CHEBI:16335` "glucose" è adenosina) — da risolvere da `contrast_entity` prima del paper; la
>    frammentazione da scritture diverse (ATRA vs acido retinoico, `STR:ifna` vs `HGNC:5417`), che
>    era fuori scope.
> 8. **LIMITE DICHIARATO su TGF-β1 (decisione utente 2026-07-28)**: (a) l'entità è ancora spezzata
>    in TRE gruppi — `HGNC:11766` k=65, `STR:tgfb` k=11, `STR:tgf_b` k=3 — perché le scritture
>    `TGFb`/`TGF-B` non risolvono all'ID del gene: **79 studi-slot potenziali contro 65 usati**, i
>    tre gruppi sono internamente coerenti (è potenza persa, non un errore di contrasto);
>    `HGNC:11768` k=4 è TGF-β**2**, isoforma diversa, non va fuso. (b) `GSE233083` (`"TGF-β1 + 3C"`
>    contro `"TGF-β1 + DMSO"`) misura 3C ma finisce nel gruppo TGF-β1: impatto misurato **1
>    confronto su 4.954**. Entrambi **non si correggono**: vanno nei Methods.
> 9. **PROSSIMO = RE-POOL (~50 h), GO DATO dall'utente il 2026-07-28, da eseguire in sessione
>    pulita** insieme alla correzione delle etichette (a valle, in parallelo: verificato che
>    `canonical_name` non entra nel pooling). Handout
>    `docs/superpowers/specs/2026-07-29-REPOOL-HANDOUT.md` (il prompt di apertura lo incolla l'utente).
>    Finding `docs/findings/2026-07-28-censimento-v13.md`;
>    evidenza `analysis/audit/2026-07-28-censimento-v13/`. Script re-cluster
>    `analysis/p4-fase-f10-stage3-v13-regole.R`. Branch invariato, master invariato, no push.
>
> **Stato 2026-07-28 (RE-CLUSTER v12 ESEGUITO + CENSIMENTO SUI DATI VERI: 297 COERENTI SU 312)**:
> 🟡 **L'ancoraggio dal-contrasto è MATERIALIZZATO. Il deliverable esiste sul disco e ogni suo gruppo
> è stato letto. NESSUN re-pool: i gruppi non sono ancora poolati (I², τ², geni significativi non
> esistono). Il re-pool (~50 h) è dietro un GO dell'utente.**
>
> 1. **RE-CLUSTER v12** (`analysis/p4-fase-f9-stage3-v12-contrast.R`, 524,8 min = 8h45m, output
>    `20260727T204316Z-stage3-v12-364547a7`). ⚠️ Lo script è copia di **f8** (quello che ha prodotto
>    v10), NON di f6 come diceva l'handout: f6 non ha i due overlay di correzione dei nomi e i 144
>    gruppi erano stati misurati sull'output di v10. **11.853 cluster `mode=cgroup`**, tutti a livello
>    5, prefisso `cgroup_L5_`, le tre colonne del contrasto popolate 11.853/11.853. Record `pair` e
>    `group` in ingresso **identici a v10** (87.081 / 187.704): il builder è additivo, provato sui dati.
> 2. **BANDIERA tutte sopra il pavimento**: SARS 38 (28) · TGFB1 61 (38) · LPS 41 (26) · enzalutamide
>    29 (24) · vemurafenib 19 (13). NB: `smoke-bandiera.csv` è ANTERIORE alle correzioni del 26/07 ed
>    è stale (dà TGFB1 27, enza 21); i pavimenti veri sono nel censimento del 27/07.
> 3. **USCITA DEI TRE RAMI** (ADR-0026 + decisione utente), in TDD: `stage4_default_config()$deliverable_methods`
>    di default `"rem_group"`; `mega`/`mega_aug`/`rem` restano nel codice e tornano raggiungibili
>    chiedendoli. Quattro test usavano fixture anteriori ad ADR-0025 (senza `cgroup`) e sono stati resi
>    espliciti. stage4 **794 PASS / 0 FAIL** (+2 ERROR pre-esistenti), stage3-contrast 228 PASS.
> 4. **IL NUMERO NON È 144, È 312.** Delle 144 chiavi censite 140 si ritrovano; le 4 "perse" erano
>    artefatti del proxy `NAME:` della misura (ipossia da k=9 a 37, SARS dentro i 38). **Zero gruppi
>    persi, k mai calato, 113 rafforzati.** Ma **242 chiavi nuove**: il 60% del deliverable non era mai
>    stato letto. Il 97,2% valeva su un altro insieme.
> 5. **CENSIMENTO SUI DATI VERI, TUTTI E 312 LETTI UNO PER UNO: 297 coerenti (95,2%), 15 incoerenti.**
>    Frequenza quasi identica fra nuovi (8/187 = 4,3%) e già letti (7/125 = 5,6%). **Tre gruppi
>    coerenti il 27/07 sono oggi incoerenti** (influenza, HIV-1, adenoma): non è cambiato il metro, è
>    cambiata la loro composizione. I 15 si raggruppano in **cinque meccanismi**, non quindici casi:
>    clinico-vs-sperimentale · entità che è una classe · entità che è un reagente (auxina, dTAGv-1:
>    induttori degron) · direzioni opposte sotto lo stesso verso (TP53 KO + overexpression) · residui
>    noti (CSF2, PTSD, Recurrence, `iL3` = larve di nematode, `2_gram` = dose come chiave).
>    **Tre regole generalizzabili chiuderebbero 7 dei 15 → 97,4%. NON scritte: servirebbe un altro
>    re-cluster, è decisione dell'utente.**
> 6. **Difetto di identità trovato e misurato**: `.ca_combo_from_labels()` calcola gli agenti del
>    trattato assenti dal controllo ma li usa solo se ≥2; con uno solo l'entità si risolve dal valore
>    intero e ripesca la parte comune (`TGF-β1 + 3C` vs `TGF-β1 + DMSO` → TGFB1). **Impatto misurato:
>    1 confronto su 4.954.** ⚠️ Due metri sbagliati prima di quello giusto (il primo non trovava
>    nemmeno il caso di partenza): riportato solo il terzo perché gli altri erano ciechi.
> 7. **Le ETICHETTE sono sbagliate su decine di gruppi, gli ID no** (CHEBI:63637 mostrato come "sodium
>    aurothiomalate" è vemurafenib; CHEBI:85993 "PI(18:0/18:3)" è palbociclib; MeSH:D008180 "cancer" è
>    il lupus). Verificato coi resolver: **gli ID sono tutti giusti**. Le etichette del paper vanno
>    prese risolvendo `contrast_entity`, non leggendo `canonical_name`.
> 8. **FRAMMENTAZIONE: 16 entità in due o più gruppi** — TGF-β1 in quattro (61+11+3+3), nutlin-3a in
>    tre (con **due ID ChEBI** per la stessa molecola), TNF-α in due (gene vs ChEMBL). Non è
>    incoerenza (i gruppi sono puliti), è potenza buttata. Metà è dovuta a **tipi di controllo tenuti
>    separati pur essendo lo stesso controllo** (`vehicle_untreated` / `no treatment` / `unstimulated`
>    / `RPMI media`): chiuderla recupererebbe DHT 27→30, LPS 41→44, IFN-γ 30→33.
> 9. **PROSSIMO = decisione utente**, in questo ordine: (a) chiudere i 5 meccanismi + la
>    frammentazione dei controlli con un altro re-cluster (~9 h), oppure (b) GO sul re-pool (~50 h)
>    sui 312 così come sono, scartando i 15. Finding
>    `docs/findings/2026-07-28-censimento-v12-dati-veri.md`; evidenza
>    `analysis/audit/2026-07-28-censimento-v12/` (`bundle-v12-compatto.txt` = il file letto,
>    `verdetti.csv`, `frammentazione.csv`). Branch invariato, master invariato, no push.
>
> **Stato 2026-07-27 (L'INNESTO È FATTO — LA PIPELINE CHIAMA LE REGOLE; 141 COERENTI SU 145 CENSITI)**:
> 🟡 **I record di gruppo nascono dal CONTRASTO dentro `build_stage3_clusters()`. Equivalenza col gate
> misurato verificata membro per membro. Censimento fatto su TUTTI i gruppi. NESSUN re-cluster,
> NESSUN re-pool: niente è materializzato, il deliverable sul disco è ancora quello vecchio.**
>
> 1. **ADR-0025 + innesto** (`R/stage3-contrast-anchor.R` nuovo, `.build_contrast_group_records()` in
>    `R/stage3-build.R`): un record per ogni comparison, `mode = "cgroup"`, chiave
>    `entità-delta || verso || tipo-di-controllo`, un solo livello (5), nessuna partizione per hard
>    filter. Le regole del gate (`.cg_*`) e della riga (`.rp_row_defect`) sono **richiamate, non
>    riscritte**. Stadio 4: il ramo `rem_group` consuma i `cgroup` e risolve per comparison.
>    **`rem`, `mega`, `mega_aug` non toccati** (test di non-regressione).
> 2. **EQUIVALENZA sui 38.440 contrasti veri**: verdetto identico al gate sul **99,4%** dei membri;
>    a livello di gruppo **zero persi, k IDENTICO su tutti e 144**, uno nuovo. Bandiera esatte: SARS
>    28, TGFB1 27, LPS 26, enzalutamide 21, vemurafenib 13.
> 3. **DODICI BUG MIEI**, nessuno visibile dai test unitari, tutti trovati misurando: nome giudicato
>    per lunghezza (565 entità vere scartate: TNF, RSV, CMV, HBV), `{.x}` in un log che uccideva il
>    build, safety a livello 5, dosi tolte coi separatori (253 combo perse), guardia sulle sigle al
>    posto sbagliato (`M.tb + CMV`), vocabolario diverso dal gate (102 membri + combo inventate),
>    prefisso `NAME:` non tolto (66 membri), entità risolta da tutti i valori invece che dalla classe
>    dominante, ombrella non controllata sull'entità, classe `time` non filtrata.
>    **Lezione: quando una regola passa da script a pacchetto, vocabolario e guardie vanno portati
>    CON lei, allo stesso posto.**
> 4. **CENSIMENTO su TUTTI i 145 gruppi, letti uno per uno**: **141 coerenti (97,2%)**, 866/878
>    studi-slot. Incoerenti: CSF2, PTSD, RSV (gli **stessi tre** del 2026-07-25) + `MeSH:D012008`
>    Recurrence (nuovo). Nessuna regola inventata per prenderli: tre casi su 145 sono una lista
>    travestita.
> 5. **FRAMMENTAZIONE misurata, decisione da riaprire**: enzalutamide `CHEBI:68534` k=21 + `STR:enza`
>    k=4; TGFB1 `HGNC:11766` k=27 + `STR:tgfb` k=7. Non è incoerenza (entrambi i gruppi sono puliti):
>    è potenza buttata. La decisione del 2026-07-26 (niente ri-mappaggio) era basata su "0 gruppi
>    NUOVI" — vero — ma il guadagno di POTENZA sui gruppi esistenti non era stato quantificato.
> 6. **k≥3 NON è più definitivo**: ADR-0026 §Aperto propone (senza deciderlo) un livello dichiarato a
>    k=2 per il ramo `cgroup`, al posto di `mega_aug`. Finché l'utente non decide, k≥3 resta.
> 7. **PROSSIMO = RE-CLUSTER (~8h), autorizzato dall'utente il 2026-07-27.** Handout operativo:
>    **`docs/superpowers/specs/2026-07-28-RECLUSTER-HANDOUT.md`**. Aggiornamento
>    ORARIO obbligatorio durante il run. Il re-pool (~50h) resta dietro un GO separato.
>    **Cache del recupero-nome: NON va bumpata, resta v7** — verificato che dal bump l'unica modifica
>    ai file del recupero-nome sono 7 righe di commento. Fuori dal deliverable: `mega` (ADR-0026),
>    `mega_aug` e `rem` (decisioni utente 2026-07-27; i 12 `rem` sono 6 meta-analisi, 5 minestroni, e
>    l'unica pulita e' gia' nel ramo nuovo con k piu' alto). Numeri di riferimento: **144 gruppi, 140
>    coerenti (97,2%)**, TGFB1 k=38, enzalutamide k=24, SARS k=28, LPS k=26. Finding
>    `docs/findings/2026-07-27-equivalenza-builder-contrasto.md` e `-censimento-145-gruppi.md`.
>    Branch invariato, master invariato, no push.
>
> **🔗 SESSIONE PARALLELA "MEGA" (branch `mega-recovery-2026-07-27`, worktree
> `/home/user/simulomicsr-mega`)**: ha censito il ramo `mega`, mai verificato prima, e l'utente ha
> deciso che **esce dal deliverable** (**ADR-0026 Accepted**, nessun codice rimosso: è selezione, non
> cancellazione). Misure a copertura 100%: dei 11.874 campioni poolati nei 99 cluster mega, **74%
> viene da studi che portano UN SOLO braccio**; le 99 mega sono in realtà **55 meta-analisi distinte**;
> **I² e τ² sono NA su tutte** le 1,75 M di righe — quel ramo non può riportare l'eterogeneità.
> `.build_group_records()` **resta** (i record `group` servono come pool donatore di `mega_aug`).
> **Si applica prima del RE-POOL, non prima del re-cluster.** Restano APERTI: `mega_aug` (419 cluster,
> 167 coerenti ma k=2 e 88% con campioni prestati) e `rem` (12 cluster, 10 minestroni). Riassunto:
> `docs/superpowers/specs/2026-07-27-mega-recovery-SESSION-SUMMARY.md`.
>
> **Stato 2026-07-26 (REGOLE IN PRODUZIONE CON TDD — 141 GRUPPI COERENTI SU 144, MISURATI COL CODICE VERO)**:
> 🟡 **Le regole di riga E le regole del gate sono codice di pacchetto, testate test-first, verificate
> equivalenti allo script sui dati veri e RIMISURATE col codice di produzione. Nessun re-cluster,
> nessun re-pool: niente e' materializzato.**
>
> 1. **Regole di RIGA** (`R/stage3-row-pairing.R`, 67 test): tempo non appaiato · soggetto/linea
>    diversa (**solo nei disegni di trattamento**: nei caso-controllo di malattia i soggetti diversi
>    sono obbligatori) · genetica su un braccio solo · combinazione non catturata.
>    Misura sulle 1.851 righe gia' verificate a mano: **139 segnalazioni, 139/139 difetti VERI**
>    (il primo rilevatore: 186 segnalate, 96 vere = 52%). Le 43 in piu' non sono un criterio piu'
>    largo: sono difetti che non poteva vedere (tempi dentro gli underscore, `CWR-22Rv1`, linee
>    diverse in GSE186341).
> 2. **CINQUE BUG MIEI** trovati misurando: `_` e' carattere di parola per le regex; la regex dei
>    codici pretendeva la cifra nel primo segmento; un token condiviso qualsiasi annullava la
>    segnalazione; la stoplist conteneva il **candidato grezzo** del resolver (disinnescava la regola
>    in silenzio); la soglia sui token scartava `TNF-` e `IL-1`.
> 3. **Regole del GATE** (`R/stage3-contrast-gate.R`, 102 test): verso, anatomia, materiale,
>    contrasto rotto, baseline, infezione clinica vs sperimentale, resistenza, controlli non validi,
>    multiclasse, ombrelli, on-contrast. **Equivalenza verificata su 19.863 etichette / 38.440
>    contrasti**: 624 differenze, tutte a favore del pacchetto (lo script non vedeva oltre un
>    underscore: `_doxycycline`, `Baseline_Control`, `CON_1_input`, `Patient_081`).
> 4. **RIMISURA COL CODICE DI PRODUZIONE** (gate v11): **stessi 144 gruppi, composizione identica,
>    0 gruppi da rileggere**. I numeri pubblicati sono quelli del codice che verra' eseguito.
> 5. **DELIVERABLE**: 145 → **144 poolabili**, 143 → **141 coerenti (97,9%)**, 866/875 studi-slot.
>    Scartati **2.722 membri (7,1%) = 1.110 confronti**. Persi i 2 gruppi previsti (bosutinib,
>    RSV-uninfected); RSV ricompare sotto un altro controllo ed e' **incoerente** (clinico +
>    sperimentale). Incoerenti: CSF2, PTSD, RSV.
> 6. **Bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` v6 → v7**: le guardie del resolver erano entrate
>    in produzione senza bump (la trappola che e' gia' costata 8 ore).
> 7. **Ri-mappaggio del resolver: MISURATO (0 gruppi nuovi, 1 rafforzamento, 50 membri) → DECISIONE
>    UTENTE 2026-07-26: NO (opzione A).** Le guardie continuano a rifiutare senza proporre il nome
>    giusto; `cancer`/`ifn`/`ml` non sono ri-mappabili per principio. Riapribile dopo il re-cluster,
>    solo per la leggibilita' delle etichette.
> 8. **PROSSIMO**: l'innesto nel build (i record **group** devono nascere dal CONTRASTO — opzione B,
>    `.build_group_records` in `R/stage3-build.R:473`), poi GATE UTENTE per re-cluster + re-pool.
>    Handout `docs/superpowers/specs/2026-07-27-NEXT-SESSION-HANDOUT.md`; finding
>    `docs/findings/2026-07-26-stage3-row-pairing-rules.md`. Branch invariato, master invariato, no push.
>
> **Stato 2026-07-25b (NOTTE AUTONOMA — COERENZA 98,6% + AUDIT SISTEMATICO DEL RESOLVER)**:
> 🟡 **145 poolabili, 143 coerenti (98,6%) censiti uno per uno; il resolver ha una guardia di
> precisione IN PRODUZIONE, con TDD e misura prima/dopo. Nessun re-cluster, nessun re-pool.**
>
> 1. **Mandato utente**: (a) gli 11 incoerenti non sono recuperabili → scartarli; (b) «il bug THPO non
>    è il solo di quel tipo, va indagato»; otto ore autonome, «soluzioni non ipotesi».
> 2. **(a) COERENZA 98,6%** (143/145, 890/896 studi-slot). Scarto **per costruzione** — non con una
>    lista di chiavi: soglia sui caratteri della *parte* (co-infezione M.tb+CMV), combo senza
>    separatore, infezione **clinica vs sperimentale** decisa sul trattato, controllo che non è un
>    controllo ("total RNA"), resistenza asimmetrica, delta multi-classe, **entità tenuta costante**
>    fra i bracci, label degenere, **dedup per entità** (policy ADR-0022). Residui: 2 cluster k=3
>    (CSF2 polarizzazione M1/M0, PTSD dentro-malattia). Costo: 2 cluster persi, entrambi **duplicati**
>    di entità sopravvissute. Più forti: SARS k=29, LPS k=28, TGFB1 k=27, JQ1 k=24, enzalutamide k=21.
> 3. **(b) IL BUG THPO È UNA CLASSE.** Sinonimi formalmente validi che collidono col gergo di
>    laboratorio: `ml`→THPO, `lap`→TGFB1 (Lap = lapatinib), `in`→CD44, `cancer`→**granchio**,
>    `5fu`→5-formiluracile, `dha`→diidrossiacetone, `tpa`→ac. tereftalico, `shh`→vorinostat,
>    `mek`→butanone, `nmda`→ketamina, `hgf`/`tpo`/`hgi`→IL6, `ifn`→IFNA1.
> 4. **Misura sulla produzione** (cache recupero-nome + testo H5 vero): 28.556 campioni con ID
>    ontologico; 414 alias sospetti (4.649 campioni); **adjudicati i 170 più impattanti → 78
>    collisioni**, di cui **5 poi RITRATTATE** ri-leggendo il testo sorgente (`lead` era davvero
>    piombo, `ser` serina, `mc` 3-metilcolantrene, `il1` IL-1α, `iaa` auxina-induttore): bloccarle
>    avrebbe cancellato 143 nomi corretti. Tabella finale **71 coppie**. ⚠️ Una prima cifra automatica (51%) era SBAGLIATA e l'ho corretta prima
>    di usarla (contava `cisplatin` in ChEBI+ChEMBL come ambiguo).
> 5. **Regola generale tentata e SCARTATA sui dati** (una sigla vale solo se l'entità è nominata per
>    esteso nel corpus): precisione 61%, copertura 46%, **danno 25%** — avrebbe perso PFOS, DNCB, DHEA.
> 6. **FIX in produzione**: `R/resolver-guards.R` (unità di misura, parole funzionali, 76 coppie
>    alias→ID accertate) innestato nei 4 resolver + TDD (`test-resolver-guards.R`, 57 PASS/0 FAIL).
>    **Prima/dopo su 26.936 campioni**: 949 identità sbagliate rimosse (3,52%), 96,5% invariate;
>    Neoplasms 354→0, IFNA1 119→0, THPO 36→0, IL6 33→0; **non-regressione perfetta** (LPS 401→401, SARS 308→308,
>    enzalutamide 89→89, TNF 275→**281**). Il fix ha chiuso da solo il cluster TGFB1.
> 7. **VERIFICA RIGA PER RIGA** (1.851 righe, tutti i 143): **96 righe mal appaiate (5,2%)** — tempo
>    non appaiato 42, controllo di linea/donatore diverso 29, combinazione non vista 13, genetica su un
>    braccio solo 12. 90 altre segnalazioni erano falsi allarmi (nei disegni malato-vs-sano i soggetti sono per forza
>    diversi). **DECISIONE UTENTE: si scartano** → 143 → **141 gruppi**. Nessun verdetto cambia.
> 8. **PROSSIMO**: implementare lo scarto delle righe come regole, poi portare le regole del gate dagli
>    script d'analisi al **codice di pacchetto con TDD**
>    (+ bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`), decidere sul ri-mappaggio (oggi si rifiuta e
>    basta), poi GATE utente per re-cluster+re-pool. Handout
>    `docs/superpowers/specs/2026-07-26-NEXT-SESSION-HANDOUT.md`; finding
>    `docs/findings/2026-07-25-resolver-alias-collisions.md`.
>
> **Stato 2026-07-25 (ANCHOR DAL-CONTRASTO v7 — RESIDUO CHIUSO + RI-CENSIMENTO SU TUTTI: 92,7%)**:
> 🟡 **150 poolabili k≥3, coerenza 92,7% (139/150) misurata su TUTTI uno per uno. NON validato, NON
> finale: nessun re-cluster lanciato. 11 falliti residui catalogati per causa.**
>
> 1. **DECISIONI UTENTE**: (a) la **direzione opposta NON si fonde** → il verso (gain/loss/block) entra
>    nella chiave dell'anchor; (b) **verso non determinabile → si scarta il cluster**.
> 2. **Numeri**: 150 poolabili k≥3 (74 con k≥5, v6 70); **139 coerenti = 92,7%**; 866/934 studi-slot nei
>    coerenti. ⚠️ **NON confrontabile con l'81% di v6** (rubrica di giudizio più severa). Il confronto
>    valido è la chiusura uno-per-uno dei falliti v6, **verificata sui dati** (`87-v6-failures-closure.R`):
>    **19 casi su 20 CHIUSI**, 1 aperto (HBV clinico-vs-sperimentale).
> 3. **Regole nuove, tutte deterministiche e tutte derivate dai falliti veri**: on-contrast a parola intera
>    su token distintivi; nome del cluster canonicalizzato nello stesso spazio-ID; **verso** nella chiave;
>    **combo = entità a sé** rilevata anche dal label; **materiale per braccio**; baseline propria;
>    **contrasto rotto** (anatomia/materiale/tipo cellulare disgiunti) → membro droppato; infezione
>    **clinica vs sperimentale**; firma delle **classi** del delta.
> 4. **Tre bug MIEI trovati misurando e corretti**: `anatomy_of()` faceva `gsub` prima di `tolower`
>    (AML-vs-"Normal Lung" passava indenne); la mia sanitizzazione spezzava `sars-cov-2`→`sars-cov` (SARS
>    2003, 166 membri sull'entità sbagliata); `\b` non vede `calcium_low` (`_` è carattere di parola).
> 5. **Bug di PRODUZIONE ortogonale (nomi)**: `.normalize_cytokine_to_hgnc` risolve **ogni etichetta con
>    `ug/ml` a THPO** (ImmPort ha `ML` come sinonimo di *Thrombopoietin*) — stessa famiglia di ethanol→TNF.
>    Non toccato (i nomi sono ortogonali alla coerenza): **decisione utente aperta**.
> 6. **Limite nuovo — frammentazione**: ~10 cluster in eccesso (LPS 27+3, SARS 31+3, enzalutamide 22+4,
>    TGFB1 28+7, ipossia 9+9+6, nutlin 4+3 = due ID ChEBI per lo stesso farmaco…). Costa k, non coerenza.
> 7. **PROSSIMO**: handout `docs/superpowers/specs/2026-07-26-stage3-contrast-anchor-NEXT-SESSION-HANDOUT.md`
>    (chiudere gli 11 + la frammentazione, ri-censire, poi GATE utente prima della Fase 2 in produzione).
>    Finding `docs/findings/2026-07-25-stage3-contrast-anchor-v7-census.md`; verdetti
>    `analysis/audit/2026-07-24-anchor-coherence-sim/v7-census-verdicts.csv`. Branch invariato, master
>    invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-24b (ANCHOR DAL-CONTRASTO — SIMULAZIONE ITERATA + CENSIMENTO SU TUTTI I CLUSTER)**:
> 🟡 **Design validato in simulazione all'81% (TUTTI i cluster) / ~89% (deliverable). NON finito, NON
> "una soluzione". Residuo catalogato. Nessun re-cluster. Handout+prompt pronti per la prossima sessione.**
>
> ⚠️ **DUE ERRORI MIEI in questa sessione, ritrattati (stesso errore dei mesi scorsi, in piccolo):**
> (a) ho scritto "DESIGN VALIDATO/soluzione" avendo misurato solo il **k recuperato** (287 poolabili) e la
> preservazione (farmaci 8/8) **senza verificare la coerenza** → verificata: **72%**, non 100%;
> (b) ho lasciato passare entità-spazzatura (`STR:t`, `STR:d`, `STR:dox`) come chiave di clustering = slop.
>
> 1. **Meccanismo che funziona**: entità = DELTA trattato↔controllo, hybrid on/off-contrast (i membri il
>    cui delta tocca l'entità del cluster la ereditano coerente; gli altri risolvono il proprio delta e si
>    staccano) + control_type preso dal **lato-controllo del delta**. SARS ricomposto pulito **k=34** (era
>    3 frammenti 7+4+4).
> 2. **Gate irrigidito (v5→v6)**: stoplist entità (min 4 char, no parole generiche high/low/positive/
>    mutant/chemotherapy…), blacklist ID (doxiciclina=induttore, DMSO=veicolo, "organic cation"/"steroid"/
>    MeSH:Neoplasms=classi-ombrello), **combo=entità a sé** (decisione utente), control material-aware.
> 3. **CENSIMENTO COERENZA SU TUTTI I CLUSTER** (mandato utente, mai a campione): v5 **74% (162/219**,
>    15 batch) → v6 **81% (159/196)** su tutti, **~89% sul deliverable** (escl. 16 bucket `+COMBO` = combo
>    staccate dai mono ORA puliti: enzalutamide/fulvestrant/palbociclib/osimertinib/DHT/estradiolo mono
>    tutti one_contrast).
> 4. **Residuo = 15 falliti veri (84 studi-slot su 965, ~9%)**, catalogati: baseline-material 5
>    (tessuto-vs-plasma), **direzione opposta 4** (agonista+antagonista → DECISIONE UTENTE APERTA), combo
>    non catturate 4 (rilevatore combo cattura `+` ma non `/` e `and`), umbrella 3, misti 2, longitud. 1.
> 5. **Strategia di recupero quantificata**: (A) SPLIT (vemurafenib 12/12, covid 13/13, HCC-tessuto 8/9,
>    RA 5/6, bleomicina mono k=3 + combo k=3 = entrambi validi); (B) RIPULITURA (droppa i MEMBRI con
>    controllo incongruo, tieni il cluster); (C) SCARTO (entità da nomi sbagliati, aggregati vaghi,
>    trattamento ignoto). Stima ~50-60 slot recuperati, ~25-30 scartati.
> 6. **Vincolo di pubblicabilità (utente)**: pipeline+gate **DETERMINISTICI** — la coerenza nasce per
>    costruzione dell'anchor, NON da un giudice LLM a runtime; nessun Claude nella pipeline né nella
>    validazione pubblicata (evaluator = Mistral self-hosted). I subagent Claude sono solo audit interno.
> 7. **PROSSIMA SESSIONE**: handout `docs/superpowers/specs/2026-07-25-stage3-contrast-anchor-NEXT-SESSION-HANDOUT.md`
>    + prompt `docs/superpowers/specs/2026-07-25-NEXT-SESSION-PROMPT.md`. Prima cosa: chiedere all'utente
>    la decisione sulla DIREZIONE OPPOSTA. Poi implementare A+B+C e **ri-censire su TUTTI**. Evidenza
>    `analysis/audit/2026-07-24-anchor-coherence-sim/` (engine, gate v6, cataloghi, FASE1-RESULT.md).
>    Branch invariato, master invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-24 (REWORK ANCORAGGIO — CAUSA RADICE PROVATA + DESIGN MISURATO SULLA COERENZA, GATED)**:
> 🟡 **Causa radice provata e design candidati misurati sulla coerenza su campione (nessun re-cluster).
> Decisione di design in attesa dell'utente.** (Nessuna dichiarazione "finale/paper-grade": è un design
> validato, non un deliverable.)
>
> 1. **CAUSA RADICE (provata):** l'anchor è **comparison-blind** — ancora sulla perturbazione del campione
>    TRATTATO, non su ciò che il CONTRASTO isola (il delta trattato↔controllo). Prova SARS `b6a3eabd`:
>    infezione-vs-mock + farmaco-vs-DMSO (SARS held-constant) + KO-genetico sotto un anchor. Scala: dei
>    1.674 cluster k≥3 risolvibili, 59,8% mescola ≥2 classi-contrasto, 76,8% ≥2 tipi-controllo.
> 2. **METODO (validate-before-fullrun):** riparto dai contrasti già ricostruiti
>    (`per-member-contrasts.parquet`, 38.440 membri/7.886 cluster), firma-di-contrasto per membro
>    (control_type + classe-delta + entità-delta via `factor_levels`), ri-partiziono ogni cluster
>    (within-cluster = LOWER BOUND, no merge cross-cluster), **verifica LLM** subagent (rubrica deep-dive
>    identica). Engine + script + verdetti: `analysis/audit/2026-07-24-anchor-coherence-sim/`.
> 3. **RISULTATI:** Design A (solo control_type) **INSUFFICIENTE = 11% coerente (3/28 LLM)**
>    ("vehicle_untreated" troppo grezzo, il trattato resta eterogeneo). Design B/C (delta-entity, proxy
>    dell'anchor derivato-dal-contrasto) **= 80% coerente (89% escl. classe `<none>`)**: i minestroni noti
>    si sciolgono (SARS→"SARS vs mock" k=7 pulito; enzalutamide/fulvestrant/osimertinib/R1881/vemurafenib/HCC
>    puliti). **~95-107 meta-analisi difendibili k≥3** (lower bound within-cluster) vs **26/184** oggi.
> 4. **TRADE-OFF misurato:** k crolla (mediana 8→3-4), le malattie collassano (13 poolabili disease, k_med 3).
>    CAVEAT: il proxy grezzo-da-label sovra-frammenta (spezza 18/26 coerenti; SARS-infezione in 3 pezzi
>    k=7+4+4 che con entità **canonica** `NCBITaxon:2697049` diventano k=15) → il design VERO usa il
>    **resolver esistente sul DELTA**, recuperando k = il lavoro del build.
> 5. **RACCOMANDAZIONE = Opzione B** (re-anchor a monte: entità-delta canonica + control_type + drop
>    degeneri, ~8h re-cluster + ~50h re-pool) con **Opzione C** (filtro a valle, stesso split senza merge,
>    ~50h) come ripiego economico. **DECISIONI APERTE per l'utente** (spec §6): direzione B vs C, soglia k,
>    trade-off k↔coerenza, disease low-k, combo.
> 6. **Output:** finding `docs/findings/2026-07-24-anchor-contrast-coherence-simulation.md`; spec di design
>    `docs/superpowers/specs/2026-07-24-stage3-contrast-anchor-design.md`; evidenza
>    `analysis/audit/2026-07-24-anchor-coherence-sim/`. **GATE: nessun re-cluster finché l'utente non sceglie
>    il design.** Branch invariato, master invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-23c (COERENZA CLUSTER Stadio 3 — VERIFICATA, problema CORE del RED ALERT)**:
> 🔴 **La coerenza di contrasto dei cluster — mai verificata in v5→v10 — è ora misurata su OGNI
> cluster k≥2 (13.287), con la prova accanto a ogni verdetto. Verdetto onesto: la maggior parte dei
> raggruppamenti NON mette insieme campioni che misurano lo stesso contrasto.**
>
> 1. **Metodo (spec/plan `docs/superpowers/{specs,plans}/2026-07-23-stage3-cluster-coherence-verification-*`,
>    approvato + subagent-driven)**: ricostruzione del contrasto via **dispatch reale Stadio 4**
>    (`.lookup_cmp`/`.lookup_cmp_by_treated_group`/`.lookup_rg`) → segnali deterministici A/C su tutti i
>    13.287 (omogeneità del controllo + degenere, `R/stage3-coherence.R` testato) + consistenza ADR-0021
>    sui 714 poolati (riuso `R/stage4-consistency.R`, validato 15/15 a 1e-17) + **deep-dive LLM (8
>    subagent, D2 "un contrasto o molti?") sui 184 rem_group**, con verifica controller (~92% accordo su
>    24 cluster). Nessuna metrica inventata. Verdetto AND multi-asse.
> 2. **Risultato (DELIVERABLE = 184 rem_group)**: **157/184 (85%) MINESTRONE** (non difendibili), 1
>    incerto, e solo **26/184 (14%) COERENTI = difendibili** (stesso contrasto). DEFINIZIONE (utente
>    2026-07-24): coerente = genera una meta-analisi difendibile (stesso contrasto); la barriera è
>    binaria, la **consistenza (k, I²) è la FORZA da riportare non il gate** — dei 26, **19 anche forti**
>    (consistenza≥0,5, 11/19 k<5). **13/184** con un contrasto degenere. **Vetrina Layer B v10: 0/9
>    raggiunge la barriera** (7 minestrone, 2 coerenti ma deboli/I² alto: RSV, RCC).
> 3. **Prove reali**: SARS `b6a3eabd` mescola infezione+farmaco+gene; M.tuberc `274f387d` dominato da
>    COVID/sepsi/dengue; `2bd06550` pool­a DHT (agonista) + Enzalutamide (antagonista, segno opposto);
>    disease_vs_normal inghiotte malattie diverse sotto un nome (SLE+Crohn+SLA…). Bug ORTOGONALE: alcuni
>    coerenti hanno canonical_name sbagliato (ethanol→TNF, anisole→calcitriolo).
> 4. **Diagnosi gate**: ADR-0022 è solo strutturale (L2-L4+group+k_eff≥3+dedup), ZERO check coerenza →
>    ammette 86% non-coerenti. Gate di coerenza proposto → 19/184. **La causa radice è a monte: l'anchor
>    entità+tessuto è troppo grezzo (L3/L4) e inghiotte contrasti diversi.**
> 5. **Onestà**: la vetrina "publication-grade" della sessione precedente NON lo era (cluster non
>    verificati). Fix del mio strumento in corsa: `frac_degenerate` fl-based dava falsi positivi (Hypoxia)
>    → degenere = uguaglianza label (54→13). Finding `docs/findings/2026-07-23-stage3-cluster-coherence.md`.
>    Codice `R/stage3-coherence.R`+test; script+tabelle `analysis/audit/2026-07-23-coherence/`.
> 6. **PROSSIMO = decisione utente**: (a) adottare il gate di coerenza (ADR nuovo, soglie k+consistenza)?
>    (b) ricostruire la vetrina solo sui sopravvissuti + fix nomi, o (c) **rework dell'anchoring a monte**
>    (il vero fix). Branch invariato, master invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-23 (LAYER B v10 — 18 case study rem_group)** — ⚠️🔴 **RITRATTATO 2026-07-24: NON
> "publication-grade", NON un "deliverable finale".** La verifica di coerenza ha mostrato che dei 9
> flagship di questa vetrina **0/9 sopravvivono**. Il blocco sotto descrive la meccanica del build
> (corretta), non la validità scientifica (assente finché l'anchoring non è rifatto):
> 🟢 **Il Layer B sulle meta-analisi nominate v10 è girato: 18 bundle
> (10 flagship + 8 extra), 108 plot, report HTML reso, wall 11,7 min.**
>
> 1. **Run notturno autonomo** (handout `docs/superpowers/specs/2026-07-22-layer-b-v10-NEXT-SESSION-handout.md`):
>    build `analysis/p5-stage4-layer-b-build-v10.R` sotto setsid sulla selection
>    `analysis/layer-b-selection-v10.csv` (18 case study, tutti `rem_group`, exists_in_stage4=TRUE).
>    Output `analysis/p4-output/20260722T215752Z-layer-b-d7a475bb/` (gitignored): 18 sottodir bundle
>    (volcano/forest/MA/heatmap/heterogeneity/GO + top_genes + summary_card + narrative.qmd stub) +
>    `layer_b_report.html` (35 MB, standalone) + `run_metadata.json` + `selection_resolved.csv`.
> 2. **Copertura**: 7 malattie (RCC/lung/gastric/hepatocell/colorectal/breast/prostate), 5 farmaci
>    (bleomicina/physostigmine/tamoxifen/enzalutamide/fulvestrant), 5 patogeni (RSV/influenza/LPS/
>    SARS/M.tuberc), 1 citochina/gene (TGFB1). Le 6 bandiera del re-gate opzione C tutte presenti.
> 3. **BUG scoperto+chiuso durante il run (paper-grade)**: la macchina Layer B (ADR-0017, 2026-05-24)
>    è ANTERIORE al ramo `rem_group` (ADR-0022) → non gestiva quel method. Due crash con stessa causa,
>    chiusi in blocco (no whack-a-mole) mappando TUTTI i dispatch su `method`: (a) mancava
>    `.build_group_rem_dispatch_from_stage3` nello script di build (nessun cluster risolto in campioni);
>    (b) `rem_group` assente dal dispatch di `.build_forest`/`.build_heterogeneity_panel`/`.build_summary_card`
>    (τ²). Fix ADDITIVO: `rem_group`→ramo `rem` (identità di schema REM: τ²/I²/Q + per-study logFC/SE),
>    replica di `R/stage4-build.R:158-171`. Validato prima di ogni rilancio (18/18 risolti; 3 cluster
>    reali producono forest+heterogeneity; 33 test builder PASS/0 FAIL). Fix in git:
>    `R/layer-b-plot-forest.R`, `-heterogeneity.R`, `layer-b-summary-card.R`, `p5-stage4-layer-b-build-v10.R`.
> 4. **Output**: finding `docs/findings/2026-07-23-layer-b-v10-case-studies.md`, ADR-0017 Addendum,
>    ledger. **Prossimo = compilare le narrative.qmd** (Biological context/Findings/Discussion) per
>    ogni bundle → sezione Results del paper. Branch invariato, master invariato. Memorie:
>    [[project_stage3_minestrone_rework]], [[feedback_no_whackamole_systematic_debug]].
>
> **Stato 2026-07-22 (v10 LLM-FALLBACK FINALE MATERIALIZZATO)** — ⚠️🔴 **"END-TO-END COMPLETO" e
> "DELIVERABLE FINALE" RITRATTATI 2026-07-24.** Il fallback ha migliorato i NOMI e il conteggio delle
> meta-analisi (161→184), ma "senza degradare l'omogeneità" misurava l'I² del pooled, NON la coerenza
> di contrasto: i 184 restano 85% minestroni (verifica 2026-07-23). Crescere di numero cluster
> incoerenti non è progresso scientifico. Il blocco sotto è meccanicamente corretto ma NON un deliverable:
> 🟢 **L'LLM-fallback su TUTTI gli indeterminati (STR:/UNK, 50% del corpus) è dentro la pipeline
> come 2° overlay. Materializzato: meta-analisi nominate 161→184. ADR-0024 Accepted.**
>
> 1. **Misura (passi 1-4, read-only)**: funnel di allocazione su v9-final → **158.751 indeterminati**
>    (agent UNK|STR:, 50% dei cluster, **96% k=1**). Fallback Mistral su TUTTI (113.475 record, DGX
>    poddgx02 34min, 100% valid_schema): **override 50.246 (44%)**, keep 62.578, **canary 0 override**.
>    Simulazione impatto anchor-aware: 79% override isolati (rumore k=1), 21% si fondono.
> 2. **Opzione C (il passo decisivo)**: `2026-07-20-v9-fallback-poolable-gain.R` riproduce il gate
>    rem_group (ADR-0022) sul membership post-overlay SENZA re-pool → **guadagno POOLABILE reale**
>    (validato: breast k_eff_pre=23 vs v9 noto 22): **+22 nuove poolabili, +41 rafforzate, +151 k_eff**.
>    **Ha ribaltato la raccomandazione da B (documentare) ad A (materializzare).**
> 3. **Materializzazione (run pesanti gated, setsid + loop orario)**: re-cluster v10 (`p4-fase-f8-stage3-v10-final.R`,
>    2 overlay v9 k≥2 + fallback STR/UNK, SMOKE PASS, ~7,6h, `20260720T180625Z-stage3-v10-364547a7`) →
>    re-pool v10 (`p4-fase-f5-...-rebuild-v10.R`, DRY_RUN PASS, ~50,6h, `simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032`).
> 4. **Re-gate (verdetto)**: **714 cluster** poolati (v9 631), **rem_group 161→184** (+23), cluster_pooled
>    12,4M righe, sig 1,45M. **Omogeneità INVARIATA** (I²_med 79,9→77,6, range identico → fusioni
>    coerenti). **k_eff bandiera PREDETTA=REALE**: breast 22→30, colorectal 18→27, hepatocell 28→34,
>    enzalutamide 27→30, SARS 20, M.tuberc 26 (scarto ±1-3 = over-stima H5 dichiarata). ANTI-STALE PASS.
> 5. **Limite L7 (invariato)**: 71 entità nominate restano NON poolabili (treated-only, gate controllo
>    interno); 79% degli override sono k=1 cosmetici (etichetta migliore, no pooling). La de-frag NON
>    aggira l'L7 — il guadagno si concentra nelle entità con controlli interni (le bandiera).
> 6. **Output**: finding `docs/findings/2026-07-22-stage4-v10-fallback-materialization.md`, **ADR-0024**,
>    re-gate `analysis/audit/2026-07-20-stage4-v10-regate.R` (+ `-out.txt`, `-remgroup-processed.csv`).
>    **Prossimo = Layer B** (case-study sui 184 rem_group nominati, 23 nuovi) = plan separato a valle.
>    Branch invariato, master invariato. Memorie: [[project_stage3_minestrone_rework]],
>    [[feedback_hourly_updates_during_long_runs]], [[dgx_storage_projects_not_home]].
>
> **Stato 2026-07-19 (v9 DE-FRAMMENTAZIONE via overlay Mistral — END-TO-END COMPLETO)**:
> 🟢 **La side-table del name-cleanup T13 è ora DENTRO la pipeline (overlay `GSM→identità`,
> precision-gated, solo `action=="override"`). Il re-cluster v9-final FONDE i frammenti mal-nominati
> della stessa entità → le meta-analisi cross-studio nominate (rem_group) RADDOPPIANO (70→161)
> SENZA degradare l'omogeneità (I²_med 74→80, fusioni coerenti non minestroni). ADR-0023 Accepted.**
>
> 1. **Fase D Task 11-15 (run pesanti gated, setsid + loop orario)**: v9-pre (7,7h, cache lookup v6) →
>    Mistral sui sospetti (DGX, poddgx02 **riparato**, scope **k≥2**=7.176 record, 0 fail) → **fix
>    canonicalizzazione kind** (commit `4daa6e7`, TDD, 1441 PASS/0 FAIL: cytokine/pathogen grezzi→enum,
>    scarta genetic_* non-anchor) → v9-final (7,8h, **56.427 GSM corretti**, 42.773 cluster LLM_NAME_CLEANUP,
>    disease UNK 25.086→9.748) → re-pool Stadio 4 v9 (~41,3h, 631 poolati, ANTI-STALE PASS).
> 2. **Re-gate (verdetto)**: rem_group poolati **70→161 (+130%)**; omogeneità **invariata** (I²_med 74,2→79,9,
>    range 0-98 identico); **bandiera 7/7** (SARS/enzalutamide/breast/prostate/fulvestrant/tamoxifen/vemurafenib)
>    + hepatocell/colorectal/M.tuberc/LPS. cluster_pooled 10,9M righe, sig FDR<0,05 1,23M.
> 3. **Limite onesto L7**: il `k_effective` poolato << studi-membri (breast cluster Stadio3 k=277 →
>    rem_group k_eff=22): il collo di bottiglia è il **gate di controllo interno** (treated-only, L7 già
>    documentato come non-recuperabile 2026-07-09), NON più il name-recovery.
> 4. **Output**: re-cluster `analysis/p4-output/20260717T171550Z-stage3-v9-364547a7/`; re-pool
>    `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v9/20260719T105254Z-stage4-v9-a500d032/`. Finding
>    `docs/findings/2026-07-19-stage4-v9-defragmentation-results.md`, ADR-0023, re-gate
>    `analysis/audit/2026-07-19-stage4-v9-regate.R`. **Prossimo = Layer B** (case-study sui 161 rem_group
>    nominati) = plan separato a valle. Branch invariato, commit di codice pushati (su richiesta utente),
>    master invariato. Memorie: [[project_stage3_minestrone_rework]], [[dgx_storage_projects_not_home]].
>
> **Stato 2026-07-09 (augmentation "passo 3" — farmaci esclusi: recuperabile pulito = 0, CHIUSO)**:
> 🟢 **I 279 gruppi `rem_group_insufficient_in_study_controls` (trattati-solo senza controllo interno)
> NON sono recuperabili in modo difendibile. Documentato come limite noto (L7). Decisione utente:
> "recupera il recuperabile poi documenta"; esito del recupero = 0 cluster puliti.**
>
> 1. **Misura (dati veri):** 279 caduti = 195 irrecuperabili (dati troppo sottili) + 38 classe A
>    (controlli interni) + 46 classe B (prestito; 13 ben ancorati, 13 interamente prestati). Il 93% dei
>    record ha un controllo nello studio, spesso non collegato dallo Stadio 2 (disegni complessi /
>    gruppi a campione singolo). Tabella `analysis/audit/2026-07-09-stage4-279-recovery-classification.csv`.
> 2. **Validazione decisiva (test swap):** su farmaci noti-buoni (tamoxifene, enzalutamide) ho
>    sostituito il controllo interno con uno prestato da altro studio comparabile → recupero geni veri
>    **7% (tamoxifene) / 1% (enzalutamide)**, I² 92→98 / 86→99. **Più studi NON aiutano.** Il prestito
>    preserva la direzione ma distrugge la scoperta di geni (batch cross-studio non modellato).
> 3. **Recupero eseguito (verifica biologica cluster-per-cluster) → 0 puliti.** Opzione 2: i 3
>    candidati a k≥3 sono minestrone (CXCL4/IL3/IFNalpha; asma steroide/gravità/vs-sano) o con 3° studio
>    confuso (IL-4 M1/M2). Nessuna entità coerente (RCC, epatite alcolica, fegato, SM, IL-4, ovaio,
>    psoriasi) raggiunge un 3° contrasto pulito (terzi confusi/incoerenti/sbagliati; molti anche
>    mal-etichettati: Abomaso=Alzheimer, Stroma corneale=Crohn, Respirovirus=Parkinson). Opzione 3
>    (prestito): gate swap già fallito → 0 ammessi.
> 4. **Chiusura:** documentato limite L7 (`project_paper_known_limitations`). Nessun re-pool, nessun
>    codice di produzione (niente da recuperare). Finding
>    `docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`, spec/plan
>    `docs/superpowers/{specs,plans}/2026-07-09-stage4-augmentation-passo3-*`. Commit `f9f7750`+`3883f8f`
>    su branch `review-scientific-consistency-2026-06-10` (pushato). Master invariato. Memorie:
>    [[project_stage4_borrowed_controls_rejected]], [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-07b (name-cleanup Mistral — FIX RESOLVER + FULL RUN T13 END-TO-END, CHIUSO)**:
> 🟢 **Il name-cleanup è completo end-to-end. Smoke PASS (13/13 recall, 0 canary false-alarm) e full run
> T13 su 193 cluster girato (83 override, 65 noop, 14 flag_review, 31 keep). Finding
> `docs/findings/2026-07-07-name-cleanup-results.md`.**
>
> 1. **Fix #1 resolver citochine** (commit `36756ac`, TDD, `R/name-cleanup.R`): lo smoke 29665 aveva Mistral
>    13/13 semantico ma il resolver mancava le citochine full-name. Cause (dati reali): Mistral emette `kind`
>    LIBERO `"cytokine"` (schema kind=string, no enum) → dispatch nel catch-all dove MeSH precede HGNC →
>    interferon/TNF → MeSH invece del gene; + full-name non sono symbol HGNC; + `"17-beta-estradiol"` non
>    matcha alias ChEBI. Fix: `.canonicalize_resolver_kind` (vocabolario→enum) + `try_cytokine` lookup
>    **WHOLE-STRING** ImmPort/HGNC/UniProt + gate whitelist + `.normalize_greek_stereo`
>    (`17-beta-estradiol`→`17β-estradiol`). **Review adversariale (subagent)** ha trovato PRECISION LEAK
>    IMPORTANT (il 1° tentativo usava `.normalize_cytokine_to_hgnc` che fa token-extraction: `"IL-6 receptor"`
>    →HGNC:IL6 spurio) → corretto a whole-string. Verifica: 45 test resolve + 19/19 sui dizionari reali.
> 2. **Fix #2 current_ids full-run** (commit `d6587c8`, `p5-name-cleanup-run.R`): lo script passava
>    `current_ids = anchor_key` completo (`kind|ID|tissue|…`) mentre la policy confronta l'ID ontologico del
>    resolver → `noop` mai raggiunto → override/flag_review gonfiati (48/62 flag + 17/100 override = noop
>    mascherati). Fix: `current_ids = extract_anchor_summary(...)$agent_id`.
> 3. **Smoke re-eval PASS** (sulle stesse predictions 29665, resolver fixato): Recall 69,2%→**100% (13/13)**,
>    Precision 81,8%→**100%**, canary false-alarm 25%→**0%**.
> 4. **Full run T13** (job 29670, 193 record = 125 candidate + 68 canary, wall 1m31s, 193/193 valid_schema):
>    **override 83** (correzioni genuine, new_id CHEBI 34/HGNC 13/MeSH 36), **noop 65** (già corretti),
>    **flag_review 14** (disaccordi → review umana; ~3 falsi da mismatch HGNC numero-vs-symbol KRAS/SF3B1/
>    TP53), **keep 31** (resolver NONE: glioblastoma MeSH miss, Infliximab anticorpo, varianti genetiche).
>    Scope B: **31 entità ≥2 cluster, max k_merged_est 91**.
> 5. **Fix #3 IDENTITÀ DEL GENE** (commit `bb802ae` resolver + `8dcd91e` sorgente): la review dei 14 flag_review
>    ha fatto emergere che **lo stesso gene aveva due ID** — `R/anchors.R` emette `HGNC:<numero>`, il
>    recupero-nome (citochine + K2) emetteva `HGNC:<simbolo>`. **Misura su anchor v7**: 39.096 cluster con
>    gene (37.160 numerici + 1.936 sigla), **61 geni in entrambi i formati**, **80 gruppi si fonderebbero**
>    (160 cluster), **3 meta-analisi oggi perse** sotto k≥3 (PF4/TGFB1/TNF) + 2 con più potenza; 5/503 cluster
>    poolati (v8) hanno un gene, 1 frammentato; **0 alias non canonici**. **Errore di OMISSIONE** (i pool
>    esistenti restano corretti) → NON giustifica un re-cluster dedicato (~20h). Fix: **ID canonico
>    `HGNC:<numero>`** (stabile; simbolo = etichetta, come `gene_id`/`gene_symbol` FASE E1) in
>    `.normalize_cytokine_to_hgnc` + K2 + resolver; `.canonicalize_gene_id` (`HGNC:KRAS`≡`HGNC:6407`); ramo
>    `genetic_perturbation` (gene prima di ChEBI, **niente MeSH**) con `try_gene` whole-string HGNC+**UniProt**
>    (`androgen receptor`→`HGNC:644`; canary 8/8 NULL); **cache lookup v4→v5** (obbligatorio). Si materializza
>    al prossimo re-cluster. Suite anchor+name-cleanup+name-recovery+stage3: **1405 PASS / 0 FAIL**.
> 6. **Full run re-eval finale**: override 83, **flag_review 14→10** (KRAS/SF3B1/TP53/APOE → noop: l'anchor era
>    giusto), noop 65→67, keep 31→33. `androgen receptor` MeSH:D011944→HGNC:644; GFP/HPV16-E7: override MeSH
>    spurio → keep. **Review dei 14**: 2 presunti *canary* erano gravemente mal-etichettati (JQ1 anchor
>    "D-cicloserina"; 4-OH-tamoxifene anchor "metil-idrossipalmitato") → il canary NON è un puro controllo di
>    non-regressione. 1 cluster è una **combo** (estradiolo+R5020) che nessuno dei due ID cattura.
> 7. **TODO** (non bloccanti): (a) `R/stage3-anchor-levels.R:154` fabbrica `HGNC:<target grezzo>` (es.
>    `HGNC:DTMYC`) per target mediated_effect ignoti a HGNC — stessa classe del fix I2, andrebbe `STR:` (5 sigle
>    in v7); (b) gap copertura resolver (glioblastoma/anticorpi/varianti/siRNA) = materia **LLM-fallback finale**
>    (DECISIONE C); (c) combo non modellate; (d) `kind` genetic_overexpression su cluster che sono *genotipi*
>    (APOE e4) = questione K2. Deliverable: `analysis/p4-output/name-cleanup-side-table-v1.rds` +
>    `-fragmentation-v1.csv`. Finding aggiornato con review dei 14 + misura frammentazione. Branch invariato,
>    master invariato, +5 commit (`36756ac`,`d6587c8`,`c66d844`,`bb802ae`,`8dcd91e`).
>    Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-06 (FULLRUN Stadio 4 v8 ESEGUITO + CLOSEOUT — ramo `rem_group` CHIUSO)**:
> 🟢 **Il re-pool Stadio 4 v8 col ramo `rem_group` è girato end-to-end e la verifica anti-stale è
> PASS. Le meta-analisi cross-studio NOMINATE sono finalmente poolate. ADR-0022 Accepted.**
>
> 1. **Run**: `setsid` detached (SID==PID, NON run_in_background), wall **1067 min (~17,8h)** laptop,
>    RSS picco ~14,6 GB, 0 crash. run_id `a500d032`, output
>    `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v8/20260706T112612Z-stage4-v8-a500d032/`. Dashboard
>    quarto fallita (non-fatale). Input v7 invariati (no re-cluster), cache counts riusata (no stale).
> 2. **ANTI-STALE PASS**: `Methods = mega,mega_aug,rem,rem_group`; **503 processati = 433 (v7, IDENTICO
>    su mega 72/mega_aug 353/rem 8) + 70 rem_group**. cluster_pooled 8.613.424 righe (rem_group 1.144.842),
>    per_study_de 34.026.609, sig FDR<0,05 1.121.633. Retrocompat rami esistenti byte-identica verificata.
> 3. **RE-GATE 70 rem_group** (tutti L4 group): n_sig 0–6347 (mediana ~1400), I² med 0–98%, k_eff 3–77
>    (studi distinti post-collapse). **BANDIERA 7/7 presenti**: SARS `NCBITaxon:2697049` (k12,n1813),
>    Prostatic `MeSH:D011471` (k4,n1485), enzalutamide `CHEBI:68534` (k12,n1337), fulvestrant
>    `CHEBI:31638` (k5,n518), tamoxifen `CHEBI:41774` (k5,n437), Breast `MeSH:D001943` (k6,n272),
>    vemurafenib `CHEBI:63637`. Top n_sig: tuberculosis|blood 6347.
> 4. **non_processable 382** = 279 `rem_group_insufficient_in_study_controls` (k_eff 131@0/93@1/55@2) +
>    103 `mega_rank_deficient`. I 279 = treated-only senza comparison stage2 (ibrido; augmentation = passo-3).
> 5. **Closeout**: finding `docs/findings/2026-07-06-stage4-rem-group-results.md`; **ADR-0022 Accepted**
>    `docs/decisions/0022-stage4-rem-group-named-metaanalyses.md`; ledger `.superpowers/sdd/progress.md`;
>    verifica `analysis/audit/2026-07-06-stage4-v8-antistale-regate.R` + `-remgroup-names.R` (+ CSV).
> 6. **PROSSIMO**: (a) **pulizia-nomi coda etichette** (LPS→"carnitine" ecc., handout
>    `docs/superpowers/specs/2026-07-06-name-cleanup-mistral-SESSION-AFTER-handout.md`); (b) augmentation
>    passo-3 (279 caduti); (c) Layer B re-curation con i 70 nuovi case-study. Branch invariato, master
>    invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-05 (ramo `rem_group` Stadio 4 — CODICE+VALIDAZIONE COMPLETI, FULLRUN v8 GATED)**:
> 🟢 **Fix del gate di selezione Stadio 4. Nuovo ramo di pooling `rem_group` che ammette le
> meta-analisi cross-studio NOMINATE (L2–L4, `safety_min` basso per design) che la selezione
> respingeva. Codice completo, final review Opus, validato sui dati veri. Fullrun v8 pronto (script +
> DRY_RUN PASS), GATED. Handout: `docs/superpowers/specs/2026-07-05-stage4-rem-group-fullrun-v8-NEXT-SESSION-handout.md`.**
>
> 1. **Causa** (finding `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`):
>    lo Stadio 4 v7 processava 433/317.304 cluster; la porta ammetteva group solo con `usable_mega_strict`
>    (`level∈{0,1}` + `safety_min≥0.7`) → 71/72 MEGA SENZA nome; SARS (k=25), enzalutamide (25), Breast
>    (88) esistevano ma `poolable=FALSE`. Logica MEGA applicata a target REM. Clustering v7 sano (95% omogeneo).
> 2. **Brainstorming→spec→plan** (5 decisioni utente): REM per-studio uniforme (both_roles+treated_only,
>    control in-study via `comparisons` stage2); porta strutturale senza `safety_min` + I²/τ² a valle;
>    ibrido documentato (no augmentation); soglie `k_eff≥3`/`n_min=2`, cap rimosso; dedup una meta-analisi
>    per entità al k massimo. `docs/superpowers/{specs,plans}/2026-07-05-stage4-rem-group-named-metaanalyses-*`.
> 3. **Impl subagent-driven (Task 1-7 TDD)**: config + porta `.identify_layer_a_clusters` + dedup +
>    dispatch-builder `.build_group_rem_dispatch_from_stage3` + `method_label` in `.pool_rem_cluster` +
>    orchestrator (filtro method + cutoff k_eff) + merge in build. Ogni task reviewato. `4f3a544`..`eb2a782`.
> 4. **Final review Opus**: **C1 CRITICAL** — il ramo era un **no-op silenzioso in produzione**
>    (`direction_check=NA` sui group → `if(NA)` → tryCatch skip ogni studio → pool vuoto; i test usavano
>    `"ok"`) → fix `isTRUE` coerce + difesa in profondità + test. **I1** (mismatch spec + pseudo-replicazione).
> 5. **Decisione utente I1**: gate `k_eff` su studi distinti + **collapse bracci intra-studio**
>    (`.collapse_arms_by_study`, inverse-variance FE, opzione C: sintesi per studio SENZA unire i campioni).
>    Limite noto: correlazione da control condiviso non modellata (raffinamento Franchini futuro).
> 6. **Validazione dati veri**: 70 rem_group AMMESSI (k_eff≥3) su 349; 6/7 bandiera (SARS k=12, enzalutamide
>    12, Breast 6, Prostatic 4, fulvestrant 5, tamoxifen 5, vemurafenib 4; Alzheimer cade); 279 cadono (no
>    comparison → ibrido, augmentation futura). Pool NON vuoto (enzalutamide 3747 sig, SARS 240; I² 58-92%).
>    Collapse validato (SARS 10→5 studi). Suite `stage4` 780 PASS, 2 FAIL PRE-ESISTENTI (dashboard quarto +
>    gene-axis E2, da `e8af92a`). Audit `analysis/audit/2026-07-05-stage4-rem-group-{smoke,collapse-validate}.*`.
> 7. **CACHE (lezione)**: v8 = re-pool (NON re-cluster) → il disastro v6→v7 (name-recovery Stadio 3) NON si
>    applica. Unica cache = **counts** (`stage4-counts/`, chiave `(v2_ensembl,biotype,gse,samples)`
>    method-independent): RIUSARLA (velocizza, no stale); nessuna cache del pooled → il ramo è sempre eseguito.
>    Verifica anti-stale: `Methods` include `rem_group`, ~70 pooled.
> 8. **Prossimo = FULLRUN v8 GATED** (~11-15h, `setsid`, `analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.R`
>    DRY_RUN PASS: Layer A 885 = rem 8/mega 175/mega_aug 353/rem_group 349, 69238 sample). Poi closeout +
>    ADR-0022 Accepted. Branch invariato, master invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-04 (biologici v6 END-TO-END + FIX PATHOGEN v7 — CHIUSO)**:
> 🟢 **Pipeline end-to-end su v7. Fix estrazione pathogen materializzato.** Finding
> `docs/findings/2026-07-03-stage3-v7-pathogen-extraction.md`. Commit `1fb1520` (fix) + `409aa0a` (cache bump).
>
> 1. **v6 run gated (2026-07-01/02, setsid+loop)**: re-cluster Stadio 3 v6
>    (`…20260702T024122Z-stage3-v6-364547a7`, wall 8h06) → re-pool Stadio 4 v6
>    (`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v6/…-stage4-v6-4f7ea215`, 11h, 7,41M righe, 998k sig, 0 crash).
>    Re-gate v6: **cytokine 61→36% (VINTO, driver ImmPort), MA pathogen REGREDITO 33→44%** (unico kind peggiorato).
> 2. **Root cause pathogen (data-driven)**: NON vocabolario ma **ESTRAZIONE**. `.normalize_pathogen_to_taxid`
>    faceva solo match esatto del termine collassato mentre `.normalize_cytokine_to_hgnc` usava già
>    `.extract_compound_candidates` → asimmetria (cytokine 53% vs pathogen 8%). Stringhe rumorose
>    `STR:lps_exposed_for_24_hours`/`sars_cov_2_infected`/`poly_i_c_10_g_ml` non risolvevano.
> 3. **Fix `1fb1520` (TDD, precision-gated)**: `.normalize_pathogen_to_taxid` itera i candidati da
>    `.extract_compound_candidates` (LPS→CHEBI:16412; SARS-CoV-2→NCBITaxon:2697049; poly(I:C)→CHEBI:84491) +
>    vernacolo `mtuberculosis`. Guardie host-species per-candidato + taxdump solo su frasi. Smoke: K3 0/200,
>    generici 0/12. Misura pre-materializzazione (re-gate su v6 col fix): **pathogen 43,9→16,8%**.
> 4. **⚠️ CACHE-MISS (lezione)**: 1° re-cluster v7 (~8h) = output byte-identico a v6 → lookup disk-cached
>    riusato perché non bumpato `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`. Beccato dalla sanity. Fix v3→v4
>    (`409aa0a`) → re-run. Vedi memoria `feedback_bump_lookup_cache_version`.
> 5. **Ciclo v7 (2026-07-03/04)**: re-cluster v7 (`…20260703T113045Z-stage3-v7-364547a7`, 475min; NCBITaxon:
>    1149→2245, PATHOGEN_VERNACULAR cluster 521→1561, PAMP 371→872, 0 host-species) → re-pool Stadio 4 v7
>    (`/mnt/wwn-…/simulomicsr-stage4-v7/…-stage4-v7-4f7ea215`, 668min, **7.468.582 righe, 998.695 sig, 433 proc,
>    0 crash df-residui**). **RE-GATE v7: pathogen 43,9→11,2%** (meglio del previsto — v7 ha ri-poolato
>    coerentemente; ora ≈ disease 7,7%, batte v5 33%). cytokine/small_molecule 35,9% invariati, TOTALE 22,0→20,1%.
> 6. **TODO**: cytokine/small_molecule ~36% = copertura ChEBI/HGNC + granularità per-membro (NON estrazione);
>    **LLM-fallback finale** (DECISIONE C, precision-gated) sui residui STR/UNK = passo generale finale.
>    Branch invariato, master invariato, no push.
>
> **Stato 2026-07-01 (biologici v6 — codice+dizionari+fix VALIDATI (GO), rebuild PRONTO NON lanciato)**:
> 🟢 **Recupero-nome BIOLOGICI (citochine+patogeni) implementato + validato. 3 run pesanti gated da
> lanciare in sessione FRESH. Handout:
> `docs/superpowers/specs/2026-07-01-stage3-biologics-v6-rebuild-NEXT-SESSION-handout.md`.**
>
> 1. **Codice+dizionari+fix (subagent-driven TDD, tutti review/validati)**: dizionari reali in
>    `~/.cache/R/simulomicsr/` = taxonomy(3.35M nomi)/ImmPort(5046 syn, 927 whitelist, has_go)/
>    UniProt(68805)/GO(213). `.normalize_cytokine_to_hgnc`(→`HGNC:`) + `.normalize_pathogen_to_taxid`
>    (→`NCBITaxon:`/PAMP `CHEBI:`) + **K3 compound-first** + anchor `NCBITaxon:` + cache **v3**. Sanity ha
>    corretto **9 ID PAMP errati**. Design finale = **spec §13**
>    (`docs/superpowers/specs/2026-06-29-stage3-biologics-name-recovery-design.md`).
> 2. **Gate smoke (validate-before-fullrun) — HA FUNZIONATO**: smoke#1 NO-GO (K3 **8% falsi**, pathogen
>    3%) → Fix-A(K3 compound-first, elimina flip su farmaci veri; PAMP preservati via CHEBI∈whitelist) +
>    Fix-B(estrazione `.AGENT_KEYS`+vernacolo) + Fix-I1(anchor adotta ID forte su STR) → ri-smoke GO →
>    **final review Opus** trovò I-1 (`organism: human` → Homo-sapiens-as-pathogen su **747 sample**) →
>    Fix-D(trim `organism` + `.HOST_SPECIES_STOPLIST` + `.AGENT_CONTROL` infection-neg) → spot-check GO.
>    **Esiti reali**: cytokine **53%**, pathogen 3→**8%**, K3 **0 falsi genuini**, host-species **0/747
>    flip**, canary generici puliti. Report `docs/findings/2026-07-01-stage3-biologics-smoke.md`.
> 3. **Script re-cluster v6 PRONTO** (`analysis/p4-fase-f6-stage3-reclustering.R`, commit `0e9bb96`:
>    assert `has_taxonomy/immport/uniprot/chembl` fail-fast + token v6; SMOKE=1 PASS: HGNC:=1155,
>    NCBITaxon:, K3_MISTYPE attivi). **NON lanciato** (decisione utente: full in sessione fresh).
>    **Prossimo = 3 RUN GATED**: (a) re-cluster Stadio 3 v6 (~6-7h, `SMOKE=0 Rscript
>    analysis/p4-fase-f6-stage3-reclustering.R`, detached) → (b) re-pool Stadio 4 v6 (~10h su `/sda`,
>    preparare `-rebuild-v6.R` copia -v5) → (c) re-gate omogeneità v6 (attesi: cytokine 61%→giù, pathogen
>    33%→giù; disease/small_molecule invariati). Branch invariato, master invariato, **pushato**.
>    Ledger `.superpowers/sdd/progress.md`. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-06-29 fine sessione 21 (Plan B FASE 2 — run gated Task 8-10 COMPLETI)**:
> 🟢 **Pipeline end-to-end ri-girata su v5. Plan B (farmaci ChEMBL) CHIUSO.**
>
> 1. **Pre-flight**: `has_chembl=TRUE` (49099 molecole), fix df-residui `0c41848` nel
>    codice, input v4 presenti. **Task 8** (re-cluster Stadio 3 v5): 2 micro-edit allo
>    script `analysis/p4-fase-f6-stage3-reclustering.R` (assert `has_chembl` fail-loud +
>    token `v5`). Smoke PASS → full detached **400 min (~6h40)**, **317.434 cluster**,
>    `analysis/p4-output/20260629T041343Z-stage3-v5-364547a7/`. run_metadata: chembl reale
>    (`fixture_subset=false`), cache lookup `v2`. Recovery ChEMBL: 4407 cluster.
> 2. **Task 9** (re-pool Stadio 4 v5): script `analysis/p4-fase-f5-stage4-layer-a-rebuild-v5.R`
>    (copia -v4, 4 cambi: stage3_dir→v5, out_dir→`/sda`+token v5, 2 log). Smoke DRY_RUN PASS
>    (Layer A 533 cluster). Full detached **619 min (~10h19)**, **7.362.958 righe pooled**,
>    987.589 sig (FDR<0,05), 428 processed + 105 non-processable. **Zero crash df-residui**
>    sui 348 mega_aug (fix `0c41848` validato sul full). Output
>    `/sda/simulomicsr-stage4-v5/20260629T164735Z-stage4-v5-4f7ea215/`. Dashboard quarto
>    fallita (non-fatale, manca binario). Stima DRY_RUN 24h pessimistica (reale ~11h).
> 3. **Task 10** (re-gate omogeneità v5 + INDAGINE): `small_molecule` minestrone **49,0% →
>    36,5%** globale (criterio soddisfatto; altri kind non peggiorano). **Indagine del
>    residuo (gate utente)**: i 409 minestroni residui sono 97,5% anchor `CHEBI:` (NON
>    UNK/STR) → NON name-recovery insufficiente. Per livello (v4→v5): **L0 12,1→8,3%, L1
>    12,4→7,9%** (granulare = composto specifico, ora ≈ disease 7,7%), L2 23→17, L3 33→25,
>    L4 41→32 (pooling per classe ChEBI = minestrone in parte BY-DESIGN). Finding
>    `docs/findings/2026-06-29-stage3-v5-chembl-homogeneity.md`; audit
>    `analysis/audit/stage3-homogeneity-check-v5-full-out.{txt,csv}`.
> 4. **TODO (NON Plan B, sessioni future)**: biologici cytokine/pathogen (~61% residuo,
>    vocabolario dedicato + fix-tipo K3); **LLM-fallback finale** (DECISIONE C generale,
>    precision-gated) sui residui STR:/UNK; micro-fix casing `ChEMBL:`/`CHEMBL:` (20
>    cluster) al prossimo rebuild; caratterizzare 105 non-processable Stadio 4.
>    Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-06-28 fine sessione 20 (Opzione B — farmaci ChEMBL)**: 🟢 **FASE 1
> CODICE COMPLETA + final review clean + Task 6/7 gated (dict ChEMBL reale + smoke
> copertura) + stoplist precisione. Prossimo = RUN GATED re-cluster Stadio 3 v5.**
>
> 1. **Brainstorming→spec→plan** (gate utente): scope = SOLO farmaci/small-molecule
>    (biologici citochina/patogeno + fix-tipo K3 → TODO sessione futura, brainstorming
>    dedicato); DB = ChEMBL (CC BY-SA, copertura composti da ricerca); canonicalizzazione
>    ChEBI-preferred via pref_name ChEMBL (de-frammentazione); estrazione tollerante a
>    dose/tempo/combo; combo → ID-combo deterministico `+`. Spec/plan/HUMANE
>    `docs/superpowers/{specs,plans}/2026-06-28-stage3-perturbative-name-recovery-B-*`.
> 2. **FASE 1 codice (subagent-driven, Task 1-5, suite 1015 PASS/0 FAIL/0 ERROR)**:
>    dizionario ChEMBL (`R/ontology-lookup.R`: `.build_chembl_index`+accessor+loader
>    GRACEFUL con `has_chembl`); estrazione `.extract_compound_candidates` +
>    risoluzione `.resolve_one_compound`/`.normalize_compound_to_chebi` (catena
>    ChEBI→ChEMBL→de-frammentazione→combo→STR, gate precisione esatto C1); bump cache
>    lookup v1→v2 + asse `has_chembl` nella chiave; script build reale
>    `analysis/p5-audit-chembl-build-dict.R`. Commit `cd9b213`..`d4419a8`.
>    - **REGRESSIONE cross-task chiusa**: lo `stop()` su ChEMBL mancante nel loader (Task 1)
>      rompeva `test-anchor-parse.R` + ogni build di anchor → DECISIONE UTENTE: loader
>      GRACEFUL (chembl=NULL+has_chembl=FALSE) + assert-at-run negli script v5 (`83e1238`).
>    - **FINAL review (opus) Ready-to-merge + 1 Important**: chiave cache lookup non
>      distingueva has_chembl TRUE/FALSE → rischio servire lookup degradato v4 → fixato
>      (`aebfc68`, chiave include `has_chembl`+release).
> 3. **Task 6 (gated, DONE)**: download ChEMBL 37 SQLite (5.4G, SHA256 in
>    `analysis/p4-output/chembl-source-provenance.json`) → dict reale
>    `cache/chembl/chembl-lookup.rds` (49099 molecole, 128937 alias). Schema SQL VERIFICATO.
>    .db estratto (30G) scartato, tarball tenuto su `/sda`.
> 4. **Task 7 (gated, DONE — smoke copertura PRE-fullrun)**: **63,4% recupero** sui 484
>    drug-name candidates (driver dominante = ESTRAZIONE che sblocca farmaci già in ChEBI;
>    ChEMBL complementa i composti da ricerca; 46 combo). Canary precisione OK. **Finding:
>    7/362 match generici spuri** (drug/acid/inhibitor/agonist/ligand/peptide come token
>    isolati → merge spuri) → **stoplist** `.GENERIC_COMPOUND_STOPLIST` (commit `3bd8728`):
>    match generici **7→0**, recupero 63,4%, farmaci reali invariati.
> 5. **Prossimo (sessione 21, GATE UTENTE)**: Task 8 re-cluster Stadio 3 v5 (~6h, assert
>    `has_chembl` + SMOKE=1 sanity + SMOKE=0 detached) → Task 9 re-pool Stadio 4 v5 (~11h,
>    `/sda`, fix df-residui già committato) → Task 10 re-gate omogeneità v5 (small_molecule
>    atteso giù dal 49%) + closeout. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-06-26 fine sessione 18**: 🟢 **REWORK Stadio 3 — FASE CODICE COMPLETA
> (Task 1-12 + final whole-branch review fix) + smoke gate validato (Task 13). Restano
> i 3 run gated Task 14-16.**
>
> 1. **Task 8-12 (subagent-driven-development)** sul plan
>    `2026-06-25-stage3-name-recovery-reclustering-plan.md`, tutti review-Approved:
>    - T8 `build_name_recovery_lookup` (`R/stage3-name-recovery-lookup.R`): env GSM→identità
>      dall'H5, lettura iniettabile, cache version-aware (commit `831afd8`).
>    - T9 `.extract_anchor_segments(recovery=NULL)` (`R/stage3-anchor-levels.R`): UNK→agente
>      recuperato, K2 genetic→kind, 3 trace-field nel tracking_meta solo con recovery non-NULL;
>      retrocompat anchor 89 test. Fix Important: NA-guard su `recovery$kind` (crash `if(NA)`).
>      Commit `d3e9404`,`3dd52d1`.
>    - T10 thread del lookup nel build (`R/stage3-build.R`): `.precompute_anchor_cache(recovery_lookup=NULL)`
>      + `build_stage3_clusters(name_recovery_lookup=NULL)`; retrocompat byte-identica, suite stage3 490.
>      Commit `8075fae`. (NB: nel loop `parts[1L]`="sid" è il GSM RAPPRESENTANTE, non series.)
>    - T11 gate omogeneità (`analysis/audit/stage3-homogeneity-check.R`): Important di VALIDITÀ fixato
>      con scelta utente A — conta le identità solo sui GSM MEMBRI (treated/case) via
>      `record_id→stage2 master`, H5 per geo_accession diretto. Minestroni 84,8%→66,8% su v3
>      pre-rework. Commit `129052e`,`0ae2823`.
>    - T12 benchmark LLM (`analysis/audit/name-recovery-llm-benchmark.R`, eval fuori produzione):
>      det 63,4% recupero, template gold 52 righe; LLM+gold+decisione C GATED. Helper condiviso
>      `analysis/audit/_gsm-lookup-helper.R` (`build_record_gsm_lookup`). Commit `046301d`,`4cffb8e`.
> 2. **FINAL whole-branch review (opus)**: integrazione SOLIDA (retrocompat byte-identica,
>    tracking_meta 12→15 consumato safe da `.summarize_clusters`, data-flow coerente). Ma 1
>    CRITICAL + 3 Important cross-task che i per-task non vedevano → fix completo (scelta utente A,
>    4 commit atomici `368e8b3`,`f957cfd`,`1087d41`,`602c2fb`, suite 283/0):
>    - **C1**: regex K2 girava con `ignore.case=TRUE` → annullava il vincolo case-sensitive di
>      `sh[A-Z]`/`si[A-Z]` → flippava a genetic_* composti/agonisti REALI (Resiquimod case study
>      noto-buono, simvastatin, sirolimus, "single cell", "serum depletion"). Fix: pattern di forma
>      case-SENSITIVE (`_CS`) vs robusti case-insensitive (`_CI`); `depletion` ristretto; `auxin`/`iaa`
>      standalone rimossi; +`\boe\b`/`\bKO\b`/`\bAID\b` case-sensitive. 6 canary.
>    - **I1**: `match(gsm, geo_accession~888k)` vettorizzato fuori dal loop (era O(n²)).
>    - **I2**: target K2 validato vs `.hgnc_lookup_symbol` (gene reale→HGNC, token non-gene→STR/NA).
>    - **I3**: 3 colonne trace (`recovery_source`/`agent_id_recovered`/`kind_recovered`) additive a `clusters.rds`.
> 3. **Task 13 smoke gate (RUN GATED leggero) — ESITO ECCELLENTE su dati reali**:
>    breast `group_L4_f12efec4` CONCORDANTE (MeSH:D001943); blood `group_L4_cc07ca23` MINESTRONE
>    SCOMPOSTO in **19 malattie distinte** MeSH-resolved; HCT116 `group_L0_686d6360` K2 (67% flippati
>    a genetic_*, geni HGNC reali INTS11/PNUTS/WDR82/XRN2, titoli "POINT-Seq XRN2-dTAG"). Canary C1
>    REGGE sui dati reali. Regime U1 atteso (NO_RECOVERY ~53% blood, non persi).
> 4. **MINOR defer residui** (non-bloccanti per i run gated): `kind_by_gsm` come env vs list a scala
>    (O(n²) → environment al full run); `.parse_characteristics_kv` splitta su "," → slug numerici
>    degeneri (STR:1/STR:464); + ledger T5/T7/T8(M1-4)/T10(M1-2)/T11(R1-R2).
>
> **Resume sessione 19**: leggi `.superpowers/sdd/progress.md` (ledger, Task 1-13 complete) + il plan
> §Phase 6. Prossimo = **Task 14 re-cluster Stadio 3 v4** (run pesante ~ore, GATE UTENTE): script
> `analysis/p4-fase-f6-stage3-reclustering.R` (preparato + smoke-validato in sessione 18 — vedi
> `.superpowers/sdd/task-14-prep-report.md`). Costruire `kind_by_gsm` come **environment**. Poi Task 15
> (ri-pooling Stadio 4, DGX) + Task 16 (gate omogeneità v4, criterio ~0 minestroni provati). Branch
> invariato, master invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-06-25 fine sessione 17**: 🔴 **F6 Fase A run pieno FATTO + bug I² rem
> fixato; in Fase B scoperto difetto MINESTRONE a monte → REWORK Stadio 3 deciso e
> in esecuzione (Fase 1 modulo completa).**
>
> 1. **F6 Fase A run pieno** (`SMOKE=0 VPC_WORKERS=24`, ~3h): `cluster_reproducibility_v2.rds`
>    (776 cluster) + `cluster_vpc_per_gene.parquet` + `cluster_pi_per_gene.parquet` in
>    `…stage4-4f7ea215/`. **Bug paper-grade trovato+fixato**: l'I² in `cluster_pooled` è
>    PERCENTUALE 0-100, ma `.consistency_score` voleva una frazione 0-1 → `1−I²` con I²=40
>    dava −39→clamp 0 (16/28 rem falsamente azzerati). Lo smoke non l'aveva visto (pescava
>    i 2 rem con I²≈0). Fix: helper `.rem_consistency_from_i2` (TDD) + env `METHODS` per
>    ri-girare solo rem+mega_aug riusando i mega. Commit `8fc9d7d`,`828e4ca`. Distribuzione
>    corretta: mega cons_med 0,525 · rem 0,715 · mega_aug 0,818.
> 2. **Finding MINESTRONE (paper-grade, blocca F6)**: i cluster `disease_vs_normal`
>    raggruppano malattie DIVERSE (es. "sangue" = HIV+Alzheimer+leucemia+dermatomiosite)
>    perché l'anchor non porta il nome (`agent=UNK`, `R/stage3-anchor-levels.R:52` legge solo
>    il campo LLM `disease_state$mesh_id_candidate`, spesso "unknown" → collassa sul tessuto).
>    Misure: **37%** dei 177 disease cluster mescolano ≥2 malattie; **70%** dei 37
>    robusti-candidati. **La consistenza NON protegge** (minestroni a cons 0,91-1,00:
>    segnale generico aspecifico). `small_molecule` simile: degron mal-etichettati + theme-pooling.
> 3. **Decisione utente: REWORK Stadio 3**. Recupero deterministico nome malattia/composto
>    dai metadati GEO grezzi + ontologia (A) + benchmark LLM→eventuale ibrido (C); scope tutti
>    gli `UNK` (S3); granularità livello-malattia (G2); ignoti non-poolati (U1); correzione tipi
>    palesemente sbagliati (K2). Spec `docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md`
>    + plan + HUMANE committati (`37beb97`,`c6a4208`).
> 4. **Esecuzione plan (subagent-driven) — Fase 1 COMPLETA**: modulo puro
>    `R/stage3-name-recovery.R` (Task 1-7: parse characteristics, estrai malattia/composto, K2
>    genetico, normalizza MeSH/ChEBI, orchestratore **`recover_identity`** esportato), **62 test
>    PASS**. La review ha pescato 1 bug vero (tolower fallback) + 3 Minor (nel ledger).
>    Commit `f88695f`..`96c8750`. **Prossimo = Task 8** (lookup `GSM→identità` dall'H5, Fase 2),
>    poi Task 9-10 (innesto in `.extract_anchor_segments`/`.precompute_anchor_cache`), 11-12 (gate
>    omogeneità + benchmark LLM), 13-16 (run gated: re-cluster Stadio 3 v4 → ri-pooling Stadio 4 →
>    collaudo omogeneità). **F6 Fase B/C/D SOSPESE** finché il rework non rende i cluster coerenti
>    (la consistenza da sola non è il gate; serve il gate di omogeneità).
>
> **Resume sessione 18**: leggi `.superpowers/sdd/progress.md` (ledger) + il plan, riparti dal
> Task 8 con la skill `superpowers:subagent-driven-development`. Branch
> `review-scientific-consistency-2026-06-10`, master invariato, no push. Memorie:
> [[project_stage3_minestrone_rework]]. Vedi `docs/RED_ALERT.md` §F6 + §Handoff sessione 18.
>
> **Stato 2026-06-16 fine sessione 16**: 🟡 **F6 Fase A — metrica di consistenza
> cross-studio implementata + verificata (run pieno da lanciare).** Deep research
> metodologica (2026-06-15) ha ribaltato la %DE/Spearman (non difendibili: winner's
> curse) → asse di consistenza [0,1] per-metodo (mega = 1−VPC(study) via
> variancePartition; rem = 1−I² + prediction interval REML+HKSJ; mega_aug k=2 =
> sign-concordance), sempre sui geni FDR-sig. **ADR-0021** + spec + piano. 4 helper
> **TDD** (`R/stage4-consistency.R`, 24 expect_*) + script
> `analysis/p4-fase-f6-consistency.R`. **Smoke SMOKE=2 PASS** (3 fix: formula VPC
> categoriche-random, `<<-`→`<-`, parallelizzazione VPC_WORKERS) + **verifica round 2
> PASS**: componenti VPC sommano a 1, allineamento geni 100%, **vpc_study
> cross-validata vs lme4 indipendente entro 0,05**, scelta geni-sig validata (separa
> segnale da rumore dei nulli: rem I² 84% su tutti i geni → ~1% sui sig). Commit
> `57c9f19`..`f342a5f`. **Prossimo (gate dato): run pieno** `SMOKE=0 VPC_WORKERS=24
> Rscript analysis/p4-fase-f6-consistency.R` (~3h sui 173 mega) →
> `cluster_reproducibility_v2.rds` (776 cluster) + parquet per-gene; poi Fase B
> shortlist (soglie con l'utente, `pi_frac_excl0` primario per i rem che saturano a
> cons≈1), Fase C validazione esterna (LINCS+pathway+LOO sui candidati), Fase D
> selezione ~15. **Finding**: covariate batch + SAMN-dedupe inerti nel fullrun F5
> (h5_metadata senza quelle colonne). Master git invariato, no push. Vedi
> `docs/RED_ALERT.md` §F6 + §Handoff sessione 17.
>
> **Stato 2026-06-14 fine sessione 15**: 🟢 **F4 (Stadio 3) + F5 (Stadio 4 Layer A)
> ricostruiti + metrica di riproducibilità per F6**. **F4 Stadio 3** (run
> `364547a7`, wall 221 min) sul master v3 + anchor v3.1.1 + completeness guard (ora
> legge `member_sample_ids`, commit `c6b9d51` TDD): **292.518 cluster, 546.905
> assignment**, guard 18.004 sample → `unclear` (≈3,5% REGOLA 4). Sanity PASS —
> regressione chunk-collision **chiusa** (0 suffissi chunk; `n_control=NA` sui group
> è per-design mega_aug). **F5 Stadio 4 Layer A** (run `4f7ea215`, wall 24h, 32
> dream worker, RSS picco 20,6 GB, FASE E default = ensembl+biotype+covariate):
> **776 cluster** (173 mega + 575 mega_aug + 28 rem) + 118 mega_rank_deficient,
> **13,28M righe pooled, 1.677.343 geni significativi (FDR<0,05)**; vs 96c43acb
> 776 vs 487 pooled (mega_aug ~raddoppiato, rem 0→28). Smoke gate pre-fullrun PASS
> (gene axis 100% Ensembl); dashboard quarto fallito (non-fatale, ri-renderizzabile).
> **Metrica riproducibilità per F6**: validazione ha mostrato che la **%DE NON è
> diagnostica** (cluster ad alta %DE sono per lo più CONCORDI = biologia reale;
> l'"artefatto" 80,7% DE aveva concordanza 1,00). Scelta utente: **concordanza
> cross-studio (B)** come gate POSITIVO di riproducibilità + **I² (A)** come asse
> complementare ortogonale (cor 0,03). Copertura B: rem k=3-8 (trusted), mega_aug
> k=2 (fragile ma dove stanno 71/75 artefatti), mega k=0 (non calcolabile,
> accettato). Script `analysis/p4-fase-f6-concordance.R` → `cluster_reproducibility.rds`;
> doc `analysis/audit/F5-concordance-metric.md`. Commit `c6b9d51`..`0defe37`.
> **Prossimo = F6 (Layer B re-selection)**: ri-girare lo shortlist sul nuovo
> `cluster_pooled.parquet` con la concordanza al posto della %DE, **soglie da
> fissare con l'utente**, ri-curare la selection, ri-girare il batch. Poi FASE G
> (doc + tag). Branch `p5-llm-anchor-classification-audit`, master git invariato,
> no push. Vedi `docs/RED_ALERT.md` §F5/§F6 + §Handoff sessione 16.
>
> **Stato 2026-06-11 fine sessione 14**: 🟢 **Stadio 2 v3 COMPLETO (opzione C) —
> fullrun + rescue + master**. Fullrun Stadio 2 v3 (slurm 24022, wall 15h20m):
> **24.953/24.972 valide (99,924%)**, 19 fail-schema su 10 studi. Audit dei fail
> (before-patch): **tre meccanismi distinti** di troncamento output — esplosione
> confronti (multi-fattoriale ~4-6 cmp/condizione), esplosione rep_groups (centinaia
> di condizioni/chunk), degenerazione/flood — + caso multi_arm a tier S. Rescue con
> config unica: nuovo parametro **`max_treated_per_chunk=12`** di `.chunk_conditions`
> (TDD, retrocompatibile, commit `e1dec27`) + **`max_tokens` 32768 piatto** +
> **`rep_pen` 1.2** (deviazione di config, NON di prompt, tracciata come β). Slurm
> 24222: **506/506 valide, 0 residui** (wall 26 min). **Master Stadio 2 v3: 24.394
> studi, 1 record/studio** (guard `.assert_stage2_one_record_per_series` PASS), studi
> re-chunkati ricomposti per series (GSE249377: 268 chunk → 1 record, 3146
> replicate_groups, 123 cmp), 490.051 campioni coperti (resto = coverage gap REGOLA 4,
> lo chiude il completeness guard a F4). Deliverable
> `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl` (gitignored, schema stage2.v2).
> Script `analysis/p4-fase-f4-stage2-rescue-build-v3.R` + `-rescue-submit-v3.R` +
> `-collect-v3.R`. Finding paper
> `docs/findings/2026-06-11-f4-stage2-v3-rescue-and-generalization.md` (il rescue è
> una **procedura data-adaptive**: stessa cassetta a tre leve su β/F3/F4, valori da
> ri-derivare per corpus). Commit `e1dec27`..`b84231b`. **Prossimo = F4 (Stadio 3
> rebuild) sul master v3 + anchor v3.1.1** (sessione 15). PRIMA: adattare il
> completeness guard a `member_sample_ids` (oggi legge geo_accession = rappresentante).
> Poi F5 (Stadio 4) → F6 (Layer B). TODO tracciati: completeness guard
> `member_sample_ids`; indagine single-cell Stadio 0 (~313 studi degeneri). Branch
> `p5-llm-anchor-classification-audit`, master git invariato, no push. Vedi
> `docs/RED_ALERT.md` §F4 + §Handoff sessione 15.
>
> **Stato 2026-06-10 fine sessione 13**: 🟢 **F4 opzione C implementata fino allo
> smoke gate PASS**. Ridisegno input Stadio 2 a condizioni di disegno deduplicate
> per firma (niente chunking per-campione). TDD (179 expect_*): `design_signature`
> (campi = sola condizione sperimentale, raffinati data-driven con tissue_segment +
> agent_raw) + `.build_study_conditions` + `.chunk_conditions`/`.is_control_condition`
> (coda D2: chunk per-condizione + broadcast controlli, cap 0.3) + espansione/fusione/
> assembly (`.expand_study_design`/`.merge_chunked_designs`/`.assemble_stage2_study`).
> Build input v3 (`analysis/input/archs4-human-stage2-input-v3.jsonl`, gitignored):
> **24.972 record** (24.149 a 1 record + 245 studi-coda chunkati, budget 80k char),
> **0 campioni persi**, ricostruzione esatta. Due fix trovati dai dati
> (audit-before-patch): encoding firma (µM/uM, NA-string) + esplosione chunk da
> broadcast. Cambio prompt Stadio 2 **gated** (A: sezione "Input format" nel system
> prompt R; B: strip `member_sample_ids` in `prompts.py`). `.reassemble_stage2_chunks`
> **sostituita** dal guard fail-loud `.assert_stage2_one_record_per_series` (stage3+4
> build). **Smoke gate 72 studi gold: schema 100%, accuracy 94,04% (= baseline F3),
> coverage 21→5 → PASS** (`analysis/audit/F4-stage2-smoke-v3-eval.md`). Decisioni a
> libro in ADR-0020. **Prossimo = fullrun Stadio 2 v3 sul DGX** (sessione 14, gate
> separato) → master v3 → F4 (Stadio 3) → F5. TODO tracciati: completeness guard su
> `member_sample_ids`; indagine single-cell Stadio 0 (~313 studi degeneri). Branch
> `p5-llm-anchor-classification-audit`, master git invariato, no push. Vedi
> `docs/RED_ALERT.md` §F4 + §Handoff sessione 14.
>
> **Stato 2026-06-04 fine sessione 12**: 🔴 **F4 bloccato da finding paper-grade
> chunk-collision → pivot a opzione C (ridisegno input Stadio 2)**. Agganciando
> il completeness guard è emerso (via code review) un difetto **pre-esistente**:
> gli studi grandi sono spezzati in chunk cs50, lo Stadio 2 classifica ogni fetta
> in modo incoerente, e a valle `record_id = series__suffix` collide +
> `.index_stage2_master` (per series, last-wins) tiene solo l'ultimo chunk →
> **35% dei campioni F3 (55% nel run β già prodotto `96c43acb`) misrisolti** nel
> pooling DE + ~435 confronti REM cross-chunk persi. Finding
> `docs/findings/2026-06-01-stage3-stage4-chunked-study-sample-resolution-bug.md`,
> repro `analysis/audit/F4-chunk-collision-repro.R`. Tentato fix a valle
> (riassemblaggio namespacing) → scartato (perde i confronti cross-chunk).
> **Decisione utente: opzione C (root cause)** — dare allo Stadio 2 le condizioni
> di design distinte (mediana 13/studio) deduplicate per firma, niente chunking,
> poi espandere. **ADR-0020 Proposed** + spec/HUMANE
> `docs/superpowers/specs/2026-06-02-stage2-design-signature-dedup-*`. **D1 decisa**
> (firma = sola condizione sperimentale, esclusa identità individuale donor/age/
> sex/ancestry). D2/D3/D4 residue (gate prossima sessione). C re-runa Stadio 2
> (rifà F3 → master v3, 1 record/studio), poi F4, F5. Stadio 1 (F2 508k) invariato.
> Codice namespacing uncommitted (superato da C, da gestire). I risultati
> `96c43acb` + Layer B `56b911e6` **non affidabili** come baseline. Master git
> invariato, no push. **Prossimo = implementare C** (vedi `docs/RED_ALERT.md`
> §Handoff sessione 13).
>
> **Stato 2026-05-31 fine sessione 11**: ✅ **F3 — Stadio 2 fullrun v2 (28.544)
> + rescue cascade → 100%**. Build input dal master Stadio 1 v2 congelato:
> **28.544 record / 24.394 studi**, guard `is_zero_timepoint` 12.967 flag corretti,
> 0 drop. Smoke Stadio 2 sui 72 studi gold (756 campioni) solo su Stadio 2 sul
> materiale congelato: schema **100%**, accuracy **94,04%** (= baseline sessione 9),
> gate PASS. Fullrun job 22948 (job unico 4-worker, config invariata, tier XL
> 25,6%): wall **~29h**, validità **99,874%** (36 fail su 28.544, sparsi, ~ β).
> Throughput oscillante (~6-19/min), dip notturno al pareggio ~6/min poi rientrato,
> monitoraggio orario, nessun intervento reattivo. Rescue: cs25 resplit 32/36 +
> cascade rep_pen=1,2 sui 4 residui (studi piccoli, JSON malformato) → 4/4. **Master
> finale 28.567 record, 100,0000% validi, 24.394 studi**
> (`analysis/p4-output/p4-fase-f3-stage2-master-rescued.jsonl`, gitignored,
> `rescue_source` ×59). Doc NEWS 9029 + RED_ALERT §F3 ✅. Commit
> `P5 audit RED_ALERT F3: *`. Branch invariato, master git invariato, no push.
> **Prossimo = F4 (Stadio 3 rebuild)**: prompt in
> `analysis/p4-fase-f3-NEXT-SESSION-PROMPT.md`. Vedi `docs/RED_ALERT.md` §F3 +
> §Handoff sessione 12.
>
> **Stato 2026-05-29 fine sessione 10**: ✅ **F2-fullrun Stadio 1 v2
> (508.037) + rescue cascade → 100%**. Fullrun sul bacino di produzione,
> config invariata, prompt v2 + guard `is_zero_timepoint` a valle: 51 chunk
> da 10k + 25 outlier, wall ~11h40m, ~13.8 min/chunk, 0 HALT. Validità
> LLM-only 99.712% (1.464 fail). Diagnosi paper-grade (audit before patch):
> fail rate 3x vs β = **fragilità prompt v2** (81.6% fail nuovi via overlap
> GSM; 22/23 residui = GSE157354 chimera human-mouse), NON infra/dati;
> accuratezza già validata 94-96%. Rescue cascade β (H1 rep_pen=1.2→1.317 /
> H1.2 rep_pen=1.3→124 / H1.3 rep_pen=1.4→21 / H1.4 manual 2) → master
> rescued **508.037/508.037 = 100%**, tag `rescue_source`. Deliverable
> `analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl`
> (gitignored). Commit `bda18f8`..`6ecd7b1` + closeout doc (RED_ALERT F2 ✅,
> NEWS 9028, finding §5). Branch ahead master 102 commit, master invariato,
> no push. **F2 chiuso; prossimo = F3 Stadio 2 fullrun** (build input v2 +
> smoke gate + fullrun). Vedi `docs/RED_ALERT.md` §Handoff sessione 11.
>
> **Stato 2026-05-28/29 fine sessione 9 (+ lavoro autonomo)**: ✅
> **F2-smoke + root-cause + fix `is_zero_timepoint` + benchmark scalato**.
> Gate F2-smoke (100 sample) → accuracy mini-gold 92.93% < 93% → STOP.
> Indagine systematic-debugging (3 run DGX): causa = **fragilità prompt
> Stadio 1** (D1b `molecule_hint` + D4 `organism_hint` destabilizzano
> `duration.is_zero_timepoint` → REGOLA 2 stage2 time-zero=control). NON il
> prompt Stadio 2 (controprova IT identica), NON drift infra (β-prompt
> recupera 98%). Fix: **guard deterministico** `R/stage1-normalize.R` (TDD 38
> expect_*) agganciato nel build input Stadio 2; mini-gold 92.93% → **97.00%**
> senza toccare il prompt. Commit `301bdc8`/`bc40793`/`03abb8b`.
> **Benchmark design-aware scalato**: gold LLM-assisted 756 sample / 72 studi
> reali bacino v2 (calibrato 88.2% vs gold umano), binary accuracy **94.14%**
> (full) / **96.02%** (raffinato). 5/717 plausibili errori pipeline; resto =
> multi-asse + coverage gap 3.5%. Finding
> `docs/findings/2026-05-28-f2-stage1-prompt-fragility.md`. **Gate
> pre-F2-fullrun PASS.** Prossimo step: **F2-fullrun** (508k, ~12-15h DGX) in
> sessione 10 con gate utente esplicito. Master invariato.
>
> **Stato 2026-05-28 fine sessione 8**: ✅ **pre-flight (5/5) + FASE F1
> chiusi**. Branch ahead master di **84 commit**. Prossimo step:
> **F2-smoke** (100-sample gate DGX) in sessione 9 separata, poi F2
> fullrun in sessione 10. Highlights sessione 8:
> - **Fix math error bacino**: 507.838 → **508.038** (oracle audit) era un
>   errore aritmetico di sessione 4 (+378 invece di +578), verificato
>   empiricamente su A3 TSV. Propagato in ADR-0019 + A3 + RED_ALERT.
> - **F1 ETL re-run** (`analysis/p4-fase-f-etl-build.R`, nuovo): bacino
>   produzione **508.037 sample** (`archs4-human-stage1-input-v2.jsonl`,
>   gitignored). Set equality vs oracle: extra=0, missing={GSM3612196}.
>   Lo script β era stale pre-FASE-C (5 problemi: H2 assente, H2-su-raw,
>   molecule droppato, D4 non applicato, H5_PATH errato) → riscritto.
> - **H2 mouse-mislabeled come filtro Stadio 0** (opzione A1 + drop pulito
>   (i) scelte utente): drop dei 72 GSE su series RISOLTO (post-resolver),
>   non raw H5. Helper `.flag_mouse_mislabeled_h2` + `.build_libsize_vec`
>   (TDD). GSM3612196 (GSE126753, 78.6% murino, residuo H2 di β) rimosso →
>   F1 è 1 sample più pulito dell'oracle.
> - **Pre-flight verificati**: smoke `is_sample_classifiable` 7/7 reali +
>   7/7 coverage TDD; `build_archs4_metadata_v2` full H5 GATE PASS
>   (n_kept 509.033 = F1 pre-H2, schema F5-compatibile, biosample SAMN
>   99.98%); config DGX live OK (.sif v0.20.2 presente, partition
>   infinite, Mistral cached).
> - **Igiene**: DESCRIPTION 9020→9026 (allineata + bump F1), man/*.Rd
>   rigenerati (42 file drift sessioni 5-7, NAMESPACE invariato),
>   dgx_p4_submit default time 12h→72h (preferenza utente), cache
>   stage4-counts purgata (−5 GB pre-E1).
> - **Nota downstream tracciata**: `build_archs4_metadata_v2` non applica
>   H2 → RDS include i 996 H2-survived-D1-D4, inerti a F5 (lookup solo su
>   GSM dei cluster post-H2). Da risolvere/documentare a F5.
>
> **Stato 2026-05-27 fine sessione 7**: ✅ **FASE A+B+C+D+E0+E0b chiuse
> (21/19 task)**. Sessione 7 ha chiuso E0b — collasso same-SAMN cross-GSE
> in pool Stadio 4 — con scelta utente (a) drop deterministico max
> `lib_size`, tie-break GSM alfabetico:
>
> **Evidence pre-implementazione: A7b** in `analysis/audit/A7b-*` —
> sui 425 GSM cross-GSE: 0% mix per `library_source` / `molecule_ch1` /
> `data_processing`, 45% mix per `instrument_model`, 95% mix per
> `extract_protocol_ch1`. Mediana `lib_size_ratio` cross-GSE 2.23×.
> Counts correlation cross-GSE Pearson(log1p) 0.41-0.75 anche con
> metadata identico (NON replicati tecnici). Upper bound 128 group
> cluster colpiti (32.4% dei 176 SAMN duplicati). Opzione (b) average
> counts scartata (statistica indifendibile cross-pipeline), opzione (c)
> sotto-noise scartata (non diluito).
>
> **Implementazione E0b in 7 commit bite-sized TDD**:
> - T1 `13d5342`: helper `.dedupe_gsm_by_samn` + `.lookup_chr/_num` +
>   `.empty_samn_dedupe_dropped` in `R/stage4-samn-dedupe.R` (nuovo file,
>   38 expect_*). Regola: max libsize, tie-break alfabetico GSM, NA SAMN
>   preservato (no collapse), `exclude_samn` per cross pair-baseline.
> - T2 `8fc6491`: integrazione MEGA pure in `.build_mega_metadata_safe`
>   (signature `biosample_lookup` + `libsize_lookup` default NULL =
>   retrocompat). `conflict_type = "cross_gse_samn_dedupe_kept_<gsm_kept>"`
>   in `pooling_warnings`. 14 expect_*.
> - T3 `5f600e1`: integrazione MEGA-AUG baseline pool in
>   `.assemble_mega_aug_metadata_bidir` + closure `build_baseline_rows`
>   con `exclude_samn = pair_samn_set` (cross pair-baseline). Return
>   list 8 -> 9 campi (`samn_dedupe_log`). 20 expect_*.
> - T4 `b386144`: `.build_samn_dedupe_lookups(h5_metadata)` helper +
>   propagazione down via `.pool_all_clusters` parametri lookup. Fallback
>   graceful (warning) se `biosample_id` o `lib_size` mancanti in
>   h5_metadata. 18 expect_*.
> - T5 `88d916c`: `stage4_default_config()$schema_versions$samn_dedupe_strategy
>   = "max_libsize_alphabetic_tiebreak"`. Registrato in run_metadata.json.
> - T6 `6ed729d`: smoke integration end-to-end MEGA pure (8 expect_*).
> - T6b `9fee42c`: **fix paper-grade self-review** — propaga
>   `assembled$samn_dedupe_log` MEGA-AUG in `pooling_warnings`
>   dell'orchestrator. Era persa silenziosamente (asimmetria con MEGA
>   pure). Schema conflicts standard (`cluster_id, sample_id, studies=NA,
>   roles=arm, conflict_type`). 5 expect_*.
>
> **Doc aggiornati**: A7b sintesi (`analysis/audit/A7b-samn-duplicate-analysis.md`),
> ADR-0019 §D9 con criterio max-libsize, RED_ALERT.md §E0b status ✅.
> Codex CLI tentato per review esterna: auth ChatGPT non supporta i
> modelli gpt-5.x-codex con quel tier (errore `400 invalid_request_error`)
> -> review affidata a Claude Opus 4.7 paper-grade. Self-review ha
> scoperto il finding T6b. Nessun whack-a-mole.
>
> Test suite E0b perimetro: **49 test_that, 202 expect_* PASS, 0 FAIL**
> (7 file: samn-dedupe, samn-lookups, mega-safe, mega-aug-samn, e0b-schema,
> e0b-smoke + delta su mega-aug-bidir). Branch ahead di master di **44
> commit** (37 pre-sessione 7 + 7 commit E0b T1..T6b). Master invariato.
>
> **Aggiornamento sessione 7 post-E0b — FASE E1 chiusa (gene axis Ensembl)**:
> ✅ FASE A+B+C+D+E0+E0b+E1 chiuse (22/19 task). E1 ha sostituito ADR-0016
> Decision 2 (workaround make.unique) con axis Ensembl ID univoco
> (67186 ID, 0 NA in H5 v2.5). Schema breaking pulito: colonna `gene`
> -> `gene_id` (Ensembl) + nuova `gene_symbol` (HGNC label, NA-aware).
> Layer B aggiornato (7 plot file): label leggibile = symbol con
> fallback gene_id. GO enrichment switch keyType SYMBOL -> ENSEMBL +
> readable=TRUE.
>
> **Implementazione E1 in 6 commit bite-sized TDD**:
> - `d9bcc00` T1: helper `.parse_gene_axis` (early-fail su NA, "", duplicati)
> - `93b8b3e` T2: `.h5_gene_axis` Ensembl + `.attach_gene_annotation` attr named
> - `13d88a1` T3: DE functions schema gene_id + gene_symbol; rimosso defensive
>   make.unique sostituito da stop() guardia
> - `3e486ec` T4: orchestrator cbind cross-study riattacca attr (catturato
>   durante self-review)
> - `5ba0786` T5: Layer B compatibility (7 file + helper fixture + 3 test)
> - `934d156` T6: cache key disk + schema_versions bump v2_ensembl_gene_axis
>
> Test perimetro E1 + Layer B: **669 expect_*, 0 fail** (38 file).
> Self-review paper-grade Opus 4.7 ha confermato integrita' algoritmica.
> Codex CLI ancora non utilizzabile (auth ChatGPT tier no gpt-5.x-codex,
> documentato in E0b). ADR-0016 Decision 2 marcato "Superseded by
> ADR-0019 §D6".
>
> **Aggiornamento sessione 7 post-E1 — FASE E2 chiusa (2026-05-28)**:
> ✅ FASE A+B+C+D+E0+E0b+E1+E2 chiuse (23/19 task). E2 ha implementato il
> filter `gene_biotype` di default 'protein_coding' (~23k geni su ~67k)
> alla sorgente Stadio 4. Parametro `build_stage4_results(gene_biotype_filter)`
> NULL = no filter, vector = union.
>
> **Implementazione E2 in 5 commit bite-sized TDD**:
> - `605ceb6` T1: `.parse_gene_axis` estende a 3-comp (ensembl + symbol +
>   biotype); `.attach_gene_annotation` setta attr gene_biotype named
> - `5f39215` T2: `.h5_gene_axis` legge meta/genes/biotype (cache key
>   `v3_with_biotype`); `.fetch_counts_from_h5` parametro filter +
>   helper `.apply_biotype_filter` NA-strict
> - `b7deb8e` T3: `.cache_key_for_fetch` stratifica per biotype filter
>   (permutazioni vector normalizzate); `.fetch_counts_cached` propaga
> - `3536dd4` T4: `build_stage4_results` parametro + closure default
>   propaga via `with_mocked_bindings`
> - `84d0ccc` T5: `schema_versions$gene_biotype_filter_strategy` +
>   `run_metadata$gene_biotype_filter` registrato; JSON pretty include
>   top-level field
>
> Test perimetro E2: 26 test_that, 61 expect_* PASS / 0 FAIL post-T7a+T7b
> (era 18/37 pre-fix). Perimetro stage4+layer-b totale: 744 expect_*.
>
> **Codex CLI finalmente eseguibile (2026-05-28 fine pomeriggio, auth
> restored)** -> review post-T6 ha sollevato 5 finding paper-grade.
> Indirizzati tutti in 2 commit:
> - `0f1dd59` T7a: 4 fix (warning fetch_fn esterno + errori distinti
>   nel .apply_biotype_filter + warning NA biotype + error H5 senza
>   biotype)
> - `054fb88` T7b: 1 fix (run_metadata\$gene_axis_summary cardinalita'
>   pre/post filter per audit paper-grade)
>
> Convenzione utente applicata: "codice robusto, non bello". Tutti i
> fix sono robustness alla sorgente (errori diagnostici, warning su
> silent drop, audit trace), no over-engineering API.
>
> **Aggiornamento sessione 7 post-E2 — FASE E3 chiusa (2026-05-28)**:
> ✅ FASE A+B+C+D+E0+E0b+E1+E2+E3 chiuse (24/19 task). E3 ha aggiunto
> covariate batch `instrument_model` + `aligner_class` al design DE
> Stadio 4 (limma-voom per-studio + dream-mega cross-study). Edge case
> gestiti: single-level drop | missing skip | NA partial -> 'unknown' |
> confound col treatment -> drop tutte covariate (pre-fit rank check).
>
> **Implementazione E3 in 7 commit bite-sized TDD**:
> - `225b015` T1: helper `.augment_de_design` (4 edge case base)
> - `e065db8` T2: `.run_limma_voom_de` integra design
> - `369b1b8` T3: `.run_dream_mega` integra design
> - `4e9ee68` T4: orchestrator + build_stage4_results propagano
> - `3fed578` T5: schema_versions + run_metadata trace
> - `02b848a` **T6a post-Codex Fix C1**: pre-fit `qr(X)$rank` check ->
>   drop covariate se design rank-deficient (confound col treatment)
> - `ff037ee` **T6b post-Codex Fix C2**: helper
>   `.join_covariates_to_metadata` con warning `join_incomplete`
>   distinto da `NA biologico`
>
> Test perimetro E3: 17 test_that, 66 expect_* PASS / 0 FAIL.
> Perimetro stage4+layer-b totale post-E3: **810 expect_*, 0 fail**.
> Self-review Opus 4.7 OK; Codex review eseguibile (auth restored) ->
> 2 finding bloccanti paper-grade (C1+C2) indirizzati prima del closing.
>
> **Aggiornamento sessione 7 post-E3 — FASE E4 + E5 chiuse (2026-05-28)**:
> ✅ FASE A+B+C+D+E0+E0b+E1+E2+E3+E4+E5 chiuse (26/19 task RED ALERT).
>
> - **E4** (`af8a80c`): test cascade integration E1+E2+E3 con mock H5
>   sintetico. 5 test_that, 23 expect_*. Verifica Ensembl axis +
>   biotype filter + covariate batch + pre-fit rank check in un flow
>   end-to-end.
> - **E5** (commit pending): Layer B compatibility check. Schema_versions
>   bumpato a v2_ensembl_gene_axis. Test 8 expect_* + script standalone
>   `analysis/audit/E5-smoke-plots.R` che materializza plot
>   (volcano/forest/heatmap/MA/top_genes/summary_card) in
>   `analysis/audit/E5-smoke-plots/` per giudizio visuale.
>
> Test perimetro post-E4+E5: **840 expect_*, 0 fail** stage4+layer-b
> totale.
>
> **FASE E del RED ALERT CHIUSA**. Prossimo step utente-driven:
> **FASE F** (rebuild pipeline F1-F6: F1 ETL re-run, F2 Stadio 1
> fullrun DGX, F3 Stadio 2 fullrun, F4 Stadio 3 rebuild, F5 Stadio 4
> Layer A rebuild, F6 Layer B re-selection). FASE F in sessione
> separata con gate utente esplicito.

---

## Visione del progetto

`simulomicsr` è una **pipeline R per meta-analisi RNAseq cross-studio
design-aware** basata su classificazione LLM dei metadati. Il nome è
legacy — il pacchetto NON simula nulla.

**Positioning (ADR-0006).** simulomicsr **non** è un altro annotatore
di GEO/SRA — quel campo è coperto da ARCHS4, MetaHQ (Hicks 2026),
MetaSRA, e dal multi-agent metadata curation di Mondal et al. 2025. Il
valore unico è la pipeline end-to-end **design-aware**: dal metadato
testuale alle comparisons appaiate (`design_role` LLM-driven entro lo
studio) → canonical `comparability_anchor` v3 cross-studio → pooling
effect-size random-effects (`metafor` REM). L'unico competitor end-to-end
vicino è RummaGEO (Maayan 2024), che però resta a livello di gene-set
per-studio senza anchor canonico né effect size. **Benchmark
testa-a-testa vs RummaGEO è deliverable integrale di P3.5 eval** (non
aggiunta opzionale post-hoc).

Pipeline complessiva (5 stadi):

1. **Acquisizione** — bulk RNAseq da ARCHS4-like (HDF5, ~700k+ sample da GEO).
2. **Stadio 1 sample-level** (P2 ✅) — classificare ogni sample dalla
   stringa di metadati GEO in un record JSON `sample_facts.stage1.v3`
   (cell context, perturbazioni, dose, tempo, ambiguity flags).
3. **Stadio 2 study-level** (P3 ✅) — interpretare il design
   sperimentale dello studio: replicate groups, design_role per sample,
   comparisons con `comparability_anchor` canonicalizzato per
   cross-studio matching.
4. **Stadio 3 raggruppamento** — cluster cross-studio sui
   `comparability_anchor`.
5. **Stadio 4 DE per-studio + Stadio 5 meta-analisi**
   (`DESeq2`/`limma` + `metafor` REM).

## Asset chiave — gold standard

`data-raw/relevant_sample_classified.xlsx` (committato nel repo, ~10 MB).

- Foglio `relevant_sample`: 130.784 righe × 8 colonne.
- Colonne: `Column1`, `string` (input metadata), `trtctr_EP` (gold
  manuale autore), `geo_accession`, `series_id`, `treat`, `trtctr`
  (baseline shallow), `gold` (ricontrollo terzo revisore).
- `trtctr_EP` riflette una semantica "qualunque intervento esplicito"
  che diverge da `design_role` — il gold "design-aware" è in
  `inst/extdata/p35c-minigold-reviewed-v5.csv` (100 sample, P3.5-C/D).

## Stato corrente (2026-05-23 — P5 Stadio 4 Layer A fullrun COMPLETE, tag `p5-stadio4-complete`)

### P5 Stadio 4 Task 21 chiusura — debugging sistematico + fullrun (branch `p5-stadio4-de-perstudio` ff-merged in master, 2026-05-22/23)

Sessione di debugging sistematico post-handoff: 5 bug distinti isolati con riproduzione minimale + fix mirati (no whack-a-mole). 8 commit + 1 commit doc. Suite Stadio 4 finale: **322 PASS / 0 FAIL / 1 SKIP** (+34 vs handoff 288).

**Bug fixati questa sessione**:

- **Problema A — `duplicate row.names` MEGA-AUG bidir** (`25c158d`): 3 sotto-cause emerse dallo scan dei 310 cluster `mega_aug`. (a) 13 cluster con stesso baseline pool su entrambi i bracci → mono-fallback (Opzione 1: augmenta solo il braccio control, marca `bidir_collapsed_to_mono=TRUE` nelle diagnostiche). (b) 7 cluster con pool distinti ma GSM condivisi (super-series ARCHS4) → drop role-conflict da entrambi i bracci. (c) 5 cluster `mega_aug` senza pair risolvibile → skip-guard esplicito `mega_aug_no_study_dispatch`. Scan post-fix: 0/310 duplicati.
- **Scoperta paper-grade: dream non aveva mai girato sui dati reali** (`f3ce3af`, ADR-0016 §Decision 2). ARCHS4 v2.5 `meta/genes/symbol` ha 4638/67186 simboli duplicati (paralogi PAR/KIR/HLA: più Ensembl ID legittimi mappano sullo stesso HGNC symbol). `dream` rifiuta rownames non unici → `.run_dream_mega` ripiegava silenziosamente sul fallback limma. Nessun risultato scientifico prodotto da questa pipeline è stato impattato (i 4 fullrun precedenti erano falliti prima del completamento; smoke test usavano fixture con simboli già unici). Fix: `make.unique()` deterministico in `.h5_gene_axis` (KIR3DL2, KIR3DL2.1, …) — cross-study coerente, niente perdita di informazione, niente aggregazione biased ante-test.
- **Problema B — OOM su cluster MEGA-AUG grandi** (`d5f6040` + `f8fab2e` + `22a5a0f` + `8c6eba9`, ADR-0016). Due fix complementari:
  - Cap dimensione baseline pool: `max_baseline_per_arm = 350` (calibrato da curva di saturazione su dati veri — `analysis/p5-stage4-debug-problemB-saturation.R`: a 350 correlazione logFC col pool pieno = 0.997, n. geni significativi al picco; oltre 350 il risultato non migliora).
  - Worker cap: `dream_workers_cap` 100 → 16 (in isolamento dream costa ~1 GB/worker, ma in contesto reale `build_stage4_results` fork-COW dello state alza il costo a ~3.4 GB/worker — a 32 worker il picco era 127 GB; a 16 worker il picco per-cluster è ~71 GB, validato end-to-end sui 3 cluster `mega_aug` più grandi).
  - Bonus: per-cluster progress logging + memoization assi H5 (`.h5_sample_axis` + `.h5_gene_axis` in env `.h5_axis_memo`).
- **Dashboard render — volcano subsample** (`858d9bb`): a 13.7M righe il chunk `volcano-overall` produceva una stringa che eccedeva R max length nel post-process knitr (`gsub`). Sub-campionamento deterministico a max 100k punti (tutti i sig + sample dei non-sig, seed=42).

### Layer A fullrun COMPLETE (run_id `96c43acb`, 2026-05-22T23:10Z → 2026-05-23T03:26Z)

- **622/622 cluster OK, 0 errori, watchdog mai triggered.** Wall 1682 min (~28h) su laptop 251 GB. **Dream-based** con il fix gene-symbol applicato.
- **Output** `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` (gitignored):
  - `cluster_pooled.parquet` 375 MB — **13.691.756 righe** (mega 4.506.781 + mega_aug 9.184.975 by_method).
  - `per_study_de.parquet` 383 MB — 12.009.646 righe.
  - `stage4_dashboard.html` 77 MB.
  - `run_metadata.json` (config completa registrata) + `qc_report.rds` + `non_processable.rds`.
- **Config registrata**: `max_baseline_per_arm=350`, `dream_workers_cap=16`, `legacy_monodirectional=FALSE` (bidir on), `franchini_correction=TRUE`, `de_engine.mega=dream`, `de_engine.mega_aug=dream`.

## Stadio 4 Layer B (2026-05-24, branch `p5-stadio4-layer-b`)

Pipeline semi-automatica generator di "showcase case study" publication-grade.
Input: `analysis/layer-b-selection.csv` (10-20 cluster_id curati a mano dalla
dashboard Layer A). Output: bundle dir-per-cluster + Quarto HTML aggregate.

Decisioni chiave (vedi ADR-0017 + spec 2026-05-24):
- Workflow: semi-automatico CSV-driven (no Shiny, no dashboard button)
- 8 plot per cluster con dispatch conditional (forest = REM+MEGA-AUG,
  heterogeneity = REM only)
- Drop-into-paper polished (PNG @300 DPI + SVG, caption inglese paper-ready)
- Top-N: 10 forest / 30 heatmap / 30 table / 15 volcano labels
- HTML standalone aggregate (NO PDF)
- NO targets integration (script standalone primary)
- Smoke 3-cluster gate obbligatorio pre-batch

Test suite Layer B: 142+ PASS / 0 FAIL su filter `^layer-b` (269 cumulative
suite intera). Wall smoke 3-cluster: 2.8 min.

DESCRIPTION delta paper-grade: clusterProfiler, ComplexHeatmap, DESeq2, dplyr,
ggplot2, ggrepel, kableExtra, org.Hs.eg.db, patchwork, quarto, sva in `Imports`;
ReactomePA, ggrastr in `Suggests`.

**Status: COMPLETE 2026-05-24, tag `p5-stadio4-layer-b-complete`, ADR-0017 Accepted.**

Smoke validation (2026-05-24): 3 cluster pick (mega_big group_L0_a6f8c0e9,
mega_aug pair_L2_3ce85e50, mega_small group_L0_1a0673ae) → bundle dir-per-cluster
+ layer_b_report.html standalone 8 MB con 16/16 immagini base64-embedded +
caption english paper-ready + run_metadata.json con bioc_versions +
n_plots_generated/skipped + summary card con anchor risolto (treated side per
pair, level-aware per group L0..L4).

Cleanup paper-grade post-implementation: ggplot2 4.0 deprecations rimosse, SVG
size -66% to -90% (raster body via ggrastr + ComplexHeatmap::use_raster), HTML
embed-resources fix (era 0 base64 -> 16), parse_anchor_key gestisce mode='pair'
(treated__VS__control), ComBat guard su single-level treatment, summary_card
n_total_samples threading via per_cluster_samples (era N/A per mega-strict),
extract_anchor_summary public helper (era duplicato inline negli script).

Branch p5-stadio4-layer-b 31 commit ff-merged. Push remote rimane all'utente.

### Layer B selection + batch 15 case study (2026-05-24, branch `p5-stadio4-layer-b-selection`)

Curation paper-grade della selection.csv tramite shortlist data-driven sul
`cluster_pooled.parquet` (13.7M righe) + dedup gerarchia anchor v3 (487 cluster
Layer A → 293 unici). Script riproducibile `analysis/p5-stage4-layer-b-shortlist.R`
con criteri documentati: hard gates (k_effective≥4, n_sig_05≥50, max_logFC≥1.5,
kind_effective non-degenere; relaxed per mega coarse-anchor) + score composito
4-dim equipesi (magnitude/effect/power/precision) + stratified pick con cap
diversità biologica + smoke pin garantiti.

Shortlist 31 candidati → selection finale **15 case study** publication-grade:
- 13 mega_aug biology-driven: pathogen exposure × 3 (TLR ligands in blood,
  Resiquimod TLR7/8, polyI:C TLR3), small_molecule × 2 (ChEBI:17236 lung +
  smoke), cytokine × 2 (IFN-β kidney, ChEBI:16236 skin), environmental × 2
  (Hypoxia HUVEC, contact inhibition lung), genetic_overexpression × 1
  (miR-9/9*-124 neural reprog skin), disease_vs_normal × 1 (MeSH:D011279
  Prostatic Neoplasms), differentiation × 1 (Mesendoderm hESC)
- 2 mega smoke-validated: group_L0_a6f8c0e9 (transversal blood) +
  group_L0_1a0673ae (transversal skin)
- Coverage 11 kind_effective × 8 tessuti, mix level L0-L4.

Batch eseguito su laptop (wall **9.3 min**, run_id `56b911e6`):
- Output `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/` (gitignored):
  15 bundle dir-per-cluster + `layer_b_report.html` 33 MB standalone con
  **88 plot base64-embedded** (no reference esterne) + `run_metadata.json`
  con bioc_versions + selection_sha256 + `selection_resolved.csv`.
- n_plots_generated/skipped: 88 / 17 (forest skip-graceful per i 2 mega
  non-REM; heterogeneity sempre generato).
- Warnings: 31 generici (ComBat mean.only su single-sample batch, pattern noto).

Next steps user-driven:
- Aprire `layer_b_report.html` per review visiva delle 15 case study
- Compilare `narrative.qmd` per ogni bundle (sezioni TODO: Biological context,
  Findings, Discussion) → integrazione nel paper Results
- ChEBI ID lookup per le 4 label "CHEBI:xxxxx" generiche (es. CHEBI:17126,
  CHEBI:17199, CHEBI:17236, CHEBI:16236) per arricchire le label paper
- Eventuale Stadio 5 meta-analisi (spec design da scrivere)

### ⚠️ AUDIT LLM ANCHOR CLASSIFICATION (2026-05-24, branch `p5-llm-anchor-classification-audit`, NON MERGIATO)

Durante il ChEBI lookup richiesto dall'utente per arricchire le label Layer B
è emerso un finding paper-grade gravissimo che bloccca l'integrazione Layer B
nel paper finché non si decide una mitigation. Audit cross-validation degli
`agent_id` LLM-emitted (Mistral-Small-3.2) contro ontologie controllate ChEBI
(205k compounds), HGNC (45k genes), MeSH 2025 (31k descriptors):

| Metrica | Valore | Cosa dice |
|---|---:|---|
| Field-swap rate `<DB>:<num>` | **23.87%** (63738/267056) | ID numerico nel campo `preferred_name` invece di `id`. Recuperabile post-hoc via lookup. |
| Pure hallucination rate | 0.97% (2587/267056) | Bassissimo. |
| `kind_effective` accuracy vs ChEBI has_role | cytokine_stim **0.7%** match, pathogen **2.4%** match, vehicle_only 93.5% match | **Disastroso** per cytokine/pathogen. |
| Fragmentation L0G (compound, kind, level, mode fissati) | 34.4% | 1/3 compounds split in piu' cluster. |

**Su 15 case study Layer B**:
- 7 scientificamente validi (poly(I:C), Resiquimod, IFN-β, Hypoxia, miR-9, contact inhibition, Mesendoderm)
- 2 transversal ambigui (smoke `group_L0_*`)
- 2 con compound LLM-oscuro CHEBI:17236 (probable consistent hallucination)
- **4 critically wrong**: Carnitine-as-pathogen, Ethanol-as-cytokine, dihydroxyphthalic-as-pathogen, Pregnanetriol-as-disease

**Impatto**:
- Pooling DE Stage 4 algoritmicamente VALIDO (anchor stringa deterministica)
- Interpretazione BIOLOGICA INVALIDA per migliaia di cluster (label numerica + kind wrong)
- L2 paper limitation va espansa drasticamente

**Decisione utente 2026-05-25**: OPZIONE 2 — post-hoc ontology override
+ rebuild Stage 3 + Stage 4 + Layer B. ADR-0018 Proposed.

Documentazione completa pronta su branch `p5-llm-anchor-classification-audit`:
- **ADR-0018**: `docs/decisions/0018-llm-anchor-ontology-override.md` (decisione architetturale)
- **Spec**: `docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md`
  (design tecnico: decision tables, edge cases, versioning, validation strategy)
- **Plan**: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`
  (task-by-task implementation, 5 sessioni S1-S5 con gate utente)
- **HUMANE**: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-HUMANE.md`
  (versione leggibile + decisioni rinviate + cosa NON fa + stima tempo)
- **Audit drive**: `docs/findings/2026-05-24-llm-anchor-classification-audit.md`

Wall stimato totale: **1-2 giorni** distribuiti su 5 sessioni con gate
utente tra ogni sessione (vedi plan §SESSIONE 1..5).

### S1 COMPLETED 2026-05-25 (impl + tests + smoke isolato)

**5 commit incrementali su `p5-llm-anchor-classification-audit`** (master invariato):

- `5ea32c7` T1: `R/ontology-lookup.R` + mini fixtures + tests TDD (28 test, 56 expect_*).
  Loader singleton + 9 accessor O(1) hash-env per ~315k lookup downstream.
- `a91764d` T2: `resolve_agent_canonical()` in `R/anchors.R` + tests (28 test, 70 expect_*).
  Decision table 16+ branch spec §4.2.
- `7aad2e2` T3: `infer_kind_from_ontology` + `infer_kind_with_override` + tests
  (28 test, 51 expect_*). Override policy paper-grade conservativa: STRONG match
  registrato senza override; STRONG differ → ONTOLOGY_OVERRIDE_STRONG;
  MEDIUM/WEAK + LLM in {cytokine_stim, pathogen} kind incompatibile →
  LLM_CONTRADICTION_DETECTED; NONE → LLM preservato + kind_unvalidatable=TRUE.
- `afac917` T4: integrazione `.extract_anchor_segments` v3.1 + `make_anchor` thin
  wrapper + `.summarize_clusters` 11 tracking columns + `ontology_releases`
  in `run_metadata` + schema_versions anchor=v3.1 + resolver=v1.0.0.
  **9 nuovi test integration** (test-stage3-anchor-v31.R). Defensive
  `.coerce_chr1` + `.normalize_key_chr` per LLM real-world input
  character(0)/array/NA (critico: previene crash exists() in ~315k lookup).
- `45459f2` T5: smoke isolato `analysis/p5-ontology-override-smoke.R` 6 case
  paradigmatici, 6/6 PASS (log `analysis/p5-ontology-override-smoke.log`).

**Test result globale S1**: 1703 PASS / 0 FAIL / 3 SKIP (full suite escluso
perf-budget). Anchor-related: 443 PASS. Stage 3 (mocked): 268 PASS.
No regressioni.

**Smoke validato** sui 6 paradigmi dell'audit:
1. Carnitine field-swap LLM=pathogen → CHEBI:17126 + override LLM_CONTRADICTION_DETECTED
2. Ethanol LLM=cytokine_stim → CHEBI:16236 + override ONTOLOGY_OVERRIDE_STRONG → vehicle_only
3. DMSO type=vehicle → STR:dmso LLM_VEHICLE_LITERAL (preserva intent)
4. Resiquimod (0 ChEBI roles) LLM=pathogen → preservato + kind_unvalidatable=TRUE
5. poly(I:C) LLM=pathogen → CHEBI:84491 STRONG match (adjuvant)
6. Disease role=case D011471 → MeSH:D011471 STRONG disease_vs_normal

**Gate utente S1→S2 APPROVATO** (2026-05-25).

### S1bis + S2bis COMPLETED 2026-05-25 (anchor v3.1.1 + Stage 3 rebuild + 4/4 audit chiuso)

**Decisione utente 2026-05-25 (post-S2 v3.1 diff)**: OPZIONE B
(extend resolver per chiudere tutti i 4 audit case) + **DGX UniPD per S3**
Stage 4 rebuild.

**Output rebuild Stage 3 v3.1.1**:
`analysis/p4-output/20260525T172032Z-stage3-v31-2655ecb0/` (gitignored).
- 390.532 cluster (+13 vs v3.1 per nuova rule DISEASE_KIND_CONTRADICTED)
- 1.255.180 assignments (invariato vs v3.1)
- Wall rebuild: 78.9 min (invariato vs v3.1 79.9 min)
- schema_versions.anchor=v3.1.1 + resolver=v1.1.0 in run_metadata.json

**Score override v3 → v3.1 → v3.1.1**:

| metric | v3 | v3.1 (S2) | v3.1.1 (S1bis+S2bis) |
|---|---:|---:|---:|
| kind_overridden | 0 | 7068 (1.81%) | **7845 (2.01%)** |
| LLM_CONTRADICTION_DETECTED | 0 | 4568 | **2833 (-1735 BUG FIX)** |
| DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY | 0 | 0 | **2512 (NEW)** |
| ONTOLOGY_OVERRIDE_STRONG | 0 | 2500 | 2500 |
| kind_chebi_zero_roles flag | n/a | n/a | **34878 (8.93%) NEW** |

**Audit 4 critically wrong Layer B → 3/4 FIXED deterministic + 1/4 FLAGGED**:

| Compound | Status v3.1.1 | Override reason |
|---|---|---|
| Carnitine CHEBI:17126 | ✅ FIXED (since v3.1) | LLM_CONTRADICTION_DETECTED |
| Ethanol CHEBI:16236 | ✅ FIXED (since v3.1) | ONTOLOGY_OVERRIDE_STRONG |
| Pregnanetriol MeSH:D011279 | ✅ **FIXED (NEW v3.1.1)** | DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY |
| dihydroxyphthalic CHEBI:17199 | ⚠️ FLAGGED | kind_chebi_zero_roles=TRUE (Layer B shortlist filter) |

**BUG silente paper-grade scoperto durante TDD S1bis**: la asymmetric trust
su `source = MESH_TREE_D` ha salvato **1735 cluster** che la policy v3.1
avrebbe wrongly demotato (es. Interferon-beta MeSH:D016899 LLM=cytokine_stim
→ MeSH tree D MEDIUM small_molecule incompatibile → demote erroneo). MeSH
tree D include sia chemicals che proteine immunitarie (D12), evidence troppo
coarse per smentire LLM cytokine specifico. Magnitude inattesa ~3x più grande
del caso target Pregnanetriol singolo. Regression test guard permanente.

**Commit S1bis + S2bis** (branch `p5-llm-anchor-classification-audit`):
- `d06e389` P5 audit S1bis: anchor v3.1.1 chiude 4/4 audit set
- `5a9aad1` P5 audit S2bis: Stage 3 v3.1.1 rebuild + diff + finding

**Report paper-grade**:
- `docs/findings/2026-05-25-stage3-v31-diff.md` — diff v3 vs v3.1 (intermediate)
- `docs/findings/2026-05-25-stage3-v311-diff.md` — diff v3 vs v3.1.1 (final)

### S2 COMPLETED 2026-05-25 (intermediate Stage 3 rebuild v3.1 + diff + report)

**Output rebuild Stage 3 v3.1**:
`analysis/p4-output/20260525T140219Z-stage3-v31-52357b00/` (gitignored).
- 390.519 cluster (+46.2% vs baseline v3 267.056)
- 1.255.180 assignments (+77.3% vs 707.595)
- 192.897 non_clusterable
- Wall rebuild: 79.9 min laptop 251 GB
- schema_versions.anchor=v3.1 + resolver=v1.0.0 + ontology_releases
  (ChEBI 205k compound + HGNC 45k + MeSH 31k) in run_metadata.json

**Override conservativo**: kind_overridden 7068 (1.81%):
- 64.6% LLM_CONTRADICTION_DETECTED (4568)
- 35.4% ONTOLOGY_OVERRIDE_STRONG (2500)

Override per kind_effective_resolved:
- 4558 → small_molecule (Carnitine-like, LLM diceva pathogen)
- 1670 → vehicle_only (Ethanol/DMSO-like, LLM diceva cytokine_stim)
- 440 → cytokine_stim (Resiquimod-like, LLM diceva small_molecule)
- 316 → disease_vs_normal (MeSH disease descriptors missed)
- 84 → pathogen_or_aggregate_exposure (poly(I:C)/TLR agonists)

**Audit 4 critically wrong Layer B (vedi `docs/findings/2026-05-25-stage3-v31-diff.md`)**:

| Compound | Old kind | New kind | Status |
|---|---|---|---|
| Carnitine CHEBI:17126 | pathogen | small_molecule | ✅ FIXED |
| Ethanol CHEBI:16236 | cytokine_stim | vehicle_only | ✅ FIXED |
| Pregnanetriol MeSH:D011279 | disease_vs_normal | disease_vs_normal | ⚠️ RESIDUAL |
| dihydroxyphthalic CHEBI:17199 | pathogen | pathogen | ⚠️ RESIDUAL |

2/4 risolti, 2/4 residual (policy attuale conservativa: no MeSH tree_top
check, no override per ChEBI compound con 0 roles annotation).

**Perf budget v3.1** (test aggiornato): 90 min wall + 8 GB memory delta
(cushion ~15-18% sui valori reali 76.6 min / 6.75 GB). Overhead +60 min su
Phase 6 `summarize_clusters` per resolve+infer lookup su 390k cluster
(atteso per design ADR-0018).

**Commit S2**:
- `74dcad4` P5 audit S2 Task 6: Stage 3 v3.1 rebuild + perf budget v3.1
- `f16de37` P5 audit S2 Task 7: diff Stage 3 v3 -> v3.1 + finding report

**Gate utente S2→S3 in attesa**.

### ⚠️ GATE PAUSE 2026-05-25 (utente richiede audit completo pipeline pre-S3)

A fine sessione S2bis l'utente ha espresso preoccupazione paper-grade per il
pattern emerso: **3 bug paper-grade scoperti in sequenza durante S2 + S1bis**
(Pregnanetriol mancato override, dihydroxyphthalic mancato flag, bug silente
Interferon-beta-like con 1735 cluster impatto). Conclude: "non mi fido più
di tutta la pipeline. Ripercorrila tutta. Audit completo dalla prossima
sessione".

**Decisione utente 2026-05-25 sera**:
- S3 Stage 4 rebuild su DGX → **SOSPESO**
- S4 Layer B re-shortlist + batch → **SOSPESO**
- S5 close ADR-0018 → **SOSPESO** (ADR resta `Proposed`)
- Merge `p5-llm-anchor-classification-audit` → master → **SOSPESO**

**Handoff completo audit pipeline**: vedi
`docs/superpowers/specs/2026-05-25-pipeline-trust-audit-handoff.md`.

Scope proposto (5 stadi × ~2-4h = 10-20h totali su 2-3 sessioni):
1. Stage 1 LLM sample-level (879k record)
2. Stage 2 LLM study-level (39k record)
3. Stage 3 anchor v3.1.1 + resolver v1.1.0 (390k cluster)
4. Stage 4 Layer A pooling DE (96c43acb baseline)
5. Layer B existing selection (56b911e6, 15 case study)

Workflow next session: gate utente tra ogni stadio. Output = 5 trust report
paper-grade in `docs/findings/<date>-stage<N>-trust-audit.md`.

Sub-skill da usare: `superpowers:systematic-debugging` come framework.

### Prossima sessione: AUDIT COMPLETO PIPELINE (PAUSED prima di S3)

**Pipeline freeze (in attesa audit)**:
- Stage 1 master rescued: `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (879k record, gitignored)
- Stage 2 master rescued: `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (39247 predictions)
- Stage 3 v3 baseline: `analysis/p4-output/20260519T055547Z-stage3-2153addc/` (267k cluster, committed)
- Stage 3 v3.1 intermediate: `analysis/p4-output/20260525T140219Z-stage3-v31-52357b00/` (gitignored, 390519 cluster)
- **Stage 3 v3.1.1 final**: `analysis/p4-output/20260525T172032Z-stage3-v31-2655ecb0/` (gitignored, 390532 cluster)
- Stage 4 Layer A baseline: `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` (gitignored, 622 cluster pooled)
- Layer B existing: `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/` (gitignored, 15 case study + 88 plot)

**Sub-skill da invocare next session**: `superpowers:systematic-debugging`
come framework di audit (NON `executing-plans` perché non c'è un plan ancora
scritto — il plan è il handoff stesso).

Branch invariato (`p5-llm-anchor-classification-audit`), master invariato.

Memorie correlate: [[project_llm_anchor_classification_audit]] (status PAUSED) +
[[no-whack-a-mole-debugging-sistematico-dopo-crash-ripetuti]] +
[[feedback-no-fretta-paper-grade]] + [[feedback-explain-then-decide]].

---

## Stato precedente (2026-05-17 — P4 β rescue cascade COMPLETE, tag p4-beta-rescue-complete pending)

### α (consolidato, riproducibile)

Pipeline classification stage1 + stage2 sul gold-standard XLSX 130.784 sample:

- **α stage1** (Task 21, 2026-05-07) → 130.784 / 130.784 = **100.00%** schema. Dettagli NEWS 0.0.0.9009-0.0.0.9011 + ADR-0008.
- **α stage2** original (Task 22, 2026-05-10, v0.10.0 + workaround stack) → 8.532 / 8.546 cs25 = 99.84% schema, mini-gold 93.3%.
- **α stage2 re-run cs50** (ADR-0010, 2026-05-11, v0.20.2-cu129 + clean stack) → **6.649 / 6.652 cs50 = 99.96%** schema single-pass, **mini-gold 96.7%** (+3.4pp). Default flipped cs25→cs50.

### β (stage1 + stage2 fullrun COMPLETE 2026-05-15/17, tag p4-beta-archs4-human-complete)

Pipeline scalata su ARCHS4 v2.5 human bulk RNA-seq (~10x α):

- **β ETL** (Task β-1..β-6, 2026-05-12) → **888.821 sample** human + RNA-Seq, 32.905 unique GSE pre-resolver, **193.097 multi-series** risolti. Output JSONL `analysis/input/archs4-human-stage1-input.jsonl` (262 MB, gitignored).
- **β series-id-resolver SRP-driven Op D revised** (`R/etl-series-resolver.R`, Task β-4): 99.86% resolti via signal (`clean_super_scarted` 183.041 + `srp_a_only/b_only` 9.011 + minor branches), 0.54% heuristic tiebreak/fallback (1.041 sample), 0 sample droppati. Test 23-pair gold replication PASS (Exp D2).
- **β GATE #1** mini-gold format B (Task β-8, 2026-05-12): stage1+stage2 end-to-end su 100 mini-gold → schema 100% s1 + 100% s2, **accuracy binaria 98.00%** (mappato design_role_v3 → control/treated via `R/eval-stage2.R::design_role_to_binary`). +1.3pp vs α 96.7%. Wall DGX 4 min totali.
- **β GATE #2** smoke 1000 stratificato per nchar quartile (Task β-9, 2026-05-12): schema **99.50% s1 + 100% s2**, 5 LLM fail droppati lenient (0.5%), tier S=718 M=3 L=0 XL=0 (no overflow), design_kind distribution sana (case_control 40%, treatment_vs_vehicle 18%, multi_arm 17%).
- **β Task 10 stage1 fullrun via chunked orchestrator** (2026-05-14/15): wall **17h53min** (20:07 UTC 2026-05-14 → 14:00 UTC 2026-05-15) per 888.795 record mainstream. 89 chunks da 10k, cron `*/3 * * * *` autonomous + cascade COMPLETED→submit-next. Throughput stabile ~12.1 min/chunk. **Zero stall**. State machine: `scripts/p4-beta-stage1-chunked-tick.sh` + `analysis/p4-beta-chunked-state.txt`.
- **β Task 10b stage1 outliers** (2026-05-15): 26 record con `nchar > 3500` (0.003%) processati separatamente con `max_model_len=32768` (Strategy A2). Strategy A1 (`max_model_len=8192`) aveva riprodotto stall su job 20705. Wall **2m23s** per 26/26 record. Strategia documentata in memoria `project_vllm_scheduler_deadlock`.
- **β Master output stage1**: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl` (888.821 righe, 3.23 GB, gitignored), concat di 90 run dirs DGX (89 chunks + 1 outliers).
- **β Task 11 stage2-input build** (2026-05-15): 887.250 sample validi (1.571 droppati lenient per LLM fail) / 28.479 GSE → **39.205 record stage2** (12.989 chunked in 2.263 studi multi-chunk + 26.216 unsplit). Output `analysis/input/archs4-human-stage2-input.jsonl` (1.2 GB, gitignored). Wall 18m46s local.
- **β Task 12 stage2 fullrun** (2026-05-15/17): job slurm **20710**, run_id `20260515T175712Z-beta-stage2-fullrun-a275b0`, wall reale **1d 18h 29m 42s** (~42.5h DGX), ExitCode 0:0 COMPLETED. Schema validity **99.89%** (39.162/39.205, 43 errori). Tier S=16.493 / M=5.626 / L=2.605 / **XL=14.481** (37%). Throughput steady ~12-14 rec/min aggregato (4 worker H100, microbatch 50 cs50 ADR-0010/0013). Output 4 worker file merged in `predictions.jsonl` 403 MB sul DGX, collected localmente.

### β rescue cascade (Task 1-15, 2026-05-17, branch `p4-beta-rescue`)

Post-fullrun cleanup di 1.571 stage1 fails + 43 stage2 fails + discovery
paper-grade mouse-mislabeled GSE. Cascade tre strategie:

- **Phase 1 classification** (Task 2): 1.571 stage1 fails decomposti in MODE_A_WHITESPACE (660), MODE_B_LEGIT_TRUNC (147), OTHER_DEGEN (15), ETL_LEAK_NONHUMAN (749). CSV `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv`.
- **H2 — mouse-mislabeled GSE discovery + GSE-level drop** (Task 3+3b): 72 GSE ARCHS4 v2.5 `organism_ch1="Homo sapiens"` ma contenuti murini → 9.654 sample droppati GSE-level (8.398 LLM-non-human + 1.256 human collaterali) + 749 LLM JSON failure signal indiretto. Stage1 master cleaned: 888.821 → **879.167**. Stage2-input: 39.205 → **38.963**. Discovery doc paper-grade: `docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md`.
- **H1 — Stage1 LLM-failure rescue** (Task 4-8): single-shot config `rep_pen=1.2 + max_tokens=4096 + max_model_len=8192` sui 822 Mode A/B/OTHER fails. Smoke20 21008 = 20/20 = 100%. Full retry 21103 = **802/822 = 97.6%** in 3m21s. Master rescued: `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (879.167 record, colonna `rescue_source = "h1_rep12_maxtok4096"` su 802).
- **H1.2 — Stage1 strong cascade su H1 residual** (post-Task 15, 2026-05-18): single-shot strong `rep_pen=1.3 + max_tokens=8192 + max_model_len=16384` sui 20 H1 residual (18 Mode A + 2 Mode B). Full retry 21136 = **19/20 = 95%** in 4m03s. 1 residual GSM6005198. Master aggiornato in-place; colonna `rescue_source = "h12_rep13_maxtok8192"` su 19 record.
- **H1.3 — Manual curation single-record** (post-H1.2, 2026-05-18): GSM6005198 (whitespace flood profondo non cedevole a rep_pen=1.3) curato a mano leggendo i metadata input, validato contro `sample_facts.stage1.v3` schema e iniettato nel master. Colonna `rescue_source = "manual_curation_2026-05-18"` su 1 record. Script `analysis/p4-beta-rescue-h13-manual-gsm6005198.R`. Branch `p4-beta-rescue-h12` ff-merge → master, tag `p4-beta-rescue-complete` retagged su nuovo HEAD.
- **H3 — Stage2 stall rescue cs25** (Task 9-13): cs50→cs25 re-split sui 43 stage2 fails (tier XL stuck post-PR #40946) + `tiered_max_tokens=TRUE` con XL=32768. 85 cs25 chunks generati. Smoke5 21129 = 5/5 = 100% in 2m35s. Full retry 21132 = **85/85 valid, 0 residual, 43/43 original keys fully rescued** in 8min. Master rescued: `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (39.247 predictions, 0 errors).

**Risultato finale β post-rescue**:

| Metric | Pre-rescue | Post-rescue cascade |
|---|---|---|
| Stage1 master records | 888.821 | **879.167** (H2 drop −9.654) |
| Stage1 LLM+manual validity | 99.82% | **100.000%** (878.418 / 878.418, 0 residual, 1 manual curation GSM6005198; escludi 749 ETL leak ridroppati per H2) |
| Stage2 records | 39.205 | **38.963** (post H2) → **39.247 predictions** (post H3 con cs25 splits) |
| Stage2 schema validity | 99.89% | **100.000%** (0 residual) |
| Mouse contamination upstream | 9.147 latent | **0** (72 GSE dropped + 72 candidati re-annotation GEO/ARCHS4) |

Strategie consolidate documentate per paper Methods/Results: `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`. ADR-0008 Addendum 2026-05-17 con H1+H3 config. NEWS 0.0.0.9017.

**Pipeline running config (invariata da α)**:

- **Container**: `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` (cu129 per driver 535 DGX compat).
- **Modello**: `mistralai/Mistral-Small-3.2-24B-Instruct-2506` self-hosted FP16 su DGX H100. Costo $0.
- **vLLM API**: `StructuredOutputsParams` (backend auto = xgrammar→outlines fallback). `GuidedDecodingParams` rimosso in vLLM v0.12.0.
- **Sampling** (ADR-0008): `temperature=0.0, repetition_penalty=1.1` stage1+stage2. Tier-based per-record max_tokens stage2 (S/M/L/XL → 4K/8K/16K/32K, ADR-0011).
- **Concurrency restored** (post PR #40946): `max_num_seqs=6, microbatch=50` stage2. Safe-mode (ADR-0009) declassato a fallback contingency.
- **Stage2 chunking**: `chunk_size=50` (cs50 default, ADR-0010 addendum + ADR-0013).
- **Schema validation**: structured_outputs = parser-grade by construction.

**Tag/branch attivi**:

- Tag α: `p4-vllm-upgrade-v0.20.2-complete` (commit 31c676a, addendum 89ca20e per cs50 flip).
- Tag β: **`p4-beta-archs4-human-complete`** (2026-05-17, closing Task β-15). Branch `p4-beta-archs4-human` ff-merged in `master` locale. Push remote rimane all'utente.
- **Test**: 544 PASS / 0 FAIL / 3 SKIP α-level (skip pre-esistenti OPENAI_API_KEY) + 41 PASS β resolver = 585 total tests.

**File risultato α + β attualmente sul disco**:

- α stage1: `analysis/p4-output/alpha-stage1-final.rds` (130.784 × 7, colonna `rescue_source`)
- α stage2 cs50: `analysis/p4-output/20260510T215308Z-p5-alpha-cs50-final-8db4c0/predictions.jsonl` (6649/6652 valid)
- α eval mini-gold cs50: `analysis/p4-output/phase3-h1-eval-20088.rds`
- β ETL output JSONL stage1-input: `analysis/input/archs4-human-stage1-input.jsonl` (gitignored, 262 MB)
- β ETL provenance: `analysis/p4-output/p4-beta-archs4-source.json` (committato force-add)
- β H5 source: `analysis/input/human_gene_v2.5.h5` (47.86 GB, gitignored; SHA256 `a1063426cb51986c77574d80d344918a075804c155e9b18c2e551b1077ad5d18`)
- β cache Entrez resolver: `tools::R_user_dir("simulomicsr","cache")/geo-series-resolver-cache.rds` (~25 MB, 32.905 GSE)
- β GATE #1 eval: `analysis/p4-output/20260512T142323Z-p4-beta-gate1-minigold-eval.rds` (force-add committato)
- β GATE #2 eval: `analysis/p4-output/20260512T150505Z-p4-beta-gate2-smoke1000-eval.rds` (force-add committato)
- β stage1 chunked input shuffled: `analysis/input/archs4-human-stage1-input-shuffled.jsonl` (gitignored, 262 MB; seed=42 globale, output di `shuf --random-source=<(yes 42)`)
- β stage1 chunked input filtered (`nchar <= 3500`): `analysis/input/archs4-human-stage1-input-shuffled-filtered.jsonl` (gitignored, 262 MB, 888.795 record)
- β stage1 outliers (`nchar > 3500`): `analysis/input/archs4-human-stage1-outliers.jsonl` (gitignored, 26 record, ~140 KB)
- β stage1 chunks (89 file): `analysis/input/chunks/chunk-00.jsonl` .. `chunk-88.jsonl` (gitignored, ~2.9 MB ciascuno)
- β stage1 master predictions: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl` (gitignored, **888.821 righe, 3.23 GB**, concat di 89 chunks + 1 outliers)
- β stage1 state machine: `analysis/p4-beta-chunked-state.txt` (gitignored, ultimo valore `89` = orchestrator idle)
- β stage1 orchestrator log: `analysis/p4-beta-chunked-orchestrator.log` (gitignored, ~70 KB, log cron tick ogni 3min)
- β stage2 input cs50: `analysis/input/archs4-human-stage2-input.jsonl` (gitignored, **39.205 record, 1.2 GB**, output di `analysis/p4-beta-stage2-build-input.R`)
- β stage2 fullrun output (collect dir): `analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0/` (gitignored, contiene `predictions.jsonl` 403 MB merged + 4 worker file + `run_summary.json` + `collect.rds`)
- β rescue stage1 fails classified: `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv` (committato, 1.571 fails × 5 colonne)
- β rescue H2 suspects (72 GSE flagged): `analysis/p4-output/p4-beta-rescue-h2-suspects.rds` (committato, 72 × 4 colonne)
- β rescue stage1 cleaned (post H2): `analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl` (gitignored, **879.167 righe, 2.97 GB**)
- β rescue stage2-input cleaned (post H2): `analysis/input/archs4-human-stage2-input-cleaned.jsonl` (gitignored, **38.963 record, 1.18 GB**)
- β rescue H1 input: `analysis/input/archs4-human-stage1-rescue.jsonl` (gitignored, 822 record, 296 KB)
- β rescue stage1 master rescued (post H1): `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (gitignored, **879.167 righe, 2.97 GB**, colonna `rescue_source = "h1_rep12_maxtok4096"` su 802)
- β rescue H3 input cs25: `analysis/input/archs4-human-stage2-rescue-cs25.jsonl` (gitignored, **85 chunks, 3.2 MB**)
- β rescue stage2 master rescued (post H3): `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (gitignored, 39.247 predictions + 0 errors, colonna `rescue_source = "h3_cs25_resplit"` su 85 cs25 chunks)

## Convenzioni operative dell'utente

### Tracciabilità — ogni decisione documentata

Mai prendere una decisione architetturale senza scriverla in modo
durevole prima di committare codice che la riflette.

- **ADR** (decisioni architetturali) → `docs/decisions/NNNN-<slug>.md`. Template in `docs/decisions/template.md`.
- **Spec** (brainstorming/design) → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
- **Plan** (implementazione) → `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md` + companion HUMANE per la review umana.
- **Commit atomici** con messaggi italiani descrittivi formato `P<N> Task <M>: <azione>`. Sono il "come tecnico" complementare all'ADR.

A fine milestone: raccogliere materiale da ADR/spec per generare /
aggiornare vignette o capitoli del futuro manuale.

### Git workflow

- **Branch per fase:** `p<N>-<slug>` (es. `p2-stage1`).
- **Merge fast-forward only** su master a fine fase. Tag `p<N>-<slug>-complete`.
- **MAI fare `git push`** — l'utente lo fa lui, sempre. Master locale può essere molti commit ahead.
- **MAI usare `--no-verify` o `--no-gpg-sign`** salvo richiesta esplicita.
- Pulire `renv/settings.json` (untracked, autogenerato) e ripristinare `analysis/_targets/.gitignore` + `analysis/_targets/meta/meta` (rigenerati da `tar_make`) prima di ogni commit.

### Convenzioni codice

- **Italiano nei commenti, docstring, messaggi commit, error messages.**
  ASCII per i caratteri accentati nei file Rd generati da roxygen
  (usare `§`/`—` o equivalenti `sec.`/`--` nel roxygen `#'`).
- Funzioni interne: `@keywords internal`. Solo i veri entry point sono `@export`.
- TDD bite-sized (test → fail → impl → pass → commit) per ogni step di plan.

### Note operative tecniche ricorrenti

- **renv 0.16.0 (lockfile) vs renv 1.1.4 (installato):** `Rscript -e ...` (no vanilla) può non trovare `devtools` perché renv intercetta il libpath. Workaround: `Rscript --vanilla -e ...` bypassa renv e usa system libs (devtools/targets installati globalmente). **Sul server DGX (R 4.6.0)** è il contrario: usare `Rscript -e ...` SENZA `--vanilla` (renv lib path corretta nel project).
- **`callr_function = NULL` per `tar_make`:** indispensabile quando i target chiamano OpenAI. callr crea sub-process R che NON ereditano la API key dal parent.
- **`format = "qs"` non disponibile su CRAN per R 4.5.2** → P2 usa `format = "rds"` per `tar_option_set`.
- **`sample_facts_validator` storizza un PATH allo schema, non il validator compilato** — i contesti V8 di `jsonvalidate` non sono serializzabili in RDS. `compile_schema()` viene chiamato inline nei target di partition.
- **MAI fare `git checkout -- analysis/_targets/meta/meta` MENTRE un `tar_make` è in corso**: il meta viene aggiornato in tempo reale, un checkout lo riporta a stato pre-run e il job successivo non riconosce più gli oggetti già calcolati. La convenzione "ripristina meta prima del commit" vale solo quando NESSUN tar_make sta girando in background.
- **Hang HTTP transitorio iniziale**: la prima call OpenAI dopo network glitch può essere catturata in I/O wait su socket (CPU 0%, processo S, TCP ESTABLISHED) senza timeout effettivo del `req_timeout(120s)` di httr2 (rare edge case). Workaround: kill + retry.
- **NON re-introdurre `temperature = 0` come default** in `R/llm-client-openai.R` (gpt-5.5 reasoning models ritornano 400 `unsupported_value` su qualunque temperature esplicita). Per output deterministici su modelli storici (gpt-4o, gpt-5.4-mini), passare `temperature = 0` esplicito dal chiamante.

### Note operative DGX (P4 cluster)

- **Path `/home/u0044/` NON `/mnt/home/u0044/`** — i compute node UniPD HPC non montano `/mnt/home/`. Sintomo del bug: ExitCode `0:53` con job FAILED in 2 secondi senza log files.
- **🔴 BLOCCANTE (2026-07-06/07): poddgx02 riavviato il 2026-07-06 17:22 → dopo il reboot la rete NFS (`bond1` LACP) è morta → `/home` non si monta → ogni job FAILED ExitCode `0:53`, ZERO log.** CAUSA RADICE PROVATA (debug sistematico via `srun`, confidenza ALTA): su poddgx02 `mount | grep nfs` = SOLO `master:/cm/shared`; `/home` è dir LOCALE VUOTA; `ping 147.162.154.180` (server NFS `ps01nfs`) e il gateway = **100% packet loss**; `/proc/net/bonding/bond1` = slave `eth3` **NO-CARRIER**, LACP "churned"; l'altra rete `eth2` (147.162.155.x) va → per questo `/cm/shared` c'è ma `/home` no. slurm non crea il file `--output` sul path `/home` mancante → `RaisedSignal:53` + zero log; con `--output=/tmp` (locale) il job COMPLETA. **⚠️ `autofs` era un FALSO INDIZIO** (la mia prima diagnosi): autofs non esiste nemmeno su poddgx02 e sul login — che monta `/home` — è `inactive` UGUALE; la home è montata STATICAMENTE via `fstab` (`ps01nfs:/home /home nfs`). **NON è codice/quota/config** (identica ai job di giugno 20710/24022 che girarono su poddgx02 PRIMA del reboot e scrissero i log). **FIX (è CLUSTER): admin UniPD riparano `bond1` su poddgx02** (eth3 NO-CARRIER/LACP churned → cablaggio/porte switch/config LACP VLAN 147.162.154.0/24, o ri-provisioning Bright `cmsh`), poi `mount /home`; **nel frattempo DRAIN il nodo** (`scontrol update nodename=poddgx02 state=drain reason=...`, ora è IDLE e accetta job che falliscono in silenzio). Nessun workaround lato-utente (job serve `/home` per input+output; `/cm/shared` read-only; `/tmp` node-local; poddgx01 escluso, poddgx03 assente). Diagnostica riusabile: `ssh login 'srun -p dgx12cluster -A dctv_dgx -w poddgxNN --gres=gpu:1 -t2 --chdir=/tmp /usr/bin/bash -c "ping -c1 147.162.154.180; cat /proc/net/bonding/bond1 | grep -iE churn\|carrier; mount|grep nfs"'`. Vedi memoria `dgx_storage_projects_not_home`.
- **STORAGE (separato dal blocco sopra, lezione valida): usare `/mnt/projects/dctv/dgx/u0044/` (NFS gruppo `dctv_dgx`, multi-PB, no cap) per i dati DGX pesanti, NON `/home/u0044/`** (quota per-utente 500G; il `df -h /home/u0044` "99%/9.9G" è la QUOTA, il fs fisico è 4.9 PB). `/mnt/projects/dctv/dgx/u0044/` è scrivibile da u0044 (la root `/mnt/projects/dctv` NO). Il 2026-07-06 `sc-gpu-benchmark` (170G, progetto separato) era stato spostato lì liberando la quota da 9.9G→380G — utile ma **NON** ha risolto il 0:53 (che è il blocco poddgx02 di sopra). **TODO**: migrare il workspace `simulomicsr-dgx` (HF_HOME 101G + runs) su `/projects` + cambiare `dgx_config()$remote_root`; PRIMA verificare che `/mnt/projects` sia montato sui compute node e bindarlo in `run_p4.sh`.
- **ssh non-interattivo NON sourca `/etc/profile.d/*.sh`** → `SLURM_CONF` mancante. Fix in `R/dgx-utils.R::.dgx_ssh()`: wrap del comando remoto con `bash -lc <cmd>` per forzare login shell.
- **Esecuzione singularity diretta, NO `srun`** — `srun singularity` non è supportato/affidabile su questo cluster. Usare `singularity exec --nv ...` direttamente.
- Vignette setup completa: `vignettes/p4-dgx-setup.Rmd`.

## Decisioni rinviate

- **ADR-0003 — rinome pacchetto.** "simulomicsr" non riflette la pipeline. Da affrontare prima del primo `install_github` pubblico.
- **ADR-0010 — vLLM upgrade evaluation.** Aprire SOLO dopo chiusura α + tag p4-dgx-complete; vLLM Issue #39734 non risolto upstream nemmeno in 0.19.x.
- **Vocabolari extra** (Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI). Necessari per Stadio 2 esteso (post-α).
- **Gold "design-aware"** scaled su 200-300 sample. Mini-gold v5 attuale è 100 sample.
- **Integrazione MetaHQ** come upstream per `normalize_tissue()` / `normalize_disease()` in Stadio 2.
- **Migrazione a `ellmer`** come client LLM (multi-provider, batch API più ergonomico). ADR separato post-α.
- **Cache cross-modello.** P1 attuale partiziona per `(provider, model, messages)`. Se servisse cache cross-modello, ADR dedicato.
- **Migrazione su server con più spazio.** ADR-0005 documenta trigger e procedura.
- **Findings sotto-soglia P3.5-A** (eventuale prompt iter post-α): `treatment_vs_untreated` 77.3% (n=141), `time_course` 59.3% (n=54), `case_control_disease` 49.1% (n=57, sotto casuale).
- ~~**β retry/uniqfail infrastructure pre full run**~~ **DONE 2026-05-17 con β rescue cascade**. Risolto via Phase 1 classification + H1 single-shot rep_pen=1.2/max_tokens=4096 + H3 cs50→cs25 invece di multi-round retry. Risultato: stage1 LLM-only 99.998% + stage2 100.000%. Cascade documentato in ADR-0008 addendum 2026-05-17 + `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`.
- **β gate2 throughput measurement bug** (cosmetico, gate-decision non impattata). Lo script `analysis/p4-beta-gate2-smoke.R` misura wall come `Sys.time()` pre/post `poll_until_done`, ma resume da job COMPLETED restituisce ~5 sec → "throughput 9996 rec/min" artefatto. Fix corretto: pull `sacct -j JID --format=Elapsed` e usare quello come wall reale. ETA stage1 full corretta calcolata a mano dal log poll iniziale: ~59h.

## Roadmap

### β tutti i task DONE (chiusura 2026-05-17)

1. ~~**β Task 10 stage1 full run**~~ **DONE** 2026-05-14/15. 888.795 record mainstream + 26 outliers = 888.821 totali. Wall 17h53min mainstream + 2m23s outliers. Master output: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl`.
2. ~~**β Task 10b stage1 outliers**~~ **DONE** 2026-05-15. Strategy A2 (`max_model_len=32768`) ha completato 26/26 record in 2m23s wall.
3. ~~**β Task 11 stage2-input**~~ **DONE** 2026-05-15. 39.205 record stage2 (vs ~17k stima gate2). Output `analysis/input/archs4-human-stage2-input.jsonl` (1.2 GB).
4. ~~**β Task 12 stage2 full run**~~ **DONE** 2026-05-15/17. Wall reale ~42.5h (vs stima iniziale 6-8h sbagliata per via di 37% tier XL e cold-start). Schema validity 99.89% (39.162/39.205). Job slurm 20710 ExitCode 0:0.
5. ~~**β Task 15 closing**~~ **DONE** 2026-05-17. NEWS 0.0.0.9016 esteso, tag `p4-beta-archs4-human-complete`, ff-merge → master locale. Push remote rimane all'utente.
6. ~~**β rescue cascade Task 1-15**~~ **DONE** 2026-05-17. Stage1 99.998% LLM-only + stage2 100.000%. NEWS 0.0.0.9017 esteso, tag `p4-beta-rescue-complete` (pending Task 15 close), ff-merge → master locale. Discovery paper-grade H2 (72 mouse-mislabeled GSE) + strategie rescue consolidate in `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`.

### Post-β + P5 Stadio 4 Layer A (immediato)

1. ~~**Stadio 3 raggruppamento cross-studio**~~ **DONE** pre-fullrun (Stage 3 build `2153addc` da cui parte il fullrun: 267.056 cluster, 707.595 assignment, 39.247 stage2 studies).
2. ~~**Stadio 4 Layer A** (`build_stage4_results`)~~ **DONE 2026-05-23** (run_id `96c43acb`, 622/622 cluster OK).
3. **Stadio 4 Layer B** + **Stadio 5 meta-analisi**: prossimo step su `cluster_pooled.parquet` (13.7M righe). Spec design da scrivere.
4. **Rename pacchetto** (ADR-0003) prima del primo `install_github` pubblico.
5. **Migrazione a `ellmer`** come ADR separato.
6. **γ ARCHS4 mouse** (post-human consolidato). NO γ in pianificazione attiva — gestito come variante futura.

## Dove vivere i dati che il repo NON contiene

| Asset                       | Location                                                          | Come ottenerlo / ricostruirlo                                            |
|-----------------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------|
| `OPENAI_API_KEY`            | `.Renviron.local` (gitignored)                                    | Utente ricrea manualmente. Riga `OPENAI_API_KEY="sk-..."`.               |
| renv libreria               | `~/Library/Caches/.../renv/` (macOS) o `~/.cache/R/renv/` (Linux) | `renv::restore()` da `renv.lock` committato.                             |
| HGNC dump completo          | `tools::R_user_dir("simulomicsr", which="cache")/hgnc_complete_set.tsv` | Download manuale da `https://www.genenames.org/download/archive/`.   |
| Cache LLM                   | `analysis/cache/` (gitignored)                                    | Auto-popolata dai run di `tar_make`. Trasferibile via `rsync`.           |
| Pipeline state              | `analysis/_targets/` (gitignored)                                 | Auto-popolato da `tar_make`. Trasferibile via `rsync`.                   |
| ARCHS4 H5 human v2.5        | `analysis/input/human_gene_v2.5.h5` (47.86GB, gitignored)         | `wget -c https://mssm-data.s3.amazonaws.com/human_gene_v2.5.h5` (~1.5h wall). SHA256 + provenance in `analysis/p4-output/p4-beta-archs4-source.json`. |
| File risultato α stage1/2   | `analysis/p4-output/*.rds` (gitignored)                           | Output dei job DGX, ricostruibili da `analysis/p4-bundles/*-job.rds`.    |
| β ETL output JSONL          | `analysis/input/archs4-human-stage1-input.jsonl` (262MB, gitignored) | Re-generato da `Rscript analysis/p4-beta-etl-build.R` (richiede H5 + cache Entrez). Stage 4 vectorizzato ~3 sec con cache full, ~5min Stage 2 H5 re-read. |
| β cache Entrez resolver     | `tools::R_user_dir("simulomicsr", which="cache")/geo-series-resolver-cache.rds` | Re-buildabile via `entrez_lookup_gse_metadata` (~5-6h wall per 32.9k GSE @ ~1.5 GSE/s con NCBI_API_KEY). |
| Bundle/runtime DGX          | `analysis/p4-bundles/` (gitignored)                               | Generati da `dgx_p4_build_bundle()`.                                     |

## Riferimenti chiave

### ADR (decisioni architetturali, in `docs/decisions/`)

- 0001 sistema-tracking · 0002 struttura-research-compendium · 0004 renv-riconciliato · 0005 server-migration-trigger
- **0006 stato-arte-vs-simulomicsr** — analisi competitor 2024-2026 + benchmark RummaGEO + decisione P3-B
- **0007 dgx-self-host-vllm** — bespoke minimale dentro simulomicsr + workflow Docker→DockerHub→Singularity
- **0008 vllm-sampling-defaults** — temperature=0.0, repetition_penalty=1.1 stage1+stage2
- **0009 stage2-safe-mode-vllm-deadlock** — `max_num_seqs=1, microbatch=1` stage2 deadlock-proof Issue #39734
- **0011 tier-based-max-tokens** — single-pass strategy per stage2 con per-record max_tokens proporzionato
- **0012 stage2-schema-multi-axis-limitation** — known limit `primary_role` mono-axis vs design factoriali (paper-grade note)

### Specs / plans (in `docs/superpowers/`)

- Spec classificatore: `specs/2026-04-29-classificatore-llm-design.md` (v5 approvata 2026-04-29).
- Plan P1-P4: `plans/<date>-p<N>-*.md` + companion HUMANE.
- Spec investigation Task 22: `specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md` (RESOLVED).

### Report Quarto

- `analysis/eval/p35-benchmark.html` (838 KB) — P3.5-B prototipo (15 GSE, 197 sample).
- `analysis/eval/p35a-benchmark.html` (980 KB) — P3.5-A scaled (100 GSE, 1507 sample, paper-ready: Wilson CI + McNemar + bootstrap + Holm).

### Documentazione storica

- **`docs/model-evaluation-history.md`** — valutazioni P3.5-C (5 modelli closed) + P3.5-D (21 modelli OpenRouter) + pattern strutturali + decisione mistral-small-3.2.

### Vignette + utenti

- `vignettes/p4-dgx-setup.Rmd` — one-time guide setup DGX.
- `README.md`, `NEWS.md` — entry point utente + storia versioni.
