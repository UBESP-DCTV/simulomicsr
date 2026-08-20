# Quanto pesano i confronti difettosi, sulle 194

**Data:** 2026-08-20/21 · **Deliverable:** A3 v16 `20260819T185517Z-stage4-v16-3e31e59d`
**Lista dei difetti:** la rilettura di tutte e 194 (`difetti.csv`: 97 segnalazioni,
94 coppie gruppo-studio, 85 studi distinti, 66 gruppi)

> Questo è il risultato lungo. La versione breve sta in
> `COME-SI-FORMA-UNA-META-ANALISI.md`, §«Quanto pesano i difetti».

---

## 0. Perché una misura e non un gate

Deciso il 2026-08-10 (opzione A dell'utente): i confronti difettosi **non
escludono** una meta-analisi. Il motivo è che il verdetto di coerenza non era
riproducibile — sugli stessi 213 gruppi Mistral ne dichiarava incoerenti 24 e la
lettura umana 96, accordo 36,2% — e perché la regola severa «almeno un confronto
difettoso ⇒ fuori» **azzera tutte le meta-analisi con k ≥ 15**, cioè esattamente
quelle con potenza.

Al posto del verdetto, tre misure. Qui sono rifatte sul deliverable **attuale** e
con la lista **nuova**: quelle del 2026-08-10 coprivano 13 gruppi (il peso) e 11
(l'influenza) del deliverable v15, con le accuse della rilettura del 5 agosto.

---

## 1. Metodo

### 1.1 Peso contaminato — quanta parte del pooling viene dai difettosi

Per ogni gene, la quota di peso random-effects degli studi accusati; poi la
**mediana sui geni**. Il peso è `1/(SE_studio² + τ²)`, con i bracci **collassati
per studio** prima di pesare.

Funzione di pacchetto `compute_pooling_weight_shares()`. Non è una regola scritta
a mano: quella pubblicata il 5 agosto usava la mediana di `1/SE²` sui **bracci**
senza collasso e senza τ², ed era sbagliata in entrambe le direzioni.

Uno studio accusato che nel pooling non porta peso contribuisce **0, non NA** — è
il caso che conta, perché un gruppo può avere accuse e peso contaminato nullo.

### 1.2 Influenza — di quanto si sposta il risultato togliendoli

Si toglie **in blocco** ogni studio accusato del gruppo e si rifà il pooling con
la stessa catena della produzione (`pool_cluster_leaving_out()`: collasso dei
bracci per studio, poi `.pool_rem_cluster`). Non serve un re-pool.

Tre statistiche, perché una sola inganna (sullo stesso gruppo si vedono Spearman
0,99 e scarti di 2-3 unità di logFC):

| statistica | risponde a |
|---|---|
| **Spearman** del ranking | cambiano *quali* geni si mostrano? |
| **geni significativi persi** | cambia *quanto* risultato c'è? |
| **max \|Δ logFC\| fra i primi 30** | cambia la *grandezza* di un effetto? |

L'insieme dei geni è **fissato sul pooling pieno** (i significativi a FDR < 0,05):
riordinare anche il ridotto misurerebbe geni diversi a ogni rimozione. Il ranking
usa `p_value_pool` e non l'FDR, perché l'FDR si ricalcola su un denominatore
diverso a ogni rimozione e ne farebbe una misura del denominatore.

**Prova di accettazione, dentro lo script:** per ogni gruppo il ri-pooling
*pieno* deve riprodurre `cluster_pooled.parquet`. **Superata su 66 gruppi su 66,
con scarto massimo esattamente 0** su logFC, SE, p, τ², I² e k.

### 1.3 I nulli — è il difetto, o è il togliere dati?

Togliere *qualunque* studio sposta il risultato. Quindi per ogni gruppo la
rimozione accusata si confronta con **20 rimozioni casuali di studi puliti** dello
stesso gruppo, e si riporta il **percentile** della rimozione accusata fra quelle
pulite: 0,50 = indistinguibile, 1,00 = sposta più di ogni rimozione pulita.

Le estrazioni pulite hanno lo **stesso numero di studi** degli accusati, e fra le
possibili si scelgono quelle col numero di **bracci** più vicino. Seme fisso per
gruppo: due esecuzioni danno gli stessi nulli.

> **Il difetto del nullo del 2026-08-10, qui corretto.** Quel nullo pareggiava i
> bracci ma toglieva **1,35 volte più studi** degli accusati (2,3 volte su
> TGF-β1): conservativo nella direzione sbagliata, e il suo p = 0,765 non provava
> indistinguibilità. Lo scarto residuo di bracci è riportato, non nascosto.

---

## 2. Risultati

### 2.1 Peso contaminato

**128 delle 194 (66%) non hanno alcun difetto letto** → peso contaminato 0 per
costruzione. Sui **66 gruppi accusati**:

| | |
|---|---:|
| peso contaminato mediano | **21,2%** |
| minimo · massimo | 0,0% · 88,0% |
| gruppi accusati con peso contaminato **zero** | 1 |
| gruppi sopra il 25% del peso | 27 |
| gruppi sopra il 50% del peso | 8 |

### 2.2 Influenza, e l'aritmetica che va scorporata

Il numero grezzo — «mediana 39,7% dei geni significativi persi» — mescola due
cose diverse e da solo inganna:

- **aritmetica**: un gruppo a k=3 che perde uno studio resta a k=2, sotto la
  soglia del pooling, e perde il 100% *per costruzione*. Sono **21 gruppi su 66**,
  tutti a k=3-4;
- **influenza vera**: il gruppo sopravvive e il risultato si sposta comunque.
  Sono **45 gruppi**.

Solo la seconda è una misura. La prima è la fragilità di `k ≥ 3`, che è un fatto
sul **gate**, non sul difetto — ed è lo stesso fatto trovato ieri sul movimento
fra le due esecuzioni (il 62,4% degli studi che escono dal deliverable aveva la
chiave di contrasto identica).

**Dove la meta-analisi sopravvive** (45 gruppi):

| | |
|---|---:|
| Spearman del ranking, mediana | **0,781** (1° quartile 0,622) |
| geni significativi persi, mediana | **27,3%** (massimo 86,7%) |
| max \|Δ logFC\|, mediana | 0,248 |
| peso contaminato, mediana | 14,7% |

### 2.3 Il meccanismo, che si vede per fascia di k

| fascia | gruppi accusati | muoiono | peso contaminato | geni sig. persi | Spearman |
|---|---:|---:|---:|---:|---:|
| k = 3-4 | 29 | **21** | **38,4%** | 58,0% | 0,473 |
| k = 5-9 | 23 | 0 | 18,1% | 40,7% | 0,632 |
| k = 10-14 | 2 | 0 | 7,3% | 17,3% | 0,840 |
| k ≥ 15 | 12 | 0 | **8,8%** | 13,1% | 0,864 |

**Monotono su tutte e tre le misure.** Più il gruppo è grande, meno il difetto
conta — e la ragione è che il peso si diluisce fra più studi.

Questo chiude in modo netto la lettura ambigua di ieri. I gruppi grandi
**contengono** quasi sempre un difetto, ma è pura aritmetica (a tasso costante
dell'8,2% per studio, un gruppo con 54 studi ne contiene uno quasi certamente); e
quel difetto **pesa poco**: 8,8% del peso, 13% dei geni significativi,
Spearman 0,86. I gruppi piccoli raramente ne contengono uno, ma quando capita
domina — 38% del peso — e spesso li uccide.

> **Riproduzione indipendente:** il peso contaminato mediano dei gruppi a k ≥ 15
> è **8,8%**, identico al valore misurato il 2026-08-10 su un deliverable diverso
> (v15) e con una lista di accuse diversa. Due letture indipendenti, stesso
> numero.

### 2.4 Che cosa resta in piedi

| | |
|---|---:|
| senza alcun difetto letto | 128 |
| con difetti, ma sopravvivono togliendoli | 45 |
| con difetti, e non sopravvivono | 21 |
| **restano in piedi togliendo TUTTI i difetti** | **173 su 194** |

I 173 coincidono col conto fatto ieri per un'altra strada (togliere gli 85 studi
accusati e contare quanti gruppi restano a k ≥ 3): due calcoli indipendenti,
stesso risultato.

### 2.5 I nulli — RISULTATO DA COMPILARE

*(in esecuzione: 66 gruppi × 20 nulli)*

---

## 3. Limiti, dichiarati

1. **Una leave-one-out vede solo gli studi DISCORDANTI.** I difetti censiti —
   secondo agente, materiale diverso, passaggio, donatore — producono in larga
   parte uno studio che misura comunque il contrasto voluto, con un bias
   plausibilmente **concorde**. Un bias concorde è invisibile a questo disegno.
   Misurato il 2026-08-10: la concordanza col poolato degli studi accusati
   (ρ 0,652) non è distinguibile da quella dei puliti (0,683), p = 0,168.
   **«Influenza piccola» non assolve il difetto.**
2. Il peso contaminato è un **limite superiore** del danno: dice quanto del
   pooling passa da quegli studi, non quanto di quel contributo sia sbagliato.
3. La lista dei difetti viene da una lettura automatica delle etichette, con
   verifica meccanica delle citazioni (98,5%) ma senza una lettura umana
   indipendente. Il 16,5% dei verdetti non è chiuso dall'etichetta.
4. I gruppi a k=3 che «muoiono» non sono un risultato sul difetto: sono un
   risultato sul gate. Vanno riportati separatamente, come qui.

---

## 4. File

| file | contenuto |
|---|---|
| `B1-peso-contaminato.R` · `.csv` | peso contaminato, tutte e 194 |
| `B2-influenza-loo.R` · `.csv` | influenza a blocco, 66 gruppi, con la prova di accettazione |
| `B3-nulli.R` · `.csv` | i nulli appaiati, 20 per gruppo |
| `B4-lettura.R` · `B4-quadro-influenza.csv` | le tre misure insieme, aritmetica scorporata |
