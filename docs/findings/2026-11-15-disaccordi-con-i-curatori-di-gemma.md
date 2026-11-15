---
type: Finding
title: "Quando il lettore dello studio e i curatori di Gemma (UBC) formano gruppi diversi: censimento delle 545 voci e lettura doppia di 120"
description: "Delle 545 voci chiuse con gruppi diversi da quelli dei curatori, il 53% sono scelte diverse, il 28% porta un errore di lettura del lettore (circa 153 voci su 2.052, 7,4%) e il 23% un errore dei curatori. Negli studi dove i due lettori locali concordano l'errore di lettura stimato è 1,8% delle voci, negli altri 18,3%."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-15T22:30:00+01:00}
sources:
- {id: carta, resource: "analysis/audit/2026-11-15-disaccordi-con-gemma/00-previsioni.md", title: "Carta: cancelli KD1-KD5, previsioni PD1-PD11, regola della causa"}
- {id: censimento, resource: "analysis/audit/2026-11-15-disaccordi-con-gemma/10-out.txt", title: "Il censimento su tutte le 2.052 voci"}
- {id: schede, resource: "analysis/audit/2026-11-15-disaccordi-con-gemma/20-out.txt", title: "Il campione di 120 voci, le 4 esche, le 124 schede"}
- {id: istruzioni, resource: "analysis/audit/2026-11-15-disaccordi-con-gemma/21-istruzioni.md", title: "Le istruzioni dei lettori"}
- {id: confronta, resource: "analysis/audit/2026-11-15-disaccordi-con-gemma/30-confronta-out.txt", title: "Il confronto fra le due letture prima delle decisioni"}
- {id: decisioni, resource: "analysis/audit/2026-11-15-disaccordi-con-gemma/31-decisioni.csv", title: "Le 9 decisioni sulle schede con cause diverse, con il motivo"}
- {id: misura, resource: "analysis/audit/2026-11-15-disaccordi-con-gemma/30-out.txt", title: "La misura delle due letture: KD3, KD5 (iii), PD7-PD11, la quantità finale"}
- {id: accanto, resource: "analysis/audit/2026-11-15-disaccordi-con-gemma/32-out.txt", title: "Conto accanto, dichiarato dopo i numeri: la causa negli studi tenuti e non tenuti dall'accordo dei due lettori"}
- {id: lettori, resource: "docs/findings/2026-11-15-lettori-su-gemma-parte-aperta.md", title: "I lettori dello studio sulla parte aperta degli studi di Gemma"}
---

# In breve

## In breve: quando il modello e i curatori di Gemma formano gruppi diversi, chi sbaglia?

**A cosa serviva.** Il modello locale forma gruppi diversi da quelli dei curatori di Gemma in 545 voci su 2.052, e in
altre 130 non chiude il disegno. Senza una lettura non sappiamo se quelle 545 voci sono errori del modello o scelte
diverse dei curatori. Un programma ha classificato tutte le 545 voci, poi due gruppi di agenti hanno letto 120 voci
senza sapere chi aveva scritto i due disegni.

**Cosa abbiamo trovato.**

1. **Un controllo scritto prima è fallito alla lettera, per un errore mio nella carta.** Avevo scritto che in uno studio
   di prova (`GSE46665`) il programma doveva trovare «livelli più fini». Il programma trova «un fattore in più», ed è
   giusto, perché il modello scrive le sigle dei pazienti come un fattore a parte. Il programma vede lo studio, quindi
   era sbagliata l'attesa e non lo strumento. Il dubbio è spiegato e i numeri non cambiano.
2. **In metà dei disaccordi nessuno sbaglia.** Nel 53% delle 545 voci i due disegni sono due scelte difendibili. Il
   modello ha un errore di lettura nel 28% delle voci e i curatori hanno un errore nel 23%. Nel 5% sbagliano tutti e due.
3. **Sul totale, il modello ha un errore di lettura in circa 7 voci su 100.** Sono circa 153 voci su 2.052, e a queste
   si aggiungono le 130 voci dove il modello non chiude il disegno (6%).
4. **Il modello sbaglia soprattutto quando forma gruppi più grossi dei curatori.** Dove ha gruppi più grossi, la lettura
   trova un suo errore in 19 voci su 40. Dove ha gruppi più fini lo trova in 7 voci su 50. Lì 31 voci sono scelte diverse
   e in 12 voci l'errore è solo dei curatori, non del modello. L'errore più frequente del modello è un campione nel livello sbagliato.
5. **L'accordo fra i due modelli locali separa gli errori dalle scelte.** Negli studi dove i due modelli concordano, il
   modello ha un errore di lettura in circa 24 voci su 1.347 (2%). Negli altri studi ne ha circa 129 su 705 (18%), più le
   130 non chiuse. Ho fatto questo conto dopo aver visto i numeri, e poggia su 120 schede.

**Cosa devi decidere.**

1. **Porto i due modelli locali su tutto ARCHS4, con la regola dell'accordo? Raccomando sì.** La regola tiene gli studi
   dove i due modelli danno gli stessi gruppi e gli stessi confronti: circa due studi su tre. Negli studi tenuti restano
   errori di lettura in circa 2 voci su 100: la regola non li porta a zero. Il costo è solo tempo di calcolo, e le
   alternative sono due:
   - **Prima apriamo la parte chiusa di Gemma (991 studi) per confermare il 2%.** Il numero diventa una misura con le
     previsioni scritte prima. Però usiamo adesso gli ultimi studi curati mai visti, prima di avere provato gli altri
     modelli locali come secondo lettore.
   - **Ci fermiamo qui.** Resta la misura contro i curatori, senza i disegni di tutto ARCHS4.

**Comunque.** La parte chiusa di Gemma (991 studi) resta chiusa finché non decidi di aprirla. La lettura è un controllo
interno fatto da agenti Claude: non entra nella pipeline e non è una validazione da pubblicare. Le prove con i Claude via
API sono costate 42,21 dollari su 99, e ho tolto la chiave dal disco: puoi cancellarla.

Appena decidi questo punto, la sessione è chiusa.

**Sui tempi di calcolo.** La stima è mia, dai tempi misurati su 2.016 studi sul nodo DGX che usiamo. Il primo modello ha
impiegato 51 minuti e il secondo 113 minuti. Su 24.393 studi sono circa 10 ore per il primo e circa 23 ore per il secondo.
Prima va congelato il testo GEO degli studi che non abbiamo ancora scaricato.

---

# 1. Oggetto e metodo

Carta depositata prima di ogni calcolo (commit `a420deb`)[^carta]. Oggetto: le 2.052 voci (studio GEO × disegno di Gemma)
della misura di Mistral-Small 3.2, forma `B0`, corsa `M-rp11`, sulla parte aperta degli studi di Gemma[^lettori]: 1.377
identiche, 545 chiuse con gruppi diversi (307 più fini, 156 più grosse, 82 incrociate), 130 non chiuse. La parte chiusa
(991 studi), gli 82 studi di giudizio di Atlas e i 47 di sviluppo non entrano (cancello KD4).

**Parte 1, il censimento** (`10-censimento.R`, tutte le voci, nessun campione): riforma i gruppi dalle due tabelle dei
fattori, dà a ogni voce chiusa con gruppi diversi una classe (`fattore_in_piu`, `fattore_in_meno`,
`fattori_in_piu_e_in_meno`, `livelli_piu_fini`, `livelli_piu_grossi`, `altro`), il tipo e la colonna di ogni fattore in
più, la presenza nella vista di ogni fattore perso, e la classe dei gruppi degli altri lettori (Gemma-4-31B `GE-rp0`,
Haiku corsa 1 e 2, Sonnet, Opus) sulle stesse voci.

**Parte 2, la lettura** (audit interno, **a campione dichiarato**): 120 voci estratte con seme 20261115 dalle 545 (50 più
fini, 40 più grosse, 30 incrociate; 120 studi GEO distinti) più 4 esche dai 47 studi di sviluppo. Ogni scheda porta il
testo dello studio, la tabella dei campioni e i due disegni come «A» e «B», con il lato estratto a caso (62 e 62) e
senza dire chi ha scritto quale[^schede]. Due letture indipendenti (8 agenti Claude per lettura, 15-16 schede ciascuno,
stesse istruzioni[^istruzioni]) danno a ogni disegno `errore` (a, b, c, d), `non_verificabile` o `sostenuto`. La causa di
ogni voce esce dalla chiave dopo i giudizi (`30-misura-letture.R`, commit `83cd867`, scritto prima di vedere un giudizio).
Dove le due letture danno cause diverse ho deciso io sulla scheda, senza aprire la chiave[^decisioni]. Quote pesate per
classe (pesi 307/50, 156/40, 82/30), ricampionamento delle voci dentro le classi, B = 10.000, seme 20261115.

# 2. I cancelli

| cancello | esito | nota |
|---|---|---|
| KD1 impronte delle uscite e dell'ingresso | passa | 7 file su 7 |
| KD2 il censimento riforma la classe dei gruppi della misura | passa | 2.052 voci riga per riga |
| KD3 copertura | passa | 545/545 con una classe, 130/130 con un motivo; 124 schede lette due volte, tutte fino alla fine, nessuna tagliata |
| KD4 nessuno studio chiuso, di giudizio o di sviluppo | passa | 2.007 studi GEO, tutti aperti |
| KD5 (i) studio finto | passa | le sei classi attese e la voce identica |
| **KD5 (ii) alla lettera** | **fallisce** | la carta attendeva `GSE46665` = `livelli_piu_fini`; il censimento dà `fattore_in_piu` |
| KD5 (ii) corretto, dichiarato dopo il fallimento | passa | `GSE60340` = `fattore_in_meno` con una colonna nella vista; `GSE46665` = `fattore_in_piu`, il fattore in più è `disease` da `source_name_ch1` |
| KD5 (iii) le due letture danno `errore` al lettore nelle esche `GSE46665` e `GSE60340` | passa | S032 e S083 |

**Il cancello fallito.** L'errore è nella carta: in `GSE46665` il lettore scrive le sigle dei pazienti come livelli di un
fattore `disease` separato dal fattore vero, quindi la voce ha un fattore in più, non livelli più fini dello stesso
fattore. Lo strumento vede lo studio e lo classifica in modo corretto. La carta non è stata cambiata. La classe del
censimento non entra nelle quote della lettura: il campione è stratificato sulla classe dei gruppi, che il cancello KD2
verifica riga per riga. Il dubbio è chiuso come **spiegato**.

# 3. Il censimento (tutte le 545 voci)[^censimento]

| classe dei gruppi | voci | classi del censimento |
|---|---|---|
| più fini | 307 | `fattore_in_piu` 142, `livelli_piu_fini` 119, `altro` 46 |
| più grosse | 156 | `fattore_in_meno` 82, `livelli_piu_grossi` 59, `altro` 15 |
| incrociate | 82 | `fattori_in_piu_e_in_meno` 41, `livelli_piu_fini` 18, `livelli_piu_grossi` 12, `altro` 11 |

- **Fattori in più** (484 su tutte le voci): perturbazione 208, contesto 83, stato 75, tempo 68, tecnico 50. Colonne:
  `treatment` 89, `title` 73, `source_name_ch1` 33, `genotype` 32, `cell line` 22, `description` 11. Nelle 142 voci
  `fattore_in_piu`: contesto 47, tecnico 37, tempo 29, perturbazione 28, stato 20.
- **Fattori di Gemma persi** (275): 178 hanno una colonna nella vista, 97 no. Con colonna / senza: biological sex 55/3,
  genotype 25/35, treatment 24/29, cell line 24/3, disease 15/8, cell type 13/5.
- **Gli altri lettori** sulle 545 voci: tutti e tre (Gemma-4-31B, Haiku corsa 1, Sonnet) hanno i gruppi di Mistral in 198
  (36,3%); nessuno ha i gruppi di Gemma in 346 (63,5%). Gruppi di Gemma / di Mistral: `GE-rp0` 114 / 304, Haiku 1
  141 / 268, Haiku 2 135 / 279, Sonnet 140 / 278, Opus 20 / 41 su 74.
- **Errori fra i confronti non elencati** per classe della voce: identica 96 (su 412 giudicati), più fine 27 (952), più
  grossa 251 (261), incrociata 170 (270).

| previsione | atteso (intervallo di rilevanza) | misurato (IC95) | verdetto |
|---|---|---|---|
| PD1 almeno un altro lettore ha i gruppi di Gemma | 35% (20-50) | 199/545 = 36,5% (32,3-40,7) | confermata |
| PD2 almeno due altri lettori hanno i gruppi di Mistral | 40% (25-55) | 286/545 = 52,5% (48,2-56,7) | indeterminata |
| PD3 voci nelle classi a fattori interi | 65% (50-80) | 265/545 = 48,6% (44,2-52,8) | indeterminata |
| PD4 `fattore_in_piu`: solo contesto o tempo | 60% (40-80) | 63/142 = 44,4% (35,7-52,5) | indeterminata |
| PD5 il fattore perso ha una colonna nella vista | 50% (30-70) | 79/123 = 64,2% (55,7-72,8) | indeterminata |
| PD6 errori fra i non elencati in voci con gruppi diversi | 90% (≥ 75) | 448/544 = 82,4% (75,2-88,3) | confermata, per 0,2 punti |

Nessuna previsione è smentita. PD3 dice che il disaccordo sta per metà nei fattori e per metà nei livelli (attendevo due
terzi nei fattori). PD2 e PD5 superano l'atteso: il disaccordo con i curatori è in buona parte comune a tutti i lettori, e
il fattore perso sta spesso in una colonna che il lettore vede (il sesso in 55 casi).

# 4. La lettura (120 voci, due letture)[^misura]

Le due letture danno la stessa causa in 111 voci del campione su 120 e in 4 esche su 4 (115 schede su 124)[^confronta];
kappa sulla causa **+0,887** (IC95 +0,810, +0,951). Giudizi uguali disegno per disegno: A 122/124, B 117/124.

**Cause finali, campione (non pesato) per classe dei gruppi:**

| causa | più fini (50) | più grosse (40) | incrociate (30) | totale |
|---|---|---|---|---|
| `scelte_diverse` | 31 | 20 | 8 | 59 |
| `errore_del_lettore` | 4 | 18 | 11 | 33 |
| `errore_del_curatore` | 12 | 1 | 8 | 21 |
| `errore_di_tutti_e_due` | 3 | 1 | 2 | 6 |
| `fuori_vista` | 0 | 0 | 1 | 1 |

Per classe del censimento l'errore del lettore (solo o con i curatori) pesa di più in `livelli_piu_grossi` (13 su 21) e
in `fattori_in_piu_e_in_meno` (6 su 18); in `fattore_in_piu` 4 su 22, in `fattore_in_meno` 6 su 18.

**Quote pesate sulle 545 voci:**

| previsione | atteso (intervallo di rilevanza) | misurato (IC95) | verdetto |
|---|---|---|---|
| PD7 `errore_del_lettore` + `errore_di_tutti_e_due` | 35% (20-50) | 28,0% (20,8-35,6) | confermata |
| PD8 `scelte_diverse` | 40% (25-55) | 53,2% (44,3-62,4) | indeterminata |
| PD9 `errore_del_curatore` + `fuori_vista` | 15% (5-30) | 18,7% (11,8-26,1) | confermata |
| PD10 kappa fra le due letture | 0,70 (≥ 0,60) | +0,887 (+0,810, +0,951) | confermata |
| PD11 un altro lettore identico a Gemma, errore del lettore meno scelte | +30 punti (> +10) | +36,8 (+16,5, +56,5) | confermata |

Le singole cause: `errore_del_lettore` 22,9% (16,5-29,5), `errore_di_tutti_e_due` 5,1% (1,2-9,6), `scelte_diverse` 53,2%,
`errore_del_curatore` 18,2% (11,2-25,6), `fuori_vista` 0,5% (0,0-1,5). Il disegno dei curatori ha un errore (solo o con
il lettore) nel 23,3% (15,7-31,4). PD7 con la sola lettura 1: 28,3%; con la sola lettura 2: 28,0%.

**Tipo dell'errore** (lettura 1 / lettura 2). Disegno del lettore: (a) variabile che non è dell'esperimento 5 / 6, (b)
campione in un livello che la scheda smentisce 27 / 25, (c) variabile dichiarata e mancante 2 / 1, (d) livelli dichiarati
distinti e uniti 6 / 7. Disegno di Gemma: (a) 0 / 1, (b) 12 / 14, (c) 8 / 8, (d) 9 / 6. Giudizio finale: lettore `errore`
39, `sostenuto` 81; Gemma `errore` 27, `non_verificabile` 1, `sostenuto` 92.

**PD11, non pesato.** Almeno un altro lettore ha i gruppi di Gemma in 23 voci su 33 con `errore_del_lettore`, in 20 su 59
con `scelte_diverse`, in 2 su 21 con `errore_del_curatore`, in 0 su 6 con `errore_di_tutti_e_due`.

**Le esche.** `GSE46665` e `GSE60340`: `errore_del_lettore` in tutte e due le letture, come atteso. `GSE51261`:
`scelte_diverse`, come atteso. `GSE71289`: la carta attendeva una scelta (Gemma unisce i livelli); tutte e due le letture
danno `errore` (d) al disegno di Gemma, quindi `errore_del_curatore`.

**La quantità finale della carta.** Voci con un errore di lettura del lettore = 545 × PD7 / 2.052 = **7,4% (IC95
5,5-9,4), circa 153 voci (114-194)**; accanto, le 130 voci non chiuse (6,3%). Nessuna soglia: la carta non ne ha.

# 5. Le 9 decisioni mie[^decisioni]

Schede con cause diverse nelle due letture: S008, S051, S054, S059, S060, S070, S079, S087, S105. Le ho lette e decise
senza la chiave, con le regole delle istruzioni («per (c) e (d) serve una frase del testo»; «nel dubbio fra `errore` e
`sostenuto`, scrivi `sostenuto`»). Cause finali: `scelte_diverse` 6, `errore_del_lettore` 2 (S008, S054),
`errore_del_curatore` 1 (S051). In 6 schede il dubbio era un'unione di controlli o una variabile di contesto senza una
frase del testo che dichiara il confronto (S059 senza siRNA con siRNA di controllo; S060 il tempo; S070 una sigla non
definita; S079 controlli di corteccia e di ippocampo; S087 veicoli e non trattati; S105 il tipo di cellula). Il motivo di
ogni decisione sta nel file.

# 6. Conto accanto, dichiarato dopo i numeri: gli studi tenuti dall'accordo dei due lettori[^accanto]

Non sta nella carta. L'ho fatto dopo aver visto PD11, per portare la lettura sulla regola dell'accordo fra Mistral `B0` e
Gemma-4-31B `GE-rp0` (studi tenuti 1.337 su 2.008, voci 1.347; non tenuti 705 voci, di cui 130 non chiuse). Stima di
dominio sul campione stratificato, stesso ricampionamento.

| | studi tenuti | studi non tenuti |
|---|---|---|
| voci | 1.347 | 705 (130 non chiuse) |
| voci chiuse con gruppi diversi da Gemma | 240 | 305 |
| schede del campione | 51 | 69 |
| cause nel campione: lettore / tutti e due / scelte / curatore / fuori vista | 7 / 0 / 30 / 14 / 0 | 26 / 6 / 29 / 7 / 1 |
| errore di lettura del lettore fra le voci diverse, pesato | 9,8% (IC95 3,6-17,0) | 42,7% (31,4-55,1) |
| `scelte_diverse`, pesato | 62,8% (48,9-76,2) | 45,6% (33,3-57,8) |
| errore dei curatori (solo o con il lettore), pesato | 27,4% (14,8-40,6) | 20,1% (10,3-30,3) |
| voci con un errore di lettura del lettore, stima | **24 (8-42) = 1,8% (0,6-3,1)** | **129 (91-169) = 18,3% (12,9-24,0)** |

Differenza della quota di errore fra le voci diverse: −32,9 punti (IC95 −47,2, −18,9). La stima pesata delle voci diverse
negli studi tenuti è 243 contro le 240 vere.

**Lettura derivata, con i suoi limiti.** Se una voce identica ai curatori conta come giusta (non le abbiamo lette), negli
studi tenuti i gruppi sono dei curatori nell'82,2% delle voci, diversi per scelta o per errore dei curatori in circa il
16%, sbagliati dal lettore in circa il 2%. Sul totale: 67,1% identiche, circa 19% diverse senza errore del lettore, 7,4%
con errore di lettura, 6,3% non chiuse.

# 7. Deviazioni dalla carta

1. **KD5 (ii)** fallito alla lettera (§2): carta non cambiata, cancello corretto dichiarato dopo.
2. **Forma delle schede** (`20-schede.R`): un livello per riga e righe spezzate sotto 1.900 caratteri, decise dopo una
   prima corsa con una riga di 3.571 caratteri e prima di ogni lettura.
3. **Un caso che la carta non scrive alla lettera** (lettore `errore` o `non_verificabile`, Gemma `non_verificabile`):
   deciso nel programma prima dei giudizi come `errore_del_lettore`; nel campione vale per 0 voci.
4. **Le 8 voci in più dei file dei Claude** (2.060 contro 2.052): non stanno nelle 2.052 voci della misura di Mistral e
   non entrano nel censimento; la classe riformata è uguale ai file dei Claude nelle altre 2.052.
5. **Il conto del §6** è nato dopo i numeri.
6. **PD6**: in un messaggio intermedio al PI l'ho detta «indeterminata»; con la regola della carta è confermata
   (estremo basso 75,2 contro la soglia 75).
7. **Esca `GSE71289`**: l'attesa della carta (scelta) non è confermata dalle letture (errore dei curatori).

# 8. Limiti

- **È un campione**: 120 voci su 545. Le 1.377 voci identiche ai curatori e le 130 non chiuse non sono state lette: un
  errore comune al lettore e ai curatori in una voce identica non si vede.
- **Chi legge è un Claude**: audit interno, non una validazione pubblicabile. I giudizi seguono le istruzioni, che danno
  `sostenuto` nel dubbio e chiedono una frase del testo per (c) e (d): un disegno che unisce controlli diversi o toglie
  una variabile di contesto è `sostenuto`. Con istruzioni più severe la quota di errori sale per tutti e due i lati.
- **La lettura non è del tutto cieca al lato**: i nomi dei livelli dei curatori hanno la forma di un'ontologia, quelli del
  lettore no. Vale per gli agenti e per le mie 9 decisioni. In S051 il lato si deduce dalla coppia di cause.
- **Le 9 decisioni** le ha prese un solo lettore (io). PD7 cambia di 0,3 punti fra le due letture prese da sole.
- **Tre agenti hanno avuto il contesto compattato a metà lavoro** (uno ha scritto le prove di 8 schede dagli appunti, uno
  non ha riletto 3 schede, uno ha ripreso 2 schede dal suo riassunto). Un agente ha segnalato due casi vicini giudicati in
  modo diverso (codice del lotto in S025, codice della replica in S101).
- **S039**: l'errore (b) del disegno dei curatori è nei nomi dei livelli (dosi scambiate) con gruppi che coincidono; le
  due letture concordano. **S093**: `errore` (b) del lettore con un dubbio dichiarato su un campione.
- **Il conto del §6** poggia su 51 schede negli studi tenuti, 7 con un errore del lettore, ed è nato dopo i numeri.
- **Un solo lettore**: la causa riguarda Mistral `B0`. Per gli altri lettori c'è solo la classe dei gruppi.

# 9. Dubbi e come sono chiusi

| dubbio | chiusura |
|---|---|
| KD5 (ii) fallito alla lettera | spiegato (§2): errore nell'attesa della carta, lo strumento vede lo studio, la classe non entra nelle quote |
| PD2, PD3, PD4, PD5, PD8 indeterminate | spiegate (§3, §4): nessuna tocca la quantità finale; PD8 dice più scelte dell'atteso |
| Esca `GSE71289` diversa dall'attesa | spiegato (§4): le due letture concordano su un errore (d) dei curatori |
| Passaggio a tutto ARCHS4 con la regola dell'accordo | **scelta del PI** (riassunto) |

# 10. Da dove vengono i numeri del riassunto

| frase del riassunto | file e riga | valore letto |
|---|---|---|
| 545 voci su 2.052, 130 non chiuse | `10-out.txt`, KD2 e KD3 | identica 1377, incrociata 82, non_chiuso 130, piu_fine 307, piu_grossa 156 |
| 120 voci lette | `20-out.txt`, «schede scritte» | campione 120, esche 4 |
| `GSE46665`: atteso «livelli più fini», trovato «un fattore in più» | `10-out.txt`, KD5 (ii) | FALLISCE alla lettera; corretto PASSA |
| scelte 53% | `30-out.txt`, `scelte_diverse` | 53.2% |
| errore di lettura del modello 28% | `30-out.txt`, PD7 | 28.0% |
| errore dei curatori 23% | `30-out.txt`, `curatore_errore` | 23.3% |
| tutti e due 5% | `30-out.txt`, `errore_di_tutti_e_due` | 5.1% |
| circa 7 voci su 100, circa 153 su 2.052 | `30-out.txt`, «voci con un errore di lettura» | 7.4%, circa 153 voci |
| 130 non chiuse (6%) | `30-out.txt`, stessa riga | 130 (6,3%) |
| gruppi più grossi: 19 su 40 | `30-out.txt`, cause per classe dei gruppi | 18 + 1 su 40 |
| gruppi più fini: 7 su 50, 31 scelte, 12 curatori | `30-out.txt`, stessa tabella | 4 + 3, 31, 12 su 50 |
| errore più frequente: campione nel livello sbagliato | `30-out.txt`, tipo dell'errore | b 27 su 40 (lettura 1), b 25 su 39 (lettura 2) |
| studi dove i due modelli concordano: 24 su 1.347 (2%) | `32-out.txt`, ultima stima | 24 su 1347 = 1.8% |
| altri studi: 129 su 705 (18%) | `32-out.txt`, ultima stima | 129 su 705 = 18.3% |
| circa due studi su tre tenuti | `docs/findings/2026-11-15-lettori-su-gemma-parte-aperta.md`, riassunto punto 3 | 1.337 su 2.008 (66,6%) |
| 991 studi chiusi | `analysis/audit/2026-11-15-lettori-su-gemma/21-divisione.csv` (CLAUDE.md §1) | 991 |
| 42,21 dollari su 99 | `analysis/audit/2026-11-15-claude-su-gemma/30-out.txt` (CLAUDE.md §1) | 42,21 |
| 51 e 113 minuti su 2.016 studi | CLAUDE.md §1, parte terza | 51 minuti l'una; 113 minuti |
| 10 e 23 ore su 24.393 studi | calcolo: 51 × 24.393 / 2.016 = 617 min; 113 × 24.393 / 2.016 = 1.367 min | 10,3 h; 22,8 h |

[^carta]: `analysis/audit/2026-11-15-disaccordi-con-gemma/00-previsioni.md`.
[^censimento]: `analysis/audit/2026-11-15-disaccordi-con-gemma/10-out.txt`, `10-censimento-voci.csv`, `10-fattori.csv`.
[^schede]: `analysis/audit/2026-11-15-disaccordi-con-gemma/20-out.txt`; chiave in `20-chiave.csv`, copiata dopo le decisioni.
[^istruzioni]: `analysis/audit/2026-11-15-disaccordi-con-gemma/21-istruzioni.md`.
[^confronta]: `analysis/audit/2026-11-15-disaccordi-con-gemma/30-confronta-out.txt`.
[^decisioni]: `analysis/audit/2026-11-15-disaccordi-con-gemma/31-decisioni.csv`.
[^misura]: `analysis/audit/2026-11-15-disaccordi-con-gemma/30-out.txt`, `30-cause-per-scheda.csv`, `30-letture/`.
[^accanto]: `analysis/audit/2026-11-15-disaccordi-con-gemma/32-accanto-tenuti.R`, `32-out.txt`.
[^lettori]: `docs/findings/2026-11-15-lettori-su-gemma-parte-aperta.md`.
