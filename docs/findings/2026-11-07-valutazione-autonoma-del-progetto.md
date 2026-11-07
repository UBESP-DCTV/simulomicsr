---
type: Finding
title: "Valutazione autonoma del progetto: ricominciare, continuare, o tenere una parte?"
description: "Sessione notturna fuori protocollo, su richiesta del PI. Giudizio sui dati del repository e del deliverable, con revisione del piano e due avvocati ciechi. Non tocca codice, deliverable né finding precedenti."
status: draft
generated: {by: claude-fable-5-1, at: '2026-11-07T23:30:00+01:00'}
sources:
- {id: fatti, resource: "analysis/audit/2026-11-07-valutazione-autonoma/FATTI.md", title: "I fatti grezzi dati agli avvocati ciechi"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi"}
- {id: rif, resource: "analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", title: "I 193 confronti difettosi"}
- {id: stadio3, resource: "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159/clusters.rds", title: "Stadio 3 corrente (soffitto)"}
- {id: modelli, resource: "docs/model-evaluation-history.md", title: "21 modelli sul mini-gold, maggio 2026"}
- {id: r1, resource: "analysis/audit/2026-11-07-valutazione-autonoma/R1-stato-arte.md", title: "Ricerca web: stato dell'arte 2025-2026 (agente)"}
- {id: r2, resource: "analysis/audit/2026-11-07-valutazione-autonoma/R2-metanalisi-pubblicate.md", title: "Ricerca web: meta-analisi pubblicate sugli stessi GSE (agente)"}
---

# In una frase

**L'idea funziona e nessuno l'ha ancora pubblicata; quello che non funziona è un pezzo solo, e da sei mesi lo si
cura col medicinale sbagliato.** Non ricominciare da capo. Non continuare così. Tenere quasi tutto, sostituire
il modo in cui la pipeline decide se due bracci sono confrontabili.

# 1. Come ho giudicato (e dove posso sbagliare)

- Ho letto `CLAUDE.md`, la storia, l'handout, i finding di S3-S11 e ho **rimisurato** quello che potevo sul
  deliverable e sui file di audit (imbuto, difetti per origine, soffitto, controllo biologico, nomi).
- Ho scritto un piano con soglie di decisione **prima** di guardare i risultati; un agente l'ha criticato e ho
  adottato tre correzioni (verdetto per componente; distinguere «metadato assente» da «metadato non letto»;
  via i costi affondati). Due agenti **ciechi** hanno costruito il caso migliore per «rifare» e per «tenere»
  dagli stessi numeri. Due agenti hanno cercato sul web lo stato dell'arte e le meta-analisi pubblicate.
- **Il mio bias**: sono lo stesso assistente che ha costruito la sovrastruttura. Posso assolvermi («è colpa dei
  dati») o flagellarmi («è tutto da rifare»). Per questo ogni verdetto qui sotto dice **quale osservazione lo
  ribalterebbe**.
- Una correzione che ho dovuto fare a me stesso stanotte: avevo scritto che 50 difetti erano leggibili «solo nei
  metadati GEO che il modello non vede». Falso: lo script di S11 (`21-metadati-geo.R`) legge **gli stessi tre
  campi** (titolo, sorgente, caratteristiche) che lo Stadio 1 riceve. Il modello li ha avuti e non li ha
  scritti, oppure lo Stadio 2 li ha persi nell'etichetta. Questo cambia il verdetto: non è un problema di
  ingresso, è un problema di **chi giudica la confrontabilità e con che cosa in mano**.

# 2. I numeri che contano

| che cosa | numero | fonte |
|---|---|---|
| Imbuto | 508.037 campioni → 24.393 studi → 18.746 con ≥1 confronto (86.212 confronti) → 323 gruppi con ≥3 studi → **194 meta-analisi** (993 studi, 1.903 confronti) | deliverable, master S14 |
| Soffitto | **455 entità** con ≥3 studi distinti nello Stadio 3 (ignorando tipo di controllo); 194 con ≥5; 62 con ≥10. Deliverable = 43% del soffitto | misurato stanotte |
| Perdita 323 → 194 | 122 gruppi cadono perché un braccio ha una sola replica (88 a 2 studi, 27 a 1, 7 a 0): **è il dato**, non la pipeline | `non_processable.rds` |
| Confronti difettosi | **193 / 1.903 = 10,1%** (stima dal basso: il riferimento viene in parte dagli allarmi di una regola) | S11 |
| Origine dei 193 | **65%** bracci non appaiati (tempo zero 48, durata, materiale, linea, donatore, genotipo, sesso, tecnica) · **23%** seconda perturbazione persa («Hypoxia + TGF-β1» sotto TGF-β1) · **8%** entità sbagliata (chiave Stadio 3) · 4% indecidibili | misurato stanotte |
| Coda lunga | **85 categorie distinte** di difetto; 55 con un solo caso; le prime 5 coprono il 38% | misurato stanotte |
| Il rilevatore a regole | vede **81 / 193** (42%), con 40-184 falsi allarmi secondo la variante | S10b, S11 |
| Il lettore (agenti sulle etichette) | test-retest kappa **0,78**; umano 18/19, kappa 0,91 | S3, punto 2 |
| Biologia | **30/31** geni attesi col segno giusto e significativi; DHT contro enzalutamide 667/690 opposti (96,7%), Spearman −0,944 | rieseguito stanotte |
| Riproducibilità | Stadi 1+2 rifatti da zero: 211.484/211.484 record identici, 8.565/8.566 studi | S14 |
| Dominanza | 116/194 (60%) con uno studio oltre metà del peso; solo **40** passavano tutti i controlli, e la scelta è **decaduta** in S11 | S5, S11 |
| Nomi | **61/194** `canonical_name` sono ID ChEBI sbagliati o vuoti («D-cycloserine(1+)» = JQ1; «hydron»; «calcium atom»); l'etichetta di contrasto è quasi sempre giusta | misurato stanotte |
| Modello | Mistral Small 3.2 = 96% sul mini-gold, **primo fra 21 modelli**; i più recenti (Mistral Small 2603, Qwen3.6) peggio sul rispetto dello schema | `model-evaluation-history.md` |
| Convergenza | verdetti cambiati per giro: S9 7/194, S11 15/194 (6 nelle 40). Tre «finale» ritrattati a luglio | S9, S11, STORIA |

# 3. Dove nascono gli errori, e perché sei mesi non li hanno chiusi

**Il meccanismo, in parole semplici.** Lo Stadio 1 legge il testo di ogni campione e lo **comprime** in una
scheda fissa (una perturbazione, una dose, un tempo…). Lo Stadio 2 **non vede più il testo**: vede le schede, e
da quelle decide quali gruppi confrontare. Lo Stadio 3 vede solo una chiave («TGF-β1 ‖ su ‖ veicolo»). Tutto
ciò che la scheda non ha catturato — un secondo agente, un tempo zero scritto come «D0», un kit diverso, un
donatore diverso — è **perso per sempre** a valle, e nessuna regola lo recupera, perché la regola lavora su
ciò che resta.

**La prova sta nei 193.** L'88% nasce prima della chiave dello Stadio 3 (65% appaiamento, 23% seconda
perturbazione); la chiave spiega l'8%. Eppure la strada in corso (S12, S12b, S12c, S12d) lavora soprattutto
sulla chiave e su un rilevatore **a regole** che, al meglio, vede il 42% dei difetti noti. Con 85 categorie e
55 difetti unici, una regola per causa non converge: la coda è lunga per natura. Nel frattempo, quello che nel
progetto **ha trovato** i difetti — un lettore che guarda il testo grezzo dei due bracci, uno accanto
all'altro — è stato usato solo come **strumento di audit**, mai come **stadio della pipeline**.

**Che cosa è successo nei sei mesi, senza giri di parole.** Da maggio a luglio si è lavorato sui *nomi*
dichiarando tre volte «finale»: strato sbagliato, ritrattato. Da agosto a oggi si è **misurato** — e questo è
il lavoro buono: oggi si sa dov'è l'errore, con che frequenza, e il metro è ripetibile — ma la correzione
scelta (regole deterministiche a valle) è quella che il dato condanna. La sensazione di «lotta impari» è
corretta per *questa* strategia, non per il progetto.

**Due cose vere che non dipendono da nulla di tutto ciò:** il 60% di dominanza e il taglio 323 → 194 sono
proprietà di GEO (poche repliche, pochi studi per perturbazione). Nessun rifacimento le cambia. Si
dichiarano.

# 4. Verdetto per componente

| componente | verdetto | perché | lo ribalterebbe |
|---|---|---|---|
| Stadio 0, ETL ARCHS4 (bacino 508.037) | **tenere** | verificato, riproducibile, con i limiti dichiarati | — |
| Master S14 (Stadi 1-2, Mistral 3.2) | **tenere** | identici al 100% al rifacimento; 94-96% sul gold binario; primo fra 21 modelli | un benchmark sul compito vero (vedi §7) in cui un altro modello riduce i 170 difetti di appaiamento di oltre la metà |
| Schema Stadio 1 «una perturbazione per campione» | **difetto noto, non va rifatto subito** | 23% dei difetti; ma il rimedio non è rifare 33 h: è leggere il testo grezzo nel nuovo stadio (sotto) | se il nuovo stadio non recupera il secondo agente dal testo |
| Decisione di confrontabilità (oggi: schede compresse + regole; programma S10-S12) | **sostituire** | 88% dei difetti nasce qui; il rilevatore a regole vede il 42%; il lettore di testo ha kappa 0,78 | se un lettore Mistral sul testo dei due bracci, sui 1.903, prende meno del rilevatore a regole |
| Chiave d'entità Stadio 3 (ID ChEBI scritti dal modello) | **correggere, non riscrivere** | 8% dei difetti + 61 nomi sbagliati; la letteratura è univoca: il modello **non deve mai scrivere un ID**, sceglie fra candidati per indice (SPIRES 97/100 contro 3/100; Wren) — è già lo spirito di S12c | — |
| Stadio 4 (limma-voom + REM, corsie, dominanza, LOO) | **tenere** | 30/31 bersagli, antagonista opposto all'agonista a −0,944; da correggere solo varianza del controllo condiviso e ordine della cache (S13, già decise) | — |
| Gold, 194 verdetti, 193 difetti, test-retest | **tenere come banco di prova cieco** | sono l'unico insieme al mondo di confronti GEO letti due volte con kappa misurato | — |
| Strumenti di audit (65k righe) | **tenere, smettere di estenderli** | hanno fatto il loro lavoro: misurare. Il rilevatore a regole non va portato in produzione | — |
| Documentazione (STORIA, handout, finding) | **tenere e potare** | è il materiale dei Methods e dei limiti | — |

# 5. Le tre strade

**(a) Ricominciare da capo (nuovo modello, nuovo schema, tutto da zero).** Contro: il rifacimento già fatto
(S14) ha dato un'uscita identica; il modello è il migliore misurato; la letteratura (R1) dice che sul testo
GEO contano prompt e fine-tuning più della taglia, e nessun articolo confronta i modelli sul compito che qui
fallisce (appaiamento dei bracci). Si butterebbe ciò che funziona (ETL, Stadio 4, gold, verdetti) per
inseguire un guadagno che oggi è una **previsione**, non un numero. Costo: mesi. **No.**

**(b) Continuare l'handout così com'è (S12 → S17).** Contro: cura l'8% con la chiave e, con il rilevatore a
regole, al massimo il 42% del resto; ogni giro ha scoperto classi nuove; le stime di durata sono state
superate quasi sempre. Pro: le sessioni S13 (varianza, ruoli, doppi), S14 seconda parte, S15, S16, S17
restano necessarie **in ogni strada**. **No, non così.**

**(c) Tenere quasi tutto, sostituire il giudice di confrontabilità.** Un nuovo passo, chiamiamolo **Stadio 2b**,
fatto da Mistral (stesso modello, temperatura 0, `VLLM_BATCH_INVARIANT=1`: deterministico come S14 ha
dimostrato), che per **ogni confronto candidato** riceve il **testo grezzo** dei campioni dei due bracci
(titolo, sorgente, caratteristiche **più** i campi tecnici dell'H5 già disponibili: `extract_protocol_ch1`,
`instrument_model`, `library_selection`, `data_processing`) e compila una **lista di controllo strutturata**:
agenti presenti nel trattato / nel controllo; tempo di raccolta dei due bracci (zero sì/no); materiale, linea,
donatore, genotipo, sesso, tecnica: uguali / diversi / non detto. Una **regola deterministica** decide dalla
lista. Il modello dà i fatti, la regola dà il verdetto: la pipeline resta deterministica e verificabile, ma
la decisione legge finalmente il dato intero. Nello stesso passo la chiave d'entità smette di fidarsi dell'ID
del modello (S12c). **Sì.**

Costo di (c), solo in avanti: 1.903 confronti del deliverable = minuti su una H100; tutti gli 86.212 candidati
= ore. Disegno + prompt + prova sui 1.903 contro i 193 (ciechi) = 2 sessioni. Chiave (S12c) = 1-2 sessioni.
S13 + re-cluster + re-pool = 1 sessione di macchina (4 h). Rilettura cieca delle 194 = 1 sessione. Seconda
validazione esterna = 1. Figure e Methods = 2. **Circa 9 sessioni**, come l'handout, ma che aggrediscono
l'88% dei difetti invece dell'8%. Con le stime raddoppiate, come insegna la storia: 4-6 settimane.

**Che cosa ribalterebbe (c)**: la prova sui 1.903. Se Mistral col testo grezzo dei due bracci prende meno di
metà dei 193 difetti, o accusa più di qualche decina dei 1.710 confronti puliti, il modello non sa fare
questo giudizio e si torna a decidere fra regole e fine-tuning. **È la prima cosa da fare, prima di ogni
altra.**

**Un avviso onesto su (c).** Il PI ha chiesto «zero errori». Nessuna strada li dà: il tetto misurato in
letteratura per il raggruppamento caso/controllo è recall 0,84 (R1 §2), il rilevatore a regole è a 0,42. La
differenza è che con (c) l'errore residuo si **misura** con la rilettura cieca e si scrive nei Methods; con
(b) si continua a scoprire una classe alla volta. È anche un cambio di filosofia da dichiarare in un ADR: il
gate non è più «solo regole», è «il modello legge, la regola decide».

# 6. Il modello locale: cambiarlo o no

**Non ora, e non alla cieca.** Mistral Small 3.2 è il migliore misurato dal progetto (96%, 21 modelli); è
deprecato nell'API di Mistral dal 31/7/2026 ma i pesi restano, Apache 2.0. I candidati seri a novembre 2026
sono pochi e con licenza aperta: **Magistral Small 1.2** (stessa base 24B; miglior F1 zero-shot, 0,893, sul
raggruppamento caso/controllo GEO in Soul & Young), **Gemma 4 31B** (Apache 2.0; motore di una pipeline GEO
di 804k campioni), **Qwen3-30B-A3B** (vince dove è stato fatto fine-tuning), **gpt-oss-120b**,
**Mistral Small 4 119B-A6B**. Nessun benchmark pubblicato li confronta sul compito che qui fallisce. Il
progetto però **ha il benchmark**: i 1.903 confronti con 193 difetti letti due volte. Un confronto fra 2-3
modelli come giudice di confrontabilità costa **una notte** su `poddgx02` e risponde per sempre alla
domanda. Il fine-tuning sul proprio gold è la mossa che vince in letteratura (+0,07/+0,20 di precisione) ma è
un passo di ricerca, non necessario per l'articolo.

# 7. Stato dell'arte (ricerca web di stanotte, dettagli e URL in `analysis/audit/2026-11-07-valutazione-autonoma/R1-stato-arte.md`)

- **Nessuno** pubblica ancora il passo che fa simulomicsr: confronti appaiati da LLM **e** meta-analisi
  random-effects per gene fra studi. Il più vicino, Soul & Young (bioRxiv 14/8/2026), fa gruppi caso/controllo
  con LLM su GEO ma solo per perturbazioni geniche, una firma per esperimento, senza pooling; SNACKKSS (Baylor,
  3/2026) aggrega fra studi ma con classificatori BERT e z-score, senza effect size.
- **Il campo si muove in fretta**: GEOMeta (Bin Chen, 8/2026) estrae 27 campi incluse perturbazione, dose,
  durata e stato di controllo su ~600k campioni; Szczepaniak & Wren (8/2026) annotano 804k campioni con un
  modello locale. Nessuno dei due costruisce confronti. **La nicchia è aperta ma la finestra si stringe**: altri
  sei mesi di cerotti rischiano di farsi superare proprio sull'affermazione centrale.
- **Il tetto misurato altrove**: Treatment per campione F1 0,91 (recall 0,85); gruppi caso/controllo P 0,93 /
  R 0,84. Il nostro 10,1% di confronti difettosi non è fuori scala: è **l'unico misurato a livello di
  confronto con un metro a kappa noto**. Gli altri hanno gold da un solo lettore o set di sviluppo non
  indipendenti.
- **Entity linking**: la risposta al difetto «nome giusto, ID sbagliato» è nota e univoca: il modello sceglie
  fra candidati per indice, mai scrive l'ID (SPIRES: 97/100 contro 3/100; Wren; MetaHarmonizer, deterministico,
  copre ChEBI).

# 8. Il benchmark proposto dal PI: replichiamo meta-analisi pubblicate sugli stessi GSE?

Ricerca dell'agente R2 (Europe PMC con co-citazione dei nostri GSE nel testo pieno, 9 ricerche web; DOI
per ogni voce in `analysis/audit/2026-11-07-valutazione-autonoma/R2-metanalisi-pubblicate.md`). **Fattibile, ma piccolo e da usare come supplementare, non
come validazione principale.**

| entità | articolo utilizzabile | GSE in comune | liste complete | nota |
|---|---|---|---|---|
| NAFLD / NASH | Piras & DiStefano 2024, *Life Sci Alliance* (REM su 9 GEO) | GSE135251, GSE126848 | sì (685 e 1.870 DEG) | **il caso migliore**: stesso metodo (random-effects), stesso contrasto |
| IPF | He 2025, *Eur Respir J* | GSE92592, GSE73189, GSE99621 | sì (tab. S5-S6) | dati uniti (MINT), non REM; il nostro gruppo ha n_sig = 14 |
| Endometriosi | Golinska 2025, *Front Immunol* | GSE153739, GSE153740, GSE232713 | sì | contrasti da allineare (eutopico vs sano / lesione vs eutopico) |
| Crohn / UC, preeclampsia, SARS-CoV-2, HCC, schizofrenia | articoli con 2 GSE in comune | 2 | parziali (figure, Excel, 43-60 geni) | HCC: `GSE144269` è quello invertito da noi; SCZ: il nostro n_sig = 0 |
| Alzheimer, Parkinson, SM, psoriasi, LPS, TNF, IFN-γ, TGF-β1 | **nessuno** con ≥2 GSE nostri | 0-1 | — | la meta-analisi seria di AD usa Synapse, 0 GEO |

**Trappole che l'agente ha incontrato e che vanno scritte nel disegno prima di guardare i numeri:** hub gene
da grado di rete (IL6/IL1B/TNF escono sempre, qualunque sia la malattia); liste di 5-20 geni contro le nostre
migliaia (metrica giusta: direzione concorde + AUC del nostro z sul loro insieme, con insieme casuale di
controllo); contrasti diversi dai nostri (fibrosi F3-4 vs F0-1, lesionale vs non lesionale, sangue vs
tessuto); «mega-analisi» senza effect size per studio; tre ritrattazioni fra gli articoli incontrati; riviste a
basso controllo dominanti. Regola: fissare articolo e metrica **prima** di guardare.

**Alternativa più solida, già a portata di mano:** le firme di consenso. PROGENy (Schubert 2018) copre
TGF-β, TNF-α, ipossia, JAK-STAT, androgeni (quindi DHT/R1881 in su **e** enzalutamide in giù: controllo
positivo e negativo insieme); per l'ipossia Buffa 2010 / Ragnum 2015 / Tardon 2020, con la valutazione
indipendente di Di Giovannantonio 2025 (*Cell Genomics*) su 73 serie GEO in vitro, **tre delle quali sono
nostre**; per l'interferone Schoggins 2011 e Aybey 2025 (tipo I contro II: misura la specificità fra IFN-α,
IFN-β e IFN-γ, che sono tre gruppi distinti nel deliverable); per LPS Xue 2014 e Chen 2019 (REM su macrofagi).
Il controllo biologico di agosto (30/31) è già una versione in piccolo di questo; estenderlo a firme intere
con specificità incrociata fra stimoli costa un pomeriggio e **non ha il bias di selezione** degli articoli di
«integrated analysis».

**Scoperte collaterali di R2 che toccano il progetto** (da verificare in sessione): Stemmer 2024 esclude
`GSE93624` come duplicato di `GSE101794` (stessi pazienti RISK) — `GSE93624` sta nel nostro gruppo Crohn; la
scheda GEO di `GSE125583` dichiara 89 soggetti in comune con `GSE95587`, entrambi nel nostro gruppo Alzheimer
(stesso tema degli «studi doppi» di S5, non visibile dalle conte se i campioni sono diversi); `GSE135485`
(ruoli scambiati da noi, §8 di `CLAUDE.md`) è la coorte di validazione di Bae 2022.

**Giudizio sul benchmark:** vale la pena per NAFLD, IPF ed endometriosi come **supplementare** («il metodo
ritrova ciò che una meta-analisi manuale ha trovato sugli stessi dati»), con metrica e articolo fissati
prima. Non può essere la validazione principale: copre 3 entità su 194, tutte malattie, e gli articoli
scelgono le entità più studiate (lo stesso bias visto con LINCS in S7). Va dopo S13/S14, come già scritto
nell'handout (S7b).

# 9. Le prime tre sessioni, se si sceglie (c)

1. **La prova che decide.** Stadio 2b su carta (ADR + lista di controllo + regola), prompt, esecuzione con
   Mistral 3.2 sui 1.903 confronti del deliverable **senza guardare i verdetti**; poi confronto cieco con i
   193 e con i 1.710 puliti. Previsioni depositate prima: «prende ≥ 130/193, accusa ≤ 40/1.710». Se passa, (c)
   è la strada; se no, si sa in una notte.
2. **Lo stesso con 1-2 modelli alternativi** (Magistral Small 1.2, Gemma 4 31B), stesso prompt, stessa
   notte, stesso metro. Chiude per sempre la domanda «cambiamo modello?».
3. **La chiave senza ID del modello (S12c)** come già deciso, misurata con gli script di S9 (35 min), poi
   S13 e il ri-calcolo. Da qui in poi l'handout vale com'è (S15 → S17), con le 194 rilette **alla cieca**.

# 10. Una nota al PI

Il progetto **non è fallito**. Ha un deliverable in cui la biologia esce giusta 30 volte su 31, un errore
misurato e ripetibile, e un'affermazione che nessun altro ha ancora pubblicato. Ha perso sei mesi su due
strati sbagliati — prima i nomi, poi le regole — e il segnale c'era: tre «finale» ritrattati, 85 categorie
di difetto, un rilevatore fermo al 42%. La tristezza è comprensibile; l'impressione di non vedere la fine è
giustificata **per la strada attuale**, non per il progetto. La fine si vede se il prossimo passo è uno
solo, piccolo e decisivo: far leggere al modello i due bracci, sui 1.903, e contare.

---

# Appendice — I fatti grezzi dati agli avvocati ciechi (FATTI.md, con la correzione del §1)

Progetto: pipeline R. ARCHS4 (RNA-seq umano bulk, 508.037 campioni GEO) → Stadio 1: LLM locale
(Mistral-Small-3.2-24B, vLLM, temperatura 0, batch-invariant) legge i metadati di OGNI campione →
Stadio 2: LLM interpreta il disegno di ogni studio (gruppi di repliche, ruolo trattato/controllo,
confronti) → Stadio 3: regole deterministiche raggruppano i confronti di studi diversi con la stessa
chiave «entità ‖ verso ‖ tipo di controllo» (entità risolta via ChEBI/HGNC/MeSH/ChEMBL) → Stadio 4:
limma-voom per studio + meta-analisi random-effects per gene (metafor), gate ≥3 studi, ≥2 repliche
per braccio. Obiettivo dell'articolo assunto: «catena end-to-end LLM→meta-analisi con resa ed errore
misurati» (non «atlante delle perturbazioni»).

## Imbuto (deliverable A3 v16, 2026-08-19)
- 508.037 campioni → 24.393 studi → 18.746 studi con ≥1 confronto (86.212 confronti) → 323 gruppi
  candidati con ≥3 studi → **194 meta-analisi** (993 studi, 1.903 confronti). 122 candidati cadono
  perché dopo il gate «≥2 repliche per braccio» restano <3 studi (88 a k_eff=2, 27 a 1, 7 a 0).
- Soffitto misurato stanotte (Stadio 3 corrente, unione di tutti i cluster di una entità, ignorando
  tipo di controllo e verso): **455 entità con ≥3 studi distinti**, 194 con ≥5, 62 con ≥10.
  Deliverable/soffitto = 194/455 = 43%. Perdita 455→323 = frammentazione per tipo di controllo e
  chiave; 323→194 = bracci con una sola replica (dato, non pipeline).
- Tipi: 107 small_molecule, 42 disease_vs_normal, 15 citochine, 11 ambientali, 9 patogeni, 9 genetici,
  1 differenziamento (colonna `kind` nota per sbagliare il tipo).

## Qualità misurata
- Lettura di tutte le 194 (agenti Claude, 2026-08-20): 116 corrette / 62 difettose / 16 incerte.
  Test-retest in ambiente congelato (S3): kappa 0,78 [0,70; 0,86]; lettura umana del PI su 19:
  accordo 18/19, kappa 0,91.
- Confronti difettosi nel riferimento dopo S11: **193/1.903 (10,1%)**, in 82 gruppi e 115 studi.
  Il riferimento NON è un campione neutro: 64 vengono da allarmi di una regola che ne vede 81/193.
- Attribuzione dei 193 per origine (regex sulle categorie, stanotte):
  - 125 (65%) bracci non appaiati: tempo zero (48), tempo/durata, materiale, linea, donatore,
    genotipo, sesso, differenza tecnica, controllo condiviso → lettura del disegno (Stadi 1/2) o
    ingresso. 50 di questi 125 sono leggibili SOLO nei metadati GEO (non nelle etichette).
  - 45 (23%) seconda perturbazione persa (es. «Hypoxia + TGF-β1» poolato sotto TGF-β1): lo Stadio 1
    scrive quasi sempre UNA perturbazione per campione (15.024/15.559).
  - 15 (8%) entità/contrasto sbagliato (chiave Stadio 3: metabolita per il padre, omonimia, IL-1β
    sotto IL1A).
  - 8 (4%) indecidibili dall'etichetta.
- Ingresso del modello: Stadio 1 vede `title`, `source_name_ch1`, `characteristics_ch1` del
  campione (`R/etl-archs4-utils.R:8`). Stadio 2 vede i fatti dello Stadio 1 per condizione (non il
  testo grezzo). **I «metadati GEO» letti in S11 sono questi stessi tre campi** (script
  `21-metadati-geo.R`): quindi i 50 difetti «leggibili solo nei metadati» erano nel testo che il
  modello ha ricevuto, e non sono arrivati al confronto (Stadio 1 non li ha scritti, o Stadio 2 li ha
  persi nell'etichetta). L'H5 ha anche `extract_protocol_ch1`, `data_processing`, `instrument_model`,
  `library_selection` (non usati dal modello); non ha `overall_design` né `summary` della serie.
- Inversioni di braccio: 1 confermata (`GSE144269` in HCC, 105 geni significativi di cui 6.590 col
  segno raddrizzato) + 4 studi con un braccio sbagliato, su 194, con uno strumento che vede il 52%.
- Nomi: 61/194 `canonical_name` sono ID ChEBI sbagliati o NA (es. «D-cycloserine(1+)» = JQ1,
  «calcium atom», «hydron», «4-maleylacetoacetate» = DHT). L'etichetta di contrasto è giusta in quasi
  tutti; la colonna del nome no. Il modello scrive il nome giusto con l'ID sbagliato e il codice si
  fida dell'ID (S9). Da maggio a luglio 2026 il lavoro è stato soprattutto sui nomi (v5→v10).
- Dominanza: 116/194 (60%) dominate da un solo studio (>50% del peso); 67 (35%) valgono meno di
  2 studi efficaci. Solo **40/194** passano tutti i controlli (nessun difetto, nessuna dominanza);
  nelle 40 i geni significativi veri sono 3,0× quelli con studi non collegati, nelle 96 dominate 1,2×.
  La scelta delle 40 è DECADUTA in S11 (6 delle 40 hanno cambiato verdetto).
- Controllo biologico (bersagli fissati ad agosto dalla letteratura, rieseguito stanotte sul
  deliverable): **30/31 geni col segno atteso e significativi** (DHT, enzalutamide, TGF-β1,
  SARS-CoV-2, IFN-γ, LPS, IL-17A); DHT contro enzalutamide: 667/690 geni di segno opposto (96,7%),
  Spearman −0,944.
- Validazione esterna (S7, senza nullo per estrazioni casuali): 14/19 contro LINCS, 11/32 contro
  Tahoe-100M; non separa le 40 dalle 132. Tumori: 6/6 trovano il proprio progetto TCGA su 16.
- Gold Stadio 1: 756 campioni / 72 studi, accuratezza binaria trattato/controllo 94,1–96,0%;
  mini-gold 100 campioni; 21 modelli confrontati su 100 campioni in P3.5 (2026-04/05).
- Riproducibilità: Stadio 1+2 rifatti da zero (S14, 33 h su 8 H100): 211.484/211.484 record e
  8.565/8.566 studi identici al riferimento; 24.393 studi.

## Convergenza
- Verdetti sulle 194 cambiati per giro di misura: S9 (greche) 7/194; S11 (tempo zero + tecnica) 15/194,
  di cui 6 nelle 40. Classi di difetto nuove scoperte in S9, S10, S11: sinonimi/ID, aggancio tabelle
  dei nomi, tempo zero, differenze tecniche, studi doppi (13 gruppi).
- Tre dichiarazioni di «deliverable finale / publication-grade» ritrattate (lug 2026): riguardavano
  il livello dei nomi, poi sostituito dal record di gruppo «dal contrasto» (ADR-0025).
- Handout 2026-08-21: 13 voci → 17 (11 chiuse). Sessioni in programma prima dell'articolo: S12, S12b,
  S12c, S12d (regole e chiave), S13 (ri-calcolo), S14 (raggruppamento sui master nuovi), S15
  (rilettura), S16 (figure), S17 (Methods). Le stime di durata dell'handout (3-6 h) sono state
  superate in quasi tutte le sessioni.

## Costi noti (solo in avanti)
- Stadio 1+2 da zero: 33 h su 8 H100 (misurato). Stadio 3: 2,5 h (32 worker). Stadio 4: 75 min a pezzi.
- Riprodurre tutte le chiavi dello Stadio 3 per misurare una correzione: 35 min.
- Lettura di 194 meta-analisi con agenti: una sessione (60 agenti); lettura umana: 19 schede = 1 sessione.
- Esistono: ETL verificato, master S14 riproducibili, gold, 194 verdetti, test-retest, strumenti di audit
  (65k righe di script), 25k righe di pacchetto R con 28k di test (4.317 asserzioni, 0 fallimenti).
