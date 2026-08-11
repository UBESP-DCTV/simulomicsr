# Previsioni depositate PRIMA di misurare l'influenza

**Scritte:** 2026-08-10, dopo il PASSO 1 (lista degli accusati riderivata sui confronti
poolati) e **prima** di eseguire una sola leave-one-out.
**Handout:** `2026-08-10-sensitivity-confronti-spuri-HANDOUT.md` §5 passo 2.

> Il progetto deposita le previsioni prima dei run pesanti da quando le cinque invarianti di
> v15 sono tornate alla cifra (2026-08-05). Qui serve a qualcosa di più: **il disegno è cieco
> proprio ai difetti che deve misurare**, quindi va scritto adesso che cosa un esito «nessuna
> influenza» sarebbe autorizzato a concludere. Dopo, sarebbe una razionalizzazione.

---

## 0. Che cosa un esito nullo licenzia — e che cosa NO

Una leave-one-out trova gli studi **discordanti**. I difetti censiti (secondo agente,
materiale diverso, passaggio di coltura, linea cellulare, sede anatomica, donatore) producono
in larga parte uno studio che misura *comunque* il contrasto voluto, con un bias
plausibilmente **concorde** con gli altri.

Misurato prima di partire (handout §6.1): la concordanza col poolato degli studi accusati
(ρ mediano **0,652**) non è distinguibile da quella dei puliti (**0,683**), **Wilcoxon
p = 0,168** su 344 studi; sui 58 misurati con la LOO vera le distribuzioni si sovrappongono
(p = 0,159 e 0,172).

| se l'influenza risulta piccola, si può dire | non si può dire |
|---|---|
| «rimuovere gli studi accusati non cambia il risultato pubblicato» | «i confronti accusati non sono difettosi» |
| «la conclusione non poggia su quegli studi» | «i difetti non hanno introdotto bias» |
| «l'ordinamento dei geni mostrati è stabile» | «il gruppo è coerente» |

**Un bias concorde è invisibile a questo disegno.** L'esito «piccolo» è quello che il disegno
produce comunque: distingue «gli accusati non trascinano il risultato» da «gli accusati lo
trascinano», **non** «ci sono difetti» da «non ce ne sono».

## 1. Le previsioni

Numerate, ciascuna falsificabile. Misura di riferimento: le tre statistiche di §4.3
(Spearman del ranking, geni significativi guadagnati/persi, massimo |Δ logFC| fra i primi 30),
su un **insieme di geni fisso** dichiarato prima.

| # | previsione | come si falsifica |
|---|---|---|
| **P1** | La rimozione in blocco degli studi accusati lascia **Spearman ≥ 0,95** sul ranking in almeno **9 gruppi su 11** | meno di 9 |
| **P2** | Esiste **almeno un gruppo** in cui il massimo \|Δ logFC\| fra i primi 30 geni supera **1,0** pur avendo Spearman ≥ 0,99 — cioè un solo numero non basta | nessun gruppo |
| **P3** | I gruppi con peso contaminato più alto (LPS 15,9%, palbociclib 15,4%, IL1B 13,3%) mostrano l'influenza maggiore; **la correlazione fra peso contaminato e max\|Δ logFC\| è positiva** (Spearman > 0) | correlazione ≤ 0 |
| **P4** | Il **nullo appaiato** (insiemi di studi puliti con lo stesso numero di bracci e campioni rimossi) produce un'influenza **della stessa grandezza** degli accusati: il test di posizione non scende sotto 0,05 in **almeno 6 gruppi su 8** con potenza sufficiente | meno di 6 |
| **P5** | La variazione del **numero di geni significativi** è dominata dalla perdita di potenza (k che cala), non dal cambio di stima: **il segno è negativo in ≥ 9 gruppi su 11** | meno di 9 |
| **P6** | **TGF-β1** — 5 studi accusati, 9,1% del peso, k=59 — resta con **Spearman ≥ 0,99** e i sei bersagli canonici (SKIL, PMEPA1, SERPINE1, TGFBI, BHLHE40, FSTL3) **tutti ancora significativi** | un bersaglio esce, o Spearman < 0,99 |
| **P7** | **DHT ed enzalutamide** dopo la rimozione danno ancora **≥ 95%** dei geni significativi in entrambi con segno opposto (oggi: 1.266/1.299 = 97,5%). Enzalutamide non ha studi da togliere, quindi si muove solo DHT | sotto il 95% |

## 2. Che cosa mi aspetto di sbagliare

Dichiarato prima, perché il conto delle previsioni del PASSO 1 è stato **quattro falsificate su
otto, tutte nella stessa direzione**: avevo sottostimato quanto il deliverable ri-risolva le cose
da sé.

Qui la direzione dell'errore atteso è l'opposta: **credo che P4 (il nullo appaiato indistinguibile)
reggerà**, e questo renderebbe l'intero esercizio incapace di separare gli accusati dai puliti.
Se P4 regge e P1 regge, la conclusione onesta non è «i difetti non contano» ma **«togliere cinque
studi qualsiasi da un gruppo con k≥15 non cambia il risultato, e gli accusati non fanno
eccezione»** — che è una proprietà della robustezza del pooling, non un'assoluzione dei difetti.

## 3. Vincoli sulla misura, fissati adesso

1. **Insieme di geni fisso.** `FDR_BH_within_cluster` si ricalcola su un denominatore diverso a
   ogni rimozione, e il 3,5% dei geni ha `k_effective = 2` e sparisce sotto LOO. Le tre
   statistiche si calcolano sui geni **significativi nel pooling pieno e presenti in entrambe le
   versioni**, e si dichiara quanti geni cadono.
2. **Nessuna soglia scelta dopo aver visto i numeri.** La soglia sull'influenza è una decisione
   dell'utente (passo 6), presa sulla curva a gradini.
3. **Il nullo è appaiato sui dati rimossi**, non sul peso: i 5 accusati di TGF-β1 portano 16
   bracci su 97 contro una mediana di 7 per 5 studi puliti; il peso invece non differisce
   (Wilcoxon p = 0,478).
4. **Denominatori dichiarati sempre**: 25 coppie (studio, gruppo) accusate su 11 gruppi, non 34
   su 13.
